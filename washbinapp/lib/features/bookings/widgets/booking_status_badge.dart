import 'package:flutter/material.dart';
import 'package:washbinapp/core/theme/app_theme.dart';
import 'package:washbinapp/features/bookings/domain/booking_status.dart';

/// The status, coloured by what it means rather than by which status it is:
/// live work in the brand colour, finished in grey, gone wrong in amber.
class BookingStatusBadge extends StatelessWidget {
  const BookingStatusBadge({super.key, required this.status});

  final BookingStatus status;

  static const _ended = Color(0xFF6B7280);
  static const _attention = Color(0xFFB45309);

  Color get _colour => switch (status) {
    BookingStatus.completed => _ended,
    BookingStatus.cancelled || BookingStatus.noPartnerFound => _attention,
    _ => AppTheme.red,
  };

  @override
  Widget build(BuildContext context) {
    final colour = _colour;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.display,
        maxLines: 1,
        // Lets a caller put the badge in a Flexible and have it shrink rather
        // than overflow the row it shares.
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: colour,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
