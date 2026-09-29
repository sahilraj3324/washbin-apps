import 'package:flutter_test/flutter_test.dart';
import 'package:washbinapp/app/app_services.dart';
import 'package:washbinapp/core/session/session_controller.dart';
import 'package:washbinapp/features/notifications/domain/app_notification.dart';

import '../support/fake_backend.dart';
import '../support/fake_messaging_service.dart';
import '../support/fake_phone_auth_service.dart';

({AppServices services, FakeMessagingService fcm}) _build(
  FakeBackend backend, {
  FakePhoneAuthService? phoneAuth,
  FakeMessagingService? messaging,
}) {
  final fcm = messaging ?? FakeMessagingService();
  addTearDown(fcm.dispose);

  final services = AppServices(
    httpClient: backend.client,
    phoneAuthService:
        phoneAuth ?? FakePhoneAuthService(storedIdToken: 'stored-id-token'),
    messagingService: fcm,
    baseUrl: 'https://api.test',
    trackingPollInterval: null,
  );
  addTearDown(services.dispose);

  return (services: services, fcm: fcm);
}

void main() {
  group('registration', () {
    test('happens only after the customer is authenticated', () async {
      // A token registered before the app knows whose device this is would
      // deliver one customer's bookings to another's phone.
      final backend = FakeBackend()..requiresProfile = false;
      final built = _build(backend);

      expect(backend.devices, isEmpty);

      await built.services.session.start(holdSplash: false);
      await Future<void>.delayed(Duration.zero);

      expect(built.services.session.isSignedIn, isTrue);
      expect(backend.devices.keys, ['fcm-token-1']);
      expect(backend.devices['fcm-token-1']!.isActive, isTrue);
      expect(backend.devices['fcm-token-1']!.platform, 'android');
    });

    test('does not happen for a customer who never signs in', () async {
      final backend = FakeBackend();
      final built = _build(backend, phoneAuth: FakePhoneAuthService());

      await built.services.session.start(holdSplash: false);
      await Future<void>.delayed(Duration.zero);

      expect(built.services.session.status, SessionStatus.unauthenticated);
      expect(backend.devices, isEmpty);
    });

    test('asks for permission, and carries on when refused', () async {
      // A refusal is not an error: the inbox still works, it just cannot
      // interrupt the customer.
      final backend = FakeBackend()..requiresProfile = false;
      final fcm = FakeMessagingService(permissionGranted: false);
      final built = _build(backend, messaging: fcm);

      await built.services.session.start(holdSplash: false);
      await Future<void>.delayed(Duration.zero);

      expect(fcm.permissionRequests, 1);
      expect(built.services.session.isSignedIn, isTrue);
    });

    test('a device with no token registers nothing and still works', () async {
      // No Play services, or an offline first launch.
      final backend = FakeBackend()..requiresProfile = false;
      final built = _build(
        backend,
        messaging: FakeMessagingService(currentToken: null),
      );

      await built.services.session.start(holdSplash: false);
      await Future<void>.delayed(Duration.zero);

      expect(backend.devices, isEmpty);
      expect(built.services.session.isSignedIn, isTrue);
    });

    test('a rotated token is re-registered', () async {
      // Firebase rotates on reinstall and app-data clear. A device that does
      // not re-register silently stops receiving anything.
      final backend = FakeBackend()..requiresProfile = false;
      final built = _build(backend);
      await built.services.session.start(holdSplash: false);
      await Future<void>.delayed(Duration.zero);

      built.fcm.rotateToken('fcm-token-2');
      await Future<void>.delayed(Duration.zero);

      expect(backend.devices.keys, containsAll(['fcm-token-1', 'fcm-token-2']));
      expect(backend.devices['fcm-token-2']!.isActive, isTrue);
      expect(built.services.push.token, 'fcm-token-2');
    });
  });

  group('sign out', () {
    test('retires the device before the session is cleared', () async {
      // The request needs the access token, so ordering is the whole point:
      // otherwise the next customer on this phone keeps receiving the
      // previous one's booking updates.
      final backend = FakeBackend()..requiresProfile = false;
      final built = _build(backend);
      await built.services.session.start(holdSplash: false);
      await Future<void>.delayed(Duration.zero);
      expect(backend.devices['fcm-token-1']!.isActive, isTrue);

      await built.services.session.signOut();
      // Started during sign-out rather than awaited by it, so that an
      // unreachable server cannot hold the customer on "Signing out...".
      await built.services.push.deactivation;

      expect(backend.devices['fcm-token-1']!.isActive, isFalse);
      expect(built.services.tokens.hasToken, isFalse);
    });

    test('drops the Firebase token too', () async {
      final backend = FakeBackend()..requiresProfile = false;
      final built = _build(backend);
      await built.services.session.start(holdSplash: false);
      await Future<void>.delayed(Duration.zero);

      await built.services.session.signOut();

      expect(built.fcm.tokenDeletions, 1);
      expect(built.services.push.token, isNull);
    });

    test('a failure retiring the device never blocks signing out', () async {
      final backend = FakeBackend()..requiresProfile = false;
      final built = _build(backend);
      await built.services.session.start(holdSplash: false);
      await Future<void>.delayed(Duration.zero);

      backend.notificationsFail = true;
      await built.services.session.signOut();
      await built.services.push.deactivation;

      expect(built.services.session.status, SessionStatus.unauthenticated);
    });

    test('clears the unread badge', () async {
      final backend = FakeBackend()
        ..requiresProfile = false
        ..notifications = [FakeBackend.notification(id: 'n1')];
      final built = _build(backend);
      await built.services.session.start(holdSplash: false);
      await Future<void>.delayed(Duration.zero);
      expect(built.services.push.unreadCount, 1);

      await built.services.session.signOut();

      expect(built.services.push.unreadCount, 0);
    });
  });

  group('the unread badge', () {
    test('is read from the server on sign-in', () async {
      final backend = FakeBackend()
        ..requiresProfile = false
        ..notifications = [
          FakeBackend.notification(id: 'n1'),
          FakeBackend.notification(id: 'n2'),
          FakeBackend.notification(id: 'n3', isRead: true),
        ];
      final built = _build(backend);

      await built.services.session.start(holdSplash: false);
      await Future<void>.delayed(Duration.zero);

      expect(built.services.push.unreadCount, 2);
      expect(built.services.push.hasUnread, isTrue);
    });

    test('is re-read when a push arrives, not incremented locally', () async {
      // Counting locally drifts the moment one push is missed.
      final backend = FakeBackend()..requiresProfile = false;
      final built = _build(backend);
      await built.services.session.start(holdSplash: false);
      await Future<void>.delayed(Duration.zero);
      expect(built.services.push.unreadCount, 0);

      backend.notifications = [
        FakeBackend.notification(id: 'n1'),
        FakeBackend.notification(id: 'n2'),
      ];
      built.fcm.deliverForeground(
        const PushPayload(type: 'PARTNER_ACCEPTED', bookingId: 'b1'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(built.services.push.unreadCount, 2);
    });

    test('keeps its last value when the count cannot be refreshed', () async {
      // Dropping to zero would hide notifications that really are there.
      final backend = FakeBackend()
        ..requiresProfile = false
        ..notifications = [FakeBackend.notification(id: 'n1')];
      final built = _build(backend);
      await built.services.session.start(holdSplash: false);
      await Future<void>.delayed(Duration.zero);
      expect(built.services.push.unreadCount, 1);

      backend.notificationsFail = true;
      await built.services.push.refreshUnreadCount();

      expect(built.services.push.unreadCount, 1);
    });
  });

  group('message routing', () {
    test('a tapped booking notification is routed', () async {
      final backend = FakeBackend()..requiresProfile = false;
      final built = _build(backend);
      final opened = <String?>[];
      built.services.push.onOpenBooking = (payload) =>
          opened.add(payload.bookingId);

      await built.services.session.start(holdSplash: false);
      await Future<void>.delayed(Duration.zero);

      built.fcm.deliverTap(
        const PushPayload(type: 'PARTNER_ARRIVED', bookingId: 'booking-9'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(opened, ['booking-9']);
    });

    test('a notification with no booking routes nowhere', () async {
      final backend = FakeBackend()..requiresProfile = false;
      final built = _build(backend);
      var opened = 0;
      built.services.push.onOpenBooking = (_) => opened++;

      await built.services.session.start(holdSplash: false);
      await Future<void>.delayed(Duration.zero);

      built.fcm.deliverTap(const PushPayload(type: 'PROMO'));
      await Future<void>.delayed(Duration.zero);

      expect(opened, 0);
    });

    test('a notification that launched the app is routed on startup', () async {
      // The terminated-app path: the tap happened before anything was running.
      final backend = FakeBackend()..requiresProfile = false;
      final built = _build(
        backend,
        messaging: FakeMessagingService(
          launchPayload: const PushPayload(
            type: 'SERVICE_COMPLETED',
            bookingId: 'booking-cold',
          ),
        ),
      );
      final opened = <String?>[];
      built.services.push.onOpenBooking = (payload) =>
          opened.add(payload.bookingId);

      await built.services.session.start(holdSplash: false);
      await Future<void>.delayed(Duration.zero);

      expect(opened, ['booking-cold']);
    });

    test('a foreground push is handed to the in-app banner', () async {
      // The system tray stays silent while the app is open.
      final backend = FakeBackend()..requiresProfile = false;
      final built = _build(backend);
      final banners = <String?>[];
      built.services.push.onForeground = (payload) =>
          banners.add(payload.title);

      await built.services.session.start(holdSplash: false);
      await Future<void>.delayed(Duration.zero);

      built.fcm.deliverForeground(
        const PushPayload(
          type: 'PARTNER_ON_THE_WAY',
          bookingId: 'b1',
          title: 'On the way',
          body: 'Your partner is on the way.',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(banners, ['On the way']);
    });
  });
}
