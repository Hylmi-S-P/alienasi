import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static String toHumanDate(DateTime date) {
    return DateFormat('d MMMM yyyy', 'id_ID').format(date);
  }

  static String toShortDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  static String toHumanDateTime(DateTime date) {
    return DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(date);
  }

  static String toMonthYear(DateTime date) {
    return DateFormat('MMMM yyyy', 'id_ID').format(date);
  }
}
