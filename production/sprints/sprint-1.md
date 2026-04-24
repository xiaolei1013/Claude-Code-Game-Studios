# Sprint 1 — 2026-04-27 to 2026-05-08

> **Stage**: Pre-Production
> **Review mode**: solo (PR-SPRINT gate skipped per `director-gates.md`)
> **Manifest Version**: 2026-04-24
> **Previous sprint**: None — this is Sprint 1

## Sprint Goal

Get the two lowest-risk Foundation-layer autoloads (`TickSystem` rank 0 and `DataRegistry` rank 1) to a **bootable + minimally functional state**: both register correctly in `project.godot`, their `_ready()` boots without error on a clean run, `TickSystem.tick_fired` emits at 20 Hz in foreground, and `DataRegistry.registry_ready` fires after a successful deterministic boot scan of `assets/data/`. Defer SaveLoadSystem (HIGH risk, HMAC from scratch) and SceneManager (HIGH risk, persistent-root scene + 4-state machine) to Sprint 2.

## Capacity

- **Total working days**: 10 (Mon 2026-04-27 → Fri 2026-05-08, two 5-day weeks)
- **Effective focused-implementation hours**: ~20 (solo dev + AI pair; realistic for Pre-Production pace)
- **Buffer (20%)**: 4 hours reserved for unplanned work, learning curve, platform verification
- **Available**: 16 hours implementation

## Tasks

### Must Have (Critical Path — both autoloads bootable)

| ID | Task | Story File | Agent/Owner | Est. Hours | Dependencies | Acceptance Criteria |
|----|------|-----------|-------------|-----------|-------------|---------------------|
| S1-M1 | TickSystem autoload skeleton | `production/epics/tick-system/story-001-tick-system-autoload-skeleton.md` | godot-gdscript-specialist | 2 | None | TR-time-001, TR-time-017, ADR-0003 Amendment #3 |
| S1-M2 | Integer accumulator + `tick_fired` synchronous emission | `production/epics/tick-system/story-002-integer-accumulator-and-tick-fired-emission.md` | godot-gdscript-specialist | 3 | S1-M1 | TR-time-003/004/005/007/010/013 |
| S1-M3 | DataRegistry autoload skeleton + state machine | `production/epics/data-registry/story-001-autoload-skeleton-and-state-machine.md` | godot-gdscript-specialist | 2 | None (parallelizable with S1-M1) | TR-data-loading-001/007/011/012/013 |
| S1-M4 | GameData abstract base + archetype/role constant sets | `production/epics/data-registry/story-002-gamedata-base-and-constant-sets.md` | godot-gdscript-specialist | 3 | S1-M3 | TR-data-loading-004/005; ADR-0011 archetype constants |
| S1-M5 | Boot scan load order + per-category enumeration | `production/epics/data-registry/story-003-boot-scan-load-order.md` | godot-gdscript-specialist | 3 | S1-M4 | TR-data-loading-001/002/003/007/008/022/025/026; AC-DLS ordered categories |

**Must Have subtotal**: ~13 hours. Goal: TickSystem emits + DataRegistry boots end-to-end.

### Should Have (Parallelizable once Must Have is done)

| ID | Task | Story File | Agent/Owner | Est. Hours | Dependencies | Acceptance Criteria |
|----|------|-----------|-------------|-----------|-------------|---------------------|
| S1-S1 | `_process(delta)` forbidden-as-economy-input + wall-clock single call site | `production/epics/tick-system/story-003-process-delta-forbidden-and-wall-clock-single-site.md` | godot-gdscript-specialist | 2 | S1-M2 | TR-time-002/006/021; CI grep enforcement |
| S1-S2 | `resolve()` API + typed category accessors | `production/epics/data-registry/story-004-resolve-api-and-typed-accessors.md` | godot-gdscript-specialist | 3 | S1-M5 | TR-data-loading-006/014/015/019/024 |

**Should Have subtotal**: ~5 hours.

### Nice to Have (Stretch — only if Must + Should land under estimate)

| ID | Task | Story File | Agent/Owner | Est. Hours | Dependencies | Acceptance Criteria |
|----|------|-----------|-------------|-----------|-------------|---------------------|
| S1-N1 | Per-type validators + duplicate id + `min_content_count` | `production/epics/data-registry/story-005-per-type-validators-and-duplicate-id.md` | godot-gdscript-specialist | 3 | S1-S2 | TR-data-loading-005/016/017/023 |
| S1-N2 | Platform BG/FG notifications + tick emission pause | `production/epics/tick-system/story-004-platform-bg-fg-notifications-and-emission-pause.md` | godot-gdscript-specialist | 4 | S1-M2 | TR-time-008/009/010/015/034 (MEDIUM risk — platform notification verification) |

**Nice to Have subtotal**: ~7 hours. Likely defers to Sprint 2.

## Carryover from Previous Sprint

None — this is Sprint 1.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| First GdUnit4 invocation — framework learning curve (test discovery, assertion helpers) | HIGH | LOW | Example test (`tests/unit/example/framework_sanity_test.gd`) already lands from pre-production gate; first real unit test should follow its pattern |
| `@abstract` keyword (Godot 4.5+) editor behavior with `GameData extends Resource` — post-cutoff verify required per ADR-0006 | MEDIUM | MEDIUM | Manual editor probe as part of S1-M4; document findings in `docs/engine-reference/godot/modules/` if behavior diverges from expectation |
| `project.godot [autoload]` lockstep discipline — adding TickSystem (rank 0) and DataRegistry (rank 1) requires architecture.md + project.godot + CONSUMER_PATHS all agreeing | MEDIUM | MEDIUM | Include the architecture.md rank-table edit in each story's PR diff; `/story-done` audits this |
| `Array[Dictionary]` not inspector-editable in 4.6 — may surface when authoring first Floor `.tres` in S1-M5 or later | MEDIUM | LOW | Use script-created dict arrays, not inspector-authored; documented in ADR-0011 |
| Solo-dev capacity overrun if platform-notification story (S1-N2) is pulled in prematurely | LOW | MEDIUM | Hard-hold S1-N2 until Must + Should complete; it's honestly Sprint 2 material |

## Dependencies on External Factors

- **Godot 4.6 editor installed locally** (confirmed per session state: `4.6.1.stable.mono.official` was present for the autoload probe)
- **GdUnit4 plugin installed** (see `tests/README.md` install steps) — not yet done; do on day 1 of sprint
- **No external service dependencies** — fully offline / local development

## Definition of Done for this Sprint

- [ ] All Must Have tasks completed (S1-M1 through S1-M5)
- [ ] All completed tasks pass their acceptance criteria (TRs cited above)
- [ ] QA plan exists at `production/qa/qa-plan-sprint-1.md` (**run `/qa-plan sprint` before starting implementation**)
- [ ] All Logic stories have passing unit tests in `tests/unit/tick_system/` and `tests/unit/data_registry/`
- [ ] Smoke check passed (`tests/smoke/critical-paths.md` items 1–3 + new entries for TickSystem + DataRegistry booted)
- [ ] No S1 or S2 bugs in delivered features (S-severity per QA plan classification)
- [ ] `project.godot [autoload]` + `architecture.md` §Autoload Rank Table + `CONSUMER_PATHS` all lockstep-consistent
- [ ] End-to-end manual verification: fresh headless `godot --headless` launch prints both autoloads' `_ready()` traces, `tick_fired` fires at 20 Hz over a 5-second capture, `registry_ready` emits once after boot scan

## Explicitly NOT in this Sprint (rationale-logged)

- **SaveLoadSystem stories** (15 stories, HIGH risk, HMAC from scratch) → Sprint 2. Depends on DataRegistry being live for the `CONSUMER_PATHS` resolution + `registry_ready` gate. Story 004 (HMAC RFC 4231 conformance) is the blocking gate for tamper-detection work and needs focused attention it won't get in Sprint 1.
- **SceneManager stories** (10 stories, HIGH risk) → Sprint 3. Persistent-root scene + 4-state machine + Tween vs AnimationPlayer coordination is its own focused session.
- **TickSystem stories 004–011** → Sprint 2 and beyond. Platform BG/FG (004) is a candidate stretch; offline replay coordination (009) depends on OfflineProgressionEngine which is Feature layer.
- **DataRegistry stories 006–008** → Sprint 2. DAG validator (006), hot-reload/immutability/hydration gate (007), and perf budget (008) need the core (001–005) bedded in first.

> **Scope check**: No stories added beyond the Foundation-layer epic scope established 2026-04-24. No scope creep to check.

## QA Plan Status

✅ **QA plan landed 2026-04-24** → `production/qa/qa-plan-sprint-1-2026-04-24.md`

Classification: 8 Logic + 1 Integration. No Visual/Feel, UI, or Config/Data stories. Per-story Given/When/Then QA cases live in each story file; the QA plan adds cross-story strategy, `project.godot` lockstep audit, smoke scope delta, severity classification (S1/S2 block sprint close), and DoD.

Key QA gates for this sprint:
- Every Logic story → unit test file under `tests/unit/[system]/` must exist and pass before `/story-done`
- S1-M4 supplement: editor-probe evidence doc for `@abstract` behavior (manual)
- S1-N2 supplement: hardware handshake evidence doc for Steam Deck + mobile simulator BG/FG (manual)
- Every autoload story (S1-M1, S1-M3): `project.godot` + architecture.md + control-manifest lockstep audit
