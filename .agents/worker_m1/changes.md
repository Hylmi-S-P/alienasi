# Milestone 1: Changes Record

**Worker**: worker_m1  
**Target**: Core Data & Dues Domain Engine (Features F5, F11, F12, F13, and DuesArrearsService)  
**Timestamp**: 2026-09-20T13:15:00Z  

---

## 1. Files Modified

### 1.1 `lib/data/repositories/transaction_repository.dart`
- **Changed**:
  - `watchRecentTransactions`: Replaced `OrderingTerm(expression: t.transactionDate, mode: OrderingMode.desc)` with `OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)` to ensure any newly recorded activity (including backdated cash reconciliation) immediately appears at the top of recent transactions.
  - Added `watchAllTransactions({required String academicYearId})`: Stream query returning all transactions for the academic year, ordered chronologically by `transactionDate DESC` followed by `createdAt DESC`.
  - Added `getAllTransactions({required String academicYearId})`: Future-based query returning all transactions for the academic year with identical dual-order sorting.

### 1.2 `lib/data/database/app_database.dart`
- **Changed**:
  - In `beforeOpen`: Added composite index creation:
    `CREATE INDEX IF NOT EXISTS idx_transactions_year_created_at ON transactions(academic_year_id, created_at);`
    to guarantee high-performance index-assisted execution for `ORDER BY createdAt DESC` queries partitioned by `academic_year_id`.

---

## 2. Files Created

### 2.1 `lib/domain/services/dues_arrears_service.dart`
- **Created**:
  - `StudentArrearsReportItem`:
    - `studentNumber` (`int`): Absen number.
    - `studentName` (`String`): Student's full name.
    - `unpaidPeriodRangeText` (`String`): Formatted range of unpaid periods (e.g., `"Dari 14 Juli s.d. 18 Juli 2025"`, `"Minggu 2 Juli s.d. Minggu 4 Juli 2026"`, `"14 Juli 2026"`).
    - `unpaidPeriodsCount` (`int`): Total count of unpaid effective periods.
    - `duesRate` (`int`): Active tariff per period.
    - `totalArrearsAmount` (`int`): Total debt (`unpaidPeriodsCount * duesRate`).
    - `rateDescription` (`String`): E.g. `"Rp 2.000 / hari"`, `"Rp 5.000 / minggu"`.
    - `unpaidPeriods` (`List<DuesPeriod>`): Underlying period list.
  - `DuesArrearsSummary`: Aggregation model containing list of arrears items, `totalArrearsAmount`, `totalStudentsWithArrears`, and `totalEffectivePeriods`.
  - `DuesArrearsService`:
    - `filterEffectivePeriods`:
      - **F11 (Weekend Rule)**: In daily mode (`duesPeriodType == 'daily'`), Saturday and Sunday periods are strictly excluded from billing and arrears calculations.
      - **F12 (Activity-Driven Holiday Rule)**: In daily mode, weekday periods (Monday through Friday) where total students paid is 0 are automatically recognized as activity holidays / days off, producing 0 arrears.
      - Weekdays with $\ge 1$ student paying are effective dues days.
      - In weekly/monthly mode, all periods are effective.
    - `formatUnpaidRange`: Groups consecutive unpaid periods into human-readable range strings (daily, weekly, monthly) using calendar adjacency and effective period sequence.
    - `calculateArrears`: Filters active students, determines unpaid effective periods, computes debt amount, formats ranges, and returns only students with `totalArrearsAmount > 0`.
    - `calculateArrearsSummary`: Computes complete class arrears summary with aggregate totals.

### 2.2 `test/unit/transaction_repository_sort_test.dart`
- **Created**: Comprehensive tests covering:
  - SQLite index `idx_transactions_year_created_at` verification in `sqlite_master`.
  - `watchRecentTransactions` sorting strictly by `createdAt DESC` (verifying backdated past-date transactions appear at the top).
  - Limit enforcement on `watchRecentTransactions`.
  - `watchAllTransactions` and `getAllTransactions` ordered by `transactionDate DESC`, then `createdAt DESC`.
  - **F13**: Unrestricted general cash logging (confirming income and expenses can be logged on Saturdays, Sundays, and holidays without restriction, accurately reflecting in cash balance).

### 2.3 `test/unit/dues_arrears_service_test.dart`
- **Created**: Comprehensive tests covering:
  - **F11**: Saturday and Sunday strict exclusion from daily dues billing and arrears.
  - **F12**: Weekday 0-collection activity-driven holiday recognition with 0 arrears.
  - Effective dues day calculation (1 student paid, 1 unpaid).
  - Daily consecutive range formatting (`"Dari 14 Juli s.d. 18 Juli 2025"`).
  - Daily disjoint unpaid periods formatting (comma-separated clusters).
  - Weekly range formatting (`"Minggu 2 Juli s.d. Minggu 4 Juli 2026"`).
  - Inactive student exclusion.
  - Aggregate summary calculations (`DuesArrearsSummary`).

---

## 3. Quality & Verification Results
- `flutter analyze`: **0 errors, 0 warnings** (`No issues found!`).
- `flutter test`: **107/107 tests passed (100%)** across 16 test suites.
