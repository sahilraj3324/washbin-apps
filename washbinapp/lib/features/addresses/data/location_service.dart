import 'dart:async';

import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:washbinapp/features/addresses/domain/coordinates.dart';

/// Why the app could not read the customer's location. Each case needs a
/// different way out, which is why this is not just a message.
enum LocationFailure {
  /// Declined this time. Asking again is allowed.
  denied,

  /// Declined permanently, or blocked by device policy. Only Settings helps.
  deniedForever,

  /// Location is switched off for the whole device.
  serviceDisabled,

  /// A fix did not arrive in time — indoors, or no signal.
  timeout,
  unknown,
}

class LocationException implements Exception {
  const LocationException(this.failure, this.message);

  final LocationFailure failure;
  final String message;

  /// True when the only fix is the system settings screen, so the UI should
  /// offer to open it rather than an unhelpful "try again".
  bool get needsSettings =>
      failure == LocationFailure.deniedForever ||
      failure == LocationFailure.serviceDisabled;

  @override
  String toString() => message;
}

/// Location permission, a GPS fix, and turning a fix into an address.
///
/// Wraps the plugins rather than letting screens call them, so the flow can be
/// tested without a device and so every permission outcome is translated into
/// something a customer can act on exactly once, here.
class LocationService {
  LocationService();

  static const _fixTimeout = Duration(seconds: 20);

  /// geocoding 5 exposes reverse lookup on an instance rather than as a
  /// top-level function, and constructing one reaches the platform channel,
  /// so it is created lazily — a build that never geocodes never touches it.
  late final geocoding.Geocoding _geocoder = geocoding.Geocoding();

  /// Asks for permission if it has not been decided, and returns a fix.
  ///
  /// Throws [LocationException] for every refusal, so callers handle one type
  /// instead of a permission enum plus two plugin exceptions.
  Future<Coordinates> currentPosition() async {
    await _ensurePermission();

    try {
      final position = await getCurrentPosition().timeout(_fixTimeout);
      return Coordinates(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on TimeoutException {
      throw const LocationException(
        LocationFailure.timeout,
        'Could not get your location. Move somewhere with a clearer signal '
        'and try again.',
      );
    } on LocationServiceDisabledException {
      throw const LocationException(
        LocationFailure.serviceDisabled,
        'Location is switched off on this device. Turn it on to use your '
        'current location.',
      );
    }
  }

  Future<void> _ensurePermission() async {
    if (!await isLocationServiceEnabled()) {
      throw const LocationException(
        LocationFailure.serviceDisabled,
        'Location is switched off on this device. Turn it on to use your '
        'current location.',
      );
    }

    var permission = await checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await requestPermission();
    }

    switch (permission) {
      case LocationPermission.denied:
        throw const LocationException(
          LocationFailure.denied,
          'Washbin needs your location to find help nearby. You can also pick '
          'a saved address instead.',
        );
      case LocationPermission.deniedForever:
        throw const LocationException(
          LocationFailure.deniedForever,
          'Location is blocked for Washbin. Allow it in Settings, or pick a '
          'saved address instead.',
        );
      case LocationPermission.unableToDetermine:
        throw const LocationException(
          LocationFailure.unknown,
          'Could not check location permission. Please try again.',
        );
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        return;
    }
  }

  /// Best-effort street address for a point.
  ///
  /// Returns an empty description rather than throwing: a fix with no address
  /// is still a perfectly good fix, and the customer can type the rest.
  Future<PlaceDescription> describe(Coordinates point) async {
    try {
      final places = await placemarksFor(point.latitude, point.longitude);
      final place = places.firstOrNull;

      if (place == null) {
        return const PlaceDescription();
      }

      return PlaceDescription(
        street: _firstOf([place.street, place.subLocality, place.locality]),
        city: _firstOf([place.locality, place.subAdministrativeArea]),
        state: _firstOf([place.administrativeArea]),
        pincode: _firstOf([place.postalCode]),
      );
    } catch (_) {
      // No geocoder on the device, no network, or nothing found. None of
      // those should stop the customer saving an address.
      return const PlaceDescription();
    }
  }

  /// Opens the app's settings page so a permanent denial can be undone.
  Future<bool> openSettings() => openAppSettings();

  // Seams. Overriding these in a test avoids the plugins entirely, which is
  // the only way this flow runs without a device.
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  Future<Position> getCurrentPosition() => Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
  );

  Future<List<geocoding.Placemark>> placemarksFor(
    double latitude,
    double longitude,
  ) => _geocoder.placemarkFromCoordinates(latitude, longitude);

  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  static String? _firstOf(List<String?> candidates) {
    for (final candidate in candidates) {
      if (candidate != null && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return null;
  }
}
