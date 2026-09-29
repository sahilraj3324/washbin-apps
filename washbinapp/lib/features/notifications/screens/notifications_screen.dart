import 'dart:async';

import 'package:flutter/material.dart';
import 'package:washbinapp/app/app_services_scope.dart';
import 'package:washbinapp/app/router/app_router.dart';
import 'package:washbinapp/core/api/api_exception.dart';
import 'package:washbinapp/core/async/async_controller.dart';
import 'package:washbinapp/core/theme/app_theme.dart';
import 'package:washbinapp/core/widgets/app_empty_view.dart';
import 'package:washbinapp/core/widgets/async_view.dart';
import 'package:washbinapp/features/notifications/domain/app_notification.dart';
import 'package:washbinapp/features/notifications/widgets/notification_tile.dart';

/// The inbox.
///
/// Tapping a booking notification opens tracking, which re-reads the booking
/// from the server — the notification is a pointer, never the current state,
/// so one that has sat in the tray for an hour cannot mislead.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  AsyncController<List<AppNotification>>? _notifications;
  bool _isMarkingAll = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_notifications != null) {
      return;
    }
    final repository = AppServicesScope.of(context).notifications;
    _notifications = AsyncController(repository.getNotifications)..load();
  }

  @override
  void dispose() {
    _notifications?.dispose();
    super.dispose();
  }

  List<AppNotification> get _loaded =>
      _notifications?.state.valueOrNull ?? const [];

  int get _unreadOnScreen =>
      _loaded.where((notification) => !notification.isRead).length;

  Future<void> _open(AppNotification notification) async {
    final services = AppServicesScope.of(context);
    final navigator = Navigator.of(context);

    // Marked read optimistically. The badge and the row should not wait on a
    // round trip that the customer's tap has already settled.
    if (!notification.isRead) {
      _applyRead(notification.id);
      unawaited(_markReadOnServer(notification.id));
    }

    final bookingId = notification.bookingId;
    if (bookingId == null) {
      return;
    }

    await navigator.push(AppRouter.bookingTracking(bookingId: bookingId));
    await services.push.refreshUnreadCount();
  }

  Future<void> _markReadOnServer(String id) async {
    final services = AppServicesScope.of(context);

    try {
      await services.notifications.markRead(id);
    } on ApiException {
      // The row stays read on screen; the next load will correct it if the
      // server disagreed.
    }
  }

  /// Rewrites the loaded list so the tile and the badge update together.
  void _applyRead(String id) {
    final controller = _notifications;
    final current = controller?.state.valueOrNull;

    if (controller == null || current == null) {
      return;
    }

    controller.setValue([
      for (final notification in current)
        notification.id == id ? notification.markedRead() : notification,
    ]);
    AppServicesScope.of(context).push.setUnreadCount(_unreadOnScreen);
  }

  Future<void> _markAllRead() async {
    final services = AppServicesScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isMarkingAll = true);

    try {
      await services.notifications.markAllRead();
      await _notifications?.refresh();
      services.push.setUnreadCount(0);
    } on ApiException catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isMarkingAll = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _notifications!;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        backgroundColor: AppTheme.red,
        foregroundColor: Colors.white,
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0),
        ),
        actions: [
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              if (_unreadOnScreen == 0) {
                return const SizedBox.shrink();
              }
              return TextButton(
                onPressed: _isMarkingAll ? null : _markAllRead,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: Text(_isMarkingAll ? 'Marking...' : 'Mark all read'),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.red,
          onRefresh: () async {
            final push = AppServicesScope.of(context).push;
            await controller.refresh();
            await push.refreshUnreadCount();
          },
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              return AsyncView<List<AppNotification>>(
                state: controller.state,
                onRetry: controller.load,
                loadingLabel: 'Loading notifications',
                isEmpty: (notifications) => notifications.isEmpty,
                empty: const AppEmptyView(
                  title: 'Nothing yet',
                  message: 'Updates about your bookings will show up here.',
                  icon: Icons.notifications_none_rounded,
                ),
                builder: (context, notifications) => ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: notifications.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return NotificationTile(
                      notification: notification,
                      onTap: () => _open(notification),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
