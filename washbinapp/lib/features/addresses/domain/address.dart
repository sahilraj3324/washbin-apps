import 'package:washbinapp/features/catalogue/domain/json_field.dart';

/// What the customer calls this address. Mirrors `ADDRESS_LABELS` in the API.
enum AddressLabel {
  home('home', 'Home'),
  work('work', 'Work'),
  other('other', 'Other');

  const AddressLabel(this.wireValue, this.display);

  /// The exact string the API accepts; `name` would give `startingFrom`-style
  /// drift the moment a label becomes two words.
  final String wireValue;
  final String display;

  static AddressLabel parse(Object? value) => switch (value) {
    'work' => AddressLabel.work,
    'other' => AddressLabel.other,
    _ => AddressLabel.home,
  };
}

/// A place the customer has saved, as `GET /addresses/me` describes it.
class Address {
  const Address({
    required this.id,
    required this.label,
    required this.fullAddress,
    required this.city,
    required this.state,
    required this.pincode,
    required this.latitude,
    required this.longitude,
    this.houseNumber,
    this.landmark,
    this.isDefault = false,
    this.isActive = true,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: JsonField.id(json),
      label: AddressLabel.parse(json['label']),
      fullAddress: json['fullAddress'] as String? ?? '',
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      pincode: json['pincode'] as String? ?? '',
      latitude: JsonField.decimal(json['latitude']) ?? 0,
      longitude: JsonField.decimal(json['longitude']) ?? 0,
      houseNumber: JsonField.text(json['houseNumber']),
      landmark: JsonField.text(json['landmark']),
      isDefault: json['isDefault'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  final String id;
  final AddressLabel label;
  final String fullAddress;
  final String? houseNumber;
  final String? landmark;
  final String city;
  final String state;
  final String pincode;
  final double latitude;
  final double longitude;
  final bool isDefault;
  final bool isActive;

  /// The street line, with the flat number the map result usually missed.
  String get streetLine {
    final house = houseNumber;
    return house == null ? fullAddress : '$house, $fullAddress';
  }

  /// City, state and PIN on one line, for under the street.
  String get areaLine => '$city, $state $pincode';

  /// Everything, for a one-line summary in a confirmation.
  String get oneLine =>
      [streetLine, if (landmark != null) 'near $landmark', areaLine].join(', ');
}

/// The fields a customer fills in to save or change an address.
///
/// Separate from [Address] because it has no id, carries only what the write
/// routes accept, and can be half-filled while the form is open.
class AddressDraft {
  const AddressDraft({
    required this.label,
    required this.fullAddress,
    required this.city,
    required this.state,
    required this.pincode,
    required this.latitude,
    required this.longitude,
    this.houseNumber,
    this.landmark,
    this.isDefault,
  });

  final AddressLabel label;
  final String fullAddress;
  final String city;
  final String state;
  final String pincode;
  final double latitude;
  final double longitude;
  final String? houseNumber;
  final String? landmark;

  /// Left null when the form does not touch it — the API makes the first
  /// address the default on its own.
  final bool? isDefault;

  Map<String, dynamic> toJson() => {
    'label': label.wireValue,
    'fullAddress': fullAddress.trim(),
    'city': city.trim(),
    'state': state.trim(),
    'pincode': pincode.trim(),
    'latitude': latitude,
    'longitude': longitude,
    'houseNumber': ?houseNumber?.trim(),
    'landmark': ?landmark?.trim(),
    'isDefault': ?isDefault,
  };
}
