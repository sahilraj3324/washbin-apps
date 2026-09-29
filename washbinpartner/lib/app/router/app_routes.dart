/// Route names, used for `RouteSettings` so navigation is observable in logs
/// and analytics rather than anonymous.
///
/// Which of these is reachable is decided by [AppGate] from the session and
/// the partner's stage, not by a screen pushing one — see `app/app_gate.dart`.
class AppRoutes {
  const AppRoutes._();

  static const splash = '/splash';
  static const login = '/login';
  static const otp = '/otp';
  static const register = '/register';

  static const onboarding = '/onboarding';
  static const partnerStatus = '/partner-status';
  static const profileEdit = '/profile-edit';
  static const myServices = '/my-services';

  static const home = '/home';

  // Reserved for later phases: the tabs the shell already has room for.

  static const jobs = '/jobs';
  static const bookings = '/bookings';
  static const profile = '/profile';
}
