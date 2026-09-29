import 'package:washbinpartner/core/api/api_client.dart';
import 'package:washbinpartner/features/auth/data/auth_result.dart';

/// The API's reason code for "this number is verified but has no account yet".
const profileRequiredCode = 'PROFILE_REQUIRED';

class AuthApi {
  AuthApi({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// Trades a Firebase phone-auth ID token for a Washbin partner access token.
  ///
  /// Signing in and registering are the same call: the server decides which
  /// one happened. Omitting the business details on a number with no account
  /// raises an [ApiException] whose `code` is [profileRequiredCode] — collect
  /// them and call again with the same token.
  Future<AuthResult> signInWithPhone({
    required String firebaseIdToken,
    String? businessName,
    String? ownerName,
    String? email,
  }) async {
    final business = businessName?.trim() ?? '';
    final owner = ownerName?.trim() ?? '';
    final trimmedEmail = email?.trim() ?? '';

    final json = await _apiClient.postJson('/partner-auth/phone', {
      'firebaseIdToken': firebaseIdToken,
      if (business.isNotEmpty) 'businessName': business,
      if (owner.isNotEmpty) 'ownerName': owner,
      if (trimmedEmail.isNotEmpty) 'email': trimmedEmail,
    });

    return AuthResult.fromJson(json);
  }
}
