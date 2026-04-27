# Sprint 5 — 2026-06-22 to 2026-07-03

> **Generated**: 2026-04-26 by `/sprint-plan` (autonomous; solo review mode)
> **Status**: Ready
> **Engine**: Godot 4.6 (pinned 2026-02-12)

## Sprint Goal

Land the **SceneManager Foundation epic (Stories 001–008)** — fill the rank ≥6
autoload hole, the LAST Foundation gap blocking a playable scene tree — and
**pre-flight Feature-layer story authoring** (HeroRoster + DungeonRunOrchestrator
+ Matchup + Combat) so Sprint 6 can assemble the Vertical Slice harness without
mechanical pre-flight burning Sprint 6 capacity. Carry over Sprint 4 tech-debt
cleanup (FOLLOWUP-001 + TD-005) to clear the audit trail before VS playtests.

## Capacity

- Total: 10 working days × 2 effective hours/day = 20 effective hours
- Buffer (20%): 4 h reserved for unplanned work / SceneManager pause-counter fiddliness
- Available: 16 h for new stories
- Sprint 1+2+3+4 baseline: ~20 h delivered per sprint (compressed in solo runs)

## Tasks

### Must Have (Critical Path)

| ID | Task | File / Path | Type | Est. h | Dependencies | Acceptance Criteria |
|----|------|-------------|------|--------|--------------|---------------------|
| S5-M1 | FOLLOWUP-001 cleanup: gate `test_resolve_assert_behavior_returns_null_after_assert_fires` for debug-vs-release | `tests/unit/data_registry/resolve_api_and_typed_accessors_test.gd` | Logic | 0.5 | none | Test passes in both debug + release CI runs; full unit suite goes 309/310 → 310/310 |
| S5-M2 | TD-005 cleanup: fix or replace broken `tests/gdunit4_runner.gd` | `tests/gdunit4_runner.gd` | Logic | 0.5 | none | Either runner script works end-to-end OR is removed from repo with CI workflow updated |
| S5-M3 | SceneManager Story 001: MainRoot.tscn + four CanvasLayer children | `production/epics/scene-manager/story-001-mainroot-scene-and-canvas-layers.md` | Integration | 2 | none | Per ADR-0007 § persistent-root layout |
| S5-M4 | SceneManager Story 002: autoload skeleton + four-state machine + DataRegistry gating | `production/epics/scene-manager/story-002-scenemanager-autoload-skeleton-and-state-machine.md` | Logic | 2 | S5-M3, DataRegistry (Sprint 1) | UNINITIALIZED→IDLE on `registry_ready`; rank ≥6 in autoload table |
| S5-M5 | SceneManager Story 003: `request_screen` API + `ScreenContainer` node-swap + first-launch routing | `production/epics/scene-manager/story-003-request-screen-api-and-node-swap.md` | Logic | 2 | S5-M4 | Sole external screen-change API; first-launch routes to main-menu |
| S5-M6 | SceneManager Story 004: `Screen extends Control` base + four lifecycle hooks + CI grep enforcement | `production/epics/scene-manager/story-004-screen-base-class-and-lifecycle-hooks.md` | Logic | 2 | S5-M5 | All four hooks declared; grep CI guard ratifies |
| S5-M7 | SceneManager Story 005: Tween-based 5 standard transitions + `_active_transition_tween` leak guard | `production/epics/scene-manager/story-005-tween-transitions-and-leak-guard.md` | Logic | 2 | S5-M6 | All 5 standard transitions; `kill()` prior tween before `create_tween()`; H-01 timing within ±10ms at 60fps |
| S5-M8 | SceneManager Story 007: Modal overlay API + counter-based `_modal_pause_count` | `production/epics/scene-manager/story-007-modal-overlay-api-and-pause-counter.md` | Logic | 2 | S5-M5 | `push_overlay` / `pop_overlay` symmetric; nested modals don't unstuck pause |
| S5-M9 | Pre-flight: `/create-stories hero-roster` | `production/epics/hero-roster/EPIC.md` | Config/Data (story authoring) | 1.5 | none | All hero-roster stories authored under `production/epics/hero-roster/` |
| S5-M10 | Pre-flight: `/create-stories dungeon-run-orchestrator` | `production/epics/dungeon-run-orchestrator/EPIC.md` | Config/Data (story authoring) | 1.5 | none | All dungeon-run-orchestrator stories authored |

**Must Have subtotal**: ~16 h (matches available capacity).

### Should Have

| ID | Task | File / Path | Type | Est. h | Dependencies | Acceptance Criteria |
|----|------|-------------|------|--------|--------------|---------------------|
| S5-S1 | SceneManager Story 006: CEREMONY transition exclusively via `AnimationPlayer` | `production/epics/scene-manager/story-006-ceremony-transition-via-animationplayer.md` | Logic | 2 | S5-M7 | Distinct from Tween path; `reduce_motion` instant-cut substitution lands here |
| S5-S2 | SceneManager Story 008: `scene_boundary_persist` narrow trigger + `save_failed` abort + cozy modal | `production/epics/scene-manager/story-008-scene-boundary-persist-and-save-failed-modal.md` | Integration | 2 | S5-M8, save-load Story 007 (Sprint 6 candidate) | Persist fires only on enter `dungeon_run_view` + exit `victory_moment`; "Try Again / Stay Here" modal renders on save fail |
| S5-S3 | Pre-flight: `/create-stories matchup-resolver` + `/create-stories combat-resolution` | EPIC.md ×2 | Config/Data (story authoring) | 2 | none | Both Feature epics fully decomposed |

**Should Have subtotal**: ~6 h.

### Nice to Have

| ID | Task | File / Path | Type | Est. h | Dependencies | Acceptance Criteria |
|----|------|-------------|------|--------|--------------|---------------------|
| S5-N1 | SceneManager Story 009: `reduce_motion` accessibility flag + offline-replay cozy-modal coordination | `production/epics/scene-manager/story-009-reduce-motion-and-offline-replay-modal.md` | Logic | 2 | S5-S1 | `reduce_motion` clamps standard transitions to 50ms; `PROGRESS_MODAL_THRESHOLD_MS=100` honored |
| S5-N2 | SceneManager Story 010: Edge cases + performance verification (H-10/H-11/H-12) | `production/epics/scene-manager/story-010-edge-cases-and-performance-verification.md` | Integration | 2 | S5-N1 | Input-block during transition; back-to-back queue; BG mid-transition |
| S5-N3 | Pre-flight: `/create-stories floor-unlock-system` | `production/epics/floor-unlock-system/EPIC.md` | Config/Data (story authoring) | 1.5 | none | Floor-unlock Feature epic decomposed (notes V1.0 multi-biome reopen per Floor Unlock I.11) |
| S5-N4 | Quick-spec → ADR propagation: matchup-viz + enemy-viz revisions into ADR-0009 + ADR-0008 | `design/quick-specs/{matchup-visualization-revision,dungeon-enemy-visualization}.md` → ADR amendments | Config/Data | 2 | none | Both quick-specs propagated; control manifest version bumped |

**Nice to Have subtotal**: ~7.5 h. Total max ceiling: ~30 h vs ~20 h target — Must Have is contractual.

## Carryover from Previous Sprint

| Task | Reason | New Estimate |
|------|--------|--------------|
| FOLLOWUP-001 (S5-M1) | Sprint 4 sign-off condition; debug-vs-release assert behavior; deferred for scope | 0.5 h |
| TD-005 (S5-M2) | Broken `tests/gdunit4_runner.gd`; CI workaround in place since Sprint 1; first cleanup window | 0.5 h |
| Save-load Stories 006–015 | NOT pulled into Sprint 5 — 10 stories of post-foundation save work; explicitly deferred to Sprint 6 alongside VS-harness assembly | — |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| OQ-8 (SceneManager autoload rank) still unassigned at S5-M4 start | HIGH | MEDIUM | Story 002 itself amends ADR-0003 + `project.godot` + architecture.md in lockstep — story spec already calls this out |
| `_modal_pause_count` race on nested modals | MEDIUM | HIGH | Story 007's QA Test Cases must include nested-overlay scenarios; counter vs boolean is the deliberate ADR-0007 choice |
| Tween leak via `Callable.bind` connect/disconnect asymmetry on Godot 4.6 | MEDIUM | MEDIUM | Story 005 explicitly flags this from Sprint 4 carry-over notes; verify before relying on signal disconnect |
| Pre-flight story authoring (S5-M9/M10) reveals GDD gaps | MEDIUM | MEDIUM | If ambiguity surfaces, log as `/quick-design` candidate — do not author guesswork |
| Sprint 4 SaveLoad consumer-persist contract (Story 007) is not yet implemented, so S5-S2 (`scene_boundary_persist`) wires into a stub | HIGH | LOW | Acceptable — Story 008's cozy modal can be unit-tested independently of a real save; integration test deferred to Sprint 6 |

## Dependencies on External Factors

- DataRegistry must reach READY before SceneManager initializes — already verified in Sprint 3 S3-M8 closure (TD-006).
- ADR-0007 (Scene Transition + Persist Coupling) is the highest-engine-risk ADR; HIGH risk on `CanvasLayer` process-mode + `Tween` `TWEEN_PAUSE_BOUND` + 4.5 Recursive Control disable interactions. Empirical verification per story.

## Definition of Done for this Sprint

- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-5-2026-04-26.md`) — see Phase 5 widget
- [ ] All Logic / Integration stories have passing unit / integration tests
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] FOLLOWUP-001 + TD-005 closed in tech-debt register
- [ ] All Feature-layer epics that ran pre-flight (`hero-roster`, `dungeon-run-orchestrator`, optionally `matchup-resolver` + `combat-resolution`) have story files under `production/epics/`
- [ ] OQ-8 SceneManager autoload rank assigned and stamped into ADR-0003 + control manifest

## Sprint 5 Deliberately Excludes (with rationale)

- **Vertical Slice playable build** — Sprint 6. Requires SceneManager (this sprint) + Feature-layer impl + save-load consumer hooks
- **Save-load Stories 006–015** — Sprint 6 alongside VS harness. Touching save-load and SceneManager simultaneously creates merge friction
- **Feature-layer epic IMPLEMENTATION** — pre-flight authoring only this sprint. Implementation begins Sprint 6.
- **Audio system** — still blocked (no GDD / no ADR-C03)
- **Character visual profiles** — Sprint 6 art-spec work, parallel with VS playtest authoring
- **AD-ART-BIBLE sign-off** — solo mode skip; defer to pre-MVP-ship gate

## Path to Pre-Production → Production Gate PASS

Per `production/gate-checks/2026-04-26-pre-production-to-production.md`:

- **Sprint 5** (this sprint): SceneManager Foundation closes; Feature-layer pre-flight unblocks Sprint 6
- **Sprint 6**: Feature-layer impl + Save-load 006–015 + VS-harness assembly + ≥3 playtests + character visual profiles + VS playtest report
- **Sprint 6 close**: re-run `/gate-check production` — VS Validation should reach 4/4 → PASS

## QA Plan

**QA Plan**: `production/qa/qa-plan-sprint-5-2026-04-26.md` (landed 2026-04-26)

Per-story test-file targets aggregated from each SceneManager story's embedded `## QA Test Cases` section. Net new automated test files projected: 11 (10 SceneManager + 1 verification of FOLLOWUP-001). Estimated ~85 net-new test cases. Zero playtest sessions required this sprint (same as Sprints 1-4 — no playable surface). Manual sign-offs: S5-M3 editor visual check + S5-N4 ADR read-through only.
