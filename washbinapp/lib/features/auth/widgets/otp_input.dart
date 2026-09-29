import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:washbinapp/core/theme/app_theme.dart';

/// A six-box code field.
///
/// One real text field sits transparently over the boxes, so the platform
/// keyboard, paste, and SMS autofill all behave normally while the boxes stay
/// purely presentational.
class OtpInput extends StatefulWidget {
  const OtpInput({
    super.key,
    required this.controller,
    this.length = 6,
    this.enabled = true,
    this.hasError = false,
    this.onCompleted,
  });

  final TextEditingController controller;
  final int length;
  final bool enabled;
  final bool hasError;

  /// Fires once the last digit is entered, so the customer does not have to
  /// reach for a button after typing the code.
  final ValueChanged<String>? onCompleted;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {});

    if (widget.controller.text.length == widget.length) {
      // Drop the keyboard first so the caller's navigation isn't fighting it.
      _focusNode.unfocus();
      widget.onCompleted?.call(widget.controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.controller.text;

    return Stack(
      children: [
        Row(
          children: List.generate(widget.length, (index) {
            final isFilled = index < code.length;
            final isNext = index == code.length && _focusNode.hasFocus;

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index == widget.length - 1 ? 0 : 8,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: widget.enabled ? Colors.white : AppTheme.canvas,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: widget.hasError
                          ? AppTheme.red
                          : isNext || isFilled
                          ? AppTheme.red
                          : AppTheme.line,
                      width: isNext ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    isFilled ? code[index] : '',
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        Positioned.fill(
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            enabled: widget.enabled,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.oneTimeCode],
            enableSuggestions: false,
            showCursor: false,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(widget.length),
            ],
            // Invisible: the boxes underneath are what the customer reads.
            style: const TextStyle(color: Colors.transparent, fontSize: 24),
            decoration: const InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              filled: false,
              counterText: '',
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }
}
