import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';

/// Modern PIN input widget with 6 digits and auto-advance.
class PinInput extends StatelessWidget {
  final void Function(String) onCompleted;
  final void Function(String)? onChanged;
  final FocusNode? focusNode;
  final TextEditingController? controller;

  const PinInput({
    super.key,
    required this.onCompleted,
    this.onChanged,
    this.focusNode,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 64,
      textStyle: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1E293B),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(
        color: const Color(0xFF2563EB),
        width: 2,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2563EB),
          width: 1.5,
        ),
      ),
    );

    final errorPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(
        color: const Color(0xFFEF4444),
        width: 2,
      ),
    );

    return Pinput(
      length: 6,
      controller: controller,
      focusNode: focusNode,
      defaultPinTheme: defaultPinTheme,
      focusedPinTheme: focusedPinTheme,
      submittedPinTheme: submittedPinTheme,
      errorPinTheme: errorPinTheme,
      showCursor: true,
      cursor: Container(
        width: 2,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
      onCompleted: onCompleted,
      onChanged: onChanged,
      keyboardType: TextInputType.number,
      autofocus: true,
      separatorBuilder: (index) => const SizedBox(width: 8),
      hapticFeedbackType: HapticFeedbackType.lightImpact,
    );
  }
}
