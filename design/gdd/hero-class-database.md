# Hero Class Database GDD — Lantern Guild

> **GDD #5 in design order** (System #6 in systems index)
> **Status**: Designed (pending independent review)
> **Created**: 2026-04-18
> **Last Updated**: 2026-04-19
> **Authors**: game-designer + systems-designer + qa-lead + main session
> **Depends on**: `design/gdd/data-loading.md` (GDD #2)
> **Referenced by**: Hero Roster (#9), Class-vs-Enemy Matchup Resolver (#10), Combat Resolution (#11), Recruitment System (#14), Hero Leveling System (#15), Formation Assignment System (#17), Dungeon Run Orchestrator (#13)
> **Implements Pillar**: Pillar 2 (Every Class Feels Distinct), Pillar 3 (Matchup Is a Decision — counter_archetype tag drives the 1.5× multiplier)
> **Creative Director Review (CD-GDD-ALIGN)**: SKIPPED — Solo review mode

---

## A. Overview

The Hero Class Database is the static content layer for all hero archetypes in *Lantern Guild*. It defines the `HeroClass` `.tres` schema, provides three MVP class stat blocks (Warrior, Mage, Rogue) and three V1.0 stubs (Cleric, Ranger, Tactician), and declares the canonical **enemy archetype tag constants** that the Matchup Resolver and Enemy Database both consume. Every class value lives in `assets/data/classes/*.tres` — nothing is hardcoded in GDScript. The database is read-only at runtime; mutable hero state (current level, XP) is owned by the Hero Roster (GDD #9).

This is the first data-definition system in the Core layer. It makes the "class-vs-enemy matchup" mechanic — the Pillar 3 hook — concrete by giving every class a single `counter_archetype: String` tag. When a formation containing a hero whose tag matches the dungeon's primary enemy archetype is dispatched, Economy's 1.5× `MATCHUP_GOLD_MULTIPLIER` applies to kill bonuses. The schema is deliberately minimal — attack, HP, speed, tick output contribution — to keep the matchup decision legible without drowning it in numbers.

Seven downstream systems depend on this database. Its stability matters: changes to the class schema cascade through Hero Roster, Matchup Resolver, Combat Resolution, Recruitment, Leveling, Formation Assignment, and every UI screen that displays hero information.

---

## B. Player Fantasy

The Class Database serves the **curation fantasy** at the heart of *Lantern Guild*: *"every hero in my roster is a specialist I chose for a reason."*

The player never interacts with this system directly. They interact with its output — the roster cards showing WARRIOR / MAGE / ROGUE with distinct silhouettes (art bible), distinct stat blocks, and a single legible counter tag. That legibility is the whole product: the player looks at a card and instantly knows "this hero is for bruiser dungeons" without reading a tutorial, without comparing numbers, without a damage calculator.

The emotional target is **connoisseur's appreciation**. Each class's stat block — highest HP on Warrior, highest attack on Mage, highest speed on Rogue — is the mechanical confirmation of what the silhouette already promised. Players should feel that building a formation is *curation*, not arithmetic. The numbers validate the feel rather than competing with it.

The direct-fantasy moment comes in the Recruit Screen: the player spends 150 gold, the portrait reveals, and the new hero joins the roster with a role and counter already decided. No build choices, no branching stats — **the class IS the build**. That simplicity is Pillar 2 in practice.

---

---

## C. Detailed Design

### C.1 HeroClass Resource Schema

Each hero class is a `GameData` subclass (GDScript: `class_name HeroClass extends GameData`) stored as a `.tres` file. `GameData` is the `@abstract` (Godot 4.5+) base class defined per ADR-0006 — it provides the universal `id: String` + `display_name: String` fields and prevents direct instantiation of the base. The Data Loading System imports the concrete subclass via `DataRegistry.resolve("classes", id)`.

**Field set and justification:**

| Field | Type | Description |
|---|---|---|
| `id` | `String` | Snake_case unique identifier (e.g. `"warrior"`). Stable key — filename may change; `id` never changes. Matches the `id` contract from Data Loading GDD. |
| `display_name` | `String` | Human-readable name shown in all UI (e.g. `"Warrior"`). |
| `tier` | `int` | 1 = Tier-1 (MVP classes); 2 = Tier-2 (V1.0 classes). Values 3–5 reserved for future expansion; not used in MVP or V1.0. |
| `role` | `String` | Functional taxonomy tag. See Role Taxonomy below. |
| `counter_archetype` | `String` | The single enemy archetype tag this class counters. Must exactly match a constant from the Archetype Constants table (C.2). |
| `base_attack` | `int` | Attack stat at Level 1. |
| `base_hp` | `int` | HP stat at Level 1. |
| `base_speed` | `int` | Speed at Level 1. Determines action cadence in Combat Resolution — higher speed = acts more frequently per unit time. |
| `attack_per_level` | `int` | Added to `base_attack` per level above 1 (linear). |
| `hp_per_level` | `int` | Added to `base_hp` per level above 1. |
| `speed_per_level` | `int` | Added to `base_speed` per level above 1. |
| `tick_output_contribution_l1` | `int` | Per-hero contribution to the formation's output pool per tick at Level 1. The Dungeon Run Orchestrator sums all heroes' current tick output and uses the total as `formation_base_output` — a forward-declaration hook for Combat Resolution and the Class Synergy System. See C.6 and Section D.3. |
| `tick_output_per_level` | `int` | Linear scaling of tick output per level above 1. |
| `sprite_path` | `String` | Path to the class's idle/combat sprite sheet. Convention: `assets/art/heroes/{id}/sprite.png`. |
| `portrait_path` | `String` | Path to the roster card portrait. Convention: `assets/art/heroes/{id}/portrait.png`. |
| `icon_path` | `String` | Path to the 32px formation-slot icon. Convention: `assets/art/heroes/{id}/icon.png`. |
| `flavor_text` | `String` | Cozy one-liner shown on roster cards. Soft limit: 120 characters. |

**Fields intentionally omitted from MVP (with rationale):**

- **Defense/Armor**: A separate defense stat would require the Combat Resolution system to implement a damage reduction formula. For a cozy idle game where the player never watches fights unfold, HP alone is sufficient to represent durability. Separating offense and defense adds a tuning dimension that only pays off in games where tactical depth is a pillar (it is not, per Pillar 3 — matchup is the strategic verb, not combat stat optimization). Defer to V1.0 if playtesting reveals HP-only combat is too opaque.
- **Crit chance / Crit multiplier**: Introduces variance into outputs that should be predictable. Idle games live and die on the clarity of their economic loop; unpredictable crits pollute the formation assignment signal. Exclude from MVP; revisit only if Class Synergy System (V1.0) needs them for a specific class identity.
- **Range / targeting priority**: Out of scope for MVP's single-formation-per-dungeon model. No decision is required about target selection in MVP; the Orchestrator resolves combat abstractly at the kill-bonus cadence.
- **Ability / skill slot**: Active abilities require mid-combat player intervention (violates Pillar 3). Passive ability hooks are a V1.0 concern (Class Synergy System). Leave the field out of the MVP schema.

**Role Taxonomy** (the full set, defined now to prevent schema drift across GDDs):

| Role tag | Description | MVP classes with this role |
|---|---|---|
| `"tank"` | Front-line durability, counters physical bruisers | Warrior |
| `"striker"` | Burst damage, counters spell-casters | Mage |
| `"precision"` | High frequency, counters armored targets | Rogue |
| `"support"` | Utility / healing; no direct damage output | Cleric (V1.0) |
| `"ranged"` | Sustained pressure from range | Ranger (V1.0) |
| `"commander"` | Buff / coordination; amplifies others | Tactician (V1.0) |

Six roles cover all six V1.0 classes without overlap. Role is display-only in MVP (Formation Assignment and Roster screens show it); it does not affect any formula until the Class Synergy System is added.

---

### C.2 Enemy Archetype Taxonomy

Archetype tags are the single string that drives the Matchup Resolver's counter check. They must be declared as constants so all systems reference the same strings — no magic strings in GDScript code.

**Declare as a static class or autoload constant file** (GDScript: `class_name EnemyArchetypes`):

```
# assets/data/archetypes/enemy_archetypes.gd (or .tres constant block)
const BRUISER      = "bruiser"      # physical melee brutes; countered by Warrior
const CASTER       = "caster"       # spell-casting enemies; countered by Mage
const ARMORED      = "armored"      # heavily plated; countered by Rogue
const BEAST        = "beast"        # fast natural creatures; countered by Ranger (V1.0)
const CONSTRUCT    = "construct"    # golem/machine types; countered by Tactician (V1.0)
const INCORPOREAL  = "incorporeal"  # undead/spirit types; countered by Cleric (V1.0)
```

**MVP requirement:** `bruiser`, `caster`, `armored` must be populated with enemies in the Enemy Database (GDD #7) before the Matchup Resolver can be tested.

**V1.0 requirement:** `beast`, `construct`, `incorporeal` are reserved — the strings are declared now so Enemy Database and Hero Class DB use the same literals from day one. The V1.0 classes reference them in their stub definitions (C.4).

**Design rationale for the V1.0 archetype choices:**
- `beast` (Ranger counter): Rangers in fantasy lore are trackers and hunters — natural predators of wild creatures. Legible from class fantasy.
- `construct` (Tactician counter): Tacticians redirect and coordinate; constructs follow rigid logic patterns that clever tactics can exploit. Role explains the counter without hand-waving.
- `incorporeal` (Cleric counter): The canonical cleric fantasy — holy power versus undead and spirits — is the most recognizable class-counter pair in the genre. Non-overlapping with bruiser/caster/armored.

---

### C.3 MVP Classes — Full Stat Blocks

Three classes; real numbers; `.tres`-ready.

#### Warrior

```yaml
id:                         "warrior"
display_name:               "Warrior"
tier:                       1
role:                       "tank"
counter_archetype:          "bruiser"
base_attack:                12
base_hp:                    120
base_speed:                 6
attack_per_level:           2
hp_per_level:               17
speed_per_level:            1
tick_output_contribution_l1: 2
tick_output_per_level:      1
sprite_path:                "assets/art/heroes/warrior/sprite.png"
portrait_path:              "assets/art/heroes/warrior/portrait.png"
icon_path:                  "assets/art/heroes/warrior/icon.png"
flavor_text:                "First into every dungeon. Last out. Counts the dents in the morning."
```

**Balance intent**: High HP makes the Warrior the most forgiving formation choice — beginners put it in the frontmost slot without second-guessing. Lowest speed means it acts least often per combat cycle, so its output per tick is modest. Moderate attack ensures it contributes meaningfully to kills without outpacing the Mage at burst output. The Warrior's economic value is staying alive (fewer formation wipes = more consistent offline income), not raw DPS.

#### Mage

```yaml
id:                         "mage"
display_name:               "Mage"
tier:                       1
role:                       "striker"
counter_archetype:          "caster"
base_attack:                20
base_hp:                    70
base_speed:                 10
attack_per_level:           3
hp_per_level:               10
speed_per_level:            1
tick_output_contribution_l1: 3
tick_output_per_level:      1
sprite_path:                "assets/art/heroes/mage/sprite.png"
portrait_path:              "assets/art/heroes/mage/portrait.png"
icon_path:                  "assets/art/heroes/mage/icon.png"
flavor_text:                "Carries three tomes she has not yet opened. She will not need them."
```

**Balance intent**: Highest attack in Tier-1 creates the "glass cannon" archetype players expect. Moderate HP (70) means a Mage-only formation is fragile on later floors — the player is nudged toward pairing it with the Warrior. The Mage counters CASTER enemies, which is thematically coherent (magic-vs-magic) and makes the counter legible from class fantasy alone. Highest `tick_output_contribution_l1` (3) reflects the Mage's burst-and-cooldown nature: it contributes disproportionately to formation output at low levels, creating an incentive to recruit the Mage early.

#### Rogue

```yaml
id:                         "rogue"
display_name:               "Rogue"
tier:                       1
role:                       "precision"
counter_archetype:          "armored"
base_attack:                14
base_hp:                    55
base_speed:                 16
attack_per_level:           2
hp_per_level:               8
speed_per_level:            2
tick_output_contribution_l1: 2
tick_output_per_level:      1
sprite_path:                "assets/art/heroes/rogue/sprite.png"
portrait_path:              "assets/art/heroes/rogue/portrait.png"
icon_path:                  "assets/art/heroes/rogue/icon.png"
flavor_text:                "Loves dungeons. Hates armor. Has strong opinions about both."
```

**Balance intent**: Highest speed (16 vs Mage's 10, Warrior's 6) is the Rogue's identity — it acts most frequently per combat cycle, compensating for moderate-per-hit attack with high action rate. Lowest HP (55) means it is the highest-risk slot; a player who understands the class system will protect it with the Warrior. ARMORED counter is the most tactically interesting: armored enemies resist blunt attacks, but the Rogue's precision strikes bypass plate — this is mechanically legible and distinct from the Warrior/Mage counter identities. The `speed_per_level` of 2 (vs 1 for others) means at higher levels the Rogue's action frequency diverges significantly from the other classes, maintaining its distinct role profile into the late game.

**Cross-class stat hierarchy at Level 1:**

| Stat | Warrior | Mage | Rogue |
|---|---|---|---|
| Attack | 12 | **20** | 14 |
| HP | **120** | 70 | 55 |
| Speed | 6 | 10 | **16** |
| Tick output | 2 | **3** | 2 |

No class dominates in all stats — each has one clear peak. This satisfies Pillar 2's "every class feels distinct" requirement at the stat layer.

---

### C.4 V1.0 Classes — Stub Definitions

These classes are **not usable in MVP**. Their `tier` value is `2` (Tier-2). They are declared here so the Enemy Database (GDD #7) can define the enemy archetypes they counter, and so the Matchup Resolver (GDD #10) does not need schema changes when they are introduced.

```yaml
# status: planned_v1

id:             "cleric"
display_name:   "Cleric"
tier:           2
role:           "support"
counter_archetype: "incorporeal"
balance_direction: >
  Support-first: low attack, high HP, non-zero tick output that buffs adjacent
  heroes (Class Synergy hook). Tick output may be 0 at MVP stub level — Cleric
  provides no direct idle income but amplifies formation output via synergy
  (V1.0 design). Flagged as the test case for tick_output_contribution_l1 = 0
  — verify Economy + Orchestrator handle zero-output heroes gracefully.

---

id:             "ranger"
display_name:   "Ranger"
tier:           2
role:           "ranged"
counter_archetype: "beast"
balance_direction: >
  Sustained pressure: moderate attack, moderate HP, high speed (similar to
  Rogue but more durable). Counters BEAST enemies at range — formation
  positioning note: Rangers should not require a frontliner to be useful,
  distinguishing their design from the Rogue's "protect me" playstyle.

---

id:             "tactician"
display_name:   "Tactician"
tier:           2
role:           "commander"
counter_archetype: "construct"
balance_direction: >
  Commander type: low personal stats, high tick_output_per_level (output
  scales faster with investment than any other class). Counters CONSTRUCT
  enemies via tactical disruption. Economy hook: Tactician makes other
  heroes in the formation contribute more to tick output — this is the
  Class Synergy System's primary design test case.
```

---

### C.5 HeroClass Resource Lifecycle States

This is a static data resource, not a runtime state machine. There are two conditions:

| State | Description | How it is reached |
|---|---|---|
| **LOADED** | `DataRegistry.resolve("classes", id)` returns a valid, non-null `HeroClass` resource. All fields validated on load (see Data Loading GDD schema validation contract). | Normal startup: Data Loading System reads `assets/data/classes/*.tres` and registers each resource by its `id` field. |
| **UNAVAILABLE** | `DataRegistry.resolve("classes", id)` returns `null`. | The `.tres` file is missing, the `id` field does not match the requested key, or the resource failed schema validation. See Edge Case E.1 for consumer behavior. |

These two states cover all runtime possibilities. Schema validation (ensuring all required fields are non-empty, `tier` is in [1, 2], `counter_archetype` is a recognized constant) is the Data Loading System's responsibility, not this system's.

---

### C.6 System Interactions

| Consumer System | Data Read | Contract |
|---|---|---|
| **Hero Roster (#9)** | Full stat block (`base_*`, `*_per_level`, `tier`, `id`, `display_name`, art refs, `flavor_text`) | Reads at hero instance creation. Stores a reference to the `HeroClass` resource; calls `stat_at_level()` helper (Section D.1) to compute live stats. |
| **Recruitment System (#14)** | `tier`, `id` | Reads `tier` to look up `BASE_RECRUIT[tier]` in Economy config. Reads `id` to check how many copies the player already owns (via Roster). Does not read combat stats. |
| **Matchup Resolver (#10)** | `counter_archetype` (of the class), enemy's archetype tag | `is_class_counter(class_data, enemy_archetype)` returns `true` if strings match, else `false`. The Matchup Resolver evaluates per-kill at enemy-death time (no caching) — see Resolver GDD #10 Rule 8 / Rule 12. The Offline Progression Engine takes a one-shot snapshot of the per-floor `MatchupResult` at dispatch time and replays via array lookup, but the resolver itself is stateless and uncached. |
| **Combat Resolution (#11)** | Live stats: `base_attack + attack_per_level × (level-1)`, same for HP and speed | Reads via the Roster's hero instance (which holds current level). Does not call the Class DB directly — Roster provides the computed stat. |
| **Dungeon Run Orchestrator (#13)** | `tick_output_contribution_l1`, `tick_output_per_level`, current hero level (from Roster) | Computes `hero_tick_output(level)` per hero, sums them to `formation_base_output`, uses this in `get_current_drip_per_tick()`. See Section D.3. |
| **Formation Assignment System (#17)** | `id`, `role`, `display_name`, `icon_path`, `counter_archetype` | Formation slot UI shows role tag and counter archetype badge. Reads via Roster. |
| **Recruit Screen (#21)** | `display_name`, `flavor_text`, `portrait_path`, `tier`, cost (from Economy via Recruitment System) | Display only. Greys out classes the player cannot afford. |
| **Roster / Hero Detail Screen (#22)** | Full stat block for display | Display only. Shows current computed stats and next-level preview. |

**Data flow direction**: All consumers read from `HeroClass` resources via `DataRegistry.resolve()`. No consumer writes to `HeroClass` resources — they are immutable static data. Level state is owned by the Hero Roster (hero instance carries current level), not by the class definition.

---

### C.7 Systems Integration Notes

*Validation by systems-designer against Economy + (undesigned) Combat Resolution. Two field-retention tensions documented for transparency.*

**Tension 1 — `tick_output_contribution` fields.**

The locked `drip_per_tick` formula in Economy (`BASE_DRIP[floor] × formation_strength_factor × matchup_drip_factor`) derives formation strength from **average formation level** via `formation_strength_factor = clamp(1.0 + (avg_formation_level - 1) × 0.2, 1.0, 3.0)` — owned by Hero Roster GDD #9 (`HeroRoster.get_formation_strength()`). It does **not** read `tick_output_contribution`. These fields are therefore **unused by Economy in MVP**.

**MVP disposition**: Fields retained as **forward declarations** for the Dungeon Run Orchestrator (#13). Per Section D.3, the Orchestrator will aggregate per-hero `tick_output` into `formation_base_output`, which may feed into `get_current_drip_per_tick()`. The precise integration contract is the Orchestrator's to resolve — this GDD declares the per-hero values so the data is available when the Orchestrator GDD is authored. The Economy's `drip_per_tick` formula does not change.

**Risk**: if the Orchestrator GDD ultimately decides not to consume `tick_output`, these fields become dead schema. Revisit at Orchestrator GDD authoring; if unused, remove the fields and migrate any existing saves that referenced them (MVP saves won't reference them, since they're static data — low-cost migration).

**Tension 2 — `base_speed` / `speed_per_level` fields.**

Speed's semantic depends on Combat Resolution (GDD #11), which is not yet authored. Three candidate interpretations exist: kill cadence (faster → more kills per tick), initiative ordering (if multi-hero attacks are sequential), or pure flavor. The GDD declares values per class (Warrior=6, Mage=10, Rogue=16) with clear hierarchy, so Combat Resolution has concrete numbers to test its formula against when authored.

**MVP disposition**: Fields retained as **forward declarations** for Combat Resolution. Speed hierarchy (Rogue > Mage > Warrior at 16/10/6 base) expresses the intended "cadence" feel even without a consuming formula.

**Risk**: if Combat Resolution GDD decides speed is purely flavor, these fields become UI-display-only. That's still fine — display is a valid consumer. The fields survive.

**Cross-system registry flag**: Per systems-designer recommendation, each MVP class's base stats (`base_attack`, `base_hp`) will be registered as `entities` entries in `design/registry/entities.yaml` so Combat Resolution (#11) can reference them without transcription errors. See Phase 5 registry updates for this GDD.

**Stat scaling ratio validation**: All three classes hit 2.75–3.33× L15/L1 growth ratios — within the 2.0–3.5× target window. No hidden power spikes; Combat Resolution can calibrate enemy HP against this band.

---

## D. Formulas

All formulas produce integers. No floating-point is persisted.

---

### D.1 Hero Live Stat at Level L

```
stat_at_level(stat_name, class_data, level) =
    class_data[base_{stat_name}] + class_data[{stat_name}_per_level] × (level - 1)
```

**Variable table:**

| Variable | Type | Description | Valid Range |
|---|---|---|---|
| `stat_name` | String | One of `"attack"`, `"hp"`, `"speed"` | Must be a field on `HeroClass` |
| `class_data` | HeroClass | The resource for this class | Non-null LOADED resource |
| `level` | int | Current hero level | 1 ≤ level ≤ LEVEL_CAP (15) |

**Output:** int ≥ base value at Level 1.

**Clamp rule**: If `level > LEVEL_CAP`, the formula uses `LEVEL_CAP` instead of `level` (see Edge Case E.2). If `level < 1`, error (see Edge Case E.3).

**Worked example — Warrior attack at Level 8:**
```
attack_at_level("attack", warrior_data, 8)
  = 12 + 2 × (8 - 1)
  = 12 + 14
  = 26
```

**Worked example — Rogue speed at Level 15:**
```
stat_at_level("speed", rogue_data, 15)
  = 16 + 2 × (15 - 1)
  = 16 + 28
  = 44
```

---

### D.2 Class Counter Match Resolver

Used by the Matchup Resolver system. Trivially simple but formally specified to avoid ambiguity.

```
is_class_counter(class_data, enemy_archetype) =
    class_data.counter_archetype == enemy_archetype
```

**Variable table:**

| Variable | Type | Description |
|---|---|---|
| `class_data` | HeroClass | The class being checked |
| `enemy_archetype` | String | The archetype tag of the dungeon's primary enemy type |

**Output:** `bool`. `true` = this class counters this enemy; apply `MATCHUP_GOLD_MULTIPLIER = 1.5×`. `false` = neutral; apply multiplier 1.0×.

**Note**: A formation is considered matchup-advantaged for a given enemy archetype if a **majority of formation slots** (more than `formation.size() / 2`) hold a hero whose `is_class_counter(class_data, enemy_archetype) == true`. Aggregation is per-kill and per-archetype, not per-run. The Matchup Resolver owns the formation-level aggregation (Resolver GDD #10 Rule 6 + D.2); this formula operates on a single hero-class / enemy-archetype pair. **Revision history:** the original "at least one counter wins" rule was changed to majority-threshold during Matchup Resolver review on 2026-04-19 to keep the Pillar 3 decision live past run 1 of MVP — see Resolver GDD #10 review log.

---

### D.3 Per-Hero Tick Output Contribution

```
hero_tick_output(class_data, level) =
    class_data.tick_output_contribution_l1 + class_data.tick_output_per_level × (level - 1)
```

**Variable table:**

| Variable | Type | Description | Valid Range |
|---|---|---|---|
| `class_data` | HeroClass | The class resource | Non-null |
| `level` | int | Hero's current level | 1 ≤ level ≤ LEVEL_CAP |

**Output:** int ≥ 0.

**Formation aggregate** (computed by Dungeon Run Orchestrator):
```
formation_base_output = sum(hero_tick_output(class_data[i], level[i])) for each hero i in formation
```

This value feeds `get_current_drip_per_tick()`. For compatibility with the Economy System's `BASE_DRIP × formation_strength_factor` formula, the Orchestrator passes `formation_base_output` as an input when computing `formation_strength_factor` (pending Orchestrator GDD confirmation).

**Worked example — 3-hero formation at floor 3, avg Level 10:**

Assuming mixed formation: Warrior L10 + Mage L10 + Rogue L10:
```
warrior_tick_output = 2 + 1 × (10 - 1) = 2 + 9 = 11
mage_tick_output    = 3 + 1 × (10 - 1) = 3 + 9 = 12
rogue_tick_output   = 2 + 1 × (10 - 1) = 2 + 9 = 11
formation_base_output = 11 + 12 + 11 = 34
```

Economy's drip formula at floor 3, `formation_strength_factor = 1.0 + (10-1) × 0.2 = 2.8`:
```
drip_per_tick = floor(7 × 2.8 × 1.0) = floor(19.6) = 19 gold/tick
```

`formation_base_output = 34` vs Economy output of `19 gold/tick`: these are not the same unit. `formation_base_output` is the class-level contribution index (informational / future-systems hook); `drip_per_tick` is the actual gold rate from the Economy formula. The Orchestrator's integration contract between these two values is resolved in the Dungeon Run Orchestrator GDD (#13). This GDD declares the per-hero values; the Orchestrator GDD owns the aggregation logic.

**Sanity check — L1 baseline:**
```
warrior L1 tick output = 2 + 1 × 0 = 2
mage L1 tick output    = 3 + 1 × 0 = 3
rogue L1 tick output   = 2 + 1 × 0 = 2
formation_base_output at L1 = 7
```
Floor 3 BASE_DRIP = 7. The L1 formation base output equals the floor 3 base drip — this is calibrated intentionally so the per-hero tick output values represent "one hero's contribution to the base floor income at L1."

---

### D.4 Sanity Table — Expected Stats at Key Levels

QA verifies these exact values for all three MVP classes. Any computed stat deviating from this table by more than ±1 (rounding edge) is a formula bug.

**Warrior** (`base_attack=12, attack_per_level=2` | `base_hp=120, hp_per_level=17` | `base_speed=6, speed_per_level=1`):

| Level | Attack | HP | Speed | Tick Output |
|---|---|---|---|---|
| 1 | 12 | 120 | 6 | 2 |
| 5 | 20 | 188 | 10 | 6 |
| 10 | 30 | 273 | 15 | 11 |
| 15 | 40 | 358 | 20 | 16 |

*(Attack L5: 12+8=20. HP L5: 120+68=188. Speed L5: 6+4=10. Tick L5: 2+4=6.)*

**Mage** (`base_attack=20, attack_per_level=3` | `base_hp=70, hp_per_level=10` | `base_speed=10, speed_per_level=1`):

| Level | Attack | HP | Speed | Tick Output |
|---|---|---|---|---|
| 1 | 20 | 70 | 10 | 3 |
| 5 | 32 | 110 | 14 | 7 |
| 10 | 47 | 160 | 19 | 12 |
| 15 | 62 | 210 | 24 | 17 |

*(Attack L5: 20+12=32. HP L5: 70+40=110. Speed L5: 10+4=14. Tick L5: 3+4=7.)*

**Rogue** (`base_attack=14, attack_per_level=2` | `base_hp=55, hp_per_level=8` | `base_speed=16, speed_per_level=2`):

| Level | Attack | HP | Speed | Tick Output |
|---|---|---|---|---|
| 1 | 14 | 55 | 16 | 2 |
| 5 | 22 | 87 | 24 | 6 |
| 10 | 32 | 127 | 34 | 11 |
| 15 | 42 | 167 | 44 | 16 |

*(Attack L5: 14+8=22. HP L5: 55+32=87. Speed L5: 16+8=24. Tick L5: 2+4=6.)*

**L15 / L1 growth ratios:**

| Class | Attack ratio | HP ratio | Speed ratio |
|---|---|---|---|
| Warrior | 40/12 = 3.33× | 358/120 = 2.98× | 20/6 = 3.33× |
| Mage | 62/20 = 3.10× | 210/70 = 3.00× | 24/10 = 2.40× |
| Rogue | 42/14 = 3.00× | 167/55 = 3.04× | 44/16 = 2.75× |

All ratios are within the 2.75–3.33× range targeted by the prompt's "~3× stronger at L15" design intent. No stat grows faster than 3.33× — no hidden power spike at max level.

---

## E. Edge Cases

### E.1 Class Resource Missing at Runtime (UNAVAILABLE state)

**Scenario**: `DataRegistry.resolve("classes", "warrior")` returns `null` because `warrior.tres` is absent from the build.

**Behavior**: This system declares the `null` contract but does not own the recovery path. Per the Data Loading GDD, `DataRegistry` logs a `push_error` and returns `null`. Each consumer is responsible for null-checking: the Hero Roster must treat a null `HeroClass` as an unresolvable hero instance and mark that hero as unavailable in the roster (not crash). The Recruitment Screen must not offer unresolvable classes for purchase. The Formation Assignment System must not allow a hero with a null class into a formation slot.

This GDD's contract: if `DataRegistry.resolve("classes", id)` returns a non-null resource, all fields on that resource are guaranteed populated (schema validation at load time). Consumers may assume non-null = fully valid.

### E.2 Level Exceeds LEVEL_CAP

**Scenario**: `stat_at_level("attack", warrior_data, 20)` is called with `level = 20 > LEVEL_CAP (15)`.

**Behavior**: Clamp the input level before applying the formula:
```
effective_level = clamp(level, 1, LEVEL_CAP)
stat = class_data[base_stat] + class_data[stat_per_level] × (effective_level - 1)
```
Result: `stat_at_level("attack", warrior_data, 20)` returns the same value as `stat_at_level("attack", warrior_data, 15)` = 40. No error is logged for this case — callers (particularly the Hero Leveling System) may pass `current_level + 1` to preview next-level stats without bounds-checking at the call site.

### E.3 Level 0 or Negative

**Scenario**: `stat_at_level("hp", mage_data, 0)` is called.

**Behavior**: Invalid input. Log `push_error("stat_at_level called with invalid level: 0")` and return `class_data.base_hp` (Level 1 stat) as a safe fallback. Do not return 0 or negative values — the consumer (display layer) would show impossible stats.

### E.4 New V1.0 Class Added Mid-Save (Patch Adds Cleric)

**Scenario**: Player has an existing save with a Warrior L8, Mage L5, Rogue L6. A V1.0 patch adds `cleric.tres` to `assets/data/classes/`. Player loads the save.

**Behavior**: `DataRegistry` automatically discovers `cleric.tres` on startup and registers `"cleric"` as a LOADED resource. The player's existing roster is unaffected (it contains no Cleric heroes). The Recruitment System now offers the Cleric for purchase at `BASE_RECRUIT[tier_2]` cost. No migration step required; no existing hero data changes. The Cleric's `status: planned_v1` marker in this GDD is a design-time annotation only — the runtime reads only the resource fields; the `status` comment is not in the `.tres` schema.

### E.5 Two Classes Sharing the Same `counter_archetype`

**Scenario**: Post-V1.0 design evolution adds a second class that also counters `"bruiser"`. Two classes now have `counter_archetype = "bruiser"`.

**Behavior**: This GDD explicitly permits this — the Matchup Resolver owns the formation-level aggregation logic and must handle it. The Class DB has no constraint against duplicate archetype values; that would be an enum enforcement that belongs in the Matchup Resolver's validation. From this GDD's perspective, multiple classes countering the same archetype creates an intentional design option (e.g., a "bruiser-buster" formation build) — and under the majority-threshold aggregation rule (Resolver GDD #10 Rule 6, revised 2026-04-19) doubling a counter class is now load-bearing for crossing the threshold in larger formations. The Matchup Resolver GDD documents the majority-threshold rule and that crossing the threshold yields one application of 1.5× (not 1.5× per qualifying hero).

### E.6 `tick_output_contribution_l1 = 0` (Support Class)

**Scenario**: Cleric stub has `tick_output_contribution_l1 = 0`. The Orchestrator's `formation_base_output` includes a hero contributing 0 per tick.

**Behavior**: `hero_tick_output(cleric_data, any_level) = 0 + cleric_data.tick_output_per_level × (level - 1)`. If `tick_output_per_level` is also 0, this hero always contributes 0 to `formation_base_output`. This is valid. The Economy's drip formula is not disrupted because it operates on `formation_strength_factor` (derived from `avg_formation_level` per Hero Roster GDD #9, not from per-class tick output). A zero-output hero still counts toward the `avg_formation_level` calculation (its `current_level` is included in the mean) and may contribute to `formation_strength_factor` through that path. The Orchestrator must not divide by formation size to compute per-hero average in a way that would error on a zero-output hero.

### E.7 Flavor Text Over 120 Characters

**Scenario**: A class is authored with a 150-character `flavor_text`.

**Behavior**: The GDD defines 120 characters as a soft limit. The `.tres` schema does not enforce length — GDScript `String` is unbounded. The UI Roster Card truncates display at 120 characters with an ellipsis (`…`). This is a content quality concern; catch it during asset review, not at runtime. Data validation during the build pipeline may optionally emit a warning, not an error.

### E.8 Art Asset Path Missing

**Scenario**: `warrior.tres` has `icon_path = "assets/art/heroes/warrior/icon.png"` but the file does not exist in the build.

**Behavior**: This is a data integrity / build pipeline issue, not a runtime behavior of the Hero Class Database system. The Data Loading GDD's schema validation does not check that asset paths resolve to actual files — it validates that the field is non-empty. Runtime: Godot's resource loader will return a fallback (pink placeholder or engine default) if the path resolves to nothing. Flag during QA asset review. The Class DB's contract is that paths are structurally correct (matching the `assets/art/heroes/{id}/` convention); file existence is the art pipeline's responsibility.

### E.9 Class with All Stats = 0

**Scenario**: A future mechanic or buff-only class has `base_attack = 0`, `base_hp = 0`, `base_speed = 0`.

**Behavior**: Formulas still execute without error (`0 + per_level × (level - 1)` is valid). The Combat Resolution System must handle a hero with 0 HP without division-by-zero in any survival calculation. The Formation Assignment UI must display the stat as `0`, not hide or error. This case is intentional-forward-compatible: a purely buff-based class (e.g., a Tactician variant that provides no direct combat output) should be representable in the schema. Document as "all-zero stats = buff-only class; Combat Resolution must treat it as a passive formation member."

---

## F. Dependencies

### Upstream Dependencies

| Upstream | Hard/Soft | Interface |
|---|---|---|
| **Data Loading System** (`design/gdd/data-loading.md`) | Hard | `DataRegistry.resolve("classes", id) -> HeroClass \| null`; `DataRegistry` loads `assets/data/classes/*.tres` at boot; filename-independent stable `id` contract; schema validation per Data Loading Rule 4 |

### Downstream Dependents

| Consumer | Hard/Soft | Interface | What they read |
|---|---|---|---|
| **Hero Roster** (#9, undesigned) | Hard | Reads full stat block at hero instance creation | All fields; computes live stats via `stat_at_level()` |
| **Class-vs-Enemy Matchup Resolver** (#10, undesigned) | Hard | Calls `is_class_counter(class, enemy_archetype)` per formation-vs-dungeon check | `counter_archetype` field only |
| **Combat Resolution** (#11, undesigned) | Hard | Reads live stats via Hero Roster (not Class DB directly) | `base_attack/hp/speed` + `*_per_level` + hero level from Roster |
| **Dungeon Run Orchestrator** (#13, undesigned) | Hard | Reads `tick_output_contribution_l1` + `tick_output_per_level` per hero; sums to `formation_base_output` | Per-hero tick output fields |
| **Recruitment System** (#14, undesigned) | Hard | Reads `tier` for `BASE_RECRUIT[tier]` Economy lookup; reads `id` for copy-count check | `tier`, `id` |
| **Hero Leveling System** (#15, undesigned) | Hard | Reads `tier` for `BASE_LEVEL[tier]` Economy lookup | `tier`, `id`, level cap |
| **Formation Assignment System** (#17, undesigned) | Hard | Reads `role`, `counter_archetype`, art refs for slot UI | `id`, `role`, `counter_archetype`, `icon_path` |
| **Recruit Screen** (#21, undesigned) | Soft | Displays `display_name`, `flavor_text`, portrait | `display_name`, `flavor_text`, `portrait_path`, `tier` |
| **Roster / Hero Detail Screen** (#22, undesigned) | Soft | Displays full stat block | Full resource |
| **Enemy Database** (#7, undesigned) | Hard — reverse | This GDD **declares the archetype tag strings** (`bruiser`, `caster`, `armored`, plus V1.0 tags) that Enemy Database resources must use | `EnemyArchetypes` constant set from C.2 |
| **Class Synergy System** (#32, V1.0 first-pass 2026-05-09) | Hard — read-only | Reads `class_id` strings ("warrior", "mage", "rogue") for the V1.0 first-pass synergy detection multiset comparison. The 3 first-pass synergies (Steel Wall, Arcane Elite, Triple Threat) are keyed by exact class_id multisets. Per `class-synergy-system.md` §C.1 + §D.1. | `class_id` (stable identifier) |
| **Prestige System** (#31, V1.0 first-pass 2026-05-09) | Hard — read-only via resolver | Hall of Retired Heroes renders `RetiredHeroRecord.class_id` strings via `HeroClassDatabase.resolve_or_default(class_id) -> HeroClass` (existing). Defensive fallback: if a future class_id removal orphans existing Hall portraits, the resolver returns a "Retired Hero (Class Lost)" placeholder per `prestige-system.md` §E.8. | `class_id` resolver + portrait/icon paths |

### Bidirectional Consistency

- `design/gdd/data-loading.md` lists Hero Class Database as a hard dependent ✅ (via `DataRegistry.resolve("classes", id)` interface)
- All undesigned downstream GDDs must cite "depends on Hero Class Database" when authored. Their schemas must respect `counter_archetype` tag set + the `HeroClass` stat field names defined here.
- **Cross-GDD pact with Enemy Database (#7)**: Enemy Database's `archetype` field must use one of the strings defined in C.2's `EnemyArchetypes` constants. If Enemy Database GDD is authored first, it MUST use these strings verbatim; adding a new archetype requires updating both GDDs + this constant file.

---

---

## G. Tuning Knobs

Every numeric value on every class lives in its `.tres` file in `assets/data/classes/`. The `.tres` files are the tuning knobs — that is the point of data-driven design. Pull them in the Godot editor; change a value; re-run. No recompile needed.

The following knobs are called out explicitly because they have outsized balance impact or because their inter-relationships are non-obvious.

### Primary Per-Class Knobs (9 base stats + 9 per-level scalings + 6 tick output values = 24 total)

**Base stats — Category: Feel** (tuned through playtest intuition; affect moment-to-moment combat feel)

| Knob | Class | Default | Safe Range | What it affects | Risk if pushed high | Risk if pushed low |
|---|---|---|---|---|---|---|
| `base_attack` | Warrior | 12 | 8 – 20 | How fast the Warrior kills enemies at L1 | Warrior dominates early floors; Mage's high-attack identity erodes | Warrior feels useless on floor 3+ enemies before leveling |
| `base_hp` | Warrior | 120 | 80 – 200 | Warrior durability at L1; formation survivability | Tank fantasy cemented, but HP difference from Mage/Rogue feels absurd at low level | Warrior not meaningfully tankier than Rogue; role silhouette lost |
| `base_speed` | Warrior | 6 | 4 – 10 | Action frequency; how often Warrior acts per combat cycle | Warrior acts too often; loses "slow and steady" identity | Warrior barely acts; feel of low contribution |
| `base_attack` | Mage | 20 | 14 – 30 | Glass cannon identity; burst output | Mage single-handedly clears all early content; Warrior/Rogue feel unnecessary | Mage no longer feels like a striker; hard to justify recruiting over Warrior |
| `base_hp` | Mage | 70 | 50 – 100 | Fragility that pushes the player toward Warrior pairing | Player ignores Warrior entirely; Mage isn't squishy enough to need protection | Mage dies too fast on floor 1; frustrating before player understands formations |
| `base_speed` | Mage | 10 | 7 – 15 | Medium-cadence striker feel | Mage acts as often as Rogue; speed identity lost | Mage barely acts despite high attack; output feels inconsistent |
| `base_attack` | Rogue | 14 | 10 – 20 | Moderate per-hit attack against armored enemies | Rogue's attack approaches Mage's; precision identity requires differentiation | Rogue must rely entirely on speed to deal damage; slow floors |
| `base_hp` | Rogue | 55 | 35 – 80 | Squishiness; requires Warrior protection | Rogue survives independently; "protect me" design intent lost | Rogue dies in one hit; formation dependency is frustrating, not interesting |
| `base_speed` | Rogue | 16 | 12 – 24 | Action frequency; the Rogue's defining trait | Rogue acts 3× Warrior rate; feels chaotic | Rogue speed barely exceeds Mage; precision-class identity flattens |

**Per-level scalings — Category: Curve** (tuned through mathematical modeling; affect progression feel across 14 levels)

| Knob | Class | Default | Safe Range | What it affects |
|---|---|---|---|---|
| `attack_per_level` | Warrior | 2 | 1 – 4 | Attack growth over 14 levels. At default: L1=12, L15=40 (3.33× growth) |
| `hp_per_level` | Warrior | 17 | 10 – 28 | HP growth. At default: L1=120, L15=358 (2.98×) |
| `speed_per_level` | Warrior | 1 | 0 – 2 | Speed growth. Lower than Rogue intentionally; keeps Warrior slow even at L15 |
| `attack_per_level` | Mage | 3 | 2 – 5 | Mage's attack diverges from Warrior/Rogue over levels; striker identity strengthens |
| `hp_per_level` | Mage | 10 | 7 – 16 | HP growth. At default: L15=210 (3.0× — exact target) |
| `speed_per_level` | Mage | 1 | 0 – 2 | Same as Warrior; Mage's speed advantage is in base, not growth |
| `attack_per_level` | Rogue | 2 | 1 – 4 | Same per-level as Warrior; Rogue's advantage is speed, not attack growth |
| `hp_per_level` | Rogue | 8 | 5 – 14 | HP growth stays lowest; fragile even at L15 (167 vs Warrior's 358) |
| `speed_per_level` | Rogue | 2 | 1 – 4 | 2× other classes — the Rogue's speed diverges sharply at high levels; this is intentional |

**Tick output — Category: Curve** (affect the Economy integration; these are the per-hero hook into the Dungeon Run Orchestrator)

| Knob | Class | Default | Notes |
|---|---|---|---|
| `tick_output_contribution_l1` | Warrior | 2 | Baseline output. Sum of L1 formation (Warrior+Mage+Rogue) = 7, matching floor 3 BASE_DRIP |
| `tick_output_contribution_l1` | Mage | 3 | Slightly higher at L1; Mage contributes disproportionately to early formation output |
| `tick_output_contribution_l1` | Rogue | 2 | Same as Warrior at L1; speed advantage reflected in combat speed, not tick output |
| `tick_output_per_level` | Warrior | 1 | Linear; at L15 = 16 |
| `tick_output_per_level` | Mage | 1 | Linear; at L15 = 17 |
| `tick_output_per_level` | Rogue | 1 | Linear; at L15 = 16 |

**Role taxonomy — Category: Gate** (the role string itself is not numeric, but its value set is a design gate):

The role taxonomy (`tank`, `striker`, `precision`, `support`, `ranged`, `commander`) is a closed enum in the design. In the `.tres` file it is a `String` field, not an `@export_enum`. This is intentional: a hard enum prevents adding roles without a code change, which would block future classes. The tradeoff is that typos are possible. Mitigation: the Data Loading System should validate `role` against the known list at load time and `push_warning` on an unrecognized value. Do not hardcode enum validation in GDScript beyond the Data Loading validation step — adding a new role in V2.0 should only require the new class's `.tres` and a one-line update to the validation list.

### First-Playtest Tuning Pass Order (highest leverage knobs for Hero Class DB):

1. `base_speed` (all classes) — speed hierarchy is the most perceptible stat in combat feedback; tune until Rogue feels "quick," Warrior feels "deliberate"
2. `base_hp` (Warrior) — Warrior's durability relative to Mage/Rogue determines whether the player learns formation synergy naturally (must protect Mage/Rogue) or ignores it (everyone survives anyway)
3. `attack_per_level` (Mage, 3) — verify Mage's attack divergence from Warrior at L8-10 feels like a meaningful striker payoff, not just a bigger number
4. `tick_output_contribution_l1` (all classes) — verify `formation_base_output` sums correctly per Orchestrator's drip computation; adjust if floor income feels off after Orchestrator GDD is authored

---

## H. Acceptance Criteria

All criteria use Given-When-Then format. 12 criteria total (10 BLOCKING + 2 ADVISORY).

### H-01 — All 3 MVP Classes Resolvable (Integration, BLOCKING)

**GIVEN** Data Loading System is `READY` with full MVP `assets/data/classes/` content (Warrior, Mage, Rogue `.tres`),
**WHEN** `DataRegistry.resolve("classes", id)` is called for `"warrior"`, `"mage"`, `"rogue"`,
**THEN** each returns non-null `HeroClass`; `resource.id` matches query; `resource.tier == 1` for all three; `resource.display_name` non-empty; no error logged.

*Verification*: integration test in `tests/integration/class-db/`.

### H-02 — Stat Scaling at L15 (Logic, BLOCKING)

**GIVEN** a `HeroClass` resource with `base_{stat}` and `{stat}_per_level` for each of {attack, hp, speed}, parameterized for Warrior / Mage / Rogue,
**WHEN** `stat_at_level(stat, class, 15)` is called for all 9 (3 stats × 3 classes) sub-cases,
**THEN** result equals exactly `base + per_level × 14` using integer arithmetic; values match the Section D.4 sanity table exactly (Warrior L15 attack=40, hp=358, speed=20; Mage L15 attack=62, hp=210, speed=24; Rogue L15 attack=42, hp=167, speed=44).

*Verification*: parameterized unit test; 9 sub-cases.

### H-03 — Stat Scaling Clamped at Level Cap (Logic, BLOCKING)

**GIVEN** `LEVEL_CAP = 15`,
**WHEN** `stat_at_level(stat, class, 16)` and `stat_at_level(stat, class, 100)` are called,
**THEN** both return identical values to `stat_at_level(stat, class, 15)`; no error logged (silent clamp); callers may safely pass `current_level + 1` for next-level preview.

### H-04 — Invalid Level Input (Logic, BLOCKING)

**GIVEN** a valid `HeroClass` resource,
**WHEN** `stat_at_level(stat, class, 0)` or `stat_at_level(stat, class, -5)` is called,
**THEN** `push_error` is called with a message containing the invalid level value; function returns L1 stats (base value) as safe fallback; no crash; callers can safely consume L1 fallback.

*Verification*: unit test asserting `push_error` via GDUnit4 + return equals base stat.

### H-05 — counter_archetype Valid and Unique (Logic, BLOCKING)

**GIVEN** all 3 MVP class resources loaded,
**WHEN** each resource's `counter_archetype` is read,
**THEN** every value is non-empty and a member of `["bruiser", "caster", "armored"]`; no two MVP classes share a `counter_archetype`; specifically Warrior=`"bruiser"`, Mage=`"caster"`, Rogue=`"armored"`.

### H-06 — is_class_counter Returns Correct Boolean (Logic, BLOCKING)

**GIVEN** Warrior with `counter_archetype = "bruiser"`,
**WHEN** `is_class_counter(warrior, "bruiser")` and `is_class_counter(warrior, "caster")` are called, plus edge cases (empty string, unknown tag),
**THEN** first returns `true`; second returns `false`; empty string returns `false` without error; unknown tag returns `false` without error; function reads only `class.counter_archetype`.

### H-07 — Save File Class References Resolve (Integration, BLOCKING)

**GIVEN** a save file containing serialized class id references (`"warrior"`, `"mage"`, `"rogue"`) as hero roster entries,
**WHEN** `DataRegistry.resolve("classes", id)` is called during session restore,
**THEN** all three return the same resource objects as fresh boot (Godot resource cache consistency); `resource.tier == 1` cross-checks against Economy's `BASE_RECRUIT[tier_1] = 150`; no `null` for any MVP id.

### H-08 — tick_output Scales Linearly (Logic, BLOCKING)

**GIVEN** any `HeroClass` with `tick_output_contribution_l1` and `tick_output_per_level`,
**WHEN** `hero_tick_output(class, L)` is computed for L = 1..15,
**THEN** each value equals `tick_output_contribution_l1 + tick_output_per_level × (L - 1)`; delta between consecutive levels is constant and equals `tick_output_per_level`; no compounding (linear only — distinguishes from Economy's geometric cost curves).

### H-09 — V1.0 Stubs Load but Filtered from MVP Pool (Logic, BLOCKING)

**GIVEN** the 3 V1.0 stub class resources (Cleric, Ranger, Tactician) present with `tier = 2`,
**WHEN** `DataRegistry.resolve("classes", id)` is called for each stub id, and `HeroClassDB.get_recruitable_classes()` is called,
**THEN** each stub `resolve()` succeeds (stubs loadable); `get_recruitable_classes()` returns only the 3 MVP classes (Tier 1); the 3 stubs absent from recruitable list; filter contract: `resource.tier == 1` for MVP builds.

*Contract clarification*: filter by `tier`, not a separate `status` field — keeps schema minimal.

### H-10 — Economy BASE_RECRUIT Cross-System Consistency (Integration, BLOCKING)

**GIVEN** MVP class resources declaring `tier = 1`, Economy config declaring `BASE_RECRUIT[tier_1] = 150`,
**WHEN** recruitment cost computed for first copy of any MVP class via Economy's `recruit_cost(class.tier, 0)`,
**THEN** result is exactly 150 gold; no MVP class returns a different cost on first purchase; `tier` field is the sole input — no class-specific cost override exists.

*Purpose*: Catches the silent regression where a designer changes a class `tier` without updating Economy.

### H-11 — flavor_text Under Character Limit (Config/Data, ADVISORY)

**GIVEN** all 6 class resources (3 MVP + 3 V1.0),
**WHEN** each `flavor_text` is read at load time,
**THEN** every non-empty value ≤ **120 characters** (soft limit per C.1 schema); content-validation smoke check reports overrun as warning (not fatal).

*Gate = ADVISORY*: long flavor text truncates with ellipsis in UI; not a runtime failure.

### H-12 — Unique Silhouette Requirement (Visual/Feel, ADVISORY — Manual Test)

**GIVEN** finalized sprite art for Warrior, Mage, Rogue,
**WHEN** the 3 class silhouettes are displayed grayscale at 32px,
**THEN** QA tester + art director identify each class by silhouette alone within 3 seconds, without color/label cues; sign-off recorded in `production/qa/evidence/class-silhouette-[date].md` with screenshot + both reviewer names.

*Gate = ADVISORY*: art-bible-validated, not code-testable. Sign-off document is Done evidence.

### Classification Summary

| ID | Description | Type | Gate |
|---|---|---|---|
| H-01 | All 3 MVP classes resolvable | Integration | BLOCKING |
| H-02 | Stat scaling at L15 (9 sub-cases) | Logic | BLOCKING |
| H-03 | Stat scaling clamped at cap | Logic | BLOCKING |
| H-04 | Invalid level input → error + L1 fallback | Logic | BLOCKING |
| H-05 | counter_archetype valid, unique per class | Logic | BLOCKING |
| H-06 | is_class_counter correct boolean | Logic | BLOCKING |
| H-07 | Save file class references resolve | Integration | BLOCKING |
| H-08 | tick_output scales linearly | Logic | BLOCKING |
| H-09 | V1.0 stubs loaded but filtered from MVP | Logic | BLOCKING |
| H-10 | Economy BASE_RECRUIT tier consistency | Integration | BLOCKING |
| H-11 | flavor_text ≤ 120 chars | Config/Data | ADVISORY |
| H-12 | Unique silhouette | Visual/Feel | ADVISORY |

---

## I. Open Questions

| Question | Owner | Target Resolution |
|---|---|---|
| `formation_strength_factor` vs `formation_base_output` — the Dungeon Run Orchestrator GDD (#13) must confirm which of these two values drives `get_current_drip_per_tick()`, and how per-hero tick output feeds into the Economy's BASE_DRIP × factor formula. This GDD declares both values; Orchestrator GDD owns the integration contract. | game-designer + systems-designer (during Orchestrator GDD) | Before Combat Resolution GDD (#11) |
| `tick_output_per_level` for Cleric — if Cleric has `tick_output_contribution_l1 = 0`, should `tick_output_per_level` also be 0 (truly passive) or > 0 (gains output as it levels, representing growing holy power)? This is a V1.0 design question. | game-designer | During Cleric class design (V1.0 pass) |
| Role taxonomy enforcement — should `role` be a GDScript `@export_enum` (preventing typos at cost of code changes for new roles) or a validated `String` (flexible, validated at load)? Recommend validated String; confirm with lead-programmer before implementation. | game-designer + lead-programmer | Before Hero Roster GDD (#9) |
| Speed stat units — "action cadence" is intentionally underspecified here pending Combat Resolution GDD. Does `speed` map to a cooldown duration, a probability-weighted turn, or a tick-rate multiplier? This GDD sets the base values; Combat Resolution owns the formula that consumes them. | systems-designer (during Combat Resolution GDD #11) | Before Combat Resolution GDD |
