# Dispatch for Worker Milestone 2

## Mission
Implement Milestone 2: UI Screens & Navigation (Features F1, F2, F3, F4, F6, F7).

## Mandatory Reference
Read `D:\project\bendehara v2\.agents\ORIGINAL_REQUEST.md` completely before starting.

## Mandatory Integrity Warning
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

## Context & Inputs
- Project Scope: `D:\project\bendehara v2\PROJECT.md`
- Survey Findings: `D:\project\bendehara v2\.agents\explorer_survey_2\survey_ui_nav.md` and `D:\project\bendehara v2\.agents\explorer_survey_2\handoff.md`
- Working Directory: `D:\project\bendehara v2\.agents\worker_m2`

## File Ownership
You exclusively own and can modify or create:
- `lib/presentation/screens/all_transactions_screen.dart` (new file)
- `lib/presentation/screens/supervision_report_screen.dart`
- `lib/presentation/screens/dashboard_screen.dart`
- `lib/presentation/widgets/transaction_list_item.dart`
- `lib/presentation/providers/app_providers.dart`
- `test/widget/all_transactions_screen_test.dart` (new file)
- `test/widget/dashboard_recent_activity_test.dart` (new file)

DO NOT modify files outside this list in this milestone.

## Detailed Requirements
1. **Providers (`lib/presentation/providers/app_providers.dart`)**:
   - Add `allTransactionsProvider`:
     ```dart
     final allTransactionsProvider = StreamProvider<List<TransactionWithCategory>>((ref) {
       final activeYear = ref.watch(activeAcademicYearProvider).valueOrNull;
       if (activeYear == null) return Stream.value([]);
       return ref.watch(transactionRepoProvider).watchAllTransactions(academicYearId: activeYear.id);
     });
     ```
2. **`AllTransactionsScreen` (`lib/presentation/screens/all_transactions_screen.dart`)** (F1, F2, F3):
   - Full transaction history screen with no 10-item cap.
   - Search bar: Real-time filtering against `item.transaction.title` and `item.transaction.description` (case-insensitive) with clear text button.
   - Category chips: Horizontal scrollable choice chips ("Semua", "Kas Masuk", "Kas Keluar", and individual category names from `categoriesProvider`).
   - Dynamic mutations summary card: Displays filtered total income, total expense, net difference (`income - expense`), and count of filtered transactions, updating live.
   - List display: Renders transactions using `TransactionListItem`.
   - Empty state: Clean empty illustration/text if no matching transactions found.
3. **Navigation Triggers (F4)**:
   - In `SupervisionReportScreen` (`lib/presentation/screens/supervision_report_screen.dart`):
     In Section 5, add a prominent button/card: `"Lihat Semua Riwayat (${txItems.length} Transaksi) >"` navigating to `AllTransactionsScreen` via `Navigator.push`.
   - In `DashboardScreen` (`lib/presentation/screens/dashboard_screen.dart`):
     Update the `"Lihat Semua"` button in the recent activity section to navigate directly to `AllTransactionsScreen` via `Navigator.push`.
4. **Dashboard Recent Activity Section Header (F6)**:
   - In `DashboardScreen`, rename the section title from `"Transaksi Terbaru"` to **"Riwayat Pencatatan Terkini"**.
5. **Dual Date / Timestamp Display (F7)**:
   - In `TransactionListItem` (`lib/presentation/widgets/transaction_list_item.dart`):
     Compare `item.transaction.transactionDate` with `item.transaction.createdAt`.
     When calendar dates differ (e.g. `!DateUtils.isSameDay(tx.transactionDate, tx.createdAt)`):
     Transparently display both the physical transaction date and the recording timestamp (e.g., `Tanggal: 14 Jul 2026 • Dicatat: 20 Sep 2026` or a clear backdate badge).
   - Also update the transaction detail bottom sheet / dialog if present.
6. **Tests**:
   - Write comprehensive widget tests for `AllTransactionsScreen` (search, chips, dynamic summary, navigation) in `test/widget/all_transactions_screen_test.dart`.
   - Write widget tests for Dashboard's "Riwayat Pencatatan Terkini" and dual timestamp display in `test/widget/dashboard_recent_activity_test.dart`.
   - Verify `flutter analyze` has 0 errors/0 warnings.
   - Verify `flutter test` passes 100%.

## Output
Write `changes.md` and `handoff.md` in `D:\project\bendehara v2\.agents\worker_m2\` and notify parent via message.

## 2026-09-20T13:21:00Z
You are Worker M2 implementing Milestone 2: UI Screens & Navigation for Bendahara Kelas.
Working directory: D:\project\bendehara v2\.agents\worker_m2

MANDATORY FIRST STEP: Read D:\project\bendehara v2\.agents\ORIGINAL_REQUEST.md completely.
Then read your detailed task assignment in D:\project\bendehara v2\.agents\worker_m2\DISPATCH.md.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Implement:
1. allTransactionsProvider in lib/presentation/providers/app_providers.dart.
2. AllTransactionsScreen (search bar matching title/description, horizontal category choice chips, live dynamic mutations summary card, full list with no 10-item cap).
3. Navigation banner in SupervisionReportScreen Section 5 and update DashboardScreen "Lihat Semua" to open AllTransactionsScreen.
4. Update DashboardScreen recent section title to "Riwayat Pencatatan Terkini".
5. Update TransactionListItem to show transparent dual timestamps when physical date != recording date (backdated).
6. Author comprehensive widget tests in test/widget/all_transactions_screen_test.dart and test/widget/dashboard_recent_activity_test.dart.
7. Run flutter analyze and flutter test. Verify 0 errors, 0 warnings, and 100% test pass.

Write your changes to D:\project\bendehara v2\.agents\worker_m2\changes.md and write a complete handoff report to D:\project\bendehara v2\.agents\worker_m2\handoff.md.
Send message to parent when complete.

