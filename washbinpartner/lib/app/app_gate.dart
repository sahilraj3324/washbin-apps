import 'package:flutter/material.dart';
import 'package:washbinpartner/app/router/app_router.dart';
import 'package:washbinpartner/core/session/session_controller.dart';
import 'package:washbinpartner/core/session/session_scope.dart';
import 'package:washbinpartner/features/auth/screens/profile_setup_screen.dart';
import 'package:washbinpartner/features/partner/domain/partner.dart';
import 'package:washbinpartner/features/splash/screens/splash_screen.dart';
import 'package:washbinpartner/features/splash/screens/startup_failed_screen.dart';
import 'package:washbinpartner/features/status/screens/partner_status_screen.dart';

/// Decides which part of the app exists, from the session and nothing else.
///
/// This is the route protection: a partner who is not approved does not
/// navigate away from the shell, the shell is simply not built. Screens never
/// check for themselves, so there is no way to reach a protected one by
/// pushing a route, restoring state, or following a link.
///
/// Two questions are asked, in order, and they are separate on purpose:
///
/// 1. **Is there a session?** — `SessionStatus`, owned by sign-in.
/// 2. **What is this partner allowed to do with it?** — `Partner.stage`,
///    owned by the backend's `status` and `verificationStatus`.
///
/// Adding a backend partner state later is a new arm of the second switch.
/// Sign-in does not move.
class AppGate extends StatelessWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);

    return switch (session.status) {
      SessionStatus.initializing => const SplashScreen(),
      SessionStatus.unauthenticated => const _AuthFlow(),
      SessionStatus.registrationRequired => const ProfileSetupScreen(),
      SessionStatus.blocked => PartnerStatusScreen.blocked(
        message: session.message,
      ),
      SessionStatus.failed => const StartupFailedScreen(),
      SessionStatus.authenticated => _forPartner(session.partner!),
    };
  }

  /// The backend recognises this partner. What it says about them decides
  /// whether they get the app, the onboarding flow, or a closed door.
  ///
  /// Live job requests live behind `_ApprovedFlow` and nowhere else, so an
  /// unapproved partner is not merely steered away from them — the screens
  /// that would show them are never built.
  static Widget _forPartner(Partner partner) {
    return switch (partner.stage) {
      PartnerStage.approved => const _ApprovedFlow(),

      // Three stages, one flow: all three are the same two tasks — finish the
      // profile, choose the services — seen at different points. The screen
      // itself varies the status and whether submitting is offered.
      PartnerStage.profileIncomplete ||
      PartnerStage.pendingApproval ||
      PartnerStage.rejected => const _OnboardingFlow(),

      // Not the onboarding flow: there is nothing a suspended partner could
      // edit that would change the decision, and offering the form would
      // suggest otherwise.
      PartnerStage.suspended => PartnerStatusScreen.forPartner(partner),
    };
  }
}

/// Sign-in is a short wizard — number, then code — so it gets its own
/// navigator. Keeping it nested means that when the session resolves, the
/// whole stack is discarded with this widget; a half-finished sign-in can
/// never be left sitting on top of the app.
class _AuthFlow extends StatelessWidget {
  const _AuthFlow();

  @override
  Widget build(BuildContext context) =>
      const _Flow(onGenerateRoute: AppRouter.onGenerateAuthRoute);
}

/// Onboarding, with the profile and service forms pushed over it. Nested so an
/// approval arriving while the partner is deep in a form replaces the whole
/// stack with the working app rather than leaving a form above it.
class _OnboardingFlow extends StatelessWidget {
  const _OnboardingFlow();

  @override
  Widget build(BuildContext context) =>
      const _Flow(onGenerateRoute: AppRouter.onGenerateOnboardingRoute);
}

/// The working app, for the same reason: a job or booking pushed over the tab
/// shell must not survive a sign-out, or a suspension arriving mid-session.
class _ApprovedFlow extends StatelessWidget {
  const _ApprovedFlow();

  @override
  Widget build(BuildContext context) =>
      const _Flow(onGenerateRoute: AppRouter.onGenerateSignedInRoute);
}

class _Flow extends StatefulWidget {
  const _Flow({required this.onGenerateRoute});

  final RouteFactory onGenerateRoute;

  @override
  State<_Flow> createState() => _FlowState();
}

class _FlowState extends State<_Flow> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return NavigatorPopHandler(
      // Without this the system back button addresses the root navigator,
      // which has a single route, and would close the app from a pushed screen.
      onPopWithResult: (_) => _navigatorKey.currentState?.maybePop(),
      child: Navigator(
        key: _navigatorKey,
        onGenerateRoute: widget.onGenerateRoute,
      ),
    );
  }
}
