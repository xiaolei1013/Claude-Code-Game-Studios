# Offline Progression Engine

**Status**: Authored (Sprint 11 S11-X4 — first design pass, 2026-05-05)
**Layer**: Feature (rank 15)
**Owners**: gameplay-programmer (chunk loop + signal suppression discipline) + performance-analyst (batch sizing + ANR headroom) + ux-designer (cozy modal copy)
**Last Verified**: 2026-05-05

⚠ **HIGH-RISK SYSTEM** per `architecture.md` rank-15 row. Failure modes here ship as user-visible rage moments (frozen "Welcome back" screen, lost offline rewards, stale gold-balance display). The performance budget is mobile min-spec ANR-headroom-bound; correctness + perf must both hold simultaneously.

---

## A. Overview

The Offline Progression Engine is the **boot-time orchestrator** that drains the wall-clock delta accumulated while the player was away from the game. It runs at app launch (rank 15, after every gameplay system is initialized) and consumes the `TickSystem.offline_elapsed_seconds` signal to compute how many sim-ticks of catch-up replay are required. It then drives the per-chunk replay loop into the Dungeon Run Orchestrator + Economy, yields to the main thread between chunks (per ADR-0014's no-worker-thread mandate), suppresses per-chunk domain signals, and emits a single aggregate `offline_rewards_collected(summary)` signal at the end. The Return-to-App Screen is the lone subscriber and renders the summary as the player's first post-launch interaction.

This GDD codifies the engine's contracts at the level needed for Sprint 12+ implementation:
- The batch-chunking algorithm (adaptive sizing, deadband, min/max clamps).
- The main-thread yield contract (`await get_tree().process_frame` between chunks; **WorkerThreadPool is FORBIDDEN per ADR-0014 forbidden-pattern**).
- The signal-suppression policy (domain signals do not fire per-chunk; single aggregate emit post-replay).
- The cap-handling policy (offline_cap_seconds, default 8 h).
- The cozy-modal UX threshold (`PROGRESS_MODAL_THRESHOLD_MS = 100` — silent below, modal above).
- The OfflineSummary aggregate shape.
- The HeroInstance-caching allowlist exception (3 call sites for the post-hydrate replay cycle).

The implementation contract is largely locked by `ADR-0014 (Offline Replay Batch Chunking + RunSnapshot Schema)` (Accepted 2026-04-22). This GDD adds: implementation-level acceptance criteria, edge-case handling, the cozy-modal copy register, and the Sprint 12+ implementation sequencing. It does NOT redefine the ADR — it translates it.

---

## B. Player Fantasy

The Return-to-App moment is one of the **most-load-bearing UX surfaces in the game**. Per the game-concept §6 ("Return-to-App: First Screen After Offline Gains"), this is where the cozy idle-game register is established or shattered. The fantasy:

1. **"Look what your guild did while you were away."** The player launches the app. They see a warm parchment ledger summarizing what happened: gold accumulated, floors cleared (if any), heroes leveled (V1.0+). The numbers are prominent. The animation is gentle. There is no ambiguity about whether the offline simulation actually ran — the summary IS the evidence. Per Pillar 3 ("Visible, Honest Progression Without Pressure"), the player sees the actual gold delta, not a vague "while you were away" placeholder.

2. **"It's still your guild."** The summary register matches the in-game register: parchment ground, lantern-gold reward color, slate-ink labels per Art Bible §4. No confetti, no slot-machine-style number counters, no "limited-time offer" upsell. The screen feels like a ledger entry, not a pop-up ad. Per Pillar 4 (HD-2D Pixel Pride), the visual continuity matters — the player's session resumes in the same world they left.

3. **"It's still YOUR session."** The 8h cap (`offline_cap_seconds = 28800`) is communicated as a soft note ("Your guild was busy for 8 hours; here's the result"), NOT as a punishment ("you missed out on more!"). Per Pillar 1 (No Fail State), the cap is a respect-the-player's-time mechanic, not a punishment. The implementation surfaces the cap via the `cap_reached(seconds_clipped: int)` signal, but the screen renders it gently.

4. **"It's fast."** The replay must complete in ≤500ms wall time for an 8h offline session per AC-TICK-10. The player sees the modal (if the replay exceeds 100ms — `PROGRESS_MODAL_THRESHOLD_MS`), not a spinner-and-rage-quit moment. The modal copy register is cozy ("Stitching your lantern lamp back on…") not utility ("Loading…").

The system is intentionally narrow: it does NOT compute reward formulas (Economy + Orchestrator do that via `compute_offline_batch`); it does NOT render the summary (Return-to-App Screen does that); it ORCHESTRATES the call chain so the player sees the result, not the work.

---

## C. Detailed Rules

### C.1 Public API surface

Per `architecture.md` §OfflineProgressionEngine + ADR-0014:

```gdscript
class_name OfflineProgressionEngine extends Node

# ---------------------------------------------------------------------------
# Public types — OfflineSummary (passed to Return-to-App Screen)
# ---------------------------------------------------------------------------

## Aggregate result of an offline replay batch. Fields are additive over
## chunks; subscribers consume the whole struct, not per-chunk events.
##
## ADR-0014 OFFLINE_SUMMARY_FIELD_SET_EXPANSION_WITHOUT_VERSION_BUMP forbidden
## pattern: adding a field here without a save-schema version bump is
## forbidden. The summary IS persisted briefly between offline replay
## completion and Return-to-App screen acknowledgment (so a crash in that
## window does not silently lose the rewards).
class OfflineSummary extends RefCounted:
	var gold_earned: int = 0                       # Sum of all credited gold (drip + kill + first-clear bonus)
	var floors_cleared_in_window: Array[int] = []  # Floor indices first-cleared during the offline window (ADR-0002)
	var seconds_credited: int = 0                  # min(elapsed, offline_cap_seconds); the actually-replayed window
	var seconds_clipped: int = 0                   # max(0, elapsed - offline_cap_seconds); 0 if under cap
	var ticks_replayed: int = 0                    # Total sim-ticks consumed during replay
	var chunks_consumed: int = 0                   # Total batch chunks consumed during replay (telemetry)
	var total_replay_wall_time_ms: int = 0         # Wall-clock duration of the replay loop (telemetry / AC-TICK-10 verification)
	# V1.0 forward-compat: hero_levels_gained: Dictionary[int, int] (hero_id → levels)
	# Adding requires save-schema version bump per ADR-0014 forbidden pattern.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Aggregate replay-complete signal. Fired ONCE per launch, AFTER all chunks
## have completed AND domain-signal aggregates (gold_changed, first_clear_*)
## have been emitted. Return-to-App Screen subscribes here and renders the
## summary as the player's first interaction.
##
## Order of operations within run_offline_replay():
##   1. for chunk in chunks: process; suppress per-chunk domain signals.
##   2. After all chunks: emit aggregate domain signals (gold_changed once
##      with total_delta; first_clear_awarded for each floor in summary;
##      floor_cleared_first_time for each from Orchestrator's offline path).
##   3. Emit THIS signal LAST — UI state must observe complete world state
##      when rendering the summary.
##
## ADR-0014 §signal emission policy.
signal offline_rewards_collected(summary: OfflineSummary)

## Cap-reached signal. Fired BEFORE offline_rewards_collected when
## offline_elapsed_seconds exceeds offline_cap_seconds. Subscribers (Return-
## to-App Screen, telemetry) use this to render the cozy "your guild was
## busy for X hours; here's the result" register per §B player fantasy 3.
##
## [param seconds_clipped]: max(0, elapsed - cap). Always > 0 when this
##   signal fires. The actually-replayed window is min(elapsed, cap).
signal cap_reached(seconds_clipped: int)

# ---------------------------------------------------------------------------
# Public API — minimal surface; this engine is mostly signal-driven.
# ---------------------------------------------------------------------------

## Manual trigger for the replay loop. Production callers do NOT use this —
## the loop is auto-triggered by the TickSystem.offline_elapsed_seconds
## signal subscription in _ready(). This method exists for QA / debug /
## test-fixture paths that need to drive a replay without going through
## TickSystem's bg/fg cycle.
##
## Idempotent: calling twice while a replay is in flight push_warns the
## second call and returns immediately (no parallel replays — ADR-0014
## single-replay-in-flight invariant).
##
## [param elapsed_seconds]: the wall-clock delta to replay. Capped to
##   offline_cap_seconds before chunking.
func run_offline_replay(elapsed_seconds: int) -> void

## Returns true if a replay is currently in flight. The Return-to-App
## Screen + the cozy progress modal use this to gate their own state
## machines. Foreground transitions (e.g., player tapping a button mid-
## replay) are blocked by SceneManager via this flag.
func is_replay_in_flight() -> bool

# ---------------------------------------------------------------------------
# Private state (visibility-sensitive; tests assert via stable field names)
# ---------------------------------------------------------------------------

## Set to true at run_offline_replay() entry; cleared at offline_rewards_collected
## emit. STABLE-FOR-TEST-ACCESS — Sub-AC OE-09 asserts this transitions
## true→false in lockstep with the signal.
var _replay_in_flight: bool = false

## Snapshot of pending elapsed seconds (set by the TickSystem signal
## handler before the replay loop begins). Cleared post-replay.
var _pending_elapsed_seconds: int = 0
```

### C.2 Batch chunking algorithm

Per ADR-0014 §adaptive time-budgeted chunking. Constants (declared in this engine OR a config tres):

```gdscript
const OFFLINE_CHUNK_TARGET_WALL_MS: int = 12       # Target wall-clock cost per chunk
const OFFLINE_CHUNK_INITIAL_TICKS: int = 5000      # First chunk size on every replay
const OFFLINE_CHUNK_MIN_TICKS: int = 500           # Floor — never go below
const OFFLINE_CHUNK_MAX_TICKS: int = 50000         # Ceiling — never go above
const OFFLINE_CHUNK_DEADBAND_RATIO: float = 0.25   # ±25% of target — within deadband, no adjustment
const OFFLINE_CHUNK_ADJUST_RATIO: float = 0.6      # New chunk = current × (target_ms / measured_ms × 0.6) when out of deadband

const PROGRESS_MODAL_THRESHOLD_MS: int = 100       # Show cozy modal if replay exceeds this duration
const TICKS_PER_SECOND: int = 20                   # From TickSystem (re-declared here for arithmetic clarity)
```

Per-chunk loop pseudocode:

```
run_offline_replay(elapsed_seconds):
  if _replay_in_flight: push_warning + return
  _replay_in_flight = true

  capped_seconds = min(elapsed_seconds, offline_cap_seconds)
  seconds_clipped = max(0, elapsed_seconds - offline_cap_seconds)
  if seconds_clipped > 0: cap_reached.emit(seconds_clipped)

  total_ticks = capped_seconds * TICKS_PER_SECOND
  remaining = total_ticks
  chunk_size = OFFLINE_CHUNK_INITIAL_TICKS

  summary = OfflineSummary.new()
  summary.seconds_credited = capped_seconds
  summary.seconds_clipped = seconds_clipped

  replay_start_ms = Time.get_ticks_msec()  # Single-call-site invariant defers to TickSystem; see §F note.

  while remaining > 0:
    n = min(chunk_size, remaining)
    chunk_start_ms = Time.get_ticks_msec()

    # Domain signals are suppressed per-chunk during these calls.
    DungeonRunOrchestrator.compute_offline_batch(n)
    Economy.compute_offline_batch(n)

    measured_ms = Time.get_ticks_msec() - chunk_start_ms
    summary.chunks_consumed += 1
    summary.ticks_replayed += n
    remaining -= n

    # Adaptive chunk size adjustment (deadband ±25% per ADR-0014).
    deadband_low = OFFLINE_CHUNK_TARGET_WALL_MS * (1 - OFFLINE_CHUNK_DEADBAND_RATIO)
    deadband_high = OFFLINE_CHUNK_TARGET_WALL_MS * (1 + OFFLINE_CHUNK_DEADBAND_RATIO)
    if measured_ms < deadband_low or measured_ms > deadband_high:
      adjusted = chunk_size * (OFFLINE_CHUNK_TARGET_WALL_MS / max(measured_ms, 1.0)) * OFFLINE_CHUNK_ADJUST_RATIO
      chunk_size = clamp(int(adjusted), OFFLINE_CHUNK_MIN_TICKS, OFFLINE_CHUNK_MAX_TICKS)

    # Yield to main thread between chunks. ADR-0014 explicitly forbids
    # WorkerThreadPool here — the yield IS the budget mechanism.
    await get_tree().process_frame

  summary.total_replay_wall_time_ms = Time.get_ticks_msec() - replay_start_ms

  # Emit aggregate domain signals (single emit each, post-replay).
  # Economy emits gold_changed once with the cumulative delta.
  # Orchestrator emits floor_cleared_first_time + first_clear_awarded for
  # each floor in the offline window (per Pass-I.15-fix in Orchestrator C.4).
  # Both autoloads internally drained their per-chunk suppression buffers.
  Economy.flush_offline_signals()
  DungeonRunOrchestrator.flush_offline_signals()

  _replay_in_flight = false
  offline_rewards_collected.emit(summary)
```

The `flush_offline_signals` methods on Economy + Orchestrator are part of those systems' offline-replay contracts. Economy GDD §C.6 already documents the suppression mechanism (`is_offline_replay: bool` flag); the flush surface lands when this engine ships in Sprint 12+ (cross-system contract addition flagged in §F).

### C.3 Signal suppression policy (ADR-0014 §signal emission policy)

Per ADR-0014's CI-enforced forbidden pattern `per_chunk_domain_signal_emission_during_offline_replay`:

- **`tick_fired` is NEVER emitted during offline replay** (TickSystem-side suppression per ADR-0005). Subscribers of `tick_fired` see zero events for the offline window.
- **`gold_changed` is suppressed per-chunk; emitted ONCE post-replay** with the cumulative delta as the `delta` argument (`new_balance` reflects post-replay balance; `reason` is `"offline_replay_aggregate"` or similar).
- **`first_clear_awarded` is suppressed per-chunk; emitted POST-replay for each first-cleared floor in the offline window**.
- **`floor_cleared_first_time` is suppressed per-chunk; emitted POST-replay for each first-cleared floor** (per Pass-I.15-fix in Orchestrator C.4).
- **`offline_rewards_collected` is THIS engine's own signal**; emitted exactly once per replay, AFTER all aggregate domain signals.

The motivation (per economy-system.md §C.6): naive per-tick signal dispatch would blow the 500ms budget on a 576k-tick worst case (`200–500 ns × 576k ≈ 230 ms` of signal overhead alone). The suppression contract is performance-critical, not just elegance.

### C.4 Cap handling (offline_cap_seconds)

Per `architecture.md` §AC-TICK-10 + game-concept §pacing:

- Default `offline_cap_seconds = 28800` (8 hours).
- The engine reads this from `TickSystem.offline_cap_seconds` (which owns the canonical value per game-time-and-tick.md). It does NOT duplicate the constant.
- Behavior beyond cap: replay only the first `offline_cap_seconds` of elapsed time. Emit `cap_reached(seconds_clipped)` BEFORE starting replay. Continue with the capped replay normally.

The cap is a respect-the-player's-time decision, not a punishment. UI surfacing is the screen's responsibility (cozy "your guild was busy for 8 hours" register per §B fantasy 3).

### C.5 Progress modal threshold

Per ADR-0014 OQ-4 resolution:

- If the cumulative replay wall time (measured continuously inside `run_offline_replay`) is projected to exceed `PROGRESS_MODAL_THRESHOLD_MS = 100`, the engine fires a `progress_modal_show()` call to SceneManager OR the modal surfaces autonomously via the existing OverlayLayer (Sprint 12+ implementation choice).
- Below the threshold, NO modal — the replay completes silently and `offline_rewards_collected` fires with the player still seeing the previous screen (e.g., black-frame loading screen → directly into Return-to-App).
- The modal copy register is cozy per the §B player fantasy 4: "Stitching your lantern lamp back on…" (or similar). NOT utility ("Loading…", "Please wait…"). The exact strings live in the locale file; the modal scene is owned by SceneManager / UIFramework.

### C.6 HeroInstance-caching allowlist (ADR-0014 exception)

Per ADR-0014: the `caching_heroinstance_reference_across_save_boundary` forbidden pattern (from ADR-0012) has a **lifetime-scoped exception** for the post-hydrate offline-replay cycle. Three production call sites are allowlisted:

1. `CombatResolver.compute_offline_batch(formation: FormationSnapshot, ...)` — `formation` is an Array[HeroInstance] held for the chunk's duration.
2. `CombatResolver.emit_events_in_range(formation, ...)` — same lifetime.
3. `MatchupResolver.resolve(formation, ...)` — same lifetime.

In all 3 cases, the lifetime is bounded: from the start of the chunk to its return. The HeroInstance reference is NEVER persisted, NEVER cached across `await get_tree().process_frame`, NEVER stored as a field on a Node that outlives the replay cycle.

The OfflineProgressionEngine's role: pass HeroInstance arrays through to those callees, but NEVER cache them as fields on its own state. The engine's `_replay_in_flight` + `_pending_elapsed_seconds` are int + bool — no HeroInstance references survive across the await.

CI grep enforces the allowlist: any `HeroInstance` reference held across an `await` boundary OUTSIDE these 3 call sites is a forbidden-pattern violation.

### C.7 Save/Load consumer surface

OfflineProgressionEngine is **NOT** in `SaveLoadSystem.CONSUMER_PATHS` per the canonical 6-entry list (Economy + HeroRoster + FloorUnlock + FormationAssignment + Recruitment + DungeonRunOrchestrator). The engine has no persisted state of its own — its inputs (offline_elapsed_seconds, RunSnapshot) come from other systems' save namespaces.

The engine's transient state (`_replay_in_flight`, `_pending_elapsed_seconds`) is session-only; an in-flight replay interrupted by a crash recovers naturally on next launch (TickSystem reads the wall-clock delta; the engine kicks off a fresh replay).

---

## D. Formulas

### D.1 Tick conversion (TickSystem-anchored)

```
total_ticks = capped_seconds * TICKS_PER_SECOND  (=20)
```

`TICKS_PER_SECOND` is owned by TickSystem. The engine reads it via the const declared in `tick_system.gd` to avoid duplication drift.

### D.2 Cap clipping (idempotent at upper bound)

```
capped_seconds  = min(elapsed_seconds, offline_cap_seconds)
seconds_clipped = max(0, elapsed_seconds - offline_cap_seconds)
```

For elapsed ≤ cap: `capped = elapsed`, `clipped = 0`, no `cap_reached` emit.
For elapsed > cap: `capped = cap`, `clipped > 0`, `cap_reached(clipped)` fires before replay starts.

### D.3 Adaptive chunk-size adjustment

Per ADR-0014:

```
deadband_low  = OFFLINE_CHUNK_TARGET_WALL_MS * (1 - 0.25)  (= 9 ms)
deadband_high = OFFLINE_CHUNK_TARGET_WALL_MS * (1 + 0.25)  (= 15 ms)

if measured_ms is in [deadband_low, deadband_high]:
  no adjustment — chunk_size stays the same

else:
  adjusted = chunk_size * (target_ms / max(measured_ms, 1.0)) * 0.6
  chunk_size = clamp(adjusted, MIN_TICKS, MAX_TICKS)  (= [500, 50000])
```

The `0.6` adjust ratio dampens oscillation: a measured 30ms (2.5× target) should NOT immediately halve chunk_size — it scales to `chunk_size * (12/30) * 0.6 = chunk_size * 0.24`, then next chunk measures, etc. Convergence over 2-3 chunks vs immediate overcorrection.

### D.4 Worst-case replay budget

8h cap × 20 Hz = 576,000 ticks.

At target 12 ms / 5000 ticks (the initial chunk size), 576k ticks = 115 chunks ≈ 1.4 s wall time WITHOUT yields.

With yields between chunks (~16 ms per process_frame on 60 Hz), 115 chunks adds ~1.8 s of wait time.

Total worst-case wall time: ~3.2 s. The AC-TICK-10 budget of 500ms is NOT achievable for the 8h worst case at 12ms/chunk; ADR-0014 documents the budget as ADVISORY for total-wall-clock-including-yield, BLOCKING only for per-chunk CPU wall time (≤16ms BLOCKING, ANR headroom on min-spec mobile). The 500ms budget cited in older sources (`architecture.md` line 443) is superseded by ADR-0014's two-budget split.

---

## E. Edge Cases

### E.1 Cold launch (no offline_elapsed)

`TickSystem.offline_elapsed_seconds` does not fire on cold launch (never-launched / first-launch path per ADR-0005). The engine's signal handler is never invoked. `_replay_in_flight` stays false. Return-to-App Screen is NOT shown — the player goes directly to Guild Hall.

### E.2 Foreground re-entry with elapsed < 1 second

`offline_elapsed_seconds` fires with a small value (e.g., 0.5s = 10 ticks). The engine processes it normally. Total replay completes in ~12ms (single chunk, well under modal threshold). `offline_rewards_collected` fires with a tiny summary. Return-to-App Screen still shows — but its render path can detect "tiny summary" and skip itself if desired (a UX decision owned by the screen, not this engine).

### E.3 Foreground re-entry with elapsed at exactly cap

`elapsed == offline_cap_seconds` (e.g., exactly 28800). `seconds_clipped = 0`. `cap_reached` does NOT fire (strict `> 0` check). Replay processes the full window.

### E.4 Foreground re-entry with elapsed >> cap (24+ hours)

`elapsed = 86400` (24h). `capped = 28800` (8h). `clipped = 57600`. `cap_reached(57600)` fires before replay. Replay processes 8h normally. The clipped 16h is surfaced to UI for cozy framing per §B fantasy 3.

### E.5 Two replays attempted in quick succession

The TickSystem.offline_elapsed_seconds signal fires once per cold-launch / fg-resume event. Theoretically a misbehaving signal source could fire twice. The `_replay_in_flight` guard catches this — second call push_warns + returns. No parallel replays.

### E.6 Replay completes successfully but offline_rewards_collected listener throws

Godot signal emission propagates exceptions from listeners. The replay state is already complete (gold added, floors cleared, summary computed). A listener exception does NOT roll back the replay. `_replay_in_flight` is already cleared (it was cleared BEFORE the emit). The next replay (next launch) will work normally.

### E.7 Crash mid-chunk

The engine has no persisted state. On next launch:
- TickSystem computes a fresh `offline_elapsed_seconds` covering the time since last persist.
- The engine kicks off a fresh replay covering that window.
- The crashed-mid-chunk's partial Economy + Orchestrator state was NOT persisted (those systems persist via SaveLoadSystem heartbeats, which fire BEFORE the replay starts, not during).
- Net: the player loses the crashed-replay's progress but gains the fresh-replay covering the same time window. Idempotent within a save cycle.

This is the **single-replay-in-flight + no-mid-replay-persist** invariant: the engine never persists during a replay; the next launch's replay is the recovery mechanism.

### E.8 Crash post-replay-completion but pre-summary-display

If the engine emits `offline_rewards_collected` and the listener (Return-to-App Screen) crashes before rendering, the summary is lost (the engine's state is cleared post-emit; the summary RefCounted gets garbage-collected). Sprint 12+ implementation choice: should the summary be persisted briefly between replay-complete and screen-acknowledge so a crash here recovers? Per game-concept Pillar 1 (No Fail State), losing offline rewards to a crash IS a fail state. **OQ-OE-1 captures this.**

### E.9 OfflineProgressionEngine autoload absent at boot

Per ADR-0003: missing required autoload is a fatal architecture violation per CONSUMER_PATHS contract — except OfflineProgressionEngine is NOT a save consumer (§C.7). Its absence is detected by TickSystem's signal having no subscriber — the offline_elapsed_seconds signal fires with nothing connected, no replay happens, the player launches into Guild Hall as if there were no offline window.

This is degraded behavior, not a crash. The cozy promise is broken (offline rewards silently lost) but the game still runs. The implementation MUST register at rank 15 per ADR-0014; absence is a packaging bug, not a runtime concern.

### E.10 await get_tree().process_frame raises (process_frame never fires)

In a degenerate state (paused tree?), the await could hang. The engine has no internal timeout. Sprint 12+ implementation should add a defensive timeout (e.g., 5s wall-clock cap on the entire replay loop; on timeout, abort with partial summary + push_error). **OQ-OE-2 captures this.**

---

## F. Dependencies

### Hard dependencies

| System | Why | Surface used |
|---|---|---|
| `TickSystem` (rank 0) | Boot-time wall-clock delta computation; signal source | `offline_elapsed_seconds(seconds: float, cap_reached: bool)` (subscribed in `_ready()`); `offline_cap_seconds: int` (config read); `TICKS_PER_SECOND: int` (const used for tick conversion); `Time.get_ticks_msec()` for chunk wall-time measurement (per ADR-0005 single-call-site invariant — note: this engine reads `Time.get_ticks_msec` directly, NOT `Time.get_unix_time_from_system`; the single-call-site invariant covers wall-clock UTC reads, not millisecond elapsed counters) |
| `DungeonRunOrchestrator` (rank 14) | Per-chunk replay driver | `compute_offline_batch(tick_count: int) -> void`; `flush_offline_signals() -> void` (cross-system contract addition flagged in §F) |
| `Economy` (rank 3) | Per-chunk replay driver | `compute_offline_batch(tick_budget: int) -> OfflineResult` per ADR-0013; `flush_offline_signals() -> void` (cross-system contract addition flagged below) |
| `SceneManager` (rank 8) | Modal-show + Return-to-App transition trigger | Modal-show API (TBD per Sprint 12+ implementation; either explicit `SceneManager.show_progress_modal(text)` or signal-based wiring) |

### Cross-system contract additions required

This GDD identifies two API additions Sprint 12+ implementation will close in lockstep:

- **`Economy.flush_offline_signals() -> void`** — drains the per-chunk-suppressed `gold_changed` deltas + emits a single aggregate. Currently Economy GDD §C.6 documents the suppression flag (`_is_offline_replay`) but not the flush surface. Sprint 12+ implementation closes this with an Economy GDD update + ADR-0013 Amendment.
- **`DungeonRunOrchestrator.flush_offline_signals() -> void`** — drains per-chunk-suppressed `floor_cleared_first_time` + `first_clear_awarded` emissions. Currently Orchestrator GDD documents the per-chunk suppression but not the flush mechanism. Sprint 12+ implementation closes this with an Orchestrator GDD update + ADR-0014 Amendment (or possibly without an ADR amendment if the flush surface is considered an internal Orchestrator detail).

### Signal-source dependencies

| Signal | Source | Subscriber action |
|---|---|---|
| `offline_elapsed_seconds(seconds, cap_reached)` | TickSystem | `_on_offline_elapsed` triggers `run_offline_replay(seconds)` |

### Reverse dependencies (subscribers of OfflineProgressionEngine signals)

| Signal | Subscriber | Purpose |
|---|---|---|
| `offline_rewards_collected(summary)` | ReturnToAppScreen (Sprint 12+ UI) | Render the cozy ledger summary as the player's first post-launch interaction |
| `offline_rewards_collected` | Telemetry (Sprint 13+) | Track offline-replay aggregate for retention metrics |
| `cap_reached(seconds_clipped)` | ReturnToAppScreen | Render cozy "your guild was busy for X hours" framing |

### Bidirectional consistency

This GDD's contracts cross-reference:
- `ADR-0014` — Offline Replay Batch Chunking + RunSnapshot Schema (load-bearing source).
- `ADR-0005` — TickSystem dual-clock contract (signal-source + const ownership).
- `ADR-0013` — Economy compute_offline_batch + OfflineResult shape.
- `architecture.md` rank 15 row + OfflineProgressionEngine API section.
- `economy-system.md` §C.6 — offline-replay strategy (signal suppression flag).
- `dungeon-run-orchestrator.md` §C.4 — Pass-I.15-fix offline replay floor_cleared_first_time emission.
- `game-time-and-tick.md` — TickSystem.offline_elapsed_seconds signal contract + offline_cap_seconds knob.
- `game-concept.md` §6 — Return-to-App fantasy framing.

---

## G. Tuning Knobs

### G.1 Designer-tunable (timing budgets — ADR-0014-locked)

| Knob | Type | Default | Range | Owner |
|---|---|---|---|---|
| `OFFLINE_CHUNK_TARGET_WALL_MS` | int | 12 | [4, 32] | OfflineProgressionEngine const |
| `OFFLINE_CHUNK_INITIAL_TICKS` | int | 5000 | [500, 50000] | OfflineProgressionEngine const |
| `OFFLINE_CHUNK_MIN_TICKS` | int | 500 | [100, 5000] | OfflineProgressionEngine const |
| `OFFLINE_CHUNK_MAX_TICKS` | int | 50000 | [5000, 200000] | OfflineProgressionEngine const |
| `OFFLINE_CHUNK_DEADBAND_RATIO` | float | 0.25 | [0.10, 0.50] | OfflineProgressionEngine const |
| `OFFLINE_CHUNK_ADJUST_RATIO` | float | 0.6 | [0.3, 1.0] | OfflineProgressionEngine const |
| `PROGRESS_MODAL_THRESHOLD_MS` | int | 100 | [50, 1000] | OfflineProgressionEngine const |

These knobs are tuned by performance-analyst against min-spec mobile + Steam Deck profiling. Changes require ADR-0014 Amendment if they violate the per-chunk CPU BLOCKING budget (≤16ms).

### G.2 Designer-tunable (offline_cap_seconds — TickSystem-owned)

| Knob | Type | Default | Range | Owner |
|---|---|---|---|---|
| `offline_cap_seconds` | int | 28800 (8h) | [3600, 86400] (1h–24h) | TickSystem (read by this engine; do NOT duplicate) |

### G.3 Debug/dev (not shipped)

- `debug_force_offline_seconds: int` — bypass TickSystem signal; force a synthetic elapsed value. Guarded by `OS.is_debug_build()`.

### G.4 V1.0 forward-compat surface

- `OFFLINE_PERSIST_SUMMARY_BETWEEN_REPLAY_AND_ACK: bool` — if `true`, the summary is persisted briefly between replay-complete and Return-to-App acknowledgment so a crash in that window does not silently lose rewards. Closes OQ-OE-1.

---

## H. Acceptance Criteria

**AC-OE-01 — Autoload registered at rank 15**
At cold boot, `/root/OfflineProgressionEngine` resolves to the autoload. `project.godot [autoload]` lists the entry between rank-14 (DungeonRunOrchestrator) and rank-16 (AudioRouter). Rank invariant: `_ready()` runs after every gameplay autoload (so signal subscriptions and direct calls into Economy / Orchestrator are safe).

**AC-OE-02 — Public API surface + OfflineSummary class**
The autoload exposes `run_offline_replay(elapsed_seconds: int)`, `is_replay_in_flight() -> bool`, signal `offline_rewards_collected(summary)`, signal `cap_reached(seconds_clipped)`. The `OfflineSummary` RefCounted has all 7 fields per §C.1.

**AC-OE-03 — Subscribed to TickSystem.offline_elapsed_seconds**
At `_ready()`, the engine connects to TickSystem.offline_elapsed_seconds. Verifying connection: `TickSystem.offline_elapsed_seconds.is_connected(engine._on_offline_elapsed) == true`.

**AC-OE-04 — Replay loop chunks correctly with deadband**
Run a synthetic replay of 100,000 ticks. Each chunk's measured wall time is recorded. The chunk size adjusts adaptively per §C.2 algorithm. Specifically: chunks within deadband [9, 15] ms do not change size; chunks outside deadband adjust per the formula. Final summary's `chunks_consumed > 0` and `ticks_replayed == 100000`.

**AC-OE-05 — `await get_tree().process_frame` between chunks**
A test that monkeypatches `get_tree().process_frame` with a counter asserts: between any two consecutive chunk processings, the counter incremented exactly once. WorkerThreadPool calls in this engine fail CI grep (forbidden pattern `worker_thread_pool_for_offline_replay_in_mvp`).

**AC-OE-06 — `cap_reached` fires when elapsed > cap**
`run_offline_replay(40000)` with `offline_cap_seconds = 28800`. Asserts: `cap_reached.emit(11200)` fires BEFORE the first chunk; `summary.seconds_credited == 28800`; `summary.seconds_clipped == 11200`.

**AC-OE-07 — `cap_reached` does NOT fire when elapsed ≤ cap**
`run_offline_replay(20000)` with cap 28800. Asserts: `cap_reached` did not emit; `summary.seconds_clipped == 0`.

**AC-OE-08 — Per-chunk domain signals are suppressed**
A spy connected to `Economy.gold_changed` and `Orchestrator.floor_cleared_first_time`. Run a replay covering ≥2 chunks worth of ticks. Asserts: those signals did NOT fire during the chunk-iteration loop. Aggregate emission post-replay (via flush_offline_signals) IS allowed; spy receives ONE aggregate emission per signal at most.

**AC-OE-09 — `_replay_in_flight` flag transitions correctly**
Pre: `_replay_in_flight == false`. During replay (assert via a signal handler that runs mid-replay — e.g., a chunk-time logger): `_replay_in_flight == true`. Post-replay (in the offline_rewards_collected handler): `_replay_in_flight == false`.

**AC-OE-10 — Re-entrant `run_offline_replay` is push_warned + no-op**
Call `run_offline_replay(1000)` mid-replay (e.g., from a signal handler that fires during a chunk). Asserts: a push_warning was logged; the second invocation did NOT start a parallel replay; the original replay completed normally.

**AC-OE-11 — `offline_rewards_collected` emits LAST**
A test connects multiple spies — one to `gold_changed`, one to `first_clear_awarded`, one to `floor_cleared_first_time`, one to `offline_rewards_collected`. After the replay, the spy ordering log shows the aggregate domain signals fired BEFORE `offline_rewards_collected`. Subscribers of `offline_rewards_collected` see post-aggregate state.

**AC-OE-12 — Worst-case 8h replay completes under 5s wall time (ADVISORY)**
With cap 28800 and the default chunk constants, `run_offline_replay(28800)` completes in `summary.total_replay_wall_time_ms < 5000`. ADVISORY budget per ADR-0014 (BLOCKING is per-chunk CPU ≤16ms; the 5s total is ANR headroom on min-spec mobile).

**AC-OE-13 — Per-chunk CPU wall time stays under 16ms (BLOCKING)**
For each chunk in a worst-case replay, `measured_ms <= 16`. This is the BLOCKING per-chunk budget. Chunk size auto-adjusts to maintain the budget.

**AC-OE-14 — Progress modal threshold gates UI surfacing**
A 50-tick replay (sub-100ms wall time) completes WITHOUT firing `progress_modal_show`. A 600,000-tick replay (~3s wall time) DOES fire it. The modal copy register matches the cozy lexicon per §B fantasy 4.

**AC-OE-15 — HeroInstance allowlist boundary not violated**
CI grep for `HeroInstance` references held across an `await` boundary in OfflineProgressionEngine source. Asserts: zero violations. The 3 allowlisted call sites (CombatResolver.compute_offline_batch / emit_events_in_range / MatchupResolver.resolve) are scoped to their own files; the engine never holds them.

**AC-OE-16 — Cold-launch path: no replay fires, Return-to-App not shown**
Boot test simulating a cold launch (no save state). Asserts: `TickSystem.offline_elapsed_seconds` did not emit (per ADR-0005); `_replay_in_flight` stays false; player lands at Guild Hall, not Return-to-App.

---

## I. Open Questions & ADR Candidates

**OQ-OE-1 — Persist OfflineSummary between replay-complete and screen-acknowledge?**
Current design: summary is RefCounted, garbage-collected after the screen handles it. A crash between `offline_rewards_collected` emit and the player tapping "Continue" loses the summary. **Pillar 1 (No Fail State) suggests yes — persist briefly.** ADR candidate: SaveLoadSystem-side post-replay summary save (write summary blob to a separate file or namespace; on next launch, if a un-acknowledged summary exists, surface it before doing a fresh replay). Sprint 13+ scope.

**OQ-OE-2 — Defensive timeout on `await get_tree().process_frame`**
In a degenerate paused-tree state, the await could hang indefinitely. Should the engine implement an internal timeout (e.g., `Timer.start(5.0)` parallel to the replay loop; on timeout, abort with partial summary + push_error)? Sprint 12+ implementation should add this defensively even without an ADR — it's a robustness nit, not a design decision. **Recommendation**: add the timeout in Story 1; don't gate on ADR.

**OQ-OE-3 — Modal copy localization timing**
The cozy modal copy ("Stitching your lantern lamp back on…") needs locale support. Loading the modal scene + locale file happens DURING the replay — an additional cost. Should the modal lazy-load (showing a placeholder text until locale loads) or eagerly load (delaying the replay start)? Sprint 12+ implementation choice; doesn't change the engine contract.

**OQ-OE-4 — Telemetry granularity**
ADR-0014 mentioned per-chunk telemetry as an option. The current OfflineSummary has aggregate fields (`chunks_consumed`, `total_replay_wall_time_ms`); per-chunk timing is NOT in the summary. If telemetry needs per-chunk data, Sprint 13+ telemetry design adds a separate signal `chunk_completed(chunk_index, ticks, wall_ms)` with a TELEMETRY-only consumer.

**OQ-OE-5 — V1.0 multi-formation offline (multiple parallel runs while away)**
MVP assumes 0 or 1 active dispatched runs at offline-start. V1.0 multi-formation expansion would mean N runs to replay in parallel. This GDD's contracts are 1-formation; V1.0 expansion is a substantial scope shift requiring a separate ADR. Out of MVP.

**OQ-OE-6 — `flush_offline_signals` cross-system addition**
This GDD identifies that Economy + Orchestrator both need `flush_offline_signals()` methods (currently undocumented). Sprint 12+ implementation closes this in lockstep with Economy GDD update + ADR-0013 Amendment for Economy; Orchestrator-side may not need an ADR amendment (internal detail). The flush surface specifically is the missing API.

**OQ-OE-7 — `_warning_logger` / `_error_logger` DI consistency**
Sprint 12+ implementation should adopt the DI-logger pattern used by FloorUnlockSystem (S11-X1) for testability. Not a design decision — a code-style consistency.

---

## J. Implementation Sequencing (Sprint 12+ candidate)

This GDD describes the design surface; ADR-0014 has done much of the heavy design work. Sprint 12+ implementation:

1. **Pre-implementation (~0.5d)**:
   - **Story 0a — Cross-system contract additions** (per OQ-OE-6): add `flush_offline_signals()` to Economy + DungeonRunOrchestrator. Economy gets an Economy GDD update + ADR-0013 Amendment. Orchestrator gets a §C.4 GDD update.

2. **OfflineProgressionEngine implementation (~3.0d total)**:
   - **Story 1 (~0.5d)** — Engine autoload skeleton + `project.godot` rank-15 lockstep + ADR-0003 Amendment for autoload registration.
   - **Story 2 (~0.5d)** — Chunk loop body (single chunk, no adaptive sizing, no yield) + `OfflineSummary` class + minimal tests.
   - **Story 3 (~0.5d)** — Adaptive chunk sizing per §D.3 + tests for deadband behavior + budget compliance.
   - **Story 4 (~0.5d)** — `await get_tree().process_frame` yield + signal suppression integration with Economy + Orchestrator + tests for AC-OE-08.
   - **Story 5 (~0.25d)** — Cap handling (`cap_reached` signal + clipping math) + tests for AC-OE-06 / AC-OE-07.
   - **Story 6 (~0.25d)** — Progress modal threshold + SceneManager integration (modal-show signal or direct call, Sprint 12+ implementation choice) + tests for AC-OE-14.
   - **Story 7 (~0.25d)** — `_replay_in_flight` re-entry guard + tests for AC-OE-09 / AC-OE-10.
   - **Story 8 (~0.25d)** — CI grep for the 5 ADR-0014 forbidden patterns + add to ADR-0003 forbidden-patterns registry.

3. **Post-engine (~1.0d)**:
   - **Story 9 (~0.5d)** — Return-to-App Screen wire-up (subscribes to `offline_rewards_collected` + `cap_reached`; renders cozy summary). UI screen scope owns the actual visual work; this story is the autoload-side hook + signal handlers.
   - **Story 10 (~0.5d)** — End-to-end integration test: simulated cold launch with synthetic offline_elapsed → replay → summary delivered → screen rendered. Verifies AC-OE-12 (5s ADVISORY budget) + AC-OE-13 (per-chunk BLOCKING budget) on min-spec mobile.

Total Sprint 12+ scope: ~4.5 days. This is the largest of the three Sprint 11 GDD-authoring follow-up stories (FormationAssignment ~2.5d, Recruitment ~3.0d, OfflineProgressionEngine ~4.5d). The order matters: implement Economy + Orchestrator flush surfaces (Story 0a) FIRST so Stories 4–6 can integrate against real cross-system contracts.

After OfflineProgressionEngine ships, the Return-to-App Screen lands as a Sprint 13+ UI story. The full Pillar 3 ("Visible, Honest Progression Without Pressure") cozy-game register is established by the screen + this engine working together.
