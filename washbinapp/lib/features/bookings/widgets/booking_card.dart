import 'package:flutter/material.dart';
import 'package:washbinapp/core/theme/app_theme.dart';
import 'package:washbinapp/features/bookings/domain/booking.dart';
import 'package:washbinapp/features/bookings/domain/booking_time.dart';
import 'package:washbinapp/features/bookings/widgets/booking_status_badge.dart';

/// One booking in the list: what, when, where, how much, and what is
/// happening to it.
class BookingCard extends StatelessWidget {
  const BookingCard({
    super.key,
    required this.booking,
    required this.serviceName,
    this.onTap,
    this.onCancel,
    this.isBusy = false,
  });

  final Booking booking;

  /// Joined from the catalogue — a booking only carries a service id.
  final String serviceName;

  /// Opens the tracking screen.
  final VoidCallback? onTap;

  /// Null when this booking can no longer be called off.
  final VoidCallback? onCancel;

  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final scheduledAt = booking.scheduledAt;
    final createdAt = booking.createdAt;
    final price = booking.price;
    final snapshot = booking.addressSnapshot;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      serviceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  BookingStatusBadge(status: booking.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                booking.status.explanation,
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              _Line(
                icon: Icons.schedule_rounded,
                // A scheduled booking is defined by when it will happen; an
                // instant one by when it was asked for.
                text: scheduledAt != null
                    ? BookingTime.describe(scheduledAt)
                    : createdAt != null
                    ? 'Booked ${BookingTime.describe(createdAt)}'
                    : 'As soon as a partner is free',
              ),
              if (snapshot != null) ...[
                const SizedBox(height: 6),
                _Line(
                  icon: Icons.location_on_outlined,
                  text: snapshot.oneLine,
                  maxLines: 2,
                ),
              ],
              if (booking.notes != null) ...[
                const SizedBox(height: 6),
                _Line(
                  icon: Icons.sticky_note_2_outlined,
                  text: booking.notes!,
                  maxLines: 2,
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  if (price != null)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            price.displayLabel,
                            style: const TextStyle(
                              color: AppTheme.ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                          ),
                          if (price.isEstimate)
                            const Text(
                              'Estimate · confirmed after the visit',
                              style: TextStyle(
                                color: AppTheme.muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    )
                  else
                    const Spacer(),
                  if (isBusy)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.red,
                      ),
                    )
                  else if (onCancel != null)
                    OutlinedButton(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.red,
                        side: const BorderSide(color: AppTheme.line),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      child: const Text('Cancel'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text, this.maxLines = 1});

  final IconData icon;
  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppTheme.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
