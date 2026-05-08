# Lantern Guild — Master Architecture

## Document Status

| Field | Value |
|---|---|
| Version | 0.1 (Draft) — amended 2026-04-22 (rank table + module ownership: ranks 8 and 9 vacated per ADR-0003 Amendment #2; `_init(args)` cascade corrected per Amendment #3 — see §Autoload Rank Table + §API Boundaries) + ADR-0011 (Core Resource Schemas) Accepted 2026-04-22d — `Floor` opaque type now fully locked; archetype + role constant sets centralized + ADR-0012 (Hero Roster Mutation + HeroInstance Identity) Accepted 2026-04-22 — HeroRoster rank 7 mutation API + HeroInstance identity contract + boot validation order + cross-save stability invariant locked + ADR-0013 (Economy State + Cost Curves + Offline Batch Contract) Accepted 2026-04-22 — Economy rank 3 state shape + 7-method public API + cost curves `recruit_cost(class_id, copies)` + `level_cost(tier, level)` + `compute_offline_batch` closed-form drip + 4 new forbidden patterns (hardcoded-balance / losing-run-read / offline-replay-emit / negative-spend); economy-system.md Pass-ADR-0013-SYNC closes 4 signature drift items + ADR-0014 (Offline Replay Batch Chunking + RunSnapshot Schema) Accepted 2026-04-22 — OfflineProgressionEngine rank 15 autoload + adaptive time-budgeted chunking (target 12ms/chunk) + `await get_tree().process_frame` main-thread yield + RunSnapshot save-persisted schema (11 fields + 2 Arrays) + HeroInstance allowlist exception to ADR-0012 forbidden pattern + OQ-4 resolved via time-gated cozy modal (silent <100ms, cozy modal ≥100ms) + 5 new forbidden patterns (progressed-signal-domain-subscriber, heroinstance-cache-outside-runsnapshot-allowlist, offline-summary-field-expansion-without-version-bump, per-chunk-domain-signal-emission, worker-thread-pool-for-offline-replay-in-mvp) |
| Last Updated | 2026-04-22 (post `/architecture-decision` ADR-0014 landing + Accept promotion + registry lockstep + Pass-ADR-0014-SYNC notes applied to dungeon-run-orchestrator.md + hero-roster.md + save-load-system.md + game-time-and-tick.md) + 2026-04-26 — OQ-8 closure (SceneManager rank 8 assignment per ADR-0003 Amendment #4 / story S5-M4) |
| Engine | Godot 4.6 (pinned 2026-02-12) |
| Renderer | Forward+ (Vulkan desktop / Metal macOS / D3D12 Windows) |
| Language | GDScript (static-typed) |
| GDDs Covered | 13 system GDDs + game concept + systems-index |
| ADRs Referenced | ADR-0001 through ADR-0014 (all Accepted as of 2026-04-22 — ADR-0014 authored + promoted Proposed→Accepted same-session as the `/architecture-decision` same-day follow-up, matching ADR-0012/0013 same-session Accept pattern; locks OfflineProgressionEngine rank 15 autoload + adaptive time-budgeted chunking (target 12ms/chunk wall time, initial 5000 ticks, deadband ±25%) + `await get_tree().process_frame` main-thread yield strategy + RunSnapshot save-persisted schema with orphan-hero recovery + HeroInstance allowlist exception to ADR-0012 `caching_heroinstance_reference_across_save_boundary` forbidden pattern (lifetime-scoped to post-hydrate replay cycle) + OQ-4 resolved via time-gated cozy modal (PROGRESS_MODAL_THRESHOLD_MS = 100) + aggregate signal emission policy (`offline_rewards_collected` last); unblocks ~8-12 TRs across Orchestrator + Economy + biome-dungeon-db gap pools; projected coverage ~92%+ — **clear PASS-verdict candidate**) |
| Tier Scope | MVP (4-6 weeks) — Vertical Slice / Alpha / V1.0 deferred |
| Technical Director Sign-Off | 2026-04-22 — APPROVED WITH CONDITIONS (see §Open Questions) |
| Lead Programmer Feasibility | SKIPPED (Solo review mode) |

This document is the technical blueprint that every implementation story
references. Pair it with `docs/architecture/control-manifest.md` (forthcoming)
for the flat per-layer rules sheet.

---

## Engine Knowledge Gap Summary

Godot 4.6 is **post-cutoff (May 2025) by ~9 months**. The LLM training data
covers ~4.3 reliably. Risk levels per domain:

| Domain | Risk | Why It Matters For Lantern Guild |
|---|---|---|
| 2D Rendering / Forward+ | LOW | Project is 2D; no glow/tonemap rework affects MVP. |
| Resources & `duplicate_deep()` | LOW | Used by Save/Load + Data Loading hydration paths. |
| GDScript variadic + `@abstract` | LOW | Optional; not load-bearing for MVP. |
| Autoload `_ready()` rank order | **VERIFIED** | Critical for Save/Load consumer wiring. Empirical probe 2026-04-21 confirmed bare-identifier resolution + rank-N→rank-(N+1) signal connect at `_ready()`. See `docs/engine-reference/godot/modules/autoload.md` Claim 1. |
| ProjectSettings designer-UI keys | **HIGH** | Pass-8 Floor Unlock pattern empirically falsified. Designer-UI for Floor Unlock biome key deferred to V1.0; runtime fallback (`get_setting(key, default)` returns hardcoded default) covers MVP single-biome play. |
| HMAC-SHA256 in `Crypto` API | LOW | Used by Save/Load envelope. Stable since 4.x. |
| `FileAccess.store_*` returning bool | LOW | Project ignores return value or asserts truthy. |
| 2D Navigation Server | LOW | Not used (no path-finding in idle gameplay). |
| Jolt Physics default | N/A | 2D project; uses Godot Physics 2D regardless. |
| Dual-focus UI system (4.6) | MEDIUM | Mouse + Touch parity is a project goal. Verify focus visuals don't fragment between input methods. |
| Compositor / shader baker | DEFERRED | HD-2D pipeline is Vertical-Slice tier, not MVP. |

**Systems touching HIGH/MEDIUM risk domains in MVP**:
- Floor Unlock System → ProjectSettings (HIGH, designer-UI deferred)
- All UI systems → Dual-focus (MEDIUM, parity testing needed)

**Mitigation rule**: any code path touching a HIGH-risk API must reference
`docs/engine-reference/godot/modules/[domain].md` before merge. See coding standards.

---

## Architecture Principles

These five principles govern every technical decision below. When two principles
conflict, the lower-numbered one wins.

1. **Player time is sacred (Pillar 1)**. Persistence is non-negotiable. Every
   transition that leaves a session must persist; every load must verify; every
   silent data loss is a P0 bug. The Save/Load layer is allowed to refuse a
   transition if its persist fails.

2. **Stateless simulation, stateful boundaries**. Combat Resolution and the
   matchup pipeline are pure functions of `(snapshot, input)`. State lives in
   exactly one place per system (the rank-table autoload). Cross-module
   communication is signal-driven; nobody mutates another module's state directly.

3. **Time is the engine's enemy**. `_process(delta)` never feeds economy or
   simulation math. The Game Time & Tick System owns both clocks; everything
   downstream reads `tick_fired(n)` or queries `now_ms()`. Foreground/offline
   parity is a load-bearing invariant verified by AC-ORC-09.

4. **Content is data, not code**. Every gameplay value lives in a `.tres`
   resource under `assets/data/`. Adding a hero class, enemy type, or biome
   never requires editing a `.gd` file outside the relevant database autoload.
   Data Loading owns the eager-load pass at boot.

5. **Two input methods, one UI**. Mouse and touch must reach feature parity
   from MVP day one. No hover-only interactions. No right-click-exclusive
   actions. Tap targets ≥44×44 logical pixels. Steam Deck (1280×800) is a
   first-class target alongside desktop and mobile-port.

---

## System Layer Map

Five layers, dependency-sorted top-down. Each module name is the autoload
identifier (or scene name for Presentation modules).

```
┌─────────────────────────────────────────────────────────────────────────┐
│  POLISH LAYER                                                           │
│  Onboarding · SettingsAccessibility                                     │
├─────────────────────────────────────────────────────────────────────────┤
│  PRESENTATION LAYER (Scenes; UI; not autoloads)                         │
│  GuildHallScreen · ReturnToAppScreen · RecruitScreen · RosterScreen     │
│  MatchupAssignmentScreen · DungeonRunView · UnlockVictoryMoment         │
│  HD2DRenderingPipeline (deferred: Vertical Slice) · VFXSystem (deferred)│
├─────────────────────────────────────────────────────────────────────────┤
│  FEATURE LAYER (Autoloads, rank 6-12)                                   │
│  HeroRoster · ClassEnemyMatchupResolver · CombatResolution              │
│  OfflineProgressionEngine · DungeonRunOrchestrator · Recruitment        │
│  HeroLeveling · FloorUnlockSystem · FormationAssignment                 │
├─────────────────────────────────────────────────────────────────────────┤
│  CORE LAYER (Autoloads, rank 3-5)                                       │
│  Economy · HeroClassDatabase · EnemyDatabase · BiomeDungeonDatabase     │
│  AudioSystem (minimal MVP)                                              │
├─────────────────────────────────────────────────────────────────────────┤
│  FOUNDATION LAYER (Autoloads, rank 0-2, 8)                              │
│  TickSystem (rank 0) · DataRegistry (rank 1) · SaveLoadSystem      │
│  (rank 2) · SceneManager (rank 8) · UIFramework                    │
│  (theme resource, not autoload)                                         │
├─────────────────────────────────────────────────────────────────────────┤
│  PLATFORM LAYER (Godot 4.6)                                             │
│  SceneTree · ResourceLoader · FileAccess · Crypto · Time · Input        │
│  · DisplayServer · Compositor (deferred)                                │
└─────────────────────────────────────────────────────────────────────────┘
```

### Autoload Rank Table (Foundation→Feature)

Rank-ordered initialization. A rank-N autoload may connect to a rank-(N+1)
autoload's signal in its own `_ready()` — VERIFIED via empirical probe
(see `docs/engine-reference/godot/modules/autoload.md` Claim 1, 2026-04-21).

| Rank | Autoload | Layer | Purpose |
|---|---|---|---|
| 0 | `TickSystem` | Foundation | Wall + Sim clocks, 20Hz tick, session boundary timestamps |
| 1 | `DataRegistry` | Foundation | Eager-loads all `.tres` content under `assets/data/`, exposes `resolve(type, id)` |
| 2 | `SaveLoadSystem` | Foundation | Persistence boundary; orchestrates `get_save_data` / `load_save_data` over consumer rank table |
| 3 | `Economy` | Core | Gold balance, per-lifetime credit ledger (`floor_clear_bonus_credited`), recruitment cost calc |
| 4 | `HeroClassDatabase` | Core | Typed accessor over class `.tres` resources |
| 5 | `EnemyDatabase` | Core | Typed accessor over enemy `.tres` resources |
| 6 | `BiomeDungeonDatabase` | Core | Typed accessor over biome + dungeon + floor `.tres` resources |
| 7 | `HeroRoster` | Feature | Owns `Array[HeroInstance]`; recruit, level-up, deletion |
| 8 | `SceneManager` | Foundation | Persistent root scene orchestration; four-state machine (UNINITIALIZED/IDLE/TRANSITIONING/PAUSED); screen routing |
| 9 | *[VACANT]* | — | Reserved-vacant — see §Non-Autoload Pure-Function Modules below |
| 10 | `FloorUnlockSystem` | Feature | Owns unlocked-floor set; subscribes to `DungeonRunOrchestrator.floor_cleared_first_time` |
| 11 | `FormationAssignment` | Feature | Owns active formation; emits `formation_browse_opened` (read) and `formation_reassignment_committed` (write) |
| 12 | `Recruitment` | Feature | Owns recruit pool generation, gold-spend transactions |
| 13 | `HeroLeveling` | Feature | XP curve, level-up triggers, gold-cost lookups |
| 14 | `DungeonRunOrchestrator` | Feature | State machine: `NO_RUN → DISPATCHING → ACTIVE_FOREGROUND/OFFLINE_REPLAY → RUN_ENDED` |
| 15 | `OfflineProgressionEngine` | Feature | Wall-clock delta computation at session start, drives offline replay batches into Combat + Economy |
| 16 | `AudioRouter` | Core (Audio) | Centralized audio routing autoload — subscribes to gameplay signals (SceneManager, DungeonRunOrchestrator, HeroRoster, Economy) at `_ready()` and translates them into bus-routed cue plays per `audio-system.md`. Save consumer (volume + mute persistence). Added per ADR-0003 Amendment #5 (2026-05-05). |

**Rank 16 is occupied by `AudioRouter` (Core / Audio)** (per ADR-0003 Amendment #5, 2026-05-05 — story S11-S2 closed OQ-AS-1). Appended at the end of the rank table to preserve the existing rank assignments — placing AudioRouter AFTER all gameplay-signal sources guarantees that signal subscription at AudioRouter's `_ready()` always finds the source autoloads instantiated. **Rank 8 is occupied by `SceneManager` (Foundation)** (per ADR-0003 Amendment #4, 2026-04-26 — story S5-M4 closed OQ-8). **Rank 9 is deliberately vacant** (per ADR-0003 Amendment #2, 2026-04-22). The `MatchupResolver` and `CombatResolver` modules that originally occupied ranks 8 and 9 are non-autoload `RefCounted` instance classes injected into `DungeonRunOrchestrator` via public setters (`set_matchup_resolver` / `set_combat_resolver`) with lazy-default construction in `_ready()` — see §Non-Autoload Pure-Function Modules. Downstream ranks were intentionally NOT renumbered (per ADR-0003 §Editing Protocol, reorders require a superseding ADR; claiming a vacant slot is the permitted alternative). The `_init(args)` phrasing in earlier drafts is superseded by ADR-0003 Amendment #3 — Godot autoload Nodes cannot have required-arg `_init` (autoload.md Claim 4 [VERIFIED]).

### Non-Autoload Pure-Function Modules

Two modules sit alongside the rank table but are **not autoloaded**. They are **lazily** constructed inside `DungeonRunOrchestrator._ready()` via `.new()` (zero-arg on non-autoload RefCounted subclasses) IF the corresponding field (`_matchup_resolver`, `_combat_resolver`) is still null at `_ready()` time. Tests pre-inject spy subclasses via the Orchestrator's public setters `set_matchup_resolver(resolver)` + `set_combat_resolver(resolver)` BEFORE `_ready()` fires (typically via the `.new() + setters + add_child(orch)` sequence per `dungeon-run-orchestrator.md` §J.3 Mode 1). The null-checks in `_ready()` short-circuit when spies are already installed. Production boots "zero-config" with defaults; tests substitute spies without needing to forbid `add_child`. See ADR-0003 Amendment #3 + ADR-0009 for the full contract; `autoload.md` Claim 4 [VERIFIED] is the empirical evidence that rules out `_init(args)` constructor injection (mechanically impossible on Godot 4.6 autoload Nodes — `_init` is called with zero args by the autoload system).

| Module | Class | Source GDD | Injected into | Ownership contract |
|---|---|---|---|---|
| `MatchupResolver` | `class_name MatchupResolver extends RefCounted` (production: `DefaultMatchupResolver`) | `design/gdd/class-vs-enemy-matchup-resolver.md` | `DungeonRunOrchestrator.set_matchup_resolver(resolver)` pre-`_ready()` OR lazy-default in `_ready()` | Stateless: zero instance vars, zero signals, no caches, no RNG, no time reads. Pure function of `(formation, enemy_archetype)` → `MatchupResult`. |
| `CombatResolver` | `class_name CombatResolver extends RefCounted` (production: `DefaultCombatResolver`) | `design/gdd/combat-resolution.md` | `DungeonRunOrchestrator.set_combat_resolver(resolver)` pre-`_ready()` OR lazy-default in `_ready()` | Stateless: pure function of `(formation, floor, tick_range)` → `CombatTickEvents` / `CombatBatchResult`. |

**CI invariant**: neither file may declare class-scope `var`, signals, or static public `func`; neither may appear as `[autoload]` in `project.godot`. Grep enforces. (See `design/gdd/class-vs-enemy-matchup-resolver.md` TR-matchup-resolver-030 and `design/gdd/combat-resolution.md` TR-combat-001.)

**Rank-invariant impact**: none. These modules are not Nodes in the tree, do not participate in `_ready()` ordering, expose no signals, and do not read or write any autoload state. They are pure data transformations.

**Rank invariant** (per ADR-0003 Amendment #1, 2026-04-22): signal SUBSCRIPTION
across any rank pair at `_ready()` time is safe — signal objects exist on Node
instantiation, before any `_ready()` fires (autoload.md Claim 1 [VERIFIED]).
State READS at `_ready()` time are rank-constrained: a rank-N autoload may read
state set in a rank-M autoload's `_ready()` only if M < N. Same-rank state reads
at `_ready()` are forbidden (intra-rank order is implementation-defined); backward
state reads at `_ready()` are forbidden (the higher-rank autoload's `_ready()` has
not yet run). All cross-autoload calls AFTER all `_ready()` fires are
unrestricted. The Save/Load consumer table (`SaveLoadSystem.CONSUMER_PATHS`) is
hardcoded and must be edited in lockstep with this rank table.

### Save/Load Consumer Rank Table

`SaveLoadSystem` resolves these autoload paths via `get_node_or_null` at **each
serialization boundary** (per Save/Load §C.3, never cached):

```
1. /root/Economy
2. /root/HeroRoster
3. /root/FloorUnlock
4. /root/FormationAssignment
5. /root/Recruitment
6. /root/DungeonRunOrchestrator
```

`TickSystem` is a special bidirectional consumer: `SaveLoadSystem` writes
back `last_persist_unix_ts` + `t_session_high_water` on load (the only permitted
external write to Time). It is NOT in `CONSUMER_PATHS` — it is read+written via
named accessor methods.

`HeroClassDatabase`, `EnemyDatabase`, `BiomeDungeonDatabase`, and `DataRegistry`
are stateless content stores — they do not appear in the consumer table.

---

## Module Ownership Map

For each module: **Owns** (sole writer), **Exposes** (read API), **Consumes**
(read deps), **Engine APIs** (with risk flag).

### Foundation Layer

#### TickSystem (rank 0)

- **Owns**: Sim Clock tick counter; Wall Clock `last_persist_unix_ts`;
  `t_session_high_water`; `flag_suspicious_timestamp`; `TICKS_PER_SECOND` (20),
  `offline_cap_seconds` (28800), `REWIND_TOLERANCE_SECONDS` (300),
  `heartbeat_interval_seconds` (60).
- **Exposes**:
  - Signal `tick_fired(n: int)` — foreground only
  - `now_ms() -> int`, `current_tick() -> int`
  - `get_last_persist_ts() -> int64`, `get_session_high_water() -> int64`
  - `set_last_persist_ts(ts)`, `set_session_high_water(ts)` — restricted to SaveLoadSystem
  - One-shot signal pair `offline_elapsed_seconds(secs: float)` + `cap_reached(reached: bool)`
- **Consumes**: Engine APIs only.
- **Engine APIs**: `Time.get_unix_time_from_system()`,
  `NOTIFICATION_APPLICATION_PAUSED/RESUMED`, `Engine.physics_ticks_per_second`
  is NOT used (Sim Clock runs in `_process` gated by accumulator). LOW risk.

#### DataRegistry (rank 1)

- **Owns**: in-memory map `{content_type: {id: Resource}}`; load state machine
  `(BOOT → LOADING → READY → ERROR | HOT_RELOAD)`.
- **Exposes**:
  - Signal `registry_ready()`
  - `get_all_by_type(type: String) -> Array[Resource]`
  - `resolve(type: String, id: String) -> Resource` (returns null + WARN if missing in production)
  - `state` property
  - `hot_reload(content_type: String)` — dev builds only
- **Consumes**: Engine APIs only.
- **Engine APIs**: `ResourceLoader.load(path)`, `DirAccess.open()`,
  `ResourceLoader.get_recognized_extensions_for_type()`. LOW risk.

#### SaveLoadSystem (rank 2)

- **Owns**: save slot path (`user://save_slot_1.dat`), single `.bak` backup,
  HMAC key derivation, schema version int, in-flight save state.
- **Exposes**:
  - Signal `save_completed(success: bool, error: String)`
  - Signal `save_failed(reason: String)`
  - `request_persist(reason: String) -> void` — coalesced
  - `load_or_init() -> LoadResult` — called once at boot after `DataRegistry.registry_ready`
  - State enum: `IDLE | PERSISTING | LOADING | CORRUPT`
- **Consumes**:
  - `DataRegistry.resolve()` for hydration
  - `TickSystem.get_last_persist_ts()` / `set_last_persist_ts()`
  - `SceneManager.scene_boundary_persist` signal
  - All consumers in the rank table via `get_save_data()` / `load_save_data(data)`
- **Engine APIs**: `FileAccess.open()` + `store_buffer()` + `flush()`; rename via
  `DirAccess.rename()`; `Crypto.new().hmac_digest()`. `FileAccess.store_*`
  returns bool in 4.4+ (NEAR-CUTOFF) — code asserts truthy.

#### SceneManager (Node, not ranked)

- **Owns**: current scene reference, transition queue, screen stack.
- **Exposes**:
  - Signal `scene_boundary_persist(reason: String)` — fired before transitions that cross persistence boundaries (Dungeon Run View enter, Victory Moment exit)
  - `transition_to(scene_path: String, reason: String) -> void`
  - `push_screen(scene_path) / pop_screen()`
- **Consumes**: `SaveLoadSystem.save_completed` / `save_failed` for abortable transitions.
- **Engine APIs**: Persistent root scene composition (`MainRoot.tscn` with HUD/Screen/Transition/Overlay CanvasLayers); `ScreenContainer` node-swap pattern via `queue_free` + `call_deferred(_complete_swap)`; `Tween` for standard transitions; `AnimationPlayer` for Victory Ceremony only; `get_tree().paused` (counter-based wrapper) for modal pause. **Explicitly does NOT use `SceneTree.change_scene_to_packed()`** (see ADR-0007 §Decision for rationale). LOW risk for all listed APIs.

#### UIFramework (theme resource + helpers, not autoload)

- **Owns**: parchment theme `.tres`, tap-target enforcement helper, focus-visual style for the dual-focus 4.6 system.
- **Exposes**: `Theme` instance, helper functions (`assert_tap_target_min(control)`)
- **Engine APIs**: 4.6 Dual-focus (MEDIUM) — verify focus visuals don't fragment between mouse vs touch.

### Core Layer

#### Economy (rank 3)

- **Owns**: `gold: int`, `floor_clear_bonus_credited: Dictionary[int, int]`
  (monotonic ledger per ADR-0002), `recruit_cost_paid_this_session: int`
  (telemetry), recruitment cost curve constants.
- **Exposes**:
  - `add_gold(amount: int) -> void`
  - `try_spend(amount: int, reason: String) -> bool`
  - `try_award_floor_clear(floor_index: int, bonus_amount: int) -> bool` — credit-the-gap per ADR-0002
  - Signal `gold_changed(new_balance: int, delta: int, reason: String)`
  - `get_save_data() / load_save_data(data)`
- **Consumes**: `TickSystem.tick_fired` (for periodic loot drips).
- **Engine APIs**: None (pure GDScript).

#### HeroClassDatabase / EnemyDatabase / BiomeDungeonDatabase (ranks 4-6)

- **Owns**: typed lookup tables built from `DataRegistry.get_all_by_type(...)` at `registry_ready`.
- **Exposes**: `get_by_id(id) -> ClassResource | EnemyResource | etc.`, `get_all() -> Array[...]`.
- **Consumes**: `DataRegistry`.
- **Engine APIs**: None (operates on already-loaded resources).

#### AudioSystem (Core, minimal MVP)

- **Owns**: bus references, current music track, SFX pool.
- **Exposes**: `play_sfx(id: String)`, `play_music(id: String, fade_seconds: float)`.
- **Consumes**: `DataRegistry` for audio `.tres` references; `SceneManager` for context-aware mixing.
- **Engine APIs**: `AudioServer`, `AudioStreamPlayer`. LOW risk.

### Feature Layer

#### HeroRoster (rank 7)

- **Owns**: `Array[HeroInstance]` (mutable; never replaced — only mutated in place to preserve external refs).
- **Exposes**: `recruit(class_id) -> HeroInstance`, `remove(hero_id)`, signal `hero_recruited(hero)`, `hero_removed(hero_id)`, `roster_changed`.
- **Consumes**: `HeroClassDatabase.get_by_id()`, `Economy.try_spend()` (delegated to Recruitment).

#### MatchupResolver (NON-AUTOLOAD — historically rank 8; rank 8 now occupied by SceneManager per ADR-0003 Amendment #4 / story S5-M4)

- **Class**: `class_name MatchupResolver extends RefCounted` (production subclass: `DefaultMatchupResolver`). NOT autoloaded — lazily constructed inside `DungeonRunOrchestrator._ready()` via `DefaultMatchupResolver.new()` (zero-arg, non-autoload RefCounted) IF `_matchup_resolver` is still null at `_ready()` time. Tests pre-inject spy subclasses via `DungeonRunOrchestrator.set_matchup_resolver(spy)` BEFORE `_ready()` fires (per `dungeon-run-orchestrator.md` §J.3 Mode 1). See ADR-0003 Amendment #2 + #3, ADR-0009, `dungeon-run-orchestrator.md` §J.1 (locked Option A wiring), and `design/gdd/class-vs-enemy-matchup-resolver.md`.
- **Owns**: NOTHING. Stateless: zero class-scope vars, zero signals, no caches, no RNG, no time-dependent reads.
- **Exposes**: `resolve_formation_matchup(formation, enemy_archetype) -> MatchupResult`; `resolve_floor_matchup(formation, floor_archetypes) -> MatchupResult`. Both pure functions of inputs.
- **Consumes**: `DataRegistry.resolve("classes", id)` (read-only) when reading a hero's `class.counter_archetype`. No state held between calls.
- **Test pattern**: spy subclasses extend `MatchupResolver` and override public methods; injected via the same constructor.

#### CombatResolver (NON-AUTOLOAD — rank 9 vacant)

- **Class**: `class_name CombatResolver extends RefCounted` (production subclass: `DefaultCombatResolver`). NOT autoloaded — lazily constructed inside `DungeonRunOrchestrator._ready()` via `DefaultCombatResolver.new()` (zero-arg, non-autoload RefCounted) IF `_combat_resolver` is still null at `_ready()` time. Tests pre-inject spy subclasses via `DungeonRunOrchestrator.set_combat_resolver(spy)` BEFORE `_ready()` fires (per `dungeon-run-orchestrator.md` §J.3 Mode 1). See ADR-0003 Amendment #2 + #3, ADR-0010 (Accepted 2026-04-22c), `dungeon-run-orchestrator.md` §J.1 (locked Option A wiring), and `design/gdd/combat-resolution.md`.
- **Owns**: NOTHING. Stateless: no instance vars, no caches, no RNG, no time reads, no float accumulation across calls.
- **Exposes**: `emit_events_in_range(formation, floor, start_tick, end_tick) -> CombatTickEvents` (foreground); `compute_offline_batch(formation, floor, tick_budget) -> CombatBatchResult` (offline). Both share private helpers to guarantee foreground/offline parity.
- **Consumes**: the injected `MatchupResolver`. Reads no autoload state.
- **Test pattern**: spy subclasses extend `CombatResolver` and override public methods.

#### DungeonRunOrchestrator (rank 14)

- **Owns**: `RunSnapshot` (active run state), state machine `(NO_RUN | DISPATCHING | ACTIVE_FOREGROUND | ACTIVE_OFFLINE_REPLAY | RUN_ENDED)`, per-dispatch idempotency flag `floor_clear_emitted`, loop counter, `dispatched_at_tick`.
- **Exposes**:
  - Signal `floor_cleared_first_time(floor_index: int)` — listened to by FloorUnlockSystem (rank 10) — VERIFIED safe via autoload Claim 1
  - Signal `run_started(snapshot)`, `run_ended(snapshot, reason)`
  - `dispatch(formation, floor) -> void`
- **Consumes**:
  - `FormationAssignment.formation_reassignment_committed` (per ADR-0001 — ends run + restarts)
  - `Economy.try_award_floor_clear()`
  - `CombatResolution.simulate()`
  - `TickSystem.tick_fired` (foreground) + `OfflineProgressionEngine.batch_replay` (offline)

#### OfflineProgressionEngine (rank 15) ⚠️ HIGH RISK

- **Owns**: offline replay state (transient — exists only between session start and offline_summary_emitted).
- **Exposes**: signal `offline_rewards_collected(summary: OfflineSummary)`, signal `cap_reached(seconds_clipped: int)`.
- **Consumes**: `TickSystem.offline_elapsed_seconds`, `DungeonRunOrchestrator.compute_offline_batch(n)`, `Economy.compute_offline_batch(n)`.
- **Performance constraint**: AC-TICK-10 (blocking). At 20Hz × 8h cap = 576,000 ticks. Replay must complete under 500ms on min-spec mobile or chunk across frames.

#### FloorUnlockSystem (rank 10)

- **Owns**: `Set[String]` of unlocked floor IDs.
- **Exposes**: `is_unlocked(floor_id) -> bool`, signal `floor_unlocked(floor_id)`.
- **Consumes**: `DungeonRunOrchestrator.floor_cleared_first_time` (rank 14). Forward signal connect at `_ready()` — VERIFIED safe.
- **MVP runtime fallback**: `ProjectSettings.get_setting("floor_unlock/active_biome_mvp", "forest_reach")`. Designer-UI key registration deferred to V1.0 (Pass-8 pattern empirically falsified — see Open Question §OQ-1).

#### FormationAssignment (rank 11)

- **Owns**: `active_formation: Array[HeroInstance]`.
- **Exposes**:
  - Signal `formation_browse_opened` — read-intent only, NEVER triggers run-end
  - Signal `formation_reassignment_committed(new_formation)` — write-intent, triggers Orchestrator option (a) per ADR-0001
- **Consumes**: `HeroRoster`.

#### Recruitment (rank 12)

- **Owns**: recruit pool generator state, recruit pool refresh timer.
- **Exposes**: `try_recruit(pool_index: int) -> RecruitOutcome`, signal `hero_recruited`.
- **Consumes**: `Economy.try_spend()`, `HeroClassDatabase`, `HeroRoster.recruit()`.

#### HeroLeveling (rank 13)

- **Owns**: XP curve constants (data-driven from `.tres`).
- **Exposes**: `try_level_up(hero_id) -> LevelUpOutcome`, signal `hero_leveled(hero_id, new_level)`.
- **Consumes**: `Economy.try_spend()`, `HeroRoster`.

### Presentation Layer

Presentation modules are scenes (not autoloads). Each is a `Control` root that
binds to autoload signals at `_ready()` and disconnects at `_exit_tree()`.

| Screen | Subscribes To | Emits | Persistence |
|---|---|---|---|
| GuildHallScreen | `Economy.gold_changed`, `HeroRoster.roster_changed`, `FloorUnlockSystem.floor_unlocked` | UI button signals routed to autoloads | None |
| ReturnToAppScreen ⚠️ | `OfflineProgressionEngine.offline_rewards_collected` (at boot) | `rewards_acknowledged` (close screen) | None |
| RecruitScreen | `Recruitment.hero_recruited`, `Economy.gold_changed` | UI button signals → `Recruitment.try_recruit()` | None |
| RosterScreen | `HeroRoster.roster_changed`, `HeroLeveling.hero_leveled` | `level_up_requested` → `HeroLeveling.try_level_up()` | None |
| MatchupAssignmentScreen | `HeroRoster`, `BiomeDungeonDatabase`, `ClassEnemyMatchupResolver` | `formation_browse_opened` (on inspection), `formation_reassignment_committed` (on confirm tap) | None |
| DungeonRunView | `DungeonRunOrchestrator.run_started/run_ended`, `tick_fired` | `recall_requested` → Orchestrator | None |
| UnlockVictoryMoment | `FloorUnlockSystem.floor_unlocked` | `victory_dismissed` | None |

The Return-to-App Screen is the only Presentation module with hard timing
requirements: it MUST appear on boot if `offline_elapsed_seconds > 0` AND
before any other Guild Hall interaction.

---

## Data Flow

### Frame Update Path (foreground)

```
Engine SceneTree
   │
   │  _process(delta)
   ▼
TickSystem._process(delta)
   │
   │  accumulator += delta; while accumulator >= TICK_INTERVAL: accumulator -= TICK_INTERVAL; emit tick_fired(n+=1)
   ▼
tick_fired(n) ──▶ Economy._on_tick (if active orchestrator) ──▶ gold_changed(delta)
              ──▶ DungeonRunOrchestrator._on_tick ──▶ CombatResolution.simulate(snapshot, floor)
                                                  ──▶ Economy.try_award_floor_clear() (on first-clear)
                                                  ──▶ floor_cleared_first_time(idx) ──▶ FloorUnlockSystem._on_floor_cleared
              ──▶ DungeonRunView._on_tick ──▶ visual update
   │
   ▼
Frame end (no extra coupling)
```

`_process(delta)` flows ONLY through `TickSystem`. No other module reads
`delta` for math. Visual interpolation may read `delta` for animation only.

### Offline Replay Path (session start)

```
App resumes / launches
   │
   ▼
TickSystem._notification(NOTIFICATION_APPLICATION_RESUMED) — or boot
   │
   │  computes offline_elapsed_seconds = clamp(now - last_persist_ts, 0, offline_cap_seconds)
   ▼
emit offline_elapsed_seconds(secs) + cap_reached(reached)
   │
   ▼
OfflineProgressionEngine._on_offline_elapsed ──▶ ticks_to_replay = secs * TICKS_PER_SECOND
   │
   │  for chunk in chunks(ticks_to_replay, max_per_frame):
   │      DungeonRunOrchestrator.compute_offline_batch(chunk)
   │      Economy.compute_offline_batch(chunk)
   ▼
emit offline_rewards_collected(summary)
   │
   ▼
SceneManager.transition_to(ReturnToAppScreen)
```

Offline replay must yield to the main thread between chunks (use `await
get_tree().process_frame`) to avoid hitches longer than 100ms. AC-TICK-10
verifies the full 576,000-tick worst case lands within 500ms total wall time.

### Save/Load Persist Path

```
SceneManager.transition_to(some_screen, "boundary")
   │
   ▼
emit scene_boundary_persist(reason="enter_dungeon_view")
   │
   ▼
SaveLoadSystem._on_scene_boundary_persist ──▶ request_persist(reason)
   │
   │  state = PERSISTING
   │  for path in CONSUMER_PATHS:
   │      node = get_node_or_null(path)            # NEVER cached
   │      assert(node and node.has_method("get_save_data"))
   │      out[snake(path.get_file())] = node.get_save_data()
   │  out["time"] = { last_persist_unix_ts, t_session_high_water }
   │  out["schema_version"] = N
   │  bytes = serialize(out)
   │  hmac  = HMAC-SHA256(bytes, derived_key)
   │  envelope = magic + version + bytes + hmac
   │  write to user://save_slot_1.dat.tmp ; flush ; rename → user://save_slot_1.dat
   │  copy previous .dat → .bak
   ▼
emit save_completed(true) → SceneManager allows transition
```

If any step fails: emit `save_failed(reason)`, refuse the transition, stay in
the current scene with a non-blocking toast. Transitions that cross persistence
boundaries are gated on `save_completed`.

### Save/Load Hydrate Path (boot)

```
boot
   │
   ▼
DataRegistry._ready ──▶ scan assets/data/ ──▶ emit registry_ready
   │
   ▼
SaveLoadSystem._on_registry_ready ──▶ load_or_init()
   │
   │  read user://save_slot_1.dat
   │  verify HMAC; if fail → try .bak; if both fail → CORRUPT
   │  parse envelope; check schema_version
   │  for path in CONSUMER_PATHS:
   │      node = get_node_or_null(path)
   │      node.load_save_data(data[snake(path.get_file())])
   │  TickSystem.set_last_persist_ts(data.time.last_persist_unix_ts)
   │  TickSystem.set_session_high_water(data.time.t_session_high_water)
   ▼
emit load_completed(LoadResult.{LOADED|FRESH|CORRUPT|MIGRATED})
   │
   ▼
TickSystem computes offline_elapsed_seconds (see Offline Replay Path)
```

### Initialization Order (boot)

```
1. Engine bootstraps autoloads in rank order (rank 0 → 15)
2. Each autoload's _ready() fires in rank order; rank-N may connect to rank-(N+1)+ signals safely
3. DataRegistry runs its scan; emits registry_ready when complete
4. SaveLoadSystem._on_registry_ready → load_or_init() → consumers populated
5. TickSystem computes offline delta → emits offline_elapsed_seconds
6. OfflineProgressionEngine drains the delta in batches
7. SceneManager.transition_to(ReturnToAppScreen) if rewards exist; else GuildHallScreen
```

### Cross-Thread Boundaries

**There are none in MVP.** All systems run on the main thread. Save serialization
happens on the main thread (HMAC + JSON for ~50KB of state is sub-frame at
worst). If profiling shows persist hitches, move HMAC + write to a `WorkerThreadPool`
task as a future ADR — for now, single-threaded is the rule.

---

## API Boundaries

Public contracts between modules. These are the surfaces that programmers
implement against; nothing else is callable across the autoload boundary.

### TickSystem

```gdscript
# READ
func now_ms() -> int
func current_tick() -> int
func get_last_persist_ts() -> int            # int64 in practice
func get_session_high_water() -> int

# WRITE — restricted to SaveLoadSystem (enforced by convention + assert in dev)
func set_last_persist_ts(ts: int) -> void
func set_session_high_water(ts: int) -> void

# SIGNAL
signal tick_fired(n: int)
signal offline_elapsed_seconds(secs: float)
signal cap_reached(reached: bool)
signal flag_suspicious_timestamp(reason: String)
```

### DataRegistry

```gdscript
func get_all_by_type(content_type: String) -> Array[Resource]
func resolve(content_type: String, id: String) -> Resource    # returns null + WARN on miss in production

signal registry_ready
```

### SaveLoadSystem

```gdscript
const CONSUMER_PATHS: PackedStringArray = [
    "/root/Economy", "/root/HeroRoster", "/root/FloorUnlock",
    "/root/FormationAssignment", "/root/Recruitment", "/root/DungeonRunOrchestrator",
]

func request_persist(reason: String) -> void              # coalesced; emits save_completed/save_failed
func load_or_init() -> LoadResult                          # called once at boot

signal save_completed(success: bool, error: String)
signal save_failed(reason: String)
signal load_completed(result: LoadResult)
```

### Consumer contract (Economy, HeroRoster, FloorUnlockSystem, FormationAssignment, Recruitment, DungeonRunOrchestrator)

```gdscript
# Every consumer MUST implement these two methods exactly.
func get_save_data() -> Dictionary           # JSON-safe; no Object refs; ints + floats + strings + nested dicts/arrays only
func load_save_data(data: Dictionary) -> void # idempotent; restores full state from a get_save_data() result
```

### Economy

```gdscript
func add_gold(amount: int) -> void
func try_spend(amount: int, reason: String) -> bool
func try_award_floor_clear(floor_index: int, bonus_amount: int) -> bool   # ADR-0002 monotonic-credit semantics

signal gold_changed(new_balance: int, delta: int, reason: String)
```

### CombatResolver (non-autoload, DI-injected)

```gdscript
# class_name CombatResolver extends RefCounted (production: DefaultCombatResolver)
# Lazily constructed inside DungeonRunOrchestrator._ready() via DefaultCombatResolver.new()
# IF _combat_resolver is still null at _ready() time; tests pre-inject spies via
# DungeonRunOrchestrator.set_combat_resolver(spy) BEFORE _ready() fires.
# Two public entry points share the same private helpers for foreground/offline parity.
# See ADR-0003 Amendment #3 + ADR-0010 (Accepted 2026-04-22c); dungeon-run-orchestrator.md §J.1 is the locked source.

func emit_events_in_range(formation: FormationSnapshot, floor: FloorSnapshot, start_tick: int, end_tick: int) -> CombatTickEvents
func compute_offline_batch(formation: FormationSnapshot, floor: FloorSnapshot, tick_budget: int) -> CombatBatchResult
```

### MatchupResolver (non-autoload, DI-injected)

```gdscript
# class_name MatchupResolver extends RefCounted (production: DefaultMatchupResolver)
# Lazily constructed inside DungeonRunOrchestrator._ready() via DefaultMatchupResolver.new()
# IF _matchup_resolver is still null at _ready() time; tests pre-inject spies via
# DungeonRunOrchestrator.set_matchup_resolver(spy) BEFORE _ready() fires.
# See ADR-0003 Amendment #3 + ADR-0009 (Accepted 2026-04-22); dungeon-run-orchestrator.md §J.1 is the locked source.

func resolve_formation_matchup(formation: FormationSnapshot, enemy_archetype: String) -> MatchupResult
func resolve_floor_matchup(formation: FormationSnapshot, floor_archetypes: Array[String]) -> MatchupResult
```

### DungeonRunOrchestrator

```gdscript
func dispatch(formation: Array[HeroInstance], floor: FloorResource) -> void
func recall() -> void
func compute_offline_batch(tick_count: int) -> void

signal run_started(snapshot: RunSnapshot)
signal run_ended(snapshot: RunSnapshot, reason: String)
signal floor_cleared_first_time(floor_index: int)
```

### FormationAssignment

```gdscript
func browse(formation: Array[HeroInstance]) -> void       # emits formation_browse_opened — NEVER triggers run-end
func commit(new_formation: Array[HeroInstance]) -> void   # emits formation_reassignment_committed — triggers ADR-0001 path

signal formation_browse_opened(formation: Array[HeroInstance])
signal formation_reassignment_committed(new_formation: Array[HeroInstance])
```

### SceneManager

```gdscript
func transition_to(scene_path: String, reason: String) -> void
func push_screen(scene_path: String) -> void
func pop_screen() -> void

signal scene_boundary_persist(reason: String)
signal scene_changed(from_path: String, to_path: String)
```

---

## ADR Audit

### Quality check

| ADR | Engine Compat | Version | GDD Linkage | Conflicts | Valid |
|-----|---------------|---------|-------------|-----------|-------|
| ADR-0001 (Mid-Run Reassignment Option a) | ✅ | 4.6 | ✅ Orchestrator §C.7, §H AC-ORC-06; Combat §I.Q7 | None — matches FormationAssignment + Orchestrator design above | ✅ |
| ADR-0002 (LOSING-clear monotonic credit) | ✅ | 4.6 | ✅ Orchestrator §C.6, §E.5, §H AC-ORC-04; Economy §C.2.3, AC H-03/H-14 | None — Economy `floor_clear_bonus_credited: Dictionary[int,int]` field reflected in API Boundaries above | ✅ |

Both ADRs pass the quality bar: they declare engine compatibility (LOW risk),
identify post-cutoff API usage (none), link to GDD requirements, and define
state transitions consistent with the autoload rank table.

### Traceability coverage check

The TR registry (`docs/architecture/tr-registry.yaml`) is empty (`requirements: []`).
The two existing ADRs reference GDD requirements directly (in their "GDD
Requirements Addressed" sections) but no TR-IDs have been minted yet.

**Action**: `/architecture-review` must populate the TR registry by extracting
requirements from all 13 GDDs and assigning stable IDs. Until then, story
authoring (`/create-stories`) cannot embed traceability metadata, and `/create-epics`
will report 100% untraced requirements.

This is the primary blocking gap before story implementation can begin.

---

## Required ADRs

The decisions below are **made implicitly in this document** but lack a written
ADR. They must be authored before stories that depend on them can be implemented.
Grouped by priority. Each entry names the system(s) blocked, suggested ADR
title, and what the ADR must decide.

### Foundation Layer (must exist before any coding starts)

| ADR | Title | Decides | Blocks |
|---|---|---|---|
| ADR-F01 | Autoload rank table is the single source of truth for module init order | Rank table is canonical; `SaveLoadSystem.CONSUMER_PATHS` is hardcoded against it; rank invariant (N may only forward-connect to N+1+) is enforced by code review | All Foundation/Core/Feature stories |
| ADR-F02 | Save envelope format and HMAC scheme | Magic header bytes, version byte, payload encoding (JSON vs MessagePack vs Godot's `bytes_to_var`), HMAC key derivation (PBKDF2 from device fingerprint? hard-coded with obfuscation?), schema_version bump policy | Save/Load implementation |
| ADR-F03 | Time System dual-clock contract (Sim vs Wall) | Tick accumulator implementation (`_process` vs `_physics_process`), foreground-only tick guarantee, `flag_suspicious_timestamp` thresholds, what counts as a "session boundary" | All systems that consume tick or persist timestamps |
| ADR-F04 | Data Loading boot scan strategy | Eager-load (current GDD direction) vs lazy-load + boot manifest; how `assets/data/` is partitioned by content_type; hot-reload behavior in dev builds | DataRegistry implementation |
| ADR-F05 | Scene transition + persist coupling | Which scene transitions emit `scene_boundary_persist`; what happens if persist fails mid-transition (block transition vs allow with toast); whether persist is sync or async | SceneManager + SaveLoadSystem |
| ADR-F06 | UI Framework: dual-focus parity | How mouse-focus + touch-focus + keyboard-focus visuals coexist (per Godot 4.6 dual-focus system); tap target enforcement strategy; theme scaling for Steam Deck 1280×800 | All Presentation modules |

### Core Layer (must exist before Feature work begins)

| ADR | Title | Decides | Blocks |
|---|---|---|---|
| ADR-C01 → **ADR-0013 (Accepted 2026-04-22)** | Economy state shape + public API + cost curves + offline batch contract (authored + promoted same-session per `/architecture-decision` flow) | `class_name Economy extends Node` autoload rank 3 with zero-arg `_init`; 3 persisted state fields (`_gold_balance: int` int64 + 1 T sanity cap, `_lifetime_gold_earned: int` unbounded statistic, `_floor_clear_bonus_credited: Dictionary[int, int]` ADR-0002 monotonic ledger) + 1 transient `_is_offline_replay` flag; 7-method public API (`add_gold(amount, reason)`, `try_spend(amount, reason) -> bool`, `try_award_floor_clear(floor_index, bonus_amount) -> bool`, `recruit_cost(class_id: String, copies_owned: int) -> int` — caller passes class_id string, Economy resolves tier internally via DataRegistry, `level_cost(class_tier, current_level) -> int` — returns -1 past LEVEL_CAP, `compute_offline_batch(tick_budget) -> OfflineResult`, `get_save_data` / `load_save_data`); 2 typed signals (`gold_changed(new_balance, delta, reason)` 3-arg, `first_clear_awarded(floor_index)` at-most-once-per-floor-per-save); all 26 tuning knobs live in `assets/data/config/economy_config.tres` (EconomyConfig extends GameData per ADR-0011 pattern); closed-form offline drip (O(1) multiply) + batch-event iteration + signal suppression during replay + aggregate emit after (AC H-10 500ms budget compliance); 4 new CI-enforced forbidden patterns (`hardcoded_balance_value_outside_economy_config`, `economy_reads_losing_run_state`, `economy_signal_emission_during_offline_replay`, `try_spend_with_non_positive_amount`); `OfflineResult extends RefCounted` inline class (Specialist NOTE #9 fold prevents memory leak); Orchestrator-applies-LOSING_RUN_LOOT_FACTOR directional invariant codified | Economy implementation (unblocked); future Recruitment ADR (`recruit_cost` + `try_spend` signatures locked); future Hero Leveling ADR (`level_cost` -1 cap-sentinel locked); ADR-X02 Offline snapshot (`compute_offline_batch` + `OfflineResult` shape locked); TR-biome-dungeon-db-017 BASE_DRIP[floor_index] lookup path (unblocked); Return-to-App Screen / Guild Hall / Recruit / Roster / Formation screens (gold_changed 3-arg signal consumer pattern locked) |
| ADR-C02 → **ADR-0011 (Accepted 2026-04-22d)** | Resource Schemas for HeroClass / EnemyData / Biome / Dungeon / Floor `.tres` files (authored 2026-04-22 Proposed; promoted to Accepted in the 2026-04-22d review follow-up) | Five `GameData` subclass schemas (14 + 11 + 5 + 2 + 5 `@export` fields across HeroClass / EnemyData / Biome / Dungeon / Floor; inherited `id: String` + `display_name: String` from ADR-0006 base not redeclared); two canonical constant modules (`EnemyArchetypes` 6 strings with `MVP_SET` / `ALL_SET` + `is_valid` / `is_mvp` helpers; `ClassRoles` 6 strings with `ALL_SET` + `is_valid` helper; both `class_name X extends RefCounted` per godot-gdscript-specialist LOAD-BEARING NOTE #5); universal + per-type + cross-type validator tables with explicit failure actions (`ERROR` state vs `push_warning`); `Floor.enemy_list: Array[Dictionary]` of `{enemy_id: String, count: int}` id-string contract (NOT inline `Array[EnemyData]` — hot-reload + save-file stability rationale); three cross-type invariants (archetype distribution F1-F3 cover 3 MVP archetypes, boss-floor uniqueness within Dungeon, tier-1 counter_archetype ∈ MVP_SET); ADR-0010 `Floor` opaque type fully locked; archetype constant set is single-source-of-truth for `HeroClass.counter_archetype` ↔ `EnemyData.archetype` ↔ `MatchupResult.matched_archetypes` (ADR-0009 `referenced_by` bumped) | Hero Class DB implementation (unblocked); Enemy DB implementation (unblocked); Biome & Dungeon DB implementation (unblocked); ADR-X02 offline snapshot `Floor` freeze target (unblocked); content-authoring stories for `.tres` files |
| ADR-C03 | Audio system minimal MVP scope | Bus layout (Master/SFX/Music/UI); audio resource naming; mixing strategy (no ducking? simple ducking?) | AudioSystem implementation |
| ADR-C04 → **ADR-0009 (Accepted 2026-04-22)** | Matchup Resolver DI + majority threshold contract (surfaced by `/architecture-review` 2026-04-22; authored same day as ADR-0009; promoted to Accepted in the 2026-04-22b review follow-up) | Non-autoload `RefCounted` pattern + setter-based DI contract (`DungeonRunOrchestrator.set_matchup_resolver` + `set_combat_resolver` + lazy-default `_ready()`); `MatchupResult` value-type schema; majority threshold rule (`n > N/2`); deduplication + alphabetical sort of `matched_archetypes`; spy-subclass test pattern; offline-replay zero-call invariant | Combat implementation (ADR-X01); Orchestrator dispatch path; offline-replay determinism |

### Feature Layer (must exist before the relevant feature is built)

| ADR | Title | Decides | Blocks |
|---|---|---|---|
| ADR-X01 → **ADR-0010 (Accepted 2026-04-22c)** | Combat Resolver — Snapshot Shape + Foreground/Offline Parity Invariants (authored 2026-04-22 Proposed; promoted to Accepted in the 2026-04-22c review follow-up) | Five RefCounted value types (`KillEvent`, `CombatTickEvents`, `CombatBatchResult`, `CombatRunSnapshot`; `MatchupResult` consumed from ADR-0009); two public entry points share private helpers (`_formation_dps_approx`, `_ticks_per_loop`, `_kill_schedule_for_loop`) — foreground/offline parity is structural, not aspirational; dict-equality-by-key-walk (hash-based equality forbidden); foreground-per-event vs offline-aggregate-only asymmetry; `error_logger: Callable` per-call DI (AC-COMBAT-11); statelessness + no-autoload CI invariants | Combat Resolution implementation (unblocked); Orchestrator dispatch path; AC-COMBAT-01/10/14/17 determinism gates |
| ADR-X02 → **ADR-0014 (Accepted 2026-04-22)** | Offline Progression Engine batch chunking strategy + RunSnapshot schema (authored + promoted same-session per `/architecture-decision` flow, matching ADR-0012/0013 pattern) | `class_name OfflineProgressionEngine extends Node` autoload rank 15 with zero-arg `_init`; adaptive time-budgeted chunking (`OFFLINE_CHUNK_TARGET_WALL_MS = 12`, initial 5000 ticks, min 500, max 50000, deadband ±25%, adjust ratio 0.6); `await get_tree().process_frame` main-thread yield between chunks (WorkerThreadPool explicitly rejected for MVP — new forbidden pattern `worker_thread_pool_for_offline_replay_in_mvp`); `RunSnapshot extends RefCounted` in `src/core/run_snapshot.gd` standalone file (11 primitive fields + `formation_ids: Array[int]` size 3 + `matched_archetypes: Array[String]` per ADR-0009 freeze); Orchestrator persists RunSnapshot via ADR-0004 consumer contract; orphan-hero recovery path (`run_snapshot_discarded_orphan` signal + Economy refund); HeroInstance **allowlist exception** to ADR-0012 `caching_heroinstance_reference_across_save_boundary` forbidden pattern — lifetime-scoped to post-hydrate replay cycle, 3 allowlisted consumer call sites (CombatResolver.compute_offline_batch + emit_events_in_range + MatchupResolver.resolve); 3 CI grep invariants enforce the allowlist; OQ-4 resolved via time-gated cozy modal (`PROGRESS_MODAL_THRESHOLD_MS = 100`, silent below / modal above, cozy tone-of-voice variants); signal emission policy: `tick_fired` never during replay (ADR-0005), `gold_changed` / `first_clear_awarded` / `floor_cleared_first_time` all suppressed per-chunk + single aggregate post-replay, `offline_rewards_collected(summary)` emitted last before SceneManager transition; 5 new CI-enforced forbidden patterns (`offline_replay_progressed_domain_subscriber`, `heroinstance_cache_outside_runsnapshot_allowlist`, `offline_summary_field_set_expansion_without_version_bump`, `per_chunk_domain_signal_emission_during_offline_replay`, `worker_thread_pool_for_offline_replay_in_mvp`); 2 new performance budgets (offline_chunk_cpu_wall_time BLOCKING ≤16ms/chunk min-spec mobile; offline_replay_total_wall_clock ADVISORY ≤5s for 8h cap ANR headroom) | Offline Progression Engine implementation (unblocked); Orchestrator mid-run persist story (unblocked); ReturnToAppScreen + OfflineSummary UI consumer (unblocked); AC-TICK-10 verification path (chunking makes it achievable); Save schema v1 freeze (RunSnapshot keys locked); `/create-control-manifest` + `/gate-check pre-production` (final architectural ADR before PASS candidate) |
| ADR-X03 → **ADR-0012 (Accepted 2026-04-22)** | Hero Roster Mutation API + HeroInstance Identity Stability (authored + promoted same-session per `/architecture-decision` flow) | `class_name HeroInstance extends RefCounted` pure data record with 5-field locked schema + factory construction pattern (`HeroInstance.create()` / `from_dict()`); `class_name HeroRoster extends Node` autoload rank 7 with zero-arg `_init`; 4-method mutation API (add_hero / remove_hero / set_hero_level / set_formation_slot) with sole-caller contracts; 16-method read API including `get_formation_strength() -> float` range [1.0, 3.0] (Economy contract locked); 3 typed signals (hero_recruited / hero_leveled / hero_removed) with boot-validation suppression; `_heroes: Dictionary[int, HeroInstance]` + `_formation_slots: Array[int]` size 3 with `0` sentinel + monotonic `_next_instance_id` (never reused); 4-step boot validation order (orphan drop → slot clear → cap trim → next_id repair); cross-save stability invariant (`caching_heroinstance_reference_across_save_boundary` forbidden pattern — consumers reference by instance_id not by HeroInstance ref); `seed_first_launch_state()` Roster-owned tutorial Warrior seeding (Onboarding does NOT inject) | Hero Roster implementation (unblocked); Presentation screens (RosterScreen/RecruitScreen/FormationAssignmentScreen) via signal-subscribe + re-resolve-by-id pattern (unblocked); future ADR-C01 Economy (`get_formation_strength` consumer signature locked); future Recruitment / Hero Leveling / Formation Assignment ADRs (mutation API locked) |
| ADR-X04 | Recruitment pool generation determinism | Whether recruit pool is RNG-seeded from save state (replayable) or session-only; refresh cadence; cost curve | Recruitment implementation |
| ADR-X05 | Floor Unlock designer-UI ProjectSettings pattern | DEFERRED to V1.0 — Pass-8 pattern empirically falsified. MVP uses `get_setting(key, default)` runtime fallback. ADR records the deferral and the three candidate correct patterns (`@tool`, EditorPlugin, hybrid) for V1.0 multi-biome work. | Floor Unlock V1.0 multi-biome authoring (NOT MVP) |

### Can defer to implementation

| ADR | Title | Why deferred |
|---|---|---|
| ADR-D01 | HD-2D rendering pipeline | Vertical Slice tier; not MVP |
| ADR-D02 | VFX system specifics | Vertical Slice tier; not MVP |
| ADR-D03 | Settings + Accessibility persistence | Polish tier; depends on UI Framework maturity |
| ADR-D04 | Localization architecture | Not in MVP scope |
| ADR-D05 | Mobile-port-specific input adaptations | Post-launch tier; design must accommodate but no separate ADR yet |

**Total Required ADRs for MVP** (post `/architecture-review` 2026-04-22e + ADR-0013 landing): 6 Foundation (ALL ACCEPTED as ADR-0003 through ADR-0008) + 4 Core (C01, C02, C03, C04) + 4 Feature (X01, X02, X03, X04 — X05 deferred V1.0) = **14 ADRs**.

Plus the 2 originally-Accepted ADRs (0001, 0002) = **16 ADRs minimum**. Of those, **14 are Accepted** (0001, 0002, 0003-0008, 0009, 0010, 0011, 0012, 0013, 0014 — where ADR-0009 = Required slot C04 "Matchup Resolver DI", ADR-0010 = Required slot X01 "Combat Resolver snapshot + parity", ADR-0011 = Required slot C02 "Core Resource Schemas", ADR-0012 = Required slot X03 "Hero Roster Mutation + HeroInstance Identity", ADR-0013 = Required slot C01 "Economy State + Cost Curves + Offline Batch Contract", ADR-0014 = Required slot X02 "Offline Replay Batch Chunking + RunSnapshot Schema") and **2 remain to author** (C03, X04). The 6 Foundation ADRs are complete; Core Phase-1 (C04) + Core Phase-2 (C02) + Core Phase-3 (C01) + Feature Phase-1 (X01) + Feature Phase-2 (X03) + Feature Phase-3 (X02) are all landed. **All architectural gaps for MVP are now closed** — ADR-C03 (Audio) + ADR-X04 (Recruitment) remain blocked on their GDDs being authored (GDD gaps, not architectural gaps). ADR-X05 (Floor Unlock designer-UI) deferred V1.0. Coverage post-ADR-0014 Accept: projected ~92%+ (~395/425) — **clear PASS-verdict candidate** pending `/architecture-review` re-run confirmation in a fresh session. Next PASS-verdict confirmation unblocks `/create-control-manifest` → `/gate-check pre-production` → `/create-epics layer: foundation` → `/create-stories` → `/sprint-plan`.

> **Update 2026-05-08**: ADR count is now **17 total** (this paragraph above tracks the 16-ADR snapshot from 2026-04-22e). Three ADRs added since: ADR-0015 (Recruitment Pool Determinism + Refresh — was the X04 slot, now Accepted), ADR-0016 (Audio Asset Sourcing Silent-MVP — closed the C03 audio-sourcing decision via defensible-default; commit `7cad317` 2026-05-07), ADR-0017 (HD-2D Shader Pass Deferred to Vertical Slice — Accepted 2026-05-07 per user creative-direction authorization). All 17 are Accepted; the C03 + X04 "remain to author" notes above are superseded.

---

## Open Questions

Decisions deferred — must be resolved before the relevant layer is built.

- **OQ-1 (Floor Unlock designer-UI)**: Pass-8 ProjectSettings pattern empirically
  falsified 2026-04-21. MVP uses runtime fallback. V1.0 multi-biome authoring
  needs one of three candidate patterns verified via `@tool`/EditorPlugin probe.
  Tracked as ADR-X05 (deferred).

- ~~**OQ-2 (Save HMAC key derivation)**: Where does the HMAC key come from? Three
  options: (a) hardcoded constant with light obfuscation (simplest, weakest);
  (b) derived from a stable device id (per-machine, cleanest UX); (c) derived
  from save filename + a hardcoded salt (no per-machine state, decent obfuscation).
  Decision is part of ADR-F02.~~ **CLOSED 2026-04-22 by ADR-0004.** Adopts option
  (d) — multi-part assembly across non-SaveLoad autoloads + N=2 build-version
  rotation, strictly stronger than (a)/(b)/(c) per the Save/Load GDD's
  Pass-5B-remainder analysis. See ADR-0004 §HMAC key derivation.

- ~~**OQ-3 (Persist failure UX)**: When `save_failed` fires, do we (a) refuse the
  transition + show a toast, (b) refuse the transition + show a modal, or (c)
  allow the transition + show a persistent banner until next successful save?
  Decision is part of ADR-F05.~~ **CLOSED 2026-04-22 by ADR-0007.** Adopts
  option (b) — refuse + cozy modal with "Try Again / Stay Here" agency.
  Matches Save/Load anti-tamper posture (don't proceed on corrupted state)
  and preserves Pillar 3 (cozy framing in modal copy). See ADR-0007
  §Persist-failure UX.

- ~~**OQ-4 (Offline replay perceived progress)**: Should the player see a progress
  bar during long offline replays (>100ms total)? Or just a static "calculating"
  card? Or instant black-out + reveal? Decision is part of ADR-X02 and feeds
  Return-to-App Screen UX.~~ **CLOSED 2026-04-22 by ADR-0014 §5.** Adopts
  time-gated cozy modal: silent for replays <100ms estimated (PROGRESS_MODAL_THRESHOLD_MS),
  cozy modal ≥100ms with indeterminate spinner + cozy tone-of-voice variants
  ("Stitching your lantern lamp back on…"); dismisses on `offline_rewards_collected`
  emission. Determinate progress bar rejected (non-linear with adaptive chunking).
  Instant black-out rejected (perceived-freeze hazard on slow hardware).

- **OQ-5 (Steam Deck testing access)**: All UI work assumes Steam Deck 1280×800
  is a first-class target, but no test hardware is available in the dev loop yet.
  Mitigation: enforce Steam Deck resolution in editor preview + a regression
  screenshot test under that resolution. Tracked as a production risk in
  `production/session-state/active.md`. **PARTIAL CLOSURE 2026-04-22 by ADR-0008**:
  rendering strategy now codified (`canvas_items` stretch + `keep` aspect; horizontal
  letterbox on Steam Deck; 44-logical-px tap-target floor renders at 33 actual px on
  Steam Deck touchscreen — accepted per trackpad-primary input). Hardware testing
  still required to validate; Steam Deck per-platform tap-target override deferred to
  V1.0 (ADR-0008 OQ-10).

---

## Next Steps

1. **Author ADR-F01 through ADR-F06** in order — Foundation layer cannot start
   coding without these. Use `/architecture-decision` per ADR.
2. **Run `/architecture-review`** after the Foundation ADRs land — this populates
   `tr-registry.yaml` with TR-IDs extracted from all GDDs, enabling story
   traceability.
3. **Run `/create-control-manifest`** once all Foundation + Core ADRs are
   Accepted — produces the flat per-layer rules sheet that stories reference.
4. **Run `/gate-check pre-production`** — validates that the Foundation+Core
   architecture is implementation-ready.
5. **Run `/create-epics layer: foundation`** — re-attempt with full prerequisites
   met. Then `/create-stories` per epic. Then `/sprint-plan`.

---

## Cross-References

- `design/gdd/systems-index.md` — full system enumeration + dependency map
- `design/gdd/game-concept.md` — pillars + scope tiers
- `docs/engine-reference/godot/VERSION.md` — pinned engine version + risk levels
- `docs/engine-reference/godot/modules/autoload.md` — VERIFIED autoload behavior probe
- `docs/architecture/ADR-0001-mid-run-formation-reassignment.md`
- `docs/architecture/ADR-0002-losing-first-clear-reclaimable-on-win.md`
- `.claude/docs/technical-preferences.md` — naming, performance budgets, allowed libraries
- `.claude/docs/coding-standards.md` — code-level standards, testing rules
