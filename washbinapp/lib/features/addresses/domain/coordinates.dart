/// A point on the map, in the order the API expects it.
class Coordinates {
  const Coordinates({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  String toString() =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

  @override
  bool operator ==(Object other) =>
      other is Coordinates &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

/// What reverse geocoding could work out about a point.
///
/// Every field is optional: the platform geocoder is best-effort, and on a
/// new estate or a rural road it routinely returns only a city. The form
/// prefills with whatever came back and the customer fixes the rest.
class PlaceDescription {
  const PlaceDescription({this.street, this.city, this.state, this.pincode});

  final String? street;
  final String? city;
  final String? state;
  final String? pincode;

  bool get isEmpty =>
      street == null && city == null && state == null && pincode == null;
}
