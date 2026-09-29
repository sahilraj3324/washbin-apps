import 'package:firebase_auth/firebase_auth.dart';
import 'package:washbinapp/features/auth/data/phone_auth_service.dart';

/// Stands in for Firebase: the OTP is "sent" and any six digits verify.
///
/// Every method that would otherwise reach `FirebaseAuth.instance` is
/// overridden, because that throws in a test with no initialised Firebase app.
class FakePhoneAuthService extends PhoneAuthService {
  FakePhoneAuthService({this.storedIdToken, this.phoneNumber});

  /// Non-null to simulate a customer who is already signed in.
  String? storedIdToken;

  /// The verified number Firebase would report for that customer.
  final String? phoneNumber;

  final sentTo = <String>[];
  var signOutCount = 0;

  /// Set to make [restoreIdToken] throw, as it would if Firebase itself were
  /// unavailable at startup.
  bool failRestore = false;

  @override
  String? get currentPhoneNumber => phoneNumber;

  @override
  Future<String?> restoreIdToken() async {
    if (failRestore) {
      throw Exception('firebase unavailable');
    }
    return storedIdToken;
  }

  @override
  Future<OtpDispatch> sendOtp({
    required String phoneNumber,
    int? resendToken,
    void Function(PhoneAuthCredential credential)? onAutoResolved,
    void Function(PhoneAuthException error)? onError,
  }) async {
    sentTo.add(phoneNumber);
    return const OtpCodeSent(verificationId: 'test-verification-id');
  }

  @override
  Future<String> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async => 'test-id-token';

  @override
  Future<void> signOut() async {
    signOutCount++;
    storedIdToken = null;
  }
}
