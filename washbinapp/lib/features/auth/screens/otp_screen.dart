import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:washbinapp/app/app_services_scope.dart';
import 'package:washbinapp/core/api/api_exception.dart';
import 'package:washbinapp/core/session/session_scope.dart';
import 'package:washbinapp/core/theme/app_theme.dart';
import 'package:washbinapp/features/auth/data/auth_api.dart';
import 'package:washbinapp/features/auth/data/phone_auth_service.dart';
import 'package:washbinapp/features/auth/data/phone_number_input.dart';
import 'package:washbinapp/features/auth/widgets/auth_error_text.dart';
import 'package:washbinapp/features/auth/widgets/auth_scaffold.dart';
import 'package:washbinapp/features/auth/widgets/otp_input.dart';

const _resendCooldown = Duration(seconds: 45);

/// Step two: the code. On Android this screen can also complete on its own,
/// because Firebase reads the arriving SMS itself.
class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.phoneNumber,
    required this.dispatch,
  });

  final String phoneNumber;
  final OtpDispatch dispatch;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _codeController = TextEditingController();

  String? _verificationId;
  int? _resendToken;
  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;
  Timer? _resendTimer;
  int _secondsUntilResend = 0;

  AuthApi get _authApi => AppServicesScope.of(context).authApi;
  PhoneAuthService get _phoneAuth => AppServicesScope.of(context).phoneAuth;

  @override
  void initState() {
    super.initState();
    _adopt(widget.dispatch);
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  /// Applies whatever Firebase reported: either a code to collect, or a
  /// credential Android already resolved, which needs no code at all.
  void _adopt(OtpDispatch dispatch) {
    switch (dispatch) {
      case OtpCodeSent(:final verificationId, :final resendToken):
        _verificationId = verificationId;
        _resendToken = resendToken;
        _startResendCountdown();
      case OtpAutoResolved(:final credential):
        _startResendCountdown();
        unawaited(_completeWithCredential(credential));
    }
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _secondsUntilResend = _resendCooldown.inSeconds);

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsUntilResend--);
      if (_secondsUntilResend <= 0) {
        timer.cancel();
      }
    });
  }

  Future<void> _submitCode(String code) async {
    final verificationId = _verificationId;

    if (verificationId == null || _isVerifying) {
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final idToken = await _phoneAuth.verifyOtp(
        verificationId: verificationId,
        smsCode: code,
      );
      await _exchangeForSession(idToken);
    } on PhoneAuthException catch (error) {
      _showError(error.message, clearCode: true);
    } on ApiException catch (error) {
      _showError(error.message);
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  /// Finishes a sign-in Android resolved without the customer typing anything.
  Future<void> _completeWithCredential(PhoneAuthCredential credential) async {
    if (_isVerifying) {
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final idToken = await _phoneAuth.signInWithCredential(credential);
      await _exchangeForSession(idToken);
    } on PhoneAuthException catch (error) {
      _showError(error.message);
    } on ApiException catch (error) {
      _showError(error.message);
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  /// Trades the verified Firebase token for a Washbin session.
  ///
  /// Both outcomes are reported to the session rather than navigated to:
  /// `AppGate` decides what replaces this screen, so a half-finished sign-in
  /// cannot be left sitting above the app.
  Future<void> _exchangeForSession(String idToken) async {
    final session = SessionScope.read(context);

    try {
      final result = await _authApi.signInWithPhone(firebaseIdToken: idToken);
      await session.completeSignIn(result);
    } on ApiException catch (error) {
      if (error.code != profileRequiredCode) {
        rethrow;
      }

      // Verified, but this number has no account. All that is missing is a
      // name, which the profile setup screen collects.
      session.requireProfile(
        firebaseIdToken: idToken,
        phoneNumber: widget.phoneNumber,
      );
    }
  }

  Future<void> _resend() async {
    if (_isResending || _secondsUntilResend > 0) {
      return;
    }

    setState(() {
      _isResending = true;
      _errorMessage = null;
      _codeController.clear();
    });

    try {
      final dispatch = await _phoneAuth.sendOtp(
        phoneNumber: widget.phoneNumber,
        resendToken: _resendToken,
        onAutoResolved: (credential) =>
            unawaited(_completeWithCredential(credential)),
        onError: (error) => _showError(error.message),
      );
      if (mounted) {
        _adopt(dispatch);
      }
    } on PhoneAuthException catch (error) {
      _showError(error.message);
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  void _showError(String message, {bool clearCode = false}) {
    if (!mounted) {
      return;
    }
    setState(() {
      _errorMessage = message;
      if (clearCode) {
        _codeController.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final canResend = _secondsUntilResend <= 0 && !_isResending;

    return AuthScaffold(
      title: 'Enter the code',
      subtitle: 'Sent by SMS to ${formatForDisplay(widget.phoneNumber)}.',
      onBack: _isVerifying ? null : () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OtpInput(
            controller: _codeController,
            enabled: !_isVerifying,
            hasError: _errorMessage != null,
            onCompleted: _submitCode,
          ),
          const SizedBox(height: 18),
          if (_isVerifying)
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.red,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'Verifying...',
                  style: TextStyle(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          if (_errorMessage != null) AuthErrorText(message: _errorMessage!),
          const SizedBox(height: 20),
          Center(
            child: canResend
                ? TextButton.icon(
                    onPressed: _resend,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Resend code'),
                  )
                : Text(
                    _isResending
                        ? 'Sending a new code...'
                        : 'Resend code in ${_secondsUntilResend}s',
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          Center(
            child: TextButton(
              onPressed: _isVerifying
                  ? null
                  : () => Navigator.of(context).pop(),
              child: const Text('Change mobile number'),
            ),
          ),
        ],
      ),
    );
  }
}
