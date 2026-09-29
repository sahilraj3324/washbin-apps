/// Date and time wording for bookings.
///
/// Hand-rolled rather than pulling in `intl`: the app shows one date format in
/// one locale, and a package would bring locale initialisation with it for two
/// functions' worth of output.
class BookingTime {
  const BookingTime._();

  /// The rules the API enforces on `scheduledAt`, mirrored so the customer is
  /// told before a request is wasted on it.
  static const minimumLead = Duration(minutes: 15);
  static const maximumHorizon = Duration(days: 60);

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  /// `Today, 7:30 PM` · `Tomorrow, 9:00 AM` · `Mon 12 Jan, 2:15 PM`.
  static String describe(DateTime when, {DateTime? now}) {
    return '${describeDay(when, now: now)}, ${describeTime(when)}';
  }

  static String describeDay(DateTime when, {DateTime? now}) {
    final today = _startOfDay(now ?? DateTime.now());
    final day = _startOfDay(when);
    final difference = day.difference(today).inDays;

    return switch (difference) {
      0 => 'Today',
      1 => 'Tomorrow',
      _ =>
        '${_weekdays[when.weekday - 1]} ${when.day} ${_months[when.month - 1]}',
    };
  }

  /// 12-hour clock, which is how times are read in India.
  static String describeTime(DateTime when) {
    final hour = when.hour % 12 == 0 ? 12 : when.hour % 12;
    final minute = when.minute.toString().padLeft(2, '0');
    final meridiem = when.hour < 12 ? 'AM' : 'PM';

    return '$hour:$minute $meridiem';
  }

  static DateTime earliest({DateTime? now}) =>
      (now ?? DateTime.now()).add(minimumLead);

  /// What the date and time pickers open on.
  ///
  /// Deliberately not [earliest]: opening exactly on the minimum lead means
  /// the default is already expired by the time the customer taps through,
  /// and every booking would be rejected for being minutes too soon. This
  /// rounds up to the next half hour, comfortably clear of the boundary.
  static DateTime suggestion({DateTime? now}) {
    final at = (now ?? DateTime.now()).add(const Duration(minutes: 30));
    final onTheHour = DateTime(at.year, at.month, at.day, at.hour);

    return at.minute < 30
        ? onTheHour.add(const Duration(minutes: 30))
        : onTheHour.add(const Duration(hours: 1));
  }

  static DateTime latest({DateTime? now}) =>
      (now ?? DateTime.now()).add(maximumHorizon);

  /// Why this time cannot be booked, or null when it can.
  ///
  /// The same two bounds the server applies, so the customer is corrected on
  /// the screen rather than by a rejected request.
  static String? validationError(DateTime? when, {DateTime? now}) {
    if (when == null) {
      return 'Pick a date and time for your booking.';
    }

    final at = now ?? DateTime.now();

    if (when.isBefore(at.add(minimumLead))) {
      return 'Pick a time at least ${minimumLead.inMinutes} minutes from now, '
          'so we can find you a partner.';
    }
    if (when.isAfter(at.add(maximumHorizon))) {
      return 'Bookings can be made up to ${maximumHorizon.inDays} days ahead.';
    }
    return null;
  }

  static DateTime _startOfDay(DateTime when) =>
      DateTime(when.year, when.month, when.day);
}
