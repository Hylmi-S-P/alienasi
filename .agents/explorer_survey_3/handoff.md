# Handoff Report: PDF Reporting Service, Test Infrastructure, and Build Configuration

**Author**: Explorer Survey 3  
**Date**: 2026-09-20  
**Status**: Task Complete (Hard Handoff)  
**Deliverable Document**: `D:\project\bendehara v2\.agents\explorer_survey_3\survey_pdf_build.md`  

---

## 1. Observation

### A. PDF Reporting Service (`lib/domain/services/pdf_report_service.dart`)
1. **Entry Point & Signature**:
   ```dart
   // lib/domain/services/pdf_report_service.dart:14-18
   static Future<Uint8List> generateReportPdf({
     required AcademicYear academicYear,
     required String periodRangeTitle,
     required List<TransactionWithCategory> items,
   }) async
   ```
2. **Current Table Formatting**:
   - Table is rendered using `pw.TableHelper.fromTextArray` (line 178) on A4 MultiPage with Plus Jakarta Sans fonts.
   - Headers: `['No', 'Tanggal', 'Kategori', 'Keterangan Transaksi', 'Kas Masuk', 'Kas Keluar', 'Saldo']` (lines 179-187).
   - Expenses are formatted as plain strings:
     `!isIncome ? CurrencyFormatter.format(item.transaction.amount) : '-'` (line 370).
   - Uniform cell style: `cellStyle: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#1E293B'))` (line 216). There is **no red text or visual red highlight** for expenses in the table.
   - Transactions are sorted by `transactionDate` and `createdAt` into a single flat table. There is **no monthly grouping or calendar month partition headers**.
3. **Current Arrears Support in PDF**:
   - `PdfReportService` contains **zero code or sections for student dues or arrears** (R4 gap).
   - In contrast, `ExcelReportService.generateExcel` (in `lib/domain/services/excel_report_service.dart:27`) accepts `List<StudentDuesReportSummary>? studentSummaries` and exports a dedicated *Sheet 2: Rekap Kas Siswa*.

### B. Test Infrastructure (`test/`)
1. **Inventory**: 14 test files exist in `test/`:
   - `backup_restore_dialog_test.dart`, `backup_restore_test.dart`, `category_and_report_test.dart`, `dues_concurrency_and_deduplication_test.dart`, `dues_lock_and_new_student_test.dart`, `edge_cases_test.dart`, `edit_delete_student_and_swipe_test.dart`, `excel_export_test.dart`, `reconciled_date_and_pdf_table_test.dart`, `revisions_v2_test.dart`, `select_all_students_dues_test.dart`, `thousand_separator_test.dart`, `unit_test.dart`, `widget_test.dart`.
2. **Execution Results**:
   - Command: `flutter test`
   - Result: Exited with code 0.
   - Verbatim Output: `00:06 +94: All tests passed!`
   - Command: `flutter analyze`
   - Result: Exited with code 0.
   - Verbatim Output: `No issues found! (ran in 2.5s)`

### C. Build & Versioning Configuration
1. **`pubspec.yaml`**:
   - Line 19: `version: 1.0.2+3`
   - SDK: `sdk: ^3.13.2`
2. **`android/app/build.gradle.kts`**:
   - Line 28: `versionCode = flutter.versionCode`
   - Line 29: `versionName = flutter.versionName`
   - Lines 33-37:
     ```kotlin
     buildTypes {
         release {
             signingConfig = signingConfigs.getByName("debug")
         }
     }
     ```
3. **Root Release Binary**:
   - File: `D:\project\bendehara v2\Bendahara-Kelas-Release.apk`
   - Size: 70,581,194 bytes (~67.3 MB)
   - Release command recorded in `docs/CONTEXT_DUMP.md:400-403`:
     ```powershell
     flutter build apk --release
     Copy-Item -Path "build\app\outputs\flutter-apk\app-release.apk" -Destination "Bendahara-Kelas-Release.apk" -Force
     ```

---

## 2. Logic Chain

1. **R3 (Monthly Partitioning & Red Highlights)**:
   - *From Observation A.2*: Transactions are currently emitted into a single `TableHelper.fromTextArray` with uniform gray text (`#1E293B`).
   - *Deduction*: When transactions span multiple months (e.g. 3-month or 1-year reports), the table lacks visual separation. Dividing the list by `DateTime(txDate.year, txDate.month)` into monthly sub-tables or inserting month banner headers (`BULAN JULI 2026`) fulfills R3.
   - *Deduction*: `TableHelper.fromTextArray` supports `textStyleBuilder`, `cellDecoration`, and passing `pw.Widget` inside row arrays. Setting `colIndex == 5` to `#DC2626` bold text with a `#FEF2F2` background tint provides the required red highlight for expenses without breaking table layout.
2. **R4 & R5 (Student Arrears Audit Section & Holiday Logic)**:
   - *From Observation A.3*: PDF generator currently ignores student dues.
   - *Deduction*: `PdfReportService.generateReportPdf` should be extended with an optional parameter `List<StudentArrearsReportItem>? studentArrears = const []`.
   - *From R5 specification*: For daily dues, weekends (Saturdays/Sundays) must be filtered out. Weekday periods with 0 collections must be treated as activity holidays and excluded from unpaid counts.
   - *Deduction*: Adding this section immediately after the transactions table and before receipt images creates a coherent audit report. If no arrears exist, a clean verified badge (`Nihil Tunggakan`) should be displayed.
3. **Test Safety & Backward Compatibility**:
   - *From Observation B.2*: 3 existing tests (`category_and_report_test.dart`, `edge_cases_test.dart`, `reconciled_date_and_pdf_table_test.dart`) call `PdfReportService.generateReportPdf`.
   - *Deduction*: By making `studentArrears` an optional parameter with default `null` / `const []`, all 94 existing tests will continue passing with zero modification required.
4. **Build & Release Protocol**:
   - *From Observation C.1 & C.2*: Android pulls `versionCode` from `pubspec.yaml`.
   - *Deduction*: The next release must bump `pubspec.yaml` to `1.0.3+4` (or `versionCode: 4`) so that Android's package installer triggers an in-place update dialog rather than requiring an uninstall.
   - *Deduction*: Compiling via `flutter build apk --release` and copying the result to `Bendahara-Kelas-Release.apk` ensures the project root artifact stays up to date.

---

## 3. Caveats

1. **Receipt Image Memory in Large Reports**: If a user generates a multi-year report with hundreds of photo receipts, loading raw image bytes could increase memory. The existing `maxWidth: 1280` image picker constraint and `receiptItems` filtering mitigate this, but implementers should keep page limits in mind.
2. **Date Range of Dues Arrears vs Transaction Date Range**: When generating a report for "1 Bulan Terakhir", the student arrears audit section typically reflects the full accumulated arrears up to the current period (or within the selected range). The prompt specifically asks for the accumulated student arrears audit sheet, which is best presented as current outstanding arrears up to the report date.

---

## 4. Conclusion

1. `PdfReportService` requires surgical enhancements:
   - Introduce monthly grouping partitions with sub-headers.
   - Apply red highlighting to expense cells/text.
   - Add a dedicated `Rekapitulasi Tunggakan Kas Siswa (Audit Kas)` table accepting `List<StudentArrearsReportItem>`.
2. Dues arrears calculation must integrate R5 rules:
   - Exclude Saturdays and Sundays unconditionally for daily dues.
   - Exclude weekday periods where 0 students paid.
3. The test suite is in exceptional health (94/94 passing, 0 lints) and ready for incremental test expansion.
4. The build pipeline is straightforward: bump `pubspec.yaml` to `version: 1.0.3+4`, run `flutter build apk --release`, and copy to `Bendahara-Kelas-Release.apk`.

---

## 5. Verification Method

To independently verify these findings:

1. **Verify Test Suite & Static Analysis**:
   ```powershell
   flutter test
   flutter analyze
   ```
   *Expected*: `All tests passed!` (94 tests) and `No issues found!`.
2. **Inspect Current PDF Service**:
   ```powershell
   # Inspect generateReportPdf signature and table builder
   Get-Content "lib\domain\services\pdf_report_service.dart" | Select -First 40
   ```
3. **Verify Build Configuration & Version**:
   ```powershell
   Select-String -Path "pubspec.yaml" -Pattern "version:"
   Select-String -Path "android\app\build.gradle.kts" -Pattern "versionCode"
   ```
4. **Verify Existing Release APK**:
   ```powershell
   Get-Item "Bendahara-Kelas-Release.apk" | Select-Object Name, Length, LastWriteTime
   ```
