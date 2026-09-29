import 'dart:async';

import 'package:flutter/material.dart';
import 'package:washbinpartner/app/app_services_scope.dart';
import 'package:washbinpartner/core/api/api_exception.dart';
import 'package:washbinpartner/core/theme/app_theme.dart';
import 'package:washbinpartner/features/notifications/data/notification_repository.dart';
import 'package:washbinpartner/features/notifications/domain/app_notification.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.onOpenJob});

  final VoidCallback? onOpenJob;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _pageSize = NotificationRepository.pageSize;

  final _notifications = <AppNotification>[];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _isMarkingAll = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool append = false}) async {
    final services = AppServicesScope.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      if (append) {
        _isLoadingMore = true;
      } else {
        _isLoading = true;
      }
    });
    try {
      final rows = await services.notifications.getNotifications(
        limit: _pageSize,
        skip: append ? _notifications.length : 0,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        if (!append) {
          _notifications.clear();
        }
        _notifications.addAll(rows);
        _hasMore = rows.length == _pageSize;
      });
      await services.push.refreshUnreadCount();
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMore() {
    if (_isLoading || _isLoadingMore || !_hasMore) {
      return Future.value();
    }
    return _load(append: true);
  }

  Future<void> _open(AppNotification notification) async {
    final services = AppServicesScope.of(context);

    if (!notification.isRead) {
      _applyRead(notification.id);
      unawaited(services.notifications.markRead(notification.id));
    }

    if (notification.opensJob) {
      widget.onOpenJob?.call();
    }
  }

  void _applyRead(String id) {
    setState(() {
      for (var i = 0; i < _notifications.length; i++) {
        if (_notifications[i].id == id) {
          _notifications[i] = _notifications[i].markedRead();
        }
      }
    });
    final unread = _notifications.where((row) => !row.isRead).length;
    AppServicesScope.of(context).push.setUnreadCount(unread);
  }

  Future<void> _markAllRead() async {
    final services = AppServicesScope.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isMarkingAll = true);
    try {
      await services.notifications.markAllRead();
      setState(() {
        for (var i = 0; i < _notifications.length; i++) {
          _notifications[i] = _notifications[i].markedRead();
        }
      });
      services.push.setUnreadCount(0);
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _isMarkingAll = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifications.where((row) => !row.isRead).length;

    return RefreshIndicator(
      color: AppTheme.red,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Row(
            children: [
              const _IconBadge(
                icon: Icons.notifications_rounded,
                color: AppTheme.red,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Notifications',
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
              if (unread > 0)
                TextButton(
                  onPressed: _isMarkingAll ? null : _markAllRead,
                  child: Text(_isMarkingAll ? 'Marking...' : 'Mark all read'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading && _notifications.isEmpty)
            const _Panel(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
              ),
            )
          else if (_notifications.isEmpty)
            const _EmptyNotifications()
          else
            for (final notification in _notifications) ...[
              _NotificationCard(
                notification: notification,
                onTap: () => _open(notification),
              ),
              if (notification != _notifications.last)
                const SizedBox(height: 10),
            ],
          if (_notifications.isNotEmpty && _hasMore) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _isLoadingMore ? null : _loadMore,
              icon: _isLoadingMore
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more_rounded),
              label: Text(_isLoadingMore ? 'Loading...' : 'Load more'),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: _Panel(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IconBadge(icon: notification.type.icon, color: AppTheme.red),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      color: AppTheme.ink,
                      fontSize: 15,
                      fontWeight: notification.isRead
                          ? FontWeight.w700
                          : FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  if (notification.age.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      notification.age,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!notification.isRead)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.red,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return const _Panel(
      child: Column(
        children: [
          _IconBadge(
            icon: Icons.notifications_none_rounded,
            color: AppTheme.red,
          ),
          SizedBox(height: 12),
          Text(
            'Nothing yet',
            style: TextStyle(
              color: AppTheme.ink,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Job requests and booking updates will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: child,
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}
