# Story 007: Suspicious-timestamp flag + signal emission + log string

> **Epic**: tick-system
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/game-time-and-tick.md`
**Requirements**: TR-time-018, TR-time-019, TR-time-036
*(Full requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time.)*

**Governing ADR(s)**: ADR-0005: Time System Dual-Clock Contract
**ADR Decision Summary**: The suspicious-timestamp flag is a session-scoped private bool that transitions once (false→true) on the first D.2 rewind-branch detection; `flag_suspicious_timestamp_emitted(prev_ts, curr_ts)` fires exactly once per launch on that transition, accompanied by a fixed-prefix warning log. Session bool is never persisted and resets to false on every cold launch.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: No post-cutoff engine APIs used in this story.

**Control Manifest Rules (Foundation Layer, TickSystem)**:
- **Required**: `flag_suspicious_timestamp_emitted(prev_ts, curr_ts)` fires once per launch on the bool's false→true transition; session-scoped private bool `_flag_suspicious_timestamp` is distinct from the public signal. — ADR-0005
- **Forbidden**: N/A (no new forbidden pattern specific to this story)

---

## Acceptance Criteria

*Scoped to this story, drawn verbatim from GDD §8 (AC-TICK-NN) or the TR-registry (TR-time-NNN):*

- [ ] AC-TICK-05: "GIVEN a saved game with `last_persist_unix = T` and `t_session_high_water = T`, WHEN the game loads and `t_current < T − REWIND_TOLERANCE_SECONDS`, THEN `elapsed_offline_seconds = 0.0`; `offline_tick_budget = 0`; `cap_reached = false`; no negative duration is passed to any consumer; `flag_suspicious_timestamp = true` for the session AND `flag_suspicious_timestamp_emitted(previous_ts=T, current_ts=t_current)` signal fires exactly once ... a warning log is emitted containing the literal string `\"[TickSystem] Clock rewind detected: delta=\"` followed by the negative delta value; save state is not corrupted."
- [ ] AC-TICK-05b: "GIVEN a player launches at T, plays 1 hour (heartbeat writes `t_last_persist = T + 3600`, `t_session_high_water = T + 3600`), then rewinds the clock to `T + 1800` during the session, then experiences an OS kill, WHEN the game relaunches at wall-clock time `T + 1800` (rewound) with the saved `t_last_persist = T + 1800` (rewound heartbeat) but `t_session_high_water = T + 3600` (max-preserved), THEN `anchor = max(T + 1800, T + 3600) = T + 3600`; `elapsed_raw = T + 1800 − (T + 3600) = −1800`; `−1800 < −300` → `flag_suspicious_timestamp = true`, `elapsed_offline_seconds = 0`."
- [ ] TR-time-018: "flag_suspicious_timestamp_emitted fires once per launch on false->true bool transition"
- [ ] TR-time-019: "Session-scoped bool flag_suspicious_timestamp resets to false on every cold launch"
- [ ] TR-time-036: "Log format on rewind: '[TickSystem] Clock rewind detected: delta=' followed by negative delta"

---

## Implementation Notes

*Derived from ADR-0005 Implementation Guidelines (and ADR-0014 / ADR-0003 where cross-cited):*

- Maintain a private session-scoped field `_flag_suspicious_timestamp: bool = false`. Initialise to false on every `_ready()` — never loaded from save, never persisted (Save/Load owns `_meta.tamper_suspicious_count` per ADR-0004, which is orthogonal).
- In the rewind branch of Formula D.2 (Story 006), guard on `not _flag_suspicious_timestamp` before setting true and emitting — this enforces the once-per-launch invariant (TR-time-018): even if multiple heartbeats observe the rewound state, the signal fires ONLY on the `false → true` transition (ADR-0005 §"state-vs-signal distinction").
- Emit `flag_suspicious_timestamp_emitted.emit(anchor, t_current)` where `anchor = max(_last_persist_ts, _session_high_water)` — matches GDD D.2 variables and AC-TICK-05 `previous_ts=T`/`current_ts=t_current` semantics.
- Emit the log line using `push_warning` or `print` with the EXACT literal prefix `"[TickSystem] Clock rewind detected: delta="` followed by `str(elapsed_raw)` — AC-TICK-05 string-match test depends on this format.
- Do NOT persist the flag. Reset to false at `_ready()` (though initial value is already false — ensure no stale state across test invocations in the same process).
- AC-TICK-05b: the max-preserving write of `_session_high_water` (done in Story 004 BG entry and Story 008 heartbeat) is the load-bearing mechanism — this story only verifies the compute correctly re-enters the rewind branch when anchor stays at the pre-rewind high-water.

---

## Out of Scope

*Handled by neighboring stories — do not implement here:*

- Story 010: `debug_emit_suspicious_timestamp(prev, curr)` debug hook (AC-SL-09 fixture support) — separate method that emits the signal directly without going through D.2

---

## QA Test Cases

*Written at story creation. Developer implements against these — do not invent new test cases during implementation.*

- **AC-TICK-05**: Rewind flag + signal + log
  - **Given**: `T = 1_745_000_000`; `_last_persist_ts = _session_high_water = T`; mock `t_current = T - 3600` (rewind by 1h, well past tolerance 300s)
  - **When**: `_compute_offline_elapsed()` runs once
  - **Then**: `_flag_suspicious_timestamp == true`; `flag_suspicious_timestamp_emitted(T, T - 3600)` emits exactly once (verify via `signal_collector` or spy); `elapsed_offline_seconds == 0.0`; `offline_tick_budget == 0`; `cap_reached == false`; log output contains literal `"[TickSystem] Clock rewind detected: delta=-3600"`; no exception raised
  - **Edge cases**: run `_compute_offline_elapsed()` a second time without reset — signal must NOT re-emit (once-per-launch invariant); run it a second time with `t_current` restored — flag stays true, no second signal

- **AC-TICK-05b**: In-session rewind via high-water
  - **Given**: simulate session: launch at T, heartbeat to `_last_persist_ts = T + 3600` and `_session_high_water = T + 3600`, attacker rewinds clock, next heartbeat overwrites `_last_persist_ts = T + 1800` BUT `_session_high_water` stays at `T + 3600` (max-preserving), simulated OS kill, then relaunch with mock `t_current = T + 1800`
  - **When**: cold-launch `_compute_offline_elapsed()` runs
  - **Then**: `anchor == T + 3600`; `elapsed_raw == -1800`; `_flag_suspicious_timestamp == true`; `elapsed_offline_seconds == 0`
  - **Edge cases**: attacker overwrites both fields via save edit — integrity check fails at Save/Load layer (out of scope); legitimate NTP correction of -100s → within tolerance, not flagged

- **TR-time-018 (once-per-launch)**: Logic
  - **Given**: three sequential calls to a flag-setting helper with all inputs triggering the rewind branch
  - **When**: calls execute
  - **Then**: `flag_suspicious_timestamp_emitted` emits exactly once; subsequent calls see `_flag_suspicious_timestamp == true` and short-circuit
  - **Edge cases**: manual reset of the bool mid-session is not supported — tests that need re-emission use Story 010's `debug_emit_suspicious_timestamp` hook

- **TR-time-019 (session-scoped reset)**: Logic
  - **Given**: process A sets `_flag_suspicious_timestamp = true` then "terminates"; fresh process B instantiates TickSystem
  - **When**: new `_ready()` fires
  - **Then**: `_flag_suspicious_timestamp == false`; save state must not contain the flag (schema verified by Save/Load tests; this test just ensures TickSystem's private field starts false)
  - **Edge cases**: no `_meta.tamper_suspicious_count` interaction — that persistent counter is SaveLoadSystem's concern

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/tick_system/suspicious_timestamp_flag_signal_emission_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 006 must be DONE
- **Unlocks**: Story 010
