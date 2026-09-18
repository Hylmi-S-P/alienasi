import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _formatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static String format(int amount, {bool includeSymbol = true}) {
    if (!includeSymbol) {
      final numberFormat = NumberFormat('#,###', 'id_ID');
      return numberFormat.format(amount);
    }
    return _formatter.format(amount);
  }

  static String formatWithSign(int amount, String type) {
    final prefix = type == 'income' ? '+ ' : '- ';
    return '$prefix${format(amount)}';
  }
}
