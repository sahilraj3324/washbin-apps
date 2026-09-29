import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:washbinpartner/core/api/api_exception.dart';
import 'package:washbinpartner/features/notifications/data/messaging_service.dart';
import 'package:washbinpartner/features/notifications/data/notification_repository.dart';
import 'package:washbinpartner/features/notifications/domain/app_notification.dart';

class PushNotifications extends ChangeNotifier {
  PushNotifications({
    required NotificationRepository repository,
    required MessagingService messaging,
  }) : _inbox = repository,
       _fcm = messaging;

  final NotificationRepository _inbox;
  final MessagingService _fcm;

  StreamSubscription<String>? _tokenRefresh;
  StreamSubscription<PushPayload>? _foreground;
  StreamSubscription<PushPayload>? _opened;

  String? _token;
  int _unreadCount = 0;
  bool _isActive = false;

  int get unreadCount => _unreadCount;
  bool get hasUnread => _unreadCount > 0;

  @visibleForTesting
  String? get token => _token;

  void Function(PushPayload payload)? onOpenJob;
  void Function(PushPayload payload)? onForeground;
  Future<void>? deactivation;

  Future<void> start() async {
    if (_isActive) {
      return;
    }
    _isActive = true;

    await _fcm.requestPermission();
    await _registerCurrentToken();

    _tokenRefresh = _fcm.onTokenRefresh.listen(_register);
    _foreground = _fcm.onForegroundMessage.listen(_handleForeground);
    _opened = _fcm.onNotificationOpened.listen(_handleOpened);

    final initial = await _fcm.initialMessage();
    if (initial != null) {
      _handleOpened(initial);
    }

    await refreshUnreadCount();
  }

  Future<void> stop() async {
    if (!_isActive) {
      return;
    }
    _isActive = false;

    unawaited(_tokenRefresh?.cancel() ?? Future<void>.value());
    unawaited(_foreground?.cancel() ?? Future<void>.value());
    unawaited(_opened?.cancel() ?? Future<void>.value());
    _tokenRefresh = null;
    _foreground = null;
    _opened = null;

    final token = _token;
    if (token != null) {
      deactivation = _deactivate(token);
    }

    await _fcm.deleteToken();
    _token = null;
    _unreadCount = 0;
    notifyListeners();
  }

  Future<void> refreshUnreadCount() async {
    try {
      final unread = await _inbox.getUnreadCount();
      if (unread != _unreadCount) {
        _unreadCount = unread;
        notifyListeners();
      }
    } on ApiException {
      // Keep the last known badge rather than hiding real unread rows.
    }
  }

  void setUnreadCount(int unread) {
    final next = unread < 0 ? 0 : unread;
    if (next != _unreadCount) {
      _unreadCount = next;
      notifyListeners();
    }
  }

  Future<void> _deactivate(String token) async {
    try {
      await _inbox.deactivateDevice(token);
    } on ApiException {
      // Firebase token deletion still stops this device locally.
    }
  }

  Future<void> _registerCurrentToken() async {
    final token = await _fcm.getToken();
    if (token != null) {
      await _register(token);
    }
  }

  Future<void> _register(String token) async {
    try {
      await _inbox.registerDevice(token: token, platform: _fcm.platform);
      _token = token;
    } on ApiException {
      // Retried on next sign-in or FCM token refresh.
    }
  }

  void _handleForeground(PushPayload payload) {
    unawaited(refreshUnreadCount());
    onForeground?.call(payload);
  }

  void _handleOpened(PushPayload payload) {
    unawaited(refreshUnreadCount());
    if (payload.opensJob) {
      onOpenJob?.call(payload);
    }
  }

  @override
  void dispose() {
    _tokenRefresh?.cancel();
    _foreground?.cancel();
    _opened?.cancel();
    super.dispose();
  }
}
