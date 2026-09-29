import 'dart:async';

import 'package:washbinapp/features/notifications/data/messaging_service.dart';
import 'package:washbinapp/features/notifications/domain/app_notification.dart';

/// Stands in for Firebase Cloud Messaging.
///
/// Every method that would reach a platform channel is overridden, and the
/// three message streams are controllers a test can push into — which is what
/// makes the foreground, tap and cold-start paths drivable without a device.
class FakeMessagingService extends MessagingService {
  FakeMessagingService({
    this.currentToken = 'fcm-token-1',
    this.permissionGranted = true,
    this.launchPayload,
  });

  String? currentToken;
  bool permissionGranted;

  /// The notification that "launched the app", for the terminated-state path.
  PushPayload? launchPayload;

  final _tokenRefresh = StreamController<String>.broadcast();
  final _foreground = StreamController<PushPayload>.broadcast();
  final _opened = StreamController<PushPayload>.broadcast();

  var permissionRequests = 0;
  var tokenDeletions = 0;

  @override
  String get platform => 'android';

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<String?> getToken() async => currentToken;

  @override
  Stream<String> get onTokenRefresh => _tokenRefresh.stream;

  @override
  Stream<PushPayload> get onForegroundMessage => _foreground.stream;

  @override
  Stream<PushPayload> get onNotificationOpened => _opened.stream;

  @override
  Future<PushPayload?> initialMessage() async => launchPayload;

  @override
  Future<void> deleteToken() async {
    tokenDeletions++;
    currentToken = null;
  }

  /// Firebase rotating this device's token.
  void rotateToken(String token) {
    currentToken = token;
    _tokenRefresh.add(token);
  }

  /// A push arriving with the app open.
  void deliverForeground(PushPayload payload) => _foreground.add(payload);

  /// The customer tapping a tray notification.
  void deliverTap(PushPayload payload) => _opened.add(payload);

  void dispose() {
    _tokenRefresh.close();
    _foreground.close();
    _opened.close();
  }
}
