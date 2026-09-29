/// What went wrong, in terms the app can branch on. The HTTP status is kept
/// alongside for logging, but screens should switch on this instead so that
/// "no internet" and "server exploded" stay distinguishable.
enum ApiErrorKind {
  /// The request itself was malformed or rejected by validation.
  badRequest,

  /// 401 — the Washbin token is missing, expired, or not a customer token.
  unauthorized,

  /// 403 — authenticated, but not allowed. A blocked account lands here.
  forbidden,
  notFound,
  conflict,

  /// 5xx — the server failed. Retrying may work.
  server,

  /// The request never reached the server: no internet, DNS failure, refused.
  network,
  timeout,
  unknown,
}

class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.code,
    this.kind = ApiErrorKind.unknown,
  });

  /// Builds the exception for a response that came back with an error status,
  /// preferring the server's own message when it sent one worth showing.
  factory ApiException.fromStatus(
    int statusCode, {
    String? serverMessage,
    String? code,
  }) {
    final kind = _kindForStatus(statusCode);
    return ApiException(
      serverMessage?.trim().isNotEmpty == true
          ? serverMessage!.trim()
          : messageForKind(kind),
      statusCode: statusCode,
      code: code,
      kind: kind,
    );
  }

  const ApiException.network()
    : message = 'No internet connection. Check your network and try again.',
      statusCode = null,
      code = null,
      kind = ApiErrorKind.network;

  const ApiException.timeout()
    : message = 'The server took too long to respond. Please try again.',
      statusCode = null,
      code = null,
      kind = ApiErrorKind.timeout;

  final String message;
  final int? statusCode;

  /// Machine-readable reason from the API, when it sends one — e.g.
  /// `PROFILE_REQUIRED` for a verified number that has no account yet.
  final String? code;

  final ApiErrorKind kind;

  /// True when trying the same request again could plausibly succeed. Drives
  /// whether an error view offers a retry button.
  bool get isRetryable => switch (kind) {
    ApiErrorKind.network || ApiErrorKind.timeout || ApiErrorKind.server => true,
    _ => false,
  };

  static ApiErrorKind _kindForStatus(int statusCode) => switch (statusCode) {
    400 => ApiErrorKind.badRequest,
    401 => ApiErrorKind.unauthorized,
    403 => ApiErrorKind.forbidden,
    404 => ApiErrorKind.notFound,
    409 => ApiErrorKind.conflict,
    // Nest's ValidationPipe answers 400, but a 422 from anywhere else means
    // the same thing to a customer: the details they sent were not accepted.
    422 => ApiErrorKind.badRequest,
    >= 500 => ApiErrorKind.server,
    _ => ApiErrorKind.unknown,
  };

  /// The fallback shown when the server sent no usable message. Deliberately
  /// free of status codes and stack traces.
  static String messageForKind(ApiErrorKind kind) => switch (kind) {
    ApiErrorKind.badRequest =>
      'Some of those details were not accepted. Please check and try again.',
    ApiErrorKind.unauthorized =>
      'Your session has expired. Please sign in again.',
    ApiErrorKind.forbidden => 'You do not have access to this.',
    ApiErrorKind.notFound => 'We could not find what you were looking for.',
    ApiErrorKind.conflict =>
      'That conflicts with something that already exists.',
    ApiErrorKind.server =>
      'Washbin is having trouble right now. Please try again in a moment.',
    ApiErrorKind.network =>
      'No internet connection. Check your network and try again.',
    ApiErrorKind.timeout =>
      'The server took too long to respond. Please try again.',
    ApiErrorKind.unknown => 'Something went wrong. Please try again.',
  };

  @override
  String toString() => message;
}
