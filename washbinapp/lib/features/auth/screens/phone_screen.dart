import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:washbinapp/app/app_services_scope.dart';
import 'package:washbinapp/app/router/app_router.dart';
import 'package:washbinapp/core/session/session_scope.dart';
import 'package:washbinapp/core/theme/app_theme.dart';
import 'package:washbinapp/features/auth/data/phone_auth_service.dart';
import 'package:washbinapp/features/auth/data/phone_number_input.dart';
import 'package:washbinapp/features/auth/widgets/auth_error_text.dart';
import 'package:washbinapp/features/auth/widgets/auth_scaffold.dart';

/// Step one of sign-in: the customer's mobile number. There is no separate
/// login and signup — the number decides which one this turns out to be.
class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isSending = false;
  bool _hasReferralCode = false;
  String? _errorMessage;

  PhoneAuthService get _phoneAuth => AppServicesScope.of(context).phoneAuth;

  @override
  void initState() {
    super.initState();
    // Surfaces why the customer is back here — an expired session, or an
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

      await Navigator.of(context)
          .push(AppRouter.otp(phoneNumber: phoneNumber, dispatch: dispatch));
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
      title: 'Clean clothes at your doorstep.',
      subtitle: 'Schedule laundry, dry cleaning, and ironing in minutes.',
      showSkip: true,
      onSkip: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Log in to book a WashBin pickup.')),
        );
      },
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Log in or Sign up',
                style: TextStyle(
                  color: AppTheme.ink,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 26),
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
                decoration: InputDecoration(
                  hintText: 'Enter mobile number',
                  hintStyle: const TextStyle(
                    color: Color(0xFF9AA3B2),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                  prefixIcon: SizedBox(
                    width: 66,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          washbinDialCode,
                          style: TextStyle(
                            color: AppTheme.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 26,
                          margin: const EdgeInsets.only(left: 12),
                          color: AppTheme.line,
                        ),
                      ],
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 66,
                    minHeight: 54,
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                AuthErrorText(message: _errorMessage!),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _isSending ? null : _sendOtp,
                child: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.ink,
                        ),
                      )
                    : const Text('Continue'),
              ),
              const SizedBox(height: 18),
              InkWell(
                onTap: _isSending
                    ? null
                    : () {
                        setState(() => _hasReferralCode = !_hasReferralCode);
                      },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _hasReferralCode,
                        onChanged: _isSending
                            ? null
                            : (value) {
                                setState(
                                  () => _hasReferralCode = value ?? false,
                                );
                              },
                        activeColor: AppTheme.royalBlue,
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Have a referral code?',
                        style: TextStyle(
                          color: Color(0xFF344054),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Text.rich(
                TextSpan(
                  text: 'By continuing, you agree to our ',
                  children: [
                    TextSpan(
                      text: 'Terms of Service',
                      style: const TextStyle(
                        color: AppTheme.royalBlue,
                        decoration: TextDecoration.underline,
                        decorationColor: AppTheme.royalBlue,
                      ),
                    ),
                    const TextSpan(text: ' & '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: const TextStyle(
                        color: AppTheme.royalBlue,
                        decoration: TextDecoration.underline,
                        decorationColor: AppTheme.royalBlue,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                  letterSpacing: 0,
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
