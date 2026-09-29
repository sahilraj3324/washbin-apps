import 'package:washbinpartner/core/api/api_client.dart';
import 'package:washbinpartner/features/availability/domain/partner_availability.dart';

class AvailabilityRepository {
  AvailabilityRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<PartnerAvailability> getMine() async {
    final json = await _api.getJson('/availability/me');
    return PartnerAvailability.fromJson(json);
  }

  Future<PartnerAvailability> updateMine({
    bool? isOnline,
    bool? isAvailable,
    double? latitude,
    double? longitude,
    double? serviceRadiusKm,
  }) async {
    final json = await _api.patchJson('/availability/me', {
      'isOnline': ?isOnline,
      'isAvailable': ?isAvailable,
      'latitude': ?latitude,
      'longitude': ?longitude,
      'serviceRadiusKm': ?serviceRadiusKm,
    });

    return PartnerAvailability.fromJson(json);
  }

  Future<PartnerAvailability> updateLocation({
    required double latitude,
    required double longitude,
  }) async {
    final json = await _api.patchJson('/availability/me/location', {
      'latitude': latitude,
      'longitude': longitude,
    });

    return PartnerAvailability.fromJson(json);
  }
}
