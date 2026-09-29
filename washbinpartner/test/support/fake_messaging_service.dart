import 'dart:async';

import 'package:washbinpartner/features/notifications/data/messaging_service.dart';
import 'package:washbinpartner/features/notifications/domain/app_notification.dart';

class FakeMessagingService extends MessagingService {
  FakeMessagingService({this.initialToken = 'test-fcm-token'});

  final String? initialToken;
  final tokenRefreshController = StreamController<String>.broadcast();
  final foregroundController = StreamController<PushPayload>.broadcast();
  final openedController = StreamController<PushPayload>.broadcast();
  var permissionRequests = 0;
  var deleteTokenCalls = 0;

  @override
  String get platform => 'android';

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return true;
  }

  @override
  Future<String?> getToken() async => initialToken;

  @override
  Stream<String> get onTokenRefresh => tokenRefreshController.stream;

  @override
  Stream<PushPayload> get onForegroundMessage => foregroundController.stream;

  @override
  Stream<PushPayload> get onNotificationOpened => openedController.stream;

  @override
  Future<PushPayload?> initialMessage() async => null;

  @override
  Future<void> deleteToken() async {
    deleteTokenCalls++;
  }
}
