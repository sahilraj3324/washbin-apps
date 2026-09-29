import 'package:washbinapp/features/catalogue/domain/json_field.dart';

/// The bit of a partner a customer is allowed to see.
///
/// Not currently sent by the API. `GET /bookings/:id` returns only
/// `assignedPartnerId`, and the one route that reads a partner —
/// `GET /partners/:id` — is an unauthenticated admin route that answers with
/// verification documents, the Firebase uid and the partner's email. None of
/// that belongs on a customer's device, so this app does not call it.
///
/// Everything here is therefore optional, and the tracking screen shows only
/// what it actually has. The day the booking response carries an
/// `assignedPartner` object with these fields, the panel fills in with no
/// further change.
class PartnerSummary {
  const PartnerSummary({
    required this.id,
    this.name,
    this.phone,
    this.rating,
    this.distanceKm,
    this.photoUrl,
  });

  factory PartnerSummary.fromJson(Map<String, dynamic> json) {
    return PartnerSummary(
      id: JsonField.id(json),
      // `ownerName` is the person who turns up; `businessName` is the trading
      // name, which is the better fallback of the two.
      name:
          JsonField.text(json['ownerName']) ??
          JsonField.text(json['name']) ??
          JsonField.text(json['businessName']),
      phone: JsonField.text(json['phone']),
      rating: JsonField.decimal(json['rating']),
      distanceKm: JsonField.decimal(json['distanceKm']),
      photoUrl: JsonField.text(json['photoUrl']),
    );
  }

  final String id;
  final String? name;
  final String? phone;
  final double? rating;
  final double? distanceKm;
  final String? photoUrl;

  /// Nothing is written to `Partner.rating` yet — the reviews module is an
  /// empty placeholder — so a zero means "unrated", not "rated zero".
  bool get hasRating => rating != null && rating! > 0;

  String get ratingLabel => rating!.toStringAsFixed(1);

  String? get distanceLabel {
    final km = distanceKm;

    if (km == null) {
      return null;
    }
    return km < 1
        ? '${(km * 1000).round()} m away'
        : '${km.toStringAsFixed(1)} km away';
  }

  bool get canCall => (phone ?? '').isNotEmpty;
}
