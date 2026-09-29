import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:washbinapp/core/api/api_exception.dart';
import 'package:washbinapp/core/config/app_config.dart';
import 'package:washbinapp/core/session/access_token_store.dart';
import 'package:washbinapp/features/auth/data/auth_api.dart';
import 'package:washbinapp/features/auth/data/auth_result.dart';
import 'package:washbinapp/features/auth/data/phone_auth_service.dart';
import 'package:washbinapp/features/profile/data/customer_repository.dart';
import 'package:washbinapp/features/profile/domain/customer.dart';

enum SessionStatus {
  /// Startup is still deciding. The splash is on screen.
  initializing,

  /// Nobody is signed in — the phone number is the way in.
  unauthenticated,

  /// The number is verified with Firebase, but no Washbin account exists for it
  /// yet. The server said so with a `PROFILE_REQUIRED` 404; all that is
  /// missing is a name.
  profileIncomplete,

  /// Signed in, with a usable access token.
  authenticated,

  /// Startup could not reach the server. The Firebase session is intact, so
  /// this is retryable and is *not* the same as being signed out.
  failed,
}

/// The one place the app decides who is signed in.
///
/// Screens read this; no screen works out its own answer. Everything that can
/// change the answer — startup, sign-in, profile creation, a rejected token,
/// logout — goes through a method here.
class SessionController extends ChangeNotifier {
  SessionController({
    required AuthApi authApi,
    required PhoneAuthService phoneAuthService,
    required CustomerRepository customerRepository,
    required AccessTokenStore tokenStore,
  }) : _auth = authApi,
       _phoneAuth = phoneAuthService,
       _customers = customerRepository,
       _tokens = tokenStore;

  final AuthApi _auth;
  final PhoneAuthService _phoneAuth;
  final CustomerRepository _customers;
  final AccessTokenStore _tokens;

  /// Run at the very start of [signOut], while the access token is still
  /// valid. Push registration is retired here — once the token is gone there
  /// is no way to tell the server which device to stop sending to.
  Future<void> Function()? beforeSignOut;

  SessionStatus _status = SessionStatus.initializing;
  Customer? _customer;
  String? _message;
  String? _pendingFirebaseIdToken;
  String? _pendingPhoneNumber;

  SessionStatus get status => _status;
  Customer? get customer => _customer;

  /// A message worth putting in front of the customer about the *last* thing
  /// that happened — an expired session, a blocked account, a failed startup.
  String? get message => _message;

  /// The verified Firebase token waiting for a name, in `profileIncomplete`.
  String? get pendingFirebaseIdToken => _pendingFirebaseIdToken;
  String? get pendingPhoneNumber => _pendingPhoneNumber;

  bool get isSignedIn => _status == SessionStatus.authenticated;

  /// Runs once at startup, and again when a failed startup is retried.
  ///
  /// Firebase owns the durable part of the session. If it still has a
  /// phone-verified user, its ID token is traded for a fresh Washbin token —
  /// which is why no token is ever written to disk.
  Future<void> start({bool holdSplash = true}) async {
    _status = SessionStatus.initializing;
    _message = null;
    notifyListeners();

    // Resolved before the floor is awaited so the two overlap: a slow network
    // costs nothing extra, and a fast one still gets the full brand moment.
    final resolution = _restore();
    final floor = holdSplash
        ? Future<void>.delayed(AppConfig.splashMinimumDuration)
        : Future<void>.value();

    final resolved = await resolution;
    await floor;
    _apply(resolved);
  }

  Future<_Resolution> _restore() async {
    String? firebaseIdToken;
    try {
      firebaseIdToken = await _phoneAuth.restoreIdToken();
    } catch (_) {
      // Firebase could not tell us anything. Signing in again is the only
      // path forward, and it is not an error worth showing.
      return const _Resolution(SessionStatus.unauthenticated);
    }

    if (firebaseIdToken == null) {
      return const _Resolution(SessionStatus.unauthenticated);
    }

    try {
      final result = await _auth.signInWithPhone(
        firebaseIdToken: firebaseIdToken,
      );
      return await _authenticate(result);
    } on ApiException catch (error) {
      return _resolutionForFailedExchange(error, firebaseIdToken);
    }
  }

  Future<_Resolution> _resolutionForFailedExchange(
    ApiException error,
    String firebaseIdToken,
  ) async {
    if (error.code == profileRequiredCode) {
      return _Resolution(
        SessionStatus.profileIncomplete,
        firebaseIdToken: firebaseIdToken,
        phoneNumber: _phoneAuth.currentPhoneNumber,
      );
    }

    // A blocked account will be refused every time; keeping the Firebase
    // session would just replay this on the next launch.
    if (error.kind == ApiErrorKind.forbidden) {
      await _signOutOfFirebase();
      return _Resolution(SessionStatus.unauthenticated, message: error.message);
    }

    // The server was unreachable, not unwelcoming. Staying signed in and
    // offering a retry is the difference between a blip and a forced re-OTP.
    if (error.isRetryable) {
      return _Resolution(SessionStatus.failed, message: error.message);
    }

    return _Resolution(SessionStatus.unauthenticated, message: error.message);
  }

  /// Takes a successful sign-in and turns it into an authenticated session,
  /// filling in the full profile when the server can be asked for it.
  Future<_Resolution> _authenticate(AuthResult result) async {
    _tokens.write(result.accessToken);

    try {
      final customer = await _customers.getCustomer(result.id);
      return _Resolution(SessionStatus.authenticated, customer: customer);
    } on ApiException catch (error) {
      if (error.kind == ApiErrorKind.unauthorized) {
        _tokens.clear();
        return _Resolution(
          SessionStatus.unauthenticated,
          message: error.message,
        );
      }

      // Any other failure is not worth blocking on: the sign-in response
      // already carried the name, phone and email the app opens with.
      return _Resolution(
        SessionStatus.authenticated,
        customer: result.toCustomer(),
      );
    }
  }

  void _apply(_Resolution resolution) {
    if (resolution.status != SessionStatus.authenticated) {
      _tokens.clear();
    }

    _status = resolution.status;
    _customer = resolution.customer;
    _message = resolution.message;
    _pendingFirebaseIdToken = resolution.firebaseIdToken;
    _pendingPhoneNumber = resolution.phoneNumber;
    notifyListeners();
  }

  /// Called by the OTP screen once the code checked out and the server handed
  /// back a session.
  Future<void> completeSignIn(AuthResult result) async {
    _apply(await _authenticate(result));
  }

  /// Called by the OTP screen when the verified number has no account yet.
  void requireProfile({
    required String firebaseIdToken,
    required String phoneNumber,
  }) {
    _tokens.clear();
    _status = SessionStatus.profileIncomplete;
    _customer = null;
    _message = null;
    _pendingFirebaseIdToken = firebaseIdToken;
    _pendingPhoneNumber = phoneNumber;
    notifyListeners();
  }

  /// Creates the account the verified number is missing. Throws [ApiException]
  /// so the form can show the failure inline and let the customer correct it.
  Future<void> submitProfile({required String name, String? email}) async {
    final firebaseIdToken = _pendingFirebaseIdToken;

    if (firebaseIdToken == null) {
      throw StateError('submitProfile called outside profileIncomplete');
    }

    final result = await _auth.signInWithPhone(
      firebaseIdToken: firebaseIdToken,
      name: name,
      email: email,
    );
    await completeSignIn(result);
  }

  /// Backs out of profile setup. The OTP that got here has already been spent,
  /// so this returns to the number entry rather than to the code screen.
  Future<void> cancelProfileSetup() => signOut();

  /// Re-reads the profile from the server, e.g. after it was edited.
  Future<void> refreshCustomer() async {
    final id = _customer?.id;

    if (id == null || _status != SessionStatus.authenticated) {
      return;
    }

    try {
      _customer = await _customers.getCustomer(id);
      notifyListeners();
    } on ApiException {
      // Keep showing what we already have rather than emptying the screen.
    }
  }

  /// Invoked by [ApiClient] when a request that carried a token came back 401.
  /// The token is dead, so the session is over.
  void handleUnauthorized() {
    if (_status != SessionStatus.authenticated) {
      return;
    }

    unawaited(
      signOut(message: ApiException.messageForKind(ApiErrorKind.unauthorized)),
    );
  }

  /// Ends the session: anything that needs the token first, then Firebase,
  /// then every trace held in memory.
  Future<void> signOut({String? message}) async {
    try {
      await beforeSignOut?.call();
    } catch (_) {
      // Nothing here may keep a customer signed in.
    }

    await _signOutOfFirebase();

    _tokens.clear();
    _status = SessionStatus.unauthenticated;
    _customer = null;
    _pendingFirebaseIdToken = null;
    _pendingPhoneNumber = null;
    _message = message;
    notifyListeners();
  }

  Future<void> _signOutOfFirebase() async {
    try {
      await _phoneAuth.signOut();
    } catch (_) {
      // Already gone, or Firebase is unreachable. Either way the in-memory
      // session below is what actually keeps the customer signed in.
    }
  }

  /// Clears a message once a screen has shown it, so it does not reappear.
  void acknowledgeMessage() {
    if (_message == null) {
      return;
    }
    _message = null;
    notifyListeners();
  }
}

/// The outcome of a startup or sign-in attempt, applied to the controller in
/// one step so listeners never observe a half-updated session.
@immutable
class _Resolution {
  const _Resolution(
    this.status, {
    this.customer,
    this.message,
    this.firebaseIdToken,
    this.phoneNumber,
  });

  final SessionStatus status;
  final Customer? customer;
  final String? message;
  final String? firebaseIdToken;
  final String? phoneNumber;
}
