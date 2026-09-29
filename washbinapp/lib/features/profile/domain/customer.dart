/// Mirrors `CustomerStatus` in the API. `blocked` is the only value that stops
/// a sign-in, and the server enforces that — this is here so the app can tell
/// the customer why rather than guess.
enum CustomerStatus {
  active,
  inactive,
  blocked;

  static CustomerStatus parse(Object? value) => switch (value) {
    'inactive' => CustomerStatus.inactive,
    'blocked' => CustomerStatus.blocked,
    _ => CustomerStatus.active,
  };
}

/// A Washbin customer, as the API describes them.
///
/// Phone is the account identity: it is verified by OTP and is the only thing
/// a customer signs in with. Name is required at creation, so an account that
/// exists always has one — there is no half-built profile on the server.
class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.profileImage,
    this.status = CustomerStatus.active,
  });

  /// Accepts both shapes the API produces: `id` from
  /// `POST /customer-auth/phone`, and Mongo's `_id` from `GET /customers/:id`.
  factory Customer.fromJson(Map<String, dynamic> json) {
    final id = json['id'] ?? json['_id'];

    return Customer(
      id: id is String ? id : id.toString(),
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: _nonEmpty(json['email']),
      profileImage: _nonEmpty(json['profileImage']),
      status: CustomerStatus.parse(json['status']),
    );
  }

  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? profileImage;
  final CustomerStatus status;

  /// The first name, for greetings. Falls back to the whole string when the
  /// customer entered a single word.
  String get givenName => name.trim().split(RegExp(r'\s+')).first;

  Customer copyWith({String? name, String? email, String? profileImage}) {
    return Customer(
      id: id,
      name: name ?? this.name,
      phone: phone,
      email: email ?? this.email,
      profileImage: profileImage ?? this.profileImage,
      status: status,
    );
  }

  static String? _nonEmpty(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;
}
