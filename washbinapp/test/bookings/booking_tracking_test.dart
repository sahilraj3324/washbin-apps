import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washbinapp/app/app_services.dart';
import 'package:washbinapp/app/washbin_app.dart';

import '../support/fake_backend.dart';
import '../support/fake_location_service.dart';
import '../support/fake_messaging_service.dart';
import '../support/fake_phone_auth_service.dart';

/// `pumpAndSettle` never returns once a searching booking is on screen: the
/// "finding a partner" indicator animates for as long as it is visible.
Future<void> _settle(WidgetTester tester) async {
  for (var frame = 0; frame < 14; frame++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<AppServices> _signedIn(
  WidgetTester tester,
  FakeBackend backend, {
  Duration? pollInterval,
}) async {
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
    trackingPollInterval: pollInterval,
  );

  await tester.pumpWidget(WashbinApp(services: services));
  await tester.pump(const Duration(milliseconds: 3200));
  await _settle(tester);
  return services;
}

/// The cancel button sits below the fold, and a ListView only builds what is
/// in view.
Future<void> _scrollToBottom(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, -600));
  await _settle(tester);
}

/// Home → the active-booking card → tracking.
Future<void> _openTracking(WidgetTester tester) async {
  await tester.tap(find.text('View booking'));
  await _settle(tester);
}

FakeBackend _withBooking({
  String status = 'searching_partner',
  String? partnerId,
  Map<String, dynamic> extra = const {},
}) => FakeBackend()
  ..bookings = [
    {
      ...FakeBackend.booking(id: '68c1f4aa930b148ed80df6ab', status: status),
      'assignedPartnerId': partnerId,
      ...extra,
    },
  ];

void main() {
  group('the active booking card', () {
    testWidgets('brings a booking in progress to the top of Home', (
      tester,
    ) async {
      // This is what reconnects a customer to their booking after a restart.
      await _signedIn(tester, _withBooking());

      expect(find.text('Searching for partner'), findsOneWidget);
      expect(find.text('View booking'), findsOneWidget);
    });

    testWidgets('a completed booking is never shown as active', (tester) async {
      await _signedIn(tester, _withBooking(status: 'completed'));

      expect(find.text('View booking'), findsNothing);
      expect(find.text('What do you need?'), findsOneWidget);
    });

    testWidgets('a cancelled booking is never shown as active', (tester) async {
      await _signedIn(tester, _withBooking(status: 'cancelled'));

      expect(find.text('View booking'), findsNothing);
    });

    testWidgets('a search that came up empty still counts as active', (
      tester,
    ) async {
      // The customer can still act on it, so hiding it would strand them.
      await _signedIn(tester, _withBooking(status: 'no_partner_found'));

      expect(find.text('No partner available'), findsOneWidget);
      expect(find.text('View booking'), findsOneWidget);
    });

    testWidgets('a bookings outage does not stop the customer browsing', (
      tester,
    ) async {
      final backend = _withBooking()..bookingsFail = true;
      await _signedIn(tester, backend);

      expect(find.text('View booking'), findsNothing);
      expect(find.text('What do you need?'), findsOneWidget);
      expect(find.text('Home Cleaning'), findsOneWidget);
    });
  });

  group('the tracking screen', () {
    testWidgets('shows the status, the reference and the timeline', (
      tester,
    ) async {
      await _signedIn(tester, _withBooking());
      await _openTracking(tester);

      expect(find.text('Searching for partner'), findsWidgets);
      expect(find.text('Booking ID: SWZ-0DF6AB'), findsOneWidget);
      expect(find.text('Booking confirmed'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
    });

    testWidgets('shows the partner panel once one is assigned', (tester) async {
      await _signedIn(
        tester,
        _withBooking(status: 'partner_assigned', partnerId: 'partner-1'),
      );
      await _openTracking(tester);

      expect(find.text('YOUR PARTNER'), findsOneWidget);
      // The API sends no partner details yet, so the panel says only that
      // someone is assigned.
      expect(find.text('Partner assigned'), findsWidgets);
      expect(find.byIcon(Icons.call_rounded), findsNothing);
    });

    testWidgets('fills the panel in when the API sends partner details', (
      tester,
    ) async {
      // Forward-compatible: the day a booking carries an `assignedPartner`
      // object, this is what the customer sees, with no further change.
      await _signedIn(
        tester,
        _withBooking(
          status: 'on_the_way',
          partnerId: 'partner-1',
          extra: {
            'assignedPartner': {
              '_id': 'partner-1',
              'ownerName': 'Rahul',
              'phone': '+919876543210',
              'rating': 4.8,
              'distanceKm': 2.3,
            },
            'etaMinutes': 15,
            'onTheWayAt': '2026-09-13T10:05:00.000Z',
          },
        ),
      );
      await _openTracking(tester);

      expect(find.text('Rahul'), findsOneWidget);
      expect(find.text('4.8'), findsOneWidget);
      expect(find.text('2.3 km away'), findsOneWidget);
      expect(find.text('Estimated arrival'), findsOneWidget);
      expect(find.text('15 mins'), findsOneWidget);
      expect(find.byIcon(Icons.call_rounded), findsOneWidget);
    });

    testWidgets('shows the start code once the partner has arrived', (
      tester,
    ) async {
      final expiry = DateTime.now()
          .add(const Duration(minutes: 10))
          .toUtc()
          .toIso8601String();
      await _signedIn(
        tester,
        _withBooking(
          status: 'arrived',
          partnerId: 'partner-1',
          extra: {
            'serviceStartOtp': '482913',
            'serviceStartOtpExpiresAt': expiry,
            'arrivedAt': '2026-09-13T10:20:00.000Z',
          },
        ),
      );
      await _openTracking(tester);

      expect(find.text('482913'), findsOneWidget);
      expect(
        find.textContaining('Give this code to your partner'),
        findsOneWidget,
      );
    });

    testWidgets('explains a search that found nobody', (tester) async {
      await _signedIn(tester, _withBooking(status: 'no_partner_found'));
      await _openTracking(tester);

      expect(find.textContaining('Nobody was free this time'), findsWidgets);
    });

    testWidgets('a failed read offers a retry that works', (tester) async {
      final backend = _withBooking();
      await _signedIn(tester, backend);
      await _openTracking(tester);

      // The screen opened on the booking Home already had, then re-read it.
      backend.bookingsFail = true;
      await tester.drag(find.byType(ListView), const Offset(0, 400));
      await _settle(tester);

      // A failed refresh keeps what is on screen rather than emptying it.
      expect(find.text('Booking ID: SWZ-0DF6AB'), findsOneWidget);
    });
  });

  group('cancelling from tracking', () {
    testWidgets('is offered only while the backend allows it', (tester) async {
      await _signedIn(tester, _withBooking(status: 'in_progress'));
      await _openTracking(tester);
      await _scrollToBottom(tester);

      expect(find.text('Cancel booking'), findsNothing);
    });

    testWidgets('asks, then lets the backend decide', (tester) async {
      final backend = _withBooking();
      await _signedIn(tester, backend);
      await _openTracking(tester);
      await _scrollToBottom(tester);

      await tester.tap(find.text('Cancel booking'));
      await _settle(tester);
      expect(find.text('Cancel this booking?'), findsOneWidget);

      await tester.tap(find.text('Cancel booking').last);
      await _settle(tester);

      expect(backend.bookings.single['status'], 'cancelled');
      expect(find.text('Cancelled'), findsWidgets);
    });

    testWidgets('a refusal from the backend is surfaced, not hidden', (
      tester,
    ) async {
      final backend = _withBooking();
      await _signedIn(tester, backend);
      await _openTracking(tester);
      await _scrollToBottom(tester);

      await tester.tap(find.text('Cancel booking'));
      await _settle(tester);

      // The partner started work while the dialog was open.
      backend.bookings.single['status'] = 'in_progress';
      await tester.tap(find.text('Cancel booking').last);
      await _settle(tester);

      expect(find.textContaining('Cannot cancel'), findsOneWidget);
      expect(backend.bookings.single['status'], 'in_progress');
      expect(find.text('Service in progress'), findsWidgets);
    });
  });

  group('polling', () {
    testWidgets(
      'picks up a status change without the customer doing anything',
      (tester) async {
        final backend = _withBooking();
        await _signedIn(
          tester,
          backend,
          pollInterval: const Duration(seconds: 2),
        );
        await _openTracking(tester);
        expect(find.text('Partner confirmed'), findsNothing);

        // The partner accepted while the screen was open.
        backend.bookings.single
          ..['status'] = 'accepted'
          ..['assignedPartnerId'] = 'partner-1'
          ..['acceptedAt'] = '2026-09-13T10:00:00.000Z';

        await tester.pump(const Duration(seconds: 2));
        await _settle(tester);

        expect(find.text('Partner confirmed'), findsWidgets);
      },
    );

    testWidgets('stops once the booking can no longer change on its own', (
      tester,
    ) async {
      final backend = _withBooking(
        status: 'completed',
        extra: {'completedAt': '2026-09-13T11:30:00.000Z'},
      );
      await _signedIn(
        tester,
        backend,
        pollInterval: const Duration(seconds: 2),
      );

      // A completed booking is not active, so it is reached from the list.
      await tester.tap(find.text('Bookings'));
      await _settle(tester);
      await tester.tap(find.text('Deep Cleaning').last);
      await _settle(tester);

      final afterOpen =
          backend.requestCounts['/bookings/68c1f4aa930b148ed80df6ab'] ?? 0;

      await tester.pump(const Duration(seconds: 6));
      await _settle(tester);

      expect(
        backend.requestCounts['/bookings/68c1f4aa930b148ed80df6ab'],
        afterOpen,
      );
    });
  });
}
