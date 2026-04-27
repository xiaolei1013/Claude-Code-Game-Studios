# Story 006: tick_fired subscribe + drip per tick (active dungeon)

> **Epic**: economy-system
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/economy-system.md` §H-01, §H-04 (drip half), §C.2.1 (drip rule)
**Requirements**: TR-economy-003 (subscribe `tick_fired` 20 Hz; never `_process(delta)`), TR-economy-005 (drip formula), TR-time-006 (forbidden `_process(delta)` as economy input)
*(Full requirement text lives in `docs/architecture/tr-registry.yaml`.)*

**Governing ADR(s)**: ADR-0005 (Time System dual-clock contract — `tick_fired(tick_number: int)` synchronous) + ADR-0013 (drip formula + `_on_tick` handler shape)
**ADR Decision Summary**: Economy MUST subscribe to `TickSystem.tick_fired` in `_ready()` and handle in `_on_tick(tick_number: int) -> void`. The handler reads `HeroRoster.get_formation_strength()`, `MATCHUP_DRIP_BONUS`, `BASE_DRIP[floor_index]`, and adds the floor()-truncated drip via `add_gold`. During offline replay (`_is_offline_replay == true`), the handler MUST early-return — replay uses the closed-form path in Story 010.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `signal.connect(callable)` returns OK; `floori()` integer truncation; signal subscribe in `_ready()` rank-safe per ADR-0003 Amendment #1.

**Control Manifest Rules (Core Layer, Economy)**:
- **Required**: subscribe `tick_fired` in `_ready()`. — ADR-0005 + ADR-0013
- **Forbidden**: `process_delta_as_economy_input` — Economy MUST NOT read `_process(delta)` for economy math. — ADR-0005
- **Forbidden**: emit `gold_changed` during `_is_offline_replay == true` (handled by `add_gold` itself). — ADR-0013
- **Required**: drip formula uses `floori()`-truncated integer arithmetic only; no float accumulation across ticks. — ADR-0013

---

## Acceptance Criteria

- [ ] **TR-economy-003**: `_ready()` connects `TickSystem.tick_fired` to `_on_tick`; the handler signature is `func _on_tick(tick_number: int) -> void`
- [ ] **TR-time-006**: no reference to `_process(delta)` exists in `economy.gd` (CI grep enforced in Story 013)
- [ ] **H-01 (drip rate)**: GIVEN active dungeon on floor 3, `formation_strength_factor = 1.2`, `matchup_drip_factor = 1.0`, `BASE_DRIP[3] = 7`, WHEN one tick fires, THEN `add_gold(8)` is called with EXACTLY `floor(7 × 1.2 × 1.0) = 8`; raw int64 balance reflects exact amount
- [ ] **H-04 (matchup drip half)**: drip computation reads `MATCHUP_DRIP_BONUS` (default 1.0; per-class overrides not in MVP)
- [ ] During `_is_offline_replay == true`, the handler early-returns; `add_gold` is NOT called from this path
- [ ] When no dungeon run is active (Orchestrator state), the handler MUST NOT call `add_gold` (no drip outside ACTIVE state)
- [ ] When formation is empty (`get_formation_strength()` returns the empty-formation guard value), drip is zero or skipped

---

## Implementation Notes

*Derived from ADR-0013 §Decision §drip path + ADR-0005 §tick_fired contract:*

- Pseudocode:
  ```
  func _ready() -> void:
      TickSystem.tick_fired.connect(_on_tick)
      # ... other init

  func _on_tick(tick_number: int) -> void:
      if _is_offline_replay:
          return  # offline replay uses closed-form path; foreground tick must not double-credit
      if not _is_active_run():  # query DungeonRunOrchestrator state — see Implementation Notes below
          return
      var floor_index := DungeonRunOrchestrator.current_floor_index()
      var fs := HeroRoster.get_formation_strength()  # range [1.0, 3.0]; empty-formation guard returns 1.0 sentinel per ADR-0012
      var base := EconomyConfig.BASE_DRIP[floor_index - 1]
      var drip := floori(base * fs * EconomyConfig.MATCHUP_DRIP_BONUS)
      if drip > 0:
          add_gold(drip)
  ```
- `_is_active_run()` is a stub helper that reads from `DungeonRunOrchestrator` (Feature epic, not yet implemented). For this story's tests, **inject a mock orchestrator** rather than depending on the real one. The story is unblocked even before DungeonRunOrchestrator lands.
- Similarly mock `HeroRoster.get_formation_strength()` for unit tests.
- `floori()` is the Godot 4.6 integer-truncation builtin. Use it (not `int(floor(...))`).
- The offline-replay early-return is critical — without it, the offline batch in Story 010 would double-credit (closed-form + per-tick replay).

---

## Out of Scope

- Story 007: `enemy_killed` signal handling (kill bonus is separate from drip)
- Story 010: closed-form `compute_offline_batch` path (the replay alternative to per-tick drip)
- Real DungeonRunOrchestrator integration — Feature-layer epic; mock here for unit tests
- Real HeroRoster integration — Feature-layer epic; mock for unit tests

---

## QA Test Cases

- **AC H-01: drip math correctness**
  - **Given**: mock orchestrator returning `current_floor_index() == 3` and `_is_active_run() == true`; mock roster returning `get_formation_strength() == 1.2`; EconomyConfig with `BASE_DRIP[2] == 7` and `MATCHUP_DRIP_BONUS == 1.0`; `_gold_balance = 0`
  - **When**: `_on_tick(N)` is called for any N
  - **Then**: `_gold_balance == 8` (= floori(7 × 1.2 × 1.0)); one `gold_changed(8, 8, "add_gold")` emission
  - **Edge cases**: `formation_strength = 1.0` → drip = 7; `formation_strength = 3.0` → drip = floori(21) = 21; floor 1 (BASE_DRIP[0] = 2, fs=1.0) → drip = 2

- **AC: floor() truncation**
  - **Given**: `BASE_DRIP[2] = 7`, `formation_strength = 1.2`, `MATCHUP_DRIP_BONUS = 1.5` (test override) → `7 × 1.2 × 1.5 = 12.6`
  - **When**: tick fires
  - **Then**: drip = `floori(12.6) = 12`, NOT 13 (round) and NOT 12.6 (float)
  - **Edge cases**: drip computation just below an integer boundary (e.g., 12.999) → 12

- **TR-economy-003: tick_fired subscription**
  - **Given**: Economy autoload booted
  - **When**: introspect signal connections via `TickSystem.tick_fired.get_connections()`
  - **Then**: at least one connection points to `economy._on_tick`
  - **Edge cases**: disconnect-then-reconnect cycle in test must restore drip behavior

- **AC: offline-replay early return**
  - **Given**: `_is_offline_replay = true`; mock active run; mock formation strength = 1.2; floor = 3
  - **When**: `_on_tick(N)` is called
  - **Then**: `_gold_balance == 0`; **zero** `add_gold` calls; **zero** `gold_changed` emissions
  - **Edge cases**: flag-flip mid-test must restore foreground drip

- **AC: no active run → no drip**
  - **Given**: mock orchestrator returning `_is_active_run() == false`
  - **When**: tick fires
  - **Then**: no `add_gold` call; balance unchanged
  - **Edge cases**: orchestrator IDLE/RESOLVING/CLEARED states all suppress drip; only ACTIVE permits it

- **AC: empty formation guard**
  - **Given**: mock roster `get_formation_strength()` returns ADR-0012's empty-formation sentinel (1.0)
  - **When**: tick fires on active run
  - **Then**: drip computed at base × 1.0 (i.e., baseline drip is allowed even with empty formation per ADR-0012 sentinel — confirm against ADR-0012 §empty-formation guard intent before locking)
  - **Edge cases**: explicit "empty roster" semantic in ADR-0012 — read fresh

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/economy/economy_drip_per_tick_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (autoload), Story 002 (EconomyConfig with BASE_DRIP), Story 003 (`add_gold` body), Sprint 1's TickSystem (rank 0, `tick_fired` signal)
- **Unlocks**: Story 010 (offline batch closed-form path mirrors this math); DungeonRunOrchestrator Feature epic
