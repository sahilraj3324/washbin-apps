import 'package:flutter/material.dart';
import 'package:washbinapp/core/api/api_exception.dart';
import 'package:washbinapp/core/session/session_scope.dart';
import 'package:washbinapp/core/theme/app_theme.dart';
import 'package:washbinapp/features/auth/data/phone_number_input.dart';
import 'package:washbinapp/features/auth/widgets/auth_error_text.dart';
import 'package:washbinapp/features/auth/widgets/auth_scaffold.dart';
import 'package:washbinapp/features/auth/widgets/auth_text_field.dart';

/// Shown only when a verified number has no Washbin account yet. The number is
/// already confirmed at this point, so all that is missing is a name.
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
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
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
      // this screen, so there is nothing to navigate to here.
      await SessionScope.read(
        context,
      ).submitProfile(name: _nameController.text, email: _emailController.text);
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
      title: 'Almost done',
      subtitle: phoneNumber == null
          ? 'Your number is verified. Tell us your name to finish setting up.'
          : '${formatForDisplay(phoneNumber)} is verified. '
                'Tell us your name to finish setting up.',
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
                controller: _nameController,
                label: 'Full name',
                icon: Icons.person_outline_rounded,
                autofillHints: const [AutofillHints.name],
                enabled: !_isSubmitting,
                validator: _validateName,
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
              const SizedBox(height: 10),
              const Text(
                'We only use your email for booking receipts.',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
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
                label: Text(
                  _isSubmitting ? 'Creating account...' : 'Create account',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validateName(String? value) {
    if ((value?.trim() ?? '').length < 2) {
      return 'Enter your full name';
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
