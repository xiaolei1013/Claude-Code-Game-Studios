# Hero Roster GDD — Lantern Guild

> **GDD #9 in design order** (System #9 in systems index)
> **Status**: In Design + **Pass 5F-propagation applied 2026-04-21 — Save/Load consumer + element-layer method-name canonicalization** + **Pass-ADR-0014-SYNC applied 2026-04-22 — ADR-0012's `caching_heroinstance_reference_across_save_boundary` forbidden pattern gains an ADR-0014 allowlist exception for DungeonRunOrchestrator `_run_snapshot.formation` post-hydrate (lifetime-scoped to one replay + run-resume cycle; 3 allowlisted consumer call sites: CombatResolver.compute_offline_batch + emit_events_in_range + MatchupResolver.resolve). §F cross-system contracts row: HeroInstance identity remains authoritative; the allowlist is a precisely-scoped carve-out with 3 CI grep invariants, not a weakening of the invariant.**
> **Created**: 2026-04-19
> **Last Updated**: 2026-04-21 (Pass 5F-propagation 2026-04-21 — per Save/Load GDD #3 Rule 11 + §F consumer discovery contract, two distinct canonical target pairs applied: **consumer-layer** `HeroRoster.save_to_dict / load_from_dict` → `HeroRoster.get_save_data / load_save_data` (22 hits); **element-layer** `HeroInstance.save_to_dict / load_from_dict` → `HeroInstance.to_dict / from_dict` (Rule 4, 2 hits). Classification per hit was required — blanket find-replace would have corrupted the element-layer references. AC-SL-01 integration test in Save/Load GDD depends on this canonicalization; per-hero shape under Rule 4 remains the same five-field dictionary. Original 2026-04-19 design.)
> **Authors**: systems-designer + game-designer + qa-lead + main session
> **Depends on**: `design/gdd/hero-class-database.md` (#5), `design/gdd/save-load-system.md` (#3)
> **Referenced by**: Combat Resolution (#11), Recruitment System (#14), Hero Leveling System (#15), Formation Assignment System (#17), Dungeon Run Orchestrator (#13), Economy System (#5 — provisional `get_formation_strength()` consumer)
> **Implements Pillar**: Pillar 2 (Every Class Feels Distinct — owns the player's hand-curated roster)
> **Creative Director Review (CD-GDD-ALIGN)**: SKIPPED — Solo review mode

---

## A. Overview

The Hero Roster is the player-state container for every hero the player owns in *Lantern Guild*. Where the Hero Class Database (#6) defines the *templates* — Warrior, Mage, Rogue stat blocks and their per-level scaling — the Roster owns the *instances*: this specific Warrior, currently Level 7, named *Theron*, recruited on Day 2. It is the canonical answer to "what heroes does this save own?" and the input every downstream Feature-layer system reads to compute live stats, count copies for recruit cost escalation, populate the Roster screen, and hydrate formations.

Mechanically, the Roster is a typed dictionary of `HeroInstance` records persisted via the Save/Load `get_save_data` / `load_save_data` contract. Each record carries a `class_id` reference (resolved through `DataRegistry`), a `current_level`, a generated personal `display_name`, and an immutable `instance_id` that lets formations and UI selections reference a specific hero across sessions even when the player owns multiple copies of the same class. (An `xp` field is reserved on the schema for V1.0 progression but is always `0` and never displayed in MVP — heroes level by spending gold, not by gaining XP.) Mutations are funnelled through three signals — `hero_recruited`, `hero_leveled`, `hero_removed` — so the HUD, recruit screen, and economy can react without polling.

Emotionally, the Roster is the player's guild. The escalation loop the game promises ("recruit → idle → return → escalate") only lands because the Roster persists every decision the player has made: which classes they invested in, how many copies they stacked, which hero they chose to push toward the level cap. The Roster is therefore Pillar 2's load-bearing system: every "every class feels distinct" moment lives or dies at the Roster screen, and every "I made this guild" feeling is the Roster's output rendered to the player.

---

## B. Player Fantasy

The Hero Roster has both a direct and an indirect player fantasy, anchored on the survey moment: opening the Roster screen and seeing your whole guild at once.

The direct fantasy is **reverent curation**. By Day 4, the Roster screen is no longer a list — it is the wall on which the player has hung every hero they chose to keep. The starter Warrior at Level 8 (recruited in the tutorial, the one who has been everywhere). The Mage they almost didn't level past 4 but kept around because the Glowmoth fights felt different with her. The Rogue they recruited last night who is still Level 1 and hasn't done anything yet but already has a place. Each hero is a remembered decision, and the Roster is the cumulative shape of those decisions. The screen is meant to be opened and lingered on — not as a menu chore, but as the cozy fantasy's emotional home base. Tone target: warm, a little proud, never grandiose. Language: "your guild," "every hero remembered," never "units" or "characters."

The indirect fantasy is **the guild persisting while you are away**. The Roster's job during a session is to be the lineup the dungeon receives; its job between sessions is to *still be there, exactly as you left it*, when you reopen the app. Save/Load is the technical guarantor of that promise; the Roster is the player-visible shape of it. When the Return-to-App screen says "Your guild earned 12,000 gold while you were away," the "your guild" means the Roster — specifically, the formation you assigned before closing.

Soul of the system: ***"This is the wall where you hang every hero you chose to keep."***

Pillar alignment: This system primarily serves **Pillar 2 (Every Class Feels Distinct)** by making class identity *owned* — abstract Warrior/Mage/Rogue templates from the Class DB become *this Warrior, this Mage, this Rogue* with histories and levels the player remembers. It serves **Pillar 1 (Respect the Player's Time)** indirectly, because losing a roster entry to a bug or save corruption is the maximum violation of the cozy promise.

---

## C. Detailed Design

### C.1 Core Rules

#### HeroInstance Schema

**Rule 1.** Every owned hero is a `HeroInstance` (`class_name HeroInstance extends RefCounted`). `HeroInstance` is a lightweight data record, not a Godot `Resource`. It is never saved as a `.tres` file — all persistence goes through Save/Load's `get_save_data()` / `load_save_data()` contract (GDD #3).

**Rule 2.** Canonical field set:

| Field | Type | Mutability | Initial value | Description |
|---|---|---|---|---|
| `instance_id` | `int` | Immutable after creation | Assigned by `HeroRoster._next_instance_id` at `add_hero()` | Stable cross-session identity. Never changes; never reused. `0` is reserved as the "no hero" sentinel for formation slot arrays. |
| `class_id` | `String` | Immutable after creation | Provided at recruitment | Snake_case class identifier (e.g., `"warrior"`). Must resolve via `DataRegistry.resolve("classes", id)`. A hero cannot change class — to "change class," remove and re-recruit. |
| `display_name` | `String` | Immutable after creation | Pulled from per-class name pool at recruit | Generated personal name (e.g., `"Theron"`). Combined with class display name in UI as `"Theron the Warrior"`. Stored verbatim — does not localize per-language in MVP (see Open Questions). |
| `current_level` | `int` | Mutable via `set_hero_level()` only | `1` | Range `[1, LEVEL_CAP=15]`. Clamped on any mutation that would exceed range. |
| `xp` | `int` | Reserved — always `0` in MVP | `0` | Forward declaration for V1.0 XP accumulation. The Hero Leveling System (#15) ignores this field in MVP; it is persisted only to prevent a save-format migration when V1.0 activates it. **Never displayed to the player in MVP.** |

**Rule 3.** `HeroInstance` exposes no mutation methods on itself. It is a pure data record. All mutation routes through `HeroRoster` methods (Rule 11).

**Rule 4.** `HeroInstance.to_dict()` produces exactly (**Pass-5F-propagation 2026-04-21**: element-layer method names canonicalized to `to_dict / from_dict` per Save/Load GDD #3 Rule 11 — element-layer is distinct from the consumer-layer `get_save_data / load_save_data` used by the HeroRoster consumer itself):
```
{ "instance_id": int, "class_id": String, "display_name": String, "current_level": int, "xp": int }
```
`HeroInstance.from_dict(data)` restores exactly these five fields. No other data is saved per hero — class template data (stats, art paths, flavor text) is re-resolved from `DataRegistry` on load. (Distinct from `HeroRoster.load_save_data()` which is the consumer-level method that iterates per-hero-dict entries through `HeroInstance.from_dict`.)

#### Per-Class Name Pool

**Rule 5.** Each class declares a per-class name pool — a flat `Array[String]` of 20–30 personal names. Pools live in `assets/data/classes/{class_id}/names.tres` (a `Resource` subclass loaded by Data Loading System). At recruit time, `add_hero(class_id)` selects a name uniformly at random from the pool, **excluding any name already in use by another `HeroInstance` of the same class on this save**. If all pool entries are taken (player owns N copies and pool size = N), fall back to `"<base_name> the [Nth]"` (e.g., `"Theron the Second"`) — see Edge Case E.6. Names are immutable after assignment; the player cannot rename a hero in MVP.

**Rule 6.** MVP pool sizes: ≥20 names per class (Warrior, Mage, Rogue). At `MAX_ROSTER_SIZE = 30`, even worst-case stacking (all 30 of one class) exhausts the pool only if pool < 30 — handled by the fallback in Rule 5. Recommended: ship with 25–30 per class to keep fallback rare.

#### HeroRoster as a Typed Collection

**Rule 7.** `HeroRoster` (`class_name HeroRoster extends Node`) stores heroes in `_heroes: Dictionary` keyed by `instance_id: int → HeroInstance`. Dictionary chosen over `Array` for: O(1) lookup by `instance_id`; no index-shifting on removal; key matches the persisted identity.

**Rule 8.** Hard cap: `MAX_ROSTER_SIZE = 30`, defined in `roster_config.tres`. Rationale is dual: (a) **screen-layout** — the Roster Screen renders all heroes in a single-page 5×6 grid at 1280×800 minimum spec, preserving the "survey the whole guild" fantasy from Section B; (b) **downstream sanity** — gives Save/Load JSON growth, offline-replay performance, and Formation Assignment UI a hard upper bound. The Recruitment System checks `roster.is_at_cap() -> bool` before calling `add_hero()`. `add_hero()` also enforces the cap and returns `null` if at cap (no signal emitted; UI greys out the button).

**Rule 9.** Per-class copy count is a derived value, not stored: `get_copies_owned(class_id) -> int` iterates `_heroes.values()` and counts entries with matching `class_id`. With cap = 30, this O(N) scan is bounded at 30 entries — not a perf concern.

**Rule 10.** The active formation is stored as `_formation_slots: Array` of size `FORMATION_SIZE = 3`. Each element is either an `instance_id: int` referencing a hero in `_heroes`, or `0` (empty slot). Formation slot writes go through `set_formation_slot()` (Formation Assignment System #17 is the only writer). Formation state is co-located with hero state inside Roster so `get_formation_strength()` (the Economy contract) can compute without cross-system reads.

#### Mutation API

**Rule 11.** Complete mutation API:

| Method | Sole Caller | Preconditions | Emits | Returns |
|---|---|---|---|---|
| `add_hero(class_id: String) -> HeroInstance \| null` | Recruitment System (#14) | `DataRegistry.resolve("classes", class_id) != null`; `_heroes.size() < MAX_ROSTER_SIZE` | `hero_recruited(instance: HeroInstance)` on success | New `HeroInstance` on success; `null` on cap reached or unresolvable class |
| `remove_hero(instance_id: int) -> bool` | Save/Load fallback only (Rule 16) | `instance_id` exists in `_heroes` | `hero_removed(instance_id, class_id, display_name)` on success — **suppressed during boot validation** | `true` on success; `false` if id not found |
| `set_hero_level(instance_id: int, new_level: int) -> bool` | Hero Leveling System (#15) | `instance_id` exists; `new_level` clamped to `[1, LEVEL_CAP]` | `hero_leveled(instance_id, old_level, new_level)` on success | `true` on success; `false` if id not found |
| `set_formation_slot(slot_index: int, instance_id: int) -> bool` | Formation Assignment System (#17) | `0 <= slot_index < FORMATION_SIZE`; `instance_id` is `0` or exists in `_heroes`; if non-zero and same id is in another slot, the other slot is cleared | None (Formation Assignment owns its own signals) | `true` on success; `false` on invalid args |

**Encapsulation contract**: `_heroes`, `_formation_slots`, and `_next_instance_id` are underscore-prefixed and treated as private by convention. No code outside `HeroRoster` reads or writes them directly. Enforced at code review (godot-gdscript-specialist), not at the language level.

**Rule 12.** `add_hero()` internally: assigns `instance_id = _next_instance_id`; selects a name from the per-class name pool (Rule 5); creates a `HeroInstance` with `current_level = 1`, `xp = 0`; inserts `_heroes[new_id] = instance`; increments `_next_instance_id`. The increment happens *after* successful insertion — failed `add_hero()` calls do not consume an id.

#### Identity Contract

**Rule 13.** `instance_id` is a monotonic positive integer (no UUIDs). `_next_instance_id` is initialized to `1` on a fresh save and persisted in `get_save_data()`. It is only ever incremented, never decremented — even after a `remove_hero()`. This guarantees uniqueness across the entire lifetime of a save.

**Rule 14.** `instance_id`, `class_id`, and `display_name` are set once at `add_hero()` time and never change thereafter. This is the immutability contract that downstream systems (formation slots, UI selections, save references) rely on.

#### Read API

**Rule 15.** Complete read API:

| Method | Returns | Primary callers |
|---|---|---|
| `get_hero(instance_id: int) -> HeroInstance \| null` | Single-hero lookup; `null` if not found | Combat Resolution (#11), Formation Assignment (#17), Hero Leveling (#15) |
| `get_all_heroes() -> Array[HeroInstance]` | All owned heroes (default sort: by `class_id` in declared registry order, then by `current_level` descending) | Roster Screen (#22) |
| `get_formation_heroes() -> Array[HeroInstance]` | Heroes in active formation slots (skips empty slots; order by slot index) | Dungeon Run Orchestrator (#13), Combat Resolution (#11), Matchup Resolver (#10) |
| `get_copies_owned(class_id: String) -> int` | Count of heroes with matching `class_id` | Recruitment System (#14) |
| `get_hero_count() -> int` | Total owned heroes (`_heroes.size()`) | Recruit button affordance |
| `is_at_cap() -> bool` | `_heroes.size() >= MAX_ROSTER_SIZE` | Recruitment System pre-check |
| `get_formation_strength() -> float` | Economy input — see Section D.1 | Economy System (#5) |
| `get_formation_slot(slot_index: int) -> int` | Raw slot value (`0` = empty) | Formation Assignment Screen (#23) |
| `has_hero(instance_id: int) -> bool` | True if id is in `_heroes` | Formation Assignment validation, Save/Load load-time validation |
| `get_save_data() -> Dictionary` | Full serialization | Save/Load (#3) |
| `load_save_data(data: Dictionary) -> void` | Restore from deserialized dict | Save/Load (#3) |

**Default sort for `get_all_heroes()`**: by `class_id` (Warrior → Mage → Rogue → V1.0 classes in declared registry order), then by `current_level` descending within class. Reinforces Pillar 2 — the player sees their guild grouped by archetype, with most-invested heroes first per archetype. Player-customizable sort is a V1.0 feature; not in MVP.

#### Validation and Invariants

**Rule 16.** `load_save_data()` runs boot validation in this order:
1. For each restored `HeroInstance`: call `DataRegistry.resolve("classes", hero.class_id)`. If null, drop the hero from `_heroes` silently (no `hero_removed` signal — UI does not exist yet during load) and append the hero's `display_name + class_id` to a session-scoped `_orphaned_heroes` list. The Save/Load System reads this list after `load_save_data()` returns and surfaces a single non-blocking notice to the player: `"Theron the Warrior was removed from your guild — the Warrior class is no longer available."` This implements the Save/Load GDD #3 fallback table contract.
2. For each formation slot: if `_formation_slots[i]` is non-zero and `not has_hero(_formation_slots[i])`, set `_formation_slots[i] = 0`. Log `push_warning`.
3. Trim if over cap: if `_heroes.size() > MAX_ROSTER_SIZE` (e.g., a save from a build with a higher cap was loaded into a build with a lower cap), remove the highest-instance_id heroes (preserving the oldest = lowest-id heroes) until at cap. Log a warning per removed hero.
4. Repair `_next_instance_id`: if `_next_instance_id <= max(existing instance_ids)`, set it to `max(existing) + 1`.

**Rule 17.** Per-mutation invariants enforced inside each mutation method (callers do not need to pre-check):
- `add_hero()`: checks resolvability and cap; returns `null` without error log on cap; logs `push_error` only on unresolvable class_id.
- `set_hero_level()`: clamps `new_level` to `[1, LEVEL_CAP]` with a `push_warning` on out-of-range. Returns `false` only if `instance_id` is unknown.
- `set_formation_slot()`: ensures the same `instance_id` is not in two slots simultaneously (auto-clears the prior slot if found).

#### First-Launch Initialization

**Rule 18.** On a fresh save (Save/Load reports `first_launch = true`), the Roster's `seed_first_launch_state()` initializer runs once:
1. Calls `add_hero("warrior")` → `_next_instance_id = 1` → creates the tutorial Warrior with `display_name = "Theron"` (deterministic — first-launch must be reproducible across reinstalls for QA; does not draw from the random pool).
2. Calls `set_formation_slot(0, 1)` → places the tutorial Warrior in formation slot 1.

The tutorial Warrior is hardcoded as constants in the seed-state path (`SEED_HERO_CLASS_ID = "warrior"`, `SEED_HERO_NAME = "Theron"`). Onboarding GDD (#29) builds the tutorial flow on top of this state — Roster guarantees the formation has one hero ready for the first idle tick. This locks the cross-system contract: Onboarding does not need to inject heroes into Roster; Roster ships its own seed state.

---

### C.2 States and Transitions

#### Per-Instance State

**Rule 19.** `HeroInstance` has no explicit state enum. `current_level` is an integer in `[1, LEVEL_CAP]`. Three implicit conditions any consumer can derive:
- `current_level == 1`: newly recruited.
- `1 < current_level < LEVEL_CAP`: actively leveling.
- `current_level == LEVEL_CAP (15)`: max level. Hero Leveling System (#15) checks this and disables the level-up button.

A state enum is intentionally omitted — it would just duplicate `current_level` value checks and add a string mapping to the save dict.

#### Roster-Level States

**Rule 20.** Three observable roster states, derived (not persisted):

| State | Condition | Meaning |
|---|---|---|
| `EMPTY` | `_heroes.size() == 0` | Valid only as a transient state after a catastrophic save fallback (all classes deleted from data). First-launch seeds the tutorial Warrior immediately, so the player never sees EMPTY in normal play. Dungeon dispatch is unavailable; HUD shows a "your guild is empty" notice. |
| `POPULATED` | `0 < _heroes.size() < MAX_ROSTER_SIZE` | Normal play state. Recruit active; formation assignable; dispatch possible if at least one slot is filled. |
| `AT_CAP` | `_heroes.size() >= MAX_ROSTER_SIZE` (= 30) | Roster full. Recruit buttons greyed out across all classes (the Recruit Screen does not display a price for unavailable purchases). |

State is re-derived on every read; no `get_state()` accessor is exposed. Consumers use `get_hero_count()` and `is_at_cap()` directly.

**Transition triggers:**

| From | To | Trigger | Notes |
|---|---|---|---|
| (uninitialized) | `POPULATED` | First-launch seed (Rule 18) places tutorial Warrior | One `hero_recruited` fires. |
| (uninitialized) | (any) | `load_save_data()` restores from existing save | All signals suppressed during load. State derived from restored `_heroes.size()`. |
| `POPULATED` | `AT_CAP` | `add_hero()` succeeds, taking size to MAX_ROSTER_SIZE | `hero_recruited` fires for the completing hero. Recruit button disables on next UI refresh. |
| `AT_CAP` | `POPULATED` | `remove_hero()` drops size below cap | Only triggered by Save/Load boot fallback in MVP (no player-initiated removal). |
| `POPULATED` | `EMPTY` | All heroes removed by Save/Load fallback (catastrophic class deletion patch) | `hero_removed` signals suppressed during boot validation; Save/Load surfaces a single player-facing notice listing affected heroes. |
| `EMPTY` | `POPULATED` | First successful `add_hero()` after empty state | One `hero_recruited` fires. |

---

### C.3 Interactions with Other Systems

| System | Direction | Reads | Writes | Exact Signatures |
|---|---|---|---|---|
| **Save/Load (#3)** | Bidirectional | Hero data during `load_save_data()` | Hero data via `get_save_data()` | `roster.get_save_data() -> Dictionary`; `roster.load_save_data(data: Dictionary) -> void`. Save dict shape: `{ "heroes": Array[Dict], "formation_slots": Array[int], "next_instance_id": int }`. Per-hero shape per Rule 4. |
| **Data Loading (#2)** | Roster reads | `DataRegistry.resolve("classes", id)` per hero on load + on `add_hero()` precondition; per-class name pool resource via `DataRegistry.resolve("name_pools", class_id)` at recruit | Nothing | Standard registry resolve contract. |
| **Economy (#5)** | Economy reads | `roster.get_formation_strength() -> float` | Nothing | Called per tick (foreground) and once at offline-replay start (Economy reads it inside `compute_offline_batch` snapshot, not per replayed tick — per Economy GDD C.6 replay contract). Returns `1.0` for empty formation. Locked range: `[1.0, 3.0]`. |
| **Recruitment System (#14)** | Recruitment writes | `is_at_cap()`, `get_copies_owned(class_id)` before spend | `add_hero(class_id)` after `economy.try_spend()` succeeds | Pre-check sequence: (1) `is_at_cap()` returns false; (2) `DataRegistry.resolve(class_id) != null`; (3) `economy.try_spend(recruit_cost(tier, get_copies_owned(class_id)))` returns true; (4) `add_hero(class_id)` returns the new instance. If step 4 returns `null`, gold has been spent — Recruitment must guarantee preconditions before step 3. |
| **Hero Leveling System (#15)** | Leveling writes | `get_hero(id)` for `current_level` + class.tier lookup | `set_hero_level(id, current_level + 1)` after spend | Sequence: (1) read `hero.current_level`; (2) if `hero.current_level < LEVEL_CAP`, compute `level_cost(class.tier, hero.current_level)` via Economy; (3) `economy.try_spend(cost)`; (4) `set_hero_level(id, hero.current_level + 1)`. Leveling System holds the LEVEL_CAP check; Roster's `set_hero_level` clamps as a safety net. |
| **Formation Assignment (#17)** | Formation Assignment writes | `get_all_heroes()`, `has_hero(id)`, `get_formation_slot(i)` | `set_formation_slot(slot_index, instance_id)` | Roster owns the formation state (the array); Formation Assignment owns the assignment rules + UI. Roster validates the id before accepting the slot write. |
| **Combat Resolution (#11)** | Roster read-only | `get_formation_heroes()`; per hero, `DataRegistry.resolve("classes", hero.class_id)` and `stat_at_level(stat, class_data, hero.current_level)` (Class DB GDD #5 D.1) | Nothing | Combat does not call any stat method on Roster directly — stats are computed via the Class DB formula. |
| **Dungeon Run Orchestrator (#13)** | Roster read-only | `get_formation_heroes()` once at run start; per hero, `hero_tick_output(class_data, hero.current_level)` (Class DB GDD #5 D.3) | Nothing | Sums per-hero tick output to `formation_base_output`. Holds the formation snapshot for the whole run / offline batch — does not re-walk Roster per tick (per Economy GDD C.6 replay contract). |
| **Roster / Hero Detail Screen (#22)** | Screen read-only | `get_all_heroes()`, `get_hero(id)` | Nothing | Subscribes to `hero_recruited`, `hero_leveled`, `hero_removed` for live refresh. Default display order = read API default sort. Displays `display_name + class.display_name + current_level`; Hero Detail tap opens full stat block computed via Class DB. |
| **Recruit Screen (#21)** | Screen read-only | `get_copies_owned(class_id)`, `is_at_cap()` | Nothing | Greys out all recruit buttons when `is_at_cap()`. Per-class cost shown via Economy `recruit_cost(tier, copies_owned)`. |

#### Signals Emitted by HeroRoster

| Signal | Payload | When |
|---|---|---|
| `hero_recruited` | `(instance: HeroInstance)` | After `add_hero()` succeeds (excludes boot validation) |
| `hero_leveled` | `(instance_id: int, old_level: int, new_level: int)` | After `set_hero_level()` mutates the level (no signal on no-op) |
| `hero_removed` | `(instance_id: int, class_id: String, display_name: String)` | After `remove_hero()` succeeds — **suppressed during `load_save_data()` boot validation**, surfaced via the Save/Load orphaned-heroes notice instead |

---

## D. Formulas

### D.1 Formation Strength Factor (Economy Contract)

The formation_strength_factor formula is the Economy System's input from Roster. It is named, registered, and computed inside `HeroRoster.get_formation_strength()`.

```
formation_strength_factor = clamp(1.0 + (avg_formation_level - 1) * 0.2, 1.0, 3.0)
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| avg formation level | `avg_formation_level` | float | [1.0, 15.0] | Arithmetic mean of `current_level` for all heroes in active formation slots. See D.2. |
| level multiplier coefficient | implicit `0.2` | float | constant | Per-level contribution to the factor. Locked by Economy GDD #5 D.1 — do not alter without Economy GDD revision. |
| level cap | `LEVEL_CAP` | int | constant 15 | Maximum hero level. Sourced from registry constant `LEVEL_CAP` (owned by Economy GDD #5). |
| factor floor | implicit `1.0` | float | constant | Lower clamp bound. Empty formation also returns 1.0 (no boost, no penalty). |
| factor ceiling | implicit `3.0` | float | constant | Upper clamp bound. Reached at `avg_formation_level == 11`; heroes leveled above 11 contribute to combat stats and tick output but not to drip rate multiplication. |
| **output** | `formation_strength_factor` | float | [1.0, 3.0] | Multiplier applied to `BASE_DRIP[floor_tier]` in Economy's `drip_per_tick` formula. |

**Output Range**: `[1.0, 3.0]`. Lower bound is structural (clamp + empty-formation guard). Upper bound is reached when average formation level is 11 or higher.

**Empty-formation guard (precedes the formula)**: if `get_formation_heroes().size() == 0`, return `1.0` directly without computing `avg_formation_level` (avoids divide-by-zero and matches the design intent that an unassigned formation neither boosts nor penalizes drip — the Economy formula multiplies BASE_DRIP × 1.0, leaving it at the floor's baseline).

**Worked examples:**

*Example A — Tutorial formation (1 hero at L1):*
```
avg_formation_level = 1.0
factor = clamp(1.0 + (1.0 - 1) * 0.2, 1.0, 3.0) = clamp(1.0, 1.0, 3.0) = 1.0
```

*Example B — Mid-game (3 heroes, all L5):*
```
avg_formation_level = 5.0
factor = clamp(1.0 + (5.0 - 1) * 0.2, 1.0, 3.0) = clamp(1.8, 1.0, 3.0) = 1.8
```
Effect on Economy: at floor 3 (`BASE_DRIP[3] = 7`), `drip_per_tick = floor(7 × 1.8 × 1.0) = 12 gold/tick`.

*Example C — Late-game mixed levels (L10/L12/L15, avg 12.33):*
```
avg_formation_level = (10 + 12 + 15) / 3 = 12.33
factor = clamp(1.0 + (12.33 - 1) * 0.2, 1.0, 3.0) = clamp(3.27, 1.0, 3.0) = 3.0
```
Clamp activates — late-game formations cap out at the ceiling factor. The remaining levels contribute to Combat Resolution (attack/HP/speed) and Dungeon Run Orchestrator tick output, not to drip multiplication.

*Example D — Empty formation:*
```
get_formation_heroes() returns []
formation_strength_factor = 1.0 (guard clause; no division)
```

*Example E — Single max-level hero (1 hero at L15):*
```
avg_formation_level = 15.0
factor = clamp(1.0 + (15.0 - 1) * 0.2, 1.0, 3.0) = clamp(3.8, 1.0, 3.0) = 3.0
```
A single max-level hero hits the ceiling. This is intentional — a player who maxes one hero before recruiting more should still feel rewarded; the formation does not need to be full to reach max factor.

---

### D.2 Average Formation Level (Helper)

Internal helper used inside `get_formation_strength()`. Not exposed publicly.

```
avg_formation_level = sum(hero.current_level for hero in formation) / size(formation)
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| formation hero count | `size(formation)` | int | [0, FORMATION_SIZE=3] | Result of `get_formation_heroes().size()` (skips empty slots). |
| per-hero level | `hero.current_level` | int | [1, LEVEL_CAP=15] | Each formation hero's level. |
| **output** | `avg_formation_level` | float | [1.0, 15.0] | Arithmetic mean. |

**Output Range**: `[1.0, 15.0]`. Undefined when `size(formation) == 0` — the empty-formation guard in D.1 prevents this branch from executing.

**Implementation note**: GDScript `int / int` produces an `int`; cast at least one operand to `float` to preserve the fractional component (e.g., `float(sum) / size(formation)`).

**Worked example — 2 heroes at L7 + L8:**
```
sum = 7 + 8 = 15
size = 2
avg = float(15) / 2 = 7.5
```

---

### D.3 Name Pool Selection (Combinatorial)

When `add_hero(class_id)` is called, the name selection is uniform-random over the *unused* subset of the pool.

```
available_names = pool.filter(name -> not in_use_for_class(name, class_id))
selected_name = available_names[randi() % size(available_names)]   # if non-empty
fallback_name = base_name + " the " + ordinal(N)                   # if pool exhausted
```

**Variables:**

| Variable | Type | Description |
|---|---|---|
| `pool` | Array[String] | The full per-class name pool from `assets/data/classes/{class_id}/names.tres`. Size: ≥20 in MVP. |
| `in_use_for_class(name, class_id)` | bool | True if any existing `HeroInstance` has `class_id == class_id AND display_name == name`. O(N) scan over `_heroes`, bounded at MAX_ROSTER_SIZE = 30. |
| `available_names` | Array[String] | Pool minus already-used names for this class. |
| `N` | int | The (copies_owned + 1)th copy of this class — used in fallback. |
| `ordinal(N)` | String | "Second", "Third", "Fourth", … (numeric word, not digit, for cozy register). |
| **output** | `selected_name` | The name written to `HeroInstance.display_name`. Immutable after assignment. |

**Output Range**: A non-empty string. Fallback ensures no run-time failure even when pool is fully consumed.

**Determinism note**: Name selection uses GDScript's default `randi()` (seeded by engine wall-clock at boot). It is **not** reproducible across sessions — recruiting the same class twice in two different sessions produces different names. The first-launch tutorial Warrior bypasses the pool entirely and uses the deterministic constant `SEED_HERO_NAME = "Theron"` (Rule 18) so QA can verify reproducible cold-launch state.

**Worked examples:**

*Example A — First Warrior recruit, pool [Theron, Aldric, Gorin, …]:*
```
available_names = entire pool (no copies owned)
selected = uniform random pick from pool
```

*Example B — 5th Warrior recruit, pool size 25, 4 names already in use:*
```
available_names = 21 names (pool minus 4 in use)
selected = uniform random pick from 21 available
```

*Example C — 26th Warrior recruit (pool size 25):*
```
available_names = [] (all 25 pool entries consumed)
N = 26
selected = "Theron the Twenty-Sixth"   // fallback
```
This case is rare — only triggered if a player stacks the same class beyond the pool size. Edge case detail in Section E.6.

---

## E. Edge Cases

### E.1 First-Launch With Empty Save (No Save File)

**Scenario**: Player launches the game for the first time. No save file exists.

**Behavior**: Save/Load reports `first_launch = true`. Roster's `seed_first_launch_state()` runs (Rule 18): creates one Warrior with `instance_id = 1`, `display_name = "Theron"`, `current_level = 1`, `xp = 0`; assigns to formation slot 0. `_next_instance_id` becomes 2. The Roster is now in `POPULATED` state with one hero in formation. Onboarding GDD #29 takes over from here. The player never sees an EMPTY roster on a fresh game.

### E.2 Save Loaded With Roster At Cap From a Build With Higher MAX_ROSTER_SIZE

**Scenario**: A patch reduces `MAX_ROSTER_SIZE` from 30 to (hypothetically) 25. A player's existing save has 28 owned heroes.

**Behavior**: `load_save_data()` boot validation Rule 16 step 3 detects `_heroes.size() > MAX_ROSTER_SIZE`. Removes the highest-instance_id heroes (newest, by Rule 13's monotonic id contract — newest = highest id) until at cap, in this case removing 3 heroes. Per removed hero, appends entry to `_orphaned_heroes` with reason "roster cap reduced." Save/Load surfaces a single notice listing the affected heroes by display_name. The player loses their three newest recruits — preserving the oldest preserves earliest-invested heroes (likely most-leveled). Cap reduction is a balance-team-only patch; never done casually.

### E.3 Catastrophic Class Removal: All Heroes Orphaned

**Scenario**: A patch removes the Warrior class from `assets/data/classes/`. A player's roster is 100% Warriors.

**Behavior**: `load_save_data()` boot validation Rule 16 step 1 fails to resolve `class_id == "warrior"` for every hero. Every hero is dropped from `_heroes`. Roster ends in `EMPTY` state. Formation slots all clear (step 2). Save/Load surfaces a player notice listing every removed hero. The player can recruit fresh heroes from the remaining classes; the tutorial Warrior re-seed does NOT fire (it only fires when `first_launch == true`, which is false for an existing save). The player can still play but must recruit new heroes from Tier-1 classes that still exist (Mage, Rogue). If ALL classes are removed, the Roster stays EMPTY, the Recruit Screen has nothing to offer, and the game soft-locks at the Guild Hall — this scenario should be impossible in practice (Hero Class DB schema validation requires `MIN_CONTENT_COUNT["classes"] >= 3`).

### E.4 Recruit Attempted While AT_CAP

**Scenario**: Player has 30 heroes (cap). They tap "Recruit Warrior."

**Behavior**: Recruitment System's pre-check `roster.is_at_cap()` returns true *before* `economy.try_spend()` is called. The Recruit Screen's Warrior button is greyed out (UI affordance). If the player somehow bypasses the UI gate and Recruitment calls `add_hero("warrior")` anyway, `add_hero()` returns `null` and emits no signal — gold has not been spent because the Recruitment System should have pre-checked. **If Recruitment did spend gold first (a bug), gold is lost** — Recruitment System GDD #14 must enforce the pre-check ordering. Roster does not refund.

### E.5 Level-Up Attempted On Max-Level Hero

**Scenario**: Player taps "Level Up" on a hero already at L15.

**Behavior**: Hero Leveling System #15's pre-check (`hero.current_level < LEVEL_CAP`) prevents the spend. If somehow bypassed and `set_hero_level(id, 16)` is called, Roster clamps `new_level` to `LEVEL_CAP = 15`, emits `hero_leveled(id, 15, 15)` (a no-op level transition), and logs `push_warning`. The Leveling System can detect the no-op via the equal old/new values in the signal payload and refund gold if it has not yet been deducted. (The clamp is a safety net — Leveling System owns the user-facing affordance to prevent the action.)

### E.6 Name Pool Exhausted (Player Stacks Beyond Pool Size)

**Scenario**: Player stacks 26 Warriors. Warrior name pool has 25 entries. The 26th Warrior recruit needs a name.

**Behavior**: Per D.3 fallback path: `available_names == []`, `N = 26`, `display_name = "Theron the Twenty-Sixth"` (using the first pool entry as base name + ordinal word). The hero is recruited normally; only the name format changes. No error; the fallback is part of the contract. If the player stacks further (27th, 28th…), each subsequent fallback uses the next ordinal: "Theron the Twenty-Seventh," etc. Cozy-register ordinal mapping (`Second`, `Third`, …, `Ninetieth`) is a flat lookup table in `roster_config.tres` (rationale: localization-friendly).

### E.7 Save File Has Duplicate instance_id Across Two Heroes

**Scenario**: Save corruption or hand-editing causes two `HeroInstance` records to share `instance_id = 5`.

**Behavior**: `load_save_data()` populates `_heroes` as a Dictionary; the second insertion overwrites the first by Dictionary semantics. The first hero is silently lost. Logs `push_error("HeroRoster: duplicate instance_id 5 — second hero overwrote the first")`. Save/Load's HMAC integrity check (GDD #3) would have rejected the save before reaching this path under any normal corruption — this case can only occur from a save authored by an attacker who has the HMAC key. Not a defended-against case; the integrity system upstream owns that boundary.

### E.8 Formation Slot References Removed Hero After Boot Validation

**Scenario**: A hero in formation slot 1 had its class removed in a patch. Boot validation Rule 16 step 1 removes the hero from `_heroes`.

**Behavior**: Boot validation step 2 detects `_formation_slots[1]` references a non-existent id (the removed hero), sets the slot to `0`, and logs `push_warning`. Player loads into a partially-empty formation. UI shows the empty slot; player must reassign before dispatch produces meaningful drip. If ALL formation slots become empty due to total class removal, dispatch is unavailable and HUD shows a "your formation is empty" notice.

### E.9 set_hero_level Called With instance_id That Does Not Exist

**Scenario**: Hero Leveling System calls `set_hero_level(99, 5)` but no hero with `instance_id = 99` exists (race condition: hero was removed by another path between Leveling's read and write).

**Behavior**: Roster's `set_hero_level()` returns `false`, emits no signal, logs nothing (this is an expected race condition under the GDScript single-threaded model only if the caller violated the API contract). Hero Leveling System receives `false` and must reconcile: if it has spent gold, it must request a refund from Economy (Economy provides no `refund` API in MVP — Leveling System GDD #15 must specify the contract). In practice, GDScript is single-threaded, so this race cannot occur within a single frame; the case is documented for completeness against future async refactors.

### E.10 add_hero Called With class_id That Does Not Resolve

**Scenario**: Recruitment System calls `add_hero("nonexistent_class")` (programmer error or stale UI binding).

**Behavior**: `add_hero()` calls `DataRegistry.resolve("classes", "nonexistent_class")`, receives `null`, returns `null` to caller, logs `push_error`. No hero created. No signal emitted. If Recruitment had pre-spent gold, gold is lost — Recruitment System must validate `class_id` BEFORE calling `try_spend()`. This is enforced by the Section C.3 cross-system contract documentation.

### E.11 Player Removes Heroes Until Formation Empty Mid-Run

**Scenario**: Not possible in MVP — there is no player-initiated `remove_hero`. The only removal vector is Save/Load boot fallback (Rules 16 + E.3), which runs at load, not mid-session. A mid-session formation-empty state cannot occur from player action.

**Behavior**: N/A in MVP. If V1.0 adds a player dismiss mechanic, this edge case becomes live and Dungeon Run Orchestrator must handle a formation transitioning to empty mid-run.

### E.12 Concurrent Recruit + Level-Up From Two UI Interactions

**Scenario**: Player rapidly taps "Recruit Warrior" then "Level Up Theron" before the first action completes its frame.

**Behavior**: GDScript is single-threaded. UI events queue and process sequentially. The Recruit completes (Roster mutates, signal fires, UI updates), then the Level Up processes against the new state. No data race possible. The `gold_changed` signal from Economy's `try_spend()` may fire in either order depending on which UI event reached `_input` first; both screens listen for it and refresh independently. No edge case behavior required.

---

## F. Dependencies

### Upstream Dependencies (systems this one depends on)

| Upstream | Hard/Soft | Interface | Locked Contracts |
|---|---|---|---|
| **Hero Class Database** (`design/gdd/hero-class-database.md`) | Hard | `DataRegistry.resolve("classes", id) -> HeroClass \| null` per hero on load + on `add_hero()` precondition; `stat_at_level(stat, class_data, level)` (D.1) computed by consumers using `HeroInstance.current_level`; `hero_tick_output(class_data, level)` (D.3) by Orchestrator | A `HeroInstance` is meaningless without a resolvable class — Roster drops orphaned heroes per Save/Load fallback table |
| **Save/Load System** (`design/gdd/save-load-system.md`) | Hard | `get_save_data() -> Dictionary` / `load_save_data(data: Dictionary)`; persisted keys: `heroes`, `formation_slots`, `next_instance_id`; per-hero keys per Section C Rule 4 | Save/Load orchestrates the persist; Roster does no direct file I/O. Boot validation order specified in Rule 16 |
| **Data Loading System** (`design/gdd/data-loading.md`) | Hard | `DataRegistry.resolve("classes", id)` (transitive via Class DB); `DataRegistry.resolve("name_pools", class_id)` for per-class name pool resource | Standard registry contract. Validation rejects invalid resources at boot |

### Downstream Dependents (systems that depend on this)

| Consumer | Hard/Soft | Interface | What they read/write |
|---|---|---|---|
| **Economy System** (`design/gdd/economy-system.md`) | Hard | `roster.get_formation_strength() -> float` | Read each tick (foreground) and once per offline-replay batch |
| **Recruitment System** (#14, undesigned) | Hard | `roster.is_at_cap()`, `roster.get_copies_owned(class_id)`, `roster.add_hero(class_id) -> HeroInstance \| null` | Pre-checks before spend; calls `add_hero()` after `economy.try_spend()` succeeds |
| **Hero Leveling System** (#15, undesigned) | Hard | `roster.get_hero(id)`, `roster.set_hero_level(id, new_level) -> bool` | Reads current_level; mutates after `economy.try_spend()` succeeds |
| **Formation Assignment System** (#17, undesigned) | Hard | `roster.get_all_heroes()`, `roster.has_hero(id)`, `roster.get_formation_slot(i)`, `roster.set_formation_slot(slot_index, instance_id) -> bool` | Reads roster for selection UI; writes formation slot assignments |
| **Combat Resolution** (#11, undesigned) | Hard — read-only | `roster.get_formation_heroes() -> Array[HeroInstance]`; per hero, `DataRegistry.resolve("classes", hero.class_id)` + `stat_at_level()` | Reads formation hero list at run start; resolves each hero's class template; computes live stats via Class DB formula |
| **Dungeon Run Orchestrator** (#13, undesigned) | Hard — read-only | `roster.get_formation_heroes()` once at run start; per hero, `hero_tick_output(class_data, hero.current_level)` (Class DB D.3) | Sums per-hero tick output to `formation_base_output`; holds snapshot for entire offline replay (no per-tick re-walk) |
| **Roster / Hero Detail Screen** (#22, undesigned) | Hard | `roster.get_all_heroes()`, `roster.get_hero(id)`; subscribes to `hero_recruited`, `hero_leveled`, `hero_removed` | Read-only display; live refresh on signals |
| **Recruit Screen** (#21, undesigned) | Soft | `roster.get_copies_owned(class_id)`, `roster.is_at_cap()` | Display: greys out recruit buttons; per-class cost lookup |
| **Onboarding / First-Session Flow** (#29, undesigned) | Soft | Reads `hero_recruited` signal; assumes seeded tutorial Warrior in slot 0 | Tutorial flow runs after Roster's `seed_first_launch_state()` |
| **Class Synergy System** (#32, V1.0 first-pass 2026-05-09) | Hard — read-only | `roster.get_hero(instance_id) -> HeroInstance` (existing); reads `hero.class_id` to compose the synergy multiset per class-synergy-system.md §D.1 `detect_active_synergy` | Reads at slot edit (live preview) + at dispatch-time snapshot. No writes. |
| **Prestige System** (#31, V1.0 first-pass 2026-05-09) | Hard — central API host | New API surface added to HeroRoster: `is_prestige_eligible(instance_id) -> bool`, `prestige_hero(instance_id) -> bool`, `get_prestige_multiplier() -> float`. New private fields: `_prestige_count: int`, `_prestige_multiplier: float`, `_retired_hero_records: Array[Dictionary]`. New signal: `prestige_completed_signal(record, new_count)`. **V1→V2 save-schema migration** adds 3 fields to the Roster save namespace. Per `prestige-system.md` §C.2 + §C.5. |

### Bidirectional Consistency

- `design/gdd/hero-class-database.md` Dependencies section: ✅ lists Hero Roster as a hard dependent ("Reads full stat block at hero instance creation")
- `design/gdd/save-load-system.md` Dependencies section: ✅ lists Hero Roster as a hard dependent (`get_save_data` / `load_save_data` + per-hero `DataRegistry.resolve("classes", id)` fallback documented)
- `design/gdd/data-loading.md` Dependencies section: ✅ Hero Class DB is listed as the proximate consumer; Roster is a transitive consumer via Class DB
- `design/gdd/economy-system.md` Dependencies section: provisionally lists Hero Roster as upstream via `roster.get_formation_strength() -> float`. **This GDD locks that signature.** Economy GDD's "provisional contract" annotation can be removed at next revision.
- Undesigned downstream GDDs (Recruitment, Leveling, Formation Assignment, Orchestrator, Combat, Roster Screen, Recruit Screen, Onboarding) MUST cite "depends on Hero Roster" with the specific interface methods listed above when authored.

### New cross-system contracts introduced by this GDD

1. `roster.get_formation_strength() -> float` — locks the Economy provisional contract
2. `seed_first_launch_state()` — Roster ships its own seed state; Onboarding does not need to inject heroes
3. `_orphaned_heroes` list returned to Save/Load — drives the player-facing "X was removed from your guild" notice
4. `hero_recruited`, `hero_leveled`, `hero_removed` signal payloads — locked for downstream UI subscribers
5. `MAX_ROSTER_SIZE = 30`, `FORMATION_SIZE = 3` constants — to be registered

---

## G. Tuning Knobs

All knobs live in `assets/data/config/roster_config.tres` (a `Resource` subclass loaded at boot by the Data Loading System). No Roster value is hardcoded in GDScript.

### G.1 Capacity Knobs

| Knob | Type | Default | Safe Range | Effect | Risk if pushed high | Risk if pushed low |
|---|---|---|---|---|---|---|
| `MAX_ROSTER_SIZE` | int | 30 | 15 – 50 | Hard cap on owned heroes. Recruit Screen greys out at this number. | Roster Screen requires scrolling/paging at >30 (5×6 grid breaks); offline-replay performance degrades; Save/Load JSON grows. Live-ops events that grant free heroes risk breaking the cap. | Players hit cap mid-week, can't experiment with stacking; per-copy cost escalation becomes irrelevant; Pillar 2 (class distinctness via collection depth) flattens. |
| `FORMATION_SIZE` | int | 3 | 1 – 5 | Number of formation slots (active dispatch lineup). | More slots = more matchup combinatorics but flatter individual hero impact (Pillar 2 erodes); Combat Resolution math complexity grows; Matchup Assignment Screen UI requires redesign. | Single-slot formations remove the matchup-decision space (Pillar 3 fails); two-slot loses one of the three MVP archetype roles per dispatch. |

**Inter-knob constraint**: `MAX_ROSTER_SIZE >= FORMATION_SIZE` (otherwise the player cannot fill the formation). Validated on `roster_config.tres` load; fatal error if violated.

### G.2 Tutorial Seed Knobs

| Knob | Type | Default | Safe Range | Effect |
|---|---|---|---|---|
| `SEED_HERO_CLASS_ID` | String | `"warrior"` | Any tier-1 class id | Class of the pre-seeded tutorial hero on first launch. |
| `SEED_HERO_NAME` | String | `"Theron"` | Any non-empty string ≤32 chars | Personal name of the tutorial hero. Hardcoded for QA reproducibility (does not draw from the random pool). |
| `SEED_FORMATION_SLOT` | int | 0 | [0, FORMATION_SIZE - 1] | Which formation slot the tutorial hero occupies on first launch. |

**When to tune `SEED_HERO_CLASS_ID`**: Only if playtest reveals a different class is the better tutorial hero (e.g., Mage easier to grasp than Warrior). Changing this requires also updating Onboarding GDD #29's tutorial copy.

### G.3 Name Pool Knobs

| Knob | Type | Default | Safe Range | Effect |
|---|---|---|---|---|
| `name_pool_min_size` | int | 20 | 15 – 50 | Validated at Data Loading boot — `assets/data/classes/{class_id}/names.tres` must contain at least this many entries or the load fails with a content error. |
| `name_fallback_template` | String | `"{base} the {ordinal}"` | Any string with `{base}` + `{ordinal}` placeholders | Template for fallback names when pool is exhausted (E.6). Localizable. |
| `ordinal_words` | Array[String] | `["Second", "Third", … "Ninetieth"]` | Cozy-register ordinal words; ≥`MAX_ROSTER_SIZE` entries required | Looked up by `ordinal(N)` in D.3. Localizable. |

### G.4 Default Sort Order

| Knob | Type | Default | Safe Range | Effect |
|---|---|---|---|---|
| `default_roster_sort_primary` | enum | `BY_CLASS` | `BY_CLASS`, `BY_LEVEL_DESC`, `BY_RECRUIT_ORDER` | Primary sort key for `get_all_heroes()` default ordering. |
| `default_roster_sort_secondary` | enum | `BY_LEVEL_DESC` | `BY_LEVEL_DESC`, `BY_LEVEL_ASC`, `BY_RECRUIT_ORDER` | Tiebreaker within primary sort group. |

**MVP behavior**: `BY_CLASS` then `BY_LEVEL_DESC` — Warriors grouped together (most-leveled first), then Mages, then Rogues, then V1.0 classes in registry order. Player-customizable sort is V1.0.

### G.5 First-Playtest Tuning Pass Order (Highest Leverage)

1. **`MAX_ROSTER_SIZE`** — verify the 5×6 grid layout works on the target Steam Deck resolution (1280×800). If portrait/icon size requires more padding, drop to 25 (5×5). If layout has headroom, raise to 40 (8×5).
2. **`SEED_HERO_CLASS_ID`** — playtest first-session flow with each of the three classes; confirm Warrior reads as "the obvious starter."
3. **`name_pool_min_size`** — verify names feel cozy and varied, not random-fantasy-name-generator. Increase per-class pools if first 5 recruits feel samey.
4. **`default_roster_sort_primary`** — observe whether playtesters scroll past the survey moment to find heroes (sort wrong) or land on what they want immediately (sort right).

### G.6 Knobs Not Owned Here (Pointers to Source)

| Knob | Owner | Why referenced here |
|---|---|---|
| `LEVEL_CAP` | Economy GDD #5 / registry | Roster's `set_hero_level()` clamps to this constant. Do not duplicate. |
| `RECRUIT_RATIO` | Economy GDD #5 / registry | Recruit cost escalation per copy — Roster's `get_copies_owned()` is the input. |
| `LEVEL_RATIO` | Economy GDD #5 / registry | Level cost escalation per level — Roster's `current_level` is the input. |
| `BASE_RECRUIT[tier]` | Economy GDD #5 / registry | Per-tier base recruit cost — Roster's `class.tier` (via Class DB) is the input. |
| `BASE_LEVEL[tier]` | Economy GDD #5 / registry | Per-tier base level cost — same input chain. |

---

## H. Acceptance Criteria

All criteria use Given-When-Then format. 23 criteria total (21 BLOCKING + 2 ADVISORY).

### H-01 — First-Launch Seed (Logic, BLOCKING)

**GIVEN** a fresh game with no save file (`first_launch == true`),
**WHEN** `seed_first_launch_state()` runs,
**THEN** `_heroes` contains exactly one entry at `instance_id == 1` with `class_id == "warrior"`, `display_name == "Theron"`, `current_level == 1`, `xp == 0`; `_formation_slots == [1, 0, 0]`; `_next_instance_id == 2`; one `hero_recruited` signal was emitted.

### H-02 — add_hero Returns Fully-Populated HeroInstance with Auto-Assigned Id (Logic, BLOCKING)

**GIVEN** a roster post-first-launch (one hero at id 1, `_next_instance_id == 2`),
**WHEN** `add_hero("mage")` is called,
**THEN** returns a non-null `HeroInstance` with `instance_id == 2`, `class_id == "mage"`, `display_name` non-empty (drawn from mage name pool), `current_level == 1`, `xp == 0`; `_next_instance_id == 3` after the call; `hero_recruited` signal emitted exactly once with the new instance as payload.

### H-03 — add_hero at MAX_ROSTER_SIZE Returns Null Without Side Effects (Logic, BLOCKING)

**GIVEN** a roster with `_heroes.size() == MAX_ROSTER_SIZE` (30) and `_next_instance_id == 31`,
**WHEN** `add_hero("warrior")` is called,
**THEN** returns `null`; emits no signal; `_next_instance_id` remains `31` (no increment); no `push_error` is logged (cap is expected); `is_at_cap()` returns `true` both before and after.

### H-04 — add_hero with Unresolvable class_id Logs Error and Returns Null (Logic, BLOCKING)

**GIVEN** a roster with capacity available, no class registered with id `"phantom"`,
**WHEN** `add_hero("phantom")` is called,
**THEN** returns `null`; logs `push_error` containing the literal substring `"phantom"`; emits no signal; `_next_instance_id` is not incremented.

### H-05 — set_hero_level Clamps to LEVEL_CAP and Emits Signal With Old/New (Logic, BLOCKING)

**GIVEN** a hero at `instance_id = 5`, `current_level = 14`,
**WHEN** `set_hero_level(5, 16)` is called (above cap),
**THEN** returns `true`; hero's `current_level == 15` (clamped to LEVEL_CAP); emits `hero_leveled(5, 14, 15)`; logs `push_warning` mentioning "out of range".

**AND WHEN** `set_hero_level(5, 16)` is called again,
**THEN** returns `true`; `current_level` stays `15`; emits `hero_leveled(5, 15, 15)` (no-op transition with old==new) so callers can detect the no-op; `push_warning` logged again.

### H-06 — set_formation_slot Validates Id and Auto-Clears Prior Slot (Logic, BLOCKING)

**GIVEN** roster with heroes at ids 1, 2; `_formation_slots = [1, 0, 0]`,
**WHEN** `set_formation_slot(1, 1)` is called (placing hero 1 in slot 1, where it already occupies slot 0),
**THEN** returns `true`; `_formation_slots == [0, 1, 0]` (slot 0 auto-cleared, slot 1 holds hero 1).
**AND WHEN** `set_formation_slot(2, 99)` is called (hero 99 does not exist),
**THEN** returns `false`; `_formation_slots` unchanged.

### H-07 — Save Round-Trip Preserves All State (Integration, BLOCKING)

**GIVEN** a populated roster: 10 heroes mixed across Warrior (4), Mage (3), Rogue (3); levels [1,3,5,8,10,12,2,7,9,15]; formation slots [3, 7, 0]; `_next_instance_id = 15` (some heroes were removed during validation),
**WHEN** `get_save_data()` is called, then a fresh `HeroRoster` instance has `load_save_data(saved)` called,
**THEN** restored roster's `_heroes.size() == 10`; every restored hero matches pre-save `instance_id`, `class_id`, `display_name`, `current_level`, and `xp` (== 0) exactly; `_formation_slots == [3, 7, 0]`; `_next_instance_id == 15`; no signals fired during load (boot suppression).

### H-08 — Boot Validation Drops Orphaned Heroes Silently (Logic, BLOCKING)

**GIVEN** a save dict with 5 heroes, 2 of which have `class_id == "deleted_class"` not in DataRegistry,
**WHEN** `load_save_data(saved)` runs,
**THEN** `_heroes.size() == 3` (only resolvable heroes survive); `_orphaned_heroes` contains 2 entries with both heroes' `display_name` and `class_id`; **zero `hero_removed` signals emitted during load**; `push_warning` logged once per orphan.

### H-09 — Boot Validation Clears Formation Slots Referencing Dropped Heroes (Logic, BLOCKING)

**GIVEN** a save dict with formation_slots = [5, 7, 9] but only hero 5 survives boot validation (heroes 7 and 9 had unresolvable class_ids),
**WHEN** `load_save_data(saved)` runs,
**THEN** after validation, `_formation_slots == [5, 0, 0]`; `push_warning` logged for each cleared slot.

### H-10 — Boot Validation Trims Roster to Cap, Preserves Lowest Ids (Logic, BLOCKING)

**GIVEN** a save dict with heroes at ids 1–35 (all resolvable), `MAX_ROSTER_SIZE = 30`,
**WHEN** `load_save_data(saved)` runs,
**THEN** `_heroes` contains exactly heroes at ids 1–30 (lowest preserved); ids 31–35 are absent; `_orphaned_heroes` contains 5 entries with reason "roster cap reduced"; `push_warning` logged per removed hero.

### H-11 — get_formation_strength: Boundary, Linear, and Clamp Cases (Logic, BLOCKING)

Parameterized — 6 sub-cases:

| Case | Formation | Expected `avg_formation_level` | Expected `factor` |
|---|---|---|---|
| (a) Empty | `[]` | N/A (guard returns 1.0) | `1.0` |
| (b) Single L1 | `[L1]` | `1.0` | `1.0` |
| (c) Triple L5 | `[L5, L5, L5]` | `5.0` | `clamp(1.8) = 1.8` |
| (d) Mixed mid (linear interior) | `[L4, L8, L9]` | `7.0` | `clamp(2.2) = 2.2` |
| (e) Triple L11 (clamp boundary) | `[L11, L11, L11]` | `11.0` | `clamp(3.0) = 3.0` |
| (f) Triple L15 (above clamp) | `[L15, L15, L15]` | `15.0` | `clamp(3.8) = 3.0` |

**THEN** each case's `get_formation_strength()` matches the expected `factor` value exactly (float equality within 1e-6).

### H-12 — Name Pool Selection Excludes In-Use Names; Fallback at Exhaustion (Logic, BLOCKING)

**GIVEN** Warrior name pool = `["Theron", "Aldric", "Gorin", … 25 entries]`; roster contains `[Theron, Aldric, Gorin, Kael]` (4 Warriors),
**WHEN** `add_hero("warrior")` is called 21 more times to exhaust the pool, then once more (the 26th Warrior overall),
**THEN** the 5th–25th calls each produce a hero whose `display_name` is in the pool but not in any prior Warrior's `display_name`; the 26th call's hero has `display_name == "Theron the Twenty-Sixth"` (using the first pool entry as `{base}` and `ordinal(26)` lookup).

### H-13 — Recruitment Pre-Check Sequence (Cross-System Integration, BLOCKING)

**GIVEN** stub Recruitment + stub Economy; roster has 2 Warriors (`get_copies_owned("warrior") == 2`); player has 1000 gold; `recruit_cost(1, 2) = floor(150 × 1.8^2) = 486`,
**WHEN** Recruitment runs the spec sequence: (1) `is_at_cap()` returns `false`; (2) `DataRegistry.resolve("classes", "warrior")` returns non-null; (3) `economy.try_spend(486)` returns `true` (sets gold to 514); (4) `add_hero("warrior")` returns a non-null instance,
**THEN** roster size increments by 1; `get_copies_owned("warrior") == 3`; gold balance == 514; one `hero_recruited` signal emitted.

*Note: this AC must be re-validated with real (non-stub) Recruitment + Economy when those GDDs ship — see Open Questions.*

### H-14 — get_formation_strength Performance (Performance, ADVISORY)

**GIVEN** a roster with `_formation_slots` fully populated (3 heroes),
**WHEN** `get_formation_strength()` is called 1000 consecutive times,
**THEN** p99 wall-clock time per call is < **50 µs** on minimum-spec target hardware (Steam Deck 1280×800 baseline). Logged to `production/qa/evidence/roster-perf-[date].md`.

### H-15 — instance_id Never Reused After remove_hero (Logic, BLOCKING)

**GIVEN** roster with heroes at ids 1, 2, 3; `_next_instance_id == 4`,
**WHEN** `remove_hero(2)` is called, then `add_hero("mage")` is called,
**THEN** new hero has `instance_id == 4` (not 2 or 3); `_next_instance_id == 5` after the new hero is added.

### H-16 — xp Field Round-Trips as Zero (Logic, BLOCKING)

**GIVEN** a roster with 3 heroes created via `add_hero()`,
**WHEN** `get_save_data()` → `load_save_data()` is applied,
**THEN** every restored hero has `xp == 0` exactly (not null, not missing key, not >0). Test asserts the field's presence in the save dict structure as well.

### H-17 — Boot Validation Repairs Corrupted _next_instance_id (Logic, BLOCKING)

**GIVEN** a save dict with `next_instance_id = 3` but `heroes` containing an instance with `instance_id = 7`,
**WHEN** `load_save_data(saved)` runs,
**THEN** after validation, `_next_instance_id == 8` (repaired to `max(existing) + 1`); the next `add_hero()` call returns an instance with `instance_id == 8`.

### H-18 — get_copies_owned Returns Accurate Per-Class Count (Logic, BLOCKING)

**GIVEN** a roster with 3 Warriors, 2 Mages, 1 Rogue,
**WHEN** `get_copies_owned()` is called for each of `"warrior"`, `"mage"`, `"rogue"`, `"cleric"` (V1.0 stub class),
**THEN** returns exactly `3`, `2`, `1`, `0` respectively.

### H-19 — is_at_cap Boundary at MAX_ROSTER_SIZE (Logic, BLOCKING)

**GIVEN** a roster with exactly `MAX_ROSTER_SIZE - 1` (29) heroes,
**WHEN** `is_at_cap()` is called,
**THEN** returns `false`.
**AND WHEN** `add_hero("warrior")` is called (taking size to 30),
**THEN** `add_hero` returns non-null; `is_at_cap()` returns `true`; subsequent `add_hero()` returns `null` per H-03.

### H-20 — Duplicate instance_id in Save Data Logs Error, Last-Written Wins (Logic, BLOCKING)

**GIVEN** a save dict with two hero entries both having `instance_id == 5` (different `class_id` / `display_name`),
**WHEN** `load_save_data(saved)` runs,
**THEN** `_heroes` contains exactly one hero at id 5 (the latter entry per Dictionary insertion order); `push_error` logged with substring `"duplicate instance_id 5"`; no crash; other heroes load normally.

### H-22 — get_all_heroes Default Sort: BY_CLASS then BY_LEVEL_DESC (Logic, BLOCKING)

**GIVEN** a roster with: Warrior L5 (id 1), Mage L10 (id 2), Warrior L8 (id 3), Rogue L3 (id 4), Mage L7 (id 5),
**WHEN** `get_all_heroes()` is called with default sort,
**THEN** returned order is: `[Warrior L8 (id 3), Warrior L5 (id 1), Mage L10 (id 2), Mage L7 (id 5), Rogue L3 (id 4)]` — class group order matches registry declaration order (Warrior → Mage → Rogue), level descending within group.

### H-23 — get_formation_strength with Partial Formation (Logic, BLOCKING)

**GIVEN** `_formation_slots = [hero_at_L4_id, hero_at_L8_id, 0]` (slot 2 empty),
**WHEN** `get_formation_strength()` is called,
**THEN** `get_formation_heroes().size() == 2` (skips empty slot); `avg_formation_level = (4+8)/2 = 6.0`; `factor = clamp(1.0 + 5.0 * 0.2, 1.0, 3.0) = 2.0`; returned value `== 2.0` (float equality within 1e-6). No divide-by-zero.

### H-24 — roster_config.tres Constraint: MAX_ROSTER_SIZE ≥ FORMATION_SIZE (Config/Data, ADVISORY)

**GIVEN** a `roster_config.tres` with `MAX_ROSTER_SIZE = 2` and `FORMATION_SIZE = 3` (invalid: cap below formation size),
**WHEN** the Data Loading System loads the config,
**THEN** raises a fatal error before the Roster system reaches the `READY` state; error message identifies the invalid constraint by name.

*Gate = ADVISORY*: caught at boot before any gameplay state exists; not a runtime concern.

### Classification Summary

| ID | Description | Type | Gate |
|---|---|---|---|
| H-01 | First-launch seed creates Theron the Warrior | Logic | BLOCKING |
| H-02 | add_hero returns full instance + auto-id | Logic | BLOCKING |
| H-03 | add_hero at cap returns null silently | Logic | BLOCKING |
| H-04 | add_hero with unresolvable class logs error | Logic | BLOCKING |
| H-05 | set_hero_level clamps + signal payload | Logic | BLOCKING |
| H-06 | set_formation_slot validates and auto-clears | Logic | BLOCKING |
| H-07 | Save round-trip preserves all state | Integration | BLOCKING |
| H-08 | Boot validation drops orphans silently | Logic | BLOCKING |
| H-09 | Boot validation clears stale formation slots | Logic | BLOCKING |
| H-10 | Boot trim to cap preserves lowest ids | Logic | BLOCKING |
| H-11 | formation_strength_factor — 6 cases | Logic | BLOCKING |
| H-12 | Name pool exclusion + fallback | Logic | BLOCKING |
| H-13 | Recruitment pre-check sequence (cross-sys stub) | Integration | BLOCKING |
| H-14 | get_formation_strength p99 < 50µs | Performance | ADVISORY |
| H-15 | instance_id never reused after remove | Logic | BLOCKING |
| H-16 | xp field round-trips as zero | Logic | BLOCKING |
| H-17 | Boot repairs corrupted _next_instance_id | Logic | BLOCKING |
| H-18 | get_copies_owned accuracy | Logic | BLOCKING |
| H-19 | is_at_cap boundary | Logic | BLOCKING |
| H-20 | Duplicate instance_id in save logs error | Logic | BLOCKING |
| H-22 | Default sort BY_CLASS then BY_LEVEL_DESC | Logic | BLOCKING |
| H-23 | get_formation_strength with partial formation | Logic | BLOCKING |
| H-24 | Config constraint MAX_ROSTER_SIZE ≥ FORMATION_SIZE | Config/Data | ADVISORY |

(H-21 was a duplicate of H-10 and was removed during drafting. Final count: 23 ACs — 21 BLOCKING + 2 ADVISORY.)

---

## I. Open Questions

| Question | Owner | Target Resolution |
|---|---|---|
| **Per-class name pool authoring** — `assets/data/classes/{class_id}/names.tres` needs 25–30 cozy-register names per MVP class (Warrior, Mage, Rogue). Names must read as fantasy-but-warm (not random-fantasy-name-generator). | writer + game-designer | Before first MVP playtest |
| **`ordinal_words` lookup table content** — 90 cozy-register ordinals (`Second` through `Ninetieth`). Localizable. Pull from a style guide; verify reads naturally with hero name templates ("Theron the Eighty-Seventh"). | writer + localization-lead | Before first MVP playtest |
| **`set_hero_level()` no-op signal contract** — Should the signal fire when `old_level == new_level` (clamped no-op)? Currently fires per E.5 / H-05 so callers can detect refund opportunities. Hero Leveling System GDD #15 may prefer the silent path. Coordinate when GDD #15 is authored. | systems-designer | During Hero Leveling System GDD |
| **Refund API for failed mutations** — If `set_hero_level()` returns `false` after `economy.try_spend()` already deducted gold, the Leveling System needs to refund. Economy GDD #5 has no `refund()` API in MVP. Decide: add it, or guarantee no race window via API ordering contract? | economy-designer + systems-designer | During Hero Leveling System GDD #15 |
| **Player rename hero in V1.0?** — Currently `display_name` is immutable. V1.0 cozy-feature consideration: let players rename. Requires UI work + save migration handling. Defer scope decision. | game-designer + ux-designer | V1.0 scope planning |
| **Player dismiss hero in V1.0?** — E.11 documents that mid-session player removal is impossible in MVP. V1.0 cozy-fantasy framing of "retirement" (not deletion) requires narrative scaffolding (currently anti-pillar). Re-evaluate at V1.0. | game-designer | V1.0 scope planning |
| **Cross-language localization of names** — `display_name` is stored verbatim. If localized to JP/zh, names should plausibly be drawn from a culture-appropriate pool, but a stored "Theron" doesn't translate. Decide: rebake the pool per locale, or freeze names as character data. | localization-lead | Before first non-English release |
| **H-13 re-validation** — Cross-system Recruitment integration AC currently uses stubs. Must re-run with real Recruitment + Economy when GDDs #14 + #5 ship. | qa-lead | During Recruitment System GDD #14 |
| **H-14 perf bound** — 50µs p99 is plausible but unmeasured. Re-validate post-implementation; loosen to 100µs if GDScript signal overhead exceeds the budget. | performance-analyst | First mobile performance pass |
| **Roster Screen visual layout for 5×6 grid at 1280×800** — G.5 anchors `MAX_ROSTER_SIZE = 30` to this grid assumption. UX/Art must validate the layout fits with portrait scale + dispatch indicator + level badge before locking the cap. | ux-designer + art-director | During Roster / Hero Detail Screen GDD #22 |
