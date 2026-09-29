import 'package:flutter/material.dart';
import 'package:washbinapp/core/theme/app_theme.dart';
import 'package:washbinapp/features/bookings/domain/booking.dart';
import 'package:washbinapp/features/bookings/domain/booking_status.dart';
import 'package:washbinapp/features/bookings/domain/booking_time.dart';

/// The "you have something in progress" banner at the top of Home.
///
/// This is what reconnects a customer to their booking after they close the
/// app: whatever is still going is the first thing they see on opening it.
class ActiveBookingCard extends StatelessWidget {
  const ActiveBookingCard({
    super.key,
    required this.booking,
    required this.serviceName,
    required this.onView,
  });

  final Booking booking;
  final String serviceName;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final status = booking.status;
    final scheduledAt = booking.scheduledAt;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onView,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.red, width: 1.4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: status == BookingStatus.searchingPartner
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: AppTheme.red,
                            ),
                          )
                        : const Icon(
                            Icons.receipt_long_rounded,
                            color: AppTheme.red,
                            size: 20,
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status.display,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          scheduledAt != null
                              ? '$serviceName · ${BookingTime.describe(scheduledAt)}'
                              : serviceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      status.explanation,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: onView,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      backgroundColor: AppTheme.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: const Text('View booking'),
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
