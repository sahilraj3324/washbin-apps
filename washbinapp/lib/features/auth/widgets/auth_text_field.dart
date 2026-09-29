import 'package:flutter/material.dart';

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.icon,
    required this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.autofillHints,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Iterable<String>? autofillHints;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      autofillHints: autofillHints,
      textInputAction: textInputAction,
      validator: validator,
      enabled: enabled,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    );
  }
}
