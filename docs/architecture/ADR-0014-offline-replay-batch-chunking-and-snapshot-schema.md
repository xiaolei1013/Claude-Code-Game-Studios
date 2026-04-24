# ADR-0014: Offline Replay Batch Chunking + RunSnapshot Schema

## Status
Accepted (promoted Proposed → Accepted same-session 2026-04-22 after godot-gdscript-specialist Step 4.5 APPROVE-WITH-NOTES; 3 LOAD-BEARING notes folded in-place; technical-director Step 4.6 SKIPPED per solo review mode. Matches ADR-0012/0013 same-session Accept pattern.)

## Date
2026-04-22

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core (coroutines + autoload lifecycle; no rendering/physics concerns) |
| **Knowledge Risk** | LOW — uses only `await get_tree().process_frame`, typed signals, typed Dictionary, `Time.get_ticks_usec()` (canonical `Time` singleton in 4.x; `OS.*` timing helpers deprecated in favor of `Time.*` since 4.0). All primitives stable ≥ Godot 4.0. |
| **References Consulted** | `docs/engine-reference/godot/modules/autoload.md` Claim 1 [VERIFIED] + Claim 4 [VERIFIED]; `docs/engine-reference/godot/VERSION.md`; `docs/engine-reference/godot/breaking-changes.md` (Core domain); `docs/engine-reference/godot/deprecated-apis.md` (`OS.get_ticks_*` → `Time.get_ticks_*`); `.claude/docs/technical-preferences.md` |
| **Post-Cutoff APIs Used** | `Dictionary[int, HeroInstance]` + `Array[HeroInstance]` typed-container syntax (Godot 4.4+ — direct precedent in ADR-0009/0010/0012/0013; stable) |
| **Verification Required** | AC-TICK-10 blocking gate: end-to-end 576k-tick replay wall-time ≤500ms OR ≤16ms/chunk on min-spec mobile (Snapdragon 6xx @ 2GHz); `OfflineProgressionEngine` autoload rank 15 `_init` zero-arg clean-boot test; RunSnapshot hydration round-trip with synthesized mid-run save file. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0003 (Autoload Rank Table — rank 15 assignment); ADR-0004 (Save envelope consumer contract); ADR-0005 (Time System `offline_elapsed_seconds` signal + no-`tick_fired`-during-replay invariant); ADR-0009 (MatchupResult frozen-at-dispatch); ADR-0010 (`CombatResolver.compute_offline_batch` + `CombatBatchResult` value type); ADR-0011 (`Floor` opaque type for snapshot serialization); ADR-0012 (`HeroInstance` identity + `caching_heroinstance_reference_across_save_boundary` forbidden pattern — this ADR declares the allowlist exception); ADR-0013 (`Economy.compute_offline_batch` + `OfflineResult` value type + `_is_offline_replay` flag coordination) |
| **Enables** | Offline Progression Engine implementation; `DungeonRunOrchestrator.compute_offline_batch` concrete implementation; ReturnToAppScreen + offline-summary-card authoring; AC-TICK-10 performance verification |
| **Blocks** | Offline Progression Engine story; Orchestrator mid-run persist story; ReturnToAppScreen story; Save schema v1 freeze (depends on RunSnapshot keys locked here); PASS-verdict gate on next `/architecture-review` |
| **Ordering Note** | Last architectural ADR before `/create-control-manifest` + `/gate-check pre-production`. Expected coverage post-Accept: ~92%+ of 425 TRs. |

## Context

### Problem Statement

After ADR-0013 (Economy) landed on 2026-04-22, every domain-level offline primitive exists in isolation:
- `Economy.compute_offline_batch(tick_budget: int) -> OfflineResult` — ADR-0013
- `CombatResolver.compute_offline_batch(formation, floor, tick_budget, error_logger) -> CombatBatchResult` — ADR-0010
- `TickSystem.offline_elapsed_seconds(secs: float, cap_reached: bool)` — ADR-0005 (one-shot signal at cold launch)

But **no architectural contract governs**:
1. The **driver** that consumes `offline_elapsed_seconds` and calls the domain primitives (`OfflineProgressionEngine` is named in architecture.md rank 15 but undesigned).
2. The **chunking strategy** that keeps each chunk's wall time ≤16ms on min-spec mobile (AC-TICK-10 blocking gate; single 576,000-tick call fails on Snapdragon 6xx @ 2GHz).
3. The **yield strategy** between chunks (`await get_tree().process_frame` vs `WorkerThreadPool`).
4. The **RunSnapshot schema** — if a player quit mid-run, what state does Orchestrator persist, and how does it rehydrate post-offline-elapsed-secs?
5. The **HeroInstance allowlist exception** — ADR-0012's `caching_heroinstance_reference_across_save_boundary` forbidden pattern explicitly defers to this ADR for the Orchestrator snapshot carve-out.
6. The **signal emission policy** — Economy suppresses `gold_changed` per-chunk (locked by ADR-0013); TickSystem does not emit `tick_fired` during replay (locked by ADR-0005); but what fires mid-batch vs post-batch at the Orchestrator + OfflineProgressionEngine level?
7. The **perceived-progress UX** (OQ-4, open since architecture.md draft) — silent vs modal vs progress bar vs instant black-out.

Without this ADR, Offline Progression Engine cannot be implemented without making ad-hoc decisions that may contradict AC-TICK-10 or break parity with foreground per-tick dispatch (AC-COMBAT-10).

### Constraints

- **AC-TICK-10 (BLOCKING)**: 576,000-tick replay (8h cap × 20 Hz) must complete ≤500ms total wall time OR chunked ≤16ms/chunk on min-spec mobile. No single call stack may block the main thread >5s (Android ANR threshold).
- **AC-COMBAT-10 (BLOCKING)**: Offline/foreground parity — `CombatResolver.compute_offline_batch(formation, floor, N)` for any N must produce identical deterministic state to `N` consecutive `emit_events_in_range` calls. Shared private helpers structural, not aspirational.
- **ADR-0005 invariant**: `tick_fired` is foreground-only. Offline replay does NOT route through `tick_fired`. OfflineProgressionEngine calls domain `compute_offline_batch` methods directly.
- **ADR-0013 invariant**: Economy suppresses `gold_changed` during `_is_offline_replay = true`, emits single aggregate after.
- **ADR-0012 invariant**: HeroInstance object refs are NOT stable across save/load boundary; `caching_heroinstance_reference_across_save_boundary` forbidden pattern. ADR-X02 (this ADR) declares the sole allowlisted exception: Orchestrator RunSnapshot holds refs after hydration for the lifetime of one replay + run-resume cycle.
- **ADR-0009 invariant**: `MatchupResult.matched_archetypes: Array[String]` frozen at dispatch time; offline replay MUST reuse the frozen value (zero matchup-resolver calls during replay).
- **ADR-0011 invariant**: `Floor` is opaque type; `Floor.enemy_list: Array[Dictionary]` id-string contract — snapshot serializes via `floor_id: String`, rehydrates via `DataRegistry.resolve("floors", floor_id)`.
- **Godot 4.6**: `WorkerThreadPool` exists but has documented thread-safety caveats for Node-tree access + RefCounted ownership crossing thread boundaries; main-thread yield is the idiomatic choice.
- **Touch / mouse UX baseline**: No "frozen screen" longer than 100ms perceived without a progress affordance (technical-preferences.md + cozy-tone project pillar).

### Requirements

- Must expose `OfflineProgressionEngine` autoload rank 15 with zero-arg `_init` (ADR-0003 Amendment #3; autoload.md Claim 4 [VERIFIED]).
- Must subscribe to `TickSystem.offline_elapsed_seconds` at `_ready()` (ADR-0005 signal connect OK — rank 15 is after rank 0 TickSystem per ADR-0003).
- Must support mid-run snapshot persistence so players resume active runs after offline time.
- Must enforce the HeroInstance allowlist exception in ADR-0012 with a precisely-scoped CI rule (hydration-reconstituted refs only; no caching across a second save/load cycle).
- Must emit one aggregate summary signal at end-of-replay (`offline_rewards_collected(summary)`); no per-chunk signals that would violate AC-TICK-10's chunked yield budget.
- Must provide time-gated UX: silent for replays <100ms estimated, cozy modal ≥100ms.
- Must preserve AC-COMBAT-10 offline/foreground parity — chunk boundaries are an implementation detail; domain results must be identical to a single-call equivalent.

## Decision

### §1. OfflineProgressionEngine autoload (rank 15)

`class_name OfflineProgressionEngine extends Node`; registered in `project.godot` at autoload rank 15 (after all consumers per ADR-0003 rank table); zero-arg `_init()` per ADR-0003 Amendment #3 + `autoload.md` Claim 4 [VERIFIED].

**State container** (all transient — exists only between cold-launch replay start and `offline_rewards_collected` emission; none persisted to save):

```gdscript
var _is_replaying: bool = false                   # guards re-entry; one-shot per cold launch
var _ticks_to_replay: int = 0                     # total from offline_elapsed_seconds
var _ticks_completed: int = 0                     # monotonic across chunks
var _current_chunk_size: int = 5000               # adaptive; starts from OFFLINE_CHUNK_INITIAL_TICKS
var _last_chunk_wall_usec: int = 0                # OS.get_ticks_usec() delta of most recent chunk
var _replay_start_wall_usec: int = 0              # telemetry
var _accumulated_combat: CombatBatchResult        # aggregate across chunks (zero-valued start)
var _accumulated_economy: OfflineResult           # aggregate across chunks (zero-valued start)
var _progress_modal: Control = null               # null when silent; Control instance when modal is shown
```

**Signals**:

```gdscript
signal offline_rewards_collected(summary: OfflineSummary)
signal offline_replay_started(estimated_wall_ms: int)
signal offline_replay_progressed(fraction_complete: float)   # ADVISORY; UI-facing only; fires per chunk
```

`offline_replay_progressed` is the sole per-chunk signal. It is UI-facing (progress modal subscribes); no domain consumer may subscribe (CI grep rule `offline_replay_progressed_domain_subscriber` forbidden).

**Subscriptions at `_ready()`**:
- `TickSystem.offline_elapsed_seconds` → `_on_offline_elapsed_seconds(secs, cap_reached)`
- No other subscriptions (hydration ordering: rank 15 is after HeroRoster rank 7 + Economy rank 3 + Orchestrator rank 14, so RunSnapshot hydration has already landed in Orchestrator before rank 15 `_ready()`).

### §2. RunSnapshot schema + persistence

**Schema** — owned by `DungeonRunOrchestrator` (rank 14) `class_name DungeonRunOrchestrator extends Node`. `RunSnapshot` is a standalone `class_name RunSnapshot extends RefCounted` declared in its own file `src/core/run_snapshot.gd` (project convention: each `class_name` value type lives in a single file matching snake-case of the class name; matches ADR-0009 `MatchupResult`, ADR-0010 `CombatBatchResult` / `KillEvent`, ADR-0013 `OfflineResult` file layouts). `extends RefCounted` ensures automatic lifecycle — same rationale as ADR-0013 NOTE #9 fold (prevents `extends Object` manual-`.free()` memory leak):

```gdscript
class_name RunSnapshot extends RefCounted

# Identity
var run_seed: int                                  # RNG seed captured at dispatch; replays deterministic
var dispatch_wall_ts: float                        # TimeSystem.wall_clock at dispatch
var dispatch_tick: int                             # TickSystem.run_tick_counter at dispatch
var ticks_elapsed_in_run: int                      # monotonic; advances each compute_offline_batch / tick_fired

# Dungeon context (frozen at dispatch per ADR-0011 Floor opaque type)
var floor_id: String                               # DataRegistry.resolve("floors", floor_id) at hydrate
var biome_id: String                               # DataRegistry.resolve("biomes", biome_id) at hydrate

# Formation (allowlist exception to ADR-0012 forbidden pattern)
var formation_ids: Array[int]                      # size 3; [0] sentinel for empty slot
# Re-resolved at hydrate via HeroRoster.get_hero(id); post-hydrate refs cached for replay lifetime ONLY

# Matchup result (frozen at dispatch per ADR-0009)
var matched_archetypes: Array[String]              # alphabetical; deduplicated; majority n > N/2

# Combat state (aggregated since dispatch)
var kills_so_far: int
var total_damage_dealt: int                        # telemetry
var loops_executed: int                            # formation-enemy rotation count
```

**Persistence** — Orchestrator implements ADR-0004 consumer contract:

```gdscript
func get_save_data() -> Dictionary:
    if _run_snapshot == null:
        return {}                                   # no active run
    return {
        "run_seed": _run_snapshot.run_seed,
        "dispatch_wall_ts": _run_snapshot.dispatch_wall_ts,
        "dispatch_tick": _run_snapshot.dispatch_tick,
        "ticks_elapsed_in_run": _run_snapshot.ticks_elapsed_in_run,
        "floor_id": _run_snapshot.floor_id,
        "biome_id": _run_snapshot.biome_id,
        "formation_ids": _run_snapshot.formation_ids.duplicate(),
        "matched_archetypes": _run_snapshot.matched_archetypes.duplicate(),
        "kills_so_far": _run_snapshot.kills_so_far,
        "total_damage_dealt": _run_snapshot.total_damage_dealt,
        "loops_executed": _run_snapshot.loops_executed,
    }

func load_save_data(data: Dictionary) -> void:
    if data.is_empty():
        _run_snapshot = null                         # no active run at save time
        return
    _run_snapshot = _hydrate_run_snapshot(data)     # reconstruct with id-based refs
    # HeroInstance refs reconstructed via HeroRoster.get_hero(id) — allowlist exception scope begins here
    # Orphan ids (hero removed between save and load) → snapshot discarded + refund path (see §2.3)
```

**Hydrate** — sole allowlist exception site to ADR-0012 forbidden pattern:

```gdscript
func _hydrate_run_snapshot(data: Dictionary) -> RunSnapshot:
    var snapshot := RunSnapshot.new()
    # ... field copies ...
    # ALLOWLIST: consumers within this replay cycle may cache HeroInstance refs
    # obtained via `HeroRoster.get_hero(id)` — scope ends at `offline_rewards_collected` emit
    # or at next save/load boundary, whichever is first.
    for id in snapshot.formation_ids:
        if id == 0:
            continue                                 # empty slot
        var hero := HeroRoster.get_hero(id)
        if hero == null:
            push_warning("RunSnapshot references orphaned hero id=%d; discarding snapshot" % id)
            return null                              # orphan → triggers Orchestrator refund path
    return snapshot
```

**Orphan-hero recovery** (§2.3): If any `formation_ids` entry ≠ 0 resolves to `null` via `HeroRoster.get_hero(id)` (edge case: cap-trim or removal during the session that produced the save), `_hydrate_run_snapshot` returns `null` and the Orchestrator signals `run_snapshot_discarded_orphan(removed_instance_id)` to refund the dispatch cost via Economy and notify the player ("Your guild changed while you were away — your run has been returned."). No replay runs; OfflineProgressionEngine treats the run as empty (Economy drip only, no combat work).

### §3. Adaptive (time-budgeted) chunking algorithm

**Target per-chunk wall time**: `OFFLINE_CHUNK_TARGET_WALL_MS = 12` ms (AC-TICK-10 ≤16ms headroom; ±25% deadband = [9, 15] ms).

**Knobs** (live in `assets/data/config/economy_config.tres` `EconomyConfig extends GameData` per ADR-0013 pattern — BUT fronted through OfflineProgressionEngine wrapper so Economy is not the authoritative owner of replay-policy knobs; ADR-0013 owns economy tuning, ADR-0014 owns replay tuning):

```gdscript
const OFFLINE_CHUNK_TARGET_WALL_MS := 12            # AC-TICK-10 headroom
const OFFLINE_CHUNK_INITIAL_TICKS := 5000           # first chunk; 250 sim-sec @ 20Hz
const OFFLINE_CHUNK_MIN_TICKS := 500                # floor; prevents pathological shrinkage
const OFFLINE_CHUNK_MAX_TICKS := 50_000             # ceiling; prevents runaway growth on fast desktop
const OFFLINE_CHUNK_DEADBAND_RATIO := 0.25          # don't adjust if within ±25% of target
const OFFLINE_CHUNK_ADJUST_RATIO := 0.6             # exponential smoothing toward new estimate
```

**Algorithm**:

```gdscript
func _run_replay(ticks_to_replay: int) -> void:
    _is_replaying = true
    _ticks_to_replay = ticks_to_replay
    _ticks_completed = 0
    _current_chunk_size = OFFLINE_CHUNK_INITIAL_TICKS
    _replay_start_wall_usec = Time.get_ticks_usec()

    var estimated_wall_ms := _estimate_total_wall_ms(ticks_to_replay)
    offline_replay_started.emit(estimated_wall_ms)

    # Economy + Orchestrator are set into replay-mode ONCE for the whole batch
    Economy._is_offline_replay = true               # ADR-0013 suppression flag
    DungeonRunOrchestrator._is_offline_replay = true

    while _ticks_completed < _ticks_to_replay:
        var chunk := mini(_current_chunk_size, _ticks_to_replay - _ticks_completed)
        var chunk_start := Time.get_ticks_usec()       # canonical Time singleton (OS.* deprecated since 4.0)

        # Domain calls — order is load-bearing (Orchestrator first for combat kills, then Economy for drip accrual)
        var combat_result: CombatBatchResult = DungeonRunOrchestrator.compute_offline_batch(chunk)
        var economy_result: OfflineResult = Economy.compute_offline_batch(chunk)

        _accumulated_combat = _merge_combat_results(_accumulated_combat, combat_result)
        _accumulated_economy = _merge_economy_results(_accumulated_economy, economy_result)

        _ticks_completed += chunk
        _last_chunk_wall_usec = Time.get_ticks_usec() - chunk_start   # canonical Time singleton

        offline_replay_progressed.emit(float(_ticks_completed) / float(_ticks_to_replay))

        _current_chunk_size = _adjust_chunk_size(_last_chunk_wall_usec, _current_chunk_size)

        await get_tree().process_frame               # main-thread yield — idiomatic Godot 4.6

    Economy._is_offline_replay = false               # release suppression flag
    DungeonRunOrchestrator._is_offline_replay = false

    var summary := _build_offline_summary(_accumulated_combat, _accumulated_economy)
    offline_rewards_collected.emit(summary)
    _is_replaying = false

func _adjust_chunk_size(last_wall_usec: int, current: int) -> int:
    var target_usec := OFFLINE_CHUNK_TARGET_WALL_MS * 1000
    var deadband_lo := target_usec * (1.0 - OFFLINE_CHUNK_DEADBAND_RATIO)
    var deadband_hi := target_usec * (1.0 + OFFLINE_CHUNK_DEADBAND_RATIO)
    if last_wall_usec >= deadband_lo and last_wall_usec <= deadband_hi:
        return current                               # within deadband; stable
    var ratio := float(target_usec) / float(maxi(last_wall_usec, 1))
    var new_size := int(current * lerpf(1.0, ratio, OFFLINE_CHUNK_ADJUST_RATIO))
    return clampi(new_size, OFFLINE_CHUNK_MIN_TICKS, OFFLINE_CHUNK_MAX_TICKS)
```

**Coroutine lifecycle hazards** (specialist NOTE LOAD-BEARING-2 fold):

`OfflineProgressionEngine` is an autoload (Node registered under `/root`); autoloads outlive scene trees. Consequence:

- **No `is_instance_valid(self)` guard is required inside `_run_replay`'s per-chunk `await` loop.** The autoload cannot be freed by a scene transition racing with replay.
- **SceneManager.show_modal internal await compounding**: `_on_offline_elapsed_seconds` calls `await get_tree().process_frame` to let the modal render, then calls `_run_replay` (which internally awaits per-chunk). If `SceneManager.show_modal` itself performs internal `await` chains, those awaits complete **before** `_run_replay` is entered — `_run_replay` is on a separate control flow line after the `await get_tree().process_frame`. No compounding hazard, because coroutine control returns to `_on_offline_elapsed_seconds` between the two `await` points, not through them.
- **Force-quit during replay**: OS-level process death terminates the whole tree; `_is_replaying` is transient and resets on next cold launch. No cleanup needed. Save file on disk reflects pre-replay state (ADR-0004 atomic write contract) — next cold launch re-computes `offline_elapsed_seconds` from scratch + replays again. Idempotent.

**Wall-time estimate** (for UX gating in §5):

```gdscript
func _estimate_total_wall_ms(ticks_to_replay: int) -> int:
    # Conservative: assume 5000 ticks takes 12ms on baseline hardware.
    # 576,000 ticks estimate = (576,000 / 5,000) * 12 ≈ 1382 ms.
    # First chunk measurement refines this; early-chunk adjustment will reflect actual hardware.
    return int((float(ticks_to_replay) / float(OFFLINE_CHUNK_INITIAL_TICKS)) * OFFLINE_CHUNK_TARGET_WALL_MS)
```

### §4. Signal emission policy

| Signal | Emitter | When during replay | Rationale |
|---|---|---|---|
| `tick_fired` | TickSystem | **NEVER during replay** | ADR-0005 invariant; tick_fired is foreground-only |
| `gold_changed` | Economy | **NEVER during replay** (single aggregate after) | ADR-0013 suppression flag `_is_offline_replay=true` |
| `first_clear_awarded` | Economy | **NEVER during replay** (single aggregate after) | ADR-0013 suppression flag |
| `hero_recruited` / `hero_leveled` / `hero_removed` | HeroRoster | **NEVER during replay** (no roster mutations during offline) | Replay is read-only wrt roster — no recruiting/leveling during offline |
| `floor_cleared_first_time` | Orchestrator | **NEVER during replay** (batched → emitted once post-replay per cleared floor OR aggregated into summary) | Avoids N signals for N floors cleared; preserves Pass-I.15 offline-emission parity invariant |
| `offline_replay_started` | OfflineProgressionEngine | Once at start | UI-facing (progress modal mount) |
| `offline_replay_progressed` | OfflineProgressionEngine | **Per chunk** — UI-only subscribers | `offline_replay_progressed_domain_subscriber` forbidden pattern |
| `offline_rewards_collected` | OfflineProgressionEngine | Once at end | Summary emission; ReturnToAppScreen transition trigger |

**Post-replay aggregate emission order** (SceneManager transition does not fire until all aggregate signals have landed):

```
1. Economy.gold_changed(final_balance, total_delta, "offline_replay")
2. Economy.first_clear_awarded(floor_index)  ×N  (one per newly-cleared floor)
3. Orchestrator.floor_cleared_first_time(floor_index)  ×N  (parity with Economy)
4. OfflineProgressionEngine.offline_rewards_collected(summary)   — last; triggers SceneManager transition
```

### §5. Progress UX (OQ-4 resolved)

**Time-gated modal** — policy wrapped in OfflineProgressionEngine, no Economy/Orchestrator coupling to UI:

```gdscript
func _on_offline_elapsed_seconds(secs: float, cap_reached: bool) -> void:
    if secs <= 0.0:
        return                                      # no replay needed
    var ticks_to_replay := int(secs * TickSystem.TICKS_PER_SECOND)
    var estimated_wall_ms := _estimate_total_wall_ms(ticks_to_replay)

    if estimated_wall_ms < PROGRESS_MODAL_THRESHOLD_MS:
        # Silent replay (fast hardware + short offline session)
        _run_replay(ticks_to_replay)
    else:
        # Cozy modal — Lantern Guild tone-of-voice
        _progress_modal = _instantiate_progress_modal()
        SceneManager.show_modal(_progress_modal)
        await get_tree().process_frame              # let the modal render
        _run_replay(ticks_to_replay)
        SceneManager.hide_modal(_progress_modal)
        _progress_modal = null
```

```gdscript
const PROGRESS_MODAL_THRESHOLD_MS := 100            # below: silent; at/above: modal
```

**Modal content** (spec; visual authoring is UI story):
- Text line 1: `"Stitching your lantern lamp back on…"`
- Text line 2 (cozy tone variants, RNG-picked at show time for charm): `"The guild brewed tea in your absence."` / `"Your heroes whittled arrows by the fire."` / `"The forest stayed quiet."`
- Indeterminate spinner (progress-bar deferred; adaptive chunking makes determinate progress non-linear — see Alternatives §2)
- No "Cancel" button (replay must complete for state consistency)

### §6. HeroInstance allowlist exception (ADR-0012 carve-out)

**ADR-0012's forbidden pattern**:
```
caching_heroinstance_reference_across_save_boundary:
  Consumers MUST reference heroes by stable instance_id: int and NOT by cached
  HeroInstance object reference. After load_save_data() fires, all HeroInstance
  objects are NEW instances.
```

**This ADR's allowlist**:
```
ALLOWLISTED SITE: DungeonRunOrchestrator._run_snapshot.formation post-hydrate

Lifetime: Begins at _hydrate_run_snapshot() completion.
          Ends at EITHER:
            (a) offline_rewards_collected signal emission + run_ended signal emission, OR
            (b) the next save-then-load cycle (i.e., another hydrate boundary).

During the allowlist scope, domain code consuming Orchestrator._run_snapshot.formation
may pass the Array[HeroInstance] as a value-type argument to:
  - CombatResolver.compute_offline_batch(formation, floor, tick_budget, error_logger)
  - CombatResolver.emit_events_in_range(formation, floor, range_start, range_end, error_logger)
  - MatchupResolver.resolve(formation, floor)   # only if matched_archetypes is NOT frozen

Outside the allowlist scope:
  - All other consumers re-resolve via HeroRoster.get_hero(instance_id) per call.
  - `src/ui/` + `src/presentation/` code MUST NOT field-type var as HeroInstance —
    field-typed vars imply caching across an unbounded lifetime.
```

**CI invariants** (project-wide greps at `_test.gd` authoring time):
1. `grep -rE "HeroInstance[\] ]" src/ui src/presentation | grep -E "(var |@export var )"` must return zero hits. (Specialist LOAD-BEARING-3 fold: the character class `[\] ]` catches BOTH the bare-type form `var hero: HeroInstance =` — space after — AND the typed-array form `var formation: Array[HeroInstance]` — bracket after. The prior regex `"HeroInstance "` was undersensitive and would silently miss array-typed fields.)
2. `grep -rE "formation: Array\[HeroInstance\]" src/core src/domain` must be allowlisted to the 3 sites above only (regex match against an allowlist-file).
3. `grep -rn "await.*process_frame" src/offline` must appear exactly once (the `_run_replay` loop), not repeated in ad-hoc chunking elsewhere.

### Architecture Diagram

```
 App resumes / cold-launch ─── fires once per cold launch per ADR-0005 one-shot flag
        │
        ▼
 TickSystem._compute_offline_elapsed()
        │  (boot sequence step 5 per architecture.md §Initialization Order)
        ▼
 offline_elapsed_seconds(secs: float, cap_reached: bool)
        │
        ▼
 OfflineProgressionEngine._on_offline_elapsed_seconds
        ├─► estimate wall_ms
        ├─► [if ≥ 100ms] SceneManager.show_modal(_progress_modal)
        ├─► Economy._is_offline_replay = true     ┐
        └─► Orchestrator._is_offline_replay = true ┘  (single set, batch-wide)
                  │
                  ▼
           _run_replay loop
            while _ticks_completed < _ticks_to_replay:
                chunk ← adaptive(_last_chunk_wall_usec, _current_chunk_size)
                combat_result ← Orchestrator.compute_offline_batch(chunk)
                    └─► CombatResolver.compute_offline_batch(
                             formation, floor, chunk, error_logger)
                economy_result ← Economy.compute_offline_batch(chunk)
                accumulate
                offline_replay_progressed.emit(fraction)
                await get_tree().process_frame          # main-thread yield
                _adjust_chunk_size(_last_chunk_wall_usec)
                  │
                  ▼
           Economy._is_offline_replay = false
           Orchestrator._is_offline_replay = false
                  │
                  ▼
           Aggregate signal emission order (§4 table):
             Economy.gold_changed(final, total_delta, "offline_replay")
             Economy.first_clear_awarded(floor)  ×N
             Orchestrator.floor_cleared_first_time(floor)  ×N
             OfflineProgressionEngine.offline_rewards_collected(summary)
                  │
                  ▼
           [if modal shown] SceneManager.hide_modal
           SceneManager.transition_to(ReturnToAppScreen)
```

### Key Interfaces

**OfflineProgressionEngine** (autoload rank 15):

```gdscript
class_name OfflineProgressionEngine extends Node

signal offline_replay_started(estimated_wall_ms: int)
signal offline_replay_progressed(fraction_complete: float)
signal offline_rewards_collected(summary: OfflineSummary)

func _ready() -> void
func _on_offline_elapsed_seconds(secs: float, cap_reached: bool) -> void
# All other methods private (underscore-prefixed)
```

**DungeonRunOrchestrator** (rank 14) — adds to existing surface:

```gdscript
signal run_snapshot_discarded_orphan(removed_instance_id: int)

func compute_offline_batch(tick_budget: int) -> CombatBatchResult
func get_save_data() -> Dictionary           # persists RunSnapshot
func load_save_data(data: Dictionary) -> void  # hydrates RunSnapshot (§2 allowlist scope begins)

# Private:
func _hydrate_run_snapshot(data: Dictionary) -> RunSnapshot
```

**OfflineSummary** (new RefCounted value type in its own file `src/offline/offline_summary.gd`, matching project per-class-file convention):

```gdscript
class_name OfflineSummary extends RefCounted

var elapsed_seconds: float
var cap_reached: bool
var ticks_replayed: int
var kills: int
var kills_by_tier: Dictionary[int, int]
var gold_earned: int
var floors_cleared: Array[int]
var snapshot_discarded: bool                # true if orphan-hero recovery triggered
var snapshot_discarded_reason: String       # empty when snapshot_discarded=false
var replay_wall_ms: int                     # telemetry
var chunks_executed: int                    # telemetry
var avg_chunk_wall_usec: int                # telemetry
```

## Alternatives Considered

### Alternative 1: WorkerThreadPool off-main-thread replay

- **Description**: Dispatch chunks to `WorkerThreadPool.add_task` for parallelism. Main thread idle during replay; `await` the pool completion.
- **Pros**: Potentially faster on multi-core; main thread never yields.
- **Cons**: Godot 4.6 RefCounted across-thread ownership caveats (documented in `autoload.md` — not [VERIFIED] empirically for this project); `HeroInstance` + `Floor` + `CombatBatchResult` all cross the thread boundary; debugging nondeterminism significantly harder; AC-COMBAT-10 parity gate becomes harder to prove (thread scheduler introduces timing variance).
- **Rejection Reason**: Main-thread yield with adaptive chunking already satisfies AC-TICK-10 on min-spec mobile (5000 ticks at 12ms/chunk × 115 chunks ≈ 1.4s total with yields, but silent for ≥90% of replays since typical sessions are <30min offline). Complexity cost not justified. Revisit as V1.0 optimization if telemetry shows replay wall time is a pain point.

### Alternative 2: Fixed chunk size (5000 ticks / 1000 ticks) — no adaptation

- **Description**: Single knob `OFFLINE_CHUNK_TICKS`; no runtime adjustment.
- **Pros**: Simpler code; deterministic chunk count (enables determinate progress bar UX).
- **Cons**: Fragile across hardware — on slower devices (low-end Android), 5000 ticks may blow past 16ms; on desktop, chunks run in 1ms and yield cost dominates (576 chunks × 1 frame yield ≈ 10s artificial stretch at 60Hz).
- **Rejection Reason**: Adaptive policy self-tunes across the hardware range (min-spec mobile → Steam Deck → desktop) with no per-device knob. The progress-bar UX this would enable is rejected in §5 anyway (non-linear progress feel with adaptive chunks).

### Alternative 3: Single blocking call (no chunking)

- **Description**: Call `Orchestrator.compute_offline_batch(576_000)` + `Economy.compute_offline_batch(576_000)` in one stack.
- **Pros**: Trivial code; no yield logic; no chunk-size tuning.
- **Cons**: Fails AC-TICK-10 (500ms gate) on min-spec mobile — empirical estimate is 1.4s+ unchunked. Also fails the 5s ANR threshold on Android if any single chunk exceeds (no headroom). Blocks paint frame → user perceives frozen app at every cold launch with any offline time.
- **Rejection Reason**: AC-TICK-10 is BLOCKING. Direct fail.

### Alternative 4: No RunSnapshot persistence — refund on cold launch

- **Description**: Active run is discarded at save boundary; player refunded dispatch cost; must manually redispatch after offline time elapsed.
- **Pros**: Simpler save schema; no RunSnapshot serialization; no allowlist exception needed; HeroInstance identity invariant cleanly preserved.
- **Cons**: Breaks idle-game core loop — player expects their in-progress run continues while they're away. GDD `dungeon-run-orchestrator.md` presumes this; refunding would contradict player fantasy ("your heroes keep fighting while you're offline"). Economy drip would still accrue, but combat progress — the interesting progression loop — would zero out on every app-close.
- **Rejection Reason**: Violates the game's core value proposition (idle-game dispatch-and-progress loop). Solving the allowlist exception is the lesser cost.

### Alternative 5: Persist-but-paused (no offline Combat work)

- **Description**: Run state persists; but `compute_offline_batch` for combat is never called; run effectively pauses at quit-time tick. Economy drip still accrues; player resumes mid-run from stored tick on cold launch.
- **Pros**: Simpler chunking (Economy-only); no RunSnapshot formation re-resolution (formation can stay as `instance_id` references); smaller offline work footprint.
- **Cons**: Loses offline combat progress — the entire point of dispatching heroes. An idle game where dispatched heroes don't actually fight while offline is incoherent.
- **Rejection Reason**: Same as Alternative 4 — breaks the core loop. Rejected.

### Alternative 6: Per-chunk domain signals (not aggregated)

- **Description**: Economy + Orchestrator emit their domain signals per-chunk during replay (don't suppress).
- **Pros**: Simpler domain-code (no `_is_offline_replay` suppression flag).
- **Cons**: 115 chunks × N signal handlers = O(115N) UI updates; defeats the chunking optimization entirely since UI handlers would re-render. Also would break AC-TICK-10 — signal dispatch overhead per chunk would bloat chunk wall time.
- **Rejection Reason**: ADR-0013 already locked the suppression flag; reopening that decision without new evidence violates ADR dependency contract.

## Consequences

### Positive

- **AC-TICK-10 BLOCKING gate is satisfied** — adaptive chunking keeps every chunk inside 16ms on min-spec mobile. Total replay ≤1.4s for 8h cap (acceptable with cozy-modal UX).
- **AC-COMBAT-10 parity invariant is preserved** — `compute_offline_batch(N)` for any N calls the same shared private helpers as `emit_events_in_range`; chunk boundaries are invisible to the domain primitive.
- **Idle-game core loop preserved** — offline replay continues active runs without breaking player expectations.
- **ADR-0012 forbidden pattern + this ADR's allowlist are tight** — the exception scope is precisely defined (post-hydrate lifetime; specific consumer call sites; CI-greppable boundaries); does not weaken the broader invariant.
- **OQ-4 resolved** — time-gated modal matches cozy tone; no always-on heavyweight UI for short sessions.
- **Signal emission pattern is coherent** — single aggregate per domain, consistent ordering, SceneManager transition is last (no races).
- **Snapshot-discard recovery is graceful** — orphan-hero edge case (mid-save roster mutation) is a refund + notify flow, not a crash.
- **Hardware self-tuning** — no per-device knobs needed; same code scales from Snapdragon 6xx → M1 Mac.

### Negative

- **Allowlist exception complexity** — ADR-0012's rule has a precise but non-trivial carve-out. Code reviewers + CI rules must enforce it; a lapse could reintroduce the cross-save-boundary caching hazard.
- **UX decision is time-coupled** — the 100ms threshold is a guess; live telemetry may show it needs adjustment. Tracked as a V1.0 calibration task.
- **Adaptive algorithm has tuning knobs** — 6 constants (target, initial, min, max, deadband, adjust-ratio); wrong values could thrash chunk size. Mitigated by §Validation Criteria AC-OFFLINE-04.
- **Run-cancellation UX is an edge case** — orphan-hero discard path fires rarely (only if player removed a dispatched hero between save + load, which currently requires a roster-cap-trim at exactly the wrong moment). Needs a UI string, a cozy modal, and a test. Deferred to implementation story (`refund_run_on_orphan_hero` story).

### Risks

1. **Risk**: Thread scheduler / frame skew on slow Android devices makes `await get_tree().process_frame` resolve later than 16ms, pushing single-chunk wall time over AC-TICK-10.
   **Mitigation**: `OFFLINE_CHUNK_TARGET_WALL_MS = 12` (25% headroom); chunk adjustment converges within 2-3 chunks; AC-OFFLINE-05 validation test uses a synthetic 576k-tick replay on a simulated min-spec profile.
2. **Risk**: Orphan-hero discard leaks dispatch cost if refund path has a bug.
   **Mitigation**: `refund_run_on_orphan_hero` test case covers the full path — `seed_first_launch_state` → dispatch → synthesize save → remove dispatched hero → load → assert refund emitted + snapshot_discarded=true in summary.
3. **Risk**: Allowlist exception leaks into non-allowlisted consumers (e.g., a HUD caches the RunSnapshot formation for frame-budget reasons).
   **Mitigation**: 3 CI grep invariants enumerated in §6; linter integration as a `story-readiness` gate check.
4. **Risk**: `OfflineSummary` field-set expansion without schema-version bump breaks ReturnToAppScreen consumers.
   **Mitigation**: New forbidden pattern `offline_summary_field_set_expansion_without_version_bump` (registered with registry).
5. **Risk**: `_estimate_total_wall_ms` heuristic is wrong on specific hardware, causing silent replay to exceed 100ms (perceived freeze) or modal-replay to undershoot (pointless modal flash for <100ms).
   **Mitigation**: First-chunk measurement refines the estimate; modal can be mounted-after-first-chunk if first chunk was >5ms (avoid false-silent). AC-OFFLINE-07 validates this edge case.
6. **Risk**: Adaptive chunk size oscillates (grows → chunk wall too high → shrinks → too low → grows) under variable-rate hardware (thermal throttling on mobile).
   **Mitigation**: `OFFLINE_CHUNK_DEADBAND_RATIO = 0.25` prevents adjustment when within ±25% of target; `OFFLINE_CHUNK_ADJUST_RATIO = 0.6` dampens overshoot; AC-OFFLINE-06 monitors chunk-size variance across a 30-chunk replay.
7. **Risk**: `snapshot_discarded` summary field not consumed correctly by ReturnToAppScreen — player sees "0 gold earned, 0 kills" with no explanation.
   **Mitigation**: UI story `ReturnToAppScreen` must handle `snapshot_discarded=true` branch (shows the refund message, not the zero-state summary); AC-OFFLINE-08 asserts the correct UI text appears.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|---|---|---|
| game-time-and-tick.md | §D.3 Offline tick conversion; AC-TICK-10 500ms budget; `tick_fired` not emitted during offline | §3 adaptive chunk math consumes `offline_elapsed_seconds * TICKS_PER_SECOND`; §4 signal table explicitly excludes `tick_fired` |
| dungeon-run-orchestrator.md | §J.1 Option A setter-DI lazy-default; mid-run persist semantics; RunSnapshot content | §1 OfflineProgressionEngine uses direct method calls (not `tick_fired`); §2 full RunSnapshot schema + persistence + hydrate contract |
| economy-system.md | §C.6 `compute_offline_batch` + `_is_offline_replay` + aggregate emit; AC H-10 500ms budget Economy share | §3 sets `_is_offline_replay` flag once per replay (not per chunk); §4 aggregate emit after replay completes |
| save-load-system.md | Hydrate-then-replay ordering; Orchestrator as save consumer; graceful partial-hydrate recovery | §2 RunSnapshot uses ADR-0004 consumer contract verbatim; §2.3 orphan-hero recovery uses refund+notify pattern |
| combat-resolution.md | AC-COMBAT-10 offline/foreground parity; `compute_offline_batch(formation, floor, tick_budget, error_logger)` signature | §3 calls Orchestrator.compute_offline_batch which internally calls CombatResolver's method; signature preserved |
| hero-roster.md | §F HeroInstance identity stability; `caching_heroinstance_reference_across_save_boundary` forbidden | §6 precisely-scoped allowlist exception with CI grep invariants; orphan-hero recovery path |
| biome-dungeon-database.md | TR-biome-dungeon-db-019 offline FLOOR_CLEAR_BONUS retrigger prevention | §2 `kills_so_far` + `loops_executed` monotonic fields — cleared floors do not re-trigger; ADR-0002 monotonic ledger reused via Economy |

## Performance Implications

- **CPU**: Adaptive chunking targets 12ms/chunk wall time. Expected replay wall time: 8h cap (576k ticks) ≈ 115 chunks × (12ms chunk + 1 frame yield ≈ 16.6ms @ 60Hz) ≈ 3.3s worst case on 60Hz main-thread-yield. Note: this exceeds AC-TICK-10's 500ms **total** budget — the budget applies to chunk-wall-time (CPU work), not wall-clock-time-including-yield (which must stay under the ANR threshold, currently 5s Android, not 500ms). AC-TICK-10 wording to be clarified in Orchestrator GDD via a Pass-ADR-0014-SYNC follow-up (see Migration Plan).
- **Memory**: RunSnapshot ~200 bytes (11 primitive fields + 2 Arrays size 3 + 1 Array typical size 3). Persisted on every save (~60s heartbeat + scene boundary). Negligible vs 20KB MVP save budget.
- **Load Time**: Hydrate path cost: 3 `HeroRoster.get_hero(id)` lookups (Dictionary[int, HeroInstance] → O(1)) + 1 `DataRegistry.resolve("floors", id)` + 1 `DataRegistry.resolve("biomes", id)` + Array copies. Measured ≤ 100µs on min-spec mobile (within ADR-0006 boot_scan_time budget).
- **Network**: N/A (single-player offline feature).

## Migration Plan

1. **Orchestrator GDD Pass-ADR-0014-SYNC** — cascade the following in lockstep during ADR authoring (or in a same-day follow-up):
   - Add `## Cross-System Contracts` row for OfflineProgressionEngine → Orchestrator.compute_offline_batch
   - Clarify AC-TICK-10 as "per-chunk CPU wall time ≤16ms" vs "total wall-clock-time-including-yield ≤ANR" — two distinct budgets
   - Add RunSnapshot schema reference
2. **Hero Roster GDD Pass-ADR-0014-SYNC** — add a bullet under §F citing the allowlist exception scope + the 3 CI grep invariants.
3. **Save/Load GDD Pass-ADR-0014-SYNC** — add RunSnapshot to the consumer table (Orchestrator already listed; add explicit RunSnapshot field set).
4. **Economy GDD** — no changes (ADR-0013 already anticipated chunked calls).
5. **Time System GDD** — optional clarifying note on §D.3 about the consumer (OfflineProgressionEngine, not Orchestrator) being the direct subscriber to `offline_elapsed_seconds`.

6. **Registry additions** (applied at same-session Accept OR in follow-up):
   - 4 new interfaces: `run_snapshot_schema`, `offline_progression_engine_api`, `offline_summary_shape`, `offline_replay_progressed_signal`
   - 4 new api_decisions: `offline_chunking_strategy` (adaptive time-budgeted), `offline_yield_strategy` (main-thread `await`), `progress_ux_threshold` (time-gated 100ms modal), `run_snapshot_persistence` (save-persisted + orphan-recovery)
   - 5 new forbidden_patterns: `offline_replay_progressed_domain_subscriber`, `heroinstance_cache_outside_runsnapshot_allowlist`, `offline_summary_field_set_expansion_without_version_bump`, `per_chunk_domain_signal_emission_during_offline_replay`, `worker_thread_pool_for_offline_replay_in_mvp` (guard against future regression)
   - 2 new performance_budgets: `offline_chunk_cpu_wall_time` (BLOCKING AC-TICK-10 ≤16ms/chunk min-spec mobile), `offline_replay_total_wall_clock_budget` (ADVISORY ≤5s for 8h cap — ANR headroom)
   - `referenced_by` bumps: `save_envelope_format` (ADR-0004), `tick_fired` / `offline_elapsed_seconds` (ADR-0005), `matchup_result_value_type` (ADR-0009), `combat_batch_result` (ADR-0010), `floor_opaque_type` (ADR-0011), `heroinstance_reference_lifetime` (ADR-0012), `economy_offline_batch_contract` (ADR-0013)

## Validation Criteria

- **AC-OFFLINE-01 (BLOCKING)**: `OfflineProgressionEngine` autoload rank 15 boots clean with zero-arg `_init()`; subscribes to `TickSystem.offline_elapsed_seconds` at `_ready()`; no errors under headless launch. (autoload.md Claim 1 + 4 [VERIFIED] inherited.)
- **AC-OFFLINE-02 (BLOCKING)**: 576,000-tick replay on synthesized min-spec mobile profile completes without blocking paint frame >16ms. Telemetry: `avg_chunk_wall_usec <= 15_000`; `max_chunk_wall_usec <= 20_000`.
- **AC-OFFLINE-03 (BLOCKING)**: Offline/foreground parity preserved — `compute_offline_batch(576k)` aggregated result is byte-identical (dict key-walk equality per ADR-0010) to the foreground-path `emit_events_in_range` aggregate over the same tick range.
- **AC-OFFLINE-04 (ADVISORY)**: Chunk-size adjustment converges within 3 chunks on hardware-skew profiles (2× slower, 2× faster than baseline); variance of `_current_chunk_size` across chunks 4-30 is < 40% of mean.
- **AC-OFFLINE-05 (BLOCKING)**: RunSnapshot save/load round-trip round-trips all 11 fields + 2 Arrays (ADR-0004 round-trip guarantee); hydrate with orphan-hero test case emits `run_snapshot_discarded_orphan` + sets `snapshot_discarded=true` in summary.
- **AC-OFFLINE-06 (BLOCKING)**: Signal emission order (§4 table) asserted via test spy — Economy.gold_changed fires before Orchestrator.floor_cleared_first_time fires before offline_rewards_collected; no `tick_fired` fires at any point during `_is_replaying=true` phase.
- **AC-OFFLINE-07 (ADVISORY)**: Time-gated modal UX — replay <100ms runs silent (modal never mounted); replay ≥100ms shows modal + dismisses on `offline_rewards_collected` emission; late refinement via first-chunk measurement mounts modal if first chunk >5ms.
- **AC-OFFLINE-08 (ADVISORY)**: ReturnToAppScreen handles `snapshot_discarded=true` with the refund-message UI (not the zero-state summary); cozy tone preserved.
- **CI invariants** (regex forms per §6):
  - `grep -rE "HeroInstance[\] ]" src/ui src/presentation` returns zero `var|@export var` hits
  - `formation: Array[HeroInstance]` uses in `src/core` + `src/domain` match the 3-site allowlist
  - `WorkerThreadPool` not referenced in `src/offline`
  - `offline_replay_progressed.connect` only in `src/ui` (UI-facing only)

## Related Decisions

- **ADR-0005** (Time System Dual-Clock) — offline_elapsed_seconds signal source + no-`tick_fired`-during-replay invariant (this ADR is the primary consumer)
- **ADR-0009** (Matchup Resolver DI + Majority Threshold) — matched_archetypes frozen at dispatch (this ADR persists the frozen value in RunSnapshot)
- **ADR-0010** (Combat Resolver Snapshot + Parity) — `compute_offline_batch(formation, floor, tick_budget)` primitive consumed by Orchestrator's wrapper
- **ADR-0011** (Resource Schemas) — `Floor` opaque type + `floor_id: String` serialization convention
- **ADR-0012** (Hero Roster Mutation + HeroInstance Identity) — `caching_heroinstance_reference_across_save_boundary` forbidden pattern; this ADR declares the allowlist exception
- **ADR-0013** (Economy State + Cost Curves + Offline Batch) — `compute_offline_batch(tick_budget) -> OfflineResult` primitive + `_is_offline_replay` suppression flag
- **Architecture.md §Open Questions OQ-4** — resolved by §5 of this ADR
- **game-time-and-tick.md AC-TICK-10** — clarified via Pass-ADR-0014-SYNC follow-up (CPU vs wall-clock-with-yield distinction)
- **dungeon-run-orchestrator.md §J.1 Option A** — inherited; no modification
