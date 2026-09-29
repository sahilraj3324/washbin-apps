import 'package:flutter/material.dart';
import 'package:washbinapp/core/session/session_scope.dart';
import 'package:washbinapp/core/theme/app_theme.dart';
import 'package:washbinapp/core/widgets/app_error_view.dart';

/// Shown when startup could not reach the server.
///
/// The customer is still signed in as far as Firebase is concerned — this is a
/// connectivity problem, not a sign-out — so the only action offered is to try
/// again, with signing out available for the case where it never recovers.
class StartupFailedScreen extends StatelessWidget {
  const StartupFailedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        child: AppErrorView(
          message: session.message ?? 'Washbin could not be reached. Check your connection and try again.',
          icon: Icons.wifi_off_rounded,
          onRetry: () => session.start(holdSplash: false),
          secondaryAction: TextButton(
            onPressed: session.signOut,
            child: const Text('Sign out instead'),
          ),
        ),
      ),
    );
  }
}
