import 'package:washbinpartner/core/api/api_client.dart';

/// What `GET /health` reports back about the instance the app just reached.
class BackendHealth {
  const BackendHealth({
    required this.status,
    required this.databaseState,
    this.environment,
  });

  factory BackendHealth.fromJson(Map<String, dynamic> json) {
    final database = json['database'];

    return BackendHealth(
      status: json['status'] as String? ?? 'unknown',
      databaseState: database is Map<String, dynamic>
          ? database['state'] as String? ?? 'unknown'
          : 'unknown',
      environment: json['env'] as String?,
    );
  }

  final String status;
  final String databaseState;
  final String? environment;

  bool get isHealthy => status == 'ok' && databaseState == 'connected';

  String get summary =>
      'API $status · database $databaseState${environment == null ? '' : ' · $environment'}';
}

/// A deliberate, on-demand connectivity check for development.
///
/// This is not called during startup: the app has no product reason to ping
/// the server before it needs it, and doing so would add a round trip to every
/// cold launch.
class HealthApi {
  HealthApi({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<BackendHealth> check() async {
    final json = await _api.getJson('/health');
    return BackendHealth.fromJson(json);
  }
}
