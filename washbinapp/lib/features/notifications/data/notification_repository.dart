import 'package:washbinapp/core/api/api_client.dart';
import 'package:washbinapp/features/notifications/domain/app_notification.dart';

/// The signed-in user's notification inbox, and this device's push
/// registration.
///
/// Every route is behind the bearer token and scoped by it, so a notification
/// belonging to someone else reads as a 404 rather than a 403.
class NotificationRepository {
  NotificationRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// The server defaults to 50 and caps at 100.
  static const pageSize = 50;

  Future<List<AppNotification>> getNotifications({int limit = pageSize}) async {
    final json = await _api.getJsonList(
      '/notifications',
      query: {'limit': '$limit'},
    );

    return json
        .cast<Map<String, dynamic>>()
        .map(AppNotification.fromJson)
        .toList(growable: false);
  }

  Future<int> getUnreadCount() async {
    final json = await _api.getJson('/notifications/unread-count');
    return json['unread'] as int? ?? 0;
  }

  Future<AppNotification> markRead(String id) async {
    return AppNotification.fromJson(
      await _api.patchJson('/notifications/$id/read', {}),
    );
  }

  /// Returns how many were still unread.
  Future<int> markAllRead() async {
    final json = await _api.patchJson('/notifications/read-all', {});
    return json['updated'] as int? ?? 0;
  }

  /// Registers this device for push.
  ///
  /// Upserted on the token, so re-registering the same device refreshes it
  /// rather than piling up duplicates.
  Future<void> registerDevice({
    required String token,
    required String platform,
  }) async {
    await _api.postJson('/notifications/device-token', {
      'token': token,
      'platform': platform,
    });
  }

  /// Stops push to this device. The row is retired, not deleted.
  ///
  /// Must be called while the session is still valid — once the access token
  /// is gone there is no way to say which device to retire.
  Future<void> deactivateDevice(String token) async {
    await _api.delete('/notifications/device-token', {'token': token});
  }
}
