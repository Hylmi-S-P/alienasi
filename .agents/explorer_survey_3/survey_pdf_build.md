# Technical Survey: PDF Reporting Service, Test Infrastructure, and Build Configuration

**Author**: Explorer Survey 3  
**Date**: 2026-09-20  
**Project**: Bendahara Kelas (`bendahara_app`)  
**Target System**: Flutter 3.47.2 / Android SDK 36 / Dart 3.13.2  

---

## 1. Executive Summary

This survey provides an exhaustive technical investigation of the **PDF Reporting Service**, **Automated Test Infrastructure**, and **Build & Versioning Configuration** in the `Bendahara Kelas` Flutter project.

Key findings:
1. **PDF Reporting Service (`lib/domain/services/pdf_report_service.dart`)**:
   - Currently generates a single-table cash transaction statement using `pw.TableHelper.fromTextArray` on A4 MultiPage with Plus Jakarta Sans fonts.
   - **Gaps against R3**: Transactions are not partitioned by calendar month; expenses are rendered in generic black/slate text with no red highlights or badges.
   - **Gaps against R4**: There is **no student dues/arrears audit section** in the PDF at all. Dues data is currently only exported in Excel (`ExcelReportService`).
   - **Integration with R5**: The student arrears calculation for the audit sheet must filter out Saturdays, Sundays, and weekdays with zero payment activity.
2. **Test Infrastructure (`test/`)**:
   - 14 test suites containing **94 automated tests**.
   - Current health: **100% passing (`00:06 +94: All tests passed!`)** with **0 issues found** on `flutter analyze`.
   - Built on in-memory SQLite (`AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()))`), Riverpod provider overrides, and Flutter WidgetTester.
3. **Build & Versioning Configuration**:
   - Current version in `pubspec.yaml`: `1.0.2+3` (`versionName = 1.0.2`, `versionCode = 3`).
   - Configured in `android/app/build.gradle.kts` to pull version dynamically from Flutter.
   - Release signing uses the `debug` keystore for frictionless in-place updates without Google Play Protect blocking.
   - Next release requires bumping `versionCode` to `4` (e.g. `version: 1.0.3+4`) and executing `flutter build apk --release` followed by copying to root `Bendahara-Kelas-Release.apk`.

---

## 2. PDF Reporting Service Investigation

### 2.1 File Location and Call Hierarchy

- **Implementation**: `lib/domain/services/pdf_report_service.dart` (390 lines)
- **Primary Method Signature**:
  ```dart
  static Future<Uint8List> generateReportPdf({
    required AcademicYear academicYear,
    required String periodRangeTitle, // e.g. "1 Bulan (1 Sep 2026 s/d 30 Sep 2026)"
    required List<TransactionWithCategory> items,
  }) async
  ```
- **Call Sites**:
  1. `lib/presentation/screens/supervision_report_screen.dart`:
     - Line 61: `_sharePdf(AcademicYear academicYear)`
     - Line 88: `_previewPdf(AcademicYear academicYear)`
  2. Automated Tests:
     - `test/category_and_report_test.dart` (Line 192)
     - `test/edge_cases_test.dart` (Line 220)
     - `test/reconciled_date_and_pdf_table_test.dart` (Line 214)

### 2.2 Layout, Page Formatting, Headers, and Styling

- **Page Format & Geometry**:
  - Format: `PdfPageFormat.a4`
  - Margins: `pw.EdgeInsets.all(32)`
  - MultiPage document: `pw.MultiPage` allowing automatic page splitting.
- **Typography**:
  - Google Fonts Plus Jakarta Sans downloaded/cached via `printing` package:
    - Regular: `PdfGoogleFonts.plusJakartaSansRegular()`
    - Bold: `PdfGoogleFonts.plusJakartaSansBold()`
    - SemiBold: `PdfGoogleFonts.plusJakartaSansSemiBold()`
- **Palette & Color Tokens**:
  - Primary Theme Color: `#1B4332` (Dark Emerald)
  - Secondary Emerald / Accents: `#2D6A4F`
  - Income Green: `#16A34A`
  - Expense Red: `#DC2626`
  - Text Slate Dark: `#0F172A`
  - Text Slate Body: `#1E293B`
  - Text Slate Muted: `#475569` and `#64748B`
  - Border Grey: `#E2E8F0` and `#CBD5E1`
  - Surface Background: `#F8F9FA`
  - Table Alternating Zebra Row: `#F8FAFC`
- **Header Structure** (rendered on every page):
  - Left:
    - Document Title: `LAPORAN PERTANGGUNGJAWABAN KAS KELAS` (Bold, 14pt, `#1B4332`)
    - Class & School Year: `${academicYear.name} (Tahun Ajaran ${academicYear.startDate.year}/${academicYear.endDate.year})` (SemiBold, 11pt, `#0F172A`)
    - Report Period: `Periode Laporan: $periodRangeTitle` (Regular, 10pt, `#475569`)
  - Right:
    - Print Timestamp: `Cetak: ${DateFormatter.toHumanDateTime(DateTime.now())}` (Regular, 8pt, `#94A3B8`)
  - Bottom Rule: `pw.Divider(thickness: 1.5, color: PdfColor.fromHex('#1B4332'))`
- **Footer Structure** (rendered on every page):
  - Right aligned: `Halaman ${context.pageNumber} dari ${context.pagesCount}` (Regular, 9pt, `#94A3B8`)

### 2.3 Current Content Sections

1. **Executive Summary Box** (`_buildSummaryBox`):
   - Background `#F8F9FA`, border `#E2E8F0`, corner radius 8.
   - 3-column row with vertical dividers:
     - `TOTAL KAS MASUK`: Green `#16A34A`
     - `TOTAL KAS KELUAR`: Red `#DC2626`
     - `SISA SALDO KAS`: Dark Slate `#0F172A`
2. **Transaction Table Header & Container**:
   - Title: `Rincian Transaksi Kas Kelas` (SemiBold, 11pt, `#0F172A`)
   - Empty State: When `items.isEmpty`, shows centered text: `Tidak ada catatan transaksi pada rentang waktu ini.`
   - Non-Empty: Rendered with `pw.TableHelper.fromTextArray`.
3. **Table Column Configuration**:
   - `0: pw.FixedColumnWidth(26)` -> `No` (Center)
   - `1: pw.FixedColumnWidth(64)` -> `Tanggal` (Center)
   - `2: pw.FixedColumnWidth(85)` -> `Kategori` (Left)
   - `3: pw.FlexColumnWidth(2.6)` -> `Keterangan Transaksi` (Left)
   - `4: pw.FixedColumnWidth(74)` -> `Kas Masuk` (Right)
   - `5: pw.FixedColumnWidth(74)` -> `Kas Keluar` (Right)
   - `6: pw.FixedColumnWidth(78)` -> `Saldo` (Right)
4. **Current Sorting Logic**:
   - Chronological ascending (oldest to newest):
     ```dart
     final sorted = List<TransactionWithCategory>.from(items)
       ..sort((a, b) {
         final cmp = a.transaction.transactionDate.compareTo(b.transaction.transactionDate);
         if (cmp != 0) return cmp;
         return a.transaction.createdAt.compareTo(b.transaction.createdAt);
       });
     ```
   - Running balance starts from row 0 and increments with income, decrements with expense.
5. **Physical Receipt Attachments Section**:
   - Collects transactions where `receiptImagePath` exists on disk.
   - Renders a 2-column wrap of image previews with title, date, and `+` or `-` formatted amount.

### 2.4 Expense Formatting Analysis (Current vs. Required)

- **Current State**:
  In `_buildTableRows`:
  ```dart
  rows.add([
    '${i + 1}',
    DateFormatter.toShortDate(item.transaction.transactionDate),
    item.category.name,
    titleText,
    isIncome ? CurrencyFormatter.format(item.transaction.amount) : '-',
    !isIncome ? CurrencyFormatter.format(item.transaction.amount) : '-',
    CurrencyFormatter.format(runningBalance),
  ]);
  ```
  Because `cellStyle` applies to all cells uniformly (`color: PdfColor.fromHex('#1E293B')`), **expense numbers are rendered in the exact same dark gray font as regular text**.
- **Requirement R3**:
  *"Setiap baris mutasi pengeluaran kas wajib diberi sorotan visual warna merah (red highlight pada teks nominal atau badge jenis transaksi) agar langsung terlihat oleh wali kelas dan wali murid."*
- **Solution via `TableHelper.fromTextArray`**:
  `fromTextArray` supports `cellBuilder`, `textStyleBuilder`, `cellDecoration`, or returning `pw.Widget` inside the row list:
  1. `textStyleBuilder: (colIndex, cell, rowNum)`:
     If `colIndex == 5` and `cell != '-'`, return `pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColor.fromHex('#DC2626'))`.
  2. Or `cellDecoration: (colIndex, cell, rowNum)`:
     If `colIndex == 5` and `cell != '-'`, add a soft red pill background `color: PdfColor.fromHex('#FEE2E2')` or badge.
  3. Or direct `pw.Widget` in `data`:
     `!isIncome ? pw.Container(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: pw.BoxDecoration(color: PdfColor.fromHex('#FEF2F2'), borderRadius: pw.BorderRadius.circular(3)), child: pw.Text(CurrencyFormatter.format(item.transaction.amount), style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColor.fromHex('#DC2626')))) : pw.Text('-')`.

### 2.5 Date and Period Formatting Analysis

- **Header Period**:
  Received from `_getRangeTitle(range, academicYear)`:
  - `oneMonth`: `'Bulan September 2026 (Minggu ke-3)'`
  - `threeMonths`: `'3 Bulan (Triwulan)'`
  - `oneYear`: `'1 Tahun Penuh'`
  - `allTime`: `'Semua Tahun (Seluruh Arsip)'`
- **Table Dates**:
  Formatted via `DateFormatter.toShortDate(date)` $\rightarrow$ `dd/MM/yyyy` (e.g. `14/09/2026`).
- **Receipt Dates**:
  `DateFormatter.toShortDate(txItem.transaction.transactionDate)`.
- **Monthly Partitioning Gap (R3)**:
  Currently, all rows are placed in a single table without any month grouping.
  When the report covers multi-month ranges (e.g. `threeMonths`, `oneYear`, `allTime`), users have no clear separators.
  **Recommended Design**:
  Group `sorted` transactions by calendar month `DateTime(date.year, date.month)`:
  For each distinct month:
  - Section Header Bar:
    `pw.Container(margin: const pw.EdgeInsets.only(top: 10, bottom: 4), padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: pw.BoxDecoration(color: PdfColor.fromHex('#2D6A4F'), borderRadius: pw.BorderRadius.circular(4)), child: pw.Text('BULAN ${monthName.toUpperCase()} ${year}', style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.white)))`
  - Table of transactions for that month.
  - Running balance persists continuously across month boundaries.
  - Final table appends the cumulative `TOTAL` summary row.

### 2.6 Student Dues / Arrears Audit Section (Requirement R4 & R5)

- **Current State**:
  Completely absent from `PdfReportService`.
- **Where It Should Be Placed**:
  Immediately following the transaction table(s) and preceding the receipt photo attachments.
- **Data Model Needed**:
  ```dart
  class StudentArrearsReportItem {
    final int attendanceNumber;
    final String studentName;
    final String unpaidPeriodRange; // e.g. "14 Juli s.d. 18 Juli 2026" or "Minggu 2 Juli s.d. Minggu 4 Juli 2026"
    final String duesRateText;      // e.g. "Rp2.000 / hari" or "Rp5.000 / minggu"
    final int totalArrears;         // e.g. 10000
    final int unpaidPeriodsCount;   // e.g. 5

    const StudentArrearsReportItem({
      required this.attendanceNumber,
      required this.studentName,
      required this.unpaidPeriodRange,
      required this.duesRateText,
      required this.totalArrears,
      required this.unpaidPeriodsCount,
    });
  }
  ```
- **Service Parameter Expansion**:
  Update `PdfReportService.generateReportPdf` with an optional parameter:
  ```dart
  static Future<Uint8List> generateReportPdf({
    required AcademicYear academicYear,
    required String periodRangeTitle,
    required List<TransactionWithCategory> items,
    List<StudentArrearsReportItem>? studentArrears,
  }) async
  ```
  *(Defaulting to null/empty preserves 100% backward compatibility for all existing tests!)*
- **Calculation Logic Incorporating R5**:
  In `supervision_report_screen.dart` (or a dedicated domain helper):
  1. Fetch `students` (active only) and `duesPeriods` for `academicYear.id`.
  2. Fetch `duesPayments`.
  3. Filter effective dues periods based on **R5**:
     - If `duesPeriodType == 'daily'`:
       - **Weekend rule**: Exclude periods where `dueDate.weekday == DateTime.saturday` or `DateTime.sunday`.
       - **Activity holiday rule**: For weekdays, count how many students paid in that period:
         `final paidCount = payments.where((p) => p.duesPeriodId == period.id && p.isPaid).length;`
         If `paidCount == 0`, treat as school holiday / bebas kas (exclude from arrears evaluation!).
         If `paidCount > 0`, it is an effective dues day.
     - If `weekly` or `monthly`:
       - Count periods where `targetAmount > 0`.
  4. For each student:
     - Find effective periods where `payment == null || !payment.isPaid`.
     - If student has 0 unpaid periods, exclude from list.
     - If student has $> 0$ unpaid periods, create `StudentArrearsReportItem`:
       - Format date range: if 1 period: `periodLabel` or date; if contiguous: `"Dari ${firstDate} s.d. ${lastDate}"`.
       - Format rate: `CurrencyFormatter.format(academicYear.defaultDuesAmount) + ' / ' + periodTypeUnit`.
       - Total: `unpaidPeriods.length * academicYear.defaultDuesAmount`.
  5. In PDF rendering:
     - Section Title: `REKAPITULASI TUNGGAKAN KAS SISWA (AUDIT KAS)`
     - If list is empty: Show green box with text: `Seluruh siswa telah melunasi kewajiban kas kelas. (Nihil Tunggakan)`.
     - If list is not empty: Show audit table with columns:
       `['No', 'Nama Siswa', 'Rincian Periode Tunggakan', 'Tarif Kas', 'Total Tunggakan']`
     - Summary Row: `['TOTAL AKUMULASI TUNGGAKAN', '', '', '', CurrencyFormatter.format(totalArrears)]`.

---

## 3. Automated Test Infrastructure Investigation

### 3.1 Test Suite Inventory (`test/`)

The test suite consists of 14 files, thoroughly covering data integrity, UI behavior, and business logic:

| Test File | Focus & Scenarios Covered | Category |
|---|---|---|
| `backup_restore_dialog_test.dart` | Rendering of modal dialog, card previews, buttons | Widget Test |
| `backup_restore_test.dart` | Full roundtrip JSON backup/restore across 2 distinct databases, relational table verification | Integration / Unit |
| `category_and_report_test.dart` | Default categories, minimum 1 category rule, transaction flows, report ranges, PDF magic bytes (`%PDF-`) | Integration / Service |
| `dues_concurrency_and_deduplication_test.dart` | Concurrent period creation race conditions, unique constraint enforcement, legacy database deduplication migration, selection isolation | Concurrency / DB |
| `dues_lock_and_new_student_test.dart` | One-way lock for paid students, multi-period navigation, delta reconciliation, self-healing new students | Integration / Logic |
| `edge_cases_test.dart` | Deficit warning dialog, zero/negative inputs, empty PDF generation, zero-data chart handling | Edge Cases |
| `edit_delete_student_and_swipe_test.dart` | Attendance number edit, duplicate number validation, soft delete vs hard delete, PageView swipe navigation | Widget / Unit |
| `excel_export_test.dart` | Binary `.xlsx` generation, 2 sheets (Buku Kas Umum, Rekap Kas Siswa), color styling, running balance | Domain Service |
| `reconciled_date_and_pdf_table_test.dart` | Label date parsing, title regex parsing, transactionDate stamping with period date, chronological PDF table order | DB / PDF Service |
| `revisions_v2_test.dart` | Education guide card, calendar auto-update & quick recovery, safe period titles, error retry boundary | Widget / UI |
| `select_all_students_dues_test.dart` | "Centang Semua (N)" button, dynamic toggle to "Batal Pilih", persistent bottom bar updates, auto-hide when all paid | Widget Test |
| `thousand_separator_test.dart` | Live thousand dots formatting (`10.000`), cursor position preservation, quick chips | Utility / Widget |
| `unit_test.dart` | CurrencyFormatter (Rupiah), DateFormatter (Indonesian dates), running balance calculation, database durability | Unit Test |
| `widget_test.dart` | App smoke test, navigation tabs, dialog dismiss, BackButton delegates, error recovery | Smoke / Widget |

### 3.2 Test Architecture & Patterns

1. **In-Memory Database Isolation**:
   Every database test spins up a fresh, isolated SQLite database using:
   ```dart
   final db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
   addTearDown(() async => await db.close());
   ```
   No state leaks between test cases.
2. **Localization Initialization**:
   Standardized `setUpAll`:
   ```dart
   setUpAll(() async {
     TestWidgetsFlutterBinding.ensureInitialized();
     await initializeDateFormatting('id_ID', null);
   });
   ```
3. **Riverpod Provider Overrides**:
   UI tests inject mocks or in-memory databases cleanly via `ProviderScope(overrides: [...])`.
4. **Current Verification Status**:
   - `flutter test`: **94 tests passed, 0 failed** in ~6 seconds.
   - `flutter analyze`: **0 errors, 0 warnings, 0 lints** in 2.5 seconds.

---

## 4. Build, Versioning & Release Configuration Investigation

### 4.1 `pubspec.yaml` Configuration

- **Package Name**: `bendahara_app`
- **Version**: `1.0.2+3`
  - `versionName`: `1.0.2`
  - `versionCode`: `3`
- **SDK Constraints**: `sdk: ^3.13.2`
- **Key Dependencies**:
  - `pdf: ^3.13.0`
  - `printing: ^5.15.0`
  - `flutter_riverpod: ^3.4.3`
  - `drift: ^2.35.0`
  - `sqlite3_flutter_libs: ^0.6.0+eol`
  - `excel_plus: ^2.22.0`
  - `share_plus: ^13.3.0`

### 4.2 `android/app/build.gradle.kts` Configuration

- **Build Tool**: Gradle Kotlin DSL (`build.gradle.kts`)
- **Android Configuration**:
  ```kotlin
  android {
      namespace = "com.bendahara.app.bendahara_app"
      compileSdk = flutter.compileSdkVersion
      ndkVersion = flutter.ndkVersion

      compileOptions {
          sourceCompatibility = JavaVersion.VERSION_17
          targetCompatibility = JavaVersion.VERSION_17
      }

      defaultConfig {
          applicationId = "com.bendahara.app.bendahara_app"
          minSdk = flutter.minSdkVersion
          targetSdk = flutter.targetSdkVersion
          versionCode = flutter.versionCode
          versionName = flutter.versionName
      }

      buildTypes {
          release {
              signingConfig = signingConfigs.getByName("debug")
          }
      }
  }
  ```
- **Version Mapping**:
  `versionCode` and `versionName` are mapped directly from Flutter (`flutter.versionCode`, `flutter.versionName`).
- **Signing Strategy**:
  Configured to use the debug keystore (`signingConfigs.getByName("debug")`).
  This ensures:
  - Universal APK installation on any Android phone without needing an external production keystore file.
  - Safe in-place update (`versionCode: 4 > 3`) preserving user database without requiring uninstall.
  - Zero Google Play Protect blocking.

### 4.3 Release APK Compilation & Placement Workflow

1. **Version Code Increment**:
   In `pubspec.yaml`, increment:
   ```yaml
   version: 1.0.3+4
   ```
   (or pass `--build-name=1.0.3 --build-number=4` to the Flutter build command).
2. **Compilation Command**:
   ```powershell
   flutter build apk --release
   ```
3. **Artifact Destination**:
   Flutter outputs the compiled APK to:
   `build\app\outputs\flutter-apk\app-release.apk`
4. **Copy to Root Artifact**:
   ```powershell
   Copy-Item -Path "build\app\outputs\flutter-apk\app-release.apk" -Destination "Bendahara-Kelas-Release.apk" -Force
   ```
5. **Existing Binary Verification**:
   - File: `D:\project\bendehara v2\Bendahara-Kelas-Release.apk`
   - Size: 70,581,194 bytes (~67.3 MB)
   - Last modified: 2026-09-20 13:27:45 UTC+7

---

## 5. Architectural Recommendations for Implementation

1. **Extend `PdfReportService` Cleanly**:
   - Introduce `StudentArrearsReportItem` model in `pdf_report_service.dart`.
   - Update `generateReportPdf` with optional `List<StudentArrearsReportItem>? studentArrears`.
   - Partition transactions by month:
     If items span $>1$ month, render monthly banner headers (`BULAN JULI 2026`, `BULAN AGUSTUS 2026`) with sub-tables, preserving cumulative running balance across tables.
   - For expense rows, apply red styling (`#DC2626`) on the Kas Keluar column and/or soft red background `#FEF2F2`.
   - Render the Audit Rekapitulasi Tunggakan section after the transaction table and before the receipt images.
2. **Update `SupervisionReportScreen`**:
   - In `_sharePdf` and `_previewPdf`, query active students, dues periods, and dues payments.
   - Filter periods according to **R5**:
     - Daily mode: Exclude Saturday/Sunday.
     - Weekdays: Exclude if 0 students paid (activity holiday rule).
   - Construct `studentArrears` and pass to `PdfReportService.generateReportPdf`.
3. **Expand Test Suite**:
   - Add unit tests for `PdfReportService` with multi-month partitioning and red expense formatting.
   - Add unit tests for student arrears calculation adhering to R5 weekend & holiday rules.
   - Ensure all 94 existing tests + new tests pass with 0 analyze warnings.
4. **Release Compilation**:
   - Bump version in `pubspec.yaml` to `1.0.3+4`.
   - Execute `flutter build apk --release` and copy artifact to `Bendahara-Kelas-Release.apk`.
