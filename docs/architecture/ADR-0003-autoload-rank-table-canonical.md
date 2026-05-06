# ADR-0003: Autoload Rank Table Is the Single Source of Truth for Module Init Order

## Status

Accepted

## Date

2026-04-22 (amended 2026-04-22 #1: rank invariant phrasing; amended 2026-04-22 #2: ranks 8 and 9 removed; amended 2026-04-22 #3: `_init(args)` superseded; amended 2026-04-26 #4: rank 8 = SceneManager; amended 2026-05-05 #5: rank 16 = AudioRouter; amended 2026-05-05 #6: rank 10 = FloorUnlockSystem registered under autoload name `FloorUnlock` — see §Amendments)

## Last Verified

2026-05-05

## Decision Makers

- Author (user) — final decision
- godot-specialist — engine pattern validation (pending Step 4.5)
- technical-director — solo mode skip (review-mode.txt = solo; gate TD-ADR not invoked)
- Empirical: probe results captured 2026-04-21 in `docs/engine-reference/godot/modules/autoload.md` Claim 1

## Summary

The 16-rank autoload table defined in `docs/architecture/architecture.md` (§System Layer Map) is the **canonical, hand-edited list** of every Foundation/Core/Feature autoload in the project. Init order is rank-ordered by Godot's autoload system. A rank-N autoload may forward-connect to a rank-(N+1)+ autoload's signal in its own `_ready()` — empirically VERIFIED on Godot 4.6.1. Backward references via `get_node_or_null("/root/Foo")` are allowed but discouraged. The Save/Load consumer table (`SaveLoadSystem.CONSUMER_PATHS`) is hardcoded and must be edited in lockstep with the rank table.

## Engine Compatibility

| Field | Value |
|---|---|
| **Engine** | Godot 4.6 |
| **Domain** | Core / Scripting (Autoload init order, signal connection at `_ready()`) |
| **Knowledge Risk** | LOW (claim 1 VERIFIED on Godot 4.6.1.stable.mono.official 2026-04-21) |
| **References Consulted** | `docs/engine-reference/godot/modules/autoload.md` (probe-verified); `docs/engine-reference/godot/VERSION.md`; Godot 4.6 ProjectSettings autoload docs |
| **Post-Cutoff APIs Used** | None — autoload init semantics are stable since 4.0 |
| **Verification Required** | None — Claim 1 empirical probe on 2026-04-21 covers the load-bearing assumption (rank-N→rank-(N+1) signal connect at `_ready()` succeeds) |

## ADR Dependencies

| Field | Value |
|---|---|
| **Depends On** | None |
| **Enables** | ADR-F02 (Save envelope + HMAC), ADR-F03 (Time dual-clock), ADR-F04 (DataRegistry boot scan), ADR-F05 (Scene transition + persist coupling), ADR-F06 (UI dual-focus parity); all Foundation/Core/Feature implementation stories |
| **Blocks** | All MVP epics — every Foundation/Core/Feature story must reference an autoload rank when defining its module |
| **Ordering Note** | This ADR is the first Foundation ADR. It must be Accepted before any other Foundation ADR can land, because the others reference rank slots defined here. |

## Context

### Problem Statement

Lantern Guild's runtime is built around 16 autoload singletons spanning Foundation, Core, and Feature layers. Their initialization order matters for three load-bearing reasons:

1. **Signal subscription correctness** — A rank-N autoload that connects to a rank-(N+1) autoload's signal in its own `_ready()` will silently fail if the signal owner doesn't yet exist. Save/Load §C.3 (rank 2) connects to Economy/HeroRoster/FloorUnlock/FormationAssignment/Recruitment/DungeonRunOrchestrator (ranks 3-14) signals at `_ready()` — if rank order isn't established, every consumer's `get_save_data` round-trip silently breaks on the next persist.

2. **Save/Load consumer enumeration** — `SaveLoadSystem.CONSUMER_PATHS` is a hardcoded ordered list of autoload node paths (per Save/Load §C.3 Pass-5D). Rank changes that aren't reflected in this constant cause silent partial saves (a missing consumer's state vanishes on the next load).

3. **Foundation/Core/Feature dependency invariant** — The architecture doc declares "rank N may only forward-connect to rank N+1+" as a load-bearing principle. Without an authoritative rank table, individual stories may inadvertently introduce backward signal dependencies that work locally but break under hot-reload, save/load round-trips, or MVP playtest sequencing.

The architecture doc currently encodes the rank table as a markdown section. This ADR formalizes that section as the **single source of truth** and defines the protocol for editing it.

### Current State

- `docs/architecture/architecture.md` §System Layer Map → §Autoload Rank Table contains the 16-rank table (rank 0 TickSystem → rank 15 OfflineProgressionEngine).
- `design/gdd/save-load-system.md` §C.3 contains a 6-entry hardcoded `CONSUMER_PATHS` constant with a per-call `get_node_or_null()` resolution pattern (NEVER cached) and a `node == null → fatal` assert in non-debug builds.
- The empirical autoload probe (2026-04-21, Godot 4.6.1.stable.mono.official) confirmed: both autoloads' `_ready()` fire after all autoload nodes are added to the tree; rank-N→rank-(N+1) signal connection at `_ready()` is safe; bare-identifier resolution (`ProbeSource == <node>`) returns true.
- No ADR currently codifies the rank-table-as-source-of-truth principle. ADR-0001 + ADR-0002 reference specific autoloads by name without anchoring them to a rank.

### Constraints

- Godot's autoload system is rank-ordered by the order they appear in Project Settings → Autoload (or `project.godot` `[autoload]` section). The order is not derived from script content — it must be hand-maintained.
- Hot-reload in dev builds swaps an autoload's underlying Node instance under the same path, invalidating any cached `var _x: X = X` capture taken at `_ready()`. Per-call `get_node_or_null(path)` always returns the current instance (Save/Load §C.3 already enforces this for consumers).
- The Save/Load consumer table's order matters for migration safety: appending a new consumer is safe; reordering existing consumers requires a save schema bump.
- MVP timeline (4-6 weeks) cannot afford a runtime registry / DI framework. Hardcoded constants + code review discipline are sufficient.

### Requirements

- Init order MUST be deterministic across builds and platforms.
- A rank-N autoload MUST be able to safely connect to rank-(N+1)+ signals in its own `_ready()`.
- Backward references (rank N reading rank M where M < N) MUST be possible at runtime (after all `_ready()` fires) but discouraged at `_ready()` time.
- Adding/removing/reordering autoloads MUST require editing exactly TWO authoritative locations: (a) the rank table in `architecture.md`, and (b) Godot's `project.godot` `[autoload]` section. If the autoload is a Save/Load consumer, ALSO `SaveLoadSystem.CONSUMER_PATHS`.
- The rank table MUST be referenced by every story that introduces a new autoload, by ADR (or supersession) for any reorder, and by `/architecture-review` to validate that all `_ready()`-time signal connections are forward-only.

## Decision

### The contract

The 16-rank autoload table in `docs/architecture/architecture.md` §Autoload Rank Table is the **canonical source**. The rank assignments are:

```
Rank 0  — TickSystem                  (Foundation)
Rank 1  — DataRegistry                     (Foundation)
Rank 2  — SaveLoadSystem                   (Foundation)
Rank 3  — Economy                          (Core)
Rank 4  — HeroClassDatabase                (Core)
Rank 5  — EnemyDatabase                    (Core)
Rank 6  — BiomeDungeonDatabase             (Core)
Rank 7  — HeroRoster                       (Feature)
Rank 8  — SceneManager (Foundation)
Rank 9  — [VACANT — see §Non-Autoload Pure-Function Modules]
Rank 10 — FloorUnlockSystem                (Feature)
Rank 11 — FormationAssignment              (Feature)
Rank 12 — Recruitment                      (Feature)
Rank 13 — HeroLeveling                     (Feature)
Rank 14 — DungeonRunOrchestrator           (Feature)
Rank 15 — OfflineProgressionEngine         (Feature)
```

**Rank 8 is now occupied by SceneManager (Foundation)** per Amendment #4 (2026-04-26 — story S5-M4 closed OQ-8). **Rank 9 is deliberately vacant.** Per Amendment #2 (2026-04-22), `ClassEnemyMatchupResolver` and `CombatResolution` were removed from the autoload table because their GDDs specify them as non-autoload `RefCounted` instance classes. Rank 8's vacant slot has been claimed by SceneManager per the editing protocol (claiming a vacant slot is preferred over reordering). Rank 9 downstream was NOT renumbered — leaving the slot empty is preferable to reordering (per §Editing protocol, reordering is forbidden without a superseding ADR). See §Non-Autoload Pure-Function Modules below.

`SceneManager` is at rank 8 (see Amendment #4, 2026-04-26). `UIFramework` (theme resource) and `AudioSystem` are not in the rank table — they are either non-autoloads or the rank is implementation-detail (for AudioSystem, "after DataRegistry" is the only constraint).

### Non-autoload pure-function modules

Two modules are implemented as `class_name X extends RefCounted` and **NOT** registered as Godot autoloads. They are constructed once at boot and injected into `DungeonRunOrchestrator` via its `_init(combat_resolver, matchup_resolver)` constructor. Tests inject spy subclasses via the same constructor.

| Module | Class declaration | Injection target | Ownership contract |
|---|---|---|---|
| `MatchupResolver` | `class_name MatchupResolver extends RefCounted` | `DungeonRunOrchestrator._init(…, matchup_resolver)` | Stateless (zero instance vars, zero signals, no caches, no RNG, no time-dependent reads); `DefaultMatchupResolver` is the production subclass |
| `CombatResolver` | `class_name CombatResolver extends RefCounted` | `DungeonRunOrchestrator._init(combat_resolver, …)` | Stateless pure functions of `(formation, floor, tick_range)`; `DefaultCombatResolver` is the production subclass |

**Why non-autoload**: these modules are pure functions. Autoload status would defeat the spy-subclass-for-testing DI pattern (the two GDDs document this as a structural invariant — see `design/gdd/class-vs-enemy-matchup-resolver.md` TR-matchup-resolver-001/002/030 and `design/gdd/combat-resolution.md` TR-combat-001/004). Autoload would also create a cross-autoload state-read trap for anyone reading the autoload table and assuming these modules exposed state.

**CI invariant**: `matchup_resolver.gd` and `combat_resolver.gd` (or their `class_name` equivalents) MUST have zero class-scope vars, zero signals, no static public `func`, and MUST NOT appear as `[autoload]` entries in `project.godot`. Grep-based CI check enforces.

**Rank-table implications**:
- Both modules are **unranked** — they do not participate in `_ready()` ordering because they are not Nodes in the tree.
- Orchestrator (rank 14) holds references to them through its `_init` constructor. At the point Orchestrator's `_ready()` runs, both resolvers exist in memory; no rank-invariant hazard.
- Neither module exposes signals, so the signal-subscription pattern of the rank invariant does not apply.
- Neither module reads or writes state on any autoload — they are pure functions of their arguments.

### Rank invariant (amended 2026-04-22 per ADR-0005 OQ-6)

**Original phrasing (2026-04-22, superseded same day)**: "A rank-N autoload may connect to a rank-M autoload's signal in its own `_ready()` ONLY if M > N." This was empirically too restrictive — it conflated signal subscription (which is rank-independent) with state reads (which are rank-constrained). The amended invariant below is the authoritative form.

**Amended invariant (2026-04-22, godot-specialist Step 4.5 confirmed)**:

> **Signal SUBSCRIPTION across any rank pair at `_ready()` time is safe.** Signal objects exist on Node instantiation (autoload.md Claim 1 [VERIFIED] — all autoload Nodes are added to the scene tree before any `_ready()` fires). A rank-N autoload may call `OtherAutoload.signal_x.connect(handler)` in its own `_ready()` regardless of OtherAutoload's rank, because the signal object on OtherAutoload exists and is mutable the moment OtherAutoload was instantiated.
>
> **STATE READS across rank pairs at `_ready()` time are constrained**:
> - **Allowed**: a rank-N autoload may read state from a rank-M autoload at its own `_ready()` time IF M < N (the lower-rank autoload's `_ready()` has already completed, so any state set there is visible).
> - **FORBIDDEN — same-rank state reads at `_ready()`**: intra-rank `_ready()` order is implementation-defined; reading a same-rank autoload's `_ready()`-set state may see uninitialized values.
> - **FORBIDDEN — backward state reads at `_ready()`**: a rank-N autoload reading state from a rank-M autoload where M > N at `_ready()` time will see the M autoload's pre-`_ready()` state (typically default values), because rank-M's `_ready()` has not yet run.
>
> **Signal EMISSION ORDERING between consumers**: When multiple consumers subscribe to the same signal, the emission order during `signal.emit()` follows connection order, NOT rank order. By convention, consumers connect at `_ready()` time, so connection order coincides with `_ready()` invocation order (rank-sequential). Rank reassignments must preserve any required consumer-ordering invariants (see ADR-0005 Risks for the `tick_fired` Economy → Orchestrator → View ordering example).
>
> **All cross-autoload calls AFTER all `_ready()` fires are unrestricted** — bare-identifier resolution, `get_node_or_null("/root/Foo")`, method calls, state reads. The constraints above apply ONLY to the `_ready()` execution window.

**Empirical evidence backing the amendment**:
- Probe ProbeSink (rank 2) connecting to ProbeSource (rank 1) signal in ProbeSink's `_ready()` — VERIFIED works (autoload.md Claim 1, 2026-04-21).
- godot-specialist Step 4.5 review of ADR-0005 confirmed: signal subscription is rank-independent because signal objects predate any `_ready()` invocation; rank ordering only affects state-read safety in `_ready()` bodies.

**What the original invariant was trying to forbid (preserved)**: backward STATE READS at `_ready()` time. That constraint is real and remains in force under the amended invariant.

**Allowed at runtime (after all `_ready()` fires) — unchanged**:
- Any autoload may call into any other autoload via `get_node_or_null("/root/Foo")` or bare-identifier resolution.
- Cross-rank method calls and state reads are unrestricted post-init.

### Save/Load consumer table protocol

`SaveLoadSystem.CONSUMER_PATHS` is the secondary authoritative list. It contains a subset of the rank table — the autoloads that own persistent state. Current contents (ordered):

```
1. /root/Economy                  (rank 3)
2. /root/HeroRoster               (rank 7)
3. /root/FloorUnlock              (rank 10)
4. /root/FormationAssignment      (rank 11)
5. /root/Recruitment              (rank 12)
6. /root/DungeonRunOrchestrator   (rank 14)
```

`TickSystem` (rank 0) is a special bidirectional consumer accessed via named methods (`get_last_persist_ts` / `set_last_persist_ts`), not via `get_save_data` / `load_save_data`. It is NOT in `CONSUMER_PATHS`.

`DataRegistry` (rank 1), `HeroClassDatabase` (rank 4), `EnemyDatabase` (rank 5), `BiomeDungeonDatabase` (rank 6), `ClassEnemyMatchupResolver` (rank 8), `CombatResolution` (rank 9), `HeroLeveling` (rank 13), `OfflineProgressionEngine` (rank 15), and `SaveLoadSystem` itself (rank 2) are NOT in `CONSUMER_PATHS` — they are stateless or own only transient state.

### Editing protocol (the "lockstep edit")

To add a new autoload: edit (a) the rank table in `architecture.md`, (b) `project.godot` `[autoload]` section. If the new autoload owns persistent state: ALSO add it to (c) `SaveLoadSystem.CONSUMER_PATHS` and (d) bump the save `schema_version`.

To remove an autoload: same three locations, in reverse. If it was a save consumer, write a save migration that drops its sub-dictionary on load.

To reorder existing autoloads: forbidden without an explicit superseding ADR. Reordering can flip a previously-safe forward signal connection into a forbidden backward one. Any reorder requires:
1. A new ADR superseding this one (or amending §Editing protocol)
2. A code-review pass through every `_ready()` method that connects to another autoload's signal, verifying the new ranks still satisfy the invariant
3. A save schema bump (because consumer order in the persisted dict may change)

To add a non-state autoload (helper, debug-only): rank assignment is implementation-detail; pick a rank ≥ the highest rank it depends on at `_ready()`-time. No `CONSUMER_PATHS` change.

### Architecture diagram

```
project.godot [autoload]                      docs/architecture/architecture.md
   ↓ (Godot reads at boot)                       ↓ (humans + /architecture-review read)
[ rank 0..15 autoloads added to /root ]      [ canonical rank table ]
   ↓ (Godot fires _ready in rank order)
   for each rank N in 0..15:
       autoload_N._ready() runs
           may call get_node_or_null("/root/RankM") with M > N → safe
           may connect("/root/RankM").signal_x → safe (signals exist; method may not yet have completed setup, but signal subscription is async-safe)
           may NOT depend on RankM having completed its own _ready() body
       end
   end

After all _ready() fires:
   tree is fully alive; cross-rank calls are unrestricted

SaveLoadSystem._on_registry_ready (DataRegistry rank 1 emits registry_ready):
   for path in CONSUMER_PATHS:
       node = get_node_or_null(path)         # NEVER cached — hot-reload safety
       assert(node != null)                  # rank-table-violation guard
       data[snake(path.get_file())] = node.get_save_data()
   end
```

### Key interfaces

```gdscript
# In SaveLoadSystem (rank 2)
const CONSUMER_PATHS: PackedStringArray = [
    "/root/Economy",
    "/root/HeroRoster",
    "/root/FloorUnlock",
    "/root/FormationAssignment",
    "/root/Recruitment",
    "/root/DungeonRunOrchestrator",
]

# Pattern enforced at every serialization boundary (NEVER cache the resolved node)
func _resolve_consumer_or_die(path: String) -> Node:
    var node: Node = get_node_or_null(path)   # explicit Node annotation (NOT `:=` — that infers Variant)
    if node == null:
        push_error("[SaveLoad] FATAL: consumer autoload missing at %s" % path)
        if not OS.is_debug_build():
            get_tree().quit(1)
    assert(node != null, "[SaveLoad] consumer autoload %s missing" % path)
    assert(node.has_method("get_save_data"), "[SaveLoad] consumer %s lacks get_save_data" % path)
    return node
```

```gdscript
# Forward-connect pattern in any rank-N autoload connecting to a rank-(N+1)+ signal
# Example: FloorUnlockSystem (rank 10) subscribing to DungeonRunOrchestrator (rank 14)
func _ready() -> void:
    DungeonRunOrchestrator.floor_cleared_first_time.connect(_on_floor_cleared_first_time)
    # Bare-identifier resolution VERIFIED safe (autoload.md Claim 1 sub-claim c)
```

## Alternatives Considered

### Alternative 1: Runtime DI container (e.g., service locator)

- **Description**: Replace autoloads with a single `ServiceLocator` autoload that registers other systems via `register(name, instance)`. Consumers fetch via `ServiceLocator.get("Economy")`. Init order is explicit in the locator's bootstrap sequence.
- **Pros**: Explicit dependency graph; no hidden ordering; testable (inject mocks at register time).
- **Cons**: Adds a layer of indirection over Godot's already-rank-ordered autoload system. Bare-identifier resolution stops working (loses static-typing hints). Adds a register/await pattern to every autoload's `_ready()`. Save/Load CONSUMER_PATHS becomes `CONSUMER_NAMES` (string-keyed) — same hardcoding, less Godot-native.
- **Estimated Effort**: ~2 stories of refactor; ~1 story of test-harness rework.
- **Rejection Reason**: Solves a problem we don't have. Godot 4.6's autoload system is rank-ordered and the empirical probe confirms it works as documented. The MVP scope (16 autoloads, 6 consumers) does not justify a DI framework. Re-evaluate at V1.0 if the autoload count grows past ~30.

### Alternative 2: Discover consumers via SceneTree group queries

- **Description**: Each consumer adds itself to a `save_consumer` group via `add_to_group("save_consumer")` in `_ready()`. SaveLoadSystem iterates `get_tree().get_nodes_in_group("save_consumer")` at each persist.
- **Pros**: Decouples consumer enumeration from a hardcoded list; new consumers self-register.
- **Cons**: Order is not stable across runs (group iteration order is implementation-defined), so the persisted dict's key insertion order would vary — making save diffs noisy and breaking any code that assumes a stable iteration order. No build-time error if a consumer forgets to call `add_to_group`. Save migration is harder because the consumer set is not enumerable from the source tree alone.
- **Estimated Effort**: ~0.5 stories.
- **Rejection Reason**: The Save/Load §C.3 Pass-5D design explicitly chose hardcoded `CONSUMER_PATHS` over group queries because "Save/Load's consumer set is small, enumerable, and stable across sprints." Group queries introduce silent failure modes that are catastrophic for the persistence layer. The intentional tight coupling is correct for this domain.

### Alternative 3: Generate the rank table from script-level metadata (decorators)

- **Description**: Each autoload declares `@autoload(rank=N, layer="Foundation")` at script top. A build-time tool generates `project.godot` `[autoload]` section + a runtime constant from the metadata.
- **Pros**: Single source of truth lives next to the code; no risk of `architecture.md` drifting from `project.godot`.
- **Cons**: GDScript has no script-level decorator system as of 4.6 (`@tool`, `@export`, `@onready` are special-cased; user-defined annotations are not supported). Would require either a build-tool that parses scripts (high maintenance) or a code-gen step that runs pre-Godot-import (fragile pipeline).
- **Estimated Effort**: ~3 stories of tooling.
- **Rejection Reason**: GDScript doesn't support the necessary metadata system. Re-evaluate if Godot adds user-defined script annotations in a future version.

## Consequences

### Positive

- **Eliminates a class of silent-failure bugs**. The empirical probe on 2026-04-21 was prompted by Floor Unlock §C.1 R3 — without an established rank invariant, FloorUnlock (rank 10) connecting to Orchestrator (rank 14) at `_ready()` could silently fail. With this ADR, that connection is provably safe and codified as the project's preferred pattern.
- **Save/Load reliability**. The hardcoded `CONSUMER_PATHS` + per-call `get_node_or_null` + nil-check assert pattern (Save/Load §C.3) is now anchored to an ADR. Adding a consumer requires editing the rank table + CONSUMER_PATHS in lockstep, with the assert catching any drift at persist time.
- **Implementation-story unblock**. Save/Load implementation stories (gated on Claim 1 [CONVERGED]→[VERIFIED] promotion, achieved 2026-04-21) are now ready to schedule. This ADR is the formal codification of the gate-resolution.
- **`/architecture-review` becomes precise**. With a canonical rank table, the review skill can verify forward-only signal connections by static analysis (grep for `signal.connect` inside `_ready()` and check rank order).

### Negative

- **Two-location edit burden**. Adding/removing an autoload requires editing two files (`architecture.md` + `project.godot`); for save consumers, three (`+ SaveLoadSystem.CONSUMER_PATHS`); reorders also bump `schema_version`. This is intentional friction — the alternative is silent breakage. Mitigated by `/architecture-review` cross-checking the two lists.
- **Rank reorders are expensive** — explicit superseding ADR + code-review pass + save migration. This is the right cost: reorders break invariants downstream.
- **No automatic enforcement** — a developer can still write a backward signal connection in `_ready()` and it will compile. The invariant is enforced by code review + `/architecture-review` static analysis, not by the language. Mitigation: add a CI check that greps `_ready` bodies for forbidden patterns once `/architecture-review` matures.

### Neutral

- The rank table size grows monotonically with system count. At 16 ranks for MVP and ~20-25 projected for V1.0, the table remains comprehensible. Re-evaluate the framework at 50+ autoloads.
- Bare-identifier resolution (e.g., `DungeonRunOrchestrator` as a typed reference inside any autoload) is preferred over `get_node_or_null("/root/...")` for type safety; the `get_node_or_null` pattern is reserved for boundaries that must survive hot-reload (Save/Load consumer resolution).

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Developer adds a new autoload to `project.godot` but forgets to edit `architecture.md` rank table | Medium | Medium (silent rank drift; future reorders may unknowingly violate invariant) | `/architecture-review` skill must list all `project.godot` `[autoload]` entries and diff against the rank table; flag any unregistered autoload |
| Developer adds a new save consumer to rank table + CONSUMER_PATHS but forgets to bump `schema_version` | Medium | High (silent migration failure on existing saves — old saves load with a missing consumer key, the assert fires, game refuses to load) | The `_resolve_consumer_or_die` assert IS the mitigation: it fires at first persist after the change, surfacing the missing consumer immediately. Schema-version bump is a separate review-checklist item. |
| Hot-reload in dev causes a rank-N autoload's cached reference to dangle | Low | Low (handled by per-call `get_node_or_null` pattern in Save/Load §C.3) | The pattern is already enforced at the Save/Load boundary. Other autoloads should follow the same pattern when they cache cross-autoload references; document in coding-standards.md |
| Same-rank autoload pair both try to connect to each other's signals in `_ready()` | Low | High (one connection silently fails; `_ready()` order within a rank is implementation-defined) | The rank invariant explicitly forbids equal-rank `_ready()`-time connections. Code review must catch this. `/architecture-review` should detect this statically (grep for `<sibling_autoload>.<signal>.connect` inside `_ready` of a same-rank node) |
| The 16-rank table grows past comprehensibility post-MVP | Low | Low (architectural drift — not a runtime risk) | Re-evaluate at V1.0 if rank count > 30; consider Alternative 1 (DI container) at that point |
| Probe ran on `.mono` (C#) build of Godot 4.6.1; project is GDScript-only | Low | Low (Mono/standard builds share GDScript autoload sequencing — extrapolation is valid) | If the export target ever switches between Mono and standard templates, no re-probe required for this claim. Note retained here for completeness per godot-specialist Step 4.5 review. |

## Performance Implications

| Metric | Before | Expected After | Budget |
|---|---|---|---|
| CPU (boot) | N/A | One `_ready()` invocation per autoload, in rank order | N/A — boot is not budget-bound |
| CPU (per persist) | N/A | One `get_node_or_null(path)` per consumer (6 × O(1) tree-path-cache lookup ≈ sub-microsecond) | 16.6ms — sub-frame, negligible |
| Memory | N/A | One `PackedStringArray` of 6 short paths in SaveLoadSystem (~150 bytes) | 512MB — negligible |
| Load Time | N/A | Same as before — autoload init is sequential anyway | N/A |

## Migration Plan

**This ADR codifies an existing implicit pattern**. No code currently depends on the rank table being formal because no implementation stories have been authored yet. Migration is purely documentation:

1. The rank table already lives in `architecture.md` (written 2026-04-22 during /create-architecture).
2. When the first implementation story lands that registers an autoload in `project.godot`, the developer must verify the rank assignment matches the table.
3. `SaveLoadSystem.CONSUMER_PATHS` is documented in `design/gdd/save-load-system.md` §C.3 (Pass-5D). The implementation story for SaveLoadSystem must use the canonical 6-entry list verbatim.
4. No save data migration is needed (no shipped saves exist).

**Rollback plan**: If post-MVP playtest surfaces a need for a runtime DI container (Alternative 1), supersede this ADR with one that introduces ServiceLocator. The CONSUMER_PATHS constant becomes a CONSUMER_NAMES dict; SaveLoadSystem fetches consumers via `ServiceLocator.get(name)`. Existing saves require no migration because the persisted dict is keyed by name (which doesn't change).

## Validation Criteria

- [ ] `architecture.md` §Autoload Rank Table is referenced from this ADR's Decision section (✅ — done at write time).
- [ ] Every Foundation/Core/Feature implementation story embeds the rank of the autoload it implements (verify when stories are authored).
- [ ] `SaveLoadSystem.CONSUMER_PATHS` exactly matches the 6-entry list in this ADR's "Save/Load consumer table protocol" section, in the same order, when the implementation story lands.
- [ ] No `_ready()` method in any autoload connects to a same-or-lower-rank autoload's signal (verifiable by `/architecture-review` static analysis once written).
- [ ] `/architecture-review` lists `project.godot` `[autoload]` entries and diffs against the rank table; reports drift as an ERROR (not a warning).
- [ ] Coding-standards.md gains a "Cross-autoload reference patterns" section that documents bare-identifier (preferred) vs `get_node_or_null` (required at Save/Load boundary) usage.

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|---|---|---|---|
| `design/gdd/save-load-system.md` §C.3 (Pass-5D) | Save/Load | "SaveLoadSystem holds a hardcoded ordered list of consumer autoload node paths in rank order, resolved via `get_node_or_null(path)` at each serialization boundary, NEVER cached, with explicit nil-check + fatal assert" | Codifies the rank-table contract that CONSUMER_PATHS depends on; defines the lockstep-edit protocol; preserves the per-call-resolution pattern |
| `design/gdd/floor-unlock-system.md` §C.1 R3 | Floor Unlock | "FloorUnlockSystem subscribes to DungeonRunOrchestrator.floor_cleared_first_time in its `_ready()`" | Establishes that rank 10 → rank 14 forward connection is safe; references the empirical probe verification |
| `design/gdd/game-time-and-tick.md` §Dependencies | Game Time | "All consumers receive `tick_fired(n)` signal from rank 0; SaveLoad reads/writes timestamp fields via named methods (sole permitted external write)" | Establishes rank 0 + special-case bidirectional access pattern (TimeSystem is not in CONSUMER_PATHS but is read+written by SaveLoad via named methods) |
| `design/gdd/data-loading.md` §Dependencies | Data Loading | "DataRegistry (rank 1) emits registry_ready; SaveLoadSystem and all databases gate on it" | Establishes rank 1 + the registry_ready signal-edge pattern |
| `design/gdd/dungeon-run-orchestrator.md` §C.7 + ADR-0001 | Orchestrator | "FormationAssignment.formation_reassignment_committed signal is connected at Orchestrator._ready" | Establishes that rank 14 → rank 11 backward signal connection is acceptable IF the connection is established by the *higher*-rank node (Orchestrator subscribes to FormationAssignment, not the other way around — preserves the forward-only invariant from FormationAssignment's perspective) |
| `docs/architecture/architecture.md` §Autoload Rank Table + §Architecture Principles #2 | (cross-cutting) | "Stateless simulation, stateful boundaries; cross-module communication is signal-driven; nobody mutates another module's state directly" | The rank table makes the "boundaries" enumerable; this ADR makes the rank table authoritative |

## Related Decisions

- ADR-0001 (Mid-Run Reassignment, Accepted) — assumes FormationAssignment + Orchestrator exist as autoloads with the signal contract defined here
- ADR-0002 (LOSING-clear monotonic credit, Accepted) — assumes Economy is a rank-3 autoload with persistent state
- ADR-F02 (Save envelope + HMAC, planned next) — depends on this ADR's CONSUMER_PATHS protocol
- ADR-F03 (Time dual-clock contract, planned) — depends on this ADR for rank-0 status of TickSystem
- ADR-F04 (DataRegistry boot scan, planned) — depends on this ADR for rank-1 status + registry_ready signal-edge pattern
- ADR-F05 (Scene transition + persist coupling, planned) — depends on this ADR's persist-boundary protocol
- `docs/engine-reference/godot/modules/autoload.md` — empirical evidence backing Claim 1 [VERIFIED]
- `docs/architecture/architecture.md` §Autoload Rank Table — the canonical table this ADR formalizes
- `design/gdd/save-load-system.md` §C.3 — Pass-5D design that introduced CONSUMER_PATHS

---

## Amendments

### Amendment #1 — 2026-04-22: Rank invariant phrasing correction

The original "rank-N may only forward-connect to rank-(N+1)+ at `_ready()`" phrasing was empirically too restrictive. Replaced with the correct distinction: signal SUBSCRIPTION across any rank pair at `_ready()` time is safe (signal objects exist on Node instantiation, before any `_ready()` fires); STATE READS at `_ready()` time are constrained (a rank-N autoload reading state set in a higher-rank `_ready()` body sees pre-init state). See §Rank invariant (amended 2026-04-22 per ADR-0005 OQ-6).

**Impact**: Registry forbidden_pattern `same_or_backward_rank_signal_connect_at_ready` was SUPERSEDED; replaced with `same_or_backward_rank_state_read_at_ready` + `signal_emission_consumer_ordering_assumption`. Backed by autoload.md Claim 1 [VERIFIED] and godot-specialist Step 4.5 review of ADR-0005.

### Amendment #2 — 2026-04-22: Ranks 8 and 9 vacated (CONFLICT-1 + CONFLICT-2 resolution)

`/architecture-review` (2026-04-22) surfaced binding cross-artifact conflicts between this ADR's autoload rank table and the matchup-resolver + combat-resolution GDDs:

- `design/gdd/class-vs-enemy-matchup-resolver.md` TR-matchup-resolver-001/002/030 declare the resolver as `class_name MatchupResolver extends RefCounted`, NOT autoload, DI-injected via `Orchestrator._init` — with a CI invariant forbidding any autoload registration.
- `design/gdd/combat-resolution.md` TR-combat-001/004 declare the same pattern for `CombatResolver`.

The original rank table placed both at ranks 8 and 9 as autoloads, which would have broken the GDD-mandated stateless DI pattern.

**Resolution**: Removed both entries from the rank table; ranks 8 and 9 are now `[VACANT]` slots. Downstream ranks (10-15) were NOT renumbered — leaving slots vacant is preferable to a reorder (which §Editing Protocol forbids without a superseding ADR).

A new §Non-Autoload Pure-Function Modules section documents the contract: both modules are constructed once at boot, injected via `DungeonRunOrchestrator._init(combat_resolver, matchup_resolver)`, and have zero participation in the autoload `_ready()` ordering protocol. CI grep enforces the "no `[autoload]` entry" invariant.

**Impact**: This amendment is a structural CHANGE to the rank table (not a phrasing fix). The GDDs are the authoritative source — they were authored after the architecture.md draft and contain the spy-subclass DI requirement that the autoload pattern would have defeated. No code exists yet, so no code migration is needed.

**Cross-doc cascade**: `docs/architecture/architecture.md` §Autoload Rank Table + §Module Ownership Map updated in lockstep with this amendment. `docs/architecture/architecture-review-2026-04-22.md` documents the conflict resolution. `docs/architecture/tr-registry.yaml` TR-IDs unchanged.

**Future reorder/refill protocol**: if a future ADR introduces a new autoload, it MAY occupy rank 8 or 9. Such an ADR must explicitly cite this amendment and confirm that the new occupant does NOT depend on the prior MatchupResolver/CombatResolver semantics being autoload-shaped.

### Amendment #3 — 2026-04-22: `_init(args)` phrasing superseded by lazy-default-with-public-setters per autoload.md Claim 4 [VERIFIED] + `dungeon-run-orchestrator.md` §J.1 Option A

Amendment #2 (above) described the DI contract as "*injected via `DungeonRunOrchestrator._init(combat_resolver, matchup_resolver)` constructor*". During Step 4.5 review of ADR-0009 (Matchup Resolver DI, authored 2026-04-22 in lockstep with this amendment), godot-specialist BLOCKED on this phrasing: **Godot's autoload system calls `_init()` with ZERO arguments**. An autoload Node script with required `_init(args)` cannot be instantiated; Godot emits `ERROR: 'Node(script.gd)::_init': Method expected N argument(s), but called with 0` at `_create_instance (modules/gdscript/gdscript.cpp:200)` and the autoload Node is never added to `/root`.

**Pass-INIT-PROBE (2026-04-22) empirically verified the finding** on Godot 4.6.1.stable.mono.official:
- Pass 1 (falsification) — autoload `_init(a: int, b: int)` reproduced the engine error verbatim.
- Pass 2 (confirmation) — zero-arg `_init()` + `_ready()` calling `wire_dependencies(100, "hello")` + non-autoload inner-class `RefCounted.new(100, "hello")` — all 7 assertion lines printed cleanly.

Findings captured in `docs/engine-reference/godot/modules/autoload.md` as **Claim 4 [VERIFIED]** (authored same day).

**Correction**: everywhere Amendment #2 and the main §Non-Autoload Pure-Function Modules section say `DungeonRunOrchestrator._init(combat_resolver, matchup_resolver)` or the injection target as an `_init` constructor, the correct contract is the **lazy-default-with-public-setters pattern** already locked by `design/gdd/dungeon-run-orchestrator.md` §J.1 (Pass 5C+, Option A):

| Where | Corrected phrasing |
|---|---|
| Injection target | Two public setters on `DungeonRunOrchestrator` — `set_matchup_resolver(resolver: MatchupResolver)` + `set_combat_resolver(resolver: CombatResolver)`, each with a non-null assert. Test-only by convention (production never calls them). |
| `_init` signature | `func _init() -> void: pass` — zero required parameters (Claim 4 [VERIFIED] autoload constraint). No DI happens here; `_init` is a no-op. |
| `_ready()` production wiring | Lazy-default construction with null-checks: `if _combat_resolver == null: _combat_resolver = DefaultCombatResolver.new()` + same for `_matchup_resolver`. When no test has pre-injected, defaults are constructed; production boots "zero-config". |
| Test wiring | Construct Orchestrator via `.new()`, call setters BEFORE adding to scene tree (`orch.set_matchup_resolver(spy); add_child(orch)`). The setters populate the fields; `_ready()`'s null-checks short-circuit; spies are preserved. Matches `dungeon-run-orchestrator.md` §J.3 Mode 1. |
| Orchestrator `_init` signature | Zero required parameters (or no `_init` at all). Required-arg `_init` on an autoload Node is mechanically impossible. |

This correction **supersedes the Amendment #2 phrasing only on the injection-method mechanism**; the structural decision (non-autoload RefCounted modules; ranks 8+9 vacant; no autoload entries for MatchupResolver or CombatResolver; spy-subclass test pattern; CI grep enforces) is unchanged.

**Why lazy-default-with-setters over a named-method alternative**: an initial Step 4.5 recommendation from godot-specialist (ADR-0009 draft) proposed a single `wire_dependencies(combat_resolver, matchup_resolver)` named method as the DI seam. Review of `dungeon-run-orchestrator.md` §J.1 surfaced that pattern's equivalent had already been considered and rejected as §J.7 Option E: *"Fails open (dispatch before `initialize()` would crash) rather than failing closed (lazy-default-safe production path)."* This amendment adopts the already-locked §J.1 Option A — same Claim-4-correctness, plus the "fails-closed production boot" property.

**Impact (registry + architecture.md lockstep)**:
- `docs/architecture/architecture.md` §Non-Autoload Pure-Function Modules + §Module Ownership Map (MatchupResolver + CombatResolver rows) corrected in same pass to reference the setter pattern.
- `design/gdd/class-vs-enemy-matchup-resolver.md` Pass-INIT-PROBE-SYNC note corrected in same pass (Rule 1, DefaultMatchupResolver paragraph, New Cross-System Contracts #3).
- `design/gdd/combat-resolution.md` Pass-INIT-PROBE-SYNC note corrected in same pass (Last Updated header, C.4 CombatResolver + DefaultCombatResolver paragraphs, §F Downstream Dependents row).
- `design/gdd/dungeon-run-orchestrator.md` — a Pass-INIT-PROBE-SYNC confirmation note added to the header; §J.1 Option A is **unchanged** (it was already correct; this ADR codifies it at ADR level).
- Registry additions: NEW forbidden pattern `autoload_init_with_required_args` (see `docs/registry/architecture.yaml`) — project-wide CI grep defends against regression.

**New CI invariant added to §Editing Protocol**:

Any new autoload-registered script MUST satisfy: if `_init` is declared, all its parameters have default values (effectively zero required args). CI grep enforces project-wide against ALL autoload scripts, not just Orchestrator. Violation blocks merge. Backed by Claim 4 [VERIFIED].

**Pattern lesson reinforcement**: this is the **fifth** engine-state claim in the project to pass cross-model specialist convergence and be falsified/refined by a ~5-minute empirical probe. Lesson #1 (empirical probes are the only authoritative evidence for engine-state API claims — see session-state generalizable lessons) continues to generalize. ADR Step 4.5 for any future ADR that load-bears on autoload lifecycle semantics MUST include a probe plan; specialist convergence alone is insufficient.

**Second lesson — read the relevant GDD §J.x section BEFORE Step 4.5**: ADR-0009's initial draft proposed a `wire_dependencies` pattern that contradicted `dungeon-run-orchestrator.md` §J.1's already-locked Option A. The conflict was caught mid-lockstep-edit and rolled back. Generalizes: ADR authoring MUST read any GDD wiring section (e.g., §J Wiring model, §F Dependencies, §C Architecture) before proposing a new wiring mechanism. Cross-referencing locked GDD decisions is a Step 2 requirement, not a Step 4.5 specialist-review concern.

**Cross-reference**: the full lazy-default-with-setters contract — signatures, CI invariants, test construction idiom, parity with `dungeon-run-orchestrator.md` §J.1 — is codified in ADR-0009 §Decision. ADR-X01 (Combat snapshot shape, upcoming) will cite this amendment when adopting the parallel setter (`set_combat_resolver`) for CombatResolver injection.

### Amendment #4 — 2026-04-26: Rank 8 reassigned from VACANT to SceneManager (Foundation) — OQ-8 closure

Story S5-M4 (SceneManager autoload skeleton + four-state machine + DataRegistry gating) required assigning a concrete rank for the `SceneManager` autoload. OQ-8 was left open in the original rank table with a recommendation of "6 or 7".

**Analysis at implementation time (2026-04-26)**:
- Ranks 0–6 are occupied by TickSystem through BiomeDungeonDatabase.
- Rank 7 is occupied by HeroRoster (Feature layer, unimplemented but reserved).
- Rank 8 was VACANT per Amendment #2.
- Rank 9 is VACANT per Amendment #2.
- Inserting SceneManager at rank 7 would push HeroRoster to rank 8 = a REORDER = **forbidden** per §Editing Protocol without a superseding ADR.
- Claiming rank 8 (VACANT slot) is explicitly **allowed** per §Editing Protocol: "leaving slots vacant is preferable to a reorder; claiming a vacant slot is permitted."

**Decision**: SceneManager is assigned rank 8 (Foundation layer). This closes OQ-8.

**Impact**:
- Rank table in `architecture.md` §Autoload Rank Table updated: rank 8 row changed from `[VACANT]` to `SceneManager (Foundation)`.
- Rank 9 remains vacant (Amendment #2 footnote updated from "ranks 8 and 9 are vacant" to "rank 9 is vacant").
- `project.godot [autoload]` — `SceneManager` entry added after `BiomeDungeonDatabase` (last entry in the current autoload section, satisfying rank-8 position).
- Amendment #2's "non-autoload modules occupy these slots" rationale is superseded for rank 8 only; rank 9 retains the Amendment #2 vacant designation.
- `SceneManager` is NOT a Save/Load consumer — no `CONSUMER_PATHS` change needed.
- Lockstep edit is complete: (a) this ADR amended, (b) `architecture.md` updated, (c) `project.godot` updated.

### Amendment #5 — 2026-05-05: AudioRouter assigned rank 16 — OQ-AS-1 closure

Story S11-S2 (AudioRouter autoload skeleton + bus layout + ADR-0003 amendment) required assigning a concrete rank for the new `AudioRouter` autoload introduced by `design/gdd/audio-system.md`. OQ-AS-1 in the audio-system GDD identified two viable patterns: (a) append AudioRouter to the rank table with a rank that places it after all gameplay-signal sources, OR (b) defer signal subscription via `call_deferred("_subscribe_to_signals")` from `_ready()` so rank order doesn't matter. Both options are workable; the GDD asked Sprint 11 implementation to decide.

**Decision**: Option (a). Append AudioRouter at rank 16 (after rank 15 OfflineProgressionEngine).

**Analysis at implementation time (2026-05-05)**:
- AudioRouter subscribes to gameplay signals from SceneManager (rank 8), DungeonRunOrchestrator (rank 14), HeroRoster (rank 7), Economy (rank 3). Per ADR-0003 §"Signal SUBSCRIPTION across any rank pair at `_ready()` time is safe" (Amendment #1, [VERIFIED]), the rank choice is technically irrelevant to subscription correctness — any rank works. **However**: ranking AudioRouter LAST keeps the signal-source autoloads strictly visible in `/root/` at AudioRouter's `_ready()` time, so the defensive `has_node("/root/SourceAutoload")` guards in `audio_router.gd._ready()` always succeed in production (failing-safe in test envs that boot a partial autoload set).
- Appending at the end avoids any rank renumbering — matches Amendment #4's "claim a vacant or end slot, do not reorder" pattern.
- AudioRouter IS a Save/Load consumer (per audio-system.md §C.7 — namespaced under top-level key `"audio"`), so SaveLoadSystem's `CONSUMER_PATHS` table needs an `AudioRouter` entry. **Sprint 12+ Story 2 owns this lockstep edit** when the SaveLoadSystem-side consumer-discovery body is implemented (currently STUB per Story 007 deferral). The gap is acknowledged: AudioRouter's `get_save_data` / `load_save_data` surface is real and tested in S11-S2; the SaveLoadSystem-side hook-up is the deferred half.

**Decision**: AudioRouter is assigned rank 16 (Core / Audio layer per architecture.md categorization). This closes OQ-AS-1.

**Impact**:
- Rank table in `architecture.md` §Autoload Rank Table updated: new row appended for rank 16 = AudioRouter (Core / Audio).
- `project.godot [autoload]` — `AudioRouter` entry added after `DungeonRunOrchestrator` (last entry pre-amendment), satisfying rank-16 position. New `[audio]` section added with `buses/default_bus_layout="res://assets/audio/audio_bus_layout.tres"` pointing at the 8-bus hierarchy authored in S11-S2.
- `SaveLoadSystem.CONSUMER_PATHS` — entry NOT added in this amendment (deferred to Sprint 12+ Story 2 alongside SaveLoadSystem-side consumer discovery). The deferral is documented as an explicit gap that Sprint 12+ implementation must close.
- audio-system.md §I.1 (OQ-AS-1) marked RESOLVED with this amendment as the resolution path.
- Lockstep edit status: (a) this ADR amended ✓, (b) `architecture.md` updated ✓, (c) `project.godot` updated ✓, (d) `SaveLoadSystem.CONSUMER_PATHS` deferred (Sprint 12+ — explicit gap, not silent).

### Amendment #6 — 2026-05-05: FloorUnlockSystem implementation lands at rank 10

Story S11-X1 (FloorUnlockSystem implementation) per the Sprint 11 unblock cascade after Story 007a (`request_full_persist` body) showed that the deferred consumer ecosystem was the actual blocker for happy-path Story 007 testing. FloorUnlockSystem was the only one of the 3 missing CONSUMER_PATHS autoloads (FloorUnlock, FormationAssignment, Recruitment) with a complete + APPROVED-for-MVP-runtime GDD (Pass-9 + Pass-PROBE-EXECUTED, 2026-04-21). The other two need GDD authoring before implementation.

**Analysis at implementation time (2026-05-05)**:
- The architecture.md rank table had `FloorUnlockSystem` listed at rank 10 since the original architecture authoring (Sprint 4-era documentation work).
- `project.godot` did NOT yet have a `FloorUnlock` entry in the `[autoload]` section — the rank table-as-canonical-source was authored before the autoload was implemented.
- `SaveLoadSystem.CONSUMER_PATHS` ALREADY listed `/root/FloorUnlock` (since Sprint 4); it was a forward-reference to the unimplemented autoload that this story closes.
- Class declaration is `class_name FloorUnlockSystem extends Node`; autoload registration name is `FloorUnlock` (the shorter form used at call sites per GDD §C.3 D2 decision — class_name and autoload name are intentionally orthogonal).

**Decision**: FloorUnlockSystem is implemented at autoload name `FloorUnlock`, rank 10 (Feature layer per architecture.md). Closes the architecture.md rank-table forward-reference.

**Impact**:
- `project.godot [autoload]` — `FloorUnlock` entry added between `SceneManager` (rank 8) and `DungeonRunOrchestrator` (rank 14), satisfying rank-10 position. The intervening rank 9 remains VACANT per Amendment #2.
- `architecture.md` §Autoload Rank Table — no edit needed (rank 10 row was already present and referenced FloorUnlockSystem). The `Status: Not Started` notation in `design/gdd/systems-index.md` row 16 should be promoted to "Implemented (Sprint 11 S11-X1)" in a follow-up systems-index update.
- `SaveLoadSystem.CONSUMER_PATHS` — `/root/FloorUnlock` was already in the list (index 2). No edit needed. The autoload now resolves where the consumer-discovery code expected it.
- FloorUnlockSystem subscribes to `DungeonRunOrchestrator.floor_cleared_first_time` at `_ready()` per the GDD §C.3 ordering. Per ADR-0003 §Signal SUBSCRIPTION rule, rank 10 → rank 14 forward subscription is safe at `_ready()` time (signal objects exist on Node instantiation, before any `_ready()` fires; [VERIFIED]).
- Pass-PROBE-EXECUTED designer-UI integration deferred per the GDD's I.11 update — runtime fallback (`ProjectSettings.get_setting(key, default)`) is what the implementation uses. V1.0 multi-biome work owns the proper @tool/EditorPlugin integration.
- Lockstep edit status: (a) this ADR amended ✓, (b) `architecture.md` already had the rank — no edit needed, (c) `project.godot` updated ✓, (d) `SaveLoadSystem.CONSUMER_PATHS` already listed it — no edit needed.

### Amendment #7 — 2026-05-05: Recruitment autoload skeleton lands at rank 12

Story S11-X10 (Recruitment autoload skeleton) closes the LAST of the missing CONSUMER_PATHS autoloads. Combined with Amendment #6 (FloorUnlock, S11-X1) and S11-X9 (FormationAssignment skeleton), the consumer ecosystem is now COMPLETE — all 7 entries in `SaveLoadSystem.CONSUMER_PATHS` have live autoloads with `get_save_data` / `load_save_data` methods, unblocking the Sprint 11 S11-M4 (Story 016) end-to-end round-trip integration test.

**Analysis at implementation time (2026-05-05)**:
- The architecture.md rank table had `Recruitment` listed at rank 12 since the original architecture authoring (Sprint 4-era documentation work).
- `project.godot` did NOT yet have a `Recruitment` entry in the `[autoload]` section — the rank table-as-canonical-source was authored before the autoload was implemented.
- `SaveLoadSystem.CONSUMER_PATHS` ALREADY listed `/root/Recruitment` (since Sprint 4 — index 4); it was a forward-reference to the unimplemented autoload that this story closes.
- Class declaration is `class_name Recruitment extends Node`; autoload registration name is `Recruitment` (the same — no orthogonality split for this system).
- Recruitment subscribes to `DungeonRunOrchestrator.floor_cleared_first_time` at `_ready()` per ADR-0015 §OQ-RC-2 (free on-clear refresh trigger). Per ADR-0003 §Signal SUBSCRIPTION rule, rank 12 → rank 14 forward subscription is safe at `_ready()` time (signal objects exist on Node instantiation, before any `_ready()` fires; [VERIFIED]).

**Decision**: Recruitment is implemented at autoload name `Recruitment`, rank 12 (Feature layer per architecture.md). Closes the architecture.md rank-table forward-reference + the final consumer-ecosystem gap.

**Impact**:
- `project.godot [autoload]` — `Recruitment` entry added between `FormationAssignment` (rank 11) and `DungeonRunOrchestrator` (rank 14), satisfying rank-12 position. The intervening rank 13 (Hero Leveling System per architecture.md) remains VACANT.
- `architecture.md` §Autoload Rank Table — no edit needed (rank 12 row was already present and referenced Recruitment). The `Status: Authored` notation in `design/gdd/systems-index.md` row 14 should be promoted to "Implemented (Sprint 11 S11-X10)" in a follow-up systems-index update.
- `SaveLoadSystem.CONSUMER_PATHS` — `/root/Recruitment` was already in the list (index 4). No edit needed. The autoload now resolves where the consumer-discovery code expected it.
- Save namespace expands by 3 fields per ADR-0015 §Decision schema (`save_pool_seed`, `refresh_counter`, `current_pool`). Pre-Recruitment-shipped saves load with empty payload + first-launch seed init per ADR-0015 Migration Plan + Save/Load §C MVP-default-on-missing-key contract. Schema version bump per Save/Load GDD Rule 14 — Sprint 12+ Recruitment Story 6 (per recruitment-system.md §J) owns the explicit schema migration documentation.
- Lockstep edit status: (a) this ADR amended ✓, (b) `architecture.md` already had the rank — no edit needed, (c) `project.godot` updated ✓, (d) `SaveLoadSystem.CONSUMER_PATHS` already listed it — no edit needed.

**Consumer ecosystem status (post-Amendment #7)**: 7 of 7 CONSUMER_PATHS autoloads live with `get_save_data` — Economy (rank 3), HeroRoster (rank 7), FloorUnlock (rank 10), FormationAssignment (rank 11), Recruitment (rank 12), DungeonRunOrchestrator (rank 14), AudioRouter (rank 16). The Sprint 11 S11-M4 / Story 016 (save-persist end-to-end) is now unblocked.

### Amendment #8 — 2026-05-05: OfflineProgressionEngine skeleton lands at rank 15

Story S12-M4 (OfflineProgressionEngine Stories 1-3 — autoload skeleton + boot orchestration + OfflineSummary class) per `design/gdd/offline-progression-engine.md` §C.1 + ADR-0014 (Offline Replay Batch Chunking + RunSnapshot Schema). Sprint 12 Must Have shipped pre-emptively in the autonomous-execution session post-Sprint-11 close-out.

**Analysis at implementation time (2026-05-05)**:
- `architecture.md` rank table had `OfflineProgressionEngine` listed at rank 15 since the original architecture authoring (Sprint 4-era documentation work).
- `project.godot` did NOT yet have an `OfflineProgressionEngine` entry in the `[autoload]` section — the rank table-as-canonical-source was authored before the autoload was implemented.
- **NOT in CONSUMER_PATHS** per `offline-progression-engine.md` §C.7 — the engine has no persisted state of its own (its inputs come from other systems' save namespaces). This is the FIRST autoload at rank ≥3 that is intentionally absent from CONSUMER_PATHS.
- `class_name` omitted to avoid the "Class hides an autoload singleton" parse error per the project_godot_autoload_class_name_collision memory note (matches FormationAssignment + AudioRouter + Recruitment pattern).
- Engine subscribes to `TickSystem.offline_elapsed_seconds` at `_ready()` per GDD §F. Per ADR-0003 §Signal SUBSCRIPTION rule + Amendment #1 [VERIFIED] empirical probe, rank 15 → rank 0 forward subscription is safe (signal objects exist on Node instantiation, before any `_ready()` fires).

**Decision**: OfflineProgressionEngine is implemented at autoload name `OfflineProgressionEngine`, rank 15 (Feature layer per architecture.md). Closes the architecture.md rank-table forward-reference. The Sprint 12 S12-M4 scope ships Stories 1-3 (skeleton + boot subscription + OfflineSummary class); the chunked replay loop body is **STUBBED** and lands in S12-M5 (Stories 4-6) per `offline-progression-engine.md` §J.

**Impact**:
- `project.godot [autoload]` — `OfflineProgressionEngine` entry added between `DungeonRunOrchestrator` (rank 14) and `AudioRouter` (rank 16), satisfying rank-15 position.
- `architecture.md` §Autoload Rank Table — no edit needed (rank 15 row was already present and referenced OfflineProgressionEngine). The `Status: Authored` notation in `design/gdd/systems-index.md` row 12 should be promoted to "Implemented (Sprint 12 S12-M4 — skeleton + boot subscription)" in a follow-up systems-index update.
- `SaveLoadSystem.CONSUMER_PATHS` — **no edit needed** (intentionally absent per GDD §C.7). The 7-entry list remains canonical.
- OfflineProgressionEngine subscribes to `TickSystem.offline_elapsed_seconds` at `_ready()` per the GDD §F. Per ADR-0003 §Signal SUBSCRIPTION rule, rank 15 → rank 0 forward subscription is safe at `_ready()` time (signal objects exist on Node instantiation; [VERIFIED]).
- The chunked replay loop body remains STUBBED per S12-M4 scope; S12-M5 lands the real implementation per ADR-0014's adaptive time-budgeted chunking algorithm.
- Lockstep edit status: (a) this ADR amended ✓, (b) `architecture.md` already had the rank — no edit needed, (c) `project.godot` updated ✓, (d) `SaveLoadSystem.CONSUMER_PATHS` intentionally absent — no edit needed.

**Rank slot inventory (post-Amendment #8)**:
- Ranks with live autoloads: 0 (TickSystem), 1 (DataRegistry), 2 (SaveLoadSystem), 3 (Economy), 4 (HeroClassDatabase), 5 (EnemyDatabase), 6 (BiomeDungeonDatabase), 7 (HeroRoster), 8 (SceneManager), 10 (FloorUnlock), 11 (FormationAssignment), 12 (Recruitment), 14 (DungeonRunOrchestrator), 15 (OfflineProgressionEngine), 16 (AudioRouter).
- VACANT ranks: 9 (per Amendment #2 footnote), 13 (HeroLeveling — Sprint 13+ implementation candidate per `architecture.md` System Layer Map).
