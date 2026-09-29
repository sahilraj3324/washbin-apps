import 'package:washbinapp/core/api/api_client.dart';
import 'package:washbinapp/features/auth/data/auth_result.dart';

/// The API's reason code for "this number is verified but has no account yet".
const profileRequiredCode = 'PROFILE_REQUIRED';

class AuthApi {
  AuthApi({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// Trades a Firebase phone-auth ID token for a Washbin access token.
  ///
  /// Signing in and signing up are the same call: the server decides which one
  /// happened. Omitting [name] on a number with no account raises an
  /// [ApiException] whose `code` is [profileRequiredCode] — collect a name and
  /// call again with the same token.
  Future<AuthResult> signInWithPhone({
    required String firebaseIdToken,
    String? name,
    String? email,
  }) async {
    final trimmedEmail = email?.trim() ?? '';

    final json = await _apiClient.postJson('/customer-auth/phone', {
      'firebaseIdToken': firebaseIdToken,
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      if (trimmedEmail.isNotEmpty) 'email': trimmedEmail,
    });

    return AuthResult.fromJson(json);
  }
}
