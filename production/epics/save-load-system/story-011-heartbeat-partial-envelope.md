# Story 011: Heartbeat partial-envelope — `request_heartbeat_persist(time_fields)` (≤512 bytes)

> **Epic**: save-load-system
> **Status**: Complete (system shipped; see systems-index Implementation Status #3. Test evidence: `tests/{unit,integration}/save_load/`. Per-story AC checkbox tick-through deferred to a dedicated audit pass.)
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/save-load-system.md` §Persist Triggers
**Requirements**: TR-save-load-008, TR-save-load-041
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0005 (primary — TickSystem dual-clock contract + heartbeat ≤512 bytes partial-envelope refinement), ADR-0004 (full-envelope contract that this refines)
**ADR Decision Summary**: TickSystem's heartbeat persist (every 60s default) writes ONLY `{t_last_persist, t_session_high_water, sim_tick_counter}` (≤512 bytes). Full-state persist occurs only on graceful exit or scene-boundary trigger. `SaveLoadSystem.request_heartbeat_persist(time_fields: Dictionary)` is the partial-envelope entry point that refines ADR-0004's full-envelope contract. Only SaveLoadSystem may call `set_last_persist_ts` / `set_session_high_water` on TickSystem.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (envelope size enforcement is BLOCKING via AC-TICK-11; writing beyond 512 bytes degrades mobile battery + crash-recovery latency)
**Engine Notes**: Same atomic-write primitives as Story 008. `NOTIFICATION_WM_CLOSE_REQUEST` triggers full-state graceful-exit persist, NOT heartbeat.

**Control Manifest Rules (Foundation Layer, heartbeat)**:
- **Required**: Heartbeat persist (every 60s default) writes ONLY `{t_last_persist, t_session_high_water, sim_tick_counter}` (≤512 bytes); full-state persist only on graceful exit or scene-boundary trigger. `SaveLoadSystem.request_heartbeat_persist(time_fields: Dictionary)` partial-envelope path refines ADR-0004 full-envelope contract. Only SaveLoadSystem may call `set_last_persist_ts(ts)` and `set_session_high_water(ts)` on TickSystem. SaveLoadSystem reads/writes TimeSystem's `last_persist_unix_ts` AND `t_session_high_water`; both covered by HMAC signature.
- **Forbidden**: Heartbeat envelope growing beyond 512 bytes through field creep (dict-shape strictly asserted). Heartbeat path invoking the full consumer loop (bypasses Story 007).
- **Guardrail**: Heartbeat envelope size ≤512 bytes [BLOCKING via AC-TICK-11]. Save persist <10ms p95 PC / <50ms p95 mobile.

---

## Acceptance Criteria

*Scoped to this story:*

- [ ] `request_heartbeat_persist(time_fields: Dictionary) -> void` entry point exists on SaveLoadSystem
- [ ] Dict shape strictly asserted: exactly 3 keys `t_last_persist: int`, `t_session_high_water: int`, `sim_tick_counter: int`; unknown keys → `push_error` + abort without writing
- [ ] Heartbeat envelope encodes ONLY the 3 time fields + `_meta` (slot_index + save_sequence_number + tamper_suspicious_count + backup_restore_events); NO consumer namespaces
- [ ] Composed heartbeat envelope size ≤512 bytes (measured in CI per AC-TICK-11)
- [ ] Atomic-write pipeline is the same Story 008 primitive; rename-safe; `.bak` rotation NOT applied for heartbeat (heartbeat doesn't touch consumer data — a partial-envelope `.bak` would corrupt the full-envelope recovery path)
- [ ] Full-state persist paths (graceful exit via `NOTIFICATION_WM_CLOSE_REQUEST`, scene-boundary per Story 012) invoke Story 007's full consumer loop — NOT `request_heartbeat_persist`
- [ ] On hydrate: heartbeat-written fields (`t_last_persist`, `t_session_high_water`, `sim_tick_counter`) merge into the last full envelope's state; consumer state is NOT overwritten (since heartbeat didn't persist it)
- [ ] Cloud-poisoning guard: rejected loaded `t_last_persist > t_current + 300` seeds both fields with `t_current` (TR-save-load-042; Story 009 owns the mechanic, this story consumes it)
- [ ] Heartbeat state-transition guard: if state is `PERSISTING` (full-state in flight), drop heartbeat trigger + `push_warning` (coalesce per TR-save-load-046)

---

## Implementation Notes

- The heartbeat envelope format is the SAME envelope layout as full-state (12B header + masked JSON payload + 32B HMAC) — the only difference is the payload JSON content. This means Story 006 validation works unchanged; Story 004 HMAC works unchanged. The size-savings come from the tiny payload (~50 bytes raw + envelope overhead = ~94 bytes total per ADR-0005 estimate — well under 512 bytes)
- JSON shape for heartbeat payload:
  ```json
  {
    "_meta": { "slot_index": 1, "save_sequence_number": 4218, "tamper_suspicious_count": 0, "backup_restore_events": [] },
    "time": { "t_last_persist": 1745000000, "t_session_high_water": 1745000000, "sim_tick_counter": 20 }
  }
  ```
  Note: heartbeat uses a `"time"` namespace, NOT the 6 consumer namespaces. On load, the `time` namespace is read by SaveLoadSystem (not delegated to TickSystem's `load_save_data`); SaveLoadSystem calls `TickSystem.set_last_persist_ts(v)` + `set_session_high_water(v)` directly (these are the ONLY permitted external writes per ADR-0005)
- Strict dict-shape assertion at entry:
  ```gdscript
  func request_heartbeat_persist(time_fields: Dictionary) -> void:
      if time_fields.size() != 3: push_error("[SaveLoad] heartbeat dict wrong size"); return
      for k in ["t_last_persist", "t_session_high_water", "sim_tick_counter"]:
          if not time_fields.has(k): push_error("[SaveLoad] heartbeat missing key " + k); return
          if typeof(time_fields[k]) != TYPE_INT: push_error("[SaveLoad] heartbeat wrong type " + k); return
      # ... proceed with composition
  ```
- Why no `.bak` rotation for heartbeat: the heartbeat envelope contains NO consumer state. If a heartbeat-written `.dat` gets promoted to `.bak`, a subsequent `.bak` fallback would hydrate with stale consumer state PLUS possibly-newer time fields — confusing. Keeping heartbeat rotation-less preserves the invariant that `.bak` always holds a full-consumer-state snapshot
- Rank-0 TickSystem subscription: SaveLoadSystem connects to TickSystem's heartbeat timer at `_ready()` (signal subscription across any rank pair is safe per ADR-0003 Amendment #1); on signal, calls `request_heartbeat_persist` with the 3 fields pulled from TickSystem
- Graceful-exit path (`NOTIFICATION_WM_CLOSE_REQUEST`): triggers full-state persist via Story 007 loop — NOT heartbeat. This is where consumer data gets its freshest snapshot before shutdown

---

## Out of Scope

- Story 007: full-state consumer loop (heartbeat bypasses this by design)
- Story 012: scene-boundary full-state persist (separate trigger from heartbeat)
- Story 015: AC-TICK-11 performance verification (this story implements; Story 015 measures)
- TickSystem's heartbeat timer implementation (owned by Time System epic)

---

## QA Test Cases

- **TR-save-load-041 / ADR-0005 Rule 10**: Heartbeat envelope size ≤512 bytes (BLOCKING AC-TICK-11)
  - **Given**: A heartbeat trigger with canonical 3-field dict
  - **When**: Envelope is composed
  - **Then**: `envelope.size() <= 512`; CI assertion measures actual bytes
  - **Edge cases**: Max-value int fields (9 007 199 254 740 991) still keep envelope under 512 bytes because JSON int encoding is at most ~19 ASCII chars per field

- **Strict dict-shape assertion**
  - **Given**: Malformed dict `{t_last_persist: 100, extra_field: "oops"}` (4 keys)
  - **When**: `request_heartbeat_persist(malformed)` runs
  - **Then**: `push_error` emitted; no file I/O; function returns early
  - **Edge cases**: Missing key → same abort; wrong type (string instead of int) → same abort

- **TR-save-load-041 (time field round-trip)**
  - **Given**: Heartbeat persists `{t_last_persist: 1745000000, t_session_high_water: 1745000100, sim_tick_counter: 20}`; fresh launch
  - **When**: Load pipeline reads the heartbeat envelope
  - **Then**: SaveLoadSystem calls `TickSystem.set_last_persist_ts(1745000000)`, `TickSystem.set_session_high_water(1745000100)`; sim_tick_counter restored
  - **Edge cases**: Heartbeat-only session (no prior full save) — load seeds consumers from first-launch bootstrap + time fields from heartbeat

- **Bypass-full-loop invariant**: Heartbeat does not invoke consumer loop
  - **Given**: Stub consumers with spy counters on `get_save_data`
  - **When**: `request_heartbeat_persist(...)` runs
  - **Then**: Zero `get_save_data` invocations on any consumer; only SaveLoadSystem-owned fields (`_meta` + `time`) present in envelope
  - **Edge cases**: `save_sequence_number` still advances (Story 009 semantics) — heartbeat persists are counted

- **State overlap**: Heartbeat coalesces during PERSISTING
  - **Given**: State is `PERSISTING` (full-state persist in flight)
  - **When**: TickSystem fires heartbeat trigger
  - **Then**: `request_heartbeat_persist` is dropped with `push_warning`; state stays `PERSISTING`
  - **Edge cases**: After full persist completes, next heartbeat fires normally

- **Graceful-exit distinct from heartbeat**
  - **Given**: `NOTIFICATION_WM_CLOSE_REQUEST` received
  - **When**: SaveLoadSystem notification handler runs
  - **Then**: Full-state persist via Story 007 loop fires (NOT heartbeat); consumer `get_save_data` invoked on all 6
  - **Edge cases**: Heartbeat firing same frame as close request → close request takes precedence (full-state is strictly more informative)

- **Cloud-poisoning guard (cross-ref TR-save-load-042)**
  - **Given**: Loaded heartbeat payload has `t_last_persist = t_current + 3600` (1 hour future)
  - **When**: Hydrate runs
  - **Then**: Both fields seeded to `t_current`; `tamper_suspicious_count` incremented; no crash
  - **Edge cases**: 300-second tolerance absorbs drift; values beyond get rejected

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/save_load/heartbeat_partial_envelope_test.gd` — must exist and pass; CI assertion measures envelope size ≤512 bytes per AC-TICK-11

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 002 (envelope layout), Story 004 (HMAC), Story 005 (keys), Story 008 (atomic write pipeline), Story 009 (`_meta` management)
- **Unlocks**: Story 015 (performance measurement of heartbeat persist time)
