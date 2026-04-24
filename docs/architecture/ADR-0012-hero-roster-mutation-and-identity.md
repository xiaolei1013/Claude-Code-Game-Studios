# ADR-0012: Hero Roster Mutation API + HeroInstance Identity Stability

## Status

Accepted (promoted Proposed → Accepted 2026-04-22 as the same-day follow-up to `/architecture-decision` Step 4.5 APPROVE-WITH-NOTES; all specialist LOAD-BEARING notes folded in-place; sole dependency chain ADR-0003/0004/0006/0011 all Accepted; registry lockstep applied in the same session. Authored 2026-04-22 to cover the top unwritten Required ADR flagged by `/architecture-review 2026-04-22d` as "ADR-X03: Hero Roster mutation contract + HeroInstance identity stability"; unblocks Hero Roster system + ~26 TRs in the TR-hero-roster-001..030 gap pool; anchor for the forthcoming ADR-C01 Economy + future Recruitment/Leveling ADRs. Projected coverage post-Accept: ~81% (PASS-verdict candidate).)

## Date

2026-04-22

## Last Verified

2026-04-22

## Decision Makers

- Author (user) — final decision
- godot-gdscript-specialist — Step 4.5 engine pattern validation (see §Specialist Review below)
- technical-director — SKIPPED (review-mode.txt = solo; gate TD-ADR not invoked per Director-Gates §TD-ADR)

## Summary

Codifies the `HeroRoster` autoload's mutation API, `HeroInstance` identity contract, boot validation order, and the cross-consumer stability invariant that downstream systems MUST reference heroes by stable `instance_id: int` and NOT by cached `HeroInstance` object reference (object identity is ephemeral across save/load boundaries). Consumes `HeroClass` schema from ADR-0011; consumes DataRegistry resolve contract from ADR-0006; consumes Save/Load envelope from ADR-0004; inherits autoload rank 7 from ADR-0003. Ratifies `design/gdd/hero-roster.md` §C Rules 1-18 at ADR level with explicit CI structural invariants + one elevated forbidden pattern (`caching_heroinstance_reference_across_save_boundary`) that was implied by GDD Rule 4 + Rule 13 but never explicitly enumerated.

## Engine Compatibility

| Field | Value |
|---|---|
| **Engine** | Godot 4.6 |
| **Domain** | Core / Scripting (`class_name X extends RefCounted` pure data record; `class_name X extends Node` autoload; typed `Dictionary[int, HeroInstance]`; `Array[int]` formation slot state; signal declarations with typed payloads; `DataRegistry.resolve()` integration) |
| **Knowledge Risk** | **LOW** — all primitives (`RefCounted` subclassing, `Node` autoload, typed Dictionary/Array syntax, typed signals) are stable since Godot 4.0 or 4.4. No post-cutoff API introduced. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; `docs/engine-reference/godot/breaking-changes.md` (4.4+ typed-Dictionary; 4.0+ signal connect semantics); `docs/engine-reference/godot/modules/autoload.md` Claim 1 [VERIFIED] + Claim 4 [VERIFIED] (rank 7 autoload `_ready()` timing + zero-arg `_init`); ADR-0003 §Rank table (HeroRoster rank 7); ADR-0004 §Consumer contract (`get_save_data`/`load_save_data`); ADR-0006 §DataRegistry.resolve; ADR-0011 §HeroClass (`id: String`, `tier: int`, role/counter_archetype); `design/gdd/hero-roster.md` §C Rules 1-18, §D.1/D.2 formulas, §H acceptance criteria |
| **Post-Cutoff APIs Used** | `Dictionary[int, HeroInstance]` + `Array[int]` + `Array[HeroInstance]` typed container syntax (Godot 4.4+) — verified via ADR-0009 `Dictionary[StringName, int]` + ADR-0010 `Array[KillEvent]` live usage in codebase precedent. No other post-cutoff APIs. |
| **Verification Required** | None new. `HeroRoster` is a standard `Node` autoload at rank 7 (per ADR-0003); all RefCounted instance patterns mirror ADR-0009 `MatchupResolver` + ADR-0010 `CombatResolver` shape already verified via Pass-INIT-PROBE (2026-04-22). |

## ADR Dependencies

| Field | Value |
|---|---|
| **Depends On** | ADR-0003 (Accepted — provides HeroRoster autoload rank 7 + zero-arg `_init` constraint + SaveLoad consumer rank table + signal emission ordering invariants); ADR-0004 (Accepted — provides `get_save_data()` / `load_save_data()` consumer contract, full-envelope + heartbeat partial-envelope shapes, boot-validation-before-signal-emission guarantee); ADR-0006 (Accepted — provides `DataRegistry.resolve("classes", id) -> HeroClass \| null` contract used by `add_hero()` precondition + boot validation orphan check); ADR-0011 (Accepted — provides `HeroClass.id: String` consumed as `HeroInstance.class_id`, `HeroClass.tier: int` consumed by Recruitment/Leveling, `class_name HeroClass extends GameData` base class for DataRegistry resolve return type) |
| **Enables** | ADR-C01 (Economy — consumes `roster.get_formation_strength() -> float` per-tick + once-per-offline-replay-batch; consumes `get_copies_owned(class_id)` for recruit cost escalation); future Recruitment ADR (consumes `is_at_cap()` + `add_hero(class_id)` contract); future Hero Leveling ADR (consumes `get_hero(id)` + `set_hero_level(id, level)` contract); future Formation Assignment ADR (consumes `get_all_heroes()` + `set_formation_slot(slot, id)` contract); Combat implementation stories (CombatResolver receives `Array[HeroInstance]` per ADR-0010 signature — HeroInstance identity shape is now locked); Roster Screen + Recruit Screen + Formation Assignment Screen implementation stories (consume via signal-subscription + re-resolve-by-id pattern) |
| **Blocks** | Any story that mutates `_heroes` / `_formation_slots` / `_next_instance_id` directly (must use the 4-method mutation API); any story that caches a `HeroInstance` reference across a save-load cycle (must re-resolve via `get_hero(id)` after the `loaded` signal); any `HeroRoster` implementation story until this ADR is Accepted; epic authoring for Hero Roster system is blocked until Accept promotion |
| **Ordering Note** | Author AFTER ADR-0003 / ADR-0004 / ADR-0006 / ADR-0011 (all Accepted). Author BEFORE ADR-C01 (Economy `get_formation_strength` consumption) and any future Recruitment / Leveling / Formation-Assignment ADR. Parallel-safe with ADR-X02 (Offline snapshot — offline-replay consumes `roster.get_formation_strength()` once at batch start, does not hold HeroInstance refs per ADR-0009 § Offline replay zero-call invariant). |

## Context

### Problem Statement

`design/gdd/hero-roster.md` §C Rules 1-18 lock the Hero Roster system's schema, mutation API, boot validation order, and signal contract. Multiple downstream systems have already locked their interfaces against this GDD:

- **Save/Load** (ADR-0004) references `HeroRoster` as a rank-7 consumer with `get_save_data` / `load_save_data` contract (per Pass-5F-propagation rename 2026-04-21).
- **Combat Resolver** (ADR-0010) signature `compute_offline_batch(formation: Array[HeroInstance], floor: Floor, ...)` passes HeroInstance objects by value-per-call. Combat must NOT hold HeroInstance refs beyond a single call — statelessness invariant.
- **Matchup Resolver** (ADR-0009) signature `compute(formation: Array[HeroInstance], floor: Floor, ...) -> MatchupResult` with offline-replay zero-call invariant (pre-computed `matched_archetypes: Array[String]` frozen at dispatch).
- **Economy** (undesigned ADR-C01) reads `roster.get_formation_strength() -> float` per tick.
- **Recruitment / Hero Leveling / Formation Assignment** (undesigned) mutate roster via the 4-method API.
- **Roster / Recruit / Formation Assignment Screens** (undesigned Presentation) subscribe to `hero_recruited` / `hero_leveled` / `hero_removed` signals and must re-resolve selection state via `get_hero(instance_id)` — not hold cached HeroInstance refs.

Without an ADR codifying these stances:

1. **Downstream ADRs cannot author against a moving target.** ADR-C01 (Economy) needs the exact `get_formation_strength()` contract — range, clamp, empty-formation guard, per-call-vs-cached semantics — locked before authoring.
2. **Cross-save object-identity rule is implied but never stated.** GDD Rule 4 says `HeroInstance.to_dict()` produces exactly 5 fields and `from_dict()` restores them — implying that restored HeroInstances are NEW objects after load. But no GDD text explicitly forbids consumers from caching `HeroInstance` refs across save/load. The Roster Screen holding `selected_hero: HeroInstance` and surviving a mid-session reload (heartbeat persist then later restart) would silently refer to a stale object after `load_save_data()`. This needs an ADR-level forbidden pattern.
3. **CI invariants have no source-of-truth.** `_heroes.size() ≤ MAX_ROSTER_SIZE`, `_next_instance_id monotonic`, `instance_id != 0 for real heroes`, `formation_slots size == FORMATION_SIZE`, `HeroInstance has no public methods` — all GDD-implied, none ADR-stated. CI tests need a definitive list.
4. **Boot validation order is GDD-only.** Rule 16's 4-step sequence must run atomically inside `load_save_data()` before any signal fires. Downstream signal subscribers must not observe an inconsistent `_heroes` snapshot (e.g., orphan hero present + formation slot dangling). ADR codifies the ordering as a structural requirement.
5. **Stories are blocked.** `/architecture-review 2026-04-22d` counted ~26 TRs in the TR-hero-roster-001..030 pool as gap — all route to ADR-X03.

### Current State

- `design/gdd/hero-roster.md` (2026-04-21 Pass 5F-propagation applied): §C Rules 1-18 complete; §D formulas complete; §H 23 ACs locked.
- ADR-0003 places `HeroRoster` at autoload rank 7; SaveLoad consumer table (rank 2 → rank 3-14 forward-connect per Claim 1) includes HeroRoster at rank 7.
- ADR-0004 `get_save_data` / `load_save_data` consumer contract locked; boot-validation-before-signal-emission captured.
- ADR-0006 `DataRegistry.resolve("classes", id)` contract locked; rank 1 autoload.
- ADR-0011 `HeroClass extends GameData` schema locked; `id: String` + `tier: int` + role/counter_archetype fields consumed by HeroInstance via `class_id` id-string resolve pattern.
- `docs/registry/architecture.yaml` has HeroRoster listed as rank-7 autoload + SaveLoad consumer; no mutation API, identity contract, or forbidden-pattern entries yet.
- `design/gdd/economy-system.md` §C.6 locks the "offline replay reads `get_formation_strength()` once per batch" contract (provisional); this ADR ratifies.
- No `src/` implementation exists yet. This ADR is pure design codification.

### Constraints

- **GDD authority**: `hero-roster.md` §C Rules 1-18 is the authoritative source. This ADR ratifies verbatim + adds explicit CI invariants and the `caching_heroinstance_reference_across_save_boundary` forbidden pattern. No rule changes.
- **ADR-0003 inheritance**: HeroRoster is autoload rank 7. No rank change. Zero-arg `_init` (per ADR-0003 Amendment #3 + autoload.md Claim 4 [VERIFIED]).
- **ADR-0004 inheritance**: `get_save_data` / `load_save_data` consumer shape; signals suppressed during boot validation.
- **ADR-0006 inheritance**: `DataRegistry.resolve("classes", id)` is the only path to resolve `class_id` to `HeroClass`.
- **ADR-0011 inheritance**: `HeroClass.id` is the stable String key. `HeroClass.tier` is the input for Economy BASE_RECRUIT / BASE_LEVEL lookup (ADR-C01 territory).
- **ADR-0009 / ADR-0010 statelessness**: MatchupResolver + CombatResolver receive `Array[HeroInstance]` as value per call; neither caches refs beyond the call boundary. This ADR codifies the symmetric requirement on HeroRoster-side: HeroInstance refs are passed OUT of `get_formation_heroes()` per call; nothing in HeroRoster returns a reference whose lifetime is expected to exceed the next save/load boundary.
- **No RNG in stat math**: Only name-pool selection uses `randi()` (per GDD D.3). `add_hero()` otherwise deterministic. `_next_instance_id` monotonic. Boot validation deterministic (Dictionary-insertion-order stable per Godot 4.4+).
- **Single-threaded GDScript**: All mutations happen on the main thread. No concurrent-access invariants. Race condition E.9 documented but impossible under single-thread model.
- **Pillar 2 (every class feels distinct)**: Per-class copy count (`get_copies_owned`) drives Recruitment cost escalation. This is load-bearing for the Pillar 2 pricing curve — the API MUST NOT return a stale count, so it is computed on read from `_heroes` not cached.
- **No player-initiated removal in MVP**: `remove_hero()` is called only by Save/Load boot fallback (GDD Rule 16). V1.0 may add a player dismiss affordance.

### Requirements

- `HeroInstance` MUST be `class_name HeroInstance extends RefCounted` — NOT a `Resource`, NOT a `.tres`, NOT registered with DataRegistry.
- `HeroInstance` field set MUST be exactly the 5 fields in GDD Rule 2: `instance_id: int`, `class_id: String`, `display_name: String`, `current_level: int`, `xp: int`. No additional fields. No subclass overrides.
- `HeroInstance.instance_id`, `class_id`, `display_name` MUST be immutable after creation (conventionally enforced by `@onready` init + `_init()` that stores values to private vars; CI lint forbids post-init writes).
- `HeroInstance.current_level` MUST be mutable ONLY via `HeroRoster.set_hero_level()` — NOT by direct write.
- `HeroInstance.xp` MUST always be `0` in MVP (reserved for V1.0 XP progression; present in schema to avoid future save-format migration).
- `HeroInstance.to_dict() / from_dict()` MUST produce/consume exactly the 5-field shape (GDD Rule 4).
- `HeroRoster` MUST be autoload at rank 7 (per ADR-0003). `class_name HeroRoster extends Node`. Zero-arg `_init`.
- `HeroRoster._heroes: Dictionary[int, HeroInstance]`, `_formation_slots: Array[int]` (size exactly `FORMATION_SIZE = 3`), `_next_instance_id: int` (starts at 1). ALL underscore-prefixed. No public property exposure.
- `HeroRoster` mutation API: exactly 4 methods per GDD Rule 11 — `add_hero`, `remove_hero`, `set_hero_level`, `set_formation_slot`. No other mutation paths.
- `HeroRoster` MUST emit the 3 signals per GDD §C.3 Signals Emitted table: `hero_recruited(instance: HeroInstance)`, `hero_leveled(instance_id: int, old_level: int, new_level: int)`, `hero_removed(instance_id: int, class_id: String, display_name: String)` with typed payloads. Signals suppressed during boot validation per ADR-0004.
- `HeroRoster.get_formation_strength() -> float` MUST implement GDD §D.1 formula with empty-formation guard (returns `1.0` on empty formation without computing `avg_formation_level`); clamped output range `[1.0, 3.0]`.
- `instance_id` MUST be monotonic positive int, assigned by `_next_instance_id`, NEVER reused after `remove_hero()` (GDD Rule 13).
- `instance_id == 0` MUST be reserved as "no hero" sentinel for formation slot empty-state. Real heroes are assigned ids ≥ 1.
- Boot validation inside `load_save_data()` MUST run in the 4-step order per GDD Rule 16: (1) orphan-hero drop, (2) formation-slot clear, (3) cap trim, (4) `_next_instance_id` repair. All steps MUST complete BEFORE any signal emission (consistent with ADR-0004 guarantee).
- External consumers MUST reference heroes by stable `instance_id: int`. Caching a `HeroInstance` reference across a save/load boundary is CI-forbidden.
- `seed_first_launch_state()` runs from HeroRoster itself on `first_launch == true`; creates deterministic tutorial Warrior `instance_id = 1, display_name = "Theron", current_level = 1`, formation slot 0. Onboarding GDD does NOT inject heroes.
- `get_copies_owned(class_id)` computed on read from `_heroes` (O(N) scan bounded at `MAX_ROSTER_SIZE = 30`); no cached dict of per-class counts.
- `get_all_heroes()` default sort: BY_CLASS (registry declaration order: warrior → mage → rogue → V1.0 classes) → BY_LEVEL_DESC within class. Reinforces Pillar 2.
- Constants `MAX_ROSTER_SIZE = 30`, `FORMATION_SIZE = 3` MUST live in `assets/data/config/roster_config.tres` (Resource subclass loaded by DataRegistry); MUST NOT be hardcoded in GDScript.
- Inter-knob constraint `MAX_ROSTER_SIZE >= FORMATION_SIZE` MUST be validated at roster_config load time; fatal error if violated (GDD §G.1).

## Decision

### 1. `HeroInstance` — pure data record

```gdscript
# src/gameplay/roster/hero_instance.gd
class_name HeroInstance
extends RefCounted

# All five fields are locked by design/gdd/hero-roster.md Rule 2 + Rule 4.
# GDScript does not support true immutable fields — immutability is enforced
# by convention + CI lint + the absence of any public setter method.
# Only `current_level` has a mutation path, and it is via HeroRoster.set_hero_level()
# which writes _current_level directly (HeroRoster is the owning Node; HeroInstance
# is its data element and trusts its owner).

var _instance_id: int = 0      # 0 = uninitialized; real heroes are always >= 1
var _class_id: String = ""
var _display_name: String = ""
var _current_level: int = 1
var _xp: int = 0               # Reserved for V1.0; always 0 in MVP

# Read-only public accessors. GDScript has no 'readonly' keyword; property
# getters are the idiomatic substitute. No setters — see HeroRoster.set_hero_level.
var instance_id: int:
    get: return _instance_id
var class_id: String:
    get: return _class_id
var display_name: String:
    get: return _display_name
var current_level: int:
    get: return _current_level
var xp: int:
    get: return _xp

# Constructor-equivalent (HeroRoster.add_hero is the sole caller).
# Not _init(args) — HeroInstance is constructed via HeroInstance.new() (zero-arg)
# then configured via this static factory. Keeps _init zero-arg per the project-wide
# autoload_init_with_required_args forbidden pattern (ADR-0003 Amendment #3 extends
# the zero-arg _init discipline to value types instantiated from autoload _ready()
# paths as a consistency convention — not a language requirement here since
# HeroInstance is non-autoload, but matches the project idiom).
static func create(instance_id: int, class_id: String, display_name: String) -> HeroInstance:
    var h := HeroInstance.new()
    h._instance_id = instance_id
    h._class_id = class_id
    h._display_name = display_name
    h._current_level = 1
    h._xp = 0
    return h

# HeroRoster uses this to apply level changes (HeroRoster is the owner).
# Underscore-prefixed: external code MUST NOT call this.
func _set_level(new_level: int) -> void:
    _current_level = new_level

# Save/Load serialization — exactly the 5-field shape per GDD Rule 4.
func to_dict() -> Dictionary:
    return {
        "instance_id": _instance_id,
        "class_id": _class_id,
        "display_name": _display_name,
        "current_level": _current_level,
        "xp": _xp,
    }

static func from_dict(data: Dictionary) -> HeroInstance:
    var h := HeroInstance.new()
    h._instance_id = int(data.get("instance_id", 0))
    h._class_id = str(data.get("class_id", ""))
    h._display_name = str(data.get("display_name", ""))
    h._current_level = int(data.get("current_level", 1))
    h._xp = int(data.get("xp", 0))
    return h
```

### 2. `HeroRoster` — autoload rank 7

```gdscript
# src/gameplay/roster/hero_roster.gd
class_name HeroRoster
extends Node

# Autoload path: /root/HeroRoster (ADR-0003 rank 7).
# zero-arg _init per ADR-0003 Amendment #3 + autoload.md Claim 4 [VERIFIED].

# --- Typed signals (GDD §C.3 — suppressed during load_save_data per ADR-0004) ---
signal hero_recruited(instance: HeroInstance)
signal hero_leveled(instance_id: int, old_level: int, new_level: int)
signal hero_removed(instance_id: int, class_id: String, display_name: String)

# --- Private state (underscore-prefixed; external access CI-forbidden) ---
var _heroes: Dictionary[int, HeroInstance] = {}
var _formation_slots: Array[int] = []   # size FORMATION_SIZE; 0 = empty slot sentinel
var _next_instance_id: int = 1
var _orphaned_heroes: Array[Dictionary] = []  # transient — read by SaveLoad after load; cleared on next persist

# --- Suppression flag: set true during boot validation; guards signal emission ---
var _boot_validating: bool = false

# --- Config constants (loaded from assets/data/config/roster_config.tres at DataRegistry rank 1) ---
# Resolved at _ready() via DataRegistry.resolve("config", "roster_config").
# Values: MAX_ROSTER_SIZE = 30, FORMATION_SIZE = 3, SEED_HERO_CLASS_ID = "warrior",
# SEED_HERO_NAME = "Theron", SEED_FORMATION_SLOT = 0, name_pool_min_size = 20, etc.

func _ready() -> void:
    # Rank 7 — DataRegistry is rank 1, so DataRegistry.state == READY at this point
    # per ADR-0003 Claim 1 [VERIFIED] forward-connect pattern.
    var cfg := DataRegistry.resolve("config", "roster_config")  # RosterConfig resource
    _formation_slots.resize(cfg.FORMATION_SIZE)
    for i in range(cfg.FORMATION_SIZE):
        _formation_slots[i] = 0
    # SaveLoadSystem (rank 2) forward-connects to HeroRoster at its own _ready();
    # by the time this _ready fires, SaveLoad is already listening for HeroRoster signals.
    # SaveLoad invokes get_save_data / load_save_data via the consumer contract.

# --- Mutation API (GDD Rule 11) -------------------------------------------------

func add_hero(class_id: String) -> HeroInstance:
    # Sole caller: Recruitment System. Preconditions per GDD Rule 11.
    if is_at_cap():
        return null
    var class_data: HeroClass = DataRegistry.resolve("classes", class_id)
    if class_data == null:
        push_error("HeroRoster.add_hero: class_id '%s' does not resolve" % class_id)
        return null
    var new_id := _next_instance_id
    var display_name := _select_name_from_pool(class_id)
    var hero := HeroInstance.create(new_id, class_id, display_name)
    _heroes[new_id] = hero
    _next_instance_id += 1
    if not _boot_validating:
        hero_recruited.emit(hero)
    return hero

func remove_hero(instance_id: int) -> bool:
    # Sole caller in MVP: Save/Load boot fallback (Rule 16 step 1).
    # V1.0 may add player-initiated removal.
    if not _heroes.has(instance_id):
        return false
    var hero := _heroes[instance_id]
    var class_id := hero.class_id
    var display_name := hero.display_name
    _heroes.erase(instance_id)
    if not _boot_validating:
        hero_removed.emit(instance_id, class_id, display_name)
    return true

func set_hero_level(instance_id: int, new_level: int) -> bool:
    # Sole caller: Hero Leveling System.
    if not _heroes.has(instance_id):
        return false
    var hero: HeroInstance = _heroes[instance_id]
    var cfg := DataRegistry.resolve("config", "economy_config")  # owns LEVEL_CAP per Economy GDD
    var clamped := clamp(new_level, 1, cfg.LEVEL_CAP)
    if clamped != new_level:
        push_warning("HeroRoster.set_hero_level: %d out of range [1,%d], clamped to %d" %
                     [new_level, cfg.LEVEL_CAP, clamped])
    var old_level := hero.current_level
    hero._set_level(clamped)
    if not _boot_validating:
        hero_leveled.emit(instance_id, old_level, clamped)   # fires even on no-op (old==new)
    return true

func set_formation_slot(slot_index: int, instance_id: int) -> bool:
    # Sole caller: Formation Assignment System.
    if slot_index < 0 or slot_index >= _formation_slots.size():
        return false
    if instance_id != 0 and not _heroes.has(instance_id):
        return false
    # Auto-clear prior slot if same hero is already placed elsewhere (GDD Rule 11).
    if instance_id != 0:
        for i in range(_formation_slots.size()):
            if i != slot_index and _formation_slots[i] == instance_id:
                _formation_slots[i] = 0
    _formation_slots[slot_index] = instance_id
    # HeroRoster emits no signal for formation changes — Formation Assignment owns its own signals.
    return true

# --- Read API (GDD Rule 15) -----------------------------------------------------

func get_hero(instance_id: int) -> HeroInstance:
    return _heroes.get(instance_id, null)

func get_all_heroes() -> Array[HeroInstance]:
    # Default sort: BY_CLASS (registry declaration order) then BY_LEVEL_DESC.
    # See §Sort implementation below.
    var arr: Array[HeroInstance] = []
    arr.assign(_heroes.values())
    arr.sort_custom(_default_sort_comparator)
    return arr

func get_formation_heroes() -> Array[HeroInstance]:
    # Skips empty slots; preserves slot-index order.
    var arr: Array[HeroInstance] = []
    for id in _formation_slots:
        if id != 0 and _heroes.has(id):
            arr.append(_heroes[id])
    return arr

func get_copies_owned(class_id: String) -> int:
    # O(N) scan bounded at MAX_ROSTER_SIZE = 30. No cache.
    var n := 0
    for h in _heroes.values():
        if h.class_id == class_id:
            n += 1
    return n

func get_hero_count() -> int:
    return _heroes.size()

func is_at_cap() -> bool:
    var cfg := DataRegistry.resolve("config", "roster_config")
    return _heroes.size() >= cfg.MAX_ROSTER_SIZE

func get_formation_strength() -> float:
    # GDD §D.1 — Economy contract. Locked range [1.0, 3.0].
    # Empty-formation guard precedes the formula (avoids div-by-zero).
    var formation := get_formation_heroes()
    if formation.is_empty():
        return 1.0
    var sum_levels := 0
    for h in formation:
        sum_levels += h.current_level
    var avg := float(sum_levels) / formation.size()
    return clamp(1.0 + (avg - 1.0) * 0.2, 1.0, 3.0)

func get_formation_slot(slot_index: int) -> int:
    if slot_index < 0 or slot_index >= _formation_slots.size():
        return 0
    return _formation_slots[slot_index]

func has_hero(instance_id: int) -> bool:
    return _heroes.has(instance_id)

# --- Save/Load consumer contract (ADR-0004) -------------------------------------

func get_save_data() -> Dictionary:
    var heroes_arr: Array = []
    for id in _heroes:
        heroes_arr.append(_heroes[id].to_dict())
    return {
        "heroes": heroes_arr,
        "formation_slots": _formation_slots.duplicate(),
        "next_instance_id": _next_instance_id,
    }

func load_save_data(data: Dictionary) -> void:
    # Boot validation runs with signal suppression. Order per GDD Rule 16.
    _boot_validating = true
    _heroes.clear()
    _formation_slots.clear()
    _orphaned_heroes.clear()

    var cfg := DataRegistry.resolve("config", "roster_config")
    _formation_slots.resize(cfg.FORMATION_SIZE)
    for i in range(cfg.FORMATION_SIZE):
        _formation_slots[i] = 0

    _next_instance_id = int(data.get("next_instance_id", 1))

    # Step 1 — orphan drop: resolve class_id; drop unresolvable heroes.
    var raw_heroes: Array = data.get("heroes", [])
    for hd in raw_heroes:
        var hero := HeroInstance.from_dict(hd)
        var class_data := DataRegistry.resolve("classes", hero.class_id)
        if class_data == null:
            _orphaned_heroes.append({"instance_id": hero.instance_id,
                                      "class_id": hero.class_id,
                                      "display_name": hero.display_name,
                                      "reason": "class unresolvable"})
            push_warning("HeroRoster.load: dropping orphan %d (class_id '%s' not in DataRegistry)"
                         % [hero.instance_id, hero.class_id])
            continue
        if _heroes.has(hero.instance_id):
            push_error("HeroRoster.load: duplicate instance_id %d — second hero overwrote the first"
                       % hero.instance_id)
        _heroes[hero.instance_id] = hero  # Dictionary semantics — last write wins per GDD E.7

    # Step 2 — formation slot clear: any slot referencing a non-extant hero goes to 0.
    var raw_slots: Array = data.get("formation_slots", [])
    for i in range(_formation_slots.size()):
        if i < raw_slots.size():
            var slot_id := int(raw_slots[i])
            if slot_id == 0 or _heroes.has(slot_id):
                _formation_slots[i] = slot_id
            else:
                _formation_slots[i] = 0
                push_warning("HeroRoster.load: formation slot %d referenced non-extant hero %d; cleared"
                             % [i, slot_id])
        else:
            _formation_slots[i] = 0

    # Step 3 — cap trim: if over cap, remove highest-id heroes preserving lowest.
    var max_size := cfg.MAX_ROSTER_SIZE
    if _heroes.size() > max_size:
        # Specialist NOTE #3 (LOAD-BEARING) fold: Dictionary[int, T].keys() returns
        # Array[int] in Godot 4.4+; annotate explicitly to satisfy static-typing mandate.
        var sorted_ids: Array[int] = _heroes.keys()
        sorted_ids.sort()
        var excess := _heroes.size() - max_size
        for i in range(excess):
            var remove_id: int = sorted_ids[sorted_ids.size() - 1 - i]
            var removed := _heroes[remove_id]
            _orphaned_heroes.append({"instance_id": removed.instance_id,
                                      "class_id": removed.class_id,
                                      "display_name": removed.display_name,
                                      "reason": "roster cap reduced"})
            _heroes.erase(remove_id)
            push_warning("HeroRoster.load: cap trim removed hero %d (%s)" %
                         [remove_id, removed.display_name])
        # Re-clean formation slots — a slot may now reference a trimmed hero.
        for i in range(_formation_slots.size()):
            if _formation_slots[i] != 0 and not _heroes.has(_formation_slots[i]):
                _formation_slots[i] = 0

    # Step 4 — _next_instance_id repair.
    var max_id := 0
    for id in _heroes:
        if id > max_id: max_id = id
    if _next_instance_id <= max_id:
        _next_instance_id = max_id + 1

    _boot_validating = false
    # No hero_* signals fire during load. Save/Load reads _orphaned_heroes
    # after load_save_data returns and surfaces the player-facing notice.

# --- First-launch seed (ADR-0003 consumer ordering: runs from SaveLoad after first_launch detection) ---

func seed_first_launch_state() -> void:
    # Sole caller: SaveLoadSystem on first_launch == true.
    # Boot validation flag NOT set — this is a real player-visible recruit.
    # Specialist NOTE #10 (LOAD-BEARING) fold: guard against contract violation if
    # called on a non-empty roster (e.g., erroneous invocation after partial load).
    assert(_heroes.is_empty(), "seed_first_launch_state called on non-empty roster")
    var cfg := DataRegistry.resolve("config", "roster_config")
    var hero := HeroInstance.create(1, cfg.SEED_HERO_CLASS_ID, cfg.SEED_HERO_NAME)
    _heroes[1] = hero
    _next_instance_id = 2
    _formation_slots[cfg.SEED_FORMATION_SLOT] = 1
    hero_recruited.emit(hero)

# --- Orphan accessor (read by SaveLoad only) ---

func get_orphaned_heroes_and_clear() -> Array[Dictionary]:
    var arr: Array[Dictionary] = []
    arr.assign(_orphaned_heroes)
    _orphaned_heroes.clear()
    return arr

# --- Private helpers ---

func _select_name_from_pool(class_id: String) -> String:
    # Per GDD D.3 — uniform random from pool minus in-use names for this class.
    # Fallback to "{base} the {ordinal(N)}" if pool exhausted.
    var pool_resource := DataRegistry.resolve("name_pools", class_id)
    var pool: PackedStringArray = pool_resource.names if pool_resource else PackedStringArray()
    var in_use: PackedStringArray = PackedStringArray()
    for h in _heroes.values():
        if h.class_id == class_id:
            in_use.append(h.display_name)
    var available: Array[String] = []
    for name in pool:
        if name not in in_use:
            available.append(name)
    if available.is_empty():
        var base := pool[0] if pool.size() > 0 else "Hero"
        var cfg := DataRegistry.resolve("config", "roster_config")
        var N := get_copies_owned(class_id) + 1
        var ordinal := cfg.ordinal_words[N - 2] if N >= 2 and N - 2 < cfg.ordinal_words.size() else "Nth"
        return "%s the %s" % [base, ordinal]
    return available[randi() % available.size()]

func _default_sort_comparator(a: HeroInstance, b: HeroInstance) -> bool:
    # BY_CLASS (registry declaration order) then BY_LEVEL_DESC.
    if a.class_id != b.class_id:
        # Compare registry declaration order — DataRegistry.get_declaration_index per ADR-0006.
        return DataRegistry.get_declaration_index("classes", a.class_id) < \
               DataRegistry.get_declaration_index("classes", b.class_id)
    return a.current_level > b.current_level  # desc
```

### 3. Architecture diagram

```
        ┌────────────────────────────────────────────────────────┐
        │  HeroRoster (autoload rank 7; Node; zero-arg _init)    │
        │                                                          │
        │  _heroes: Dictionary[int, HeroInstance]                  │
        │  _formation_slots: Array[int]  (size 3; 0 = empty)       │
        │  _next_instance_id: int  (monotonic, never reused)       │
        │                                                          │
        │  Mutation API (4 methods; sole-caller contracts):        │
        │    add_hero(class_id) → HeroInstance | null              │
        │    remove_hero(id) → bool                                │
        │    set_hero_level(id, level) → bool                      │
        │    set_formation_slot(slot_index, id) → bool             │
        │                                                          │
        │  Signals (suppressed during load_save_data):             │
        │    hero_recruited(HeroInstance)                          │
        │    hero_leveled(id, old, new)                            │
        │    hero_removed(id, class_id, display_name)              │
        │                                                          │
        │  Read API (16 methods — see §Decision §2)                │
        │  Save/Load contract: get_save_data / load_save_data      │
        └────────────────────────────────────────────────────────┘
                │            ▲              │              ▲
                │            │              │              │
  (0)  seed_first_launch_state()
              (SaveLoad invokes on first_launch == true — emits hero_recruited)
                │            │              │              │
  (1)  class_id resolve at add_hero precondition
                ▼            │              │              │
        DataRegistry.resolve("classes", id) → HeroClass | null    (ADR-0006 + ADR-0011)
                             │              │              │
  (2)  Save/Load persist/restore            │              │
                             ▼              │              │
                SaveLoadSystem (rank 2) — consumer rank 7 entry
                  Signal-suppression during boot validation (ADR-0004)
                                            │              │
  (3)  Economy per-tick read                │              │
                                            ▼              │
                roster.get_formation_strength() → float [1.0, 3.0]
                  Economy reads per foreground tick; once per offline-replay batch
                  (ADR-C01 consumer; ADR-X02 offline snapshot freeze)
                                                           │
  (4)  Combat + Matchup per-call value pass                │
                                                           ▼
                Array[HeroInstance] passed by value (ADR-0009 + ADR-0010)
                  Resolvers do NOT hold refs; statelessness invariant
                                                                          │
  (5)  Screen signal subscribe + re-resolve by id                         │
                                                                          ▼
        RosterScreen / RecruitScreen / FormationAssignmentScreen (Presentation)
          - subscribe to hero_recruited/leveled/removed
          - selection state stored as instance_id: int — NOT HeroInstance ref
          - on any screen re-entry: re-resolve via get_hero(instance_id)

DAG direction:
  DataRegistry → HeroRoster (reads class templates, name pools, config)
  SaveLoadSystem ↔ HeroRoster (bidirectional via get_save_data / load_save_data)
  HeroRoster → Economy/Combat/Matchup (value-pass; no back-ref)
  HeroRoster → Presentation (signal broadcast; Presentation holds int ids only)

  NO CYCLES. NO consumer caches a HeroInstance reference across a save/load boundary.
```

### 4. Key Interfaces

All four mutation methods, all sixteen read methods, and the three typed signals listed in `§Decision §2` above. Additionally:

- **Orphan accessor**: `get_orphaned_heroes_and_clear() -> Array[Dictionary]` — called by SaveLoadSystem after `load_save_data` returns to construct the player-facing "X was removed from your guild" notice. Returns the transient `_orphaned_heroes` list and clears it.
- **Seed entry point**: `seed_first_launch_state() -> void` — called by SaveLoadSystem when `first_launch == true`. Constructs tutorial Warrior at `instance_id=1`, formation slot `SEED_FORMATION_SLOT`, emits one `hero_recruited` signal.

### 5. Cross-consumer stability invariant (ADR-elevated)

The GDD implied — but never explicitly stated — that `HeroInstance` object identity is NOT preserved across a save/load cycle. This ADR promotes the implicit rule to an explicit forbidden pattern:

> **`caching_heroinstance_reference_across_save_boundary`** — No consumer may store a `HeroInstance` reference in a field whose lifetime exceeds the next `load_save_data()` call. After load, all HeroInstance objects are newly constructed via `HeroInstance.from_dict` — any stale references refer to orphaned objects no longer in `_heroes`. Consumers MUST store `instance_id: int` and re-resolve via `get_hero(id)` on each render / each tick read / after the `loaded` signal.
>
> **Exceptions**: single-call-scope locals (`var hero := roster.get_hero(id)`; use + discard) are fine. Per-call `Array[HeroInstance]` passed to resolvers (ADR-0009 + ADR-0010) is fine — the array is transient to the call. The forbidden pattern targets field-scope caching in Node subclasses (UI screens, HUD overlays, Presentation layer).

CI enforcement: grep check in `tests/ci/heroroster_identity_test.gd` — scan `src/presentation/`, `src/ui/` for field-typed `HeroInstance` vars; allowlist specific Orchestrator-owned formation-snapshot fields (ADR-X02 will define the snapshot lifetime explicitly).

## Alternatives Considered

### Alternative 1: Store roster as `Array[HeroInstance]` instead of Dictionary

- **Description**: `var _heroes: Array[HeroInstance] = []`; look up by scanning.
- **Pros**: Simpler type; direct iteration; no `.values()` call.
- **Cons**: O(N) lookup instead of O(1); index-based refs become invalid after any `remove_hero()` call because indices shift. GDD Rule 7 explicitly chose Dictionary for this reason. Formation slots reference by stable id, not index — Array would force either parallel-id-array or storing HeroInstance refs directly in `_formation_slots` (breaks the id-based stability contract).
- **Rejection Reason**: GDD Rule 7 is the authoritative choice; ADR ratifies.

### Alternative 2: Promote `HeroInstance` to `class_name HeroInstance extends GameData`

- **Description**: HeroInstance becomes a `GameData` subclass (per ADR-0011 pattern); each hero is a `.tres` file persisted via DataRegistry; save file references heroes by `id: String`.
- **Pros**: Unified resource-persistence pattern; inspector-editable; automatic serialization via Godot's Resource system.
- **Cons**: ADR-0011 + ADR-0006 establish `GameData` as read-only static content loaded once at boot. Mutable player state (`current_level`, formation slots, `_next_instance_id`) does NOT belong in the `assets/data/` directory — it belongs in `user://save_slot_1.dat`. Runtime-creating `.tres` files at recruit time is an anti-pattern (Godot Resource cache would grow unbounded; `DataRegistry` would need a separate "runtime-created" bucket; hot-reload would conflict with save-time mutations). Save-file stability would require ADR-0006 schema_version bumps for every roster mutation — categorically wrong layering.
- **Rejection Reason**: Mutable player state and static content are categorically different; the ADR-0006 / ADR-0011 resource pattern is explicitly read-only (ADR-0011 forbidden pattern `mutating_loaded_resource` would forbid exactly this).

### Alternative 3: Use UUID strings instead of monotonic int `instance_id`

- **Description**: `instance_id: String` where each id is a generated UUID (e.g., `"550e8400-e29b-41d4-a716-446655440000"`). Provides global uniqueness without needing `_next_instance_id`.
- **Pros**: No counter state to persist; ids globally unique across installs; collision-safe for future cloud-sync or multi-save merge scenarios.
- **Cons**: Save-file size grows ~10x per hero reference (4 bytes vs 36 bytes); hand-debug inspection of save files harder; monotonic int gives stable chronological ordering (recruitment order = id order) which the UI uses for "most-recently-recruited" sort; UUID generation is non-trivial without a library. GDD Rule 13 explicitly rejects UUID for these reasons.
- **Rejection Reason**: Monotonic int is simpler, smaller, and sufficient for a single-save single-device MVP; cloud-sync is a V2.0+ concern.

### Alternative 4: Store formation state in a separate `FormationAssignment` autoload

- **Description**: Formation slots move to a distinct rank-11 autoload `FormationAssignment` owning `Array[int] _slots`. HeroRoster knows nothing about formations.
- **Pros**: Cleaner separation of concerns; FormationAssignment could become an independent `Save/Load` consumer; formation signals colocate with their ownership.
- **Cons**: `HeroRoster.get_formation_strength()` — the Economy contract — would need to cross-read FormationAssignment to iterate formation heroes. This adds a rank-7→rank-11 forward-read per tick (rank-7 HeroRoster reading rank-11 FormationAssignment state violates ADR-0003 rank invariant — rank-7 may only forward-connect to rank-8+ SIGNALS, not read rank-11 state directly). The only fix would be having Economy (rank 3) read both HeroRoster AND FormationAssignment each tick, doubling the read-path latency. GDD Rule 10 explicitly co-locates formation state with roster state specifically so `get_formation_strength()` can compute without cross-system reads.
- **Rejection Reason**: Cross-system read would violate ADR-0003 rank invariant; per-tick performance would degrade; Formation Assignment System (#17) owns the UI + assignment rules, not the state container. This split is already codified by the GDD.

### Alternative 5: `HeroInstance` as GDScript `Dictionary` (not a class)

- **Description**: No `class_name HeroInstance`; heroes are plain Dictionaries with `{"instance_id": int, "class_id": String, ...}` keys.
- **Pros**: Zero boilerplate; direct save/load (Dictionary already serializes).
- **Cons**: No type checking; typos in key names silently return `null`; no single place to refactor the 5-field shape; signal payloads become untyped Dicts (`hero_recruited(instance: Dictionary)` forces every subscriber to key-fetch fields). Violates project idiom (GDD Rule 1 + typed-GDScript coding-standards.md).
- **Rejection Reason**: Typed RefCounted class catches typos at parse time + yields smaller memory footprint than Dictionary + preserves the project's static-typing discipline.

## Consequences

### Positive

- **GDD Rule 11 mutation API locked at ADR level**: Every downstream system (Recruitment, Leveling, Formation Assignment) can cite this ADR for the sole-caller contracts. No more "which GDD owns this method" drift.
- **HeroInstance identity rule codified**: The `caching_heroinstance_reference_across_save_boundary` forbidden pattern prevents a whole class of UI bugs where a screen holds a stale HeroInstance after mid-session reload. Implicit invariant made explicit.
- **Boot validation order binding**: Rule 16's 4-step sequence is now an ADR requirement, not a GDD implementation note. `tests/ci/heroroster_boot_validation_test.gd` can drive the ordering directly from this ADR.
- **Signal contract locked**: 3 signals with typed payloads; suppression during boot validation per ADR-0004 inheritance. No more "does `hero_removed` fire during load?" ambiguity.
- **Economy contract locked**: `get_formation_strength() -> float` in range `[1.0, 3.0]` with empty-formation guard. ADR-C01 can author against this signature without reopening the GDD.
- **Combat + Matchup statelessness reinforced**: ADR-0009 + ADR-0010's "Resolvers do not hold HeroInstance refs" is now mirrored on the HeroRoster side — Roster's own API returns per-call `Array[HeroInstance]` values; consumers are structurally unable to cache.
- **First-launch seed shipped by Roster itself**: Onboarding GDD does not need to inject heroes — Roster has `seed_first_launch_state()` and owns its own initial state. Eliminates cross-system ordering coupling.
- **Pillar 2 structural support**: `get_copies_owned(class_id)` computed on read (no cached count) means recruit-cost escalation can never be out of sync with the true roster state. The Pillar 2 pricing curve is load-bearing and this ADR's contract prevents subtle caching drift.
- **CI invariants enumerated**: Every field-level + cross-system rule (`_heroes.size() ≤ MAX_ROSTER_SIZE`, `_next_instance_id monotonic`, `HeroInstance field set = 5`, etc.) has an explicit CI test target. Eliminates "test coverage that nobody wrote" gaps.

### Negative

- **HeroRoster.gd is ~300 lines** of GDScript (mutation API + read API + save/load contract + boot validation + helpers). This is appropriate (single-file for a single autoload's state machine) but larger than ADR-0009's MatchupResolver or ADR-0010's CombatResolver. Mitigation: no changes expected until V1.0; file is stable.
- **`HeroInstance` property getter pattern** (`var x: int: get: return _x`) is verbose but necessary for Godot 4.6 read-only semantics. Godot 5 may add a `readonly` keyword; MVP accepts the boilerplate.
- **Name pool CI test must cover the fallback path**: H-12 exercises the 26-Warriors case; `tests/unit/roster/name_pool_test.gd` needs to construct a pool with ≥25 entries and recruit past it. Test data weight (20-30 name strings × 3 classes × pool definition) is small but non-trivial.
- **`_orphaned_heroes` transient state**: lives in HeroRoster memory between `load_save_data()` and the first subsequent SaveLoadSystem read. If SaveLoadSystem fails to call `get_orphaned_heroes_and_clear()` (implementation bug), the list grows across subsequent loads. Mitigation: SaveLoadSystem must call clear on every load; CI test verifies.
- **`set_hero_level` no-op signal emission** (GDD E.5 + H-05): emits `hero_leveled(id, 15, 15)` on clamped no-op so Leveling System can detect refund opportunities. Open Question I.3 in the GDD asks whether Leveling would prefer silent no-op; this ADR adopts the emit-always stance per GDD default. Future Leveling ADR may revise this contract (would require an ADR amendment).
- **UI selection staleness still possible in MVP**: The `caching_heroinstance_reference_across_save_boundary` forbidden pattern is CI-enforced at build time, not runtime. A developer who writes `var _selected: HeroInstance` in a screen will fail CI, not get a runtime error. Mitigation: CI catches at PR time; no shipped bug.

### Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| A future Presentation screen caches `HeroInstance` in a field, breaking on save-reload | Medium | High (stale UI state, possibly crash on method call on stale RefCounted) | CI test `heroroster_identity_test.gd` greps all `src/presentation/*.gd` + `src/ui/*.gd` for field-typed `HeroInstance` vars; fails the build with allowlist exceptions |
| `_next_instance_id` overflow after many hundreds of thousands of recruits over a long save lifetime | Very Low | Low (GDScript int is 64-bit; would take >10^15 recruits — impossible) | None needed; int64 overflow is impossible in practice |
| Save-file hand-edited to produce `instance_id == 0` on a real hero | Low | Medium (formation slot sentinel collision; slot would be treated as empty) | Boot validation Step 1 rejects instance_id == 0 with `push_error` + orphan drop. New invariant added to Step 1: `if hero.instance_id == 0: drop as orphan with reason "instance_id 0 is reserved"` |
| Dictionary insertion order changes between Godot versions, breaking H-20's "last-write-wins" determinism | Low | Medium (H-20 becomes flaky across engine upgrades) | Godot 4.4+ docs guarantee insertion-order preservation; VERSION.md pin protects against accidental upgrade. H-20 asserts on logged `push_error`, not on which hero survives — semantics stable across engines |
| Name pool file missing or empty → `_select_name_from_pool` returns "Hero the Nth" | Low | Low (cozy fallback still works) | ADR-0006 validator: `name_pools/{class_id}.tres` has `.names.size() >= 20` at boot; load fails with ERROR state if violated |
| `roster_config.tres` missing → `_ready()` crashes on `cfg.FORMATION_SIZE` access | Low | High (HeroRoster _ready() fails; autoload chain breaks) | ADR-0006 required-resource validator: `config/roster_config.tres` loaded at DataRegistry rank 1; load fails with ERROR state if missing. HeroRoster's `_ready()` assumes READY state per ADR-0003 Claim 1 [VERIFIED] rank invariant |
| `set_hero_level` clamp silently loses intended level data if caller passes garbage (e.g., `set_hero_level(id, -999)`) | Low | Low (clamped to 1 with `push_warning`) | `push_warning` makes the error visible in development; H-05 test exercises the clamp path |
| Boot validation Step 3 trims the "wrong" heroes if a player deliberately keeps high-id (newest) heroes over low-id | Low | Medium (player perceives as "game deleted my favorites") | Documented cozy-framing: lowest-id = oldest = most-invested; GDD E.2 explicitly covers. UI surfaces the orphan notice listing removed heroes. Cap reduction is a balance-team patch that should be rare. |

## GDD Requirements Addressed

| GDD Document | Requirement | How This ADR Addresses It |
|---|---|---|
| `design/gdd/hero-roster.md` §C Rule 1 | `HeroInstance` is `class_name HeroInstance extends RefCounted`, not a Resource | §Decision §1 verbatim |
| `design/gdd/hero-roster.md` §C Rule 2 | 5-field HeroInstance schema with mutability rules | §Decision §1 + §Requirements list |
| `design/gdd/hero-roster.md` §C Rule 3 | HeroInstance exposes no mutation methods on itself | §Decision §1 — all setters are underscore-prefixed; `_set_level` is HeroRoster-only |
| `design/gdd/hero-roster.md` §C Rule 4 | `to_dict() / from_dict()` exact 5-field shape | §Decision §1 — methods mirror GDD verbatim |
| `design/gdd/hero-roster.md` §C Rule 5 + Rule 6 | Per-class name pool; exclude-in-use; fallback at exhaustion | §Decision §2 `_select_name_from_pool` helper |
| `design/gdd/hero-roster.md` §C Rule 7 | `_heroes: Dictionary[int, HeroInstance]` typed container | §Decision §2 state declaration |
| `design/gdd/hero-roster.md` §C Rule 8 | `MAX_ROSTER_SIZE = 30` hard cap from `roster_config.tres` | §Decision §2 `is_at_cap()` + `add_hero()` cap check |
| `design/gdd/hero-roster.md` §C Rule 9 | `get_copies_owned` computed on read, not cached | §Decision §2 explicit O(N) scan |
| `design/gdd/hero-roster.md` §C Rule 10 | `_formation_slots: Array` size `FORMATION_SIZE = 3`, sentinel `0` = empty | §Decision §2 state declaration + `set_formation_slot` |
| `design/gdd/hero-roster.md` §C Rule 11 | 4-method mutation API with sole-caller + emit contracts | §Decision §2 mutation API verbatim |
| `design/gdd/hero-roster.md` §C Rule 12 | `add_hero()` increments `_next_instance_id` AFTER successful insert | §Decision §2 `add_hero` sequence |
| `design/gdd/hero-roster.md` §C Rule 13 | `instance_id` monotonic positive int, never reused | §Decision §2 + §Cross-consumer stability invariant |
| `design/gdd/hero-roster.md` §C Rule 14 | `instance_id`/`class_id`/`display_name` set-once immutability | §Decision §1 property-getter pattern + `_set_level`-only mutation |
| `design/gdd/hero-roster.md` §C Rule 15 | 16-method read API signatures | §Decision §2 Read API block |
| `design/gdd/hero-roster.md` §C Rule 16 | 4-step boot validation order inside `load_save_data()` | §Decision §2 `load_save_data` verbatim |
| `design/gdd/hero-roster.md` §C Rule 17 | Per-mutation invariants (clamp, push_error, etc.) | §Decision §2 mutation API clamp + log paths |
| `design/gdd/hero-roster.md` §C Rule 18 | `seed_first_launch_state()` creates Theron at id 1, slot 0 | §Decision §2 `seed_first_launch_state` verbatim |
| `design/gdd/hero-roster.md` §D.1 | `formation_strength_factor` formula + empty-formation guard + clamp | §Decision §2 `get_formation_strength` verbatim |
| `design/gdd/hero-roster.md` §D.2 | `avg_formation_level = sum / size` helper | §Decision §2 inline in `get_formation_strength` |
| `design/gdd/hero-roster.md` §D.3 | Name pool selection (uniform random + exclude + fallback) | §Decision §2 `_select_name_from_pool` verbatim |
| `design/gdd/hero-roster.md` §E.1..E.12 | 12 edge cases | All covered by mutation API + boot validation paths; ACs H-03/H-04/H-05/H-06/H-08/H-09/H-10/H-12/H-20 exercise |
| `design/gdd/hero-roster.md` §H (23 ACs) | All 23 acceptance criteria | All ACs traceable to specific code paths in §Decision; see `tests/unit/roster/` + `tests/integration/roster_save_roundtrip_test.gd` |
| `design/gdd/save-load-system.md` §C.3 Consumer contract | HeroRoster implements `get_save_data` / `load_save_data`; signals suppressed during load | §Decision §2 `_boot_validating` flag + ADR-0004 inheritance |
| `design/gdd/save-load-system.md` Rule 4 | Save-file references resolve by stable id (int for HeroInstance) | §Cross-consumer stability invariant — `instance_id` is the cross-session identity |
| `design/gdd/hero-class-database.md` (ADR-0011) | `class_id: String` resolves to `HeroClass` via DataRegistry | §Decision §2 `add_hero` + `load_save_data` Step 1 orphan check |
| `design/gdd/economy-system.md` §C.6 | Offline replay reads `get_formation_strength()` once per batch | §Decision §Architecture diagram + §Positive Consequences (Economy contract locked) |
| `design/gdd/dungeon-run-orchestrator.md` §J | Formation snapshot frozen at dispatch; Orchestrator holds `Array[HeroInstance]` for run duration | §Cross-consumer stability invariant — Orchestrator snapshot is ADR-X02 territory; allowlisted from the forbidden pattern |
| `docs/architecture/ADR-0010-combat-resolver-snapshot-and-parity.md` | `Array[HeroInstance]` value-pass to `compute_tick_events` / `compute_offline_batch` | §Decision §Architecture diagram — per-call value pass; Resolvers are stateless |
| `docs/architecture/ADR-0009-matchup-resolver-di-and-majority-threshold.md` | `Array[HeroInstance]` value-pass; offline-replay zero-call (matched_archetypes pre-computed) | §Cross-consumer stability invariant — Resolvers do not cache refs |

## Performance Implications

| Metric | Before | Expected After | Budget |
|---|---|---|---|
| CPU (per `get_formation_strength()` call) | N/A | <50 µs p99 on Steam Deck min-spec (per GDD H-14) | ADVISORY — HeroRoster is not on a hot per-tick path beyond Economy's single read |
| CPU (per `add_hero()` call) | N/A | <200 µs (includes DataRegistry.resolve + name-pool scan) | No budget — called on player UI action (once per recruit) |
| CPU (per `load_save_data()` call) | N/A | <20 ms p99 for full 30-hero roster (boot validation 4 steps + from_dict × 30) | Rolls into ADR-0004 `save_load_roundtrip` 200 ms p99 BLOCKING budget |
| CPU (per `get_copies_owned()` call) | N/A | O(N) scan bounded at N=30; <10 µs typical | No budget — called by Recruit Screen on pre-recruit check |
| Memory (HeroRoster state) | N/A | ~300 bytes per HeroInstance × 30 max = ~9 KB; `_heroes` Dictionary overhead ~1 KB; `_formation_slots` + `_next_instance_id` ~50 bytes | Negligible |
| Memory (signals + suppression flag) | N/A | ~100 bytes | Negligible |

**No new performance budget registered.** All costs fit inside ADR-0004's `save_load_roundtrip` budget (for load path) and per-tick Economy budget (for `get_formation_strength` read).

**`get_formation_strength()` ADVISORY budget** (GDD H-14): 50 µs p99. Re-validate post-implementation. If GDScript signal/method overhead exceeds, loosen to 100 µs (per GDD I.9 Open Question). Not BLOCKING because the call is cheap — O(1) iteration over 3 formation slots.

## Migration Plan

**No migration needed.** No implementation exists yet. When the first HeroRoster implementation story lands:

1. Create `src/gameplay/roster/hero_instance.gd` per §Decision §1 field set + factory + to_dict/from_dict.
2. Create `src/gameplay/roster/hero_roster.gd` per §Decision §2 state + mutation API + read API + save/load contract + boot validation + helpers.
3. Register `/root/HeroRoster` autoload at rank 7 in `project.godot` (per ADR-0003 §Rank table).
4. Create `assets/data/config/roster_config.tres` (RosterConfig resource subclass with `MAX_ROSTER_SIZE = 30`, `FORMATION_SIZE = 3`, `SEED_HERO_CLASS_ID = "warrior"`, `SEED_HERO_NAME = "Theron"`, `SEED_FORMATION_SLOT = 0`, `name_pool_min_size = 20`, `ordinal_words = ["Second", "Third", ..., "Ninetieth"]`).
5. Create `assets/data/name_pools/warrior.tres`, `mage.tres`, `rogue.tres` (NamePool resource subclass with `names: PackedStringArray` of ≥20 entries per class). Writer GDD I.1 authors the cozy-register names pre-playtest.
6. Create `assets/data/name_pools/cleric.tres`, `ranger.tres`, `tactician.tres` (V1.0 stubs; required by ADR-0011 counter_archetype validators post-ADR-C01; minimum 20 names each).
7. Implement Save/Load consumer registration: SaveLoadSystem's `CONSUMER_PATHS` already includes `/root/HeroRoster` (per ADR-0004 §Consumer contract); `get_save_data` / `load_save_data` fire automatically.
8. Write test suite:
   - `tests/unit/roster/hero_instance_test.gd` — to_dict/from_dict round-trip + immutability attempts (verify no public setter path exists)
   - `tests/unit/roster/mutation_api_test.gd` — ACs H-02/H-03/H-04/H-05/H-06/H-15/H-19
   - `tests/unit/roster/read_api_test.gd` — ACs H-11/H-18/H-22/H-23
   - `tests/unit/roster/boot_validation_test.gd` — ACs H-08/H-09/H-10/H-17/H-20
   - `tests/unit/roster/name_pool_test.gd` — AC H-12 (exhaustion + fallback)
   - `tests/integration/roster_save_roundtrip_test.gd` — AC H-07 (30-hero round-trip)
   - `tests/ci/heroroster_identity_test.gd` — `caching_heroinstance_reference_across_save_boundary` grep check over `src/presentation/` + `src/ui/`
   - `tests/integration/roster_recruitment_stub_test.gd` — AC H-13 (stub Recruitment + stub Economy pre-check sequence)

**Rollback plan**: If post-MVP playtest reveals a mutation rule needs to change (e.g., V1.0 adds player-initiated `remove_hero`), the fix is a superseding ADR + GDD Pass-X + potentially a Save/Load `schema_version` bump if the save-dict shape changes. The core shape (RefCounted HeroInstance + Dictionary-keyed roster + monotonic instance_id + 4-method mutation API) is not expected to require rollback — it is stable V1.0+ by design.

## Validation Criteria

- [ ] `src/gameplay/roster/hero_instance.gd` exists; declares `class_name HeroInstance extends RefCounted`; has exactly 5 private underscore-prefixed vars (`_instance_id`, `_class_id`, `_display_name`, `_current_level`, `_xp`); has exactly 5 read-only property getters; has `create()` static factory + `to_dict()` + `from_dict()` static method; has one underscore-prefixed `_set_level(new_level: int) -> void` method and no other mutation methods.
- [ ] `src/gameplay/roster/hero_roster.gd` exists; declares `class_name HeroRoster extends Node`; autoload path `/root/HeroRoster` registered at rank 7 in `project.godot`; zero-arg `_init` (implicit); declares 3 typed signals `hero_recruited(instance: HeroInstance)`, `hero_leveled(instance_id: int, old_level: int, new_level: int)`, `hero_removed(instance_id: int, class_id: String, display_name: String)`; 4 mutation methods `add_hero`, `remove_hero`, `set_hero_level`, `set_formation_slot`; 16 read methods per §Decision §2; `get_save_data` + `load_save_data` + `seed_first_launch_state` + `get_orphaned_heroes_and_clear`.
- [ ] CI asserts: `_heroes`, `_formation_slots`, `_next_instance_id`, `_orphaned_heroes`, `_boot_validating` are all underscore-prefixed (registry forbidden pattern `external_access_to_underscore_private`).
- [ ] CI asserts: no `src/*/` file outside `src/gameplay/roster/` contains a field-typed `HeroInstance` declaration (forbidden pattern `caching_heroinstance_reference_across_save_boundary`) except the Orchestrator snapshot allowlist (exact path TBD by ADR-X02).
- [ ] CI asserts: `HeroInstance.new()` is called ONLY from `HeroInstance.create()` and `HeroInstance.from_dict()` — no other caller constructs HeroInstance directly (registry forbidden pattern `heroinstance_direct_construction_outside_factory`).
- [ ] CI asserts: no file outside `src/gameplay/roster/hero_roster.gd` mutates `_heroes`, `_formation_slots`, or `_next_instance_id` — grep for `_heroes[` + `_formation_slots[` + `_next_instance_id =` returns only the owning file.
- [ ] CI asserts: no file outside `src/gameplay/roster/hero_roster.gd` calls `hero._set_level(...)` — grep for `._set_level(` returns only the owning file.
- [ ] CI asserts: `HeroInstance` field set unchanged — grep the 5 var declarations; test fails if a 6th field is added without a schema_version bump.
- [ ] AC H-07 round-trip test passes: 10-hero save → load → all 5 fields per hero preserved + formation slots + `_next_instance_id` preserved + zero signals fired during load.
- [ ] AC H-08/H-09/H-10/H-17/H-20 boot validation tests pass in the specified step order.
- [ ] AC H-11 parametric test passes all 6 formation-strength cases with float equality ≤ 1e-6.
- [ ] AC H-12 name pool fallback test passes the 26-Warriors case.
- [ ] AC H-15 test passes: `remove_hero(id) + add_hero()` produces `_next_instance_id + 1`, not the removed id.
- [ ] AC H-14 performance test ADVISORY: `get_formation_strength()` p99 < 50 µs on Steam Deck baseline (or loosened to 100 µs per Open Question I.9).

## Related Decisions

- **ADR-0003** (Autoload Rank Table Canonical) — HeroRoster rank 7 + zero-arg `_init` invariant + signal-emission consumer ordering. This ADR inherits verbatim.
- **ADR-0004** (Save Envelope + HMAC Scheme) — Consumer contract (`get_save_data` + `load_save_data`); boot-validation-before-signal-emission; heartbeat partial-envelope shape (HeroRoster is NOT on the 5s heartbeat path — only on full-envelope persist). This ADR inherits verbatim.
- **ADR-0006** (Data Loading Boot Scan Strategy) — `DataRegistry.resolve("classes", id) -> HeroClass | null` used by `add_hero()` precondition + boot validation Step 1 orphan check; `DataRegistry.resolve("config", "roster_config")` + `DataRegistry.resolve("name_pools", class_id)` resource loads. Also provides the required-resource validator for `roster_config.tres` and per-class `name_pools/*.tres`.
- **ADR-0011** (Resource Schemas for HeroClass / EnemyData / Biome / Dungeon / Floor) — `HeroClass.id: String` consumed as `HeroInstance.class_id`; `HeroClass.tier: int` consumed by future Recruitment/Leveling ADRs via HeroRoster.
- **ADR-0009** (Matchup Resolver DI + Majority Threshold) — `Array[HeroInstance]` value-pass to `compute`; offline-replay zero-call invariant (matched_archetypes pre-computed from formation archetypes at dispatch, frozen in snapshot per ADR-X02). This ADR codifies the HeroRoster-side stability invariant.
- **ADR-0010** (Combat Resolver — Snapshot Shape + Foreground/Offline Parity) — `Array[HeroInstance]` value-pass to `compute_tick_events` + `compute_offline_batch`; CombatResolver statelessness. This ADR codifies the HeroRoster-side contract: formation is returned by value from `get_formation_heroes()` per call.
- **Future ADR-C01** (Economy state shape + recruit cost curve) — consumes `get_formation_strength()` per tick + `get_copies_owned(class_id)` per recruit cost calculation. This ADR locks both signatures.
- **Future ADR-X02** (Offline batch chunking + snapshot schema) — snapshot carries `formation: Array[HeroInstance]` frozen at dispatch. ADR-X02 must specify the snapshot lifetime and allowlist it from the `caching_heroinstance_reference_across_save_boundary` forbidden pattern.
- **Future Recruitment ADR** — consumes `is_at_cap()` + `get_copies_owned()` + `add_hero()`; enforces Recruitment pre-check sequence per GDD H-13.
- **Future Hero Leveling ADR** — consumes `get_hero(id)` + `set_hero_level()`; handles refund contract per GDD I.4 open question.
- **Future Formation Assignment ADR** — consumes `get_all_heroes()` + `has_hero()` + `get_formation_slot()` + `set_formation_slot()`; owns UI + assignment rules (Roster owns the state container per GDD Rule 10).
- `design/gdd/hero-roster.md` — authoritative design source.
- `design/gdd/save-load-system.md` §C.3 — consumer contract.
- `design/gdd/economy-system.md` §C.6 — offline-replay read contract.

## Specialist Review

### godot-gdscript-specialist (Step 4.5 engine pattern validation) — 2026-04-22

**Verdict**: APPROVE-WITH-NOTES.

**Notes issued**: 10 total (2 LOAD-BEARING folded in-place; 8 forward-looking retained for implementation-story awareness).

**LOAD-BEARING (folded in §Decision §2 code blocks)**:

- **NOTE #3** — `Dictionary[int, HeroInstance].keys()` returns `Array[int]` in Godot 4.4+; `load_save_data` Step 3 was declaring `var sorted_ids: Array = _heroes.keys()` (bare `Array`). Fixed by typing explicitly: `var sorted_ids: Array[int] = _heroes.keys()`. Matches project static-typing mandate (`.claude/docs/coding-standards.md`); prevents unsafe-cast warning. Inline comment added at fold site citing the NOTE reference.
- **NOTE #10** — `seed_first_launch_state()` hardcodes `_heroes[1] = hero` + `_next_instance_id = 2`, bypassing the monotonic increment path. If erroneously called on a non-empty roster, it silently overwrites `_heroes[1]`. Fixed by adding `assert(_heroes.is_empty(), "seed_first_launch_state called on non-empty roster")` as the first line of the method body. Inline comment added at fold site citing the NOTE reference.

**Forward-looking (retained for implementation-story awareness — not ADR-blockers)**:

- **NOTE #1** — `var x: int: get: return _x` property-getter pattern is idiomatic Godot 4.x substitute for missing `readonly`. No `@export` needed (HeroInstance is runtime-only). Single-line `get: return _x` is the cleanest form.
- **NOTE #2** — `static func create(...) -> HeroInstance` + `HeroInstance.new()` factory pattern is fully valid GDScript 4.x. Zero-arg `_init` is a consistency convention per ADR-0003 Amendment #3 (not language-required for non-autoload RefCounted).
- **NOTE #4** — Godot 4.6 does NOT type-check signal payloads at emit time. Signal parameter type annotations are documentation-only. Matches ADR-0009 + ADR-0010 idiom; no change needed.
- **NOTE #5** — `_boot_validating` flag pattern vs `Object.set_block_signals(true/false)`: either pattern is defensible. The flag's advantage is grep-visibility of suppression scope; `set_block_signals` is cleaner one-liner but blocks ALL signals. Implementation engineer may substitute during coding; no ADR-level contract change.
- **NOTE #6** — `float(sum_levels) / formation.size()` int→float cast is correct; GDScript 4 promotes `float / int` to `float`. No concern.
- **NOTE #7** — `in` operator on `PackedStringArray` works in 4.6; all operands in `_select_name_from_pool` are `String`, not `StringName`. ADR-0011 NOTE #5 StringName coercion concern does NOT apply here.
- **NOTE #8** — `DataRegistry.resolve()` at rank-7 `_ready()` has no race window: rank-1 `_ready()` fires before rank-7 `_ready()` per Claim 1 [VERIFIED]; ADR-0006 synchronous boot scan ensures READY state before rank-7's turn.
- **NOTE #9** — `Dictionary[int, HeroInstance].get(key, null)` returns `null` on missing key; `null` is valid for any reference type. Callers must null-check (which the ADR's consumer contract already requires).

**Engine-reference cross-check**: All claims reconcile with `autoload.md` Claim 1 + Claim 4 (both [VERIFIED] 2026-04-21 / 2026-04-22 via empirical probes at `/Users/xiaolei/work/godot-project/godot/`). No new engine claims introduced by ADR-0012 that would require a new probe. All primitives (`extends RefCounted`, `extends Node` autoload, typed `Dictionary[K,V]`, typed `Array[T]`, signal typed payloads, property getters, `Object.set_block_signals` as alternative) are stable ≥ 4.4 with empirical precedent in ADR-0009 / ADR-0010 / ADR-0011 landed implementations.

**No mechanically-wrong engine claims flagged.** Both LOAD-BEARING items are code-block refinements, not architectural stance changes.

### technical-director (Step 4.6 TD-ADR gate) — SKIPPED

Review mode `production/review-mode.txt = solo`. Per `.claude/docs/director-gates.md` §TD-ADR, solo mode skips the gate. Note recorded per gate-skip protocol.

## Amendments

*(None yet.)*
