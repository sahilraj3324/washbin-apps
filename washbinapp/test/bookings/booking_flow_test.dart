import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washbinapp/app/app_services.dart';
import 'package:washbinapp/app/washbin_app.dart';

import '../support/fake_backend.dart';
import '../support/fake_location_service.dart';
import '../support/fake_messaging_service.dart';
import '../support/fake_phone_auth_service.dart';

Future<AppServices> _signedIn(WidgetTester tester, FakeBackend backend) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  backend.requiresProfile = false;
  final services = AppServices(
    httpClient: backend.client,
    phoneAuthService: FakePhoneAuthService(storedIdToken: 'stored-id-token'),
    locationService: FakeLocationService(),
    baseUrl: 'https://api.test',
    // No poll timer firing under the test; polling has its own test.
    // Real FCM would reach Firebase, which no test has initialised.
    messagingService: FakeMessagingService(),
    trackingPollInterval: null,
  );

  await tester.pumpWidget(WashbinApp(services: services));
  await tester.pump(const Duration(milliseconds: 3200));
  await tester.pumpAndSettle();
  return services;
}

/// Like [_signedIn], for a customer who already has a booking in progress —
/// whose Home card animates, so stillness never arrives.
Future<AppServices> _signedInLive(
  WidgetTester tester,
  FakeBackend backend,
) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  backend.requiresProfile = false;
  final services = AppServices(
    httpClient: backend.client,
    phoneAuthService: FakePhoneAuthService(storedIdToken: 'stored-id-token'),
    locationService: FakeLocationService(),
    baseUrl: 'https://api.test',
    // Real FCM would reach Firebase, which no test has initialised.
    messagingService: FakeMessagingService(),
    trackingPollInterval: null,
  );

  await tester.pumpWidget(WashbinApp(services: services));
  await tester.pump(const Duration(milliseconds: 3200));
  await _settle(tester);
  return services;
}

Future<void> _toSummaryLive(WidgetTester tester) async {
  // The active-booking card names the same service, so the card in the
  // catalogue list is the later of the two.
  await tester.tap(find.text('Deep Cleaning').last);
  await _settle(tester);
  await tester.tap(find.text('Continue'));
  await _settle(tester);
  await tester.tap(find.text('Home'));
  await _settle(tester);
  await tester.tap(find.text('Continue'));
  await _settle(tester);
  await tester.tap(find.text('Review booking'));
  await _settle(tester);
}

/// A backend with one saved, serviceable address ready to book against.
FakeBackend _ready() =>
    FakeBackend()
      ..addresses = [FakeBackend.address(id: 'addr-1', isDefault: true)];

/// Home → service → Continue → pick the saved address → Continue.
Future<void> _toBookingSetup(WidgetTester tester) async {
  await tester.tap(find.text('Deep Cleaning'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Home'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
}

Future<void> _toSummary(WidgetTester tester) async {
  await _toBookingSetup(tester);
  await tester.tap(find.text('Review booking'));
  await tester.pumpAndSettle();
}

/// Advances frames without waiting for the tree to go still.
///
/// `pumpAndSettle` never returns once a searching booking is on screen: the
/// "finding a partner" card animates for as long as it is visible, which is
/// correct on a device and fatal to a test that waits for stillness.
Future<void> _settle(WidgetTester tester) async {
  for (var frame = 0; frame < 14; frame++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  group('reaching the booking screens', () {
    testWidgets('a chosen address leads to the booking type screen', (
      tester,
    ) async {
      await _signedIn(tester, _ready());
      await _toBookingSetup(tester);

      expect(find.text('When do you need it?'), findsOneWidget);
      expect(find.text('Book now'), findsOneWidget);
      expect(find.text('Schedule'), findsOneWidget);
      expect(find.text('Anything we should know?'), findsOneWidget);
    });

    testWidgets('the summary shows service, location, time and price', (
      tester,
    ) async {
      await _signedIn(tester, _ready());
      await _toSummary(tester);

      expect(find.text('SERVICE'), findsOneWidget);
      expect(find.text('Deep Cleaning'), findsOneWidget);
      expect(find.text('LOCATION'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.textContaining('Mumbai, Maharashtra 400020'), findsOneWidget);
      expect(find.text('BOOKING'), findsOneWidget);
      expect(find.text('Now'), findsOneWidget);
      expect(find.text('PRICE'), findsOneWidget);
      expect(find.text('₹299'), findsOneWidget);
    });

    testWidgets('notes reach the summary and the request', (tester) async {
      final backend = _ready();
      await _signedIn(tester, backend);
      await _toBookingSetup(tester);

      await tester.enterText(
        find.byType(TextField).last,
        'Please call before arriving',
      );
      await tester.tap(find.text('Review booking'));
      await tester.pumpAndSettle();

      expect(find.text('NOTES'), findsOneWidget);
      expect(find.text('Please call before arriving'), findsOneWidget);

      await tester.tap(find.text('Confirm booking'));
      await tester.pumpAndSettle();

      expect(
        backend.bookingAttempts.single['notes'],
        'Please call before arriving',
      );
    });
  });

  group('instant booking', () {
    testWidgets('confirming creates it and reports searching for a partner', (
      tester,
    ) async {
      final backend = _ready();
      await _signedIn(tester, backend);
      await _toSummary(tester);

      await tester.tap(find.text('Confirm booking'));
      await tester.pumpAndSettle();

      expect(backend.bookings, hasLength(1));
      expect(backend.bookings.single['status'], 'searching_partner');
      expect(backend.bookings.single['bookingType'], 'instant');

      expect(find.text('Booking created'), findsOneWidget);
      expect(find.text('Searching for partner'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('Done returns to the app, not to the Confirm button', (
      tester,
    ) async {
      final backend = _ready();
      await _signedIn(tester, backend);
      await _toSummary(tester);
      await tester.tap(find.text('Confirm booking'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('What do you need?'), findsOneWidget);
      expect(find.text('Confirm booking'), findsNothing);
    });
  });

  group('scheduled booking', () {
    testWidgets('a date and time must be chosen before reviewing', (
      tester,
    ) async {
      await _signedIn(tester, _ready());
      await _toBookingSetup(tester);

      await tester.tap(find.text('Schedule'));
      await tester.pumpAndSettle();
      expect(find.text('Not chosen yet'), findsOneWidget);

      await tester.tap(find.text('Review booking'));
      await tester.pumpAndSettle();

      // Stopped here rather than rejected two screens later by the server.
      expect(find.textContaining('Pick a date and time'), findsWidgets);
      expect(find.text('Booking summary'), findsNothing);
    });

    testWidgets('a chosen time creates a pending booking', (tester) async {
      final backend = _ready();
      await _signedIn(tester, backend);
      await _toBookingSetup(tester);

      await tester.tap(find.text('Schedule'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Not chosen yet'));
      await tester.pumpAndSettle();
      // Tomorrow, at whatever time the picker opens on.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Review booking'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm booking'));
      await tester.pumpAndSettle();

      expect(backend.bookings.single['bookingType'], 'scheduled');
      expect(backend.bookings.single['status'], 'pending');
      expect(backend.bookings.single['scheduledAt'], isNotNull);
      expect(find.text('Scheduled'), findsOneWidget);
      expect(
        find.textContaining('start looking for a partner closer to the time'),
        findsOneWidget,
      );
    });

    testWidgets('switching back to Book now clears the chosen time', (
      tester,
    ) async {
      final backend = _ready();
      await _signedIn(tester, backend);
      await _toBookingSetup(tester);

      await tester.tap(find.text('Schedule'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not chosen yet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Book now'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review booking'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm booking'));
      await tester.pumpAndSettle();

      // The API rejects scheduledAt on an instant booking outright.
      expect(
        backend.bookingAttempts.single.containsKey('scheduledAt'),
        isFalse,
      );
      expect(backend.bookings.single['status'], 'searching_partner');
    });
  });

  group('duplicate submission', () {
    testWidgets('two taps in the same frame create one booking', (
      tester,
    ) async {
      final backend = _ready();
      await _signedIn(tester, backend);
      await _toSummary(tester);

      // No pump between them: the button has had no chance to rebuild as
      // disabled, which is exactly how a double tap gets through.
      await tester.tap(find.text('Confirm booking'));
      await tester.tap(find.text('Confirm booking'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(backend.bookingAttempts, hasLength(1));
      expect(backend.bookings, hasLength(1));
    });

    testWidgets('the button is disabled while the request is in flight', (
      tester,
    ) async {
      final backend = _ready();
      await _signedIn(tester, backend);
      await _toSummary(tester);

      await tester.tap(find.text('Confirm booking'));
      await tester.pump();

      expect(find.text('Creating booking...'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Creating booking...'),
      );
      expect(button.onPressed, isNull);

      await tester.pumpAndSettle();
      expect(backend.bookings, hasLength(1));
    });

    testWidgets('back from the confirmation cannot re-submit', (tester) async {
      final backend = _ready();
      await _signedIn(tester, backend);
      await _toSummary(tester);
      await tester.tap(find.text('Confirm booking'));
      await tester.pumpAndSettle();

      // The summary was replaced, and the confirmation refuses to pop.
      final popped = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(popped, isTrue);
      expect(find.text('Booking created'), findsOneWidget);
      expect(backend.bookings, hasLength(1));
    });
  });

  group('failures', () {
    testWidgets('a clashing booking is explained and can be retried', (
      tester,
    ) async {
      final backend = _ready()
        ..bookings = [
          {
            '_id': 'existing',
            'serviceId': 'svc-1',
            'status': 'searching_partner',
            'bookingType': 'instant',
          },
        ];
      await _signedInLive(tester, backend);
      await _toSummaryLive(tester);

      await tester.tap(find.text('Confirm booking'));
      await _settle(tester);

      expect(
        find.textContaining('already have a booking in progress'),
        findsOneWidget,
      );
      // Still on the summary, and the button works again.
      expect(find.text('Confirm booking'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Confirm booking'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('a server failure leaves the summary intact', (tester) async {
      final backend = _ready()..bookingsFail = true;
      await _signedIn(tester, backend);
      await _toSummary(tester);

      await tester.tap(find.text('Confirm booking'));
      await tester.pumpAndSettle();

      expect(find.text('Booking summary'), findsOneWidget);
      expect(find.text('Booking created'), findsNothing);
      expect(backend.bookings, isEmpty);

      // And a retry succeeds once the server recovers.
      backend.bookingsFail = false;
      await tester.tap(find.text('Confirm booking'));
      await tester.pumpAndSettle();
      expect(find.text('Booking created'), findsOneWidget);
    });

    testWidgets('an unserviceable address is refused by the server', (
      tester,
    ) async {
      // Serviceable when picked, then the coverage is withdrawn.
      final backend = _ready();
      await _signedIn(tester, backend);
      await _toSummary(tester);

      backend.serviceAreas = [];
      await tester.tap(find.text('Confirm booking'));
      await tester.pumpAndSettle();

      expect(find.textContaining('not serviceable'), findsOneWidget);
      expect(backend.bookings, isEmpty);
    });
  });

  group('current location', () {
    testWidgets('must be saved as an address before it can be booked', (
      tester,
    ) async {
      // The API books against an addressId, never raw coordinates.
      final backend = FakeBackend();
      await _signedIn(tester, backend);

      await tester.tap(find.text('Deep Cleaning'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Use my current location'));
      await tester.pumpAndSettle();
      expect(find.text('Save address & continue'), findsOneWidget);

      await tester.tap(find.text('Save address & continue'));
      await tester.pumpAndSettle();

      // The form opens on the fix that was just confirmed.
      expect(find.text('Add address'), findsWidgets);
      expect(find.text('Map location set'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Address'),
        '12 Marine Drive',
      );
      await tester.tap(find.text('Save address'));
      await tester.pumpAndSettle();

      expect(backend.addresses, hasLength(1));
      expect(find.text('When do you need it?'), findsOneWidget);
    });
  });
}
