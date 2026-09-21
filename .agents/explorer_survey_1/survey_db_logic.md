# Technical Survey Report: Database, Models, and Core Dues Logic

**Date**: 2026-09-20  
**Target Application**: `Bendahara Kelas` (Flutter / Drift SQLite / Riverpod)  
**Investigator**: Explorer Survey 1  
**Working Directory**: `D:\project\bendehara v2\.agents\explorer_survey_1`  

---

## 1. Executive Summary

This investigation analyzed the database layer, data models, repository queries, dues (*kas siswa*) calculations, transaction lifecycles, and report generation pipelines of the **Bendahara Kelas** application.

### Key Discoveries:
1. **`createdAt` Column Already Exists**:
   - The `transactions` table in Drift (`lib/data/database/tables/transactions.dart`) already defines `DateTimeColumn get createdAt => dateTime()();`.
   - When transactions are inserted (`TransactionRepository.insertTransaction` and `DuesRepository.reconcileIntoGeneralCash`), `createdAt: DateTime.now()` is correctly stamped.
2. **Dashboard Query Ordering Flaw (R2 Root Cause)**:
   - `TransactionRepository.watchRecentTransactions` currently orders by `transactionDate DESC`, **not** `createdAt DESC`.
   - Consequently, backdated transactions (such as reconciling July 2026 dues today in September) get stamped with a July `transactionDate` and are buried at the bottom of recent activity.
   - Changing the query to `ORDER BY createdAt DESC` immediately resolves this issue without schema modification.
3. **No Existing Weekend / Holiday Rule for Daily Dues (R5 Gap)**:
   - In daily dues mode, Saturdays and Sundays are currently treated like any other day: clicking them creates a `dues_periods` row and empty `dues_payments` rows for all students.
   - There is no logic recognizing weekdays with 0 collections as school holidays.
   - However, general transactions (`transactions` table) are completely decoupled from `dues_periods`, allowing unrestricted income/expense logging at any time.
4. **No Dedicated Student Arrears (*Tunggakan*) Engine (R4 Gap)**:
   - The codebase has no arrears calculation service or model. The PDF generator (`PdfReportService`) only prints general transactions, completely lacking a student dues arrears audit sheet.
   - The Excel generator (`ExcelReportService`) only checks if a student's paid period count equals the total period count in the DB, without period range formatting (e.g., *"Dari 14 Juli s.d. 18 Juli"*).
5. **PDF Generator Lacks Monthly Partitioning & Expense Highlighting (R3 Gap)**:
   - `PdfReportService` prints all transactions in a single flat table. It lacks calendar month partition headers (e.g., `BULAN JULI 2026`) and contrast red highlights for expenses.
6. **No Full Transaction History Screen (R1 Gap)**:
   - `supervision_report_screen.dart` limits transaction rendering to 10 rows with a "Muat 10 Lagi" button. There is no dedicated `AllTransactionsScreen` with real-time text search, category chips, and dynamic totals.
7. **Database Stability & Migration Safety**:
   - Drift schema version is currently `2`. No breaking schema change is required.
   - All 94 existing unit and widget tests pass cleanly (`flutter test`), and static analysis (`flutter analyze`) reports 0 issues.

---

## 2. Database Helper, DAOs, Tables & Schema Definitions

### 2.1 Database Core: `AppDatabase`
- **File**: `lib/data/database/app_database.dart`
- **Generated Code**: `lib/data/database/app_database.g.dart`
- **Engine**: Drift SQLite with WAL (Write-Ahead Logging) mode and memory temp store.
- **Database Name**: `'bendahara_v2_db'`
- **Current Schema Version**: `2`
- **Registered Tables**:
  1. `AcademicYears` (`academic_years`)
  2. `Students` (`students`)
  3. `Categories` (`categories`)
  4. `Transactions` (`transactions`)
  5. `DuesPeriods` (`dues_periods`)
  6. `DuesPayments` (`dues_payments`)

### 2.2 Table Schemas & Models

#### A. `Transactions` (`lib/data/database/tables/transactions.dart`)
```dart
class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get academicYearId => text().references(AcademicYears, #id, onDelete: KeyAction.restrict)();
  TextColumn get categoryId => text().references(Categories, #id, onDelete: KeyAction.restrict)();
  TextColumn get type => text()(); // 'income' or 'expense'
  IntColumn get amount => integer()(); // Nominal in Rupiah
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get receiptImagePath => text().nullable()();
  DateTimeColumn get transactionDate => dateTime()();
  DateTimeColumn get createdAt => dateTime()(); // ALREADY PRESENT
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
```
- **Generated Model**: `Transaction` in `app_database.g.dart`.
- **Existing Indexes** (configured in `AppDatabase.beforeOpen`):
  - `idx_transactions_year_date` on `transactions(academic_year_id, transaction_date)`
  - `idx_transactions_type` on `transactions(academic_year_id, type)`
  - `idx_transactions_category` on `transactions(category_id)`
- **Recommended Index for R2**:
  - `idx_transactions_year_created_at` on `transactions(academic_year_id, created_at)` in `beforeOpen` (via `CREATE INDEX IF NOT EXISTS`).

#### B. `DuesPeriods` (`lib/data/database/tables/dues_periods.dart`)
```dart
class DuesPeriods extends Table {
  TextColumn get id => text()();
  TextColumn get academicYearId => text().references(AcademicYears, #id, onDelete: KeyAction.cascade)();
  TextColumn get periodLabel => text()(); // e.g. "Harian 14 September 2026", "Minggu 2 September 2026"
  DateTimeColumn get dueDate => dateTime()();
  IntColumn get targetAmount => integer()(); // Standard per student (e.g. 2000, 5000)
  BoolColumn get isReconciled => boolean().withDefault(const Constant(false))();
  IntColumn get reconciledAmount => integer().withDefault(const Constant(0))();
  TextColumn get transactionId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {academicYearId, periodLabel}
  ];
}
```
- **Generated Model**: `DuesPeriod`.
- **Existing Indexes**:
  - `idx_dues_periods_year_label` UNIQUE on `dues_periods(academic_year_id, period_label)`.

#### C. `DuesPayments` (`lib/data/database/tables/dues_payments.dart`)
```dart
class DuesPayments extends Table {
  TextColumn get id => text()();
  TextColumn get duesPeriodId => text().references(DuesPeriods, #id, onDelete: KeyAction.cascade)();
  TextColumn get studentId => text().references(Students, #id, onDelete: KeyAction.cascade)();
  IntColumn get amountPaid => integer().withDefault(const Constant(0))();
  BoolColumn get isPaid => boolean().withDefault(const Constant(false))();
  DateTimeColumn get paidAt => dateTime().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {duesPeriodId, studentId}
  ];
}
```
- **Generated Model**: `DuesPayment`.
- **Existing Indexes**:
  - `idx_dues_payments_period_paid` on `dues_payments(dues_period_id, is_paid)`.

#### D. `AcademicYears` (`lib/data/database/tables/academic_years.dart`)
```dart
class AcademicYears extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get grade => integer()();
  TextColumn get treasurerName => text().withDefault(const Constant('Bendahara'))();
  TextColumn get supervisorName => text().withDefault(const Constant('Ibu Pengawas'))();
  IntColumn get defaultDuesAmount => integer().withDefault(const Constant(5000))();
  TextColumn get duesPeriodType => text().withDefault(const Constant('weekly'))(); // 'daily', 'weekly', 'monthly'
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
```

#### E. `Students` (`lib/data/database/tables/students.dart`)
```dart
class Students extends Table {
  TextColumn get id => text()();
  TextColumn get academicYearId => text().references(AcademicYears, #id, onDelete: KeyAction.cascade)();
  IntColumn get attendanceNumber => integer()();
  TextColumn get name => text()();
  TextColumn get status => text().withDefault(const Constant('active'))(); // 'active', 'inactive'
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
```

#### F. `Categories` (`lib/data/database/tables/categories.dart`)
```dart
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()(); // 'income' or 'expense'
  TextColumn get name => text()();
  TextColumn get iconName => text()();
  TextColumn get colorHex => text()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
```

---

## 3. Transaction Storage, Querying, and Recent Transactions

### 3.1 Insertion Mechanisms
Transactions are created through two distinct pathways:

1. **Manual General Transactions (`TransactionFormScreen` -> `TransactionRepository.insertTransaction`)**:
   - `lib/data/repositories/transaction_repository.dart:162-190`
   - Takes `academicYearId`, `categoryId`, `type`, `amount`, `title`, `description`, `receiptImagePath`, and `transactionDate`.
   - Sets `createdAt = DateTime.now()` and `updatedAt = DateTime.now()`.
   - Can be logged on any day, including weekends or holidays.

2. **Dues Reconciliation (`DuesCheckScreen` -> `DuesRepository.reconcileIntoGeneralCash`)**:
   - `lib/data/repositories/dues_repository.dart:329-431`
   - When the bendahara clicks "Simpan & Masukkan ke Kas Kelas":
     - Calculates `delta = totalCollected - previouslyReconciled`.
     - Determines `effectivePeriodDate` from the period's label or `dueDate`.
     - Constructs `txDate = DateTime(effectivePeriodDate.year, effectivePeriodDate.month, effectivePeriodDate.day, now.hour, now.minute, now.second)`.
     - Sets `createdAt = DateTime.now()`.
     - Inserts a general transaction under category `"Uang Kas Rutin"` with title `'Kas Kelas (${period.periodLabel})'`.
     - Updates `dues_periods.isReconciled = true` and `reconciledAmount = totalCollected`.

### 3.2 Investigation of `createdAt` vs `transactionDate`
- **`transactionDate`**: Represents the physical or nominal effective date of the transaction (e.g., July 14, 2026).
- **`createdAt`**: Represents the exact timestamp when the record was entered into the database (e.g., September 20, 2026 20:05:00).
- **Current Problem**:
  `TransactionRepository.watchRecentTransactions` (`lib/data/repositories/transaction_repository.dart:33-55`) executes:
  ```dart
  ..orderBy([(t) => OrderingTerm(expression: t.transactionDate, mode: OrderingMode.desc)])
  ..limit(limit)
  ```
  If the treasurer reconciles backdated dues or enters a backdated expense, `transactionDate` is placed in the past, so the transaction does **not** appear on the Dashboard's recent card.

### 3.3 Dashboard Display Flow
- In `lib/presentation/providers/app_providers.dart:60-66`:
  `recentTransactionsProvider` watches `watchRecentTransactions(academicYearId: activeYear.id, limit: 5)`.
- In `lib/presentation/screens/dashboard_screen.dart:415-467`:
  - Card title: `"Transaksi Terbaru"`.
  - Maps items: `recentItems.take(5).map((item) => TransactionListItem(item: item))`.
  - Button `"Lihat Semua"` switches tab to Tab 3 (Laporan).
- In `lib/presentation/widgets/transaction_list_item.dart:81-89`:
  - Renders only `DateFormatter.toHumanDate(tx.transactionDate)`.

### 3.4 Requirements for R1 and R2
- **For R2 (Dashboard Recent Recording Activity)**:
  1. Change `watchRecentTransactions` ordering expression to:
     `OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)`.
  2. Update Dashboard card header to **"Riwayat Pencatatan Terkini"** (*Recent Recording Activity*).
  3. In `TransactionListItem` or a specialized recent tile, if `tx.transactionDate` differs from `tx.createdAt` (comparing calendar day `year/month/day`), render both dates transparently (e.g., `"Tgl Transaksi: 14 Jul 2026 • Dicatat: 20 Sep 2026"` or a distinct badge).
- **For R1 (`AllTransactionsScreen`)**:
  1. Add a dedicated query in `TransactionRepository`:
     `watchAllTransactions({required String academicYearId})` without date bounds or limits.
  2. Provide navigation from the Laporan tab: `"Lihat Semua Riwayat (N Transaksi) >"`.
  3. Create `AllTransactionsScreen` featuring:
     - Full transaction list without 10-item truncation.
     - Real-time search bar filtering by `title` and `description`.
     - Filter chips: "Semua", "Kas Masuk", "Kas Keluar", or category-specific.
     - Dynamic mutation summary banner displaying total filtered income, expense, and balance.

---

## 4. Dues (*Kas Siswa*) Calculation Logic & Arrears Engine

### 4.1 Storage & Hierarchy
```
AcademicYear (duesPeriodType: daily/weekly/monthly, defaultDuesAmount: e.g. 2000/5000)
 └── DuesPeriod (periodLabel: e.g. "Harian 14 September 2026", dueDate, targetAmount, reconciledAmount)
      └── DuesPayment (studentId, amountPaid, isPaid, paidAt)
```

### 4.2 How Periods are Generated
- Managed in `DuesRepository.getOrCreateActivePeriod` (`lib/data/repositories/dues_repository.dart:43-147`).
- Formatted by `formatPeriodLabel(date, periodType)` in `app_providers.dart`:
  - `'daily'`: `'Harian ${DateFormatter.toHumanDate(date)}'`
  - `'weekly'`: `'Minggu $weekNumber $currentMonth ${date.year}'`
  - `'monthly'`: `'Bulan $currentMonth ${date.year}'`
- When accessed, it checks `dues_periods` for `academicYearId` and `periodLabel`.
- If missing, it creates the period AND self-heals by bulk-inserting `dues_payments` rows for all active students with `isPaid: false`, `amountPaid: 0`.

### 4.3 Current Lack of Arrears (*Tunggakan*) Engine
- Neither `dues_repository.dart` nor any domain service calculates student arrears period-by-period.
- The only check currently present is in `supervision_report_screen.dart:145` and `excel_report_service.dart`:
  ```dart
  final isAllPaid = periods.isNotEmpty && paidPeriodsCount >= periods.length;
  ```
  This is a crude count check that fails to identify which periods are missing, their date ranges, or the amounts owed.

### 4.4 Proposed Core Arrears Engine (Required for R4 & R5)
To support R4 and R5, an arrears calculation utility (e.g. `StudentArrearsService` or methods in `DuesRepository`) must be implemented with the following specifications:

1. **Student Arrears Data Structure**:
   ```dart
   class StudentArrearsInfo {
     final Student student;
     final List<DuesPeriod> unpaidPeriods;
     final int totalArrearsAmount;
     final String periodRangeDescription; // e.g. "Dari 14 Juli s.d. 18 Juli" or "Minggu 2 Juli s.d. Minggu 4 Juli"
     final String rateDescription; // e.g. "Rp2.000 / hari" or "Rp5.000 / minggu"
   }
   ```

2. **Period Range Formatting Algorithm**:
   - For consecutive periods, aggregate start and end labels:
     - Daily: If missing July 14 to July 18 -> `"Dari 14 Juli s.d. 18 Juli"`. If single day -> `"14 Juli"`. If multiple disjoint blocks -> `"14–18 Juli, 22 Juli"`.
     - Weekly: If missing Week 2 to Week 4 of July -> `"Minggu 2 Juli s.d. Minggu 4 Juli"`.
     - Monthly: `"Juli s.d. Agustus 2026"`.
   - Active rate: `CurrencyFormatter.format(period.targetAmount) + (periodType == 'daily' ? ' / hari' : ' / minggu')`.

3. **Filtering for the Audit Sheet**:
   - Filter to keep **only** students with `totalArrearsAmount > 0` (students who have fully paid are excluded from the arrears audit table).
   - Compute total uncollected class arrears: `sum(student.totalArrearsAmount)`.

---

## 5. Weekend & Holiday Handling Analysis (R5)

### 5.1 Current Weekend Handling
- In `lib/presentation/widgets/dues_period_calendar_card.dart:446-447`:
  Saturday (`Sab`) and Sunday (`Min`) headers are colored red, but **every cell in the calendar grid is fully interactive**.
- If a user taps Saturday or Sunday in daily mode:
  - A `DuesPeriod` row like `"Harian 20 September 2026"` is created.
  - Zero-payment rows are created for every student.
  - The system treats it as an active dues billing day, creating false arrears.

### 5.2 Required R5 Rules for Daily Dues
1. **Rule 1: Strict Weekend Exclusion (Saturday & Sunday)**:
   - Saturdays and Sundays are **never** billable days for daily student dues.
   - They must never incur student arrears, regardless of whether a period record exists.
   - In `DuesPeriodCalendarCard`:
     - When `periodType == 'daily'`, Saturday and Sunday cells should indicate "Libur" / "Bebas Kas" and be disabled or non-billable.
   - In `DuesCheckScreen`:
     - If viewing a weekend date, display a clear banner: *"Hari Libur Bebas Kas Akhir Pekan (Sabtu & Minggu tidak ada tagihan kas harian)"*.
2. **Rule 2: Activity-Driven Weekday School Holiday Rule (Monday to Friday)**:
   - For any weekday (Senin s.d. Jumat):
     - **If $\ge 1$ student has paid** (`isPaid == true` or `amountPaid > 0`): The day is an **Effective School/Dues Day**. Any student who has not paid owes dues and is recorded in arrears.
     - **If $0$ students have paid**: The day is automatically recognized as an **Activity-Free Holiday / Tanggal Merah / Libur Sekolah**. The system does not charge dues or record arrears for this day.
3. **Rule 3: General Class Cash Transactions 100% Unrestricted**:
   - The holiday and weekend rules **only apply to student dues (kas siswa)**.
   - General class cash operations (`transactions` table) — such as income from school bazaar/donations or expenses for weekend activities, stationery, or competition snacks on Sunday — **remain 100% active on any calendar day and fully impact the general cash balance**.

---

## 6. PDF & Excel Report Services Analysis (R3, R4)

### 6.1 Current `PdfReportService` (`lib/domain/services/pdf_report_service.dart`)
- **Signature**:
  ```dart
  static Future<Uint8List> generateReportPdf({
    required AcademicYear academicYear,
    required String periodRangeTitle,
    required List<TransactionWithCategory> items,
  })
  ```
- **Structure**:
  - Executive summary box (Total Masuk, Total Keluar, Sisa Saldo).
  - Single flat `pw.TableHelper.fromTextArray` for all transactions.
  - Receipt image annex.
- **Deficiencies against R3 & R4**:
  - No monthly calendar grouping/partition headers.
  - Expense rows have no red highlight (text or row styling).
  - Completely missing the Student Dues Arrears Audit Section (*Rekapitulasi Tunggakan Kas Siswa*).

### 6.2 Required Enhancements to `PdfReportService`
1. **Monthly Partitioning (R3)**:
   - Group sorted transactions by calendar month (`DateTime(tx.year, tx.month)`).
   - Render a distinct month section header before each group (e.g., `BULAN JULI 2026`, `BULAN AGUSTUS 2026`).
2. **Red Highlight on Expenses (R3)**:
   - For rows where `tx.type == 'expense'`:
     - Highlight the expense nominal or type badge with a distinct red color (`#DC2626` / `#EF4444`).
     - Optionally apply subtle red row background tint or red text styling to ensure immediate visibility for teachers and parents.
3. **Dedicated Student Arrears Audit Sheet / Page (R4)**:
   - Add a dedicated audit section / page in the PDF:
     - Title: `REKAPITULASI TUNGGAKAN KAS SISWA`.
     - Columns: `No`, `No. Absen`, `Nama Siswa`, `Periode Menunggak`, `Tarif Kas`, `Total Tunggakan (Rp)`.
     - Only includes students with outstanding dues.
     - Displays summary row at the bottom: `Total Akumulasi Kas Kelas Belum Tertagih: Rp X.XXX.XXX`.
   - Update `PdfReportService.generateReportPdf` signature or overload to accept `List<StudentArrearsInfo>? arrearsItems`.

---

## 7. Architecture & Dependency Mapping

### 7.1 Core Classes and Functions Matrix

| Component | File Path | Key Classes / Functions | Primary Responsibility |
|---|---|---|---|
| **Database** | `lib/data/database/app_database.dart` | `AppDatabase`, `beforeOpen`, migrations | Drift SQLite DB, indexes, schema v2 |
| **Transactions Table** | `lib/data/database/tables/transactions.dart` | `Transactions` table | Stores income/expense, already includes `createdAt` |
| **Dues Periods Table** | `lib/data/database/tables/dues_periods.dart` | `DuesPeriods` table | Stores dues periods, target amount, reconciliation |
| **Dues Payments Table** | `lib/data/database/tables/dues_payments.dart` | `DuesPayments` table | Stores per-student payment status & amounts |
| **Transaction Repo** | `lib/data/repositories/transaction_repository.dart` | `TransactionRepository.watchRecentTransactions` | **Needs order fix: change to `createdAt DESC`**; add `watchAllTransactions` |
| **Dues Repo** | `lib/data/repositories/dues_repository.dart` | `DuesRepository.reconcileIntoGeneralCash` | Reconciles dues into general cash with `createdAt = now` |
| **PDF Report** | `lib/domain/services/pdf_report_service.dart` | `PdfReportService.generateReportPdf` | **Needs: monthly partition, red expense highlight, arrears audit table** |
| **Excel Report** | `lib/domain/services/excel_report_service.dart` | `ExcelReportService.generateExcel` | Generates 2-sheet Excel report |
| **Providers** | `lib/presentation/providers/app_providers.dart` | `recentTransactionsProvider`, `activeDuesPeriodProvider` | Riverpod streams connecting repositories to UI |
| **Dashboard** | `lib/presentation/screens/dashboard_screen.dart` | `DashboardScreen` | **Needs: "Riwayat Pencatatan Terkini" header & dual date display** |
| **Dues Check** | `lib/presentation/screens/dues_check_screen.dart` | `DuesCheckScreen` | Dues check-off & reconciliation UI |
| **Dues Calendar** | `lib/presentation/widgets/dues_period_calendar_card.dart` | `DuesPeriodCalendarCard` | **Needs: weekend exclusion indicator for daily mode** |
| **Transaction Item**| `lib/presentation/widgets/transaction_list_item.dart` | `TransactionListItem`, `_TransactionDetailDialog` | Displays transaction item & detail dialog with receipt |
| **All Transactions**| `lib/presentation/screens/all_transactions_screen.dart` | `AllTransactionsScreen` *(To be created)* | Full history, real-time search, category filter, dynamic summary |

### 7.2 Safety Assessment & Test Baseline
- **Current Test Coverage**: 94 tests passing (`100%`).
- **Linter Status**: `flutter analyze` 0 issues.
- **Migration Risk**: Low. No table schema modifications or destructive migrations required.
  - Adding `CREATE INDEX IF NOT EXISTS idx_transactions_year_created_at` in `beforeOpen` is 100% backwards-compatible.
  - Adding `AllTransactionsScreen`, updating `PdfReportService`, and adding arrears calculation functions are purely additive or behavioral refinements.
