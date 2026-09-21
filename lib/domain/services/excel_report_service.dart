import 'dart:typed_data';
import 'package:excel_plus/excel_plus.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/transaction_repository.dart';

class StudentDuesReportSummary {
  final int attendanceNumber;
  final String name;
  final int totalPaid;
  final bool isAllPaid;

  const StudentDuesReportSummary({
    required this.attendanceNumber,
    required this.name,
    required this.totalPaid,
    required this.isAllPaid,
  });
}

class ExcelReportService {
  ExcelReportService._();

  static Uint8List generateExcel({
    required AcademicYear academicYear,
    required List<TransactionWithCategory> items,
    List<StudentDuesReportSummary>? studentSummaries,
  }) {
    final excel = Excel.createExcel();

    // Pastikan lembar default diganti namanya menjadi 'Buku Kas Umum'
    final initialSheet = excel.sheets.keys.isNotEmpty ? excel.sheets.keys.first : 'Sheet1';
    excel.rename(initialSheet, 'Buku Kas Umum');
    final kasSheet = excel['Buku Kas Umum'];

    // Palet Warna Excel
    final emeraldDark = ExcelColor.fromHexString('FF1B4332');
    final emeraldHeader = ExcelColor.fromHexString('FF2D6A4F');
    final whiteColor = ExcelColor.fromHexString('FFFFFFFF');
    final slateDark = ExcelColor.fromHexString('FF0F172A');
    final slateMuted = ExcelColor.fromHexString('FF475569');
    final greenIncome = ExcelColor.fromHexString('FF166534');
    final redExpense = ExcelColor.fromHexString('FF991B1B');
    final borderGrey = ExcelColor.fromHexString('FFE2E8F0');
    final zebraBg = ExcelColor.fromHexString('FFF8FAFC');
    final summaryBg = ExcelColor.fromHexString('FFE2E8F0');

    final thinBorder = Border(borderStyle: BorderStyle.Thin, borderColorHex: borderGrey);
    final headerBorder = Border(borderStyle: BorderStyle.Thin, borderColorHex: emeraldDark);

    // ==========================================
    // 1. LEMBAR KERJA 1: BUKU KAS UMUM
    // ==========================================

    // A. Banner Judul Laporan (Row 0)
    final titleCell = kasSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    titleCell.value = TextCellValue('LAPORAN PERTANGGUNGJAWABAN KAS KELAS');
    titleCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 14,
      fontColorHex: whiteColor,
      backgroundColorHex: emeraldDark,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    // Merge A1:H1 untuk Banner Judul
    kasSheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 0),
      customValue: TextCellValue('LAPORAN PERTANGGUNGJAWABAN KAS KELAS'),
    );
    kasSheet.setRowHeight(0, 32.0);

    // B. Blok Informasi Kelas & Administrasi (Row 2 - 6)
    final metaInfo = [
      ['Kelas', academicYear.name],
      ['Tahun Ajaran', '${academicYear.startDate.year}/${academicYear.endDate.year}'],
      ['Bendahara', academicYear.treasurerName],
      ['Pengawas / Wali Kelas', academicYear.supervisorName],
      ['Tanggal Cetak', DateFormatter.toHumanDateTime(DateTime.now())],
    ];

    for (var r = 0; r < metaInfo.length; r++) {
      final rowIndex = r + 2;
      final labelCell = kasSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
      labelCell.value = TextCellValue(metaInfo[r][0]);
      labelCell.cellStyle = CellStyle(
        bold: true,
        fontColorHex: slateMuted,
        fontSize: 10,
      );

      final valCell = kasSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex));
      valCell.value = TextCellValue(metaInfo[r][1]);
      valCell.cellStyle = CellStyle(
        bold: true,
        fontColorHex: slateDark,
        fontSize: 10,
      );
    }

    // C. Header Kolom Tabel (Row 8)
    const headerRow = 8;
    kasSheet.setRowHeight(headerRow, 26.0);

    final headers = [
      'No',
      'Tanggal',
      'Kategori',
      'Keterangan Transaksi',
      'Kas Masuk (Rp)',
      'Kas Keluar (Rp)',
      'Saldo Berjalan (Rp)',
      'Bukti Nota',
    ];

    for (var c = 0; c < headers.length; c++) {
      final cell = kasSheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: headerRow));
      cell.value = TextCellValue(headers[c]);
      cell.cellStyle = CellStyle(
        bold: true,
        fontSize: 10,
        fontColorHex: whiteColor,
        backgroundColorHex: emeraldHeader,
        horizontalAlign: (c == 0 || c == 1 || c == 7)
            ? HorizontalAlign.Center
            : (c >= 4 && c <= 6)
                ? HorizontalAlign.Right
                : HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
        leftBorder: headerBorder,
        rightBorder: headerBorder,
        topBorder: headerBorder,
        bottomBorder: headerBorder,
      );
    }

    // D. Pengurutan Kronologis Data (Oldest to Newest)
    final sorted = List<TransactionWithCategory>.from(items)
      ..sort((a, b) {
        final cmp = a.transaction.transactionDate.compareTo(b.transaction.transactionDate);
        if (cmp != 0) return cmp;
        return a.transaction.createdAt.compareTo(b.transaction.createdAt);
      });

    var runningBalance = 0;
    var totalIncome = 0;
    var totalExpense = 0;

    // E. Pengisian Baris Data Transaksi
    var currentRow = headerRow + 1;
    for (var i = 0; i < sorted.length; i++) {
      final item = sorted[i];
      final isIncome = item.transaction.type == 'income';
      final amount = item.transaction.amount;

      if (isIncome) {
        runningBalance += amount;
        totalIncome += amount;
      } else {
        runningBalance -= amount;
        totalExpense += amount;
      }

      final isOddRow = i % 2 == 1;
      final rowBg = isOddRow ? zebraBg : whiteColor;
      final hasReceipt = item.transaction.receiptImagePath != null && item.transaction.receiptImagePath!.isNotEmpty;

      // Col 0: No
      final cellNo = kasSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow));
      cellNo.value = IntCellValue(i + 1);
      cellNo.cellStyle = CellStyle(
        fontSize: 10,
        backgroundColorHex: rowBg,
        horizontalAlign: HorizontalAlign.Center,
        leftBorder: thinBorder,
        rightBorder: thinBorder,
        bottomBorder: thinBorder,
      );

      // Col 1: Tanggal
      final cellTgl = kasSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow));
      cellTgl.value = TextCellValue(DateFormatter.toShortDate(item.transaction.transactionDate));
      cellTgl.cellStyle = CellStyle(
        fontSize: 10,
        backgroundColorHex: rowBg,
        horizontalAlign: HorizontalAlign.Center,
        leftBorder: thinBorder,
        rightBorder: thinBorder,
        bottomBorder: thinBorder,
      );

      // Col 2: Kategori
      final cellKat = kasSheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow));
      cellKat.value = TextCellValue(item.category.name);
      cellKat.cellStyle = CellStyle(
        fontSize: 10,
        backgroundColorHex: rowBg,
        horizontalAlign: HorizontalAlign.Left,
        leftBorder: thinBorder,
        rightBorder: thinBorder,
        bottomBorder: thinBorder,
      );

      // Col 3: Keterangan
      final cellKet = kasSheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow));
      cellKet.value = TextCellValue(item.transaction.title);
      cellKet.cellStyle = CellStyle(
        fontSize: 10,
        backgroundColorHex: rowBg,
        horizontalAlign: HorizontalAlign.Left,
        leftBorder: thinBorder,
        rightBorder: thinBorder,
        bottomBorder: thinBorder,
      );

      // Col 4: Kas Masuk
      final cellMasuk = kasSheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow));
      cellMasuk.value = IntCellValue(isIncome ? amount : 0);
      cellMasuk.cellStyle = CellStyle(
        fontSize: 10,
        bold: isIncome,
        fontColorHex: isIncome ? greenIncome : slateMuted,
        backgroundColorHex: rowBg,
        horizontalAlign: HorizontalAlign.Right,
        leftBorder: thinBorder,
        rightBorder: thinBorder,
        bottomBorder: thinBorder,
      );

      // Col 5: Kas Keluar
      final cellKeluar = kasSheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow));
      cellKeluar.value = IntCellValue(!isIncome ? amount : 0);
      cellKeluar.cellStyle = CellStyle(
        fontSize: 10,
        bold: !isIncome,
        fontColorHex: !isIncome ? redExpense : slateMuted,
        backgroundColorHex: rowBg,
        horizontalAlign: HorizontalAlign.Right,
        leftBorder: thinBorder,
        rightBorder: thinBorder,
        bottomBorder: thinBorder,
      );

      // Col 6: Saldo Berjalan
      final cellSaldo = kasSheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: currentRow));
      cellSaldo.value = IntCellValue(runningBalance);
      cellSaldo.cellStyle = CellStyle(
        fontSize: 10,
        bold: true,
        backgroundColorHex: rowBg,
        horizontalAlign: HorizontalAlign.Right,
        leftBorder: thinBorder,
        rightBorder: thinBorder,
        bottomBorder: thinBorder,
      );

      // Col 7: Bukti Nota
      final cellNota = kasSheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: currentRow));
      cellNota.value = TextCellValue(hasReceipt ? 'Ada Nota' : '-');
      cellNota.cellStyle = CellStyle(
        fontSize: 10,
        backgroundColorHex: rowBg,
        horizontalAlign: HorizontalAlign.Center,
        leftBorder: thinBorder,
        rightBorder: thinBorder,
        bottomBorder: thinBorder,
      );

      kasSheet.setRowHeight(currentRow, 20.0);
      currentRow++;
    }

    // F. Baris Ringkasan TOTAL (Summary Row)
    kasSheet.setRowHeight(currentRow, 24.0);

    for (var c = 0; c < 4; c++) {
      final cell = kasSheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: currentRow));
      cell.value = c == 0 ? TextCellValue('TOTAL') : TextCellValue('');
      cell.cellStyle = CellStyle(
        bold: true,
        fontSize: 11,
        backgroundColorHex: summaryBg,
        horizontalAlign: HorizontalAlign.Center,
        topBorder: thinBorder,
        bottomBorder: Border(borderStyle: BorderStyle.Double, borderColorHex: emeraldDark),
        leftBorder: thinBorder,
        rightBorder: thinBorder,
      );
    }

    // Merge A:D untuk label TOTAL
    kasSheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
      CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow),
      customValue: TextCellValue('TOTAL'),
    );

    // Total Kas Masuk
    final totMasukCell = kasSheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow));
    totMasukCell.value = IntCellValue(totalIncome);
    totMasukCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: greenIncome,
      backgroundColorHex: summaryBg,
      horizontalAlign: HorizontalAlign.Right,
      topBorder: thinBorder,
      bottomBorder: Border(borderStyle: BorderStyle.Double, borderColorHex: emeraldDark),
      leftBorder: thinBorder,
      rightBorder: thinBorder,
    );

    // Total Kas Keluar
    final totKeluarCell = kasSheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow));
    totKeluarCell.value = IntCellValue(totalExpense);
    totKeluarCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: redExpense,
      backgroundColorHex: summaryBg,
      horizontalAlign: HorizontalAlign.Right,
      topBorder: thinBorder,
      bottomBorder: Border(borderStyle: BorderStyle.Double, borderColorHex: emeraldDark),
      leftBorder: thinBorder,
      rightBorder: thinBorder,
    );

    // Saldo Akhir
    final totSaldoCell = kasSheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: currentRow));
    totSaldoCell.value = IntCellValue(runningBalance);
    totSaldoCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 11,
      backgroundColorHex: summaryBg,
      horizontalAlign: HorizontalAlign.Right,
      topBorder: thinBorder,
      bottomBorder: Border(borderStyle: BorderStyle.Double, borderColorHex: emeraldDark),
      leftBorder: thinBorder,
      rightBorder: thinBorder,
    );

    // Bukti Nota cell di baris total
    final totNotaCell = kasSheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: currentRow));
    totNotaCell.value = TextCellValue('');
    totNotaCell.cellStyle = CellStyle(
      backgroundColorHex: summaryBg,
      topBorder: thinBorder,
      bottomBorder: Border(borderStyle: BorderStyle.Double, borderColorHex: emeraldDark),
      leftBorder: thinBorder,
      rightBorder: thinBorder,
    );

    // G. Atur Lebar Kolom Lembar 1 (Auto-Width Padding)
    kasSheet.setColumnWidth(0, 6.0);   // No
    kasSheet.setColumnWidth(1, 14.0);  // Tanggal
    kasSheet.setColumnWidth(2, 22.0);  // Kategori
    kasSheet.setColumnWidth(3, 38.0);  // Keterangan
    kasSheet.setColumnWidth(4, 18.0);  // Kas Masuk
    kasSheet.setColumnWidth(5, 18.0);  // Kas Keluar
    kasSheet.setColumnWidth(6, 20.0);  // Saldo
    kasSheet.setColumnWidth(7, 14.0);  // Bukti Nota

    // ==========================================
    // 2. LEMBAR KERJA 2: REKAPITULASI KAS SISWA
    // ==========================================
    if (studentSummaries != null && studentSummaries.isNotEmpty) {
      final siswaSheet = excel['Rekap Kas Siswa'];

      // Banner Judul Lembar 2
      final siswaTitleCell = siswaSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
      siswaTitleCell.value = TextCellValue('REKAPITULASI PEMBAYARAN KAS SISWA - ${academicYear.name.toUpperCase()}');
      siswaTitleCell.cellStyle = CellStyle(
        bold: true,
        fontSize: 13,
        fontColorHex: whiteColor,
        backgroundColorHex: emeraldDark,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      siswaSheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
        CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 0),
        customValue: TextCellValue('REKAPITULASI PEMBAYARAN KAS SISWA - ${academicYear.name.toUpperCase()}'),
      );
      siswaSheet.setRowHeight(0, 30.0);

      // Header Kolom Siswa (Row 2)
      const sHeaderRow = 2;
      siswaSheet.setRowHeight(sHeaderRow, 24.0);
      final sHeaders = ['No', 'No. Absen', 'Nama Siswa', 'Total Disetor (Rp)', 'Status Kas'];

      for (var c = 0; c < sHeaders.length; c++) {
        final cell = siswaSheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: sHeaderRow));
        cell.value = TextCellValue(sHeaders[c]);
        cell.cellStyle = CellStyle(
          bold: true,
          fontSize: 10,
          fontColorHex: whiteColor,
          backgroundColorHex: emeraldHeader,
          horizontalAlign: (c == 0 || c == 1 || c == 4) ? HorizontalAlign.Center : (c == 3 ? HorizontalAlign.Right : HorizontalAlign.Left),
          verticalAlign: VerticalAlign.Center,
          leftBorder: headerBorder,
          rightBorder: headerBorder,
          topBorder: headerBorder,
          bottomBorder: headerBorder,
        );
      }

      var sRow = sHeaderRow + 1;
      var sumSiswaKas = 0;

      for (var i = 0; i < studentSummaries.length; i++) {
        final s = studentSummaries[i];
        sumSiswaKas += s.totalPaid;
        final isOdd = i % 2 == 1;
        final rowBg = isOdd ? zebraBg : whiteColor;

        // Col 0: No
        final cNo = siswaSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sRow));
        cNo.value = IntCellValue(i + 1);
        cNo.cellStyle = CellStyle(fontSize: 10, backgroundColorHex: rowBg, horizontalAlign: HorizontalAlign.Center, leftBorder: thinBorder, rightBorder: thinBorder, bottomBorder: thinBorder);

        // Col 1: Absen
        final cAbsen = siswaSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: sRow));
        cAbsen.value = IntCellValue(s.attendanceNumber);
        cAbsen.cellStyle = CellStyle(fontSize: 10, bold: true, backgroundColorHex: rowBg, horizontalAlign: HorizontalAlign.Center, leftBorder: thinBorder, rightBorder: thinBorder, bottomBorder: thinBorder);

        // Col 2: Nama
        final cNama = siswaSheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: sRow));
        cNama.value = TextCellValue(s.name);
        cNama.cellStyle = CellStyle(fontSize: 10, backgroundColorHex: rowBg, horizontalAlign: HorizontalAlign.Left, leftBorder: thinBorder, rightBorder: thinBorder, bottomBorder: thinBorder);

        // Col 3: Total Disetor
        final cTotal = siswaSheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: sRow));
        cTotal.value = IntCellValue(s.totalPaid);
        cTotal.cellStyle = CellStyle(fontSize: 10, bold: true, fontColorHex: greenIncome, backgroundColorHex: rowBg, horizontalAlign: HorizontalAlign.Right, leftBorder: thinBorder, rightBorder: thinBorder, bottomBorder: thinBorder);

        // Col 4: Status Kas
        final cStatus = siswaSheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: sRow));
        cStatus.value = TextCellValue(s.isAllPaid ? 'Lunas' : 'Belum Lunas');
        cStatus.cellStyle = CellStyle(
          fontSize: 10,
          bold: true,
          fontColorHex: s.isAllPaid ? greenIncome : redExpense,
          backgroundColorHex: rowBg,
          horizontalAlign: HorizontalAlign.Center,
          leftBorder: thinBorder,
          rightBorder: thinBorder,
          bottomBorder: thinBorder,
        );

        siswaSheet.setRowHeight(sRow, 20.0);
        sRow++;
      }

      // Baris Total Kas Siswa
      siswaSheet.setRowHeight(sRow, 24.0);
      siswaSheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: sRow),
        CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: sRow),
        customValue: TextCellValue('TOTAL KAS TERKUMPUL'),
      );
      for (var c = 0; c < 3; c++) {
        final cell = siswaSheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: sRow));
        cell.cellStyle = CellStyle(
          bold: true,
          fontSize: 10,
          backgroundColorHex: summaryBg,
          horizontalAlign: HorizontalAlign.Center,
          topBorder: thinBorder,
          bottomBorder: Border(borderStyle: BorderStyle.Double, borderColorHex: emeraldDark),
          leftBorder: thinBorder,
          rightBorder: thinBorder,
        );
      }

      final sTotCell = siswaSheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: sRow));
      sTotCell.value = IntCellValue(sumSiswaKas);
      sTotCell.cellStyle = CellStyle(
        bold: true,
        fontSize: 11,
        fontColorHex: greenIncome,
        backgroundColorHex: summaryBg,
        horizontalAlign: HorizontalAlign.Right,
        topBorder: thinBorder,
        bottomBorder: Border(borderStyle: BorderStyle.Double, borderColorHex: emeraldDark),
        leftBorder: thinBorder,
        rightBorder: thinBorder,
      );

      final sBlankCell = siswaSheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: sRow));
      sBlankCell.value = TextCellValue('');
      sBlankCell.cellStyle = CellStyle(
        backgroundColorHex: summaryBg,
        topBorder: thinBorder,
        bottomBorder: Border(borderStyle: BorderStyle.Double, borderColorHex: emeraldDark),
        leftBorder: thinBorder,
        rightBorder: thinBorder,
      );

      siswaSheet.setColumnWidth(0, 6.0);   // No
      siswaSheet.setColumnWidth(1, 12.0);  // Absen
      siswaSheet.setColumnWidth(2, 32.0);  // Nama
      siswaSheet.setColumnWidth(3, 20.0);  // Total
      siswaSheet.setColumnWidth(4, 16.0);  // Status
    }

    final bytes = excel.save();
    return Uint8List.fromList(bytes ?? []);
  }
}
