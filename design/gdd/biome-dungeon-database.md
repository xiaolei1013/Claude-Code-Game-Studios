# Biome & Dungeon Database GDD — Lantern Guild

> **GDD #7 in design order** (System #8 in systems index)
> **Status**: Designed (pending independent review)
> **Created**: 2026-04-18
> **Last Updated**: 2026-04-19
> **Authors**: game-designer + systems-designer + qa-lead + main session
> **Depends on**: `design/gdd/data-loading.md` (GDD #2), `design/gdd/enemy-database.md` (GDD #6)
> **Referenced by**: Formation Assignment (#17), Dungeon Run Orchestrator (#13), Floor/Biome Unlock (#16), Matchup Assignment Screen (#23), Dungeon Run View (#24)
> **Implements Pillar**: Pillar 2 + Pillar 3 (floor-by-floor archetype distribution drives matchup decisions) + Pillar 4 (Art Bible environmental storytelling)
> **Creative Director Review (CD-GDD-ALIGN)**: SKIPPED — Solo review mode

---

## A. Overview

The Biome & Dungeon Database is the spatial/progression container for all dungeon content in *Lantern Guild*. It defines three nested resource types — `Biome`, `Dungeon`, `Floor` — that together compose the places a formation can be dispatched to. MVP scope: **one active biome (Forest Reach)** containing one dungeon of five floors, plus four V1.0 biome stubs (Sunken Ruins, Ember Cavern, Thornwood Depths, Arcane Spire) with name and flavor only.

Each floor declares a **deterministic enemy list** (exact `{enemy_id, count}` pairs, no probabilistic spawns) so offline runs produce predictable outcomes — the Pillar 1 guarantee. Floor composition respects the archetype distribution invariant locked in Enemy DB: Tiers 1 and 2 each carry all three MVP archetypes (bruiser/caster/armored), and Tiers 3–5 are intentionally bruiser-only for the Warrior-showcase climax of the Forest Reach arc.

This system closes the Core data-definition trio (Class DB → Enemy DB → Biome/Dungeon DB). Seven downstream systems depend on its schema or composition invariants, from Formation Assignment UI through Floor/Biome Unlock gating to the Dungeon Run Orchestrator's encounter spawning.

---

## B. Player Fantasy

The Biome & Dungeon Database serves the **frontier fantasy**: *"there's a forest out there, and my guild is learning how to handle it."*

The player never reads this database. They experience its output: a biome-select screen showing Forest Reach and its five floors, each with a name, flavor line, and enemy preview. The database's job is to make each floor feel like a distinct place with distinct threats, not a procedural generator spitting out encounter #37. The deterministic enemy lists mean every run of Floor 3 is The Deep Grove — the same 2 Elder Boars, 2 Moss Druids, 1 Vined Knight — and that predictability is the basis for mastery and planning.

The indirect emotional target: **a sense of place that rewards memory**. A player who returns to Floor 3 on Day 10 knows what to bring and why. A player opening the app and reassigning to Floor 4 for the first time is stepping into The Rootfall — a specific named moment, not a difficulty bucket. Deterministic content is how a 5-floor dungeon becomes a world instead of a spreadsheet.

For the boss floor (Floor 5), the fantasy sharpens: the database's single-enemy composition plus the `is_boss_floor: true` flag is what lets the Dungeon Run Orchestrator produce the full boss-encounter beat — the longer fight, the extended kill pop, the 18,000 gold clear bonus. *The Rootking's Hollow* is the MVP's climax moment, and this GDD is what makes it exist as a specific named place.

---

## C. Detailed Design

### C.1 Biome, Dungeon, and Floor Resource Schemas

Three nested resource types. Biome is the thematic container (palette, storytelling). Dungeon is the structural container (ordered floor sequence). Floor is the encounter definition (enemy list, pacing target).

**`class_name Biome extends GameData`**

| Field | Type | Description |
|---|---|---|
| `id` | `String` | Snake_case unique key (e.g. `"forest_reach"`) |
| `display_name` | `String` | UI label (e.g. `"Forest Reach"`) |
| `primary_palette_key` | `String` | References Art Bible color-system constant (e.g. `"moss_sage_guild_amber"`). Read by Dungeon Run View for atmospheric tinting. Not runtime-enforced — Art Bible is authority. |
| `dominant_archetypes` | `Array[String]` | Ordered list of archetypes present on this biome's floors. UI signal for Formation Assignment matchup planning. No gameplay calculation. |
| `dungeons` | `Array[Dungeon]` | Inline array. MVP: each biome has exactly 1 dungeon. Array forward-compatible for multi-dungeon biomes in V1.0+. |
| `environmental_storytelling` | `Array[String]` | Prop keys (e.g. `"claw_marks_on_trees"`). Read by Dungeon Run View. ≥2 per biome per Art Bible Section 4. |
| `flavor_text` | `String` | Biome lore blurb, soft limit 200 chars |
| `status` | `String` | `"active"` = playable; `"planned_v1"` = stub only, filtered from assignment UI |

**Fields intentionally omitted**: `unlock_condition` (owned by Floor/Biome Unlock System), `music_track_key` (deferred to Audio GDD), `clear_reward` (Economy owns `FLOOR_CLEAR_BONUS[floor_index]` at floor granularity).

**`class_name Dungeon extends GameData`**

| Field | Type | Description |
|---|---|---|
| `id` | `String` | Snake_case unique key (e.g. `"forest_reach_dungeon_01"`) |
| `display_name` | `String` | UI title (e.g. `"Forest Reach — The First Descent"`) |
| `biome_id` | `String` | Back-reference to parent biome id. Load-time validation rejects Dungeon with non-existent `biome_id`. |
| `floors` | `Array[Floor]` | Inline array ordered by `floor_index`. MVP: exactly 5 floors. Run Orchestrator iterates array in order; authoring order is canonical. |

**`class_name Floor extends GameData`**

| Field | Type | Description |
|---|---|---|
| `id` | `String` | Snake_case unique key (convention: `{biome_id}_f{floor_index}`) |
| `floor_index` | `int` | 1-based (1–5 for MVP). Used to lookup Economy's `BASE_DRIP[floor_index]` and `FLOOR_CLEAR_BONUS[floor_index]`. |
| `display_name` | `String` | UI title (e.g. `"Floor 1: The Edge of the Wood"`) |
| `enemy_list` | `Array[Dictionary]` | Ordered list of `{enemy_id: String, count: int}` entries. Deterministic — no RNG. |
| `expected_clear_time_seconds` | `int` | Design target, NOT runtime enforcement. QA/Economy uses for pacing validation. |
| `is_boss_floor` | `bool` | `true` only for boss floors (F5 in MVP). Triggers boss-death fanfare. |
| `flavor_text` | `String` | Floor teaser, soft limit 120 chars |

**Fields intentionally omitted**: `difficulty_rating` (derivable from enemy HP totals), `unlock_condition` (Floor/Biome Unlock System owns), `reward_override` (Economy owns), `background_scene_key` (Art direction — `id` serves as scene-key convention hook).

**Contrast with Enemy Database**: Enemy has 12 fields covering a single runtime entity. Floor has 7 — it's a roster of references, not an entity. Biome (8) + Dungeon (4) + Floor (7) = 19 combined fields across three nested containers.

### C.2 Forest Reach Biome — Full Composition

**Biome metadata**:

```yaml
id: "forest_reach"
display_name: "Forest Reach"
primary_palette_key: "moss_sage_guild_amber"
dominant_archetypes: ["bruiser", "caster", "armored"]
environmental_storytelling:
  - "claw_marks_on_trees"         # telegraphs hollow_brute / elder_boar / thorn_guardian
  - "webbing_in_canopy"           # telegraphs glowmoth / moss_druid
  - "disturbed_mushroom_rings"    # telegraphs large presence (thorn_guardian, ancient_rootking)
  - "broken_pillars_with_moss"    # ancient-forest flavor; no specific enemy telegraph
flavor_text: "Where the guild's first heroes prove themselves. The canopy filters amber light, and something in the deeper wood has started paying attention."
status: "active"
```

**Dungeon metadata**:

```yaml
id: "forest_reach_dungeon_01"
display_name: "Forest Reach — The First Descent"
biome_id: "forest_reach"
# floors: inline array of 5 Floor resources, detailed below
```

---

#### Floor 1 — The Edge of the Wood

```yaml
id: "forest_reach_f1"
floor_index: 1
display_name: "Floor 1: The Edge of the Wood"
enemy_list:
  - {enemy_id: "hollow_brute", count: 3}
  - {enemy_id: "glowmoth",     count: 1}
expected_clear_time_seconds: 40
is_boss_floor: false
flavor_text: "The lantern's reach ends here. Beyond this line, the forest has its own opinion about visitors."
```

**Rationale**: 3 Hollow Brutes anchor onboarding — bruiser is the most visually obvious archetype (mass-forward) and lowest HP in Tier 1. Kills arrive within 30–40s of run start. 1 Glowmoth introduces caster without clutter. No Shellback — armored archetype held for Floor 2 ("one new concept per floor"). Total HP = 216.

**Matchup distribution**: Warrior earns 3 bonus kills (bruisers); Mage earns 1 (caster); Rogue earns 0 — the intentional Rogue-counter deferral to Floor 2.

#### Floor 2 — The Thicket

```yaml
id: "forest_reach_f2"
floor_index: 2
display_name: "Floor 2: The Thicket"
enemy_list:
  - {enemy_id: "hollow_brute", count: 2}
  - {enemy_id: "glowmoth",     count: 1}
  - {enemy_id: "shellback",    count: 2}
expected_clear_time_seconds: 55
is_boss_floor: false
flavor_text: "The path closes in. Something with a shell and bad intentions has claimed this part of the forest as its own."
```

**Rationale**: Complete Pillar-3 vocabulary floor — all 3 Tier-1 archetypes present. 2 Shellbacks introduce armored as a pair (not singleton) for presence. Total HP = 308.

**Matchup distribution**: Warrior 2 / Mage 1 / Rogue 2. Optimal: Warrior + Rogue formation (4 of 5 matched).

#### Floor 3 — The Deep Grove

```yaml
id: "forest_reach_f3"
floor_index: 3
display_name: "Floor 3: The Deep Grove"
enemy_list:
  - {enemy_id: "elder_boar",   count: 2}
  - {enemy_id: "moss_druid",   count: 2}
  - {enemy_id: "vined_knight", count: 1}
expected_clear_time_seconds: 85   # Pass 2B (2026-04-20): revised from 60 → 85 per Combat GDD #11 D.7 tick-model calibration
is_boss_floor: false
flavor_text: "The trees here are older than the guild's founding. Whatever lives in them has been watching since before that."
```

**Rationale**: Tier-2 introduction; complete-vocabulary at higher power. 2:2:1 split favors bruiser+caster (Warrior+Mage dominant) while 1× Vined Knight creates Rogue counter pressure. Total HP = 985. **Pass 2B revision**: target revised 60s → 85s per Combat GDD #11 D.7 tick-model calibration — at SPEED_BASE=2400 with an L6 W+M+R formation (raw DPS 0.580, neutral matchup), `ceili(985 / 0.580) / 20 = 85.0 s`. The earlier 60s target was unreachable under Combat's authoritative cadence; 85s is the closed-form derived value. Combat GDD #11 I.Q1 CLOSED; see C.7 for the resolved tension record.

**Matchup distribution**: Warrior 2 / Mage 2 / Rogue 1. Optimal formation earns 5/5 matched kills (mixed Warrior + Mage + Rogue).

#### Floor 4 — The Rootfall

```yaml
id: "forest_reach_f4"
floor_index: 4
display_name: "Floor 4: The Rootfall"
enemy_list:
  - {enemy_id: "thorn_guardian", count: 3}
expected_clear_time_seconds: 90
is_boss_floor: false
flavor_text: "The canopy has closed. Thorn lattices seal the sky. Three shapes in the dark are already moving."
```

**Rationale**: Single-archetype attrition floor; all bruiser, Warrior showcase. 3 Thorn Guardians creates pre-boss exhaustion without becoming a wall. Total HP = 2040. **See C.7 — HP model predicts ~176s at L11 formation; Orchestrator round-cadence decision resolves which target is correct.**

**Matchup distribution**: Warrior 3 / Mage 0 / Rogue 0 — strongest per-floor matchup delta in the dungeon. Warrior-heavy formation earns 3×120g = 360g (vs 240g neutral).

#### Floor 5 — The Rootking's Hollow (BOSS)

```yaml
id: "forest_reach_f5"
floor_index: 5
display_name: "Floor 5: The Rootking's Hollow"
enemy_list:
  - {enemy_id: "ancient_rootking", count: 1}
expected_clear_time_seconds: 170
is_boss_floor: true
flavor_text: "The roots here remember everything. The Rootking is not angry. It simply cannot allow the guild to continue."
```

**Rationale**: Boss-only floor. `is_boss_floor: true` triggers boss-death sequence. Pass 2B locked `ancient_rootking.base_hp = 4818` precisely so an L13 W+M+R formation under neutral matchup at the default `SPEED_BASE = 2400` clears in 170 s — derivation `ceili(170 × 20 × 1.417) = 4818` against weighted_sum 3400 / DPS 1.417 per Combat GDD #11 D.7 / G.2. The deprecated round-model heuristic ("130 ATK × 10s/round") is superseded by the per-enemy integer ceiling kill schedule (Combat Rule 10 / D.5). Total HP = **4818** (Pass 2B; was 2200).

**Matchup distribution**: Warrior 1 / Mage 0 / Rogue 0. 120g kill with Warrior (vs 80g neutral) + 18,000g floor-clear bonus = 18,120g total.

### C.3 V1.0 Biome Stubs — Name + Description Only

**Sunken Ruins** — `status: "planned_v1"`, palette `"ochre_dusk_purple"`, dominant archetypes `["incorporeal", "caster"]`. Cleric class showcase. *"A trading post that slipped below the waterline three centuries ago. The structures are still standing. Their former occupants are also still standing, which is the problem."* No enemy_list.

**Ember Cavern** — `status: "planned_v1"`, palette `"ember_rust_charcoal"`, dominant archetypes `["construct", "bruiser"]`. Tactician class showcase. *"The guild's cartographers marked this mountain as dormant. The things living inside its heat appear to have a different interpretation of that word."* No enemy_list.

**Thornwood Depths** — `status: "planned_v1"`, palette `"dusk_purple_dead_sage"`, dominant archetypes `["beast", "armored"]`. Ranger class showcase; darkest biome. *"Deeper than the Forest Reach, darker than anything the lanterns were built for."* No enemy_list.

**Arcane Spire** — `status: "planned_v1"`, palette `"parchment_cream_gold"`, dominant archetypes `["caster", "incorporeal"]`. V1.0 finale biome; Mage + Cleric counter showcase. *"Whatever the spire was built to contain has long since gotten loose."* No enemy_list.

### C.4 Archetype Distribution Validation Matrix

| Floor | Total | bruiser | caster | armored | Warrior bonus | Mage bonus | Rogue bonus |
|---|---|---|---|---|---|---|---|
| F1 | 4 | 3 | 1 | 0 | 3 | 1 | 0 |
| F2 | 5 | 2 | 1 | 2 | 2 | 1 | 2 |
| F3 | 5 | 2 | 2 | 1 | 2 | 2 | 1 |
| F4 | 3 | 3 | 0 | 0 | 3 | 0 | 0 |
| F5 | 1 | 1 | 0 | 0 | 1 | 0 | 0 |
| **Total** | **18** | **11** | **4** | **3** | **11** | **4** | **3** |

**Invariant check**: F1–F3 expose all three counter archetypes. F4–F5 intentional single-archetype (Warrior showcase — locked per Enemy DB C.2). F1 zero-armored is intentional (one-new-concept-per-floor onboarding ramp).

### C.5 States and Transitions

Static data. Same LOADED / UNAVAILABLE pattern as Enemy DB and Hero Class DB. Schema validation at load time: `enemy_list` non-empty; all `enemy_id` strings resolve against Enemy DB; `floor_index` unique within dungeon; `is_boss_floor=true` → enemy_list contains `is_boss=true` enemy; `status` in `{"active", "planned_v1"}`.

**`planned_v1` filter**: V1.0 stubs load as LOADED (data valid, dungeons empty), but Floor/Biome Unlock System filters them from UI surfaces. Stubs must load cleanly so future V1.0 builds can flip `status → "active"` without data migration.

### C.6 System Interactions

| Consumer | Reads | Contract |
|---|---|---|
| **Formation Assignment System (#17)** | `Biome.*`, `Dungeon.*`, `Floor.enemy_list`, `Floor.is_boss_floor` | Populates matchup-planning UI; reads `dominant_archetypes` for tooltip |
| **Dungeon Run Orchestrator (#13)** | `Floor.enemy_list`, `Floor.floor_index`, `Floor.is_boss_floor` | Builds encounter roster at run start; looks up `BASE_DRIP[floor_index]` and `FLOOR_CLEAR_BONUS[floor_index]` from Economy; triggers boss-death fanfare on `is_boss_floor` |
| **Floor/Biome Unlock System (#16)** | `Biome.status`, `Floor.floor_index`, `Floor.is_boss_floor` | Filters `planned_v1` biomes; tracks per-floor first-clear state |
| **Matchup Assignment Screen (#23)** | `Biome.dominant_archetypes`, `Floor.enemy_list` | Displays per-enemy archetype icons + biome-level counter hint |
| **Dungeon Run View (#24)** | `Biome.primary_palette_key`, `Biome.environmental_storytelling`, `Floor.id`, `Floor.flavor_text`, `Floor.is_boss_floor` | Applies atmospheric lighting; populates background props; title card |

### C.7 Systems Integration Notes

*Validation by systems-designer against Economy + Enemy DB pacing. Five flags documented.*

**VALIDATE — Kill cadence matches for F1, F2, F5; F3–F4 tension**:
- F1: 4 enemies × 10s = 40s ✓ target 40s
- F2: 5 × 10s ≈ 55s ✓ target 55s (within 10% rounding)
- F3: **RESOLVED Pass 2B 2026-04-20** — target revised 60s → **85s** per Combat GDD #11 D.7 tick-model: `ceili(985 / 0.580) / 20 = 85.0 s` at L6 W+M+R neutral matchup. Legacy HP-model "120s under uniform 10s/round" superseded by Combat's per-tick cadence. Combat GDD #11 I.Q1 CLOSED.
- F4: HP-model (2040 ÷ 116 × 10s) = **176s**, but target is 90s — **~2× mismatch**
- F5: **Combat-tick model** (authoritative, Pass 2B): `ceili(4818 / 1.417)/20 = 170.05s ≈ 170s target ✓` under SPEED_BASE=2400, L13 W+M+R neutral matchup. Legacy HP-model (round-based) superseded by Combat GDD #11's per-enemy tick cadence.

**Two valid models, one reconciliation**: The game-designer's targets assume **variable seconds-per-round** (shorter at high-ATK/low-HP ratios — e.g., 7s/round at F3 where per-hit kills are fast). The systems-designer's HP-model assumes **uniform 10s/round**. F5 validates both because the boss is a single long fight where both models converge.

**Disposition**: `expected_clear_time_seconds` is a design target, not a runtime enforcement. Keep the current values (40/55/60/90/170) as aspirational targets. The Dungeon Run Orchestrator GDD (#13) will lock the actual round-to-tick cadence; if it chooses uniform 10s/round, F3 and F4 targets bump to ~120s and ~176s respectively. **Flagged as Open Question.**

**WARN — Clear bonus dominates kill income at every floor, extreme ratio at F5**:

| Floor | Kill income | Clear bonus | Ratio |
|---|---|---|---|
| F1 | 60g | 500g | 1:8.3 |
| F2 | 75g | 1,200g | 1:16 |
| F3 | 175g | 3,000g | 1:17 |
| F4 | 240g | 7,500g | 1:31 |
| F5 | 80g | 18,000g | 1:226 |

F5's extreme ratio is a structural artifact (1 kill on boss floor) but is design-intentional — the boss clear is the session milestone. Matchup gold delta stays meaningful through F4 (+120g on F4 = 50% bonus), becomes negligible at F5 in percentage terms but still legible as absolute value on return-to-app screens.

**WARN — Offline clear-bonus inflation risk (CRITICAL integration constraint)**:

At 8h offline cap, F5 allows 169 replays. If clear bonus retriggers per replay: 169 × 18,000g = **3.04M gold** per offline session — breaks economy pacing entirely.

**Constraint for Offline Progression Engine (#12) GDD**: Specify whether `FLOOR_CLEAR_BONUS` fires per replay during offline or only once per session. **Recommended resolution**: clear bonus fires once per floor per offline batch; subsequent replays credit only kill income and drip. This must be locked before Offline Engine authoring. **Flagged as Open Question owned by Offline Engine GDD.**

**RECOMMEND — F1 archetype coverage (informational)**:
F1 missing armored enemy means Rogue has no counter target on the tutorial floor. Two valid positions:
- **Keep as-is** (chosen): "one new concept per floor" onboarding ramp; Rogue introduced cleanly on F2. Warrior + Mage dominate F1.
- **Alternative**: Replace 1× hollow_brute with 1× shellback for full-archetype tutorial on F1.

**Disposition**: Current draft keeps F1 Rogue-counter-free. Tutorial copy (Onboarding GDD #29) should contextualize so early Rogue players aren't confused.

**VALIDATE — Registry consistency**:
All 8 enemy HP values in the floor compositions match `design/registry/entities.yaml` exactly (hollow_brute 52 / glowmoth 60 / shellback 72 / elder_boar 195 / moss_druid 185 / vined_knight 225 / thorn_guardian 680 / **ancient_rootking 4818** per Pass 2B). No registry drift. **F5 HP update 2026-04-20**: ancient_rootking raised 2200 → 4818 (Enemy DB + entities.yaml updated in lockstep per Combat GDD #11 I.Q2 resolution).

---

## D. Formulas / Pacing

### D.1 Floor Total HP

```
total_floor_hp = Σ (enemy.base_hp × count)  for each entry in floor.enemy_list
```

**Per-floor totals**: F1 = 216, F2 = 308, F3 = 985, F4 = 2040, F5 = **4818** (Pass 2B, was 2200). Growth ratios: F1→F2 = ×1.4, F2→F3 = ×3.2 (tier jump), F3→F4 = ×2.1, F4→F5 = ×2.36 (Pass 2B: was ×1.08 under old F5=2200; the new ratio reflects the 170 s boss fight being a genuine HP-wall climax, not a stat-inflation of F4-elites).

### D.2 Gold Earned per Floor Clear

```
floor_kill_gold(floor, matchup_mult) = Σ (BASE_KILL[enemy.tier] × matchup_mult × count)
floor_total_income = floor_kill_gold + FLOOR_CLEAR_BONUS[floor_index]
```

Where `BASE_KILL[1]=10`, `BASE_KILL[2]=35`, `BASE_KILL[3]=80` (Pass 4B-Economy A3 reconciliation 2026-04-20 — prior value `BASE_KILL[1]=15` was stale; see Economy review log); `FLOOR_CLEAR_BONUS` = `[500, 1200, 3000, 7500, 18000]` (1-based per Pass 4A D.6); `matchup_mult` applied per-kill (1.5 if counter matches, else 1.0). **Pacing table below was computed under the old `BASE_KILL[1]=15` assumption — flagged for recomputation at next tuning review; flag is tech debt not blocking (MVP pacing differences are small and are invisible below the first-playtest tuning threshold).**

| Floor | Kill gold (neutral) | Kill gold (full advantage) | Matchup delta | Floor-clear bonus | Total neutral | Total full-advantage |
|---|---|---|---|---|---|---|
| F1 | 60g | 88g | +28g | 500g | **560g** | **588g** |
| F2 | 75g | 110g | +35g | 1,200g | **1,275g** | **1,310g** |
| F3 | 175g | 260g | +85g | 3,000g | **3,175g** | **3,260g** |
| F4 | 240g | 360g | +120g | 7,500g | **7,740g** | **7,860g** |
| F5 | 80g | 120g | +40g | 18,000g | **18,080g** | **18,120g** |

**Matchup decision peak**: F3 is where matchup-earned gold is most proportionally significant (+85g delta before tier-3 clear bonuses dominate).

### D.3 Offline Session Math — Floors Cleared per 8-Hour Session

```
max_clears = floor(28800 / expected_clear_time_seconds)
```

| Floor | Clear (s) | Max 8h clears | Gold/clear | Total 8h (assuming clear bonus retriggers) |
|---|---|---|---|---|
| F1 | 40 | 720 | 560g | 403,200g |
| F2 | 55 | 523 | 1,275g | 666,825g |
| F3 | 60 | 480 | 3,175g | 1,524,000g |
| F4 | 90 | 320 | 7,740g | 2,476,800g |
| F5 | 170 | 169 | 18,080g | 3,055,520g |

> **⚠ CRITICAL**: The above totals assume `FLOOR_CLEAR_BONUS` retriggers per replay. If the Offline Engine GDD locks clear-bonus as first-clear-only during offline batches (recommended per C.7), these totals drop by ~95% — e.g., F5 becomes 169 × 80g kill + 18,000g one-shot bonus = **31,520g**, not 3.05M. **Resolution pending Offline Engine GDD.**

---

## E. Edge Cases

- **If a player assigns formation to a locked floor**: Formation Assignment UI should prevent this; if bypassed, Dungeon Run Orchestrator checks `FloorUnlock.is_unlocked(floor.floor_index)` at DISPATCHING (per Floor/Biome Unlock System GDD #16 §C.3) and rejects with `validation_failed("floor_locked", {floor_index})` → `RUN_ENDED`. No gold accrues. **2026-04-20 Floor-Unlock-Propagation-Edit-1**: signature updated from the retired `FloorUnlockSystem.is_floor_unlocked(floor_id: String)` form to the authoritative `FloorUnlock.is_unlocked(floor_index: int)` locked by AC-ORC-13; single-source signature owned by GDD #16 §C.1 R1.

- **If a floor's `enemy_list` references a non-existent `enemy_id`**: Load-time validation rejects the Floor (UNAVAILABLE). Parent Dungeon → UNAVAILABLE. Parent Biome → UNAVAILABLE if it has no other valid dungeons. Error logged: `[DataRegistry] FLOOR LOAD FAILURE: forest_reach_f3 references unknown enemy_id 'vine_knight'`. Caught at boot, not runtime.

- **If `is_boss_floor=true` but `enemy_list` has no `is_boss=true` enemy**: Warning logged at load: `[BiomeDungeonDB] WARN: floor 'forest_reach_f5' has is_boss_floor=true but enemy_list[0].enemy_id='thorn_guardian' has is_boss=false`. Floor loads; boss fanfare triggers on wrong enemy. QA-catch via H-05.

- **If two floors share the same `floor_index` within a dungeon**: Load-time validation rejects the dungeon: `[BiomeDungeonDB] DUPLICATE FLOOR_INDEX: dungeon 'forest_reach_dungeon_01' has two floors with floor_index=2`. Dungeon → UNAVAILABLE.

- **If `enemy_list` is empty on a non-boss floor**: Load rejection: `[BiomeDungeonDB] INVALID FLOOR: 'forest_reach_f1' has empty enemy_list`. An instant-clear floor would award free floor-clear bonus, breaking economy. Hard rejection.

- **If a biome has no dungeons**: Biome loads; Floor/Biome Unlock filters it from UI (no floors → can't dispatch). Warning logged. Forward-compat for partially-authored V1.0 biomes.

- **If a V1.0 `"planned_v1"` biome loaded in MVP**: Loads as LOADED (valid schema, empty dungeons). Floor/Biome Unlock excludes from assignment UI. No error. Forward-compat.

- **If floor clear time wildly exceeds `expected_clear_time_seconds`**: `expected_clear_time` is a design target, not runtime cap. No runtime error; soft feedback ("your formation is under-leveled"). QA flags if a max-level formation exceeds 2× expected (formula error signal).

- **If an enemy is removed from Enemy DB but still referenced in a floor**: E.2 case. Load rejects floor. Migration checklist: cross-reference all floor `enemy_list` ids against enemy registry before removing any enemy.

---

## F. Dependencies

### Upstream Dependencies

| Upstream | Hard/Soft | Interface |
|---|---|---|
| **Data Loading System** (`design/gdd/data-loading.md`) | Hard | `DataRegistry.resolve("biomes"/"dungeons"/"floors", id) -> Resource \| null`; schema validation at load |
| **Enemy Database** (`design/gdd/enemy-database.md`) | Hard | Floor `enemy_list` references `enemy.id`; `is_boss_floor` cross-checks against `enemy.is_boss`; archetype distribution invariant from Enemy DB C.2 is respected here |
| **Economy System** (`design/gdd/economy-system.md`) | Hard — read-through | Floor `floor_index` looks up `BASE_DRIP[floor_index]` and `FLOOR_CLEAR_BONUS[floor_index]`; this GDD references Economy's registered constants but does not own them |
| **Art Bible** (`design/art/art-bible.md`) | Hard — contract | `primary_palette_key` references Section 4 color system; `environmental_storytelling` prop keys reference Section 6 |

### Downstream Dependents

| Consumer | Hard/Soft | What they read |
|---|---|---|
| **Formation Assignment System (#17)** | Hard | Full biome/dungeon/floor structure; `dominant_archetypes`, `enemy_list`, `is_boss_floor` |
| **Dungeon Run Orchestrator (#13)** | Hard | `floor.enemy_list`, `floor_index`, `is_boss_floor` |
| **Floor/Biome Unlock System (#16)** | Hard | `biome.status`, `floor.floor_index`, `floor.is_boss_floor` |
| **Matchup Assignment Screen (#23)** | Hard | `biome.dominant_archetypes`, `floor.enemy_list` |
| **Dungeon Run View (#24)** | Hard | `biome.primary_palette_key`, `biome.environmental_storytelling`, `floor.flavor_text`, `is_boss_floor` |

### Bidirectional Consistency

- `design/gdd/data-loading.md` ✅ lists this as hard dependent
- `design/gdd/enemy-database.md` ✅ lists this as hard dependent ("Biome & Dungeon DB reads enemy list to compose floor encounter pools")
- **Cross-GDD pact**: Biome `primary_palette_key` strings must match Art Bible color-system keys. Art Bible is authoritative for those strings.

---

## G. Tuning Knobs

### G.1 Per-Floor `enemy_list` (Primary Tuning Surface)

| Knob | Current | Safe range | Effect |
|---|---|---|---|
| F1 hollow_brute count | 3 | 2–4 | Onboarding kill pace |
| F1 glowmoth count | 1 | 0–2 | Caster tutorial presence |
| F2 shellback count | 2 | 1–3 | Armored presence on complete-vocabulary floor |
| F3 elder_boar count | 2 | 1–3 | Bruiser weight at Tier-2 intro |
| F3 moss_druid count | 2 | 1–3 | Caster weight; reduce if F3 HP total too high |
| F3 vined_knight count | 1 | 1–2 | Armored anchor |
| F4 thorn_guardian count | 3 | 2–4 | Pre-boss attrition |

**When to tune**: First-playtest validates clear times vs Section D.1 targets. If any floor deviates >20% from target at expected formation level, adjust count first (safer than HP — no cross-system side effects). Never reduce below 1 enemy.

### G.2 Per-Floor `expected_clear_time_seconds`

| Floor | Current | Safe range |
|---|---|---|
| F1 | 40s | 25–60s |
| F2 | 55s | 40–80s |
| F3 | **85s** (Pass 2B; was 60s) | 65–105s |
| F4 | 90s | 60–150s (may need 176s per C.7) |
| F5 | 170s | 120–240s |

Design target, not runtime enforcement. Update when observed divergence is validated.

### G.3 Per-Biome Tuning (Lower Leverage)

- `dominant_archetypes` order — UI signal only
- `environmental_storytelling` prop list — ≥2 required per Art Bible Section 4
- `flavor_text` — soft 200 char limit (biome), 120 char (floor)

---

## H. Acceptance Criteria

All criteria use Given-When-Then format. 11 criteria total (10 BLOCKING + 1 ADVISORY).

### H-01 — All MVP Biome / Dungeon / Floor Resources Resolvable (Integration, BLOCKING)

**GIVEN** Data Loading is `READY` with Forest Reach biome + 1 dungeon + 5 floors registered,
**WHEN** `DataRegistry.resolve("biomes", "forest_reach")`, `.resolve("dungeons", "forest_reach_dungeon_01")`, and `.resolve("floors", "forest_reach_f{n}")` called for n=1..5,
**THEN** every call returns non-null; `id` matches query; no error logged; system remains READY.

*Verification*: parameterized integration test across 7 ids.

### H-02 — Forest Reach = 1 Dungeon × 5 Floors (Logic, BLOCKING)

**GIVEN** Forest Reach biome loaded,
**WHEN** `biome.dungeons` and `dungeons[0].floors` read,
**THEN** `dungeons.size() == 1`; `dungeons[0].biome_id == "forest_reach"`; `dungeons[0].floors.size() == 5`; any other count fails.

### H-03 — floor_index Unique, Sequential, Gap-Free (Logic, BLOCKING)

**GIVEN** all 5 Forest Reach floors loaded,
**WHEN** each `floor_index` read,
**THEN** collected set == `{1, 2, 3, 4, 5}` exactly; sorted sequence is monotonic step-1; no duplicates, no gaps, no out-of-range.

### H-04 — enemy_list References Valid Enemy DB ids (Integration, BLOCKING)

**GIVEN** Enemy DB has 8 MVP resources + 5 Forest Reach floors loaded,
**WHEN** each `floor.enemy_list[i].enemy_id` passed to `DataRegistry.resolve("enemies", enemy_id)`,
**THEN** every resolution returns non-null; referenced ids are subset of {hollow_brute, glowmoth, shellback, elder_boar, moss_druid, vined_knight, thorn_guardian, ancient_rootking}.

### H-05 — Exactly One is_boss_floor, Contains Boss Enemy (Logic, BLOCKING)

**GIVEN** all 5 floors + 8 enemies loaded,
**WHEN** `is_boss_floor` read per floor, and boss floor's `enemy_list` resolved,
**THEN** exactly one floor (F5) has `is_boss_floor == true`; that floor's enemy_list contains ≥1 enemy with `is_boss == true` (Ancient Rootking); zero boss floors or multiple boss floors fail; boss floor with no is_boss=true enemy fails.

### H-06 — Archetype Distribution: F1–F4 Cover At Least One MVP Archetype (Integration, BLOCKING)

**GIVEN** F1–F4 loaded with enemies resolved,
**WHEN** archetype set computed per floor,
**THEN** each contains ≥1 enemy in `{"bruiser", "caster", "armored"}`; F5 excluded (single-archetype boss is documented design decision per Enemy DB C.2).

### H-07 — V1.0 Stubs Load with status="planned_v1" (Logic, BLOCKING)

**GIVEN** 4 V1.0 stub biomes present (`status: "planned_v1"`, empty dungeons),
**WHEN** `DataRegistry.resolve("biomes", stub_id)` called for each,
**THEN** each returns non-null; `status == "planned_v1"`; `dungeons.size() == 0`; no error; stubs don't trigger `MIN_CONTENT_COUNT` error.

### H-08 — V1.0 Stubs Excluded from Playable Biome List (Logic, BLOCKING)

**GIVEN** DataRegistry READY with 5 biomes (1 MVP + 4 stubs),
**WHEN** playable biome query called (`get_playable_biomes()` or equivalent filter),
**THEN** list contains exactly 1 biome (Forest Reach, `status="active"`); 4 stubs absent; full registry count remains 5.

### H-09 — Empty enemy_list on Non-Boss Floor Rejected at Load (Logic, BLOCKING)

**GIVEN** a FloorData `.tres` with `is_boss_floor: false` and `enemy_list: []`,
**WHEN** Data Loading processes it,
**THEN** `push_error` logged with floor id + empty list reason; resource rejected (not registered); `resolve()` returns null; other floors continue loading.

*Note*: Boss floors with 1-entry enemy_list (e.g., F5 with ancient_rootking) are valid.

### H-10 — Save File Biome/Floor References Resolve After Restore (Integration, BLOCKING)

**GIVEN** save file containing serialized biome/floor id refs (`"forest_reach"`, `"forest_reach_f3"`) + DataRegistry booted fresh,
**WHEN** `resolve("biomes", "forest_reach")` and `resolve("floors", "forest_reach_f3")` called during Save/Load restore,
**THEN** both return non-null identical to fresh-boot return values (cache consistency); fields round-trip correctly; no null dereference.

### H-11 — flavor_text Character Limits (Config/Data, ADVISORY)

**GIVEN** all BiomeData + FloorData with `flavor_text`,
**WHEN** string length measured,
**THEN** biome flavor_text ≤ 200 chars; floor flavor_text ≤ 120 chars; overrun reported as warning, not fatal; UI truncates with ellipsis.

*Gate = ADVISORY*: truncation prevents player-visible breakage.

### Classification Summary

| ID | Description | Type | Gate |
|---|---|---|---|
| H-01 | All biome/dungeon/floor resources resolvable | Integration | BLOCKING |
| H-02 | Forest Reach = 1 dungeon × 5 floors | Logic | BLOCKING |
| H-03 | floor_index unique, sequential, gap-free | Logic | BLOCKING |
| H-04 | enemy_list references valid Enemy DB ids | Integration | BLOCKING |
| H-05 | Exactly one boss floor with is_boss=true enemy | Logic | BLOCKING |
| H-06 | Archetype distribution F1–F4 covers MVP archetypes | Integration | BLOCKING |
| H-07 | V1.0 stubs load with planned_v1 status | Logic | BLOCKING |
| H-08 | V1.0 stubs excluded from playable list | Logic | BLOCKING |
| H-09 | Empty non-boss enemy_list rejected | Logic | BLOCKING |
| H-10 | Save file refs resolve after restore | Integration | BLOCKING |
| H-11 | flavor_text character limits | Config/Data | ADVISORY |

---

## I. Open Questions

| Question | Owner | Target Resolution |
|---|---|---|
| **F3/F4 expected_clear_time_seconds** — **F3 RESOLVED 2026-04-20 Pass 2B**: target revised 60s → **85s** per Combat GDD #11 D.7 tick-model derivation. F4 target (90s) is within tolerance of Combat-tick prediction (89.5s at L11 W+M+R neutral matchup — 0.6% under target); no revision required. | ~~systems-designer + Orchestrator GDD author~~ | ~~Before Orchestrator GDD authoring~~ — **F3 CLOSED**; F4 stable |
| **Offline clear-bonus retrigger policy** — does `FLOOR_CLEAR_BONUS` fire per offline replay or only once per batch? Recommended: once per batch (prevents 3M-gold F5 inflation). Must be locked before Offline Engine GDD (#12). | economy-designer + Offline Engine GDD author | Before Offline Engine GDD |
| **F1 Rogue-counter deferral** — current design has zero armored on Floor 1. Tutorial copy (Onboarding GDD #29) must contextualize why Rogue feels sidelined in Session 1. Alternative: add 1× shellback to F1. | game-designer + ux-designer | First MVP playtest |
| **V1.0 biome floor composition** — 4 stubs have no enemy_list. When V1.0 scope is locked, each biome needs 3-5 floors designed. Per-biome design effort comparable to Forest Reach. | game-designer | V1.0 scope planning |
| **Multi-dungeon biomes** — schema allows `biome.dungeons[]` arrays of length >1, but MVP and V1.0 stubs all use exactly 1. If a V1.0+ biome adds a second dungeon (e.g., Sunken Ruins Upper + Lower), Floor/Biome Unlock System's gating model needs expansion. | game-designer + systems-designer | V2.0+ |
| **Per-floor modifiers (V1.0 events)** — e.g., "Blood Moon" floors with +50% enemies or matchup-suppression events. Current schema has no `modifier_list` field. Defer until live-ops design. | live-ops-designer | Post-launch |

---

*This GDD registers Forest Reach + 1 dungeon + 5 floors in `design/registry/entities.yaml`. Floor enemy references cross-link against the 8 enemies registered by Enemy DB.*
