import 'package:flutter_test/flutter_test.dart';
import 'package:washbinapp/features/bookings/domain/booking.dart';
import 'package:washbinapp/features/bookings/domain/booking_status.dart';
import 'package:washbinapp/features/bookings/domain/booking_timeline.dart';

import '../support/fake_backend.dart';

Booking _booking({
  String status = 'searching_partner',
  String? partnerId,
  Map<String, String?> stamps = const {},
}) => Booking.fromJson({
  ...FakeBackend.booking(id: '68c1f4aa930b148ed80df6ab', status: status),
  'assignedPartnerId': partnerId,
  ...stamps,
});

List<String> _done(Booking booking) =>
    BookingTimeline.of(booking)
        .where((step) => step.isDone)
        .map((step) => step.label)
        .toList();

void main() {
  group('timeline', () {
    test('a fresh booking has only its confirmation ticked', () {
      expect(_done(_booking()), ['Booking confirmed']);
    });

    test('an assigned partner ticks the second step', () {
      expect(_done(_booking(status: 'partner_assigned', partnerId: 'p1')), [
        'Booking confirmed',
        'Partner assigned',
      ]);
    });

    test('steps are ticked from timestamps, not from the current status', () {
      // The point: a booking that went back into the pool after a declined
      // offer must not show "accepted" ticked just because it once was.
      final booking = _booking(
        status: 'on_the_way',
        partnerId: 'p1',
        stamps: {
          'acceptedAt': '2026-09-13T10:00:00.000Z',
          'onTheWayAt': '2026-09-13T10:05:00.000Z',
        },
      );

      expect(_done(booking), [
        'Booking confirmed',
        'Partner assigned',
        'Partner accepted',
        'On the way',
      ]);
    });

    test('a completed booking ticks the whole ladder', () {
      final booking = _booking(
        status: 'completed',
        partnerId: 'p1',
        stamps: {
          'acceptedAt': '2026-09-13T10:00:00.000Z',
          'onTheWayAt': '2026-09-13T10:05:00.000Z',
          'arrivedAt': '2026-09-13T10:20:00.000Z',
          'startedAt': '2026-09-13T10:25:00.000Z',
          'completedAt': '2026-09-13T11:30:00.000Z',
        },
      );

      expect(_done(booking), hasLength(7));
      expect(
        BookingTimeline.of(booking).every((step) => !step.isCurrent),
        isTrue,
      );
    });

    test('a cancelled booking stops where it stopped', () {
      // Showing the rest of the ladder greyed out would suggest it is still
      // going somewhere.
      final booking = _booking(
        status: 'cancelled',
        stamps: {'cancelledAt': '2026-09-13T10:10:00.000Z'},
      );
      final steps = BookingTimeline.of(booking);

      expect(steps.map((step) => step.label), [
        'Booking confirmed',
        'Cancelled',
      ]);
      expect(steps.last.isCurrent, isTrue);
    });

    test('the current step is the furthest one reached', () {
      final booking = _booking(
        status: 'accepted',
        partnerId: 'p1',
        stamps: {'acceptedAt': '2026-09-13T10:00:00.000Z'},
      );

      final current = BookingTimeline.of(booking)
          .where((step) => step.isCurrent)
          .map((step) => step.label);
      expect(current, ['Partner accepted']);
    });
  });

  group('status meaning', () {
    test('only completed and cancelled are settled', () {
      final settled = BookingStatus.values
          .where((status) => status.isSettled)
          .toList();

      expect(settled, [BookingStatus.completed, BookingStatus.cancelled]);
    });

    test('no partner found is unsettled but not worth polling', () {
      // It can go back into searching, so the customer can still act on it —
      // but it will not move on its own, so polling it is pure waste.
      const status = BookingStatus.noPartnerFound;

      expect(status.isSettled, isFalse);
      expect(status.isOpen, isTrue);
      expect(status.isLive, isFalse);
    });

    test('every in-flight status is worth polling', () {
      for (final status in [
        BookingStatus.pending,
        BookingStatus.searchingPartner,
        BookingStatus.partnerAssigned,
        BookingStatus.accepted,
        BookingStatus.onTheWay,
        BookingStatus.arrived,
        BookingStatus.inProgress,
      ]) {
        expect(status.isLive, isTrue, reason: '${status.wireValue} is live');
      }
    });

    test('a settled booking is never polled', () {
      expect(BookingStatus.completed.isLive, isFalse);
      expect(BookingStatus.cancelled.isLive, isFalse);
    });
  });

  group('booking reference', () {
    test('is derived from the id, and is stable', () {
      final booking = _booking();

      expect(booking.reference, 'SWZ-0DF6AB');
      expect(booking.reference, booking.reference);
    });
  });

  group('service start code', () {
    Booking withOtp(String? otp, String? expiry) => Booking.fromJson({
      ...FakeBackend.booking(id: '68c1f4aa930b148ed80df6ab', status: 'arrived'),
      'serviceStartOtp': otp,
      'serviceStartOtpExpiresAt': expiry,
    });

    test('is shown while it is still valid', () {
      final future = DateTime.now()
          .add(const Duration(minutes: 10))
          .toUtc()
          .toIso8601String();

      expect(withOtp('482913', future).liveStartOtp, '482913');
    });

    test('is withheld once expired', () {
      final past = DateTime.now()
          .subtract(const Duration(minutes: 1))
          .toUtc()
          .toIso8601String();

      expect(withOtp('482913', past).liveStartOtp, isNull);
    });

    test('is absent when the server did not issue one', () {
      // SERVICE_START_OTP_REQUIRED defaults to false, so this is the norm.
      expect(withOtp(null, null).liveStartOtp, isNull);
    });
  });
}
