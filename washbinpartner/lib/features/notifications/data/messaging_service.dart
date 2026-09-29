import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:washbinpartner/features/notifications/domain/app_notification.dart';

class MessagingService {
  MessagingService();

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  String get platform {
    if (kIsWeb) {
      return 'web';
    }
    return Platform.isIOS ? 'ios' : 'android';
  }

  Future<bool> requestPermission() async {
    try {
      final settings = await _messaging.requestPermission();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  Stream<PushPayload> get onForegroundMessage =>
      FirebaseMessaging.onMessage.map(_toPayload);

  Stream<PushPayload> get onNotificationOpened =>
      FirebaseMessaging.onMessageOpenedApp.map(_toPayload);

  Future<PushPayload?> initialMessage() async {
    try {
      final message = await _messaging.getInitialMessage();
      return message == null ? null : _toPayload(message);
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
    } catch (_) {}
  }

  static PushPayload _toPayload(RemoteMessage message) => PushPayload.fromData(
    message.data,
    title: message.notification?.title,
    body: message.notification?.body,
  );
}
