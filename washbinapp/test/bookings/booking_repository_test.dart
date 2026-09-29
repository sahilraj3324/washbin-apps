import 'package:flutter_test/flutter_test.dart';
import 'package:washbinapp/core/api/api_client.dart';
import 'package:washbinapp/core/api/api_exception.dart';
import 'package:washbinapp/features/addresses/domain/address.dart';
import 'package:washbinapp/features/bookings/data/booking_repository.dart';
import 'package:washbinapp/features/bookings/domain/booking_draft.dart';
import 'package:washbinapp/features/bookings/domain/booking_status.dart';
import 'package:washbinapp/features/bookings/domain/booking_time.dart';
import 'package:washbinapp/features/catalogue/domain/service.dart';

import '../support/fake_backend.dart';

BookingRepository _repository(FakeBackend backend) {
  return BookingRepository(
    apiClient: ApiClient(
      httpClient: backend.client,
      accessToken: () => 'washbin-token',
      baseUrl: 'https://api.test',
    ),
  );
}

Service _service({
  String id = 'svc-1',
  String pricingType = 'fixed',
  num basePrice = 299,
  int? durationMinutes = 30,
}) => Service.fromJson({
  '_id': id,
  'categoryId': 'cat-1',
  'name': 'Deep Cleaning',
  'description': 'Thorough.',
  'pricingType': pricingType,
  'basePrice': basePrice,
  'estimatedDurationMinutes': durationMinutes,
});

Address _address({String id = 'addr-1', double latitude = 19.076}) =>
    Address.fromJson(FakeBackend.address(id: id, latitude: latitude));

FakeBackend _backendWith({List<Map<String, dynamic>>? addresses}) {
  return FakeBackend()
    ..addresses = addresses ?? [FakeBackend.address(id: 'addr-1')];
}

void main() {
  group('instant bookings', () {
    test('are created in searching_partner', () async {
      final backend = _backendWith();

      final booking = await _repository(backend)
          .create(BookingDraft(service: _service(), address: _address()));

      expect(booking.status, BookingStatus.searchingPartner);
      expect(booking.bookingType, BookingType.instant);
      expect(booking.scheduledAt, isNull);
    });

    test('never send scheduledAt, which the API would reject', () async {
      final backend = _backendWith();

      await _repository(backend).create(
        BookingDraft(
          service: _service(),
          address: _address(),
          // Left over from a customer who switched back to Book now.
          scheduledAt: DateTime.now().add(const Duration(days: 1)),
        ),
      );

      expect(
        backend.bookingAttempts.single.containsKey('scheduledAt'),
        isFalse,
      );
    });

    test('customerId is never sent — it comes from the token', () async {
      final backend = _backendWith();

      await _repository(backend)
          .create(BookingDraft(service: _service(), address: _address()));

      expect(backend.bookingAttempts.single.keys, [
        'serviceId',
        'addressId',
        'bookingType',
      ]);
    });

    test(
      'clash with an existing active booking, with a clear reason',
      () async {
        final backend = _backendWith();
        final repository = _repository(backend);
        await repository.create(
          BookingDraft(service: _service(), address: _address()),
        );

        await expectLater(
          repository.create(
            BookingDraft(service: _service(), address: _address()),
          ),
          throwsA(
            isA<ApiException>()
                .having((error) => error.kind, 'kind', ApiErrorKind.conflict)
                .having(
                  (error) => error.message,
                  'message',
                  contains('already have a booking in progress'),
                ),
          ),
        );
        expect(backend.bookings, hasLength(1));
      },
    );
  });

  group('scheduled bookings', () {
    BookingDraft scheduledFor(DateTime when) => BookingDraft(
      service: _service(),
      address: _address(),
      bookingType: BookingType.scheduled,
      scheduledAt: when,
    );

    test('are created in pending, awaiting their dispatch window', () async {
      final backend = _backendWith();
      final when = DateTime.now().add(const Duration(days: 2));

      final booking = await _repository(backend).create(scheduledFor(when));

      expect(booking.status, BookingStatus.pending);
      expect(booking.bookingType, BookingType.scheduled);
      expect(
        booking.scheduledAt!.difference(when).inMinutes.abs(),
        lessThan(1),
      );
    });

    test('the time is sent as UTC ISO 8601', () async {
      final backend = _backendWith();
      final when = DateTime.now().add(const Duration(days: 2));

      await _repository(backend).create(scheduledFor(when));

      final sent = backend.bookingAttempts.single['scheduledAt'] as String;
      expect(sent, endsWith('Z'));
      expect(DateTime.parse(sent).isUtc, isTrue);
    });

    test('too soon is refused by the server', () async {
      final backend = _backendWith();

      await expectLater(
        _repository(
          backend,
        ).create(scheduledFor(DateTime.now().add(const Duration(minutes: 5)))),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            contains('at least 15 minutes'),
          ),
        ),
      );
    });

    test('beyond the horizon is refused by the server', () async {
      final backend = _backendWith();

      await expectLater(
        _repository(backend)
            .create(scheduledFor(DateTime.now().add(const Duration(days: 90)))),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            contains('more than 60 days'),
          ),
        ),
      );
    });

    test('two bookings close together clash', () async {
      final backend = _backendWith();
      final repository = _repository(backend);
      final when = DateTime.now().add(const Duration(days: 2));

      await repository.create(scheduledFor(when));

      await expectLater(
        repository.create(scheduledFor(when.add(const Duration(minutes: 10)))),
        throwsA(
          isA<ApiException>()
              .having((error) => error.kind, 'kind', ApiErrorKind.conflict)
              .having(
                (error) => error.message,
                'message',
                contains('around that time'),
              ),
        ),
      );
    });

    test('two bookings far apart do not clash', () async {
      final backend = _backendWith();
      final repository = _repository(backend);
      final when = DateTime.now().add(const Duration(days: 2));

      await repository.create(scheduledFor(when));
      await repository.create(scheduledFor(when.add(const Duration(hours: 5))));

      expect(backend.bookings, hasLength(2));
    });
  });

  group('rejections', () {
    test('an unserviceable address is refused', () async {
      // Delhi, outside the Mumbai operational area.
      final backend = _backendWith(
        addresses: [
          FakeBackend.address(
            id: 'addr-far',
            latitude: 28.6139,
            longitude: 77.209,
          ),
        ],
      );

      await expectLater(
        _repository(backend).create(
          BookingDraft(
            service: _service(),
            address: _address(id: 'addr-far', latitude: 28.6139),
          ),
        ),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            contains('not serviceable'),
          ),
        ),
      );
      expect(backend.bookings, isEmpty);
    });

    test('an inactive service is refused', () async {
      final backend = _backendWith()
        ..services = [
          FakeBackend.service(
            id: 'svc-off',
            categoryId: 'cat-1',
            name: 'Retired',
            basePrice: 1,
            isActive: false,
          ),
        ];

      await expectLater(
        _repository(backend).create(
          BookingDraft(
            service: _service(id: 'svc-off'),
            address: _address(),
          ),
        ),
        throwsA(isA<ApiException>()),
      );
    });

    test('an address that is not the customer\'s is refused', () async {
      final backend = _backendWith();

      await expectLater(
        _repository(backend).create(
          BookingDraft(
            service: _service(),
            address: _address(id: 'addr-999'),
          ),
        ),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            contains('Address not found'),
          ),
        ),
      );
    });
  });

  group('price', () {
    test('a fixed service has a final amount at creation', () async {
      final backend = _backendWith();

      final booking = await _repository(backend)
          .create(BookingDraft(service: _service(), address: _address()));

      expect(booking.price!.baseAmount, 299);
      expect(booking.price!.finalAmount, 299);
      expect(booking.price!.isEstimate, isFalse);
      expect(booking.price!.displayLabel, '₹299');
    });

    test(
      'an hourly service is only an estimate until the work is done',
      () async {
        final backend = _backendWith()
          ..services = [
            FakeBackend.service(
              id: 'svc-1',
              categoryId: 'cat-1',
              name: 'Daily Home Cook',
              basePrice: 299,
              pricingType: 'hourly',
            ),
          ];

        final booking = await _repository(backend).create(
          BookingDraft(
            service: _service(pricingType: 'hourly'),
            address: _address(),
          ),
        );

        expect(booking.price!.baseAmount, 299);
        expect(booking.price!.finalAmount, isNull);
        expect(booking.price!.isEstimate, isTrue);
      },
    );
  });

  group('draft validation', () {
    test('an instant draft is always valid', () {
      final draft = BookingDraft(service: _service(), address: _address());

      expect(draft.isValid, isTrue);
      expect(draft.validationError, isNull);
    });

    test('a scheduled draft with no time is not', () {
      final draft = BookingDraft(
        service: _service(),
        address: _address(),
        bookingType: BookingType.scheduled,
      );

      expect(draft.isValid, isFalse);
      expect(draft.validationError, contains('Pick a date and time'));
    });

    test('the client refuses a time the server would refuse', () {
      final tooSoon = BookingDraft(
        service: _service(),
        address: _address(),
        bookingType: BookingType.scheduled,
        scheduledAt: DateTime.now().add(const Duration(minutes: 5)),
      );
      final tooFar = BookingDraft(
        service: _service(),
        address: _address(),
        bookingType: BookingType.scheduled,
        scheduledAt: DateTime.now().add(const Duration(days: 90)),
      );

      expect(tooSoon.validationError, contains('15 minutes'));
      expect(tooFar.validationError, contains('60 days'));
    });

    test('switching back to instant drops the time', () {
      final draft = BookingDraft(
        service: _service(),
        address: _address(),
        bookingType: BookingType.scheduled,
        scheduledAt: DateTime.now().add(const Duration(days: 1)),
      ).copyWith(bookingType: BookingType.instant, clearSchedule: true);

      expect(draft.scheduledAt, isNull);
      expect(draft.toJson().containsKey('scheduledAt'), isFalse);
    });
  });

  group('time wording', () {
    final noon = DateTime(2026, 9, 11, 12);

    test('today and tomorrow are named', () {
      expect(BookingTime.describeDay(noon, now: noon), 'Today');
      expect(
        BookingTime.describeDay(noon.add(const Duration(days: 1)), now: noon),
        'Tomorrow',
      );
    });

    test('further out gives a weekday and date', () {
      expect(
        BookingTime.describeDay(DateTime(2026, 9, 14, 9), now: noon),
        'Mon 14 Sep',
      );
    });

    test('times read on a 12-hour clock', () {
      expect(
        BookingTime.describeTime(DateTime(2026, 9, 11, 19, 30)),
        '7:30 PM',
      );
      expect(BookingTime.describeTime(DateTime(2026, 9, 11, 0, 5)), '12:05 AM');
      expect(BookingTime.describeTime(DateTime(2026, 9, 11, 12)), '12:00 PM');
      expect(BookingTime.describeTime(DateTime(2026, 9, 11, 9)), '9:00 AM');
    });

    test('the picker opens on a time the server would accept', () {
      // Opening exactly on the 15-minute minimum expires before the customer
      // can tap through, and every booking gets rejected as too soon.
      final now = DateTime(2026, 9, 11, 19, 7);
      final suggestion = BookingTime.suggestion(now: now);

      expect(suggestion, DateTime(2026, 9, 11, 20));
      expect(suggestion.isAfter(BookingTime.earliest(now: now)), isTrue);
      expect(BookingTime.validationError(suggestion, now: now), isNull);
    });

    test('the suggestion rolls into the next hour past the half hour', () {
      // 19:45 + 30 min lands at 20:15, which rounds up to 20:30.
      expect(
        BookingTime.suggestion(now: DateTime(2026, 9, 11, 19, 45)),
        DateTime(2026, 9, 11, 20, 30),
      );
      expect(
        BookingTime.suggestion(now: DateTime(2026, 9, 11, 19, 0)),
        DateTime(2026, 9, 11, 20),
      );
    });

    test('the whole phrase reads as the summary shows it', () {
      expect(
        BookingTime.describe(DateTime(2026, 9, 11, 19, 30), now: noon),
        'Today, 7:30 PM',
      );
    });
  });
}
