# Survey Report: UI Architecture, State Management, Navigation, Dashboard & Reports Tab

**Target Project**: Bendahara Kelas (Flutter v2)  
**Investigator**: Explorer Survey 2  
**Date**: 2026-09-20  
**Integrity Mode**: Development / Read-Only Investigation  

---

## 1. Executive Summary

This investigation explores the presentation layer, UI architecture, state management patterns, navigation flows, and database-to-UI reactive pipelines for the Bendahara Kelas Flutter application. Specifically, this survey analyzes:
1. The **UI Architecture & State Management** (`flutter_riverpod` v3.4.3 + Drift v2.35.0).
2. The **Dashboard screen** (`dashboard_screen.dart`) and the implementation of recent transaction cards to satisfy **Requirement R2** (*Riwayat Pencatatan Terkini* ordered by `createdAt DESC`).
3. The **Reports tab** (`supervision_report_screen.dart`) and the placement of the navigation trigger to open the dedicated full transaction screen (**Requirement R1**).
4. Detailed specifications and widget design for **`AllTransactionsScreen`**, including real-time search, category chip filtering, and dynamic mutation summary calculations.

---

## 2. UI Architecture & State Management

### 2.1 Layered Architecture
The project strictly follows a clean layered Flutter structure:
```
lib/
├── core/
│   ├── constants/
│   │   └── app_colors.dart            # Semantic color definitions (brandPrimary, incomeText, expenseText, etc.)
│   └── utils/
│       ├── currency_formatter.dart    # Rupiah currency parsing and formatting
│       └── date_formatter.dart        # Indonesian locale date and period parsing
├── data/
│   ├── database/
│   │   ├── app_database.dart          # Drift database class, migrations, indexes, seeding
│   │   └── tables/                    # Table definitions (academic_years, students, categories, transactions, etc.)
│   └── repositories/
│       ├── academic_year_repository.dart
│       ├── dues_repository.dart
│       ├── student_repository.dart
│       └── transaction_repository.dart# SQL queries, joined streams, balance statistics
├── domain/
│   └── services/                      # Business & export services (pdf_report_service, excel_report_service, etc.)
├── presentation/
│   ├── providers/
│   │   └── app_providers.dart         # Riverpod providers, streams, notifiers
│   ├── screens/
│   │   ├── main_scaffold.dart         # Root shell with PageView and BottomNavigationBar
│   │   ├── dashboard_screen.dart      # Tab 0: Dashboard
│   │   ├── dues_check_screen.dart     # Tab 1: Kas Siswa checklist & period reconciler
│   │   ├── transaction_form_screen.dart # Tab 2: Catat Transaksi
│   │   ├── supervision_report_screen.dart # Tab 3: Laporan
│   │   └── dialogs/                   # Modal dialogs (class setup, categories, backup/restore, students)
│   ├── theme/
│   │   └── app_theme.dart             # Material 3 light theme definition
│   └── widgets/
│       ├── dues_period_calendar_card.dart
│       ├── financial_chart_card.dart
│       └── transaction_list_item.dart # Reusable transaction tile with detail dialog
└── main.dart                          # App entry point, ProviderScope, Indonesian date formatting
```

### 2.2 State Management: Flutter Riverpod
- **Root ProviderScope**: Declared in `lib/main.dart` (lines 11-15):
  ```dart
  runApp(
    const ProviderScope(
      child: BendaharaApp(),
    ),
  );
  ```
- **Pattern**: A combination of:
  - **`StreamProvider` / `StreamProvider.family`**: For reactive data streams mapped from Drift database queries (e.g. `activeAcademicYearProvider`, `recentTransactionsProvider`, `balanceStatsProvider`, `categoriesStreamProvider`, `reportTransactionsProvider`).
  - **`NotifierProvider`**: For UI filter state that needs persistence across rebuilds (e.g., `periodOffsetProvider`, `selectedPeriodDateProvider`, `selectedReportRangeProvider`, `selectedReportYearIdProvider`).
  - **Widget-level `setState`**: For ephemeral UI state (e.g., form text editing controllers, local tab switching, dialog visibility).
- **Consumer Widgets**: Screens extend `ConsumerStatefulWidget` with `ConsumerState<T>`, accessing providers via `ref.watch()` for reactive rebuilds and `ref.read()` for one-off actions/notifiers.
- **Cache Invalidation**: Mutation actions invalidate affected stream providers via `ref.invalidate(balanceStatsProvider)`, `ref.invalidate(recentTransactionsProvider)`, etc.

### 2.3 Navigation Model
- **Main App Shell**: `MainScaffold` (`lib/presentation/screens/main_scaffold.dart`) manages the 4 primary tabs:
  - **Tab 0**: `DashboardScreen(onNavigateTab: _navigateToTab)`
  - **Tab 1**: `DuesCheckScreen(onBackToDashboard: () => _navigateToTab(0))`
  - **Tab 2**: `TransactionFormScreen(initialType: 'expense', onBackToDashboard: () => _navigateToTab(0))`
  - **Tab 3**: `SupervisionReportScreen(onBackToDashboard: () => _navigateToTab(0))`
- **Controller**: Managed by `PageController` with `_KeepAlivePage` (AutomaticKeepAliveClientMixin) so each tab maintains its scroll and interaction state.
- **Deep/Subscreen Navigation**: Standard imperative routing via `Navigator.of(context).push(MaterialPageRoute(...))`. Subscreens provide a back button (`IconButton(icon: Icon(Icons.arrow_back_rounded))`) that checks `Navigator.canPop(context)` or invokes `onBackToDashboard`.

---

## 3. Dashboard Screen & Recent Activity Cards

### 3.1 Location & Structure
- **File**: `lib/presentation/screens/dashboard_screen.dart`
- **Component Sections**:
  1. **Class Header Card** (lines 100-156): Active class name, school year, treasurer name, backup/restore & class edit dialog triggers.
  2. **Total Balance Card** (lines 160-280): Current class cash balance (`stats.totalBalance`), monthly income (`stats.monthlyIncome`), monthly expense (`stats.monthlyExpense`).
  3. **Quick Action Buttons** (lines 282-332): `+ Uang Masuk` (pushes `TransactionFormScreen`), `- Uang Keluar` (pushes `TransactionFormScreen`), `Centang Kas` (navigates to Tab 1).
  4. **Active Period Progress Card** (lines 335-412): Dues collection percentage, target vs collected, paid student count.
  5. **Recent Transactions Section** (lines 415-468):
     - Section Header:
       ```dart
       Row(
         mainAxisAlignment: MainAxisAlignment.spaceBetween,
         children: [
           const Text(
             'Transaksi Terbaru', // Needs update for R2
             style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
           ),
           TextButton(
             onPressed: () {
               if (widget.onNavigateTab != null) widget.onNavigateTab!(3); // Currently navigates to Tab 3 (Laporan)
             },
             child: const Text('Lihat Semua', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
           ),
         ],
       )
       ```
     - List rendering:
       ```dart
       if (recentItems.isEmpty)
         // Empty state box
       else
         ...recentItems.take(5).map((item) => TransactionListItem(key: ValueKey(item.transaction.id), item: item)),
       ```

### 3.2 Current Data Pipeline & Sorting (Defect for R2)
- In `lib/presentation/providers/app_providers.dart` (lines 60-66):
  ```dart
  final recentTransactionsProvider = StreamProvider<List<TransactionWithCategory>>((ref) {
    final activeYear = ref.watch(activeAcademicYearProvider).value;
    if (activeYear == null) return Stream.value([]);
    return ref.watch(transactionRepoProvider).watchRecentTransactions(academicYearId: activeYear.id, limit: 5);
  });
  ```
- In `lib/data/repositories/transaction_repository.dart` (lines 33-40):
  ```dart
  Stream<List<TransactionWithCategory>> watchRecentTransactions({
    required String academicYearId,
    int limit = 5,
  }) {
    final query = (_db.select(_db.transactions)
          ..where((t) => t.academicYearId.equals(academicYearId))
          ..orderBy([(t) => OrderingTerm(expression: t.transactionDate, mode: OrderingMode.desc)]) // <-- DEFECT: orders by transactionDate, NOT createdAt!
          ..limit(limit))
        .join([
      innerJoin(_db.categories, _db.categories.id.equalsExp(_db.transactions.categoryId)),
      innerJoin(_db.academicYears, _db.academicYears.id.equalsExp(_db.transactions.academicYearId)),
    ]);
    ...
  ```

### 3.3 The Backdating Issue (Requirement R2)
- When dues are recorded in `DuesRepository.reconcileIntoGeneralCash` (`dues_repository.dart:386-418`):
  `transactionDate` is set to the date of the dues period (`effectivePeriodDate`), while `createdAt` is `DateTime.now()`.
- If a treasurer enters dues for an earlier period (e.g. July 2026 recorded in September 2026), its `transactionDate` is in July.
- Because `watchRecentTransactions` sorts by `t.transactionDate DESC`, the newly recorded backdated transaction is buried under newer transaction dates and **never appears** in the Dashboard's top 5 recent items!
- **Requirement R2 Fix**:
  1. Change `watchRecentTransactions` SQL query sorting to:
     ```dart
     ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)])
     ```
  2. Update section header text in `dashboard_screen.dart` from `'Transaksi Terbaru'` to **`'Riwayat Pencatatan Terkini'`** (with subtitle or tooltip indicating sorting by system input time).
  3. Ensure transparent display of both transaction date and recording timestamp when different (see section 3.4).

### 3.4 Formatting & Displaying Dates and Timestamps
- Reusable item tile: `TransactionListItem` (`lib/presentation/widgets/transaction_list_item.dart`).
- Currently displays:
  - `DateFormatter.toHumanDate(tx.transactionDate)` (e.g. `14 September 2026`).
  - `item.category.name`.
  - `tx.receiptImagePath` badge ('Ada Nota').
  - Detail dialog: `DateFormatter.toHumanDateTime(tx.transactionDate)` (e.g. `14 Sep 2026, 14:30`).
- **To satisfy R2 (Transparent Date Differences)**:
  - Compare `tx.transactionDate` and `tx.createdAt` (e.g., date parts differ by more than 24 hours):
    ```dart
    final isBackdated = tx.transactionDate.year != tx.createdAt.year ||
        tx.transactionDate.month != tx.createdAt.month ||
        tx.transactionDate.day != tx.createdAt.day;
    ```
  - In `TransactionListItem`: If `isBackdated`, display both dates or a subtle badge/indicator:
    - E.g. Subtitle: `DateFormatter.toShortDate(tx.transactionDate) • Dicatat: ${DateFormatter.toShortDate(tx.createdAt)}`
    - In `_TransactionDetailDialog`:
      - `Tanggal Transaksi Fisik: [DateFormatter.toHumanDateTime(tx.transactionDate)]`
      - `Waktu Pencatatan Sistem: [DateFormatter.toHumanDateTime(tx.createdAt)]`
      - If `isBackdated`, show a highlight chip: `Pencatatan Kas Mundur (Backdated)`.

---

## 4. Reports Tab & Navigation to AllTransactionsScreen

### 4.1 Location & Structure
- **File**: `lib/presentation/screens/supervision_report_screen.dart`
- **Class**: `SupervisionReportScreen` (Stateful Consumer Widget).
- **Component Sections**:
  1. **Header Supervisi** (lines 277-330): Title "Pusat Laporan Kas dan Ekspor" and subtitle.
  2. **Academic Year Selector** (lines 333-375): Dropdown when multiple academic years exist.
  3. **Filter Bar Rentang Waktu** (lines 378-413): 1 Bulan, 3 Bulan, 1 Tahun, Semua Tahun (`selectedReportRangeProvider`).
  4. **Ringkasan Audit Keuangan** (lines 415-464): Total Masuk, Total Keluar, Sisa Saldo for the selected range.
  5. **Grafik Analisis Keuangan** (lines 468-473): `FinancialChartCard` showing bar chart by week/month and category breakdown.
  6. **Tombol Aksi Utama Ekspor** (lines 476-509):
     - "Bagikan Laporan PDF ke WhatsApp"
     - "Pratinjau PDF"
     - "Ekspor Excel"
  7. **Daftar Transaksi pada Rentang Ini** (lines 512-590):
     - Currently caps items to `_visibleTxCount = 10`.
     - Has "Muat 10 Lagi" and "Semua" buttons.
     - Does NOT have search, does NOT have category chip filtering, does NOT calculate dynamic mutation summaries based on search.

### 4.2 Optimal Placement for Navigation Button
Under **Requirement R1**:
> *"Menyediakan tombol navigasi jelas pada tab Laporan (misalnya 'Lihat Semua Riwayat (N Transaksi) >') untuk membuka halaman khusus baru (`AllTransactionsScreen`)."*

There are two clean and complementary places to put the trigger:
1. **Prominent Navigation Card / Button in Section 5 of `SupervisionReportScreen`**:
   - Right above the transaction list in `SupervisionReportScreen` (around line 512):
     ```dart
     Container(
       margin: const EdgeInsets.symmetric(vertical: 8),
       child: InkWell(
         onTap: () {
           Navigator.of(context).push(
             MaterialPageRoute(
               builder: (_) => AllTransactionsScreen(academicYear: displayYear),
             ),
           );
         },
         borderRadius: BorderRadius.circular(10),
         child: Container(
           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
           decoration: BoxDecoration(
             color: AppColors.blueLight,
             borderRadius: BorderRadius.circular(10),
             border: Border.all(color: AppColors.borderSubtle),
           ),
           child: Row(
             children: [
               const Icon(Icons.manage_search_rounded, color: AppColors.brandPrimary, size: 22),
               const SizedBox(width: 12),
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(
                       'Buka Semua Riwayat Transaksi (${txItems.length} Transaksi)',
                       style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.brandPrimaryDark),
                     ),
                     const Text(
                       'Cari berdasarkan judul, filter kategori, dan lihat ringkasan',
                       style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                     ),
                   ],
                 ),
               ),
               const Icon(Icons.chevron_right_rounded, color: AppColors.brandPrimary),
             ],
           ),
         ),
       ),
     )
     ```
   - Alternatively / in addition, the "Semua" button or section header trailing can link directly.
2. **Dashboard "Lihat Semua" Link**:
   - In `dashboard_screen.dart` (line 427), the `TextButton` currently switches tab to Tab 3.
   - It can be updated to directly push `AllTransactionsScreen(academicYear: activeYear)` so the user gets immediate access to the full history from Dashboard as well as from Laporan.

### 4.3 Reusable Widgets
- `TransactionListItem` (`lib/presentation/widgets/transaction_list_item.dart`): Reused directly in `AllTransactionsScreen` to display each filtered transaction row.
- `_TransactionDetailDialog`: Already built into `TransactionListItem`, providing details, categories, descriptions, and receipt image viewer.
- `CurrencyFormatter` and `DateFormatter`: Standardized utils for currency formatting and dates.

---

## 5. Requirements & Technical Specification for `AllTransactionsScreen`

### 5.1 File Path & Screen Definition
- **Proposed File**: `lib/presentation/screens/all_transactions_screen.dart`
- **Class**: `AllTransactionsScreen extends ConsumerStatefulWidget`
- **Props**:
  - `final AcademicYear academicYear;`
  - Optional initial search query or category filter.

### 5.2 Data Sourcing & Reactive Provider
To support viewing all transactions without range limitation:
- In `TransactionRepository` (`lib/data/repositories/transaction_repository.dart`):
  Add `watchAllTransactions`:
  ```dart
  Stream<List<TransactionWithCategory>> watchAllTransactions({
    required String academicYearId,
  }) {
    final query = (_db.select(_db.transactions)
          ..where((t) => t.academicYearId.equals(academicYearId))
          ..orderBy([(t) => OrderingTerm(expression: t.transactionDate, mode: OrderingMode.desc)]))
        .join([
      innerJoin(_db.categories, _db.categories.id.equalsExp(_db.transactions.categoryId)),
      innerJoin(_db.academicYears, _db.academicYears.id.equalsExp(_db.transactions.academicYearId)),
    ]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return TransactionWithCategory(
          transaction: row.readTable(_db.transactions),
          category: row.readTable(_db.categories),
          academicYear: row.readTable(_db.academicYears),
        );
      }).toList();
    });
  }
  ```
- In `app_providers.dart`:
  ```dart
  final allTransactionsProvider = StreamProvider.family<List<TransactionWithCategory>, String>((ref, yearId) {
    return ref.watch(transactionRepoProvider).watchAllTransactions(academicYearId: yearId);
  });
  ```

### 5.3 Real-Time Search Bar
- **Input Field**:
  - Controller: `TextEditingController _searchController`
  - Hint text: `"Cari transaksi (judul atau keterangan)..."`
  - Leading: `Icon(Icons.search_rounded, color: AppColors.textSecondary)`
  - Trailing: If `_searchController.text.isNotEmpty`, show `IconButton(icon: Icon(Icons.clear), onPressed: () => setState(() => _searchController.clear()))`
  - Behavior: `onChanged: (val) => setState(() {})` triggers real-time filtering.
- **Search Matching Logic**:
  ```dart
  final query = _searchController.text.trim().toLowerCase();
  final matchesSearch = query.isEmpty ||
      tx.title.toLowerCase().contains(query) ||
      (tx.description != null && tx.description!.toLowerCase().contains(query));
  ```

### 5.4 Category & Type Filter Chips
- **Requirements**:
  - "Filter chip kategori (Semua, Kas Masuk, Kas Keluar, atau per kategori spesifik)."
- **Filter State Model**:
  ```dart
  enum TransactionFilterType { all, income, expense }
  // Either a type-based filter or a specific category filter
  String? _selectedCategoryId; // null = all categories
  TransactionFilterType _selectedType = TransactionFilterType.all;
  ```
- **UI Presentation**:
  - Horizontal scrolling row (`SingleChildScrollView(scrollDirection: Axis.horizontal)`) with `ChoiceChip`s:
    1. **"Semua"**: `_selectedType == TransactionFilterType.all && _selectedCategoryId == null`
    2. **"Kas Masuk"**: `_selectedType == TransactionFilterType.income && _selectedCategoryId == null`
    3. **"Kas Keluar"**: `_selectedType == TransactionFilterType.expense && _selectedCategoryId == null`
    4. **Per Kategori Spesifik**: List of category chips fetched from `categoriesStreamProvider` or derived from the transaction dataset:
       - Clicking a category sets `_selectedCategoryId = cat.id` and synchronizes `_selectedType = (cat.type == 'income' ? TransactionFilterType.income : TransactionFilterType.expense)`.
       - Selecting "Semua" clears `_selectedCategoryId` and resets `_selectedType` to `.all`.

### 5.5 Dynamic Total Mutations Summary Calculation
- **Calculation over Filtered Set**:
  As the user types in the search bar or selects different filter chips, the filtered list `filteredItems` is computed.
  From `filteredItems`, calculate:
  ```dart
  int totalFilteredIncome = 0;
  int totalFilteredExpense = 0;
  for (final item in filteredItems) {
    if (item.transaction.type == 'income') {
      totalFilteredIncome += item.transaction.amount;
    } else {
      totalFilteredExpense += item.transaction.amount;
    }
  }
  final netMutation = totalFilteredIncome - totalFilteredExpense;
  ```
- **Visual Card UI**:
  - Renders a clean summary container at the top of the list (below search and chips):
    - **Header**: `'Ringkasan Mutasi (${filteredItems.length} Transaksi)'`
    - 3 metric tiles:
      - **Masuk**: `+${CurrencyFormatter.format(totalFilteredIncome)}` (Green `AppColors.incomeText`)
      - **Keluar**: `-${CurrencyFormatter.format(totalFilteredExpense)}` (Red `AppColors.expenseText`)
      - **Selisih**: `${netMutation >= 0 ? '+' : '-'}${CurrencyFormatter.format(netMutation.abs())}`
        - Color: Green if >= 0, Red if < 0.

### 5.6 Full Widget Tree for AllTransactionsScreen
```
Scaffold
├── AppBar
│   ├── leading: BackButton (pop)
│   ├── title: "Semua Riwayat Transaksi"
│   └── subtitle / tooltip: "${academicYear.name}"
└── body: SafeArea
    └── Column
        ├── 1. Search Bar Container (TextField with search icon & clear button)
        ├── 2. Filter Chips Row (Semua, Kas Masuk, Kas Keluar, + individual categories)
        ├── 3. Dynamic Mutation Summary Card (Total Masuk, Total Keluar, Net Selisih, Filtered Count)
        └── 4. Expanded ListView
            ├── If empty: Empty State Card ("Tidak ada transaksi yang cocok")
            └── If items: ListView.builder rendering TransactionListItem for each item
```

---

## 6. Code & Widget Traceability Matrix

| File Path | Relevant Lines | Component / Function | Survey Finding & Action Needed |
|:---|:---|:---|:---|
| `lib/presentation/screens/dashboard_screen.dart` | 415-468 | `_DashboardScreenState.build` | Section title is `'Transaksi Terbaru'`. Needs to be updated to `'Riwayat Pencatatan Terkini'`. "Lihat Semua" button can navigate to `AllTransactionsScreen`. |
| `lib/presentation/widgets/transaction_list_item.dart` | 83-124, 224-228 | `TransactionListItem` & `_TransactionDetailDialog` | Currently only renders `tx.transactionDate`. Needs to display both `transactionDate` and `createdAt` when they differ to expose backdated recordings transparently. |
| `lib/data/repositories/transaction_repository.dart` | 33-55 | `watchRecentTransactions` | Currently sorts by `t.transactionDate DESC`. Must be updated to sort by `t.createdAt DESC`. Add `watchAllTransactions`. |
| `lib/presentation/providers/app_providers.dart` | 60-66 | `recentTransactionsProvider` | Feeds recent 5 items to Dashboard. Add `allTransactionsProvider` family stream. |
| `lib/presentation/screens/supervision_report_screen.dart` | 512-590 | Section 5: Daftar Transaksi | Currently caps to 10 items. Needs clear navigation button/banner: *"Lihat Semua Riwayat (N Transaksi) >"* opening `AllTransactionsScreen`. |
| `lib/presentation/screens/all_transactions_screen.dart` | NEW | `AllTransactionsScreen` | Create new screen with search bar, category chips, dynamic mutation summary, and full list. |
| `lib/core/utils/date_formatter.dart` | 6-16 | `DateFormatter` | Already contains `toHumanDate`, `toShortDate`, `toHumanDateTime`. Usable directly for dual timestamp display. |
| `lib/core/utils/currency_formatter.dart` | 1-20 | `CurrencyFormatter` | Standard Rupiah formatter for summary calculations. |
| `lib/data/database/tables/transactions.dart` | 14-16 | `Transactions` table | Contains `transactionDate`, `createdAt`, `updatedAt`. All required timestamps already exist in schema. |

---

## 7. Verification Method & Commands

1. **Static Analysis**:
   ```bash
   flutter analyze
   ```
   Must yield 0 errors and 0 warnings.

2. **Existing Test Suite Verification**:
   ```bash
   flutter test
   ```
   All existing tests in `test/` must pass 100%.

3. **New Tests Needed for R1 & R2**:
   - `test/all_transactions_screen_test.dart`:
     - Test search bar filtering by keyword in title.
     - Test search bar filtering by keyword in description.
     - Test category chip selection (All, Kas Masuk, Kas Keluar, specific category).
     - Test dynamic summary calculation matches filtered subset.
     - Test navigation button in `SupervisionReportScreen` opens `AllTransactionsScreen`.
   - `test/recent_recording_activity_test.dart`:
     - Insert a past-dated transaction (e.g. `transactionDate = 2 months ago`, `createdAt = now`).
     - Insert an older-created transaction with a newer `transactionDate`.
     - Verify `recentTransactionsProvider` / `watchRecentTransactions` returns the past-dated transaction first because `createdAt` is newest.
     - Verify `TransactionListItem` displays transparent date information for backdated transactions.
