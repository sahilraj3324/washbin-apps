import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    this.inputFormatters,
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

  /// For fields with a shape the keyboard alone does not enforce, such as a
  /// digits-only pincode of a fixed length.
  final List<TextInputFormatter>? inputFormatters;

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
      inputFormatters: inputFormatters,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    );
  }
}
