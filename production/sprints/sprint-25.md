# Sprint 25 — 2026-06-26 to 2026-07-09

> **Status: Day-0 plan authored 2026-05-16**, same-day close of Sprint 24.
> Twelfth consecutive same-day-compressed sprint (Sprint 14→…→24→25).
> Solo review mode.
>
> **STRATEGIC PIVOT**: Sprint 24 playtester verdict was "the uiux and functions are not progressing too much." Recent sprints have shipped lots of cleanup with no player-visible progress. See `production/retrospectives/sprint-24-retrospective-2026-05-16.md` §"What Could Be Better" + memory entry `feedback_infrastructure_debt_drift.md`. **Sprint 25 pivots to player-visible content + mechanics; new GDD authoring, test fixture refactors, hygiene polish, and engine refinement are explicitly deferred.**

## Sprint Goal

**Ship implementation of two already-authored GDDs — Floor Unlock System (#16) and Onboarding First-Session Flow (#29) — so the player sees actual depth (multiple floors gated by progression) and a guided first-session, not a bare Guild Hall on cold launch.**

Why these two:
- **Both GDDs have been ready since Sprint 14/18.** The implementation hasn't shipped despite the GDDs going through 9 + 4 review passes respectively. That is the load-bearing example of "infrastructure debt that doesn't ship the game."
- **Floor Unlock implementation gives the game depth.** Right now the player can clear floor 1 and the game offers nothing new on floors 2-5; floor unlock progression is the difference between "5-minute novelty" and "real session length."
- **Onboarding implementation gives new players a guided first 5 minutes** instead of being dropped onto an empty Guild Hall with seeded Theron and no context.

**Definition of Sprint 25 success**:
(a) Floor Unlock System autoload (`src/core/floor_unlock_system/`) shipped per GDD #16 §C.1–§C.3; AC-FU-01..15 all passing in `tests/unit/floor_unlock_system/`;
(b) `floor_cleared_first_time` signal wired Orchestrator → FloorUnlockSystem at autoload rank 4 < 5; replay-on-load handles the offline-replay path per I.12;
(c) Dispatch screen floor picker shows floors 1–5 with floors > `highest_cleared+1` rendered as LOCKED (per GDD §F);
(d) Onboarding first-session flow ships per GDD #29 §C.1–§C.8; AC-29-01..14 all passing in `tests/unit/onboarding/`;
(e) First-launch detection triggers the 5-minute tutorial context (welcome → meet your guild → first dispatch → first run → return-to-app); subsequent launches skip the tutorial via persisted flag;
(f) Visual playtest validates BOTH systems read clearly to a fresh-save player: "I understand why floor 3 is locked" + "I knew what to do on first launch without guessing";
(g) Sprint 25 retro committed.

## Capacity

- Total days: 10 (~2 weeks at 5 days/week, solo)
- Buffer (20%): 2.0 days reserved for unplanned work
- Available: **8.0 days**

**Calibration note**: Sprint 25 is the HEAVIEST player-visible-content sprint since Sprint 17. Must Haves total 6.0d (Floor Unlock 3.5d + Onboarding 2.0d + playtest 0.5d). This is intentional pushback against the recent infrastructure-only cadence. If Must Haves run long, drop Should Haves entirely; do NOT add hygiene polish to "fill" remaining capacity.

## Pre-Plan Disposition (handle BEFORE Sprint 25 M1 starts)

| PR / Gate | Status | Action |
|-----------|--------|--------|
| **Sprint 24 retro** | COMMITTED 2026-05-16 | Done — playtest verdict captured; infrastructure-debt-drift memory entry written |
| **Floor Unlock GDD #16 Open Questions I.14 + I.15** | RESOLVED 2026-04-21 (per the existing GDD §I note) | Done — no upstream blocker remains |
| **Floor Unlock GDD #16 Open Question I.11** (designer-accessible ACTIVE_BIOME_MVP) | DEFERRED to V1.0; runtime fallback works | OK — implementation uses the `get_setting(key, "forest_reach")` runtime fallback; designer-UI surfacing is V1.0+ work |
| **Onboarding GDD #29** | DRAFT 2026-05-06 with Sprint 18 §J retirement note | OK — Sprint 18 §J retired the *polish carry*, NOT the §H ACs. Implementation is fresh ground |

## Tasks

### Must Have (Critical Path)

| ID | Task | Owner | Est. | Dependencies | Acceptance Criteria |
|----|------|-------|------|--------------|-------------------|
| S25-M1 | **Floor Unlock System autoload implementation.** Create `src/core/floor_unlock_system/floor_unlock_system.gd` per GDD #16 §C.1–§C.3 and `tests/unit/floor_unlock_system/*_test.gd`. Implement: `_unlock_state: Dictionary[String, int]` (biome_id → highest_cleared), `_ready()` initialization with autoload-rank-4-before-Orchestrator (rank 5) invariant, `_on_floor_cleared_first_time(floor_index, biome_id, losing_run)` handler with all guards (R1–R9 per §C.1), `get_highest_cleared(biome_id) -> int` + `get_available_biomes() -> Array[String]` public API, save/load via `get_save_data()` + `load_save_data(data)` with all 5 clamp/cast guards (R3 + Sub-ACs 05/08), DI of `_error_logger` + `_warning_logger`. Register in `project.godot` autoloads at rank 4. **Defer** the designer-UI ACTIVE_BIOME_MVP surfacing (I.11 — V1.0 work); use runtime fallback `get_setting("floor_unlock/active_biome_mvp", "forest_reach")`. | godot-gdscript-specialist | 2.0d | none | All 15 BLOCKING ACs pass (AC-FU-01..15); autoload registered at rank 4; save/load round-trip works; full suite green |
| S25-M2 | **Wire Orchestrator → FloorUnlockSystem signal + Dispatch floor picker UI gating.** Orchestrator already emits `floor_cleared_first_time` on the foreground path; verify offline-path emit landed (per GDD #13 Pass-I.15-fix). Subscribe FloorUnlockSystem to the signal at autoload init. Update Dispatch screen's floor picker (`assets/screens/formation_assignment/formation_assignment.gd::_render_floor_picker_biome_tabs`) to read `FloorUnlockSystem.get_highest_cleared(biome_id)` and render floors > `highest_cleared + 1` as LOCKED (disabled Button + grayed visual per GDD #16 §F). | godot-gdscript-specialist | 1.0d | S25-M1 | Player can clear floor 1; floor 2 then unlocks (visible enable); floors 3–5 stay LOCKED; replay accessible after first clear; `_unlock_state` persists across save/load |
| S25-M3 | **Replay-on-load: offline replay correctness.** Wire the `floor_cleared_first_time` signal from `compute_offline_run` (per GDD #16 §C.3 step 5 + I.12 dependency). Verify that an offline run that crosses a first-clear emits the signal so `FloorUnlockSystem._on_floor_cleared_first_time` fires during replay. Cover AC-FU-13 + AC-FU-14 integration tests. | godot-gdscript-specialist | 0.5d | S25-M2 | Offline first-clear of floor 2 advances `_unlock_state["forest_reach"]` from 1 → 2; AC-FU-13 + AC-FU-14 pass |
| S25-M4 | **Onboarding First-Session Flow implementation.** Create `src/core/onboarding/onboarding_state.gd` autoload + `assets/screens/_modals/onboarding_overlay.tscn + .gd` per GDD #29 §C.1–§C.8. Implement: `is_first_session: bool` derived from save state (no save → first session), step-sequenced overlay flow (welcome step → guild explainer step → dispatch hint step → run-end celebration step → return-to-app celebration step), skip via Esc or "Skip" button (dismissal grace per GDD §C.6), persistent flag `onboarding_completed: bool` written on completion OR skip. Wire SceneManager to push overlay on first-launch detection. | godot-gdscript-specialist | 1.5d | none (parallel with M1) | All 14 ACs pass (AC-29-01..14); fresh-save player sees the overlay chain; subsequent launches do not; Skip button works |
| S25-M5 | **Sprint 25 visual playtest + retro.** Use `production/playtests/_template-visual-playtest.md` with TWO grading axes specific to Sprint 25: "I understand why floor N is locked" (Floor Unlock readability) + "I knew what to do on first launch" (Onboarding readability). Per-check PASS/PARTIAL/FAIL. Retro doc + sprint-status.yaml closed. **Failure mode to watch for**: if either system tests-pass but playtests-fail, the cause is almost certainly [[feedback_scaffolded_but_unwired_pattern]] — a nav button or state-seed step that was deferred. | xiaolei (human) + claude-code | 0.5d | M1+M2+M3+M4 | playtest-16 committed with per-check verdict on BOTH axes; sprint-25 retro committed; sprint-status.yaml all Must Haves marked done |

**Must Have total**: 5.5 days (engineering: 5.0d + playtest 0.5d)

### Should Have

| ID | Task | Owner | Est. | Dependencies | Notes |
|----|------|-------|------|--------------|-------|
| S25-S1 | **Add one new biome: `moonlit_glade` (or equivalent).** Wire 5 floors of `moonlit_glade` content into DataRegistry. Add a biome background asset (cozy night register; same programmatic-ColorRect approach as `forest_reach` until art lands). Add `moonlit_glade` to BIOME_FLOOR_COUNT. Wire it as a second TAB on Dispatch's floor picker. **Initial state: LOCKED until floor 5 of `forest_reach` cleared** (V1.0 biome-chain unlock per GDD #16 §I.1 — pick option (a): `is_biome_completed(forest_reach)`). | game-designer + godot-gdscript-specialist | 1.5d | S25-M2 (Floor Unlock UI ready) | `moonlit_glade` appears as a 2nd biome tab on Dispatch; LOCKED indicator visible until forest_reach floor 5 cleared; first clear of moonlit_glade floor 1 emits signal correctly |
| S25-S2 | **Add one new class: `paladin` (warrior tier-2 variant).** Add to DataRegistry classes table per existing hero-roster.md schema. Recruitable from refreshed pool. Stats: warrior-shape with higher HP, lower DMG (cozy-tank archetype). Wire portrait via ClassPortraitFactory (existing deterministic hash → color). The new class triggers no new synergies by itself but ROSTER diversity increases (Triple Threat now reachable with warrior + mage + paladin = 1+1+1 mixed comp). | game-designer + godot-gdscript-specialist | 1.0d | none | `paladin` recruitable from pool; portrait renders distinct color; hero card displays correctly; synergy detection still works correctly with new class |

**Should Have total**: 2.5 days

### Nice to Have

| ID | Task | Owner | Est. | Notes |
|----|------|-------|------|-------|
| S25-N1 | **First-time biome unlock fanfare.** When a player unlocks a NEW biome for the first time (S25-S1's moonlit_glade flip), play a one-shot toast + audio cue per Audio Router MVP wiring (S23-N1). Locale key: `biome_unlocked_toast_format,New biome unlocked: %s`. | godot-gdscript-specialist | 0.5d | Cozy-register celebration; no FOMO/timer |
| S25-N2 | **Floor lock indicator UX polish.** Replace the "grayed-out floor button" UX with a softer "locked" affordance: 🔒 icon + smaller tooltip "Clear floor N first" (per GDD #16 §F design hints). | godot-gdscript-specialist | 0.5d | Player-visible polish on Floor Unlock surface |

**Nice to Have total**: 1.0 day

## Carryover from Previous Sprint

| Task | Reason | New Estimate / Disposition |
|------|--------|---------------------------|
| S24-S1 polish items (Guild Hall empty-state, Dispatch empty-slot hints, tap-target audit) | Plan called for 4 items; only 1 landed (Recruit pool placeholder) | **DEFER PERMANENTLY** unless playtest signal demands. Sprint 25 should not pick these up — see Sprint 24 retro §"What I'd Do Differently" #4 |
| S24-S3 remaining test-site refactors | 3 sites un-refactored to use the new fixture | **DEFER** until those test files are touched for unrelated reasons. Helper is non-breaking; coexistence is fine |
| S23-S1 carryforward (M4 clarity polish) | Already DROPPED TO ADVISORY by playtest-14 PASS, then partially landed in S24-S1 | **CLOSED** — no further carry |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| **Floor Unlock implementation complexity exceeds 3.5d estimate** (15 ACs + autoload-order invariant + DI + Sub-AC clamp paths) | MED | HIGH | Implement in 4 stages mapped to the GDD §J Implementation Sequencing if it exists, otherwise: stage 1 = `_ready()` + autoload registration + AC-FU-01 + AC-FU-02; stage 2 = handler + R1-R9 + AC-FU-03..05; stage 3 = save/load + R3 clamps + AC-FU-06..12; stage 4 = signal wiring + integration + AC-FU-13..15. Each stage shippable as its own PR; if stage 3 + 4 overrun, defer to S25-stretch. |
| **Onboarding overlay flow has unauthored UX details** (the GDD is design-only; UX wireframes aren't part of GDD #29) | MED | MED | Lean on the existing `_modals/pause_menu.tscn` overlay pattern as visual scaffold. Onboarding overlay = step-paged variant of pause menu with Next/Skip buttons. Defer custom animations to N3-equivalent followup if needed. |
| **First-launch detection is the hardest part of Onboarding** | LOW | HIGH | Already specified in GDD #29 §C.1: `SaveLoadSystem.request_full_load` reports `load_completed("first_launch")` when no save file exists. The signal contract is shipped (S11-M4); Onboarding just subscribes. Verify the signal in a unit test BEFORE building the overlay flow. |
| **Wiring step deferred-and-never-landed** (the [[feedback_scaffolded_but_unwired_pattern]]) | MED | HIGH | After each Must Have ships, verify end-to-end manually: actually trigger first-launch detection, actually clear floor 1, actually see floor 2 unlock. Don't trust test-pass alone. This is the dominant failure mode in this project per memory. |
| **Plan still drifts back to infrastructure mid-sprint** | LOW | HIGH | Sprint 25 explicitly defers ALL infrastructure/hygiene/refactor work. If a Should Have/Nice to Have feels like infrastructure when starting it, STOP and ship the player-visible work first. Re-check at mid-sprint: "what does the player see different after this sprint?" If answer is "nothing yet," focus on closing M-tasks. |

## Dependencies on External Factors

- **No external dependencies for Must Have or Should Have.** Sprint 25 is fully autonomous-doable.
- **N3+ stories** (real product art) remain external-art-blocked; not scoped here.
- **M5 playtest is the only human-gated step** — same pattern as every prior sprint.

## Definition of Done for this Sprint

- [ ] Floor Unlock System autoload shipped (S25-M1)
- [ ] Signal wiring + Dispatch floor picker UI gating shipped (S25-M2)
- [ ] Replay-on-load offline correctness shipped (S25-M3)
- [ ] Onboarding First-Session overlay flow shipped (S25-M4)
- [ ] Sprint 25 playtest run on BOTH axes (Floor Unlock readability + Onboarding readability)
- [ ] Sprint 25 retro committed
- [ ] sprint-status.yaml updated: Sprint 24 archived to comment block; Sprint 25 stories block in `stories:` array
- [ ] **Strategic checkpoint**: at sprint close, write one sentence answering "what does the player see different now?" If you can't answer it concretely with specifics, the sprint has drifted

## Sprint 25 Process Rules

1. **Per-task PR with `base=main` ALWAYS.** Continued from Sprint 24 process rule. No stacked PRs.
2. **Implementation BEFORE new GDD authoring.** If a Sprint 25 task seems to need "more design work first," check whether the design already exists. The grep-first GDD-existence check is now standard practice.
3. **Player-visible surface check at mid-sprint.** Halfway through, ask: "What does the player see different after the work shipped so far?" If the answer is "nothing yet" and Must Haves aren't done, focus on M-tasks. If the answer is "nothing yet" and Must Haves ARE done, the sprint planning was wrong — surface as a retro action.
4. **Failure mode watchlist**: [[feedback_scaffolded_but_unwired_pattern]] (tests pass + ACs green but no player can reach the feature); [[feedback_infrastructure_debt_drift]] (cleanup work crowds out content); [[feedback_playtest_driven_closure]] (100% tests passing ≠ shipped).
5. **No GDD authoring stories in Sprint 25.** The grep-first check already runs; if a Sprint 26 candidate seems to need a new GDD, that's Sprint 26's planning problem, not Sprint 25's.

## After Sprint 25

Sprint 26 candidates (in priority order — provisional):
- **Real product art ingestion** (if art workstream lands an ETA). The S23-S3 ClassPortraitFactory pattern means art-asset swap-in is non-blocking.
- **Class Synergy V2 tier coloring + iconography** (S24-M1 design hints → visual polish — but ONLY if Sprint 25 ships content depth first).
- **Additional biomes** beyond Sprint 25's first new biome (depending on Sprint 25 playtest signal).
- **Additional classes** beyond Sprint 25's `paladin` (depending on Sprint 25 playtest signal).
- **Equipment / Items system** (NOT YET DESIGNED — would need a Sprint 26 GDD authoring stretch only if Sprint 25 surfaces "what's missing is item depth" as the playtest signal).

**Anti-pattern to actively avoid in Sprint 26 planning**: scoping more "GDD authoring" or "test fixture hygiene" or "engine optimization" stories. The infrastructure-debt-drift memory entry is the canonical guardrail.


---

## ADDENDUM — Re-Scope After Day-0 Grep Audit (2026-05-16)

**Status**: The Sprint 25 Day-0 plan above was authored 2026-05-16 with the explicit intent of "pivot to player-visible content + mechanics." However, the post-merge grep audit immediately surfaced a self-inflicted infrastructure-debt-drift mistake: **both S25-M1 (Floor Unlock implementation) and S25-M4 (Onboarding implementation) are already shipped.**

### Self-audit findings

**S25-M1..M3 Floor Unlock — VERIFIED-IN-PLACE**:
- `src/core/floor_unlock_system/floor_unlock_system.gd` exists (576 lines)
- 4 unit test files in `tests/unit/floor_unlock_system/`
- Autoload registered as `FloorUnlock` in `project.godot`
- Dispatch screen (`assets/screens/formation_assignment/formation_assignment.gd`) wires `FloorUnlock.is_unlocked_in_biome(biome_id, floor_index)` for floor picker button enable/disable + subscribes to `floor_unlocked` signal for live UI update + handles `"floor_locked"` validation toast
- Orchestrator emits `floor_cleared_first_time` (verified by integration tests)

**S25-M4 Onboarding — VERIFIED-IN-PLACE-BUT-DIFFERENT-SHAPE**:
- GDD #29 §A explicitly states "**strictly diegetic** — no tutorial overlays, no 'click here' arrows, no skippable splash text."
- The implementation that exists matches the GDD: a `first_launch` signal from `SaveLoadSystem` triggers seed states (Theron warrior, starting gold, recruitable pool, first biome unlocked). NO overlay flow. The cozy register IS the onboarding.
- Integration test `tests/integration/onboarding/first_launch_flow_test.gd` covers the diegetic flow end-to-end.
- A unit test `tests/unit/onboarding/no_tutorial_copy_grep_test.gd` enforces the no-overlay constraint by grepping for forbidden tutorial copy.

**The Sprint 25 Day-0 plan made the exact mistake `feedback_infrastructure_debt_drift.md` warns about** — scoping "implement system X" stories without grep-first checking whether system X already exists. The plan also got Onboarding's design intent backwards: it scoped a step-paged overlay flow, which is the OPPOSITE of what GDD #29 §A specifies.

### What this means

The user's playtest signal ("uiux and functions are not progressing too much") was NOT about Floor Unlock or Onboarding being missing — those are working as designed. The signal is about **the existing depth not being enough to feel like progression**:
- 1 biome with 5 floors that all use the same biome background
- 3 classes that all play similarly
- Programmatic-placeholder portraits/visuals
- Repetitive matchup interactions across floors of the same biome
- No "wow, new content" moment between floor 1 and floor 5

The actual remaining work is **content expansion + visual differentiation**, not system implementation.

### Revised Sprint 25 Must Haves (CONTENT ONLY)

| ID (Revised) | Task | Owner | Est. | Status of Day-0 Equivalent |
|--------------|------|-------|------|---------------------------|
| **S25-M1-rev** | **Add second biome `moonlit_glade`** — 5 floors of content (enemies + visuals); biome background (cozy night register); LOCKED-until-forest_reach-completed gate using existing FloorUnlock biome-availability path. **Was S25-S1 in Day-0 plan; promoted to Must Have.** | game-designer + godot-gdscript-specialist | 1.5d | (Day-0 S25-S1 stays as-is) |
| **S25-M2-rev** | **Add new class `paladin`** — cozy-tank archetype (warrior tier-2 variant); recruitable from pool; portrait via ClassPortraitFactory; updates synergy interaction space. **Was S25-S2 in Day-0 plan; promoted to Must Have.** | game-designer + godot-gdscript-specialist | 1.0d | (Day-0 S25-S2 stays as-is) |
| **S25-M3-rev** | **Per-floor visual differentiation in `forest_reach`** — F1 is daytime forest, F2 is dusk forest, F3 is evening forest, F4 is night forest, F5 is bossfight-overcast. Same `BiomeBackground` ColorRect approach as Sprint 22 S22-M3; one color palette per floor instead of one per biome. Tests update the BiomeBackground contract test to assert per-floor selection. | game-designer + godot-gdscript-specialist | 1.0d | NEW — fills the "every floor feels the same" gap |
| **S25-M4-rev** | **Floor unlock celebration moment** — when a player clears floor N and unlocks floor N+1, the Victory Moment screen shows a "🎉 Floor N+1 unlocked!" callout above the gold rewards block. Uses the existing `floor_unlocked` signal + `_show_toast` pattern. | godot-gdscript-specialist | 0.5d | NEW — gives the implicit "I made progress" beat a visible celebration |
| **S25-M5-rev** | **Sprint 25 visual playtest + retro** — TWO grading axes: "I feel like the game grew between sprints" (qualitative content-progression) + "Floor 3 looks/feels different from floor 1" (per-floor differentiation). | xiaolei (human) + claude-code | 0.5d | Updated playtest axes |

**Must Have total (revised)**: 4.5 days

### Revised Should Have (still in scope)

| ID (Revised) | Task | Est. |
|--------------|------|------|
| S25-S1-rev | **Add third biome `crystal_caverns`** — same shape as `moonlit_glade`; LOCKED-until-moonlit_glade-cleared. | 1.5d |
| S25-S2-rev | **Add new class `archer`** — DPS / ranged archetype (mage tier-2 variant); recruitable; new synergy combinations. | 1.0d |

### Revised Nice to Have

| ID (Revised) | Task | Est. |
|--------------|------|------|
| S25-N1-rev | **Biome unlock fanfare** (toast + audio cue on new-biome unlock). Same as Day-0 N1. | 0.5d |
| S25-N2-rev | **Floor lock indicator UX polish** — 🔒 icon + tooltip per GDD #16 §F. Same as Day-0 N2. | 0.5d |
| S25-N3-rev | **First-floor differentiation in `moonlit_glade` + `crystal_caverns`** — same per-floor visual approach as S25-M3-rev applied to the new biomes. Only ship if Sprint 25 has capacity. | 1.0d |

### What this addendum DEFERS (formal closure)

**Day-0 S25-M1..M3 (Floor Unlock implementation)**: CLOSED as VERIFIED-IN-PLACE. The system exists, is tested, is wired to Dispatch. No further implementation work in Sprint 25.

**Day-0 S25-M4 (Onboarding overlay)**: CLOSED as DESIGN-MISALIGNED. GDD #29 explicitly forbids overlay-based onboarding (diegetic-only per §A). The first-launch seed pathway IS the onboarding implementation, already shipped. No overlay work in Sprint 25.

### Memory entry update

Adding a new memory entry `feedback_grep_first_check_must_run_pre_planning.md`: the Sprint 25 Day-0 plan committed the exact mistake the `feedback_infrastructure_debt_drift.md` memory entry warns about, despite the entry being written in the same session by the same agent. This indicates the grep-first check needs to be a HARD step in `/sprint-plan new` (skill-level enforcement), not a soft process rule that the planner is expected to remember.

### Sprint 25 Process Rule Update

Adding Process Rule #6: **Before writing "implement system X" into a sprint plan, run `grep -rn "<system snake_case name>\|<SystemPascalCase>" src/ tests/` and verify NO existing implementation appears.** If results appear, the story is VERIFIED-IN-PLACE or DESIGN-MISALIGNED, not Implement-Net-New.

### Acknowledgment

This addendum is uncomfortable to author — it documents that I, the agent, made the exact mistake I just wrote a memory entry warning about, within minutes of writing the entry. The user's playtest signal stands: the game isn't growing. The path forward is content expansion (more biomes, classes, floor differentiation, visible progression beats), not system implementation. Sprint 25's revised Must Haves all touch content + visual surfaces the player will see.
