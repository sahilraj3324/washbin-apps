import 'package:washbinapp/features/addresses/domain/address.dart';
import 'package:washbinapp/features/bookings/domain/booking_status.dart';
import 'package:washbinapp/features/bookings/domain/booking_time.dart';
import 'package:washbinapp/features/catalogue/domain/service.dart';

/// A booking being put together, carried from screen to screen.
///
/// Holding the whole [Service] and [Address] rather than two ids is what lets
/// the summary screen render without refetching anything, and makes "no
/// service selected" or "no address selected" impossible to express.
class BookingDraft {
  const BookingDraft({
    required this.service,
    required this.address,
    this.bookingType = BookingType.instant,
    this.scheduledAt,
    this.notes,
  });

  final Service service;
  final Address address;
  final BookingType bookingType;

  /// Only meaningful for a scheduled booking. The API rejects it outright on
  /// an instant one, so [toJson] never sends it there.
  final DateTime? scheduledAt;

  final String? notes;

  bool get isScheduled => bookingType == BookingType.scheduled;

  /// Why this draft cannot be sent yet, or null when it can.
  ///
  /// The service and address cannot be missing — the type system sees to that
  /// — so what is left is the schedule.
  String? get validationError =>
      isScheduled ? BookingTime.validationError(scheduledAt) : null;

  bool get isValid => validationError == null;

  BookingDraft copyWith({
    BookingType? bookingType,
    DateTime? scheduledAt,
    String? notes,
    bool clearSchedule = false,
  }) {
    return BookingDraft(
      service: service,
      address: address,
      bookingType: bookingType ?? this.bookingType,
      scheduledAt: clearSchedule ? null : (scheduledAt ?? this.scheduledAt),
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    final notes = this.notes?.trim();

    return {
      'serviceId': service.id,
      'addressId': address.id,
      'bookingType': bookingType.wireValue,
      // Absent, not null: the API rejects scheduledAt on an instant booking.
      if (isScheduled && scheduledAt != null)
        'scheduledAt': scheduledAt!.toUtc().toIso8601String(),
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };
  }
}
