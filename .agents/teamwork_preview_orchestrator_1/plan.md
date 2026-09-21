# Orchestration Master Plan: Bendahara Kelas

## Overview
Orchestrate end-to-end implementation and verification of all 5 core requirements from `ORIGINAL_REQUEST.md`:
1. R1: `AllTransactionsScreen` with search, category filtering chips, dynamic summary, linked from Reports tab.
2. R2: Dashboard recent recording activity ordered by `createdAt DESC` with transparent indication of transaction date != input date.
3. R3: Monthly-partitioned PDF report with month header dividers and visually highlighted red expense rows.
4. R4: Dedicated student dues arrears audit sheet/section in PDF with unpaid periods, dues rate, student amounts, and summary.
5. R5: Activity-driven holiday rule for daily dues (weekends excluded; weekdays with 0 collections treated as holidays; class general transactions 100% active).
6. Quality & Delivery: `flutter analyze` clean (0 errors/warnings), 100% tests passing, release APK compiled with bumped `versionCode`.

## Phase Plan
- **Phase 0: Survey & Mapping (Current)**
  - Spawn 3 Explorers to survey Database/Models, UI/State/Navigation, and PDF/Testing/Build systems.
  - Synthesize findings into `PROJECT.md` (Architecture, Feature Inventory, Milestones, Interface Contracts, Code Layout).
- **Phase 1: Milestone Decomposition & Track Setup**
  - Implementation Track:
    - Milestone 1 (M1): Database & Core Logic (createdAt ordering, holiday/weekend dues calculation rules) [R2, R5]
    - Milestone 2 (M2): UI Screens & Navigation (AllTransactionsScreen, search/filter/summary, Dashboard activity card) [R1, R2]
    - Milestone 3 (M3): PDF Reporting Enhancements (Monthly partitioning, red expense highlights, student arrears audit section) [R3, R4]
  - E2E / Unit Testing Track:
    - Dedicated test harness & test suite covering R1-R5 across Tiers 1-4.
- **Phase 2: Milestone Iterations (Explorer -> Worker -> Reviewer -> Challenger -> Auditor -> Gate)**
  - Execute M1, M2, M3 in dependency order.
  - Enforce binary veto on Forensic Auditor integrity checks.
- **Phase 3: Final Verification & Release Build**
  - Execute all tests (`flutter test`), static analysis (`flutter analyze`), and compile release APK with bumped versionCode.
  - Final Gate approval and Sentinel completion report.
