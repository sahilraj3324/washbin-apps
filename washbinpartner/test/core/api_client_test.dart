import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:washbinpartner/core/api/api_client.dart';
import 'package:washbinpartner/core/api/api_exception.dart';

const _baseUrl = 'https://api.test';

ApiClient _clientThat(
  Future<http.Response> Function(http.Request request) handler, {
  String? token,
  void Function()? onUnauthorized,
  Duration? timeout,
}) {
  return ApiClient(
    httpClient: MockClient(handler),
    accessToken: () => token,
    onUnauthorized: onUnauthorized,
    baseUrl: _baseUrl,
    timeout: timeout,
  );
}

http.Response _json(Map<String, dynamic> body, [int status = 200]) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

void main() {
  group('authorization', () {
    test('attaches the access token as a bearer header', () async {
      String? seen;
      final client = _clientThat((request) async {
        seen = request.headers['Authorization'];
        return _json({'ok': true});
      }, token: 'washbin-partner-token');

      await client.getJson('/partners/abc');

      expect(seen, 'Bearer washbin-partner-token');
    });

    test('sends no authorization header when nobody is signed in', () async {
      String? seen;
      final client = _clientThat((request) async {
        seen = request.headers['Authorization'];
        return _json({'ok': true});
      });

      await client.postJson('/partner-auth/phone', {'firebaseIdToken': 'x'});

      expect(seen, isNull);
    });
  });

  group('401 handling', () {
    test('reports a rejected token so the session can end', () async {
      var calls = 0;
      final client = _clientThat(
        (_) async => _json({'message': 'Invalid or expired token'}, 401),
        token: 'stale-token',
        onUnauthorized: () => calls++,
      );

      await expectLater(
        client.getJson('/partners/abc'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.kind,
            'kind',
            ApiErrorKind.unauthorized,
          ),
        ),
      );
      expect(calls, 1);
    });

    test(
      'a 401 on a call that carried no token is not a dead session',
      () async {
        // Signing out here would loop: sign out, retry, 401, sign out.
        var calls = 0;
        final client = _clientThat(
          (_) async => _json({'message': 'Missing bearer token'}, 401),
          onUnauthorized: () => calls++,
        );

        await expectLater(
          client.getJson('/bookings'),
          throwsA(isA<ApiException>()),
        );
        expect(calls, 0);
      },
    );
  });

  group('error mapping', () {
    test('a transport failure is a retryable network error', () async {
      final client = _clientThat(
        (request) async =>
            throw http.ClientException('failed host lookup', request.url),
      );

      await expectLater(
        client.getJson('/health'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiErrorKind.network)
              .having((e) => e.isRetryable, 'isRetryable', isTrue)
              .having((e) => e.message, 'message', contains('internet')),
        ),
      );
    });

    test('a slow server times out rather than hanging', () async {
      final client = _clientThat((_) async {
        await Future<void>.delayed(const Duration(seconds: 5));
        return _json({});
      }, timeout: const Duration(milliseconds: 50));

      await expectLater(
        client.getJson('/health'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.timeout,
          ),
        ),
      );
    });

    test('a 500 is retryable and never shows the server text raw', () async {
      final client = _clientThat(
        (_) async => http.Response('<html>Gateway crash</html>', 500),
      );

      await expectLater(
        client.getJson('/health'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiErrorKind.server)
              .having((e) => e.isRetryable, 'isRetryable', isTrue)
              .having((e) => e.message, 'message', isNot(contains('html'))),
        ),
      );
    });

    test('a 409 is surfaced with the server message', () async {
      final client = _clientThat(
        (_) async => _json({'message': 'Phone already registered'}, 409),
      );

      await expectLater(
        client.getJson('/partners/abc'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiErrorKind.conflict)
              .having((e) => e.message, 'message', 'Phone already registered'),
        ),
      );
    });

    test(
      "Nest's list of validation messages is joined, not printed raw",
      () async {
        final client = _clientThat(
          (_) async => _json({
            'message': ['name must be longer', 'email must be an email'],
          }, 400),
        );

        await expectLater(
          client.postJson('/partners', {}),
          throwsA(
            isA<ApiException>()
                .having((e) => e.kind, 'kind', ApiErrorKind.badRequest)
                .having(
                  (e) => e.message,
                  'message',
                  'name must be longer\nemail must be an email',
                ),
          ),
        );
      },
    );

    test('the PROFILE_REQUIRED code survives the round trip', () async {
      final client = _clientThat(
        (_) async => _json({
          'code': 'PROFILE_REQUIRED',
          'message': 'No account for this number yet.',
        }, 404),
      );

      await expectLater(
        client.postJson('/partner-auth/phone', {}),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'PROFILE_REQUIRED'),
        ),
      );
    });
  });

  group('requests', () {
    test('a query map reaches the server', () async {
      Uri? seen;
      final client = _clientThat((request) async {
        seen = request.url;
        return _json({'ok': true});
      });

      await client.getJson('/services', query: {'categoryId': 'abc'});

      expect(seen?.queryParameters, {'categoryId': 'abc'});
      expect(seen?.path, '/services');
    });

    test('a 204 with an empty body decodes to an empty map', () async {
      final client = _clientThat((_) async => http.Response('', 204));

      expect(await client.delete('/addresses/me/abc'), isEmpty);
    });
  });
}
