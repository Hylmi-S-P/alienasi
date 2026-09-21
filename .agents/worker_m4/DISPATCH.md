# Dispatch for Worker Milestone 4

## Mission
Implement Milestone 4: Comprehensive E2E Testing, Static Analysis Verification, and Release APK Compilation (Features F14, F15).

## Mandatory Reference
Read `D:\project\bendehara v2\.agents\ORIGINAL_REQUEST.md` completely before starting.

## Mandatory Integrity Warning
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

## Context & Inputs
- Authoritative Request: `D:\project\bendehara v2\.agents\ORIGINAL_REQUEST.md`
- Project Scope: `D:\project\bendehara v2\PROJECT.md`
- Test Infrastructure: `D:\project\bendehara v2\TEST_INFRA.md`
- Working Directory: `D:\project\bendehara v2\.agents\worker_m4`

## File Ownership
You exclusively own and can modify or create:
- `pubspec.yaml`
- `test/e2e/e2e_full_acceptance_test.dart` (new file)
- `Bendahara-Kelas-Release.apk` (at project root)

DO NOT modify files outside this list in this milestone.

## Detailed Requirements
1. **Comprehensive End-to-End Acceptance Test (`test/e2e/e2e_full_acceptance_test.dart`)**:
   - Write comprehensive tests validating all 5 requirements from `ORIGINAL_REQUEST.md`:
     - **R1 Acceptance**: `AllTransactionsScreen` uncapped, search bar filtering by title/description, category choice chips, dynamic mutation summary recalculations, and navigation link from `SupervisionReportScreen` Section 5.
     - **R2 Acceptance**: Dashboard recent recording activity ordered strictly by `createdAt DESC` so backdated transactions surface on top, with dual timestamp and backdated indication when `transactionDate != createdAt`.
     - **R3 Acceptance**: `PdfReportService` divides transactions by month with clear subheaders (`BULAN JULI 2026`, etc.) and formats expense cells with red font (`#DC2626`) and background tint (`#FEF2F2`).
     - **R4 Acceptance**: PDF generates dedicated `REKAPITULASI TUNGGAKAN KAS SISWA` audit section showing unpaid period ranges, active dues rate, individual debt amounts, and grand total uncollected summary row (or verified "Nihil Tunggakan" badge).
     - **R5 Acceptance**: Daily dues strictly exclude Saturdays and Sundays from billing/arrears; weekdays with 0 collections are treated as holidays without debt; weekdays with $\ge 1$ payment are effective dues days; general class cash transactions (incomes & expenses) are 100% active anytime on any day.
2. **Version Bump in `pubspec.yaml`**:
   - In `pubspec.yaml`, increment `version: 1.0.2+3` to `version: 1.0.3+4` (incrementing `versionCode` to 4 for seamless in-place APK installation).
3. **Compile Release APK**:
   - Execute:
     ```powershell
     flutter build apk --release
     Copy-Item -Path "build\app\outputs\flutter-apk\app-release.apk" -Destination "Bendahara-Kelas-Release.apk" -Force
     ```
   - Verify `Bendahara-Kelas-Release.apk` exists at `D:\project\bendehara v2\Bendahara-Kelas-Release.apk`, inspect its file length, and verify write timestamp.
4. **Quality Gates Verification**:
   - Execute `flutter analyze`: Must have 0 errors, 0 warnings, 0 lints.
   - Execute `flutter test`: 100% of all tests in the project must pass.

## Output
Write `changes.md` and `handoff.md` in `D:\project\bendehara v2\.agents\worker_m4\` and report back via message.

## 2026-09-20T14:19:00Z
<USER_REQUEST>
You are Worker M4 implementing Milestone 4: Comprehensive E2E Testing & Release APK Compilation for Bendahara Kelas.
Working directory: D:\project\bendehara v2\.agents\worker_m4

MANDATORY FIRST STEP: Read D:\project\bendehara v2\.agents\ORIGINAL_REQUEST.md completely.
Then read your detailed task assignment in D:\project\bendehara v2\.agents\worker_m4\DISPATCH.md.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Implement:
1. Comprehensive E2E acceptance tests in test/e2e/e2e_full_acceptance_test.dart covering all 5 core requirements (R1, R2, R3, R4, R5) end-to-end.
2. In pubspec.yaml, increment version to 1.0.3+4 (versionCode: 4) for seamless in-place APK installation.
3. Compile release APK:
   flutter build apk --release
   Copy-Item -Path "build\app\outputs\flutter-apk\app-release.apk" -Destination "Bendahara-Kelas-Release.apk" -Force
   Verify file size and timestamp of Bendahara-Kelas-Release.apk.
4. Run flutter analyze (0 errors, 0 warnings) and flutter test (100% pass across all tests).

Write your changes to D:\project\bendehara v2\.agents\worker_m4\changes.md and write a complete handoff report to D:\project\bendehara v2\.agents\worker_m4\handoff.md.
Send message to parent when complete.
</USER_REQUEST>

