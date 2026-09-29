import 'package:flutter/material.dart';
import 'package:washbinapp/app/app_services_scope.dart';
import 'package:washbinapp/app/router/app_router.dart';
import 'package:washbinapp/core/api/api_exception.dart';
import 'package:washbinapp/core/config/app_config.dart';
import 'package:washbinapp/core/session/session_scope.dart';
import 'package:washbinapp/core/theme/app_theme.dart';
import 'package:washbinapp/features/auth/data/phone_number_input.dart';

/// The profile tab. Editing lands in a later phase; for now this shows who is
/// signed in and provides the way out.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isSigningOut = false;
  bool _isCheckingHealth = false;
  String? _healthResult;
  bool _isSweeping = false;
  String? _sweepResult;

  Future<void> _signOut() async {
    final session = SessionScope.read(context);
    setState(() => _isSigningOut = true);

    // No navigation here: AppGate rebuilds on the session change and the
    // signed-in half of the app stops existing.
    await session.signOut();
  }

  Future<void> _checkBackend() async {
    final health = AppServicesScope.of(context).health;
    setState(() {
      _isCheckingHealth = true;
      _healthResult = null;
    });

    try {
      final result = await health.check();
      if (mounted) {
        setState(() => _healthResult = result.summary);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _healthResult = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingHealth = false);
      }
    }
  }

  /// Runs the work the platform cron normally does — closing lapsed offers
  /// and waking scheduled bookings whose time has come.
  ///
  /// Here so a scheduled booking can be dispatched on demand rather than by
  /// waiting for the next cron tick.
  Future<void> _runSweep() async {
    final devTools = AppServicesScope.of(context).devTools;
    setState(() {
      _isSweeping = true;
      _sweepResult = null;
    });

    try {
      final result = await devTools.runDispatchSweep();
      if (mounted) {
        setState(() => _sweepResult = result.summary);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _sweepResult = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _isSweeping = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customer = SessionScope.of(context).customer;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppTheme.red.withValues(alpha: 0.12),
              child: const Icon(
                Icons.person_rounded,
                color: AppTheme.red,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer?.name ?? 'Your account',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    customer == null ? '' : formatForDisplay(customer.phone),
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (customer?.email != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      customer!.email!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        _ProfileAction(
          icon: Icons.location_on_outlined,
          title: 'Saved addresses',
          subtitle: 'Home, work, and anywhere else you book for',
          onTap: () => Navigator.of(context).push(AppRouter.addressBook()),
        ),
        const SizedBox(height: 20),
        if (!AppConfig.isProduction) ...[
          _DeveloperCard(
            baseUrl: AppConfig.baseUrl,
            environment: AppConfig.environment.name,
            result: _healthResult,
            isChecking: _isCheckingHealth,
            onCheck: _isCheckingHealth ? null : _checkBackend,
            sweepResult: _sweepResult,
            isSweeping: _isSweeping,
            onSweep: _isSweeping ? null : _runSweep,
          ),
          const SizedBox(height: 20),
        ],
        OutlinedButton.icon(
          onPressed: _isSigningOut ? null : _signOut,
          icon: const Icon(Icons.logout_rounded),
          label: Text(_isSigningOut ? 'Signing out...' : 'Sign out'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.red,
            minimumSize: const Size.fromHeight(52),
            side: const BorderSide(color: AppTheme.line),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.line),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.red),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Build information and a manual connectivity check. Hidden in production
/// builds — startup never pings the server, so this is the way to confirm the
/// app is pointed at a backend that is actually up.
class _DeveloperCard extends StatelessWidget {
  const _DeveloperCard({
    required this.baseUrl,
    required this.environment,
    required this.result,
    required this.isChecking,
    required this.onCheck,
    required this.sweepResult,
    required this.isSweeping,
    required this.onSweep,
  });

  final String baseUrl;
  final String environment;
  final String? result;
  final bool isChecking;
  final VoidCallback? onCheck;
  final String? sweepResult;
  final bool isSweeping;
  final VoidCallback? onSweep;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Build: $environment',
            style: const TextStyle(
              color: AppTheme.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            baseUrl,
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onCheck,
            icon: const Icon(Icons.network_check_rounded, size: 18),
            label: Text(
              isChecking ? 'Checking...' : 'Check backend connection',
            ),
          ),
          if (result != null)
            Text(
              result!,
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          const Divider(height: 20, color: AppTheme.line),
          const Text(
            'Runs what the cron runs: lapsed offers, then scheduled '
            'bookings that are due.',
            style: TextStyle(
              color: AppTheme.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          TextButton.icon(
            onPressed: onSweep,
            icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
            label: Text(isSweeping ? 'Running...' : 'Run dispatch sweep'),
          ),
          if (sweepResult != null)
            Text(
              sweepResult!,
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}
