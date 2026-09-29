import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:washbinapp/core/api/api_exception.dart';
import 'package:washbinapp/core/api/api_logger.dart';
import 'package:washbinapp/core/config/app_config.dart';

/// Supplies the current Washbin access token, or null when nobody is signed in.
///
/// This is the backend's own JWT — not the Firebase ID token. Firebase proves
/// the phone number once; `POST /customer-auth/phone` trades that proof for
/// the token every other route actually checks.
typedef AccessTokenProvider = String? Function();

/// Called when a request that *did* carry a token was rejected with 401, i.e.
/// the session is genuinely dead rather than merely absent.
typedef UnauthorizedCallback = void Function();

/// The single place any HTTP call leaves the app. Features go through
/// repositories, repositories go through here — no screen builds a request.
class ApiClient {
  ApiClient({
    http.Client? httpClient,
    AccessTokenProvider? accessToken,
    this.onUnauthorized,
    ApiLogger? logger,
    String? baseUrl,
    Duration? timeout,
  }) : _httpClient = httpClient ?? http.Client(),
       _accessToken = accessToken ?? _noToken,
       _logger = logger ?? const ApiLogger(),
       _baseUrl = baseUrl ?? AppConfig.baseUrl,
       _timeout = timeout ?? AppConfig.requestTimeout;

  static String? _noToken() => null;

  final http.Client _httpClient;
  final AccessTokenProvider _accessToken;
  final ApiLogger _logger;
  final String _baseUrl;
  final Duration _timeout;

  /// Settable because the session controller is built *after* the client it
  /// depends on; the composition root wires this up once both exist.
  UnauthorizedCallback? onUnauthorized;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
  }) {
    return _send('GET', path, query: query);
  }

  /// For routes that answer with a bare JSON array, as the catalogue does.
  Future<List<dynamic>> getJsonList(
    String path, {
    Map<String, String>? query,
  }) async {
    final json = await _send('GET', path, query: query);
    final data = json['data'];

    if (data is List) {
      return data;
    }

    // A route that should have sent an array sent an object instead — a
    // wrapper, or an error body that slipped through with a 2xx.
    throw const ApiException(
      'Washbin sent back something unexpected. Please try again.',
      kind: ApiErrorKind.server,
    );
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) {
    return _send('POST', path, body: body);
  }

  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> body,
  ) {
    return _send('PATCH', path, body: body);
  }

  /// A body is optional but does reach the server — `DELETE
  /// /notifications/device-token` identifies the device that way.
  Future<Map<String, dynamic>> delete(
    String path, [
    Map<String, dynamic>? body,
  ]) => _send('DELETE', path, body: body);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final uri = _resolve(path, query);
    final stopwatch = Stopwatch()..start();
    _logger.request(method, path);

    try {
      final request = http.Request(method, uri)..headers.addAll(_headers());
      if (body != null) {
        request.body = jsonEncode(body);
      }

      final streamed = await _httpClient.send(request).timeout(_timeout);
      final response = await http.Response.fromStream(streamed)
          .timeout(_timeout);

      _logger.response(method, path, response.statusCode, stopwatch.elapsed);
      return _handle(response);
    } on ApiException catch (error) {
      _logger.failure(method, path, error, stopwatch.elapsed);
      rethrow;
    } on TimeoutException catch (error) {
      _logger.failure(method, path, error, stopwatch.elapsed);
      throw const ApiException.timeout();
    } on http.ClientException catch (error) {
      _logger.failure(method, path, error, stopwatch.elapsed);
      throw const ApiException.network();
    } on FormatException catch (error) {
      // The server answered, but with something that is not JSON — a proxy
      // error page or an HTML crash dump. Not the customer's network.
      _logger.failure(method, path, error, stopwatch.elapsed);
      throw const ApiException(
        'Washbin sent back something unexpected. Please try again.',
        kind: ApiErrorKind.server,
      );
    } catch (error) {
      // Everything left is a transport failure: SocketException, a refused
      // connection, a DNS miss. dart:io types are not named because they do
      // not exist on web.
      _logger.failure(method, path, error, stopwatch.elapsed);
      throw const ApiException.network();
    }
  }

  Map<String, String> _headers() {
    final token = _accessToken();

    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _handle(http.Response response) {
    final decoded = _decodeBody(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final error = ApiException.fromStatus(
      response.statusCode,
      serverMessage: _errorMessage(decoded),
      code: _errorCode(decoded),
    );

    // Only a *rejected* token means the session died. A 401 on a call that
    // carried no token just means the route needed one, and signing the
    // customer out over it would be a loop: sign out, retry, 401, sign out.
    if (error.kind == ApiErrorKind.unauthorized && _hasToken) {
      onUnauthorized?.call();
    }

    throw error;
  }

  bool get _hasToken {
    final token = _accessToken();
    return token != null && token.isNotEmpty;
  }

  Map<String, dynamic> _decodeBody(String body) {
    if (body.trim().isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return {'data': decoded};
  }

  String? _errorCode(Map<String, dynamic> body) {
    final code = body['code'];
    return code is String && code.isNotEmpty ? code : null;
  }

  /// Nest sends `message` as a string, or as a list of strings when the
  /// ValidationPipe rejected several fields at once.
  String? _errorMessage(Map<String, dynamic> body) {
    final message = body['message'];

    if (message is String && message.isNotEmpty) {
      return message;
    }
    if (message is List && message.isNotEmpty) {
      return message.join('\n');
    }
    return null;
  }

  Uri _resolve(String path, Map<String, String>? query) {
    final baseWithScheme =
        _baseUrl.startsWith('http://') || _baseUrl.startsWith('https://')
        ? _baseUrl
        : 'https://$_baseUrl';
    final cleanBase = baseWithScheme.endsWith('/')
        ? baseWithScheme.substring(0, baseWithScheme.length - 1)
        : baseWithScheme;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$cleanBase$cleanPath');

    return query == null || query.isEmpty
        ? uri
        : uri.replace(queryParameters: {...uri.queryParameters, ...query});
  }

  void close() => _httpClient.close();
}
