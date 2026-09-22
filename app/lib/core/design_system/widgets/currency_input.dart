import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../tokens/typography.dart';

/// Large, currency-symbol-prefixed amount entry field used by Quick Capture,
/// Add Expense, and Add Income — the "amount first" pattern from the
/// product spec. [currencyCode] is an ISO 4217 code (never hardcoded by the
/// caller to a specific currency); the symbol shown is derived from it.
class CurrencyInput extends StatelessWidget {
  const CurrencyInput({
    super.key,
    required this.currencyCode,
    required this.controller,
    this.autofocus = true,
    this.onChanged,
  });

  final String currencyCode;
  final TextEditingController controller;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  String get _symbol {
    try {
      return NumberFormat.simpleCurrency(name: currencyCode).currencySymbol;
    } on Exception {
      return currencyCode;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(_symbol, style: AppTypography.displayLarge),
        const SizedBox(width: 8),
        IntrinsicWidth(
          child: TextField(
            controller: controller,
            autofocus: autofocus,
            onChanged: onChanged,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            style: AppTypography.displayLarge,
            decoration: const InputDecoration(
              border: InputBorder.none,
              filled: false,
              hintText: '0',
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }
}
