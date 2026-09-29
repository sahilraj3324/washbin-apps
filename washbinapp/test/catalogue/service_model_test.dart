import 'package:flutter_test/flutter_test.dart';
import 'package:washbinapp/features/catalogue/domain/category.dart';
import 'package:washbinapp/features/catalogue/domain/service.dart';

void main() {
  group('parsing', () {
    test("Mongo's _id is read as the id", () {
      final service = Service.fromJson({
        '_id': 'svc-1',
        'categoryId': 'cat-1',
        'name': 'Deep Cleaning',
        'description': 'Kitchen, bath, full home.',
        'pricingType': 'fixed',
        'basePrice': 299,
      });

      expect(service.id, 'svc-1');
      expect(service.categoryId, 'cat-1');
      expect(
        Category.fromJson({'_id': 'cat-1', 'name': 'Cleaning'}).id,
        'cat-1',
      );
    });

    test('a populated categoryId is reduced back to its id', () {
      final service = Service.fromJson({
        '_id': 'svc-1',
        'categoryId': {'_id': 'cat-1', 'name': 'Cleaning'},
        'name': 'Deep Cleaning',
        'description': '',
        'pricingType': 'fixed',
        'basePrice': 299,
      });

      expect(service.categoryId, 'cat-1');
    });

    test('missing optional fields become null, not empty strings', () {
      final service = Service.fromJson({
        '_id': 'svc-1',
        'categoryId': 'cat-1',
        'name': 'Deep Cleaning',
        'description': 'Thorough.',
        'pricingType': 'fixed',
        'basePrice': 299,
        'imageUrl': '   ',
        'estimatedDurationMinutes': null,
      });

      expect(service.imageUrl, isNull);
      expect(service.iconUrl, isNull);
      expect(service.durationLabel, isNull);
    });

    test('an unknown pricing type falls back to fixed', () {
      expect(PricingType.parse('per_square_foot'), PricingType.fixed);
      expect(PricingType.parse(null), PricingType.fixed);
      expect(PricingType.parse('hourly'), PricingType.hourly);
      expect(PricingType.parse('starting_from'), PricingType.startingFrom);
    });
  });

  group('price label', () {
    Service priced(num price, String type) => Service.fromJson({
      '_id': 's',
      'categoryId': 'c',
      'name': 'n',
      'description': 'd',
      'pricingType': type,
      'basePrice': price,
    });

    test('a whole number of rupees shows no paise', () {
      expect(priced(299, 'fixed').priceLabel, '₹299');
    });

    test('paise are shown only when the price has them', () {
      // basePrice is a float on the server, so 299.50 is reachable.
      expect(priced(299.5, 'fixed').priceLabel, '₹299.50');
    });

    test('the pricing type changes how the price reads', () {
      expect(priced(299, 'hourly').priceLabel, '₹299/hr');
      expect(priced(299, 'starting_from').priceLabel, 'From ₹299');
    });

    test('only a non-fixed price needs explaining', () {
      expect(priced(299, 'fixed').pricingNote, isNull);
      expect(priced(299, 'hourly').pricingNote, contains('every hour'));
      expect(priced(299, 'starting_from').pricingNote, contains('Starting'));
    });
  });

  group('duration label', () {
    Service lasting(int? minutes) => Service.fromJson({
      '_id': 's',
      'categoryId': 'c',
      'name': 'n',
      'description': 'd',
      'pricingType': 'fixed',
      'basePrice': 1,
      'estimatedDurationMinutes': minutes,
    });

    test('under an hour reads in minutes', () {
      expect(lasting(30).durationLabel, '30 mins');
      expect(lasting(59).durationLabel, '59 mins');
    });

    test('whole hours drop the minutes', () {
      expect(lasting(60).durationLabel, '1 hr');
      expect(lasting(120).durationLabel, '2 hrs');
    });

    test('a part hour keeps both', () {
      expect(lasting(90).durationLabel, '1 hr 30 mins');
      expect(lasting(150).durationLabel, '2 hrs 30 mins');
    });

    test('absent or nonsense durations say nothing at all', () {
      expect(lasting(null).durationLabel, isNull);
      expect(lasting(0).durationLabel, isNull);
      expect(lasting(-5).durationLabel, isNull);
    });
  });
}
