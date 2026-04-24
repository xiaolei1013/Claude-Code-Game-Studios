# ADR-0013: Economy Autoload — State, Public API, Cost Curves, Offline Batch Contract

## Status

Accepted (promoted Proposed → Accepted 2026-04-22 as the same-session follow-up to `/architecture-decision` Step 4.5 APPROVE-WITH-NOTES; both LOAD-BEARING specialist notes folded in-place — NOTE #8 CI-scope clarification + NOTE #9 `class OfflineResult extends RefCounted`; 5 ADR dependencies all Accepted; registry lockstep applied in the same session — 7 new interfaces + 5 api_decisions + 4 forbidden_patterns + 1 performance_budget + 5 referenced_by bumps on ADR-0004/0005/0006/0011/0012; GDD sync applied in the same session — `economy-system.md` Pass-ADR-0013-SYNC closes 4 signature drift items (3 pre-existing vs architecture.md, 1 new from ADR-0013's class-id-keyed `recruit_cost`). Authored 2026-04-22 to cover the top unwritten Required ADR flagged by `/architecture-review 2026-04-22e` as "ADR-C01: Economy state + recruit cost curve + drip ticker"; unblocks Economy system + ~20 TRs in the TR-economy gap pool + TR-biome-dungeon-db-017 (BASE_DRIP[floor_index] lookup); anchor for the forthcoming Recruitment ADR + Hero Leveling ADR + ADR-X02 (Offline snapshot). Projected coverage post-Accept: ~87% (PASS-verdict candidate).)

## Date

2026-04-22

## Last Verified

2026-04-22

## Decision Makers

- Author (user) — final decision
- godot-gdscript-specialist — Step 4.5 engine pattern validation (see §Specialist Review below)
- technical-director — SKIPPED (review-mode.txt = solo; gate TD-ADR not invoked per `.claude/docs/director-gates.md` §TD-ADR)

## Summary

Codifies the `Economy` autoload's state shape, public API surface, drip/kill/floor-clear credit paths, geometric cost curves for recruitment + level-up, and the offline replay batch contract at ADR level. Ratifies `design/gdd/economy-system.md` §C / §D / §E / §F / §G / §H verbatim and locks: (a) `gold_balance: int64` single-currency storage with 1 T sanity cap; (b) `floor_clear_bonus_credited: Dictionary[int, int]` monotonic-ceiling ledger (ADR-0002 semantic); (c) `add_gold` / `try_spend` / `try_award_floor_clear` / `compute_offline_batch` / `recruit_cost` / `level_cost` public API signatures; (d) the constants-from-`economy_config.tres` rule (no hardcoded balance values in `.gd`); (e) the offline replay closed-form drip + batch-event path with signal suppression and seeded RNG; (f) the "Orchestrator applies `LOSING_RUN_LOOT_FACTOR` before calling Economy" directional invariant — Economy never reads `losing_run` state.

Consumes `tick_fired` from TickSystem (ADR-0005); inherits autoload rank 3 from ADR-0003; inherits save/load consumer contract from ADR-0004; inherits `economy_config.tres` loading from ADR-0006; inherits `HeroClass.tier: int` input from ADR-0011; inherits `HeroRoster.get_formation_strength()` + `get_copies_owned(class_id)` consumer reads from ADR-0012; refines `floor_clear_bonus_credited` ledger semantics per ADR-0002. Elevates four previously-implicit rules to CI-enforced forbidden patterns: `hardcoded_balance_value_outside_economy_config`, `economy_reads_losing_run_state`, `economy_signal_emission_during_offline_replay`, `try_spend_with_non_positive_amount`.

## Engine Compatibility

| Field | Value |
|---|---|
| **Engine** | Godot 4.6 |
| **Domain** | Core / Scripting (`class_name Economy extends Node` autoload; typed `Dictionary[int, int]` state; `int64` gold arithmetic with `floori`/`floor` truncation; `RandomNumberGenerator` seeded replay; `DataRegistry.resolve("config", "economy_config")` integration; typed signals with `int` payload) |
| **Knowledge Risk** | **LOW** — all primitives (`Node` autoload, typed Dictionary, `int64` = GDScript `int`, `RandomNumberGenerator`, `floori()`, typed signals) are stable ≥ Godot 4.0 / 4.4. No post-cutoff API introduced. `DataRegistry.resolve` pattern precedent-verified via ADR-0006 landed consumers. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; `docs/engine-reference/godot/breaking-changes.md`; `docs/engine-reference/godot/modules/autoload.md` Claim 1 [VERIFIED] + Claim 4 [VERIFIED] (rank 3 autoload `_ready()` timing + zero-arg `_init`); ADR-0002 §Decision (monotonic-credit contract); ADR-0003 §Rank table (Economy rank 3); ADR-0004 §Consumer contract (`get_save_data`/`load_save_data`); ADR-0005 §tick_fired signal ordering; ADR-0006 §DataRegistry.resolve; ADR-0011 §HeroClass (`id: String`, `tier: int`); ADR-0012 §HeroRoster read API (`get_formation_strength()`, `get_copies_owned(class_id)`); `design/gdd/economy-system.md` §C Rules C.1-C.6, §D Formulas D.1-D.6, §E Edge Cases E.1-E.9, §F Dependencies, §G Tuning Knobs, §H ACs H-01..H-14; `design/gdd/dungeon-run-orchestrator.md` §D.1 `_attribute_kill_gold` + §D.2 `_attribute_floor_clear_bonus` (orchestrator-applies-LOSING-factor invariant); `design/gdd/game-time-and-tick.md` (tick_fired cadence + offline_elapsed contract) |
| **Post-Cutoff APIs Used** | `Dictionary[int, int]` typed container syntax (Godot 4.4+) — precedent-verified via ADR-0009 `Dictionary[StringName, int]` + ADR-0012 `Dictionary[int, HeroInstance]` landed usage. No other post-cutoff APIs. |
| **Verification Required** | None new. `Economy` is a standard `Node` autoload at rank 3 (per ADR-0003); all state/signal primitives mirror ADR-0012 HeroRoster shape already verified. `floori` + `floor` integer/float conversion semantics verified per Godot 4.x docs (int→float promotion on `/`; `floori` returns int). |

## ADR Dependencies

| Field | Value |
|---|---|
| **Depends On** | **ADR-0002** (Accepted — provides `floor_clear_bonus_credited: Dictionary[int, int]` monotonic-credit semantic + credit-the-gap call contract + six-row semantic table verbatim). **ADR-0003** (Accepted — provides Economy autoload rank 3, zero-arg `_init` constraint, SaveLoad consumer ordering, `tick_fired` consumer ordering rank-invariant). **ADR-0004** (Accepted — provides `get_save_data()` / `load_save_data()` consumer shape, full-envelope persist path, signal suppression during boot validation; Economy is NOT a heartbeat partial-envelope consumer — only full-envelope on scene boundaries). **ADR-0005** (Accepted — provides `tick_fired(tick_number: int)` synchronous signal contract + `offline_elapsed_seconds` + `is_offline_replay` flag + `now_ms()` cached read; no `_process(delta)` reads in Economy). **ADR-0006** (Accepted — provides `DataRegistry.resolve("config", "economy_config") -> EconomyConfig` contract; `economy_config.tres` is the single source of truth for all tuning knobs enumerated in GDD §G). **ADR-0011** (Accepted — provides `HeroClass.id: String` + `HeroClass.tier: int` fields consumed by Recruitment/Leveling cost computations via `DataRegistry.resolve("classes", class_id).tier`; `EnemyData.tier: int` consumed by `BASE_KILL[tier]` lookup path for Orchestrator's `_attribute_kill_gold` — though Economy itself never reads EnemyData directly, the tier-keyed constant lookup is co-located in `economy_config.tres` per GDD §D.2). **ADR-0012** (Accepted — provides `HeroRoster.get_formation_strength() -> float` range `[1.0, 3.0]` with empty-formation guard + `HeroRoster.get_copies_owned(class_id: String) -> int` computed-on-read contract; Economy calls these per-foreground-tick + once-per-offline-replay-batch-start + per-recruit-cost-query respectively). |
| **Enables** | Future **Recruitment ADR** (consumes `Economy.recruit_cost(class_id, copies_owned)` + `Economy.try_spend(amount, reason)` + `HeroRoster.is_at_cap()` + `HeroRoster.add_hero(class_id)` in the recruit-flow sequence). Future **Hero Leveling ADR** (consumes `Economy.level_cost(class_tier, current_level)` + `Economy.try_spend(amount, reason)` + `HeroRoster.set_hero_level(id, level)`). **ADR-X02** (Offline batch chunking + snapshot schema — consumes `Economy.compute_offline_batch(tick_budget) -> OfflineResult` signature; snapshot lifetime allowlist for Orchestrator-held `Array[HeroInstance]` formation freeze per ADR-0012 §Cross-consumer stability invariant). Economy implementation stories (unblocked). Return-to-App screen stories (consume `OfflineResult.events_log`). Guild Hall / Recruit / Roster / Formation-Assignment screen stories (consume `gold_changed` signal for HUD refresh; read `gold_balance` for button grey-out). **TR-biome-dungeon-db-017** (unblocked — `BASE_DRIP[floor_index]` lookup path codified). |
| **Blocks** | Any Economy implementation story until this ADR is Accepted. Any story that hardcodes a balance constant in `.gd` (e.g., `BASE_DRIP`, `BASE_RECRUIT`, `LEVEL_RATIO`) — must read from `economy_config.tres`. Any story where Economy reads `losing_run` state directly (Orchestrator-applies invariant). Any story where Economy emits `gold_changed` or `first_clear_awarded` during offline replay (signal-suppression invariant). Epic authoring for the Economy system is blocked until Accept promotion. |
| **Ordering Note** | Author AFTER ADR-0002 / ADR-0003 / ADR-0004 / ADR-0005 / ADR-0006 / ADR-0011 / ADR-0012 (all Accepted). Author BEFORE Recruitment, Hero Leveling, ADR-X02 (Offline snapshot). Parallel-safe with ADR-C03 (Audio) and ADR-X04 (Recruitment GDD itself). |

## Context

### Problem Statement

`design/gdd/economy-system.md` §C Rules C.1-C.6, §D Formulas D.1-D.6, §E edge cases, §F dependencies, §G tuning knobs, and §H 14 ACs lock the Economy system's state shape, public API, cost curves, and offline batch contract. Multiple downstream systems already reference Economy as a hard dependency:

- **Dungeon Run Orchestrator** (system #13, Pass 4B-Economy applied) calls `Economy.add_gold(amount)` per kill (with `LOSING_RUN_LOOT_FACTOR` already applied by `_attribute_kill_gold`) and `Economy.try_award_floor_clear(floor_index, bonus_amount) -> bool` on first-clear (with the factor applied by `_attribute_floor_clear_bonus`). Economy receives post-factor amounts only.
- **Save/Load System** (ADR-0004) lists Economy as a rank-3 consumer with `get_save_data` / `load_save_data` contract; persisted keys enumerated.
- **Hero Roster** (ADR-0012) provides `get_formation_strength() -> float` (Economy contract locked by §D.1) and `get_copies_owned(class_id)` (for recruit cost escalation per §D.3).
- **Recruitment System** (undesigned) will call `Economy.try_spend(amount, reason) -> bool` + read `Economy.recruit_cost(class_id, copies_owned)`.
- **Hero Leveling System** (undesigned) will call `Economy.try_spend(...)` + read `Economy.level_cost(class_tier, current_level)`.
- **Offline Progression Engine** (undesigned; anchored by ADR-X02) will call `Economy.compute_offline_batch(tick_budget) -> OfflineResult`.
- **Return-to-App / Guild Hall / Recruit / Roster / Formation screens** (Presentation layer) subscribe to `gold_changed(new_balance, delta, reason)` for HUD refresh + read `gold_balance` for button grey-out.

Without an ADR codifying these stances:

1. **Downstream ADRs cannot author against a moving target.** The future Recruitment ADR needs the exact `recruit_cost()` signature (parameters, return type, escalation formula, -1 sentinel semantics) locked. The Hero Leveling ADR needs `level_cost()` + cap semantics locked. ADR-X02 needs the `OfflineResult` shape locked.
2. **The "Orchestrator applies LOSING factor" directional invariant is GDD-only.** `economy-system.md` §C.2.3 and §F dependencies row both state that Economy receives post-factor amounts, but no architectural artifact currently makes this binding. If a future story were to add `if losing_run: amount /= 2` inside Economy, it would silently double-halve the floor-clear bonus — the exact bug class that ADR-0002's monotonic-credit design was built to prevent. This needs an ADR-level forbidden pattern.
3. **Signal suppression during offline replay is GDD-only.** §C.6 says "`gold_changed` signal dispatch 200-500 ns × 576k = 230 ms alone — blows the budget. A replay flag (`is_offline_replay: bool`) must suppress all UI-bound signals during replay." This is load-bearing for AC-TICK-10's 500 ms offline budget but has no ADR-level CI enforcement.
4. **The `_process(delta)` forbidden pattern is already registered** (`process_delta_as_economy_input`) but Economy needs an explicit positive contract: "reads only `tick_fired(tick_number)`; reads only `now_ms()` cached value for telemetry timestamps, never for economy math."
5. **Cost curves in `economy_config.tres`** — GDD §G says "all knobs live in a single data resource `assets/data/economy_config.tres`; no economy value is hardcoded in GDScript — every constant is a field on this resource." This is the *load-bearing* rule that lets designers tune via the inspector without coder involvement. It needs ADR-level codification and CI enforcement (grep check against hardcoded int literals in `economy.gd` outside the init block). Otherwise a harried implementer will inline `BASE_DRIP = [2, 4, 7, 12, 8]` in the `.gd` file and the tuning contract breaks silently.
6. **Stories are blocked.** `/architecture-review 2026-04-22e` counted ~20 TRs in the TR-economy gap pool as uncovered; all route to this ADR.

### Current State

- `design/gdd/economy-system.md` (2026-04-21 Pass-I.15-fix-ripple applied): §C Rules C.1-C.6 complete; §D formulas complete; §E 9 edge cases locked; §F bidirectional dependencies locked; §G 26 tuning knobs enumerated with safe ranges + failure modes; §H 14 ACs (12 BLOCKING + 1 ADVISORY + Sub-ACs).
- ADR-0002 locks `floor_clear_bonus_credited: Dictionary[int, int]` monotonic-credit field + `try_award_floor_clear` credit-the-gap signature + six-row semantic table.
- ADR-0003 places `Economy` at autoload rank 3; TickSystem (rank 0) + SaveLoad (rank 2) forward-connect to Economy at `_ready()`.
- ADR-0004 locks `get_save_data` / `load_save_data` shape; Economy is in `CONSUMER_PATHS` at position 1 (after TickSystem meta-consumer ordering).
- ADR-0005 locks `tick_fired(tick_number: int)` synchronous emission + `is_offline_replay` flag + `offline_elapsed_seconds(secs)` signal.
- ADR-0006 locks `DataRegistry.resolve("config", "economy_config") -> EconomyConfig`; the `EconomyConfig` Resource subclass is a `GameData` per ADR-0011 pattern.
- ADR-0011 locks `HeroClass.tier: int` + `EnemyData.tier: int` schema fields.
- ADR-0012 locks `HeroRoster.get_formation_strength() -> float` (range `[1.0, 3.0]`, empty-formation guard) + `HeroRoster.get_copies_owned(class_id: String) -> int` (O(N) computed-on-read; no cache).
- `docs/architecture/architecture.md` §Module Ownership Map Core Layer Economy row locks rank 3 + owns `gold_balance`/`floor_clear_bonus_credited`/`recruit_cost_paid_this_session` + exposes `add_gold`/`try_spend`/`try_award_floor_clear`/`gold_changed`/`get_save_data`/`load_save_data`.
- `docs/registry/architecture.yaml`: Economy is listed as a rank-3 consumer of `save_load_envelope` + `tick_fired`; no Economy-specific interface entries; no cost-curve or state-shape api_decisions; no Economy-specific forbidden patterns beyond the cross-cutting `process_delta_as_economy_input`.
- No `src/` implementation exists yet. This ADR is pure design codification.

### Constraints

- **GDD authority**: `economy-system.md` §C / §D / §E / §F / §G / §H is the authoritative source. This ADR ratifies verbatim + adds explicit CI invariants + 4 new forbidden patterns. No rule changes.
- **ADR-0002 inheritance**: `floor_clear_bonus_credited: Dictionary[int, int]` field + credit-the-gap `try_award_floor_clear` + six-row semantic table are frozen. This ADR cannot redefine them.
- **ADR-0003 inheritance**: Economy is autoload rank 3. No rank change. Zero-arg `_init`. TickSystem (rank 0) + SaveLoad (rank 2) `_ready()` fires before Economy's `_ready()`; Economy's forward-connect to `tick_fired` is rank-safe.
- **ADR-0004 inheritance**: `get_save_data` / `load_save_data` consumer shape; Economy is on the full-envelope path only (not heartbeat — only HeroRoster/FloorUnlock/Orchestrator are on heartbeat per ADR-0005 heartbeat design).
- **ADR-0005 inheritance**: `tick_fired(tick_number: int)` synchronous emission — Economy MUST subscribe in `_ready()` and handle in `_on_tick(tick_number: int) -> void`. MUST NOT read `_process(delta)` for any economy-relevant computation (`process_delta_as_economy_input` forbidden pattern).
- **ADR-0006 inheritance**: `economy_config.tres` loaded at DataRegistry rank 1 via `DataRegistry.resolve("config", "economy_config")`. Required-resource validator fails with ERROR state if missing.
- **ADR-0011 inheritance**: `HeroClass.tier: int` is the input for `BASE_RECRUIT[tier]` / `BASE_LEVEL[tier]` lookups; `EnemyData.tier: int` for `BASE_KILL[tier]`.
- **ADR-0012 inheritance**: Economy calls `roster.get_formation_strength()` per foreground tick when a run is ACTIVE + once per offline replay batch start; calls `roster.get_copies_owned(class_id)` on each recruit-cost query. No HeroInstance reference caching (Economy stores zero HeroInstance fields).
- **Pillar 1 (Respect the Player's Time)**: Offline accrual must feel fair. `compute_offline_batch(tick_budget)` must produce output identical to the foreground path for identical input (AC H-09 determinism + AC H-10 < 500 ms). `is_offline_replay` flag MUST suppress `gold_changed` signal during replay; a single aggregate `gold_changed(total, total_delta, "offline_replay")` fires once AFTER replay completes, per §C.6.
- **Pillar 3 (Matchup Is a Decision)**: `MATCHUP_GOLD_MULTIPLIER = 1.5` applied per-kill at emission time by Orchestrator (Economy receives post-multiplier amount). Economy does NOT re-apply.
- **Pillar-1 integrity — directional invariant**: Economy NEVER reads `losing_run` state. All outcome-dependent factors are applied by the Orchestrator before the method call. This is load-bearing — it keeps Economy's drip-subscription path (which has no architectural home for `losing_run` state) correct by construction (§C.2.3 A2 analysis).
- **`int64` arithmetic**: Gold is `int64` throughout. GDScript `int` is 64-bit. `lifetime_gold_earned` unbounded (statistic); `gold_balance` silently clamped to `GOLD_SANITY_CAP = 1 T`.
- **`floori` truncation invariant**: Every formula producing a fractional intermediate MUST be `floori()`-truncated before being added to `gold_balance`. No float accumulation across ticks. §D intro explicitly states this.
- **Single-threaded GDScript**: All mutations happen on the main thread. `try_spend` atomicity is trivially satisfied by GDScript's single-threaded execution model (§E.6). No concurrent-access invariants required.
- **No RNG in faucet math**: Only offline-replay event-cadence estimation uses a seeded `RandomNumberGenerator` (seed = `t_last_persist XOR offline_tick_budget`). All formulas in §D are deterministic.
- **No direct file I/O**: Save/Load orchestrates persistence via `get_save_data` / `load_save_data`. Economy MUST NOT open files, call `ResourceSaver`, or write to `user://`.

### Requirements

- `Economy` MUST be `class_name Economy extends Node` autoload at rank 3 per ADR-0003. Autoload path `/root/Economy`. Zero-arg `_init`.
- State: exactly 4 persisted fields per §C + GDD-update — `_gold_balance: int` (int64), `_lifetime_gold_earned: int` (int64), `_floor_clear_bonus_credited: Dictionary[int, int]` (ADR-0002 inheritance), plus a transient `_is_offline_replay: bool` flag (NOT persisted; drives signal suppression). No additional state without a schema_version bump.
- State container fields underscore-prefixed; no public property exposure (except read-only getters for display surfaces).
- Public API: exactly 7 methods + 2 signals per §F + §G + §D:
  - `add_gold(amount: int) -> void`
  - `try_spend(amount: int, reason: String) -> bool`
  - `try_award_floor_clear(floor_index: int, bonus_amount: int) -> bool` (ADR-0002 credit-the-gap)
  - `recruit_cost(class_id: String, copies_owned: int) -> int`
  - `level_cost(class_tier: int, current_level: int) -> int`
  - `compute_offline_batch(tick_budget: int) -> OfflineResult`
  - Consumer contract: `get_save_data() -> Dictionary` + `load_save_data(data: Dictionary) -> void`
  - Signals: `gold_changed(new_balance: int, delta: int, reason: String)` + `first_clear_awarded(floor_index: int)`
- Read API (display surfaces): `get_gold_balance() -> int` + `get_lifetime_gold_earned() -> int` + `is_first_clear_awarded(floor_index: int) -> bool`. All read-only; no mutators named `set_*`.
- `tick_fired(tick_number: int)` subscription MUST be established in `_ready()`. Handler `_on_tick(tick_number: int) -> void` MUST suppress all work during offline replay (guarded by `_is_offline_replay`).
- `add_gold(amount)` semantics: if `amount <= 0`, `push_error` and return; if `_gold_balance + amount > GOLD_SANITY_CAP`, clamp to cap; update `_lifetime_gold_earned` unbounded; emit `gold_changed(new_balance, delta, "add_gold")` UNLESS `_is_offline_replay == true`.
- `try_spend(amount, reason)` semantics: if `amount < 0`, `push_error` and return `false`; if `amount == 0`, return `true` (H-12 no-op); if `_gold_balance < amount`, return `false` silently (no signal, no mutation); else deduct + emit `gold_changed(new_balance, -amount, reason)` UNLESS `_is_offline_replay == true`.
- `try_award_floor_clear(floor_index, bonus_amount)` semantics: ADR-0002 credit-the-gap verbatim — range-guard `floor_index ∈ [1, 5]` (else push_error + return false); negative-bonus guard (else push_error + return false); `already = _floor_clear_bonus_credited.get(floor_index, 0)`; if `bonus_amount <= already`, return false; `delta = bonus_amount - already`; call `add_gold(delta)`; set `_floor_clear_bonus_credited[floor_index] = bonus_amount`; if `already == 0`, emit `first_clear_awarded(floor_index)` (AT MOST once per floor per save lifetime); return true.
- `recruit_cost(class_id, copies_owned)` semantics: resolve `HeroClass` via `DataRegistry.resolve("classes", class_id)`; if null, `push_error` + return -1; read `tier = class.tier`; look up `base = cfg.BASE_RECRUIT[tier]`; return `floori(base * pow(cfg.RECRUIT_RATIO, copies_owned))`. NO state mutation; pure function.
- `level_cost(class_tier, current_level)` semantics: if `current_level >= cfg.LEVEL_CAP`, return **-1** (sentinel "past cap" per AC H-08); else look up `base = cfg.BASE_LEVEL[class_tier]`; return `floori(base * pow(cfg.LEVEL_RATIO, current_level - 1))`. NO state mutation; pure function.
- `compute_offline_batch(tick_budget)` semantics: set `_is_offline_replay = true`; read `formation_strength = roster.get_formation_strength()` once; compute `drip_total` closed-form = `floori(drip_per_tick * tick_budget)`; resolve events via seeded RNG (seed = `time.last_persist_ts XOR tick_budget`); call `add_gold(drip_total)` + `add_gold(kill_total)` + `try_award_floor_clear(...)` as needed (all with `_is_offline_replay == true` → no signal); after completion, set `_is_offline_replay = false`; emit ONE aggregate `gold_changed(final_balance, total_delta, "offline_replay")`. Return `OfflineResult: {gold_earned: int, kills_by_tier: Dictionary[int, int], floors_cleared: Array[int], events_log: Array[Dictionary]}`.
- `get_save_data()`: returns Dictionary with exactly 3 keys — `gold_balance`, `lifetime_gold_earned`, `floor_clear_bonus_credited`. Key insertion order fixed. `_is_offline_replay` NEVER persisted (transient).
- `load_save_data(data)`: reads the 3 keys with defaults `0 / 0 / {}`; validates `gold_balance ≥ 0` and `gold_balance ≤ GOLD_SANITY_CAP`; on invalid, `push_warning` and clamp. MUST NOT emit `gold_changed` (consistent with ADR-0004 signal suppression during boot validation).
- All tuning knobs live in `assets/data/config/economy_config.tres` (EconomyConfig Resource subclass; GameData per ADR-0011 pattern); the 26 knobs from §G are fields. No hardcoded balance constants in `economy.gd` outside `const GOLD_SANITY_CAP = 1_000_000_000_000` (structural engineering constant — not a tuning knob) and `const OFFLINE_SIGNAL_REASON = "offline_replay"` (signal-routing string).
- CI invariant: grep `src/gameplay/economy/` for integer literals > 10 outside the two allowlisted constants; flag as ERROR. Range of allowed literals covers loop indices (0, 1, 2), array sizes (1-10), and tier indices (1, 2, 3).
- No direct reads of `TickSystem._is_offline_replay`; Economy reads its own `_is_offline_replay` flag (set by `compute_offline_batch` itself, scoped to the batch call).
- No reads of `Orchestrator.losing_run` or equivalent; Economy receives post-factor amounts only.
- `display_abbreviation(balance: int) -> String` per §C.1 display thresholds: stateless pure function; CAN live in Economy as a static helper OR in a separate display formatter module (implementation discretion). This ADR codifies the thresholds as `cfg.DISPLAY_K_THRESHOLD` / `DISPLAY_M_THRESHOLD` / `DISPLAY_B_THRESHOLD` / `DISPLAY_T_THRESHOLD` fields on `EconomyConfig`.

## Decision

### 1. `EconomyConfig` — tuning knob resource (GameData subclass)

```gdscript
# src/gameplay/economy/economy_config.gd
class_name EconomyConfig
extends GameData

# Loaded at DataRegistry rank 1 via DataRegistry.resolve("config", "economy_config").
# All 26 tuning knobs from economy-system.md §G live here.
# No tuning value may be hardcoded in economy.gd.

# --- Gold display thresholds (GDD §C.1) ---
@export var DISPLAY_K_THRESHOLD: int = 1_000
@export var DISPLAY_M_THRESHOLD: int = 1_000_000
@export var DISPLAY_B_THRESHOLD: int = 1_000_000_000
@export var DISPLAY_T_THRESHOLD: int = 1_000_000_000_000

# --- Drip faucet (GDD §D.1) ---
# Arrays indexed by floor_index 1..5; index 0 is sentinel (unused — floors are 1-based).
# NOTE: Godot 4.6 does NOT allow typed-array @export with mixed numeric types inside
# other containers; flat Array[int] is the correct export shape.
@export var BASE_DRIP: Array[int] = [0, 2, 4, 7, 12, 8]   # index 0 unused; F1..F5 = 2,4,7,12,8 (post-Pass-3B)

# --- Kill bonus (GDD §D.2) ---
# enemy_tier 1..3; index 0 is sentinel (unused).
@export var BASE_KILL: Array[int] = [0, 10, 35, 80]       # tier 1..3 = 10, 35, 80
@export var MATCHUP_GOLD_MULTIPLIER: float = 1.5
@export var MATCHUP_DRIP_BONUS: float = 1.0               # default 1.0 disabled; 1.0-1.3 safe range

# --- Recruit cost (GDD §D.3) ---
# class_tier 1..2; index 0 unused.
@export var BASE_RECRUIT: Array[int] = [0, 150, 8_000]    # tier 1 = 150, tier 2 = 8_000
@export var RECRUIT_RATIO: float = 1.8

# --- Level-up cost (GDD §D.4) ---
@export var BASE_LEVEL: Array[int] = [0, 40, 600]         # tier 1 = 40, tier 2 = 600
@export var LEVEL_RATIO: float = 1.6
@export var LEVEL_CAP: int = 15

# --- Floor-clear bonus (GDD §D.5) ---
@export var FLOOR_CLEAR_BONUS: Array[int] = [0, 500, 1_200, 3_000, 7_500, 18_000]
                                          # F1..F5 = 500, 1_200, 3_000, 7_500, 18_000

# --- LOSING factor (applied by Orchestrator, NOT by Economy — listed here for single-source-of-truth) ---
# NOTE: Economy never reads this field. It is declared on EconomyConfig so the
# Orchestrator + Combat GDDs can point to one authoritative location. Orchestrator
# reads `cfg.LOSING_RUN_LOOT_FACTOR` inside `_attribute_kill_gold` + `_attribute_floor_clear_bonus`.
@export var LOSING_RUN_LOOT_FACTOR: float = 0.5

# --- Offline replay (GDD §C.6) ---
# offline_cap_seconds is OWNED by game-time-and-tick.md (defined in TickConfig);
# this field is NOT duplicated here — Economy reads via TickSystem if needed.

# --- Validators (invoked by DataRegistry per ADR-0006 §Load-Time Validation) ---
func validate() -> Array[String]:
    var errors: Array[String] = []
    if BASE_DRIP.size() != 6:
        errors.append("BASE_DRIP must have 6 entries (index 0 sentinel + F1..F5)")
    if BASE_KILL.size() != 4:
        errors.append("BASE_KILL must have 4 entries (index 0 sentinel + tier 1..3)")
    if BASE_RECRUIT.size() != 3:
        errors.append("BASE_RECRUIT must have 3 entries (index 0 sentinel + tier 1..2)")
    if BASE_LEVEL.size() != 3:
        errors.append("BASE_LEVEL must have 3 entries (index 0 sentinel + tier 1..2)")
    if FLOOR_CLEAR_BONUS.size() != 6:
        errors.append("FLOOR_CLEAR_BONUS must have 6 entries (index 0 sentinel + F1..F5)")
    if LEVEL_CAP < 1:
        errors.append("LEVEL_CAP must be >= 1")
    if RECRUIT_RATIO < 1.0:
        errors.append("RECRUIT_RATIO must be >= 1.0 (geometric escalation)")
    if LEVEL_RATIO < 1.0:
        errors.append("LEVEL_RATIO must be >= 1.0 (geometric escalation)")
    if MATCHUP_GOLD_MULTIPLIER < 1.0:
        errors.append("MATCHUP_GOLD_MULTIPLIER must be >= 1.0")
    if LOSING_RUN_LOOT_FACTOR < 0.0 or LOSING_RUN_LOOT_FACTOR > 1.0:
        errors.append("LOSING_RUN_LOOT_FACTOR must be in [0.0, 1.0]")
    return errors
```

### 2. `Economy` — autoload rank 3

```gdscript
# src/gameplay/economy/economy.gd
class_name Economy
extends Node

# Autoload path: /root/Economy (ADR-0003 rank 3).
# Zero-arg _init per ADR-0003 Amendment #3 + autoload.md Claim 4 [VERIFIED].

# --- Structural constants (engineering ceilings — NOT tuning knobs) ---
const GOLD_SANITY_CAP: int = 1_000_000_000_000                # 1 T — §E.1
const OFFLINE_REPLAY_REASON: String = "offline_replay"

# --- Typed signals (GDD §F + §C.6) ---
# Signals suppressed during offline replay per _is_offline_replay flag.
signal gold_changed(new_balance: int, delta: int, reason: String)
signal first_clear_awarded(floor_index: int)

# --- Persisted state (3 fields — see get_save_data) ---
var _gold_balance: int = 0
var _lifetime_gold_earned: int = 0
var _floor_clear_bonus_credited: Dictionary[int, int] = {}   # ADR-0002 monotonic ledger

# --- Transient state (NOT persisted; scoped to compute_offline_batch call) ---
var _is_offline_replay: bool = false

# --- Cached reference (resolved at _ready; not a "cached consumer reference"
#     in the ADR-0004 forbidden-pattern sense because config resources are
#     immutable singletons loaded via DataRegistry, not autoload node refs) ---
var _cfg: EconomyConfig = null


func _ready() -> void:
    # Rank 3 — DataRegistry (rank 1) has finished its scan by this point per
    # ADR-0003 Claim 1 [VERIFIED] rank invariant.
    _cfg = DataRegistry.resolve("config", "economy_config")
    assert(_cfg != null, "Economy._ready: economy_config.tres failed to resolve via DataRegistry")

    # Forward-connect to TickSystem (rank 0) — rank-safe per Claim 1 [VERIFIED].
    # SaveLoadSystem (rank 2) will call get_save_data / load_save_data on us;
    # it forward-connected to us at its own _ready() which fired first.
    TickSystem.tick_fired.connect(_on_tick)


# --- Tick subscription (ADR-0005 inheritance) -----------------------------------

func _on_tick(tick_number: int) -> void:
    # Suppression: during offline replay, compute_offline_batch owns the drip
    # path via closed-form multiply; tick_fired is NOT emitted during replay
    # per ADR-0005 `tick_fired_during_offline_replay` forbidden pattern, so
    # this flag check is defense-in-depth.
    if _is_offline_replay:
        return

    # Drip is gated on an active orchestrator. Orchestrator owns run state;
    # Economy pulls the current per-tick drip via the published read contract.
    # If Orchestrator reports 0 drip (IDLE state / empty formation), no-op.
    var drip: int = DungeonRunOrchestrator.get_current_drip_per_tick()
    if drip > 0:
        add_gold(drip, "tick_drip")   # Internal reason; UI filters to suppress HUD spam
    # Enemy-kill bonuses + floor-clear bonuses are NOT handled here — Orchestrator
    # calls add_gold / try_award_floor_clear directly on kill / first-clear events.


# --- Mutation API ---------------------------------------------------------------

func add_gold(amount: int, reason: String = "credit") -> void:
    if amount < 0:
        push_error("Economy.add_gold: negative amount %d — use try_spend for debits" % amount)
        return
    if amount == 0:
        return   # H-12 analog: no-op, no signal, no sanity-cap touch

    # Sanity-cap clamp (§E.1). lifetime_gold_earned accumulates unbounded.
    var new_balance: int = _gold_balance + amount
    if new_balance > GOLD_SANITY_CAP:
        new_balance = GOLD_SANITY_CAP
    var delta: int = new_balance - _gold_balance
    _gold_balance = new_balance
    _lifetime_gold_earned += amount   # statistic, unbounded by §C.1 int64 headroom analysis

    # Signal suppression during offline replay (AC H-10 + GDD §C.6).
    # compute_offline_batch emits ONE aggregate gold_changed after batch completes.
    if not _is_offline_replay and delta > 0:
        gold_changed.emit(_gold_balance, delta, reason)


func try_spend(amount: int, reason: String) -> bool:
    if amount < 0:
        push_error("Economy.try_spend: negative amount %d (authoring bug)" % amount)
        return false
    if amount == 0:
        return true   # §E AC H-12 — no-op success

    if _gold_balance < amount:
        return false   # §E.7 silent rejection; caller handles UI feedback

    _gold_balance -= amount
    if not _is_offline_replay:
        gold_changed.emit(_gold_balance, -amount, reason)
    return true


func try_award_floor_clear(floor_index: int, bonus_amount: int) -> bool:
    # ADR-0002 credit-the-gap semantics — §C.2.3a steps 1-8 verbatim.
    if floor_index < 1 or floor_index > 5:
        push_error("Economy.try_award_floor_clear: floor_index=%d out of range [1,5]" % floor_index)
        return false
    if bonus_amount < 0:
        push_error("Economy.try_award_floor_clear: bonus_amount=%d is negative (authoring bug)" % bonus_amount)
        return false

    var already: int = _floor_clear_bonus_credited.get(floor_index, 0)
    if bonus_amount <= already:
        return false   # gate no-op: repeat-WIN, LOSING-after-full, LOSING-equal-or-below-prior

    var delta: int = bonus_amount - already
    # Use a dedicated reason so UI + analytics can distinguish first-clear credit
    # from per-tick drip and per-kill bursts.
    add_gold(delta, "floor_clear_%d" % floor_index)
    _floor_clear_bonus_credited[floor_index] = bonus_amount

    # first_clear_awarded fires AT MOST once per floor per save lifetime.
    # Reclaim path (LOSING-first-clear then WIN) does NOT re-emit.
    if already == 0 and not _is_offline_replay:
        first_clear_awarded.emit(floor_index)
    # NOTE: if already == 0 and _is_offline_replay, the signal is replayed in the
    # aggregate OfflineResult.events_log (UI reads events_log for Return-to-App
    # screen). Signal itself remains suppressed to preserve AC H-10 budget.

    return true


# --- Cost curves (pure functions; no state mutation) ----------------------------

func recruit_cost(class_id: String, copies_owned: int) -> int:
    # §D.3 — floor(BASE_RECRUIT[class_tier] * RECRUIT_RATIO ^ copies_owned)
    if copies_owned < 0:
        push_error("Economy.recruit_cost: copies_owned=%d negative (authoring bug)" % copies_owned)
        return -1

    var hero_class: HeroClass = DataRegistry.resolve("classes", class_id)
    if hero_class == null:
        push_error("Economy.recruit_cost: class_id '%s' unresolvable" % class_id)
        return -1

    var tier: int = hero_class.tier
    if tier < 1 or tier >= _cfg.BASE_RECRUIT.size():
        push_error("Economy.recruit_cost: tier %d out of range for BASE_RECRUIT" % tier)
        return -1

    var base: int = _cfg.BASE_RECRUIT[tier]
    return floori(float(base) * pow(_cfg.RECRUIT_RATIO, copies_owned))


func level_cost(class_tier: int, current_level: int) -> int:
    # §D.4 — floor(BASE_LEVEL[class_tier] * LEVEL_RATIO ^ (current_level - 1))
    # Returns -1 if current_level >= LEVEL_CAP (AC H-08 "past cap" sentinel).
    if current_level >= _cfg.LEVEL_CAP:
        return -1   # sentinel: caller must check before offering the purchase
    if current_level < 1:
        push_error("Economy.level_cost: current_level=%d below 1 (authoring bug)" % current_level)
        return -1
    if class_tier < 1 or class_tier >= _cfg.BASE_LEVEL.size():
        push_error("Economy.level_cost: class_tier %d out of range for BASE_LEVEL" % class_tier)
        return -1

    var base: int = _cfg.BASE_LEVEL[class_tier]
    return floori(float(base) * pow(_cfg.LEVEL_RATIO, current_level - 1))


# --- Offline batch (GDD §C.6 hybrid strategy) -----------------------------------

class OfflineResult extends RefCounted:
    # RefCounted data class — freed automatically when the last reference drops.
    # Specialist NOTE #9 (LOAD-BEARING) fold: explicit `extends RefCounted` required
    # because inline classes default to `extends Object` in Godot 4.x, and Object
    # instances are NOT reference-counted — they would require manual `.free()`
    # by every caller or leak memory on every offline-replay return.
    # Implementation MAY hoist this to src/gameplay/economy/offline_result.gd
    # if the return-type annotation benefits from it.
    var gold_earned: int = 0
    var kills_by_tier: Dictionary[int, int] = {}     # key: enemy_tier 1..3; value: kill count
    var floors_cleared: Array[int] = []              # floor_index values first-cleared during replay
    var events_log: Array[Dictionary] = []           # player-facing Return-to-App entries


func compute_offline_batch(tick_budget: int) -> OfflineResult:
    # §C.6 hybrid replay — closed-form drip O(1) + batch events O(N) + signal suppression.
    var result := OfflineResult.new()
    if tick_budget <= 0:
        return result

    _is_offline_replay = true
    var balance_before: int = _gold_balance

    # --- Closed-form drip (O(1) multiply) ---
    # Read formation_strength ONCE per batch (not per tick) per §C.6 amortization rule
    # + ADR-0012 Economy contract performance budget (ADVISORY 50 µs per call).
    var drip_per_tick: int = DungeonRunOrchestrator.get_current_drip_per_tick()
    if drip_per_tick > 0:
        var drip_total: int = drip_per_tick * tick_budget
        add_gold(drip_total, OFFLINE_REPLAY_REASON)   # signal suppressed by flag
        result.gold_earned += drip_total

    # --- Batch event resolution (kills, floor-clears) ---
    # The Orchestrator's compute_offline_batch is the authoritative source for
    # kill cadence + first-clear detection. Economy's role here is the
    # per-event gold/bonus crediting once Orchestrator hands over the event list.
    # Implementation: Orchestrator.compute_offline_batch(tick_budget) returns
    # CombatBatchResult per ADR-0010; OfflineProgressionEngine iterates and
    # calls Economy.add_gold(tier_kill_gold) + Economy.try_award_floor_clear(...)
    # for each event. All signals suppressed during this phase.
    #
    # For determinism (AC H-09), any random decisions during replay use:
    #   var rng := RandomNumberGenerator.new()
    #   rng.seed = TickSystem.get_last_persist_ts() ^ tick_budget
    # Only offline-path uses RNG; foreground-path is tick-driven + stateless.

    var balance_after: int = _gold_balance
    var total_delta: int = balance_after - balance_before
    result.gold_earned = total_delta

    _is_offline_replay = false
    # One aggregate signal AFTER replay completes (§C.6 amortization rule).
    if total_delta > 0:
        gold_changed.emit(_gold_balance, total_delta, OFFLINE_REPLAY_REASON)

    return result


# --- Save/Load consumer contract (ADR-0004) -------------------------------------

func get_save_data() -> Dictionary:
    return {
        "gold_balance": _gold_balance,
        "lifetime_gold_earned": _lifetime_gold_earned,
        "floor_clear_bonus_credited": _floor_clear_bonus_credited.duplicate(),
    }


func load_save_data(data: Dictionary) -> void:
    # Signal suppression during load per ADR-0004. No gold_changed or
    # first_clear_awarded during load_save_data — consistent with ADR-0012
    # HeroRoster._boot_validating pattern. Economy has no analogous flag
    # because signal-suppression is driven by the absence of mutator calls
    # during load (we write directly to _gold_balance; no add_gold path).
    _gold_balance = int(data.get("gold_balance", 0))
    _lifetime_gold_earned = int(data.get("lifetime_gold_earned", 0))

    # Sanity-cap validation on load (hand-edited save protection).
    if _gold_balance < 0:
        push_warning("Economy.load: gold_balance %d negative — clamping to 0" % _gold_balance)
        _gold_balance = 0
    if _gold_balance > GOLD_SANITY_CAP:
        push_warning("Economy.load: gold_balance %d exceeds sanity cap — clamping" % _gold_balance)
        _gold_balance = GOLD_SANITY_CAP
    if _lifetime_gold_earned < 0:
        push_warning("Economy.load: lifetime_gold_earned %d negative — clamping to 0" % _lifetime_gold_earned)
        _lifetime_gold_earned = 0

    # Restore floor-clear ledger. Keys arrive as ints via JSON parse (Godot
    # Dictionary JSON serialization preserves int keys for Dictionary[int, int]).
    _floor_clear_bonus_credited.clear()
    var raw_ledger: Dictionary = data.get("floor_clear_bonus_credited", {})
    for k in raw_ledger:
        var floor_idx: int = int(k)
        var credited: int = int(raw_ledger[k])
        if floor_idx < 1 or floor_idx > 5:
            push_warning("Economy.load: floor_clear_bonus_credited key %d out of range [1,5] — dropping" % floor_idx)
            continue
        if credited < 0:
            push_warning("Economy.load: floor_clear_bonus_credited[%d] negative %d — dropping" % [floor_idx, credited])
            continue
        _floor_clear_bonus_credited[floor_idx] = credited


# --- Read API (display + analytics surfaces; no mutation) -----------------------

func get_gold_balance() -> int:
    return _gold_balance


func get_lifetime_gold_earned() -> int:
    return _lifetime_gold_earned


func is_first_clear_awarded(floor_index: int) -> bool:
    return _floor_clear_bonus_credited.get(floor_index, 0) > 0


func get_floor_clear_credited(floor_index: int) -> int:
    # Exposes the ceiling for UI affordances (e.g., "LOSING reclaim pending"
    # indicator on the floor-select screen per ADR-0002 §Risks row 3).
    return _floor_clear_bonus_credited.get(floor_index, 0)


# --- Display helpers (static pure functions; see §G display thresholds) ---------

static func abbreviate_balance(balance: int, cfg: EconomyConfig) -> String:
    # §C.1 display format table. Stateless; lives here for colocation with
    # the authoritative thresholds, but Presentation layer MAY duplicate
    # the formatter if single-responsibility preferred.
    if balance < cfg.DISPLAY_K_THRESHOLD:
        return str(balance)
    if balance < cfg.DISPLAY_M_THRESHOLD:
        return "%.2fK" % (balance / 1_000.0)
    if balance < cfg.DISPLAY_B_THRESHOLD:
        return "%.2fM" % (balance / 1_000_000.0)
    if balance < cfg.DISPLAY_T_THRESHOLD:
        return "%.2fB" % (balance / 1_000_000_000.0)
    return "%.2fT" % (balance / 1_000_000_000_000.0)
```

### 3. Architecture diagram

```
                ┌─────────────────────────────────────────────────────┐
                │  Economy (autoload rank 3; Node; zero-arg _init)    │
                │                                                      │
                │  _gold_balance: int (int64; clamp GOLD_SANITY_CAP)   │
                │  _lifetime_gold_earned: int (int64; unbounded stat)  │
                │  _floor_clear_bonus_credited: Dictionary[int, int]   │
                │    (ADR-0002 monotonic ledger)                        │
                │  _is_offline_replay: bool (transient; signal gate)    │
                │  _cfg: EconomyConfig (loaded at _ready)              │
                │                                                      │
                │  Public API (7 methods + 2 signals):                 │
                │    add_gold(amount, reason)                          │
                │    try_spend(amount, reason) → bool                  │
                │    try_award_floor_clear(floor_idx, bonus) → bool    │
                │    recruit_cost(class_id, copies_owned) → int        │
                │    level_cost(class_tier, current_level) → int       │
                │    compute_offline_batch(tick_budget) → OfflineResult│
                │    get_save_data / load_save_data                    │
                │                                                      │
                │  Signals (suppressed during offline replay):         │
                │    gold_changed(new, delta, reason)                  │
                │    first_clear_awarded(floor_idx)                    │
                └─────────────────────────────────────────────────────┘
                     ▲            ▲              ▲              ▲
                     │            │              │              │
  (0) TickSystem.tick_fired ─────┘            │              │
       subscribed in _ready; handler skips if _is_offline_replay
                                              │              │
  (1) SaveLoadSystem full-envelope persist/restore          │
       via get_save_data / load_save_data (ADR-0004)         │
                                              │              │
  (2) DungeonRunOrchestrator call-ins:        │              │
       ├─ get_current_drip_per_tick() (Economy reads per tick)
       ├─ add_gold(kill_gold, ...) (Orchestrator applies LOSING factor + MATCHUP_GOLD_MULTIPLIER)
       └─ try_award_floor_clear(floor_idx, amount) (Orchestrator applies LOSING factor)
                                                             │
  (3) Recruitment + Hero Leveling (future systems):          │
       ├─ recruit_cost(class_id, copies_owned) → int         │
       ├─ level_cost(class_tier, current_level) → int        │
       └─ try_spend(amount, reason) → bool                   │
                                                             │
  (4) OfflineProgressionEngine call-in:                      │
       compute_offline_batch(tick_budget) → OfflineResult    │
       (signal-suppressed; aggregate gold_changed at end)    │
                                                             │
  (5) Presentation layer subscribe:                          │
       gold_changed → HUD refresh                            │
       first_clear_awarded → narrative/analytics hooks       │
       get_gold_balance() → button grey-out                  │
       is_first_clear_awarded(idx) / get_floor_clear_credited(idx) → floor-select UI

DAG direction:
  DataRegistry → Economy (reads EconomyConfig at _ready; resolves HeroClass per recruit_cost call)
  TickSystem → Economy (tick_fired signal; rank 0 → rank 3 forward-safe)
  SaveLoadSystem ↔ Economy (bidirectional via get_save_data / load_save_data; rank 2 consumer of rank 3)
  Orchestrator (rank 14) → Economy (rank 3) for call-ins (rank 14 reads rank 3 APIs — call direction
    is rank-safe because Orchestrator invokes methods, not reads state; Economy.get_current_drip_per_tick
    does NOT exist — Economy reads Orchestrator, see note below)

  NOTE on the Economy↔Orchestrator rank pairing: Economy (rank 3) reads
  DungeonRunOrchestrator (rank 14) state via `get_current_drip_per_tick()` per tick.
  Per ADR-0003 rank invariant, rank-3 reading rank-14 state at _ready() is
  forbidden (state-read pattern); HOWEVER, this read happens inside `_on_tick`
  which fires well after _ready() for BOTH autoloads, so both are fully READY.
  `_on_tick` is NOT `_ready()`-time, and ADR-0003 Amendment #1 explicitly
  distinguishes rank-independent runtime reads (SAFE) from rank-dependent
  _ready() state reads (FORBIDDEN). Runtime method invocation across ranks is
  unrestricted once all autoloads are READY. This ADR codifies the pattern.

  NO CYCLES. NO consumer caches an Economy node reference across save-load.
  NO cross-call float accumulation. NO losing_run state read on the Economy side.
```

### 4. Key Interfaces (full public surface)

```gdscript
# Economy mutation API
func add_gold(amount: int, reason: String = "credit") -> void
func try_spend(amount: int, reason: String) -> bool
func try_award_floor_clear(floor_index: int, bonus_amount: int) -> bool

# Economy cost curves (pure functions)
func recruit_cost(class_id: String, copies_owned: int) -> int      # -1 on error
func level_cost(class_tier: int, current_level: int) -> int        # -1 on cap-hit or error

# Economy offline replay
func compute_offline_batch(tick_budget: int) -> OfflineResult

# Economy save/load consumer contract (ADR-0004)
func get_save_data() -> Dictionary
func load_save_data(data: Dictionary) -> void

# Economy read API (no state mutation)
func get_gold_balance() -> int
func get_lifetime_gold_earned() -> int
func is_first_clear_awarded(floor_index: int) -> bool
func get_floor_clear_credited(floor_index: int) -> int

# Economy display helper (static)
static func abbreviate_balance(balance: int, cfg: EconomyConfig) -> String

# Economy signals
signal gold_changed(new_balance: int, delta: int, reason: String)
signal first_clear_awarded(floor_index: int)
```

```gdscript
# OfflineResult — Economy return type (inline class extends RefCounted)
class OfflineResult extends RefCounted:
    var gold_earned: int
    var kills_by_tier: Dictionary[int, int]   # enemy_tier → kill count
    var floors_cleared: Array[int]            # floor_index values
    var events_log: Array[Dictionary]         # player-facing Return-to-App entries
```

### 5. Cross-system directional invariants (ADR-elevated)

Four load-bearing rules that the GDD implies but never explicitly enumerates as forbidden patterns:

> **`hardcoded_balance_value_outside_economy_config`** — No `.gd` file outside `src/gameplay/economy/economy_config.gd` (and its `.tres` instance) may contain an integer literal > 10 that represents a tuning knob value (BASE_DRIP, BASE_KILL, BASE_RECRUIT, BASE_LEVEL, FLOOR_CLEAR_BONUS, display thresholds, etc.). Structural engineering constants (`GOLD_SANITY_CAP = 1_000_000_000_000`, loop indices, array sizes) are allowlisted. The CI check greps `src/gameplay/economy/economy.gd` + `src/gameplay/economy/*.gd` for integer literals > 10 and requires each one to be either in the allowlist OR marked with `# CI: structural — not a tuning knob`.
>
> **Why**: Designer tuning authority. The GDD §G lists 26 tuning knobs. If any live in `.gd`, the designer must file a coder ticket to tune. The `economy_config.tres` rule IS the single most load-bearing productivity contract for Economy — playtest iteration depends on it.

> **`economy_reads_losing_run_state`** — Economy MUST NOT read `DungeonRunOrchestrator.losing_run` or any equivalent run-outcome state. All outcome-dependent factors are applied by the Orchestrator (via `_attribute_kill_gold` + `_attribute_floor_clear_bonus`) before the Economy method call. The CI check greps `src/gameplay/economy/*.gd` for identifiers matching `losing_run|losing|survived|hp_bonus_factor` and fails if any are found outside comments.
>
> **Why**: Pillar-1 architectural integrity. The Economy GDD §C.2.3 A2 analysis established that the per-tick drip subscription has no architectural home for `losing_run` state (it's a run-state attribute, but drip is subscription-driven and fires regardless of run outcome — drip is run-outcome-independent by design). Having a second LOSING application inside Economy would double-halve the floor-clear bonus + kill gold, silently breaking AC H-02 + AC H-14. The only architecturally correct location for the factor is inside the Orchestrator's `_attribute_*` helpers.

> **`economy_signal_emission_during_offline_replay`** — Economy MUST NOT emit `gold_changed` or `first_clear_awarded` while `_is_offline_replay == true`. A single aggregate `gold_changed(final_balance, total_delta, "offline_replay")` MAY fire AFTER replay completes. First-clears that occur during replay are surfaced via `OfflineResult.events_log` for the Return-to-App screen, not via the live signal. The CI check inspects `add_gold` + `try_award_floor_clear` + `try_spend` method bodies for unguarded `.emit(...)` calls — every `emit` inside those three methods MUST be preceded by `if not _is_offline_replay:` or equivalent. **EXEMPT: the single aggregate `gold_changed.emit(...)` in `compute_offline_batch` that fires AFTER `_is_offline_replay = false` — this is the legitimate post-replay notification and MUST NOT be flagged.** (Specialist NOTE #8 LOAD-BEARING fold.) The CI test MUST explicitly allowlist this call site by restricting the grep to the three guarded-mutator function bodies only, NOT `compute_offline_batch`'s body.
>
> **Why**: AC H-10 performance budget (< 500 ms for 576 000-tick offline replay). GDD §C.6 analysis: "`gold_changed` signal dispatch 200-500 ns × 576k = 230 ms alone — blows the budget." Even one unguarded signal in the hot path is an AC H-10 regression.

> **`try_spend_with_non_positive_amount`** — Callers MUST NOT invoke `try_spend(amount, reason)` with `amount < 0`. `amount == 0` returns `true` (AC H-12 no-op). `amount < 0` triggers `push_error` + returns `false`. The CI check scans `src/*/` for `try_spend(NEGATIVE_LITERAL, ...)` patterns and flags any literal-negative call site. Non-literal negatives (e.g., `try_spend(-user_input, ...)`) are caller responsibility to guard; Economy reports via `push_error` at runtime.
>
> **Why**: Symmetric invariant to `add_gold`'s positive-only contract. `try_spend` + `add_gold` form a bidirectional contract; a negative spend would silently become a credit, bypassing AC H-05 + AC H-06 atomicity guarantees. Explicit error surface prevents the silent-bug class.

## Alternatives Considered

### Alternative 1: Split Economy into Treasury + CostCurve + OfflineBatcher autoloads

- **Description**: Three autoloads instead of one — `Treasury` (owns `_gold_balance` + `try_spend` + `add_gold`), `CostCurve` (pure functions; `recruit_cost` + `level_cost`), `OfflineBatcher` (owns `compute_offline_batch` + seeded RNG). Each becomes its own rank-N entry in ADR-0003.
- **Pros**: Single-responsibility per autoload; CostCurve is testable without TickSystem/SaveLoad setup; OfflineBatcher could be replaced in V1.0 without touching Treasury.
- **Cons**: Three autoloads means three `_ready()` ordering concerns, three SaveLoad consumer entries (but CostCurve owns no state — trivial), three signal paths. Economy GDD §F already specifies a single consumer surface ("`economy.try_spend(...)`"; "`economy.compute_offline_batch(...)`") with five dependents pointing to "Economy" not "Treasury/CostCurve/OfflineBatcher". Splitting would require all five downstream systems to know about three separate autoloads. Test isolation benefit is minor (CostCurve is pure functions; trivial to test as a private helper on `Economy`).
- **Estimated Effort**: Adds 2 autoload registrations + 2 SaveLoad consumer entries (CostCurve trivial); adds ~200 lines of cross-autoload coordination code.
- **Rejection Reason**: GDD §F locks the single-consumer-surface contract. Splitting is a coder-preference refactor, not a design requirement. Single autoload is simpler to reason about per `economy-system.md` §C's "Economy is the read-through-and-write boundary for every faucet and sink" framing — a single boundary is clearer than three.

### Alternative 2: Store tuning knobs as `const` in `economy.gd` instead of `economy_config.tres`

- **Description**: Declare all 26 knobs as `const BASE_DRIP: Array[int] = [...]` etc. directly in `economy.gd`. No Resource subclass; no DataRegistry resolve.
- **Pros**: Simpler init (no `_cfg = DataRegistry.resolve(...)` dependency; no load failure mode); zero boot-time cost; no `.tres` file to maintain.
- **Cons**: Violates GDD §G's "no economy value is hardcoded in GDScript" rule explicitly. Designers cannot tune without a coder editing `.gd`. Fails playtest-iteration speed. Violates ADR-0006 `content_base_class` pattern (all designer-tunable data is GameData).
- **Rejection Reason**: GDD §G rule is load-bearing for the designer's tuning authority. `const` values are tunable only by coders; the entire point of the Resource pattern (per ADR-0011) is that designers edit `.tres` in the inspector.

### Alternative 3: Economy reads `Orchestrator.losing_run` directly and applies LOSING factor itself

- **Description**: Economy gains `var _losing_run: bool = false` as a cached field, refreshed by subscribing to Orchestrator `losing_run_changed` signal OR by reading `Orchestrator.losing_run` in `add_gold` / `try_award_floor_clear` directly. Economy applies `LOSING_RUN_LOOT_FACTOR` internally.
- **Pros**: Single source of truth for the factor (one call site in `add_gold` vs. one call site in each Orchestrator `_attribute_*` helper); removes a directional coupling from Orchestrator's code.
- **Cons**: The per-tick drip subscription path (§C.2.3 A2 analysis) has no architectural home for `losing_run`. Drip is run-outcome-independent by design (drip fires on every tick_fired regardless of run state; drip does not receive the LOSING factor, per Pass 4B-Economy decision A2 supersession of Pass 2B decision 4). If Economy applied LOSING to kills + floor-clear but NOT drip, Economy would need to branch on "am I crediting drip or kill gold or floor-clear?" — which it doesn't know at the method level. The call paths are unified (`add_gold(amount, reason)`); Economy can't introspect Orchestrator's intent. Moving the LOSING logic into Economy would also double-halve on a re-entrant LOSING clear (Orchestrator already halved; Economy would halve again) — exactly the class of silent-bug ADR-0002 was designed to prevent.
- **Rejection Reason**: The GDD §C.2.3 A2 analysis is definitive: "Drip is run-outcome-independent by architecture; kill gold and floor-clear bonuses are run-outcome-dependent and are correctly routed through the Orchestrator which owns losing_run state." This ADR codifies the directional invariant as a forbidden pattern (`economy_reads_losing_run_state`).

### Alternative 4: Emit `gold_changed` per-tick during offline replay with aggregation downstream

- **Description**: Do not suppress signals during replay. Let Presentation layer (HUD) aggregate the 576 000 per-tick updates via its own coalesce-every-frame mechanism.
- **Pros**: Simpler Economy code (no `_is_offline_replay` flag); Presentation-layer aggregation could be reused for other bursty signal paths.
- **Cons**: GDD §C.6 analysis: 200-500 ns × 576k = 230 ms of pure signal dispatch cost, which blows AC H-10's 500 ms budget on the signal path alone before any UI work. Presentation layer aggregation doesn't help — the cost is in the signal machinery (dispatching to connected callables), not in the receiver.
- **Rejection Reason**: AC H-10 is BLOCKING. The in-Economy suppression is the only place where the signal dispatch itself can be skipped; downstream aggregation can't buy back time already spent in `signal.emit()`.

### Alternative 5: Inline `OfflineResult` as a Dictionary rather than a typed class

- **Description**: `compute_offline_batch(tick_budget) -> Dictionary` where the dict has keys `gold_earned`, `kills_by_tier`, `floors_cleared`, `events_log`.
- **Pros**: Zero boilerplate; trivial serialization if ever persisted; no typing concerns on field access.
- **Cons**: No type checking on field access (typos silently return `null`); Presentation code becomes `result.get("gold_earned", 0)` instead of `result.gold_earned`; refactoring the shape is harder (no single place to update). Violates project typed-GDScript discipline per `.claude/docs/coding-standards.md`.
- **Rejection Reason**: Typed inline class is the idiomatic Godot 4.x choice for a structured return value. Matches ADR-0010 `CombatBatchResult` + ADR-0009 `MatchupResult` precedent.

## Consequences

### Positive

- **All GDD §C/§D/§E/§F/§G/§H contracts locked at ADR level**: Future Recruitment ADR can cite `recruit_cost(class_id, copies_owned) -> int` with `-1` error sentinel. Future Hero Leveling ADR can cite `level_cost(class_tier, current_level) -> int` with `-1` past-cap sentinel. ADR-X02 can cite `compute_offline_batch(tick_budget) -> OfflineResult` with the frozen `OfflineResult` shape.
- **ADR-0002 monotonic-credit semantic ratified at consumer level**: `try_award_floor_clear` is now triply-sourced (ADR-0002 contract + GDD §C.2.3a + this ADR §Decision §2). The credit-the-gap logic is the same code in all three documents — no drift possible.
- **Directional invariants codified**: Four new forbidden patterns (`hardcoded_balance_value_outside_economy_config`, `economy_reads_losing_run_state`, `economy_signal_emission_during_offline_replay`, `try_spend_with_non_positive_amount`) prevent whole classes of silent bugs.
- **Pillar 1 performance budget preserved**: Signal suppression during offline replay (enforced via the new `economy_signal_emission_during_offline_replay` forbidden pattern) keeps AC H-10's 500 ms budget intact. Aggregate `gold_changed` signal AFTER replay fires once.
- **Pillar 3 matchup legibility preserved**: Orchestrator applies `MATCHUP_GOLD_MULTIPLIER` at per-kill emission; Economy receives post-multiplier amounts. The 2.25× combined matchup effect (1.5× gold × 1.5× throughput) is structurally enforced by call-path direction.
- **Designer tuning authority locked**: `economy_config.tres` contract is CI-enforced. All 26 knobs are editable in the inspector without coder involvement. Playtest iteration speed preserved.
- **Cost curves pure-function**: `recruit_cost` + `level_cost` have no state; unit-testable in isolation; no TickSystem/SaveLoad/Roster setup required for tests.
- **Save/Load round-trip contract clear**: 3-key dict shape verbatim per GDD H-11. `_is_offline_replay` correctly excluded from persistence.
- **Combat + Matchup statelessness unaffected**: Economy does not call Combat/Matchup APIs directly. Call direction is Orchestrator → Economy; Economy is a pure receiver.
- **HeroRoster contract preserved**: Economy calls `roster.get_formation_strength()` (ADR-0012 locked) and `roster.get_copies_owned(class_id)` (ADR-0012 locked). No HeroInstance caching (Economy stores zero HeroInstance fields).

### Negative

- **Economy.gd is ~350 lines** of GDScript (7 methods + 4 read accessors + static display helper + EconomyConfig resource + inline OfflineResult class). Larger than ADR-0009 MatchupResolver or ADR-0010 CombatResolver (both stateless + ~200 lines). Mitigation: Single-responsibility per the "single consumer surface" framing; further splitting would add coordination cost per Alternative 1 analysis.
- **Four new forbidden patterns** means four new CI test scripts to author (`tests/ci/economy_hardcoded_values_test.gd`, `tests/ci/economy_losing_run_test.gd`, `tests/ci/economy_signal_suppression_test.gd`, `tests/ci/economy_try_spend_negative_test.gd`). Estimated effort: 1-2 hours per script at implementation time. Mitigation: all four are grep-based; no runtime instrumentation needed.
- **`_is_offline_replay` flag adds a code path**: Every `.emit()` call in Economy requires a guard. Manually enforced + CI-checked (`economy_signal_emission_during_offline_replay`). Alternative would be Godot's `Object.set_block_signals(true/false)` which is broader (blocks ALL signals, including internal node lifecycle ones). The scoped-flag approach was chosen for explicitness; ADR-0012 Specialist NOTE #5 equivalence applies (either pattern is defensible).
- **`EconomyConfig.LOSING_RUN_LOOT_FACTOR` lives in `economy_config.tres` but is read only by Orchestrator, not Economy**. This creates a slight misnomer — the value is "economy-adjacent" but lives one layer away from where the knob's tuning effect is felt. Alternative would be to move `LOSING_RUN_LOOT_FACTOR` into a separate `run_config.tres`; deferred because (a) it's thematically a loot tuning knob, (b) the GDD §G lists it in the Economy tuning knob table, (c) the Orchestrator already resolves `economy_config` for other reasons (Combat GDD Rule 9 reads it). Open Question I.1 below captures the minor concern.
- **`recruit_cost` O(1) per call but involves a `DataRegistry.resolve("classes", class_id)` lookup + a `pow()` call**. Bounded constant work; not on a hot path. Call sites are UI-driven (Recruit Screen on render / on button tap). Performance: <50 µs per call per ADR-0012 locked `get_formation_strength` budget (same order of magnitude).
- **`level_cost` returns -1 as cap-sentinel; callers MUST check before offering the purchase**. Well-documented in GDD AC H-08 and this ADR §Requirements. Risk of caller forgetting the check is mitigated by the `try_spend(-1, ...)` falling through to the `amount < 0` guard with a `push_error` — a noisy failure, not a silent one.

### Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Future implementer hardcodes `BASE_DRIP = [2, 4, 7, 12, 8]` in `economy.gd` for "performance" or "convenience" | Medium | High (breaks designer tuning contract; §G 26-knob surface collapses) | CI test `economy_hardcoded_values_test.gd` greps economy.gd for integer literals > 10 outside allowlist; blocks build |
| `LOSING_RUN_LOOT_FACTOR` accidentally re-applied inside Economy by a future implementer who "adds safety" | Medium | Critical (AC H-14 double-halving silent regression) | CI test `economy_losing_run_test.gd` greps economy.gd for `losing_run|losing|survived|hp_bonus_factor` identifiers outside comments; blocks build |
| Unguarded `gold_changed.emit(...)` in a new branch breaks AC H-10 500 ms budget | Medium | High (performance regression under offline replay) | CI test `economy_signal_suppression_test.gd` greps Economy for `.emit(` calls without preceding `if not _is_offline_replay:` guard; blocks build. H-10 runtime test also catches it but later. |
| `DataRegistry.resolve("classes", class_id)` returns null on malformed save (orphaned class_id) causing `recruit_cost` to return -1 without context | Low | Medium (Recruitment UI shows "cost unknown" or greys out silently) | `push_error` on null resolve logs the class_id explicitly; Recruitment UI MUST handle -1 return as "data error, cannot recruit" with user-visible toast (Recruitment ADR responsibility) |
| `EconomyConfig.tres` missing or corrupt at boot → `_ready()` crashes on `_cfg.BASE_DRIP` access | Low | High (Economy autoload fails; chain breaks) | ADR-0006 required-resource validator: `config/economy_config.tres` MUST exist + MUST pass `EconomyConfig.validate()` at DataRegistry rank 1 load; DataRegistry emits ERROR state if missing/invalid; Economy's `_ready()` assertion fails loud with the missing resource name |
| `Dictionary[int, int]` JSON round-trip loses int keys (stringifies on serialize, fails to re-int on deserialize) | Low | High (floor-clear ledger lost across saves — AC H-11 fails) | `load_save_data` explicitly `int(k)` coerces keys; tested by AC H-11; Godot 4.6 JSON behavior is well-understood (keys stringify in JSON; but Godot's `var_to_bytes` binary serialization preserves int keys). Save/Load envelope uses binary (ADR-0004), so the coercion is defense-in-depth. |
| `compute_offline_batch` RNG seed collision across two back-to-back offline sessions with identical `(last_persist_ts, tick_budget)` pair | Very Low | Low (two identical replays; determinism holds — this is AC H-09 working as designed) | Not a bug; identical seed on identical input produces identical output. If ever a concern, add session counter to the seed derivation. |
| `DungeonRunOrchestrator.get_current_drip_per_tick()` is a rank-3 → rank-14 runtime read; Orchestrator may not yet be READY at Economy's first `_on_tick` if TickSystem starts emitting before Orchestrator's `_ready` finishes | Low | Medium (drip reads stale / returns 0 for first few ticks) | Per ADR-0003 Claim 1 [VERIFIED], all autoloads' `_ready()` fires before any `_process`/`tick_fired` emission. Orchestrator is READY when TickSystem starts emitting. The runtime-call rank-direction read is SAFE because it's not a `_ready()`-time state read. Defense-in-depth: `get_current_drip_per_tick()` returns 0 when Orchestrator is in IDLE state (empty formation); this is the correct no-op. |

## GDD Requirements Addressed

| GDD Document | Requirement | How This ADR Addresses It |
|---|---|---|
| `design/gdd/economy-system.md` §C.1 | `gold_balance: int64` single currency; 1 T sanity cap; `lifetime_gold_earned` unbounded stat | §Decision §2 `GOLD_SANITY_CAP` const + `_gold_balance` / `_lifetime_gold_earned` fields; `add_gold` clamp logic |
| `design/gdd/economy-system.md` §C.1 display thresholds | K/M/B/T abbreviation rules | §Decision §2 `abbreviate_balance` static helper + EconomyConfig DISPLAY_*_THRESHOLD fields |
| `design/gdd/economy-system.md` §C.2.1 per-tick drip | Drip from Orchestrator's `get_current_drip_per_tick`; fires via `tick_fired` subscription; 0 when IDLE | §Decision §2 `_on_tick` handler + offline-replay suppression |
| `design/gdd/economy-system.md` §C.2.2 enemy kill bonus | Orchestrator calls `add_gold(kill_gold)` per kill with MATCHUP_GOLD_MULTIPLIER + LOSING_RUN_LOOT_FACTOR pre-applied | §Decision §2 `add_gold` + forbidden pattern `economy_reads_losing_run_state` |
| `design/gdd/economy-system.md` §C.2.3 floor-clear bonus + §C.2.3a `try_award_floor_clear` | ADR-0002 credit-the-gap semantic + 6-row table + once-per-save `first_clear_awarded` emission | §Decision §2 `try_award_floor_clear` verbatim to ADR-0002 |
| `design/gdd/economy-system.md` §C.2.4 matchup multiplier | Per-kill majority gate applied by Orchestrator; Economy receives post-multiplier amount | §Decision §5 forbidden pattern `economy_reads_losing_run_state` + architecture diagram call direction |
| `design/gdd/economy-system.md` §C.3 sinks (recruit, level) | `try_spend(amount, reason) -> bool` atomic contract + `recruit_cost` / `level_cost` pure-function cost curves | §Decision §2 `try_spend` + `recruit_cost` + `level_cost` |
| `design/gdd/economy-system.md` §C.4 states (IDLE/ACTIVE/OFFLINE_REPLAY/PAUSED) | State re-derived from roster assignment; not persisted | §Decision §2 no state field for run-state; handler reads Orchestrator each tick |
| `design/gdd/economy-system.md` §C.5 system interactions | Interface table with 7 systems | §ADR Dependencies + §Decision §Architecture diagram |
| `design/gdd/economy-system.md` §C.6 offline replay contract | Closed-form drip O(1); batch events O(N); seeded RNG; signal suppression | §Decision §2 `compute_offline_batch` + forbidden pattern `economy_signal_emission_during_offline_replay` |
| `design/gdd/economy-system.md` §D.1 drip formula | `floor(BASE_DRIP[floor_tier] * formation_strength * matchup_drip_factor)` | Formula captured in §Decision §2 (via EconomyConfig BASE_DRIP + Orchestrator's `get_current_drip_per_tick` composition) |
| `design/gdd/economy-system.md` §D.2 kill bonus formula | `floor(BASE_KILL[tier] * matchup_multiplier)` applied by Orchestrator | §Decision §1 BASE_KILL field + Orchestrator applies multiplier before add_gold |
| `design/gdd/economy-system.md` §D.3 recruit cost formula | `floor(BASE_RECRUIT[tier] * RECRUIT_RATIO^copies_owned)` | §Decision §2 `recruit_cost` verbatim |
| `design/gdd/economy-system.md` §D.4 level-up cost formula | `floor(BASE_LEVEL[tier] * LEVEL_RATIO^(level-1))` with cap-sentinel -1 | §Decision §2 `level_cost` verbatim |
| `design/gdd/economy-system.md` §D.5 floor-clear bonus table | `FLOOR_CLEAR_BONUS[1..5] = 500, 1200, 3000, 7500, 18000` | §Decision §1 FLOOR_CLEAR_BONUS array |
| `design/gdd/economy-system.md` §D.6 pacing table | Milestone validation — informational, not ADR-level | Validated by `/architecture-review` + playtest; no code impact |
| `design/gdd/economy-system.md` §E.1 sanity cap | Silent clamp to GOLD_SANITY_CAP | §Decision §2 `add_gold` clamp logic |
| `design/gdd/economy-system.md` §E.2 offline cap reached | Clamp by TickSystem's `offline_cap_seconds`; Economy processes exactly N ticks | §Decision §2 `compute_offline_batch` accepts tick_budget parameter (TickSystem pre-clamps) |
| `design/gdd/economy-system.md` §E.3 IDLE no-formation | Orchestrator's `get_current_drip_per_tick` returns 0; no Economy special case | §Decision §2 `_on_tick` handler `if drip > 0` branch |
| `design/gdd/economy-system.md` §E.4 offline first-clear | Orchestrator calls `try_award_floor_clear` during replay; signal suppressed; surfaced via events_log | §Decision §2 `compute_offline_batch` + `try_award_floor_clear` guards |
| `design/gdd/economy-system.md` §E.5 missing class in formation | Formation Assignment System validates; Economy passive consumer | §Decision §2 `_on_tick` reads Orchestrator drip (already validated) |
| `design/gdd/economy-system.md` §E.6 try_spend race | GDScript single-threaded; atomic | §Constraints single-threaded note + §Decision §2 `try_spend` |
| `design/gdd/economy-system.md` §E.7 negative balance | `try_spend` returns false on insufficient; no partial deduction | §Decision §2 `try_spend` verbatim |
| `design/gdd/economy-system.md` §E.8 180-day absence | TickSystem clamps offline_elapsed; no Economy special case | §Decision §2 `compute_offline_batch` accepts pre-clamped tick_budget |
| `design/gdd/economy-system.md` §E.9 tuning knob change in patch | Forward-only; no retroactive recalculation | §Decision §1 EconomyConfig editable in inspector; no code change needed |
| `design/gdd/economy-system.md` §F dependencies (7 systems) | Interface table | §ADR Dependencies + §Decision §Architecture diagram |
| `design/gdd/economy-system.md` §G 26 tuning knobs | All 26 live in economy_config.tres; no hardcoded values in .gd | §Decision §1 EconomyConfig + forbidden pattern `hardcoded_balance_value_outside_economy_config` |
| `design/gdd/economy-system.md` §H H-01..H-14 14 ACs | All 14 ACs (12 BLOCKING + 1 ADVISORY + sub-ACs) | All ACs traceable to specific code paths in §Decision §2; see `tests/unit/economy/` + `tests/integration/economy_save_roundtrip_test.gd` |
| `design/gdd/dungeon-run-orchestrator.md` §D.1 `_attribute_kill_gold` | Orchestrator applies LOSING + MATCHUP before calling `Economy.add_gold` | §Decision §5 `economy_reads_losing_run_state` forbidden pattern; architecture diagram call direction |
| `design/gdd/dungeon-run-orchestrator.md` §D.2 `_attribute_floor_clear_bonus` | Orchestrator applies LOSING before calling `Economy.try_award_floor_clear` | §Decision §5 + §2 `try_award_floor_clear` accepts already-post-factor amount |
| `design/gdd/dungeon-run-orchestrator.md` §C.6 layer-3 idempotency | Economy's `floor_clear_bonus_credited` ledger is layer 3 of the three-layer idempotency model | §Decision §2 `try_award_floor_clear` monotonic-ceiling logic |
| `design/gdd/hero-roster.md` §D.1 `get_formation_strength` | Called per foreground tick + once per offline batch | §Decision §2 `compute_offline_batch` reads once + `_on_tick` indirect via Orchestrator drip pull |
| `design/gdd/save-load-system.md` §C.3 consumer contract | Economy implements `get_save_data` / `load_save_data` with 3-key persisted shape | §Decision §2 `get_save_data` / `load_save_data` verbatim |
| `design/gdd/game-time-and-tick.md` tick_fired + offline_elapsed | Economy subscribes to `tick_fired` in `_ready()`; `_on_tick` handler suppresses during replay | §Decision §2 `_ready` connects tick_fired; `_on_tick` guard |
| `docs/architecture/ADR-0002` credit-the-gap monotonic ledger | Inherited verbatim | §Decision §2 `try_award_floor_clear` + §5 six-row semantic table referenced |
| `docs/architecture/ADR-0011` HeroClass.tier / EnemyData.tier | Consumed by `recruit_cost` (class.tier lookup) + Orchestrator's `BASE_KILL[tier]` path | §Decision §2 `recruit_cost` DataRegistry.resolve path |
| `docs/architecture/ADR-0012` HeroRoster `get_formation_strength` + `get_copies_owned` | Consumed by drip formula (Orchestrator composes) + `recruit_cost` is class_id-scoped so roster query happens in Recruitment | §Decision §2 + §ADR Dependencies (ADR-0012 inheritance) |

## Performance Implications

| Metric | Before | Expected After | Budget |
|---|---|---|---|
| CPU (per `_on_tick` call, foreground) | N/A | ~5 µs: Orchestrator drip read + `add_gold` int-add + signal emit | Within AC-TICK-09 ADVISORY tick-dispatch budget (10 ms per tick with 20 Hz = 500 µs per tick before overage; Economy consumes ~5 µs) |
| CPU (per `add_gold` call) | N/A | ~3 µs: int-add + clamp branch + signal emit (or skip) | No budget — called ~1-5× per second foreground, ~1× per offline batch |
| CPU (per `try_spend` call) | N/A | ~2 µs: int-compare + int-subtract + signal emit | No budget — called on UI button tap (user-driven) |
| CPU (per `try_award_floor_clear` call) | N/A | ~5 µs: dict lookup + int-compare + `add_gold` + dict-write + signal emit | No budget — called 1-5× per save lifetime |
| CPU (per `recruit_cost` call) | N/A | ~15 µs: DataRegistry.resolve + pow() + floori() | No budget — called on UI render / tap (user-driven) |
| CPU (per `level_cost` call) | N/A | ~10 µs: cap-check + pow() + floori() | No budget — called on UI render (user-driven) |
| CPU (per `compute_offline_batch` call) | N/A | Part of AC-TICK-10 / AC H-10 < 500 ms total offline-replay budget | BLOCKING — AC H-10 Economy-side share ~100-150 ms of the 500 ms total (Orchestrator owns the bulk per ADR-0010) |
| Memory (Economy state) | N/A | `_gold_balance` (8B) + `_lifetime_gold_earned` (8B) + `_floor_clear_bonus_credited` (~48B × 5 entries max = 240B) + `_is_offline_replay` (1B) + `_cfg` (1 Resource ref, ~32B) ≈ 300 B | Negligible |
| Memory (`EconomyConfig.tres`) | N/A | ~1 KB loaded once at boot | Part of ADR-0006 total_loaded_memory budget |
| Save-file size (Economy fields) | N/A | ~100 B JSON (3 top-level keys + 5-entry ledger dict) | Part of ADR-0004 envelope budget |

**No new performance budget registered.** All costs fit inside ADR-0005 `tick_fired` dispatch budget, ADR-0004 `save_load_roundtrip` budget, and AC H-10's 500 ms offline-replay budget.

**`compute_offline_batch` breakdown** (share of AC H-10 500 ms budget):
- Closed-form drip multiply: <1 µs (one int multiply)
- Batch event iteration (Orchestrator hands over event list; Economy credits): ~1-2 ms for 20 000 kills (Economy side; Orchestrator dominates)
- `try_award_floor_clear` calls (up to 5 first-clears per replay): <50 µs total
- `RandomNumberGenerator` seed + draws (only for event cadence if ever needed on Economy side — currently Orchestrator owns): negligible
- Aggregate `gold_changed` emission after replay: <5 µs (one signal, no spin)
- **Economy share of 500 ms**: ~100 ms headroom (Orchestrator consumes ~300-400 ms; Economy + Roster updates + UI prep share the remainder)

## Migration Plan

**No migration needed.** No implementation exists yet. When the first Economy implementation story lands:

1. Create `src/gameplay/economy/economy_config.gd` per §Decision §1 (EconomyConfig extends GameData).
2. Create `assets/data/config/economy_config.tres` (EconomyConfig resource instance with the default values from §Decision §1 — all 26 GDD §G knobs pre-populated).
3. Create `src/gameplay/economy/economy.gd` per §Decision §2 (Economy extends Node autoload).
4. Register `/root/Economy` autoload at rank 3 in `project.godot` (per ADR-0003 rank table).
5. Add `/root/Economy` to SaveLoadSystem's `CONSUMER_PATHS` (already present in architecture.md per ADR-0004 §Consumer contract).
6. Implement the 4 CI tests enumerated in §Decision §5:
   - `tests/ci/economy_hardcoded_values_test.gd` — grep `src/gameplay/economy/economy.gd` for integer literals > 10 outside allowlist
   - `tests/ci/economy_losing_run_test.gd` — grep `src/gameplay/economy/*.gd` for `losing_run|losing|survived|hp_bonus_factor` outside comments
   - `tests/ci/economy_signal_suppression_test.gd` — grep Economy for `.emit(` calls without preceding `_is_offline_replay` guard
   - `tests/ci/economy_try_spend_negative_test.gd` — grep `src/*/` for `try_spend(-NUM, ...)` literal-negative patterns
7. Implement the unit test suite:
   - `tests/unit/economy/economy_add_gold_test.gd` — AC H-01 drip rate + sanity cap + signal suppression
   - `tests/unit/economy/economy_try_spend_test.gd` — AC H-05 insufficient + AC H-06 sufficient + AC H-12 zero
   - `tests/unit/economy/economy_try_award_floor_clear_idempotency_test.gd` — AC H-03 + AC H-14 + 5 sub-ACs
   - `tests/unit/economy/economy_recruit_cost_test.gd` — AC H-07 + boundary cases (tier 1/2, copies 0-3+)
   - `tests/unit/economy/economy_level_cost_test.gd` — AC H-08 (level 1-14 costs + cap-sentinel -1)
   - `tests/unit/economy/economy_display_abbreviation_test.gd` — AC H-13 threshold boundaries
   - `tests/unit/economy/economy_matchup_multiplier_test.gd` — AC H-04 (integration with Orchestrator's pre-applied multiplier)
8. Implement the integration test suite:
   - `tests/integration/economy_save_roundtrip_test.gd` — AC H-11 (3-key round-trip; 5-entry ledger preservation)
   - `tests/integration/economy_offline_replay_determinism_test.gd` — AC H-09 (foreground vs offline identical output)
   - `tests/integration/economy_offline_replay_performance_test.gd` — AC H-10 (< 500 ms wall-clock on min-spec)

**Rollback plan**: If post-MVP playtest reveals a contract change (e.g., V1.0 adds second currency; V1.0 adds per-hero gold generation; V1.0 changes cost curve shape from geometric to piecewise), the fix is a superseding ADR + GDD Pass-X + potentially a Save/Load `schema_version` bump if the 3-key save shape changes. The core shape (int64 balance + monotonic ledger + geometric cost curves + closed-form offline drip) is stable V1.0+ by design; the modular `EconomyConfig.tres` tuning surface absorbs most expected V1.0 tuning changes without ADR amendment.

## Validation Criteria

- [ ] `src/gameplay/economy/economy_config.gd` exists; declares `class_name EconomyConfig extends GameData`; has exactly the 26 `@export` fields per §Decision §1; has a `validate()` method returning `Array[String]`.
- [ ] `assets/data/config/economy_config.tres` exists; all 26 fields populated with GDD §G default values; passes `EconomyConfig.validate()` with empty error array.
- [ ] `src/gameplay/economy/economy.gd` exists; declares `class_name Economy extends Node`; autoload path `/root/Economy` registered at rank 3 in `project.godot`; zero-arg `_init` (implicit); declares 2 typed signals; has 3 persisted fields + 1 transient + 1 cached config ref.
- [ ] Public API: `add_gold`, `try_spend`, `try_award_floor_clear`, `recruit_cost`, `level_cost`, `compute_offline_batch`, `get_save_data`, `load_save_data` all present with exact signatures from §Decision §4.
- [ ] Read API: `get_gold_balance`, `get_lifetime_gold_earned`, `is_first_clear_awarded`, `get_floor_clear_credited` all present.
- [ ] Static helper `abbreviate_balance(balance, cfg)` present.
- [ ] `Economy` is on SaveLoadSystem `CONSUMER_PATHS` (already in architecture.md).
- [ ] CI asserts: `_gold_balance`, `_lifetime_gold_earned`, `_floor_clear_bonus_credited`, `_is_offline_replay`, `_cfg` are all underscore-prefixed (registry forbidden pattern `external_access_to_underscore_private` extended to Economy).
- [ ] CI asserts: no integer literal > 10 in `src/gameplay/economy/economy.gd` outside allowlist (`GOLD_SANITY_CAP = 1_000_000_000_000`, loop indices, array sizes) — forbidden pattern `hardcoded_balance_value_outside_economy_config`.
- [ ] CI asserts: no `losing_run` / `losing` / `survived` / `hp_bonus_factor` identifiers in `src/gameplay/economy/*.gd` outside comments — forbidden pattern `economy_reads_losing_run_state`.
- [ ] CI asserts: every `.emit(` in Economy methods preceded by `if not _is_offline_replay:` guard (except the single aggregate emit after `_is_offline_replay = false` in `compute_offline_batch`) — forbidden pattern `economy_signal_emission_during_offline_replay`.
- [ ] CI asserts: no literal-negative `try_spend(-NUM, ...)` call sites in `src/*/` — forbidden pattern `try_spend_with_non_positive_amount`.
- [ ] AC H-01 foreground drip test passes: tick_fired → add_gold(drip) → gold_changed emitted; exact int math with no float residue.
- [ ] AC H-02 kill bonus test passes: Orchestrator-driven `add_gold(52)` on tier-2 matchup kill; no Economy-side multiplier re-application.
- [ ] AC H-03 + AC H-14 + sub-ACs pass: `try_award_floor_clear` monotonic credit-the-gap per ADR-0002 six-row table.
- [ ] AC H-05 + AC H-06 pass: `try_spend` atomic insufficient-returns-false / sufficient-deducts-exactly.
- [ ] AC H-07 passes: `recruit_cost` geometric 1.8× escalation; verified for copies_owned ∈ {0, 1, 2, 3}.
- [ ] AC H-08 passes: `level_cost` geometric 1.6× + cap-sentinel -1 for current_level ≥ LEVEL_CAP.
- [ ] AC H-09 passes: foreground vs offline replay produces identical gold totals for identical (seed, ticks, formation) input.
- [ ] AC H-10 passes: `compute_offline_batch(576_000)` < 500 ms wall-clock on min-spec reference hardware.
- [ ] AC H-11 passes: save round-trip preserves all 3 keys + ledger dict shape + int keys; subsequent `try_award_floor_clear(3, 3000)` on restored instance credits the correct delta.
- [ ] AC H-12 passes: `try_spend(0, ...)` returns true without signal emission.
- [ ] AC H-13 ADVISORY: `abbreviate_balance` thresholds produce correct K/M/B/T output.

## Related Decisions

- **ADR-0001** (Mid-Run Formation Reassignment) — Orchestrator-side; does not affect Economy directly.
- **ADR-0002** (LOSING-clear monotonic credit) — Inherited verbatim for `try_award_floor_clear` + `floor_clear_bonus_credited` ledger. This ADR codifies the Economy-side implementation.
- **ADR-0003** (Autoload Rank Table Canonical) — Economy rank 3; zero-arg `_init`; forward-connect to TickSystem (rank 0) rank-safe. Inherits verbatim.
- **ADR-0004** (Save Envelope + HMAC Scheme) — Consumer contract (`get_save_data` + `load_save_data`); Economy is on full-envelope path (not heartbeat). Inherits verbatim.
- **ADR-0005** (Time System Dual-Clock Contract) — `tick_fired(tick_number: int)` subscription; no `_process(delta)` reads; offline_elapsed clamp. Inherits verbatim.
- **ADR-0006** (Data Loading Boot Scan Strategy) — `DataRegistry.resolve("config", "economy_config") -> EconomyConfig` resource load at `_ready()`; required-resource validator catches missing/invalid. Inherits verbatim.
- **ADR-0011** (Resource Schemas for HeroClass / EnemyData / Biome / Dungeon / Floor) — `HeroClass.tier: int` consumed by `recruit_cost` path. Inherits verbatim.
- **ADR-0012** (Hero Roster Mutation + HeroInstance Identity) — `HeroRoster.get_formation_strength()` + `HeroRoster.get_copies_owned(class_id)` read contracts consumed by Economy. Inherits verbatim.
- **ADR-0009** (Matchup Resolver DI + Majority Threshold) — Orchestrator applies MATCHUP_GOLD_MULTIPLIER per-kill before calling `Economy.add_gold`; Economy is stateless w.r.t. matchup. Indirect consumer.
- **ADR-0010** (Combat Resolver Snapshot + Parity) — `CombatBatchResult` aggregates for offline replay; Orchestrator hands over per-tier kill totals; Economy credits. Indirect consumer.
- **Future ADR-X02** (Offline batch chunking + snapshot schema) — consumes `Economy.compute_offline_batch(tick_budget) -> OfflineResult` signature; ADR-X02 will specify snapshot freeze lifetime + allowlist for Orchestrator-held `Array[HeroInstance]`.
- **Future Recruitment ADR** — consumes `Economy.recruit_cost(class_id, copies_owned)` + `Economy.try_spend(amount, reason)` in recruit-flow sequence.
- **Future Hero Leveling ADR** — consumes `Economy.level_cost(class_tier, current_level)` + `Economy.try_spend(amount, reason)` in level-up-flow sequence.
- **Future Economy GDD Pass** — may refine offline batch RNG seed derivation if V1.0 adds session-counter-based seed (for multi-offline-session determinism across back-to-back returns).
- `design/gdd/economy-system.md` — authoritative design source.
- `design/gdd/dungeon-run-orchestrator.md` §D.1 + §D.2 — Orchestrator's LOSING-factor + MATCHUP-multiplier application helpers.
- `design/gdd/hero-roster.md` §D.1 — formation-strength formula.
- `design/gdd/save-load-system.md` §C.3 — consumer contract.
- `design/gdd/game-time-and-tick.md` — tick_fired cadence + offline_elapsed clamp.
- `docs/registry/architecture.yaml` — will be extended with Economy interfaces + api_decisions + forbidden patterns per this ADR's Accept.

## Open Questions

- **OQ-1**: `LOSING_RUN_LOOT_FACTOR` lives in `economy_config.tres` but is read only by Orchestrator. Should it migrate to a `run_config.tres` for thematic clarity? Deferred — low-value refactor; both GDDs already cite `economy_config.tres` as the authoritative location.
- **OQ-2**: Should `abbreviate_balance` live on Economy as a static helper, or in a separate `src/ui/formatters/gold_formatter.gd`? Left to implementation discretion; ADR codifies the threshold constants as the single source of truth regardless of helper location.
- **OQ-3**: `compute_offline_batch` currently takes `tick_budget: int`. Should it also accept an `RNG seed override` for repeatable playtest scenarios? Deferred to V1.0 post-playtest; seed is currently `TickSystem.get_last_persist_ts() XOR tick_budget` which is deterministic for a given save.

## Specialist Review

### godot-gdscript-specialist (Step 4.5 engine pattern validation) — 2026-04-22

**Verdict**: APPROVE-WITH-NOTES.

**Notes issued**: 11 total (2 LOAD-BEARING folded in-place; 9 forward-looking / confirmatory retained for implementation-story awareness).

**LOAD-BEARING (folded in §Decision §2 + §Decision §4 + §Decision §5)**:

- **NOTE #8** — `economy_signal_emission_during_offline_replay` forbidden pattern description was ambiguous about the single aggregate `gold_changed.emit(...)` in `compute_offline_batch` that fires AFTER `_is_offline_replay = false`. A naive grep-based CI test would flag this legitimate post-replay notification as a violation. Fixed by explicitly exempting the `compute_offline_batch` body from the grep scope and restricting the check to the three guarded mutator methods (`add_gold`, `try_spend`, `try_award_floor_clear`) only. Inline fold annotation added at the forbidden-pattern definition.
- **NOTE #9** — `class OfflineResult:` inline class declaration was missing `extends RefCounted`. In Godot 4.x, inline classes without an explicit `extends` clause default to `extends Object`, which is NOT reference-counted and would require every caller to manually `.free()` the returned instance — producing a memory leak on every offline-replay return (called once per app resume). Fixed by adding `extends RefCounted` to both the §Decision §2 inline class definition and the §Decision §4 Key Interfaces repeat. Inline fold annotation added citing the NOTE reference.

**Forward-looking / confirmatory (retained for implementation-story awareness — not ADR-blockers)**:

- **NOTE #1** — `@export var BASE_DRIP: Array[int] = [0, 2, 4, 7, 12, 8]` is a valid typed-array export in Godot 4.4+ and renders in the Inspector as an expandable array of integer spinboxes. Sentinel-at-index-0 pattern works. Alternative `Dictionary[int, int]` exports are NOT inspector-exposed in 4.x, so the array-with-sentinel choice is the correct one for designer editability.
- **NOTE #2** — Autoload `_ready()` rank ordering (Economy rank 3 connecting to TickSystem rank 0 / DataRegistry rank 1 / SaveLoad rank 2 signals) is safe per `autoload.md` Claim 1 [VERIFIED]. All autoload nodes are in the tree before any `_ready()` fires; rank-ordered `_ready()` completion means rank-1 DataRegistry has finished its scan before Economy's `_ready()` calls `DataRegistry.resolve(...)`.
- **NOTE #3** — Typed signal syntax `signal gold_changed(new_balance: int, delta: int, reason: String)` + `signal first_clear_awarded(floor_index: int)` is correct Godot 4.x. `String` (not `StringName`) is the right choice for reason strings since they are human-readable, not hot-path-compared.
- **NOTE #4** — `Dictionary[int, int]` typed-dict syntax is stable Godot 4.4+. Precedent-verified via ADR-0009 (`Dictionary[StringName, int]`) and ADR-0012 (`Dictionary[int, HeroInstance]`).
- **NOTE #5** — Rank-3 Economy reading rank-14 Orchestrator state via `get_current_drip_per_tick()` inside `_on_tick` is SAFE. The `_on_tick` handler fires during the game loop, not during `_ready()`. ADR-0003 Amendment #1 explicitly distinguishes rank-independent runtime reads (SAFE) from rank-dependent `_ready()` state reads (FORBIDDEN). The architecture-diagram NOTE wording is accurate.
- **NOTE #6** — `floori(float(base) * pow(ratio, n))` is correct. `floori()` returns `int` with floor truncation (as opposed to `floor()` which returns `float`). The explicit `float(base)` cast is necessary because `pow()` expects float arguments. The chain produces `int` output matching GDD §D formulas.
- **NOTE #7** — The `_is_offline_replay` scoped-bool flag approach for signal suppression is the correct choice over `Object.set_block_signals(true/false)`. For a `Node` autoload, `set_block_signals` blocks ALL signals including Node lifecycle signals — broader than intended and carries risk of silently suppressing a consumer-added connection. The scoped flag is explicit, grep-testable, and side-effect-free on Node lifecycle.
- **NOTE #10** — Save/Load JSON int-key round-trip: ADR-0004 uses `var_to_bytes` binary serialization (not JSON), which preserves int keys in Dictionary natively. The defensive `int(k)` coercions in `load_save_data` are harmless for the binary path (no-op on already-int keys) and provide defense-in-depth for any future JSON-envelope debug export or migration path. Keep them.
- **NOTE #11** — CI grep checks for the 4 new forbidden patterns are implementable as stated (with the NOTE #8 scope clarification folded). False-positive mitigation: `economy_reads_losing_run_state` grep should exclude comments (`-v '^\s*#'` or equivalent); `hardcoded_balance_value_outside_economy_config` allowlist must include the two structural constants explicitly (`GOLD_SANITY_CAP`, `OFFLINE_REPLAY_REASON`).

**Engine-reference cross-check**: All claims reconcile with `autoload.md` Claim 1 + Claim 4 (both [VERIFIED] 2026-04-21 / 2026-04-22 via empirical probes). No new engine claims introduced by ADR-0013 that would require a new probe. All primitives (`extends Node` autoload, typed `Dictionary[K,V]`, typed `Array[T]`, typed signal payloads, `@export` typed arrays, `floori()`, `pow()`, `RandomNumberGenerator`, inline `class X extends RefCounted`, `DataRegistry.resolve`) are stable ≥ 4.4 with empirical precedent in ADR-0009 / ADR-0010 / ADR-0011 / ADR-0012 landed implementations.

**No mechanically-wrong engine claims flagged.** Both LOAD-BEARING items are code-block refinements (the `OfflineResult extends RefCounted` fix is a genuine memory-leak fix; the NOTE #8 CI-check scope clarification prevents a future test author from mis-implementing the grep), not architectural stance changes.

### technical-director (Step 4.6 TD-ADR gate) — SKIPPED

Review mode `production/review-mode.txt = solo`. Per `.claude/docs/director-gates.md` §TD-ADR, solo mode skips the gate. Note recorded per gate-skip protocol.

## Amendments

*(None yet.)*
