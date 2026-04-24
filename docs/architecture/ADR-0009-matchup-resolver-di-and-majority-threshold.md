# ADR-0009: Matchup Resolver — Non-Autoload DI Pattern + Majority-Threshold Contract

## Status

Accepted (2026-04-22 — promoted from Proposed in the same-day `/architecture-review 2026-04-22b` follow-up pass after no new conflicts surfaced and all matchup-resolver scope TRs verified covered)

## Date

2026-04-22

## Last Verified

2026-04-22

## Decision Makers

- Author (user) — final decision
- godot-specialist — Step 4.5 engine pattern validation; issued **BLOCK** on initial draft's `DungeonRunOrchestrator._init(combat_resolver, matchup_resolver)` pattern. Empirical probe (Pass-INIT-PROBE 2026-04-22) verified the specialist's diagnosis and landed `docs/engine-reference/godot/modules/autoload.md` Claim 4 [VERIFIED]. Revised draft below adopts the **lazy-default-with-public-setters** pattern locked by `design/gdd/dungeon-run-orchestrator.md` §J.1 (2026-04-20+, Option A) — the pre-existing GDD decision correctly anticipated the autoload `_init` zero-arg constraint and chose a "fails-closed" production wiring that the specialist's initial Option-B recommendation would have superseded unnecessarily. See §Reconciliation below.
- technical-director — SKIPPED (review-mode.txt = solo; gate TD-ADR not invoked)

## Summary

`MatchupResolver` is implemented as a non-autoload `class_name MatchupResolver extends RefCounted` module. The production subclass `DefaultMatchupResolver` is lazily constructed inside `DungeonRunOrchestrator._ready()` (via `DefaultMatchupResolver.new()` — zero-arg on a non-autoload RefCounted) IF the orchestrator's `_matchup_resolver` field is still null at `_ready()` time. Tests pre-inject spy subclasses via the public setter `orchestrator.set_matchup_resolver(spy)` BEFORE triggering `_ready()` (either by `add_child(orch)` in a test scene, or by calling `orch._ready()` directly after construction). The null-check in `_ready()` short-circuits when a spy is already installed — production gets defaults "fails-closed"; tests get spy injection via the same code path. Parallel pattern for `CombatResolver` (setter: `set_combat_resolver`) per Combat Pass 3D + this ADR. The resolver exposes two public instance methods (`resolve_formation_matchup`, `resolve_floor_matchup`) returning a `MatchupResult` value type (`is_advantaged: bool` + sorted deduplicated `matched_archetypes: Array[String]`). Aggregation uses strict majority (`n > N/2` integer division) — not boolean OR. Offline replay consults `snapshot.matched_archetypes.has(archetype)` and MUST NOT invoke the resolver or `DataRegistry.resolve` per replayed kill.

## Engine Compatibility

| Field | Value |
|---|---|
| **Engine** | Godot 4.6 |
| **Domain** | Core / Scripting (RefCounted module, autoload lifecycle, lazy-default `_ready()` construction, test-facing setters, instance method polymorphism via `extends`) |
| **Knowledge Risk** | **MEDIUM** — elevated from LOW at Step 4.5 due to the autoload `_init` arg-passing gotcha surfaced by godot-specialist and empirically verified by Pass-INIT-PROBE (2026-04-22). All other patterns (RefCounted subclass override, `Array[String]` typed arrays, static vs instance func, non-autoload `.new(args)` constructor) are LOW-risk and stable since Godot 4.0. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; `docs/engine-reference/godot/modules/autoload.md` Claim 1 [VERIFIED] (boundary — resolver sits OUTSIDE the autoload table) + Claim 4 [VERIFIED] (`_init` arg-passing on autoload Node scripts fails with "Method expected N argument(s), but called with 0") |
| **Post-Cutoff APIs Used** | None. `@abstract` is NOT used here. |
| **Verification Required** | None — Pass-INIT-PROBE (2026-04-22) executed on Godot 4.6.1.stable.mono.official. Pass 1 falsification: autoload `_init(a: int, b: int)` → boot error `"Method expected 2 argument(s), but called with 0"` at `_create_instance (modules/gdscript/gdscript.cpp:200)`. Pass 2 confirmation: zero-arg `_init()` + `_ready()` + non-autoload inner-class `RefCounted.new(args)` all printed cleanly. See `autoload.md` Claim 4 §Empirical evidence. The lazy-default-with-setters pattern this ADR codifies works under the same engine guarantees Pass 2 verified (zero-arg `_init` on autoload Node + `.new()` on non-autoload RefCounted — neither is novel; the pattern composes verified primitives). |

## ADR Dependencies

| Field | Value |
|---|---|
| **Depends On** | ADR-0003 (Accepted — Amendment #3 corrects Amendment #2's mechanically-impossible `_init(args)` phrasing to the lazy-default-with-setters pattern this ADR codifies, authored in lockstep); ADR-0006 (Accepted — `DataRegistry.resolve("classes", id)` is the single upstream call the resolver makes) |
| **Enables** | ADR-X01 (Combat snapshot shape + CombatResolver DI pattern — parallel module at vacated rank 9; adopts the same `set_combat_resolver` public setter + lazy-default `_ready()` wiring); Orchestrator dispatch + matchup-integration stories; Offline Engine replay-determinism stories (H-13, H-17) |
| **Blocks** | Any Matchup Resolver implementation story; any Orchestrator dispatch / matchup-integration story; any Matchup Assignment Screen story; any Offline Engine replay story asserting zero-resolver-call invariant |
| **Ordering Note** | Author BEFORE ADR-X01 — X01's CombatResolver is a structural mirror of this ADR's pattern and uses the parallel `set_combat_resolver` setter. |

## Reconciliation with `design/gdd/dungeon-run-orchestrator.md` §J.1 (locked)

The initial draft of this ADR specified a single `wire_dependencies(combat_resolver, matchup_resolver)` named method as the DI seam (godot-specialist's Step 4.5 Option B recommendation). After drafting, review of `design/gdd/dungeon-run-orchestrator.md` §J.1 ("Wiring model — Script autoload with lazy-default DI (locked)", Pass 5C+ dated) surfaced that the Orchestrator GDD had already:

1. Correctly anticipated the autoload `_init` zero-arg constraint (§J.1 line 1105: *"Godot instantiates the script at project load and calls `_init()` with no arguments, then calls `_ready()` after the scene tree is available"*).
2. Selected **Option A — lazy-default with public setters** as the DI pattern.
3. Explicitly rejected the equivalent of `wire_dependencies` as Option E (§J.1 line 1249): *"Explicit `initialize()` method (no lazy defaults)… Rejected: production code would need a separate bootstrap that calls `initialize()` — reintroduces Option B's indirection without Option A's zero-config win. Fails open (dispatch before `initialize()` would crash) rather than failing closed (lazy-default-safe production path)."*

This ADR **codifies §J.1's Option A verbatim** and makes it the project-wide canonical DI pattern for autoload-level injection. The godot-specialist's Step 4.5 Option-B recommendation is retained below as Alternative 5 (post-Step-4.5 consideration, aligned-with-rejected-in-GDD).

## Context

### Problem Statement

`design/gdd/class-vs-enemy-matchup-resolver.md` (Pass 5C, 2026-04-20) specifies a stateless injectable-instance pattern that crosses four system boundaries (Orchestrator, Combat, Offline Engine, Matchup Assignment Screen) and has no codifying ADR. `/architecture-review 2026-04-22` surfaced this as CONFLICT-1 — the prior architecture.md + ADR-0003 draft placed `ClassEnemyMatchupResolver` at autoload rank 8, which would have broken the GDD-mandated spy-subclass DI pattern and the Orchestrator re-review's AC-ORC-11 mockability gate (GdUnit4 cannot mock static or autoload methods).

ADR-0003 Amendment #2 (same day) vacated ranks 8 + 9 and referenced a future ADR to codify the full contract. This is that ADR. It locks:

1. The non-autoload `RefCounted` module shape + Orchestrator lazy-default DI via public setters (`set_combat_resolver`, `set_matchup_resolver`).
2. The `MatchupResult` value-type schema.
3. The majority-threshold aggregation rule (`n > N/2`), revised from boolean OR on 2026-04-19 and locked by Hero Class DB E.5.
4. The `matched_archetypes` deduplication + alphabetical sort invariant.
5. The spy-subclass test pattern.
6. The offline-replay zero-resolver-call invariant (H-13 AND clause + H-17).

**Step 4.5 discovery**: the initial draft of this ADR (and ADR-0003 Amendment #2) specified `DungeonRunOrchestrator._init(combat_resolver, matchup_resolver)` as the injection path. godot-specialist Step 4.5 review BLOCKED on this: Godot's autoload system instantiates via `_create_instance` which calls `_init()` with zero arguments; an autoload script with required `_init(args)` fails at boot. Pass-INIT-PROBE (2026-04-22) empirically verified the finding — see `autoload.md` Claim 4. ADR-0003 Amendment #3 corrects the Amendment-#2 phrasing in lockstep with this ADR. The adopted pattern (lazy-default with public setters) matches the already-locked `dungeon-run-orchestrator.md` §J.1 Option A decision.

### Current State

- `design/gdd/class-vs-enemy-matchup-resolver.md` is approved (2026-04-19 re-review) + Pass 5C DI-converted (2026-04-20). 17 ACs; 13 BLOCKING. GDD Pass-INIT-PROBE-SYNC note updated in lockstep with this ADR to correct the `_init(combat_resolver, matchup_resolver)` phrasing to `set_matchup_resolver(matchup_resolver)` + lazy-default `_ready()`.
- `design/gdd/dungeon-run-orchestrator.md` §J.1 is the already-locked source-of-truth for the Orchestrator wiring pattern. This ADR codifies §J.1 at ADR-level. No pattern change to the GDD — only a Pass-INIT-PROBE-SYNC note appended confirming ADR-0009 adopted §J.1's locked decision.
- ADR-0003 Amendment #2 (Accepted 2026-04-22) removed ranks 8 + 9 from the autoload table; Amendment #3 (same day, in lockstep with this ADR) corrects the `_init` phrasing per Claim 4.
- `docs/architecture/architecture.md` §Non-Autoload Pure-Function Modules + §Module Ownership Map MatchupResolver + CombatResolver rows corrected in lockstep to reference the setter-based injection.
- Combat GDD (`combat-resolution.md`) Pass-INIT-PROBE-SYNC note corrected in lockstep (same mechanical swap).
- Registry drift: `data_registry_ready_edge` consumers list previously contained `ClassEnemyMatchupResolver # rank 8` (stale; the resolver is non-autoload, has no `_ready()`, does not subscribe to signals). Removed in this ADR's registry update.
- No resolver implementation exists yet (no `.gd` file under `src/gameplay/matchup/`). This ADR is pure design codification.

### Constraints

- **Godot autoload `_init` gotcha (Claim 4 [VERIFIED])**: autoload-registered Node scripts are instantiated with `_init()` called zero-arg. Required `_init(args)` fails at boot. This applies ONLY to autoload-level instantiation; non-autoload RefCounted classes retain full `.new(args)` support.
- GdUnit4 4.6 cannot mock static methods on a `class_name` type — forcing the conversion from static-utility to instance methods (Pass 5C, 2026-04-20). AC-ORC-11 (Orchestrator matchup-cache correctness) is architecturally unwritable without an injectable instance.
- The resolver is on the hot path of the Orchestrator's per-kill signal emission. Performance is ACLD-gated (H-14 ADVISORY, CI canary BLOCKING within).
- Offline replay determinism (Pillar 1 — player time is sacred) requires that per-kill replay consult the frozen snapshot, not the live resolver. H-13 + H-17 assert zero `MatchupResolver.*` and zero `DataRegistry.resolve` calls during replay.
- **Production wiring must "fail closed"** — a ship build where a programmer forgot to explicitly wire the resolver should still boot into a playable state with production defaults. The lazy-default pattern achieves this; an explicit `wire_dependencies`-must-be-called-first pattern would fail-open (boot success, then crash on first dispatch with "no resolver"). Per `dungeon-run-orchestrator.md` §J.7 Option E rejection.

### Requirements

- The resolver MUST be injectable into `DungeonRunOrchestrator` for test spy substitution.
- The Orchestrator MUST have a zero-parameter `_init` (or no `_init` at all) — required-arg `_init` on an autoload is mechanically impossible per Claim 4.
- Production boot MUST succeed with zero manual wiring (lazy-default construction inside `_ready()`).
- The resolver MUST have zero class-scope mutable state, zero signals, no caches, no RNG, no time-dependent reads (Rule 12 pure-function contract).
- The resolver MUST NOT appear as an `[autoload]` entry in `project.godot`.
- The production base class `MatchupResolver` MUST be extendable — `DefaultMatchupResolver` is the production subclass; tests extend `MatchupResolver` directly with spy/stub subclasses.
- Public methods MUST be regular instance `func`, NOT `static func` (enforced by H-16 structural CI test).
- `MatchupResult.matched_archetypes` MUST be sorted alphabetically and deduplicated for byte-identical golden-file comparison.
- The aggregation rule MUST be `n > N/2` (strict majority, integer division) — not boolean OR, not unanimity.
- Offline replay MUST consult `snapshot.matched_archetypes.has(archetype)` directly; resolver calls during replay are forbidden and CI-asserted.

## Decision

### Module shape

```gdscript
# src/gameplay/matchup/matchup_resolver.gd
class_name MatchupResolver extends RefCounted
## Injectable instance. Zero class-scope state, zero signals, no caches, no RNG, no time reads.
## Production: DefaultMatchupResolver subclass. Tests: spy subclass extends MatchupResolver directly.
## NOT an autoload — never appears in project.godot [autoload]. CI grep enforces.

func resolve_formation_matchup(formation: Array, enemy_archetype: String) -> MatchupResult: ...
func resolve_floor_matchup(formation: Array, floor_archetypes: Array[String]) -> MatchupResult: ...
```

```gdscript
# src/gameplay/matchup/default_matchup_resolver.gd
class_name DefaultMatchupResolver extends MatchupResolver
## Production implementation — majority-threshold aggregation per this ADR §Aggregation rule.
## Constructed via DefaultMatchupResolver.new() (zero-arg) inside the Orchestrator's _ready() lazy default.
```

```gdscript
# src/gameplay/matchup/matchup_result.gd
class_name MatchupResult extends RefCounted
var is_advantaged: bool
var matched_archetypes: Array[String]   # sorted alphabetically; deduplicated; empty when is_advantaged == false
```

### Injection contract — lazy-default with public setter (codifies `dungeon-run-orchestrator.md` §J.1 Option A)

```gdscript
# src/gameplay/dungeon/dungeon_run_orchestrator.gd (rank 14 AUTOLOAD — extends Node)
var _matchup_resolver: MatchupResolver = null
var _combat_resolver: CombatResolver = null

# Called by Godot on autoload load. MUST be safe to call with zero args (autoload constraint
# per autoload.md Claim 4 [VERIFIED]). Does NOT create resolvers — that's _ready()'s job.
func _init() -> void:
    pass

# Called by Godot after the scene tree is ready. Lazy-constructs default resolvers iff no
# test has pre-injected via the setters below. Production: zero-config. Test: setters have
# already populated the fields; null-checks short-circuit; no defaults are constructed.
func _ready() -> void:
    if _combat_resolver == null:
        _combat_resolver = DefaultCombatResolver.new()
    if _matchup_resolver == null:
        _matchup_resolver = DefaultMatchupResolver.new()
    # ... rest of Orchestrator _ready() per Orchestrator GDD C.3 / §J.6

# Test-facing setter. Production code NEVER calls this. Tests call it BEFORE _ready() fires
# (i.e., before add_child(orch) or before orch._ready() is invoked directly).
# Asserts non-null input (a spy that was meant to be injected but is null is a test bug; fail loud).
# If called AFTER _ready() has already installed a default, this overwrites — the calling test
# body must document the intent (late-override scenarios are uncommon but permitted).
func set_matchup_resolver(resolver: MatchupResolver) -> void:
    assert(resolver != null, "set_matchup_resolver: null not permitted")
    _matchup_resolver = resolver

func set_combat_resolver(resolver: CombatResolver) -> void:
    assert(resolver != null, "set_combat_resolver: null not permitted")
    _combat_resolver = resolver
```

### Boot wiring (production — "fails closed")

Godot's autoload system instantiates the Orchestrator Node by calling its `_init()` with zero arguments (Claim 4 [VERIFIED]), then `_ready()` fires in rank order. Inside `_ready()` the null-checks observe that `_combat_resolver` and `_matchup_resolver` are still `null` (no test has set them), and the lazy defaults construct via `.new()` on the non-autoload RefCounted subclasses (`DefaultCombatResolver.new()` + `DefaultMatchupResolver.new()` — both zero-arg on RefCounted, fully supported per Claim 4). Production boot is **zero-config** — no bootstrap script, no `initialize()` call, no way to forget to wire. If a programmer misnames the default subclass or removes its registration, boot fails loudly at the `.new()` call site (compile-time class resolution error).

### Test wiring (matches `dungeon-run-orchestrator.md` §J.3 Mode 1)

Tests instantiate the Orchestrator via `.new()`, pre-populate the resolver fields via the public setters, then either add to a test scene (to fire `_ready()` once) or call `_ready()` directly:

```gdscript
# tests/unit/dungeon/orchestrator_matchup_cache_test.gd (example — matches §J.3 Mode 1)
class SpyMatchupResolver extends MatchupResolver:
    var resolve_formation_calls: int = 0
    func resolve_formation_matchup(formation, archetype) -> MatchupResult:
        resolve_formation_calls += 1
        return super.resolve_formation_matchup(formation, archetype)  # or return a stub

func test_spy_records_calls() -> void:
    var orch: DungeonRunOrchestrator = DungeonRunOrchestrator.new()
    var spy := SpyMatchupResolver.new()
    orch.set_matchup_resolver(spy)
    orch.set_combat_resolver(SpyCombatResolver.new())
    add_child(orch)                   # fires _ready(); null-checks short-circuit; spies preserved
    # ... exercise orch ...
    assert_eq(spy.resolve_formation_calls, expected_count)
```

**Test isolation note**: define spy classes as **inner classes** inside the test file (`class SpyMatchupResolver extends MatchupResolver:`) rather than top-level `class_name SpyMatchupResolver`. GDScript's `class_name` registers globally for the session; two test files declaring the same `class_name` spy will collide at class registration time.

**Orchestrator GDD §J.3 parity**: this pattern matches `dungeon-run-orchestrator.md` §J.3 Mode 1 (the pattern used by 9 of 13 orchestrator ACs — AC-ORC-01/02/06/07/08/10/11/13). ADR-0009 codifies it; the GDD is the canonical source for the broader test-mode taxonomy (Mode 2 = integration against real autoload singleton; Mode 3 = standalone no-autoload isolation).

### Aggregation rule (majority threshold)

For `resolve_formation_matchup(formation, enemy_archetype)`:

```
filtered = [hero for hero in formation if DataRegistry.resolve("classes", hero.class_id) != null]
N = filtered.size()
if N == 0: return MatchupResult { false, [] }     # Rule 10 guard
n = count(hero where class_data.counter_archetype == enemy_archetype, for hero in filtered)
is_advantaged = (n > N / 2)                        # integer division — strict majority
matched_archetypes = ["<enemy_archetype>"] if is_advantaged else []
```

For `resolve_floor_matchup(formation, floor_archetypes)`:

```
matched = sorted(unique([a for a in floor_archetypes if threshold_crossed(formation, a)]))
is_advantaged = not matched.is_empty()
return MatchupResult { is_advantaged, matched }
```

**MVP threshold concrete values** (for `FORMATION_SIZE = 3`):

- `N = 3` → threshold `n >= 2` (strict majority of 3)
- `N = 2` → threshold `n >= 2` (strict majority of 2 requires `n > 1`)
- `N = 1` → threshold `n >= 1` (solo formations qualify trivially)
- `N = 0` → Rule 10 guard returns `{false, []}` before formula reached

**Null class_data contract (H-10)**: heroes whose `class_id` does not resolve via `DataRegistry` are EXCLUDED from both `n` and `N`.

**Unknown archetype contract (H-04 + Rule 13)**: strings not countered by any loaded class (V1.0-reserved like `"beast"`, typos like `"xyzzy"`, wrong-case like `"BRUISER"`) all return `{false, []}` identically. String equality is case-sensitive.

### MatchupResult schema contract

```
is_advantaged: bool
matched_archetypes: Array[String]
  - sorted alphabetically (byte-identical golden-file comparison)
  - deduplicated
  - empty when is_advantaged == false
  - contains ONLY archetype strings (NEVER HeroInstance refs, NEVER instance_id values)
```

**RefCounted equality warning (H-07)**: `MatchupResult` extends RefCounted; `assert_eq(a, b)` compares references, not fields. Test authors MUST compare fields separately.

### Offline replay zero-call invariant

The Offline Progression Engine calls `resolve_floor_matchup` EXACTLY ONCE per dispatch at snapshot time; the resulting `MatchupResult` is stored verbatim in the snapshot. Per-kill replay consults:

```
is_matchup_advantaged = snapshot.matched_archetypes.has(enemy.archetype)    # pure Array lookup
```

**During replay** (tick-by-tick loop within a batch):

- Zero calls to `MatchupResolver.resolve_formation_matchup` / `resolve_floor_matchup` (enforced by spy-subclass call-count == 0 assertion; H-13 + H-17).
- Zero calls to `DataRegistry.resolve("classes", *)` (enforced by mocked registry call-count == 0; H-03(a) + H-17).

This invariant is mathematically equivalent to per-kill live resolution ONLY if the snapshot's `formation` AND `floor_archetypes` are both frozen at dispatch time (Rule 14). The Offline Engine GDD (#12, undesigned) owns this snapshot-freezing obligation; ADR-X02 will codify the snapshot schema.

### CI structural invariants (enforced at merge time)

| Check | Enforced By | Failure Action |
|---|---|---|
| `matchup_resolver.gd` has zero class-scope `var ` outside method bodies | Grep CI step | Block merge |
| `matchup_resolver.gd` has zero `signal ` declarations | Grep CI step | Block merge |
| All public methods in `matchup_resolver.gd` are `func `, not `static func ` (grep `^static func [a-zA-Z]` returns 0 hits) | Grep CI step | Block merge |
| Neither `MatchupResolver` nor `DefaultMatchupResolver` appears in `project.godot` `[autoload]` | ConfigFile parse in CI | Block merge |
| `DefaultMatchupResolver extends MatchupResolver` | Grep CI step | Block merge |
| `DungeonRunOrchestrator` declares `func set_matchup_resolver(resolver: MatchupResolver)` AND `func set_combat_resolver(resolver: CombatResolver)` — both asserting `resolver != null` | Grep CI step (two match predicates) | Block merge |
| `DungeonRunOrchestrator._ready()` contains the null-check lazy-default pattern for BOTH `_combat_resolver` and `_matchup_resolver` (grep for `if _combat_resolver == null:` + `if _matchup_resolver == null:` in the `_ready()` body) | Grep CI step | Block merge |
| **`dungeon_run_orchestrator.gd` `_init` (if present) has zero required parameters** — prevents regression against Claim 4 [VERIFIED] autoload `_init` zero-arg constraint. Check: grep `^func _init\(` and assert the line has no un-defaulted parameters. | Grep CI step (project-wide: applies to ALL autoload scripts, not just Orchestrator) | Block merge |
| **Combined structural regex** — asserts `class_name MatchupResolver extends RefCounted` on the file's collapsed content (not per-line), defending against multi-line or comment-injected bypass | Script-based CI step | Block merge |

### Architecture diagram

```
                 Godot autoload system
                         │
                         │  instantiates rank 14 autoload
                         │  via _create_instance() — calls _init() with ZERO args
                         │  (autoload.md Claim 4 [VERIFIED])
                         ▼
           DungeonRunOrchestrator (rank 14, extends Node)
                         │
                         │  _init() fires — zero-arg no-op per §J.1
                         ▼
                         │  _ready() fires in rank order
                         ▼
                 ┌───────┴───────┐
                 │               │
                 │  if _combat_resolver == null:
                 │      _combat_resolver = DefaultCombatResolver.new()
                 │  if _matchup_resolver == null:
                 │      _matchup_resolver = DefaultMatchupResolver.new()
                 │
                 │  (PRODUCTION — defaults installed; zero-config boot)
                 │  (TEST — setters already populated; null-checks short-circuit; spies preserved)
                 ▼
       ┌──────────────────────────────────┐
       │                                  │
       ▼                                  ▼
 _combat_resolver: CombatResolver   _matchup_resolver: MatchupResolver
       │ (ADR-X01, upcoming)             │ (this ADR)
       │                                  │

     === per-enemy-death foreground path ===
           _matchup_resolver.resolve_formation_matchup(
               frozen_formation, enemy.archetype
           ) → MatchupResult
                         │
                         ▼
           emit_signal("enemy_killed", enemy.tier, result.is_advantaged)
                         │
                         ▼
           Economy.kill_bonus(tier) * (1.5 if is_advantaged else 1.0)


     === offline replay path — Pillar 1 determinism ===
           OfflineProgressionEngine (rank 15)
                         │
                         │  snapshot time (dispatch): ONE call
                         ▼
           _matchup_resolver.resolve_floor_matchup(
               frozen_formation, frozen_floor_archetypes
           ) → MatchupResult
                         │
                         ▼
           snapshot.matched_archetypes = result.matched_archetypes   (stored verbatim)
                         │
                         │  replay loop (per kill): ZERO resolver calls
                         ▼
           is_matchup_advantaged = snapshot.matched_archetypes.has(enemy.archetype)
           (CI: spy resolver call-count == 0; mocked DataRegistry call-count == 0)


     === test path — §J.3 Mode 1 ===
           var orch := DungeonRunOrchestrator.new()
           orch.set_matchup_resolver(SpyMatchupResolver.new())    # BEFORE add_child
           orch.set_combat_resolver(SpyCombatResolver.new())
           add_child(orch)                                         # fires _ready(); null-checks
                                                                   # short-circuit; spies preserved
```

## Alternatives Considered

### Alternative 1: Autoload singleton with test-only injection method
- **Description**: Register `MatchupResolver` as an autoload. Add a test-only `set_production_resolver(r: MatchupResolver)` method gated on `OS.is_debug_build()`.
- **Rejection Reason**: Breaks the test pattern the GDD explicitly requires (Rule 1 Pass 5C; H-16 structural AC). Pre-accepted as rejected via ADR-0003 Amendment #2.

### Alternative 2: `static func` utility class
- **Description**: Keep the pre-Pass-5C shape — `class_name MatchupResolver` with all public methods `static func`.
- **Rejection Reason**: Falsified by GdUnit4 4.6 behavior — cannot mock static methods. AC-ORC-11 becomes architecturally unwritable.

### Alternative 3: Autoload with runtime `set_script` monkey-patching
- **Description**: Register `MatchupResolver` as autoload; tests swap behavior via `get_node("/root/MatchupResolver").set_script(spy_script)`.
- **Rejection Reason**: Fragile, stateful across tests, violates test isolation.

### Alternative 4: Boolean OR aggregation (pre-2026-04-19)
- **Description**: `is_advantaged = (n >= 1)` — any single counter hero grants the bonus.
- **Rejection Reason**: Locked out by Hero Class DB E.5 and matchup-resolver GDD Rule 6.

### Alternative 5 (post-Step-4.5): `_init(args)` constructor injection on the autoload Orchestrator
- **Description**: `DungeonRunOrchestrator._init(combat_resolver: CombatResolver, matchup_resolver: MatchupResolver) -> void`. Production boot supplies args; tests supply spies at construction.
- **Rejection Reason**: **MECHANICALLY IMPOSSIBLE on Godot 4.6.** Godot's autoload system calls `_init()` with zero arguments (autoload.md Claim 4 [VERIFIED]). Discovered at this ADR's own Step 4.5 review; `_init(args)` phrasing was corrected in ADR-0003 Amendment #3 in lockstep.

### Alternative 6 (post-Step-4.5): Explicit `wire_dependencies(combat, matchup)` named method called from `_ready()` (godot-specialist Step 4.5 Option B)
- **Description**: Single public method `wire_dependencies(combat_resolver, matchup_resolver) -> void` with one-shot assertion (`assert(_matchup_resolver == null)` before assignment). Production: `_ready()` calls `wire_dependencies(DefaultCombatResolver.new(), DefaultMatchupResolver.new())`. Tests: construct Orchestrator standalone (NOT added to scene tree), call `wire_dependencies(spy_combat, spy_matchup)` explicitly.
- **Pros**: Single injection method; one-shot semantics prevent re-wiring; consolidates both resolver's wiring into one call.
- **Cons**: **Fails open** — a production code path that bypasses `_ready()` (or an `_ready()` that forgets to call `wire_dependencies` after a refactor) boots successfully, then crashes at first dispatch with "resolver is null". Lazy-default pattern fails closed instead — production always boots playable. Tests must construct the Orchestrator WITHOUT adding to scene tree; `add_child(orch)` would fire `_ready()` which installs production defaults and overwrites spies — a silent false-positive failure mode. The one-shot assertion makes late-override test scenarios impossible (`dungeon-run-orchestrator.md` §J.2 documents rare late-override cases where post-`_ready()` setter calls are intentional).
- **Rejection Reason**: godot-specialist Step 4.5 recommended this pattern without knowledge of `dungeon-run-orchestrator.md` §J.1 Option A already being the locked decision (Pass 5C+, 2026-04-20+). §J.7 Option E explicitly rejects this pattern's equivalent with the "fails open vs fails closed" rationale above. This ADR adopts §J.1's Option A (lazy-default with public setters) instead. The initial draft of this ADR proposed Option B; the draft was corrected before write approval.

## Consequences

### Positive

- **Testability unlock**: AC-ORC-11 (Orchestrator matchup-cache correctness) becomes architecturally writable. Spy subclasses inject cleanly via `set_matchup_resolver()`; no runtime script-swap, no autoload-state leakage between tests.
- **Production fails closed**: lazy-default construction means a shipped build with no test-harness plumbing boots into a fully-playable state with production defaults. No forgotten-wiring failure mode.
- **Offline determinism mechanically enforced**: the zero-resolver-call invariant during replay is spy-asserted (H-13 AND clause, H-17).
- **Pillar 1 (player time is sacred) preserved structurally**: the frozen-snapshot + zero-call-during-replay pattern makes offline replay mathematically equivalent to per-kill live resolution.
- **Pillar 3 ("Matchup Is a Decision") locked mechanically**: majority-threshold aggregation produces a specialist-vs-generalist tradeoff at MVP scale.
- **Rank table integrity**: ranks 8 + 9 stay vacant; downstream ranks keep their assignments. ADR-X01's CombatResolver uses the parallel pattern with its own `set_combat_resolver` setter.
- **GDD-ADR alignment preserved**: this ADR codifies `dungeon-run-orchestrator.md` §J.1 Option A verbatim rather than superseding it. No contradiction between ADR and GDD; `/architecture-review` will cleanly trace ADR-0009 → §J.1 → Pass 5C DI decision.

### Negative

- **Two setter methods instead of one**: `set_combat_resolver` + `set_matchup_resolver` are separate methods. Tests that inject both must call both. Tradeoff: each is a single-purpose, asserting, non-overloadable DI point — clearer than a combined method where a test might accidentally omit one argument.
- **Test-only public surface in production binary**: `set_matchup_resolver` and `set_combat_resolver` ship in release builds. They're one-line assertion-gated setters (zero production call sites by convention) — cost is a couple bytes per method. `OS.is_debug_build()` gating was considered and rejected by §J.1 (mirror-symmetric with test-only methods elsewhere; consistent naming beats asymmetric gating).
- **MVP-locked aggregation rule**: majority threshold is non-negotiable for MVP (Rule 6 + Class DB E.5). V1.0 may revisit pending playtest evidence. Orthogonal to this ADR's shape.

### Neutral

- The resolver's `DataRegistry.resolve("classes", id)` call per hero per invocation is inside the hot path. H-14 ADVISORY is the canary.
- `MatchupResolver` extends `RefCounted` rather than `Object`. Automatic reference counting — no manual `free()`.

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Developer adds a required-arg `_init(...)` to `DungeonRunOrchestrator` (or any other autoload) in a future sprint, silently reintroducing the Claim 4 boot-failure pattern | Medium | High (autoload fails instantiation at boot) | §CI structural invariants table includes a project-wide grep assertion: every autoload script's `_init` (if present) must have zero required parameters. Applies to ALL autoload scripts. Backed by Claim 4 [VERIFIED]. |
| Spy subclass `class_name` collision between two test files | Low | Medium | Define spy subclasses as inner classes inside test files; coding-standards.md adds the rule. |
| CI structural grep fooled by multi-line or comment-injected declarations | Low | Low-Medium | §CI structural invariants includes a script-based check that collapses file content (strip blank lines + comments) and runs the regex on the collapsed text. |
| Test calls `set_matchup_resolver(spy)` AFTER `add_child(orch)` — defaults have already installed, setter overwrites silently | Medium | Medium (test exercises spy after `_ready()` has already constructed defaults; intentional "late override" scenarios work correctly, but the setter overwrite is unobserved if the test author didn't mean to do it) | §J.2 explicitly documents that post-`_ready` setter calls are permitted for late-override scenarios. Coding-standards.md rule: "Test asserts setter call is BEFORE `add_child(orch)` unless the test body comment documents a late-override intent." Not CI-enforceable beyond convention. |
| Test forgets one of the two setters — only `set_matchup_resolver(spy)` called, `set_combat_resolver` left to lazy-default | Medium | Low (test exercises spy matchup + production combat — sometimes correct, sometimes the wrong test surface; the test passes green or fails in a misleading way) | `tests/helpers/orchestrator_factory.gd` helper encapsulates the double-setter pattern (`factory.with_both_spies(combat_spy, matchup_spy)` returns a fully-wired Orchestrator); coding-standards.md rule: "Prefer the factory over raw constructor + setters." |
| `DataRegistry.resolve("classes", id)` performance regression | Low | Medium | H-14 ADVISORY with CI-BLOCKING gate inside. |
| Post-MVP playtest demands aggregation rule change | Medium | Low (contained) | Aggregation formula lives in `DefaultMatchupResolver`; a new `AltThresholdMatchupResolver extends MatchupResolver` ships without touching this ADR. |

## GDD Requirements Addressed

| GDD Document | Requirement | How This ADR Addresses It |
|---|---|---|
| `design/gdd/class-vs-enemy-matchup-resolver.md` Rule 1 (Pass 5C + Pass-INIT-PROBE-SYNC) | `class_name MatchupResolver extends RefCounted`; instance methods; `DefaultMatchupResolver` production subclass; injected via Orchestrator's public setter `set_matchup_resolver(resolver)` pre-`_ready()` | §Module shape + §Injection contract codify |
| `design/gdd/class-vs-enemy-matchup-resolver.md` Rules 2-14 + H-01..H-17 | Stateless resolver contract, majority threshold, schema, edge cases, offline zero-call invariant, structural CI | §Aggregation rule + §MatchupResult + §CI structural invariants + §Offline replay zero-call invariant codify |
| `design/gdd/combat-resolution.md` TR-combat-001/004 (mirror pattern) | `class_name CombatResolver extends RefCounted`; `DefaultCombatResolver` production subclass; injected via `set_combat_resolver(resolver)` pre-`_ready()` | §Injection contract codifies the parallel setter for CombatResolver; ADR-X01 will author the full Combat-side contract |
| `design/gdd/dungeon-run-orchestrator.md` §J.1 (locked — "Wiring model — Script autoload with lazy-default DI") | Zero-arg `_init` + `_ready()` lazy-default construction + two public setters (`set_combat_resolver`, `set_matchup_resolver`) | §Injection contract + §Boot wiring + §Test wiring codify §J.1 verbatim at ADR level; §Alternative 6 documents §J.7 Option E rejection rationale |
| `design/gdd/hero-class-database.md` D.2 + E.5 | `is_class_counter` = string equality on `counter_archetype`; majority threshold rule | §Aggregation rule references |
| `design/gdd/economy-system.md` D.2 | `MATCHUP_GOLD_MULTIPLIER = 1.5` applied when `is_matchup_advantaged == true` | §Architecture diagram end-to-end path |

## Performance Implications

| Metric | Before | Expected After | Budget |
|---|---|---|---|
| CPU (per `resolve_formation_matchup` call, N=3) | N/A | ~<10μs | H-14 ADVISORY: <200ms / 10,000 calls on CI, <50ms / 10,000 calls on Steam Deck |
| CPU (offline replay per kill, with snapshot lookup) | N/A | 1 × `Array[String].has(String)` ≈ sub-μs | AC-TICK-10 BLOCKING (<500ms for 576,000-tick worst case) |
| Memory (per `MatchupResult` allocation) | N/A | ~40 bytes | 512MB — negligible |
| Memory (snapshot `matched_archetypes: Array[String]`) | N/A | ~64 bytes per snapshot | 512MB — negligible |

## Migration Plan

**No migration needed.** No implementation exists yet. When the first implementation story lands:

1. Create `src/gameplay/matchup/matchup_resolver.gd` + `default_matchup_resolver.gd` + `matchup_result.gd` per §Module shape.
2. Add H-16 CI structural assertion test + the project-wide "autoload `_init` zero-required-arg" CI check.
3. Implement `DungeonRunOrchestrator._ready()` lazy-default + `set_matchup_resolver` / `set_combat_resolver` setters exactly as §J.1 specifies.
4. Add `tests/helpers/orchestrator_factory.gd` with the double-setter helper per Risk mitigation.
5. Author the 13 BLOCKING + 4 ADVISORY unit tests per the matchup-resolver GDD §H.
6. Combat Pass 3E (separate, Combat-team-owned) migrates Combat's static `MatchupResolver.resolve_formation_matchup(...)` bridge call site to the instance-method form; ADR-X01 governs.

**Rollback plan**: If post-MVP playtest evidence demands an aggregation rule change, the change is GDD-revision territory, NOT this ADR. This ADR's DI shape (lazy-default with setters) is orthogonal to the aggregation formula.

## Validation Criteria

- [ ] `src/gameplay/matchup/matchup_resolver.gd` exists with exactly one `class_name MatchupResolver extends RefCounted` declaration.
- [ ] `src/gameplay/matchup/default_matchup_resolver.gd` exists with `class_name DefaultMatchupResolver extends MatchupResolver`.
- [ ] Neither class appears as `[autoload]` in `project.godot`.
- [ ] `matchup_resolver.gd` contains zero class-scope `var` declarations outside method bodies, zero `signal` declarations, and all public methods are `func` not `static func`.
- [ ] `DungeonRunOrchestrator` declares `func set_matchup_resolver(resolver: MatchupResolver)` + `func set_combat_resolver(resolver: CombatResolver)`, each with a non-null assert.
- [ ] `DungeonRunOrchestrator._ready()` contains lazy-default null-check + `.new()` construction for BOTH `_combat_resolver` and `_matchup_resolver`.
- [ ] `DungeonRunOrchestrator._init` (if present) has zero required parameters (CI grep assertion).
- [ ] `MatchupResult.matched_archetypes` is sorted alphabetically and deduplicated in all returned values.
- [ ] `resolve_formation_matchup` uses integer division for the threshold check (`n > N / 2`).
- [ ] H-10 contract — heroes with null class_data are EXCLUDED from `N`.
- [ ] H-17 CI canary — spy resolver + mocked DataRegistry call-counts are both 0 during a 100-kill stub offline replay batch.
- [ ] H-16 BLOCKING CI test passes on every PR.
- [ ] Autoload `_init` zero-required-arg CI check passes on every PR (project-wide defense of Claim 4 [VERIFIED]).

## Related Decisions

- ADR-0003 (Accepted) — Amendment #2 vacated ranks 8+9; Amendment #3 (same day as this ADR) corrects Amendment #2's `_init(args)` phrasing to the lazy-default-with-setters pattern this ADR codifies.
- ADR-0006 (Accepted) — defines `DataRegistry.resolve(content_type, id)` contract.
- ADR-X01 (to author next) — Combat snapshot shape + CombatResolver DI pattern. Parallel to this ADR. Will cite this ADR as the companion decision.
- ADR-X02 (to author later) — Offline batch chunking refinement. Must codify the snapshot schema.
- `design/gdd/class-vs-enemy-matchup-resolver.md` — the authoritative GDD this ADR codifies.
- `design/gdd/combat-resolution.md` — mirror pattern for CombatResolver.
- `design/gdd/dungeon-run-orchestrator.md` §J.1 — the locked Wiring model this ADR codifies at ADR level. §J.7 Option E is the rejection rationale for the `wire_dependencies` one-shot alternative considered at Step 4.5.
- `docs/engine-reference/godot/modules/autoload.md` Claim 4 [VERIFIED] — empirical evidence for the autoload `_init` zero-arg constraint.
- `docs/architecture/architecture.md` §Non-Autoload Pure-Function Modules — architectural summary that this ADR backs.
