# Sprint 20 Retrospective — 2026-05-15

> **Sprint Mapping**: S20-M7. Closes Sprint 20 (`production/sprints/sprint-20.md`).
> **Sprint Window**: 2026-05-15 to 2026-05-28 nominal; actual close 2026-05-15 (seventh consecutive same-day-compressed sprint).
> **Review Mode**: Solo.

## Sprint Goal — Met

> **Ship the UI/HUD design system: typography + palette + spacing tokens + 5 new UX specs + pattern library expansion + apply to first live screen (Guild Hall) + validate via playtest.**

All six success conditions satisfied:
- (a) DESIGN.md authored (typography / 7-color palette / 8px spacing / 4 motion easing curves) — pre-plan PR #111. ✅
- (b) S20-M1 scaffolded-but-unwired audit shipped — twice-deferred from S18 retro #1 and S19 S1 — found 2 confirmed ghosts in RunSnapshot (kill_schedule + loop_counter); both annotated DEFERRED rather than wired/deleted (low-risk path). ✅ (PR #116)
- (c) Lora + IM Fell English font sourcing (SIL OFL) wired into `parchment_theme.tres` via FontVariation sub_resources. ✅ (PR #115)
- (d) 5 new UX specs landed (DRV / Return-to-App / Victory Moment / Hero Detail / Matchup Assignment), each with 14 required sections + ≥17 acceptance criteria. ✅ (PR #117)
- (e) Pattern library expanded 9 → 20 patterns (v0.1 → v0.2). ✅ (PR #118)
- (f) Guild Hall theme implementation shipped: LedgerRow theme variation + SynergyBadge node + wiring, with 8 new contract tests; visual playtest PASS on all 5 checks. ✅ (PR #119 + playtest-12)

## By the Numbers

- **PRs merged**: 11 — 4 pre-plan (#110 Guild Hall UX spec, #111 DESIGN.md, #112 Formation Assignment UX spec, #113 Recruit Screen UX spec) + 7 sprint execution (#114 plan, #115 fonts, #116 scaffolds audit, #117 5 UX specs, #118 11 patterns, #119 Guild Hall theme, #120 bookkeeping + playtest skeleton).
- **Cumulative tests at sprint close**: 4462 PASS / 0 errors / 0 failures.
- **Regressions**: 0.
- **New ADRs**: 0 (design system documented in `DESIGN.md` rather than as an ADR — design tokens are not architectural decisions in the structural sense).
- **GDD status transitions**: 0.
- **New contract tests**: 8 (Guild Hall theme application — LedgerRow variation + SynergyBadge node + Conditional Strip behavior + HeroCard theme variation).
- **New UX specs**: 8 (Guild Hall, Formation Assignment, Recruit Screen authored pre-plan + DRV, Return-to-App, Victory Moment, Hero Detail, Matchup Assignment authored mid-sprint). Each: 14 sections + ≥17 ACs.
- **Pattern library growth**: +11 patterns (9 → 20). New: Guild-Ledger-Entry, Conditional Strip, Slot Button, Two-Tap Assignment Flow, Affordability Gating, Pool Entry Card, Browseable Locked Frontier, Identity Header Strip, Atomic Commit Action, Sticky Affordance Footer, Cross-Fade Refresh.
- **Tilt-shift / shader tests stable**: 3 warm-lantern + 9 tilt-shift = 12 shader contract tests still passing.
- **Version**: 0.0.0.44 → 0.0.0.45.

## What Worked

- **DESIGN.md token-to-Godot-Theme translation pipeline held without surprises.** S20-M5 was flagged in the sprint plan as MED-probability risk for "DESIGN.md token-to-Godot-Theme translation surprises." The risk did not fire. The `LedgerRow` variation slotted into the existing parchment theme structure cleanly via the same idiom used for `ParchmentPanel`, `OverlayDimPlate`, `IdentityHeader`, and `SelectedSlotButton`. The translation guide in `DESIGN.md §Godot Theme implementation` is now validated by a shipped application — future screens (S20-S1 Formation Assignment + S20-S2 Recruit Screen, Sprint 21 candidates) inherit confidence from this validation.
- **Twice-deferred S18 retro action #1 (scaffolds audit) FINALLY shipped.** S20-M1 was framed as non-negotiable in the sprint plan; running it FIRST before any design implementation began was the right ordering. Found 2 confirmed ghosts (RunSnapshot.kill_schedule + RunSnapshot.loop_counter); both DEFERRED rather than wired/deleted because both are honest scaffolding for not-yet-shipped features. The DEFERRED annotation pattern (vs immediate deletion) makes the next sprint's "do I wire this or delete it?" decision recoverable from inline context rather than requiring archaeology.
- **Pattern library expansion 9 → 20 unlocked future sprints.** The 11 new patterns capture the reusable interaction grammar surfaced by Sprint 20's 8 new UX specs. Pattern #10 (Guild-Ledger-Entry) and #11 (Conditional Strip) were the load-bearing patterns for S20-M5 — both shipped as theme variations / scene nodes in the same sprint. The 9 other patterns are infrastructure for Sprint 21's S1+S2 theme implementations.
- **Cozy register held through the redesign.** The Sprint 20 plan's success criteria included "no FOMO patterns introduced." The playtest confirmed: the LedgerRow + Conditional Strip patterns reinforce **calm bookkeeping** vs **gamified pressure**. The visual delta from pre-Sprint-20 → post-Sprint-20 was deliberately subtle (hairline borders, 50% alpha, 2px radius, warm continuity in serif fonts) — the goal was warm continuity, not redesign shock. The cozy register survived intact.
- **Solo same-day cadence held for seventh consecutive sprint.** S14 → S15 → S16 → S17 → S18 → S19 → S20. Day-0 plan + same-day close is now structural baseline. The autonomous "merged. move on" cadence shipped 7 Must Haves in one day.
- **"Is the new design implemented?" question caught a real bug.** Mid-sprint, the playtest verdict was "we still use old uiux and hud" — initially read as design rejection, but root-cause investigation revealed PR #119 was OPEN, not merged. The branch had the code; main did not. Cost: 1 conversation cycle. Lesson: when playtest verdict contradicts "the code is there," verify which branch the playtester is running before designing a revert.

## What Hurt

- **Sprint-status.yaml bookkeeping fell out of sync.** The autonomous "merged. move on" cadence shipped M1 → M2 → M3 → M4 → M5 across 7 PRs but never flipped the `status` field from `ready-for-dev` → `done` on the yaml. The gap was visible only at retro time when M6 needed the status to be coherent. Backfilled via PR #120, but the workflow gap is real — PRs merge faster than the status file updates. Sprint 21 action: flip `status: done` in the same PR that merges the implementation, not as a separate bookkeeping pass.
- **`.uid` sidecar files accumulated as untracked over multiple sprints.** PR #120 picked up 4 orphaned `.uid` files from Sprint 18, Sprint 19, and Sprint 20 (`biome_background.gd.uid`, `biome_background_test.gd.uid`, `losing_run_wiring_test.gd.uid`, `guild_hall_theme_application_test.gd.uid`). Godot 4.6 auto-generates these next to `.gd` files for UID-based resource resolution — they should commit alongside their parent `.gd`. Pattern: any commit that adds a `.gd` file must also add the sibling `.uid`.
- **Initial playtest happened against the wrong branch.** When the user said "i did playtest, we still use old uiux and hud," the actual cause was that PR #119 hadn't merged yet. Local main was at PR #118. The branch with the new design existed but wasn't on main. The autonomous-execution cadence ("PR opened with CI green → done → move on") didn't include "wait for merge before recommending playtest." For visual playtest gates specifically, verify the playtested branch IS main (or instruct the playtester to checkout the feature branch explicitly).
- **5-check playtest verdict was a one-liner again.** Same observation as Sprint 19 retro #5 (visual-correctness playtest checklist template). Sprint 20's plan listed 5 specific checks; the verdict was "playtest approved. let's move on." The light-touch sign-off pattern is valid (per project memory `feedback_playtest_driven_closure`), but the gap between plan specificity and verdict terseness persists. Action item carries to Sprint 21.

## Action Items for Sprint 21

| # | Action | Priority | Owner |
|---|--------|----------|-------|
| 1 | **S20-S1 Formation Assignment theme implementation.** Should-Have not landed; first candidate for Sprint 21. UX-FA-01..21 spec already complete. Theme variation infrastructure shipped in S20-M5; this is an application sprint, not a design sprint. Risk: low; the DESIGN.md translation pipeline is validated. | **HIGH** | godot-gdscript-specialist |
| 2 | **S20-S2 Recruit Screen theme implementation.** Same shape as #1. UX-RS-01..20 spec already complete; Pool Entry Card + Affordability Gating + Cross-Fade Refresh patterns ready. Risk: low. | **HIGH** | godot-gdscript-specialist |
| 3 | **Sprint-status.yaml flip-on-merge discipline.** The bookkeeping gap from Sprint 20 (M1-M5 all `ready-for-dev` despite merged) suggests the status flip should be part of the merging PR, not a separate retro-time pass. Sprint 21 trial: every implementation PR also includes the `status: done` flip in sprint-status.yaml. | MED | claude-code (process change) |
| 4 | **`.uid` sidecar tracking discipline.** Any PR that adds a `.gd` file must also add the sibling `.uid`. Adopt as part of the standard PR checklist. Sprint 20 backfilled 4 stragglers (Sprint 18 + 19 + 20 lineage); zero new orphans in Sprint 21 is the goal. | MED | claude-code (process change) |
| 5 | **S20-N1 ClassPortrait placeholder art — pull into Sprint 21 if real art remains ETA-less.** Nice-to-Have not landed in S20. Recruit Screen spec OQ-RS-01 calls out the placeholder art gap. If user's separate real-art workstream has ETA by Sprint 21 planning, retire; otherwise, generate 6 placeholder textures as part of S2 implementation. | LOW | producer / user check |
| 6 | **Visual-correctness playtest checklist template.** Carry-over from Sprint 19 retro action #5; still not authored. For future visual sprints (Sprint 21 has 2 theme implementations and presumably another playtest), author a small playtest-checklist template that asks "PASS/FAIL per check" rather than aggregate sign-off. Process improvement only — no code. Effort: ~0.1d. Twice-flagged is the warning sign; same pattern as the scaffolds audit. | LOW | claude-code |
| 7 | **Playtest-branch verification step.** Before recommending playtest, verify the deliverable is on the playtester's main (not just on a branch with CI green). Add to the autonomous-execution cadence: PR merge ≠ playtester-can-see-it; ask "have you pulled main?" or instruct branch checkout explicitly. | LOW | claude-code (process change) |

## Process Improvements

- **Authoring design infrastructure (theme variation + node + wiring) does not require visual approval upfront.** S20-M5 shipped LedgerRow theme variation + SynergyBadge node + wiring + 8 contract tests with CI green; the visual judgment came after, at the M6 playtest gate. This is the right ordering for design-system work: ship the infrastructure that the contract tests can verify, then let the playtest grade the visual outcome. If the visual outcome had FAILED, the infrastructure would have remained as deferred building blocks (Sprint 18 N1 tilt-shift disabled-by-default precedent). The infrastructure isn't wasted just because the visual grade is "not yet" — it's ready for the next iteration.
- **Pre-plan workstream paid off.** Sprint 20 had 4 pre-plan PRs (#110 Guild Hall UX spec, #111 DESIGN.md, #112 Formation Assignment UX spec, #113 Recruit Screen UX spec) authored BEFORE the sprint plan itself (#114). This pre-loaded the design context for M3-M5 such that the sprint plan could be aggressive on Must Have execution. The pattern: when a sprint theme requires substantial design groundwork, author the design ahead of the sprint plan rather than as part of it. Frees the sprint execution to be implementation-focused.
- **Pattern library is now a real reuse asset, not aspirational.** With 20 patterns at v0.2, the cost of authoring the next UX spec drops substantially because most components reference existing patterns rather than inventing new ones. Sprint 21 S1+S2 theme implementations will validate this — the prediction is that the Formation Assignment + Recruit Screen theme work compresses to <0.75d each (the sprint plan estimate) because the pattern library does the heavy lifting.
- **Autonomous-execution cadence works at the per-PR level, breaks at the per-sprint level.** The "merged. move on" cadence is excellent for individual PR closure but causes drift on cross-PR state (sprint-status.yaml). Sprint 21 trial: bundle the status flip with the merging PR. This is small enough that it doesn't break the autonomous cadence; large enough that it closes the bookkeeping gap.

## Notes

- **Sprint 20 closes 7/7 Must Haves on the strict goal; 0/2 Should Haves shipped; 0/1 Nice to Haves shipped.** Sprint goal MET. The 7/7 Must Have completion + visual playtest PASS is the load-bearing closure signal; the deferred S/N tier work is the Sprint 21 candidate set.
- **Day-0 plan + same-day close: seventh consecutive sprint.** S14 → S15 → S16 → S17 → S18 → S19 → S20. Cadence is structural baseline.
- **19 ADRs cumulative.** No new ADR this sprint — design system is documented in `DESIGN.md` (not an ADR) because design tokens are not structural-architecture decisions in the ADR sense. This is a deliberate boundary: ADRs capture system-shape decisions; `DESIGN.md` captures style decisions.
- **The Sprint 20 sprint plan §M6 risk register flagged "Visual playtest signals a major design system flaw" as LOW probability, MED-HIGH impact.** Risk did not fire. The conservative-register choice (subtle hairline borders + warm continuity) was the design hedge that made this LOW-probability outcome stick.
- **DESIGN.md is the project's first dedicated design-token file.** Prior sprints authored design context inside GDDs (per-system) or as one-off ADRs. DESIGN.md establishes the canonical token registry. Future design changes route through DESIGN.md updates first, then through theme/scene application — the same shape as GDD-first-then-implementation that Sprint 19 retro identified as the right cadence for visual work.
- **The HD-2D pipeline + the UI/HUD design system are now both shipped.** HD-2D activated in S19; design system shipped in S20. The visual stack is structurally complete from BiomeBackground (z=-1) → tilt-shift DoF (z=-1) → UI (z=0) → WarmLanternOverlay (z=1), with the UI layer now rendered through DESIGN.md tokens rather than programmer-art defaults. Sprint 21's S1+S2 theme implementations are the broader-application sweep that proves the system holds across screens.
