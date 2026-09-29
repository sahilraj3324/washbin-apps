import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washbinapp/app/app_services.dart';
import 'package:washbinapp/app/washbin_app.dart';
import 'package:washbinapp/features/notifications/domain/app_notification.dart';

import '../support/fake_backend.dart';
import '../support/fake_location_service.dart';
import '../support/fake_messaging_service.dart';
import '../support/fake_phone_auth_service.dart';

/// `pumpAndSettle` cannot be used once a searching booking is on screen, and
/// several of these tests put one there.
Future<void> _settle(WidgetTester tester) async {
  for (var frame = 0; frame < 14; frame++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

({AppServices services, FakeMessagingService fcm}) _servicesFor(
  FakeBackend backend,
) {
  final fcm = FakeMessagingService();
  addTearDown(fcm.dispose);

  backend.requiresProfile = false;
  return (
    services: AppServices(
      httpClient: backend.client,
      phoneAuthService: FakePhoneAuthService(storedIdToken: 'stored-id-token'),
      locationService: FakeLocationService(),
      messagingService: fcm,
      baseUrl: 'https://api.test',
      trackingPollInterval: null,
    ),
    fcm: fcm,
  );
}

Future<({AppServices services, FakeMessagingService fcm})> _signedIn(
  WidgetTester tester,
  FakeBackend backend,
) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final built = _servicesFor(backend);
  await tester.pumpWidget(WashbinApp(services: built.services));
  await tester.pump(const Duration(milliseconds: 3200));
  await _settle(tester);
  return built;
}

Future<void> _openInbox(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.notifications_none_rounded));
  await _settle(tester);
}

void main() {
  group('the badge', () {
    testWidgets('appears on Home with the unread count', (tester) async {
      final backend = FakeBackend()
        ..notifications = [
          FakeBackend.notification(id: 'n1'),
          FakeBackend.notification(id: 'n2'),
          FakeBackend.notification(id: 'n3', isRead: true),
        ];
      await _signedIn(tester, backend);

      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('is absent when everything has been read', (tester) async {
      final backend = FakeBackend()
        ..notifications = [FakeBackend.notification(id: 'n1', isRead: true)];
      await _signedIn(tester, backend);

      expect(find.text('0'), findsNothing);
      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    });
  });

  group('the inbox', () {
    testWidgets('lists notifications newest first', (tester) async {
      final backend = FakeBackend()
        ..notifications = [
          FakeBackend.notification(
            id: 'old',
            type: 'SERVICE_COMPLETED',
            title: 'Service completed',
            createdAt: DateTime.now()
                .subtract(const Duration(hours: 1))
                .toUtc()
                .toIso8601String(),
          ),
          FakeBackend.notification(id: 'new', title: 'Partner assigned'),
        ];
      await _signedIn(tester, backend);
      await _openInbox(tester);

      expect(find.text('Partner assigned'), findsOneWidget);
      expect(find.text('Service completed'), findsOneWidget);
      expect(find.text('2 min ago'), findsOneWidget);
      expect(find.text('1 hour ago'), findsOneWidget);
    });

    testWidgets('an empty inbox says so', (tester) async {
      await _signedIn(tester, FakeBackend());
      await _openInbox(tester);

      expect(find.text('Nothing yet'), findsOneWidget);
      expect(find.text('Mark all read'), findsNothing);
    });

    testWidgets('a failed load offers a retry that works', (tester) async {
      final backend = FakeBackend()
        ..notifications = [FakeBackend.notification(id: 'n1')];
      await _signedIn(tester, backend);

      backend.notificationsFail = true;
      await _openInbox(tester);
      expect(find.text('Try again'), findsOneWidget);

      backend.notificationsFail = false;
      await tester.tap(find.text('Try again'));
      await _settle(tester);

      expect(find.text('Partner assigned'), findsOneWidget);
    });
  });

  group('marking read', () {
    testWidgets('tapping one marks it read and drops the badge', (
      tester,
    ) async {
      final backend = FakeBackend()
        ..notifications = [
          FakeBackend.notification(id: 'n1', bookingId: null),
          FakeBackend.notification(id: 'n2', bookingId: null),
        ];
      final built = await _signedIn(tester, backend);
      expect(built.services.push.unreadCount, 2);

      await _openInbox(tester);
      await tester.tap(find.text('Partner assigned').first);
      await _settle(tester);

      expect(backend.notifications.last['isRead'], isTrue);
      expect(built.services.push.unreadCount, 1);
    });

    testWidgets('mark all read clears every row and the badge', (tester) async {
      final backend = FakeBackend()
        ..notifications = [
          FakeBackend.notification(id: 'n1'),
          FakeBackend.notification(id: 'n2'),
        ];
      final built = await _signedIn(tester, backend);
      await _openInbox(tester);

      await tester.tap(find.text('Mark all read'));
      await _settle(tester);

      expect(
        backend.notifications.every((row) => row['isRead'] == true),
        isTrue,
      );
      expect(built.services.push.unreadCount, 0);
      expect(find.text('Mark all read'), findsNothing);
    });

    testWidgets('mark all read is not offered when nothing is unread', (
      tester,
    ) async {
      final backend = FakeBackend()
        ..notifications = [FakeBackend.notification(id: 'n1', isRead: true)];
      await _signedIn(tester, backend);
      await _openInbox(tester);

      expect(find.text('Mark all read'), findsNothing);
    });
  });

  group('opening a booking', () {
    testWidgets('a booking notification opens tracking, freshly read', (
      tester,
    ) async {
      // The notification says "Partner assigned"; the server says the partner
      // is already on the way. What the customer sees is the server's answer.
      final backend = FakeBackend()
        ..bookings = [
          {
            ...FakeBackend.booking(
              id: '68c1f4aa930b148ed80df6ab',
              status: 'on_the_way',
            ),
            'assignedPartnerId': 'partner-1',
            'onTheWayAt': '2026-09-13T10:05:00.000Z',
          },
        ]
        ..notifications = [
          FakeBackend.notification(id: 'n1', title: 'Partner assigned'),
        ];
      await _signedIn(tester, backend);
      await _openInbox(tester);

      await tester.tap(find.text('Partner assigned'));
      await _settle(tester);

      expect(find.text('Booking ID: SWZ-0DF6AB'), findsOneWidget);
      // The server's status wins over the notification's headline.
      expect(find.text('On the way'), findsWidgets);
      expect(
        find.text('Your service professional has accepted your request.'),
        findsNothing,
      );
    });

    testWidgets('a push tapped from the tray opens the right booking', (
      tester,
    ) async {
      final backend = FakeBackend()
        ..bookings = [
          FakeBackend.booking(
            id: '68c1f4aa930b148ed80df6ab',
            status: 'arrived',
          ),
        ];
      final built = await _signedIn(tester, backend);

      built.fcm.deliverTap(
        const PushPayload(
          type: 'PARTNER_ARRIVED',
          bookingId: '68c1f4aa930b148ed80df6ab',
        ),
      );
      await _settle(tester);

      expect(find.text('Booking ID: SWZ-0DF6AB'), findsOneWidget);
      expect(find.text('Arrived'), findsWidgets);
    });

    testWidgets('a foreground push shows a banner rather than a screen', (
      tester,
    ) async {
      final backend = FakeBackend()
        ..bookings = [
          FakeBackend.booking(
            id: '68c1f4aa930b148ed80df6ab',
            status: 'arrived',
          ),
        ];
      final built = await _signedIn(tester, backend);

      built.fcm.deliverForeground(
        const PushPayload(
          type: 'PARTNER_ARRIVED',
          bookingId: '68c1f4aa930b148ed80df6ab',
          title: 'Partner arrived',
          body: 'Your service professional has arrived.',
        ),
      );
      await _settle(tester);

      expect(find.text('Partner arrived'), findsOneWidget);
      expect(find.text('View'), findsOneWidget);
      // It interrupts, it does not navigate.
      expect(find.text('What do you need?'), findsOneWidget);

      await tester.tap(find.text('View'));
      await _settle(tester);
      expect(find.text('Booking ID: SWZ-0DF6AB'), findsOneWidget);
    });
  });
}
