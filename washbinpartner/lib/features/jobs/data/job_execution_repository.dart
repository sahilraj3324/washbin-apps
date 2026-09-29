import 'package:washbinpartner/core/api/api_client.dart';
import 'package:washbinpartner/features/jobs/domain/job_offer.dart';
import 'package:washbinpartner/features/jobs/domain/partner_dashboard.dart';

class JobExecutionRepository {
  JobExecutionRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<JobBookingSummary?> getActive() async {
    final json = await _api.getJson('/bookings/me/active');
    final data = json['data'];

    if (data == null) {
      return null;
    }
    if (data is Map<String, dynamic>) {
      return JobBookingSummary.fromJson(data);
    }

    return JobBookingSummary.fromJson(json);
  }

  Future<PartnerDashboard> getDashboard() async {
    final json = await _api.getJson('/bookings/me/dashboard');
    return PartnerDashboard.fromJson(json);
  }

  Future<List<JobBookingSummary>> getHistory({
    required JobBookingStatus status,
    int limit = 30,
    int skip = 0,
  }) async {
    final wireStatus = switch (status) {
      JobBookingStatus.completed => 'completed',
      JobBookingStatus.cancelled => 'cancelled',
      _ => throw ArgumentError('History supports completed or cancelled only'),
    };

    final json = await _api.getJsonList(
      '/bookings/me/history',
      query: {'status': wireStatus, 'limit': '$limit', 'skip': '$skip'},
    );

    return json
        .cast<Map<String, dynamic>>()
        .map(JobBookingSummary.fromJson)
        .toList(growable: false);
  }

  Future<JobBookingSummary> markOnTheWay(String bookingId) =>
      _postBooking('/bookings/$bookingId/on-the-way');

  Future<JobBookingSummary> markArrived(String bookingId) =>
      _postBooking('/bookings/$bookingId/arrive');

  Future<JobBookingSummary> startService(String bookingId) =>
      _postBooking('/bookings/$bookingId/start');

  Future<JobBookingSummary> verifyStartOtp({
    required String bookingId,
    required String otp,
  }) => _postBooking('/bookings/$bookingId/verify-start-otp', {'otp': otp});

  Future<JobBookingSummary> completeService(String bookingId) =>
      _postBooking('/bookings/$bookingId/complete');

  Future<JobBookingSummary> _postBooking(
    String path, [
    Map<String, dynamic> body = const {},
  ]) async {
    final json = await _api.postJson(path, body);
    return JobBookingSummary.fromJson(json);
  }
}
