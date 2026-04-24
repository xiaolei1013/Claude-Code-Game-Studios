# ADR-0005: Time System — Dual-Clock Contract (Wall + Sim, 20Hz)

## Status

Accepted

## Date

2026-04-22

## Last Verified

2026-04-22

## Decision Makers

- Author (user) — final decision
- godot-specialist — engine pattern validation (pending Step 4.5)
- technical-director — solo mode skip (review-mode.txt = solo; gate TD-ADR not invoked)
- Source of truth: `design/gdd/game-time-and-tick.md` (Pass-TS-DEBUG-API 2026-04-21)

## Summary

Codifies the Time System (autoload identifier `TickSystem`, rank 0) as the **single source** of two strictly-separated clocks: a Wall Clock (`Time.get_unix_time_from_system()` cast to int64) and a 20Hz Simulation Clock (integer tick counter via `_process(delta)` accumulator, never `_physics_process`, never `Engine.physics_ticks_per_second`). The ADR locks: the autoload identifier and rank, the dual-clock separation, the foreground-only `tick_fired` synchronous emission contract, the state machine (FOREGROUND / BACKGROUNDED / OFFLINE-as-derived), the platform-specific BG/FG trigger mapping, the bidirectional Save/Load contract for `last_persist_unix_ts` + `t_session_high_water` (sole permitted external writes), the heartbeat persist payload size cap (≤512 bytes), the `flag_suspicious_timestamp` state-vs-signal distinction, and the debug-only mock-clock test surface (`debug_set_unix_time` / `debug_clear_unix_time` runtime-gated by `OS.is_debug_build()`). Pillar-1 invariant: `_process(delta)` is forbidden as an input to economy math, period.

## Engine Compatibility

| Field | Value |
|---|---|
| **Engine** | Godot 4.6 |
| **Domain** | Core / Scripting (Time singleton, Node `_process` + `_notification`, autoload init, signal emission semantics) |
| **Knowledge Risk** | LOW — `Time.get_unix_time_from_system()`, `_process(delta)`, `_notification(what)`, NOTIFICATION_APPLICATION_PAUSED/RESUMED, NOTIFICATION_WM_WINDOW_FOCUS_OUT/IN, OS.is_debug_build() are all stable since 4.0; no post-cutoff change touches any of these. |
| **References Consulted** | `design/gdd/game-time-and-tick.md`; `docs/engine-reference/godot/breaking-changes.md` (no relevant entries 4.4-4.6); `docs/engine-reference/godot/deprecated-apis.md` (`OS.get_ticks_msec` deprecated in favor of `Time.get_ticks_msec` — relevant precedent for "use Time singleton" preference); `docs/engine-reference/godot/modules/autoload.md` (Claim 1 [VERIFIED] — autoload init order) |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None — all engine APIs in this ADR are training-data-stable. Behavioral verification (AC-TICK-01 through AC-TICK-13) is implementation-side, not engine-knowledge-side. |

## ADR Dependencies

| Field | Value |
|---|---|
| **Depends On** | ADR-0003 (Autoload Rank Table, Accepted) — establishes rank 0 for TickSystem and the rank invariant that consumers (ranks 2-15) connect to TickSystem signals at their `_ready()`. ADR-0004 (Save Envelope, Accepted) — establishes the persistence contract that `last_persist_unix_ts` and `t_session_high_water` flow through. |
| **Enables** | All Foundation/Core/Feature systems that consume `tick_fired` (Economy, DungeonRunOrchestrator, OfflineProgressionEngine), the `offline_elapsed_seconds` one-shot signal (OfflineProgressionEngine, Return-to-App Screen), or `flag_suspicious_timestamp_emitted` (SaveLoadSystem). All AC-TICK-* through AC-TICK-13. |
| **Blocks** | TickSystem implementation epic; Economy implementation (depends on `tick_fired`); DungeonRunOrchestrator implementation (depends on `tick_fired` foreground + batch API offline path); OfflineProgressionEngine implementation (depends on the one-shot `offline_elapsed_seconds` contract); Save/Load AC-SL-09 (depends on `flag_suspicious_timestamp_emitted` signal contract). |
| **Ordering Note** | Should land before ADR-F04 (Data Loading) and ADR-F05 (Scene Transition) only insofar as those ADRs reference timing behavior; in practice they are independent. Time and Data are both Foundation peers; Time has no upstream dependency on Data, but Save/Load does — Save/Load implementation needs both ADRs Accepted. |

## Context

### Problem Statement

The Time System is the load-bearing infrastructure for Pillar 1 (Respect the Player's Time). Architecture.md identified it as ADR-F03 ("Time System dual-clock contract") with these decisions to lock:

1. **Sim Clock implementation** — `_process(delta)` accumulator vs `_physics_process` vs `Engine.physics_ticks_per_second` vs a custom Timer node
2. **Foreground-only tick guarantee** — what notification triggers BG transition on each platform; how UI pause interacts with OS pause
3. **`flag_suspicious_timestamp` thresholds and the state-vs-signal distinction**
4. **Session boundary definition** — what counts as a session end requiring persist (graceful exit, heartbeat, BG entry, all three?)

Without an ADR, future revisions could re-litigate the `_process` vs `_physics_process` choice (the GDD argues against `_physics_process` but the rationale must not drift), or the synchronous-emission contract (a future "performance optimization" might add `call_deferred`, silently breaking offline-replay determinism), or the heartbeat payload bound (creep from 512 bytes → kilobytes degrades crash-recovery latency).

### Current State

- `design/gdd/game-time-and-tick.md` is fully designed through Pass-TS-DEBUG-API (2026-04-21). It specifies the autoload identifier (`TickSystem`), the two clocks, the state machine, all signals, and the debug-only test surface. The Acceptance Criteria (AC-TICK-01 through AC-TICK-13) are blocking-classified.
- ADR-0003 (Accepted 2026-04-22) places the Time System at autoload rank 0 — but uses the conceptual label "GameTimeAndTick" in the rank table rather than the GDD-canonical autoload identifier `TickSystem`. **Architecture.md must be updated to use `TickSystem` everywhere** (GDD sync issue surfaced in this ADR's Step 4.7).
- ADR-0004 (Accepted 2026-04-22) establishes that `last_persist_unix_ts` and `t_session_high_water` are envelope-protected fields in the Save/Load `_meta` adjacency layer. This ADR locks the bidirectional read/write contract.
- The GDD's Pass-TS-DEBUG-API (2026-04-21) reconciles the `flag_suspicious_timestamp` naming with Save/Load AC-SL-09 by formalizing the signal as `flag_suspicious_timestamp_emitted(prev: int, curr: int)` and distinguishing it from the session-scoped bool of the same root name.

### Constraints

- Godot 4.6 `Time.get_unix_time_from_system()` returns `float` — the GDD mandates a single `int(...)` cast at the TickSystem boundary so all downstream math is integer.
- `_physics_process(delta)` is tied to `Engine.physics_ticks_per_second`. Setting that to 20 globally would couple economy cadence to physics step (a config-fragility risk: any future change to physics rate would silently change economy timing).
- Mobile platforms emit `NOTIFICATION_APPLICATION_PAUSED/RESUMED`. Desktop platforms emit `NOTIFICATION_WM_WINDOW_FOCUS_OUT/IN` for alt-tab/minimize. There is no cross-platform unified "app suspended" notification — handling both is mandatory.
- Offline replay must complete under 500ms on min-spec mobile for 576,000 ticks (8h × 20Hz cap). Synchronous `tick_fired` emission for that volume would burn frames; the GDD therefore specifies offline replay uses batch APIs on consumers, NOT the signal path.
- `OS.is_debug_build()` is a runtime check (not a compile-time `const`); production exports return `false`. Method bodies cannot be `const`-gated. For the debug-only test surface, the runtime guard is the only mechanism — accepted because the attack surface is narrow (release builds no-op the methods).
- Heartbeat fires every 60s by default (`heartbeat_interval_seconds`); each heartbeat writes a small persist envelope. Payload bound matters for battery on mobile and for crash-recovery latency.

### Requirements

- Sim Clock MUST tick at exactly 20Hz when foregrounded (no drift, no double-fire).
- Sim Clock MUST freeze on BG entry and resume from the same accumulator residual on FG return (no silent ≤50ms phase shift per pause cycle).
- `tick_fired` MUST be synchronous emission inside `_process` — no `call_deferred` ever (downstream consumers depend on synchronous ordering).
- `tick_fired` MUST NOT fire during offline replay; the OfflineProgressionEngine MUST invoke `consumer.compute_offline_batch(n)` directly.
- Wall Clock MUST be cast to int64 at exactly one call site (the TickSystem boundary). Downstream systems MUST NOT call `Time.get_unix_time_from_system()` directly.
- The session-scoped `flag_suspicious_timestamp` bool MUST be distinguishable from the public signal `flag_suspicious_timestamp_emitted(prev, curr)` — these are two distinct concepts with the same name root.
- Save/Load MUST be the sole external writer to `last_persist_unix_ts` and `t_session_high_water`. Any other write (Economy, Orchestrator, Roster, etc.) is a contract violation.
- Debug-only test surface MUST exist (`debug_set_unix_time` / `debug_clear_unix_time` and equivalents) for AC-SL-05, AC-SL-09, AC-SL-TAMPER-04 deterministic testing.
- Heartbeat payload MUST be ≤512 bytes; full state serialization happens on graceful exit only.

## Decision

### Autoload identifier and rank

The Time System is implemented as the autoload singleton **`TickSystem`** at **rank 0** per ADR-0003. Consumers connect via bare-identifier resolution: `TickSystem.tick_fired.connect(_on_tick)`.

Architecture.md's rank table label "GameTimeAndTick" is updated to `TickSystem` in this ADR's GDD sync update (see §Step 4.7 in the closing notes). The GDD slug `game-time-and-tick.md` remains as-is (file rename has zero value and breaks history).

### Two clocks, strictly separated

**Wall Clock** — read by exactly one call site:

```gdscript
# TickSystem (rank 0) — sole call site project-wide
# int() not floori() — floori() returns float in GDScript 4.x despite the name (godot-specialist Step 4.5 Note 1).
# GDScript int IS int64; IEEE-754 double has 53-bit mantissa = exact for any Unix ts (~10^9) — no precision loss.
var t: int = int(Time.get_unix_time_from_system())  # float → int64 cast at the boundary
```

Downstream systems MUST NOT call `Time.get_unix_time_from_system()` directly. They read TickSystem's vended value via `get_last_persist_ts()`, `get_session_high_water()`, or the `offline_elapsed_seconds(secs, cap_reached)` one-shot signal.

**Simulation Clock** — integer tick counter, 20Hz fixed rate, session-scoped (resets to 0 on every cold launch):

```gdscript
# TickSystem (rank 0)
const TICKS_PER_SECOND: int = 20                              # NOT a tuning knob; do not parameterize
const _TICK_INTERVAL_SECONDS: float = 1.0 / TICKS_PER_SECOND  # 0.05

var _tick_accumulator_seconds: float = 0.0  # preserved across pause; NEVER reset on BG entry
var _sim_tick_counter: int = 0              # session-scoped; resets to 0 on cold launch

func _process(delta: float) -> void:
    if _state != FOREGROUND or _ui_paused:
        return
    _tick_accumulator_seconds += delta
    while _tick_accumulator_seconds >= _TICK_INTERVAL_SECONDS:
        _tick_accumulator_seconds -= _TICK_INTERVAL_SECONDS
        _sim_tick_counter += 1
        tick_fired.emit(_sim_tick_counter)   # synchronous emission — NEVER call_deferred
```

`TICKS_PER_SECOND = 20` is **architectural**, not configurable. Implementations MUST NOT expose it as a tuning knob in `ProjectSettings` or `.tres` data — the GDD's Tuning Knobs section lists 20 as the "default with safe range 10-60" only as designer-facing context, not as a runtime setting. Changing it requires a superseding ADR because it changes downstream economy cadence assumptions and the offline-replay tick budget formula (`offline_cap_seconds × 20 = 576,000` worst case ticks, which AC-TICK-10 verifies fits within 500ms on min-spec mobile).

### Why `_process` accumulator (not `_physics_process`, not Timer node)

- **Rejected: `_physics_process(delta)` with `Engine.physics_ticks_per_second = 20`**. Couples economy cadence to physics step globally; any future physics change silently breaks economy timing. Also affects every other system using `_physics_process`.
- **Rejected: `Timer` node with `wait_time = 0.05, autostart = true, one_shot = false`**. Timer nodes are subject to frame-rate aliasing on slow frames — a 30-fps frame can fire two timers but emit them in the same frame, while a 10-fps frame loses one tick entirely. The integer-accumulator pattern in `_process` recovers cleanly from variable frame times.
- **Chosen: `_process(delta)` accumulator** — `_process` is already running for rendering; the accumulator pattern is well-understood and frame-rate-independent. Burns no extra Node allocation.

### State machine

Three states, one substate:

```
FOREGROUND ──── OS pause / WM focus-out ────► BACKGROUNDED
    ▲                                              │
    └──────────── OS resume / WM focus-in ─────────┘

FOREGROUND ──── UI pause (settings menu) ────► FOREGROUND (UI-paused substate)
    ▲                                                      │
    └──────────── UI pause released ───────────────────────┘

OFFLINE — derived state, NOT a runtime state of the app. Computed once at cold launch
          via `_compute_offline_elapsed()`; emits `offline_elapsed_seconds(secs, cap_reached)`
          one-shot. BG↔FG cycles do NOT re-fire offline replay (one-shot flag is
          process-scoped, in-memory, NOT persisted).
```

### Platform-specific notification mapping

```gdscript
func _notification(what: int) -> void:
    match what:
        NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
            _on_backgrounded()
        NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_WM_WINDOW_FOCUS_IN:
            _on_foregrounded()
        NOTIFICATION_WM_CLOSE_REQUEST:
            _on_graceful_exit()  # full-state persist via SaveLoadSystem
```

PC focus-loss (alt-tab, minimize) intentionally maps to BACKGROUNDED, matching mobile behavior conservatively. A heartbeat fires on BG entry to bound recovery loss.

### `tick_fired` is foreground-only and synchronous

```gdscript
signal tick_fired(tick_number: int)  # foreground-only; synchronous emission
```

**Forbidden**: `call_deferred("emit_signal", "tick_fired", n)` or `tick_fired.emit.call_deferred(n)`. Consumers depend on synchronous delivery for ordering guarantees (Economy.compute_tick → DungeonRunOrchestrator.compute_tick → DungeonRunView.update must run in this order within a single tick).

**Offline replay path bypasses the signal**:

```gdscript
# OfflineProgressionEngine (rank 15), at session start, on receiving offline_elapsed_seconds
func _on_offline_elapsed(secs: float, cap_reached: bool) -> void:
    var ticks: int = int(secs * TickSystem.TICKS_PER_SECOND)
    # Direct batch-API invocation; tick_fired is NOT emitted during this loop
    Economy.compute_offline_batch(ticks)
    DungeonRunOrchestrator.compute_offline_batch(ticks)
    # AC-TICK-10: the full 576,000-tick worst case must complete under 500ms on min-spec mobile
```

### `offline_elapsed_seconds` one-shot

```gdscript
signal offline_elapsed_seconds(seconds: float, cap_reached: bool)
```

Fired exactly once per cold launch, after `_compute_offline_elapsed()` runs. The one-shot flag is process-scoped (in-memory only, not persisted). BG↔FG cycles do NOT re-fire — that would re-credit offline rewards and is a Pillar 1 catastrophe. AC-TICK-13 verifies non-refire under intra-session BG↔FG cycling.

### `flag_suspicious_timestamp` — state-vs-signal distinction

Two distinct concepts, same name root, MUST NOT be conflated:

1. **Session-scoped bool** `_flag_suspicious_timestamp: bool` — internal TickSystem state, set inside the Formula D.2 rewind branch when `elapsed_raw < -REWIND_TOLERANCE_SECONDS`. Reset to `false` on every cold launch. Does NOT persist across launches. Save/Load owns the persistent cumulative counter `_meta.tamper_suspicious_count` (per ADR-0004).

2. **Public signal** `flag_suspicious_timestamp_emitted(previous_ts: int, current_ts: int)` — fires exactly once per launch on the bool's `false → true` transition. SaveLoadSystem connects this in its `_ready()` per ADR-0003's forward-connect pattern (rank 2 → rank 0 is FORBIDDEN by the rank invariant — but rank 0 → rank 2 emission is fine; SaveLoadSystem subscribes to TickSystem, not the inverse). AC-SL-09 asserts listener receipt.

```gdscript
signal flag_suspicious_timestamp_emitted(previous_ts: int, current_ts: int)

# Inside the Formula D.2 rewind branch:
if not _flag_suspicious_timestamp:
    _flag_suspicious_timestamp = true
    flag_suspicious_timestamp_emitted.emit(_anchor_ts, t_current)
```

**Wait — let me re-check the rank invariant.** ADR-0003 says "rank-N may only forward-connect to rank-(N+1)+ at `_ready()`". SaveLoadSystem (rank 2) connects to TickSystem (rank 0). M=0 < N=2. Backward connection at `_ready()` time. This appears to violate the invariant.

**Resolution**: the invariant prohibits backward signal SUBSCRIPTION at `_ready()` — but that subscription IS forward from the signal-owner's perspective: TickSystem (rank 0) emits, SaveLoadSystem (rank 2) listens. The connection is established by the higher-ranked (rank 2) node, but the signal flow is forward-down-the-rank-table. Since signal objects exist at Node instantiation (before any `_ready()` fires per autoload.md Claim 1), SaveLoadSystem's `_ready()` can safely call `TickSystem.flag_suspicious_timestamp_emitted.connect(...)` — the signal object on TickSystem already exists; the bare identifier resolves; the connection establishes.

The rank invariant as stated in ADR-0003 §"A rank-N autoload may connect to a rank-M autoload's signal in its own `_ready()` ONLY if M > N" is therefore **incorrect as worded** — it should be **"ONLY if M < N OR if the connection is to receive (subscribe to) a signal whose owner is already in the tree, which is true for any pair of autoloads"**. The actual invariant Claim 1 [VERIFIED] establishes is: at `_ready()` time, all autoload Nodes are in the tree, so signal-object addressability is universal. The forbidden case is reading another autoload's STATE that is set in its `_ready()` body (because `_ready()` order is rank-sequential — a higher-rank `_ready()` runs after lower ones, so the higher-rank can read lower-rank state safely; the lower-rank cannot read higher-rank state set in `_ready()` because higher-rank `_ready()` hasn't run yet).

**Action**: ADR-0003's rank invariant phrasing needs a clarifying amendment. I'll add a §Open Questions item in this ADR (OQ-6) and surface it in §Step 4.7 as a non-blocking ADR-0003 amendment candidate. The empirical Claim 1 [VERIFIED] result already supports the corrected interpretation; this is a documentation precision issue, not a behavioral one.

### Bidirectional Save/Load contract

```gdscript
# READ — anyone can call (typically SaveLoadSystem at persist time)
func get_last_persist_ts() -> int           # int64 in practice
func get_session_high_water() -> int

# WRITE — restricted to SaveLoadSystem (enforced by convention + assert in dev)
func set_last_persist_ts(ts: int) -> void
func set_session_high_water(ts: int) -> void
```

```gdscript
# In set_last_persist_ts and set_session_high_water:
assert(_caller_is_save_load_system(), "[TickSystem] only SaveLoadSystem may write timestamps")
# In production builds, the assert strips; the convention is enforced by code review.
# A helper get_stack()-based caller check is debug-only and produces a fatal push_error.
```

The GDD's bidirectional contract (Save/Load reads BOTH timestamps on persist; writes BOTH back on load) is preserved verbatim. ADR-0004's HMAC envelope covers both fields under the integrity signature.

### Heartbeat persist payload constraint

```gdscript
# TickSystem heartbeat (every heartbeat_interval_seconds = 60)
# Writes ONLY these three fields via SaveLoadSystem.request_persist("heartbeat"):
{
    "t_last_persist": int,           # 8 bytes
    "t_session_high_water": int,     # 8 bytes
    "sim_tick_counter": int,         # 8 bytes
}  # Total ≤512 bytes including envelope overhead
```

Heartbeat is a **partial** persist — full state serialization happens only on graceful exit (`NOTIFICATION_WM_CLOSE_REQUEST`) or manual save trigger. This is a deliberate departure from ADR-0004's CONSUMER_PATHS iteration; ADR-0004's full-payload contract applies to graceful exit and `scene_boundary_persist` triggered persists, NOT heartbeats. The heartbeat path needs its own SaveLoadSystem method:

```gdscript
# In SaveLoadSystem (rank 2)
func request_heartbeat_persist(time_fields: Dictionary) -> void
    # Accepts ONLY {t_last_persist, t_session_high_water, sim_tick_counter}.
    # Asserts dict shape; rejects any other key.
    # Writes a heartbeat-shaped envelope (still HMAC-protected, still atomic) — payload is the time fields dict only.
    # On load, heartbeat-only saves are valid: SaveLoadSystem populates time fields and zeros consumer state — consumers must handle "fresh state" on load if the prior save was heartbeat-only.
```

This is a refinement to ADR-0004's contract — heartbeat envelopes carry a strict subset of fields. ADR-0004's payload structure (one key per CONSUMER_PATHS entry + `_meta`) is the **full** envelope; heartbeats use a **partial** envelope with only `_meta` time fields populated.

**Crash-recovery semantics**: on cold launch, if the most recent envelope is heartbeat-only, SaveLoadSystem populates `_meta` time fields from it AND signals `LoadResult.HEARTBEAT_ONLY` so consumers know to seed fresh state instead of attempting to hydrate missing `economy`/`hero_roster`/etc. keys. Player loses up to 60s of foreground progress (acceptable per Pillar 1 "respect the player's time" — full per-tick persist would destroy mobile battery).

### Debug-only test surface

```gdscript
# All three methods MUST runtime-gate with `if not OS.is_debug_build(): return`.
# Production exports no-op these methods; CI scan (AC-SL-TAMPER-05 pattern) catches accidental exposure.

var _debug_mock_unix_time: int = -1   # -1 sentinel = no mock active

func debug_set_unix_time(t: int) -> void:
    if not OS.is_debug_build(): return
    if t < 0:
        push_error("[TickSystem] debug_set_unix_time: t must be >= 0, got %d" % t)
        return
    _debug_mock_unix_time = t

func debug_clear_unix_time() -> void:
    if not OS.is_debug_build(): return
    _debug_mock_unix_time = -1

# (Additional debug helpers per the GDD §Debug-Only Test Surface)
```

Why a runtime guard instead of compile-time `const` like Save/Load's `integrity_check_enabled`: method body cannot be `const`-gated in GDScript. The runtime guard is the only mechanism. Attack surface is narrow because release builds no-op the methods (the dispatch still happens but the body returns immediately) — `OS.is_debug_build()` returns `false` on release exports, and any invocation by a player-modified release build cannot do anything beyond what the player could do with a Godot project (i.e., everything). This is acceptable for MVP; reconsider if competitive integrity becomes a requirement.

### Architecture diagram

```
                              ┌──────────────────┐
                              │   OS / Godot     │
                              │ Time singleton   │
                              └────────┬─────────┘
                                       │ get_unix_time_from_system() → float
                                       ▼
                       ┌────────────────────────────────┐
                       │  TickSystem (autoload, rank 0) │
                       │  ─────────────────────────────  │
                       │  Wall Clock (int64 cast here)  │
                       │  Sim Clock (20Hz accumulator)  │
                       │  state: FG | BG | UI-paused    │
                       │  _flag_suspicious_timestamp    │
                       └─────────┬─────────┬────────────┘
                                 │         │
                  tick_fired(n)  │         │  flag_suspicious_timestamp_emitted(prev, curr)
              (foreground only,  │         │
               synchronous)      │         │
                                 ▼         ▼
              ┌──────────────────────┐  ┌───────────────────────┐
              │ Economy (rank 3)     │  │ SaveLoadSystem (rank 2)│
              │ DungeonRunOrch (14)  │  │ — flag_suspicious      │
              │ DungeonRunView       │  │   handler              │
              └──────────────────────┘  │ — heartbeat_persist    │
                                        │   (partial envelope)   │
                                        │ — get/set_last_persist │
              ┌──────────────────────┐  │   _ts (bidirectional)  │
              │ OfflineProgEngine    │  └────────┬───────────────┘
              │ (rank 15)            │           │
              │ — receives one-shot  │           │
              │   offline_elapsed    │           │
              │ — invokes batch APIs │           │
              │   on Economy + Orch  │           │
              └──────────┬───────────┘           │
                         │                       │
                         │ offline_elapsed_seconds(secs, cap_reached)
                         │ (one-shot, in-process flag, NOT persisted)
                         │                       │
                         └───────────────────────┘ (cold-launch only)
```

### Key interfaces

```gdscript
# TickSystem (autoload `TickSystem`, rank 0)

# Constants
const TICKS_PER_SECOND: int = 20
const _TICK_INTERVAL_SECONDS: float = 1.0 / TICKS_PER_SECOND

# Tuning knobs (read from ProjectSettings or .tres at boot; NOT TICKS_PER_SECOND)
@export var offline_cap_seconds: int = 28_800              # 8h
@export var REWIND_TOLERANCE_SECONDS: int = 300            # 5 min
@export var heartbeat_interval_seconds: int = 60

# Public read API
func now_ms() -> int                          # current Unix time in milliseconds (Wall Clock)
                                              # MUST return _last_wall_ts * 1000 from cached value; MUST NOT
                                              # call Time.get_unix_time_from_system() — preserves single-call-site
                                              # invariant (godot-specialist Step 4.5 Note 2).
func current_tick() -> int                    # current sim tick counter (session-scoped)
func get_last_persist_ts() -> int             # int64; SaveLoad reads on persist
func get_session_high_water() -> int          # int64; SaveLoad reads on persist

# Public write API — RESTRICTED to SaveLoadSystem (asserted in debug; conventional in release)
func set_last_persist_ts(ts: int) -> void
func set_session_high_water(ts: int) -> void

# Signals (foreground-only synchronous unless noted)
signal tick_fired(tick_number: int)                                       # foreground-only, synchronous, NEVER call_deferred
signal offline_elapsed_seconds(seconds: float, cap_reached: bool)         # one-shot per cold launch
signal flag_suspicious_timestamp_emitted(previous_ts: int, current_ts: int)   # one-shot per launch on bool false→true

# Debug-only test surface (runtime-gated by OS.is_debug_build())
func debug_set_unix_time(t: int) -> void
func debug_clear_unix_time() -> void
```

```gdscript
# SaveLoadSystem (rank 2) — heartbeat extension to ADR-0004

func request_heartbeat_persist(time_fields: Dictionary) -> void
    # Strict subset envelope; only _meta time fields persisted.
    # Atomic + HMAC-protected per ADR-0004 envelope contract.
    # Refines ADR-0004's full-payload CONSUMER_PATHS iteration — heartbeat is a partial path.
```

## Alternatives Considered

### Alternative 1: `_physics_process(delta)` with `Engine.physics_ticks_per_second = 20`

- **Description**: Set the global physics tick rate to 20Hz; use `_physics_process` for the tick accumulator (or directly tie `tick_fired` to physics step).
- **Pros**: Godot-native fixed-rate hook; no manual accumulator needed; `_physics_process` is guaranteed deterministic per Godot's docs.
- **Cons**: Globally couples economy cadence to physics step. Any future physics-rate change (e.g., enabling 60Hz physics for a polish-tier juicy collision feel) would silently break economy timing. Conflates two unrelated concerns into one engine setting.
- **Estimated Effort**: Lower — Godot does the accumulation.
- **Rejection Reason**: Architectural separation — economy cadence and physics cadence are independent concerns and should remain so. Indie code-base cleanliness > the few lines of accumulator logic saved.

### Alternative 2: `Timer` node with `wait_time = 0.05, autostart = true, one_shot = false`

- **Description**: Spawn a Timer node as a child of TickSystem; subscribe to its `timeout` signal; `tick_fired` fires from the Timer callback.
- **Pros**: Even cleaner than `_process` accumulator — Godot manages the timer queue.
- **Cons**: Timer nodes are subject to frame-rate aliasing on slow frames. A 30-fps frame (33ms) can fire two 50ms timers but emit them in the same frame, while a 10-fps frame (100ms) can lose a tick if the Timer's internal scheduling doesn't catch the missed deadline. Frame-rate independence is the entire point of having a Sim Clock distinct from Wall Clock — Timer nodes don't guarantee it.
- **Estimated Effort**: Comparable to chosen approach.
- **Rejection Reason**: Frame-rate independence guarantee. The integer accumulator pattern recovers cleanly from variable frame times because it processes whole-tick increments per frame regardless of how many ticks elapsed.

### Alternative 3: Separate Wall Clock and Sim Clock autoloads

- **Description**: Two autoloads — `WallClock` (rank 0) reads `Time.get_unix_time_from_system()`; `SimClock` (rank 1) holds the tick counter and emits `tick_fired`. Save/Load talks to WallClock for timestamps; Economy talks to SimClock for ticks.
- **Pros**: Single Responsibility Principle; clearer testing surfaces; each clock can be independently mock-injected.
- **Cons**: Doubles the autoload rank table entries; the two clocks are coupled at session-boundary moments (sim resets when wall says "new cold launch"; wall reads sim for heartbeat); inter-autoload coupling at rank 0/1 means SimClock connects to WallClock signals at `_ready()`. Splits no real concern at the cost of structural complexity.
- **Estimated Effort**: ~2x of chosen approach.
- **Rejection Reason**: Premature decomposition. The two clocks share a single owner (the session) and a single set of state transitions (FG/BG/UI-paused). Splitting them violates the YAGNI principle without solving any current problem.

### Alternative 4: Persist sim tick counter across launches

- **Description**: Save `_sim_tick_counter` to disk; on cold launch, restore it instead of resetting to 0. Sim ticks become a global monotonic counter usable as a save-file key or analytics deduplication ID.
- **Pros**: Cross-session analytics get a free deduplication key; consumers have a stable per-session ID without needing UUIDs.
- **Cons**: Sim tick counter is fundamentally a session-scoped concept — it's an integer count of foreground-active ticks since cold launch. Making it cross-session breaks that mental model. Forces a save schema migration (any persisted tick counter from before this change is meaningless after the change). The use cases (analytics deduplication, save-file key) are better served by `_meta.save_sequence_number` (ADR-0004) which is purpose-built and increments per persist.
- **Estimated Effort**: Low to add; high to remove later.
- **Rejection Reason**: Conceptual coherence. The GDD explicitly states sim tick counter is session-scoped; persisting it confuses two concepts. ADR-0004's `save_sequence_number` already covers the use cases.

## Consequences

### Positive

- **Locks Pillar 1 invariant architecturally**. `_process(delta)` as economy input is now a registered FORBIDDEN pattern; future stories cannot drift into using it. The single Wall Clock call site (TickSystem boundary) eliminates the "dozens of `Time.get_unix_time_from_system()` calls scattered through code" failure mode.
- **Locks the synchronous-emission contract**. Future "performance optimization" attempts to defer `tick_fired` will be caught at code review (the FORBIDDEN pattern in registry).
- **Heartbeat persist size cap (≤512 bytes) preserved**. Refines ADR-0004's full-envelope contract with an explicit partial-envelope path. Mobile battery and crash-recovery latency stay bounded.
- **Debug-only test surface formalized**. AC-SL-05, AC-SL-09, AC-SL-TAMPER-04 deterministic testing is unblocked without rearchitecting TickSystem as DI-accepting for MVP.
- **State-vs-signal ambiguity resolved**. The two `flag_suspicious_timestamp` concepts are now distinguished in code (`_flag_suspicious_timestamp: bool` private field vs `flag_suspicious_timestamp_emitted` signal). Future readers cannot confuse them.
- **Surfaces ADR-0003 rank invariant phrasing imprecision**. The invariant as written prohibits forward-listening (rank 2 listening to rank 0 emission), which is actually safe and required. Documented as OQ-6 for ADR-0003 amendment.

### Negative

- **TICKS_PER_SECOND is hardcoded**. Designers cannot tune it without a superseding ADR. This is intentional — changing it changes downstream economy assumptions and the offline-replay tick budget — but is friction.
- **Heartbeat envelope path is a refinement to ADR-0004**. SaveLoadSystem gains a second persist method (`request_heartbeat_persist`) with a partial-envelope contract. Implementation must enforce dict-shape strictly to prevent consumer-state from leaking into heartbeat envelopes.
- **Wall Clock single-call-site rule is convention-enforced, not language-enforced**. A developer can still call `Time.get_unix_time_from_system()` directly anywhere. Mitigation: code review checklist + grep CI rule once `/architecture-review` matures.
- **Debug-only methods rely on runtime guard**, not compile-time `const`. Release builds no-op the methods but still pay the dispatch cost (sub-microsecond, negligible). Compared to Save/Load's `integrity_check_enabled` compile-time const pattern, this is a weaker defense.

### Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Developer adds a `call_deferred` to `tick_fired` emission as a "performance fix" | Medium | High (breaks ordering guarantees; offline replay determinism degrades) | Registry forbidden_pattern: `deferred_tick_emission`; code review; `/architecture-review` static-grep for `tick_fired.emit.call_deferred` and `call_deferred("emit_signal", "tick_fired", ...)` |
| Developer calls `Time.get_unix_time_from_system()` directly outside TickSystem | Medium | Medium (silent drift from int64 vended value; potential float rounding bugs at session boundaries) | Registry forbidden_pattern: `wall_clock_read_outside_tick_system`; CI grep for non-TickSystem references |
| Heartbeat envelope grows beyond 512 bytes through field creep | Low | Medium (mobile battery degrades; crash-recovery latency drifts) | `request_heartbeat_persist` asserts dict shape strictly; AC-TICK-11 (heartbeat crash recovery) measures actual envelope size in CI |
| BG entry doesn't reset accumulator residual; resume re-applies it (silent ≤50ms phase shift) | Low | Medium (cumulative drift across many BG↔FG cycles; offline-replay determinism degrades) | Registry forbidden_pattern: `discarding_accumulator_residual_on_pause`; AC-TICK-04 verifies accumulator preservation across BG↔FG transition |
| Save/Load incorrectly invokes `set_last_persist_ts` from a non-SaveLoad context (e.g., Economy attempts to "stamp time" on a transaction) | Low | High (Time System invariant violation; rewind detection unreliable) | Debug-build assert via `get_stack()` caller-check; convention enforcement via code review; coding-standards.md adds "Time System write-access" section |
| `OS.is_debug_build()` returns true unexpectedly in production (e.g., wrong export preset) | Low | Medium (debug methods become callable in production; mock-clock injection becomes a cheat vector) | AC-SL-TAMPER-05 CI scan pattern: grep for unguarded debug method bodies fails the build; release pipeline asserts export preset = release |
| ADR-0003 rank invariant phrasing causes future reviewers to flag legitimate forward-listening as a violation | Medium | Low (review-cycle friction; no runtime impact) | OQ-6 in this ADR proposes ADR-0003 amendment; resolve before next ADR drafted that involves cross-rank signal subscription. **godot-specialist Step 4.5 confirmed the OQ-6 analysis**: signal subscription is universally safe across rank pairs at `_ready()` time; only state reads are constrained. |
| `tick_fired` synchronous-delivery ordering between consumers depends on signal connection order, which coincides with autoload rank order only because Economy (rank 3) registers its connection before DungeonRunOrchestrator (rank 14). A future rank reassignment could silently invert Economy ↔ Orchestrator processing within a tick. | Low | Medium (silent ordering inversion; outcome computation pre-economy update would produce stale gold balances mid-tick) | Any rank reassignment touching ranks 3-14 must include a code-review checklist item verifying `tick_fired` consumer ordering remains Economy → Orchestrator → View. Document in coding-standards.md alongside the rank reassignment protocol. (godot-specialist Step 4.5 Note 3) |

## Performance Implications

| Metric | Before | Expected After | Budget |
|---|---|---|---|
| CPU per frame (TickSystem `_process`) | N/A | Accumulator increment + 0-2 `tick_fired` emissions per frame at 60fps (typically 0.03 ticks per frame, occasional 1) | < 0.1ms per frame (negligible) |
| CPU per heartbeat | N/A | 1 SaveLoadSystem.request_heartbeat_persist call: HMAC over ~50-byte payload + atomic rename. Sub-millisecond on PC, ~1-5ms on mobile | < 5ms per heartbeat (every 60s — negligible aggregate) |
| CPU per offline replay | N/A | Direct batch-API invocation on Economy + Orchestrator with N ticks; no signal emission overhead | AC-TICK-10: < 500ms total for 576,000-tick worst case on min-spec mobile |
| Memory | N/A | TickSystem state: ~64 bytes (counters, flags, accumulator). Heartbeat envelope buffer: ~512 bytes transient. | 512MB PC / 256MB mobile — negligible |
| Save file size (heartbeat) | N/A | Heartbeat envelope: 44-byte ADR-0004 header/footer + ~50-byte time fields JSON = ~94 bytes per heartbeat. | Heartbeat ≤ 512 bytes per Rule 10 — well under budget |
| Save file size (full state) | N/A | Per ADR-0004 budget — heartbeat does NOT contribute to full-state size | 20KB MVP / 200KB V1.0 (per ADR-0004) |

## Migration Plan

**No migration required for MVP** — no shipped saves exist. This ADR codifies the contracts the first MVP build will implement.

**Post-MVP changes**:
- TICKS_PER_SECOND change requires a superseding ADR + downstream economy formula audit + AC-TICK-10 re-verification under the new tick budget.
- Heartbeat envelope schema change (e.g., adding a fourth time field) requires a save-format VERSION bump per ADR-0004 + migration function.
- Adding a third clock concept (e.g., a "real-time event scheduler") requires a new ADR; do NOT extend TickSystem to own a third clock — Wall and Sim are the right granularity.

**Rollback plan**: If the `_process` accumulator pattern proves problematic in production (e.g., a Godot 4.7 change causes drift), supersede with Alternative 2 (Timer node) and accept the frame-rate-aliasing risk OR Alternative 1 (`_physics_process` + global tick rate) and accept the physics-coupling risk. Saves migrate trivially: TickSystem state is ephemeral; only persisted timestamps move forward.

## Validation Criteria

- [ ] AC-TICK-01 passes: 20Hz tick delivery is exact under varying frame rates (10fps, 30fps, 60fps, 144fps).
- [ ] AC-TICK-02 passes: offline elapsed calculation (Formula D.2) returns correct values across normal, capped, future-timestamp, and rewind cases.
- [ ] AC-TICK-04 passes: BG↔FG transition preserves accumulator residual (no ≤50ms phase shift).
- [ ] AC-TICK-05 + AC-TICK-05b pass: clock-rewind detection fires `flag_suspicious_timestamp_emitted` on bool transition; in-session rewind detection via high-water mark works.
- [ ] AC-TICK-08 passes: offline batch delivery does NOT emit `tick_fired`; consumers receive `compute_offline_batch(n)` calls directly.
- [ ] AC-TICK-09 (ADVISORY): per-tick dispatch budget under 1ms PC / 5ms mobile.
- [ ] AC-TICK-10 (BLOCKING): offline replay of 576,000 ticks completes under 500ms on min-spec mobile.
- [ ] AC-TICK-11 passes: heartbeat persist + crash-recovery loses ≤60s of progress (heartbeat_interval_seconds default).
- [ ] AC-TICK-13 passes: intra-session BG↔FG cycling does NOT re-fire offline replay (one-shot flag in-process).
- [ ] AC-SL-09 passes: SaveLoadSystem receives `flag_suspicious_timestamp_emitted` in its `_ready()`-time subscription; debug mock-clock invocation produces deterministic test outcomes.
- [ ] No `Time.get_unix_time_from_system()` call outside TickSystem (verifiable by CI grep).
- [ ] No `tick_fired.emit.call_deferred` or `call_deferred("emit_signal", "tick_fired", ...)` anywhere (verifiable by CI grep).
- [ ] Heartbeat envelope size measured ≤512 bytes in AC-TICK-11 telemetry.
- [ ] OQ-6 resolved (ADR-0003 rank invariant phrasing amendment) before next ADR involving cross-rank signal subscription is drafted.

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|---|---|---|---|
| `design/gdd/game-time-and-tick.md` §Architecture — Godot Host | Time | "Implemented as a Godot autoload singleton named `TickSystem`; signal/notification host" | Codifies `TickSystem` as autoload identifier at rank 0; reconciles with ADR-0003 rank table (architecture.md update fold-in). |
| `design/gdd/game-time-and-tick.md` §Core Rules 1-4 | Time | "Two clocks strictly separated; sim ticks at 20Hz integer counter; Wall Clock is float→int64 cast at single call site; `_process(delta)` forbidden as economy input" | Locks Wall Clock single-call-site, Sim Clock 20Hz `_process` accumulator pattern, the `_process(delta)` forbidden-as-economy-input invariant in registry. |
| `design/gdd/game-time-and-tick.md` §Core Rules 5 + AC-TICK-04 | Time | "Pause preserves accumulator residual; reset is prohibited" | Explicit FORBIDDEN pattern in registry: `discarding_accumulator_residual_on_pause`. |
| `design/gdd/game-time-and-tick.md` §Core Rules 7-8 + AC-TICK-08 | Time | "tick_fired synchronous emission; offline replay does NOT emit tick_fired (uses batch APIs)" | Both contracts locked; FORBIDDEN patterns in registry: `deferred_tick_emission`, `tick_fired_during_offline_replay`. |
| `design/gdd/game-time-and-tick.md` §Core Rules 9-10 + AC-TICK-11 | Time | "Session high-water field; heartbeat payload ≤512 bytes; full state on graceful exit only" | Codifies the heartbeat envelope as a partial-envelope refinement to ADR-0004; SaveLoadSystem.request_heartbeat_persist contract. |
| `design/gdd/game-time-and-tick.md` §States and Transitions | Time | "FOREGROUND / BACKGROUNDED / OFFLINE-derived; UI-paused as FG substate; platform-specific notification mapping" | State machine + notification mapping locked in Decision diagram. |
| `design/gdd/game-time-and-tick.md` §Signal Declarations (Pass-TS-DEBUG-API) | Time | "tick_fired, offline_elapsed_seconds (one-shot), flag_suspicious_timestamp_emitted (one-shot per launch on bool transition)" | All three signal contracts locked verbatim with the `flag_suspicious_timestamp_emitted` state-vs-signal distinction codified. |
| `design/gdd/game-time-and-tick.md` §Debug-Only Test Surface (Pass-TS-DEBUG-API) | Time | "debug_set_unix_time / debug_clear_unix_time runtime-gated by OS.is_debug_build(); accepts runtime-check-not-compile-time-const because method body cannot be const-gated" | Codifies the debug surface; ties to AC-SL-TAMPER-05 CI scan pattern for production-exposure defense. |
| `design/gdd/game-time-and-tick.md` §Interactions with Other Systems — Save/Load | Time | "Save/Load is sole external writer to last_persist_unix_ts and t_session_high_water; bidirectional contract on load" | Codifies the bidirectional contract; assert-based dev-build defense + convention-enforced production. |
| `design/gdd/game-time-and-tick.md` §Tuning Knobs | Time | "TICKS_PER_SECOND default 20 (safe range 10-60 designer-facing context only); offline_cap_seconds, REWIND_TOLERANCE_SECONDS, heartbeat_interval_seconds are runtime-tunable" | Locks TICKS_PER_SECOND as architectural (NOT a runtime tuning knob); the other three are listed as `@export` runtime-tunable per the GDD. |

## Related Decisions

- ADR-0003 (Autoload Rank Table, Accepted) — establishes rank 0 for TickSystem; ALSO surfaces the rank invariant phrasing imprecision flagged in OQ-6 below.
- ADR-0004 (Save Envelope, Accepted) — establishes the full-envelope persistence contract; this ADR refines it with the heartbeat partial-envelope path.
- ADR-F04 (Data Loading, planned) — independent peer; both are Foundation.
- ADR-F05 (Scene Transition + Persist, planned) — depends on this ADR for the heartbeat path; transitions that cross persistence boundaries trigger a full-envelope persist (per ADR-0004), heartbeats fire on the 60s schedule (per this ADR).
- `design/gdd/game-time-and-tick.md` — full implementation spec (this ADR's source of truth).
- `design/gdd/save-load-system.md` Pass-5C + Pass-TS-DEBUG-API reconciliation — origin of the `flag_suspicious_timestamp_emitted` signal contract.
- `docs/engine-reference/godot/modules/autoload.md` Claim 1 [VERIFIED] — empirical evidence backing the cross-rank subscription pattern.
- `docs/architecture/architecture.md` §Autoload Rank Table — the rank-0 entry currently labeled "GameTimeAndTick" is updated to `TickSystem` alongside this ADR (GDD sync update).

## Open Questions Created by This ADR

- **OQ-6 (ADR-0003 rank invariant phrasing)**: ADR-0003 §"A rank-N autoload may connect to a rank-M autoload's signal in its own `_ready()` ONLY if M > N" is too strict as written. The autoload Claim 1 [VERIFIED] result establishes that signal SUBSCRIPTION (the higher-rank node connecting to the lower-rank node's signal) is safe regardless of rank order, because all autoload Nodes are in the tree before any `_ready()` fires. The actual invariant is: at `_ready()` time, do not READ STATE that another autoload sets in its own `_ready()` body — and `_ready()` order is rank-sequential, so a higher-rank `_ready()` cannot read state set by a lower-rank `_ready()` because the lower-rank's `_ready()` hasn't run yet. The forbidden case is "lower-rank reads higher-rank state", not "higher-rank subscribes to lower-rank signal". Recommend: amend ADR-0003 with a clarifying note. Non-blocking for this ADR's acceptance; resolve before the next ADR involves cross-rank signal subscription mechanics.
