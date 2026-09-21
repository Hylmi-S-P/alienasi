# Dispatch for Worker Milestone 3

## Mission
Implement Milestone 3: PDF Reporting Enhancements (Features F8, F9, F10).

## Mandatory Reference
Read `D:\project\bendehara v2\.agents\ORIGINAL_REQUEST.md` completely before starting.

## Mandatory Integrity Warning
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

## Context & Inputs
- Project Scope: `D:\project\bendehara v2\PROJECT.md`
- Survey Findings: `D:\project\bendehara v2\.agents\explorer_survey_3\survey_pdf_build.md` and `D:\project\bendehara v2\.agents\explorer_survey_3\handoff.md`
- Dues Arrears Service: `lib/domain/services/dues_arrears_service.dart`
- Working Directory: `D:\project\bendehara v2\.agents\worker_m3`

## File Ownership
You exclusively own and can modify or create:
- `lib/domain/services/pdf_report_service.dart`
- `lib/presentation/screens/supervision_report_screen.dart`
- `test/unit/pdf_report_service_test.dart` (new file)

DO NOT modify files outside this list in this milestone.

## Detailed Requirements
1. **F8 & F9: Monthly Partitioning & Red Expense Highlights in `PdfReportService` (`lib/domain/services/pdf_report_service.dart`)**:
   - In `generateReportPdf`:
     - Accept optional `List<StudentArrearsReportItem>? studentArrears = const []`.
     - Partition `items` into groups by calendar month (`DateTime(tx.transactionDate.year, tx.transactionDate.month)`).
     - For each month group, render a clear, attractive month partition sub-header (e.g. `BULAN JULI 2026`, `BULAN AGUSTUS 2026`, etc.).
     - In the transactions table, for every expense row (`isIncome == false`):
       - Visually highlight the row with red text (`#DC2626`) on the expense column and/or a subtle red background tint (`#FEF2F2`).
2. **F10: Dedicated Student Dues Arrears Audit Section in PDF**:
   - In `generateReportPdf`, if `studentArrears != null`:
     - Render a dedicated audit section / page:
       - Header: `REKAPITULASI TUNGGAKAN KAS SISWA (AUDIT KAS KELAS)`
       - Subtitle: Keterangan tarif kas aktif (e.g. `Rp2.000 / hari` atau `Rp5.000 / minggu`), tanggal audit, dan catatan kepatuhan.
       - Table Columns:
         - `No` (absent number / row number)
         - `Nama Siswa`
         - `Rentang Periode Belum Bayar` (e.g. "Dari 14 Juli s.d. 18 Juli 2026")
         - `Tarif Kas` (e.g. "Rp2.000 / hari")
         - `Total Tunggakan` (e.g. "Rp10.000")
       - Summary footer row: `Total Kas Kelas Belum Tertagih` with sum of all student arrears.
       - If `studentArrears.isEmpty`: render a verified audit badge: `Nihil Tunggakan (Semua Siswa Lunas)`.
3. **Integration in `SupervisionReportScreen` (`lib/presentation/screens/supervision_report_screen.dart`)**:
   - When generating or downloading PDF, call `DuesArrearsService.calculateArrears` with the database and active academic year to obtain the real `List<StudentArrearsReportItem>`, and pass it to `PdfReportService.generateReportPdf`.
4. **Automated Unit & Integration Tests (`test/unit/pdf_report_service_test.dart`)**:
   - Test monthly partitioning with multi-month transactions.
   - Test expense rows render with red color styling.
   - Test student arrears section generates table with names, period ranges, rates, amounts, and summary row.
   - Test zero arrears generates "Nihil Tunggakan" badge.
   - Verify backward compatibility: calls without `studentArrears` still succeed.
   - Run `flutter analyze` (0 errors, 0 warnings).
   - Run full `flutter test` (100% pass).

## Output
Write `changes.md` and `handoff.md` in `D:\project\bendehara v2\.agents\worker_m3\` and report back via message.

## 2026-09-20T13:59:11Z
You are Worker M3 implementing Milestone 3: PDF Reporting Enhancements for Bendahara Kelas.
Working directory: D:\project\bendehara v2\.agents\worker_m3

MANDATORY FIRST STEP: Read D:\project\bendehara v2\.agents\ORIGINAL_REQUEST.md completely.
Then read your detailed task assignment in D:\project\bendehara v2\.agents\worker_m3\DISPATCH.md.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Implement:
1. In lib/domain/services/pdf_report_service.dart:
   - Accept optional List<StudentArrearsReportItem>? studentArrears.
   - Monthly partition subheaders (BULAN JULI 2026, etc.) when transactions span multiple months.
   - Contrast red font/tint highlight (#DC2626 / #FEF2F2) on cash out / expense rows.
   - Dedicated Student Dues Arrears Audit section/page with student numbers, names, unpaid period ranges, active dues rate, amounts, and total uncollected dues summary row (or 'Nihil Tunggakan' badge if empty).
2. In lib/presentation/screens/supervision_report_screen.dart:
   - Compute and pass real student arrears from DuesArrearsService to generateReportPdf.
3. Authored tests in test/unit/pdf_report_service_test.dart verifying monthly partitions, red expense styling, arrears audit section, and zero arrears badge.
4. Verify with flutter analyze and flutter test (100% pass).

Write your changes to D:\project\bendehara v2\.agents\worker_m3\changes.md and write a complete handoff report to D:\project\bendehara v2\.agents\worker_m3\handoff.md.
Send message to parent when complete.

