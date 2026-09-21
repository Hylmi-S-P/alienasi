# Handoff Report: UI Architecture, Navigation, Dashboard & Reports Tab Investigation

**Agent**: Explorer Survey 2  
**Date**: 2026-09-20T13:07:30Z  
**Type**: Hard Handoff (Investigation Complete)  
**Destination**: Orchestrator / Parent Agent (`d148fd63-79de-4b7e-aef5-81ae3716f491`)  
**Primary Reference**: `D:\project\bendehara v2\.agents\explorer_survey_2\survey_ui_nav.md`  

---

## 1. Observation

1. **State Management & UI Framework**:
   - `pubspec.yaml` (lines 36-39):
     ```yaml
     cupertino_icons: ^1.0.8
     flutter_riverpod: ^3.4.3
     drift: ^2.35.0
     drift_flutter: ^0.3.1
     ```
   - `lib/main.dart` (lines 11-15):
     ```dart
     runApp(
       const ProviderScope(
         child: BendaharaApp(),
       ),
     );
     ```
   - Global reactive state is managed via `flutter_riverpod` (`StreamProvider`, `NotifierProvider`, `Provider`). Local widget ephemeral state uses `StatefulWidget` / `ConsumerState` with `setState`.

2. **Navigation & Tab Shell**:
   - `lib/presentation/screens/main_scaffold.dart` (lines 44-89):
     - `MainScaffold` manages 4 tabs using a `PageView` with `_KeepAlivePage`:
       - Index 0: `DashboardScreen(onNavigateTab: _navigateToTab)`
       - Index 1: `DuesCheckScreen(onBackToDashboard: () => _navigateToTab(0))`
       - Index 2: `TransactionFormScreen(initialType: 'expense', onBackToDashboard: () => _navigateToTab(0))`
       - Index 3: `SupervisionReportScreen(onBackToDashboard: () => _navigateToTab(0))`
     - Deep screen transitions utilize standard imperative `Navigator.of(context).push(MaterialPageRoute(...))`.

3. **Dashboard Recent Activity Defect (Requirement R2)**:
   - `lib/presentation/screens/dashboard_screen.dart` (lines 415-467):
     - Section title is `'Transaksi Terbaru'` with `TextButton` `'Lihat Semua'` navigating to tab index 3 (Laporan).
     - Renders recent transactions via:
       `...recentItems.take(5).map((item) => TransactionListItem(key: ValueKey(item.transaction.id), item: item))`
     - Data is supplied by `recentTransactionsProvider` in `lib/presentation/providers/app_providers.dart` (lines 60-66).
   - `lib/data/repositories/transaction_repository.dart` (lines 37-40):
     ```dart
     final query = (_db.select(_db.transactions)
           ..where((t) => t.academicYearId.equals(academicYearId))
           ..orderBy([(t) => OrderingTerm(expression: t.transactionDate, mode: OrderingMode.desc)])
           ..limit(limit))
     ```
     Observed that sorting is currently performed on `t.transactionDate DESC`, NOT `t.createdAt DESC`.
   - `lib/data/repositories/dues_repository.dart` (lines 386-418):
     - Dues reconciliations set `transactionDate` to `effectivePeriodDate` (which can be a past date, e.g. July 2026), but `createdAt` is `DateTime.now()`.
     - Because of `orderBy(t.transactionDate DESC)`, backdated transactions never appear at the top of the Dashboard.

4. **Timestamp Display in Transaction Item**:
   - `lib/presentation/widgets/transaction_list_item.dart` (lines 83-89 and 224-227):
     ```dart
     Text(
       DateFormatter.toHumanDate(tx.transactionDate),
       style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
     ),
     ```
     Only `tx.transactionDate` is displayed. `tx.createdAt` is omitted, obscuring whether a transaction was backdated.

5. **Reports Tab Structure & Navigation Trigger (Requirement R1)**:
   - `lib/presentation/screens/supervision_report_screen.dart`:
     - Implements the Reports tab (`SupervisionReportScreen`).
     - Section 5 (lines 512-590) displays `'Arus Kas Tercatat (${txItems.length} Transaksi)'`.
     - Capped at `_visibleTxCount = 10` with "Muat 10 Lagi" / "Semua" buttons.
     - Lacks a search bar, category chips, and dynamic mutation calculations.
     - Requires a dedicated navigation card/button: `"Lihat Semua Riwayat (N Transaksi) >"` opening `AllTransactionsScreen`.

6. **Baseline Health**:
   - Executed `flutter analyze`: Result was `No issues found! (ran in 2.6s)`.
   - Executed `flutter test`: Result was `00:06 +94: All tests passed!`.

---

## 2. Logic Chain

1. **R2 Root Cause & Solution**:
   - From Observation 3, when a treasurer enters backdated transactions, `tx.createdAt` is recent, but `tx.transactionDate` is old.
   - Because `TransactionRepository.watchRecentTransactions` sorts by `t.transactionDate DESC`, the entry is placed far down or completely excluded by the `LIMIT 5`.
   - Modifying the sort order to `OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)` in `watchRecentTransactions` directly guarantees that any newly entered transaction—regardless of its transaction date—will immediately appear at the top of Dashboard.
   - Changing the Dashboard section header from `'Transaksi Terbaru'` to `'Riwayat Pencatatan Terkini'` aligns user expectations with system input timestamps.
   - From Observation 4, updating `TransactionListItem` and `_TransactionDetailDialog` to compare `tx.transactionDate` with `tx.createdAt` and show both dates when they differ satisfies the requirement for transparency.

2. **R1 Navigation Trigger & Placement**:
   - From Observation 5, `SupervisionReportScreen` currently caps the list at 10 items and provides pagination buttons.
   - Placing a prominent banner/button (e.g. `"Lihat Semua Riwayat (${txItems.length} Transaksi) >"`) in Section 5 of `SupervisionReportScreen` provides the required navigation entry point.
   - Additionally, redirecting the `'Lihat Semua'` button in `DashboardScreen` to `AllTransactionsScreen` provides seamless navigation from both entry points.

3. **`AllTransactionsScreen` Architecture**:
   - To show all transactions without truncation, a new query `watchAllTransactions({required String academicYearId})` sorted by `transactionDate DESC` (or `createdAt DESC`) should be added to `TransactionRepository` and exposed via `allTransactionsProvider(yearId)` in `app_providers.dart`.
   - Local state in `AllTransactionsScreen` handles:
     - `_searchController` for real-time text matching against `tx.title` and `tx.description`.
     - `_selectedType` ('all', 'income', 'expense') and `_selectedCategoryId` for category chips.
     - Dynamic mutation summary: calculates `totalIncome`, `totalExpense`, and `netMutation = totalIncome - totalExpense` in real-time over the filtered subset.
     - Reuses `TransactionListItem` for list rows.

---

## 3. Caveats

- **Scope Boundary**: This investigation focused on the UI, Navigation, Dashboard, and Reports tab. PDF partitioning, red expense highlighting, student arrears audit sheets, and holiday dues rules belong to parallel domains (Domain Services & Dues Engine) and were not modified.
- **Assumptions**: We assume `AllTransactionsScreen` will be placed in `lib/presentation/screens/all_transactions_screen.dart` and push/popped via standard `Navigator.push(MaterialPageRoute(...))` to maintain consistency with `TransactionFormScreen`.
- No caveats regarding codebase health; all 94 baseline tests pass.

---

## 4. Conclusion

1. **Dashboard Update (R2)**:
   - Update `TransactionRepository.watchRecentTransactions` query in `lib/data/repositories/transaction_repository.dart` from `ORDER BY transactionDate DESC` to `ORDER BY createdAt DESC`.
   - Rename Dashboard section title to **"Riwayat Pencatatan Terkini"** in `lib/presentation/screens/dashboard_screen.dart`.
   - Add dual timestamp display in `TransactionListItem` and `_TransactionDetailDialog` when `transactionDate` differs from `createdAt`.
2. **Navigation Trigger (R1)**:
   - Add navigation card/button `"Lihat Semua Riwayat (${txItems.length} Transaksi) >"` to Section 5 in `lib/presentation/screens/supervision_report_screen.dart`.
   - Optionally update Dashboard `'Lihat Semua'` to also open `AllTransactionsScreen`.
3. **AllTransactionsScreen Implementation (R1)**:
   - Create `lib/presentation/screens/all_transactions_screen.dart`.
   - Implement real-time search, horizontal category chips (Semua, Kas Masuk, Kas Keluar, specific categories), dynamic mutation summary card, and full list rendering.
   - Add `watchAllTransactions` to `TransactionRepository` and `allTransactionsProvider` to `app_providers.dart`.

---

## 5. Verification Method

1. **Run Static Analysis**:
   ```powershell
   flutter analyze
   ```
   *Expected*: 0 issues found.

2. **Run Full Test Suite**:
   ```powershell
   flutter test
   ```
   *Expected*: 94 existing tests pass 100%.

3. **Verify Newly Proposed Tests**:
   - Test backdated transaction appears first on Dashboard when ordered by `createdAt DESC`.
   - Test `AllTransactionsScreen` search filtering by keyword in title/description.
   - Test `AllTransactionsScreen` category chip filtering.
   - Test `AllTransactionsScreen` dynamic mutation total updates live with search/chip filters.
   - Test navigation from `SupervisionReportScreen` and `DashboardScreen` opens `AllTransactionsScreen`.
