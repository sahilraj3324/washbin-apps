import 'package:flutter_test/flutter_test.dart';
import 'package:washbinapp/app/app_services.dart';
import 'package:washbinapp/core/session/session_controller.dart';

import '../support/fake_backend.dart';
import '../support/fake_messaging_service.dart';
import '../support/fake_phone_auth_service.dart';

/// Builds the real object graph over a scripted backend and a Firebase
/// stand-in, so the controller under test is wired exactly as it is in the app.
({AppServices services, SessionController session}) _build(
  FakeBackend backend,
  FakePhoneAuthService phoneAuth,
) {
  final services = AppServices(
    httpClient: backend.client,
    phoneAuthService: phoneAuth,
    baseUrl: 'https://api.test',
    // No poll timer firing under the test; polling has its own test.
    // Real FCM would reach Firebase, which no test has initialised.
    messagingService: FakeMessagingService(),
    trackingPollInterval: null,
  );
  return (services: services, session: services.session);
}

void main() {
  group('startup', () {
    test('no Firebase user means nobody is signed in', () async {
      final backend = FakeBackend();
      final built = _build(backend, FakePhoneAuthService());

      await built.session.start(holdSplash: false);

      expect(built.session.status, SessionStatus.unauthenticated);
      expect(built.services.tokens.hasToken, isFalse);
      expect(backend.signInCalls, isEmpty);
    });

    test('a stored Firebase session is traded for a Washbin one', () async {
      final backend = FakeBackend()..requiresProfile = false;
      final built = _build(
        backend,
        FakePhoneAuthService(storedIdToken: 'stored-id-token'),
      );

      await built.session.start(holdSplash: false);

      expect(built.session.status, SessionStatus.authenticated);
      expect(built.session.customer?.name, 'Rahul Sharma');
      expect(built.services.tokens.read(), 'washbin-token');
      // The exchange happened without an SMS.
      expect(backend.signInCalls.single['firebaseIdToken'], 'stored-id-token');
    });

    test('the profile read carries the freshly issued token', () async {
      final backend = FakeBackend()..requiresProfile = false;
      final built = _build(
        backend,
        FakePhoneAuthService(storedIdToken: 'stored-id-token'),
      );

      await built.session.start(holdSplash: false);

      expect(
        backend.authorizationHeaders['/customers/customer-1'],
        'Bearer washbin-token',
      );
      // The exchange itself is how a token is obtained, so it has none yet.
      expect(backend.authorizationHeaders['/customer-auth/phone'], isNull);
    });

    test('a verified number with no account waits for a name', () async {
      final backend = FakeBackend();
      final built = _build(
        backend,
        FakePhoneAuthService(
          storedIdToken: 'stored-id-token',
          phoneNumber: '+919876543210',
        ),
      );

      await built.session.start(holdSplash: false);

      expect(built.session.status, SessionStatus.profileIncomplete);
      expect(built.session.pendingFirebaseIdToken, 'stored-id-token');
      expect(built.session.pendingPhoneNumber, '+919876543210');
      expect(built.services.tokens.hasToken, isFalse);
    });

    test('an unreachable server is retryable, not a sign-out', () async {
      // The difference that matters: a network blip must not cost the
      // customer their session and force a new SMS.
      final backend = FakeBackend()
        ..requiresProfile = false
        ..offline = true;
      final phoneAuth = FakePhoneAuthService(storedIdToken: 'stored-id-token');
      final built = _build(backend, phoneAuth);

      await built.session.start(holdSplash: false);

      expect(built.session.status, SessionStatus.failed);
      expect(built.session.message, contains('internet'));
      expect(phoneAuth.signOutCount, 0);

      backend.offline = false;
      await built.session.start(holdSplash: false);

      expect(built.session.status, SessionStatus.authenticated);
    });

    test('a blocked account is signed out of Firebase too', () async {
      final backend = FakeBackend()..blocked = true;
      final phoneAuth = FakePhoneAuthService(storedIdToken: 'stored-id-token');
      final built = _build(backend, phoneAuth);

      await built.session.start(holdSplash: false);

      expect(built.session.status, SessionStatus.unauthenticated);
      expect(built.session.message, 'This account has been blocked');
      expect(phoneAuth.signOutCount, 1);
    });

    test('Firebase being unavailable falls back to signing in again', () async {
      final built = _build(
        FakeBackend(),
        FakePhoneAuthService(storedIdToken: 'x')..failRestore = true,
      );

      await built.session.start(holdSplash: false);

      expect(built.session.status, SessionStatus.unauthenticated);
    });

    test('a failed profile read still opens the app', () async {
      // Sign-in already returned the name, phone and email; losing the richer
      // read is not a reason to keep the customer out.
      final backend = FakeBackend()
        ..requiresProfile = false
        ..profileReadFails = true;
      final built = _build(
        backend,
        FakePhoneAuthService(storedIdToken: 'stored-id-token'),
      );

      await built.session.start(holdSplash: false);

      expect(built.session.status, SessionStatus.authenticated);
      expect(built.session.customer?.name, 'Rahul Sharma');
    });
  });

  group('profile setup', () {
    test('submitting a name completes the sign-in', () async {
      final backend = FakeBackend();
      final built = _build(
        backend,
        FakePhoneAuthService(
          storedIdToken: 'stored-id-token',
          phoneNumber: '+919876543210',
        ),
      );
      await built.session.start(holdSplash: false);
      expect(built.session.status, SessionStatus.profileIncomplete);

      await built.session.submitProfile(name: 'Asha Menon');

      expect(built.session.status, SessionStatus.authenticated);
      expect(built.session.customer?.name, 'Asha Menon');
      expect(built.services.tokens.read(), 'washbin-token');
      // The same verified token is reused; no second SMS.
      expect(backend.signInCalls.last['firebaseIdToken'], 'stored-id-token');
      expect(backend.signInCalls.last['name'], 'Asha Menon');
    });

    test('backing out returns to the start, signed out', () async {
      final phoneAuth = FakePhoneAuthService(
        storedIdToken: 'stored-id-token',
        phoneNumber: '+919876543210',
      );
      final built = _build(FakeBackend(), phoneAuth);
      await built.session.start(holdSplash: false);

      await built.session.cancelProfileSetup();

      expect(built.session.status, SessionStatus.unauthenticated);
      expect(built.session.pendingFirebaseIdToken, isNull);
      expect(phoneAuth.signOutCount, 1);
    });
  });

  group('ending a session', () {
    test('signing out clears the token, the profile and Firebase', () async {
      final phoneAuth = FakePhoneAuthService(storedIdToken: 'stored-id-token');
      final built = _build(FakeBackend()..requiresProfile = false, phoneAuth);
      await built.session.start(holdSplash: false);
      expect(built.session.isSignedIn, isTrue);

      await built.session.signOut();

      expect(built.session.status, SessionStatus.unauthenticated);
      expect(built.session.customer, isNull);
      expect(built.services.tokens.hasToken, isFalse);
      expect(phoneAuth.signOutCount, 1);
    });

    test('a rejected token ends the session with an explanation', () async {
      final backend = FakeBackend()..requiresProfile = false;
      final built = _build(
        backend,
        FakePhoneAuthService(storedIdToken: 'stored-id-token'),
      );
      await built.session.start(holdSplash: false);

      built.session.handleUnauthorized();
      // signOut is awaited internally; let it settle.
      await Future<void>.delayed(Duration.zero);

      expect(built.session.status, SessionStatus.unauthenticated);
      expect(built.session.message, contains('expired'));
      expect(built.services.tokens.hasToken, isFalse);
    });

    test('a 401 while already signed out changes nothing', () async {
      final built = _build(FakeBackend(), FakePhoneAuthService());
      await built.session.start(holdSplash: false);

      built.session.handleUnauthorized();
      await Future<void>.delayed(Duration.zero);

      expect(built.session.status, SessionStatus.unauthenticated);
      expect(built.session.message, isNull);
    });
  });

  test('listeners see one notification per resolved startup', () async {
    final built = _build(
      FakeBackend()..requiresProfile = false,
      FakePhoneAuthService(storedIdToken: 'stored-id-token'),
    );
    final seen = <SessionStatus>[];
    built.session.addListener(() => seen.add(built.session.status));

    await built.session.start(holdSplash: false);

    // Initializing, then the outcome — never a half-applied state between.
    expect(seen, [SessionStatus.initializing, SessionStatus.authenticated]);
  });
}
