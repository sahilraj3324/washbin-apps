import 'package:flutter/material.dart';
import 'package:washbinpartner/app/app_services_scope.dart';
import 'package:washbinpartner/app/router/app_router.dart';
import 'package:washbinpartner/core/api/api_exception.dart';
import 'package:washbinpartner/core/config/app_config.dart';
import 'package:washbinpartner/core/session/session_scope.dart';
import 'package:washbinpartner/core/theme/app_theme.dart';
import 'package:washbinpartner/features/auth/data/phone_number_input.dart';
import 'package:washbinpartner/features/partner/domain/partner.dart';
import 'package:washbinpartner/features/partner/domain/profile_completeness.dart';

/// The profile tab: everything Washbin holds about this partner, and the way
/// out.
///
/// The same screen serves an approved partner and one still being reviewed —
/// which is why it shows verification state rather than assuming it is
/// settled.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isSigningOut = false;
  bool _isCheckingHealth = false;
  String? _healthResult;

  Future<void> _signOut() async {
    final session = SessionScope.read(context);
    setState(() => _isSigningOut = true);

    // No navigation here: AppGate rebuilds on the session change and the
    // signed-in half of the app stops existing.
    await session.signOut();
  }

  Future<void> _refresh() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await SessionScope.read(context).refreshPartner();
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
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

  @override
  Widget build(BuildContext context) {
    final partner = SessionScope.of(context).partner;

    if (partner == null) {
      return const SizedBox.shrink();
    }

    final completeness = ProfileCompleteness.of(partner);

    return RefreshIndicator(
      color: AppTheme.red,
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _Header(partner: partner),
          const SizedBox(height: 20),
          _VerificationRow(partner: partner),
          if (!completeness.isComplete) ...[
            const SizedBox(height: 12),
            _IncompleteNote(completeness: completeness),
          ],
          const SizedBox(height: 20),
          _Card(
            children: [
              _InfoRow(label: 'Owner', value: partner.ownerName),
              _InfoRow(
                label: 'Mobile',
                value: formatForDisplay(partner.phone),
              ),
              _InfoRow(label: 'Email', value: partner.email ?? 'Not added'),
              _InfoRow(
                label: 'Experience',
                value: partner.experienceYears == null
                    ? 'Not added'
                    : '${partner.experienceYears} '
                          '${partner.experienceYears == 1 ? 'year' : 'years'}',
              ),
              _InfoRow(
                label: 'Gender',
                value: partner.gender?.label ?? 'Not added',
              ),
              _InfoRow(
                label: 'Based at',
                value: partner.address?.summary ?? 'Not added',
              ),
              _InfoRow(
                label: 'Emergency',
                value: partner.emergencyContact == null
                    ? 'Not added'
                    : '${partner.emergencyContact!.name} · '
                          '${partner.emergencyContact!.phone}',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Action(
            icon: Icons.edit_outlined,
            title: 'Edit profile',
            subtitle: 'Business details, experience, and where you are based',
            onTap: () => Navigator.of(context).push(
              AppRouter.profileEdit(partner),
            ),
          ),
          const SizedBox(height: 10),
          _Action(
            icon: Icons.home_repair_service_outlined,
            title: 'My services',
            subtitle: 'Choose the work you take on',
            onTap: () => Navigator.of(context).push(AppRouter.myServices()),
          ),
          if (!AppConfig.isProduction) ...[
            const SizedBox(height: 20),
            _BackendCard(
              isChecking: _isCheckingHealth,
              result: _healthResult,
              onCheck: _checkBackend,
            ),
          ],
          const SizedBox(height: 20),
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
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.partner});

  final Partner partner;

  @override
  Widget build(BuildContext context) {
    final image = partner.profileImage;

    return Row(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: AppTheme.red.withValues(alpha: 0.12),
          // Uploading a photo is not built — there is no file storage behind
          // the API yet — but one set elsewhere is shown.
          backgroundImage: image == null ? null : NetworkImage(image),
          child: image != null
              ? null
              : const Icon(
                  Icons.store_mall_directory_rounded,
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
                partner.businessName,
                maxLines: 2,
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
                formatForDisplay(partner.phone),
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VerificationRow extends StatelessWidget {
  const _VerificationRow({required this.partner});

  final Partner partner;

  @override
  Widget build(BuildContext context) {
    final isApproved = partner.stage == PartnerStage.approved;
    final accent = isApproved ? const Color(0xFF1B8A4B) : AppTheme.red;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        children: [
          Icon(
            isApproved ? Icons.verified_rounded : Icons.hourglass_top_rounded,
            color: accent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              partner.stage.label,
              style: TextStyle(
                color: accent,
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IncompleteNote extends StatelessWidget {
  const _IncompleteNote({required this.completeness});

  final ProfileCompleteness completeness;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.red.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: Text(
        'Still to add: '
        '${completeness.missing.map((m) => m.label).join(', ')}.',
        style: const TextStyle(
          color: AppTheme.muted,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
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
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.line),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppTheme.red, size: 21),
              ),
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
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.muted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackendCard extends StatelessWidget {
  const _BackendCard({
    required this.isChecking,
    required this.result,
    required this.onCheck,
  });

  final bool isChecking;
  final String? result;
  final VoidCallback onCheck;

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
            'Connected to ${AppConfig.environment.name}',
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppConfig.baseUrl,
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: isChecking ? null : onCheck,
            icon: const Icon(Icons.cloud_done_outlined, size: 18),
            label: Text(
              isChecking ? 'Checking...' : 'Check backend connection',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.red,
              minimumSize: const Size.fromHeight(46),
              side: const BorderSide(color: AppTheme.line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          if (result != null) ...[
            const SizedBox(height: 10),
            Text(
              result!,
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
