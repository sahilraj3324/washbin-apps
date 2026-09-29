import 'package:washbinapp/core/api/api_client.dart';
import 'package:washbinapp/features/addresses/domain/address.dart';
import 'package:washbinapp/features/addresses/domain/coordinates.dart';

/// The customer's saved addresses, and whether a point can be served.
///
/// Every read and write uses the `/addresses/me` routes: the customer id comes
/// from the bearer token, so one customer can neither see nor edit another's
/// addresses even by guessing an id.
class AddressRepository {
  AddressRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// Default first, then newest — the order the picker shows them in.
  Future<List<Address>> getMyAddresses() async {
    final json = await _api.getJsonList('/addresses/me');

    return json
        .cast<Map<String, dynamic>>()
        .map(Address.fromJson)
        .toList(growable: false);
  }

  /// Saves a new address. The API makes the customer's first one the default
  /// whatever the draft says.
  Future<Address> addAddress(AddressDraft draft) async {
    return Address.fromJson(
      await _api.postJson('/addresses/me', draft.toJson()),
    );
  }

  Future<Address> updateAddress(String id, AddressDraft draft) async {
    return Address.fromJson(
      await _api.patchJson('/addresses/me/$id', draft.toJson()),
    );
  }

  /// Promotes one address to default, which demotes the previous one.
  ///
  /// There is no "clear the default": the API rejects that, because a customer
  /// with addresses but no default has nowhere to send a booking.
  Future<Address> setDefault(String id) async {
    return Address.fromJson(
      await _api.patchJson('/addresses/me/$id', {'isDefault': true}),
    );
  }

  Future<void> deleteAddress(String id) async {
    await _api.delete('/addresses/me/$id');
  }

  /// Whether Washbin covers this point for this service.
  ///
  /// Takes raw coordinates rather than an address id so the same call answers
  /// for a saved address and for "use my current location", which has nothing
  /// saved yet.
  Future<bool> isServiceable({
    required Coordinates point,
    required String serviceId,
  }) async {
    final json = await _api.postJson('/addresses/check-serviceability', {
      'latitude': point.latitude,
      'longitude': point.longitude,
      'serviceId': serviceId,
    });

    return json['serviceable'] as bool? ?? false;
  }
}
