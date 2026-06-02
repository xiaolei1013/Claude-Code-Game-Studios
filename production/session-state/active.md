# Active Session State

## Current Phase: Polish (design artifact maturity) — Infrastructure gap open
## Project: 58/58 stories complete (100%), all 7 epics complete
## Stage pointer: Polish (kept) — see stage-framing note below

## Stage Framing (2026-04-18, revised)

A retrospective `/gate-check` on Technical Setup → Pre-Production returned
FAIL with five reported blockers. During `/test-setup` the same day, one
blocker was found to be a **false positive** — the gate-check skill scans
root-level `tests/`, but this project's Unity project lives at
`production/Trizzle/` with 245 tests already organized under
`Assets/Trizzle/Tests/` per Unity convention. Test framework was never
actually missing.

Remaining real gaps (3 of 5):
- ~~Test framework~~ → **resolved (false positive)** — 245 Unity tests already
  exist under `production/Trizzle/Assets/Trizzle/Tests/`.
- ~~CI workflow~~ → **intentionally deferred 2026-04-18** (Xiaolei). Solo-dev
  tradeoff — Unity CI via game-ci is overhead without sufficient team-size
  payoff. Local Unity Test Runner is the test gate. Accepted gap; future
  `/gate-check` runs will continue to flag but it is a deliberate override.
- ~~UX foundation~~ → **resolved 2026-04-18**: `design/ux/interaction-patterns.md`, `design/ux/hud.md`, `design/ux/main-menu.md` (authored from Unity MCP hierarchy inspection of MainMenu.unity + PlayScene_HUD.prefab).
- ~~Accessibility tier~~ → **resolved 2026-04-18**: `design/accessibility-requirements.md` committing **Standard** tier.
- ~~Architecture traceability matrix~~ → **resolved 2026-04-18**: `docs/architecture/architecture-traceability.md` — 74 TR-IDs mapped to 8 ADRs across 6 systems, zero Foundation-layer gaps, all ADRs covered (no orphans).

**Decision**: `production/stage.txt` stays at `Polish`. Project has 58 story
docs, 8 ADRs, 245 Unity tests, 8 sprint QA cycles, smoke reports through
2026-04-19. Polish is the accurate pointer.

## Immediate Next Action: Infrastructure Sprint

**Plan**: `production/sprints/sprint-infrastructure.md` (authored 2026-04-18)
**Duration**: 5–8 days solo
**Purpose**: Close the 5 hard blockers from the retrospective gate check.

Five blockers:
1. Test framework not scaffolded (`tests/unit/`, `tests/integration/`, example)
2. CI workflow absent (`.github/workflows/tests.yml`)
3. UX foundation absent (`design/ux/` directory does not exist)
4. Accessibility tier undefined (`design/accessibility-requirements.md`)
5. Architecture traceability matrix absent (`docs/architecture/architecture-traceability.md`)

Day-by-day breakdown in the sprint plan. Exit criteria: re-run `/gate-check`
Technical Setup → Pre-Production, verdict PASS or CONCERNS.

## Deferred Priority Work Items (post-Infrastructure Sprint)

### P0-impl: SpawnManager IWaveProvider Integration — SPEC LOCKED (ADR-0008, 2026-04-18)

The integration contract is fully specified in ADR-0008. Unity implementation
follows after the Infrastructure Sprint:

- `SpawnManager` public API: `SetWaveProvider` / `SpawnNextWave` /
  `IsWaveComplete` / `OnWaveComplete` (ADR-0008 §1). **No `StartSpawnWave`** —
  stale placeholder, does not exist.
- `WaveData` is a tagged union (authored `SpawnItems` for campaign; procedural
  fields for Endless). SpawnManager's private `ExpandToSpawnQueue()` converts
  both to a unified `List<SpawnItemInfo>` queue; `ApplyDifficulty()` applies
  `IDifficultyProvider` multipliers once. Call order: `GetNextWave → Expand →
  ApplyDifficulty → Dispatch` (R-029).
- `IsWaveComplete` semantic: dispatch exhausted ∧ zero live hostiles (bosses
  and minions included).
- Wave completion: `OnWaveComplete` event preferred for new consumers;
  `EndlessSessionController.WaveLoop()` grandfathered to poll `IsWaveComplete`
  (R-031).
- `SetWave(int)` is on `EndlessWaveProvider` only — not on `IWaveProvider`
  (R-013 v2). `CampaignWaveProvider` auto-advances.

Remaining P0-impl work (post-Infrastructure Sprint): SpawnManager.cs refactor,
CampaignWaveProvider.GetNextWave() implementation, EndlessWaveProvider.
GetNextWave() implementation, EndlessSessionController wire-up.

### P1: Unity Editor Authoring (Manual)
10 boss prefabs, 10 RoomConfig assets, 15 BT assets, arena scene, VFX

### P2: 3 Playtest Sessions (for Polish → Release gate)
### P3: Performance Profiling (wave 30+ with 19 enemies)
### P4: Accessibility Check (moved into Infrastructure Sprint Day 5 — tier commit)

### P5: Feel Issues (new 2026-04-18, confirmed by Xiaolei during Pre-Prod → Production gate check)
Three feel areas need Polish iteration — the "mostly, with some issues"
response to the Vertical Slice Validation subjective check:

1. **Combat hit feel / damage feedback weight** — damage numbers, hit flash,
   screen shake, sound layering; combat doesn't punch hard enough.
2. **Skill/ability responsiveness** — input-to-action latency, cooldown
   readability, telegraph clarity.
3. **Draft pacing / choice clarity** — draft modal feel, skill card
   readability, comparison weight.

Movement / dodge / dash feel was explicitly NOT flagged — that part feels good.
Address these in the first Polish-phase feel-iteration sprint before
difficulty-curve tuning locks.

### P6: Process Debt (from Pre-Prod → Production gate review) — ✅ CLOSED 2026-04-18
- ~~Run `/ux-review` on 2026-04-18 UX specs~~ → **resolved**: all three specs now APPROVED after additive patches.
- ~~Formalize pause menu as standalone `design/ux/pause-menu.md`~~ → **resolved**: authored 2026-04-18 from Unity MCP inspection (4-button ButtonGroup with Continue/Restart/GiveUp/Settings, ScreenDimmed overlay, Text_Pause localized title).
- ~~Move `session-logs/playtest-sprint-*.md` to canonical path~~ → **resolved**: copies placed at `production/playtests/` + README noting the canonical vs session-log relationship.
- ~~Document prototype graduation~~ → **resolved**: `production/prototype-status.md` written to explain the absence of `prototypes/` (demo graduated to production).

### P7: Release Blockers
- Muted text 12px contrast 3.9:1 — ship blocker per `design/accessibility-requirements.md`; resize or recolor before Release gate.
- VFX hierarchy doc — 27 status effects + 125+ skill VFX + boss phase effects need explicit priority tier matrix before VFX authoring peaks.
- CI workflow — re-evaluate at Polish → Release gate (currently intentionally deferred; CI is table stakes for release certification).
- W6 DragonEnemyController orphan — resolve in boss-phase GDD or art-bible character roster.

---

## Polish → Release Roadmap (from 2026-04-18 gate check — verdict FAIL as expected)

Four-sprint plan merging Creative / Technical / Producer / Art Director verdicts.
Approx. 8 weeks solo.

### Sprint 9 — Feel + Measurement
- [ ] Combat hit feel pass (damage weight, hit flash, screen shake, sound layering)
- [ ] Skill responsiveness pass (input latency, cooldown readability, telegraph clarity)
- [ ] Draft pacing pass (card readability, modal motion, comparison weight)
- [ ] Performance profiling — TR-difficulty-010 (Room 1 Hard min-spec 30fps), TR-combo-010 (<0.5ms/frame), TR-endless-012 (wave 30 PC <16.6ms / Mobile <33ms)
- [ ] Create `production/milestones/v1.0-release.md` with target date + scope lock

### Sprint 10 — Fixes + Compliance
- [ ] Externalize hardcoded strings (`RunDraftPanel.cs`, `RunHistoryPanel.cs`, `MenuPrepareStagePanelPC.cs`) to localization tables
- [ ] Apply perf fixes based on Sprint 9 profiling data
- [ ] Muted-text contrast fix (resize to ≥14px OR recolor to ≥4.5:1)
- [ ] Author `design/art/vfx-hierarchy.md` (Tier 1 player feedback / Tier 2 enemy telegraphs / Tier 3 ambient, with density cull rules)
- [ ] Resolve W6 DragonEnemyController orphan (roster entry OR shared-visual note)
- [ ] Run `/balance-check` + triage findings

### Sprint 11 — RC + Playtest Round 1
- [ ] Scope lock
- [ ] Produce release-candidate builds: Windows x64 + one Mobile target (clean compile + smoke boot)
- [ ] Playtest 1: Archer full campaign (external playtester)
- [ ] Playtest 2: Endless wave-25+ on Mobile (W17 validation)
- [ ] ADR-0009 Foundation Systems Retrospective (optional, recommended)
- [ ] ADR-0010 CI Decision (stand up game-ci workflow OR formalize pre-flight checklist)

### Sprint 12 — Playtest Round 2 + Launch Artifacts
- [ ] Playtest 3 on RC after Sprint 11 fixes
- [ ] Draft v1.0 game-facing CHANGELOG / patch notes
- [ ] Run `/launch-checklist` or `/release-checklist`
- [ ] Store metadata inventory (key art, capsule images, screenshots, trailer for v1.0 additions)
- [ ] Legal check (EULA, privacy policy, age rating — confirm if changed from demo)
- [ ] Final QA pass + smoke on RC
- [ ] Re-run `/gate-check` Polish → Release — target verdict PASS

## Next Session

Start with the Infrastructure Sprint Day 1 task: `/test-setup` to scaffold
`tests/unit/`, `tests/integration/`, and the first example test. Sprint plan
at `production/sprints/sprint-infrastructure.md`.
