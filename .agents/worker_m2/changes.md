# Technical Changes — Milestone 2: UI Screens & Navigation

**Worker**: Worker M2  
**Date**: 2026-09-20  
**Status**: Completed & Verified  

---

## 1. Summary of Changes

Milestone 2 implements the dedicated full transaction history screen (`AllTransactionsScreen`), real-time search and filtering, live dynamic mutation summaries, navigation entry points from both the Reports and Dashboard tabs, renamed Dashboard recent activity section to "Riwayat Pencatatan Terkini", transparent dual timestamps for backdated entries, and comprehensive widget tests.

---

## 2. Modified & Created Files

### 2.1 `lib/presentation/providers/app_providers.dart`
- Added `allTransactionsProvider`: Reactive `StreamProvider<List<TransactionWithCategory>>` querying `watchAllTransactions(academicYearId: activeYear.id)`.
- Added `allTransactionsByYearProvider`: Family `StreamProvider` accepting `yearId` for inspecting specific academic years.
- Added `categoriesProvider`: Unified stream combining income and expense categories.

### 2.2 `lib/presentation/screens/all_transactions_screen.dart` (NEW FILE)
- Created `AllTransactionsScreen` (`ConsumerStatefulWidget`):
  - **Search Bar**: Real-time filtering against `item.transaction.title` and `item.transaction.description` (case-insensitive) with clear text button.
  - **Horizontal Choice Chips**: SingleChildScrollView row featuring:
    - `"Semua"`
    - `"Kas Masuk"`
    - `"Kas Keluar"`
    - Individual category chips dynamically adapted to the active transaction type filter.
  - **Live Dynamic Mutations Summary Card**: Computes in single pass:
    - Total Masuk (`+Rp ...`)
    - Total Keluar (`-Rp ...`)
    - Selisih Bersih / Net (`+Rp ...` or `-Rp ...`)
    - Filtered vs Total transaction count (`N dari M Transaksi`).
  - **Full List**: Uncapped `ListView.builder` rendering `TransactionListItem` for all matching transactions.
  - **Empty State**: Displays `Icons.search_off_rounded`, friendly guidance text, and a `"Reset Filter"` button when no transactions match.
  - **RefreshIndicator**: Supports pull-to-refresh to invalidate riverpod streams.

### 2.3 `lib/presentation/screens/supervision_report_screen.dart`
- Added import for `all_transactions_screen.dart`.
- Added prominent navigation card in Section 5:
  `"Lihat Semua Riwayat (${txItems.length} Transaksi) >"` with search icon and chevron, navigating directly via `Navigator.of(context).push(MaterialPageRoute(builder: (_) => AllTransactionsScreen(academicYear: displayYear)))`.

### 2.4 `lib/presentation/screens/dashboard_screen.dart`
- Added import for `all_transactions_screen.dart`.
- Renamed recent activity section header from `"Transaksi Terbaru"` to **`"Riwayat Pencatatan Terkini"`**.
- Updated `"Lihat Semua"` button callback to navigate to `AllTransactionsScreen(academicYear: activeYear)`.
- Wrapped header text in `Expanded` to ensure overflow-safe responsive layout across varied screen resolutions and DPIs.

### 2.5 `lib/presentation/widgets/transaction_list_item.dart`
- Added check `isBackdated = !DateUtils.isSameDay(tx.transactionDate, tx.createdAt)`.
- Replaced rigid `Row` with flexible `Wrap` in list tile subtitle:
  - If backdated: Transparently displays `Tanggal: <DateFormatter.toHumanDate(tx.transactionDate)> • Dicatat: <DateFormatter.toHumanDate(tx.createdAt)>` and a subtle amber `"Mundur"` badge.
  - If same day: Displays standard single `DateFormatter.toHumanDate(tx.transactionDate)`.
- Updated `_TransactionDetailDialog`:
  - If backdated: Displays separate rows for `"Tanggal Transaksi"` (physical date) and `"Waktu Pencatatan"` (system timestamp), accompanied by a `"Pencatatan Kas Mundur (Backdated)"` status banner.
  - If same day: Displays standard `"Tanggal"`.

### 2.6 `test/widget/all_transactions_screen_test.dart` (NEW FILE)
Authored 6 comprehensive widget tests:
1. `Displays full list without 10-item cap (15 transactions rendered)`
2. `Search bar filters by title & description in real time with clear button`
3. `Horizontal category choice chips filter by type and specific category`
4. `Dynamic mutations summary card updates live on filtering`
5. `Displays clean empty state and Reset Filter button works`
6. `SupervisionReportScreen Section 5 banner navigates to AllTransactionsScreen`

### 2.7 `test/widget/dashboard_recent_activity_test.dart` (NEW FILE)
Authored 4 comprehensive widget tests:
1. `Section header is renamed to "Riwayat Pencatatan Terkini"`
2. `Tapping "Lihat Semua" in Dashboard navigates to AllTransactionsScreen`
3. `Backdated transaction appears at the top due to createdAt DESC sorting`
4. `Dual timestamp display shows both dates & Mundur badge on backdated transactions`

---

## 3. Verification Commands & Results

- **Static Analysis**:
  ```powershell
  flutter analyze
  ```
  Result: `No issues found! (ran in 2.1s)` — 0 errors, 0 warnings.

- **Automated Test Suite**:
  ```powershell
  flutter test
  ```
  Result: `155/155 tests passed (100%)`.
