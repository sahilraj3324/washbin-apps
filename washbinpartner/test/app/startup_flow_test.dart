import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washbinpartner/app/app_services.dart';
import 'package:washbinpartner/app/washbin_partner_app.dart';
import 'package:washbinpartner/features/availability/data/partner_location_service.dart';

import '../support/fake_backend.dart';
import '../support/fake_messaging_service.dart';
import '../support/fake_partner_location_service.dart';
import '../support/fake_phone_auth_service.dart';

/// Boots the real app over a scripted backend and a Firebase stand-in.
AppServices _services(
  FakeBackend backend,
  FakePhoneAuthService phoneAuth, {
  FakePartnerLocationService? location,
  FakeMessagingService? messaging,
}) {
  return AppServices(
    httpClient: backend.client,
    phoneAuthService: phoneAuth,
    locationService: location,
    messagingService: messaging ?? FakeMessagingService(),
    baseUrl: 'https://api.test',
  );
}

/// Lets the splash's minimum duration elapse and the session resolve.
Future<void> _passSplash(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 2600));
  await tester.pumpAndSettle();
}

/// The registration form is taller than the 800x600 test viewport, so the
/// button has to be scrolled into view first — as it would be on a small phone.
Future<void> _tapRegister(WidgetTester tester) async {
  final button = find.widgetWithText(FilledButton, 'Register');
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

/// Signing out drops the Firebase session before clearing the app's. No frames
/// are scheduled while that runs, so `pumpAndSettle` finds the tree still and
/// returns before it has finished.
Future<void> _settleSignOut(WidgetTester tester) async {
  for (var frame = 0; frame < 12; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _tapJobButton(WidgetTester tester, String label) async {
  var button = find.widgetWithText(FilledButton, label);
  if (button.evaluate().isEmpty) {
    button = find.widgetWithText(OutlinedButton, label);
  }
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

/// A partner the backend already knows, at the given verification status,
/// with a finished profile and one service — so the stage under test is the
/// only thing deciding what the app shows.
FakeBackend _known(String verificationStatus) => FakeBackend()
  ..requiresProfile = false
  ..verificationStatus = verificationStatus
  ..completeProfile()
  ..offerService('svc-1');

void main() {
  testWidgets('startup shows the splash before anything else', (tester) async {
    await tester.pumpWidget(
      WashbinPartnerApp(
        services: _services(FakeBackend(), FakePhoneAuthService()),
      ),
    );

    expect(find.text('Work that comes to you.'), findsOneWidget);
    expect(find.text('Send OTP'), findsNothing);

    await _passSplash(tester);
  });

  testWidgets('nobody signed in lands on the phone screen', (tester) async {
    await tester.pumpWidget(
      WashbinPartnerApp(
        services: _services(FakeBackend(), FakePhoneAuthService()),
      ),
    );
    await _passSplash(tester);

    expect(find.text('Partner login'), findsOneWidget);
    expect(find.text('Send OTP'), findsOneWidget);
    // The working app is not merely hidden — it was never built.
    expect(find.text('Jobs'), findsNothing);
  });

  testWidgets('a short number is rejected before any SMS is sent', (
    tester,
  ) async {
    final phoneAuth = FakePhoneAuthService();
    await tester.pumpWidget(
      WashbinPartnerApp(services: _services(FakeBackend(), phoneAuth)),
    );
    await _passSplash(tester);

    await tester.enterText(find.byType(TextFormField), '98765');
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your 10-digit mobile number'), findsOneWidget);
    expect(phoneAuth.sentTo, isEmpty);
  });

  testWidgets('a new number goes number -> code -> business -> waiting', (
    tester,
  ) async {
    final backend = FakeBackend();
    final phoneAuth = FakePhoneAuthService();
    await tester.pumpWidget(
      WashbinPartnerApp(services: _services(backend, phoneAuth)),
    );
    await _passSplash(tester);

    await tester.enterText(find.byType(TextFormField), '9876543210');
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();

    expect(phoneAuth.sentTo, ['+919876543210']);
    expect(find.text('Enter the code'), findsOneWidget);

    // Entering the last digit submits on its own.
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pumpAndSettle();

    // Verified, but this number has no partner account yet.
    expect(find.text('Register your business'), findsOneWidget);
    expect(backend.signInCalls.single['firebaseIdToken'], 'test-id-token');
    expect(backend.signInCalls.single.containsKey('businessName'), isFalse);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Sharma Home Services');
    await tester.enterText(fields.at(1), 'Rahul Sharma');
    await _tapRegister(tester);

    expect(backend.signInCalls.last['businessName'], 'Sharma Home Services');
    expect(backend.signInCalls.last['ownerName'], 'Rahul Sharma');

    // A brand new partner is registered, with onboarding still to do.
    expect(find.text('Finish setting up'), findsOneWidget);
    expect(find.text('Profile details'), findsOneWidget);
    expect(find.text('Jobs'), findsNothing);
  });

  testWidgets('an existing session skips the OTP flow entirely', (
    tester,
  ) async {
    await tester.pumpWidget(
      WashbinPartnerApp(
        services: _services(
          _known('submitted'),
          FakePhoneAuthService(storedIdToken: 'stored-id-token'),
        ),
      ),
    );
    await _passSplash(tester);

    expect(find.text('Pending approval'), findsOneWidget);
    expect(find.text('Send OTP'), findsNothing);
  });

  testWidgets('a verified partner reaches the app shell', (tester) async {
    await tester.pumpWidget(
      WashbinPartnerApp(
        services: _services(
          _known('verified'),
          FakePhoneAuthService(storedIdToken: 'stored-id-token'),
        ),
      ),
    );
    await _passSplash(tester);

    expect(find.text('Sharma Home Services'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Jobs'), findsOneWidget);
    expect(find.text('Bookings'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Check again'), findsNothing);
  });

  testWidgets('home restores online availability from the backend', (
    tester,
  ) async {
    final backend = _known('verified')
      ..isOnline = true
      ..isAvailable = true
      ..latitude = 19.076
      ..longitude = 72.8777;

    await tester.pumpWidget(
      WashbinPartnerApp(
        services: _services(
          backend,
          FakePhoneAuthService(storedIdToken: 'stored-id-token'),
        ),
      ),
    );
    await _passSplash(tester);
    await tester.pumpAndSettle();

    expect(find.text('You are Online'), findsOneWidget);
    expect(
      find.text('Available for jobs. Current location updated.'),
      findsOneWidget,
    );
    expect(find.text('Go Offline'), findsOneWidget);
    expect(backend.requestCounts['/availability/me'], 1);
  });

  testWidgets('home shows dashboard counts earnings and recent jobs', (
    tester,
  ) async {
    final backend = _known('verified');
    final now = DateTime.now().toUtc();

    final completed = backend.addJobOffer(amount: 350);
    final completedBooking = completed['bookingId'] as Map<String, dynamic>;
    completedBooking['status'] = 'completed';
    completedBooking['completedAt'] = now.toIso8601String();

    final upcoming = backend.addJobOffer(serviceName: 'Scheduled Cleaning');
    final upcomingBooking = upcoming['bookingId'] as Map<String, dynamic>;
    upcomingBooking['status'] = 'accepted';
    upcomingBooking['bookingType'] = 'scheduled';
    upcomingBooking['scheduledAt'] = now
        .add(const Duration(hours: 1))
        .toIso8601String();

    final cancelled = backend.addJobOffer(serviceName: 'Cancelled Repair');
    final cancelledBooking = cancelled['bookingId'] as Map<String, dynamic>;
    cancelledBooking['status'] = 'cancelled';
    cancelledBooking['cancelledAt'] = now.toIso8601String();

    await tester.pumpWidget(
      WashbinPartnerApp(
        services: _services(
          backend,
          FakePhoneAuthService(storedIdToken: 'stored-id-token'),
        ),
      ),
    );
    await _passSplash(tester);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Today'), 300);
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsWidgets);
    expect(find.text('Earnings'), findsWidgets);
    expect(find.text('This Week'), findsOneWidget);
    expect(find.text('This Month'), findsOneWidget);
    expect(find.text('₹350'), findsWidgets);

    await tester.scrollUntilVisible(find.text('Recent Jobs'), 300);
    await tester.pumpAndSettle();

    expect(find.text('Recent Jobs'), findsOneWidget);
    expect(find.text('Home Assistance'), findsOneWidget);
    expect(find.text('Scheduled Cleaning'), findsOneWidget);
    expect(find.text('Cancelled Repair'), findsOneWidget);
  });

  testWidgets('go online sends availability, location and radius', (
    tester,
  ) async {
    final backend = _known('verified');
    final location = FakePartnerLocationService(
      latitude: 28.6139,
      longitude: 77.209,
    );

    await tester.pumpWidget(
      WashbinPartnerApp(
        services: _services(
          backend,
          FakePhoneAuthService(storedIdToken: 'stored-id-token'),
          location: location,
        ),
      ),
    );
    await _passSplash(tester);
    await tester.pumpAndSettle();

    expect(find.text('You are Offline'), findsOneWidget);

    await tester.tap(find.text('Go Online'));
    await tester.pumpAndSettle();

    expect(find.text('You are Online'), findsOneWidget);
    expect(backend.isOnline, isTrue);
    expect(backend.isAvailable, isTrue);
    expect(location.currentPositionCalls, 1);
    expect(backend.availabilityUpdates.single['isOnline'], isTrue);
    expect(backend.availabilityUpdates.single['isAvailable'], isTrue);
    expect(backend.availabilityUpdates.single['latitude'], 28.6139);
    expect(backend.availabilityUpdates.single['longitude'], 77.209);
    expect(backend.availabilityUpdates.single['serviceRadiusKm'], 10);
  });

  testWidgets('location denial keeps the partner offline', (tester) async {
    final backend = _known('verified');
    final location = FakePartnerLocationService()
      ..nextError = const PartnerLocationException(
        PartnerLocationFailure.denied,
        'Washbin needs your location before you can receive nearby jobs.',
      );

    await tester.pumpWidget(
      WashbinPartnerApp(
        services: _services(
          backend,
          FakePhoneAuthService(storedIdToken: 'stored-id-token'),
          location: location,
        ),
      ),
    );
    await _passSplash(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Go Online'));
    await tester.pumpAndSettle();

    expect(find.text('You are Offline'), findsOneWidget);
    expect(backend.availabilityUpdates, isEmpty);
    expect(
      find.text(
        'Washbin needs your location before you can receive nearby jobs.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('backend rejection does not show online success', (tester) async {
    final backend = _known('verified')..goOnlineRejected = true;

    await tester.pumpWidget(
      WashbinPartnerApp(
        services: _services(
          backend,
          FakePhoneAuthService(storedIdToken: 'stored-id-token'),
          location: FakePartnerLocationService(),
        ),
      ),
    );
    await _passSplash(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Go Online'));
    await tester.pumpAndSettle();

    expect(find.text('You are Offline'), findsOneWidget);
    expect(find.text('Only approved partners can go online'), findsOneWidget);
  });

  testWidgets('jobs tab shows incoming job offer details', (tester) async {
    final backend = _known('verified')
      ..isOnline = true
      ..isAvailable = true
      ..addJobOffer();

    await tester.pumpWidget(
      WashbinPartnerApp(
        services: _services(
          backend,
          FakePhoneAuthService(storedIdToken: 'stored-id-token'),
        ),
      ),
    );
    await _passSplash(tester);

    await tester.tap(find.text('Jobs').last);
    await tester.pumpAndSettle();

    expect(find.text('New Job Request'), findsOneWidget);
    expect(find.text('Home Assistance'), findsOneWidget);
    expect(find.text('2.4 km'), findsOneWidget);
    expect(find.text('Gurugram, Haryana'), findsOneWidget);
    expect(find.text('₹350'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
  });

  testWidgets('accepting a job opens active job and marks partner busy', (
    tester,
  ) async {
    final backend = _known('verified')
      ..isOnline = true
      ..isAvailable = true
      ..addJobOffer();

    await tester.pumpWidget(
      WashbinPartnerApp(
        services: _services(
          backend,
          FakePhoneAuthService(storedIdToken: 'stored-id-token'),
        ),
      ),
    );
    await _passSplash(tester);

    await tester.tap(find.text('Jobs').last);
    await tester.pumpAndSettle();
    await _tapJobButton(tester, 'Accept');

    expect(backend.acceptedOffers, ['as-1']);
    expect(backend.isAvailable, isFalse);
    expect(find.text('Active Job'), findsOneWidget);
    expect(find.text('Status: Accepted'), findsOneWidget);
    expect(find.text('On The Way'), findsOneWidget);
    expect(find.text('New Job Request'), findsNothing);
  });

  testWidgets('active job moves through service execution and frees partner', (
    tester,
  ) async {
    final backend = _known('verified')
      ..isOnline = true
      ..isAvailable = true
      ..addJobOffer();

    await tester.pumpWidget(
      WashbinPartnerApp(
        services: _services(
          backend,
          FakePhoneAuthService(storedIdToken: 'stored-id-token'),
        ),
      ),
    );
    await _passSplash(tester);

    await tester.tap(find.text('Jobs').last);
    await tester.pumpAndSettle();
    await _tapJobButton(tester, 'Accept');

    final onTheWay = find.widgetWithText(FilledButton, 'On The Way');
    await tester.ensureVisible(onTheWay);
    await tester.pumpAndSettle();
    await tester.tap(onTheWay);
    await tester.pumpAndSettle();
    expect(find.text('Status: On The Way'), findsOneWidget);

    final arrived = find.widgetWithText(FilledButton, 'Arrived');
    await tester.ensureVisible(arrived);
    await tester.pumpAndSettle();
    await tester.tap(arrived);
    await tester.pumpAndSettle();
    expect(find.text('Status: Arrived'), findsOneWidget);

    final start = find.widgetWithText(FilledButton, 'Start Service');
    await tester.ensureVisible(start);
    await tester.pumpAndSettle();
    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(find.text('Status: In Progress'), findsOneWidget);

    final complete = find.widgetWithText(FilledButton, 'Complete Service');
    await tester.ensureVisible(complete);
    await tester.pumpAndSettle();
    await tester.tap(complete);
    await tester.pumpAndSettle();

    expect(backend.isAvailable, isTrue);
    expect(find.text('Active Job'), findsNothing);
    expect(find.text('No incoming job requests'), findsOneWidget);

    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();
    expect(find.text('Home Assistance'), findsOneWidget);
    expect(find.text('Completed'), findsWidgets);

    await tester.tap(find.text('Home Assistance').first);
    await tester.pumpAndSettle();
    expect(find.text('Job Details'), findsOneWidget);
    expect(find.text('Booking ID'), findsOneWidget);
  });

  testWidgets('rejecting a job removes it and partner remains available', (
    tester,
  ) async {
    final backend = _known('verified')
      ..isOnline = true
      ..isAvailable = true
      ..addJobOffer();

    await tester.pumpWidget(
      WashbinPartnerApp(
        services: _services(
          backend,
          FakePhoneAuthService(storedIdToken: 'stored-id-token'),
        ),
      ),
    );
    await _passSplash(tester);

    await tester.tap(find.text('Jobs').last);
    await tester.pumpAndSettle();
    await _tapJobButton(tester, 'Reject');

    expect(backend.rejectedOffers, ['as-1']);
    expect(backend.isAvailable, isTrue);
    expect(find.text('No incoming job requests'), findsOneWidget);
  });

  testWidgets('expired accept is trusted from the backend', (tester) async {
    final backend = _known('verified')
      ..isOnline = true
      ..isAvailable = true
      ..acceptOfferFailsAsExpired = true
      ..addJobOffer();

    await tester.pumpWidget(
      WashbinPartnerApp(
        services: _services(
          backend,
          FakePhoneAuthService(storedIdToken: 'stored-id-token'),
        ),
      ),
    );
    await _passSplash(tester);

    await tester.tap(find.text('Jobs').last);
    await tester.pumpAndSettle();
    await _tapJobButton(tester, 'Accept');

    expect(find.text('This job is no longer available.'), findsOneWidget);
    expect(find.text('Active Job'), findsNothing);
  });

  testWidgets('notifications can be read and open the jobs tab', (
    tester,
  ) async {
    final backend = _known('verified')
      ..isOnline = true
      ..isAvailable = true
      ..addJobOffer();
    backend.addNotification(bookingId: 'booking-as-1');

    await tester.pumpWidget(
      WashbinPartnerApp(
        services: _services(
          backend,
          FakePhoneAuthService(storedIdToken: 'stored-id-token'),
        ),
      ),
    );
    await _passSplash(tester);

    await tester.tap(find.text('Alerts'));
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('New Job Request'), findsOneWidget);
    expect(find.text('2.1 km away'), findsOneWidget);

    await tester.tap(find.text('New Job Request'));
    await tester.pumpAndSettle();

    expect(backend.notifications.single['isRead'], isTrue);
    expect(find.text('New Job Request'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
  });

  testWidgets('a rejected partner gets the reason and a way to fix it', (
    tester,
  ) async {
    final backend = _known('rejected')
      ..rejectionReason = 'Document details are incomplete.';
    await tester.pumpWidget(
      WashbinPartnerApp(
        services: _services(
          backend,
          FakePhoneAuthService(storedIdToken: 'stored-id-token'),
        ),
      ),
    );
    await _passSplash(tester);

    expect(find.text('Profile rejected'), findsOneWidget);
    expect(find.text('Document details are incomplete.'), findsOneWidget);
    expect(find.text('Submit again'), findsOneWidget);
    expect(find.text('Jobs'), findsNothing);
  });

  testWidgets('a suspended partner is told, not asked to sign in again', (
    tester,
  ) async {
    final backend = FakeBackend()..suspended = true;
    await tester.pumpWidget(
      WashbinPartnerApp(
        services: _services(
          backend,
          FakePhoneAuthService(storedIdToken: 'stored-id-token'),
        ),
      ),
    );
    await _passSplash(tester);

    expect(find.text('Account suspended'), findsOneWidget);
    expect(
      find.text('This partner account has been suspended'),
      findsOneWidget,
    );
    expect(find.text('Send OTP'), findsNothing);
  });

  testWidgets('a waiting partner is let in once Washbin approves them', (
    tester,
  ) async {
    final backend = _known('submitted');
    await tester.pumpWidget(
      WashbinPartnerApp(
        services: _services(
          backend,
          FakePhoneAuthService(storedIdToken: 'stored-id-token'),
        ),
      ),
    );
    await _passSplash(tester);

    expect(find.text('Pending approval'), findsOneWidget);

    backend.verificationStatus = 'verified';
    await tester.fling(
      find.text('Before you can go online'),
      const Offset(0, 320),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.text('Jobs'), findsOneWidget);
    expect(find.text('Pending approval'), findsNothing);
  });

  testWidgets('an unreachable server offers a retry, not a sign-out', (
    tester,
  ) async {
    final backend = _known('verified')..offline = true;
    await tester.pumpWidget(
      WashbinPartnerApp(
        services: _services(
          backend,
          FakePhoneAuthService(storedIdToken: 'stored-id-token'),
        ),
      ),
    );
    await _passSplash(tester);

    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Send OTP'), findsNothing);

    backend.offline = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Jobs'), findsOneWidget);
  });

  testWidgets('signing out from the profile tab tears the app down', (
    tester,
  ) async {
    final phoneAuth = FakePhoneAuthService(storedIdToken: 'stored-id-token');
    final backend = _known('verified');
    final messaging = FakeMessagingService();
    await tester.pumpWidget(
      WashbinPartnerApp(
        services: _services(backend, phoneAuth, messaging: messaging),
      ),
    );
    await _passSplash(tester);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    final signOut = find.widgetWithText(OutlinedButton, 'Sign out');
    await tester.scrollUntilVisible(signOut, 200);
    await tester.pumpAndSettle();
    await tester.tap(signOut);
    await _settleSignOut(tester);

    expect(find.text('Partner login'), findsOneWidget);
    expect(find.text('Jobs'), findsNothing);
    expect(phoneAuth.signOutCount, 1);
    expect(backend.registeredDeviceTokens.single['token'], 'test-fcm-token');
    expect(backend.deactivatedDeviceTokens, ['test-fcm-token']);
    expect(messaging.deleteTokenCalls, 1);
  });

  testWidgets('signing out from onboarding works too', (tester) async {
    final phoneAuth = FakePhoneAuthService(storedIdToken: 'stored-id-token');
    await tester.pumpWidget(
      WashbinPartnerApp(services: _services(_known('pending'), phoneAuth)),
    );
    await _passSplash(tester);

    expect(find.text('Finish setting up'), findsOneWidget);

    final signOut = find.widgetWithText(TextButton, 'Sign out');
    await tester.ensureVisible(signOut);
    await tester.pumpAndSettle();
    await tester.tap(signOut);
    await _settleSignOut(tester);

    expect(find.text('Partner login'), findsOneWidget);
    expect(phoneAuth.signOutCount, 1);
  });
}
