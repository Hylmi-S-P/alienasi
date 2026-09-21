import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _formatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final NumberFormat _numberOnlyFormatter = NumberFormat('#,###', 'id_ID');

  static String format(int amount, {bool includeSymbol = true}) {
    if (!includeSymbol) {
      return _numberOnlyFormatter.format(amount);
    }
    return _formatter.format(amount);
  }

  static String formatWithSign(int amount, String type) {
    final prefix = type == 'income' ? '+ ' : '- ';
    return '$prefix${format(amount)}';
  }

  /// Membersihkan tanda pemisah ribuan dan mengembalikan nilai integer murni
  static int parseAmount(String? text) {
    if (text == null || text.trim().isEmpty) return 0;
    final digitsOnly = text.replaceAll(RegExp(r'[^\d]'), '');
    return int.tryParse(digitsOnly) ?? 0;
  }
}

/// Formatter input otomatis yang menyisipkan titik sebagai pemisah ribuan (standar Indonesia)
/// secara real-time saat pengguna mengetik angka pada kolom nominal.
class ThousandSeparatorInputFormatter extends TextInputFormatter {
  static final NumberFormat _formatter = NumberFormat('#,###', 'id_ID');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Ambil hanya digit angka
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Batasi panjang angka maksimal 13 digit (hingga ratusan triliun) agar tidak overflow 64-bit int
    final safeDigits = digitsOnly.length > 13 ? digitsOnly.substring(0, 13) : digitsOnly;
    final value = int.tryParse(safeDigits);
    if (value == null) {
      return oldValue;
    }

    final newFormatted = _formatter.format(value);

    // Hitung berapa banyak digit angka yang berada sebelum posisi kursor pada newValue
    int digitsBeforeCursor = 0;
    final cursorOffset = newValue.selection.end;
    for (int i = 0; i < cursorOffset && i < newValue.text.length; i++) {
      if (RegExp(r'\d').hasMatch(newValue.text[i])) {
        digitsBeforeCursor++;
      }
    }

    // Cari posisi kursor yang setara pada teks yang sudah diformat dengan titik
    int newCursorPos = 0;
    int digitCount = 0;
    for (int i = 0; i < newFormatted.length; i++) {
      if (RegExp(r'\d').hasMatch(newFormatted[i])) {
        digitCount++;
      }
      if (digitCount == digitsBeforeCursor) {
        newCursorPos = i + 1;
        break;
      }
    }

    if (digitsBeforeCursor == 0) {
      newCursorPos = 0;
    } else if (digitCount < digitsBeforeCursor) {
      newCursorPos = newFormatted.length;
    }

    return TextEditingValue(
      text: newFormatted,
      selection: TextSelection.collapsed(offset: newCursorPos),
    );
  }
}

