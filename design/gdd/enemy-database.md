# Enemy Database GDD — Lantern Guild

> **GDD #6 in design order** (System #7 in systems index)
> **Status**: Designed (pending independent review)
> **Created**: 2026-04-18
> **Last Updated**: 2026-04-19
> **Authors**: game-designer + systems-designer + qa-lead + main session
> **Depends on**: `design/gdd/data-loading.md` (GDD #2), `design/gdd/hero-class-database.md` (GDD #5)
> **Referenced by**: Biome & Dungeon Database (#8), Class-vs-Enemy Matchup Resolver (#10), Combat Resolution System (#11), Dungeon Run Orchestrator (#13)
> **Implements Pillar**: Pillar 2 (Every Class Feels Distinct — enemy design telegraphs counter class), Pillar 3 (Matchup Is a Decision — single archetype tag per enemy drives the 1.5× bonus)
> **Art Bible**: Forest Reach materials, palette, and silhouette scale rules (Sections 5–6)
> **Creative Director Review (CD-GDD-ALIGN)**: SKIPPED — Solo review mode

---

## A. Overview

The Enemy Database is the static content layer for all enemy archetypes in *Lantern Guild*. It defines the `EnemyData` `.tres` schema, provides eight MVP enemy stat blocks (all Forest Reach biome, Tiers 1–3), and establishes the archetype distribution invariant that guarantees every floor-tier offers a counter opportunity for each of the three MVP hero classes. Enemies are read-only data resources loaded at boot by the Data Loading System and queried at formation-assignment time by the Biome & Dungeon Database, Matchup Resolver, and Combat Resolution System.

Enemies are simpler than hero classes by design: no leveling, no resistances, no per-enemy loot overrides in MVP. The schema exposes `base_hp`, `base_attack`, and `base_speed` as forward-compatible hooks for Combat Resolution, along with a single `archetype` tag that drives the Matchup Resolver's counter check. Art direction fields (`sprite_path`, `death_anim_key`) and flavor text complete the schema. The goal is the minimum data surface area needed to make every enemy feel Forest-Reach-rooted, mechanically legible, and counter-class-visible at a glance.

---

## B. Player Fantasy

The Enemy Database serves **threat-legibility** and **counter-fantasy** — two halves of the same cozy-strategic pleasure.

**Threat-legibility**: the player glances at a dungeon floor's enemy preview and understands the challenge in under three seconds. "Three bruisers on Floor 1" immediately reads as "send the Warrior." This is the Pillar 3 hook in sensory form — matchup decisions happen at the assignment layer, and the visual language has already done most of the strategic work before the player touches the formation screen.

**Counter-fantasy**: the slight thrill when a dispatched Rogue formation meets a Vined Knight and the matchup bonus fires on the kill — +17 gold instead of +35. The delta is small but legible, and the player *feels clever* for having recruited the right specialist. The art bible's "cozy register" constraint shapes this: enemies are threatening enough to matter (mass, scale, joint gaps, orbs) but never alarming (no needle-sharp spines, no pure-saturated red warnings, no horror imagery). A player opening the app during a lunch break sees a Forest Reach dungeon and feels *invited to plan*, not stressed.

The indirect fantasy this supports: **"my guild understands this forest."** Every enemy archetype the player learns — bruiser, caster, armored — adds to the sense that they are mastering a miniature world whose rules are learnable and generous.

---

## C. Detailed Design

### C.1 Enemy Resource Schema

Each enemy is a `GameData` subclass (GDScript: `class_name EnemyData extends GameData`) stored as a `.tres` file in `assets/data/enemies/`. `GameData` is the `@abstract` (Godot 4.5+) base class defined per ADR-0006 — it provides the universal `id: String` + `display_name: String` fields and prevents direct instantiation of the base. The Data Loading System loads the concrete subclass via `DataRegistry.resolve("enemies", id)`.

**Field set:**

| Field | Type | Description |
|---|---|---|
| `id` | `String` | Snake_case unique identifier (e.g. `"hollow_brute"`). Stable key — filename may change; `id` never changes. Matches the `id` contract from Data Loading GDD. |
| `display_name` | `String` | Human-readable name shown in dungeon floor UI (e.g. `"Hollow Brute"`). |
| `tier` | `int` | 1, 2, or 3. Determines which `BASE_KILL[tier]` constant the Economy System applies on kill. |
| `archetype` | `String` | The single enemy archetype tag. Must exactly match one of the three MVP constants (`"bruiser"`, `"caster"`, `"armored"`). The Matchup Resolver reads this field only. |
| `biome` | `String` | Biome affiliation. All MVP enemies: `"forest_reach"`. Included as a forward-compatibility hook for Biome & Dungeon DB floor composition and future biome expansions. |
| `base_hp` | `int` | HP at the point of encounter. Not leveled — enemies do not scale with hero level. Fixed per encounter as defined in stat blocks (C.3). |
| `base_attack` | `int` | Attack value. Combat Resolution reads this to compute damage per hit against the formation. Fixed per encounter. |
| `base_speed` | `int` | Action cadence forward-declaration. Same forward-decl pattern as hero classes — Combat Resolution GDD (#11) owns the consuming formula. Declared now so the data surface is consistent; speed hierarchy is established (boss slowest, casters fastest). |
| `sprite_path` | `String` | Path to the enemy's sprite sheet. Convention: `assets/art/enemies/{id}/sprite.png`. |
| `death_anim_key` | `String` | Animation name key played on enemy death. Convention: `"death"` default; overridable for boss death (e.g. `"death_boss"`). Read by the Dungeon Run View screen. |
| `flavor_text` | `String` | Cozy-threatening one-liner shown on floor preview. Soft limit: 120 characters. |
| `is_boss` | `bool` | `true` only for the Floor 5 final enemy (Ancient Rootking). Dungeon Run Orchestrator reads this to trigger boss-death fanfare and floor-clear bonus. |

**Fields intentionally omitted from MVP (with rationale):**

- **Resistances / damage type modifiers**: A resistance system requires Combat Resolution to implement a damage-type lookup table. For a cozy idle game where combat is resolved abstractly, the archetype counter tag (`"armored"` enemy = Rogue counter) already encodes the relevant resistance concept in a legible, single-field form. Separate resistance values would add a tuning dimension that only pays off in games where the player watches combat unfold in real time. Defer to V1.0 if Combat Resolution demands it.
- **Loot table override**: All kill rewards in MVP are driven by `BASE_KILL[tier] × matchup_multiplier` from the Economy System. There is no per-enemy gold override. If a specific enemy needs a different reward rate, that is a tier assignment decision, not a schema change.
- **Leveling / scaling**: Enemies do not level with the player. Tier defines the stat tier; floor composition (Biome & Dungeon DB) determines which tier appears on which floor. Hero progression is the scalar that changes; enemy stats are fixed anchors.
- **Ability / special mechanic slot**: Out of scope for MVP's abstract combat model. V1.0 can add an `ability_key: String` forward hook if special mechanics are needed.

**Contrast with HeroClass schema**: `HeroClass` has 16+ fields including `*_per_level` scaling fields, `tick_output_contribution`, `role`, and three art paths. `EnemyData` has 13 fields, no per-level scaling, no tick output, one art path. This asymmetry is intentional: heroes are persistent entities that grow; enemies are encounter templates that are read once per run.

---

### C.2 Archetype Distribution Policy

**Design invariant:** Every floor-tier must contain at least one enemy matching at least one of the three MVP hero class counter-archetypes (`"bruiser"`, `"caster"`, `"armored"`).

For MVP's eight enemies distributed across five floors:
- **Tier 1 (floors 1–2)**: three enemies — exactly one each of `"bruiser"`, `"caster"`, `"armored"`. All three counter opportunities represented.
- **Tier 2 (floor 3)**: three enemies — exactly one each of `"bruiser"`, `"caster"`, `"armored"`. Full distribution preserved at mid-tier.
- **Tier 3 (floor 4)**: one `"bruiser"` elite. Floor 4 is a single-archetype encounter — the Warrior's moment.
- **Tier 3 (floor 5)**: one `"bruiser"` boss. Floor 5 is the Warrior showcase climax.

**Lock rationale**: The distribution is a design invariant enforced here. The Biome & Dungeon Database (GDD #8) must respect it when composing floor enemy lists. If V1.0 adds enemies, the invariant must be re-checked at V1.0 design time — adding five new enemies to a floor that already has all three archetypes covered is fine; adding five casters to a floor breaks the invariant.

**Floor 4–5 single-archetype decision**: Floors 4 and 5 both use `"bruiser"` because the dungeon arc's climax is the Warrior's showcase. The Mage and Rogue are still useful in Tier-1 and Tier-2 encounters within the same dungeon run; their counter opportunities do not disappear, they are front-loaded. This is consistent with the flow-state design principle of building tension toward a specific resolution moment.

**V1.0 note**: When `"beast"`, `"construct"`, and `"incorporeal"` archetypes are introduced with their corresponding V1.0 classes (Ranger, Tactician, Cleric), the distribution invariant expands to cover all six archetypes. The Biome & Dungeon Database must be updated at that time.

---

### C.3 The 8 MVP Enemies — Full Stat Blocks

**HP calibration methodology:**

Enemy HP is calibrated against the hero attack ranges provided in the design brief, using the "rounds to kill" model:
- **Tier 1** (floors 1–2): fightable by L1–L3 hero formation. Target 5–7 rounds for a solo L1 Warrior (ATK 12). Floor-1 ease-in enemy targets the low end of the range (fast first kill for onboarding). Tier-1 midpoint HP = 62; valid band = 52–72.
- **Tier 2** (floor 3): fightable by L5–L8 formation. Target ~10 rounds for a solo L6 Warrior (ATK 22). Tier-2 midpoint HP = 210; valid band = 168–252 (±20% of midpoint). In practice, three enemies on one floor means each enemy is faced by one hero slot, not a full formation — calibrated accordingly.
- **Tier 3 elite** (floor 4): fightable by L10–L12 formation. Target 15–20 rounds for a L10 Warrior (ATK 30). HP range 500–700.
- **Tier 3 boss** (floor 5): intended for a full L12–L15 formation. At boss HP **4818** (Pass 2B, was 2200) the Combat GDD #11 tick-model locks a 170.05 s clear for an L13 W+M+R neutral-matchup formation (raw DPS 1.417/tick at SPEED_BASE=2400 → `ceili(4818/1.417)=3401` ticks @ 20 Hz). The earlier "rounds-to-kill" framing (~17 rounds at 2200 HP) was superseded by Combat's per-tick cadence. Solo heroes cannot trivially solo the boss (solo L15 Warrior at DPS 0.333: `ceili(4818/0.333) = 14454` ticks ≈ 723 s ≈ 12 min — structurally prohibitive).

**Enemy attack calibration**: Enemy attack is a forward-declaration for Combat Resolution. Calibrated so that a standard formation takes meaningful damage but can survive multiple encounters within a run — enemies are attrition, not one-shots. Exact damage formula is Combat Resolution's contract.

**Silhouette scale**: Per Art Bible Sections 5–6. Tier-1 enemies fit one hero-sprite height. Tier-2 enemies are 1.2–1.5× hero-sprite height. Tier-3 elite is 1.5× height. Tier-3 boss is approximately 2× hero-sprite width, filling the dungeon panel.

---

#### Enemy 1 — Hollow Brute

```yaml
id:              "hollow_brute"
display_name:    "Hollow Brute"
tier:            1
archetype:       "bruiser"
biome:           "forest_reach"
base_hp:         52
base_attack:     8
base_speed:      3
sprite_path:     "assets/art/enemies/hollow_brute/sprite.png"
death_anim_key:  "death"
flavor_text:     "All bark. Literally. Something hollow rattles inside when it walks."
is_boss:         false
```

**HP justification**: 52 HP is the ease-in anchor for Floor 1. A L1 Warrior (ATK 12) kills it in 5 rounds — fast enough to feel responsive in the first session, establishing the "numbers going up" idle-clicker feedback loop quickly. A L1 Mage (ATK 20) kills it in 3 rounds — the Mage's burst identity telegraphed immediately. Floor-1 onboarding intent: the player should see their first kill within the first 30 seconds of a run.

**Silhouette note**: Stout, mass-forward barrel-chest shape. Bark-textured torso with hollow cavity visible at center. Rounded limbs, no spikes — cozy-threatening register. Larger mass than the Shellback or Glowmoth, establishing the bruiser silhouette immediately.

**Counter-class hint**: Warrior-sized silhouette weight (same "physical mass" visual language as the hero it counters against). No orb, no plating — pure brute presence.

---

#### Enemy 2 — Glowmoth

```yaml
id:              "glowmoth"
display_name:    "Glowmoth"
tier:            1
archetype:       "caster"
biome:           "forest_reach"
base_hp:         60
base_attack:     11
base_speed:      5
sprite_path:     "assets/art/enemies/glowmoth/sprite.png"
death_anim_key:  "death"
flavor_text:     "It carries a little orb of light and uses it for everything except being friendly."
is_boss:         false
```

**HP justification**: 60 HP sits at the Tier-1 midpoint. Higher HP than the Hollow Brute because casters have range — the player needs slightly more kill-time to feel the Mage's counter advantage pay off. L1 Mage (ATK 20) kills in 3 rounds (matchup); L1 Warrior (ATK 12) kills in 5 rounds (no counter advantage). The 2-round delta is legible and creates the first "a-ha" moment when the player assigns a Mage against casters.

**Silhouette note**: Winged moth shape, compact body, two large wings. Carries a glowing orb in its forelimbs — the orb is the counter-class hint (spell-user visual cue from Art Bible). Soft yellowy-green bioluminescence on wings per Forest Reach palette (muted, never neon).

**Counter-class hint**: Orb prop visible at 32px sprite size — one of the three Art Bible-required signals (casters carry focus/orb per Section 6).

---

#### Enemy 3 — Shellback

```yaml
id:              "shellback"
display_name:    "Shellback"
tier:            1
archetype:       "armored"
biome:           "forest_reach"
base_hp:         72
base_attack:     9
base_speed:      2
sprite_path:     "assets/art/enemies/shellback/sprite.png"
death_anim_key:  "death"
flavor_text:     "The shell is beautiful. The thing inside is much less interested in your opinion."
is_boss:         false
```

**HP justification**: 72 HP is the highest in Tier 1, reflecting the armored archetype's durability fantasy. A L1 Warrior (ATK 12) takes 6 rounds; a L1 Rogue (ATK 14) takes 6 rounds without counter advantage, 4 rounds with the 1.5× multiplier. The 2-round reduction from matchup advantage is the sharpest proportional delta in Tier 1 — armored enemies are specifically designed to make the Rogue counter feel most mechanically obvious at low levels. Lowest speed (2) reinforces the "heavy and slow" armored archetype feel.

**Silhouette note**: Round beetle carapace shape — chunky, blocky, curves dominant. Shell segments visible with clear joint gaps (Art Bible armored counter-class hint: joint gaps signal Rogue's precision-strike counter). Forest bark and moss texture on shell surface.

**Counter-class hint**: Visible joint gaps between shell plates at all sprite sizes per Art Bible Section 6 requirement.

---

#### Enemy 4 — Elder Boar

```yaml
id:              "elder_boar"
display_name:    "Elder Boar"
tier:            2
archetype:       "bruiser"
biome:           "forest_reach"
base_hp:         195
base_attack:     18
base_speed:      4
sprite_path:     "assets/art/enemies/elder_boar/sprite.png"
death_anim_key:  "death"
flavor_text:     "Ancient. Scarred. Has opinions about trespassers and will share them at speed."
is_boss:         false
```

**HP justification**: 195 HP at the low end of the Tier-2 band (valid band 168–252). The Elder Boar is the first enemy encountered on Floor 3 — placing it at the band's low end gives the player an immediate kill to establish they have grown since Tier 1. A L6 Warrior (ATK 22) kills in ~9 rounds; a L7 Warrior (ATK 24) kills in ~9 rounds — within the 10-round target for pacing. Slightly lower HP than the Vined Knight signals that the bruiser is manageable even without the Warrior counter.

**Silhouette note**: Large boar shape, 1.3× hero-sprite height, heavy shoulder mass forward. Moss-grown tusks, bark-rough hide. Charging posture — mass-forward silhouette establishing the bruiser archetype (Art Bible requirement).

**Counter-class hint**: Mass-forward charging posture mirrors the Warrior's upright combat stance — visual language symmetry between the counter pair.

---

#### Enemy 5 — Moss Druid

```yaml
id:              "moss_druid"
display_name:    "Moss Druid"
tier:            2
archetype:       "caster"
biome:           "forest_reach"
base_hp:         185
base_attack:     24
base_speed:      6
sprite_path:     "assets/art/enemies/moss_druid/sprite.png"
death_anim_key:  "death"
flavor_text:     "Speaks only in spores. Nobody in the guild has found this charming."
is_boss:         false
```

**HP justification**: 185 HP — lowest in Tier 2, reflecting the caster archetype's glass-cannon equivalent. High attack (24) compensates: the Moss Druid hits hard but falls quickly to the Mage counter. A L6 Mage (ATK 38, with matchup multiplier applied to kill reward — not to ATK) kills in ~5 rounds; L6 Warrior kills in ~9 rounds. The Mage's counter advantage here shows up in kill-reward gold (1.5×) rather than in attack power, preserving the abstract combat model.

**Silhouette note**: Tall, thin humanoid draped in hanging moss. Carries a gnarled staff topped with a spore-cap orb (counter-class cue: orb/focus prop). Slightly taller than hero-sprite height — imposing but not massive.

**Counter-class hint**: Orb prop on staff; casting posture (raised staff arm); spell-particle residue around the figure. All three caster cues from Art Bible Section 6.

---

#### Enemy 6 — Vined Knight

```yaml
id:              "vined_knight"
display_name:    "Vined Knight"
tier:            2
archetype:       "armored"
biome:           "forest_reach"
base_hp:         225
base_attack:     20
base_speed:      3
sprite_path:     "assets/art/enemies/vined_knight/sprite.png"
death_anim_key:  "death"
flavor_text:     "The armor grew over time. So did whatever is wearing it."
is_boss:         false
```

**HP justification**: 225 HP — highest in Tier 2, reinforcing the armored archetype's durability. A L6 Rogue (ATK 24) kills in ~9 rounds (no matchup-gold-bonus scenario); with 1.5× kill reward, the player earns 52.5 gold per kill instead of 35 — a tangible economic difference that makes the Rogue assignment decision visible. L6 Warrior (ATK 22) kills in ~11 rounds — slightly above the 10-round target, making the Rogue counter economically attractive without making the Warrior useless.

**Silhouette note**: Humanoid knight silhouette overgrown with vines, 1.4× hero-sprite height. Plate armor with visible joint gaps — vine-filled joints are the Art Bible counter-class hint (gaps between plates signal Rogue's precision attack access). Forest Reach material: iron-gray plates with vine and leaf growth.

**Counter-class hint**: Visible joint gaps at shoulder, elbow, and knee — three clear gap points at dungeon-preview sprite size.

---

#### Enemy 7 — Thorn Guardian

```yaml
id:              "thorn_guardian"
display_name:    "Thorn Guardian"
tier:            3
archetype:       "bruiser"
biome:           "forest_reach"
base_hp:         680
base_attack:     32
base_speed:      5
sprite_path:     "assets/art/enemies/thorn_guardian/sprite.png"
death_anim_key:  "death"
flavor_text:     "Something in the deep forest decided thorns were not enough. It was right."
is_boss:         false
```

**HP justification**: 680 HP for the Tier-3 elite. A L10 Warrior (ATK 30) kills in ~23 rounds; a L12 Warrior (ATK 34) kills in ~20 rounds. Target range was 15–20 rounds — the Thorn Guardian is intentionally at the upper end to create a pre-boss attrition challenge on Floor 4. The player should feel that Floor 4 is genuinely dangerous before reaching the boss. L10 Mage (ATK 47, no counter) kills in ~15 rounds — Mage can handle the bruiser but slower; reinforces Warrior deployment.

**Silhouette note**: Upright bipedal form, 1.5× hero-sprite height. Dense thorn cluster shoulders and arms — thorns curve (never spike, per Art Bible cozy register). Heavy mass-forward stance with root-tendril legs anchoring to ground. Forest Reach bark-and-vine materials throughout.

**Counter-class hint**: Mass-forward stance with no orb, no armor gaps — pure bruiser visual vocabulary. Art Bible: bruisers are identified by their dominant forward mass.

---

#### Enemy 8 — Ancient Rootking

```yaml
id:              "ancient_rootking"
display_name:    "Ancient Rootking"
tier:            3
archetype:       "bruiser"
biome:           "forest_reach"
base_hp:         4818   # Pass 2B (2026-04-20): raised from 2200 per Combat GDD #11 I.Q2 resolution
base_attack:     45
base_speed:      3
sprite_path:     "assets/art/enemies/ancient_rootking/sprite.png"
death_anim_key:  "death_boss"
flavor_text:     "The forest's patience has a name. It has been here longer than the lanterns."
is_boss:         true
```

**HP justification (Pass 2B, 2026-04-20)**: 4818 HP for the Floor 5 boss. Derived directly from Combat GDD #11 D.7 pacing table: at SPEED_BASE=2400 with an L13 W+M+R formation (raw DPS 1.417/tick, neutral matchup because `n=1` per archetype), `ticks_per_loop = ceili(4818 / 1.417) = 3401` ticks → 170.05 s clear — precisely the 170 s target from Biome DB F5. The formula is `ceili(target_seconds × TICKS_PER_SECOND × dps) = ceili(170 × 20 × 1.417) = ceili(4817.8) = 4818`. A specialist W+W+R formation (advantaged against bruiser, factor=1.5) clears the boss in ~137 s — Pillar 3 payoff still audible at the MVP climax. The boss fight remains the single most economically significant kill in the early game. `is_boss: true` triggers the boss-death fanfare signal in the Dungeon Run Orchestrator. Slow speed (3) makes the boss feel ponderous and weighty despite its power.

**Pre-Pass-2B note**: HP was 2200 under the Pass-1 "17-round" game-designer intuition; Combat's tick-model calibration required the cascade to 4818 to hit the 170 s target deterministically. Enemy DB Open Question on this HP (C.3 + I) is **CLOSED** by this Pass 2B revision.

**Archetype choice rationale**: `"bruiser"` for the boss because the Forest Reach arc culminates in a Warrior-vs-giant-brute showcase. This is the most legible boss fantasy for the MVP's three classes: the Warrior was built to fight this creature. The Mage and Rogue remain useful in the formation (high combined attack), but the Warrior's counter advantage earns the 1.5× kill bonus on the boss kill — the single most economically significant kill in the early game.

**Silhouette note**: Ancient tree-creature, approximately 2× hero-sprite width as required by Art Bible scale signal for Tier-3 boss. Roots for legs sprawling outward. Rounded, ancient-wood torso. Canopy of branches and vines forming a crown — imposing but not alarming (curves dominant, no spikes). Environmental storytelling: ground disturbed in a circle around the boss's root-spread.

---

### C.4 Enemy Resource Lifecycle States

Enemies are static data. Same two-state model as HeroClass:

| State | Description | How it is reached |
|---|---|---|
| **LOADED** | `DataRegistry.resolve("enemies", id)` returns a valid, non-null `EnemyData` resource. All fields validated on load. | Normal startup: Data Loading System reads `assets/data/enemies/*.tres` and registers each by its `id` field. |
| **UNAVAILABLE** | Returns `null`. | `.tres` file missing, `id` mismatch, or schema validation failure. |

Schema validation at load time (Data Loading System's responsibility): `tier` in {1, 2, 3}; `archetype` in {`"bruiser"`, `"caster"`, `"armored"`, `"beast"`, `"construct"`, `"incorporeal"`}; `biome` non-empty; `base_hp` > 0; `base_attack` > 0; `base_speed` > 0; `display_name` non-empty; `id` non-empty. Exactly one enemy may have `is_boss: true` in the MVP set.

---

### C.5 System Interactions

| Consumer System | Data Read | Contract |
|---|---|---|
| **Biome & Dungeon Database (#8)** | `id`, `tier`, `archetype`, `biome` | Reads enemy list to compose per-floor encounter pools. Respects the archetype distribution invariant (C.2). Reads `tier` to assign the correct `BASE_KILL` value. |
| **Matchup Resolver (#10)** | `archetype` only | `is_class_counter(class_data, enemy_archetype) -> bool` (canonical name per Class DB D.2 + Resolver Rule 5; do not refer to it as `is_enemy_countered_by`). Resolver reads `enemy.archetype` and compares against `hero_class.counter_archetype`. Formation-level aggregation is the **majority threshold** rule (Resolver Rule 6 + D.2: `n > N/2`). No other fields consumed from this GDD. |
| **Combat Resolution (#11)** | `base_hp`, `base_attack`, `base_speed` | Reads live stats directly from the `EnemyData` resource (enemies do not level; stats are static). No intermediate roster layer needed. |
| **Dungeon Run Orchestrator (#13)** | `id`, `tier`, `is_boss`, `base_hp`, `base_attack` | Spawns enemy instances per floor, resolves combat, emits `enemy_killed(enemy.tier, matchup_advantage)` to Economy. Reads `is_boss` to trigger boss-death fanfare and floor-clear bonus. Awards `BASE_KILL[enemy.tier]` × matchup_multiplier gold per kill. |
| **Enemy sprite rendering (Dungeon Run View #24)** | `sprite_path`, `death_anim_key` | Loads sprite at run start. Plays `death_anim_key` animation on kill event. |

---

### C.6 Systems Integration Notes

*Validation by systems-designer against hero stat ranges (Hero Class DB #5) + Economy kill pacing (#4). Four flags documented.*

**VALIDATE — Rounds-to-kill calibration**:
- **Tier 1** (52–72 HP vs L1 formation attack of 46): 1–2 rounds. The Hollow Brute at 52 HP is a deliberate ease-in (4.3 rounds vs solo L1 Warrior); the 60–72 HP enemies give a 2-3 round feel vs a full formation. Systems-designer flagged the solo-Warrior vs Tier-1 ratio as borderline too fast if the player deploys only one hero — acceptable since Hero Roster's formation slot count is 3.
- **Tier 2** (185–225 HP vs L5 formation 74): 3–4 rounds. **PASS** — inside the 2–8 round sweet spot.
- **Tier 3 elite** (680 HP vs L10 formation 109): 7 rounds solo Warrior; ~15–20 rounds with full formation. **PASS** — floor 4 is designed as pre-boss attrition.
- **Tier 3 boss** (**4818 HP** per Pass 2B, was 2200): Combat GDD #11 tick-model locks 170.05 s clear for L13 W+M+R neutral matchup (raw DPS 1.417/tick, SPEED_BASE=2400). The earlier 17-round framing is legacy; Combat owns the canonical cadence now. **CLOSED 2026-04-20 Pass 2B** per Combat I.Q2 resolution (see Section I below).

**WARN — Enemy attack values are lower than systems-designer's recommended safe ranges**:
- Systems-designer proposed Tier 1 attack 12–15, Tier 2 attack 25–40, Tier 3 attack 50–70.
- Game-designer chose Tier 1 attack 8–11, Tier 2 attack 18–24, Tier 3 attack 32–45.
- **Delta rationale**: The game-designer's lower values reflect the cozy register — hero deaths are de-emphasized in the concept (no fail state per GDD pillar 1). Lower enemy attack means longer survival windows, which suits the session-based idle loop. Systems-designer's ranges would produce more survivability drama but risk one-shotting Rogues at L1 (HP 55 vs attack 20).
- **Disposition**: Kept game-designer's values. First playtest validates "does combat feel like it has stakes?" If yes, ship. If no, raise attack toward systems-designer's recommended band.

**VALIDATE — Gold/round ratio**:
Tier 1: 15 gold ÷ 1.5 rounds = ~10 gold/round. Tier 2: 35 ÷ 3.5 = ~10. Tier 3 elite: 80 ÷ 7 = ~11. Matchup 1.5× adds +50% to the kill bonus component but doesn't alter the rounds-to-kill. **Ratio is consistent across tiers — PASS.** Economy's "1 kill per 10 seconds" pacing assumption in its D.6 model depends on the Dungeon Run Orchestrator's round-to-tick mapping — see Tension 4 below.

**WARN — Round-to-tick cadence is an unresolved cross-system constraint**:
The Dungeon Run Orchestrator (#13, undesigned) must decide: does one "attack round" in the combat model correspond to one 50ms tick, or to multiple ticks (e.g., 5 ticks = 250ms per round)? This GDD's rounds-to-kill calibration assumes **1 round = 200 ticks = 10 seconds** (matching Economy's 1 kill per 10 sec pacing). If Orchestrator chooses a different cadence, the HP values in this GDD need recalibration. **Flagged as Open Question — this GDD's numbers are provisional until Orchestrator confirms.**

**RECOMMEND — Floor 5 boss archetype tension**:
Systems-designer flagged risk: pure-bruiser Ancient Rootking means Mage- or Rogue-focused players earn no matchup bonus on the MVP finale. Alternative was multi-archetype (e.g., bruiser+caster) so Matchup Resolver could trigger on any counter. Game-designer kept pure bruiser per explicit "Warrior showcase climax" intent. **Compromise**: Floor 5 is the Warrior's showcase, but the formation's Mage and Rogue still contribute raw DPS (46 of 130 formation attack at L13 comes from Warrior alone — Mage+Rogue contribute 74, the majority). The matchup-gold delta on the boss is 40 gold — significant but not the dominant income source. **Flagged as Open Question — playtest validates whether Mage/Rogue-focused players feel their investment matters on Floor 5.**

---

## D. Formulas

### D.1 Enemy Kill Reward

**Reference only — do not redefine.** The authoritative formula lives in `design/gdd/economy-system.md` Section D.2.

```
gold_awarded_on_kill = kill_bonus(enemy.tier) × matchup_multiplier
```

Where:
- `kill_bonus(tier)` is **deprecated in favour of Orchestrator's `attribute_kill_gold(tier, advantaged, losing_run)`** (Pass 4B-Economy A4 2026-04-20 — see Economy review log). Reference-only values: `BASE_KILL[1] = 10`, `BASE_KILL[2] = 35`, `BASE_KILL[3] = 80` (Pass 4B-Economy A3 reconciled `BASE_KILL[1]` 15→10). Orchestrator is the canonical gold-attribution call-site.
- `matchup_multiplier` = `1.5` if the dispatched formation crosses the **majority threshold** for `enemy.archetype` — i.e. more than `formation.size() / 2` heroes have `counter_archetype == enemy.archetype` (for MVP `FORMATION_SIZE = 3`, that means at least 2 of 3 slots counter); else `1.0`. Aggregation is per-kill / per-archetype and owned by the Matchup Resolver (Resolver GDD #10 Rule 6 + D.2). The threshold rule replaced an earlier "at least one counter" model on 2026-04-19.
- Output range: `5` (Tier-1, no matchup, LOSING) to `120` (Tier-3, matchup advantage, non-LOSING: `80 × 1.5 × 1.0 = 120`). Non-LOSING non-matchup Tier-1 = 10.

**Worked example — all-Warrior formation (W+W+W, N=3) vs. Hollow Brute (Tier 1, bruiser):**
```
n = 3 (all three Warriors counter "bruiser") → n > N/2 (3 > 1) → threshold crossed → matchup_multiplier = 1.5
gold_awarded_on_kill = floor(15 × 1.5) = 22 gold
```

**Worked example — all-Mage formation (M+M+M, N=3) vs. Ancient Rootking (Tier 3, bruiser):**
```
n = 0 (no Mage counters "bruiser") → 0 > 1 false → threshold not crossed → matchup_multiplier = 1.0
gold_awarded_on_kill = 80 × 1.0 = 80 gold
```

**Worked example — generalist formation (Warrior + Mage + Rogue, N=3) vs. Ancient Rootking:**
```
n = 1 (only Warrior counters "bruiser") → 1 > 1 false → threshold NOT crossed → matchup_multiplier = 1.0
gold_awarded_on_kill = floor(80 × 1.0) = 80 gold
```
Note: under the majority-threshold rule (Resolver Rule 6, revised 2026-04-19), a single counter hero in a 3-slot formation is no longer sufficient — the generalist formation gets neutral 1.0× on every kill. A specialist W+W+M formation would cross the threshold (n=2 ≥ 2) on bruiser kills and earn 1.5× there.

---

### D.2 Effective HP Ratio (Pacing Validation Signal)

This formula is a **design-time pacing signal**, not a runtime formula. Combat Resolution owns the actual combat math. This is used by QA and designers to validate that enemy HP values produce the intended "rounds to kill" feel at each tier.

```
effective_hp_ratio(enemy, hero_attack) = enemy.base_hp / hero_attack
```

Where:
- `enemy.base_hp`: the enemy's fixed HP value.
- `hero_attack`: the `stat_at_level("attack", class_data, level)` value for the representative hero (using the hero class DB formula: `base_attack + attack_per_level × (level - 1)`).
- Output: float — approximate number of attack rounds to kill the enemy, assuming each attack deals damage equal to `hero_attack`. This is a simplification; Combat Resolution's actual formula may include speed-weighting or other modifiers. This ratio is a calibration check, not a contract.

**MVP calibration table:**

| Enemy | base_hp | Representative hero | Hero ATK | Ratio (rounds) | Target range |
|---|---|---|---|---|---|
| Hollow Brute | 52 | Warrior L1 | 12 | 4.3 | 4–7 |
| Hollow Brute | 52 | Mage L1 | 20 | 2.6 | 3–5 |
| Glowmoth | 60 | Mage L1 (counter) | 20 | 3.0 | 3–5 |
| Glowmoth | 60 | Warrior L1 (no counter) | 12 | 5.0 | 4–7 |
| Shellback | 72 | Rogue L1 (counter) | 14 | 5.1 | 4–7 |
| Shellback | 72 | Warrior L1 (no counter) | 12 | 6.0 | 5–8 |
| Elder Boar | 195 | Warrior L6 | 22 | 8.9 | 8–12 |
| Moss Druid | 185 | Mage L6 (counter) | 38 | 4.9 | 4–8 |
| Vined Knight | 225 | Rogue L6 (counter) | 24 | 9.4 | 8–12 |
| Thorn Guardian | 680 | Warrior L10 | 30 | 22.7 | 15–25 |
| Thorn Guardian | 680 | Warrior L12 | 34 | 20.0 | 15–25 |
| Ancient Rootking | **4818** (Pass 2B) | Warrior L13 | 36 | 133.8 rounds (legacy model) / 723 s Combat-tick / (solo blocked by design) | (formation, not solo) |
| Ancient Rootking | **4818** (Pass 2B) | 3-hero L13 formation | 130 | 37.1 rounds (legacy model) / **170.05 s Combat-tick** | matches Biome F5 170 s target ✓ |

**QA instruction**: Run this table against implemented combat at first playtest. If any enemy falls outside its target range by more than 2 rounds, flag as a balance tuning task. The Thorn Guardian's solo ratio (61 rounds for L13 Warrior) is intentional — the elite is not designed to be soloed.

---

### D.3 Matchup Advantage Counter Legibility Check

Not a runtime formula. A design validation check to confirm the economic difference between matched and unmatched kill rewards is legible at each tier.

```
counter_bonus_delta(tier) = BASE_KILL[tier] × 1.5 - BASE_KILL[tier]
                          = BASE_KILL[tier] × 0.5
```

| Tier | BASE_KILL | With matchup (1.5×) | Without (1.0×) | Delta | % extra |
|---|---|---|---|---|---|
| 1 | 15 | 22 (floor) | 15 | 7 gold | +47% |
| 2 | 35 | 52 (floor) | 35 | 17 gold | +49% |
| 3 | 80 | 120 | 80 | 40 gold | +50% |

The delta grows in absolute terms as tier increases, keeping the matchup decision economically meaningful at every progression stage. At Tier 3 (boss), the delta is 40 gold per kill — significant enough to feel on the Return-to-App screen's kill-bonus summary.

---

## E. Edge Cases

### E.1 Enemy Resource Missing (UNAVAILABLE State)

**Scenario**: `DataRegistry.resolve("enemies", "hollow_brute")` returns `null` because `hollow_brute.tres` is absent from the build.

**Behavior**: This system declares the `null` contract and does not own recovery. Per the Data Loading GDD, `DataRegistry` logs `push_error` and returns `null`. Each consumer is responsible for null-checking:
- Biome & Dungeon DB: must not compose a floor list containing a null enemy reference — mark that floor as uncomputable and log an error.
- Matchup Resolver: must not call `is_class_counter` on a null enemy; return `false` (no matchup advantage) as safe fallback.
- Combat Resolution: must not attempt to read `base_hp` from null; abort the combat calculation and log an error.
- Dungeon Run Orchestrator: must not spawn a null enemy instance; skip the kill and log an error (do not award phantom gold).

This GDD's contract: if `DataRegistry.resolve("enemies", id)` returns non-null, all fields are guaranteed populated (Data Loading System validates on load).

### E.2 Enemy `archetype` Not in the MVP Set (Typo or V1.0 String)

**Scenario**: An enemy `.tres` is authored with `archetype = "armoured"` (British spelling typo) or `archetype = "beast"` (V1.0 string used on a Forest Reach enemy before the Ranger class exists).

**Behavior for typo**: Data Loading System schema validation at load time checks `archetype` against the known constant set. A string not in the valid set triggers `push_error("EnemyData [id]: archetype '[value]' is not a recognized archetype constant")` and sets the resource to UNAVAILABLE. The enemy does not load into the registry. This is a **hard failure at load time, not runtime** — catches authoring errors before they reach players.

**Behavior for valid V1.0 archetype (`"beast"`) used in MVP build**: Schema validation passes (the string is a recognized constant). The enemy loads as LOADED. At matchup resolution time, `is_enemy_countered_by("beast", hero_class)` returns `false` for all three MVP hero classes (none have `counter_archetype = "beast"`). The enemy receives no matchup advantage, and all formations kill it at the 1.0× gold rate. This is **expected behavior** — the V1.0 enemy loads cleanly; players just cannot trigger a matchup bonus against it until the Ranger class is added. Document this as expected, not a bug.

### E.3 Two Enemies with the Same `id`

**Scenario**: `forest_bruiser_01.tres` and `forest_bruiser_02.tres` both declare `id = "hollow_brute"`.

**Behavior**: Data Loading System handles duplicate-id detection per its contract (see Data Loading GDD, Section C.X). The second registration attempt for the same `id` logs `push_warning("DataRegistry: duplicate id 'hollow_brute' — keeping first registration, discarding second")` and discards the duplicate. The first loaded resource wins. This is a data authoring error; catch in asset review pipeline. If the two resources are genuinely different enemies with accidentally shared IDs, the second enemy is silently lost — QA must verify enemy count matches expected total (8 enemies for MVP).

### E.4 Enemy `base_hp` = 0 or Negative

**Scenario**: A `.tres` is authored with `base_hp = 0` or `base_hp = -10` (data entry error).

**Behavior**: Data Loading System schema validation should reject any enemy with `base_hp <= 0` with `push_error`. If somehow a zero-HP enemy reaches runtime (validation bypassed or future refactor removes the check), it dies on the first combat tick without damage being applied — no infinite loop, no division-by-zero, because enemy HP formulas are additive, not divisive. Combat Resolution must treat `current_hp <= 0` as the death condition regardless of how the enemy was loaded. This GDD requires that Data Loading validation prevents this case before runtime.

### E.5 Boss Enemy on a Non-Boss Floor

**Scenario**: The Biome & Dungeon Database (GDD #8) incorrectly places the Ancient Rootking (`is_boss: true`) on Floor 2 instead of Floor 5.

**Behavior**: This is a floor composition bug in the Biome & Dungeon Database, not an Enemy Database contract violation. The Enemy Database has no knowledge of floor assignment — it is static data. The Dungeon Run Orchestrator reads `is_boss` and triggers the boss-death fanfare on any enemy with `is_boss: true`, regardless of floor. Result: the boss fanfare fires on Floor 2. This is a data authoring bug, not a runtime error. The Biome & Dungeon Database GDD must document the invariant that `is_boss: true` enemies belong only on the final floor of their biome's dungeon. The Enemy Database GDD's only contract is: exactly one enemy in the MVP set has `is_boss: true` (schema validation may enforce this as a warning if desired).

### E.6 Counter Match with No Counter Hero in Formation

**Scenario**: The Shellback (archetype `"armored"`) is in the floor pool. The player dispatches a formation containing only Warriors and Mages — no Rogue. The Matchup Resolver checks the formation.

**Behavior**: `matchup_multiplier = 1.0`. No counter bonus awarded. Kill reward = `BASE_KILL[1] × 1.0 = 10` gold (Pass 4B-Economy A3 2026-04-20: `BASE_KILL[1]` reconciled 15→10). This is the **design working correctly**, not an error. The player made a formation assignment choice that doesn't exploit the matchup; they earn the standard rate. No edge case handling required — this is the expected outcome for non-optimal formation assignment. Pillar 3 ("Matchup Is a Decision") depends on this case existing.

### E.7 V1.0 Enemy with `"beast"` Archetype Added While Ranger Class Does Not Exist

**Scenario**: A V1.0 patch adds a `forest_wolf.tres` with `archetype = "beast"` to the Forest Reach biome. The Ranger class is planned for V1.1 and does not exist in the current build.

**Behavior**: The wolf loads successfully (LOADED state — `"beast"` is a recognized constant per the Hero Class DB's `EnemyArchetypes` constant set). At matchup resolution, no MVP class has `counter_archetype = "beast"`, so `matchup_multiplier = 1.0` for all formations. The wolf kills at the base rate. No crash, no error. When the Ranger class is added in V1.1, the wolf immediately benefits from matchup bonus for Ranger formations — no schema change, no migration. This is expected V1.0 behavior: archetypes are declared ahead of their class pairs.

### E.8 Per-Enemy Gold Override (Not in MVP Schema, Planned for V1.0)

**Scenario**: V1.0 design adds a `kill_gold_override: int` field to `EnemyData` so a special event enemy can award a unique gold amount.

**Behavior**: When this field is added, the Economy / Dungeon Run Orchestrator integration must check: if `enemy.kill_gold_override > 0`, use the override value instead of `BASE_KILL[enemy.tier]`. If the field is absent (MVP enemies, or new enemies where it is left at default 0), fall back to `BASE_KILL[tier]`. The fallback is not an error — it is the default path. This edge case documents the expected migration contract so V1.0 implementation does not require Enemy Database schema re-review.

---

## F. Dependencies

### Upstream Dependencies

| Upstream | Hard/Soft | Interface |
|---|---|---|
| **Data Loading System** (`design/gdd/data-loading.md`) | Hard | `DataRegistry.resolve("enemies", id) -> EnemyData \| null`; schema validation rejects invalid archetypes and duplicate ids at load time |
| **Hero Class Database** (`design/gdd/hero-class-database.md`) | Hard | Enemy `archetype` field must use constants declared in `HeroClass` GDD C.2's `EnemyArchetypes` set (`"bruiser"`, `"caster"`, `"armored"` for MVP; `"beast"`, `"construct"`, `"incorporeal"` reserved for V1.0). No other field reads `HeroClass` data. |
| **Economy System** (`design/gdd/economy-system.md`) | Hard — read-through | `BASE_KILL[tier]` lookup (tier_1=15, tier_2=35, tier_3=80); `MATCHUP_GOLD_MULTIPLIER = 1.5` applied at kill resolution. This GDD references these registered constants but does not own them. |

### Downstream Dependents

| Consumer | Hard/Soft | What they read |
|---|---|---|
| **Biome & Dungeon Database (#8)** | Hard | `id`, `tier`, `archetype`, `biome` — composes per-floor encounter pools; respects the C.2 archetype distribution invariant |
| **Matchup Resolver (#10)** | Hard | `archetype` only — compares against `hero.counter_archetype` to return 1.5× or 1.0× |
| **Combat Resolution (#11)** | Hard | `base_hp`, `base_attack`, `base_speed` — static stats read directly from `EnemyData` (enemies don't level) |
| **Dungeon Run Orchestrator (#13)** | Hard | `id`, `tier`, `is_boss`, `base_hp`, `base_attack` — spawns enemies, resolves combat, emits `enemy_killed(tier, matchup_advantage)` to Economy, triggers boss-death fanfare when `is_boss == true` |
| **Dungeon Run View (#24)** | Soft | `sprite_path`, `death_anim_key` — display only |

### Bidirectional Consistency

- `design/gdd/data-loading.md` lists Enemy Database as hard dependent ✅ (via `DataRegistry.resolve("enemies", id)`)
- `design/gdd/hero-class-database.md` **Cross-GDD pact** (Section F): "Enemy Database's `archetype` field must use one of the strings defined in C.2's `EnemyArchetypes` constants" — verified ✅
- `design/gdd/economy-system.md` does not list Enemy Database as a dependent (Economy is read-through — it exposes `kill_bonus(tier)` formula; enemies consume it by reference without needing Economy to know they exist). This is intentional: the tier-to-gold mapping is Economy's responsibility, enemy content is this GDD's.

---

---

## G. Tuning Knobs

Every enemy's `base_hp`, `base_attack`, and `base_speed` value lives in its `.tres` file in `assets/data/enemies/`. These are the primary tuning handles — editable in the Godot editor without recompile.

### G.1 Per-Enemy Stat Knobs (Category: Feel)

Each enemy exposes three feel-category knobs tuned through playtest intuition:

| Enemy | `base_hp` | Range | `base_attack` | Range | `base_speed` | Range |
|---|---|---|---|---|---|---|
| Hollow Brute | 52 | 40–65 | 8 | 6–12 | 3 | 2–5 |
| Glowmoth | 60 | 45–75 | 11 | 8–15 | 5 | 3–7 |
| Shellback | 72 | 55–90 | 9 | 6–12 | 2 | 1–4 |
| Elder Boar | 195 | 155–245 | 18 | 14–24 | 4 | 3–6 |
| Moss Druid | 185 | 145–230 | 24 | 18–30 | 6 | 4–8 |
| Vined Knight | 225 | 175–280 | 20 | 15–26 | 3 | 2–5 |
| Thorn Guardian | 680 | 540–820 | 32 | 24–40 | 5 | 3–7 |
| Ancient Rootking | **4818** | 4400–5200 (Pass 2B post-cascade band) | 45 | 36–56 | 3 | 2–4 |

**When to tune `base_hp`**: If first-playtest effective_hp_ratio falls outside the Section D.2 target ranges, adjust HP first (safe change — no formula dependencies, no cross-system side effects).

**When to tune `base_attack`**: Adjust only after Combat Resolution formula is authored and tested. Enemy attack interacts with hero HP in ways not fully specified until Combat Resolution GDD (#11) is complete. Use the minimum safe default until that contract is clear.

**When to tune `base_speed`**: Speed hierarchy (fast casters, medium bruisers, slow armored) should be preserved across tuning. Never make an armored enemy faster than a caster of the same tier.

### G.2 Tier HP Band Policy (Category: Curve)

Rather than uniform HP across a tier, enemies within each tier use a ±20% band around the tier midpoint. This creates variety without breaking the pacing model:

- **Tier 1 midpoint**: 62 HP. Valid band: 50–74 HP. Actual values: 52 (Hollow Brute), 60 (Glowmoth), 72 (Shellback) — all within band.
- **Tier 2 midpoint**: 202 HP. Valid band: 162–242 HP. Actual values: 185 (Moss Druid), 195 (Elder Boar), 225 (Vined Knight) — all within band.
- **Tier 3**: two enemies with distinct roles (elite vs. boss); no shared midpoint applies. Elite HP (680) and boss HP (**4818** Pass 2B, was 2200) are independently calibrated.

**Band rationale**: ±20% is wide enough to create archetype-appropriate variation (armored = highest HP in tier, caster = lowest HP in tier) while narrow enough that no enemy in a tier takes twice as long to kill as another. The band prevents the armored enemy from becoming a roadblock and the caster from becoming trivial relative to the same-tier bruiser.

### G.3 Boss HP Multiplier Approach (Category: Gate)

The Ancient Rootking's HP (**4818** Pass 2B, was 2200) is **set directly in its `.tres` file**, not derived from a `boss_hp_multiplier × base_tier_hp` formula. Rationale:

1. The boss is a unique encounter with unique design intent — its HP should be explicitly owned, not calculated from a shared multiplier that another designer might change.
2. There is only one boss in MVP. A multiplier formula only pays off when there are many bosses to tune at once (V1.0+ concern).
3. Direct values are more auditable: opening `ancient_rootking.tres` and reading `base_hp = 4818` is unambiguous. A calculated value requires following the formula chain.
4. Pass 2B locked 4818 via the closed-form `ceili(target_seconds × TICKS_PER_SECOND × dps) = ceili(170 × 20 × 1.417) = 4818` — auditable against Combat GDD #11 I.Q2 resolution, not against a stale heuristic.

If V1.0 adds a second biome with a second boss, revisit whether a `boss_hp_multiplier` config in the Economy / Balance data files makes more sense than per-boss direct HP values.

### G.4 Floor-1 Ease-In Knob (Category: Gate)

The Hollow Brute's `base_hp = 52` is intentionally 16% below the Tier-1 midpoint (62). This is the ease-in knob: the first enemy the player fights should die faster than a "typical" Tier-1 enemy to establish the idle loop's positive feedback before the player is asked to make formation decisions.

**Tuning guidance**: The ease-in enemy should die in 3–5 rounds for a solo L1 Warrior (currently: 52 ÷ 12 = 4.3 rounds). If Session-1 playtest shows players are confused before their first kill, lower Hollow Brute HP further (minimum 40 HP). If the first kill arrives so fast it doesn't register, raise toward 65 HP. This knob is independent of the Tier-1 band policy in G.2 — the Hollow Brute can sit below the band floor (50 HP) if onboarding requires it; the band is a guideline, not a hard constraint.

---

## H. Acceptance Criteria

All criteria use Given-When-Then format. 12 criteria total (10 BLOCKING + 2 ADVISORY).

### H-01 — All 8 MVP Enemies Resolvable (Integration, BLOCKING)

**GIVEN** Data Loading System is `READY` with 8 `.tres` files in `assets/data/enemies/`,
**WHEN** `DataRegistry.resolve("enemies", id)` is called for each of the 8 MVP enemy ids,
**THEN** every call returns non-null `EnemyData`; `resource.id` matches query; `resource.display_name` non-empty; `resource.biome == "forest_reach"` for all 8; no error logged.

*Verification*: integration test parameterized across all 8 ids.

### H-02 — archetype Restricted to 3 MVP Tags (Logic, BLOCKING)

**GIVEN** all 8 MVP enemies loaded,
**WHEN** each `archetype` field is read,
**THEN** every value is a member of exactly `["bruiser", "caster", "armored"]`; no empty string; no V1.0 tag used (`"beast"`, `"construct"`, `"incorporeal"` forbidden in MVP content).

*Verification*: unit test; 8 sub-cases assert against `EnemyArchetypes` constant set from Hero Class DB C.2.

### H-03 — tier Field in {1, 2, 3} with Correct Distribution (Logic, BLOCKING)

**GIVEN** all 8 MVP enemies loaded,
**WHEN** `tier` field read on each,
**THEN** every value is in {1, 2, 3}; distribution is exactly 3 tier-1 + 3 tier-2 + 2 tier-3 enemies (1 elite + 1 boss); any value outside {1, 2, 3} is a test failure.

### H-04 — Balanced Archetype Distribution at Tier 1 and Tier 2 (Integration, BLOCKING)

**GIVEN** all 8 MVP enemies loaded,
**WHEN** enemies grouped by `tier`,
**THEN** tier-1 group (3 enemies) contains exactly one `"bruiser"`, one `"caster"`, one `"armored"`; tier-2 group (3 enemies) same distribution; tier-3 group (2 enemies: Thorn Guardian + Ancient Rootking) both `"bruiser"` as documented in C.2 (single-archetype tier-3 is the Warrior-showcase design decision).

*Rationale*: tests the design invariant (C.2), not just field types. A database with 3 tier-1 bruisers and 0 tier-1 casters passes H-02/H-03 but fails here.

### H-05 — Gold Reward Matches Economy Formula (Integration, BLOCKING)

**GIVEN** a tier-2 `EnemyData` resource and a formation with `is_matchup_advantaged = true`,
**WHEN** `Economy.kill_bonus(enemy.tier)` is invoked with `matchup_multiplier = 1.5` (formula: `floor(BASE_KILL[tier] × multiplier)` where `BASE_KILL[2] = 35`),
**THEN** gold awarded = exactly `floor(35 × 1.5) = 52`; no per-enemy gold override field alters this; same enemy with `matchup_multiplier = 1.0` → exactly 35.

*Verification*: cross-system integration test (Enemy DB + Economy); assert both neutral and advantage cases.

### H-06 — Matchup Multiplier: Warrior/Bruiser vs Warrior/Caster (Logic, BLOCKING)

**GIVEN** Warrior with `counter_archetype = "bruiser"`, bruiser enemy, caster enemy,
**WHEN** `MatchupResolver.is_class_counter(warrior, bruiser_enemy.archetype)` and same call with caster enemy,
**THEN** first returns `true` (1.5× applies); second returns `false` (1.0×); Economy kill bonus for tier-1 bruiser with Warrior advantage = `floor(15 × 1.5) = 22`; caster with Warrior (no counter) = 15.

### H-07 — is_boss Flag True for Exactly One Enemy (Logic, BLOCKING)

**GIVEN** all 8 MVP enemies loaded,
**WHEN** `is_boss` read on each,
**THEN** exactly one (Ancient Rootking) has `is_boss == true`; that enemy has `tier == 3`; all other 7 have `is_boss == false`; no tie (0 bosses) or double (2+ bosses) accepted.

### H-08 — HP Calibration Within Tier Bands (Logic, BLOCKING)

**GIVEN** tier HP bands per Section G.2: tier-1 = [50, 74], tier-2 = [162, 242], tier-3 elite = [540, 820], tier-3 boss = [1800, 2600],
**WHEN** each enemy's `base_hp` read and compared against its band,
**THEN** every enemy's HP falls within its tier band (inclusive); Hollow Brute's 52 HP sits below tier-1 midpoint but within the 50–74 band (ease-in per G.4); no tier-1 enemy has HP in tier-2 range; no tier-3 non-boss exceeds the boss lower bound.

*Catches*: content errors where a designer puts a tier-3 HP value on a tier-1 enemy.

### H-09 — Save File Enemy References Resolve After Restore (Integration, BLOCKING)

**GIVEN** a save file containing serialized enemy id references and `DataRegistry` booted fresh,
**WHEN** `DataRegistry.resolve("enemies", id)` called for each stored id during restore,
**THEN** every MVP id resolves to same non-null resource as fresh boot (Godot resource cache consistency); `tier` and `archetype` round-trip correctly; no `null` for any valid MVP enemy id.

### H-10 — Unknown archetype String Rejected at Load (Logic, BLOCKING)

**GIVEN** a `.tres` authored with `archetype = "berserker"` (unrecognized tag),
**WHEN** Data Loading processes the file at boot,
**THEN** logs `[DataRegistry] INVALID ARCHETYPE: 'berserker' in enemy '{id}'`; resource rejected (not registered); `resolve()` returns `null`; other enemies load normally; if count falls below `MIN_CONTENT_COUNT["enemies"]`, state → `ERROR`.

*Contract*: validation ownership per Data Loading GDD Rule 4. This criterion confirms end-to-end enforcement for the archetype field.

### H-11 — sprite_path and death_anim_key Non-Empty (Logic, BLOCKING)

**GIVEN** all 8 MVP enemies loaded,
**WHEN** `sprite_path` and `death_anim_key` read on each,
**THEN** both non-empty for every enemy; `sprite_path` matches convention `assets/art/enemies/{id}/sprite.png`; `death_anim_key` non-whitespace; any empty or whitespace-only value is a per-enemy-per-field failure.

*Verification*: 16 assertions (8 enemies × 2 fields).

### H-12 — flavor_text Under 120-Character Soft Limit (Config/Data, ADVISORY)

**GIVEN** all 8 MVP enemies loaded,
**WHEN** each `flavor_text` read,
**THEN** every non-empty value ≤ 120 characters; smoke check reports overrun as warning (not fatal); UI truncates at 120 with ellipsis regardless.

*Gate = ADVISORY*: truncation prevents runtime failure.

### Classification Summary

| ID | Description | Type | Gate |
|---|---|---|---|
| H-01 | All 8 enemies resolvable | Integration | BLOCKING |
| H-02 | archetype field restricted to MVP tags | Logic | BLOCKING |
| H-03 | tier in {1,2,3} with correct distribution | Logic | BLOCKING |
| H-04 | Balanced archetype at tiers 1 & 2 | Integration | BLOCKING |
| H-05 | Gold reward matches Economy formula | Integration | BLOCKING |
| H-06 | Matchup multiplier Warrior/bruiser vs caster | Logic | BLOCKING |
| H-07 | is_boss true for exactly one enemy | Logic | BLOCKING |
| H-08 | HP within tier bands | Logic | BLOCKING |
| H-09 | Save file refs resolve after restore | Integration | BLOCKING |
| H-10 | Unknown archetype rejected at load | Logic | BLOCKING |
| H-11 | sprite_path + death_anim_key non-empty | Logic | BLOCKING |
| H-12 | flavor_text ≤ 120 chars | Config/Data | ADVISORY |

---

## I. Open Questions

| Question | Owner | Target Resolution |
|---|---|---|
| **Round-to-tick cadence** — this GDD's rounds-to-kill math assumes 1 round ≈ 200 ticks (10 seconds). If Dungeon Run Orchestrator (#13) decides otherwise, HP values need recalibration. | systems-designer + Orchestrator GDD author | Before Orchestrator GDD authoring |
| **Ancient Rootking HP** — ~~game-designer locked 2200 for 17-round boss; systems-designer recommended 1800 HP.~~ **RESOLVED 2026-04-20 Pass 2B**: `base_hp` raised 2200 → **4818** per Combat GDD #11 I.Q2 closed-form calibration (`ceili(170 × 20 × 1.417) = 4818`). Hits 170 s target deterministically under SPEED_BASE=2400, L13 W+M+R neutral matchup. Cascade applied across Enemy DB (C.2 rationale, C.3 Ancient Rootking entry, D.2 pacing table, D.3 attack table, G.1 base-HP band, G.2 midpoint note, G.3 direct-HP rationale), Combat GDD #11 D.4/D.7/I.Q2, Biome DB F5 HP registry check, entities.yaml `floor_total_hp` + `ancient_rootking`. | ~~economy-designer + game-designer~~ | ~~First MVP playtest~~ — **CLOSED** |
| **Floor 5 boss archetype** — pure bruiser prioritizes Warrior-showcase climax but gives Mage/Rogue-focused players no matchup bonus on MVP finale. Playtest validates whether Mage/Rogue investment still feels meaningful on Floor 5. | game-designer + systems-designer | First MVP playtest |
| **Enemy attack vs hero HP** — current values (Tier 1: 8–11, Tier 2: 18–24, Tier 3: 32–45) are lower than systems-designer's recommended band (12–15 / 25–40 / 50–70). Validated "does combat feel like it has stakes?" | game-designer + qa-lead | First MVP playtest |
| **Per-enemy `kill_gold_override` field** — V1.0 may add this; current schema doesn't include it. Fallback policy documented in E.8 but not implemented. | economy-designer | V1.0 scope |
| **Hollow Brute ease-in HP** (52) — could drop to 40 if Session-1 kill latency is too long in playtest; could raise to 65 if first kill arrives invisibly fast. Knob range in G.4. | game-designer + qa-tester | First MVP playtest |
