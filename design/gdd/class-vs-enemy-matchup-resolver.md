# Class-vs-Enemy Matchup Resolver GDD — Lantern Guild

> **GDD #10 in design order** (System #10 in systems index)
> **Status**: Approved 2026-04-19 (re-review pass) + Pass 5C DI conversion applied 2026-04-20 — static-only utility converted to injectable instance class to close Orchestrator re-review Cluster α BLOCKER on AC-ORC-11 mockability; mirrors Combat Pass 3D pattern.
> **Created**: 2026-04-19
> **Last Updated**: 2026-04-22 (**Pass-INIT-PROBE-SYNC — DI injection seam corrected from `_init(combat_resolver, matchup_resolver)` constructor to the lazy-default-with-public-setters pattern already locked by `dungeon-run-orchestrator.md` §J.1 (Option A, Pass 5C+)** per empirical finding that Godot's autoload system calls `_init()` with zero arguments; required-arg `_init` on an autoload Node fails instantiation. Test-injection uses `DungeonRunOrchestrator.set_matchup_resolver(spy)` BEFORE `_ready()` fires; production uses lazy-default construction inside `_ready()` with null-check short-circuit. Rule 1 + DefaultMatchupResolver paragraph + New Cross-System Contracts #3 updated in lockstep with ADR-0009 + ADR-0003 Amendment #3. Evidence: `docs/engine-reference/godot/modules/autoload.md` Claim 4 [VERIFIED] via Pass-INIT-PROBE 2026-04-22 on Godot 4.6.1.stable.mono.official. Structural design (non-autoload RefCounted + DefaultMatchupResolver subclass + spy test pattern) and Pass 5C rationale are UNCHANGED — only the injection MECHANISM is corrected (from imagined `_init(args)` to the already-locked §J.1 Option A pattern).) Previously: 2026-04-20 (Pass 5C — `class_name MatchupResolver extends RefCounted` injectable instance class; `DefaultMatchupResolver extends MatchupResolver` concrete production impl; public methods converted `static func → func`; Rule 1 rewritten; Rule 4 methods un-staticified; Rule 2 statelessness note refined; H-16 predicates inverted (no-static assertion); H-12 + H-13 + H-17 spy-subclass language updated; Dependencies tables (upstream + downstream + Combat bridge) updated; New Cross-System Contracts list updated with Orchestrator constructor signature. Pre-Pass-5C approval from 2026-04-19 re-review preserved — Pass 5C is a DI revision only, not a rules revision.)
> **Authors**: systems-designer + game-designer + qa-lead + main session
> **Revision summary**: Section B fantasy reframed from per-hero to collective; Rule 6 aggregation changed from boolean OR ("at least one counter") to **majority threshold** ("more than N/2 counters"); Class DB E.5 + C.6 + Economy C.2.4 errata applied in same pass; H-12/H-13 demoted to ADVISORY pending real Orchestrator/Offline Engine GDDs; new ACs added for static-class structure (Rule 1), DataRegistry call-count assertion in offline replay (Rule 14), arbitrary garbage-string disambiguation (Rule 13), and explicit RefCounted equality warning (H-07). See `design/gdd/reviews/class-vs-enemy-matchup-resolver-review-log.md`.
> **Depends on**: `design/gdd/hero-class-database.md` (#5), `design/gdd/enemy-database.md` (#6)
> **Referenced by**: Economy System (#5 — `matchup_multiplier` input), Combat Resolution (#11), Dungeon Run Orchestrator (#13), Formation Assignment System (#17), Matchup Assignment Screen (#23)
> **Implements Pillar**: Pillar 3 (Matchup Is a Decision, Not a Reflex) — load-bearing system for the strategic-formation hook. Also serves Pillar 2 (class distinctness made economically legible).
> **Creative Director Review (CD-GDD-ALIGN)**: SKIPPED — Solo review mode

---

## A. Overview

The Class-vs-Enemy Matchup Resolver is the smallest system in *Lantern Guild* by lines of code and the largest by emotional weight. It is a stateless resolver with a single job: given a formation of heroes and an enemy (or floor's enemy list), decide whether the formation has matchup advantage and return a `bool` (`is_matchup_advantaged`) plus the per-archetype counter detail the UI needs to explain *why*. That `bool` flips a `1.0` to a `1.5` in Economy's `kill_bonus` formula. That single-bit difference is the entire Pillar 3 ("Matchup Is a Decision") economic hook.

Mechanically, the resolver is a pair of pure functions: `is_class_counter(class, enemy_archetype) -> bool` (already declared in Hero Class DB GDD #5 D.2 — string equality on `class.counter_archetype == enemy_archetype`) and `resolve_formation_matchup(formation, enemy_or_floor) -> MatchupResult`. The aggregation rule is **majority threshold** — for a given enemy archetype the formation is matchup-advantaged if **more than `formation.size() / 2`** of its heroes counter that archetype (integer division). For the MVP `FORMATION_SIZE = 3` this means at least 2 of 3 slots must counter. Crossing the threshold yields a single application of `1.5×` (no per-hero stacking beyond the threshold). This forces a specialist-vs-generalist decision: a generalist W+M+R formation crosses no thresholds and earns neutral gold across the floor; a specialist W+W+M crosses bruiser only. The threshold-vs-OR choice (revised from boolean OR on 2026-04-19) is established by Hero Class DB E.5 and locked here.

The resolver is called at three distinct moments: **per-kill** by the Dungeon Run Orchestrator (which then emits `enemy_killed(tier, is_matchup_advantaged)` to Economy), **per-floor** by the Matchup Assignment Screen (which previews the matchup against the floor's `dominant_archetypes` for the player's planning), and **per-dispatch** as a one-shot snapshot for the Offline Progression Engine (which freezes the formation+dungeon pairing at last persist and replays without re-querying the live roster). All three call paths must produce identical results for identical inputs — determinism is non-negotiable for offline replay fairness (Pillar 1).

---

## B. Player Fantasy

The Matchup Resolver has no direct player fantasy — players never see it. It serves the indirect fantasy of **the smallest decision with the largest payoff**, anchored on a single arc that crosses session boundaries:

*60 seconds at the Recruit Screen on Wednesday evening — the player notices the next biome's preview shows armored enemies and the matchup screen shows their current Warrior+Mage+Rogue formation crosses zero majority thresholds for this dungeon. They drop the Mage, recruit a second Warrior, and now W+W+R crosses the bruiser threshold. They close the app. Eight hours later, the Return-to-App screen reports: "Your guild earned 12,400 gold while you were away — your formation's matchup advantage banked an extra 4,200 gold from bruiser kills."* The player smiles at the dishes.

That arc — one minute of attention, eight hours of compounding reward — is the cozy-idle promise made specific. This system is what lets the game say *"the time you spent thinking earned more than the time you spent watching"* and have the math be honest. Pillar 3 ("Matchup Is a Decision") is not abstract here; it is the line item on the Return-to-App screen that the player can read and trace back to a formation choice they remember making — attributed to the **formation as a whole** (the unit of decision), not to a specific hero.

The tactile confirmation moment lives in-combat: the *+52g* floating up over a dying Hollow Brute instead of *+35g* because the formation crosses the bruiser threshold. That kill-bonus pop is the comma in the sentence — it confirms cause and effect during play, but the period is hours later when the cumulative matchup contribution lands on the offline-rewards summary.

The tone is **almanac-warm**: this game speaks of guildmasters and rosters, not synergies and multipliers. Counters are *the warriors know the bruiser's weight; the mages know the caster's tongue; the rogues know the seam in the plate* — and the wisdom of a formation is in **how many of its members carry the same lore against this foe**. No spreadsheet language. No "DPS." The matchup taxonomy reads as a small piece of guild wisdom the player accumulates, not a damage-type chart they memorize.

Soul of the system: ***"One thoughtful minute, eight grateful hours."***

Pillar alignment: This system is the load-bearing implementation of **Pillar 3 (Matchup Is a Decision, Not a Reflex)** — without it, Pillar 3 is aspiration, not mechanic. The majority-threshold rule keeps the decision live across the MVP week (a generalist W+M+R has zero matchup advantage anywhere; a specialist formation must be built deliberately for the dungeon ahead). It also serves **Pillar 1 (Respect the Player's Time)** with unusual purity: the matchup decision is the highest-leverage minute in the game, and the offline payoff is the game saying "we noticed you thought." Indirectly serves **Pillar 2 (Every Class Feels Distinct)** by making class identity *economically* legible — the Warrior is not just a stat block, the Warrior is half of every bruiser-specialist formation.

**Honest scope statement (post-revision):** The fantasy attributes the bonus to the **formation as a whole**, not to a specific hero. Per-hero gold attribution ("+9,200g came from your Rogue") would require a per-kill ledger keyed by `hero_id` that does not exist in the current Orchestrator → Economy data flow (only `is_matchup_advantaged: bool` crosses the boundary). Adding that ledger is XL work and out of MVP scope. The collective framing is what the data flow can actually deliver.

**Downstream design dependency**: this framing requires the Return-to-App / Offline Rewards Screen (#20) to carry the matchup-bonus contribution as a distinctly named line item ("formation matchup bonus: +4,200g"), not bury it in a single "kill bonus" total. The line does NOT need per-hero breakdown — collective formation attribution is sufficient. Flagged in Open Questions for confirmation when GDD #20 is authored.

---

## C. Detailed Design

### C.1 Core Rules

#### Resolver Identity and Hosting

**Rule 1 (Pass 5C DI conversion — 2026-04-20; injection mechanism corrected Pass-INIT-PROBE-SYNC 2026-04-22).** The resolver is an **injectable instance class** — `class_name MatchupResolver extends RefCounted` declared in `src/gameplay/matchup/matchup_resolver.gd`. It holds no per-call state, exposes no signals, and is never added to the scene tree. No autoload entry exists. Public methods are regular instance methods (NOT `static`). The Orchestrator holds one `_matchup_resolver: MatchupResolver` field populated via the lazy-default-with-public-setter pattern locked in `design/gdd/dungeon-run-orchestrator.md` §J.1 Option A: production boot — `DungeonRunOrchestrator._ready()` null-checks the field and lazy-constructs `DefaultMatchupResolver.new()` if still null; tests — test body calls `orchestrator.set_matchup_resolver(spy)` BEFORE `add_child(orchestrator)` (or before direct `orchestrator._ready()` call), so the null-check short-circuits at `_ready()` time and the spy is preserved. Callers invoke the resolver as `matchup_resolver.resolve_formation_matchup(...)` — no static dispatch.

**Pass-INIT-PROBE-SYNC note (2026-04-22)**: Prior to this pass, Rule 1 described the injection mechanism as `DungeonRunOrchestrator._init(combat_resolver, matchup_resolver)`. That phrasing is mechanically impossible on Godot 4.6 — the autoload system calls `_init()` with zero arguments via `_create_instance (modules/gdscript/gdscript.cpp:200)` and a required-arg `_init` fails instantiation. Empirically verified via Pass-INIT-PROBE 2026-04-22 on Godot 4.6.1.stable.mono.official; see `docs/engine-reference/godot/modules/autoload.md` Claim 4 [VERIFIED]. The correction adopts the already-locked `dungeon-run-orchestrator.md` §J.1 Option A pattern (zero-arg `_init` + lazy-default `_ready()` + two public setters `set_matchup_resolver` / `set_combat_resolver` on the Orchestrator) — see ADR-0009 §Decision for the full contract + CI invariants + §J.3 Mode 1 test construction idiom. The Pass 5C structural decisions (non-autoload RefCounted; `DefaultMatchupResolver extends MatchupResolver` production subclass; instance methods not static; spy-subclass test pattern; no autoload entry) are all unchanged.

**Pass 5C rationale**: Prior to Pass 5C (2026-04-19 Pass 1 + 2026-04-19 re-review), `MatchupResolver` was declared as a `static func`-only utility. The Orchestrator independent re-review (2026-04-20, godot-gdscript-specialist BLOCKING) identified this as the same class of mockability gap that Combat Pass 3D solved for `CombatResolver`: GdUnit4 cannot mock static methods on a class, making Orchestrator AC-ORC-11 (matchup-cache correctness) architecturally unwriteable — the test spec references "synthetic MatchupResolver stub" with no shape for constructing one. Pass 5C converts public methods to **instance methods** on a concrete base class mirroring the Pass 3D pattern; subclasses override them for tests. A concrete production implementation (`DefaultMatchupResolver`) extends `MatchupResolver` and provides the real logic; tests extend `MatchupResolver` directly to create spies/stubs.

```gdscript
class_name MatchupResolver extends RefCounted
# Injectable instance — never holds per-run mutable state. The Orchestrator
# injects one instance at construction; production wiring uses DefaultMatchupResolver;
# tests inject a spy subclass. Pass 5C: converted from static-only to instance
# methods to enable GdUnit4 mocking of AC-ORC-11 (matchup-cache correctness).

# Returns the per-archetype majority-threshold outcome for a frozen formation
# snapshot. See Rule 4 + Rule 6 + Rule 10 for semantics.
func resolve_formation_matchup(
    formation: Array,
    enemy_archetype: String
) -> MatchupResult: ...

# Per-floor convenience merge. See Rule 4 for semantics.
func resolve_floor_matchup(
    formation: Array,
    floor_archetypes: Array[String]
) -> MatchupResult: ...
```

**`DefaultMatchupResolver`** — the concrete production implementation. Extends `MatchupResolver`, provides the real `resolve_formation_matchup` and `resolve_floor_matchup` logic (the majority-threshold aggregation defined in Rule 6 + Rule 10). Created once at game boot **lazily inside `DungeonRunOrchestrator._ready()`** via `DefaultMatchupResolver.new()` (zero-arg; RefCounted non-autoload `.new()` works normally — autoload.md Claim 4 [VERIFIED]) IF the Orchestrator's `_matchup_resolver` field is still null at `_ready()` time (i.e., no test pre-injected a spy via `set_matchup_resolver`). No consumer ever calls `MatchupResolver.new()` directly in production — always `DefaultMatchupResolver.new()`.

**Statelessness preserved (post Pass 5C)**: `MatchupResolver` instances carry no per-run state. Every call to `resolve_formation_matchup` or `resolve_floor_matchup` is a pure function of its arguments; the instance is a dependency, not a state container. Injecting the same `MatchupResolver` instance across multiple Orchestrator dispatches is safe — there is nothing to reset between runs. Rule 12 (pure function contract) is unchanged; Rule 14 (DataRegistry call-count invariant during replay) is unchanged; H-07 RefCounted equality warning for `MatchupResult` is unchanged.

**Rule 2.** The resolver has zero mutable state and emits zero signals. The Orchestrator's `enemy_killed(tier, is_matchup_advantaged)` signal is the single observability surface for matchup outcomes; the resolver is the input source, not a publisher itself. If post-launch telemetry needs richer data, the Orchestrator owns enrichment. (Pass 5C: "zero state" refers to per-run mutation — the instance itself is a dependency carrier; it has no instance variables that change after construction.)

#### MatchupResult Struct

**Rule 3.** All public methods that communicate outcome return a `MatchupResult` value type:

```
class_name MatchupResult extends RefCounted
var is_advantaged: bool                  # true = formation crosses majority threshold for the queried archetype(s)
var matched_archetypes: Array[String]    # archetypes that were countered (deduplicated)
                                          # empty when is_advantaged == false
```

`matched_archetypes` contains archetype strings (e.g. `["bruiser", "armored"]`) — never `HeroInstance` references and never `instance_id` values. Resolving "which named hero contributed" is a UI-layer concern (the Matchup Assignment Screen can derive it by re-walking the formation against its own per-archetype check); it must not be represented in the result. This keeps `MatchupResult` decoupled from Roster identity, which keeps the offline snapshot lightweight (a stored result is just a bool + a small array of strings).

#### Public API

**Rule 4 (Pass 5C — instance methods).** Two public methods; both are regular instance methods (NOT `static` — see Rule 1). Everything else is private (`_` prefixed).

```
# Per-kill / per-archetype evaluation.
# Called per-enemy-death by the Dungeon Run Orchestrator via its injected matchup_resolver.
# Called per-archetype on a floor's enemy list by the Matchup Assignment Screen.
#
# formation: Array[HeroInstance] — current formation heroes (may be empty)
# enemy_archetype: String        — the archetype of the specific enemy being evaluated
#                                  (must be a value from EnemyArchetypes constant set,
#                                  per Hero Class DB GDD #5 C.2)
# Returns: MatchupResult
func resolve_formation_matchup(
    formation: Array,
    enemy_archetype: String
) -> MatchupResult

# Per-floor convenience: evaluates the formation against every archetype that appears
# on a floor and returns a single merged MatchupResult.
# Called by the Matchup Assignment Screen for the per-floor preview.
# Called by the Offline Progression Engine once at dispatch snapshot time.
#
# formation: Array[HeroInstance]
# floor_archetypes: Array[String] — deduplicated list of archetypes on the floor,
#                                   derived by the caller from Floor.enemy_list
#                                   (caller is responsible for deduplication)
# Returns: MatchupResult — is_advantaged is true if any floor archetype is countered;
#          matched_archetypes contains all countered archetypes on the floor
func resolve_floor_matchup(
    formation: Array,
    floor_archetypes: Array[String]
) -> MatchupResult
```

**Pass 5C call-site migration note**: Before Pass 5C, callers wrote `MatchupResolver.resolve_formation_matchup(...)` (static dispatch). After Pass 5C, callers receive a `matchup_resolver: MatchupResolver` instance (typically via constructor injection from their host autoload) and call `matchup_resolver.resolve_formation_matchup(...)`. The migration sites are: `DungeonRunOrchestrator` C.3 / C.4 (per-kill + per-archetype cache paths — see Orchestrator Pass 5C); `Combat Resolution` Rule 10 / D.5 (per-enemy throughput-factor path — flagged as a Combat Pass 3E follow-up, NOT landed in this Matchup pass; Combat's existing static call path temporarily continues to use `MatchupResolver.resolve_formation_matchup(...)` as a deprecated bridge until Combat Pass 3E lands the `matchup_resolver` injection); `Matchup Assignment Screen` (#23, undesigned — will inject when authored). The deprecated static bridge is documented below the AC H-18 structural assertion (see Section H).

**Rule 5.** The internal worker `_is_class_counter(class_data: HeroClass, enemy_archetype: String) -> bool` is private. It is the single string-equality comparison `class_data.counter_archetype == enemy_archetype` — duplicating Hero Class DB D.2's declaration. If Class DB ever changes the counter check logic, the resolver must change in lockstep.

#### Aggregation Rule (Majority Threshold)

**Rule 6.** `resolve_formation_matchup` iterates each `HeroInstance` in `formation`, resolves its `HeroClass` via `DataRegistry.resolve("classes", hero.class_id)`, and calls `_is_class_counter(class_data, enemy_archetype)`. Let `n` = number of heroes for which the check returns `true`, and `N` = `formation.size()` (the count of non-null heroes after the Rule 10 / E.2 filtering). The formation is matchup-advantaged for this archetype iff `n > N / 2` (integer division — strict majority). For MVP `N = FORMATION_SIZE = 3`, the threshold is `n >= 2`. Crossing the threshold yields a single application of `MATCHUP_GOLD_MULTIPLIER = 1.5×` (no stacking beyond the threshold). The threshold rule was selected during 2026-04-19 review to prevent the Pillar 3 decision from collapsing in MVP (with boolean OR + 3 archetypes × 3 classes, the W+M+R formation was trivially dominant after run 1; under majority threshold W+M+R crosses no thresholds anywhere, forcing a real specialist-vs-generalist tradeoff). This rule is locked by Hero Class DB E.5 (revised same session) and is non-negotiable for MVP. V1.0 may revisit pending playtest evidence; see Open Questions.

**Rule 7.** `matched_archetypes` records each archetype for which the formation crosses the majority threshold, exactly once per archetype. A formation with **one** Warrior on a bruiser-only floor (`N = 3`, `n = 1`, `n > 1` is `false`) yields `matched_archetypes = []`. A formation with **two** Warriors on the same floor (`n = 2`, `n > 1` is `true`) yields `matched_archetypes = ["bruiser"]`. A Warrior + Warrior + Mage formation against a multi-archetype floor (bruiser + caster + armored) yields `matched_archetypes = ["bruiser"]` — bruiser crosses majority via the two Warriors; caster and armored do not (one Mage, zero Rogues). `matched_archetypes` is sorted alphabetically before return so that two equivalent calls produce byte-identical results (matters for golden-file testing and offline snapshot equality checks).

#### Per-Kill Evaluation Model (No "Primary Archetype")

**Rule 8.** The Dungeon Run Orchestrator calls `resolve_formation_matchup` once per enemy death, passing the dying enemy's `archetype` string. The formation passed in is the *frozen dispatch snapshot* (Rule 11) — never a live read from the Roster. **Each kill on a multi-archetype floor is evaluated independently**: two Elder Boar kills (bruiser) and two Moss Druid kills (caster) on Floor 3 resolve separately. A formation of Warrior + Warrior + Mage earns the `1.5×` bonus on Elder Boar kills (bruiser threshold crossed: 2/3 ≥ 2) but NOT on Moss Druid kills (caster threshold not crossed: 1/3 < 2) and NOT on Vined Knight kills (armored threshold not crossed: 0/3 < 2). A generalist Warrior + Mage + Rogue formation earns neutral `1.0×` on every kill on this floor (each archetype reaches `n = 1` only, below the `n >= 2` threshold for `N = 3`). The specialist gets 2/5 advantaged kills on F3; the generalist gets 0/5; the choice is real.

**Rule 9.** No concept of a "floor's primary archetype" exists in the resolver or in any upstream call path. The per-kill model is the *only* model — it makes the Section B fantasy honest ("matchup bonus on 1,847 kills" requires per-enemy resolution, not a flattened per-run multiplier).

#### Empty-Formation Defensive Guard

**Rule 10.** If `formation` is empty (length 0), `resolve_formation_matchup` returns immediately:
```
MatchupResult { is_advantaged = false, matched_archetypes = [] }
```
No iteration; no `DataRegistry` calls; no error; no signal. This is a defensive guard, not a contract: the Dungeon Run Orchestrator must not dispatch an empty formation (a Formation Assignment System #17 precondition). The resolver degrades gracefully rather than asserting because asserting would crash valid offline replay paths if a corrupted save somehow resurrects an empty-formation snapshot. Almanac framing: "an empty formation earns no guild wisdom."

#### Frozen Dispatch Snapshot Contract

**Rule 11.** The `formation` parameter passed to the resolver MUST be a snapshot frozen at dispatch time, not a live read of `HeroRoster.get_formation_heroes()` at the moment of resolution. This matters for:
- **Offline replay**: the formation could change between dispatch and the next session start; replay must use the dispatched snapshot.
- **Determinism**: two calls with the same snapshot must always return identical results, even if the live roster has changed in between.

The Orchestrator and Offline Engine own the snapshot — they pass the snapshot's `Array[HeroInstance]` (or its deserialized equivalent) to the resolver per call.

#### Statelessness and Determinism

**Rule 12.** Pure function. No instance variables, no class-level mutable state, no caches, no RNG, no time-dependent reads. Given identical `formation` and `enemy_archetype` inputs, `resolve_formation_matchup` always returns an identical `MatchupResult`. This satisfies Pillar 1's offline-replay-fairness requirement automatically — no special synchronization or seeding code needed.

#### Unknown / V1.0 Archetypes

**Rule 13.** If `enemy_archetype` is a string that no class in the current `DataRegistry` counters (e.g. `"beast"` in MVP before the Ranger ships, or any future-V2.0 archetype), `_is_class_counter` returns `false` for all heroes. `resolve_formation_matchup` returns `MatchupResult { is_advantaged = false, matched_archetypes = [] }` and logs nothing. No special-case code, no hardcoded archetype list anywhere in the resolver. V1.0 activates new counters by adding class data files to `DataRegistry`; the resolver code does not change.

#### Offline Snapshot Contract

**Rule 14.** The Offline Progression Engine calls `resolve_floor_matchup` *exactly once* at dispatch snapshot time, passing the frozen formation and the floor's deterministic deduplicated archetype list. The resulting `MatchupResult` is stored verbatim in the offline snapshot. During replay, per-kill evaluation reads `snapshot.matchup_result.matched_archetypes.has(enemy.archetype) -> bool` instead of re-calling the resolver per kill. This is mathematically equivalent **only if both the formation and the floor's enemy composition are immutable for the duration of the replay** — which is enforced by two invariants the Offline Engine GDD MUST honor:

1. **Frozen formation**: the snapshot stores the formation slot assignments captured at dispatch time, not a live read of the Roster.
2. **Frozen floor archetypes**: the snapshot stores `floor_archetypes` captured at dispatch time, not derived from a live `Floor.enemy_list` read at replay time. (A patch-time data update that changes enemy archetypes mid-replay would otherwise silently corrupt per-kill outcomes.)

The optimization shaves resolver call overhead from the offline batch budget. The resolver itself does not implement this caching; the Offline Engine owns the snapshot pattern. Per-kill replay must NOT call `MatchupResolver.*` and MUST NOT call `DataRegistry.resolve` for class data — both are dispatch-time-only operations. This invariant is asserted by H-13's call-count check.

**Snapshot serializability**: The snapshot stores the resolved `MatchupResult` (a `bool` + a small sorted `Array[String]`) plus enough context to identify which `class_id`s were in the formation (for UI replay; the resolver itself does not need them). The snapshot does NOT store live `HeroInstance` references — those carry signal connections and live `HeroClass` resource pointers that are not JSON-serializable. The Offline Engine GDD owns the snapshot schema; this GDD's contract is "store the `MatchupResult` and an `Array[String]` of class_ids; reconstruct nothing else."

---

### C.2 States and Transitions

The Matchup Resolver is a stateless utility. **There is no state machine.** No states, no transitions, no persisted fields, no lifecycle methods (`_ready`, `_process`, etc.). This subsection documents that absence explicitly so implementers do not introduce state by habit.

**Content modes (not runtime states):**

| Content Mode | Active When | Effect on Resolver |
|---|---|---|
| **MVP (Tier-1 only)** | Launch through V1.0 | Only `bruiser`, `caster`, `armored` archetypes are countered by any class in `DataRegistry`. Enemies with `beast`, `construct`, or `incorporeal` archetypes resolve to `is_advantaged = false`. |
| **V1.0 (Tier-2 added)** | V1.0 release | Cleric/Ranger/Tactician class files added to `DataRegistry`; `incorporeal`/`beast`/`construct` archetypes now resolve to `is_advantaged = true` for matching formations. **Zero resolver code changes.** |

These are content-driven, not state-driven. A new `.tres` file in `assets/data/classes/` is the entire V1.0 activation path for the resolver.

---

### C.3 Interactions with Other Systems

| Consumer | Call Site | Inputs | Exact Signature | What It Receives | Downstream Action |
|---|---|---|---|---|---|
| **Dungeon Run Orchestrator (#13)** | Per enemy death (foreground run); per-archetype cache at DISPATCHING (offline path) | Frozen dispatch formation snapshot; dying enemy's `archetype` | `matchup_resolver.resolve_formation_matchup(formation_snapshot, enemy.archetype) -> MatchupResult` (instance call via the Orchestrator's injected `matchup_resolver: MatchupResolver` field — Pass 5C DI) | `result.is_advantaged: bool` | Emits `enemy_killed(enemy.tier, result.is_advantaged)` to Economy. `matched_archetypes` is unused by Orchestrator. |
| **Matchup Assignment Screen (#23, undesigned)** | Per-floor preview render (live, on every formation slot change) | Live formation via `HeroRoster.get_formation_heroes()`; floor's deduplicated archetype list (caller derives from `Floor.enemy_list`) | `MatchupResolver.resolve_floor_matchup(formation, floor_archetypes) -> MatchupResult` | `result.is_advantaged`, `result.matched_archetypes` | Renders per-archetype "covered" indicators in the almanac-warm UI. Consumes `matched_archetypes` to label which archetypes are currently countered. |
| **Offline Progression Engine (#12, undesigned)** | Once at dispatch snapshot time; then per-kill during replay (no resolver call — array lookup) | Snapshot: frozen formation + floor archetype list. Replay: stored `matched_archetypes` vs per-kill `enemy.archetype`. | Snapshot: `MatchupResolver.resolve_floor_matchup(frozen_formation, floor_archetypes)` → store result. Replay: `snapshot.matched_archetypes.has(enemy_archetype)` (pure array lookup). | Snapshot stores full `MatchupResult`. Replay reads boolean per kill. | Constructs `is_matchup_advantaged: bool` per kill for Economy batch replay. Determinism guaranteed by Rule 12. |
| **Combat Resolution (#11)** | Per distinct `enemy_list` entry inside `_kill_schedule_for_loop` at dispatch (MVP, Pass 2B) | Frozen dispatch formation snapshot; enemy's `archetype` | `MatchupResolver.resolve_formation_matchup(formation_snapshot, enemy.archetype) -> MatchupResult` | `result.is_advantaged: bool` | Selects `MATCHUP_THROUGHPUT_FACTOR_ADV` (default `1.5`) vs `MATCHUP_THROUGHPUT_FACTOR_DIS` (default `1.0`) to scale `formation_dps_per_tick` per enemy (Combat GDD #11 Rule 10 / D.5). Pillar 3 tempo payoff. `matched_archetypes` is unused by Combat. |
| **Formation Assignment System (#17, undesigned)** | Pre-dispatch validation | Live formation | Does NOT call the resolver. Reads `HeroRoster.get_formation_heroes()` directly to validate non-empty before enabling dispatch. | — | The empty-formation guard (Rule 10) is a defensive backstop, not a substitute for this precondition check. |
| **Economy System (#5, designed)** | Receives `enemy_killed` signal | Tier + `is_matchup_advantaged` from Orchestrator | Does NOT call the resolver directly. Reads `MATCHUP_GOLD_MULTIPLIER = 1.5` registry constant. | — | Applies the multiplier in `kill_bonus(enemy_tier) × matchup_multiplier` per Economy D.2. |

#### Cross-system contracts that downstream GDD authors must honor

1. **Dungeon Run Orchestrator** must pass a *frozen snapshot* of the formation captured at dispatch time, not a live `HeroRoster.get_formation_heroes()` read mid-run. Formation contents cannot change mid-run. The signal `enemy_killed(tier, is_matchup_advantaged)` is the Economy contract — its boolean parameter is the resolver's output.

2. **Offline Progression Engine** must store the `MatchupResult` in the offline snapshot, not re-evaluate the resolver during per-kill replay. Use the `matched_archetypes.has(...)` lookup pattern. The snapshot is invalidated only when the formation assignment changes (owned by Formation Assignment, not the resolver) AND must include a frozen `floor_archetypes` list captured at dispatch time, NOT derived from a live `Floor.enemy_list` read during replay (Rule 14).

3. **Matchup Assignment Screen** is responsible for deriving and *deduplicating* `floor_archetypes` from `Floor.enemy_list`. Recommended local helper: `_collect_floor_archetypes(floor: Floor) -> Array[String]`. The resolver accepts `Array[String]` directly and does not deduplicate.

4. **Economy** receives the resolver output indirectly via the Orchestrator's signal. Economy does not import the resolver. `MATCHUP_GOLD_MULTIPLIER` lives in Economy's tuning knobs; the resolver does not know about gold values.

---

## D. Formulas

### D.1 Class Counter Check (Cross-Referenced)

This is the only "formula" in the resolver — a string equality test. It is declared in **Hero Class DB GDD #5 Section D.2** as `is_class_counter(class_data, enemy_archetype)`:

```
is_class_counter(class_data, enemy_archetype) =
    (class_data.counter_archetype == enemy_archetype)
```

The resolver's private `_is_class_counter()` is the implementation of this declaration. No new math; see Class DB D.2 for the variable table.

**Output**: `bool`. `true` → Economy applies `MATCHUP_GOLD_MULTIPLIER` (1.5× from registry constant, owned by Economy GDD #5). `false` → neutral `1.0×`.

### D.2 Formation Aggregation (Majority Threshold over heroes)

```
N = formation.size()                          # count of non-null heroes (post Rule 10 / E.2 filter)
n = count(_is_class_counter(hero.class, enemy_archetype) for hero in formation)
is_advantaged = (n > N / 2)                   # integer division — strict majority
```

Per-archetype evaluation is short-circuit-friendly but cannot terminate early: implementations must count all `n` to apply the threshold. For MVP `FORMATION_SIZE = 3` the threshold is `n >= 2`. For `N = 1` the threshold is `n >= 1` (a solo formation must counter to qualify). For `N = 2` the threshold is `n >= 2` (both must counter — strict majority of 2 requires more than 1). For `N = 4` the threshold is `n >= 3`. For empty formation (`N = 0`), the Rule 10 guard returns `{false, []}` before reaching this formula.

**Variable table:**

| Variable | Type | Range | Description |
|---|---|---|---|
| `formation` | `Array[HeroInstance]` | length 0–`FORMATION_SIZE` | Frozen dispatch snapshot (Rule 11). |
| `enemy_archetype` | `String` | one of `EnemyArchetypes` constants | The archetype of the killed enemy or queried floor archetype. |
| `N` | `int` | 0 – `FORMATION_SIZE` (=3 in MVP) | Count of non-null heroes after Rule 10 / E.2 filter. |
| `n` | `int` | 0 – `N` | Count of heroes whose class counters this archetype. |
| `is_advantaged` | `bool` | `true` iff `n > N / 2` | Output of D.2. |

**Output**: `bool`. Paired with the sorted, deduplicated `matched_archetypes: Array[String]` in the `MatchupResult` struct.

### D.3 Matched-Archetypes Collection (Floor-Level)

Used by `resolve_floor_matchup`:

```
N = formation.size()
matched_archetypes = sorted(unique([
    a for a in floor_archetypes
    if count(hero.class.counter_archetype == a for hero in formation) > N / 2
]))
is_advantaged = not matched_archetypes.is_empty()
```

**Output**: deduplicated, alphabetically sorted `Array[String]`. Empty iff no archetype in the floor crosses the formation's majority threshold.

**Worked example — Warrior + Warrior + Mage (specialist) vs Floor 3 (`floor_archetypes = ["armored", "bruiser", "caster"]`, `N = 3`, threshold `n >= 2`):**
```
For "bruiser":  n = 2 (both Warriors)        → 2 >= 2  → matched
For "caster":   n = 1 (one Mage)             → 1 < 2   → not matched
For "armored":  n = 0                        → 0 < 2   → not matched
matched_archetypes = ["bruiser"]   (sorted)
is_advantaged = true
```
Per-kill evaluation of the 5 F3 enemies using this result: 2 Hollow Brutes (bruiser) → 1.5×; 2 Moss Druids (caster) → 1.0×; 1 Vined Knight (armored) → 1.0×. Total matchup-bonus kills: 2 of 5 (40%).

**Worked example — Warrior + Mage + Rogue (generalist) vs Floor 3 (`N = 3`, threshold `n >= 2`):**
```
For "bruiser":  n = 1 (Warrior)              → 1 < 2   → not matched
For "caster":   n = 1 (Mage)                 → 1 < 2   → not matched
For "armored":  n = 1 (Rogue)                → 1 < 2   → not matched
matched_archetypes = []
is_advantaged = false
```
The generalist gets 0/5 advantaged kills. **This is the Pillar 3 decision in numerical form**: the same 3 hero slots produce 40% advantaged kills as a bruiser specialist or 0% as a generalist — and the player picks per-dungeon.

**Worked example — Warrior-only solo formation (`N = 1`, threshold `n >= 1`) vs Floor 3:**
```
For "bruiser":  n = 1                        → 1 >= 1  → matched
For "caster":   n = 0                        → 0 < 1   → not matched
For "armored":  n = 0                        → 0 < 1   → not matched
matched_archetypes = ["bruiser"]
is_advantaged = true
```
Solo formations qualify trivially because the threshold collapses; this is intentional — a single-slot dispatch is itself a specialist by construction.

**Worked example — empty formation vs any floor (`N = 0`):**
```
matched_archetypes = []  (guard clause, Rule 10 — does not reach D.3)
is_advantaged = false
```

---

## E. Edge Cases

### E.1 Empty Formation Passed to resolve_formation_matchup

**Behavior**: Returns `MatchupResult { false, [] }` immediately via Rule 10 guard. No iteration, no `DataRegistry` calls. Not an error; the Orchestrator shouldn't dispatch one, but the Resolver degrades cozy-correctly.

### E.2 HeroInstance Has class_id That Does Not Resolve

**Scenario**: `DataRegistry.resolve("classes", hero.class_id)` returns `null` during resolver iteration (hero's class was removed from data in a patch before Roster boot validation fired).

**Behavior**: Per Hero Class DB E.1 + Hero Roster Rule 16, orphaned heroes are dropped from the roster at boot validation — this case should not reach the resolver. Defensive: if the resolver encounters a null `class_data`, skip that hero silently (treat as non-counter) and continue iteration. Log nothing (Save/Load already handled the player notice at boot). Formation length for aggregation counts only non-null resolutions. If ALL heroes are null, result is `{ false, [] }` equivalent to the empty-formation case.

### E.3 enemy_archetype Is an Empty String or null

**Scenario**: Caller passes `""` or `null` as `enemy_archetype` (programmer error).

**Behavior**: `_is_class_counter` returns `false` for every hero (no class has an empty `counter_archetype`; schema validation forbids it). `resolve_formation_matchup` returns `{ false, [] }`. Logs `push_error("MatchupResolver: empty or null enemy_archetype passed")`. Defensive but not assertive; offline replay must never crash.

### E.4 enemy_archetype Is a V1.0-Reserved String in MVP Build

**Scenario**: An enemy with `archetype = "beast"` loads in MVP. No current class counters beast.

**Behavior**: Per Rule 13, resolver returns `{ false, [] }` normally. No error, no warning — this is expected operational behavior, not an exceptional path. V1.0 activates beast counters by adding the Ranger class; zero resolver code change.

### E.5 Formation Contains Duplicate instance_id

**Scenario**: A save corruption resurrects two `HeroInstance` records with the same `instance_id` (blocked by Roster boot validation Rule 16 but theoretically possible in unit tests).

**Behavior**: The resolver does not check `instance_id` uniqueness — it iterates the array order-preserving. Two "copies" of the same instance contribute the same counter once (the `matched_archetypes` deduplication absorbs the redundancy). No failure, no weird doubling of anything.

### E.6 floor_archetypes Contains Duplicates (Caller Forgot to Dedupe)

**Scenario**: `resolve_floor_matchup` receives `floor_archetypes = ["bruiser", "bruiser", "caster"]` because the caller forgot to dedupe.

**Behavior**: Internal deduplication via `unique()` in D.3. `matched_archetypes` output is still deduplicated. Slightly wasteful iteration (~3 string compares vs 2), negligible cost. No warning — the resolver is defensive about caller mistakes.

### E.7 floor_archetypes Is Empty

**Scenario**: `resolve_floor_matchup` is called with `floor_archetypes = []` (e.g., a floor with no enemies, forbidden by Biome/Dungeon DB schema but defensively handled).

**Behavior**: Returns `{ false, [] }` — there are no archetypes to check. No error.

### E.8 Stacking Multiple Counter Heroes of the Same Class

**Scenario A**: Formation = 2 Warriors only (`N = 2`, threshold `n >= 2`). Fighting a bruiser.
**Behavior**: `n = 2`, `2 >= 2` → `is_advantaged = true`. 1.5× applied once. Stacking does NOT produce 2.25× or any multiplier above 1.5×.

**Scenario B**: Formation = 2 Warriors + 1 Mage (`N = 3`, threshold `n >= 2`). Fighting a bruiser.
**Behavior**: `n = 2`, `2 >= 2` → `is_advantaged = true`. The second Warrior is **load-bearing** here — without it, `n = 1` and the formation fails the threshold. Under the majority rule, stacking is the *whole mechanism* by which a 3-slot formation crosses the threshold for a single archetype.

**Scenario C**: Formation = 1 Warrior + 1 Mage + 1 Rogue (`N = 3`, threshold `n >= 2`). Fighting a bruiser.
**Behavior**: `n = 1`, `1 < 2` → `is_advantaged = false`. The generalist gets neutral 1.0× even though one of its members counters this archetype.

Aggregation is the majority threshold rule (Rule 6 + D.2), revised 2026-04-19 from boolean OR. Locked by Hero Class DB E.5 (also revised same session). Design intent: the Pillar 3 decision is "is most of my formation built for this fight?" not "do I happen to own one of the right class?"

### E.9 Formation Counters Multiple Archetypes on Mixed-Archetype Floor

**Scenario A — generalist W+M+R on F3 (bruiser + caster + armored), `N = 3`, threshold `n >= 2`**:
**Behavior**: For each of the 3 archetypes, `n = 1` (one hero each) → all archetypes fail the threshold → all per-kill calls return `is_advantaged = false`. Floor 3 yields 0/5 advantaged kills for the generalist. The per-kill model is faithful but every kill is neutral.

**Scenario B — specialist W+W+M on F3, `N = 3`, threshold `n >= 2`**:
**Behavior**: bruiser `n = 2` (advantaged), caster `n = 1` (neutral), armored `n = 0` (neutral). Hollow Brute kills → 1.5×; Moss Druid + Vined Knight kills → 1.0×. F3 yields 2/5 advantaged kills.

**Scenario C — solo Warrior dispatch on F3, `N = 1`, threshold `n >= 1`**:
**Behavior**: bruiser `n = 1` (advantaged), caster `n = 0` (neutral), armored `n = 0` (neutral). Solo dispatches qualify trivially for the archetype the hero counters; the player gets 2/5 on F3 but with one-third the per-tick output (smaller absolute gold, same matchup percentage).

This is the Pillar 3 feel: **mixed floors punish generalists**; specialists clear what they're built for and accept neutral kills on what they're not.

### E.10 Offline Replay With Stale Snapshot Under a Rule Change

**Scenario**: A patch between session close and session open changes the counter taxonomy (e.g., hypothetical V1.5 rebalance: Mage now counters bruiser instead of caster). The offline snapshot was taken under old rules.

**Behavior**: The Offline Engine's snapshot contains the pre-patch `MatchupResult` values — replay uses them as-is. On next session's fresh dispatch, the new rules apply. This is intentional: offline replay preserves the player's perceived outcome under the rules that were active when they closed the app. If a V1.5 patch wants retroactive reassessment, that is a save-migration decision owned by Save/Load, not the resolver. Document in V1.0 patch notes policy.

### E.11 Concurrent Resolver Calls From Different Systems in the Same Tick

**Scenario**: Orchestrator calls `resolve_formation_matchup` for enemy death; Matchup Assignment Screen simultaneously calls `resolve_floor_matchup` for UI refresh.

**Behavior**: GDScript is single-threaded. Both calls serialize on the main thread. The resolver is stateless, so there is no shared state to race on. Not an edge case requiring handling — documented only to confirm the pure-function design makes concurrency a non-issue.

---

## F. Dependencies

### Upstream Dependencies (systems this one depends on)

| Upstream | Hard/Soft | Interface | Locked Contracts |
|---|---|---|---|
| **Hero Class Database** (`design/gdd/hero-class-database.md`) | Hard | `DataRegistry.resolve("classes", class_id) -> HeroClass \| null`; reads `HeroClass.counter_archetype: String` only; cites Class DB D.2 (`is_class_counter`) and C.2 (`EnemyArchetypes` constant set) | Class DB owns the counter check definition; resolver's `_is_class_counter` is an implementation of that declaration. If Class DB changes the check logic, the resolver must change in lockstep. |
| **Enemy Database** (`design/gdd/enemy-database.md`) | Hard (indirectly — via callers) | Callers (Orchestrator, Matchup Assignment Screen, Offline Engine) read `EnemyData.archetype: String` and pass it as the `enemy_archetype` parameter. Resolver itself does not import `EnemyData`. | Archetype string values must match the `EnemyArchetypes` constant set (declared in Class DB C.2). |
| **Hero Roster** (`design/gdd/hero-roster.md`) | Hard (indirectly — via callers) | Callers pass `Array[HeroInstance]` snapshots to the resolver. Resolver reads `hero.class_id` to resolve `HeroClass` via `DataRegistry`. | Formation must be a frozen dispatch snapshot, never a live roster read (Rule 11). |
| **Biome & Dungeon Database** (`design/gdd/biome-dungeon-database.md`) | Hard (indirectly — via callers) | Matchup Assignment Screen and Offline Engine derive `floor_archetypes: Array[String]` from `Floor.enemy_list`. Resolver itself does not import `Floor`. | Floor's `enemy_list` is authoritative for per-floor archetype enumeration. |
| **Data Loading System** (`design/gdd/data-loading.md`) | Hard (transitive) | `DataRegistry.resolve("classes", id)` — the one registry call the resolver makes. | Standard registry contract. |

### Downstream Dependents (systems that depend on this)

| Consumer | Hard/Soft | Interface | What they read/write |
|---|---|---|---|
| **Dungeon Run Orchestrator** (#13) | Hard | `matchup_resolver.resolve_formation_matchup(formation, enemy_archetype) -> MatchupResult` (instance method on injected `matchup_resolver: MatchupResolver`; Pass 5C DI) | Per-enemy-death + per-archetype-cache at DISPATCHING; emits `enemy_killed(tier, is_matchup_advantaged)` to Economy |
| **Matchup Assignment Screen** (#23, undesigned) | Hard | `matchup_resolver.resolve_floor_matchup(formation, floor_archetypes) -> MatchupResult` (instance method — the screen will receive the injected resolver from its host when #23 is authored; Pass 5C DI) | Per-floor preview; consumes both `is_advantaged` and `matched_archetypes` for UI |
| **Offline Progression Engine** (#12, undesigned) | Hard | Calls `resolve_floor_matchup` once at dispatch snapshot; stores `MatchupResult`; replays via `matched_archetypes.has(enemy_archetype)` lookup | Snapshot pattern; no resolver call per replayed kill |
| **Combat Resolution** (#11) | Hard (MVP — Pass 2B) | Calls `MatchupResolver.resolve_formation_matchup(formation, enemy.archetype)` once per distinct `enemy_list` entry inside `_kill_schedule_for_loop` at dispatch. **Pass 5C — Combat Pass 3E migration flag**: Combat currently uses the pre-Pass-5C static-dispatch form as a temporary bridge. Combat Pass 3E will convert this to `matchup_resolver.resolve_formation_matchup(...)` via a `matchup_resolver: MatchupResolver` parameter added to `CombatResolver.compute_offline_batch` / `emit_events_in_range` (dependency passed through from the Orchestrator's injection). Until Pass 3E lands, the static bridge continues to work because `DefaultMatchupResolver` is instance-compatible — a test running Combat in isolation can construct `DefaultMatchupResolver.new()` and use its instance method directly; a test mocking Combat's matchup dependency still cannot do so at the Combat boundary (the Orchestrator-level spy path via AC-ORC-11 is the current substitute). | Consumes `is_advantaged` to scale per-enemy throughput via `MATCHUP_THROUGHPUT_FACTOR_ADV`/`_DIS` (Combat D.5). Pillar 3 mechanical payoff. |
| **Economy System** (`design/gdd/economy-system.md`) | Indirect | Does NOT import the resolver. Receives `is_matchup_advantaged` via Orchestrator's `enemy_killed` signal. | Applies `MATCHUP_GOLD_MULTIPLIER = 1.5` in `kill_bonus` formula per Economy D.2. |
| **Class Synergy System** (#32, V1.0 first-pass 2026-05-09) | Indirect (archetype string source) | Reads enemy `archetype` string ("bruiser", "skirmisher", etc.) for Steel Wall conditional check (`archetype == "bruiser"` triggers ×1.25 multiplier). Does NOT call the resolver directly — receives the archetype via Combat Resolution's per-kill schedule. Per `class-synergy-system.md` §C.1 + §F. | Per-kill conditional check; no formula coupling. |

### Bidirectional Consistency

- `design/gdd/hero-class-database.md` Dependencies section: ✅ declares `is_class_counter` (D.2) and the `EnemyArchetypes` constant set (C.2), which the resolver consumes.
- `design/gdd/enemy-database.md` Dependencies section: ✅ declares `archetype` field on `EnemyData`; the resolver is a transitive consumer via callers.
- `design/gdd/hero-roster.md` Dependencies section: ✅ declares `get_formation_heroes()` returning `Array[HeroInstance]`; the resolver is a transitive consumer via the frozen-snapshot pattern passed by callers.
- `design/gdd/biome-dungeon-database.md` Dependencies section: ✅ declares `Floor.enemy_list`; the resolver is a transitive consumer via callers.
- `design/gdd/economy-system.md`: references `MATCHUP_GOLD_MULTIPLIER` registry constant and `matchup_multiplier` parameter. **Errata applied 2026-04-19 same session**: C.2.4 wording "primary enemy type" replaced with explicit per-kill majority-threshold language; `matchup_multiplier` variable description updated; calibration note added flagging that `MATCHUP_GOLD_MULTIPLIER` and the Day 3-4 Tier-2 milestone (8,000g) need re-validation under the new lower hit-rate produced by majority aggregation.
- `design/gdd/hero-class-database.md`: C.6 erroneously described the resolver as caching "once per formation-enemy pairing." **Errata applied 2026-04-19 same session**: replaced with per-kill no-caching language (matches Rule 12). E.5 "at least one counter" rule replaced with majority-threshold language (matches revised Rule 6). D.2 note also updated.

### Recommended Cross-System Additions (for V1.0 readiness)

- **Enemy DB**: consider adding a `future_counter: String` field to `EnemyData` schema so future V1.0 archetypes (beast/construct/incorporeal) appearing in MVP enemy data can render a "your guild hasn't mastered this foe's kind yet" tooltip on the Matchup Assignment Screen. Cost: one field + one UI string. Converts a potential friction point (no-bonus enemies with no explanation) into a V1.0 anticipation hook. **Not a hard requirement of this GDD** — raised as a design recommendation for the Enemy DB owner. See Open Questions.

### New cross-system contracts introduced by this GDD

1. `MatchupResult` value type with fields `is_advantaged: bool` + `matched_archetypes: Array[String]`
2. `MatchupResolver` injectable instance class (`extends RefCounted`, Pass 5C) with two public instance methods: `resolve_formation_matchup`, `resolve_floor_matchup`; concrete production impl is `DefaultMatchupResolver extends MatchupResolver`
3. Orchestrator DI pattern — **lazy-default with two public setters** (locked in `dungeon-run-orchestrator.md` §J.1 Option A; codified at ADR level by ADR-0009). Orchestrator exposes `func set_matchup_resolver(resolver: MatchupResolver) -> void` (non-null asserting) alongside the parallel `set_combat_resolver(resolver: CombatResolver) -> void`; tests call both setters BEFORE `add_child(orchestrator)`; production `_ready()` null-checks each field and lazy-constructs `DefaultMatchupResolver.new()` / `DefaultCombatResolver.new()` when still null (i.e., when no test has pre-injected). The Orchestrator's `_init()` takes zero required arguments (Godot autoload system calls `_init()` with zero args per autoload.md Claim 4 [VERIFIED]; required-arg `_init` on an autoload Node fails instantiation). Pass-INIT-PROBE-SYNC 2026-04-22 corrected the prior phrasing from `_init(combat_resolver, matchup_resolver)` to this pattern. See ADR-0009 + ADR-0003 Amendment #3 + `dungeon-run-orchestrator.md` §J.1 (the canonical locked source).
4. Frozen-dispatch-snapshot contract (Rule 11)
5. Offline snapshot pattern using `matched_archetypes.has(...)` lookup (Rule 14) — downstream Offline Engine GDD must honor
6. Per-kill evaluation model — Economy GDD wording to be reconciled

---

## G. Tuning Knobs

The Matchup Resolver has **no tuning knobs of its own**. It is a pure-function system with behavior entirely determined by upstream data (`HeroClass.counter_archetype`, `EnemyData.archetype`). This section documents the absence explicitly and points to the knobs owned elsewhere that affect matchup outcomes.

### G.1 Knobs That Affect Matchup Outcomes (Owned Elsewhere)

| Knob | Owner | Why it matters here |
|---|---|---|
| `counter_archetype` per class | Hero Class Database (#5) — per-class `.tres` file | Changing a class's counter archetype changes which enemies it counters. Rebalancing this is a design-time decision via `.tres` file edit. |
| `archetype` per enemy | Enemy Database (#6) — per-enemy `.tres` file | Changing an enemy's archetype changes which classes counter it. Same `.tres` edit mechanism. |
| `MATCHUP_GOLD_MULTIPLIER` | Economy (#5) — registered constant, value 1.5 | The magnitude of the matchup payoff. Safe range 1.0–2.5 per Economy G. Resolver outputs a bool; Economy applies the multiplier. |
| `MATCHUP_DRIP_BONUS` | Economy (#5) — registered constant, default 1.0 (disabled) | If non-1.0, matchup advantage also boosts per-tick drip. Resolver's bool output feeds this too. |

### G.2 Why No Resolver-Owned Knobs

A tuning knob on the resolver itself would either:
1. Parameterize the aggregation rule (currently majority threshold `n > N/2`; alternatives include boolean OR `n >= 1`, supermajority `n >= ceil(2N/3)`, or unanimity `n == N`) — this is a **design decision**, not a knob. The current rule is locked by Hero Class DB E.5 and Rule 6. Changing it is a GDD revision, not a tuning pass.
2. Parameterize the counter check (e.g., fuzzy match, partial credit) — this would contradict the simple, legible "counter or not" fantasy locked in Section B.
3. Add a per-call behavior flag (e.g., "strict mode" vs "lenient mode") — this creates ambiguity in the offline replay determinism contract (Rule 12) and multiplies the test surface with no player-facing payoff.

The resolver is designed to be **unparameterized** precisely because its determinism and offline-replay-correctness depend on having no configurable behavior. Matchup balance lives in the upstream data; the resolver faithfully executes whatever the data says.

**Aggregation rule revisit triggers (playtest evidence that would prompt re-opening Rule 6):**

| Symptom in playtest | Possible re-tuning direction |
|---|---|
| Players don't notice the formation decision; matchup-screen interaction <50% by Day 2 | Soften threshold to `n >= 1` (boolean OR) so the decision is forgiving early; pair with a separate "synergy bonus" knob that rewards stacking. |
| Specialist formations dominate; rosters collapse to 6–9 of one class | Tighten threshold to `n >= 3` (`N=3` requires unanimity); rewards diversification within the threshold. |
| Per-kill matchup-bonus pop feels invisible in foreground play | Knob is `MATCHUP_GOLD_MULTIPLIER` (Economy G), not the threshold. Resolver remains unchanged. |
| MATCHUP_GOLD_MULTIPLIER recalibration (post-revision) lands above 2.0 to hit the Tier-2 milestone | Re-open: the high multiplier × low hit-rate combo may indicate the threshold is too strict. |

These triggers are **playtest gates**, not auto-tunable values. The resolver code does not branch on them; rule changes are GDD revisions that cascade to Class DB E.5 and the AC suite.

---

## H. Acceptance Criteria

All criteria use Given-When-Then format. **17 criteria total** (13 BLOCKING + 4 ADVISORY) after 2026-04-19 revision: H-12/H-13 demoted ADVISORY pending real Orchestrator + Offline Engine GDDs; H-14 already ADVISORY; H-15/H-16/H-17 added new (Rule 1 structural assertion, Rule 14 DataRegistry call-count assertion, threshold-fail load-bearing test). H-17 is ADVISORY (CI canary against stub); H-15 + H-16 are BLOCKING.

### H-01 — Pure-Counter Stacking Crosses Threshold At All Sizes (Logic, BLOCKING)

**GIVEN** a Warrior-only formation (`counter_archetype = "bruiser"`),
**WHEN** `resolve_formation_matchup(formation, "bruiser")` is called for formations of size 1 (one Warrior), 2 (two Warriors), and 3 (three Warriors),
**THEN** all three calls return identical `MatchupResult { is_advantaged = true, matched_archetypes = ["bruiser"] }`. Threshold computation:
- size 1: `N=1`, `n=1`, `n > N/2` is `1 > 0` → `true`
- size 2: `N=2`, `n=2`, `n > N/2` is `2 > 1` → `true`
- size 3: `N=3`, `n=3`, `n > N/2` is `3 > 1` → `true`

`matched_archetypes` contains exactly one entry regardless of formation size — crossing the threshold yields a single archetype entry, not one entry per qualifying hero. The 1.5× downstream multiplier is applied once, not per hero.

### H-02 — No-Counter Returns False (Logic, BLOCKING)

**GIVEN** a Warrior-only formation,
**WHEN** `resolve_formation_matchup(formation, "caster")` is called,
**THEN** returns `MatchupResult { is_advantaged = false, matched_archetypes = [] }`. No error logged.

### H-03 — Empty-Input Guards (Logic, BLOCKING)

Parameterized — two sub-cases:

(a) **GIVEN** an empty formation `[]`,
**WHEN** `resolve_formation_matchup([], "bruiser")` is called,
**THEN** returns `{ false, [] }`; no `DataRegistry.resolve` call is made (verifiable via mocked registry that asserts call count == 0); no error logged.

(b) **GIVEN** a non-empty Warrior formation and `floor_archetypes = []`,
**WHEN** `resolve_floor_matchup(formation, [])` is called,
**THEN** returns `{ false, [] }`; no error logged.

### H-04 — Unknown Archetype Returns False Cleanly (Logic, BLOCKING)

Parameterized — three sub-cases:

(a) **GIVEN** an MVP build (no Ranger/Tactician/Cleric in DataRegistry); a Warrior+Mage+Rogue formation,
**WHEN** `resolve_formation_matchup(formation, "beast")` is called,
**THEN** returns `{ false, [] }`; no error logged; no exception thrown; behavior identical for `"construct"` and `"incorporeal"`.

(b) **GIVEN** the same formation,
**WHEN** `resolve_formation_matchup(formation, "xyzzy")` is called (an arbitrary garbage string that is neither a current archetype nor a V1.0-reserved one),
**THEN** returns `{ false, [] }`; no error logged. **Critical**: this behavior is identical to the V1.0-reserved case in (a). The resolver does NOT distinguish a typo from a future archetype — that is the Enemy DB load-time validation's job (Rule 13 + see H-16). If a developer expects "xyzzy" to log a warning, they are looking at the wrong layer.

(c) **GIVEN** the same formation,
**WHEN** `resolve_formation_matchup(formation, "BRUISER")` is called (correct archetype but wrong case),
**THEN** returns `{ false, [] }` — string equality is case-sensitive (per Hero Class DB D.2). No error. This sub-case documents the case-sensitivity contract and prevents a "well-meaning" toLower normalization from sneaking in.

### H-05 — Floor Matchup Aggregation, Sorted, Deduplicated (Logic, BLOCKING)

**GIVEN** a Warrior + Warrior + Mage **specialist** formation (`N = 3`, threshold `n >= 2`); `floor_archetypes = ["armored", "bruiser", "caster"]` (F3 archetypes),
**WHEN** `resolve_floor_matchup(formation, floor_archetypes)` is called,
**THEN** returns `{ true, ["bruiser"] }` exactly. Threshold computation: bruiser `n=2 >= 2` (matched), caster `n=1 < 2` (not matched), armored `n=0 < 2` (not matched). Only bruiser appears in `matched_archetypes`. (See H-09 for sort isolation against non-trivial input ordering.)

### H-06 — Caller-Dedup Defensive Behavior (Logic, BLOCKING)

**GIVEN** a 2-Warrior + 1-Mage formation (`N = 3`, threshold `n >= 2`); `floor_archetypes = ["bruiser", "bruiser", "caster"]` (caller did not deduplicate),
**WHEN** `resolve_floor_matchup(formation, floor_archetypes)` is called,
**THEN** returns `{ true, ["bruiser"] }` — `matched_archetypes` is internally deduplicated despite duplicate input; bruiser threshold is crossed (`n=2`); caster does not cross (`n=1 < 2`); no error.

### H-07 — Determinism: Identical Inputs → Field-Equal Results (Logic, BLOCKING)

**GIVEN** a fixed formation and `enemy_archetype = "bruiser"`,
**WHEN** `resolve_formation_matchup` is called three times in succession,
**THEN** all three returned `MatchupResult` objects satisfy `result_a.is_advantaged == result_b.is_advantaged` AND structural equality on `result_a.matched_archetypes` vs `result_b.matched_archetypes` (element-wise comparison) for every pair.

> ⚠️ **Test author warning** (added 2026-04-19): `MatchupResult` extends `RefCounted`. Do **NOT** write `assert_eq(result_a, result_b)` or `result_a == result_b` — these compare object references, not field values, and will always fail across separately-allocated returns. Assert each field separately:
> ```
> assert_eq(result_a.is_advantaged, result_b.is_advantaged)
> assert_eq(result_a.matched_archetypes, result_b.matched_archetypes)   # GDScript Array == is structural, OK
> ```
> If a future refactor adds an `equals()` method to `MatchupResult`, prefer that. Until then, field-by-field is the only correct comparison.

### H-08 — Per-Kill Independence on Mixed-Archetype Floor (Logic, BLOCKING)

**GIVEN** a Warrior-only formation (`counter_archetype = "bruiser"`),
**WHEN** `resolve_formation_matchup` is called three times — once with `"bruiser"`, once with `"caster"`, once with `"armored"`,
**THEN** the three calls return `{ true, ["bruiser"] }`, `{ false, [] }`, and `{ false, [] }` respectively. The per-kill model produces three independent outcomes; no shared state between calls; no "primary archetype" leakage.

This is the load-bearing test for the per-kill evaluation model and the F3 mixed-floor design intent.

### H-09 — Alphabetical Sort with Non-Trivial Input Ordering (Logic, BLOCKING)

**GIVEN** a 2-Mage + 1-Rogue formation (`N = 3`, threshold `n >= 2`); `floor_archetypes = ["caster", "armored", "bruiser"]` (deliberately non-alphabetical input order — caster first, armored before bruiser),
**WHEN** `resolve_floor_matchup(formation, floor_archetypes)` is called,
**THEN** returns `{ true, ["caster"] }` — caster threshold crossed (`n=2 >= 2` via two Mages); armored fails (`n=1 < 2`, one Rogue); bruiser fails (`n=0`). Sort behavior is isolated by an input ordering that differs from alphabetical, so a coincidentally-sorted insertion order cannot accidentally pass this test.

**AND WHEN** the same formation is queried with `floor_archetypes = ["caster", "armored"]` (no bruiser, reverse-alphabetical pair),
**THEN** returns `{ true, ["caster"] }` — same outcome; armored does not appear in the output despite appearing in the input.

### H-10 — Null class_data Is Skipped Silently and Excluded From Threshold N (Logic, BLOCKING)

**GIVEN** a formation containing a `HeroInstance` whose `class_id` does not resolve via `DataRegistry` (returns null), alongside one valid Warrior,
**WHEN** `resolve_formation_matchup(formation, "bruiser")` is called,
**THEN** the null hero is silently skipped (no crash, no exception). After filtering: `N = 1` (one valid Warrior), `n = 1` (it counters bruiser), threshold `n >= 1` → `true`. Result: `{ true, ["bruiser"] }`. No error logged at the resolver layer (Save/Load owns the player notice at boot).

**AND WHEN** the formation is 1 valid Warrior + 2 nulls and the call is `resolve_formation_matchup(formation, "bruiser")`,
**THEN** post-filter `N = 1`, `n = 1`, threshold `n >= 1` → `true`. Result: `{ true, ["bruiser"] }`. **Critical contract**: nulls are EXCLUDED from `N` for threshold computation — they don't count as "non-counter heroes that drag the threshold up." Otherwise a corrupted save could silently demote a single-Warrior dispatch.

**AND WHEN** the same call is made with a formation where ALL heroes' `class_id` resolves to null,
**THEN** post-filter `N = 0`, returns `{ false, [] }` — equivalent to the empty-formation case (Rule 10 guard semantically reached).

### H-11 — Empty/Null enemy_archetype Logs Error and Returns False (Logic, BLOCKING)

Parameterized — two sub-cases:

(a) **GIVEN** a non-empty Warrior formation,
**WHEN** `resolve_formation_matchup(formation, "")` is called,
**THEN** returns `{ false, [] }`; **a `push_error` is emitted** containing the substring `"empty or null enemy_archetype"`.

(b) **GIVEN** the same formation,
**WHEN** `resolve_formation_matchup(formation, null)` is called,
**THEN** identical behavior — `{ false, [] }` + `push_error` emitted.

> **Test author note** (added 2026-04-19): The substring assertion depends on GdUnit4's `assert_error_logged()` (or equivalent) API in Godot 4.6 supporting substring matching against `push_error` output. **Pre-sprint validation step**: confirm GdUnit4 4.6 API supports this; if it does not, the AC fallback is to add a dedicated test-only return signal `_test_invalid_archetype` (gated behind an `if OS.is_debug_build()` check) that the test asserts on instead. Decision made by qa-lead before implementation; if signal route is taken, document it as Rule 2 exception.

### H-12 — Cross-System Integration: Orchestrator → Economy Kill-Bonus Pipeline (Integration, ADVISORY)

**Status note (2026-04-19 revision):** Demoted from BLOCKING to ADVISORY because both consuming systems (Orchestrator #13 + Economy #5) are stub-mocked here. The real BLOCKING gate for this integration lives in those GDDs' AC sections (to be added when authored). This AC remains here as a reference scenario and a smoke-test for early integration spike work.

**GIVEN** a stub Dungeon Run Orchestrator (injected with a `DefaultMatchupResolver.new()` instance per Pass 5C DI) + stub Economy + a 2-Warrior + 1-Mage formation (`N=3`, threshold `n>=2`); the Orchestrator triggers a Hollow Brute (`tier=1, archetype="bruiser"`) kill,
**WHEN** Orchestrator calls `matchup_resolver.resolve_formation_matchup(formation, "bruiser")` (instance method on injected field) and emits `enemy_killed(1, result.is_advantaged)`,
**THEN** the signal payload is `enemy_killed(1, true)` (bruiser threshold crossed: 2 Warriors meet `n>=2`); Economy's `kill_bonus(1)` formula applies `MATCHUP_GOLD_MULTIPLIER = 1.5` per Economy GDD D.2; gold awarded `= floor(15 × 1.5) = 22`.

**AND WHEN** the same Orchestrator triggers a Glowmoth (`tier=1, archetype="caster"`) kill against the same formation,
**THEN** signal is `enemy_killed(1, false)` (caster threshold not crossed: 1 Mage `< 2`); gold awarded `= floor(15 × 1.0) = 15`.

**Re-validation owners:** Orchestrator GDD #13 author MUST add a BLOCKING AC to that GDD that exercises this exact pipeline against the real (non-stub) Economy; Economy GDD already has `H-Economy-04` covering the kill_bonus formula. The cross-system handoff is what needs new AC ownership in #13.

### H-13 — Offline Snapshot Pattern Isolation (Integration, ADVISORY)

**Status note (2026-04-19 revision):** Demoted from BLOCKING to ADVISORY for the same reason as H-12 — the Offline Progression Engine GDD #12 is undesigned. The real BLOCKING gate for this contract belongs in #12's AC section. This AC remains here as the canonical contract description.

**GIVEN** the Offline Engine stores a `MatchupResult` snapshot at dispatch time (e.g., for a 2-Warrior + 1-Mage specialist formation on F3: `{ true, ["bruiser"] }`); a hypothetical patch then changes Mage's `counter_archetype` from `"caster"` to `"bruiser"` in the live `DataRegistry`,
**WHEN** the offline replay runs using the stored snapshot for per-kill resolution via `snapshot.matched_archetypes.has(enemy.archetype)`,
**THEN** the per-kill outcomes for that replay use the **pre-patch snapshot values**: bruiser kills are advantaged, caster kills are NOT. The Mage rule change does not affect the in-flight replay because the resolver is NOT called during replay — only the array lookup runs.

**AND WHEN** a mocked `DataRegistry` instrumenting `resolve()` call counts + a spy subclass of `MatchupResolver` (Pass 5C DI — extend `MatchupResolver` directly, override `resolve_formation_matchup` / `resolve_floor_matchup` to record and forward) are observed during the replay phase,
**THEN** `DataRegistry.resolve("classes", *)` call count is **exactly 0** during replay. (Snapshot-time call counts are non-zero by design; replay-time MUST be zero.) Spy `MatchupResolver.resolve_formation_matchup` and `resolve_floor_matchup` call counts during replay are also **exactly 0**. (The spy is injected into the Orchestrator + Offline Engine just like `DefaultMatchupResolver` would be in production; the assertion is that the per-kill replay loop consults `snapshot.matched_archetypes` rather than the injected resolver.)

**AND WHEN** the next foreground dispatch occurs after replay completes,
**THEN** a fresh `resolve_floor_matchup` call returns the **post-patch values** (Mage now matches bruiser). The post-patch dispatch may produce different `matched_archetypes` for the same formation+floor — that is the intended seam.

**AND WHEN** the snapshot's `floor_archetypes` field is mutated between dispatch and replay (simulating data corruption or a bad live-derivation),
**THEN** replay still uses the **stored** snapshot values, not any live-derived alternative. (Validates Rule 14's frozen-`floor_archetypes` invariant.)

**Re-validation owner:** Offline Engine GDD #12 author MUST add a BLOCKING AC encoding all four sub-cases above against the real Offline Engine implementation.

### H-14 — Resolver Performance (Performance, ADVISORY)

**GIVEN** a 3-hero formation,
**WHEN** `resolve_formation_matchup` is called 10,000 consecutive times against any single archetype,
**THEN** total wall-clock time is below the budget for the runtime tier:

| Hardware tier | Budget | Where it runs |
|---|---|---|
| **CI canary (BLOCKING within ADVISORY gate)** | < 200 ms on GitHub Actions `ubuntu-latest` standard runner | Runs every PR via `godot --headless --script tests/gdunit4_runner.gd`. Exists to catch accidental `DataRegistry`/loop-allocation regressions. |
| **Steam Deck baseline (manual)** | < 50 ms on Steam Deck (1280×800, performance profile) | Run manually before each milestone release. Result logged to `production/qa/evidence/matchup-resolver-perf-[date].md` with hardware profile (CPU model, OS, Godot version). |

The CI canary is the load-bearing test (catches regressions automatically). The Steam Deck manual run is the truth check (ensures the abstraction holds on shipping hardware). A failure on the CI canary blocks merge; a failure on the Steam Deck check blocks the milestone.

*Gate = ADVISORY*: a stateless string-comparison resolver will trivially hit both bounds. The criterion exists as a regression canary against accidental introduction of `DataRegistry` calls in a hot path (e.g., per-kill snapshot pattern broken by future refactor) — see H-17 for the call-count assertion that catches that drift directly.

### H-15 — Threshold-Fail Load-Bearing Test: Generalist Crosses Zero Thresholds (Logic, BLOCKING)

**This is the load-bearing test for the 2026-04-19 majority-threshold revision.** Without this AC, a regression to boolean OR could silently restore old behavior and pass H-01/H-05/H-06/H-09 (which still hold under both rules for their specific inputs).

**GIVEN** a Warrior + Mage + Rogue **generalist** formation (`N = 3`, threshold `n >= 2`),
**WHEN** `resolve_formation_matchup` is called against each of `"bruiser"`, `"caster"`, `"armored"` in turn,
**THEN** all three calls return `{ false, [] }`. Threshold computation: each archetype gets `n = 1`, `1 < 2` → `false` for every call. **AND WHEN** `resolve_floor_matchup(formation, ["bruiser", "caster", "armored"])` is called,
**THEN** returns `{ false, [] }` — the F3 generalist gets ZERO matchup-advantaged kills. (Compare to specialist W+W+M's 1-of-3 archetype coverage in H-05; this is the design intent of the majority rule.)

### H-16 — Injectable-Class Structure (Structural / CI, BLOCKING)

*(Pass 5C rewrite — was "Static Class Structure"; predicates updated for instance-method shape per Rule 1 DI conversion.)*

**GIVEN** the source files `src/gameplay/matchup/matchup_resolver.gd` and `src/gameplay/matchup/default_matchup_resolver.gd`,
**WHEN** statically analysed (test runs at CI time via grep + project autoload-list parse),
**THEN** all of the following hold:
- `matchup_resolver.gd` contains exactly one `class_name MatchupResolver` declaration and `extends RefCounted`.
- `matchup_resolver.gd` contains zero instance variables declared at class scope (no `var ` outside method bodies — Rule 2 statelessness preserved).
- `matchup_resolver.gd` contains zero `signal` declarations.
- All public methods (no `_` prefix) in `matchup_resolver.gd` are declared as regular `func` (**NOT `static func`** — Pass 5C instance-method shape). A test that greps `^static func [a-zA-Z]` inside the file matches zero lines except within comments.
- `default_matchup_resolver.gd` contains exactly one `class_name DefaultMatchupResolver` declaration and `extends MatchupResolver`.
- No entry exists for `MatchupResolver` or `DefaultMatchupResolver` in `project.godot`'s `[autoload]` section — both are RefCounted instances created + owned by other systems (the Orchestrator's autoload), not autoloads themselves.

Test implementation: a GdUnit4 test that reads each file as text and asserts the predicates via regex + ConfigFile parse of `project.godot`. If any predicate fails, the test fails with the specific predicate name in the message. This catches structural drift (instance var added by accident, signal added for "convenience", `static func` regression, autoload registered "just in case") that would silently violate Rule 1 / Rule 2.

**Pass 5C note on the `static func` predicate reversal**: H-16 pre-Pass-5C required "all public methods are declared `static`". Post-Pass-5C requires the inverse — public methods must NOT be `static`. This is intentional: the structural AC catches drift in whichever direction violates the current contract. The prior `static func` predicate is the regression check against accidental re-introduction of the static-only shape that blocked AC-ORC-11 mockability.

### H-17 — Per-Kill Replay Calls Neither Resolver Nor DataRegistry (Performance / Integration, ADVISORY)

**Note:** This AC is also covered as a sub-case of H-13 against the real Offline Engine. It exists separately here as a CI canary that runs against a stub Offline Engine + a mocked `DataRegistry`/`MatchupResolver` to catch resolver-side drift even before #12 ships.

**GIVEN** a stub Offline Engine that performs the per-kill replay loop using the snapshot pattern (`snapshot.matched_archetypes.has(enemy.archetype)`); a mocked `DataRegistry` and a **spy subclass of `MatchupResolver`** (Pass 5C DI — extend `MatchupResolver` directly; override the two public methods to count their `resolve_formation_matchup()` / `resolve_floor_matchup()` invocations and forward to the base implementation) — both injected into the Engine via the usual Pass 5C DI path,
**WHEN** the stub Offline Engine processes a 100-kill replay batch,
**THEN** mocked `DataRegistry.resolve` call count == 0 during the replay loop; mocked `MatchupResolver.*` call count == 0 during the replay loop. (Snapshot construction calls before the loop are exempt and not counted by the mock harness.)

This catches a future "convenience" refactor where someone re-introduces resolver calls inside the replay hot path "just to be safe" — which would silently destroy the Offline Engine performance budget without changing observable per-kill outcomes.

### Classification Summary

| ID | Description | Type | Gate |
|---|---|---|---|
| H-01 | Pure-counter stacking crosses threshold at all sizes | Logic | BLOCKING |
| H-02 | No-counter returns false | Logic | BLOCKING |
| H-03 | Empty-input guards (formation + floor_archetypes) | Logic | BLOCKING |
| H-04 | Unknown archetype returns false (V1.0-reserved + garbage + case-sensitivity) | Logic | BLOCKING |
| H-05 | Floor matchup aggregation, sorted, deduplicated | Logic | BLOCKING |
| H-06 | Caller-dedup defensive behavior | Logic | BLOCKING |
| H-07 | Determinism — field-equal results (with RefCounted assert_eq warning) | Logic | BLOCKING |
| H-08 | Per-kill independence on mixed floor | Logic | BLOCKING |
| H-09 | Alphabetical sort with non-trivial input | Logic | BLOCKING |
| H-10 | Null class_data skipped, excluded from threshold N | Logic | BLOCKING |
| H-11 | Empty/null enemy_archetype logs error (GdUnit4 API verified) | Logic | BLOCKING |
| H-12 | Cross-sys: Orchestrator → Economy pipeline (stubbed) | Integration | ADVISORY (real-system gate moves to GDD #13) |
| H-13 | Offline snapshot pattern isolation (stubbed) | Integration | ADVISORY (real-system gate moves to GDD #12) |
| H-14 | Resolver performance: CI canary + Steam Deck manual | Performance | ADVISORY |
| **H-15** | **Threshold-fail load-bearing test (generalist crosses zero thresholds)** | **Logic** | **BLOCKING** |
| **H-16** | **Static class structure (no instance vars, no signals, no autoload)** | **Structural** | **BLOCKING** |
| **H-17** | **Per-kill replay calls neither resolver nor DataRegistry (stubbed canary)** | **Performance/Integration** | **ADVISORY** |

Total: **17 ACs** — 13 BLOCKING + 4 ADVISORY (post-revision). BLOCKING set: H-01..H-11, H-15, H-16. ADVISORY set: H-12, H-13, H-14, H-17.

---

## I. Open Questions

### Resolved in 2026-04-19 revision

- ✅ **Economy GDD C.2.4 wording reconciliation** — Resolved: errata applied to `economy-system.md` C.2.4 + `matchup_multiplier` variable description in same session.
- ✅ **Hero Class DB C.6 caching language** — Resolved: errata applied (was `"caches the result for the run"`; now per-kill no-caching). E.5 + D.2 note also updated to majority-threshold language.
- ✅ **Section B fantasy reframed** — Resolved: per-hero attribution removed; collective formation framing adopted. Honest about data-flow capability. Remaining downstream dependency on Return-to-App Screen #20 wording (now collective, not per-hero) is below.
- ✅ **H-12 / H-13 disposition** — Resolved: demoted to ADVISORY here; re-validation ownership reassigned to Orchestrator GDD #13 and Offline Engine GDD #12 as BLOCKING ACs in those documents (to be added when authored).

### Still open

| Question | Owner | Target Resolution |
|---|---|---|
| **Majority threshold playtest validation** — Rule 6 was changed from boolean OR to majority on 2026-04-19 design-time reasoning. The playtest evidence triggers in Section G.2 will determine whether the threshold stays, softens, tightens, or moves to a different aggregation entirely. Specifically watch: matchup-screen interaction rate by Day 2; specialist vs generalist roster spread by end of Week 1; `MATCHUP_GOLD_MULTIPLIER` recalibration target value. | game-designer + economy-designer | First MVP playtest (target: 1 week post-vertical-slice) |
| **MATCHUP_GOLD_MULTIPLIER recalibration** — The hit-rate of matchup-advantaged kills under majority is meaningfully lower than under boolean OR (specialists get ~2/5 on F3 instead of all-counter formations getting all 5). Economy's Day 3-4 Tier-2 milestone (8,000g) was calibrated against the prior model and may now under-deliver. Recalibrate `MATCHUP_GOLD_MULTIPLIER` (currently 1.5, safe range 1.0–2.5) once playtest data lands. | economy-designer | After first MVP playtest |
| **Combined MATCHUP × DRIP ceiling** — Economy G has independent safe ranges for `MATCHUP_GOLD_MULTIPLIER` (1.0–2.5) and `MATCHUP_DRIP_BONUS` (1.0–1.3), but no joint constraint. If both are tuned high, the matchup-advantaged formation earns multiplicatively more on both faucets. Define a joint ceiling in Economy G or document "do not push both simultaneously." | economy-designer | During Economy tuning pass |
| **Floor-composition guarantee for archetype variety** — Pillar 2 (class distinctness) only works if every MVP archetype appears with sufficient frequency on dungeon floors that each counter class feels relevant. No floor-composition spec currently guarantees this. If F3-F5 all over-index on bruiser, the Mage and Rogue identities are economically invisible. | game-designer + Biome/Dungeon DB owner | During Biome & Dungeon DB next revision |
| **Matchup Assignment Screen affordance discovery** — game-designer recommends low-handholding (enemy archetype tags + class icons; trust the player to learn over 1-2 runs). Risk: the idle nature means a player who misses the affordance accumulates neutral-multiplier offline hours with no feedback. Define a recovery affordance plan if first playtest shows discovery rate <50%. | ux-designer + game-designer | First MVP playtest |
| **Return-to-App / Offline Rewards Screen line item** — Revised Section B requires Screen #20 to display "your formation's matchup advantage banked an extra Xg from [archetype] kills" as a distinctly-named line item. NOT per-hero (that data does not flow). Confirm during #20 authoring. | ux-designer + game-designer | During Return-to-App Screen GDD #20 |
| **Enemy DB schema validation for unknown archetypes** — Rule 13 + H-04 establish that unknown archetypes return `false` silently; H-16 distinguishes typo from V1.0-reserved at the Enemy DB load layer. The Enemy DB GDD does not currently specify this load-time validation. Add a BLOCKING AC to Enemy DB requiring `archetype` field to validate against the `EnemyArchetypes` constant set on `.tres` load. | systems-designer + Enemy DB owner | During Enemy DB next revision |
| **GdUnit4 push_error substring assertion API verification** — H-11's substring assertion against `push_error` output requires GdUnit4's `assert_error_logged()` (or equivalent) to support substring matching in Godot 4.6. Pre-sprint validation step. If unsupported, fall back to test-only `_test_invalid_archetype` signal (documented as Rule 2 exception). | qa-lead | Before resolver implementation sprint |
| **Enemy DB `future_counter` field for V1.0 anticipation** — Recommended (not required) addition to `EnemyData` schema so V1.0 archetype enemies appearing in MVP enemy data can render a "your guild hasn't mastered this foe's kind yet" tooltip. Cost: one field + one UI string. | game-designer + Enemy DB owner | During Enemy DB next revision or V1.0 scoping |
| **Patch-time matchup rule change policy** — E.10 documents that offline replay preserves pre-patch values. If V1.5+ rebalances counter taxonomy, what is the player-facing policy: silent (current default), retroactive recalculation (Save/Load migration), or notice-and-grant (compensation gold)? Live-ops question. | live-ops-designer + economy-designer | Post-launch |
| **`MatchupResult` registration in entities.yaml** — systems-designer noted the struct crosses 4 system boundaries. Worth adding to the registry as a struct/type entry so future GDD authors reference canonical field names. Currently no `types` section exists in `entities.yaml`. | systems-designer | During next `/consistency-check` or registry expansion |
| **Thread-safety re-evaluation if Offline Engine moves to WorkerThreadPool** — E.11 dismisses thread safety because GDScript is single-threaded. If a future sprint moves the Offline Engine batch replay to `WorkerThreadPool`, the resolver would be called off the main thread. Statelessness still protects concurrent reads, but any future caching layer would require a mutex. Re-evaluate when/if WorkerThreadPool migration is proposed. | technical-director | If/when Offline Engine migrates to WorkerThreadPool |
