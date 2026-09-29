import 'package:washbinapp/core/api/api_client.dart';
import 'package:washbinapp/features/bookings/domain/booking.dart';
import 'package:washbinapp/features/bookings/domain/booking_draft.dart';
import 'package:washbinapp/features/bookings/domain/booking_status.dart';

/// Creates and reads the signed-in customer's bookings.
///
/// Every route is scoped by the bearer token, so no customer id is ever sent
/// and no customer can read or create a booking in another's name.
class BookingRepository {
  BookingRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// Sends the booking.
  ///
  /// The server re-runs every validation the app just did — service active,
  /// address owned and usable, location serviceable, schedule in range, no
  /// clashing booking — so a rejection here is authoritative, not a surprise.
  Future<Booking> create(BookingDraft draft) async {
    return Booking.fromJson(await _api.postJson('/bookings', draft.toJson()));
  }

  /// The customer's bookings, newest first.
  Future<List<Booking>> getMyBookings({BookingStatus? status}) async {
    final json = await _api.getJsonList(
      '/bookings',
      query: {if (status != null) 'status': status.wireValue},
    );

    return json
        .cast<Map<String, dynamic>>()
        .map(Booking.fromJson)
        .toList(growable: false);
  }

  Future<Booking> getBooking(String id) async {
    return Booking.fromJson(await _api.getJson('/bookings/$id'));
  }

  /// Rejected with 409 from a status the server does not allow cancelling
  /// from, such as in_progress or completed.
  Future<Booking> cancel(String id) async {
    return Booking.fromJson(await _api.patchJson('/bookings/$id/cancel', {}));
  }
}
