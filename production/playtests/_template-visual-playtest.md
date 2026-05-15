# Visual Playtest — TEMPLATE

> **Why this template exists**: Sprint 19 retro action #5, Sprint 20 retro
> action #6, and Sprint 21 retro action #2 all flagged the same gap — visual
> playtest verdicts were one-liners ("looks good" / "demo quality") that
> didn't grade individual checks. Sprint 22 S22-S1 (4th-time carry) finally
> landed this template, used by S22-M5 onward.

Copy this template to a new file when starting a visual playtest:
`production/playtests/playtest-NN-<theme>-YYYY-MM-DD.md`.

Fill in every cell of the 5-check table. Per-check PASS/FAIL/PARTIAL grading
is the load-bearing protocol; aggregate verdicts are advisory only.

---

# Playtest NN — [Sprint goal headline]

> **Sprint Mapping**: S__-M_ (`production/sprints/sprint-__.md`).
> **Gate**: Sprint __ Definition of Done — "[copy the playtest gate line from the plan]".
> **Status**: [PENDING — fill in after live playtest] / PASS / CONDITIONAL PASS / BLOCKED
> **Precedent**: Light-touch sign-off pattern (per project memory `feedback_playtest_driven_closure.md`); per-check granularity (per template — S22-S1).

## Session Info

- **Date**: YYYY-MM-DD
- **Build**: v0.0.0.XX (post-PR #XXX — [headline change])
- **Tester**: [Project lead / collaborator]
- **Platform**: macOS / Windows / Steam Deck / etc.
- **Input Method**: Mouse / Touch / Gamepad
- **Session Type**: [What's being validated — clarity sweep / new flow / bug-fix verification]

## Hypothesis Under Test

[2-4 sentences. Frame the question the playtest answers. Reference the
sprint plan's success criteria. Make the disconfirmation criteria explicit
so the verdict can read against them.]

## Per-Check Validation

| # | Check | Result | Notes |
|---|-------|--------|-------|
| (a) | [Check description from sprint plan] | [PASS / FAIL / PARTIAL] | [What you saw; specific gaps if FAIL/PARTIAL] |
| (b) | [Check description] | [PASS / FAIL / PARTIAL] | [Notes] |
| (c) | [Check description] | [PASS / FAIL / PARTIAL] | [Notes] |
| (d) | [Check description] | [PASS / FAIL / PARTIAL] | [Notes] |
| (e) | [Check description] | [PASS / FAIL / PARTIAL] | [Notes] |

**Per-check protocol** (load-bearing — established S22-S1):
- **PASS** — the check works as designed; no caveats
- **PARTIAL** — works, but specific aspect falls short (note it)
- **FAIL** — does not work; sprint goal not met on this axis

A check with multiple sub-criteria gets ONE row but split into bullets in
Notes — don't merge sub-criteria into a meta-PASS that hides individual
fails.

## Findings

**Tester report**: *"[verbatim 1-3 sentence quote from playtest — what
felt right, what felt wrong, what surprised]"*

[2-5 paragraphs of free-form observations. What's the playtest signal
beyond the structured table? Surprises? Subjective register? Specific
moments that landed or didn't?]

## Test Suite Impact

- Cumulative tests at vN: X PASS / 0 errors / 0 failures.
- [+M new tests this sprint]
- [Notable test surfaces preserved or stressed]

## Files Touched This Session

- [This file (new playtest report)]
- [Any other files modified during playtest — usually none for visual
  playtests; for bug-fix playtests, list the fix files]

## Verdict

[ONE of:]

- **S__-M_: CLOSED — PASS** on all N checks. Sprint __ Definition of Done
  satisfied. Proceed to next milestone / retro.
- **S__-M_: CONDITIONAL PASS** — N/M checks pass. Specific gaps surfaced
  for [sprint+1] iteration. Sprint __ ships the deliverable as
  visible-but-imperfect; the gaps are advisory, not blocking.
- **S__-M_: BLOCKED — REVISION NEEDED** — fundamental flaw signaled.
  Sprint __ must scope-defer downstream items and instead iterate the
  problem before declaring the sprint goal MET. See findings.

## Notes

- Per-check verdict template used (S22-S1 — 4th-time carry from S19/S20/
  S21 retros — finally non-negotiable).
- Light-touch sign-off matches established precedent
  ([playtest-11 S19-M5], [playtest-12 S20-M6]).
- [Sprint-specific notes — e.g. process trial outcomes, follow-up actions]
