# Dispatch for Worker M3 Remediation (`worker_m3_fix`)

## Mission
Remediate the critical `PdfTooBigPageException` pagination defect in `PdfReportService` when student arrears reach $\ge 25-30$ students.

## Inputs & Reports
- Authoritative Request: `D:\project\bendehara v2\.agents\ORIGINAL_REQUEST.md` (MANDATORY: read this first)
- Project Scope: `D:\project\bendehara v2\PROJECT.md`
- Gate Status & Feedback: `D:\project\bendehara v2\.agents\teamwork_preview_orchestrator_1\GATE_STATUS.md`
- Reviewer 1 Findings: `D:\project\bendehara v2\.agents\reviewer_m3_1\handoff.md`
- Reviewer 2 Findings: `D:\project\bendehara v2\.agents\reviewer_m3_2\handoff.md`
- Challenger 1 Findings: `D:\project\bendehara v2\.agents\challenger_m3_1\handoff.md`
- Challenger 2 Findings: `D:\project\bendehara v2\.agents\challenger_m3_2\handoff.md`
- Working Directory: `D:\project\bendehara v2\.agents\worker_m3_fix`

## Mandatory Integrity Warning
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

## Defects to Remediate
1. **`lib/domain/services/pdf_report_service.dart`**:
   - `buildArrearsAuditSection` currently returns a single `pw.Column` enclosing the audit table. In `package:pdf`, `pw.Column` is rigid and cannot split across pages. When an Indonesian classroom has 25 or more students in arrears (standard class size 32–36 students), the column exceeds single-page height, triggering an infinite page loop in `MultiPage` and crashing with `PdfTooBigPageException: This widget created more than 20 pages`.
   - **Fix**:
     - Change `buildArrearsAuditSection` to return `List<pw.Widget>` instead of `pw.Widget` (exactly like `buildTransactionSection`).
     - In `generateReportPdf`, spread the returned list into `MultiPage.build`:
       `...buildArrearsAuditSection(studentArrears, academicYear, baseFont, boldFont)`
     - Set `maxPages: 100` on `pw.MultiPage` so large classroom arrears tables paginate seamlessly across pages.
2. **`test/unit/pdf_report_service_test.dart`**:
   - Update any unit test assertions that expected `buildArrearsAuditSection` to return a `pw.Column` to expect `List<pw.Widget>`.
   - Ensure tests verify that 35+ students in arrears generate a valid multi-page PDF without throwing `PdfTooBigPageException`.

## Verification Method
- Run `flutter test test/unit/challenger_m3_1_adversarial_test.dart`
- Run `flutter test test/unit/challenger_m3_2_adversarial_test.dart`
- Run `flutter test test/unit/pdf_report_service_test.dart`
- Run `flutter analyze`
- Run full `flutter test`
All tests must pass (100%) with 0 errors and 0 analyzer issues.

Write `changes.md` and `handoff.md` in `D:\project\bendehara v2\.agents\worker_m3_fix\` and report back via message.
