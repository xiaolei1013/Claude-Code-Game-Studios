# Sprint 19 Retrospective — 2026-05-14

> **Sprint Mapping**: S19-M6. Closes Sprint 19 (`production/sprints/sprint-19.md`).
> **Sprint Window**: 2026-05-14 to 2026-05-27 nominal; actual close 2026-05-14 (sixth consecutive same-day-compressed sprint).
> **Review Mode**: Solo.

## Sprint Goal — Met

> **Ship the HD-2D first visual pass: programmatic biome backgrounds + activated tilt-shift DoF, validating the diorama register before real product art lands.**

All five success conditions satisfied:
- (a) GDD #26 expanded from STUB DRAFT (3 sections) to full 8-section APPROVED first-pass. ✅ (PR #105)
- (b) ADR-0019 authored as successor to ADR-0017; layer-order contract + per-screen composition + programmatic-placeholder strategy + activation strategy locked. ✅ (PR #106)
- (c) BiomeBackground system shipped: scene + script + 7 palette presets + 21 contract tests; wired into Guild Hall (tavern preset) + DungeonRunView (per-biome via orchestrator getter). ✅ (PR #107)
- (d) Tilt-shift re-wired + activated: scene trees restructured to put BackBufferCopy + TiltShiftDof at z=-1 (between BiomeBackground and UI); `enabled = 1.0`; 2 new UI-sharpness guard tests (AC-26-08). ✅ (PR #108)
- (e) Sprint 19 visual playtest PASS — diorama register fires correctly; S18-N1 UI-ghost-smear is structurally impossible per the new layer-order contract. ✅ (playtest-11)

## By the Numbers

- **PRs merged**: 5 (#104 plan, #105 GDD #26 first-pass, #106 ADR-0019, #107 BiomeBackground system, #108 tilt-shift activation)
- **Cumulative tests at sprint close**: 4446 PASS in the most-comprehensive local headless run (compared to truncated 813/834 partial runs in prior sprints; the runner ran further this sprint before the headless cleanup SIGABRT)
- **Regressions**: 0
- **New ADRs**: 1 (ADR-0019 HD-2D Pipeline Activation; supersedes ADR-0017)
- **GDD status transitions**: 1 (#26 HD-2D Rendering Pipeline: STUB DRAFT → APPROVED)
- **New contract tests**: 23 (21 BiomeBackground + 2 UI-sharpness guard)
- **Architectural decisions locked**: 4 (layer-order contract, per-screen composition, programmatic-placeholder strategy, activation strategy)

## What Worked

- **Scaffolding-first authoring of the GDD before implementation paid off.** S19-M1 expanded GDD #26 to all 8 sections + S19-M2 authored ADR-0019 BEFORE M3 (BiomeBackground impl) and M4 (activation). The GDD's §C.1 layer-order contract was the design artifact that drove the M4 scene restructure — without it, M4 would have re-run into the S18-N1 ghost-smear class. Authoring the design FIRST, then implementing, is the right cadence for visual-pipeline work where automated tests can't verify visual correctness.
- **Programmatic-placeholder strategy decoupled from the external art workstream.** Sprint 19 shipped working diorama-register infrastructure with zero dependency on the user's in-flight real-art deliverables. When art lands, it drops in as a BiomeBackground scene-root swap (ColorRect → Sprite2D) with zero downstream changes. The strategy resolution in ADR-0019 §Decision 3 is the load-bearing decision that made same-day-close possible.
- **AC-26-08 UI-sharpness guard test is the architectural antibody.** The Sprint 18 N1 ghost-smear bug taught us that "shader wired correctly" and "shader looks right on current content" are different verifiable surfaces. AC-26-08 — `TiltShiftDof.z_index < UI_label.z_index` — is the automated assertion that catches the S18 bug class structurally. If a future regression promotes tilt-shift to z=0, the test catches it before merge.
- **Two Godot 4.6 quirks caught + documented inline during M3.** `class_name` cross-file registration timing + GDScript lambda primitive capture. Both are now annotated in the affected files so future contributors don't repeat the trial-and-error.
- **Solo same-day cadence held for sixth consecutive sprint (S14→S15→S16→S17→S18→S19).** Day-0 plan + same-day close is no longer remarkable — it is the project's rhythm.

## What Hurt

- **Should-Have and Nice-to-Have items did not land in Sprint 19.** S19-S1 (scaffolded-but-unwired audit — flagged as highest-priority retro action from Sprint 18) was queued; S19-S2 (per-biome tilt-shift presets) and S19-N1 (gradient shader) also queued. None landed this sprint. The strategic pivot to UI/HUD design (S19-M5 surface) supersedes the S2/N1 polish work for Sprint 20 — defensible — but **S1 (scaffolds audit) remains high-priority and should be the FIRST item folded into Sprint 20** before any UI/HUD design plan is implemented. Deferring it twice (Sprint 18 retro action #1 → Sprint 19 S1 → ???) starts to look like avoidance.
- **The "5-check visual playtest" specification was richer than the actual sign-off.** Sprint 19 plan documented 5 specific visual checks; the playtest sign-off was a single sentence ("the functionality is working") that did not explicitly grade each check. The light-touch sign-off pattern (per project memory `feedback_playtest_driven_closure`) is valid, but the gap between the plan's specificity and the verdict's terseness is worth naming — future visual sprints may need a "playtest checklist" pre-filled form to make per-check verdicts observable rather than aggregate.
- **The pivot to UI/HUD design surfaced mid-sprint, not at sprint plan time.** Sprint 19 was planned around HD-2D visual pass; the user's strategic awareness that the underlying UI itself needs designed plan only crystallized during the M5 playtest session. The visual-polish layer ON TOP of programmer-art UI surfaces a contrast that makes the UI's own design debt visible. This is a virtuous loop — Sprint 19's polish revealed Sprint 20's priority — but it also means the Sprint 19 plan's "biggest visual lift available" framing under-estimated where the visual ceiling actually was.

## Action Items for Sprint 20

| # | Action | Priority | Owner |
|---|--------|----------|-------|
| 1 | **Sprint 20 theme: UI/HUD design.** The user surfaced this during S19-M5 playtest. Scope TBD via Sprint 20 planning conversation: UX flows? Visual design system? Per-screen layout overhaul? HUD-specific elements? All? Recommend `/ux-design` skill + `/design-consultation` skill as the two entry points; planning conversation should choose between them or commit to both. | **HIGH** | user + claude-code |
| 2 | **S19-S1 scaffolded-but-unwired audit pulled into Sprint 20 as S20-S1.** Twice-deferred (Sprint 18 retro #1 → Sprint 19 S1 → Sprint 20 S1). Recommended as the FIRST item before UI/HUD implementation begins — would surface any latent placeholder constants that future UI/HUD work might compound on top of. Not high-effort (~0.25d); recommend doing it before sprint plan execution as a "Sprint 20 setup" task. | HIGH | claude-code |
| 3 | **S19-S2 per-biome tilt-shift presets — defer or retire.** Without real biome art, per-biome tuning is tuning placeholder gradients against placeholder gradients — diminishing return. Recommend retiring with a "pull in if M5-style playtest signals a tuning need" condition. The infrastructure (S19-M3 7-preset BiomeBackground) is shipped; tuning lands when there's content to tune against. | LOW | producer |
| 4 | **S19-N1 gradient shader — defer or retire.** Similar logic: richer placeholder content has diminishing return if real art lands "soon" (no committed ETA, but the workstream exists). Recommend retiring with the same condition as #3. | LOW | producer |
| 5 | **Visual-correctness playtest checklist template.** Sprint 19 M5 plan listed 5 specific visual checks; the verdict aggregated all 5 into one sentence. For future visual sprints (Sprint 20 UI/HUD will likely have several), author a small playtest-checklist template that asks "PASS/FAIL per check" rather than aggregate sign-off. Process improvement only — no code. | Low | claude-code |

## Process Improvements

- **GDD-first-then-implementation is now a documented pattern for visual-pipeline work.** Sprint 19's M1 → M2 → M3 → M4 ordering (design, architecture, implementation, activation) is the cleanest sequence the project has shipped. Worth adopting as the default for any sprint where automated tests can't verify the deliverable (e.g., visual + audio + feel work).
- **The "scaffolds-but-unwired" audit (S18 retro action #1, S19-S1, S20-S1) shipping discipline matters more than the audit itself.** Authoring the pattern (S18-S2 PATTERNS §15) was easy; running it before each sprint close is the recurring discipline that catches the bug class. Sprint 20's first item being this audit is non-negotiable — twice-deferred is the warning sign.
- **Two Godot 4.6 quirks captured this sprint via inline code comments rather than new project memories.** Both are local to specific code patterns (cross-file `class_name`, lambda primitive capture) and live near the affected files where they'll be encountered organically. This is a deliberate choice — project memories are for cross-session lessons; inline annotations are for in-context onboarding. Both have their place.

## Notes

- **Sprint 19 closes 6/6 Must Haves on the strict goal; 0/2 Should Haves shipped; 0/1 Nice to Haves shipped.** Sprint goal MET. The 6/6 Must Have completion + visual playtest PASS is the load-bearing closure signal; the deferred S/N tier work is the recommended Sprint 20 cleanup (or retire).
- **Day-0 plan + same-day close: sixth consecutive sprint.** Sprint 14→15→16→17→18→19. The cadence is now structural baseline, not an outlier.
- **19 ADRs cumulative.** Architecture continues to accumulate at ~1 ADR/sprint average. The Sprint 18 plan flagged `/architecture-review` before Sprint 20 as a healthy hygiene checkpoint; reaffirm before Sprint 20 implementation begins (or fold into Sprint 20 setup).
- **GDD #26 status: STUB DRAFT → APPROVED.** First Sprint-19-era Vertical-Slice-tier GDD to fully transition out of stub status. Sets the precedent for #27 VFX System and other Vertical-Slice stubs to follow when their own pivot triggers fire.
- **The HD-2D pipeline is the first system to fully ship its design (GDD #26) + its architectural decision (ADR-0019) + its implementation (BiomeBackground + tilt-shift activation) + its visual playtest validation in a single sprint.** That's a useful template for future visual-pipeline work.
