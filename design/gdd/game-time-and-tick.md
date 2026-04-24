# Game Time & Tick System

> **Status**: Revised — ready for re-review + **Pass-TS-DEBUG-API applied 2026-04-21 — Save/Load cross-GDD request D5C-1 landed** + **Pass-ADR-0014-SYNC applied 2026-04-22 — ADR-0014 Accepted: `offline_elapsed_seconds(secs: float, cap_reached: bool)` signal's sole subscriber is now canonically OfflineProgressionEngine rank 15 autoload (not Orchestrator direct); AC-TICK-10 clarification — the 500ms/16ms budget targets per-chunk CPU wall time (BLOCKING), not total wall-clock-including-yield which has a separate ADVISORY ≤5s Android ANR headroom budget; TickSystem itself does NOT chunk — OfflineProgressionEngine owns the adaptive chunking policy per ADR-0014 §3; `tick_fired` not-during-offline-replay invariant from Pass-5D §D.3 is now CI-enforced via ADR-0014's `per_chunk_domain_signal_emission_during_offline_replay` forbidden pattern.**
> **Author**: systems-designer + qa-lead + main session; major revision 2026-04-19 after 7-specialist adversarial review; Pass-TS-DEBUG-API 2026-04-21 main session (Save/Load cross-GDD request fulfillment)
> **Last Updated**: 2026-04-21 (Pass-TS-DEBUG-API 2026-04-21 — added 3 debug-only test-surface methods to fulfill Save/Load GDD #3 Pass-5C D5C-1 cross-GDD request: `TickSystem.debug_set_unix_time(t: int)`, `TickSystem.debug_clear_unix_time()`, `TickSystem.debug_emit_suspicious_timestamp(prev: int, curr: int)`, all guarded by `if OS.is_debug_build():` compile-time-equivalent runtime check; added formal `flag_suspicious_timestamp_emitted(previous_ts: int, current_ts: int)` SIGNAL declaration to reconcile against Save/Load AC-SL-09's Pass-5C signal-framing correction (prior D.2 framing treated it as a session bool field only — it is BOTH: session state AND a signal fired when the state transitions true; signal is the Save/Load-consumer-facing contract, the field is the Time-System-internal state). Unblocks AC-SL-05 + AC-SL-09 + AC-SL-TAMPER-04 execution-ready state in Save/Load GDD. Prior: 2026-04-19 Revised — ready for re-review.)
> **Implements Pillar**: Pillar 1 — *Respect the Player's Time* (the game earns time by being there on return, not by demanding attention)
> **Creative Director Review (CD-GDD-ALIGN)**: REJECT on 2026-04-19 first pass — 7 blocking items; all addressed in this revision. Re-review pending.

---

## Overview

The Game Time & Tick System is the authoritative source of time for *Lantern Guild*. It provides two strictly separated clocks — a **Wall Clock** used only for session-boundary persistence, and a **Simulation Clock** that ticks at 20 Hz while the app is foregrounded and drives every downstream economy and run-resolution event. It owns the timestamp written into the save file at session close and the offline-elapsed calculation performed at session start.

This is pure infrastructure. Players never interact with it. But every felt moment in the game — the accumulated gold on return-to-app, the drip of loot during a dungeon run, the pacing of a recruit's level-up — reads from this system's output. Get it wrong and Pillar 1 is violated at the root: offline progression feels unfair, arbitrary, or exploitable.

The single inviolable rule: **`_process(delta)` is never an input to economy math.** Frame rate, frame drops, and resume-after-pause all corrupt `delta`. Economy integrity requires a fixed-rate simulation tick and a monotonic wall clock, strictly separated.

---

## Player Fantasy

This system has no direct player fantasy — it is infrastructure the player never sees. It serves the fantasy by making one thing true: **"whatever the app was doing while I was gone, it was doing it honestly."**

The emotional payload lives at the boundary the Time System guards: the moment the app reopens and the Return-to-App screen reports accumulated gold. If that number is too small, the player feels cheated. If too large, the number loses weight. If different across sessions, the player stops trusting the game. The Time System's job is to make the number *correct and boring* — a precondition the player will never notice, but whose absence would destroy the loop.

The indirect fantasy served: *"my heroes were working while I slept."* The Time System is the ledger that makes that sentence accurate.

---

## Detailed Rules

### Architecture — Godot Host

The Time System is implemented as a **Godot autoload singleton named `TickSystem`** (a Node-derived script). Autoload registration is the only supported deployment — downstream systems connect to `TickSystem.tick_fired` by name at their `_ready()`. The autoload is the single receiver of OS-level notifications and the single owner of the sim-clock state.

Rationale: signals require a concrete Object host; `_notification(what)` is a Node virtual. Any non-Node implementation cannot receive `NOTIFICATION_APPLICATION_PAUSED` (mobile) or `NOTIFICATION_WM_WINDOW_FOCUS_OUT` (desktop). Autoload also matches the "no upstream dependencies" declaration — no scene tree hookup required.

### Core Rules

The time system is built on a single inviolable premise: **economy math never reads frame delta.** Two clocks exist with strictly separated jurisdictions.

**Wall Clock** is read via `Time.get_unix_time_from_system()`, which returns a `float` in Godot 4.6. The Time System casts this to `int64` at the single call site: `int(Time.get_unix_time_from_system())`. All downstream math uses the integer form. Downstream systems never call the Godot API directly — they read the Time System's vended value.

**Simulation Clock** is an integer tick counter maintained by the Time System. It increments at a fixed rate of **20 ticks per second (20 Hz)** while the app is foregrounded and not paused. It does not map 1:1 to wall-clock seconds; it is a pure counter with no calendar meaning. The simulation clock is **session-scoped and resets to 0 on every cold launch** — it is NOT a persistent or globally unique identifier. Consumers must not use `tick_number` from `tick_fired(n)` as a save-file key or analytics deduplication ID.

**Why 20 Hz:**
- Coarser than frame rate (60 fps), so economy events are frame-rate-independent.
- Fine enough that 1 tick = 50 ms, which is imperceptible lag for an idle game.
- Integer division from wall-clock seconds is exact: 20 ticks/sec × N seconds = integer tick count with no remainder accumulation.
- Offline replay: converting N offline seconds to N × 20 ticks is trivially auditable.

**Why `_process` accumulator over `_physics_process`:** `Engine.physics_ticks_per_second = 20` would work but couples the economy tick rate to the physics step globally. We use `_process(delta)` with an integer-accumulator pattern so the physics step (60 Hz default) stays independent. `_process(delta)` is used only for rendering, animation interpolation, and this tick accumulator — never as an input to any formula that produces loot, currency, or run outcomes.

**Numbered rules:**

1. The simulation clock is the authoritative source for in-session economy cadence. No other system increments it.
2. The wall clock is the authoritative source for session boundary timestamps. No other system writes the "last persist" timestamp.
3. `_process(delta)` is forbidden as an economy input. Violations are architecture errors, not tuning problems.
4. The simulation clock is always a non-negative integer. It never decreases while the app is alive. It resets to 0 on every cold launch — session-scoped only.
5. Time may be paused (simulation clock freezes) in three conditions: mobile BACKGROUNDED state, PC focus-loss (window unfocused), and explicit UI pause (e.g., settings menu open). The wall clock is never paused — it is read-only from the OS. While paused, `tick_fired` is NOT emitted — consumers must not expect ticks to fire-and-be-ignored. The pause happens at source. **Accumulator state is preserved across pause**: the `_process` fractional-delta accumulator retains its residual value when entering a pause state and resumes from that value on unpause. Discarding the residual (implementing pause as "reset accumulator to 0") is prohibited — it introduces a silent ≤50ms tick-phase shift per pause cycle, which compounds over Steam Deck sleep/wake sequences and breaks offline-replay determinism assumptions. See AC-TICK-04 for verification.
6. Anti-tamper at this layer is limited to monotonicity enforcement against the persisted high-water mark (see F.1 below and Formulas D.4). Hard anti-cheat (ban flag escalation, save lock) lives in Save/Load; this layer enforces the timestamp floor and signals the `flag_suspicious_timestamp` event.
7. **`tick_fired` emission is synchronous** within `_process`. Deferred emission (`call_deferred`, `emit_signal.call_deferred`) is prohibited — ordering guarantees for consumers depend on synchronous delivery.
8. **Offline replay does NOT emit `tick_fired`.** The Offline Progression Engine invokes batch APIs on consumers directly (`economy.compute_offline_batch(n)`, `dungeon.compute_offline_batch(n)`). The `tick_fired` signal is a foreground-only contract. See D.3 and AC-TICK-08.
9. **Session high-water field F.1 (`t_session_high_water`)** is persisted in the save file and signed by Save/Load. It is updated by the Time System on every heartbeat and on graceful exit: `t_session_high_water = max(t_session_high_water_prev, t_current)`. The rewind detector in D.4 compares against this high-water mark, not just `t_last_persist`.
10. **Heartbeat payload constraint.** The 60s heartbeat writes `{t_last_persist, t_session_high_water, sim_tick_counter}` only — ≤512 bytes. Full state serialization happens on graceful exit and manual save-trigger only, never on heartbeat.

### States and Transitions

The system occupies exactly one of three states at any time.

**FOREGROUND** — App is the active process and window is focused. `_process` runs, simulation clock ticks at 20 Hz. Wall clock is sampled periodically (every `heartbeat_interval_seconds`, default 60s) as a heartbeat persist checkpoint, so that a crash or OS kill always leaves a recent timestamp. The Dungeon Run Orchestrator receives tick events. Economy sinks/faucets fire on tick schedule.

**BACKGROUNDED** — App is suspended (mobile) or its window has lost focus (PC). `_process` stops. Simulation clock freezes. Before entering this state, the Time System writes the current wall-clock timestamp to the heartbeat checkpoint and updates the session high-water mark. No economy events fire. No `tick_fired` is emitted.

**OFFLINE** — This is not a runtime state of the app; it is a computed state derived at next launch. The Time System reads `(current_wall_clock − last_persist_timestamp)`, applies the offline elapsed formula (D.4), and emits a single `offline_elapsed_seconds` signal (with companion `cap_reached: bool`) to subscribers. This is a one-shot event at session start; there is no "offline mode" the running app enters.

**Platform-specific trigger mapping:**

| Platform | BACKGROUNDED trigger | FOREGROUND trigger |
|---|---|---|
| Mobile (Android/iOS) | `NOTIFICATION_APPLICATION_PAUSED` | `NOTIFICATION_APPLICATION_RESUMED` |
| PC (Windows/macOS/Linux) | `NOTIFICATION_WM_WINDOW_FOCUS_OUT` (alt-tab or minimize) | `NOTIFICATION_WM_WINDOW_FOCUS_IN` |

The PC branch uses focus-loss semantics (alt-tab pauses the sim clock), matching the mobile behavior conservatively. A player who alt-tabs triggers BACKGROUNDED; on return, the session-start offline-replay path does NOT refire (replay is cold-launch-only). Heartbeat on BG entry bounds the recovery window.

**Transition table:**

| From | Event | To | Boundary Action |
|---|---|---|---|
| — | App launch, no prior save | FOREGROUND | Seed `last_persist_ts = now`; seed `t_session_high_water = now`; emit `offline_elapsed_seconds = 0, cap_reached = false` |
| — | App launch, prior save exists | FOREGROUND | Compute offline elapsed (D.4); emit `offline_elapsed_seconds` and `cap_reached`; start sim clock at 0 |
| FOREGROUND | OS pause / WM focus-out | BACKGROUNDED | Write `last_persist_ts = now`; update `t_session_high_water = max(prev, now)`; freeze sim clock |
| BACKGROUNDED | OS resume / WM focus-in | FOREGROUND | Resume sim clock; do NOT recompute offline elapsed (session-start one-shot) |
| FOREGROUND | UI pause (settings menu open) | FOREGROUND (paused) | Freeze sim clock; heartbeat continues to fire |
| FOREGROUND (paused) | UI pause released | FOREGROUND | Resume sim clock |
| FOREGROUND | App shutdown (graceful) | — | Write `last_persist_ts = now`; update `t_session_high_water`; flush full save |
| FOREGROUND | App crash / OS kill | — | Last heartbeat checkpoint is the recovery point (≤60s loss) |

The BACKGROUNDED → FOREGROUND transition intentionally does not re-fire the offline elapsed calculation. Offline progression is replayed once at session start, not incrementally on every resume. The **one-shot replay flag is process-scoped** (in-memory only, not persisted). Cold launch always re-fires replay; in-session BG↔FG cycles do not.

UI pause (settings menu, modal dialogs) freezes the sim clock but is a substate of FOREGROUND — `_process` still runs (heartbeat continues), only tick emission is suppressed. The UI layer is responsible for displaying a "Simulation paused" affordance when entering a UI-pause context that lasts more than a few seconds; this is a cross-system UX contract, not a Time System responsibility.

### Interactions with Other Systems

**Economy System**
- Reads from Time System (foreground): subscribes to `tick_fired(tick_number: int)` and schedules its own sinks/faucets at tick multiples.
- Reads from Time System (session start): the `offline_elapsed_seconds` and `cap_reached` signal values are passed through the Offline Progression Engine, which invokes `economy.compute_offline_batch(tick_count)` directly — Economy does NOT receive `tick_fired` during offline replay.
- Writes to Time System: nothing. Economy is a consumer.

**Save/Load System**
- Reads from Time System: `last_persist_unix_ts` (int64 Unix seconds) and `t_session_high_water` (int64) to embed in the save file. Both fields must be covered by Save/Load's signature — unsigned fields are trivially tamperable.
- Writes to Time System: `last_persist_unix_ts` and `t_session_high_water` on load (restoring prior session state). These are the only external writes permitted.
- **Contract**: Save/Load must reject any loaded `last_persist_unix_ts > t_current + 300` (future timestamp — likely cloud-save poisoning) and fall back to seeding both fields with `t_current`. This protects against the "forged future timestamp soft-bricks account" vector.
- **Contract**: Save/Load owns `flag_suspicious_timestamp` escalation — cumulative counter, threshold, and action (log-only, save-lock, etc.) are specified in the Save/Load GDD. The Time System only sets the flag for the current session; it does not count or persist repeat offenses.
- The Save/Load system owns hard anti-tamper (signature/hash checks). The Time System provides raw timestamps and enforces only monotonicity vs the high-water mark.

**Offline Progression Engine**
- Reads from Time System: the one-shot `offline_elapsed_seconds` signal value (float, already capped) and its companion `cap_reached: bool`.
- Converts seconds to sim ticks via the wall-to-ticks formula (D.3).
- **Invokes downstream batch APIs directly**: `economy.compute_offline_batch(tick_count)`, `dungeon.compute_offline_batch(tick_count)`. Does NOT re-emit `tick_fired`. This is the signal-bypass path required by performance (see AC-TICK-10).
- The Offline Engine does not call any Time System API after session start. It receives its budget once and is responsible for replaying it.

**Dungeon Run Orchestrator**
- Reads from Time System: `tick_fired(tick_number)` signal while FOREGROUND.
- Reads from Offline Engine (not Time System directly) via `dungeon.compute_offline_batch(tick_count)`: the tick budget for offline replay.
- The Orchestrator must not use wall-clock deltas for run outcome math. All run timing is in ticks.

**Return-to-App Screen** (downstream presentation layer — GDD not yet written)
- Reads from Time System (indirectly, via Offline Engine handoff): `cap_reached: bool`. When true, must display a player-facing "You earned the maximum 8h of rewards (cap reached)" line alongside the reward summary. The cap-reached signal is the cross-system contract that makes Pillar 1 honest — silent clamping is information suppression, not respect.

---

### Signal Declarations (Pass-TS-DEBUG-API 2026-04-21 — reconciliation with Save/Load GDD Pass-5C)

The Time System exposes the following signals on its autoload singleton. All signals are documented here as the authoritative public contract; consumers (Save/Load, Offline Progression Engine, Economy, Dungeon Run Orchestrator) connect to them in their `_ready()` via `TickSystem.signal_name.connect(listener)`.

```gdscript
# Foreground-only tick signal. Synchronous emission inside _process.
signal tick_fired(tick_number: int)

# One-shot signal fired once per cold launch, after offline elapsed has been computed.
signal offline_elapsed_seconds(seconds: float, cap_reached: bool)

# Clock-rewind detection signal (Pass-TS-DEBUG-API 2026-04-21 — formal declaration added to
# reconcile with Save/Load GDD #3 AC-SL-09 Pass-5C signal-framing correction).
#
# Fires when the Formula D.2 rewind branch executes — i.e., when
# elapsed_raw < -REWIND_TOLERANCE_SECONDS. Emits ONCE per launch regardless of how
# many subsequent heartbeats observe the rewound state (the session-scoped
# flag_suspicious_timestamp bool tracks per-session state; the signal fires on the
# transition false → true only).
#
# previous_ts: int64 — the anchor timestamp (max of last_persist_ts and t_session_high_water)
# current_ts:  int64 — t_current at the moment of detection
#
# Save/Load AC-SL-09 listener contract: connect via
#   TickSystem.flag_suspicious_timestamp_emitted.connect(
#       SaveLoadSystem._on_time_system_flag_suspicious_timestamp_emitted)
# in SaveLoadSystem._ready(). Listener signature:
#   func _on_time_system_flag_suspicious_timestamp_emitted(previous_ts: int, current_ts: int) -> void
signal flag_suspicious_timestamp_emitted(previous_ts: int, current_ts: int)
```

**State-vs-signal relationship**: the name `flag_suspicious_timestamp` is used in two distinct senses and MUST NOT be conflated:

1. **Session-scoped bool state** (`flag_suspicious_timestamp: bool`, reset to `false` on every cold launch) — set inside the Formula D.2 rewind branch; readable by tests via the `_flag_suspicious_timestamp` private field OR the debug helper `get_meta_field` equivalent (none currently defined; not needed for MVP). The bool's value does NOT persist across launches — the Save/Load System owns the persistent cumulative counter `_meta.tamper_suspicious_count` (see Save/Load GDD `_meta` Sub-Schema).
2. **Public signal** (`flag_suspicious_timestamp_emitted(prev, curr)`) — fires when the bool transitions `false → true`. This is the Save/Load-consumer-facing contract. Save/Load AC-SL-09 asserts listener receipt; Save/Load's `_escalation_pending` in-memory flag is set by the listener and drained on the next persist.

Prior revisions of this GDD + Save/Load referred to "the flag" without distinguishing the two; Pass-TS-DEBUG-API formalizes both and commits the signal declaration above as the authoritative public contract.

---

### Debug-Only Test Surface (Pass-TS-DEBUG-API 2026-04-21 — Save/Load cross-GDD D5C-1)

The Time System exposes three debug-only methods that exist solely to make deterministic automated testing possible for the Save/Load System's time-sensitive acceptance criteria (AC-SL-05 First-Launch Bootstrap; AC-SL-09 Time Rewind Escalation; AC-SL-TAMPER-04 Forward-then-Rewind Tamper Detection). These methods are the operational equivalent of a mock-clock dependency-injection seam, without requiring the Time System to be rearchitected as DI-accepting for MVP.

**Surfacing contract — all three methods MUST be runtime-gated by `if OS.is_debug_build():`.** Production exports (shipping to players) MUST NOT expose these methods as functional call targets. Enforcement pattern matches the Save/Load GDD #3 AC-SL-TAMPER-05 CI scan — a grep for method-body execution paths outside `OS.is_debug_build()` guards fails the build. **Godot 4.6 caveat (Pass-TS-DEBUG-API note)**: `OS.is_debug_build()` returns `true` when the export preset is a debug export AND when running from the editor; it returns `false` for release exports. The method-body guard is therefore a runtime check — unlike Save/Load's `integrity_check_enabled` (which is a compile-time `const`), a method body cannot be `const`-gated. For MVP, the runtime check is acceptable because the attack surface is narrow (a `release` build will no-op the methods); the AC-SL-TAMPER-05 CI scan provides the additional defense against accidental production exposure.

```gdscript
# TickSystem autoload

var _debug_mock_unix_time: int = -1  # -1 sentinel = no mock active

# Pass-TS-DEBUG-API 2026-04-21 — overrides the return value of get_unix_time_from_system
# for the duration of the test scope. Must be paired with debug_clear_unix_time()
# in the same test's after_each() (or equivalent cleanup) to prevent mock leakage
# across tests.
#
# Argument contract: t MUST be a valid Unix timestamp (positive int64, not -1 sentinel).
# Passing t == -1 is a programmer error and triggers push_error + quit(1) in debug,
# silent no-op in release (the method is already guarded — this path never runs).
func debug_set_unix_time(t: int) -> void:
    if not OS.is_debug_build():
        return
    if t < 0:
        push_error("[TickSystem] debug_set_unix_time: t must be >= 0, got %d" % t)
        return
    _debug_mock_unix_time = t

# Pass-TS-DEBUG-API 2026-04-21 — clears the mock and restores the normal wall-clock
# read path. Idempotent: calling with no active mock is a no-op.
func debug_clear_unix_time() -> void:
    if not OS.is_debug_build():
        return
    _debug_mock_unix_time = -1

# Pass-TS-DEBUG-API 2026-04-21 — fires the flag_suspicious_timestamp_emitted signal
# directly without requiring an actual clock rewind to produce the state transition.
# Used by Save/Load AC-SL-09 fixture (clock-rewind escalation) and AC-SL-TAMPER-04
# (forward+rewind tamper detection) to achieve a deterministic signal emission
# without the test-setup complexity of driving wall-clock and high-water-mark state
# into the rewind-detection branch of Formula D.2.
#
# Does NOT set the session-scoped _flag_suspicious_timestamp bool — only emits the
# signal. Tests that assert the bool's value separately must seed it directly
# (or not — Save/Load-level tests only care about the signal per AC-SL-09 contract).
#
# Argument contract: prev and curr are int64 Unix timestamps. No validity check is
# enforced at this layer (the signal consumer owns its own validation).
func debug_emit_suspicious_timestamp(prev: int, curr: int) -> void:
    if not OS.is_debug_build():
        return
    flag_suspicious_timestamp_emitted.emit(prev, curr)
```

**Call-site contract inside the Time System's own Formula D.2 read path**:

```gdscript
# TickSystem internal: the single read-point for wall-clock time
func _read_wall_clock_unix_time() -> int:
    if OS.is_debug_build() and _debug_mock_unix_time != -1:
        return _debug_mock_unix_time
    return int(Time.get_unix_time_from_system())
```

All Time System internal references to `Time.get_unix_time_from_system()` MUST route through `_read_wall_clock_unix_time()` — otherwise the mock does not propagate to the Formula D.2 calculation. Direct calls to `Time.get_unix_time_from_system()` anywhere in TickSystem's body are a regression.

**Test usage pattern** (applies to Save/Load AC-SL-05, AC-SL-09, AC-SL-TAMPER-04):

```gdscript
# tests/unit/save_load/test_ac_sl_05_first_launch.gd (illustrative)
const T_MOCK := 1_745_000_000

func before_each() -> void:
    TickSystem.debug_set_unix_time(T_MOCK)

func after_each() -> void:
    TickSystem.debug_clear_unix_time()

func test_first_launch_seeds_last_persist_to_mock_time() -> void:
    # ... triggers first-launch bootstrap path ...
    assert_that(TimeSystem.get_last_persist_ts()).is_equal_to(T_MOCK)
```

**Integration with Save/Load debug surfaces**: this is the third in a family of debug-only hooks that Save/Load stories depend on, alongside `SaveSystem.debug_pause_before_rename()` (Save/Load Pass-5C D5C-3) and `SaveLoadFixture.corrupt_byte_at_offset()` (Save/Load Pass-5C fixture helper). All three are subject to the AC-SL-TAMPER-05 CI scan that fails builds exposing any of them outside `OS.is_debug_build()` guards.

**Scope limits — what this surface does NOT provide**:

- No `debug_advance_ticks(n)` — the sim clock itself is not mocked; tests needing deterministic tick cadence should either use `await get_tree().process_frame` with a known frame rate, or accept wall-clock-gated integration-test latency.
- No `debug_set_session_high_water(t)` — the high-water-mark state is a Save/Load-owned field hydrated via `set_session_high_water(t)` at load time; Save/Load tests that need to stage a specific high-water state use that existing public setter, not a new debug hook.
- No `debug_force_background_state()` — OS-level notifications are the sole driver of FOREGROUND ↔ BACKGROUNDED transitions; tests simulating background transitions use the integration-harness subprocess pattern (see Save/Load AC-SL-02 test_atomic_write_crash.gd for the pattern reference).

This surface is deliberately minimal. Each method's existence is justified by a specific Save/Load AC fixture that cannot be authored without it. Adding more debug hooks requires a new cross-GDD request analogous to D5C-1 — not an in-session expansion.

---

## Formulas

### D.1 Offline Cap Justification

**Default cap: 8 hours (28 800 seconds).**

Cozy-idle genre norms (Idle Heroes, AFK Arena) range 8–12 hours. 8 hours matches one full sleep cycle — the longest natural gap between sessions for a player who opens the app morning and evening. Shorter than this (e.g., 4 h) punishes players who sleep; longer (e.g., 24 h) weakens the daily re-engagement loop. The cap is a single tuning knob — extend to 12 h for launch generosity or contract to 6 h if economy tests show inflation. **Caveat**: this default is borrowed from F2P mobile precedent. *Lantern Guild* is a premium PC title with a once-or-twice-daily session pattern; the 8h default may be revisited during economy tuning and the Offline Progression Engine GDD. Flagged in Open Questions.

### D.2 Offline Elapsed Calculation (master formula)

The offline-elapsed calculation is a single composed formula. The rewind-detection branch runs **first**; only the "accept" branch applies the cap clamp. Programmers must implement this as one function with the branch structure below, not as two separate formulas.

```
# Pre-step: compute raw delta against the high-water mark, not just last-persist.
anchor = max(t_last_persist, t_session_high_water)
elapsed_raw = t_current - anchor     # int64 subtraction, result int64

# Rewind detection:
if elapsed_raw < -REWIND_TOLERANCE_SECONDS:
    elapsed_offline_seconds = 0
    cap_reached = false
    # Pass-TS-DEBUG-API 2026-04-21: set session-scoped bool AND fire the public signal
    # on the false → true transition (first occurrence per launch only; subsequent
    # heartbeat observations of rewound state do NOT re-emit — the consumer owns
    # per-session-escalation counting).
    if not flag_suspicious_timestamp:
        flag_suspicious_timestamp = true
        flag_suspicious_timestamp_emitted.emit(anchor, t_current)
else:
    # Accept path: clamp to [0, cap]. This also handles the small-negative tolerance window.
    clamped = clamp(elapsed_raw, 0, offline_cap_seconds)
    cap_reached = (elapsed_raw > offline_cap_seconds)
    elapsed_offline_seconds = float(clamped)     # int → float64 widening; GDScript float is double, safe for int64 values up to 2^53
    flag_suspicious_timestamp = false
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| current wall time | `t_current` | int64 | 0 – 2⁵³ | Unix timestamp at session launch; obtained as `int(Time.get_unix_time_from_system())` — source API returns `float` in Godot 4.6, explicit cast required |
| last persist time | `t_last_persist` | int64 | 0 – 2⁵³ | Unix timestamp stored in save file at last graceful persist or heartbeat checkpoint |
| session high-water | `t_session_high_water` | int64 | 0 – 2⁵³ | Highest wall-clock timestamp ever observed across all past sessions on this save; signed by Save/Load |
| anchor timestamp | `anchor` | int64 | 0 – 2⁵³ | `max(t_last_persist, t_session_high_water)` — prevents in-session rewind evasion |
| raw delta | `elapsed_raw` | int64 | −∞ – +∞ | `t_current - anchor`. Negative if clock was rewound past the high-water mark |
| rewind tolerance (knob) | `REWIND_TOLERANCE_SECONDS` | int | 0 – 600 | Grace window for benign clock corrections including post-sleep NTP; **default 300 (5 min)** |
| offline cap (knob) | `offline_cap_seconds` | int | 14 400 – 86 400 | Designer knob; maximum creditable offline seconds (default: **28 800 = 8 h**) |
| cap-reached signal | `cap_reached` | bool | true / false | True when `elapsed_raw` exceeded the cap before clamping. Emitted alongside `offline_elapsed_seconds` for Return-to-App Screen disclosure |
| anti-tamper flag | `flag_suspicious_timestamp` | bool | true / false | Session-scoped; resets to false on every cold launch (Save/Load owns persistent counter and escalation) |
| final output | `elapsed_offline_seconds` | float | 0.0 – `offline_cap_seconds` | Creditable offline duration, fed to Offline Progression Engine |

Note on `2^53` upper bound: GDScript's `float` is IEEE 754 double-precision (52-bit mantissa, ~9 × 10¹⁵). Unix timestamps will fit comfortably until the year ~285 million. The bound is a type-safety annotation, not a practical limit.

**Output Range**: `elapsed_offline_seconds` is clamped to [0, `offline_cap_seconds`]. `cap_reached` is true iff the raw delta exceeded the cap. `flag_suspicious_timestamp` is true iff the raw delta was less than `-REWIND_TOLERANCE_SECONDS`.

**Examples:**

- *Cap hit*: Player closes at Unix 1_745_000_000, reopens 10h later at 1_745_036_000, no prior high-water. `anchor = 1_745_000_000`, `elapsed_raw = 36_000`. `36_000 > 28_800` → `cap_reached = true`, `elapsed_offline_seconds = 28_800.0`. Return-to-App Screen displays "8h maximum reached."
- *Under cap*: Same start, reopens 2h later at 1_745_007_200. `elapsed_raw = 7_200`. `cap_reached = false`, `elapsed_offline_seconds = 7_200.0`.
- *Rewind*: `t_last_persist = 1_745_036_000`, `t_session_high_water = 1_745_036_000`, player rewinds to `t_current = 1_745_000_000`. `anchor = 1_745_036_000`, `elapsed_raw = -36_000`. `-36_000 < -300` → `elapsed_offline_seconds = 0`, `flag_suspicious_timestamp = true`.
- *Post-sleep NTP correction*: `anchor = 1_745_036_000`, `t_current = 1_745_035_900` (100s backward correction). `elapsed_raw = -100`. `-100 > -300` (within tolerance) → accept branch, `clamped = 0`, `elapsed_offline_seconds = 0.0`, flag NOT set.
- *In-session rewind (attack)*: Launch at T = 1_745_036_000; `t_session_high_water` updated to T. Play 1h (T + 3600); heartbeat at T + 3600 writes `t_last_persist = T + 3600` and `t_session_high_water = T + 3600`. Rewind clock to T + 1800; heartbeat overwrites `t_last_persist = T + 1800` but `t_session_high_water` stays T + 3600 (max-preserving). Crash; relaunch at T + 1800. `anchor = max(T + 1800, T + 3600) = T + 3600`. `elapsed_raw = T + 1800 − (T + 3600) = -1800`. `-1800 < -300` → rewind flagged. Attack detected.

### D.3 Wall-Seconds to Simulation Ticks

The wall-to-ticks conversion is defined as:

```
offline_tick_budget = int(elapsed_offline_seconds × TICKS_PER_SECOND)
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| creditable seconds | `elapsed_offline_seconds` | float | 0.0 – `offline_cap_seconds` | From D.2 |
| tick rate constant | `TICKS_PER_SECOND` | int | **constant = 20** | Fixed simulation tick rate |
| tick budget output | `offline_tick_budget` | int | 0 – `offline_cap_seconds × 20` | Integer tick count fed to Offline Progression Engine |

**Output Range**: Non-negative integer. The multiply-then-truncate form (`int(x × 20)`) is preferred over the divide form (`int(x / 0.05)`) because `0.05` is not exactly representable in IEEE 754 and can introduce a one-tick rounding error at the cap boundary. All ACs that reference this conversion must use the multiply form. Maximum value at default cap: **28 800 × 20 = 576 000 ticks**. The Offline Engine must be able to batch-replay up to this many ticks without freezing the main thread — see AC-TICK-10 (performance).

**Example**: `elapsed_offline_seconds = 28_800.0`. `offline_tick_budget = int(28_800.0 × 20) = 576_000` ticks. At 20 ticks/sec real-time equivalent, that is 8 hours of simulated game activity.

---

## Edge Cases

- **E1 — Clock rewind exceeds tolerance**: If the player rewinds the system clock by more than `REWIND_TOLERANCE_SECONDS` (default 300s) past the anchor (`max(t_last_persist, t_session_high_water)`), `elapsed_offline_seconds` is forced to 0 and `flag_suspicious_timestamp` is set for the session. The player receives no offline gains for that session. The simulation clock is unaffected (it is session-relative and does not use wall time). *Rationale*: zeroing the delta is the minimum sufficient response at this layer; cumulative counter and escalation (save-lock, etc.) are Save/Load's domain per its GDD.

- **E2 — Clock advances forward (large)**: `elapsed_raw` may be huge, but `elapsed_offline_seconds` is clamped to `offline_cap_seconds`. The player gains at most the cap value. `cap_reached = true` is emitted; the Return-to-App Screen MUST disclose "cap reached" to the player — silent clamping would hide the mechanic and violate Pillar 1's respect contract. A forward jump does NOT set the suspicious flag (indistinguishable from a legitimately long absence). Cumulative-claim heuristics (lifetime claimed vs lifetime elapsed) are Save/Load's domain and defined in its GDD.

- **E3 — Player offline for weeks or months**: `elapsed_raw` is millions of seconds. Cap clamp absorbs the excess. `cap_reached = true`. Return-to-App displays "8h maximum reached" — Pillar 1 compliance requires honest disclosure, not silence. No crash, no error, no progress cliff: the cap is a ceiling, not a wall.

- **E4 — Mobile OS kills app mid-run (heartbeat recovery)**: The last heartbeat checkpoint (written every `heartbeat_interval_seconds`, default 60s) is the recovery `t_last_persist` and `t_session_high_water`. In the worst case, the player loses up to 60 seconds of foreground progress. On next launch, D.2 is computed from that heartbeat. The Dungeon Run Orchestrator must be able to resume an in-progress run from its own serialized mid-run state — that is the Orchestrator's contract, not the Time System's. Tested by AC-TICK-11.

- **E5 — Steam Deck sleep-and-wake (multiple cycles)**: Each wake is a BACKGROUNDED → FOREGROUND transition. The Time System does NOT refire the offline elapsed signal on resume — it only fires at cold launch. Sleep/wake cycles within a live session accumulate no incremental offline credit. Post-sleep NTP corrections on the Steam Deck can step the clock backward by several minutes; `REWIND_TOLERANCE_SECONDS = 300` absorbs these as legitimate. Heartbeat checkpoints during a live session keep the save fresh for the next cold launch.

- **E6 — First-ever launch (no prior timestamp)**: `t_last_persist` and `t_session_high_water` are absent or zero in the save. The Time System detects this, seeds both fields to `t_current`, and emits `offline_elapsed_seconds = 0, cap_reached = false`. No offline replay fires. The Offline Progression Engine must handle a zero-budget input gracefully (emit empty result, return immediately).

- **E7 — DST / timezone change**: `Time.get_unix_time_from_system()` returns UTC-based Unix epoch. Timezone and DST changes do not affect Unix timestamps. A 1-hour jump backward from DST-end is well inside `REWIND_TOLERANCE_SECONDS` (300s ≥ 3600s? No — 3600 > 300, so a DST-end backward jump would actually flag as suspicious under the 300s tolerance). **Mitigation**: if DST-end false positives become a real-world issue, either detect the 3600s-exactly case as legitimate or raise tolerance. For now, the `flag_suspicious_timestamp` signal is session-scoped and has no automatic consequence — Save/Load's escalation policy decides whether a single flag triggers action. Flagged in Open Questions. Tested by AC-TICK-12.

- **E8 — Cloud save conflict between two devices (V1.0+)**: Policy is owned by Save/Load. The Time System provides two inputs: (a) pick the save with the higher `t_session_high_water` as authoritative (newer device state), and (b) reject any `t_last_persist > t_current + 300` on load as implausible (cloud poisoning defense). These two together prevent both "older save wins = phantom offline time" and "forged future timestamp = account soft-brick" failure modes. Tested at the Save/Load boundary.

- **E9 — BG→FG cycle within the same second**: Between BG entry (heartbeat writes `t_last_persist = now`) and FG return within 1 second, `t_current − anchor` is 0 or 1. D.2 yields `elapsed_offline_seconds ≈ 0`. `offline_tick_budget = 0`. But note: the session-start offline replay is a one-shot (process-scoped flag). An intra-session BG↔FG cycle does NOT re-run D.2 at all — this edge case only matters if the app is crash-killed during the cycle and then cold-launched. The one-shot flag resets on cold launch; offline replay runs normally.

- **E10 — Multiple BG entries overwrite `t_last_persist`**: Each BG entry writes the current wall-clock timestamp as the new `t_last_persist`. This is correct behavior — the most recent timestamp minimizes the maximum potential progress loss on crash. The `t_session_high_water` field is also updated via max-preserving assignment, so even if `t_last_persist` gets smaller in an attack, the high-water never regresses.

- **E11 — UI pause for an extended period**: A player opens settings and leaves the game paused for 20 minutes (phone call, dog walk, etc.). The sim clock is frozen (Rule 5); no gold drips; no ticks fire. Heartbeat continues because `_process` still runs in FOREGROUND substate. On close-settings, sim clock resumes. The UI layer MUST display a "Simulation paused" affordance on long-lived UI-pause contexts — this is a UX contract with the UI/Screen Manager, not a Time System responsibility. Without the affordance, players perceive this as an invisible punishment. This is owned by the Scene/Screen Manager GDD.

---

## Dependencies

### Upstream Dependencies (systems this one depends on)

**None.** This is a Foundation-layer system with no prerequisites. It reads directly from Godot engine APIs (`Time.get_unix_time_from_system()`, `NOTIFICATION_APPLICATION_PAUSED/RESUMED`) and exposes a tick signal + timestamp contract.

### Downstream Dependents (systems that depend on this)

All interfaces below are **one-directional** — this system emits/vends, consumers read. Exception: Save/Load writes timestamp/high-water state back into the Time System on load.

| Consumer | Hard/Soft | Data Interface | Direction |
|---|---|---|---|
| Economy System | Hard | `tick_fired(n)` signal (foreground only); `economy.compute_offline_batch(n)` is invoked by Offline Engine during offline replay | Time → Economy |
| Save/Load System | Hard | Reads `last_persist_unix_ts` (int64), `t_session_high_water` (int64), `flag_suspicious_timestamp` (bool) from Time. Writes `last_persist_unix_ts` and `t_session_high_water` back on load (sole permitted external write). Both persisted fields MUST be covered by Save/Load signature. | Bidirectional (writes restricted to timestamp fields) |
| Offline Progression Engine | Hard | `offline_elapsed_seconds` (float) and `cap_reached` (bool) one-shot signal pair at session start; receives tick budget from D.3 | Time → Offline Engine |
| Dungeon Run Orchestrator | Hard | `tick_fired(n)` signal (foreground only); `dungeon.compute_offline_batch(n)` invoked by Offline Engine during offline replay | Time → Orchestrator |
| Return-to-App Screen (future GDD) | Hard | Receives `cap_reached` indirectly via Offline Engine's reward summary; displays cap-reached disclosure to player | Time → Offline Engine → Return-to-App |

**No soft dependencies.** Every system listed needs this one to function — the Time System is the load-bearing foundation for the entire idle loop.

**Removed contracts (from prior revision):** `time_since_last_persist_seconds` is no longer vended. The prior "catchup multiplier" reference in Economy was unspecified with no consuming formula; both sides have been cleaned up. If a catchup mechanism is designed later (e.g., during Offline Progression Engine GDD authoring), it will be re-introduced with a complete formula + AC.

---

## Tuning Knobs

| Knob | Default | Safe Range | Too High | Too Low | Read By |
|---|---|---|---|---|---|
| `TICKS_PER_SECOND` | 20 | 10 – 60 | Economy events fire faster than gameplay is paced; performance hit on low-end mobile during offline replay | Economy events fire so infrequently that fine-grained timing (e.g., per-second loot) requires fractional-tick workarounds | Economy, Dungeon Run Orchestrator, Offline Progression Engine |
| `offline_cap_seconds` | 28 800 (8 h) | 14 400 – 86 400 (4 h – 24 h) | Weakens daily re-engagement loop; economy inflation if offline yield is high | Players who sleep or miss a day feel punished; negative sentiment | Offline Progression Engine, Economy |
| `REWIND_TOLERANCE_SECONDS` | **300 (5 min)** | 0 – 600 | Wide tolerance masks real clock-rewind cheating | Tight tolerance causes false positives on post-sleep NTP corrections (laptop/Steam Deck) and DST changes; legitimate players flagged | Save/Load (reads the `flag_suspicious_timestamp` output) |
| `heartbeat_interval_seconds` | 60 | 15 – 300 | Long interval means more progress lost on crash/OS kill | Frequent disk writes; battery drain on mobile | Internal (Time System only; not read by other systems) |

**Designer notes on interaction between knobs**: `offline_cap_seconds` × `TICKS_PER_SECOND` = `offline_tick_budget_max`. At defaults, that is **576 000 ticks**. The Offline Progression Engine's batch-replay performance budget is validated by AC-TICK-10 (blocking performance AC). If offline replay takes more than 500 ms at 576 000 ticks on minimum-spec mobile, either the cap must be lowered, the replay must be chunked across frames, or the batch API must adopt a closed-form computation.

**Removed knob**: `offline_grace_seconds` was previously listed here but referenced by no formula, no edge case, and no AC in this GDD. The skip-small-budgets optimization belongs in the Offline Progression Engine GDD, where the consuming logic will be defined. It has been removed from this GDD and will be reintroduced in the Offline Engine GDD with a proper formula and AC.

---

## Visual / Audio Requirements

**None.** This is pure infrastructure. Visual and audio feedback for time-related events (offline reward reveal, tick-driven idle animations, etc.) are owned by the screens and systems that consume the tick signal — primarily the **Return-to-App Screen** (offline rewards) and the **Dungeon Run View** (in-scene idle/combat animations synced to sim ticks). Those GDDs will specify their own VFX/audio requirements.

---

## UI Requirements

**None.** This system has no UI. The Time System emits signals and exposes read-only properties; it has no player-facing interface.

---

## Acceptance Criteria

All criteria below use Given-When-Then format. `TICKS_PER_SECOND = 20` (50 ms per tick) and `OFFLINE_CAP_SEC = 28 800` (8 h) unless tests parameterize otherwise. Tick-count conversions use the multiply form exclusively: `ticks = int(seconds × TICKS_PER_SECOND)`.

### AC-TICK-01: Fixed-Rate Tick Delivery (Logic, BLOCKING)

**GIVEN** 20 deterministic delta values each equal to 0.05 are fed sequentially to the tick accumulator,
**WHEN** all 20 deltas have been processed,
**THEN** exactly 20 `tick_fired` signals have been emitted — no tick is skipped, doubled, or emitted early; the accumulator residual after the 20th delta is ≤ 1e-9; and `tick_number` values are monotonically increasing integers starting from 0.

*Verification*: unit test — inject 20 × 0.05 deltas; assert signal emission count equals 20; assert recorded `tick_number` sequence is [0, 1, 2, …, 19].

### AC-TICK-02: Offline Elapsed Calculation (Logic, BLOCKING)

**GIVEN** a saved game with `last_persist_unix = T`, `t_session_high_water = T`, `OFFLINE_CAP_SEC = 28 800`, `TICKS_PER_SECOND = 20`,
**WHEN** the game loads at wall-clock time `T + D` where `D > 0`,
**THEN** `elapsed_offline_seconds = float(min(D, OFFLINE_CAP_SEC))`; `offline_tick_budget = int(elapsed_offline_seconds × TICKS_PER_SECOND)`; `cap_reached = (D > OFFLINE_CAP_SEC)`; and the `offline_elapsed_seconds` and `cap_reached` signals are emitted to the Offline Progression Engine BEFORE the first `tick_fired` signal is emitted (verified by recording signal emission order).

*Verification*: unit test — mock `Time.get_unix_time_from_system()` for `D ∈ {0, 1, 14 400, 28 800, 28 801, 86 400, 1 000 000}`; assert tick count matches `int(min(D, 28 800) × 20)` for each; assert `cap_reached` bool matches `D > 28 800`; assert signal emission order via recorded sequence.

### AC-TICK-03: Offline Cap Enforcement (Logic, BLOCKING)

**GIVEN** a player has been offline for longer than `OFFLINE_CAP_SEC`,
**WHEN** the game loads,
**THEN** `elapsed_offline_seconds` is clamped to exactly `OFFLINE_CAP_SEC`; `offline_tick_budget` equals exactly `int(28 800 × 20) = 576 000`; `cap_reached = true` is emitted alongside; the excess is discarded with no error or unexpected state change.

*Verification*: unit test — set `D = OFFLINE_CAP_SEC × 10`; assert tick count equals 576 000 exactly and `cap_reached = true`.

### AC-TICK-04: Foreground / Background State Transition (Integration, BLOCKING)

**GIVEN** the game is in FOREGROUND and emitting ticks,
**WHEN** the platform-appropriate BG trigger fires (mobile: `NOTIFICATION_APPLICATION_PAUSED`; PC: `NOTIFICATION_WM_WINDOW_FOCUS_OUT`),
**THEN** tick emission halts before the next `_process` frame completes; `last_persist_unix` is written to the save buffer with the current wall-clock timestamp; `t_session_high_water` is updated to `max(prev, now)`; no partial-interval tick is emitted after the trigger fires.

**AND WHEN** the platform-appropriate FG trigger fires (mobile: `NOTIFICATION_APPLICATION_RESUMED`; PC: `NOTIFICATION_WM_WINDOW_FOCUS_IN`),
**THEN** the system does NOT recompute offline elapsed (that is cold-launch only); foreground ticking resumes; the total count of `tick_fired` emissions attributable to the background interval is exactly zero (verified by recording tick timestamps and confirming no emission has a timestamp within the BG window); no `tick_number` sequence gap exists across the pause/resume cycle beyond the intentional freeze.

**AND** the `_process` fractional-delta accumulator is preserved across the pause: if accumulator residual was `R` seconds (0 ≤ R < 0.05) when BG fired, accumulator on FG resumption equals `R` ± 1e-9; the first post-resume tick fires after exactly `(0.05 − R)` additional accumulated delta — not after a full 0.05s interval (which would indicate accumulator was reset) and not immediately at resume (which would indicate the BG interval was counted as accumulated delta).

*Verification*: integration test — programmatic BG/FG notifications with controlled wall-clock delta; record all `tick_fired(n)` emissions with their frame index; assert zero emissions occur during the BG interval; assert state transitions; assert `t_session_high_water` non-regression; inject a BG trigger at accumulator residual 0.03s, simulate a 10s BG interval, trigger FG, then feed deltas — assert the next `tick_fired` lands exactly when cumulative post-resume delta crosses 0.02s (not 0.05s, not immediately).

### AC-TICK-05: Clock-Rewind Cheat Detection (Logic, BLOCKING)

**GIVEN** a saved game with `last_persist_unix = T` and `t_session_high_water = T`,
**WHEN** the game loads and `t_current < T − REWIND_TOLERANCE_SECONDS`,
**THEN** `elapsed_offline_seconds = 0.0`; `offline_tick_budget = 0`; `cap_reached = false`; no negative duration is passed to any consumer; `flag_suspicious_timestamp = true` for the session AND `flag_suspicious_timestamp_emitted(previous_ts=T, current_ts=t_current)` signal fires exactly once (Pass-TS-DEBUG-API 2026-04-21: signal emission contract added per Signal Declarations subsection); a warning log is emitted containing the literal string `"[TickSystem] Clock rewind detected: delta="` followed by the negative delta value; save state is not corrupted.

*Verification*: unit test — seed the wall clock via `TickSystem.debug_set_unix_time(T − 3 600)` (Pass-TS-DEBUG-API 2026-04-21 — Save/Load D5C-1 debug hook); assert tick count 0; assert bool field true; assert signal emission with expected `(previous_ts, current_ts)` via GdUnit4 `signal_collector`; assert warning string in log output; assert no exceptions. Test teardown calls `TickSystem.debug_clear_unix_time()` in `after_each()`.

### AC-TICK-05b: In-Session Rewind Detection via High-Water Mark (Logic, BLOCKING)

**GIVEN** a player launches at T, plays 1 hour (heartbeat writes `t_last_persist = T + 3600`, `t_session_high_water = T + 3600`), then rewinds the clock to `T + 1800` during the session, then experiences an OS kill,
**WHEN** the game relaunches at wall-clock time `T + 1800` (rewound) with the saved `t_last_persist = T + 1800` (rewound heartbeat) but `t_session_high_water = T + 3600` (max-preserved),
**THEN** `anchor = max(T + 1800, T + 3600) = T + 3600`; `elapsed_raw = T + 1800 − (T + 3600) = −1800`; `−1800 < −300` → `flag_suspicious_timestamp = true`, `elapsed_offline_seconds = 0`.

*Verification*: unit test — simulate the two-heartbeat sequence by directly setting saved state; assert flag true and tick count 0 on relaunch.

### AC-TICK-06: Clock Jump Forward Anti-Abuse Floor (Logic, BLOCKING)

**GIVEN** `last_persist_unix = T` where T fits in int64,
**WHEN** `t_current = T + D` where `D = INT64_MAX − T`,
**THEN** `elapsed_raw > 0` (no signed overflow); `elapsed_offline_seconds = float(OFFLINE_CAP_SEC)` (cap clamp); `offline_tick_budget = 576 000`; `cap_reached = true`; no intermediate calculation produces a negative or `+Inf` value.

*Verification*: unit test — set `D = INT64_MAX − T`; assert `elapsed_raw` is positive int64; assert tick count equals 576 000; assert no float overflow.

### AC-TICK-07: First-Launch Bootstrap (Logic, BLOCKING)

**GIVEN** the game is launched with no prior save file (all Time fields at zero or absent),
**WHEN** the TickSystem autoload initializes,
**THEN** `elapsed_offline_seconds = 0.0`; `offline_tick_budget = 0`; `cap_reached = false`; the Offline Progression Engine receives zero offline ticks; `last_persist_unix = t_current` (equal, not merely non-zero); `t_session_high_water = t_current`; `flag_suspicious_timestamp = false`; foreground ticking begins within the first `_process` frame after initialization.

*Verification*: unit test — instantiate TickSystem with empty save state; mock `t_current = T_mock`; assert `last_persist_unix == T_mock` and `t_session_high_water == T_mock` exactly; assert tick count 0.

### AC-TICK-08: Offline Batch Delivery Contract (Integration, BLOCKING)

**GIVEN** the Economy System exposes `compute_offline_batch(tick_count: int) -> OfflineResult` and the Offline Progression Engine is wired between TickSystem and Economy,
**WHEN** TickSystem emits `offline_elapsed_seconds` and `cap_reached` at cold launch with `offline_tick_budget = N`,
**THEN** the Offline Progression Engine invokes `economy.compute_offline_batch(N)` exactly once; `tick_fired` is NOT emitted during the offline replay (recorded emission count for the replay window is zero); the returned gold delta equals the closed-form expectation (e.g., for a constant drip rate `R`: `gold_delta == N × R`); and a subsequent N foreground `tick_fired` emissions on the same stubbed Economy produces the same `N × R` gold delta.

*Verification*: integration test — stub Economy class with `compute_offline_batch(n: int)` that increments a counter by `n × R` and a `_on_tick` slot that increments by `R`. Connect both. Run an offline replay with `N = 1000`, assert `compute_offline_batch` was called exactly once with argument 1000 and `tick_fired` was called zero times; assert gold delta = `1000 × R`. Separately run 1000 foreground ticks; assert same gold delta.

### AC-TICK-09: Per-Tick Dispatch Budget (Performance, ADVISORY)

**GIVEN** the game is running in FOREGROUND at 20 Hz with 4 active subscribers (Economy, Dungeon Run Orchestrator, UI HUD, Stats) connected to `tick_fired`,
**WHEN** a tick interval boundary is crossed within `_process(delta)`,
**THEN** the TickSystem's own CPU time to fan out the signal and update the accumulator — measured via `Time.get_ticks_usec()` before and after the emit — is **≤ 150 µs p99** on minimum-spec target hardware (same target device class as AC-TICK-10: Snapdragon 6xx-class ARM @ 2 GHz or equivalent; Steam Deck acceptable as a conservative desktop proxy); the TickSystem does not perform I/O, pathfinding, or per-entity iteration.

*Verification*: performance unit test — attach 4 no-op slots; sample 1000 consecutive ticks; assert p99 tick-dispatch time ≤ 150 µs. Budget revised upward from the original 50 µs after GDScript signal-dispatch benchmarking (≈10 µs per slot × 4 slots + accumulator overhead realistically lands in 50–100 µs range; 150 µs provides headroom without being permissive). Still < 1% of a 16.6 ms frame budget.

### AC-TICK-10: Offline Replay Performance Budget (Performance, BLOCKING)

**GIVEN** an offline tick budget of exactly 576 000 ticks (default cap maximum) and the Economy System's `compute_offline_batch(576_000)` is invoked on minimum-spec mobile hardware (target device: Snapdragon 6xx-class ARM @ 2 GHz or equivalent),
**WHEN** the Offline Progression Engine executes the replay,
**THEN** EITHER the total wall-clock time for `compute_offline_batch` to return does not exceed 500 ms, OR the replay is chunked across multiple frames with no single frame exceeding 16 ms in `compute_offline_batch`-attributable time; no single call stack ever blocks the main thread for more than 5 seconds (Android ANR watchdog threshold); during the replay window no visible UI freeze is perceptible beyond a loading affordance.

*Verification*: performance integration test on CI'd mobile target or the Steam Deck as a conservative desktop proxy — invoke batch with 576 000; measure wall time; assert ≤500ms total OR chunked with each chunk ≤16ms. If neither satisfiable, the cap must be reduced or the batch API must adopt a closed-form computation (multiply-only).

### AC-TICK-11: Heartbeat Crash Recovery (Integration, BLOCKING)

**GIVEN** the game has been in FOREGROUND for 120 real seconds without a pause event, with `heartbeat_interval_seconds = 60`,
**WHEN** the Time System's heartbeat timer is inspected,
**THEN** at least two heartbeat writes have occurred within the 120s window; each write updates `last_persist_unix` and `t_session_high_water` in the save buffer; each write payload is ≤ 512 bytes (per Rule 10); on simulated OS-kill and cold relaunch, `anchor` equals the most recent heartbeat timestamp within 60s of the kill moment; `elapsed_offline_seconds ≤ 60`.

*Verification*: integration test — run the autoload for 120s simulated time with deterministic deltas; assert two or more save-buffer writes of `last_persist_unix`; cold-relaunch with the post-kill wall-clock and asserted recovery within 60s.

### AC-TICK-12: DST / Timezone Invariance (Logic, BLOCKING)

**GIVEN** a saved game with `last_persist_unix = T` and `t_session_high_water = T`,
**WHEN** the system's local timezone or DST offset changes between session-end and session-start (e.g., DST-end backward step of 3600s; timezone change from UTC-5 to UTC-8),
**THEN** the wall-clock read via `int(Time.get_unix_time_from_system())` returns UTC-based Unix epoch seconds; `elapsed_raw = t_current - anchor` reflects real elapsed UTC time; no phantom forward or backward jump is introduced by the DST/timezone change alone.

**AND GIVEN** a *malicious* local-clock backward step of 3600s (player manually rewinds the device clock by one hour, simulating a DST-end scenario, but Unix time genuinely moves backward because the device clock is the source),
**WHEN** the game loads,
**THEN** `elapsed_raw = -3600`; because `−3600 < −REWIND_TOLERANCE_SECONDS (−300)`, the rewind branch of D.2 fires: `elapsed_offline_seconds = 0.0`, `flag_suspicious_timestamp = true`. This AC encodes the current documented behavior from E7 — a DST-sized backward step IS flagged under the 300s tolerance. If Open Question #3 resolves to raise tolerance to 3660s, this AC must be updated in lockstep.

*Verification*: two unit tests. **Test 1 (UTC invariance)**: mock `Time.get_unix_time_from_system()` to return `T + 60`; assert `elapsed_offline_seconds == 60` regardless of mocked timezone state. **Test 2 (DST-backward flag)**: mock `t_current = T − 3600`; assert `elapsed_offline_seconds == 0.0` and `flag_suspicious_timestamp == true`. Documents that Godot's API is UTC-based (so benign DST/timezone shifts do not affect Unix time at all) and that an actual clock-backward step of 3600s is treated as a rewind under the current tolerance.

### AC-TICK-13: Intra-Session BG↔FG Cycling Does Not Re-Fire Offline Replay (Integration, BLOCKING)

**GIVEN** the game has completed cold-launch offline replay (the process-scoped one-shot flag is set),
**WHEN** the app enters BACKGROUNDED and returns to FOREGROUND within the same process lifetime (any number of times),
**THEN** no additional `offline_elapsed_seconds` signal is emitted; the Offline Progression Engine is not re-invoked; `economy.compute_offline_batch()` is not re-called; only foreground `tick_fired` emissions resume on return.

*Verification*: integration test — simulate cold launch → offline replay → BG → FG → BG → FG; assert `offline_elapsed_seconds` signal fires exactly once (at cold launch); assert `compute_offline_batch` is invoked exactly once.

---

## Open Questions

### Resolved in this revision
- ~~Does PC window-minimize count as BACKGROUNDED?~~ **Resolved**: PC uses focus-loss semantics (`NOTIFICATION_WM_WINDOW_FOCUS_OUT` triggers BACKGROUNDED on alt-tab or minimize). Mobile continues to use `NOTIFICATION_APPLICATION_PAUSED`. Two platform-specific code paths, one shared state machine.
- ~~Cloud save conflict resolution policy~~ **Resolved** (at Time's boundary): Time vends `t_session_high_water` and `last_persist_unix`; Save/Load picks the save with the higher high-water as authoritative AND rejects any loaded `last_persist_unix > t_current + 300` as implausible. Full policy lives in Save/Load GDD.
- ~~576 000-tick replay wall-time budget~~ **Escalated** to AC-TICK-10 as a BLOCKING performance AC. Implementation must satisfy it or the cap/batch API must change.

### Still open
| Question | Owner | Target Resolution |
|---|---|---|
| Is the 8h default `offline_cap_seconds` right for a premium PC once-or-twice-daily session pattern (typical gap 10–14h)? game-designer argued for 12–16h; systems-designer accepted 8h as F2P-mobile borrow. This is a tuning decision, not a GDD structure issue. | economy-designer + game-designer | During `/design-system "Offline Progression Engine"` and economy tuning pass |
| Heartbeat persist frequency on battery-powered devices — is 60s aggressive enough to justify the battery cost? Alternative: write heartbeat only when sim tick counter crosses a round threshold (e.g., every 10 000 ticks = ~8 min). | performance-analyst | Before mobile port work |
| DST-end backward step is 3600s; `REWIND_TOLERANCE_SECONDS = 300` will flag it as suspicious. If DST false positives materialize in live data, either (a) detect the 3600s-exactly case as legitimate, or (b) raise tolerance to 3660s. No fix is needed unless it becomes a real-world issue — `flag_suspicious_timestamp` is session-scoped at this layer and has no automatic consequence. | security-engineer + game-designer | Post-launch (monitor live data) |
| Should `offline_cap_seconds` be temporarily increased during launch (e.g., 12 h for first week) to compensate for early-game slower economy? Live-ops question. | economy-designer + live-ops-designer | Post-launch |
| `flag_suspicious_timestamp` escalation thresholds, save-lock semantics, and the persistent cumulative counter live in the Save/Load GDD. Time only writes the flag for the current session — how Save/Load counts and acts on it is out of scope here. | security-engineer | During Save/Load GDD re-review |

---

*This GDD introduces 5 registry entries: `TICKS_PER_SECOND=20`, `offline_cap_seconds=28800`, `REWIND_TOLERANCE_SECONDS=300` (revised from 60), formula `offline_elapsed_seconds` (master formula D.2, now includes high-water mark and cap-reached signal), formula `offline_tick_budget` (D.3, multiply form). Downstream GDDs (Economy, Offline Engine, Save/Load, Dungeon Run Orchestrator) will reference these values — do not redefine.*

*Additional contracts introduced in this revision: `t_session_high_water` persistent field (signed by Save/Load), `cap_reached` signal (consumed by Return-to-App Screen for Pillar 1 disclosure), `compute_offline_batch(n)` batch API (Economy + Dungeon Run Orchestrator must expose), autoload singleton name `TickSystem` (host architecture).*
