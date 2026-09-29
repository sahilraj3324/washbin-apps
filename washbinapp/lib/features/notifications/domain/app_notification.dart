import 'package:flutter/material.dart';
import 'package:washbinapp/features/catalogue/domain/json_field.dart';

/// The notification kinds the API sends a customer.
///
/// `PARTNER_ASSIGNED` is absent on purpose: the server's template for it is
/// empty, because a declined offer re-enters that state and would ping the
/// customer once per decline. The "Partner assigned" copy they do see arrives
/// as [partnerAccepted].
enum NotificationType {
  bookingCreated('BOOKING_CREATED'),
  partnerAccepted('PARTNER_ACCEPTED'),
  partnerOnTheWay('PARTNER_ON_THE_WAY'),
  partnerArrived('PARTNER_ARRIVED'),
  serviceStarted('SERVICE_STARTED'),
  serviceCompleted('SERVICE_COMPLETED'),
  bookingCancelled('BOOKING_CANCELLED'),
  noPartnerFound('NO_PARTNER_FOUND'),
  other('OTHER');

  const NotificationType(this.wireValue);

  final String wireValue;

  static NotificationType parse(Object? value) {
    for (final type in NotificationType.values) {
      if (type.wireValue == value) {
        return type;
      }
    }
    // An unknown type still has a title and body worth showing, so it is
    // never dropped — only drawn with a neutral icon.
    return NotificationType.other;
  }

  IconData get icon => switch (this) {
    NotificationType.bookingCreated => Icons.receipt_long_rounded,
    NotificationType.partnerAccepted => Icons.person_pin_circle_rounded,
    NotificationType.partnerOnTheWay => Icons.directions_run_rounded,
    NotificationType.partnerArrived => Icons.home_rounded,
    NotificationType.serviceStarted => Icons.play_circle_fill_rounded,
    NotificationType.serviceCompleted => Icons.verified_rounded,
    NotificationType.bookingCancelled => Icons.cancel_rounded,
    NotificationType.noPartnerFound => Icons.person_off_rounded,
    NotificationType.other => Icons.notifications_rounded,
  };
}

/// A stored notification, as `GET /notifications` describes it.
///
/// Named `AppNotification` because `Notification` is a Flutter framework class
/// and shadowing it would make every widget file ambiguous.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    this.bookingId,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: JsonField.id(json),
      type: NotificationType.parse(json['type']),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      isRead: json['isRead'] as bool? ?? false,
      bookingId: json['bookingId'] == null
          ? null
          : JsonField.text(JsonField.reference(json['bookingId'])),
      createdAt: _dateTime(json['createdAt']),
    );
  }

  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final bool isRead;
  final String? bookingId;
  final DateTime? createdAt;

  /// Whether tapping this should open something.
  bool get opensBooking => bookingId != null;

  AppNotification markedRead() => AppNotification(
    id: id,
    type: type,
    title: title,
    body: body,
    isRead: true,
    bookingId: bookingId,
    createdAt: createdAt,
  );

  /// `2 min ago`, `10 min ago`, `1 hour ago`.
  String get age {
    final at = createdAt;

    if (at == null) {
      return '';
    }

    final elapsed = DateTime.now().difference(at);

    if (elapsed.inSeconds < 60) {
      return 'Just now';
    }
    if (elapsed.inMinutes < 60) {
      return '${elapsed.inMinutes} min ago';
    }
    if (elapsed.inHours < 24) {
      final hours = elapsed.inHours;
      return hours == 1 ? '1 hour ago' : '$hours hours ago';
    }
    final days = elapsed.inDays;
    return days == 1 ? 'Yesterday' : '$days days ago';
  }

  static DateTime? _dateTime(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value)?.toLocal();
  }
}

/// What a push carried, reduced to the two things the app acts on.
///
/// The payload is a hint, never the truth: tapping it opens the booking and
/// the booking is re-read from the server, so a push that has been sitting in
/// the tray for an hour cannot show a stale status.
class PushPayload {
  const PushPayload({
    this.type,
    this.bookingId,
    this.notificationId,
    this.title,
    this.body,
  });

  factory PushPayload.fromData(
    Map<String, dynamic> data, {
    String? title,
    String? body,
  }) {
    return PushPayload(
      type: JsonField.text(data['type']),
      bookingId: JsonField.text(data['bookingId']),
      notificationId: JsonField.text(data['notificationId']),
      title: JsonField.text(title),
      body: JsonField.text(body),
    );
  }

  final String? type;
  final String? bookingId;
  final String? notificationId;

  /// From the FCM `notification` block, for the in-app banner the tray does
  /// not show while the app is open.
  final String? title;
  final String? body;

  bool get opensBooking => (bookingId ?? '').isNotEmpty;
}
