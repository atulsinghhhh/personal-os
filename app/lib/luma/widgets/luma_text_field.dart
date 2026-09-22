import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Labeled 50px input: white surface, hairline border, radius 14.
class LumaTextField extends StatelessWidget {
  const LumaTextField({
    super.key,
    required this.label,
    this.value,
    this.controller,
    this.hint,
    this.obscure = false,
    this.helper,
    this.trailingLabel,
    this.keyboardType,
    this.textInputAction,
  });

  final String label;
  final String? value;
  final TextEditingController? controller;
  final String? hint;
  final bool obscure;
  final String? helper;
  final Widget? trailingLabel;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(label,
                style: lumaSans(
                    size: 13, weight: FontWeight.w500, color: LumaColors.ink2)),
            ?trailingLabel,
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: LumaColors.surface,
            border: Border.all(color: LumaColors.hairline),
            borderRadius: BorderRadius.circular(LumaRadius.button),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.centerLeft,
          child: TextFormField(
            initialValue: controller == null ? value : null,
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            style: lumaSans(size: 16),
            cursorColor: LumaColors.ink,
            decoration: InputDecoration(
              isCollapsed: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              hintText: hint,
              hintStyle: lumaSans(size: 16, color: LumaColors.ink3),
            ),
          ),
        ),
        if (helper != null) ...[
          const SizedBox(height: 6),
          Text(helper!, style: lumaSans(size: 12, color: LumaColors.ink3)),
        ],
      ],
    );
  }
}
