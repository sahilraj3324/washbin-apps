import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washbinapp/app/app_services.dart';
import 'package:washbinapp/app/washbin_app.dart';
import 'package:washbinapp/core/session/session_controller.dart';

import '../support/fake_backend.dart';
import '../support/fake_messaging_service.dart';
import '../support/fake_phone_auth_service.dart';

/// Boots the real app over a scripted backend and a Firebase stand-in.
AppServices _services(FakeBackend backend, FakePhoneAuthService phoneAuth) {
  return AppServices(
    httpClient: backend.client,
    phoneAuthService: phoneAuth,
    baseUrl: 'https://api.test',
    // No poll timer firing under the test; polling has its own test.
    // Real FCM would reach Firebase, which no test has initialised.
    messagingService: FakeMessagingService(),
    trackingPollInterval: null,
  );
}

/// Lets the splash's minimum duration elapse and the session resolve.
Future<void> _passSplash(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 3200));
  await tester.pumpAndSettle();
}

/// Signing out cancels three push subscriptions and drops the Firebase token
/// before clearing the session. No frames are scheduled while that runs, so
/// `pumpAndSettle` finds the tree still and returns before it has finished.
Future<void> _settleSignOut(WidgetTester tester) async {
  for (var frame = 0; frame < 12; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('startup shows the splash before anything else', (tester) async {
    await tester.pumpWidget(
      WashbinApp(services: _services(FakeBackend(), FakePhoneAuthService())),
    );

    expect(find.text('Trusted help for every home.'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
    expect(find.text('What do you need?'), findsNothing);

    await _passSplash(tester);
  });

  testWidgets('nobody signed in lands on the phone screen', (tester) async {
    await tester.pumpWidget(
      WashbinApp(services: _services(FakeBackend(), FakePhoneAuthService())),
    );
    await _passSplash(tester);

    expect(find.text('Log in or Sign up'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    // The signed-in app is not merely hidden — it was never built.
    expect(find.text('What do you need?'), findsNothing);
  });

  testWidgets('a short number is rejected before any SMS is sent', (
    tester,
  ) async {
    final phoneAuth = FakePhoneAuthService();
    await tester.pumpWidget(
      WashbinApp(services: _services(FakeBackend(), phoneAuth)),
    );
    await _passSplash(tester);

    await tester.enterText(find.byType(TextFormField), '98765');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your 10-digit mobile number'), findsOneWidget);
    expect(phoneAuth.sentTo, isEmpty);
  });

  testWidgets('a new number goes number -> code -> name -> home', (
    tester,
  ) async {
    final backend = FakeBackend();
    final phoneAuth = FakePhoneAuthService();
    await tester.pumpWidget(
      WashbinApp(services: _services(backend, phoneAuth)),
    );
    await _passSplash(tester);

    await tester.enterText(find.byType(TextFormField), '9876543210');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // The dial code is added before Firebase is asked for an SMS.
    expect(phoneAuth.sentTo, ['+919876543210']);
    expect(find.text('Enter the code'), findsOneWidget);
    expect(find.text('Sent by SMS to +91 98765 43210.'), findsOneWidget);

    // Entering the last digit submits on its own.
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pumpAndSettle();

    // Verified, but this number has no account, so a name is collected.
    expect(find.text('Almost done'), findsOneWidget);
    expect(backend.signInCalls.single['firebaseIdToken'], 'test-id-token');
    expect(backend.signInCalls.single.containsKey('name'), isFalse);

    await tester.enterText(find.byType(TextFormField).first, 'Rahul Sharma');
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(backend.signInCalls.last['name'], 'Rahul Sharma');
    expect(find.text('Hi, Rahul'), findsOneWidget);
    expect(find.text('What do you need?'), findsOneWidget);
  });

  testWidgets('an existing session skips the OTP flow entirely', (
    tester,
  ) async {
    final backend = FakeBackend()..requiresProfile = false;
    await tester.pumpWidget(
      WashbinApp(
        services: _services(
          backend,
          FakePhoneAuthService(storedIdToken: 'stored-id-token'),
        ),
      ),
    );
    await _passSplash(tester);

    expect(find.text('Hi, Rahul'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
  });

  testWidgets('signing out returns to the phone screen', (tester) async {
    final backend = FakeBackend()..requiresProfile = false;
    final phoneAuth = FakePhoneAuthService(storedIdToken: 'stored-id-token');
    final services = _services(backend, phoneAuth);
    await tester.pumpWidget(WashbinApp(services: services));
    await _passSplash(tester);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Rahul Sharma'), findsOneWidget);

    await tester.tap(find.text('Sign out'));
    await _settleSignOut(tester);

    // Sign-out must actually finish, not merely start: it tears down push
    // before clearing the session, and an await in that chain that never
    // returns would strand the customer on "Signing out...".
    expect(services.session.status, SessionStatus.unauthenticated);

    expect(find.text('Log in or Sign up'), findsOneWidget);
    expect(find.text('What do you need?'), findsNothing);
    expect(phoneAuth.signOutCount, 1);
  });

  testWidgets('an unreachable backend offers a retry that works', (
    tester,
  ) async {
    final backend = FakeBackend()
      ..requiresProfile = false
      ..offline = true;
    await tester.pumpWidget(
      WashbinApp(
        services: _services(
          backend,
          FakePhoneAuthService(storedIdToken: 'stored-id-token'),
        ),
      ),
    );
    await _passSplash(tester);

    expect(find.textContaining('No internet connection'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    backend.offline = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Hi, Rahul'), findsOneWidget);
  });

  testWidgets('a rejected token returns to sign-in and says why', (
    tester,
  ) async {
    final services = _services(
      FakeBackend()..requiresProfile = false,
      FakePhoneAuthService(storedIdToken: 'stored-id-token'),
    );
    await tester.pumpWidget(WashbinApp(services: services));
    await _passSplash(tester);
    expect(find.text('Hi, Rahul'), findsOneWidget);

    // What ApiClient does when a request that carried a token comes back 401.
    services.session.handleUnauthorized();
    await _settleSignOut(tester);

    expect(find.text('Log in or Sign up'), findsOneWidget);
    expect(find.textContaining('session has expired'), findsOneWidget);
    expect(services.tokens.hasToken, isFalse);
  });

  testWidgets('the tab bar reaches every shell destination', (tester) async {
    await tester.pumpWidget(
      WashbinApp(
        services: _services(
          FakeBackend()..requiresProfile = false,
          FakePhoneAuthService(storedIdToken: 'stored-id-token'),
        ),
      ),
    );
    await _passSplash(tester);

    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();
    expect(find.text('No bookings yet'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('What do you need?'), findsOneWidget);
  });
}
