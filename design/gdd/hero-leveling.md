# Hero Leveling System — GDD #15

> **Status: First-pass DRAFT 2026-05-06** by post-Sprint-14-prep autonomous-execution session. All 8 required sections (A–H) + 2 supplemental (I Open Questions, J Implementation Sequencing) per `.claude/docs/coding-standards.md`. Run `/design-review` before APPROVED. Replaces the S10-M4 stub `+1 level per floor clear` with a real XP-curve progression.

---

## A. Overview

**Hero Leveling** turns combat kills + floor clears into hero progression. Heroes accumulate XP from kills (per-tier amount) and floor clears (flat bonus); when XP crosses a per-level threshold, the hero auto-levels-up and the leftover XP carries to the next level. Levels feed into formation strength via `HeroRoster.get_formation_strength()`.

The system is fully signal-driven: `DungeonRunOrchestrator` receives `enemy_killed` + `floor_cleared_first_time` signals from itself (as the snapshot owner), translates them into XP grants on each formation hero via `HeroRoster.add_xp(instance_id, amount)`, and `HeroRoster` handles the threshold check + multi-level cascade if the XP gain is large enough to cross multiple thresholds.

Replaces the Sprint 10 S10-M4 stub `_grant_stub_levels_to_formation` (+1 level on floor clear), which was placeholder feedback with no per-class scaling. The real curve scales kill XP by enemy tier (kill a Tier 5 boss → 80 XP; kill a Tier 1 mob → 5 XP) so late-floor combat is meaningfully more rewarding.

---

## B. Player Fantasy

> *"Each kill makes my heroes a tiny bit stronger. Each floor clear is a real milestone. By Floor 5 my Tier 1 heroes are mid-leveled; by V1.0 prestige they're capped — earned, not handed over."*

The cozy register applies: leveling is **continuous, predictable, and fair**. The player should be able to look at a hero on Floor 3 and predict roughly when they'll level up next ("3 more kills"). No luck-based XP drops, no XP rares, no party-vs-solo XP split — every formation hero gets the same XP grant per kill.

Critical: **leveling is a felt-progression moment**, not a flow interrupter. The level-up chime (S12-M6 AC-AS-05) + level-up toast (S10-M4) play together; the run continues seamlessly. No "level-up screen" modal. The player observes "Theron reached level 4!" floating across, then keeps watching the run.

Cap-rate target (cozy register tunable): a player optimizing well should cap a Tier 1 hero (level 1 → 15) in ~30–40 dispatched runs of mixed-tier content. A player optimizing poorly should cap in ~80–100 runs. The 2.5× spread between optimizing-well and optimizing-poorly is the engagement curve.

---

## C. Detailed Rules

### C.1 XP grant per kill

Every kill grants XP to every formation hero who participated in the run (the formation array at dispatch time, not who currently has HP):

```
xp_per_kill(tier) = XP_PER_KILL[tier]
```

Default values (BASE_XP_PER_KILL, tunable in EconomyConfig or HeroLevelingConfig):
- Tier 1: 5 XP
- Tier 2: 10 XP
- Tier 3: 20 XP
- Tier 4: 40 XP
- Tier 5: 80 XP

The geometric ~2× scaling matches the gold scaling in BASE_KILL (10/35/80 ratio is 1:3.5:8) but is gentler — late-tier kills are roughly 16× early-tier kills, which keeps Floor 5 from trivializing earlier-floor leveling-up paths.

XP is granted to **each living formation hero** (formation_size = 3). A 60-kill run grants 300 XP to every hero in formation if all kills were Tier 1; 4800 XP if all were Tier 5.

### C.2 XP grant per floor clear

In addition to kill XP, the floor-clear milestone grants a flat XP bonus to every formation hero:

```
xp_per_floor_clear(floor_index) = XP_PER_FLOOR_CLEAR_BASE + (floor_index - 1) * XP_PER_FLOOR_CLEAR_STEP
```

Default values:
- XP_PER_FLOOR_CLEAR_BASE = 50
- XP_PER_FLOOR_CLEAR_STEP = 25

So Floor 1 clear = 50 XP, Floor 2 = 75, Floor 3 = 100, Floor 4 = 125, Floor 5 = 150. Linear scaling rewards deeper progression without runaway exponential.

### C.3 XP threshold per level

Hero levels up when accumulated XP crosses the threshold for the next level. Threshold is linear:

```
xp_threshold(current_level) = XP_THRESHOLD_BASE + XP_THRESHOLD_STEP * current_level
```

Default values:
- XP_THRESHOLD_BASE = 100
- XP_THRESHOLD_STEP = 50

So:
- Level 1 → 2 needs 100 + 50·1 = 150 XP
- Level 2 → 3 needs 100 + 50·2 = 200 XP
- Level 14 → 15 (cap) needs 100 + 50·14 = 800 XP
- Total XP from level 1 to LEVEL_CAP=15 = 150 + 200 + … + 800 = 6650 XP

### C.4 Multi-level cascade

If a single XP grant pushes the hero past multiple thresholds (e.g., Floor 5 clear of high-tier content giving 5000 XP to a level-1 hero), `HeroRoster.add_xp` cascades through level-ups in a loop:

```
func add_xp(id, amount):
    instance.xp += amount
    while instance.current_level < LEVEL_CAP:
        var threshold = xp_threshold(instance.current_level)
        if instance.xp < threshold:
            break
        instance.xp -= threshold
        instance.current_level += 1
        hero_leveled.emit(id, instance.current_level - 1, instance.current_level)
    if instance.current_level >= LEVEL_CAP:
        instance.xp = 0  # cap reached, XP overflow discarded
```

Each level crossed emits a separate `hero_leveled` signal (so the toast + chime fire per level). For a 5-level cascade, the player sees 5 toasts and hears 5 chimes — at the chime throttle rate (audio-system.md §F.2 throttles UI/Reward signals to ≤4/sec, so the cascade plays as a satisfying rapid sequence rather than overlapping cacophony).

### C.5 LEVEL_CAP overflow

When `current_level == LEVEL_CAP`, `add_xp` is a no-op (XP discarded silently — no negative feedback toast, per cozy register). Per `Economy.level_cost`, attempts to spend gold to level a capped hero return -1. The hero is "fully leveled" — their stat ceiling is set; further runs benefit only the formation's other heroes.

V1.0 prestige system (#31) will be the lever to reset capped heroes for further progression. MVP scope ends at the cap.

### C.6 Formation-membership determinism

XP is granted to the **formation slots at dispatch time**, NOT the formation slots at kill-time. If the player swaps a hero out via `FormationAssignment.set_formation_slot` during a run (mid-run reassignment per ADR-0001), the swapped-out hero KEEPS the XP they earned up to the swap point; the swapped-in hero earns from the swap point forward. No retroactive XP redistribution.

This is captured in `DungeonRunOrchestrator.run_snapshot.formation` (the snapshot's frozen formation), with mid-run reassignment updating the snapshot's formation atomically (per Story 008).

### C.7 Hydration suppression

When `HeroRoster._suppress_signals == true` (post-load hydration per ADR-0004), `add_xp` MUST NOT emit `hero_leveled`. The reason: hydration restores save-state including the hero's current_level + xp, which means no LEVEL-UP MOMENT happened — emitting the signal would fire the chime + toast for every hero post-load, which is jarring.

Implementation: `HeroRoster.add_xp` checks `_suppress_signals` before emit. Audio-system.md AC-AS-05 already guards against this on the AudioRouter side, but the test in `tests/unit/audio_router/audio_router_signal_handlers_test.gd:test_hero_leveled_chime_is_suppressed_during_hydration` asserts the AudioRouter side; the HeroRoster side is the canonical source.

### C.8 Save/Load surface

`HeroInstance.current_level` + `HeroInstance.xp` are already persisted via the existing 5-field HeroInstance schema (S11-M2b shipped this). No save-schema changes needed for this story. `HeroRoster.add_xp` mutates the in-memory state; the next save-trigger persists.

---

## D. Formulas

### D.1 XP-per-kill

`xp_per_kill(tier) = XP_PER_KILL[tier]` — flat per-tier values from §C.1.

### D.2 XP-per-floor-clear

`xp_per_floor_clear(floor_index) = XP_PER_FLOOR_CLEAR_BASE + (floor_index - 1) * XP_PER_FLOOR_CLEAR_STEP` from §C.2.

### D.3 XP-threshold per level

`xp_threshold(current_level) = XP_THRESHOLD_BASE + XP_THRESHOLD_STEP * current_level` from §C.3.

Cumulative XP to reach level N from level 1:
```
cumulative_xp(N) = sum(xp_threshold(i) for i in [1, N-1])
                 = (N - 1) * XP_THRESHOLD_BASE + XP_THRESHOLD_STEP * sum(i for i in [1, N-1])
                 = (N - 1) * (XP_THRESHOLD_BASE + XP_THRESHOLD_STEP * N / 2)
```

For N=15: 14 * (100 + 50 * 15 / 2) = 14 * 475 = 6650 XP. Matches §C.3.

### D.4 Cap-rate sanity check

Mid-tier run (~30 kills, mixed Tier 1-3, Floor 3 clear):
- Kill XP: 30 kills * avg(5+10+20)/3 = 30 * 11.67 ≈ 350 XP per hero
- Floor clear XP: 100
- Total per run: ~450 XP per hero

Runs to cap a Tier 1 hero (6650 XP): 6650 / 450 ≈ 15 runs.

This is FASTER than the §B Player Fantasy target (30-40 runs). Two interpretations:
- (a) The per-tier kill XP is too generous (lower BASE_XP_PER_KILL by 30-40%)
- (b) The Player Fantasy target was overcautious

OQ-15-1 calls out this discrepancy for the design-review pass. Defaults are conservative (favor player); playtest will calibrate.

---

## E. Edge Cases

### E.1 Multi-level cascade in one tick
Combat tick produces 5 enemy kills in one frame. Each kill grants XP to all 3 formation heroes. If any hero crosses 2+ thresholds, the cascade fires multiple `hero_leveled` signals in the same call stack. The audio chime throttle (audio-system.md §F.2 250ms window) absorbs the burst — at most ~4 chimes audible per second.

### E.2 Hero swap mid-cascade
The swap-out hero is mid-cascade (e.g., XP grant from kill 3 of 5 pushes them past level 4 → 5; mid-cascade the player swaps them out). The cascade completes for the original hero (their internal state updates fully) before the swap snapshot is captured. The swap-in hero earns XP from kill 4 onward — no XP redistribution.

### E.3 Save during cascade
Save-trigger fires while `add_xp` is mid-cascade. The persist captures the current_level at the persist moment (which may be mid-cascade — i.e., the level is mid-update). Since `add_xp` runs synchronously in a single call stack, save-triggers can only fire BEFORE or AFTER the entire `add_xp` completes (Godot's main-thread single-fiber execution). No partial-state corruption.

### E.4 Negative XP
`add_xp(id, -10)` is invalid. Implementation push_errors and returns without mutation per the project's `add_gold` / `try_spend` precedent. If a future "XP penalty" feature is added, it gets a separate `subtract_xp` method.

### E.5 Zero XP grant
`add_xp(id, 0)` is a no-op. Returns immediately without touching state, without emitting signals.

### E.6 LEVEL_CAP reached mid-cascade
Hero is at level 14 with 700 XP banked; kill grants 1500 XP. Cascade: level 14 → 15 (uses 800 of the 1500), then level 15 == LEVEL_CAP, so `instance.xp = 0` and the remaining 700 XP is discarded. One `hero_leveled(id, 14, 15)` emit. No silent overflow into level 16.

### E.7 Unknown class_tier in XP_PER_KILL Dictionary
If `enemy_killed` fires with a tier not in `XP_PER_KILL` (config drift), default to `XP_PER_KILL[1]` and push_warning. Defensive fallback prevents content-drift crashes.

### E.8 Hero deleted mid-grant
HeroRoster.add_xp(id) where `id` doesn't exist (orphan instance_id from a snapshot mid-deletion). Push_warning + early return per the existing `set_hero_level` pattern.

### E.9 Offline replay XP grants
During offline replay (per ADR-0014 + S12-M5), `enemy_killed` signals are suppressed; the `compute_offline_batch` aggregation provides a kills-by-tier dict. The orchestrator's offline-XP-grant path translates the dict into a single batch `add_xp` call per hero (sum of all kills' XP) plus per-floor-clear XP for each `floors_cleared_in_window` entry. This means the cascade is still capped to a single hero's XP gain but happens post-replay rather than per-tick. The OfflineSummary carries `hero_levels_gained: Dictionary[int, int]` (V1.0 forward-compat field already in audio-system.md / offline-progression-engine.md) which the Return-to-App Screen renders.

### E.10 Hydration leveling-suppression
Per §C.7, `add_xp` skips emit during `_suppress_signals == true`. Save-loaded heroes have their level + XP restored without firing chimes/toasts.

---

## F. Dependencies

### Hard dependencies (Hero Leveling requires these to function)

| System | Why | Surface used |
|---|---|---|
| `HeroRoster` (#9) | Hero state owner | `add_xp(id, amount)` (NEW), `set_hero_level`, `hero_leveled` signal |
| `DungeonRunOrchestrator` (#13) | Signal source for kills + clears | `enemy_killed` + `floor_cleared_first_time` subscribers |
| `Economy` (#5) | Config storage for XP constants | `EconomyConfig.XP_PER_KILL`, `XP_PER_FLOOR_CLEAR_*`, `XP_THRESHOLD_*` |
| `AudioRouter` (#28) | Level-up chime | `hero_leveled` signal subscriber per audio-system.md AC-AS-05 |
| `OfflineProgressionEngine` (#12) | Offline replay XP grant batching | Orchestrator's `flush_offline_signals` aggregates kills-by-tier; XP grants happen post-replay |

### Signal-source dependencies

Hero Leveling subscribes to NO new signals. It's a thin layer over the existing kill + floor-clear surface in DungeonRunOrchestrator.

### Reverse dependencies (systems that depend on Hero Leveling)

- **Combat Resolution** (#11) — `formation_strength` reads `current_level`; HP/DPS scale with it (no API change, just behavior)
- **Recruit Screen** (#21) — displays cost-to-level via `Economy.level_cost(tier, current_level + 1)`
- **Roster / Hero Detail Screen** (#22) — displays level + XP-to-next-level progress bar
- **DungeonRunView** (S10-M4 toast) — already wired via `hero_leveled` signal subscriber

---

## G. Tuning Knobs

### XP_PER_KILL (Dictionary[int, int])
- Tier 1: 5
- Tier 2: 10
- Tier 3: 20
- Tier 4: 40
- Tier 5: 80
- Range: int 1–500 per tier (sub-1 produces no felt progression; super-500 caps mid-tier-1 heroes in 2 runs)

### XP_PER_FLOOR_CLEAR_BASE (int = 50)
- Range: 0–500. 0 disables floor-clear bonus (kills only). 500 makes floor clears 10× a Tier 5 kill.

### XP_PER_FLOOR_CLEAR_STEP (int = 25)
- Range: 0–100. 0 makes Floor 1 = Floor 5 (flat bonus). 100 makes Floor 5 clear 5× the Floor 1 clear.

### XP_THRESHOLD_BASE (int = 100)
- Range: 50–500. 50 makes level 1→2 trivially fast (1-2 kills); 500 makes the early game slow.

### XP_THRESHOLD_STEP (int = 50)
- Range: 0–200. 0 = flat XP curve (every level needs XP_THRESHOLD_BASE). 200 = aggressive late-game grind.

### LEVEL_CAP (int = 15)
- Already documented in EconomyConfig per S12-N5. Range 1–20 per the existing @export_range.

### Per-cue feedback knobs
- Audio chime throttle: 250ms (audio-system.md §F.2). 5-level cascade plays 4 chimes max in the 1-second window.
- Toast linger: 3.0 s (S10-M4). Stacked toasts use vertical offset so multiple level-ups in cascade stay visible.

---

## H. Acceptance Criteria

**AC-15-01 — XP grant per kill matches Formula D.1**
For each tier 1..5, `enemy_killed(tier, ...)` causes each formation hero's `xp` to increase by `XP_PER_KILL[tier]`.

**AC-15-02 — XP grant per floor clear matches Formula D.2**
`floor_cleared_first_time(floor_index, biome_id, losing_run)` causes each formation hero's `xp` to increase by `XP_PER_FLOOR_CLEAR_BASE + (floor_index - 1) * XP_PER_FLOOR_CLEAR_STEP`.

**AC-15-03 — Single level-up at threshold crossing**
Hero with current_level=1, xp=149 (one short of threshold 150). Grant 1 XP. Hero's current_level=2, xp=0; `hero_leveled(id, 1, 2)` emitted exactly once.

**AC-15-04 — Multi-level cascade emits per-level signals**
Hero with current_level=1, xp=0. Grant 1000 XP. Hero advances through levels 2, 3, 4, 5 (cumulative thresholds: 150 + 200 + 250 + 300 = 900); 100 XP carried into level 5. `hero_leveled` emitted 4 times: (1→2), (2→3), (3→4), (4→5). Final state: current_level=5, xp=100.

**AC-15-05 — LEVEL_CAP discards overflow**
Hero with current_level=14, xp=799 (one short of level 15 threshold 800). Grant 5000 XP. Hero advances to level 15 (using 800 of the 5000 XP); remaining 4200 XP discarded; instance.xp == 0 post-grant. `hero_leveled(id, 14, 15)` emitted exactly once.

**AC-15-06 — XP grant respects formation determinism**
Run starts with formation [hero_a, hero_b, hero_c]. Mid-run, swap hero_a out for hero_d. Subsequent kills grant XP to [hero_d, hero_b, hero_c] — hero_a's XP is frozen at the swap moment.

**AC-15-07 — Hydration suppression**
With `HeroRoster._suppress_signals == true`, calling `add_xp(id, large_amount)` mutates xp + current_level but does NOT emit `hero_leveled`. Audio chime (S12-M6 AC-AS-05) does not fire.

**AC-15-08 — Negative XP is push_error + no-op**
`add_xp(id, -10)` calls push_error; instance.xp + current_level unchanged; no signal emitted.

**AC-15-09 — Zero XP is silent no-op**
`add_xp(id, 0)` returns immediately; no state change, no signal.

**AC-15-10 — Unknown tier defaults to Tier 1**
`enemy_killed(tier=99, ...)` (config-drift scenario) grants `XP_PER_KILL[1]` (= 5 by default). push_warning logged.

**AC-15-11 — Offline replay XP batched correctly**
After offline replay completes (per ADR-0014), each formation hero's XP gain matches:
`sum(XP_PER_KILL[tier] * kills_by_tier[tier] for tier in 1..5) + sum(XP_PER_FLOOR_CLEAR(f) for f in floors_cleared_in_window)`. Cascade fires post-replay (slow-path replayed by S12-M5 + S13-S1 buffered-replay infrastructure).

**AC-15-12 — Save round-trip preserves level + xp**
Hero with current_level=7, xp=125. Save → load. Hero has current_level=7, xp=125. No spurious `hero_leveled` emit during hydration.

**AC-15-13 — Capped hero gold spend returns -1**
Hero with current_level=15 (LEVEL_CAP). `Economy.level_cost(tier, 15)` returns -1 per existing S12-N5 contract. Manual gold-spend UI must check this and disable the level-up button.

**AC-15-14 — Stub +1-per-clear grant removed from Orchestrator**
`grep _grant_stub_levels_to_formation src/core/dungeon_run_orchestrator/dungeon_run_orchestrator.gd` returns no matches. Replaced by `_grant_xp_to_formation` calling `HeroRoster.add_xp` per the formulas above.

---

## I. Open Questions & ADR Candidates

**OQ-15-1 — Cap-rate calibration**
Per Formula D.4 worked example, mid-tier runs cap a hero in ~15 runs vs. the §B Player Fantasy target of 30-40. Either the formulas are too generous OR the Player Fantasy target was overcautious. **Resolution path**: lock the formulas as drafted; calibrate via playtest after Sprint 14 implementation. Adjust XP_PER_KILL by ±30% per playtest evidence.

**OQ-15-2 — Stat scaling per level**
This GDD specifies XP grant + level-up; it does NOT specify how level affects HP/DPS. Combat Resolution (#11) currently uses `formation_strength` which sums `current_level` across formation. The exact HP/DPS multiplier per level is in combat-resolution.md §D.3 (`HP_PER_LEVEL`, `DPS_PER_LEVEL`). This GDD does NOT change those — Hero Leveling is the EARN side; Combat is the SPEND side.

**OQ-15-3 — Per-class XP modifier?**
Should "Mage" levels faster than "Warrior" (or vice versa)? MVP says NO — flat per-tier XP grants regardless of class. Sprint 15+ may add a `class.xp_multiplier` field if playtest reveals one class is consistently underleveled.

**OQ-15-4 — XP gain visualization**
Should the dungeon_run_view show floating "+5 XP" numbers on each kill? MVP says NO — keep the cozy register clean. Level-up toast is the visible feedback. Sprint 15+ may add an XP bar to the per-hero display in the formation_assignment screen.

**OQ-15-5 — Per-class XP requirement scaling?**
Should Tier 2 classes (Mage with BASE_RECRUIT 8000) have higher XP_THRESHOLD than Tier 1 (Warrior 150)? MVP says NO — flat threshold across all classes. The recruit cost is the gate on Tier 2 access; once recruited, leveling is uniform.

**OQ-15-6 — Capped hero retirement / prestige**
LEVEL_CAP=15 is a real ceiling. V1.0 prestige system (#31) is the intended lever to recycle capped heroes for further progression. MVP locks the ceiling; prestige is post-MVP scope.

---

## J. Implementation Sequencing (Sprint 14+ candidate)

This GDD is design-first; implementation is Sprint 14 S14-M4 scope. Pre-sequenced as 4 stories totaling ~1.5 days:

1. **Story 1 (~0.25d)** — EconomyConfig additions: 5 new constants (`XP_PER_KILL`, `XP_PER_FLOOR_CLEAR_BASE`, `XP_PER_FLOOR_CLEAR_STEP`, `XP_THRESHOLD_BASE`, `XP_THRESHOLD_STEP`). Update `assets/data/config/economy_config.tres` with the §C defaults.
2. **Story 2 (~0.5d)** — `HeroRoster.add_xp(id, amount) -> bool`: pure XP-mutation + multi-level cascade per §C.4. Hydration suppression check. Tests for ACs 15-03, 15-04, 15-05, 15-07, 15-08, 15-09.
3. **Story 3 (~0.5d)** — Replace `DungeonRunOrchestrator._grant_stub_levels_to_formation` with `_grant_xp_to_formation` that subscribes to `enemy_killed` + `floor_cleared_first_time` and calls `add_xp` per the formulas. Tests for ACs 15-01, 15-02, 15-06, 15-10, 15-14.
4. **Story 4 (~0.25d)** — Offline replay path: orchestrator's `flush_offline_signals` aggregates kills_by_tier; post-flush, dispatch a single batch `add_xp` call per hero with the summed XP. Tests for AC-15-11.

Total Sprint 14 scope: ~1.5 days. Matches the sprint-14.md S14-M4 estimate.

---

## Notes

- Authored 2026-05-06 by post-Sprint-14-prep autonomous-execution session. Drafted to unblock Sprint 14 S14-M4 (real XP curve + Hero Leveling GDD).
- All ACs are testable via the patterns documented in `tests/PATTERNS.md`.
- This GDD has NOT yet had a `/design-review` pass. Run before declaring APPROVED. Expect review to surface ~5–10 BLOCKING items per the audio-system.md / recruitment-system.md / settings GDD precedent.
- Closes the design-coverage gap for Hero Leveling that has existed since the Sprint 1 GDD-authoring pass — systems-index.md row 15 has been "Not Started" since project inception.
