import 'dart:developer' as developer;

import 'package:washbinapp/core/config/app_config.dart';

/// Request logging for development.
///
/// Deliberately records only the shape of a call — method, path, status,
/// duration. Headers (which carry the bearer token), request bodies (which
/// carry OTP codes and Firebase tokens) and response bodies (which carry
/// personal data) are never passed in, so they can never be logged by mistake.
class ApiLogger {
  const ApiLogger();

  static const _name = 'washbin.api';

  bool get _enabled => AppConfig.enableNetworkLogging;

  void request(String method, String path) {
    if (!_enabled) {
      return;
    }
    developer.log('→ $method $path', name: _name);
  }

  void response(String method, String path, int statusCode, Duration elapsed) {
    if (!_enabled) {
      return;
    }
    developer.log(
      '← $method $path $statusCode (${elapsed.inMilliseconds}ms)',
      name: _name,
    );
  }

  void failure(String method, String path, Object error, Duration elapsed) {
    if (!_enabled) {
      return;
    }
    developer.log(
      '✗ $method $path failed after ${elapsed.inMilliseconds}ms: $error',
      name: _name,
    );
  }
}
