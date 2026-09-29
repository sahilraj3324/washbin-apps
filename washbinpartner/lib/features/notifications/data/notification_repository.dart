import 'package:washbinpartner/core/api/api_client.dart';
import 'package:washbinpartner/features/notifications/domain/app_notification.dart';

class NotificationRepository {
  NotificationRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  static const pageSize = 50;

  Future<List<AppNotification>> getNotifications({
    int limit = pageSize,
    int skip = 0,
  }) async {
    final json = await _api.getJsonList(
      '/notifications',
      query: {'limit': '$limit', 'skip': '$skip'},
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

  Future<int> markAllRead() async {
    final json = await _api.patchJson('/notifications/read-all', {});
    return json['updated'] as int? ?? 0;
  }

  Future<void> registerDevice({
    required String token,
    required String platform,
  }) async {
    await _api.postJson('/notifications/device-token', {
      'token': token,
      'platform': platform,
    });
  }

  Future<void> deactivateDevice(String token) async {
    await _api.delete('/notifications/device-token', {'token': token});
  }
}
