import 'package:washbinpartner/core/api/api_client.dart';
import 'package:washbinpartner/features/jobs/domain/job_offer.dart';

class JobOffersRepository {
  JobOffersRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<List<JobOffer>> getMine() async {
    final json = await _api.getJsonList('/partner-assignment/offers/me');

    return json
        .cast<Map<String, dynamic>>()
        .map(JobOffer.fromJson)
        .toList(growable: false);
  }

  Future<JobOffer> accept(String assignmentId) async {
    final json = await _api.postJson(
      '/partner-assignment/$assignmentId/accept',
      const {},
    );

    return JobOffer.fromJson(json);
  }

  Future<JobOffer> reject(String assignmentId) async {
    final json = await _api.postJson(
      '/partner-assignment/$assignmentId/reject',
      const {},
    );

    return JobOffer.fromJson(json);
  }
}
