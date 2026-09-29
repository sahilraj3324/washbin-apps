import 'package:washbinapp/core/api/api_client.dart';

/// What a dispatch sweep did.
class SweepResult {
  const SweepResult({
    required this.expired,
    required this.readvanced,
    required this.dispatched,
  });

  factory SweepResult.fromJson(Map<String, dynamic> json) {
    return SweepResult(
      expired: json['expired'] as int? ?? 0,
      readvanced: json['readvanced'] as int? ?? 0,
      // Absent on a server that predates scheduled dispatch.
      dispatched: json['dispatched'] as int?,
    );
  }

  /// Offers whose 60-second window had passed.
  final int expired;

  /// Bookings re-offered to the next partner after a lapse.
  final int readvanced;

  /// Scheduled bookings woken because their time had come. Null when the
  /// deployed API does not have the dispatcher yet.
  final int? dispatched;

  String get summary {
    final scheduled = dispatched == null
        ? 'dispatch not deployed'
        : '$dispatched scheduled dispatched';

    return '$expired offer(s) expired · $readvanced re-offered · $scheduled';
  }
}

/// Things worth poking by hand while building, and nothing a customer ever
/// does.
///
/// The sweep is normally driven by the platform cron every few minutes. On a
/// plan without sub-daily crons, or when you simply do not want to wait, this
/// runs the same work on demand.
class DevToolsApi {
  DevToolsApi({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<SweepResult> runDispatchSweep() async {
    return SweepResult.fromJson(
      await _api.postJson('/partner-assignment/sweep-expired', const {}),
    );
  }
}
