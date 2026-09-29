import 'package:washbinapp/features/profile/domain/customer.dart';

/// What `POST /customer-auth/phone` returns: a Washbin access token plus enough
/// of the profile to start the app without a second round trip.
class AuthResult {
  const AuthResult({
    required this.accessToken,
    required this.id,
    required this.name,
    required this.phone,
    required this.isNewCustomer,
    this.email,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      accessToken: json['accessToken'] as String,
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      isNewCustomer: json['isNewCustomer'] as bool? ?? false,
      email: json['email'] as String?,
    );
  }

  final String accessToken;
  final String id;
  final String name;
  final String phone;
  final bool isNewCustomer;
  final String? email;

  /// The profile the sign-in already told us about. Enough to render the app;
  /// `CustomerRepository` fills in the rest when it can.
  Customer toCustomer() =>
      Customer(id: id, name: name, phone: phone, email: email);
}
