import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Formats a plain-number TextField with '.' thousands separators as the
/// user types (id_ID style, e.g. 1.250.000) - used for IDR amount fields.
/// Pair with [unformatNumber] to recover the raw numeric value on submit.
class ThousandsInputFormatter extends TextInputFormatter {
  static final _formatter = NumberFormat.decimalPattern('id_ID');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    final formatted = _formatter.format(int.parse(digits));
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}

num? unformatNumber(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.isEmpty ? null : num.tryParse(digits);
}

/// Formats a raw numeric string (e.g. an amount pulled from the API) with
/// '.' thousands separators, for pre-filling a [ThousandsInputFormatter] field.
String formatThousands(String rawNumber) {
  final n = num.tryParse(rawNumber.split('.').first);
  return n == null ? rawNumber : NumberFormat.decimalPattern('id_ID').format(n);
}
