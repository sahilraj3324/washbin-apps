import 'package:washbinapp/features/catalogue/domain/json_field.dart';

/// How `basePrice` should be read. Mirrors `PRICING_TYPES` in the API.
enum PricingType {
  /// The whole job costs this.
  fixed,

  /// Charged per hour of work.
  hourly,

  /// A floor; the real price is quoted later.
  startingFrom;

  static PricingType parse(Object? value) => switch (value) {
    'hourly' => PricingType.hourly,
    'starting_from' => PricingType.startingFrom,
    _ => PricingType.fixed,
  };
}

/// A bookable service, as `GET /services` describes it.
class Service {
  const Service({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.slug,
    required this.description,
    required this.pricingType,
    required this.basePrice,
    this.imageUrl,
    this.iconUrl,
    this.estimatedDurationMinutes,
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory Service.fromJson(Map<String, dynamic> json) {
    return Service(
      id: JsonField.id(json),
      categoryId: JsonField.reference(json['categoryId']),
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String? ?? '',
      pricingType: PricingType.parse(json['pricingType']),
      basePrice: JsonField.decimal(json['basePrice']) ?? 0,
      imageUrl: JsonField.text(json['imageUrl']),
      iconUrl: JsonField.text(json['iconUrl']),
      estimatedDurationMinutes: JsonField.integer(
        json['estimatedDurationMinutes'],
      ),
      isActive: json['isActive'] as bool? ?? true,
      sortOrder: JsonField.integer(json['sortOrder']) ?? 0,
    );
  }

  final String id;
  final String categoryId;
  final String name;
  final String slug;
  final String description;
  final PricingType pricingType;

  /// Rupees. The API stores this as a float, so it is read as one here rather
  /// than silently truncating a price like 299.50.
  final double basePrice;

  final String? imageUrl;
  final String? iconUrl;
  final int? estimatedDurationMinutes;
  final bool isActive;
  final int sortOrder;

  /// `₹299`, `₹299/hr`, or `From ₹299`, depending on how the price is meant
  /// to be read. Paise are shown only when the price actually has them.
  String get priceLabel {
    final amount = basePrice == basePrice.roundToDouble()
        ? basePrice.toStringAsFixed(0)
        : basePrice.toStringAsFixed(2);

    return switch (pricingType) {
      PricingType.fixed => '₹$amount',
      PricingType.hourly => '₹$amount/hr',
      PricingType.startingFrom => 'From ₹$amount',
    };
  }

  /// `30 mins`, `1 hr`, `1 hr 30 mins` — or null when the API did not say.
  String? get durationLabel {
    final minutes = estimatedDurationMinutes;

    if (minutes == null || minutes <= 0) {
      return null;
    }
    if (minutes < 60) {
      return '$minutes mins';
    }

    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    final hourPart = hours == 1 ? '1 hr' : '$hours hrs';

    return rest == 0 ? hourPart : '$hourPart $rest mins';
  }

  /// What the price actually promises, for the detail screen. `fixed` needs no
  /// explanation, so it gets none.
  String? get pricingNote => switch (pricingType) {
    PricingType.fixed => null,
    PricingType.hourly => 'Charged for every hour of work.',
    PricingType.startingFrom =>
      'Starting price. The final amount is confirmed after the visit.',
  };
}
