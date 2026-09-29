import 'package:washbinpartner/core/api/api_client.dart';
import 'package:washbinpartner/features/services/domain/service.dart';

/// The catalogue: what Washbin sells, and therefore what a partner can offer.
///
/// Read-only from this app. Both routes are public on the server — the
/// catalogue is the same for everyone, signed in or not.
class ServicesRepository {
  ServicesRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// Only active rows: a partner must not be able to opt in to a service that
  /// has been taken down, because no customer can book it.
  Future<List<ServiceCategory>> getCategories() async {
    final json = await _api.getJsonList('/categories', query: {
      'isActive': 'true',
    });

    return json
        .cast<Map<String, dynamic>>()
        .map(ServiceCategory.fromJson)
        .toList(growable: false);
  }

  Future<List<Service>> getServices() async {
    final json = await _api.getJsonList('/services', query: {
      'isActive': 'true',
    });

    return json
        .cast<Map<String, dynamic>>()
        .map(Service.fromJson)
        .toList(growable: false);
  }
}
