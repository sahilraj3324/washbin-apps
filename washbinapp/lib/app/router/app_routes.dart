/// Route names, used for `RouteSettings` so navigation is observable in logs
/// and analytics rather than anonymous.
///
/// Which of these is reachable is decided by [AppGate] from the session, not
/// by a screen pushing one — see `app/app_gate.dart`.
class AppRoutes {
  const AppRoutes._();

  static const splash = '/splash';
  static const login = '/login';
  static const otp = '/otp';
  static const profileSetup = '/profile-setup';
  static const home = '/home';

  static const services = '/services';
  static const categoryServices = '/category-services';
  static const serviceDetail = '/service-detail';

  static const addresses = '/addresses';
  static const addressForm = '/address-form';
  static const chooseLocation = '/choose-location';

  static const bookings = '/bookings';
  static const bookingSetup = '/booking-setup';
  static const bookingSummary = '/booking-summary';
  static const bookingCreated = '/booking-created';
  static const bookingTracking = '/booking-tracking';

  // Reserved for later phases.

  static const notifications = '/notifications';
  static const profile = '/profile';
}
