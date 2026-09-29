import 'package:flutter/material.dart';

enum PartnerNotificationType {
  partnerOffered('PARTNER_OFFERED'),
  bookingCancelled('BOOKING_CANCELLED'),
  serviceCompleted('SERVICE_COMPLETED'),
  partnerAccepted('PARTNER_ACCEPTED'),
  partnerOnTheWay('PARTNER_ON_THE_WAY'),
  partnerArrived('PARTNER_ARRIVED'),
  serviceStarted('SERVICE_STARTED'),
  other('OTHER');

  const PartnerNotificationType(this.wireValue);

  final String wireValue;

  static PartnerNotificationType parse(Object? value) {
    for (final type in PartnerNotificationType.values) {
      if (type.wireValue == value) {
        return type;
      }
    }
    return PartnerNotificationType.other;
  }

  IconData get icon => switch (this) {
    PartnerNotificationType.partnerOffered => Icons.work_rounded,
    PartnerNotificationType.bookingCancelled => Icons.cancel_rounded,
    PartnerNotificationType.serviceCompleted => Icons.verified_rounded,
    PartnerNotificationType.partnerAccepted =>
      Icons.assignment_turned_in_rounded,
    PartnerNotificationType.partnerOnTheWay => Icons.directions_bike_rounded,
    PartnerNotificationType.partnerArrived => Icons.place_rounded,
    PartnerNotificationType.serviceStarted => Icons.play_circle_fill_rounded,
    PartnerNotificationType.other => Icons.notifications_rounded,
  };
}

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
      id: _id(json),
      type: PartnerNotificationType.parse(json['type']),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      isRead: json['isRead'] as bool? ?? false,
      bookingId: _reference(json['bookingId']),
      createdAt: _dateTime(json['createdAt']),
    );
  }

  final String id;
  final PartnerNotificationType type;
  final String title;
  final String body;
  final bool isRead;
  final String? bookingId;
  final DateTime? createdAt;

  bool get opensJob => bookingId != null;

  AppNotification markedRead() => AppNotification(
    id: id,
    type: type,
    title: title,
    body: body,
    isRead: true,
    bookingId: bookingId,
    createdAt: createdAt,
  );

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
      return elapsed.inHours == 1
          ? '1 hour ago'
          : '${elapsed.inHours} hours ago';
    }
    return elapsed.inDays == 1 ? 'Yesterday' : '${elapsed.inDays} days ago';
  }
}

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
      type: _text(data['type']),
      bookingId: _text(data['bookingId']),
      notificationId: _text(data['notificationId']),
      title: _text(title),
      body: _text(body),
    );
  }

  final String? type;
  final String? bookingId;
  final String? notificationId;
  final String? title;
  final String? body;

  bool get opensJob => (bookingId ?? '').isNotEmpty;
}

String _id(Map<String, dynamic> json) {
  final id = json['_id'] ?? json['id'];
  return id is String ? id : id?.toString() ?? '';
}

String? _reference(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is String) {
    return _text(value);
  }
  if (value is Map<String, dynamic>) {
    return _id(value);
  }
  return value.toString();
}

String? _text(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

DateTime? _dateTime(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value)?.toLocal();
}
