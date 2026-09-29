import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:washbinapp/core/api/api_exception.dart';
import 'package:washbinapp/features/notifications/data/messaging_service.dart';
import 'package:washbinapp/features/notifications/data/notification_repository.dart';
import 'package:washbinapp/features/notifications/domain/app_notification.dart';

/// Owns push for the signed-in customer: the device registration, the unread
/// badge, and where a tapped notification leads.
///
/// Started only after authentication — a token registered before the app knows
/// whose device it is would deliver one customer's bookings to another's
/// phone — and stopped before the session is torn down, while the access
/// token is still good enough to retire the registration.
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

  /// The FCM token this device is registered with, if any.
  @visibleForTesting
  String? get token => _token;

  /// Where a tapped notification should take the customer. Set by the app
  /// shell, which owns the navigator.
  void Function(PushPayload payload)? onOpenBooking;

  /// Shown as an in-app banner while the app is in the foreground, where the
  /// system tray stays silent.
  void Function(PushPayload payload)? onForeground;

  /// Runs once the customer is authenticated.
  ///
  /// Every step is best-effort: a refused permission, a device with no Play
  /// services, or an offline first launch must not stop the app working. The
  /// inbox is still readable, it just will not interrupt.
  Future<void> start() async {
    if (_isActive) {
      return;
    }
    _isActive = true;

    await _fcm.requestPermission();
    await _registerCurrentToken();

    // Firebase rotates tokens on reinstall and app-data clears. A device that
    // does not re-register silently stops receiving anything.
    _tokenRefresh = _fcm.onTokenRefresh.listen(_register);
    _foreground = _fcm.onForegroundMessage.listen(_handleForeground);
    _opened = _fcm.onNotificationOpened.listen(_handleOpened);

    // A notification that launched the app from terminated.
    final initial = await _fcm.initialMessage();
    if (initial != null) {
      _handleOpened(initial);
    }

    await refreshUnreadCount();
  }

  /// Runs before the session is cleared, so the request still authenticates.
  ///
  /// Retiring the registration is what stops the next person to sign in on
  /// this phone receiving the previous customer's booking updates.
  Future<void> stop() async {
    if (!_isActive) {
      return;
    }
    _isActive = false;

    // Not awaited: these streams have no asynchronous teardown, so the
    // future a cancel returns carries no information, and waiting on it would
    // put three event-loop turns between the customer's tap and being signed
    // out.
    unawaited(_tokenRefresh?.cancel() ?? Future<void>.value());
    unawaited(_foreground?.cancel() ?? Future<void>.value());
    unawaited(_opened?.cancel() ?? Future<void>.value());
    _tokenRefresh = null;
    _foreground = null;
    _opened = null;

    final token = _token;
    if (token != null) {
      // Started, not awaited. The bearer header is attached when the request
      // is built, which happens synchronously here — so the call still
      // authenticates even though the session is cleared moments later.
      //
      // Signing out is a local act and must be instant: holding a customer on
      // "Signing out..." until an unreachable server answers would be worse
      // than a registration that is retired a moment late. Deleting the
      // Firebase token below stops delivery to this device regardless, and
      // the server retires any token FCM later rejects.
      deactivation = _deactivate(token);
    }

    await _fcm.deleteToken();
    _token = null;
    _unreadCount = 0;
    notifyListeners();
  }

  /// The in-flight device retirement from the last [stop], for tests and for
  /// anything that needs to know it landed.
  Future<void>? deactivation;

  Future<void> _deactivate(String token) async {
    try {
      await _inbox.deactivateDevice(token);
    } on ApiException {
      // The session may already be gone. The Firebase token has been dropped
      // either way, so this device receives nothing more.
    }
  }

  Future<void> refreshUnreadCount() async {
    try {
      final unread = await _inbox.getUnreadCount();
      if (unread != _unreadCount) {
        _unreadCount = unread;
        notifyListeners();
      }
    } on ApiException {
      // A badge that cannot be refreshed keeps its last value rather than
      // dropping to zero and hiding real notifications.
    }
  }

  /// Applied locally by the notifications screen, so the badge does not wait
  /// for a round trip to agree with what is on screen.
  void setUnreadCount(int unread) {
    final next = unread < 0 ? 0 : unread;

    if (next != _unreadCount) {
      _unreadCount = next;
      notifyListeners();
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
      // Registration will be retried on the next sign-in or token rotation.
      // Failing here must not block startup.
    }
  }

  void _handleForeground(PushPayload payload) {
    // The push is only a nudge. The badge is re-read from the server rather
    // than incremented locally, so it stays right even if one was missed.
    unawaited(refreshUnreadCount());
    onForeground?.call(payload);
  }

  void _handleOpened(PushPayload payload) {
    unawaited(refreshUnreadCount());

    if (payload.opensBooking) {
      onOpenBooking?.call(payload);
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
