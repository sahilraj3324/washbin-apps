import 'package:flutter/material.dart';
import 'package:washbinpartner/core/api/api_exception.dart';
import 'package:washbinpartner/core/session/session_controller.dart';
import 'package:washbinpartner/core/session/session_scope.dart';
import 'package:washbinpartner/core/theme/app_theme.dart';
import 'package:washbinpartner/features/auth/data/phone_number_input.dart';
import 'package:washbinpartner/features/common/widgets/washbin_logo.dart';
import 'package:washbinpartner/features/partner/domain/partner.dart';

/// A closed door: the partner is who they say they are, and Washbin is not
/// letting them in.
///
/// Only suspension reaches here. Pending, incomplete and rejected partners get
/// the onboarding flow instead, because each of those has something they can
/// actually do — see `AppGate`.
class PartnerStatusScreen extends StatefulWidget {
  const PartnerStatusScreen({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.partner,
  });

  /// The screen for a suspended partner the app has a record for.
  factory PartnerStatusScreen.forPartner(Partner partner) {
    return PartnerStatusScreen(
      title: 'Account suspended',
      message:
          'This partner account has been suspended. Contact Washbin support '
          'to find out why and what happens next.',
      icon: Icons.block_rounded,
      partner: partner,
    );
  }

  /// The screen for a verified number the server refused a token for, so there
  /// is no partner record to describe — only what the server said.
  factory PartnerStatusScreen.blocked({String? message}) {
    return PartnerStatusScreen(
      title: 'Account suspended',
      message:
          message ??
          'This partner account has been suspended. Contact Washbin support '
              'to find out why and what happens next.',
      icon: Icons.block_rounded,
    );
  }

  final String title;
  final String message;
  final IconData icon;

  /// Null in the blocked case: the server refused before it said who this is.
  final Partner? partner;

  @override
  State<PartnerStatusScreen> createState() => _PartnerStatusScreenState();
}

class _PartnerStatusScreenState extends State<PartnerStatusScreen> {
  bool _isChecking = false;
  bool _isSigningOut = false;
  String? _checkError;

  /// Asks the server whether anything has changed.
  ///
  /// A partner with a session re-reads their own record; a blocked one has no
  /// token, so the whole startup exchange runs again — which is also how a
  /// lifted suspension lets them back in.
  Future<void> _check() async {
    final session = SessionScope.read(context);
    setState(() {
      _isChecking = true;
      _checkError = null;
    });

    try {
      if (session.status == SessionStatus.authenticated) {
        await session.refreshPartner();
      } else {
        await session.start(holdSplash: false);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _checkError = error.message);
      }
    } finally {
      // The session may have moved on and taken this screen with it.
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);

    // No navigation: AppGate rebuilds on the session change.
    await SessionScope.read(context).signOut();
  }

  @override
  Widget build(BuildContext context) {
    const accent = AppTheme.darkRed;
    final partner = widget.partner;
    final busy = _isChecking || _isSigningOut;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          children: [
            const Center(child: WashbinLogo(size: 72)),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(widget.icon, color: accent, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            color: accent,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.message,
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                  ),
                  if (partner != null) ...[
                    const SizedBox(height: 18),
                    const Divider(color: AppTheme.line, height: 1),
                    const SizedBox(height: 16),
                    _DetailRow(
                      icon: Icons.store_mall_directory_outlined,
                      value: partner.businessName,
                    ),
                    const SizedBox(height: 10),
                    _DetailRow(
                      icon: Icons.person_outline_rounded,
                      value: partner.ownerName,
                    ),
                    const SizedBox(height: 10),
                    _DetailRow(
                      icon: Icons.phone_rounded,
                      value: formatForDisplay(partner.phone),
                    ),
                  ],
                ],
              ),
            ),
            if (_checkError != null) ...[
              const SizedBox(height: 16),
              Text(
                _checkError!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.darkRed,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: busy ? null : _check,
              icon: _isChecking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded),
              label: Text(_isChecking ? 'Checking...' : 'Check again'),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: busy ? null : _signOut,
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: Text(_isSigningOut ? 'Signing out...' : 'Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.muted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
