# Project: Bendahara Kelas — Core Enhancements

## Architecture
- **Framework**: Flutter 3.13.2+ with Material Design 3 and Plus Jakarta Sans typography.
- **State Management**: `flutter_riverpod` (v3.4.3) with reactive `StreamProvider` and `NotifierProvider`.
- **Database & Persistence**: Drift (v2.35.0) over SQLite (`drift_flutter: ^0.3.1`).
- **Domain Services**:
  - `PdfReportService`: PDF generation using `package:pdf` (`pw.Document`, `pw.MultiPage`, `pw.Table`).
  - `ExcelReportService`: Spreadsheet exports using `package:excel`.
  - `DuesArrearsService`: Student dues arrears computation, period grouping, and holiday exclusion engine.
- **Presentation Layer**:
  - `MainScaffold`: Tab shell with `PageView` (Dashboard, DuesCheck, TransactionForm, SupervisionReport).
  - `DashboardScreen`: KPI overview, quick actions, recent recording activity.
  - `SupervisionReportScreen`: Filterable report screen, monthly stats, navigation to full transactions.
  - `AllTransactionsScreen`: Full transaction history with search, category filtering chips, dynamic summary.
  - `TransactionListItem`: Reusable transaction card with dual-timestamp indicator when backdated.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| F1 | Full Search in AllTransactionsScreen | Real-time search query matching title and description with clear button | M2 | Survey / R1 |
| F2 | Category Chips in AllTransactionsScreen | Choice chips: Semua, Kas Masuk, Kas Keluar, and specific category chips | M2 | Survey / R1 |
| F3 | Dynamic Mutation Summary Card | Real-time calculation of total income, expense, and net difference for filtered items | M2 | Survey / R1 |
| F4 | Navigation Trigger to AllTransactionsScreen | Prominent navigation card in Reports tab (`SupervisionReportScreen`) and Dashboard "Lihat Semua" | M2 | Survey / R1 |
| F5 | Dashboard Recent Activity Sorting | `watchRecentTransactions` sorted by `createdAt DESC` to show backdated entries on top | M1 | Survey / R2 |
| F6 | Dashboard Section Title Update | Rename section to "Riwayat Pencatatan Terkini" | M2 | Survey / R2 |
| F7 | Dual Timestamp Display | Transparent indicator in `TransactionListItem` and detail dialog when `transactionDate != createdAt` | M2 | Survey / R2 |
| F8 | Monthly Partitioned PDF Reports | PDF table partitioned into calendar month sections with sub-headers (`BULAN JULI 2026`) | M3 | Survey / R3 |
| F9 | Red Highlighted PDF Expense Rows | Contrast red font (`#DC2626`) and tinted background (`#FEF2F2`) on expense rows | M3 | Survey / R3 |
| F10 | Student Dues Arrears Audit in PDF | Dedicated section/page: student no., name, unpaid period range, dues rate, student total, grand total | M3 | Survey / R4 |
| F11 | Daily Dues Weekend Exclusion Rule | Saturdays and Sundays strictly excluded from daily dues billing and arrears calculation | M1 | Survey / R5 |
| F12 | Daily Dues Activity-Driven Holiday Rule | Weekdays (Mon-Fri) with 0 collections auto-treated as holidays (no arrears); >=1 collection = effective day | M1 | Survey / R5 |
| F13 | 100% Unrestricted General Transactions | General income and expenses active anytime (including weekends and holidays), fully affecting balance | M1 | Survey / R5 |
| F14 | Comprehensive Automated Test Suite | Unit and widget tests across Tiers 1-4 verifying R1-R5, 100% passing, 0 analyze issues | M4 | Survey / Quality |
| F15 | Release APK Compilation | Version bumped to `1.0.3+4`, compiled `Bendahara-Kelas-Release.apk` for in-place install | M4 | Survey / Quality |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Core Data & Dues Domain Engine | `TransactionRepository.watchRecentTransactions` sorting by `createdAt DESC`; `DuesArrearsService` with strict weekend exclusion, activity-driven holiday detection, and arrears period range formatting; non-destructive DB index. | none | DONE |
| M2 | UI Screens & Navigation | `AllTransactionsScreen` with real-time search, category chips, and dynamic summary; Navigation button on `SupervisionReportScreen` and Dashboard; Dashboard "Riwayat Pencatatan Terkini" header; Dual timestamp display in `TransactionListItem`. | M1 | DONE |
| M3 | PDF Reporting Enhancements | `PdfReportService` monthly table partitioning with month subheaders; red visual expense highlighting; dedicated `Rekapitulasi Tunggakan Kas Siswa` audit page/section. | M1 | DONE |
| M4 | Comprehensive Testing & Release Compilation | E2E test suite covering Tiers 1-4; `flutter analyze` 0 issues; `flutter test` 100% pass; bump `versionCode: 4` and compile `Bendahara-Kelas-Release.apk`. | M2, M3 | DONE |


## Interface Contracts
### `DuesArrearsService` ↔ `PdfReportService` & `SupervisionReportScreen`
- **Model**: `StudentArrearsReportItem`
  ```dart
  class StudentArrearsReportItem {
    final int studentNumber;
    final String studentName;
    final String unpaidPeriodRangeText; // e.g. "Dari 14 Juli s.d. 18 Juli" or "Minggu 2 Juli s.d. Minggu 4 Juli"
    final int unpaidPeriodsCount;
    final int duesRate;
    final int totalArrearsAmount; // unpaidPeriodsCount * duesRate
  }
  ```
- **Service API**:
  ```dart
  class DuesArrearsService {
    static Future<List<StudentArrearsReportItem>> calculateArrears({
      required AppDatabase db,
      required String academicYearId,
      DateTime? upToDate,
    });
    
    static String formatUnpaidRanges({
      required List<DateTime> unpaidDates,
      required String duesPeriodType, // 'daily', 'weekly', 'monthly'
    });
  }
  ```

### `TransactionRepository` ↔ UI Providers
- `Stream<List<TransactionWithCategory>> watchRecentTransactions({required String academicYearId, int limit = 5})`:
  - Must sort by `OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)`.
- `Stream<List<TransactionWithCategory>> watchAllTransactions({required String academicYearId})`:
  - Must return all transactions for the academic year, sorted by `transactionDate DESC` or `createdAt DESC`.

### `PdfReportService`
- `static Future<Uint8List> generateReportPdf({required AcademicYear academicYear, required String periodRangeTitle, required List<TransactionWithCategory> items, List<StudentArrearsReportItem>? studentArrears})`
  - When `studentArrears` is provided, generates the dedicated arrears audit page.
  - Partitions `items` by `(item.transaction.transactionDate.year, item.transaction.transactionDate.month)` and renders month sub-headers.
  - Renders expense amounts with `#DC2626` font and `#FEF2F2` background tint.

## Code Layout
- `lib/data/database/tables/`: Drift table schemas (`transactions.dart`, `dues_periods.dart`, `dues_payments.dart`, `students.dart`, `academic_years.dart`).
- `lib/data/repositories/`:
  - `transaction_repository.dart`: Transaction queries and insertions.
  - `dues_repository.dart`: Dues reconciliation and period operations.
- `lib/domain/services/`:
  - `dues_arrears_service.dart`: Business logic for arrears calculation, weekend/holiday filtering, and range formatting.
  - `pdf_report_service.dart`: Document generation, monthly partitions, red highlights, arrears audit page.
  - `excel_report_service.dart`: Spreadsheet generation.
- `lib/presentation/screens/`:
  - `dashboard_screen.dart`: Dashboard with "Riwayat Pencatatan Terkini".
  - `supervision_report_screen.dart`: Reports tab with navigation card to `AllTransactionsScreen`.
  - `all_transactions_screen.dart`: Full transactions screen with search, category chips, dynamic summary.
- `lib/presentation/widgets/`:
  - `transaction_list_item.dart`: Reusable card with dual timestamp indication.
  - `dues_period_calendar_card.dart`: Calendar with disabled weekend cells in daily mode.
- `test/`: Unit, widget, and integration tests.
