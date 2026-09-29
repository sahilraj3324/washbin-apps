import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:washbinpartner/core/api/api_exception.dart';
import 'package:washbinpartner/core/config/app_config.dart';
import 'package:washbinpartner/core/session/access_token_store.dart';
import 'package:washbinpartner/features/auth/data/auth_api.dart';
import 'package:washbinpartner/features/auth/data/auth_result.dart';
import 'package:washbinpartner/features/auth/data/phone_auth_service.dart';
import 'package:washbinpartner/features/partner/data/partner_repository.dart';
import 'package:washbinpartner/features/partner/domain/partner.dart';

/// How far a partner has got towards *having* a usable session.
///
/// What they are then allowed to do with it is a separate question, answered
/// by `Partner.stage` — see `app/app_gate.dart`. Keeping the two apart is what
/// lets a new backend partner state be added without touching sign-in.
enum SessionStatus {
  /// Startup is still deciding. The splash is on screen.
  initializing,

  /// Nobody is signed in — the phone number is the way in.
  unauthenticated,

  /// The number is verified with Firebase, but no Washbin partner exists for it
  /// yet. The server said so with a `PROFILE_REQUIRED` 404; what is missing is
  /// the business itself.
  ///
  /// Distinct from `PartnerStage.profileIncomplete`, which is an account that
  /// exists but has not finished onboarding. This one has no record at all.
  registrationRequired,

  /// Signed in, with a usable access token and a partner record.
  authenticated,

  /// The number is verified, and the server refused to issue a token for it —
  /// a suspended account. Not the same as being signed out: there is nothing
  /// to sign in *to*, so the app says so rather than asking for the number
  /// again and refusing it again.
  blocked,

  /// Startup could not reach the server. The Firebase session is intact, so
  /// this is retryable and is *not* the same as being signed out.
  failed,
}

/// The one place the app decides who is signed in.
///
/// Screens read this; no screen works out its own answer. Everything that can
/// change the answer — startup, sign-in, registration, a rejected token,
/// logout — goes through a method here.
class SessionController extends ChangeNotifier {
  SessionController({
    required AuthApi authApi,
    required PhoneAuthService phoneAuthService,
    required PartnerRepository partnerRepository,
    required AccessTokenStore tokenStore,
  }) : _auth = authApi,
       _phoneAuth = phoneAuthService,
       _partners = partnerRepository,
       _tokens = tokenStore;

  final AuthApi _auth;
  final PhoneAuthService _phoneAuth;
  final PartnerRepository _partners;
  final AccessTokenStore _tokens;

  /// Run at the very start of [signOut], while the access token is still
  /// valid — for anything that must tell the server goodbye before the token
  /// is gone. Unused in Phase 1; push registration will want it.
  Future<void> Function()? beforeSignOut;

  SessionStatus _status = SessionStatus.initializing;
  Partner? _partner;
  String? _message;
  String? _pendingFirebaseIdToken;
  String? _pendingPhoneNumber;

  SessionStatus get status => _status;
  Partner? get partner => _partner;

  /// A message worth putting in front of the partner about the *last* thing
  /// that happened — an expired session, a suspended account, a failed
  /// startup.
  String? get message => _message;

  /// The verified Firebase token waiting for business details, in
  /// `registrationRequired`.
  String? get pendingFirebaseIdToken => _pendingFirebaseIdToken;
  String? get pendingPhoneNumber => _pendingPhoneNumber;

  bool get isSignedIn => _status == SessionStatus.authenticated;

  /// Where the signed-in partner stands with Washbin, or null when there is no
  /// partner record to ask — which is every status but `authenticated`.
  PartnerStage? get stage => _partner?.stage;

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

  _Resolution _resolutionForFailedExchange(
    ApiException error,
    String firebaseIdToken,
  ) {
    if (error.code == profileRequiredCode) {
      return _Resolution(
        SessionStatus.registrationRequired,
        firebaseIdToken: firebaseIdToken,
        phoneNumber: _phoneAuth.currentPhoneNumber,
      );
    }

    // A suspended account is refused a token every time. The Firebase session
    // is kept: the partner is who they say they are, and telling them why the
    // app is closed beats bouncing them back to a number they cannot use.
    if (error.kind == ApiErrorKind.forbidden) {
      return _Resolution(SessionStatus.blocked, message: error.message);
    }

    // The server was unreachable, not unwelcoming. Staying signed in and
    // offering a retry is the difference between a blip and a forced re-OTP.
    if (error.isRetryable) {
      return _Resolution(SessionStatus.failed, message: error.message);
    }

    return _Resolution(SessionStatus.unauthenticated, message: error.message);
  }

  /// Takes a successful sign-in and turns it into an authenticated session,
  /// filling in the full partner record when the server can be asked for it.
  Future<_Resolution> _authenticate(AuthResult result) async {
    _tokens.write(result.accessToken);

    try {
      final partner = await _partners.getMe();
      return _Resolution(SessionStatus.authenticated, partner: partner);
    } on ApiException catch (error) {
      if (error.kind == ApiErrorKind.unauthorized) {
        _tokens.clear();
        return _Resolution(
          SessionStatus.unauthenticated,
          message: error.message,
        );
      }

      // Any other failure is not worth blocking on: the sign-in response
      // already carried the business name, phone and verification status the
      // app routes on. `status` is the one field it omits, and a suspended
      // partner never got this far — the exchange itself would have 403'd.
      return _Resolution(
        SessionStatus.authenticated,
        partner: result.toPartner(),
      );
    }
  }

  void _apply(_Resolution resolution) {
    if (resolution.status != SessionStatus.authenticated) {
      _tokens.clear();
    }

    _status = resolution.status;
    _partner = resolution.partner;
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

  /// Called by the OTP screen when the verified number has no partner yet.
  void requireProfile({
    required String firebaseIdToken,
    required String phoneNumber,
  }) {
    _tokens.clear();
    _status = SessionStatus.registrationRequired;
    _partner = null;
    _message = null;
    _pendingFirebaseIdToken = firebaseIdToken;
    _pendingPhoneNumber = phoneNumber;
    notifyListeners();
  }

  /// Called by the OTP screen when the server refused the verified number
  /// outright — a suspended account.
  void reportBlocked(String message) {
    _tokens.clear();
    _status = SessionStatus.blocked;
    _partner = null;
    _message = message;
    _pendingFirebaseIdToken = null;
    _pendingPhoneNumber = null;
    notifyListeners();
  }

  /// Creates the partner the verified number is missing. Throws
  /// [ApiException] so the form can show the failure inline and let the
  /// partner correct it.
  Future<void> submitProfile({
    required String businessName,
    required String ownerName,
    String? email,
  }) async {
    final firebaseIdToken = _pendingFirebaseIdToken;

    if (firebaseIdToken == null) {
      throw StateError('submitProfile called outside registrationRequired');
    }

    final result = await _auth.signInWithPhone(
      firebaseIdToken: firebaseIdToken,
      businessName: businessName,
      ownerName: ownerName,
      email: email,
    );
    await completeSignIn(result);
  }

  /// Backs out of registration. The OTP that got here has already been spent,
  /// so this returns to the number entry rather than to the code screen.
  Future<void> cancelProfileSetup() => signOut();

  /// Re-reads the partner from the server.
  ///
  /// This is how a waiting partner finds out they have been approved, so
  /// unlike most refreshes it reports failure: the status screen is the only
  /// thing they can act on, and silently doing nothing would read as a broken
  /// button. Throws [ApiException].
  Future<void> refreshPartner() async {
    if (_status != SessionStatus.authenticated) {
      return;
    }

    final partner = await _partners.getMe();

    // A 401 mid-refresh ends the session from under us; do not resurrect it.
    if (_status != SessionStatus.authenticated) {
      return;
    }

    _partner = partner;
    notifyListeners();
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
      // Nothing here may keep a partner signed in.
    }

    await _signOutOfFirebase();

    _tokens.clear();
    _status = SessionStatus.unauthenticated;
    _partner = null;
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
      // session below is what actually keeps the partner signed in.
    }
  }

  /// Replaces the signed-in partner with one the app already has.
  ///
  /// For a write whose response *is* the new partner — a profile edit, a
  /// submit for review — so the change reaches the router immediately instead
  /// of after a round trip. Ignored unless a session is actually open, so a
  /// response landing after a sign-out cannot resurrect one.
  void applyPartner(Partner partner) {
    if (_status != SessionStatus.authenticated) {
      return;
    }

    _partner = partner;
    notifyListeners();
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
    this.partner,
    this.message,
    this.firebaseIdToken,
    this.phoneNumber,
  });

  final SessionStatus status;
  final Partner? partner;
  final String? message;
  final String? firebaseIdToken;
  final String? phoneNumber;
}
