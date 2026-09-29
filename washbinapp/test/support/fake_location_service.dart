import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:washbinapp/features/addresses/data/location_service.dart';
import 'package:washbinapp/features/addresses/domain/coordinates.dart';

/// Stands in for the device: no GPS, no permission dialog, no geocoder.
///
/// Overrides [currentPosition] and [describe] rather than the plugin seams
/// beneath them, because a widget test has no platform channels to answer.
class FakeLocationService extends LocationService {
  FakeLocationService({
    this.position = const Coordinates(latitude: 19.076, longitude: 72.8777),
    this.place = const PlaceDescription(
      street: 'Marine Drive',
      city: 'Mumbai',
      state: 'Maharashtra',
      pincode: '400020',
    ),
    this.failure,
  });

  Coordinates position;
  PlaceDescription place;

  /// Set to make every request fail the way a real refusal would.
  LocationException? failure;

  var requests = 0;
  var settingsOpened = 0;

  @override
  Future<Coordinates> currentPosition() async {
    requests++;
    final failure = this.failure;

    if (failure != null) {
      throw failure;
    }
    return position;
  }

  @override
  Future<PlaceDescription> describe(Coordinates point) async => place;

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }

  @override
  Future<List<geocoding.Placemark>> placemarksFor(
    double latitude,
    double longitude,
  ) async => const [];
}
