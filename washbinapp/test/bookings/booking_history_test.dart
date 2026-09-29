import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washbinapp/app/app_services.dart';
import 'package:washbinapp/app/washbin_app.dart';
import 'package:washbinapp/features/bookings/domain/booking.dart';
import 'package:washbinapp/features/bookings/domain/booking_bucket.dart';
import 'package:washbinapp/features/bookings/domain/booking_status.dart';
import 'package:washbinapp/features/bookings/domain/bookings_view.dart';

import '../support/fake_backend.dart';
import '../support/fake_location_service.dart';
import '../support/fake_messaging_service.dart';
import '../support/fake_phone_auth_service.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var frame = 0; frame < 14; frame++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<AppServices> _signedIn(WidgetTester tester, FakeBackend backend) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  backend.requiresProfile = false;
  final services = AppServices(
    httpClient: backend.client,
    phoneAuthService: FakePhoneAuthService(storedIdToken: 'stored-id-token'),
    locationService: FakeLocationService(),
    messagingService: FakeMessagingService(),
    baseUrl: 'https://api.test',
    trackingPollInterval: null,
  );

  await tester.pumpWidget(WashbinApp(services: services));
  await tester.pump(const Duration(milliseconds: 3200));
  await _settle(tester);
  return services;
}

Future<void> _openBookings(WidgetTester tester) async {
  await tester.tap(find.text('Bookings'));
  await _settle(tester);
}

Future<void> _openTab(WidgetTester tester, String label) async {
  final tab = find.text(label);
  await tester.ensureVisible(tab);
  await _settle(tester);
  await tester.tap(tab);
  await _settle(tester);
}

Booking _booking({
  required String status,
  String bookingType = 'instant',
  String? scheduledAt,
  Map<String, dynamic> extra = const {},
}) => Booking.fromJson({
  ...FakeBackend.booking(
    id: '68c1f4aa930b148ed80df6ab',
    status: status,
    bookingType: bookingType,
    scheduledAt: scheduledAt,
  ),
  ...extra,
});

void main() {
  group('bucketing', () {
    test('every status lands in exactly one bucket', () {
      // Nothing may fall between the filters and vanish from the history.
      for (final status in BookingStatus.values) {
        final bucket = BookingBucket.of(_booking(status: status.wireValue));
        expect(
          BookingBucket.values.contains(bucket),
          isTrue,
          reason: '${status.wireValue} has no bucket',
        );
      }
    });

    test('work in flight is active', () {
      for (final status in [
        'searching_partner',
        'partner_assigned',
        'accepted',
        'on_the_way',
        'arrived',
        'in_progress',
      ]) {
        expect(
          BookingBucket.of(_booking(status: status)),
          BookingBucket.active,
          reason: status,
        );
      }
    });

    test('a search that found nobody stays active, needing a decision', () {
      expect(
        BookingBucket.of(_booking(status: 'no_partner_found')),
        BookingBucket.active,
      );
    });

    test('a scheduled booking awaiting its window is upcoming', () {
      expect(
        BookingBucket.of(_booking(status: 'pending', bookingType: 'scheduled')),
        BookingBucket.upcoming,
      );
    });

    test('a scheduled booking that has been dispatched is active', () {
      // Once it is looking for a partner it is happening now, not later.
      expect(
        BookingBucket.of(
          _booking(status: 'searching_partner', bookingType: 'scheduled'),
        ),
        BookingBucket.active,
      );
    });

    test('finished bookings go to their own buckets', () {
      expect(
        BookingBucket.of(_booking(status: 'completed')),
        BookingBucket.completed,
      );
      expect(
        BookingBucket.of(_booking(status: 'cancelled')),
        BookingBucket.cancelled,
      );
    });
  });

  group('the view', () {
    BookingsView viewOf(List<String> statuses) => BookingsView.join([
      for (final status in statuses) _booking(status: status),
    ], const []);

    test('counts each bucket', () {
      final view = viewOf([
        'searching_partner',
        'accepted',
        'completed',
        'cancelled',
      ]);

      expect(view.countIn(BookingBucket.active), 2);
      expect(view.countIn(BookingBucket.upcoming), 0);
      expect(view.countIn(BookingBucket.completed), 1);
      expect(view.countIn(BookingBucket.cancelled), 1);
    });

    test('opens on the first bucket with something in it', () {
      expect(viewOf(['completed']).openingBucket, BookingBucket.completed);
      expect(viewOf(['cancelled']).openingBucket, BookingBucket.cancelled);
      expect(
        viewOf(['accepted', 'completed']).openingBucket,
        BookingBucket.active,
      );
    });

    test('names a service that has been deleted outright', () {
      // The booking outlives the service; the row still has to say something.
      final view = viewOf(['completed']);

      expect(view.nameFor(view.bookings.single), 'Service');
    });
  });

  group('history on screen', () {
    testWidgets('a completed booking shows its full timeline', (tester) async {
      final backend = FakeBackend()
        ..bookings = [
          {
            ...FakeBackend.booking(
              id: '68c1f4aa930b148ed80df6ab',
              status: 'completed',
            ),
            'assignedPartnerId': 'partner-1',
            'acceptedAt': '2026-09-13T10:00:00.000Z',
            'onTheWayAt': '2026-09-13T10:05:00.000Z',
            'arrivedAt': '2026-09-13T10:20:00.000Z',
            'startedAt': '2026-09-13T10:25:00.000Z',
            'completedAt': '2026-09-13T11:30:00.000Z',
          },
        ];
      await _signedIn(tester, backend);
      await _openBookings(tester);
      await tester.tap(find.text('Deep Cleaning'));
      await _settle(tester);

      expect(find.text('Booking ID: SWZ-0DF6AB'), findsOneWidget);
      expect(find.text('Booking confirmed'), findsOneWidget);
      expect(find.text('Partner accepted'), findsOneWidget);
      expect(find.text('Service started'), findsOneWidget);
      expect(find.text('Completed'), findsWidgets);
      expect(find.text('Price'), findsOneWidget);
      // Nothing to call off any more.
      expect(find.text('Cancel booking'), findsNothing);
    });

    testWidgets('a cancelled booking says when, and stops there', (
      tester,
    ) async {
      final backend = FakeBackend()
        ..bookings = [
          {
            ...FakeBackend.booking(
              id: '68c1f4aa930b148ed80df6ab',
              status: 'cancelled',
            ),
            'cancelledAt': '2026-09-13T10:10:00.000Z',
          },
        ];
      await _signedIn(tester, backend);
      await _openBookings(tester);
      await tester.tap(find.text('Deep Cleaning'));
      await _settle(tester);

      expect(find.text('CANCELLED'), findsOneWidget);
      expect(find.text('Cancelled at'), findsOneWidget);
      // The API records no reason and no actor, so neither is invented.
      expect(find.text('Cancelled by'), findsNothing);
      expect(find.text('Reason'), findsNothing);
      // The ladder stops rather than showing stages it will never reach.
      expect(find.text('Service started'), findsNothing);
    });

    testWidgets('a cancellation fills in when the API sends the details', (
      tester,
    ) async {
      // Forward-compatible: no client change is needed when the booking
      // starts carrying who cancelled it and why.
      final backend = FakeBackend()
        ..bookings = [
          {
            ...FakeBackend.booking(
              id: '68c1f4aa930b148ed80df6ab',
              status: 'cancelled',
            ),
            'cancelledAt': '2026-09-13T10:10:00.000Z',
            'cancelledBy': 'customer',
            'cancellationReason': 'Changed my plans',
          },
        ];
      await _signedIn(tester, backend);
      await _openBookings(tester);
      await tester.tap(find.text('Deep Cleaning'));
      await _settle(tester);

      expect(find.text('Cancelled by'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
      expect(find.text('Changed my plans'), findsOneWidget);
    });

    testWidgets('an upcoming booking shows when it will happen', (
      tester,
    ) async {
      final backend = FakeBackend()
        ..bookings = [
          FakeBackend.booking(
            id: '68c1f4aa930b148ed80df6ab',
            status: 'pending',
            bookingType: 'scheduled',
            scheduledAt: DateTime.now()
                .add(const Duration(days: 1))
                .toUtc()
                .toIso8601String(),
          ),
        ];
      await _signedIn(tester, backend);
      await _openBookings(tester);

      expect(find.text('Upcoming (1)'), findsOneWidget);
      expect(find.text('Scheduled'), findsOneWidget);
      expect(find.textContaining('Tomorrow'), findsOneWidget);
    });

    testWidgets('a booking whose service is gone still opens', (tester) async {
      final backend = FakeBackend()
        ..services = []
        ..bookings = [
          FakeBackend.booking(
            id: '68c1f4aa930b148ed80df6ab',
            status: 'completed',
          ),
        ];
      await _signedIn(tester, backend);
      await _openBookings(tester);

      expect(find.text('Service'), findsOneWidget);
      await tester.tap(find.text('Service'));
      await _settle(tester);

      expect(find.text('Booking ID: SWZ-0DF6AB'), findsOneWidget);
    });

    testWidgets('a failed history load offers a retry that works', (
      tester,
    ) async {
      final backend = FakeBackend()
        ..bookings = [FakeBackend.booking(id: 'b1', status: 'completed')]
        ..bookingsFail = true;
      await _signedIn(tester, backend);
      await _openBookings(tester);

      expect(find.text('Try again'), findsOneWidget);

      backend.bookingsFail = false;
      await tester.tap(find.text('Try again'));
      await _settle(tester);

      expect(find.text('Deep Cleaning'), findsOneWidget);
    });

    testWidgets('pull-to-refresh works on an empty tab too', (tester) async {
      final backend = FakeBackend()
        ..bookings = [FakeBackend.booking(id: 'live')];
      await _signedIn(tester, backend);
      await _openBookings(tester);
      await _openTab(tester, 'Cancelled');
      expect(find.text('No cancelled bookings'), findsOneWidget);

      backend.bookings = [
        ...backend.bookings,
        FakeBackend.booking(id: 'gone', status: 'cancelled'),
      ];
      await tester.fling(
        find.text('No cancelled bookings'),
        const Offset(0, 400),
        1000,
      );
      await _settle(tester);

      expect(find.text('Cancelled (1)'), findsOneWidget);
    });
  });
}
