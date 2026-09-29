import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:washbinapp/features/notifications/domain/app_notification.dart';

/// Firebase Cloud Messaging, behind methods the app can stub.
///
/// Wraps the plugin rather than letting features call it, so the notification
/// flow can be driven end to end in a test with no Firebase, no platform
/// channels, and no real device.
class MessagingService {
  MessagingService();

  /// Resolved on use so constructing the service does not itself require
  /// Firebase to be initialised.
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  /// What the API's `platform` field expects.
  String get platform {
    if (kIsWeb) {
      return 'web';
    }
    return Platform.isIOS ? 'ios' : 'android';
  }

  /// Asks for permission to show notifications.
  ///
  /// Required on iOS always, and on Android from 13. Returns false when the
  /// customer said no — which is not an error: the app still works, it just
  /// cannot interrupt them.
  Future<bool> requestPermission() async {
    try {
      final settings = await _messaging.requestPermission();
      final status = settings.authorizationStatus;

      return status == AuthorizationStatus.authorized ||
          status == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  /// This device's FCM token, or null when one cannot be obtained — no Google
  /// Play services, no network at first launch, or permission refused.
  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  /// Fires when Firebase rotates the token, which it does on reinstall, app
  /// data clear, and periodically. The new token must be re-registered or the
  /// device silently stops receiving anything.
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  /// Messages arriving while the app is in the foreground. The system tray
  /// does not show these, so the app has to.
  Stream<PushPayload> get onForegroundMessage =>
      FirebaseMessaging.onMessage.map(_toPayload);

  /// A tray notification the customer tapped while the app was backgrounded.
  Stream<PushPayload> get onNotificationOpened =>
      FirebaseMessaging.onMessageOpenedApp.map(_toPayload);

  /// The notification that launched the app from terminated, if any.
  Future<PushPayload?> initialMessage() async {
    try {
      final message = await _messaging.getInitialMessage();
      return message == null ? null : _toPayload(message);
    } catch (_) {
      return null;
    }
  }

  /// Drops this device's token, so a signed-out phone stops receiving push
  /// even before the backend row is retired.
  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
    } catch (_) {
      // Nothing to delete, or Firebase unavailable. The backend
      // deactivation is what actually stops delivery.
    }
  }

  static PushPayload _toPayload(RemoteMessage message) => PushPayload.fromData(
    message.data,
    title: message.notification?.title,
    body: message.notification?.body,
  );
}
