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
  await _settle(tester);
  return services;
}

/// The tab bar scrolls, and under the test font — where every glyph is a
/// full-width box — the later tabs start off-screen.
Future<void> _openTab(WidgetTester tester, String label) async {
  final tab = find.text(label);
  await tester.ensureVisible(tab);
  await _settle(tester);
  await tester.tap(tab);
  await _settle(tester);
}

Future<void> _openBookings(WidgetTester tester) async {
  await tester.tap(find.text('Bookings'));
  await _settle(tester);
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
  testWidgets('the tab loads its own list only once opened', (tester) async {
    // Home reads bookings for its active-booking card, but the tab keeps its
    // own list — and the shell builds every tab up front, so loading on
    // construction would double that cost for a tab nobody may open.
    final backend = FakeBackend();
    await _signedIn(tester, backend);

    final afterHome = backend.requestCounts['/bookings'] ?? 0;
    expect(afterHome, 1);

    await _openBookings(tester);

    expect(backend.requestCounts['/bookings'], afterHome + 1);
  });

  testWidgets('an empty list says so and points at Home', (tester) async {
    await _signedIn(tester, FakeBackend());
    await _openBookings(tester);

    expect(find.text('No bookings yet'), findsOneWidget);
    expect(find.textContaining('Pick a service from Home'), findsOneWidget);
  });

  testWidgets('a booking shows its service, status, time and price', (
    tester,
  ) async {
    final backend = FakeBackend()
      ..bookings = [
        FakeBackend.booking(id: 'b1', notes: 'Please call before arriving'),
      ];
    await _signedIn(tester, backend);
    await _openBookings(tester);

    // The name is joined from the catalogue — a booking carries only an id.
    expect(find.text('Deep Cleaning'), findsOneWidget);
    expect(find.text('Searching for partner'), findsOneWidget);
    expect(find.text('₹299'), findsOneWidget);
    expect(find.textContaining('Mumbai, Maharashtra 400020'), findsOneWidget);
    expect(find.text('Please call before arriving'), findsOneWidget);
  });

  testWidgets('bookings are sorted into tabs, with counts', (tester) async {
    final backend = FakeBackend()
      ..bookings = [
        FakeBackend.booking(id: 'done', status: 'completed'),
        FakeBackend.booking(id: 'live', status: 'searching_partner'),
        FakeBackend.booking(id: 'off', status: 'cancelled'),
        FakeBackend.booking(
          id: 'later',
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

    expect(find.text('Active (1)'), findsOneWidget);
    expect(find.text('Upcoming (1)'), findsOneWidget);
    expect(find.text('Completed (1)'), findsOneWidget);
    expect(find.text('Cancelled (1)'), findsOneWidget);

    // Opens on Active, which has something in it.
    expect(find.text('Searching for partner'), findsOneWidget);
    expect(find.text('This booking is done.'), findsNothing);

    await _openTab(tester, 'Completed (1)');

    expect(find.text('This booking is done.'), findsOneWidget);
    expect(find.text('Searching for partner'), findsNothing);
  });

  testWidgets('an empty tab explains itself', (tester) async {
    final backend = FakeBackend()..bookings = [FakeBackend.booking(id: 'live')];
    await _signedIn(tester, backend);
    await _openBookings(tester);

    await _openTab(tester, 'Cancelled');

    expect(find.text('No cancelled bookings'), findsOneWidget);
  });

  testWidgets('opens on a tab with something in it', (tester) async {
    // A customer whose bookings are all finished should not land on an empty
    // "Active" and conclude they have none.
    final backend = FakeBackend()
      ..bookings = [FakeBackend.booking(id: 'done', status: 'completed')];
    await _signedIn(tester, backend);
    await _openBookings(tester);

    expect(find.text('Deep Cleaning'), findsOneWidget);
    expect(find.text('Nothing in progress'), findsNothing);
  });

  testWidgets('an estimated price is labelled as one', (tester) async {
    final backend = FakeBackend()
      ..bookings = [
        // hourly and starting-from services are settled after the visit.
        FakeBackend.booking(id: 'b1', finalAmount: null),
      ];
    await _signedIn(tester, backend);
    await _openBookings(tester);

    expect(find.textContaining('Estimate'), findsOneWidget);
  });

  testWidgets('a scheduled booking shows when it will happen', (tester) async {
    final when = DateTime.now().add(const Duration(days: 1));
    final backend = FakeBackend()
      ..bookings = [
        FakeBackend.booking(
          id: 'b1',
          bookingType: 'scheduled',
          status: 'pending',
          scheduledAt: when.toUtc().toIso8601String(),
        ),
      ];
    await _signedIn(tester, backend);
    await _openBookings(tester);

    expect(find.text('Scheduled'), findsOneWidget);
    expect(find.textContaining('Tomorrow'), findsOneWidget);
  });

  testWidgets('a service taken down still names its past booking', (
    tester,
  ) async {
    final backend = FakeBackend()
      ..services = [
        FakeBackend.service(
          id: 'svc-1',
          categoryId: 'cat-1',
          name: 'Deep Cleaning',
          basePrice: 299,
          isActive: false,
        ),
      ]
      ..bookings = [FakeBackend.booking(id: 'b1', status: 'completed')];
    await _signedIn(tester, backend);
    await _openBookings(tester);

    expect(find.text('Deep Cleaning'), findsOneWidget);
  });

  group('cancelling', () {
    testWidgets('is offered while the booking can still be called off', (
      tester,
    ) async {
      final backend = FakeBackend()
        ..bookings = [FakeBackend.booking(id: 'b1', status: 'accepted')];
      await _signedIn(tester, backend);
      await _openBookings(tester);

      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('is not offered once the work has started or finished', (
      tester,
    ) async {
      final backend = FakeBackend()
        ..bookings = [
          FakeBackend.booking(id: 'b1', status: 'in_progress'),
          FakeBackend.booking(id: 'b2', status: 'completed'),
        ];
      await _signedIn(tester, backend);
      await _openBookings(tester);

      expect(find.text('Cancel'), findsNothing);
    });

    testWidgets('asks first, and keeping it changes nothing', (tester) async {
      final backend = FakeBackend()..bookings = [FakeBackend.booking(id: 'b1')];
      await _signedIn(tester, backend);
      await _openBookings(tester);

      await tester.tap(find.text('Cancel'));
      await _settle(tester);
      expect(find.text('Cancel this booking?'), findsOneWidget);

      await tester.tap(find.text('Keep it'));
      await _settle(tester);
      expect(backend.bookings.single['status'], 'searching_partner');
    });

    testWidgets('confirming cancels it and moves it to the Cancelled tab', (
      tester,
    ) async {
      final backend = FakeBackend()..bookings = [FakeBackend.booking(id: 'b1')];
      await _signedIn(tester, backend);
      await _openBookings(tester);

      await tester.tap(find.text('Cancel'));
      await _settle(tester);
      await tester.tap(find.text('Cancel booking'));
      await _settle(tester);

      expect(backend.bookings.single['status'], 'cancelled');
      // It leaves the tab it was on and turns up under Cancelled.
      expect(find.text('Nothing in progress'), findsOneWidget);

      await _openTab(tester, 'Cancelled (1)');
      expect(find.text('This booking was cancelled.'), findsOneWidget);
    });

    testWidgets('a booking that moved on is explained, not silently lost', (
      tester,
    ) async {
      final backend = FakeBackend()..bookings = [FakeBackend.booking(id: 'b1')];
      await _signedIn(tester, backend);
      await _openBookings(tester);

      await tester.tap(find.text('Cancel'));
      await _settle(tester);

      // The partner started work while the dialog was open.
      backend.bookings.single['status'] = 'in_progress';
      await tester.tap(find.text('Cancel booking'));
      await _settle(tester);

      expect(find.textContaining('Cannot cancel'), findsOneWidget);
      expect(find.text('Service in progress'), findsOneWidget);
    });
  });

  testWidgets('a booking just created appears on returning to the tab', (
    tester,
  ) async {
    // The tabs are kept alive, so this only works because the shell asks the
    // screen to reload when it is opened.
    final backend = FakeBackend()
      ..addresses = [FakeBackend.address(id: 'addr-1', isDefault: true)];
    await _signedIn(tester, backend);

    await _openBookings(tester);
    expect(find.text('No bookings yet'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await _settle(tester);
    await tester.tap(find.text('Deep Cleaning'));
    await _settle(tester);
    await tester.tap(find.text('Continue'));
    await _settle(tester);
    await tester.tap(find.text('Home'));
    await _settle(tester);
    await tester.tap(find.text('Continue'));
    await _settle(tester);
    await tester.tap(find.text('Review booking'));
    await _settle(tester);
    await tester.tap(find.text('Confirm booking'));
    await _settle(tester);
    await tester.tap(find.text('Done'));
    await _settle(tester);

    await _openBookings(tester);

    expect(find.text('No bookings yet'), findsNothing);
    expect(find.text('Searching for partner'), findsOneWidget);
  });

  testWidgets('a failed load offers a retry that works', (tester) async {
    final backend = FakeBackend()
      ..bookings = [FakeBackend.booking(id: 'b1')]
      ..bookingsFail = true;
    await _signedIn(tester, backend);
    await _openBookings(tester);

    expect(find.text('Try again'), findsOneWidget);

    backend.bookingsFail = false;
    await tester.tap(find.text('Try again'));
    await _settle(tester);

    expect(find.text('Searching for partner'), findsOneWidget);
  });
}
