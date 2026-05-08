# Story 007: enemy_killed signal handler + kill bonus

> **Epic**: economy-system
> **Status**: Complete (system shipped; see systems-index Implementation Status #5. Test evidence: `tests/unit/economy/`. Per-story AC checkbox tick-through deferred to a dedicated audit pass.)
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/economy-system.md` §H-02, §H-04 (kill half), §C.2.2 (kill rule)
**Requirements**: TR-economy-007 (BASE_KILL + MATCHUP_GOLD_MULTIPLIER), TR-enemy-db-012 (Orchestrator emits `enemy_killed(tier, matchup_advantage)`)
*(Full requirement text lives in `docs/architecture/tr-registry.yaml`.)*

**Governing ADR(s)**: ADR-0013 (kill-bonus rule + Orchestrator-applies-LOSING invariant)
**ADR Decision Summary**: Economy subscribes (or is invoked) on per-kill events. Kill bonus = `floor(BASE_KILL[enemy_tier] × MATCHUP_GOLD_MULTIPLIER if matchup_advantage else BASE_KILL[enemy_tier])`. Bonus credited once per kill (not per tick). Orchestrator's `_attribute_kill_gold` may apply `LOSING_RUN_LOOT_FACTOR` BEFORE calling Economy — Economy receives the post-factor amount.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Boolean payload in signal arity; signal connection rank-safe at `_ready()`; `floori()` integer truncation.

**Control Manifest Rules (Core Layer, Economy)**:
- **Required**: kill bonus credited via `add_gold` (canonical mutation site). — ADR-0013
- **Required**: Orchestrator-applies-LOSING invariant — Economy reads NEITHER `losing_run` NOR `LOSING_RUN_LOOT_FACTOR`. — ADR-0013
- **Forbidden**: re-applying `MATCHUP_GOLD_MULTIPLIER` per tick (only per kill). — ADR-0013

---

## Acceptance Criteria

- [ ] **H-02**: GIVEN Tier-2 enemy dies during active run, `matchup_advantage = true`, `BASE_KILL[2] = 35`, `MATCHUP_GOLD_MULTIPLIER = 1.5`, WHEN Economy receives `enemy_killed(2, true)`, THEN gold increases by EXACTLY `floor(35 × 1.5) = 52`; bonus is applied ONCE (not per tick); no additional drip adjustment from this event
- [ ] **H-04 (kill half)**: kill bonus reads `MATCHUP_GOLD_MULTIPLIER = 1.5` from EconomyConfig; matchup state read at the kill moment, not from cached earlier value
- [ ] No-matchup-advantage path: `enemy_killed(tier, false)` credits `floor(BASE_KILL[tier] × 1.0) = BASE_KILL[tier]`
- [ ] Tier coverage: tier 1 → 10 (no advantage) / 15 (advantage); tier 2 → 35 / 52; tier 3 → 80 / 120
- [ ] Unknown tier (out of `BASE_KILL` keys): `push_error("Economy.enemy_killed: tier=X has no BASE_KILL entry")`; no credit
- [ ] During `_is_offline_replay == true`: kills are processed via closed-form / batch-event path in Story 010, NOT this handler — handler MUST early-return when flag set

---

## Implementation Notes

*Derived from ADR-0013 §Decision §kill-bonus path:*

- Two viable subscription patterns; pick one and document:
  - **Pattern A (signal subscribe)**: `_ready()` connects to `DungeonRunOrchestrator.enemy_killed`. Pro: Economy stays passive. Con: requires Orchestrator to exist before Economy `_ready()` (rank ordering — Economy is rank 3, Orchestrator rank 14, so signal SUBSCRIPTION at Economy `_ready()` to a not-yet-instantiated higher-rank node may not work — verify via ADR-0003 Amendment #1).
  - **Pattern B (called by Orchestrator)**: Orchestrator calls `Economy.attribute_kill_gold(tier, matchup_advantage)` directly. Pro: rank-safe. Con: another public API surface.
- **Recommendation**: Pattern B. ADR-0003 Amendment #1 establishes that signal subscription across rank pairs at `_ready()` is safe **for already-instantiated higher-rank nodes**, but Orchestrator (rank 14) does NOT exist when Economy (rank 3) `_ready()` runs. Use a direct method call from Orchestrator.
- Pseudocode (Pattern B):
  ```
  func attribute_kill_gold(tier: int, matchup_advantage: bool) -> void:
      if _is_offline_replay:
          return  # offline path handles kills via closed-form
      if not EconomyConfig.BASE_KILL.has(tier):
          push_error("Economy.attribute_kill_gold: tier=%d has no BASE_KILL entry" % tier)
          return
      var base: int = EconomyConfig.BASE_KILL[tier]
      var bonus: int
      if matchup_advantage:
          bonus = floori(base * EconomyConfig.MATCHUP_GOLD_MULTIPLIER)
      else:
          bonus = base
      add_gold(bonus)
  ```
- Add `attribute_kill_gold` to the public API surface (it's the 8th public method — note this is consistent with ADR-0013 §Decision when including the read API; verify against the ADR's exact method enumeration when this story is picked up — if ADR strictly says "7 methods", consider folding kill-bonus into a different surface or proposing an ADR amendment).
- DO NOT apply `LOSING_RUN_LOOT_FACTOR` here. The Orchestrator's `_attribute_kill_gold` GDD §D.1 already applies it before calling Economy. Economy receives post-factor amounts.

---

## Out of Scope

- Story 010: offline replay batch-event path for kills
- DungeonRunOrchestrator's `enemy_killed` emission (Feature epic)
- `LOSING_RUN_LOOT_FACTOR` application (Orchestrator's job)

---

## QA Test Cases

- **AC H-02: kill with matchup advantage**
  - **Given**: EconomyConfig with `BASE_KILL == {1: 10, 2: 35, 3: 80}`, `MATCHUP_GOLD_MULTIPLIER == 1.5`; `_gold_balance = 0`; `_is_offline_replay = false`
  - **When**: `attribute_kill_gold(2, true)` called once
  - **Then**: `_gold_balance == 52` (= floori(35 × 1.5)); one `gold_changed(52, 52, "add_gold")` emission
  - **Edge cases**: `attribute_kill_gold(1, true)` → 15; `attribute_kill_gold(3, true)` → 120

- **AC: kill without matchup advantage**
  - **Given**: same config; `_gold_balance = 0`
  - **When**: `attribute_kill_gold(2, false)`
  - **Then**: `_gold_balance == 35`
  - **Edge cases**: tier 1 → 10; tier 3 → 80

- **AC: bonus applied once per kill (not per tick)**
  - **Given**: 0 gold; one kill event
  - **When**: `attribute_kill_gold(2, true)` called; followed by `_on_tick(N)` with no orchestrator-active mock OR with active run + no further kill
  - **Then**: gold increases by 52 ONCE on the kill; subsequent ticks add only the drip portion (verified separately via Story 006 drip test); no double-credit
  - **Edge cases**: simulating 100 ticks between two kills must not synthesise extra kill bonuses

- **AC: unknown tier defensive**
  - **Given**: any state
  - **When**: `attribute_kill_gold(99, true)`
  - **Then**: `push_error`; no credit; no signal
  - **Edge cases**: tier 0 also rejected (BASE_KILL only has 1/2/3)

- **AC: offline-replay suppression**
  - **Given**: `_is_offline_replay = true`
  - **When**: `attribute_kill_gold(2, true)`
  - **Then**: balance unchanged; no `add_gold` call; no signal
  - **Edge cases**: flag-flip mid-test must restore foreground behavior

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/economy/economy_kill_bonus_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (autoload), Story 002 (EconomyConfig.BASE_KILL + MATCHUP_GOLD_MULTIPLIER), Story 003 (`add_gold` body)
- **Unlocks**: Story 010 (offline batch reuses kill-bonus formula), DungeonRunOrchestrator (calls this method)
