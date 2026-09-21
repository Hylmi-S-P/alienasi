# E2E Test Infra: Bendahara Kelas

## Test Philosophy
- Opaque-box and requirement-driven testing directly derived from `ORIGINAL_REQUEST.md`.
- Methodology: Category-Partition + Boundary Value Analysis + Pairwise Interaction + Real-World School Treasury Scenarios.
- Zero-tolerance regression guard: all existing 94 tests must remain passing at 100%.

## Feature Inventory & Test Coverage Goals
| # | Feature | Requirement | Tier 1 (Unit/Feature) | Tier 2 (Boundary/Edge) | Tier 3 (Pairwise/Combo) | Tier 4 (Workload) |
|---|---------|-------------|:---------------------:|:----------------------:|:-----------------------:|:-----------------:|
| 1 | AllTransactionsScreen Search | R1 | >=5 cases | >=5 cases | Pairwise with category chips | Realistic query flows |
| 2 | Category Chips & Filter | R1 | >=5 cases | >=5 cases | Pairwise with search query | Multi-category filtering |
| 3 | Dynamic Mutation Summary Card | R1 | >=5 cases | >=5 cases | Pairwise with search/filter | Mixed income/expense tallies |
| 4 | Navigation Trigger to Full History | R1 | >=5 cases | >=5 cases | Pairwise with tab routing | Report tab & Dashboard flows |
| 5 | Dashboard Recent Activity Sorting | R2 | >=5 cases | >=5 cases | Pairwise with backdated tx | Multiple backdated reconciliations |
| 6 | Dual Timestamp Display | R2 | >=5 cases | >=5 cases | Pairwise with tx types | Same date vs different date displays |
| 7 | Monthly Partitioned PDF Reports | R3 | >=5 cases | >=5 cases | Pairwise with multi-year tx | 6-month semester treasury report |
| 8 | Red Highlighted PDF Expense Rows | R3 | >=5 cases | >=5 cases | Pairwise with income rows | Mixed ledger audit check |
| 9 | Student Dues Arrears Audit in PDF | R4 | >=5 cases | >=5 cases | Pairwise with zero arrears | Full classroom arrears breakdown |
| 10 | Daily Dues Weekend Exclusion | R5 | >=5 cases | >=5 cases | Pairwise with weekly dues | Saturday & Sunday zero-debt checks |
| 11 | Daily Dues Activity Holiday Rule | R5 | >=5 cases | >=5 cases | Pairwise with partial payments | Mon-Fri 0 payments vs >=1 payment |
| 12 | Unrestricted General Transactions | R5 | >=5 cases | >=5 cases | Pairwise with holiday dates | Weekend expense & donation recording |

## Test Architecture
- Test Framework: Flutter test framework (`testWidgets`, `test`), `drift/native` in-memory database for isolated hermetic state, and Riverpod `ProviderContainer`.
- Test Directory Layout:
  - `test/unit/`: Domain logic tests (`dues_arrears_service_test.dart`, `transaction_repository_sort_test.dart`).
  - `test/widget/`: UI component tests (`all_transactions_screen_test.dart`, `dashboard_recent_activity_test.dart`, `transaction_list_item_timestamp_test.dart`).
  - `test/e2e/`: End-to-end integration and scenario tests (`e2e_financial_report_flow_test.dart`, `e2e_daily_dues_holiday_rules_test.dart`).

## Real-World Application Scenarios (Tier 4)
1. **Scenario A (Semester Treasury Audit)**: A class treasurer inputs backdated transactions for July and August while standing in September. Dashboard immediately displays the newly recorded items on top with clear dual-timestamp indications.
2. **Scenario B (Daily Dues with School Holidays & Weekends)**: A class has daily dues. Across a 2-week period containing weekends, national holidays (0 students collected), and active school days (partial students collected), the system accurately computes arrears only for active weekdays and completely ignores weekends and zero-collection days.
3. **Scenario C (Comprehensive Multi-Month PDF Statement Export)**: The treasurer exports a 3-month PDF report. The table cleanly splits with calendar month subheaders (`BULAN JULI 2026`, `BULAN AGUSTUS 2026`, `BULAN SEPTEMBER 2026`), renders expense rows in clear contrast red font, and includes a dedicated Student Dues Arrears Audit page detailing each debtor's unpaid range and amount.
4. **Scenario D (General Weekend Expense & Bazar Income)**: On a Sunday, the class participates in a school bazaar (earns cash income) and buys snacks (cash expense). The transactions are logged normally on Sunday, 100% reflected in the balance, without affecting daily dues rules.
5. **Scenario E (Search & Filter Reconciliation)**: In `AllTransactionsScreen`, the treasurer filters by "Kas Keluar", types "Konsumsi", and immediately views the filtered rows with real-time dynamic total mutation summary recalculations.

## Coverage Thresholds
- Tier 1: >=5 per feature
- Tier 2: >=5 per feature
- Tier 3: Pairwise coverage of major feature interactions
- Tier 4: >=5 realistic application scenarios
- All 94 existing baseline tests must continue passing.
