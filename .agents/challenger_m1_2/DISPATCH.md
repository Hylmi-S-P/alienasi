# Dispatch for Challenger M1 (Instance 2)

## Mission
Adversarially challenge and stress-test Milestone 1 (Core Data & Dues Domain Engine).

## Inputs
- Authoritative Request: `D:\project\bendehara v2\.agents\ORIGINAL_REQUEST.md` (MANDATORY: read this first)
- Project Scope: `D:\project\bendehara v2\PROJECT.md`
- Working Directory: `D:\project\bendehara v2\.agents\challenger_m1_2`

## Scope
1. Empirically verify sorting behavior:
   - Verify ordering with identical created timestamps, reverse order insertions, and large volumes.
2. Empirically test boundary conditions for R4 & R5:
   - Inactive students with unpaid records -> must be excluded.
   - Fully paid students -> must not appear in arrears list.
   - Mixed daily and weekly dues academic years.
   - Large range formatting: single day missing, 2 days missing, 30 days missing.
3. Check general transactions:
   - Ensure weekend transactions (income/expense) work without interference.
4. Execute tests and report verdict (`APPROVE` or `REJECT`) with evidence to `D:\project\bendehara v2\.agents\challenger_m1_2\handoff.md`.

## 2026-09-20T13:15:44Z
You are Challenger 2 for Milestone 1 (Core Data & Dues Domain Engine).
Working directory: D:\project\bendehara v2\.agents\challenger_m1_2
MANDATORY: Read D:\project\bendehara v2\.agents\ORIGINAL_REQUEST.md completely.
Read your dispatch at D:\project\bendehara v2\.agents\challenger_m1_2\DISPATCH.md.
Stress-test boundary conditions: inactive students, 100% paid students, month boundary date groupings, and unrestricted general transactions.
Deliver empirical findings and verdict APPROVE or REJECT in handoff.md and send message to parent.

