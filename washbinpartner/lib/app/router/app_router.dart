import 'package:flutter/material.dart';
import 'package:washbinpartner/app/router/app_routes.dart';
import 'package:washbinpartner/features/auth/data/phone_auth_service.dart';
import 'package:washbinpartner/features/auth/screens/otp_screen.dart';
import 'package:washbinpartner/features/auth/screens/phone_screen.dart';
import 'package:washbinpartner/features/home/screens/partner_shell.dart';
import 'package:washbinpartner/features/onboarding/screens/onboarding_screen.dart';
import 'package:washbinpartner/features/partner/domain/partner.dart';
import 'package:washbinpartner/features/profile/screens/profile_edit_screen.dart';
import 'package:washbinpartner/features/services/screens/my_services_screen.dart';

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

  /// Returns true when the profile was saved.
  static Route<bool?> profileEdit(Partner partner) {
    return MaterialPageRoute<bool?>(
      settings: const RouteSettings(name: AppRoutes.profileEdit),
      builder: (_) => ProfileEditScreen(partner: partner),
    );
  }

  static Route<void> myServices({VoidCallback? onChanged}) {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: AppRoutes.myServices),
      builder: (_) => MyServicesScreen(onChanged: onChanged),
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

  /// An unapproved partner's navigator starts at the onboarding screen, with
  /// the profile and services forms pushed over it.
  static Route<void>? onGenerateOnboardingRoute(RouteSettings settings) {
    return switch (settings.name) {
      AppRoutes.onboarding || Navigator.defaultRouteName =>
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: AppRoutes.onboarding),
          builder: (_) => const OnboardingScreen(),
        ),
      _ => null,
    };
  }

  /// The approved partner's navigator starts at the tab shell. Later phases
  /// push job and booking detail over it, covering the tab bar.
  static Route<void>? onGenerateSignedInRoute(RouteSettings settings) {
    return switch (settings.name) {
      AppRoutes.home || Navigator.defaultRouteName => MaterialPageRoute<void>(
        settings: const RouteSettings(name: AppRoutes.home),
        builder: (_) => const PartnerShell(),
      ),
      _ => null,
    };
  }
}
