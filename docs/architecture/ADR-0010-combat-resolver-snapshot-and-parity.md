# ADR-0010: Combat Resolver — Snapshot Shape + Foreground/Offline Parity Invariants

## Status

Accepted (2026-04-22c — promoted Proposed → Accepted per `/architecture-review 2026-04-22c` same-day follow-up. All dependencies (ADR-0003, ADR-0006, ADR-0009) Accepted; no content change at promotion. Originally authored 2026-04-22 in the same arc as ADR-0009 Accepted + Amendment #3 to cover the CombatResolver companion scope flagged by `/architecture-review 2026-04-22b` as the top unwritten Core/Feature gap.)

## Date

2026-04-22

## Last Verified

2026-04-22

## Decision Makers

- Author (user) — final decision
- godot-specialist — Step 4.5 engine pattern validation (see §Specialist Review below)
- technical-director — SKIPPED (review-mode.txt = solo; gate TD-ADR not invoked per Director-Gates §TD-ADR)

## Summary

`CombatResolver` is implemented as a non-autoload `class_name CombatResolver extends RefCounted` module at the vacated rank-9 slot (per ADR-0003 Amendment #2). The production subclass `DefaultCombatResolver` is lazily constructed inside `DungeonRunOrchestrator._ready()` via `DefaultCombatResolver.new()` — IF `_combat_resolver` is still null at `_ready()` time. Tests pre-inject spy subclasses via `orchestrator.set_combat_resolver(spy)` BEFORE `_ready()` fires. The DI seam (setter + lazy-default + `_init` zero-arg) is codified at ADR level by **ADR-0009** — this ADR re-uses that seam verbatim and does not duplicate it.

This ADR's **new** scope covers the **Combat-side structural contracts** that ADR-0009 leaves open:

1. **Five RefCounted value types** — `KillEvent`, `CombatTickEvents`, `CombatBatchResult`, `CombatRunSnapshot`, with `MatchupResult` (from ADR-0009) consumed per-enemy inside the kill-schedule computation. Each value type exposes an `equals(other) -> bool` deep-equality method used by AC-COMBAT-01/10 determinism gates.
2. **Two public entry points** — `emit_events_in_range(formation, floor, start, end) -> CombatTickEvents` (foreground) and `compute_offline_batch(formation, floor, tick_budget) -> CombatBatchResult` (offline) — that **MUST share the same private helpers** (`_formation_dps_approx`, `_ticks_per_loop`, `_kill_schedule_for_loop`). Structural CI check enforces the shared-helper routing; divergence between the two paths is the failure mode AC-COMBAT-10 (foreground/offline parity) defends against.
3. **Statelessness contract** — zero class-scope `var`, zero `signal`, no public `static func` on `CombatResolver`; neither `CombatResolver` nor `DefaultCombatResolver` may appear in `project.godot` `[autoload]`. Enforced by CI structural grep (mirrors ADR-0009's H-16 pattern).
4. **Dictionary equality contract** — `CombatBatchResult.dict_equals(a, b)` key-walk is the canonical correctness comparison. **`Dictionary.hash()`-based equality is forbidden** for correctness checks (hash collisions are real; AC-COMBAT-01 would silently pass on non-deterministic results).
5. **Foreground/offline output asymmetry** — foreground `CombatTickEvents` is per-event (UI needs individual `enemy_killed` pops); offline `CombatBatchResult` is aggregate-only (offline batches can produce 15k+ kills and per-event enumeration would bloat the call-chain without UX benefit). Parity still holds because both paths feed the same private kill-schedule generator — offline just aggregates.
6. **Error injection contract** — both public methods accept an optional `error_logger: Callable = Callable()` parameter so tests can capture `push_error`-class messages deterministically without process-level log scraping. Default invalid Callable falls through to `push_error(msg)`. **Stateless** — never stored on the instance.

## Engine Compatibility

| Field | Value |
|---|---|
| **Engine** | Godot 4.6 |
| **Domain** | Core / Scripting (RefCounted module, typed Array/Dictionary value types, instance method polymorphism via `extends`, optional `Callable` DI parameter, `is_equal_approx` for float compare) |
| **Knowledge Risk** | **MEDIUM** — inherited from ADR-0009's risk posture. All patterns here are structural mirrors of ADR-0009's verified shape. Typed dictionaries (`Dictionary[StringName, int]`) are Godot 4.4+ (post-LLM-cutoff); verified live in the codebase via `combat-resolution.md` C.4. No other post-cutoff API used. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; `docs/engine-reference/godot/modules/autoload.md` Claim 4 [VERIFIED] (empirical evidence for autoload `_init` zero-arg — ADR-X01 inherits, does not re-prove); `docs/engine-reference/godot/breaking-changes.md` (4.4→4.5 `Dictionary[K,V]` typed dicts; `duplicate_deep()`); ADR-0009 §Module shape + §Injection contract (companion structural pattern) |
| **Post-Cutoff APIs Used** | `Dictionary[StringName, int]` + `Dictionary[int, int]` typed-dictionary syntax (Godot 4.4+, verified in combat-resolution.md C.4). No other post-cutoff APIs. `@abstract` is NOT used (C.4 Pass 3D notes the `@abstract` removal in favor of concrete `DefaultCombatResolver`). |
| **Verification Required** | None — all structural primitives are reuses of ADR-0009's verified pattern (`.new()` on non-autoload RefCounted subclass, zero-arg autoload `_init`, lazy-default `_ready()`, public setter DI, `extends` inheritance override for test spies). Pass-INIT-PROBE (2026-04-22) on Godot 4.6.1.stable.mono.official is the empirical backing for the composed pattern. |

## ADR Dependencies

| Field | Value |
|---|---|
| **Depends On** | ADR-0003 (Accepted — Amendment #2 vacated rank 9 for `CombatResolver`; Amendment #3 locks the zero-arg `_init` + setter pattern this ADR re-uses); ADR-0006 (Accepted — `DataRegistry.resolve("enemies", id)` + `DataRegistry.resolve("classes", id)` are the ONLY upstream calls `DefaultCombatResolver` makes); ADR-0009 (Accepted — codifies the `set_combat_resolver` DI seam + lazy-default `_ready()` pattern this ADR extends to Combat-side structural invariants) |
| **Enables** | ADR-X02 (Offline batch chunking refinement — requires `CombatBatchResult` schema to chunk); ADR-C02 (Resource schemas for `HeroClass`/`Enemy`/`Biome`/`Dungeon`/`Floor` `.tres` — will cite `Floor` as the consumed resource type); Orchestrator dispatch implementation stories; Offline Progression Engine replay-parity stories |
| **Blocks** | Any Combat implementation story; any Orchestrator `_on_tick` foreground dispatch story; any Offline Progression Engine replay story asserting AC-COMBAT-10 parity; any Dungeon Run View story consuming `enemy_killed` pops |
| **Ordering Note** | Author AFTER ADR-0009 (this ADR cites 0009's DI seam). Author BEFORE ADR-X02 (X02's offline chunking depends on `CombatBatchResult` aggregate-count shape). ADR-C02's Resource schemas can land in either order relative to this ADR — ADR-X01 cites `Floor` as an opaque `Resource` type here and lets C02 lock its fields. |

## Context

### Problem Statement

`design/gdd/combat-resolution.md` (Pass 3D, approved 2026-04-20) specifies the Combat Resolver's module shape, its five RefCounted value types, and the foreground/offline parity invariant — with 28 locked Type Requirements (TR-combat-001..028) and 20 Acceptance Criteria (16 BLOCKING + 2 ADVISORY + 2 Orchestrator-deferred). `/architecture-review 2026-04-22b` flags ADR-X01 as the top unwritten Required ADR: the GDD's structural contracts have no codifying ADR, meaning registry stances (CI structural invariants, forbidden patterns) cannot attach to an authoritative decision, and implementation stories have nothing to cite for the parity invariant beyond the GDD itself.

ADR-0009 locks the DI seam (`set_combat_resolver` setter + lazy-default `_ready()`) but does NOT cover:
- The CombatResolver module's own statelessness CI structural invariants (parallel to ADR-0009's `matchup_resolver_state_or_signal_addition` forbidden pattern)
- The five value-type schemas (`KillEvent`, `CombatTickEvents`, `CombatBatchResult`, `CombatRunSnapshot` — `MatchupResult` is already covered by 0009)
- The foreground/offline shared-private-helper invariant that makes parity structural rather than aspirational
- The dict-equality-by-key-walk contract (hash-based equality is banned for correctness comparisons)
- The foreground-per-event vs offline-aggregate-only asymmetry rationale
- The `error_logger: Callable` optional DI parameter for deterministic test log capture (AC-COMBAT-11)

This ADR codifies all six at ADR-level so registry stances can attach, stories can cite, and `/architecture-review` can trace coverage.

### Current State

- `design/gdd/combat-resolution.md` is approved Pass 3D + Pass-INIT-PROBE-SYNC 2026-04-22 (DI phrasing corrected from `_init(combat_resolver)` to `set_combat_resolver(resolver)` + lazy-default `_ready()` per `dungeon-run-orchestrator.md` §J.1 Option A). 28 Type Requirements + 20 ACs locked.
- ADR-0003 Amendment #2 + #3 (both Accepted 2026-04-22) vacated rank 9 and locked the zero-arg `_init` constraint project-wide.
- ADR-0009 (Accepted 2026-04-22) codifies the DI seam + majority-threshold aggregation for `MatchupResolver`; `orchestrator_di_pattern` registry interface explicitly covers BOTH `set_matchup_resolver` AND `set_combat_resolver` setters (single pattern, two setters).
- `docs/architecture/architecture.md` §Non-Autoload Pure-Function Modules + §Module Ownership Map CombatResolver rows describe the shape at architectural-overview level; ADR-X01 replaces "(upcoming)" references with a landed authority.
- `docs/architecture/tr-registry.yaml` TR-combat-001..028 lock the GDD requirements that this ADR codifies structurally.
- No resolver implementation exists yet (no `.gd` file under `src/gameplay/combat/`). This ADR is pure design codification.

### Constraints

- **ADR-0009 DI seam re-use (no duplication)**: This ADR MUST re-use `orchestrator_di_pattern` and `orchestrator_setter_call_after_ready` registry stances via `referenced_by` bumps, NOT redeclare them. Duplication creates `/architecture-review` drift (the reviewer treats the same stance registered twice as a conflict).
- **Godot autoload `_init` zero-arg (Claim 4 [VERIFIED])**: CombatResolver itself is NON-autoload (RefCounted), so its `_init` is unconstrained. The constraint is on the Orchestrator autoload, already covered by `autoload_init_with_required_args` forbidden pattern (project-wide). ADR-X01 re-asserts via `referenced_by` bump, not a new stance.
- **GdUnit4 4.6 cannot mock static methods** — forces instance-method shape (Pass 3D). AC-ORC-03 + AC-ORC-05 (Orchestrator matchup/combat cache correctness) are architecturally unwritable without injection; AC-COMBAT-01/10/17 determinism ACs require field-equal `equals()` comparison, not `==` identity.
- **Pillar 1 (player time is sacred)** — offline replay must be mathematically equivalent to per-kill live resolution. The shared-private-helper invariant is what makes this structural: foreground `emit_events_in_range` and offline `compute_offline_batch` both route through `_kill_schedule_for_loop` and compute the same schedule, so divergence is impossible by construction (not by convention). A "convenience" refactor that forks helpers (e.g., offline adds a fast-path) is the failure mode this invariant defends against.
- **AC-TICK-10 BLOCKING (500ms for 576,000 ticks on min-spec mobile)** — `compute_offline_batch` must return aggregate counts in bounded time; per-event enumeration of a 15k+ kill batch would bloat the call-chain and blow the budget. AC-COMBAT-14 (TR-combat-024) sets the internal perf contract: 100ms CI / 200ms min-spec mobile for a single 576k-tick batch call.
- **Production wiring must "fail closed"** — per §J.1 Option A (ADR-0009). ADR-X01 inherits.

### Requirements

- `CombatResolver` MUST be `class_name CombatResolver extends RefCounted` with zero class-scope `var`, zero `signal`, no public `static func`.
- `DefaultCombatResolver` MUST `extends CombatResolver` and be the only production instantiation site (`DefaultCombatResolver.new()` inside `DungeonRunOrchestrator._ready()` lazy-default).
- Neither `CombatResolver` nor `DefaultCombatResolver` may appear as `[autoload]` in `project.godot`.
- The two public entry points MUST share private helpers `_formation_dps_approx`, `_ticks_per_loop`, `_kill_schedule_for_loop`. Foreground MUST NOT implement a divergent path.
- All value types MUST `extends RefCounted` (automatic lifecycle — no manual `free()`) and expose `equals(other: T) -> bool` deep-equality.
- `CombatBatchResult` MUST use the key-walk `dict_equals` helper; `Dictionary.hash()`-based equality is forbidden.
- Float fields MUST be compared via `is_equal_approx`, never `==`.
- Typed dictionaries (`Dictionary[StringName, int]`, `Dictionary[int, int]`) — required syntax (Godot 4.4+).
- Both public methods MUST accept `error_logger: Callable = Callable()` for deterministic test log capture; default invalid Callable falls through to `push_error`. The `error_logger` is stateless and NEVER stored on the instance.
- `compute_offline_batch` MUST return aggregate counts only; per-event enumeration forbidden for offline path.
- `emit_events_in_range` MUST return per-event `kills: Array[KillEvent]` plus loop-boundary markers.

## Decision

### Module shape

```gdscript
# src/gameplay/combat/combat_resolver.gd
class_name CombatResolver extends RefCounted
## Injectable instance. Zero class-scope state, zero signals, no caches, no RNG, no time reads.
## Production: DefaultCombatResolver subclass. Tests: spy subclass extends CombatResolver directly.
## NOT an autoload — never appears in project.godot [autoload]. CI grep enforces.

func emit_events_in_range(
    formation: Array[HeroInstance],
    floor: Floor,
    range_start_tick: int,             # exclusive
    range_end_tick: int,               # inclusive
    error_logger: Callable = Callable()
) -> CombatTickEvents: ...

func compute_offline_batch(
    formation: Array[HeroInstance],
    floor: Floor,
    tick_budget: int,
    error_logger: Callable = Callable()
) -> CombatBatchResult: ...
```

```gdscript
# src/gameplay/combat/default_combat_resolver.gd
class_name DefaultCombatResolver extends CombatResolver
## Production implementation — closed-form kill schedule per combat-resolution.md Rule 10 / D.5.
## Constructed via DefaultCombatResolver.new() (zero-arg) inside DungeonRunOrchestrator._ready() lazy default.
## Both public methods route through private _kill_schedule_for_loop — structural parity invariant.
```

### Injection contract — re-uses ADR-0009 §Injection contract

The `DungeonRunOrchestrator` autoload at rank 14 holds `var _combat_resolver: CombatResolver = null`, implements `func set_combat_resolver(resolver: CombatResolver)` with a non-null `assert`, and lazy-constructs `DefaultCombatResolver.new()` in `_ready()` iff the field is still null. See ADR-0009 §Injection contract for the full code block; this ADR re-uses that seam verbatim. The `orchestrator_di_pattern` registry interface (added by ADR-0009) already lists both setters — this ADR does not add a new DI stance; it cites the existing one.

### Five RefCounted value types

All value types `extends RefCounted` (automatic lifecycle), use plain `var` (not `@export var` — transient per-call; `@export` falsely signals save-worthy intent), and expose `equals(other) -> bool` for deep field-equality. `==` on these objects tests identity, NOT field equality — tests MUST call `a.equals(b)`.

#### 1. `KillEvent`

```gdscript
class_name KillEvent extends RefCounted

var enemy_id:  StringName   # matches Enemy DB id
var archetype: StringName   # bruiser | caster | armored | beast | elemental
var tier:      int          # 1-3
var is_boss:   bool
var kill_tick: int          # absolute tick (foreground) or loop-relative (schedule)

func equals(other: KillEvent) -> bool:
    return (other != null
        and enemy_id  == other.enemy_id
        and archetype == other.archetype
        and tier      == other.tier
        and is_boss   == other.is_boss
        and kill_tick == other.kill_tick)
```

#### 2. `CombatTickEvents` — foreground per-tick-range output

```gdscript
class_name CombatTickEvents extends RefCounted

var kills:                 Array[KillEvent]  # per-event, in kill_tick order
var loop_completed_ticks:  Array[int]        # ticks at which a loop ended within this range
var first_clear_in_range:  bool              # true iff loop_counter crossed 0→1 inside (range_start, range_end]

func equals(other: CombatTickEvents) -> bool:
    if other == null: return false
    if kills.size() != other.kills.size(): return false
    for i in kills.size():
        if not kills[i].equals(other.kills[i]): return false
    # Typed Array[int] != is element-wise in Godot 4.6 (not identity). Caveat:
    # comparison requires matching element type — Array[int] != Array[int] works
    # element-wise; comparing Array[int] against a plain Array containing ints
    # also coerces correctly. Comparing against Array[String] would return true
    # for any content (type-mismatched typed arrays short-circuit as unequal by
    # contract). Since loop_completed_ticks is always Array[int] on both sides
    # by the field declaration, the plain != is safe here.
    if loop_completed_ticks != other.loop_completed_ticks: return false
    return first_clear_in_range == other.first_clear_in_range
```

#### 3. `CombatBatchResult` — offline batch output (aggregate-only)

```gdscript
class_name CombatBatchResult extends RefCounted

# Typed dictionaries (Godot 4.4+) — engine enforces key/value types at assignment
# (write path). Read access via operator[] returns the value directly; no per-access
# cast is performed. Passing a plain untyped Dictionary where Dictionary[K,V] is
# expected is caught at static analysis or runtime assignment, not at read time.
# The dict_equals helper accepts untyped `Dictionary` so that specific call site
# is always safe regardless of the caller's static typing.
var kills_by_archetype: Dictionary[StringName, int]   # archetype -> kill count
var kills_by_tier:      Dictionary[int, int]          # tier (1-3) -> kill count
var loops_completed:    int
var first_clear_tick:   int          # -1 if no loop completed
var hp_bonus_factor:    float        # D.6 Pillar 2 continuous throughput factor, [0.0, 1.0]
var survived:           bool         # D.6 derived: hp_bonus_factor >= 0.5 (Pass 2B)
var final_tick:         int          # always == tick_budget on success

# Static helper — key-by-key walk. Used for ALL dictionary equality checks.
# PUBLIC name (no leading underscore) because AC-COMBAT-01 and AC-COMBAT-10 call
# it from test code as the determinism gate; underscore prefix would falsely
# signal "private — do not use externally" and contradict the AC contract.
# Hash-based equality is unsound (hash collisions are real and would silently
# pass determinism tests on non-deterministic results — Pillar 1 regression).
# The walk is trivial for the small dicts here (≤5 keys each).
static func dict_equals(a: Dictionary, b: Dictionary) -> bool:
    if a.size() != b.size(): return false
    for key in a:
        if not b.has(key): return false
        if a[key] != b[key]: return false
    return true

func equals(other: CombatBatchResult) -> bool:
    if other == null: return false
    # hp_bonus_factor is a float — use is_equal_approx (Pass 2B). CMP_EPSILON is
    # 1e-5. For values in [0.0, 1.0] the relative error from double-precision
    # IEEE 754 accumulation across D.4/D.6 formulas is well below 1e-5, so the
    # default tolerance is appropriate. Note: is_equal_approx uses a relative
    # epsilon scaled by input magnitude, with an absolute floor for near-zero
    # values — still correct for losing-run edge cases where hp_bonus_factor
    # approaches 0.0.
    if not is_equal_approx(hp_bonus_factor, other.hp_bonus_factor): return false
    return (dict_equals(kills_by_archetype, other.kills_by_archetype)
        and dict_equals(kills_by_tier,      other.kills_by_tier)
        and loops_completed  == other.loops_completed
        and first_clear_tick == other.first_clear_tick
        and survived         == other.survived
        and final_tick       == other.final_tick)
```

#### 4. `CombatRunSnapshot` — dispatch-time cache (Orchestrator-owned, Combat-produced)

```gdscript
class_name CombatRunSnapshot extends RefCounted

var formation_dps_per_tick: float             # raw (Rule 4)
var hp_bonus_factor:        float             # Pillar 2 continuous, D.6 (Pass 2B)
var ticks_per_loop:         int
var survived:               bool              # derived: hp_bonus_factor >= 0.5
var kill_schedule:          Array[KillEvent]  # loop-relative ticks

func equals(other: CombatRunSnapshot) -> bool:
    if other == null: return false
    if not is_equal_approx(formation_dps_per_tick, other.formation_dps_per_tick):
        return false
    if not is_equal_approx(hp_bonus_factor, other.hp_bonus_factor):
        return false
    if ticks_per_loop != other.ticks_per_loop: return false
    if survived != other.survived: return false
    if kill_schedule.size() != other.kill_schedule.size(): return false
    for i in kill_schedule.size():
        if not kill_schedule[i].equals(other.kill_schedule[i]): return false
    return true
```

#### 5. `MatchupResult` — consumed from ADR-0009

Not declared by this ADR. `MatchupResult` is owned by ADR-0009 and consumed per-enemy inside `_kill_schedule_for_loop` (combat-resolution.md Rule 10 / D.5). Combat reads `result.is_advantaged` only; ignores `matched_archetypes`. See `matchup_result_value_type` registry interface (ADR-0009) — this ADR bumps its `referenced_by` list to include `design/gdd/combat-resolution.md` + this ADR.

### Foreground/offline parity via shared private helpers

Both public entry points MUST route through the same private helpers. Divergent helpers are the structural failure mode AC-COMBAT-10 defends against.

```gdscript
# Private helpers — BOTH public paths MUST call these (not re-implementations)
func _formation_dps_approx(formation: Array[HeroInstance]) -> float: ...
func _ticks_per_loop(formation: Array[HeroInstance], floor: Floor) -> int: ...
func _kill_schedule_for_loop(formation: Array[HeroInstance], floor: Floor) -> Array[KillEvent]: ...

# Public foreground path — computes schedule once, filters to tick range, enumerates per-event
func emit_events_in_range(formation, floor, range_start, range_end, error_logger) -> CombatTickEvents:
    var schedule := _kill_schedule_for_loop(formation, floor)   # SAME helper as offline
    var tpl := _ticks_per_loop(formation, floor)                # SAME helper as offline
    # ... windowed enumeration + loop-boundary markers ...

# Public offline path — computes schedule once, iterates loops, aggregates counts
func compute_offline_batch(formation, floor, tick_budget, error_logger) -> CombatBatchResult:
    var schedule := _kill_schedule_for_loop(formation, floor)   # SAME helper as foreground
    var tpl := _ticks_per_loop(formation, floor)                # SAME helper as foreground
    # ... loop iteration + aggregate kills_by_archetype / kills_by_tier ...
```

**Parity is structural, not aspirational**: because both public methods call the identical private helpers, the output events are byte-identical sets (foreground enumerates; offline aggregates). A "foreground fast path" or "offline shortcut" that skips the shared helper is the pattern this ADR's CI check defends against.

### Foreground-per-event vs offline-aggregate-only asymmetry

Foreground `CombatTickEvents.kills: Array[KillEvent]` is **per-event** because:
- UI needs individual `enemy_killed(tier, archetype)` signal pops for kill-feed and boss-fanfare timing.
- Per-tick-range calls are bounded (one `tick_fired` → one `emit_events_in_range(last_n, current_n)` where `current_n - last_n` is typically 1-10 ticks, producing 0-few kills per call).

Offline `CombatBatchResult.kills_by_archetype: Dictionary[StringName, int]` + `kills_by_tier: Dictionary[int, int]` is **aggregate-only** because:
- Offline batches commonly produce 15k+ kills in a single call (576k ticks / ~40-tick average kill cadence).
- Per-event enumeration would allocate 15k+ `KillEvent` RefCounted objects per batch — ~600 KB allocation per dispatched floor.
- Return-to-App UI consumes aggregate counts only (kill-feed shows "+15,342 bruisers defeated" not a 15k-entry scrollback).
- Performance contract AC-COMBAT-14 (TR-combat-024): ≤100ms p95 CI / ≤200ms p95 min-spec mobile for 576k-tick batch. Aggregate-only keeps it inside this budget.

**Parity preserved**: the aggregate dicts are the sum of the per-event schedule that `_kill_schedule_for_loop` produces — the foreground union-of-ranges equals the offline aggregate by construction (AC-COMBAT-10 BLOCKING asserts this on a shared `(formation, floor, T)` fixture).

### Dictionary equality contract

The `CombatBatchResult.dict_equals(a, b)` static helper is the canonical correctness comparison. **Do NOT use `Dictionary.hash()`** for correctness checks — `hash()` returns a 32-bit int and collisions are possible even for flat primitive dictionaries. A determinism test (AC-COMBAT-01, AC-COMBAT-10) requires **injectivity**, not just determinism: two distinct dictionaries must NEVER compare equal. The key-walk is trivially cheap at the scale here (≤5 archetype keys, 3 tier keys).

The `dict_equals` helper has a public name (no underscore prefix) because AC-COMBAT-01 test code calls it directly — the AC contract IS "test code compares via this helper", so the helper is a public API of `CombatBatchResult`, not a private one.

### `error_logger: Callable` optional DI parameter (AC-COMBAT-11 contract)

Both public methods accept `error_logger: Callable = Callable()`. When `error_logger.is_valid()` is true, Combat calls `error_logger.call(msg)` in place of `push_error(msg)`. Production callers omit the argument — the default invalid `Callable()` means `is_valid()` returns false and Combat falls through to `push_error(msg)` (engine's log stream). Tests pass a capturing Callable that appends to a local Array, enabling deterministic assertion of error-path behavior without process-level log scraping.

**Stateless**: `error_logger` is NEVER stored on the `CombatResolver` instance. It is a per-call parameter. Combat Rule 1 (statelessness) is preserved.

**Not a logger injection pattern**: this is explicitly a single-call observability hook, not a generalized `error_logger` field. Tests rely on the per-call scoping to avoid cross-test logger contamination.

### CI structural invariants (enforced at merge time)

| Check | Enforced By | Failure Action |
|---|---|---|
| `combat_resolver.gd` has zero class-scope `var ` outside method bodies | Grep CI step | Block merge |
| `combat_resolver.gd` has zero `signal ` declarations | Grep CI step | Block merge |
| All public methods in `combat_resolver.gd` are `func `, not `static func ` (grep `^static func [a-zA-Z]` returns 0 hits; the `CombatBatchResult.dict_equals` static is OK because it lives on `combat_batch_result.gd`, not on `CombatResolver`) | Grep CI step | Block merge |
| Neither `CombatResolver` nor `DefaultCombatResolver` appears in `project.godot` `[autoload]` | ConfigFile parse in CI | Block merge |
| `DefaultCombatResolver extends CombatResolver` | Grep CI step | Block merge |
| `DungeonRunOrchestrator` declares `func set_combat_resolver(resolver: CombatResolver)` with non-null `assert` (shared with ADR-0009 — same check defends both setters) | Grep CI step | Block merge (inherits ADR-0009's check) |
| `DungeonRunOrchestrator._ready()` contains the null-check lazy-default pattern for `_combat_resolver` (inherits ADR-0009's check for both resolvers) | Grep CI step | Block merge (inherits ADR-0009's check) |
| **Shared-private-helper routing**: both `emit_events_in_range` and `compute_offline_batch` public method bodies MUST contain a call to `_kill_schedule_for_loop(` (each public method body independently — a raw file-wide `grep -c` returning ≥2 is INSUFFICIENT because it cannot distinguish "inside `emit_events_in_range` body" from "inside a private helper or comment"). Implementation MUST use method-body-aware parsing: either a GDScript AST walker, or a structured text scanner that tracks indent depth after each `func` declaration and asserts the call appears within each public method's indent block. A `grep -c` approach would silently fail if a developer refactored one public method to skip the shared helper while adding a third call elsewhere in the file (count stays at ≥2). A foreground fast-path that skips the shared helper MUST fail this check. | Script-based CI step (method-body-aware, NOT raw file-wide grep-count) | Block merge |
| **Hash-based dict equality ban**: `combat_resolver.gd`, `default_combat_resolver.gd`, AND all `tests/unit/combat/` test files contain zero `\.hash\(\) == ` patterns against `Dictionary`-typed values. Grep allows explicit `# HASH-OK: <justification>` comments as escape hatches (rare — if used at all, must be justified in the comment). | Grep CI step | Block merge |
| **Error-logger statelessness**: `combat_resolver.gd` has zero class-scope `var error_logger` or `var _error_logger` — the logger is per-call-only. | Grep CI step | Block merge |
| **`equals` presence**: all five value-type files (`kill_event.gd`, `combat_tick_events.gd`, `combat_batch_result.gd`, `combat_run_snapshot.gd`) declare `func equals(other: <TypeName>) -> bool`. | Grep CI step (one predicate per file) | Block merge |
| **`compute_offline_batch` returns aggregate-only**: `combat_batch_result.gd` has no `Array[KillEvent]` field (grep negative match). This check fails if someone converts the offline path to per-event. | Grep CI step | Block merge |
| **Combined structural regex** — asserts `class_name CombatResolver extends RefCounted` on the file's collapsed content (strip blank lines + comments), defending against multi-line or comment-injected bypass. Mirrors ADR-0009's H-16 pattern. | Script-based CI step | Block merge |

### Architecture diagram

```
                 Godot autoload system
                         │
                         │  instantiates rank 14 autoload
                         │  via _create_instance() — calls _init() with ZERO args
                         │  (autoload.md Claim 4 [VERIFIED], ADR-0009)
                         ▼
           DungeonRunOrchestrator (rank 14, extends Node)
                         │
                         │  _ready() lazy-default (ADR-0009 §Injection contract)
                         ▼
                 ┌───────┴───────┐
                 │               │
         _combat_resolver   _matchup_resolver
          : CombatResolver   : MatchupResolver
           (this ADR)         (ADR-0009)
                 │
                 ▼
       ┌─────────────────────────────────────────────────┐
       │  CombatResolver (RefCounted — NON-autoload)     │
       │                                                  │
       │   Public entry points (BOTH route through        │
       │   shared private helpers — structural parity):   │
       │                                                  │
       │   ┌── emit_events_in_range(...)          ──┐    │
       │   │    → _kill_schedule_for_loop(...)    │    │
       │   │    → windowed per-event enumeration  │    │
       │   │    → CombatTickEvents (per-event)    │    │
       │   │                                        │    │
       │   └── compute_offline_batch(...)         ──┘    │
       │        → _kill_schedule_for_loop(...)   <─same │
       │        → aggregate loops + kills         helper │
       │        → CombatBatchResult (aggregate)         │
       │                                                  │
       │   Private helpers (single source of truth):     │
       │   _formation_dps_approx, _ticks_per_loop,       │
       │   _kill_schedule_for_loop                       │
       └─────────────────────────────────────────────────┘
                         │
                         ▼  per-enemy lookup inside _kill_schedule_for_loop
                  MatchupResolver.resolve_formation_matchup(frozen_formation, enemy.archetype)
                         │  → MatchupResult { is_advantaged, matched_archetypes }
                         ▼  (ADR-0009; Combat reads is_advantaged only)

     === foreground path — per-tick emission ===
           Orchestrator._on_tick(range_start, range_end)
                         │
                         ▼
           _combat_resolver.emit_events_in_range(formation, floor, start, end)
                         │
                         ▼
           CombatTickEvents { kills: per-event, loop_completed_ticks, first_clear_in_range }
                         │
                         ▼
           Orchestrator translates → enemy_killed signal per KillEvent

     === offline path — per-floor aggregate ===
           OfflineProgressionEngine (rank 15)
                         │
                         ▼  ONE call per dispatched floor per wake
           _combat_resolver.compute_offline_batch(formation, floor, tick_budget)
                         │
                         ▼
           CombatBatchResult { kills_by_archetype, kills_by_tier, loops_completed,
                               first_clear_tick, hp_bonus_factor, survived, final_tick }
                         │
                         ▼
           Orchestrator translates → Economy.add_gold (aggregate) + Return-to-App UI

     === test path — §J.3 Mode 1 (shared with ADR-0009) ===
           var orch := DungeonRunOrchestrator.new()
           orch.set_combat_resolver(SpyCombatResolver.new())    # BEFORE add_child
           orch.set_matchup_resolver(SpyMatchupResolver.new())
           add_child(orch)                                       # fires _ready(); null-checks
                                                                 # short-circuit; spies preserved
```

### Parity invariant — formal statement (AC-COMBAT-10 BLOCKING)

For any `(formation, floor, T)` tuple where foreground tick-range calls partition `[0, T]` into non-overlapping segments `(r_0=0, r_1], (r_1, r_2], ..., (r_{k-1}, r_k=T]`:

```
foreground_kills_union := flatten([
    emit_events_in_range(formation, floor, r_{i-1}, r_i).kills
    for i in range(1, k+1)
])

offline_result := compute_offline_batch(formation, floor, T)

# Parity assertion:
aggregate_kills(foreground_kills_union).kills_by_archetype
    == offline_result.kills_by_archetype   # via dict_equals
aggregate_kills(foreground_kills_union).kills_by_tier
    == offline_result.kills_by_tier        # via dict_equals
```

Structural backing: both paths call `_kill_schedule_for_loop(formation, floor)` and iterate it — foreground filters by range, offline aggregates total. The schedule itself is identical by construction.

## Alternatives Considered

### Alternative 1: Separate foreground vs offline resolver classes (`ForegroundCombatResolver` + `OfflineCombatResolver`)

- **Description**: Two RefCounted classes with no shared base, each owning its own kill-schedule generator, aggregating at their own cadence.
- **Pros**: Separate perf tuning; foreground can optimize for per-tick latency without affecting offline batch throughput.
- **Cons**: Breaks AC-COMBAT-10 structurally (parity becomes a written-test gate, not a compile-time invariant). Doubles the test surface (two schedule generators to prove field-equal). A bug fix in one path silently diverges the other.
- **Rejection Reason**: Parity-by-construction (via shared private helpers) is the whole point of the Pass 3D shape (combat-resolution.md Rule 2). Splitting the class loses the invariant.

### Alternative 2: Per-event offline output (`CombatBatchResult.kills: Array[KillEvent]`)

- **Description**: Offline path enumerates every kill event, same as foreground.
- **Pros**: Simpler parity assertion (two `Array[KillEvent]` compared element-wise, no `aggregate_kills` helper needed).
- **Cons**: Blows AC-COMBAT-14 performance budget. A 576k-tick batch producing 15k+ kills × ~40-byte `KillEvent` RefCounted = ~600 KB allocation per dispatched floor per wake. Mobile memory and GC pressure become unacceptable during long absences.
- **Rejection Reason**: Performance constraint (TR-combat-024 / AC-COMBAT-14 BLOCKING). Aggregate-only is the architected win.

### Alternative 3: `Dictionary.hash()` equality for determinism ACs

- **Description**: `CombatBatchResult.equals` could check `kills_by_archetype.hash() == other.kills_by_archetype.hash()` instead of the key-walk.
- **Pros**: One-line equality; may be marginally faster on large dicts.
- **Cons**: Hash collisions are mathematically real on 32-bit hashes. AC-COMBAT-01 (Stateless Purity) would silently pass on non-deterministic results if the hash happened to collide. Pillar 1 (player time is sacred) depends on determinism gates being **injective** — two distinct outputs MUST never compare equal.
- **Rejection Reason**: Correctness over micro-optimization. Dict sizes here are ≤5 keys; key-walk is trivially cheap. Forbidden pattern explicitly CI-enforced.

### Alternative 4: Store `error_logger` as a CombatResolver instance field set at injection time

- **Description**: Add `var _error_logger: Callable` to `CombatResolver`; Orchestrator sets it alongside `set_combat_resolver`.
- **Pros**: Callers don't need to pass `error_logger` to every method call.
- **Cons**: Breaks Rule 1 statelessness — the resolver now carries per-test state. Cross-test contamination risk (a test that forgets to clear the logger can affect the next test's assertions). Forces all tests to explicitly reset the logger.
- **Rejection Reason**: Statelessness is a structural invariant (CI-enforced via `combat_resolver_state_or_signal_addition`). Per-call optional parameter preserves the invariant.

### Alternative 5: `@abstract class_name CombatResolver extends Object` (pre-Pass-3D shape)

- **Description**: Original design — all methods `static func` on an `@abstract` base class.
- **Pros**: Zero-allocation static dispatch; no instance overhead.
- **Cons**: **GdUnit4 4.6 cannot mock static methods on `@abstract` classes** — AC-ORC-03, AC-ORC-05, AC-COMBAT-01 all become architecturally unwritable. Also requires `@abstract` (Godot 4.5+ post-cutoff API) with documented editor UI gaps (autoload.md Claim 3 [INCONCLUSIVE]). A narrower "`@abstract` on the base methods but concrete base class" alternative is ALSO rejected: `@abstract` base methods would require override in every subclass, which defeats the spy-subclass test pattern (tests routinely extend `CombatResolver` and override ONLY the one method under test — leaving other methods un-overridden to fall through to the base implementation). Forcing override of every method across all test spies adds boilerplate without safety benefit.
- **Rejection Reason**: Pass 3D (combat-resolution.md, 2026-04-19) explicitly superseded this with the instance-method shape. AC mockability is non-negotiable. The concrete-base-class shape is the correct tradeoff for test-spy ergonomics.

### Alternative 6: Collapse `CombatRunSnapshot` into `CombatBatchResult`

- **Description**: Remove `CombatRunSnapshot` as a separate value type; return the same fields inside `CombatBatchResult` at dispatch time (when `tick_budget=0`).
- **Pros**: Five value types → four.
- **Cons**: `CombatRunSnapshot` contains `kill_schedule: Array[KillEvent]` (loop-relative ticks — used by Orchestrator for foreground tick-range filtering); `CombatBatchResult` is aggregate-only (no per-event schedule). Merging forces either (a) aggregate `CombatBatchResult` gains a per-event field (regresses Alternative 2's perf concern), or (b) the dispatch-time call returns a different shape than the offline-replay call (breaks the "same signature for both paths" simplicity).
- **Rejection Reason**: The two types have distinct semantics (dispatch-time cache vs batch result). Merging trades clarity for a single-type-count savings.

## Consequences

### Positive

- **Parity-by-construction**: AC-COMBAT-10 is a structural invariant (shared-helper CI check), not a written-test gate. Foreground/offline divergence is mechanically prevented.
- **Determinism gates are injective**: dict-equality-by-key-walk means AC-COMBAT-01, AC-COMBAT-10, AC-COMBAT-17 cannot silently pass on hash-collided outputs.
- **Statelessness CI-enforced**: zero class-scope `var`, zero `signal`, no public `static func` — Rule 1 (stateless purity) is machine-checkable, not review-checked.
- **Test mockability unlocked**: AC-ORC-03, AC-ORC-05, AC-COMBAT-01/10/17 all become writable because `CombatResolver` is instance-methods + injectable-subclass.
- **Offline performance preserved**: aggregate-only `CombatBatchResult` stays inside the 100ms CI / 200ms mobile budget (AC-COMBAT-14) for 576k-tick batches with 15k+ kills.
- **Production fails closed**: lazy-default construction (inherited from ADR-0009) means a shipped build with no test-harness plumbing boots playable. No forgotten-wiring failure mode.
- **Test log capture is deterministic**: `error_logger: Callable` per-call DI means tests assert `push_error` paths without process-level log scraping or signal-based indirection.
- **GDD-ADR alignment**: this ADR codifies combat-resolution.md C.4 + Rule 1-2 + Rule 7 verbatim. No GDD-vs-ADR drift; `/architecture-review` will cleanly trace ADR-X01 → 28 TR-combat-XXX + 20 AC-COMBAT-XX.

### Negative

- **Two setter methods in Orchestrator** (inherited from ADR-0009): `set_combat_resolver` + `set_matchup_resolver`. Tests that inject both must call both. Mitigated by `tests/helpers/orchestrator_factory.gd` helper (inherited from ADR-0009 Risks table).
- **Test-only public surface in production binary**: `set_combat_resolver` ships in release builds. Same one-line assertion-gated setter as `set_matchup_resolver` (ADR-0009); cost is a few bytes per method. `OS.is_debug_build()` gating was considered and rejected by §J.1 (consistency with matchup setter beats asymmetric gating).
- **Private-helper naming as structural contract**: `_formation_dps_approx`, `_ticks_per_loop`, `_kill_schedule_for_loop` are not arbitrary names — the CI structural check greps for `_kill_schedule_for_loop(` call site presence in both public method bodies. A future refactor that renames these helpers MUST update the CI check in lockstep. Mitigation: the CI check lives in `tests/ci/combat_structural_test.gd` with a comment block pointing to this ADR's §CI structural invariants.
- **Aggregate-only offline output constrains debug observability**: per-kill replay debugging (e.g., "which enemy kill caused the gold spike at tick 412,000?") requires foreground-style enumeration. Mitigated by the `--debug-offline-enumerate` flag (not in MVP; flagged for ADR-X02 offline-chunking refinement).

### Neutral

- `CombatResolver` extends `RefCounted` rather than `Object` or `Node`. Automatic reference counting — no manual `free()`, no scene-tree membership required.
- Five RefCounted value types (`KillEvent`, `CombatTickEvents`, `CombatBatchResult`, `CombatRunSnapshot`, plus `MatchupResult` consumed from ADR-0009) — lean; each carries only the fields its consumers need.

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Developer adds a "fast path" to `emit_events_in_range` that skips `_kill_schedule_for_loop` for tick-ranges of size 1 | Medium | **High** (silently breaks AC-COMBAT-10 parity; diagnostic is "offline replay shows different kill counts than the foreground session it's meant to reproduce") | §CI structural invariants table includes a grep assertion that both public method bodies contain a call to `_kill_schedule_for_loop(`. Any divergent fast path fails the check. Refactor-time updates to helper names must update the CI check in lockstep. |
| Developer adds a class-scope `var _schedule_cache: Dictionary` for "memoization" | Medium | High (breaks Rule 1 statelessness; cross-call state leakage; AC-COMBAT-01 becomes flaky) | §CI structural invariants: `combat_resolver.gd` class-scope `var ` count must be zero. Forbidden pattern `combat_resolver_state_or_signal_addition` registry entry enforces. |
| Test author uses `Dictionary.hash() ==` for AC-COMBAT-01 determinism assertion (copy-paste from another codebase) | Low | High (silent pass on non-deterministic output — Pillar 1 regression reaches production undetected) | §CI structural invariants: grep `\.hash\(\) == ` in `combat_resolver.gd`, `default_combat_resolver.gd`, and all `tests/unit/combat/` test files returns 0 hits. Escape hatch: explicit `# HASH-OK: <justification>` comment; none expected for MVP. |
| Offline path is converted to per-event for "consistency with foreground" | Medium | Medium (blows AC-COMBAT-14 perf budget; mobile memory pressure during long offline replays) | §CI structural invariants: `combat_batch_result.gd` has no `Array[KillEvent]` field (grep negative match). Any conversion MUST edit the CI check in lockstep — which requires explicit intent. |
| Developer stores `error_logger` as an instance field for "less typing" | Low | Medium (breaks statelessness; cross-test contamination) | §CI structural invariants: `combat_resolver.gd` has no class-scope `var error_logger` or `var _error_logger`. Per-call parameter is the only permitted form. |
| Value-type `equals` method omitted on a new field addition | Medium | Medium (AC-COMBAT-01 determinism test passes but does not actually compare the new field — false-positive green) | Code review discipline + coding-standards.md rule: "Any `var` added to a RefCounted value type MUST be added to the `equals` method's field list in the same commit." Not CI-enforceable beyond an `equals`-method-presence check. The presence check (§CI structural invariants) guards against the equals method itself being deleted. |
| `CombatRunSnapshot` mutated after dispatch | Low | High (breaks Rule 14 frozen-snapshot contract; offline replay produces different results than foreground session) | `CombatRunSnapshot` is `extends RefCounted` with no setters — all fields are `var` but the Orchestrator treats the snapshot as frozen after DISPATCHING. Coding-standards.md rule: "CombatRunSnapshot MUST NOT be written after the Orchestrator transitions out of DISPATCHING." Not directly CI-enforceable; relies on review. |

## GDD Requirements Addressed

| GDD Document | Requirement | How This ADR Addresses It |
|---|---|---|
| `design/gdd/combat-resolution.md` Rule 1 + C.4 (Pass 3D) | `CombatResolver` is `class_name CombatResolver extends RefCounted`; stateless (zero class-scope var, zero signal, no static public func); `DefaultCombatResolver` production subclass | §Module shape + §CI structural invariants codify |
| `design/gdd/combat-resolution.md` Rule 2 | Two public entry points (`emit_events_in_range`, `compute_offline_batch`) share private helpers (`_formation_dps_approx`, `_ticks_per_loop`, `_kill_schedule_for_loop`) | §Foreground/offline parity via shared private helpers codifies + CI-enforces |
| `design/gdd/combat-resolution.md` Rule 7 + Rule 10 | `first_clear_in_range` / `first_clear_tick` markers; per-enemy kill-schedule with MatchupResolver lookup; kill_tick integer arithmetic via `ceili` | §Value types (KillEvent, CombatTickEvents, CombatBatchResult) + §Architecture diagram codify |
| `design/gdd/combat-resolution.md` C.4 type contracts — `KillEvent`, `CombatTickEvents`, `CombatBatchResult`, `CombatRunSnapshot` | All five value types extend RefCounted; use plain `var` (not `@export var`); expose `equals(other) -> bool` | §Five RefCounted value types codifies verbatim |
| `design/gdd/combat-resolution.md` C.4 — `dict_equals` static helper on `CombatBatchResult`; hash-based equality forbidden | §Dictionary equality contract + §CI structural invariants codify |
| `design/gdd/combat-resolution.md` AC-COMBAT-01 Stateless Purity (BLOCKING) | Repeated `compute_offline_batch` calls return field-equal results; no input mutation | §Value types' `equals()` methods + §Foreground/offline parity invariant codify |
| `design/gdd/combat-resolution.md` AC-COMBAT-10 Foreground/Offline Parity (BLOCKING) | Union of `emit_events_in_range` events == `compute_offline_batch` aggregate for same `(formation, floor, T)` | §Parity invariant — formal statement + §Foreground/offline parity via shared private helpers codify |
| `design/gdd/combat-resolution.md` AC-COMBAT-11 Unresolvable class_id Skipped (BLOCKING) | Optional `error_logger: Callable` parameter enables deterministic test log capture | §`error_logger: Callable` optional DI parameter codifies |
| `design/gdd/combat-resolution.md` AC-COMBAT-14 (TR-combat-024) — 100ms CI / 200ms mobile for 576k-tick batch | Aggregate-only `CombatBatchResult` (not per-event) | §Foreground-per-event vs offline-aggregate-only asymmetry + §Performance Implications codify |
| `design/gdd/combat-resolution.md` AC-COMBAT-17 Long-Run Aggregate Counts No Drift (BLOCKING) | Aggregate counts across a 576k-tick batch field-equal to accumulated per-loop counts | §Foreground/offline parity + §Value types' `equals()` codify |
| `design/gdd/combat-resolution.md` AC-COMBAT-18 Formation Immutability During Batch (ADVISORY) | Input formation array unchanged after any `compute_offline_batch` / `emit_events_in_range` call | §Requirements + §CI structural invariants (error-logger statelessness + class-scope var zero-check) codify; direct array-immutability check is an AC-COMBAT-18 test-level concern |
| `design/gdd/dungeon-run-orchestrator.md` §J.1 (locked) — lazy-default + setter DI for Orchestrator autoload | `set_combat_resolver` setter + `_ready()` null-check lazy-default | Inherited from ADR-0009 §Injection contract; ADR-X01 adds `referenced_by` bump, does not restate |
| `design/gdd/class-vs-enemy-matchup-resolver.md` (consumed) — `MatchupResult.is_advantaged` read per-enemy inside `_kill_schedule_for_loop` | No new stance; ADR-X01 cites `matchup_result_value_type` registry interface (ADR-0009) + adds itself to the `referenced_by` list |

## Performance Implications

| Metric | Before | Expected After | Budget |
|---|---|---|---|
| CPU (per `emit_events_in_range` call, foreground, tick-range size 1-10) | N/A | <1ms p95 | Well inside 16.6ms frame budget (60fps) |
| CPU (per `compute_offline_batch` call, 576k ticks / 15k+ kills) | N/A | ≤100ms p95 on CI, ≤200ms p95 on min-spec mobile | **TR-combat-024 / AC-COMBAT-14 BLOCKING**; registered as performance budget `combat_compute_offline_batch` below |
| CPU (`_kill_schedule_for_loop`, per call) | N/A | O(sum of enemy_list counts) — typically <200 iterations per MVP floor | Called once per `compute_offline_batch`, once per foreground `emit_events_in_range` (cached on `CombatRunSnapshot` — Orchestrator re-uses across ticks in same dispatch) |
| Memory (per `CombatTickEvents` allocation, foreground) | N/A | ~40 bytes (RefCounted header) + per-event `KillEvent` (~40 bytes × 0-10 kills per range) | 512 MB — negligible |
| Memory (per `CombatBatchResult` allocation, offline) | N/A | ~120 bytes (RefCounted header + 5 primitive fields + 2 small dicts ≤5 keys each) | 512 MB — negligible |
| Memory (per `CombatRunSnapshot` allocation, dispatch) | N/A | ~40 bytes + `kill_schedule: Array[KillEvent]` (≤~200 entries per MVP floor × ~40 bytes = ≤8 KB) | 512 MB — negligible |
| Memory (offline path peak, 576k-tick batch) | N/A | ~120 bytes (`CombatBatchResult`) + ~8 KB (`CombatRunSnapshot`) — **no 15k × `KillEvent` allocation** | 512 MB — aggregate-only avoids ~600 KB/floor peak |

**Performance budget registered**: `combat_compute_offline_batch` — 100ms p95 CI / 200ms p95 min-spec mobile for 576,000-tick batch call — BLOCKING, backs AC-COMBAT-14 + TR-combat-024.

## Migration Plan

**No migration needed.** No implementation exists yet. When the first implementation story lands:

1. Create `src/gameplay/combat/combat_resolver.gd` + `default_combat_resolver.gd` + `kill_event.gd` + `combat_tick_events.gd` + `combat_batch_result.gd` + `combat_run_snapshot.gd` per §Module shape + §Five RefCounted value types.
2. Implement the shared private helpers `_formation_dps_approx`, `_ticks_per_loop`, `_kill_schedule_for_loop` per combat-resolution.md Rule 4 / Rule 8 / Rule 10 / D.5.
3. Implement public `emit_events_in_range` + `compute_offline_batch` — both MUST call `_kill_schedule_for_loop` in their method bodies (CI-enforced).
4. Add CI structural test suite at `tests/ci/combat_structural_test.gd` implementing all 13 §CI structural invariants checks. Mirror the style of ADR-0009's H-16 structural test.
5. Implement the 16 BLOCKING + 2 ADVISORY AC-COMBAT-XX unit tests per combat-resolution.md §H.
6. `DungeonRunOrchestrator._ready()` lazy-default already covers `_combat_resolver` via ADR-0009's shared pattern — no new Orchestrator code required beyond what ADR-0009 specifies.
7. Add the `combat_compute_offline_batch` perf regression CI canary (576k-tick batch call; assert p95 ≤ 100ms on CI runner).

**Rollback plan**: If post-MVP implementation discovers the aggregate-only offline path is insufficient for debug observability, the fix is an additive `--debug-offline-enumerate` flag (separate ADR; scope = ADR-X02 offline chunking refinement). This ADR's core shape (lazy-default DI + shared-helper parity + RefCounted value types) is not expected to require rollback.

## Validation Criteria

- [ ] `src/gameplay/combat/combat_resolver.gd` exists with exactly one `class_name CombatResolver extends RefCounted` declaration.
- [ ] `src/gameplay/combat/default_combat_resolver.gd` exists with `class_name DefaultCombatResolver extends CombatResolver`.
- [ ] Neither class appears as `[autoload]` in `project.godot`.
- [ ] `combat_resolver.gd` contains zero class-scope `var` declarations outside method bodies, zero `signal` declarations, zero public `static func`.
- [ ] Both `emit_events_in_range` and `compute_offline_batch` method bodies contain a call to `_kill_schedule_for_loop(` (CI grep predicate).
- [ ] `combat_batch_result.gd` has no `Array[KillEvent]` field.
- [ ] `combat_batch_result.gd` declares `static func dict_equals(a: Dictionary, b: Dictionary) -> bool`.
- [ ] All five value-type files declare `func equals(other: <TypeName>) -> bool`.
- [ ] `combat_resolver.gd`, `default_combat_resolver.gd`, AND all `tests/unit/combat/` test files contain zero `\.hash\(\) == ` patterns (except explicit `# HASH-OK: <justification>` comments).
- [ ] `combat_resolver.gd` has no class-scope `var error_logger` or `var _error_logger`.
- [ ] `DungeonRunOrchestrator.set_combat_resolver(resolver: CombatResolver)` declared with non-null `assert` (inherits ADR-0009 check).
- [ ] `DungeonRunOrchestrator._ready()` null-check lazy-default for `_combat_resolver` (inherits ADR-0009 check).
- [ ] AC-COMBAT-01 BLOCKING passes (repeated `compute_offline_batch` calls return field-equal `CombatBatchResult` via `.equals()`).
- [ ] AC-COMBAT-10 BLOCKING passes (foreground range-union aggregate equals offline batch aggregate via `dict_equals`).
- [ ] AC-COMBAT-14 BLOCKING passes (576k-tick batch ≤100ms p95 CI).
- [ ] AC-COMBAT-17 BLOCKING passes (long-run aggregate counts no drift).
- [ ] CI structural test suite at `tests/ci/combat_structural_test.gd` implements all 13 §CI structural invariants — passes on every PR.

## Specialist Review

godot-specialist **APPROVE-WITH-NOTES** (2026-04-22). No mechanically-wrong engine claims; all core patterns idiomatic for Godot 4.6. Seven notes issued; five folded in-place, two retained for implementation-story awareness (not ADR-level):

- **NOTE #1 (folded)** — Typed Dictionary comment in §CombatBatchResult tightened: assignment-time type-check clarified; read-path behavior added; `dict_equals(Dictionary, Dictionary)` helper accepts untyped — always safe regardless of caller typing.
- **NOTE #2 (folded)** — `Array[T] !=` comment in §CombatTickEvents expanded with the typed-vs-untyped coercion caveat. Load-bearing for AC-COMBAT-01 — Godot 4.6's element-wise equality on typed arrays is confirmed correct; the caveat is documentation completeness.
- **NOTE #3 (folded)** — `is_equal_approx` tolerance justified for [0.0, 2.31] and [0.0, 1.0] ranges; near-zero losing-run edge case addressed (relative epsilon falls back to absolute floor).
- **NOTE #4 (no change)** — `Callable()` default construction yielding `is_valid() == false` confirmed idiomatic for 4.6. `Callable = null` is invalid for a typed Callable parameter; the ADR's pattern is correct.
- **NOTE #5 (folded — load-bearing)** — §CI structural invariants shared-helper-routing row rewritten. A raw file-wide `grep -c _kill_schedule_for_loop >= 2` is INSUFFICIENT to enforce the invariant — a developer could refactor one public method to skip the helper while adding a third call elsewhere and the check would silently pass. The row now explicitly mandates method-body-aware parsing (GDScript AST walker OR structured indent-tracking scanner), not raw grep. Critical for AC-COMBAT-10 enforcement.
- **NOTE #6 (folded)** — §Alternatives Considered Alternative 5 rejection rationale expanded. Adds the "narrower `@abstract` on base methods" sub-alternative and documents why it's ALSO rejected (forces override in every test spy — defeats the spy-subclass ergonomic pattern where tests override only the method under test).
- **NOTE #7 (no change)** — Typed Array covariance surfaced as an implementation-story gotcha: Godot 4.6 does NOT support covariant typed arrays, so `Array[HeroSubclass]` is not assignable to `Array[HeroInstance]` even when `HeroSubclass extends HeroInstance`. The ADR's signature `Array[HeroInstance]` is correct for the current codebase (roster stores heroes as `Array[HeroInstance]`); the gotcha is forward-looking for any future story introducing a hero subclass hierarchy. Not an ADR-level concern.

**Inherited findings not re-proven by this review**: autoload.md Claim 4 [VERIFIED] (autoload `_init` zero-arg), ADR-0009's DI seam (`set_combat_resolver` + lazy-default `_ready()`), and non-autoload RefCounted `.new()` — all verified in prior specialist passes and empirical probes (Pass-INIT-PROBE 2026-04-22). ADR-X01 composes verified primitives; no novel engine mechanism introduced.

## Related Decisions

- ADR-0003 (Accepted) — Amendment #2 vacated rank 9 for `CombatResolver`; Amendment #3 locks zero-arg `_init` project-wide. This ADR re-asserts via `referenced_by`.
- ADR-0006 (Accepted) — `DataRegistry.resolve("classes"/"enemies", id)` are the ONLY upstream calls `DefaultCombatResolver` makes.
- ADR-0009 (Accepted) — **companion ADR**. Codifies the `set_combat_resolver` + lazy-default DI seam + `MatchupResult` consumed by Combat. This ADR re-uses that seam verbatim and does not duplicate it.
- ADR-X02 (to author later) — Offline batch chunking refinement. Will cite this ADR's `CombatBatchResult` schema as the chunking unit.
- ADR-C02 (to author later) — Resource schemas for `HeroClass` / `Enemy` / `Biome` / `Dungeon` / `Floor` `.tres` files. Will lock the `Floor` type this ADR consumes as an opaque parameter.
- `design/gdd/combat-resolution.md` — the authoritative GDD this ADR codifies (28 TRs + 20 ACs).
- `design/gdd/dungeon-run-orchestrator.md` §J.1 — the locked Wiring model ADR-0009 codifies; this ADR inherits the seam.
- `design/gdd/class-vs-enemy-matchup-resolver.md` — source of `MatchupResult` consumed per-enemy inside `_kill_schedule_for_loop`.
- `docs/engine-reference/godot/modules/autoload.md` Claim 4 [VERIFIED] — empirical evidence for autoload `_init` zero-arg (inherited via ADR-0009).
- `docs/architecture/architecture.md` §Non-Autoload Pure-Function Modules — architectural summary that this ADR backs.
- `docs/architecture/tr-registry.yaml` TR-combat-001..028 — the 28 locked requirements this ADR codifies structurally.
