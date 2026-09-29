import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:washbinpartner/app/app_services_scope.dart';
import 'package:washbinpartner/app/router/app_router.dart';
import 'package:washbinpartner/core/session/session_scope.dart';
import 'package:washbinpartner/core/theme/app_theme.dart';
import 'package:washbinpartner/features/auth/data/phone_auth_service.dart';
import 'package:washbinpartner/features/auth/data/phone_number_input.dart';
import 'package:washbinpartner/features/auth/widgets/auth_error_text.dart';
import 'package:washbinpartner/features/auth/widgets/auth_scaffold.dart';

/// Step one of sign-in: the partner's mobile number. There is no separate
/// login and register — the number decides which one this turns out to be.
class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isSending = false;
  String? _errorMessage;

  PhoneAuthService get _phoneAuth => AppServicesScope.of(context).phoneAuth;

  @override
  void initState() {
    super.initState();
    // Surfaces why the partner is back here — an expired session, or an
    // account the server refused — then clears it so it shows once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final session = SessionScope.read(context);
      final message = session.message;
      if (message != null) {
        setState(() => _errorMessage = message);
        session.acknowledgeMessage();
      }
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final phoneNumber = toE164(_phoneController.text);
    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      final dispatch = await _phoneAuth.sendOtp(phoneNumber: phoneNumber);
      if (!mounted) {
        return;
      }

      await Navigator.of(
        context,
      ).push(AppRouter.otp(phoneNumber: phoneNumber, dispatch: dispatch));
    } on PhoneAuthException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Partner login',
      subtitle: 'Take bookings for cleaning, cooking, and home help.',
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Mobile number',
                style: TextStyle(
                  color: AppTheme.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'We will text you a 6-digit code to confirm it. New to '
                'Washbin? This registers you too.',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _phoneController,
                enabled: !_isSending,
                autofocus: true,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.telephoneNumberNational],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(washbinLocalNumberLength),
                ],
                onFieldSubmitted: (_) => _isSending ? null : _sendOtp(),
                validator: _validatePhone,
                decoration: const InputDecoration(
                  labelText: 'Mobile number',
                  prefixIcon: Icon(Icons.phone_rounded),
                  prefixText: '$washbinDialCode  ',
                  prefixStyle: TextStyle(
                    color: AppTheme.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                AuthErrorText(message: _errorMessage!),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isSending ? null : _sendOtp,
                icon: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.arrow_forward_rounded),
                label: Text(_isSending ? 'Sending code...' : 'Send OTP'),
              ),
              const SizedBox(height: 18),
              const Text(
                'By continuing you agree to receive an SMS from Washbin. '
                'Standard message rates may apply.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validatePhone(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');

    if (digits.length != washbinLocalNumberLength) {
      return 'Enter your $washbinLocalNumberLength-digit mobile number';
    }
    // Indian mobile numbers start 6-9; catching it here saves an SMS attempt.
    if (!RegExp(r'^[6-9]').hasMatch(digits)) {
      return 'Enter a valid mobile number';
    }
    return null;
  }
}
