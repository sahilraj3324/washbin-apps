import 'package:washbinapp/features/bookings/domain/booking.dart';
import 'package:washbinapp/features/bookings/domain/booking_status.dart';

/// How the bookings tab divides a customer's history.
///
/// Every one of the ten statuses lands in exactly one of these, so nothing can
/// go missing from the list by falling between two filters.
enum BookingBucket {
  /// Happening now, or trying to: searching, assigned, accepted, travelling,
  /// arrived, in progress — and a search that came up empty, which needs the
  /// customer to decide what next.
  active('Active'),

  /// Scheduled, and still waiting for its window to come round.
  upcoming('Upcoming'),

  completed('Completed'),
  cancelled('Cancelled');

  const BookingBucket(this.label);

  final String label;

  static BookingBucket of(Booking booking) {
    return switch (booking.status) {
      BookingStatus.cancelled => BookingBucket.cancelled,
      BookingStatus.completed => BookingBucket.completed,
      // `pending` means a scheduled booking that dispatch has not woken yet.
      // An instant booking never starts there.
      BookingStatus.pending => BookingBucket.upcoming,
      _ => BookingBucket.active,
    };
  }

  /// What an empty tab says, which differs enough per tab to be worth writing
  /// out rather than generating.
  ({String title, String message}) get emptyState => switch (this) {
    BookingBucket.active => (
      title: 'Nothing in progress',
      message: 'Book a service from Home and you can follow it here.',
    ),
    BookingBucket.upcoming => (
      title: 'Nothing scheduled',
      message: 'Bookings you schedule for later will wait here.',
    ),
    BookingBucket.completed => (
      title: 'No completed bookings',
      message: 'Services you have had done will be listed here.',
    ),
    BookingBucket.cancelled => (
      title: 'No cancelled bookings',
      message: 'Bookings you call off will be listed here.',
    ),
  };
}
