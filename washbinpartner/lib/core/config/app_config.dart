import 'package:flutter/foundation.dart';

/// Which backend this build talks to. Selected at compile time with
/// `--dart-define=ENV=...`; anything unrecognised is treated as production so
/// a typo can never silently point a release build at a dev server.
enum AppEnvironment { development, staging, production }

/// Every environment-dependent value in the app. Nothing here is a secret —
/// these are build settings, and the Firebase client config lives in
/// `google-services.json` / `GoogleService-Info.plist` instead.
///
/// Kept deliberately identical to the customer app's, so one `--dart-define`
/// points both apps at the same API.
class AppConfig {
  const AppConfig._();

  static const _env = String.fromEnvironment('ENV', defaultValue: 'production');
  static const _baseUrlOverride = String.fromEnvironment('API_BASE_URL');

  /// The name this project shipped with before `API_BASE_URL` existed. Still
  /// honoured so existing run configurations and CI scripts keep working.
  static const _legacyBaseUrlOverride = String.fromEnvironment(
    'WASHBIN_API_BASE_URL',
  );

  static AppEnvironment get environment => switch (_env.toLowerCase()) {
    'development' || 'dev' || 'local' => AppEnvironment.development,
    'staging' || 'stage' => AppEnvironment.staging,
    _ => AppEnvironment.production,
  };

  /// An explicit `--dart-define` always wins; otherwise the environment picks
  /// the default. See `docs/environments.md` for the per-device values.
  static String get baseUrl {
    if (_baseUrlOverride.isNotEmpty) {
      return _baseUrlOverride;
    }
    if (_legacyBaseUrlOverride.isNotEmpty) {
      return _legacyBaseUrlOverride;
    }

    return switch (environment) {
      AppEnvironment.development => _localBaseUrl,
      AppEnvironment.staging => 'https://washbin-api-staging.vercel.app',
      AppEnvironment.production => 'https://washbin-api.vercel.app',
    };
  }

  /// `localhost` on a device means the device itself, and the Android emulator
  /// reaches the host machine on a dedicated alias instead. A physical phone
  /// matches neither and must pass `--dart-define=API_BASE_URL=http://<lan-ip>:3000`.
  static String get _localBaseUrl =>
      defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:3000'
      : 'http://localhost:3000';

  static const requestTimeout = Duration(seconds: 20);

  /// How long the splash stays up even when the session resolves sooner, so
  /// startup reads as a deliberate brand moment rather than a flash.
  static const splashMinimumDuration = Duration(milliseconds: 2600);

  /// Request logging is a development aid and never runs in a release build,
  /// regardless of which environment the build points at.
  static bool get enableNetworkLogging =>
      kDebugMode && environment != AppEnvironment.production;

  static bool get isProduction => environment == AppEnvironment.production;
}
