import 'package:flutter/material.dart';
import 'package:washbinapp/app/app_services_scope.dart';
import 'package:washbinapp/app/router/app_router.dart';
import 'package:washbinapp/core/session/session_controller.dart';
import 'package:washbinapp/core/session/session_scope.dart';
import 'package:washbinapp/features/auth/screens/profile_setup_screen.dart';
import 'package:washbinapp/features/splash/screens/splash_screen.dart';
import 'package:washbinapp/features/splash/screens/startup_failed_screen.dart';

/// Decides which part of the app exists, from the session and nothing else.
///
/// This is the route protection: a signed-out customer does not navigate away
/// from the home screen, the home screen is simply not built. Screens never
/// check for themselves, so there is no way to reach a protected one by
/// pushing a route, restoring state, or following a link.
class AppGate extends StatelessWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);

    return switch (session.status) {
      SessionStatus.initializing => const SplashScreen(),
      SessionStatus.unauthenticated => const _AuthFlow(),
      SessionStatus.profileIncomplete => const ProfileSetupScreen(),
      SessionStatus.authenticated => const _SignedInFlow(),
      SessionStatus.failed => const StartupFailedScreen(),
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

/// The signed-in app, for the same reason: a category or service pushed over
/// the tab shell must not survive a sign-out. Because this stack is nested,
/// it goes away with the branch rather than sitting above the phone screen.
class _SignedInFlow extends StatelessWidget {
  const _SignedInFlow();

  @override
  Widget build(BuildContext context) {
    return _Flow(
      onGenerateRoute: AppRouter.onGenerateSignedInRoute,
      // Shared with the app services so a tapped push notification can open a
      // booking from outside the widget tree — and so it stops working the
      // moment this branch is torn down on sign-out.
      navigatorKey: AppServicesScope.of(context).signedInNavigatorKey,
    );
  }
}

class _Flow extends StatefulWidget {
  const _Flow({required this.onGenerateRoute, this.navigatorKey});

  final RouteFactory onGenerateRoute;

  /// Supplied when something outside the tree needs to navigate this stack.
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  State<_Flow> createState() => _FlowState();
}

class _FlowState extends State<_Flow> {
  late final GlobalKey<NavigatorState> _navigatorKey =
      widget.navigatorKey ?? GlobalKey<NavigatorState>();

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
