enum JobOfferStatus {
  offered,
  accepted,
  rejected,
  expired,
  cancelled;

  static JobOfferStatus parse(Object? value) => switch (value) {
    'accepted' => JobOfferStatus.accepted,
    'rejected' => JobOfferStatus.rejected,
    'expired' => JobOfferStatus.expired,
    'cancelled' => JobOfferStatus.cancelled,
    _ => JobOfferStatus.offered,
  };
}

enum JobBookingType {
  instant,
  scheduled;

  static JobBookingType parse(Object? value) => switch (value) {
    'scheduled' => JobBookingType.scheduled,
    _ => JobBookingType.instant,
  };
}

enum JobBookingStatus {
  pending,
  searchingPartner,
  partnerAssigned,
  accepted,
  onTheWay,
  arrived,
  inProgress,
  completed,
  cancelled,
  noPartnerFound;

  static JobBookingStatus parse(Object? value) => switch (value) {
    'searching_partner' => JobBookingStatus.searchingPartner,
    'partner_assigned' => JobBookingStatus.partnerAssigned,
    'accepted' => JobBookingStatus.accepted,
    'on_the_way' => JobBookingStatus.onTheWay,
    'arrived' => JobBookingStatus.arrived,
    'in_progress' => JobBookingStatus.inProgress,
    'completed' => JobBookingStatus.completed,
    'cancelled' => JobBookingStatus.cancelled,
    'no_partner_found' => JobBookingStatus.noPartnerFound,
    _ => JobBookingStatus.pending,
  };

  String get label => switch (this) {
    JobBookingStatus.pending => 'Pending',
    JobBookingStatus.searchingPartner => 'Searching partner',
    JobBookingStatus.partnerAssigned => 'Partner assigned',
    JobBookingStatus.accepted => 'Accepted',
    JobBookingStatus.onTheWay => 'On The Way',
    JobBookingStatus.arrived => 'Arrived',
    JobBookingStatus.inProgress => 'In Progress',
    JobBookingStatus.completed => 'Completed',
    JobBookingStatus.cancelled => 'Cancelled',
    JobBookingStatus.noPartnerFound => 'No partner found',
  };
}

class JobCustomerSummary {
  const JobCustomerSummary({required this.id, required this.name, this.phone});

  factory JobCustomerSummary.fromJson(Object? value) {
    if (value is String) {
      return JobCustomerSummary(id: value, name: 'Customer');
    }
    if (value is! Map<String, dynamic>) {
      return const JobCustomerSummary(id: '', name: 'Customer');
    }

    return JobCustomerSummary(
      id: _id(value),
      name: _text(value['name']) ?? 'Customer',
      phone: _text(value['phone']),
    );
  }

  final String id;
  final String name;
  final String? phone;
}

class JobServiceSummary {
  const JobServiceSummary({
    required this.id,
    required this.name,
    this.estimatedDurationMinutes,
  });

  factory JobServiceSummary.fromJson(Object? value) {
    if (value is String) {
      return JobServiceSummary(id: value, name: 'Service');
    }
    if (value is! Map<String, dynamic>) {
      return const JobServiceSummary(id: '', name: 'Service');
    }

    return JobServiceSummary(
      id: _id(value),
      name: _text(value['name']) ?? 'Service',
      estimatedDurationMinutes: (value['estimatedDurationMinutes'] as num?)
          ?.toInt(),
    );
  }

  final String id;
  final String name;
  final int? estimatedDurationMinutes;
}

class JobAddressSnapshot {
  const JobAddressSnapshot({
    required this.fullAddress,
    required this.city,
    required this.state,
    required this.pincode,
    required this.latitude,
    required this.longitude,
  });

  factory JobAddressSnapshot.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      return const JobAddressSnapshot(
        fullAddress: '',
        city: '',
        state: '',
        pincode: '',
        latitude: 0,
        longitude: 0,
      );
    }

    return JobAddressSnapshot(
      fullAddress: _text(value['fullAddress']) ?? '',
      city: _text(value['city']) ?? '',
      state: _text(value['state']) ?? '',
      pincode: _text(value['pincode']) ?? '',
      latitude: _decimal(value['latitude']) ?? 0,
      longitude: _decimal(value['longitude']) ?? 0,
    );
  }

  final String fullAddress;
  final String city;
  final String state;
  final String pincode;
  final double latitude;
  final double longitude;

  bool get hasCoordinates => latitude != 0 || longitude != 0;

  String get areaLine =>
      [city, state].where((part) => part.isNotEmpty).join(', ');

  String get oneLine => [
    fullAddress,
    city,
    state,
    pincode,
  ].where((part) => part.isNotEmpty).join(', ');
}

class JobPrice {
  const JobPrice({
    required this.baseAmount,
    required this.currency,
    this.finalAmount,
  });

  factory JobPrice.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      return const JobPrice(baseAmount: 0, currency: 'INR');
    }

    return JobPrice(
      baseAmount: _decimal(value['baseAmount']) ?? 0,
      finalAmount: _decimal(value['finalAmount']),
      currency: _text(value['currency']) ?? 'INR',
    );
  }

  final double baseAmount;
  final double? finalAmount;
  final String currency;

  String get displayLabel => _rupees(finalAmount ?? baseAmount);
  bool get isEstimate => finalAmount == null;
}

class JobBookingSummary {
  const JobBookingSummary({
    required this.id,
    required this.customer,
    required this.service,
    required this.address,
    required this.bookingType,
    required this.status,
    this.scheduledAt,
    this.price,
    this.notes,
    this.acceptedAt,
    this.onTheWayAt,
    this.arrivedAt,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
  });

  factory JobBookingSummary.fromJson(Object? value) {
    if (value is String) {
      return JobBookingSummary(
        id: value,
        customer: const JobCustomerSummary(id: '', name: 'Customer'),
        service: const JobServiceSummary(id: '', name: 'Service'),
        address: const JobAddressSnapshot(
          fullAddress: '',
          city: '',
          state: '',
          pincode: '',
          latitude: 0,
          longitude: 0,
        ),
        bookingType: JobBookingType.instant,
        status: JobBookingStatus.pending,
      );
    }
    if (value is! Map<String, dynamic>) {
      return JobBookingSummary.fromJson('');
    }

    final price = value['price'];

    return JobBookingSummary(
      id: _id(value),
      customer: JobCustomerSummary.fromJson(value['customerId']),
      service: JobServiceSummary.fromJson(value['serviceId']),
      address: JobAddressSnapshot.fromJson(value['addressSnapshot']),
      bookingType: JobBookingType.parse(value['bookingType']),
      status: JobBookingStatus.parse(value['status']),
      scheduledAt: _dateTime(value['scheduledAt']),
      price: price is Map<String, dynamic> ? JobPrice.fromJson(price) : null,
      notes: _text(value['notes']),
      acceptedAt: _dateTime(value['acceptedAt']),
      onTheWayAt: _dateTime(value['onTheWayAt']),
      arrivedAt: _dateTime(value['arrivedAt']),
      startedAt: _dateTime(value['startedAt']),
      completedAt: _dateTime(value['completedAt']),
      cancelledAt: _dateTime(value['cancelledAt']),
    );
  }

  final String id;
  final JobCustomerSummary customer;
  final JobServiceSummary service;
  final JobAddressSnapshot address;
  final JobBookingType bookingType;
  final JobBookingStatus status;
  final DateTime? scheduledAt;
  final JobPrice? price;
  final String? notes;
  final DateTime? acceptedAt;
  final DateTime? onTheWayAt;
  final DateTime? arrivedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  String get reference =>
      id.length >= 6 ? 'SWZ-${id.substring(id.length - 6).toUpperCase()}' : id;

  String get scheduledLabel {
    if (bookingType == JobBookingType.instant || scheduledAt == null) {
      return 'Now';
    }

    final local = scheduledAt!.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month}/${local.year} $hour:$minute';
  }
}

class JobOffer {
  const JobOffer({
    required this.id,
    required this.status,
    required this.offeredAt,
    required this.expiresAt,
    required this.booking,
    this.respondedAt,
    this.distanceKm,
  });

  factory JobOffer.fromJson(Map<String, dynamic> json) {
    return JobOffer(
      id: _id(json),
      status: JobOfferStatus.parse(json['status']),
      offeredAt: _dateTime(json['offeredAt']) ?? DateTime.now(),
      expiresAt: _dateTime(json['expiresAt']) ?? DateTime.now(),
      respondedAt: _dateTime(json['respondedAt']),
      distanceKm: _decimal(json['distanceKm']),
      booking: JobBookingSummary.fromJson(json['bookingId']),
    );
  }

  final String id;
  final JobOfferStatus status;
  final DateTime offeredAt;
  final DateTime expiresAt;
  final DateTime? respondedAt;
  final double? distanceKm;
  final JobBookingSummary booking;

  bool get isOpen =>
      status == JobOfferStatus.offered && expiresAt.isAfter(DateTime.now());

  String get distanceLabel {
    final distance = distanceKm;
    if (distance == null) {
      return 'Not available';
    }
    return '${distance.toStringAsFixed(distance < 10 ? 1 : 0)} km';
  }
}

String _id(Map<String, dynamic> json) {
  final id = json['_id'] ?? json['id'];
  return id is String ? id : id?.toString() ?? '';
}

String? _text(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

double? _decimal(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

DateTime? _dateTime(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value)?.toLocal();
}

String _rupees(double amount) {
  final text = amount == amount.roundToDouble()
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(2);
  return '₹$text';
}
