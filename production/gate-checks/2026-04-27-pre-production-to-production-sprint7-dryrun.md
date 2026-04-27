# Gate Check: Pre-Production → Production (Sprint 7 dry-run)

**Date**: 2026-04-27
**Checked by**: gate-check skill (solo review mode — director panel skipped)
**Sprint context**: Sprint 7 in progress — 14/18 Must Have done. Autonomous portion of Sprint 7 closed at S7-M14. Remaining 4 Must Have (S7-M15/M16/M17 playtests + S7-M18 gate retry) require a human playtester.

This is a **dry-run** intended to enumerate the exact gaps blocking gate-PASS, so the human playtest sessions can target them directly.

---

## Required Artifacts: 12/14 present (+1 since Sprint 6 close)

- [x] **Prototype**: `prototypes/idle-matchup-loop/` exists
- [x] **Sprint plans**: 7 plans in `production/sprints/` (sprint-1.md through sprint-7.md)
- [x] **Art bible**: `design/art/art-bible.md` exists (v1.0 Draft; AD-ART-BIBLE sign-off SKIPPED in solo mode but acknowledged)
- [x] **Character visual profiles** (NEW since Sprint 6): `design/art/character-profiles/{warrior,mage,rogue}.md` — 3 profiles, each covering silhouette + hex palette + pose + matchup-counter visual cue. Anchored on game-concept.md Visual Identity Anchor (cozy-fantasy + warm-light). ✅ S7-M14
- [x] **MVP-tier GDDs**: complete (16 GDDs in `design/gdd/`)
- [x] **Master architecture**: `docs/architecture/architecture.md` exists
- [x] **ADRs**: 14 ADRs in `docs/architecture/` (well above the ≥3 Foundation-layer minimum)
- [x] **Control manifest**: `docs/architecture/control-manifest.md` exists
- [x] **Epics**: 13 epics in `production/epics/` covering Foundation + Core + Feature layers
- [ ] **Vertical Slice build**: PARTIAL — Sprint 7 wired the **data harness** end-to-end (S7-M13: dispatch → ACTIVE_FOREGROUND → tick-driven kills → RUN_ENDED with kill_count > 0, real DefaultCombatResolver + DefaultMatchupResolver, 9 integration tests pass). UI-facing portion (DispatchScreen widget + manual smoke session) deferred to Sprint 8 per S7-M13 closure. **Status**: Kernel verified runnable; not yet a playable build a human can sit in front of.
- [ ] **Vertical Slice playtest report**: `production/playtests/` directory does not exist — **MISSING** (S7-M15/M16/M17 deferred — require human playtester)
- [x] **UX specs (key screens)**: `design/ux/` has hud.md, main-menu.md, pause-menu.md, interaction-patterns.md
- [x] **HUD design doc**: `design/ux/hud.md` exists
- [x] **UX specs reviewed**: prior `/ux-review` cycles in Sprint 4-5 reached APPROVED-or-NEEDS-REVISION-accepted

---

## Quality Checks

- [x] **Sprint plan references real story file paths**: Sprint 7 plan + sprint-status.yaml reference `production/epics/**/story-*.md` paths verbatim
- [x] **Tests passing**: ~870 tests project-wide (no regressions across 14 closed Sprint 7 stories per per-story closure logs)
- [x] **All ADRs have Engine Compatibility sections**: confirmed by Sprint 5 architecture review
- [x] **All ADRs have ADR Dependencies sections**: confirmed by Sprint 5 architecture review
- [ ] **Core loop fun is validated**: NO PLAYTEST DATA — cannot validate without S7-M15/M16/M17 playtest reports
- [ ] **Vertical Slice is COMPLETE**: NO — kernel is wired (S7-M13 data path) but UI integration + first end-to-end manual run deferred to Sprint 8
- [ ] **Core fantasy is delivered**: cannot validate without playtest data
- [x] **Architecture document has no unresolved Foundation/Core open questions**: confirmed
- [x] **GDDs + architecture + epics coherent**: confirmed across 14 Sprint 7 closures

---

## Vertical Slice Validation: 0/4 (auto-FAIL)

- [ ] **A human has played through the core loop without developer guidance** — NO (DispatchScreen widget not yet built; data harness exists but no input surface)
- [ ] **The game communicates what to do within the first 2 minutes of play** — NO (no playable surface to test against)
- [ ] **No critical "fun blocker" bugs exist in the Vertical Slice build** — UNTESTED
- [ ] **The core mechanic feels good to interact with** — UNTESTED

> **Per gate definition**: Any VS Validation item FAIL = automatic gate FAIL.
> This gate-check is a **dry-run** with full advance knowledge that VS Validation cannot pass until S7-M15/M16/M17 are run by a human.

---

## Verdict: **FAIL** (auto-FAIL via VS Validation 0/4)

**Expected outcome.** Sprint 7's autonomous portion completed exactly as the Sprint 6 close-out planned: structural foundation + data harness + character visual profiles all landed. The remaining 4 Sprint 7 Must Have stories (S7-M15/M16/M17 playtests + S7-M18 gate retry) require either a human playtester (M15-M17) or a passing VS playtest pre-condition (M18).

### Progress since previous gate-check (Sprint 6 close-out — `2026-04-26-pre-production-to-production-sprint6-close.md`)

| Metric | Sprint 6 close | **Sprint 7 dry-run** | Δ |
|--------|---------------|----------------------|---|
| Required artifacts present | 11/14 | **12/14** | +1 (character profiles ✅) |
| Tests passing | 664 | **~870** | +206 |
| Stories closed (cumulative since Sprint 5) | 23 | **37** | +14 (Sprint 7 Must Have 14/18) |
| ADRs accepted | 14 | 14 | 0 |
| Tech debt items | 10 | 10 | 0 (TD-010 RESOLVED, TD-011 added) |
| VS Validation | 0/4 | 0/4 | 0 |

The kernel is now provably end-to-end runnable in tests. What's left is the **UI surface + 3 human playtests** that turn the kernel into a build a person can react to.

---

## Blockers (must resolve before re-running this gate)

1. **DispatchScreen UI integration** — Sprint 8 contractual: assemble the screen that lets a human player select a 3-hero formation, pick a floor, and press Dispatch. Per S7-M13 closure note, this is deliberately deferred to Sprint 8 because it requires UMG/Control wiring rather than kernel logic. The data harness is already proven; this is "wrap a button around it."
2. **3 playtest sessions** — Sprint 7 contractual (S7-M15/M16/M17): ≥3 internal playtest sessions documented at `production/playtests/`. Cannot complete autonomously.
3. **VS Validation items 1–4** — all four flow from blockers 1–2. None of the four can be satisfied without (a) a runnable build with a UI and (b) a human running it.

**Note on `production/playtests/`**: the directory does not exist yet. It will be created when the first playtest report is authored; do not pre-create empty.

---

## Recommendations

1. **Plan Sprint 8 explicitly toward VS PASS.** Sprint 8 scope:
   - Week 1: DispatchScreen UI (HeroRoster panel + FloorSelect panel + Dispatch button + ReturnView). Wire to existing orchestrator via the data harness already proven in S7-M13.
   - Week 1.5: First internal manual smoke session — author can drive a full dispatch end-to-end in a real Godot run, verify no crashes, capture screen recording.
   - Week 2: Playtest sessions #1, #2, #3 (S7-M15/M16/M17 carry-over). Document at `production/playtests/playtest-{01,02,03}-*.md`.
   - Week 2.5: `/gate-check production` — expected verdict **PASS** subject to playtest validation of "core fantasy delivered."
2. **Consider promoting S7-M15/M16/M17 to Sprint 8 carry-over** — they are gating Sprint 7 from PASSING, but they cannot complete without the Sprint 8 UI work. Carrying them forward removes the awkward "Sprint 7 is done except for 4 stories that physically cannot run yet" state.
3. **Do not run `/gate-check production` again until at least 1 playtest report exists.** The verdict will be the same.

---

## Stage advancement

`production/stage.txt` remains **`Pre-Production`**. Do not advance.

---

## Next steps

1. **Stand down on autonomous Sprint 7 work** — the autonomous portion is genuinely complete.
2. When you're ready for the human-driven phase: `/sprint-plan new` for Sprint 8 (explicitly: VS PASS as goal).
3. After Sprint 8's first playtest report exists at `production/playtests/`: re-run `/gate-check production`.

---

## Chain-of-Verification

5 challenge questions checked — verdict unchanged (FAIL):

1. *"Does the new character-profiles artifact change the verdict?"* — No. It moves required-artifacts from 11/14 to 12/14, but VS Validation 0/4 is hard-coded auto-FAIL.
2. *"Does the S7-M13 data-harness wiring count toward 'Vertical Slice is COMPLETE'?"* — Partially. Kernel is verified runnable, but the `Vertical Slice build` artifact requires a *playable build a human can interact with*, not a kernel that passes tests. The deferred UI is the gating piece.
3. *"Is there a path to PASS without playtest reports?"* — No. The gate definition explicitly requires `≥3 distinct playtest sessions documented in production/playtests/` before the Pre-Production → Production gate can advance.
4. *"Is the FAIL recoverable in Sprint 8?"* — Yes. Sprint 8 plan, when authored, can target VS PASS and the verdict will flip.
5. *"Are there blockers I missed?"* — No additional blockers found. Architecture traceability matrix is still missing (was missing in prior gates too) but is not gate-blocking at this stage.

**Verdict stands**: FAIL (auto-FAIL via VS Validation 0/4) — expected and informative; Sprint 8 has a clear path to PASS.
