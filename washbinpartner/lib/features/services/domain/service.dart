/// How a service's `basePrice` should be read. The partner app only shows it,
/// so the distinction matters for wording rather than arithmetic.
enum PricingType {
  fixed,
  hourly,
  startingFrom;

  static PricingType parse(Object? value) => switch (value) {
    'hourly' => PricingType.hourly,
    'starting_from' => PricingType.startingFrom,
    _ => PricingType.fixed,
  };

  String priceLabel(double basePrice) {
    final amount = basePrice == basePrice.roundToDouble()
        ? basePrice.toStringAsFixed(0)
        : basePrice.toStringAsFixed(2);

    return switch (this) {
      PricingType.fixed => '₹$amount',
      PricingType.hourly => '₹$amount / hour',
      PricingType.startingFrom => 'From ₹$amount',
    };
  }
}

/// A category of work, e.g. Home Cleaning. Used to group the service list.
class ServiceCategory {
  const ServiceCategory({
    required this.id,
    required this.name,
    this.sortOrder = 0,
  });

  factory ServiceCategory.fromJson(Map<String, dynamic> json) {
    final id = json['id'] ?? json['_id'];

    return ServiceCategory(
      id: id is String ? id : id.toString(),
      name: json['name'] as String? ?? '',
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String name;
  final int sortOrder;
}

/// A service Washbin offers customers, and therefore one a partner can opt in
/// to deliver.
class Service {
  const Service({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.description,
    required this.pricingType,
    required this.basePrice,
    this.estimatedDurationMinutes,
    this.sortOrder = 0,
  });

  factory Service.fromJson(Map<String, dynamic> json) {
    final id = json['id'] ?? json['_id'];
    final categoryId = json['categoryId'];

    return Service(
      id: id is String ? id : id.toString(),
      categoryId: categoryId is String ? categoryId : categoryId.toString(),
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      pricingType: PricingType.parse(json['pricingType']),
      basePrice: (json['basePrice'] as num?)?.toDouble() ?? 0,
      estimatedDurationMinutes: (json['estimatedDurationMinutes'] as num?)
          ?.toInt(),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String categoryId;
  final String name;
  final String description;
  final PricingType pricingType;
  final double basePrice;
  final int? estimatedDurationMinutes;
  final int sortOrder;

  String get priceLabel => pricingType.priceLabel(basePrice);

  String? get durationLabel {
    final minutes = estimatedDurationMinutes;
    if (minutes == null) {
      return null;
    }
    if (minutes < 60) {
      return '$minutes min';
    }

    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours hr' : '$hours hr $rest min';
  }
}
