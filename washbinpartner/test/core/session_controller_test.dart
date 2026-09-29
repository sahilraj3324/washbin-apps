import 'package:flutter_test/flutter_test.dart';
import 'package:washbinpartner/app/app_services.dart';
import 'package:washbinpartner/core/api/api_exception.dart';
import 'package:washbinpartner/core/session/session_controller.dart';
import 'package:washbinpartner/features/partner/domain/partner.dart';

import '../support/fake_backend.dart';
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
      final backend = FakeBackend()
        ..requiresProfile = false
        ..verificationStatus = 'verified';
      final built = _build(
        backend,
        FakePhoneAuthService(storedIdToken: 'stored-id-token'),
      );

      await built.session.start(holdSplash: false);

      expect(built.session.status, SessionStatus.authenticated);
      expect(built.session.partner?.businessName, 'Sharma Home Services');
      expect(built.services.tokens.read(), 'washbin-partner-token');
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
        backend.authorizationHeaders['/partners/me'],
        'Bearer washbin-partner-token',
      );
    });

    test('a verified number with no partner needs registering', () async {
      final built = _build(
        FakeBackend(),
        FakePhoneAuthService(
          storedIdToken: 'stored-id-token',
          phoneNumber: '+919876543210',
        ),
      );

      await built.session.start(holdSplash: false);

      expect(built.session.status, SessionStatus.registrationRequired);
      expect(built.session.pendingFirebaseIdToken, 'stored-id-token');
      expect(built.session.pendingPhoneNumber, '+919876543210');
      // No token is held for a partner that does not exist yet.
      expect(built.services.tokens.hasToken, isFalse);
    });

    test('an unreachable server is retryable, not a sign-out', () async {
      final backend = FakeBackend()
        ..requiresProfile = false
        ..offline = true;
      final phoneAuth = FakePhoneAuthService(storedIdToken: 'stored-id-token');
      final built = _build(backend, phoneAuth);

      await built.session.start(holdSplash: false);

      expect(built.session.status, SessionStatus.failed);
      // The Firebase session survives, so the retry costs no SMS.
      expect(phoneAuth.signOutCount, 0);
      expect(phoneAuth.storedIdToken, 'stored-id-token');

      backend.offline = false;
      await built.session.start(holdSplash: false);

      expect(built.session.status, SessionStatus.authenticated);
    });

    test('a suspended partner is blocked, not bounced to the number', () async {
      final backend = FakeBackend()..suspended = true;
      final phoneAuth = FakePhoneAuthService(storedIdToken: 'stored-id-token');
      final built = _build(backend, phoneAuth);

      await built.session.start(holdSplash: false);

      expect(built.session.status, SessionStatus.blocked);
      expect(built.session.message, 'This partner account has been suspended');
      // Kept signed in with Firebase: re-checking must not need a new SMS.
      expect(phoneAuth.signOutCount, 0);
      expect(built.services.tokens.hasToken, isFalse);
    });

    test('a failed profile read falls back to the sign-in response', () async {
      final backend = FakeBackend()
        ..requiresProfile = false
        ..verificationStatus = 'verified'
        ..profileReadFails = true;
      final built = _build(
        backend,
        FakePhoneAuthService(storedIdToken: 'stored-id-token'),
      );

      await built.session.start(holdSplash: false);

      // Still usable: the exchange already carried everything the gate routes
      // on, so a flaky profile read does not cost the partner their session.
      expect(built.session.status, SessionStatus.authenticated);
      expect(built.session.stage, PartnerStage.approved);
      expect(built.session.partner?.businessName, 'Sharma Home Services');
    });

    test('a rejected token at startup signs the partner out', () async {
      final backend = FakeBackend()
        ..requiresProfile = false
        ..profileReadUnauthorized = true;
      final built = _build(
        backend,
        FakePhoneAuthService(storedIdToken: 'stored-id-token'),
      );

      await built.session.start(holdSplash: false);

      expect(built.session.status, SessionStatus.unauthenticated);
      expect(built.services.tokens.hasToken, isFalse);
    });

    test('Firebase being unavailable is not shown as an error', () async {
      final phoneAuth = FakePhoneAuthService(storedIdToken: 'stored-id-token')
        ..failRestore = true;
      final built = _build(FakeBackend(), phoneAuth);

      await built.session.start(holdSplash: false);

      expect(built.session.status, SessionStatus.unauthenticated);
      expect(built.session.message, isNull);
    });
  });

  group('partner stage', () {
    Future<SessionController> signedInWith({
      required String verificationStatus,
      String partnerStatus = 'active',
    }) async {
      final backend = FakeBackend()
        ..requiresProfile = false
        ..verificationStatus = verificationStatus
        ..partnerStatus = partnerStatus;
      final built = _build(
        backend,
        FakePhoneAuthService(storedIdToken: 'stored-id-token'),
      );

      await built.session.start(holdSplash: false);
      return built.session;
    }

    test('pending means onboarding is unfinished, not that Washbin is busy',
        () async {
      // The distinction Phase 2 introduced: `pending` is a partner who has not
      // asked for a review yet, and the app must give them something to do
      // rather than a waiting screen.
      expect(
        (await signedInWith(verificationStatus: 'pending')).stage,
        PartnerStage.profileIncomplete,
      );
    });

    test('submitted means waiting on Washbin', () async {
      expect(
        (await signedInWith(verificationStatus: 'submitted')).stage,
        PartnerStage.pendingApproval,
      );
    });

    test('verified opens the app', () async {
      final session = await signedInWith(verificationStatus: 'verified');

      expect(session.stage, PartnerStage.approved);
      expect(session.stage?.opensApp, isTrue);
    });

    test('rejected does not', () async {
      final session = await signedInWith(verificationStatus: 'rejected');

      expect(session.stage, PartnerStage.rejected);
      expect(session.stage?.opensApp, isFalse);
    });

    test('suspension outranks a completed verification', () async {
      // Only reachable when the suspension lands mid-session — a fresh
      // sign-in would have been refused outright.
      final session = await signedInWith(
        verificationStatus: 'verified',
        partnerStatus: 'suspended',
      );

      expect(session.stage, PartnerStage.suspended);
    });

    test('an inactive partner still has the app', () async {
      final session = await signedInWith(
        verificationStatus: 'verified',
        partnerStatus: 'inactive',
      );

      expect(session.stage, PartnerStage.approved);
    });
  });

  group('refreshPartner', () {
    test('picks up an approval granted since sign-in', () async {
      final backend = FakeBackend()..requiresProfile = false;
      final built = _build(
        backend,
        FakePhoneAuthService(storedIdToken: 'stored-id-token'),
      );
      await built.session.start(holdSplash: false);

      expect(built.session.stage, PartnerStage.profileIncomplete);

      backend.verificationStatus = 'verified';
      await built.session.refreshPartner();

      expect(built.session.stage, PartnerStage.approved);
    });

    test('reports a failure rather than silently doing nothing', () async {
      final backend = FakeBackend()..requiresProfile = false;
      final built = _build(
        backend,
        FakePhoneAuthService(storedIdToken: 'stored-id-token'),
      );
      await built.session.start(holdSplash: false);

      backend.profileReadFails = true;

      await expectLater(
        built.session.refreshPartner(),
        throwsA(isA<ApiException>()),
      );
      // The partner already on screen is kept.
      expect(built.session.status, SessionStatus.authenticated);
    });

    test('a rejected token ends the session', () async {
      final backend = FakeBackend()..requiresProfile = false;
      final built = _build(
        backend,
        FakePhoneAuthService(storedIdToken: 'stored-id-token'),
      );
      await built.session.start(holdSplash: false);

      backend.profileReadUnauthorized = true;

      await expectLater(
        built.session.refreshPartner(),
        throwsA(isA<ApiException>()),
      );
      // The client reports the 401 to the session, which signs out without
      // being awaited by the call that triggered it.
      await Future<void>.delayed(Duration.zero);

      expect(built.session.status, SessionStatus.unauthenticated);
      expect(built.services.tokens.hasToken, isFalse);
    });
  });

  group('sign out', () {
    test('drops the token, the partner and the Firebase session', () async {
      final backend = FakeBackend()..requiresProfile = false;
      final phoneAuth = FakePhoneAuthService(storedIdToken: 'stored-id-token');
      final built = _build(backend, phoneAuth);
      await built.session.start(holdSplash: false);

      await built.session.signOut();

      expect(built.session.status, SessionStatus.unauthenticated);
      expect(built.session.partner, isNull);
      expect(built.services.tokens.hasToken, isFalse);
      expect(phoneAuth.signOutCount, 1);
    });

    test('a 401 on a token-carrying call ends the session once', () async {
      final backend = FakeBackend()..requiresProfile = false;
      final built = _build(
        backend,
        FakePhoneAuthService(storedIdToken: 'stored-id-token'),
      );
      await built.session.start(holdSplash: false);

      built.session
        ..handleUnauthorized()
        ..handleUnauthorized();
      // signOut is asynchronous; let it finish.
      await Future<void>.delayed(Duration.zero);

      expect(built.session.status, SessionStatus.unauthenticated);
      expect(
        built.session.message,
        ApiException.messageForKind(ApiErrorKind.unauthorized),
      );
    });
  });

  group('registration', () {
    test('sends the business details with the same verified token', () async {
      final backend = FakeBackend();
      final built = _build(
        backend,
        FakePhoneAuthService(
          storedIdToken: 'stored-id-token',
          phoneNumber: '+919876543210',
        ),
      );
      await built.session.start(holdSplash: false);

      await built.session.submitProfile(
        businessName: 'Verma Cleaning Co',
        ownerName: 'Anita Verma',
        email: 'anita@example.com',
      );

      expect(backend.signInCalls.last['firebaseIdToken'], 'stored-id-token');
      expect(backend.signInCalls.last['businessName'], 'Verma Cleaning Co');
      expect(backend.signInCalls.last['ownerName'], 'Anita Verma');
      expect(backend.signInCalls.last['email'], 'anita@example.com');

      // A new partner is authenticated, with onboarding still to do — nobody
      // is reviewing them until they ask.
      expect(built.session.status, SessionStatus.authenticated);
      expect(built.session.stage, PartnerStage.profileIncomplete);
    });

    test('cannot be submitted outside registrationRequired', () async {
      final built = _build(FakeBackend(), FakePhoneAuthService());
      await built.session.start(holdSplash: false);

      expect(
        () => built.session.submitProfile(
          businessName: 'Verma Cleaning Co',
          ownerName: 'Anita Verma',
        ),
        throwsStateError,
      );
    });
  });
}
