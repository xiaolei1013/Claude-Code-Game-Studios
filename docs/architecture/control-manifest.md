# Control Manifest

> **Engine**: Godot 4.6 (GDScript)
> **Last Updated**: 2026-04-26
> **Manifest Version**: 2026-04-26
> **ADRs Covered**: ADR-0001, ADR-0002, ADR-0003 (Amendments #1–#4), ADR-0004, ADR-0005, ADR-0006, ADR-0007, ADR-0008, ADR-0009, ADR-0010, ADR-0011, ADR-0012, ADR-0013, ADR-0014
> **Status**: Active — regenerate with `/create-control-manifest` when ADRs change

`Manifest Version` is the date this manifest was generated. Story files embed this date when created. `/story-readiness` compares a story's embedded version to this field to detect stories written against stale rules. Always matches `Last Updated` — they are the same date, serving different consumers.

This manifest is a programmer's quick-reference extracted from all Accepted ADRs, `.claude/docs/technical-preferences.md`, and `docs/engine-reference/godot/`. For the reasoning behind each rule, see the referenced ADR.

---

## Foundation Layer Rules

*Applies to: autoloads, save/load, time system, data loading, scene/screen management, engine initialisation.*

### Required Patterns

**Autoload architecture (ADR-0003, Amendments #1–#3; ADR-0005; ADR-0009; ADR-0010)**
- **Init order is rank-ordered by the table in `docs/architecture/architecture.md` §Autoload Rank Table — the canonical source of truth.** — ADR-0003
- **Rank assignments (canonical):** rank 0 `TickSystem`; 1 `DataRegistry`; 2 `SaveLoadSystem`; 3 `Economy`; 4 `HeroClassDatabase`; 5 `EnemyDatabase`; 6 `BiomeDungeonDatabase`; 7 `HeroRoster`; 8 + 9 VACANT (MatchupResolver / CombatResolver are non-autoload RefCounted); 10 `FloorUnlockSystem`; 11 `FormationAssignment`; 12 `Recruitment`; 13 `HeroLeveling`; 14 `DungeonRunOrchestrator`; 15 `OfflineProgressionEngine`. — ADR-0003
- **Signal SUBSCRIPTION across any rank pair at `_ready()` is safe** — signal objects exist on Node instantiation per `autoload.md` Claim 1 [VERIFIED]. — ADR-0003 Amendment #1, ADR-0005
- **STATE READS at `_ready()`: only allowed if M < N** (a rank-N autoload may read state of rank-M where M < N, because lower-rank `_ready()` has already run). Same-rank and backward state reads at `_ready()` are forbidden. — ADR-0003
- **All cross-autoload calls AFTER all `_ready()` fires are unrestricted.** — ADR-0003
- **Adding/removing autoloads requires lockstep edit** of (a) `architecture.md` rank table, (b) `project.godot [autoload]`, (c) `SaveLoadSystem.CONSUMER_PATHS`, and (d) save schema_version bump if a save consumer. — ADR-0003
- **Autoload script `_init` (if declared) MUST have ZERO required parameters** (Claim 4 [VERIFIED]); all params must default. — ADR-0003 Amendment #3, ADR-0009
- **DI into Orchestrator uses lazy-default with public setters:** `set_combat_resolver(r)` + `set_matchup_resolver(r)` called before `_ready()`; `_ready()` lazy-constructs `DefaultCombatResolver` / `DefaultMatchupResolver` if field still null. — ADR-0003 Amendment #3, ADR-0009, ADR-0010

**SaveLoadSystem consumer wiring (ADR-0003, ADR-0004)**
- **`SaveLoadSystem.CONSUMER_PATHS`** is a hardcoded ordered `PackedStringArray` of exactly 6 entries: `/root/Economy`, `/root/HeroRoster`, `/root/FloorUnlock`, `/root/FormationAssignment`, `/root/Recruitment`, `/root/DungeonRunOrchestrator`. — ADR-0003
- **SaveLoadSystem MUST resolve consumers via per-call `get_node_or_null(path)`** with explicit nil-check + fatal assert; references NEVER cached. — ADR-0003

**Save envelope + HMAC (ADR-0004)**
- **Envelope layout**: `MAGIC ("LGLD" 0x4C4C474C44, 4 bytes) + VERSION u16 LE + FLAGS u16 LE + PAYLOAD_LENGTH u32 LE + UTF-8 JSON payload (XOR-masked) + 32-byte HMAC-SHA256`. — ADR-0004
- **Total file size** = 44 + PAYLOAD_LENGTH bytes; PAYLOAD_LENGTH lives inside the HMAC-protected region. — ADR-0004
- **Payload encoding**: UTF-8 JSON (NOT MessagePack, NOT `bytes_to_var`, NOT BSON). — ADR-0004
- **XOR mask seed** = `SHA256(MAGIC || VERSION || STATIC_SECRET_16_BYTES)`; mask repeats via `SHA256(seed || u32_le(chunk_index))` until PAYLOAD_LENGTH bytes; XOR-mask **before** HMAC. — ADR-0004
- **HMAC algorithm** = HMAC-SHA256 (RFC 2104) implemented in GDScript on `HashingContext.HASH_SHA256`; from-scratch wrapper ~30 lines. — ADR-0004
- **HMAC key derivation** = multi-part assembly + N=2 build-version rotation: `SHA256(PART_A XOR PART_B || PART_C || build_version_string)`; parts in different autoload scripts under non-suggestive names. — ADR-0004
- **`keys` array is fixed length N=2**: `keys[0]` = current build's key, `keys[1]` = prior build's key compiled into binary; on `keys[1]` success, queue immediate re-persist under `keys[0]`. — ADR-0004
- **Validation order on load**: MAGIC → VERSION → HMAC (deliberate; never reorder to HMAC-first). — ADR-0004
- **Pre-HMAC buffer allocation** uses `file_length - 44`, NOT PAYLOAD_LENGTH (Rule 2 DoS defense). — ADR-0004
- **HMAC-SHA256 implementation MUST pass all 7 RFC 4231 §4.2–4.8 test vectors bit-exactly** before any tamper AC runs (gate AC-SL-HMAC-01 BLOCKING). — ADR-0004
- **Atomic write order**: `save_slot_1.dat.tmp` → `flush()` → `DirAccess.rename()` → `save_slot_1.dat` → copy previous → `.bak`. iOS/Android fallback uses `.commit` marker. — ADR-0004
- **`_meta` namespace owned exclusively by SaveLoadSystem**; consumers MUST NOT read or write `_meta` fields. — ADR-0004
- **`_meta` fields**: `slot_index` (immutable post-creation), `save_sequence_number` (saturates at 2⁵³−1), `tamper_suspicious_count` (saturates at 10000), `backup_restore_events` (`PackedInt64Array`, hard cap 16 per persist). — ADR-0004
- **Adding a new `_meta` field requires a save VERSION bump.** — ADR-0004
- **No identifier in SaveLoadSystem or HMAC fragment autoloads may contain "key", "secret", or "hmac"** (CI grep enforced). — ADR-0004
- **STATIC_SECRET (16 bytes) MUST NOT participate in HMAC key derivation** (XOR-mask seeding and HMAC keying are architecturally disjoint). — ADR-0004
- **`FileAccess.store_*` calls (4.4+ return bool) MUST be asserted/checked**: `assert(file.store_buffer(bytes), …)`. — ADR-0004

**TickSystem — dual clock (ADR-0005)**
- **TickSystem autoload identifier = `TickSystem` (rank 0)**; architecture.md "GameTimeAndTick" label corrected in lockstep. — ADR-0005
- **`TICKS_PER_SECOND = 20`** is an architectural constant (NOT a tuning knob; NOT exposed as ProjectSettings/.tres). — ADR-0005
- **Wall Clock = `int(Time.get_unix_time_from_system())`** cast to int64 at exactly ONE call site (the TickSystem boundary). — ADR-0005
- **Sim Clock = integer accumulator pattern in `_process(delta)`**: `_tick_accumulator_seconds += delta; while ≥ _TICK_INTERVAL_SECONDS (0.05) → _sim_tick_counter += 1; tick_fired.emit(_sim_tick_counter)`. — ADR-0005
- **`tick_fired` MUST emit synchronously inside `_process`** — NEVER `call_deferred`, NEVER via `Timer`. — ADR-0005
- **`tick_fired` is foreground-only**: freeze on BG entry; preserve accumulator residual across pause. — ADR-0005
- **Offline replay path bypasses `tick_fired`**: `OfflineProgressionEngine` calls `consumer.compute_offline_batch(n)` directly. — ADR-0005
- **`offline_elapsed_seconds(seconds, cap_reached)`** is a one-shot signal fired exactly once per cold launch; in-process flag NOT persisted; BG↔FG cycles MUST NOT re-fire. — ADR-0005
- **Platform notification mapping**: `NOTIFICATION_APPLICATION_PAUSED` / `RESUMED` (mobile) AND `NOTIFICATION_WM_WINDOW_FOCUS_OUT` / `IN` (desktop); `NOTIFICATION_WM_CLOSE_REQUEST` triggers full-state graceful-exit persist. — ADR-0005
- **`flag_suspicious_timestamp_emitted(prev_ts, curr_ts)`** fires once per launch on the bool's false→true transition; session-scoped private bool `_flag_suspicious_timestamp` is distinct from the public signal. — ADR-0005
- **Only SaveLoadSystem may call `set_last_persist_ts(ts)` and `set_session_high_water(ts)` on TickSystem** (debug assert + convention). — ADR-0005
- **Heartbeat persist** (every 60s default) writes ONLY `{t_last_persist, t_session_high_water, sim_tick_counter}` (≤512 bytes); full-state persist only on graceful exit or scene-boundary trigger. — ADR-0005
- **SaveLoadSystem exposes `request_heartbeat_persist(time_fields: Dictionary)`** partial-envelope path; refines ADR-0004 full-envelope contract. — ADR-0005
- **Debug-only methods** (`debug_set_unix_time`, `debug_clear_unix_time`) MUST runtime-gate: `if not OS.is_debug_build(): return`. — ADR-0005

**DataRegistry — boot scan (ADR-0006)**
- **DataRegistry autoload identifier = `DataRegistry` (rank 1)**; use bare-identifier resolution `DataRegistry.registry_ready.connect(...)`. — ADR-0006
- **DataRegistry boot scan is eager + synchronous via `ResourceLoader.load(path)`** (NOT `load_threaded_request` for MVP). — ADR-0006
- **Deterministic load order**: `classes → enemies → biomes → dungeons → items → matchup` (PackedStringArray `ordered_categories`). — ADR-0006
- **Adding a new content category requires explicit edit to `DataRegistry.ordered_categories` AND `min_content_count`**; auto-discovery from directory presence FORBIDDEN. — ADR-0006
- **Content lives ONLY under `assets/data/{classes,enemies,biomes,dungeons,items,matchup}/`**; `.tres` is the only authored format. — ADR-0006
- **`@abstract class_name GameData extends Resource`** with `id: String` (snake_case, globally unique within content type) + `display_name: String`; subclasses MUST NOT redeclare these. — ADR-0006, ADR-0011
- **`registry_ready` signal fires exactly once per session** (LOADING→READY); `registry_error(reason, details)` fires on fatal load error; `hot_reload_complete(content_type)` is dev-only. — ADR-0006
- **State machine**: `UNLOADED → LOADING → READY | ERROR | HOT_RELOAD`; `ERROR` is terminal (game cannot proceed); SaveLoadSystem checks `DataRegistry.state == READY` before hydrating. — ADR-0006
- **Resources returned by `get_all_by_type()` / `resolve()` are immutable by convention**; consumers MUST NOT mutate `@export` fields (Godot resource cache returns the same object — mutation corrupts every cached holder). — ADR-0006
- **For mutable copies**, consumers MUST explicitly `template.duplicate()` (shallow) or `template.duplicate_deep()` (4.5+); `duplicate_deep()` does NOT cross `ExtResource()` boundaries. — ADR-0006
- **Cross-reference DAG MUST hold** (no cycles); `_validate_dag()` BFS-traverses post-load and triggers `ERROR` state on cycle detection. — ADR-0006
- **`resolve(content_type, id) -> Resource | null`** returns null on miss with WARN log in production, ASSERT in test builds when `missing_id_behavior == ASSERT`. — ADR-0006
- **`hot_reload(content_type)` runtime-gated by `OS.is_debug_build()`**; production no-op; never invoked from production code paths. — ADR-0006

**SceneManager — scene/screen orchestration (ADR-0007)**
- **Persistent root scene = `MainRoot.tscn` with four CanvasLayer children**: `PersistentHUDLayer` (layer=10, `PROCESS_MODE_ALWAYS`), `ScreenContainer` (Node, `PROCESS_MODE_PAUSABLE`), `TransitionLayer` (layer=100, `PROCESS_MODE_ALWAYS`), `OverlayLayer` (layer=110, `PROCESS_MODE_ALWAYS`). — ADR-0007
- **SceneManager autoload identifier = `SceneManager`**; rank position is implementation-detail (≥6, after DataRegistry); stays `UNINITIALIZED` until `DataRegistry.registry_ready` fires. — ADR-0007
- **`request_screen(screen_id, transition_type)` is the SOLE external API** for screen changes; `push_overlay(overlay_id, pause_on_open)` / `pop_overlay(overlay_id)` for modals. — ADR-0007
- **Four-state machine**: `UNINITIALIZED | IDLE | TRANSITIONING | PAUSED`. — ADR-0007
- **Every screen extends `Screen extends Control` with all four lifecycle hooks declared** (empty body OK): `on_enter()`, `on_exit()`, `on_pause()`, `on_resume()`. — ADR-0007
- **`scene_boundary_persist(reason)` fires before entering `dungeon_run_view` AND after exiting `victory_moment`** — no other transitions trigger it. — ADR-0007
- **On `save_failed` from SaveLoad, transition is ABORTED**; SceneManager stays on current screen; non-blocking modal with "Try Again / Stay Here" cozy copy (resolves OQ-3 hard-stop). — ADR-0007
- **Back-to-back transitions**: queue depth max 1; overwriting fires `push_warning` (NOT error). — ADR-0007
- **Modal overlay with `pause_on_open=true`** sets `get_tree().paused = true`; close sets `false`. TickSystem honors via `PROCESS_MODE_ALWAYS` + explicit `if get_tree().paused: return` guard. — ADR-0007
- **Pause uses counter-based `_modal_pause_count`** to prevent race-condition stuck-pause. — ADR-0007
- **Transition input-block via full-screen Control on TransitionLayer** with `mouse_filter = MOUSE_FILTER_STOP`; silent-drop policy (taps consumed + discarded, not queued). — ADR-0007
- **App backgrounded mid-transition**: in-progress transition completes BEFORE background handler runs. — ADR-0007
- **Tween for 5 standard transitions** (CROSS_FADE, SLIDE_*, FADE_TO_BLACK, PUSH_MODAL); `AnimationPlayer` exclusively for the CEREMONY transition. — ADR-0007
- **SceneManager MUST maintain `_active_transition_tween: Tween` reference** and `kill()` any valid prior reference before `create_tween()`. — ADR-0007
- **`reduce_motion` accessibility flag**: clamps standard transitions to 50ms; replaces ceremony with instant cut + reward number reveal; persisted (interim `user://settings.cfg`; migrates to Save/Load envelope when Settings GDD #30 lands). — ADR-0007

### Forbidden Approaches

- **Never reorder existing autoload ranks** — would silently break forward-only signal/state-read invariants. — ADR-0003
- **Never use same-or-backward state reads at `_ready()`** (rank-N reading rank-M state where M ≥ N) — uninitialized values. — ADR-0003
- **Never assume signal-emission consumer ordering beyond connection order** — rank coincidence is convention; rank reassignment can silently invert tick consumer order. — ADR-0003, ADR-0005
- **Never declare `func _init(...)` with required parameters on an autoload script** (`autoload_init_with_required_args`) — Godot calls `_init()` zero-arg; instantiation fails. — ADR-0003 Amendment #3, ADR-0009
- **Never cache SaveLoad consumer references in instance vars** — re-resolve via `get_node_or_null(path)` per persist boundary. — ADR-0003
- **Never let consumers self-register save participation** via `add_to_group("save_consumer")` or runtime registration. — ADR-0003
- **Never read or write `_meta` from a consumer** — `_meta` owned exclusively by SaveLoadSystem. — ADR-0004
- **Never use identifier substrings "key", "secret", or "hmac"** in SaveLoad/HMAC code paths — abstraction leak to decompiler attackers. — ADR-0004
- **Never let STATIC_SECRET participate in HMAC key derivation** — XOR mask seeding and integrity keying are architecturally separate. — ADR-0004
- **Never reorder validation to HMAC-first** — creates save-destruction DoS on N-1 fallback path. — ADR-0004
- **Never reference STATIC_SECRET as "providing secrecy"** in comments, names, or logs. — ADR-0004
- **Never use AES-GCM / libsodium GDExtension for save crypto in MVP** (rejected: disproportionate to casual-deterrent threat). — ADR-0004
- **Never derive HMAC key from per-machine `OS.get_unique_id()`** (rejected: legitimate-user UX bug — machine change = tamper modal). — ADR-0004
- **Never use `_process(delta)` value as input to economy / currency / loot / run-outcome math** (`process_delta_as_economy_input`). — ADR-0005
- **Never `call_deferred` `tick_fired` emission** (`deferred_tick_emission`) — synchronous ordering required. — ADR-0005
- **Never emit `tick_fired` during offline replay** (`tick_fired_during_offline_replay`) — offline path uses batch APIs. — ADR-0005
- **Never reset `_tick_accumulator_seconds` on pause entry** (`discarding_accumulator_residual_on_pause`). — ADR-0005
- **Never call `Time.get_unix_time_from_system()` outside TickSystem** (`wall_clock_read_outside_tick_system`) — single-call-site invariant. — ADR-0005
- **Never write to `TickSystem.set_last_persist_ts` / `set_session_high_water` from non-SaveLoad context** (`tick_system_timestamp_write_outside_save_load`). — ADR-0005
- **Never mutate a Resource returned by DataRegistry accessors** (`mutating_loaded_resource`) — corrupts every cached holder. — ADR-0006
- **Never call `.duplicate()` / `.duplicate_deep()` inside DataRegistry accessors** — accessor returns cached instance directly. — ADR-0006
- **Never call `ResourceLoader.load("res://assets/data/...")` directly from non-DataRegistry code** — all content access flows through DataRegistry. — ADR-0006
- **Never auto-discover content categories from directory presence** — explicit registration only. — ADR-0006
- **Never call `hot_reload(...)` from production code paths or UI affordances** — content-injection vector. — ADR-0006
- **Never call `SceneTree.change_scene_to_packed()` / `change_scene_to_file()`** or any equivalent (`direct_scene_tree_change_scene`) — all changes via `SceneManager.request_screen`. — ADR-0007
- **Never call `queue_free()` on a Screen instance or `add_child()` to ScreenContainer from outside SceneManager** (`screen_container_external_mutation`). — ADR-0007
- **Never add children to OverlayLayer directly from outside SceneManager** (`overlay_layer_external_mutation`) — use `push_overlay` / `pop_overlay`. — ADR-0007
- **Never write `get_tree().paused = true/false` from outside SceneManager modal API** (`get_tree_paused_external_write`). — ADR-0007
- **Never silently omit any of the four lifecycle hooks on a Screen subclass** — empty body OK; missing FORBIDDEN. — ADR-0007
- **Never assume `MOUSE_FILTER_STOP` cascades to children** — only `MOUSE_FILTER_IGNORE` cascades in 4.5+. — ADR-0007, ADR-0008

### Performance Guardrails

- **Save persist time**: <10 ms p95 PC / <50 ms p95 mobile — [BLOCKING via AC-SL-11 (mobile); ADVISORY (PC)]. — ADR-0004
- **Save load time**: <50 ms PC / <100 ms mobile — [ADVISORY]. — ADR-0004
- **Save file size**: <20 KB MVP / <200 KB V1.0 — [BUDGET]. — ADR-0004
- **Heartbeat envelope size**: ≤512 bytes — [BLOCKING via AC-TICK-11]. — ADR-0005
- **Offline replay total**: 576,000-tick worst case completes <500 ms on min-spec mobile — [BLOCKING AC-TICK-10]. — ADR-0005
- **Per-tick dispatch budget**: <1 ms PC / <5 ms mobile — [ADVISORY AC-TICK-09]. — ADR-0005
- **Boot scan time** (DataRegistry): <200 ms on min-spec mobile at MVP scale — [BLOCKING AC-DLS-07]. — ADR-0006
- **Total loaded content memory**: <400 KB MVP / <5 MB V1.0 (within 256 MB mobile ceiling) — [BUDGET]. — ADR-0006
- **Transition overhead** (SceneManager code path, excluding tween / DataRegistry / `_ready`): <5 ms on min-spec mobile — [BLOCKING AC H-10]. — ADR-0007
- **Zero memory leaks over 10 consecutive transitions** — [BLOCKING AC H-11]. — ADR-0007
- **Standard cross-fade**: 150 ms ± 10 ms — [BLOCKING AC H-01]. — ADR-0007
- **Touch feedback pulse**: begins within 16 ms of input receipt; 80 ms duration — [ADVISORY AC H-12]. — ADR-0007, ADR-0008
- **Scene-boundary persist**: aborted on `save_failed` (hard-stop) — [BLOCKING AC H-07]. — ADR-0007

---

## Core Layer Rules

*Applies to: matchup resolution, combat resolution, GameData resource schemas.*

### Required Patterns

**Matchup resolver (ADR-0009)**
- **`MatchupResolver` is `class_name MatchupResolver extends RefCounted`** — non-autoload, zero class-scope state, zero signals, no caches, no RNG, no time-dependent reads. — ADR-0009
- **`DefaultMatchupResolver extends MatchupResolver`** is the production subclass; tests extend `MatchupResolver` directly with spy/stub inner classes. — ADR-0009
- **All public methods on `MatchupResolver` are instance `func`, NOT `static func`.** — ADR-0009
- **`MatchupResult` value type**: `is_advantaged: bool` + `matched_archetypes: Array[String]` (sorted alphabetically, deduplicated, empty when `is_advantaged == false`, archetype strings only). — ADR-0009
- **Aggregation rule = strict majority (`n > N / 2` integer division)**; NOT boolean OR, NOT unanimity. — ADR-0009
- **Heroes whose `class_id` does not resolve via DataRegistry are EXCLUDED from both `n` and `N`.** — ADR-0009
- **Unknown archetype strings** (V1.0-reserved, typos, wrong-case) all return `{false, []}`; case-sensitive equality. — ADR-0009
- **Offline replay consults `snapshot.matched_archetypes.has(archetype)` directly**; ZERO calls to MatchupResolver methods AND ZERO calls to `DataRegistry.resolve("classes", *)` during replay. — ADR-0009

**Combat resolver (ADR-0010)**
- **`CombatResolver` is `class_name CombatResolver extends RefCounted`** — non-autoload, zero class-scope `var`, zero signals, no public `static func`. — ADR-0010
- **`DefaultCombatResolver extends CombatResolver`** is the production subclass; lazy-default constructed in Orchestrator `_ready()`. — ADR-0010
- **Two public entry points**: `emit_events_in_range(formation, floor, range_start_tick, range_end_tick, error_logger=Callable())` (foreground) and `compute_offline_batch(formation, floor, tick_budget, error_logger=Callable())` (offline). — ADR-0010
- **BOTH public entry points MUST call shared private helpers** `_formation_dps_approx`, `_ticks_per_loop`, `_kill_schedule_for_loop` — parity is structural. — ADR-0010
- **Five RefCounted value types**: `KillEvent`, `CombatTickEvents`, `CombatBatchResult`, `CombatRunSnapshot` (+ `MatchupResult` from ADR-0009). — ADR-0010
- **All value types extend RefCounted, use plain `var`** (not `@export var`), expose `equals(other) -> bool` deep-equality method. — ADR-0010
- **`CombatBatchResult.dict_equals(a, b)` static helper is the canonical correctness comparison**; key-by-key walk; hash-based equality FORBIDDEN. — ADR-0010
- **Float fields compared via `is_equal_approx`, never `==`.** — ADR-0010
- **Foreground `CombatTickEvents.kills` is per-event `Array[KillEvent]`**; offline `CombatBatchResult.kills_by_archetype: Dictionary[StringName, int]` + `kills_by_tier: Dictionary[int, int]` is aggregate-only (no per-event field on offline path). — ADR-0010
- **`error_logger: Callable` is per-call optional parameter**; NEVER stored on instance; default invalid `Callable()` falls through to `push_error`. — ADR-0010
- **`CombatRunSnapshot` is frozen after Orchestrator transitions out of DISPATCHING** (Rule 14 frozen-snapshot contract). — ADR-0010
- **Typed dictionaries `Dictionary[StringName, int]` + `Dictionary[int, int]` required** (Godot 4.4+ syntax). — ADR-0010

**Resource schemas (ADR-0011)**
- **All five GameData subclass schemas locked**: `HeroClass` 16 fields, `EnemyData` 13, `Biome` 7, `Dungeon` 4, `Floor` 7; subclasses extend `GameData` and inherit `id` + `display_name`. — ADR-0011
- **Every content field on a GameData subclass MUST be `@export`-decorated** (otherwise not surfaced / serialized). — ADR-0011
- **Archetype constant set**: `EnemyArchetypes extends RefCounted` at `assets/data/archetypes/enemy_archetypes.gd` with 6 const strings (`bruiser`, `caster`, `armored`, `beast`, `construct`, `incorporeal`); `MVP_SET` = 3, `ALL_SET` = 6; static `is_valid(s)` + `is_mvp(s)`. — ADR-0011
- **Role constant set**: `ClassRoles extends RefCounted` at `assets/data/roles/class_roles.gd` with 6 const strings (`tank`, `striker`, `precision`, `support`, `ranged`, `commander`); `ALL_SET` + `is_valid(s)`. — ADR-0011
- **`HeroClass.counter_archetype` and `EnemyData.archetype` MUST validate against `EnemyArchetypes.is_valid()`** (single source of truth). — ADR-0011
- **`HeroClass.role` MUST validate against `ClassRoles.is_valid()`.** — ADR-0011
- **`Biome.status` MUST be in `{"active", "planned_v1"}`.** — ADR-0011
- **`Floor.enemy_list: Array[Dictionary]`** with each element exactly `{enemy_id: String, count: int}` (NOT `Array[EnemyData]` inline refs). — ADR-0011
- **`Dungeon.biome_id` MUST resolve via `DataRegistry.resolve("biomes", biome_id)`** (DAG required). — ADR-0011
- **`Floor.enemy_list[].enemy_id` MUST resolve via `DataRegistry.resolve("enemies", enemy_id)`** (DAG required). — ADR-0011
- **`is_boss_floor == true` ⇔ at least one `enemy_list[i]` resolved EnemyData has `is_boss == true`**; cross-type validator [BLOCKING]. — ADR-0011
- **Archetype-distribution invariant**: for every active dungeon, floors 1-3 collectively cover all 3 MVP archetypes (`bruiser`, `caster`, `armored`); cross-type validator [BLOCKING]. — ADR-0011
- **Boss-uniqueness invariant**: exactly one floor per Dungeon has `is_boss_floor == true`. — ADR-0011
- **Validators run in `ordered_categories` sequence**; cross-type validators run AFTER all per-type validation completes; fail-fast. — ADR-0011
- **Validation failure actions**: fatal (duplicate id, DAG cycle, below-minimum count, unresolvable required cross-ref) → `ERROR` state; non-fatal (soft-limit overrun, asset-path empty) → `push_warning` + load-with-value-retained. — ADR-0011

### Forbidden Approaches

- **Never register `MatchupResolver` / `DefaultMatchupResolver` or `CombatResolver` / `DefaultCombatResolver` as `[autoload]`.** — ADR-0009, ADR-0010
- **Never declare class-scope `var` outside method bodies on `MatchupResolver` or `CombatResolver`** (`matchup_resolver_state_or_signal_addition`, `combat_resolver_state_or_signal_addition`). — ADR-0009, ADR-0010
- **Never declare `signal` on `MatchupResolver` / `CombatResolver`.** — ADR-0009, ADR-0010
- **Never use `static func` for public methods on resolvers** — GdUnit4 4.6 cannot mock statics. — ADR-0009, ADR-0010
- **Never call `MatchupResolver.resolve_*` or `DataRegistry.resolve("classes", *)` during offline replay loop** (`offline_replay_resolver_call`). — ADR-0009
- **Never use `Dictionary.hash() ==` for correctness comparisons** in `combat_resolver.gd` / `default_combat_resolver.gd` / `tests/unit/combat/` (escape hatch: `# HASH-OK: <justification>` comment). — ADR-0010
- **Never add a "fast path" to `emit_events_in_range` that skips `_kill_schedule_for_loop`** (`combat_shared_helper_routing_violation`) — breaks AC-COMBAT-10 parity. — ADR-0010
- **Never store `error_logger` as a CombatResolver instance field** (`error_logger_state_storage`) — per-call only. — ADR-0010
- **Never add an `Array[KillEvent]` field to `CombatBatchResult`** — offline path is aggregate-only. — ADR-0010
- **Never redeclare `id` or `display_name` on a GameData subclass** (`gamedata_inherited_field_redeclaration`) — silent shadowing. — ADR-0011
- **Never hardcode archetype string literals** (`"bruiser"`, `["bruiser","caster"]`) outside `enemy_archetypes.gd` (`archetype_string_hardcoded_outside_constant_set`). — ADR-0011
- **Never hardcode role string literals outside `class_roles.gd`** (`role_string_hardcoded_outside_constant_set`). — ADR-0011
- **Never read `Floor.expected_clear_time_seconds` to gate runtime behavior** (`expected_clear_time_seconds_as_runtime_gate`) — design-target QA-pacing only. — ADR-0011
- **Never declare a non-`@export` content field on a GameData subclass** (`gamedata_subclass_non_exported_content_field`) — silent loss on `.tres` load. — ADR-0011
- **Never use derive-from-filename ID assignment** (`filename_as_id`) — `id` is the stable cross-system key. — ADR-0011

### Performance Guardrails

- **`MatchupResolver.resolve_formation_matchup`** (N=3): ≈<10 µs/call; <200 ms / 10 000 calls CI; <50 ms / 10 000 calls Steam Deck — [ADVISORY H-14]. — ADR-0009
- **`CombatResolver.compute_offline_batch`** (576k-tick batch): ≤100 ms p95 CI / ≤200 ms p95 min-spec mobile — [BLOCKING AC-COMBAT-14]. — ADR-0010

---

## Feature Layer Rules

*Applies to: mid-run formation reassignment, first-clear reclaimable, hero roster, economy, offline replay + run snapshot.*

### Required Patterns

**Mid-run formation reassignment (ADR-0001)**
- **Mid-run `formation_reassignment_committed(new_formation: Array[HeroInstance])`** during `ACTIVE_FOREGROUND` or `ACTIVE_OFFLINE_REPLAY` transitions: `ACTIVE_* → RUN_ENDED("reassigned") → DISPATCHING(new_formation) → ACTIVE_FOREGROUND` (option (a) MVP lock). — ADR-0001
- **Per-dispatch idempotency flags reset on new RunSnapshot**: `floor_clear_emitted = false`, `loop_counter = 0`, `last_emitted_tick = dispatched_at_tick`. — ADR-0001
- **`RUN_ENDED → DISPATCHING` transition deep-copies new formation**: `formation.duplicate(true)` (matches DISPATCHING deep-copy invariant AC-ORC-08). — ADR-0001
- **`MID_RUN_REASSIGN_WARNING_ENABLED = true` tuning knob** fires UX confirmation dialog BEFORE the commit signal. — ADR-0001
- **Read/write signal split** (`formation_browse_opened` read-only vs `formation_reassignment_committed` write) enforced at Formation Assignment Screen boundary, not Orchestrator. — ADR-0001
- **Partial-loop progress on old dispatch is NOT credited on reassignment** (accepted trade-off). — ADR-0001

**First-clear reclaimable on LOSING (ADR-0002)**
- **Economy state replaces boolean `floors_cleared_bonus_awarded: Dictionary[int, bool]`** with monotonic integer `floor_clear_bonus_credited: Dictionary[int, int]` (key=floor_index, value=total credited). — ADR-0002
- **`try_award_floor_clear(floor_index, bonus_amount)` is credit-the-gap**: `already = dict.get(floor_index, 0); if bonus_amount <= already: return false; delta = bonus_amount - already; add_gold(delta); dict[floor_index] = bonus_amount; return true`. — ADR-0002
- **Monotonic ceiling**: per-floor credited total NEVER exceeds `FLOOR_CLEAR_BONUS[floor_index]`. — ADR-0002
- **LOSING→WIN→LOSING-re-entry sequence**: 250→250 = 500 total; further LOSING re-entry = 0 (delta 250 ≤ already 500). — ADR-0002
- **Orchestrator-side call path unchanged** (`floor_clear_emitted` per-dispatch flag still gates duplicate emissions within a dispatch). — ADR-0002
- **Orchestrator passes `attribute_floor_clear_bonus(floor_index, losing_run)`** = `floori(FLOOR_CLEAR_BONUS[i] × 0.5)` for LOSING, full for non-LOSING. — ADR-0002

**Hero roster — mutation + identity (ADR-0012)**
- **`HeroInstance` is `class_name HeroInstance extends RefCounted`** (NOT a Resource, NOT a `.tres`, NOT registered with DataRegistry). — ADR-0012
- **`HeroInstance` field set is exactly 5 fields**: `instance_id: int`, `class_id: String`, `display_name: String`, `current_level: int`, `xp: int` (always 0 in MVP). — ADR-0012
- **`instance_id`, `class_id`, `display_name` immutable after creation**; `current_level` mutable ONLY via `HeroRoster.set_hero_level()`. — ADR-0012
- **`HeroInstance.to_dict() / from_dict()`** produces/consumes exactly the 5-field shape. — ADR-0012
- **`HeroInstance.new()` may only be called from `HeroInstance.create()` and `HeroInstance.from_dict()`** (sanctioned static factories). — ADR-0012
- **`HeroRoster` is autoload rank 7**; `class_name HeroRoster extends Node`; zero-arg `_init`. — ADR-0012
- **HeroRoster state**: `_heroes: Dictionary[int, HeroInstance]`, `_formation_slots: Array[int]` (size `FORMATION_SIZE=3`, sentinel 0=empty), `_next_instance_id: int` (starts at 1). — ADR-0012
- **Mutation API = exactly 4 methods**: `add_hero(class_id)`, `remove_hero(instance_id)`, `set_hero_level(instance_id, new_level)`, `set_formation_slot(slot_index, instance_id)`. — ADR-0012
- **3 typed signals**: `hero_recruited(instance: HeroInstance)`, `hero_leveled(instance_id: int, old_level: int, new_level: int)`, `hero_removed(instance_id: int, class_id: String, display_name: String)`; suppressed during boot validation (`_boot_validating == true`). — ADR-0012
- **`get_formation_strength() -> float`** returns clamped `[1.0, 3.0]`; empty-formation guard returns `1.0` without computing avg. — ADR-0012
- **`instance_id` MUST be monotonic positive int**; NEVER reused after `remove_hero()`. — ADR-0012
- **`instance_id == 0` reserved as "no hero in this formation slot" sentinel**; real heroes ≥ 1. — ADR-0012
- **Boot validation inside `load_save_data()` runs in 4-step order**: (1) orphan-hero drop, (2) formation-slot clear, (3) cap trim, (4) `_next_instance_id` repair — ALL BEFORE any signal emission. — ADR-0012
- **External consumers reference heroes by stable `instance_id: int`**; `HeroInstance` references MUST NOT cross save/load boundary. — ADR-0012
- **`seed_first_launch_state()` runs from HeroRoster on `first_launch == true`**; creates Theron at `instance_id=1, current_level=1`, formation slot 0; emits one `hero_recruited`. — ADR-0012
- **`get_copies_owned(class_id)` computed on read from `_heroes`** (O(N) bounded at `MAX_ROSTER_SIZE=30`); no cache. — ADR-0012
- **Constants `MAX_ROSTER_SIZE=30`, `FORMATION_SIZE=3` live in `assets/data/config/roster_config.tres`**; never hardcoded; inter-knob constraint `MAX_ROSTER_SIZE >= FORMATION_SIZE`. — ADR-0012

**Economy — state + cost curves (ADR-0013)**
- **`Economy` is autoload rank 3**; `class_name Economy extends Node`; zero-arg `_init`. — ADR-0013
- **Economy state**: 3 persisted fields (`_gold_balance: int64`, `_lifetime_gold_earned: int64`, `_floor_clear_bonus_credited: Dictionary[int, int]`) + 1 transient (`_is_offline_replay: bool`). — ADR-0013
- **Public API** — 7 methods + 2 signals: `add_gold(amount, reason="credit")`, `try_spend(amount, reason)`, `try_award_floor_clear(floor_index, bonus_amount)`, `recruit_cost(class_id, copies_owned)`, `level_cost(class_tier, current_level)`, `compute_offline_batch(tick_budget) -> OfflineResult`, `get_save_data` / `load_save_data`; signals `gold_changed(new_balance, delta, reason)` + `first_clear_awarded(floor_index)`. — ADR-0013
- **Read API (no setters)**: `get_gold_balance()`, `get_lifetime_gold_earned()`, `is_first_clear_awarded(floor_index)`, `get_floor_clear_credited(floor_index)`. — ADR-0013
- **All tuning knobs live in `assets/data/config/economy_config.tres`** (`EconomyConfig extends GameData`); 26 knobs from GDD §G; no hardcoded balance values in `.gd`. — ADR-0013
- **Allowlisted structural constants in `economy.gd`**: `GOLD_SANITY_CAP = 1_000_000_000_000` and `OFFLINE_REPLAY_REASON = "offline_replay"`. — ADR-0013
- **`add_gold` semantics**: `amount < 0` → `push_error` + return; `amount == 0` → no-op; clamp `gold_balance + amount` to `GOLD_SANITY_CAP`; `lifetime_gold_earned` unbounded; emit `gold_changed` UNLESS `_is_offline_replay`. — ADR-0013
- **`try_spend` semantics**: `amount < 0` → `push_error` + return false; `amount == 0` → return true (no-op); insufficient gold → return false silently (no signal); else deduct + emit unless replay. — ADR-0013
- **`try_award_floor_clear` semantics** (ADR-0002 verbatim): range-guard `floor_index ∈ [1,5]`; negative-bonus guard; credit-the-gap; emit `first_clear_awarded(floor_index)` AT MOST once per floor per save lifetime (only when `already == 0`). — ADR-0013
- **`recruit_cost(class_id, copies_owned) = floori(BASE_RECRUIT[hero_class.tier] * pow(RECRUIT_RATIO, copies_owned))`**; resolves via DataRegistry; returns -1 on error. — ADR-0013
- **`level_cost(class_tier, current_level) = floori(BASE_LEVEL[class_tier] * pow(LEVEL_RATIO, current_level - 1))`**; returns -1 if `current_level >= LEVEL_CAP` (sentinel "past cap"). — ADR-0013
- **`compute_offline_batch(tick_budget)` semantics**: set `_is_offline_replay=true` at start; closed-form drip O(1); seeded RNG (`seed = TickSystem.get_last_persist_ts() XOR tick_budget`); set `_is_offline_replay=false` at end; emit ONE aggregate `gold_changed(final, total_delta, "offline_replay")`. — ADR-0013
- **Economy NEVER reads `losing_run` state**; Orchestrator applies `LOSING_RUN_LOOT_FACTOR` and `MATCHUP_GOLD_MULTIPLIER` in `_attribute_kill_gold` / `_attribute_floor_clear_bonus` BEFORE calling Economy. — ADR-0013
- **Tick subscription in `_ready()`**: `TickSystem.tick_fired.connect(_on_tick)`; handler skips work if `_is_offline_replay`. — ADR-0013
- **Every formula producing a fractional intermediate MUST be `floori()`-truncated** before adding to `_gold_balance` (no float accumulation across ticks). — ADR-0013
- **`OfflineResult` value type**: `class OfflineResult extends RefCounted` with `gold_earned: int`, `kills_by_tier: Dictionary[int, int]`, `floors_cleared: Array[int]`, `events_log: Array[Dictionary]`. — ADR-0013

**Offline replay + RunSnapshot (ADR-0014)**
- **`OfflineProgressionEngine` autoload rank 15**; `class_name OfflineProgressionEngine extends Node`; zero-arg `_init`; subscribes to `TickSystem.offline_elapsed_seconds` at `_ready()`. — ADR-0014
- **`RunSnapshot` is `class_name RunSnapshot extends RefCounted` in `src/core/run_snapshot.gd`**; 11 fields (`run_seed`, `dispatch_wall_ts`, `dispatch_tick`, `ticks_elapsed_in_run`, `floor_id`, `biome_id`, `formation_ids: Array[int]` size 3, `matched_archetypes: Array[String]`, `kills_so_far`, `total_damage_dealt`, `loops_executed`). — ADR-0014
- **RunSnapshot serialized via id-strings** (`floor_id`, `biome_id`); rehydrated via `DataRegistry.resolve("floors", floor_id)` / `DataRegistry.resolve("biomes", biome_id)`; formation rehydrated via `HeroRoster.get_hero(id)` per slot. — ADR-0014
- **Orphan-hero recovery**: if any `formation_ids[i] != 0` resolves to null, `_hydrate_run_snapshot` returns null, Orchestrator emits `run_snapshot_discarded_orphan(removed_instance_id)`, refunds dispatch via Economy, sets `snapshot_discarded=true` in summary. — ADR-0014
- **Adaptive chunking**: `OFFLINE_CHUNK_TARGET_WALL_MS=12`, initial=5000 ticks, min=500, max=50000, deadband ±25%, exponential smoothing ratio 0.6; yield via `await get_tree().process_frame` between chunks. — ADR-0014
- **`Economy._is_offline_replay` and `DungeonRunOrchestrator._is_offline_replay` set ONCE for whole batch**; aggregate signals fire AFTER both flags reset. — ADR-0014
- **Aggregate post-replay signal emission order**: (1) `Economy.gold_changed(final, total_delta, "offline_replay")`, (2) `Economy.first_clear_awarded(floor_index)` ×N, (3) `Orchestrator.floor_cleared_first_time(floor_index)` ×N, (4) `OfflineProgressionEngine.offline_rewards_collected(summary)` (last; triggers SceneManager transition). — ADR-0014
- **Time-gated UX**: silent for replays <100 ms estimated; cozy modal at ≥100 ms via `SceneManager.show_modal(_progress_modal)`; modal auto-dismisses on `offline_rewards_collected`. — ADR-0014
- **`OfflineProgressionEngine.offline_replay_progressed(fraction)`** is per-chunk UI-facing only; domain code MUST NOT subscribe. — ADR-0014
- **Use `Time.get_ticks_usec()`** (canonical 4.x Time singleton; `OS.get_ticks_*` deprecated 4.0+). — ADR-0014
- **No multi-thread parallelism for MVP offline replay** (no `WorkerThreadPool`); main-thread yield only. — ADR-0014
- **`OfflineSummary` value type lives at `src/offline/offline_summary.gd`**, `class_name OfflineSummary extends RefCounted`; 11 fields (`elapsed_seconds`, `cap_reached`, `ticks_replayed`, `kills`, `kills_by_tier`, `gold_earned`, `floors_cleared`, `snapshot_discarded`, `snapshot_discarded_reason`, `replay_wall_ms`, `chunks_executed`, `avg_chunk_wall_usec`). — ADR-0014
- **HeroInstance allowlist exception scope** = post-`_hydrate_run_snapshot` until either `offline_rewards_collected + run_ended` OR next save/load cycle; permitted ONLY at 3 sites: `CombatResolver.compute_offline_batch`, `CombatResolver.emit_events_in_range`, `MatchupResolver.resolve` (when `matched_archetypes` not frozen). — ADR-0014

### Forbidden Approaches

- **Never block (reject) intentional mid-run reassignment** (option (b) violates Pillar 3 cozy feel). — ADR-0001
- **Never use a deferred queue for mid-run reassignment in MVP** (option (c) deferred to V1.1). — ADR-0001
- **Never use boolean per-lifetime gate `floors_cleared_bonus_awarded: Dictionary[int, bool]`** (superseded by ADR-0002 monotonic credit). — ADR-0002
- **Never exempt floor-clear bonus from LOSING halving entirely** (Alternative 1 rejected; weakens LOSING penalty). — ADR-0002
- **Never cache `HeroInstance` reference in a field whose lifetime exceeds next `load_save_data()`** (`caching_heroinstance_reference_across_save_boundary`). — ADR-0012, ADR-0014
- **Never read or write `HeroRoster._heroes` / `_formation_slots` / `_next_instance_id` / `_orphaned_heroes` / `_boot_validating` from outside `hero_roster.gd`** (`hero_roster_private_state_external_access`). — ADR-0012
- **Never call `HeroInstance.new()` from outside `HeroInstance.create()` and `HeroInstance.from_dict()`** (`heroinstance_construction_outside_factory`). — ADR-0012
- **Never call `hero._set_level(...)` from outside `HeroRoster.set_hero_level()`** (`heroinstance_set_level_external_call`). — ADR-0012
- **Never assign `instance_id == 0` to a real hero** (sentinel-only). — ADR-0012
- **Never decrement or reset `_next_instance_id`** (monotonic invariant). — ADR-0012
- **Never add a 6th field to HeroInstance** without a superseding ADR + Save/Load schema_version bump + migration pass. — ADR-0012
- **Never directly mutate HeroRoster state from outside `hero_roster.gd`** (`hero_roster_direct_state_mutation`). — ADR-0012
- **Never hardcode any tuning knob value** (`BASE_DRIP`, `BASE_KILL`, `BASE_RECRUIT`, `BASE_LEVEL`, `FLOOR_CLEAR_BONUS`, `RECRUIT_RATIO`, `LEVEL_RATIO`, `MATCHUP_GOLD_MULTIPLIER`, `MATCHUP_DRIP_BONUS`, `LEVEL_CAP`, `LOSING_RUN_LOOT_FACTOR`, display thresholds) in `.gd` outside `economy_config.gd` (`hardcoded_balance_value_outside_economy_config`). — ADR-0013
- **Never let Economy read `Orchestrator.losing_run` / `survived` / `hp_bonus_factor`** (`economy_reads_losing_run_state`). — ADR-0013
- **Never emit `gold_changed` / `first_clear_awarded` while `_is_offline_replay == true`** (`economy_signal_emission_during_offline_replay`); EXEMPT: single aggregate `gold_changed.emit` AFTER `_is_offline_replay = false` in `compute_offline_batch`. — ADR-0013
- **Never call `Economy.try_spend(NEGATIVE_LITERAL, ...)`** (`try_spend_with_non_positive_amount`). — ADR-0013
- **Never let domain code (`src/core`, `src/domain`, `src/gameplay`) subscribe to `OfflineProgressionEngine.offline_replay_progressed`** (`offline_replay_progressed_domain_subscriber`) — UI-only. — ADR-0014
- **Never field-type `HeroInstance` vars in `src/ui` / `src/presentation`** (`heroinstance_cache_outside_runsnapshot_allowlist`); CI grep `HeroInstance[\] ]` against `var|@export var` must return zero hits. — ADR-0014
- **Never expand `OfflineSummary` field set without schema_version bump + downstream consumer handler** (`offline_summary_field_set_expansion_without_version_bump`). — ADR-0014
- **Never emit per-chunk domain signals during offline replay** (`per_chunk_domain_signal_emission_during_offline_replay`) — single aggregate post-replay only. — ADR-0014
- **Never use `WorkerThreadPool` or other multi-thread parallelism for offline replay in MVP** (`worker_thread_pool_for_offline_replay_in_mvp`). — ADR-0014

### Performance Guardrails

- **Mid-run reassign overhead**: ~sub-millisecond (one extra state transition) — [BUDGET 16.6 ms frame]. — ADR-0001
- **Floor-clear ledger memory delta**: ~48 B/entry × ≤5 entries (`Dictionary[int,int]` vs `[int,bool]`) — [NEGLIGIBLE]. — ADR-0002
- **`get_formation_strength()`**: <50 µs p99 on Steam Deck min-spec — [ADVISORY H-14]. — ADR-0012
- **`load_save_data()`** (HeroRoster, full 30-hero): <20 ms p99 (rolls into ADR-0004 `save_load_roundtrip` 200 ms p99 BLOCKING). — ADR-0012
- **`compute_offline_batch`** (Economy, 576k-tick): completes within AC-TICK-10's 500 ms total budget; `gold_changed` suppression saves ~230 ms of signal dispatch. — ADR-0013
- **Offline chunk CPU wall time**: ≤16 ms/chunk on min-spec mobile — [BLOCKING AC-TICK-10]. — ADR-0014
- **Offline replay total wall-clock-with-yield**: ≤5 s for 8 h cap (ANR headroom) — [ADVISORY]. — ADR-0014

---

## Presentation Layer Rules

*Applies to: UI framework, parchment theme, dual-focus parity, rendering strategy.*

### Required Patterns

- **UI Framework is a NON-AUTOLOAD module**: single canonical `Theme` resource at `assets/ui/parchment_theme.tres` + static helper script `src/ui/ui_framework.gd` (`class_name UIFramework`). — ADR-0008
- **`MainRoot.theme = preload("res://assets/ui/parchment_theme.tres")`** cascades to all Control descendants. — ADR-0008
- **Single-focus-mode strategy**: keyboard/gamepad nav NOT implemented in MVP (per technical-preferences.md "Gamepad: None"); `focus_mode = FOCUS_NONE` set per Control instance via `UIFramework.suppress_keyboard_focus(root)` walking the tree (focus_mode is NOT theme-settable in Godot 4.6). — ADR-0008
- **Tap-target floor**: `MIN_TAP_TARGET_LOGICAL_PX = 44`; every interactive Control calls `UIFramework.assert_tap_target_min(self)` in its `_ready()` (debug-only `push_error`; production no-op via `OS.is_debug_build()`). — ADR-0008
- **Two fonts only**: `info_font.ttf` (Information, ≥16 px body) + `identity_font.ttf` (Identity, ≥24 px, used sparingly via theme variation "IdentityHeader" @32 px). — ADR-0008
- **Mouse hover state preserved via theme `:hover` pseudo-state on Controls** (mouse-focus path of 4.6 dual-focus); `:pressed` for tap state; `:focus` suppressed. — ADR-0008
- **Touch feedback** (1.05× scale, 80 ms, return in 1 frame) is per-screen opt-in via `UIFramework.wire_touch_feedback(control)` — NOT theme-encoded. — ADR-0008
- **`mouse_filter` defaults**: Button / TextureButton = STOP; Panel / PanelContainer = STOP (override to PASS for decorative); Label / RichTextLabel = PASS; Container subclasses = PASS; TextureRect (decorative) = IGNORE. — ADR-0008
- **Steam Deck rendering**: `project.godot` Display → `stretch/mode = "canvas_items"`, `stretch/aspect = "keep"` (or `"expand"`); reference 1920×1080. — ADR-0008
- **Localization-ready**: `AUTOWRAP_WORD_SMART` on Label theme defaults; `tr()` for all UI strings. — ADR-0008
- **Theme encodes Art Bible §4 palette as named theme constants**; no hardcoded `Color(...)` calls in UI code. — ADR-0008
- **Colorblind-safe icons (matchup)**: Lantern Gold upward triangle (advantage) + Parchment Cream circle (neutral) + Dusk Purple downward triangle (disadvantage). — ADR-0008

### Forbidden Approaches

- **Never use `Color(r, g, b)` literal in UI screen code** (`hardcoded_color_in_ui_code`) — all colors via theme. — ADR-0008
- **Never commit a third font file to `assets/ui/fonts/`** (`third_font_in_ui`) — Art Bible §7 two-font max. — ADR-0008
- **Never create per-screen Theme resources** (`per_screen_theme_resource`) — single canonical theme. — ADR-0008
- **Never add `focus_neighbor_*` graphs, `FOCUS_ALL` overrides, or keyboard-focus visuals in MVP** (`mvp_keyboard_navigation_implementation`) — single-focus-mode contract. — ADR-0008
- **Never assume `MOUSE_FILTER_STOP` cascades to children in 4.5+** (`mouse_filter_stop_recursive_assumption`) — only `IGNORE` cascades. — ADR-0008

### Performance Guardrails

- **UI render per frame**: theme lookup cached per-Control; negligible — [BUDGET 16.6 ms]. — ADR-0008
- **`assert_tap_target_min` cost**: ~10 µs debug-only; production no-op — [NOT IN PRODUCTION BUDGET]. — ADR-0008
- **Theme + font + texture memory**: ~1.3 MB persistent (~0.5 % of 256 MB mobile ceiling) — [BUDGET]. — ADR-0008

---

## Global Rules (All Layers)

### Naming Conventions

| Element | Convention | Example |
|---|---|---|
| Classes | PascalCase | `HeroRoster`, `DungeonRun` |
| Variables | snake_case | `current_gold`, `active_formation` |
| Signals/Events | snake_case past tense | `hero_recruited`, `dungeon_cleared`, `offline_rewards_collected` |
| Files | snake_case matching class | `hero_roster.gd` |
| Scenes/Prefabs | PascalCase matching root node | `HeroRoster.tscn` |
| Constants | UPPER_SNAKE_CASE | `MAX_ROSTER_SIZE`, `DEFAULT_OFFLINE_CAP_HOURS` |

Source: `.claude/docs/technical-preferences.md`.

### Performance Budgets

| Target | Value |
|---|---|
| Framerate | 60 fps PC + mobile; idle screens may drop to 30 fps backgrounded |
| Frame budget | 16.6 ms (60 fps); idle game = mostly UI rendering |
| Draw calls | <200/frame |
| Memory ceiling | 512 MB PC / 256 MB mobile |
| Test coverage minimum | 80 % for balance formulas + offline-progression math |

Source: `.claude/docs/technical-preferences.md`.

### Approved Libraries / Addons

- **None configured** (per technical-preferences.md "Allowed Libraries / Addons").
- **Test framework**: GdUnit4 (CI runner: `tests/gdunit4_runner.gd`, headless `godot --headless --script tests/gdunit4_runner.gd`).

### Forbidden APIs — Godot 4.6

Source: `docs/engine-reference/godot/deprecated-apis.md`.

- `TileMap` → use `TileMapLayer` (4.3).
- `VisibilityNotifier2D` / `3D` → use `VisibleOnScreenNotifier2D` / `3D` (4.0).
- `YSort` → use `Node2D.y_sort_enabled` (4.0).
- `Navigation2D` / `3D` → use `NavigationServer2D` / `3D` (4.0).
- `EditorSceneFormatImporterFBX` → use `EditorSceneFormatImporterFBX2GLTF` (4.3).
- `yield()` → use `await signal` (4.0).
- String-based `connect("signal", obj, "method")` → use `signal.connect(callable)` (4.0).
- `instance()` / `PackedScene.instance()` → use `instantiate()` (4.0).
- `get_world()` → use `get_world_3d()` (4.0).
- `OS.get_ticks_msec()` → use `Time.get_ticks_msec()` (4.0); also applies to `Time.get_ticks_usec` (ADR-0014).
- `duplicate()` for nested resources → use `duplicate_deep()` (4.5).
- `Skeleton3D.bone_pose_updated` → use `skeleton_updated` (4.3).
- `AnimationPlayer.method_call_mode` → use `AnimationMixer.callback_mode_method` (4.3).
- `AnimationPlayer.playback_active` → use `AnimationMixer.active` (4.3).
- String-based `connect()` → typed signal connections.
- `$NodePath` in `_process()` → `@onready var` cached reference.
- Untyped `Array` / `Dictionary` → `Array[Type]`, typed variables.
- `Texture2D` in shader parameters → `Texture` base type (4.4).
- Manual post-process viewport chains → `Compositor` + `CompositorEffect` (4.3+).
- `GodotPhysics3D` for new projects → Jolt Physics 3D (default 4.6). N/A — Lantern Guild is 2D.

### Engine Best Practices (Required Patterns)

Source: `docs/engine-reference/godot/current-best-practices.md`.

- **Use `@abstract` keyword (4.5+)** for abstract classes/methods — required for `GameData` base (ADR-0006, ADR-0011).
- **Use typed `Array[T]` / `Dictionary[K,V]`** for compiler optimizations — applied throughout (ADR-0009, ADR-0010, ADR-0012, ADR-0013, ADR-0014).
- **Use `duplicate_deep()` for nested resources** — aware it does NOT cross `ExtResource()` boundaries (ADR-0006).
- **Use the canonical `Time` singleton** (`Time.get_ticks_msec/usec`, `Time.get_unix_time_from_system`) — ADR-0005, ADR-0014.
- **Use `await signal`** (no `yield()`).
- **Use Callable-based signal connections** (no string-based).
- **Use `@onready var` for cached node references** (no `$NodePath` in `_process`).
- **2D physics = Godot Physics 2D** (Jolt is 3D-only).
- **Forward+ rendering**: Vulkan desktop, Metal macOS, D3D12 Windows (per 4.6 default).

### Cross-Cutting Constraints

Source: `.claude/docs/technical-preferences.md`, `.claude/docs/coding-standards.md`, registry.

- **No hover-only UI interactions** — mouse + touch parity.
- **No right-click-exclusive actions.**
- **No drag precision <24 logical pixels.**
- **No keyboard navigation in MVP** (single-focus-mode strategy — ADR-0008).
- **No gamepad support** (per technical-preferences.md).
- **All gameplay values must be data-driven (external config), never hardcoded** (coding-standards.md).
- **No autoload script with required-arg `_init`** (`autoload_init_with_required_args`) — global CI grep. — ADR-0003 Amendment #3.

---

## Notes on Coverage

**Carried open (non-blocking for implementation start):**
- ADR-0007 SceneManager autoload rank assignment (OQ-8) — recommended ≥6, no concrete rank yet.
- ADR-0007 `reduce_motion` persistence uses `user://settings.cfg` as interim — migrates to Save/Load envelope when Settings GDD #30 lands (OQ-7).
- Floor Unlock designer-UI `ProjectSettings` pattern deferred to V1.0 (runtime fallback works for MVP).

**Reconciled amendments applied:**
- ADR-0003 Amendment #1: signal subscription is rank-independent at `_ready()`; only state reads are constrained (M < N). Supersedes the original rank-invariant phrasing.
- ADR-0003 Amendment #3: autoload `_init` is zero-arg per Claim 4 [VERIFIED]; DI via lazy-default with public setters.
- Canonical names after GDD drift sweep: `EnemyData`, `DataRegistry`, `SceneManager`, `TickSystem`.

**ADR-C03 (Audio) and ADR-X04 (Recruitment)** are Required ADRs pending undesigned GDDs — out of scope for this manifest. Regenerate the manifest when those ADRs are accepted.
