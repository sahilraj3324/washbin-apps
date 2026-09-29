import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

/// A failure raised while sending or checking an OTP, already carrying a
/// message that is safe to put in front of a partner.
class PhoneAuthException implements Exception {
  const PhoneAuthException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// The outcome of asking Firebase to send an OTP.
sealed class OtpDispatch {
  const OtpDispatch();
}

/// The SMS is on its way; [verificationId] pairs with the code the partner
/// types. [resendToken] lets a later resend skip Firebase's rate limiting.
final class OtpCodeSent extends OtpDispatch {
  const OtpCodeSent({required this.verificationId, this.resendToken});

  final String verificationId;
  final int? resendToken;
}

/// Android resolved the number without the partner typing anything (instant
/// verification, or SMS auto-retrieval). There is no code to ask for.
final class OtpAutoResolved extends OtpDispatch {
  const OtpAutoResolved(this.credential);

  final PhoneAuthCredential credential;
}

class PhoneAuthService {
  PhoneAuthService({FirebaseAuth? auth}) : _authOverride = auth;

  final FirebaseAuth? _authOverride;

  /// Resolved on use, not in the constructor, so building the service does not
  /// itself require Firebase to be initialised.
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  /// How long Firebase waits for Android's SMS auto-retrieval before the
  /// partner is expected to type the code themselves.
  static const autoRetrievalTimeout = Duration(seconds: 60);

  User? get currentUser => _auth.currentUser;

  /// The verified number of the signed-in partner, when there is one.
  /// Guarded because reading it before Firebase is initialised throws, and
  /// callers only want it for display.
  String? get currentPhoneNumber {
    try {
      return _auth.currentUser?.phoneNumber;
    } catch (_) {
      return null;
    }
  }

  /// Asks Firebase to text an OTP to [phoneNumber], which must be E.164
  /// (`+919876543210`).
  ///
  /// The returned future settles on the first thing Firebase reports. Android
  /// can also resolve the number *after* that — it reads the arriving SMS
  /// itself — so pass [onAutoResolved] to finish the sign-in when it does, and
  /// [onError] for a failure that lands equally late.
  Future<OtpDispatch> sendOtp({
    required String phoneNumber,
    int? resendToken,
    void Function(PhoneAuthCredential credential)? onAutoResolved,
    void Function(PhoneAuthException error)? onError,
  }) {
    final dispatch = Completer<OtpDispatch>();

    _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      forceResendingToken: resendToken,
      timeout: autoRetrievalTimeout,
      verificationCompleted: (credential) {
        if (dispatch.isCompleted) {
          onAutoResolved?.call(credential);
        } else {
          dispatch.complete(OtpAutoResolved(credential));
        }
      },
      codeSent: (verificationId, token) {
        if (!dispatch.isCompleted) {
          dispatch.complete(
            OtpCodeSent(verificationId: verificationId, resendToken: token),
          );
        }
      },
      verificationFailed: (error) {
        final failure = _translate(error);
        if (dispatch.isCompleted) {
          onError?.call(failure);
        } else {
          dispatch.completeError(failure);
        }
      },
      // Nothing to do: the partner types the code, which is already the
      // screen's default state.
      codeAutoRetrievalTimeout: (_) {},
    );

    return dispatch.future;
  }

  /// Verifies the code the partner typed and returns a Firebase ID token
  /// proving the number is theirs. The token is what the Washbin API checks.
  Future<String> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) {
    return signInWithCredential(
      PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      ),
    );
  }

  /// Completes sign-in from a credential Android resolved on its own.
  Future<String> signInWithCredential(PhoneAuthCredential credential) async {
    try {
      final result = await _auth.signInWithCredential(credential);
      return await _idTokenOf(result.user);
    } on FirebaseAuthException catch (error) {
      throw _translate(error);
    }
  }

  /// Returns a fresh ID token for the already signed-in partner, or null if
  /// there is no phone-verified Firebase session to restore.
  Future<String?> restoreIdToken() async {
    final user = _auth.currentUser;

    if (user == null || (user.phoneNumber ?? '').isEmpty) {
      return null;
    }

    try {
      return await user.getIdToken(true);
    } on FirebaseAuthException {
      // The session was revoked or the account deleted; sign in again.
      return null;
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<String> _idTokenOf(User? user) async {
    final token = user == null ? null : await user.getIdToken();

    if (token == null || token.isEmpty) {
      throw const PhoneAuthException(
        'Could not confirm your number. Please try again.',
      );
    }
    return token;
  }

  PhoneAuthException _translate(FirebaseAuthException error) {
    final message = switch (error.code) {
      'invalid-phone-number' =>
        'That mobile number does not look right. Check it and try again.',
      'invalid-verification-code' =>
        'That code is not correct. Please check the SMS and retype it.',
      'invalid-verification-id' || 'session-expired' =>
        'The code has expired. Tap resend to get a new one.',
      'too-many-requests' || 'quota-exceeded' =>
        'Too many attempts. Please wait a few minutes and try again.',
      'network-request-failed' =>
        'No internet connection. Check your network and try again.',
      'operation-not-allowed' =>
        'Phone sign-in is not enabled for this app yet.',
      'user-disabled' => 'This account has been disabled.',
      _ => error.message ?? 'Could not verify your number. Please try again.',
    };

    return PhoneAuthException(message, code: error.code);
  }
}
