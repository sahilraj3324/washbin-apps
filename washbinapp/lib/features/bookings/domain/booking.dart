import 'package:washbinapp/features/bookings/domain/booking_status.dart';
import 'package:washbinapp/features/bookings/domain/partner_summary.dart';
import 'package:washbinapp/features/catalogue/domain/json_field.dart';

/// Where the work is, copied at booking time.
///
/// The customer can later edit or delete the saved address; this says where
/// the partner was actually sent.
class BookingAddressSnapshot {
  const BookingAddressSnapshot({
    required this.fullAddress,
    required this.city,
    required this.state,
    required this.pincode,
    required this.latitude,
    required this.longitude,
  });

  factory BookingAddressSnapshot.fromJson(Map<String, dynamic> json) {
    return BookingAddressSnapshot(
      fullAddress: json['fullAddress'] as String? ?? '',
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      pincode: json['pincode'] as String? ?? '',
      latitude: JsonField.decimal(json['latitude']) ?? 0,
      longitude: JsonField.decimal(json['longitude']) ?? 0,
    );
  }

  final String fullAddress;
  final String city;
  final String state;
  final String pincode;
  final double latitude;
  final double longitude;

  String get oneLine => '$fullAddress, $city, $state $pincode';
}

/// What the booking costs, as the server worked it out.
class BookingPrice {
  const BookingPrice({
    required this.baseAmount,
    required this.currency,
    this.finalAmount,
  });

  factory BookingPrice.fromJson(Map<String, dynamic> json) {
    return BookingPrice(
      baseAmount: JsonField.decimal(json['baseAmount']) ?? 0,
      currency: json['currency'] as String? ?? 'INR',
      finalAmount: JsonField.decimal(json['finalAmount']),
    );
  }

  /// The service's price at booking time, not read live afterwards.
  final double baseAmount;

  /// What is actually owed. Only set at creation for `fixed` pricing; hourly
  /// and starting-from services are settled once the work is done.
  final double? finalAmount;

  final String currency;

  String get baseLabel => _rupees(baseAmount);

  /// The amount to show, and whether it is final or still an estimate.
  String get displayLabel => _rupees(finalAmount ?? baseAmount);

  bool get isEstimate => finalAmount == null;

  static String _rupees(double amount) {
    final text = amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    return '₹$text';
  }
}

/// A service request, as `POST /bookings` and `GET /bookings` describe it.
class Booking {
  const Booking({
    required this.id,
    required this.serviceId,
    required this.addressId,
    required this.addressSnapshot,
    required this.bookingType,
    required this.status,
    this.scheduledAt,
    this.price,
    this.notes,
    this.createdAt,
    this.assignedPartnerId,
    this.assignedPartner,
    this.etaMinutes,
    this.serviceStartOtp,
    this.serviceStartOtpExpiresAt,
    this.acceptedAt,
    this.onTheWayAt,
    this.arrivedAt,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.cancelledBy,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    final snapshot = json['addressSnapshot'];
    final price = json['price'];

    return Booking(
      id: JsonField.id(json),
      serviceId: JsonField.reference(json['serviceId']),
      addressId: JsonField.reference(json['addressId']),
      addressSnapshot: snapshot is Map<String, dynamic>
          ? BookingAddressSnapshot.fromJson(snapshot)
          : null,
      bookingType: BookingType.parse(json['bookingType']),
      status: BookingStatus.parse(json['status']),
      scheduledAt: _dateTime(json['scheduledAt']),
      price: price is Map<String, dynamic>
          ? BookingPrice.fromJson(price)
          : null,
      notes: JsonField.text(json['notes']),
      createdAt: _dateTime(json['createdAt']),
      assignedPartnerId: JsonField.text(
        json['assignedPartnerId'] == null
            ? null
            : JsonField.reference(json['assignedPartnerId']),
      ),
      // Not sent today. Read here so the tracking screen fills in the moment
      // the API starts including it — see PartnerSummary.
      assignedPartner: json['assignedPartner'] is Map<String, dynamic>
          ? PartnerSummary.fromJson(
              json['assignedPartner'] as Map<String, dynamic>,
            )
          : null,
      etaMinutes: JsonField.integer(json['etaMinutes']),
      serviceStartOtp: JsonField.text(json['serviceStartOtp']),
      serviceStartOtpExpiresAt: _dateTime(json['serviceStartOtpExpiresAt']),
      acceptedAt: _dateTime(json['acceptedAt']),
      onTheWayAt: _dateTime(json['onTheWayAt']),
      arrivedAt: _dateTime(json['arrivedAt']),
      startedAt: _dateTime(json['startedAt']),
      completedAt: _dateTime(json['completedAt']),
      cancelledAt: _dateTime(json['cancelledAt']),
      // Neither is stored by the API yet — a cancellation records only its
      // timestamp. Read here so the detail screen fills in the moment the
      // booking starts carrying them.
      cancellationReason: JsonField.text(json['cancellationReason']),
      cancelledBy: JsonField.text(json['cancelledBy']),
    );
  }

  final String id;
  final String serviceId;
  final String addressId;
  final BookingAddressSnapshot? addressSnapshot;
  final BookingType bookingType;
  final BookingStatus status;
  final DateTime? scheduledAt;
  final BookingPrice? price;
  final String? notes;
  final DateTime? createdAt;

  final String? assignedPartnerId;

  /// Null until the API sends partner details with the booking.
  final PartnerSummary? assignedPartner;

  /// Minutes until the partner arrives, when the API can say. There is no
  /// route computing this yet, and the app deliberately does not guess.
  final int? etaMinutes;

  /// Quoted to the partner to start the service — proof they reached the
  /// address. Stored in the clear precisely so this app can show it, and
  /// stripped from every partner-facing response.
  final String? serviceStartOtp;

  final DateTime? serviceStartOtpExpiresAt;

  // Stamped by the transition that reached each status. Together they are the
  // timeline, with no need to reconstruct anything.
  final DateTime? acceptedAt;
  final DateTime? onTheWayAt;
  final DateTime? arrivedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  /// Why it was called off, when the API can say.
  final String? cancellationReason;

  /// Who called it off — `customer`, `partner`, or `system`. Null today.
  final String? cancelledBy;

  String? get cancelledByLabel => switch (cancelledBy) {
    'customer' => 'You',
    'partner' => 'The partner',
    'system' || 'admin' => 'Washbin',
    final String value when value.isNotEmpty => value,
    _ => null,
  };

  /// A short handle a customer can quote to support.
  ///
  /// Derived from the id rather than stored: the API has no booking reference
  /// of its own, and the last six hex characters of an ObjectId are its
  /// counter and part of the machine id, so they differ between bookings made
  /// in the same second.
  String get reference => 'SWZ-${id.substring(id.length - 6).toUpperCase()}';

  bool get hasPartner => assignedPartnerId != null;

  /// The service-start code, only while it is worth showing.
  String? get liveStartOtp {
    final otp = serviceStartOtp;
    final expiry = serviceStartOtpExpiresAt;

    if (otp == null || otp.isEmpty) {
      return null;
    }
    if (expiry != null && expiry.isBefore(DateTime.now())) {
      return null;
    }
    return otp;
  }

  /// The API sends UTC; the customer thinks in local time.
  static DateTime? _dateTime(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value)?.toLocal();
  }
}
