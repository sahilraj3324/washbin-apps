import 'package:flutter/material.dart';
import 'package:washbinapp/core/theme/app_theme.dart';
import 'package:washbinapp/features/bookings/domain/booking_timeline.dart';
import 'package:washbinapp/features/bookings/domain/booking_time.dart';

/// The ladder of stages, ticked as far as the booking has actually got.
class BookingTimelineView extends StatelessWidget {
  const BookingTimelineView({super.key, required this.steps});

  final List<TimelineStep> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < steps.length; index++)
          _Rung(
            step: steps[index],
            isLast: index == steps.length - 1,
            // The connector below a rung is lit only when the next stage has
            // also been reached, so the line stops where progress stopped.
            isConnectorDone:
                index < steps.length - 1 && steps[index + 1].isDone,
          ),
      ],
    );
  }
}

class _Rung extends StatelessWidget {
  const _Rung({
    required this.step,
    required this.isLast,
    required this.isConnectorDone,
  });

  final TimelineStep step;
  final bool isLast;
  final bool isConnectorDone;

  @override
  Widget build(BuildContext context) {
    final done = step.isDone;
    final at = step.at;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: done ? AppTheme.red : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: done ? AppTheme.red : AppTheme.line,
                    width: 2,
                  ),
                ),
                child: done
                    ? const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: Colors.white,
                      )
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: isConnectorDone ? AppTheme.red : AppTheme.line,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: TextStyle(
                      color: done ? AppTheme.ink : AppTheme.muted,
                      fontSize: 14,
                      fontWeight: step.isCurrent
                          ? FontWeight.w900
                          : FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                  if (at != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      BookingTime.describe(at),
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
