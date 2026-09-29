import 'package:flutter/material.dart';
import 'package:washbinpartner/core/api/api_exception.dart';
import 'package:washbinpartner/core/session/session_scope.dart';
import 'package:washbinpartner/core/theme/app_theme.dart';
import 'package:washbinpartner/features/auth/data/phone_number_input.dart';
import 'package:washbinpartner/features/auth/widgets/auth_error_text.dart';
import 'package:washbinpartner/features/auth/widgets/auth_scaffold.dart';
import 'package:washbinpartner/features/auth/widgets/auth_text_field.dart';

/// Shown only when a verified number has no partner account yet. The number is
/// already confirmed at this point, so what is missing is the business itself.
///
/// Reached by the session entering `profileIncomplete`, never by a push — the
/// verified Firebase token it needs is held by `SessionController`.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _businessNameController.dispose();
    _ownerNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      // On success the session flips to authenticated and AppGate replaces
      // this screen — with the verification-pending screen, because that is
      // what a brand new partner is.
      await SessionScope.read(context).submitProfile(
        businessName: _businessNameController.text,
        ownerName: _ownerNameController.text,
        email: _emailController.text,
      );
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final phoneNumber = session.pendingPhoneNumber;

    return AuthScaffold(
      title: 'Register your business',
      subtitle: phoneNumber == null
          ? 'Your number is verified. Now tell us who you are.'
          : '${formatForDisplay(phoneNumber)} is verified. '
                'Now tell us who you are.',
      // The code that got here has already been spent, so going back means
      // starting again from the number rather than returning to a dead OTP.
      onBack: _isSubmitting ? null : session.cancelProfileSetup,
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthTextField(
                controller: _businessNameController,
                label: 'Business name',
                icon: Icons.store_mall_directory_outlined,
                enabled: !_isSubmitting,
                validator: (value) => _validateName(value, 'business name'),
              ),
              const SizedBox(height: 14),
              AuthTextField(
                controller: _ownerNameController,
                label: 'Owner full name',
                icon: Icons.person_outline_rounded,
                autofillHints: const [AutofillHints.name],
                enabled: !_isSubmitting,
                validator: (value) => _validateName(value, 'own name'),
              ),
              const SizedBox(height: 14),
              AuthTextField(
                controller: _emailController,
                label: 'Email address (optional)',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.done,
                enabled: !_isSubmitting,
                validator: _validateOptionalEmail,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.line),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      color: AppTheme.red,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'You can sign in straight away. Washbin verifies your '
                        'documents before you can accept bookings.',
                        style: TextStyle(
                          color: AppTheme.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                AuthErrorText(message: _errorMessage!),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(_isSubmitting ? 'Registering...' : 'Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validateName(String? value, String label) {
    if ((value?.trim() ?? '').length < 2) {
      return 'Enter your $label';
    }
    return null;
  }

  String? _validateOptionalEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return null;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email, or leave this blank';
    }
    return null;
  }
}
