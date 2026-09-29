import 'package:washbinpartner/core/api/api_client.dart';
import 'package:washbinpartner/features/services/domain/partner_service.dart';

/// The signed-in partner's own service list.
///
/// All three routes are `/partner-services/me*`, which take the partner id
/// from the bearer token — a partner cannot read or change anyone else's
/// offerings.
class PartnerServicesRepository {
  PartnerServicesRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// Every row, active and paused alike. The paused ones matter: re-selecting
  /// a service reactivates its row rather than creating a second one.
  Future<List<PartnerServiceRow>> getMine() async {
    final json = await _api.getJsonList('/partner-services/me');

    return json
        .cast<Map<String, dynamic>>()
        .map(PartnerServiceRow.fromJson)
        .toList(growable: false);
  }

  Future<PartnerServiceRow> add(String serviceId) async {
    final json = await _api.postJson('/partner-services/me', {
      'serviceId': serviceId,
    });

    return PartnerServiceRow.fromJson(json);
  }

  /// Turns an existing row on or off.
  ///
  /// This is how a partner removes a service: the API has no partner-facing
  /// delete, deliberately. Pausing keeps the history and the row's identity,
  /// and partner assignment skips an inactive row just as it would a missing
  /// one.
  Future<PartnerServiceRow> setActive({
    required String rowId,
    required bool isActive,
  }) async {
    final json = await _api.patchJson('/partner-services/me/$rowId', {
      'isActive': isActive,
    });

    return PartnerServiceRow.fromJson(json);
  }
}
