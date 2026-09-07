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
