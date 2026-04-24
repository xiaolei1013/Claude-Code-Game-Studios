# Story 005: First-launch bootstrap and `offline_elapsed_seconds` one-shot emission

> **Epic**: tick-system
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/game-time-and-tick.md`
**Requirements**: TR-time-004, TR-time-016, TR-time-030, TR-time-033
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0005: Time System Dual-Clock Contract
**ADR Decision Summary**: `offline_elapsed_seconds` is a one-shot signal fired exactly once per cold launch, guarded by an in-process bool that is never persisted; first-launch bootstrap seeds `last_persist_ts = session_high_water = t_current` and emits `offline_elapsed_seconds(0.0, false)` before the first `tick_fired`.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: No post-cutoff engine APIs used in this story.

**Control Manifest Rules (Foundation Layer, TickSystem)**:
- **Required**: `offline_elapsed_seconds(seconds, cap_reached)` is a one-shot signal fired exactly once per cold launch; in-process flag NOT persisted; BG↔FG cycles MUST NOT re-fire. — ADR-0005
- **Forbidden**: (accumulator reset on pause not relevant here; `tick_fired` deferral not relevant here)

---

## Acceptance Criteria

*Scoped to this story, drawn verbatim from GDD §8 (AC-TICK-NN) or the TR-registry (TR-time-NNN):*

- [ ] AC-TICK-07: "GIVEN the game is launched with no prior save file (all Time fields at zero or absent), WHEN the TickSystem autoload initializes, THEN `elapsed_offline_seconds = 0.0`; `offline_tick_budget = 0`; `cap_reached = false`; the Offline Progression Engine receives zero offline ticks; `last_persist_unix = t_current` (equal, not merely non-zero); `t_session_high_water = t_current`; `flag_suspicious_timestamp = false`; foreground ticking begins within the first `_process` frame after initialization."
- [ ] AC-TICK-13: "GIVEN the game has completed cold-launch offline replay (the process-scoped one-shot flag is set), WHEN the app enters BACKGROUNDED and returns to FOREGROUND within the same process lifetime (any number of times), THEN no additional `offline_elapsed_seconds` signal is emitted; the Offline Progression Engine is not re-invoked; `economy.compute_offline_batch()` is not re-called; only foreground `tick_fired` emissions resume on return."
- [ ] TR-time-004: "Simulation clock session-scoped; resets to 0 on every cold launch; NOT persistent or globally unique"
- [ ] TR-time-016: "One-shot offline-replay flag is process-scoped (in-memory, not persisted); cold launch re-fires, BG<->FG does not"
- [ ] TR-time-030: "First-launch bootstrap: seed last_persist_ts = t_session_high_water = t_current; emit offline_elapsed=0, cap_reached=false"
- [ ] TR-time-033: "Offline replay signal order: offline_elapsed_seconds and cap_reached emitted BEFORE first tick_fired"

---

## Implementation Notes

*Derived from ADR-0005 Implementation Guidelines (and ADR-0014 / ADR-0003 where cross-cited):*

- Add a process-scoped bool `_offline_one_shot_fired: bool = false`. Guard the `offline_elapsed_seconds` emission: once true, NEVER re-emit in the same process (ADR-0005 §"`offline_elapsed_seconds` one-shot").
- In `_ready()` (after SaveLoadSystem at rank 2 has restored state via `set_last_persist_ts`/`set_session_high_water` in a later story; for now hydrate from defaults OR from a stubbed load path): detect first-launch condition via `_last_persist_ts == 0 AND _session_high_water == 0`. If first launch, seed `_last_persist_ts = _session_high_water = _read_wall_clock_unix_time()` and emit `offline_elapsed_seconds.emit(0.0, false)`.
- Ordering invariant for AC-TICK-02/TR-time-033: the `offline_elapsed_seconds` signal MUST emit BEFORE the first `tick_fired` — implement this by running the bootstrap/compute inside `_ready()` (rank 0), which fires before any `_process` call. OfflineProgressionEngine at rank 15 subscribes in its own `_ready()`, which runs AFTER TickSystem's `_ready()`. Ensure the signal emission is deferred until AFTER rank 15 has wired up — use `call_deferred` ONLY on the signal emission itself (this is allowed for `offline_elapsed_seconds` — the `call_deferred` prohibition is specific to `tick_fired` per ADR-0005). Alternative: emit inside the first `_process` frame before ticking — confirm with godot-specialist which pattern fits best (OQ).
- Ensure `_sim_tick_counter = 0` at every cold launch — never persist it (TR-time-004 + ADR-0005 Alternatives §4 rejection of persisting sim tick counter).
- For AC-TICK-13: on BG→FG transition, verify `_offline_one_shot_fired == true` blocks any re-emit; add a test that cycles BG↔FG 5 times and asserts exactly one signal emission across the entire process lifetime.
- Formula D.2 (the not-first-launch path that computes `elapsed_offline_seconds > 0`) is OUT OF SCOPE for this story — lands in Story 006. This story covers only the first-launch zero-case + the one-shot emission mechanism.

---

## Out of Scope

*Handled by neighboring stories — do not implement here:*

- Story 006: Formula D.2 (offline elapsed + cap + rewind + overflow)
- Story 008: Save/Load hydrating `_last_persist_ts` / `_session_high_water` at load time (until then, tests stage state via direct field assignment or `set_*` calls)

---

## QA Test Cases

*Written at story creation. Developer implements against these — do not invent new test cases during implementation.*

- **AC-TICK-07**: First-launch bootstrap
  - **Given**: TickSystem `_ready()` runs with `_last_persist_ts == 0`, `_session_high_water == 0` (no prior save)
  - **When**: initialization completes
  - **Then**: `_last_persist_ts == _read_wall_clock_unix_time()` (equal, not merely non-zero); `_session_high_water == _read_wall_clock_unix_time()`; `_flag_suspicious_timestamp == false`; `offline_elapsed_seconds(0.0, false)` emitted exactly once; first `_process` frame thereafter emits `tick_fired`
  - **Edge cases**: `_read_wall_clock_unix_time() == 0` (impossible in practice but a degenerate test case) — bootstrap still runs without divide-by-zero

- **AC-TICK-13**: Intra-session BG↔FG does not re-fire offline replay
  - **Given**: cold launch has completed, one `offline_elapsed_seconds` signal received
  - **When**: simulate BG→FG 5 times in the same process
  - **Then**: zero additional `offline_elapsed_seconds` emissions; `_offline_one_shot_fired == true` throughout
  - **Edge cases**: FG→BG→FG within 1 second; FG→BG→FG across a wall-clock skip of 10 hours (still one-shot, no re-emit)

- **TR-time-033**: Signal order
  - **Given**: test spy recording `tick_fired` and `offline_elapsed_seconds` emissions with sequence numbers
  - **When**: cold launch completes and first `_process` frame fires
  - **Then**: `offline_elapsed_seconds` is sequence index < any `tick_fired` sequence index
  - **Edge cases**: if OfflineProgressionEngine's `_ready()` hasn't run before the signal emits, test should detect the missing subscriber and FAIL (documents the ordering contract for future refactors)

- **TR-time-004**: Session-scoped counter
  - **Given**: simulated cold launch → play for 1000 ticks → simulated "process restart" (test harness instantiates fresh TickSystem)
  - **When**: fresh TickSystem `_ready()` fires
  - **Then**: `_sim_tick_counter == 0`; no attempt to load counter from save
  - **Edge cases**: if a test stub's `load_save_data` returns a nonzero counter, TickSystem must ignore it (counter is not a Save/Load field per ADR-0005)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/tick_system/first_launch_bootstrap_offline_one_shot_emission_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 003 must be DONE
- **Unlocks**: Story 006
