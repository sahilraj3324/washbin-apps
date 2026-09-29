import 'package:washbinapp/features/bookings/domain/booking.dart';
import 'package:washbinapp/features/bookings/domain/booking_bucket.dart';
import 'package:washbinapp/features/catalogue/domain/service.dart';

/// The bookings list, with the names filled in and sorted into tabs.
///
/// A booking only carries a `serviceId`, so the catalogue is read alongside it
/// and joined here — one extra request for the whole list rather than one per
/// row.
class BookingsView {
  BookingsView({required this.bookings, required this.serviceNames});

  final List<Booking> bookings;
  final Map<String, String> serviceNames;

  /// Grouped once rather than filtered on every rebuild, and kept in the
  /// order the server sent — newest first.
  late final Map<BookingBucket, List<Booking>> _buckets = {
    for (final bucket in BookingBucket.values)
      bucket: bookings
          .where((booking) => BookingBucket.of(booking) == bucket)
          .toList(growable: false),
  };

  List<Booking> inBucket(BookingBucket bucket) => _buckets[bucket]!;

  int countIn(BookingBucket bucket) => _buckets[bucket]!.length;

  bool get isEmpty => bookings.isEmpty;

  /// The tab to open on: whatever the customer most likely came to check.
  BookingBucket get openingBucket {
    for (final bucket in BookingBucket.values) {
      if (countIn(bucket) > 0) {
        return bucket;
      }
    }
    return BookingBucket.active;
  }

  /// Falls back rather than showing a raw id: a service deleted outright
  /// still leaves its bookings behind.
  String nameFor(Booking booking) =>
      serviceNames[booking.serviceId] ?? 'Service';

  static BookingsView join(List<Booking> bookings, List<Service> services) {
    return BookingsView(
      bookings: bookings,
      serviceNames: {for (final service in services) service.id: service.name},
    );
  }
}
