import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:washbinpartner/features/availability/domain/partner_availability.dart';

enum PartnerLocationFailure {
  denied,
  deniedForever,
  serviceDisabled,
  timeout,
  unknown,
}

class PartnerLocationException implements Exception {
  const PartnerLocationException(this.failure, this.message);

  final PartnerLocationFailure failure;
  final String message;

  bool get needsSettings =>
      failure == PartnerLocationFailure.deniedForever ||
      failure == PartnerLocationFailure.serviceDisabled;

  @override
  String toString() => message;
}

class PartnerLocationService {
  PartnerLocationService();

  static const _fixTimeout = Duration(seconds: 20);

  Future<PartnerCoordinates> currentPosition() async {
    await _ensurePermission();

    try {
      final position = await getCurrentPosition().timeout(_fixTimeout);
      return PartnerCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on TimeoutException {
      throw const PartnerLocationException(
        PartnerLocationFailure.timeout,
        'Could not get your location. Move somewhere with a clearer signal and try again.',
      );
    } on LocationServiceDisabledException {
      throw const PartnerLocationException(
        PartnerLocationFailure.serviceDisabled,
        'Location is switched off on this device. Turn it on to go online.',
      );
    }
  }

  Future<void> _ensurePermission() async {
    if (!await isLocationServiceEnabled()) {
      throw const PartnerLocationException(
        PartnerLocationFailure.serviceDisabled,
        'Location is switched off on this device. Turn it on to go online.',
      );
    }

    var permission = await checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await requestPermission();
    }

    switch (permission) {
      case LocationPermission.denied:
        throw const PartnerLocationException(
          PartnerLocationFailure.denied,
          'Washbin needs your location before you can receive nearby jobs.',
        );
      case LocationPermission.deniedForever:
        throw const PartnerLocationException(
          PartnerLocationFailure.deniedForever,
          'Location is blocked for Washbin Partner. Allow it in Settings to go online.',
        );
      case LocationPermission.unableToDetermine:
        throw const PartnerLocationException(
          PartnerLocationFailure.unknown,
          'Could not check location permission. Please try again.',
        );
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        return;
    }
  }

  Future<bool> openSettings() => openAppSettings();

  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  Future<Position> getCurrentPosition() => Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
  );

  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}
