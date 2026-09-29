import 'package:washbinapp/features/bookings/domain/booking.dart';
import 'package:washbinapp/features/bookings/domain/booking_status.dart';

/// One rung of the tracking timeline.
class TimelineStep {
  const TimelineStep({
    required this.label,
    required this.isDone,
    this.at,
    this.isCurrent = false,
  });

  final String label;
  final bool isDone;

  /// When it happened, from the booking's own lifecycle stamps.
  final DateTime? at;

  /// The step the booking is sitting on right now.
  final bool isCurrent;
}

/// Turns a booking into the list of stages the customer sees.
///
/// Built from the lifecycle timestamps the server stamps on each transition,
/// so a step is ticked because it demonstrably happened — not inferred from
/// the current status, which would tick the wrong things after a booking goes
/// back into the pool on a declined offer.
class BookingTimeline {
  const BookingTimeline._();

  static List<TimelineStep> of(Booking booking) {
    final status = booking.status;

    // A cancelled booking stops where it stopped; showing the rest of the
    // ladder greyed out would suggest it is still going somewhere.
    if (status == BookingStatus.cancelled) {
      return [
        TimelineStep(
          label: 'Booking confirmed',
          isDone: true,
          at: booking.createdAt,
        ),
        TimelineStep(
          label: 'Cancelled',
          isDone: true,
          at: booking.cancelledAt,
          isCurrent: true,
        ),
      ];
    }

    final steps = <({String label, DateTime? at, bool reached})>[
      (label: 'Booking confirmed', at: booking.createdAt, reached: true),
      (
        label: 'Partner assigned',
        at: null,
        // No timestamp is stamped for assignment, so this is inferred from
        // having a partner or having moved past that point.
        reached: booking.hasPartner || booking.acceptedAt != null,
      ),
      (
        label: 'Partner accepted',
        at: booking.acceptedAt,
        reached: booking.acceptedAt != null,
      ),
      (
        label: 'On the way',
        at: booking.onTheWayAt,
        reached: booking.onTheWayAt != null,
      ),
      (
        label: 'Arrived',
        at: booking.arrivedAt,
        reached: booking.arrivedAt != null,
      ),
      (
        label: 'Service started',
        at: booking.startedAt,
        reached: booking.startedAt != null,
      ),
      (
        label: 'Completed',
        at: booking.completedAt,
        reached: booking.completedAt != null,
      ),
    ];

    final lastDone = steps.lastIndexWhere((step) => step.reached);

    return [
      for (var index = 0; index < steps.length; index++)
        TimelineStep(
          label: steps[index].label,
          isDone: steps[index].reached,
          at: steps[index].at,
          isCurrent: index == lastDone && !booking.status.isSettled,
        ),
    ];
  }
}
