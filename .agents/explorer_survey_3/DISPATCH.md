# Dispatch for Explorer Survey 3

## 2026-09-20T13:05:00Z

## Task
Investigate PDF Reporting Service, Testing Infrastructure, and Build Configuration.

## Inputs
- Authoritative Request: `D:\project\bendehara v2\.agents\ORIGINAL_REQUEST.md`
- Working Directory: `D:\project\bendehara v2\.agents\explorer_survey_3`
- Project Root: `D:\project\bendehara v2`

## Scope
1. Examine PDF generation:
   - Locate `PdfReportService` or whatever service generates PDF financial reports.
   - Inspect table generation logic, page formatting, headers, styles, and colors.
   - How are expenses currently formatted?
   - How are dates and periods formatted in the PDF?
   - Is there any current dues / arrears section in the PDF, or where should the dedicated student arrears audit section be placed?
2. Examine Test Infrastructure:
   - What existing tests exist in `test/`?
   - How are tests structured? Can tests run currently?
3. Examine Build & Versioning Configuration:
   - Inspect `pubspec.yaml`, `android/app/build.gradle` (or `build.gradle.kts`).
   - What is the current version and `versionCode`?
   - What is the command to build the release APK (`Bendahara-Kelas-Release.apk`)?
4. Document all relevant file paths, signatures, dependencies, and build details.

## Output
Write a comprehensive report to `D:\project\bendehara v2\.agents\explorer_survey_3\survey_pdf_build.md` and finish with `handoff.md`.
