enum PartnerAvailabilityState {
  offline,
  available,
  busy;

  String get label => switch (this) {
    PartnerAvailabilityState.offline => 'Offline',
    PartnerAvailabilityState.available => 'Online',
    PartnerAvailabilityState.busy => 'Busy',
  };
}

class PartnerCoordinates {
  const PartnerCoordinates({required this.latitude, required this.longitude});

  factory PartnerCoordinates.fromGeoJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      return const PartnerCoordinates(latitude: 0, longitude: 0);
    }

    final coordinates = value['coordinates'];
    if (coordinates is! List || coordinates.length < 2) {
      return const PartnerCoordinates(latitude: 0, longitude: 0);
    }

    return PartnerCoordinates(
      latitude: (coordinates[1] as num?)?.toDouble() ?? 0,
      longitude: (coordinates[0] as num?)?.toDouble() ?? 0,
    );
  }

  final double latitude;
  final double longitude;

  bool get isKnown => latitude != 0 || longitude != 0;
}

class PartnerAvailability {
  const PartnerAvailability({
    required this.isOnline,
    required this.isAvailable,
    this.currentLocation,
    this.serviceRadiusKm,
    this.lastLocationUpdatedAt,
    this.updatedAt,
  });

  factory PartnerAvailability.fromJson(Map<String, dynamic> json) {
    final location = PartnerCoordinates.fromGeoJson(json['currentLocation']);

    return PartnerAvailability(
      isOnline: json['isOnline'] as bool? ?? false,
      isAvailable: json['isAvailable'] as bool? ?? false,
      currentLocation: location.isKnown ? location : null,
      serviceRadiusKm: (json['serviceRadiusKm'] as num?)?.toDouble(),
      lastLocationUpdatedAt: DateTime.tryParse(
        json['lastLocationUpdatedAt'] as String? ?? '',
      ),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }

  final bool isOnline;
  final bool isAvailable;
  final PartnerCoordinates? currentLocation;
  final double? serviceRadiusKm;
  final DateTime? lastLocationUpdatedAt;
  final DateTime? updatedAt;

  PartnerAvailabilityState get state {
    if (!isOnline) {
      return PartnerAvailabilityState.offline;
    }
    return isAvailable
        ? PartnerAvailabilityState.available
        : PartnerAvailabilityState.busy;
  }
}
