# Playtest 02 — Mid-Game Pacing (S8-M6)

> **Sprint Mapping**: S8-M6 (sprint-8.md "Playtest session #2 — mid-game pacing")
> **AC**: covers 2nd or 3rd dispatch including offline-aware ticks if applicable
> **Status**: Complete — observations rolled forward from S8-M5 session (multi-dispatch happened in same session)

## Session Info

- **Date**: 2026-04-28
- **Build**: post-S8-M4 hotfix bundle
- **Duration**: ~10 minutes (3 dispatches back-to-back during S8-M5 session)
- **Tester**: Project lead
- **Platform**: macOS (Apple M2 Max, Godot 4.6.1.stable.mono)
- **Input Method**: Mouse
- **Session Type**: Targeted test — multi-dispatch pacing

## Test Focus

**Hypothesis under test**: a player who has already completed one dispatch cycle finds the *2nd and 3rd dispatch* feel meaningfully different — either pace shifts, harder enemies, or different choices. The "feel" of the loop on N=2 and N=3 reveals whether the kernel produces interesting variation or feels samey.

**Boundaries**:
- Sprint 8 VS scope: only `forest_reach` floor 1 unlocked. Multi-floor variation isn't testable.
- Offline-aware ticks: confirmed NOT testable in current build (deferred to S8-M7).

## Setup Used

1. F5 → fresh first-launch
2. Walked first dispatch cycle (S8-M5 main session)
3. Tap "Go to Dispatch" on Main Menu → start of 2nd dispatch
4. Repeat for 3rd dispatch
5. Captured ticks + kill_counts across all 3 runs

## Per-Dispatch Observations

### Dispatch #1 (from S8-M5)
- **Run duration (ticks at RUN_ENDED)**: 141 ticks ≈ 7s wall-clock
- **Final kill_count**: 3
- **Felt**: tester saw the run briefly; perceptible but short

### Dispatch #2
- **Setup time** (Main Menu → Dispatch tap): seconds (single button tap)
- **Roster state**: Theron (warrior Lv1) — same as #1, no level/XP change observable
- **Formation state**: persisted from #1 — Theron still in slot 0
- **Run duration (ticks at RUN_ENDED)**: 338 ticks ≈ 17s wall-clock
- **Final kill_count**: 3
- **Felt different from #1?**: Slightly — #2 was longer (17s vs 7s) but produced same kill_count
- **Notes**: Same formation, same floor, same outcome (3 kills). Only timing differed — and that variance is RNG-driven, not strategy-driven.

### Dispatch #3
- **Setup time**: seconds
- **Roster state**: Theron (warrior Lv1) — unchanged
- **Formation state**: Theron still in slot 0
- **Run duration (ticks at RUN_ENDED)**: ~10 ticks ≈ <1s wall-clock (run resolved during/just-after FADE_TO_BLACK)
- **Final kill_count**: 3
- **Felt different from #1 or #2?**: Yes — but in a BAD way. So fast it didn't register as "watching a run."
- **Notes**: Tester verbatim: "_it go to next scene but almost immediately go back to the main scene_". The screen swap happened but the run was effectively invisible.

## Pacing Analysis

- **Run duration variance across 3 dispatches**: **141 ticks → 338 ticks → ~10 ticks**. Order-of-magnitude swings (~7s → ~17s → <1s) with the same formation + same floor.
- **Kill count variance**: 3 / 3 / 3 — completely stable outcome despite wildly varying duration
- **Did the player feel motivated to dispatch a 4th time?**: No — the 3rd was so fast it broke the loop's perceptual rhythm
- **Felt repetitive after #2?**: Yes (deterministic outcome + same formation + same floor)
- **Felt rewarding even if repetitive?**: No — sub-second runs produce no satisfaction loop

## State Persistence Check

- **Did formation slot assignment persist across cycles?**: Yes — Theron stayed in slot 0 across all 3 cycles (in-memory state retained; no save file written)
- **Did Theron's level/XP persist?**: No level change observed — Theron stayed Lv1. Either combat doesn't grant XP yet OR XP grant is wired but with no audible/visible feedback (couldn't tell).
- **Were any heroes added between cycles?**: No (Recruit flow not yet wired — expected for Sprint 8 scope)

## Offline-Aware Ticks (if applicable)

**Verdict**: NOT testable in current build.

- Save-persist pipeline isn't actually writing to disk (confirmed by `~/Library/Application Support/Godot/app_userdata/Lantern Guild/` having no save file after multiple completed runs that should have triggered scene_boundary_persist).
- Without save persistence, offline computation has nothing to bridge across a background→resume cycle.
- Defer offline mechanics evaluation to **S8-M7 dedicated test**, with explicit caveat that the infrastructure may not exist yet.

## Feature-Specific Feedback

### Multi-dispatch loop UX
- **Returning to MainMenu after each run feels appropriate?**: Mostly — the cross-fade is smooth, but the run-end overlay's 0ms dwell makes the transition feel jarring rather than ritual.
- **"Go to Dispatch" on MainMenu → formation_assignment is the right shortcut?**: Yes — the loop closes correctly mechanically.
- **Missing: a "play again" button that skips formation_assignment?**: Wanted. Tester didn't change anything between dispatches (same formation, same floor) — having to re-traverse formation_assignment for each cycle is friction. Sprint 9 polish: optional "Re-dispatch" button on main_menu's run-end UI.

### Run-end overlay dwell
- **Did the dwell on the run-end overlay feel right?**: Too short
- **Sprint 8 default is 0ms dwell** — feels rushed, NOT natural. **Recommend bumping to 1500-2000ms for Sprint 9 polish** (Story 013 spec allows up to 350ms; would need a spec amendment to go higher).

## Bugs Encountered

| # | Description | Severity | Reproducible |
|---|-------------|----------|--------------|
| - | None new — same 5 hotfixes from S8-M4 covered the bugs surfaced. The "extreme variance in run duration" is a tuning issue, not a bug. | - | - |

## Pillar Alignment Check (mid-game lens)

| Pillar | Description | Score (1-5) | Notes |
|---|---|---|---|
| 1 | Respect the Player's Time | 2/5 | Multi-dispatch loop is fast in the OPPOSITE direction — too fast. Pillar 1 isn't "be fast", it's "be the right speed." Sub-second runs fail this. |
| 2 | Decisions Matter | 1/5 | 3 dispatches with identical formation produced 3 identical kill_counts in wildly different wall-times. The decision (which formation, which floor) didn't change the outcome — only the timing did. That's RNG without consequence. |
| 3 | Cozy / No-Fail | 3/5 | Cozy is undermined by jittery pacing. No-fail is honored (no failure state). |
| 4 | (4th pillar) | -/5 | Tester to fill in |

## Top 3 Priorities

1. **Run pacing tuning + minimum-perceived-duration** — same as S8-M5 P2; this session reinforces it. Sprint 9 ticket.
2. **"Re-dispatch" shortcut on main_menu** — multi-dispatch loop friction. Lower priority Sprint 9 polish.
3. **XP/level grant feedback** — Theron stayed Lv1 across 3 dispatches. Either grant is missing or feedback is missing; either way it's a Pillar 2 issue (decisions don't matter if the hero never grows).

---

## Verdict

- [x] **AC satisfied**: 2nd/3rd dispatch covered. Offline-aware ticks NOT testable — documented as carryover to S8-M7 + Sprint 9.

**Overall**: **PASS WITH NOTES** — multi-dispatch loop closes mechanically; pacing + outcome-variance are the headline findings. Reinforces S8-M5's Pillar 2 concerns.

**Next**: S8-M7 (offline + return-to-app) using `production/playtests/playtest-03-offline-return-2026-04-28.md`.
