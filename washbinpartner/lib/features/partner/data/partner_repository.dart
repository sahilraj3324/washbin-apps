import 'package:washbinpartner/core/api/api_client.dart';
import 'package:washbinpartner/features/partner/domain/partner.dart';

/// What `POST /partners/me/submit-for-review` answers with.
class SubmitForReviewResult {
  const SubmitForReviewResult({required this.partner, required this.submitted});

  factory SubmitForReviewResult.fromJson(Map<String, dynamic> json) {
    return SubmitForReviewResult(
      partner: Partner.fromJson(json['partner'] as Map<String, dynamic>),
      submitted: json['submitted'] as bool? ?? false,
    );
  }

  final Partner partner;

  /// False when the partner was already under review — the request changed
  /// nothing, which is not a failure.
  final bool submitted;
}

/// Reads and writes the signed-in partner's own record.
///
/// Everything here goes through `/partners/me`, which takes the partner id
/// from the bearer token. There is deliberately no path that names a partner
/// id: `PATCH /partners/:id` is unguarded on the server and accepts
/// `authUserId` and `phone`, so using it from the app would be handing the
/// client the keys to any account.
class PartnerRepository {
  PartnerRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<Partner> getMe() async {
    final json = await _api.getJson('/partners/me');
    return Partner.fromJson(json);
  }

  /// Updates the fields a partner may change about themselves.
  ///
  /// Only non-null arguments are sent, so a form that edits one field does not
  /// blank the rest. Clearing an optional field is not expressible and not
  /// offered: the server treats absent as "leave alone".
  Future<Partner> updateMe({
    String? businessName,
    String? ownerName,
    String? email,
    String? profileImage,
    Gender? gender,
    int? experienceYears,
    PartnerAddress? address,
    EmergencyContact? emergencyContact,
  }) async {
    final json = await _api.patchJson('/partners/me', {
      if (businessName != null) 'businessName': businessName.trim(),
      if (ownerName != null) 'ownerName': ownerName.trim(),
      if (email != null) 'email': email.trim(),
      'profileImage': ?profileImage,
      'gender': ?gender?.wireValue,
      'experienceYears': ?experienceYears,
      'address': ?address?.toJson(),
      'emergencyContact': ?emergencyContact?.toJson(),
    });

    return Partner.fromJson(json);
  }

  /// Puts the partner forward for verification.
  ///
  /// Throws [ApiException] with the server's own message when the profile is
  /// incomplete or no service has been chosen — the app checks both first, so
  /// reaching that is a sign the two rules have drifted apart.
  Future<SubmitForReviewResult> submitForReview() async {
    final json = await _api.postJson('/partners/me/submit-for-review', const {});
    return SubmitForReviewResult.fromJson(json);
  }
}
