# Dispatch for Worker Milestone 1

## Mission
Implement Milestone 1: Core Data & Dues Domain Engine (Features F5, F11, F12, F13, and DuesArrearsService).

## Mandatory Reference
Read `D:\project\bendehara v2\.agents\ORIGINAL_REQUEST.md` completely before starting.

## Mandatory Integrity Warning
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

## Context & Inputs
- Project Scope: `D:\project\bendehara v2\PROJECT.md`
- Survey Findings: `D:\project\bendehara v2\.agents\explorer_survey_1\survey_db_logic.md` and `D:\project\bendehara v2\.agents\explorer_survey_1\handoff.md`
- Working Directory: `D:\project\bendehara v2\.agents\worker_m1`

## File Ownership
You exclusively own and can modify or create:
- `lib/data/repositories/transaction_repository.dart`
- `lib/data/database/app_database.dart`
- `lib/domain/services/dues_arrears_service.dart` (new file)
- `test/unit/dues_arrears_service_test.dart` (new file)
- `test/unit/transaction_repository_sort_test.dart` (new file)

DO NOT modify files outside this list in this milestone.

## Detailed Requirements
1. **F5: `watchRecentTransactions` Order by `createdAt DESC`**:
   - In `lib/data/repositories/transaction_repository.dart`, update `watchRecentTransactions`:
     Order by `OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)`.
   - Also add `watchAllTransactions({required String academicYearId})` returning transactions ordered by `transactionDate DESC` (or `createdAt DESC` fallback) for Milestone 2.
2. **Database Index**:
   - In `lib/data/database/app_database.dart`, in `beforeOpen`, add:
     `await customStatement('CREATE INDEX IF NOT EXISTS idx_transactions_year_created_at ON transactions(academic_year_id, created_at);');`
3. **`DuesArrearsService` Implementation (`lib/domain/services/dues_arrears_service.dart`)**:
   - Create `StudentArrearsReportItem`:
     - `studentNumber` (int)
     - `studentName` (String)
     - `unpaidPeriodRangeText` (String) (e.g. "Dari 14 Juli s.d. 18 Juli" or "Minggu 2 Juli s.d. Minggu 4 Juli" or single period)
     - `unpaidPeriodsCount` (int)
     - `duesRate` (int)
     - `totalArrearsAmount` (int) (`unpaidPeriodsCount * duesRate`)
   - Create `DuesArrearsService`:
     - `calculateArrears`: Given active students, academic year, dues periods, and dues payments:
       - **F11 (Weekend Rule)**: For daily dues (`duesPeriodType == 'daily'`), any period falling on Saturday (`DateTime.saturday`) or Sunday (`DateTime.sunday`) is strictly excluded. It MUST NOT generate any arrears or billing obligation.
       - **F12 (Activity-Driven Holiday Rule)**: For daily dues, any weekday period (Monday to Friday) where the total number of students who paid (`isPaid == true`) is 0 is automatically recognized as an activity holiday / day off. It MUST NOT generate any arrears.
       - Any weekday period where at least 1 student paid (`>= 1`) is an effective dues day. Students with `isPaid == false` (or missing payment) for that day are considered in arrears.
       - For weekly or monthly dues, periods where student hasn't paid are in arrears.
       - Group consecutive unpaid dates into human-readable range strings (e.g., "Dari 14 Juli s.d. 18 Juli 2026", or comma-separated formatted groups).
       - Only return students who actually have `totalArrearsAmount > 0` (or provide helper for full summary).
4. **F13: Unrestricted General Transactions**:
   - Verify that general class transactions in `TransactionRepository` (incomes & expenses) are never blocked or filtered by weekend or holiday rules.
5. **Unit Tests**:
   - Write comprehensive unit tests in `test/unit/dues_arrears_service_test.dart` and `test/unit/transaction_repository_sort_test.dart`.
   - Ensure all 94 existing tests + new tests pass (`flutter test`).
   - Ensure `flutter analyze` reports 0 issues.

## Verification & Output
- Run `flutter analyze` and `flutter test`.
- Document all changes and verification outputs in `D:\project\bendehara v2\.agents\worker_m1\changes.md` and `D:\project\bendehara v2\.agents\worker_m1\handoff.md`.
- Send message to parent upon completion.

## 2026-09-20T13:10:00Z
You are Worker M1 implementing Milestone 1: Core Data & Dues Domain Engine for Bendahara Kelas.
Working directory: D:\project\bendehara v2\.agents\worker_m1

MANDATORY FIRST STEP: Read D:\project\bendehara v2\.agents\ORIGINAL_REQUEST.md completely.
Then read your detailed task assignment in D:\project\bendehara v2\.agents\worker_m1\DISPATCH.md.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Implement:
1. TransactionRepository.watchRecentTransactions sorted by createdAt DESC, and watchAllTransactions.
2. Composite index on transactions(academic_year_id, created_at) in beforeOpen.
3. DuesArrearsService and StudentArrearsReportItem (weekend exclusion, activity holiday rule, consecutive range formatting).
4. Unit tests in test/unit/dues_arrears_service_test.dart and test/unit/transaction_repository_sort_test.dart.
5. Run flutter analyze and flutter test. Verify 0 errors, 0 warnings, and 100% tests pass.

Write your changes to D:\project\bendehara v2\.agents\worker_m1\changes.md and write a complete handoff report to D:\project\bendehara v2\.agents\worker_m1\handoff.md.
Send message to parent when complete.
