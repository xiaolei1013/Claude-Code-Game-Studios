# Story 008: Heartbeat persist coupling + Save/Load writer surface

> **Epic**: tick-system
> **Status**: Complete (system shipped; see systems-index Implementation Status #1. Test evidence: `tests/{unit,integration}/tick_system/`. Per-story AC checkbox tick-through deferred to a dedicated audit pass.)
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/game-time-and-tick.md`
**Requirements**: TR-time-011, TR-time-012, TR-time-031, TR-time-032
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0005: Time System Dual-Clock Contract (+ ADR-0004 envelope context)
**ADR Decision Summary**: A 60s foreground heartbeat writes a small partial-envelope (`{t_last_persist, t_session_high_water, sim_tick_counter}`, ≤512 bytes) via `SaveLoadSystem.request_heartbeat_persist`; BG entry also triggers a heartbeat write; graceful exit triggers a full-envelope persist. `_session_high_water` uses max-preserving assignment; only SaveLoadSystem may call the `set_*` writer methods on TickSystem.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: MEDIUM risk from coordination across the ADR-0004 envelope + BG/FG path (partial-envelope schema refinement). No post-cutoff engine APIs introduced here; `get_stack()` debug assert is stable.

**Control Manifest Rules (Foundation Layer, TickSystem)**:
- **Required**: Only SaveLoadSystem may call `set_last_persist_ts(ts)` and `set_session_high_water(ts)` on TickSystem (debug assert + convention). — ADR-0005
- **Required**: Heartbeat persist (every 60s default) writes ONLY `{t_last_persist, t_session_high_water, sim_tick_counter}` (≤512 bytes); full-state persist only on graceful exit or scene-boundary trigger. — ADR-0005
- **Required**: SaveLoadSystem exposes `request_heartbeat_persist(time_fields: Dictionary)` partial-envelope path; refines ADR-0004 full-envelope contract. — ADR-0005
- **Forbidden**: Never write to `TickSystem.set_last_persist_ts` / `set_session_high_water` from non-SaveLoad context (`tick_system_timestamp_write_outside_save_load`). — ADR-0005
- **Guardrail**: Heartbeat envelope size: ≤512 bytes — [BLOCKING via AC-TICK-11]. — ADR-0005

---

## Acceptance Criteria

*Scoped to this story, drawn verbatim from GDD §8 (AC-TICK-NN) or the TR-registry (TR-time-NNN):*

- [ ] AC-TICK-11: "GIVEN the game has been in FOREGROUND for 120 real seconds without a pause event, with `heartbeat_interval_seconds = 60`, WHEN the Time System's heartbeat timer is inspected, THEN at least two heartbeat writes have occurred within the 120s window; each write updates `last_persist_unix` and `t_session_high_water` in the save buffer; each write payload is ≤ 512 bytes (per Rule 10); on simulated OS-kill and cold relaunch, `anchor` equals the most recent heartbeat timestamp within 60s of the kill moment; `elapsed_offline_seconds ≤ 60`."
- [ ] TR-time-011: "Persist session high-water field t_session_high_water via max-preserving assignment; signed by Save/Load"
- [ ] TR-time-012: "Heartbeat payload (60s) <=512 bytes: {t_last_persist, t_session_high_water, sim_tick_counter} only"
- [ ] TR-time-031: "Heartbeat interval 60s default (safe range 15-300); writes t_last_persist and t_session_high_water on every heartbeat and BG entry"
- [ ] TR-time-032: "Save/Load sole permitted external writer: set_last_persist_ts(int) and set_session_high_water(int) on load"

---

## Implementation Notes

*Derived from ADR-0005 Implementation Guidelines (and ADR-0014 / ADR-0003 where cross-cited):*

- Implement a heartbeat accumulator inside `_process(delta)` (runs whenever `_process` runs — so it fires in FOREGROUND including UI-paused substate, but NOT when `_state == BACKGROUNDED` per TR-time-034). When accumulator ≥ `heartbeat_interval_seconds`, reset it and call `SaveLoadSystem.request_heartbeat_persist({t_last_persist, t_session_high_water, sim_tick_counter})`.
- On every heartbeat: `_last_persist_ts = _read_wall_clock_unix_time()`; `_session_high_water = max(_session_high_water, _last_persist_ts)` — max-preserving (TR-time-011).
- On BG entry (Story 004's `_on_backgrounded`): ALSO fire a heartbeat write — BG is a persist boundary per ADR-0005 §transition table and GDD §Core Rule 5/9.
- On graceful exit (`NOTIFICATION_WM_CLOSE_REQUEST` → `_on_graceful_exit`): trigger a FULL-envelope persist (ADR-0004's `request_persist("scene_boundary_persist")` equivalent) — this is distinct from the partial heartbeat envelope.
- Implement `set_last_persist_ts(ts: int)` and `set_session_high_water(ts: int)`: assign fields; in debug build, add `assert(_caller_is_save_load_system(), ...)` via `get_stack()` check (ADR-0005 Decision §Bidirectional Save/Load contract); release builds strip the assert and rely on convention.
- Implement `get_last_persist_ts()` and `get_session_high_water()` accessors (referenced by Save/Load at persist time).
- Coordinate with SaveLoadSystem (rank 2): it subscribes to `TickSystem` via named methods, NOT via `CONSUMER_PATHS` (control-manifest.md line 170 "TickSystem is a special bidirectional consumer accessed via named methods"). This story's test stubs a SaveLoadSystem fake that implements `request_heartbeat_persist(dict) -> void` and verifies it gets called with the expected dict shape + size.
- Payload-size assertion: compute the envelope size via `JSON.stringify({...}).length` (approx UTF-8 byte count); must be ≤ 512 bytes including ADR-0004's 44-byte header/footer overhead. With only 3 int fields, realistic payload is ~50-94 bytes.
- Contract with ADR-0004: `request_heartbeat_persist` is the partial-envelope path; strict dict-shape assertion inside SaveLoadSystem rejects any extra key. This story implements TickSystem's side; SaveLoadSystem's side is its own story under the save-load epic.

---

## Out of Scope

*Handled by neighboring stories — do not implement here:*

- SaveLoadSystem internal implementation of `request_heartbeat_persist` (separate epic)
- Full-envelope graceful-exit persist coordination with ADR-0007 scene transition (Story 008 only triggers it; scene-boundary coupling is ADR-0007's concern)

---

## QA Test Cases

*Written at story creation. Developer implements against these — do not invent new test cases during implementation.*

- **AC-TICK-11**: Heartbeat timing + envelope size + crash recovery
  - **Given**: TickSystem in FOREGROUND, `heartbeat_interval_seconds = 60`, SaveLoadSystem test double recording each `request_heartbeat_persist` call
  - **When**: advance simulated wall time 120s (feed enough deltas via `_process`)
  - **Then**: at least 2 `request_heartbeat_persist` calls recorded; each dict has exactly keys `{t_last_persist, t_session_high_water, sim_tick_counter}`; each payload serialized size ≤ 512 bytes; `t_session_high_water` non-regressing across calls
  - **Edge cases**: simulated OS kill after 70s → on relaunch with mock `t_current = kill_moment + 60`, `anchor` = most recent heartbeat timestamp; `elapsed_offline_seconds ≤ 60`

- **TR-time-011**: max-preserving high-water
  - **Given**: `_session_high_water = 1_000_000`; attacker sets `_last_persist_ts = 500_000` via heartbeat
  - **When**: next heartbeat fires
  - **Then**: `_session_high_water = max(1_000_000, new_wall_ts)` — never regresses to 500_000
  - **Edge cases**: if new wall ts < prev high-water due to legitimate NTP correction within tolerance, high-water still stays at prev

- **TR-time-012**: Payload size
  - **Given**: heartbeat dict with the 3 fields
  - **When**: `JSON.stringify()` of the dict
  - **Then**: byte length + ADR-0004 44-byte overhead ≤ 512 bytes
  - **Edge cases**: int64 max values (19 digits each) → worst-case envelope ~150 bytes; still well under budget. Adding a 4th field would require a save VERSION bump (out of scope)

- **TR-time-031**: Interval tunability
  - **Given**: `heartbeat_interval_seconds = 15` (safe-range minimum)
  - **When**: 60s of simulated time elapse
  - **Then**: 4 heartbeats fire
  - **Edge cases**: `heartbeat_interval_seconds = 300` (max) → 0 heartbeats in 120s (only on BG entry); `heartbeat_interval_seconds` out of safe range should clamp or warn (not a blocking requirement)

- **TR-time-032**: Save/Load writer contract
  - **Given**: test harness calls `TickSystem.set_last_persist_ts(12345)` from a context identified as SaveLoadSystem
  - **When**: call executes
  - **Then**: `_last_persist_ts == 12345`; no assert fires
  - **Edge cases**: same call from a non-SaveLoad caller in debug build → `get_stack()`-based assert triggers `push_error` + optional `quit(1)` per ADR-0005 risks row 5; in release, convention-enforced (no runtime check)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/tick_system/heartbeat_persist_saveload_writer_surface_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 004 must be DONE
- **Unlocks**: Story 011
