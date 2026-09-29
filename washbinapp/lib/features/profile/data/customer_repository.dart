import 'package:washbinapp/core/api/api_client.dart';
import 'package:washbinapp/features/profile/domain/customer.dart';

/// Reads and writes the signed-in customer's profile.
///
/// The API has no `GET /customers/me` yet, so the id from the session is used
/// against `GET /customers/:id`. That route is currently unauthenticated on
/// the server (a known backend issue); the bearer token is sent regardless, so
/// nothing here changes when the route is locked down and a `/me` variant
/// lands — only the two paths below.
class CustomerRepository {
  CustomerRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<Customer> getCustomer(String id) async {
    final json = await _api.getJson('/customers/$id');
    return Customer.fromJson(json);
  }

  Future<Customer> updateCustomer(
    String id, {
    String? name,
    String? email,
    String? profileImage,
  }) async {
    final json = await _api.patchJson('/customers/$id', {
      if (name != null) 'name': name.trim(),
      if (email != null) 'email': email.trim(),
      'profileImage': ?profileImage,
    });

    return Customer.fromJson(json);
  }
}
