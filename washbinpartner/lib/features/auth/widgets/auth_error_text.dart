import 'package:flutter/material.dart';
import 'package:washbinpartner/core/theme/app_theme.dart';

class AuthErrorText extends StatelessWidget {
  const AuthErrorText({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE8E8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: AppTheme.darkRed,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
      ),
    );
  }
}
