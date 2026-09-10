import 'package:intl/intl.dart';

final _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
final _dateDisplayFormat = DateFormat('dd MMM yyyy');

String formatCurrency(String amount) {
  final value = double.tryParse(amount) ?? 0;
  return _currencyFormat.format(value);
}

String formatDate(String isoDate) {
  if (isoDate.isEmpty) return '-';
  try {
    return _dateDisplayFormat.format(DateTime.parse(isoDate));
  } catch (_) {
    return isoDate;
  }
}

/// Formats a DateTime's own calendar fields as a bare "yyyy-MM-dd" string -
/// no UTC conversion. Send this (not toIso8601String()) for a date-only field
/// like Expense.expenseDate: toIso8601String() on a local DateTime embeds the
/// device's local midnight as a UTC instant, which lands on the *previous*
/// calendar day once the backend parses it for any timezone ahead of UTC
/// (e.g. a user in WIB/UTC+7 picking 9 June ends up with 8 June stored).
String dateOnlyString(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
