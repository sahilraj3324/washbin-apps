import 'package:flutter/material.dart';
import 'package:washbinapp/app/router/app_routes.dart';
import 'package:washbinapp/features/auth/data/phone_auth_service.dart';
import 'package:washbinapp/features/auth/screens/otp_screen.dart';
import 'package:washbinapp/features/auth/screens/phone_screen.dart';
import 'package:washbinapp/features/addresses/domain/address.dart';
import 'package:washbinapp/features/addresses/domain/coordinates.dart';
import 'package:washbinapp/features/addresses/screens/address_book_screen.dart';
import 'package:washbinapp/features/addresses/screens/address_form_screen.dart';
import 'package:washbinapp/features/addresses/screens/choose_location_screen.dart';
import 'package:washbinapp/features/bookings/domain/booking.dart';
import 'package:washbinapp/features/bookings/domain/booking_draft.dart';
import 'package:washbinapp/features/bookings/screens/booking_created_screen.dart';
import 'package:washbinapp/features/bookings/screens/booking_setup_screen.dart';
import 'package:washbinapp/features/bookings/screens/booking_tracking_screen.dart';
import 'package:washbinapp/features/bookings/screens/booking_summary_screen.dart';
import 'package:washbinapp/features/catalogue/domain/category.dart';
import 'package:washbinapp/features/notifications/screens/notifications_screen.dart';
import 'package:washbinapp/features/catalogue/domain/service.dart';
import 'package:washbinapp/features/catalogue/screens/service_detail_screen.dart';
import 'package:washbinapp/features/catalogue/screens/service_list_screen.dart';
import 'package:washbinapp/features/home/screens/home_shell.dart';

/// Builds the app's routes in one place.
///
/// These are typed factories rather than a `routes:` map keyed by string,
/// because [otp] needs a live `OtpDispatch` from Firebase and passing that
/// through `Object? arguments` would trade a compile-time check for a runtime
/// cast. The route still carries its name for observability.
class AppRouter {
  const AppRouter._();

  static Route<void> login() {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: AppRoutes.login),
      builder: (_) => const PhoneScreen(),
    );
  }

  static Route<void> otp({
    required String phoneNumber,
    required OtpDispatch dispatch,
  }) {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: AppRoutes.otp),
      builder: (_) => OtpScreen(phoneNumber: phoneNumber, dispatch: dispatch),
    );
  }

  static Route<void> categoryServices(Category category) {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: AppRoutes.categoryServices),
      builder: (_) => ServiceListScreen(category: category),
    );
  }

  static Route<void> serviceDetail(Service service) {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: AppRoutes.serviceDetail),
      builder: (_) => ServiceDetailScreen(service: service),
    );
  }

  static Route<void> addressBook() {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: AppRoutes.addresses),
      builder: (_) => const AddressBookScreen(),
    );
  }

  /// Returns the saved [Address], or null when the customer backed out.
  static Route<Address?> addressForm({
    Address? existing,
    Coordinates? initialPoint,
  }) {
    return MaterialPageRoute<Address?>(
      settings: const RouteSettings(name: AppRoutes.addressForm),
      builder: (_) =>
          AddressFormScreen(existing: existing, initialPoint: initialPoint),
    );
  }

  static Route<void> chooseLocation(Service service) {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: AppRoutes.chooseLocation),
      builder: (_) => ChooseLocationScreen(service: service),
    );
  }

  static Route<void> bookingSetup(BookingDraft draft) {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: AppRoutes.bookingSetup),
      builder: (_) => BookingSetupScreen(draft: draft),
    );
  }

  static Route<void> bookingSummary(BookingDraft draft) {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: AppRoutes.bookingSummary),
      builder: (_) => BookingSummaryScreen(draft: draft),
    );
  }

  static Route<void> bookingCreated({
    required Booking booking,
    required Service service,
  }) {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: AppRoutes.bookingCreated),
      builder: (_) => BookingCreatedScreen(booking: booking, service: service),
    );
  }

  static Route<void> bookingTracking({
    required String bookingId,
    String? serviceName,
    Booking? initial,
  }) {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: AppRoutes.bookingTracking),
      builder: (_) => BookingTrackingScreen(
        bookingId: bookingId,
        serviceName: serviceName,
        initial: initial,
      ),
    );
  }

  static Route<void> notifications() {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: AppRoutes.notifications),
      builder: (_) => const NotificationsScreen(),
    );
  }

  /// The auth flow's inner navigator only ever starts at the phone screen;
  /// every later step is pushed with the factories above.
  static Route<void>? onGenerateAuthRoute(RouteSettings settings) {
    return switch (settings.name) {
      AppRoutes.login || Navigator.defaultRouteName => login(),
      _ => null,
    };
  }

  /// The signed-in navigator starts at the tab shell. Catalogue screens are
  /// pushed over it, covering the tab bar, as a detail screen should.
  static Route<void>? onGenerateSignedInRoute(RouteSettings settings) {
    return switch (settings.name) {
      AppRoutes.home || Navigator.defaultRouteName => MaterialPageRoute<void>(
        settings: const RouteSettings(name: AppRoutes.home),
        builder: (_) => const HomeShell(),
      ),
      _ => null,
    };
  }
}
