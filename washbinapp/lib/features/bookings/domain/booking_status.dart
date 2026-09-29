/// Whether the customer wants someone now, or at a time they choose.
enum BookingType {
  instant('instant'),
  scheduled('scheduled');

  const BookingType(this.wireValue);

  final String wireValue;

  static BookingType parse(Object? value) =>
      value == 'scheduled' ? BookingType.scheduled : BookingType.instant;
}

/// The booking lifecycle. Mirrors `BOOKING_STATUSES` in the API.
///
/// The app only ever *reads* these: status moves on the server, through
/// partner assignment or a cancellation, and there is deliberately no route
/// that lets a client set one.
enum BookingStatus {
  /// A scheduled booking waiting for its dispatch window.
  pending('pending'),
  searchingPartner('searching_partner'),
  partnerAssigned('partner_assigned'),
  accepted('accepted'),
  onTheWay('on_the_way'),
  arrived('arrived'),
  inProgress('in_progress'),
  completed('completed'),
  cancelled('cancelled'),
  noPartnerFound('no_partner_found');

  const BookingStatus(this.wireValue);

  final String wireValue;

  static BookingStatus parse(Object? value) {
    for (final status in BookingStatus.values) {
      if (status.wireValue == value) {
        return status;
      }
    }
    // An unrecognised status means the server moved ahead of this build.
    // Treating it as pending keeps the booking visible instead of hiding it.
    return BookingStatus.pending;
  }

  /// What the customer is told is happening.
  String get display => switch (this) {
    BookingStatus.pending => 'Scheduled',
    BookingStatus.searchingPartner => 'Searching for partner',
    BookingStatus.partnerAssigned => 'Partner found',
    BookingStatus.accepted => 'Partner confirmed',
    BookingStatus.onTheWay => 'On the way',
    BookingStatus.arrived => 'Arrived',
    BookingStatus.inProgress => 'Service in progress',
    BookingStatus.completed => 'Completed',
    BookingStatus.cancelled => 'Cancelled',
    BookingStatus.noPartnerFound => 'No partner available',
  };

  /// A sentence of context under the status.
  String get explanation => switch (this) {
    BookingStatus.pending =>
      'We will start looking for a partner closer to the time.',
    BookingStatus.searchingPartner =>
      'We are finding a partner near you right now.',
    BookingStatus.partnerAssigned => 'Waiting for the partner to confirm.',
    BookingStatus.accepted => 'Your partner has confirmed the booking.',
    BookingStatus.onTheWay => 'Your partner is on the way.',
    BookingStatus.arrived => 'Your partner has reached your address.',
    BookingStatus.inProgress => 'The work has started.',
    BookingStatus.completed => 'This booking is done.',
    BookingStatus.cancelled => 'This booking was cancelled.',
    BookingStatus.noPartnerFound =>
      'Nobody was free this time. You can try again.',
  };

  /// Whether the customer may still call it off.
  ///
  /// Derived from the same table the server enforces: work that has started
  /// cannot be cancelled, and neither can anything already finished.
  bool get isCancellable => switch (this) {
    BookingStatus.pending ||
    BookingStatus.searchingPartner ||
    BookingStatus.partnerAssigned ||
    BookingStatus.accepted ||
    BookingStatus.onTheWay ||
    BookingStatus.arrived => true,
    _ => false,
  };

  /// Nothing further will happen to this booking, ever.
  ///
  /// `no_partner_found` is deliberately not settled: the transition table
  /// allows it back into `searching_partner`, so the customer can still act
  /// on it and it belongs among their current bookings.
  bool get isSettled =>
      this == BookingStatus.completed || this == BookingStatus.cancelled;

  /// True while the booking still has somewhere to go.
  bool get isOpen => !isSettled;

  /// True when the status can change on its own, without the customer doing
  /// anything — which is exactly when it is worth polling for.
  ///
  /// A search that came up empty will sit there until someone retries it, so
  /// polling it would be a request every few seconds for a value that cannot
  /// move.
  bool get isLive => !isSettled && this != BookingStatus.noPartnerFound;
}
