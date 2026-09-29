import 'package:washbinpartner/features/partner/domain/partner.dart';

/// What `POST /partner-auth/phone` returns: a Washbin access token plus enough
/// of the partner to start the app without a second round trip.
class AuthResult {
  const AuthResult({
    required this.accessToken,
    required this.id,
    required this.businessName,
    required this.ownerName,
    required this.phone,
    required this.verificationStatus,
    required this.isNewPartner,
    this.email,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      accessToken: json['accessToken'] as String,
      id: json['id'] as String,
      businessName: json['businessName'] as String,
      ownerName: json['ownerName'] as String,
      phone: json['phone'] as String,
      verificationStatus: VerificationStatus.parse(json['verificationStatus']),
      isNewPartner: json['isNewPartner'] as bool? ?? false,
      email: json['email'] as String?,
    );
  }

  final String accessToken;
  final String id;
  final String businessName;
  final String ownerName;
  final String phone;
  final VerificationStatus verificationStatus;
  final bool isNewPartner;
  final String? email;

  /// The partner the sign-in already told us about. Enough to route on;
  /// `PartnerRepository` fills in the rest when it can.
  ///
  /// `status` is the one field the sign-in response omits, and `active` is the
  /// only value it can have been: the exchange refuses a suspended account
  /// with a 403 rather than answering with one.
  Partner toPartner() => Partner(
    id: id,
    businessName: businessName,
    ownerName: ownerName,
    phone: phone,
    email: email,
    verificationStatus: verificationStatus,
  );
}
