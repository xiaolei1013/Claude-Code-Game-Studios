# Story 003: 7+ MVP enemy .tres files (tier distribution + Ancient Rootking boss)

> **Epic**: enemy-database
> **Status**: Complete
> **Layer**: Core
> **Type**: Config/Data
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/enemy-database.md` §C, §D, §H-01, §H-03, §H-04, §H-07, §H-08, §H-11, §H-12
**Requirements**: TR-enemy-db-003, TR-enemy-db-008, TR-enemy-db-009, TR-enemy-db-016, TR-enemy-db-017, TR-enemy-db-020, TR-enemy-db-021
*(Full requirement text lives in `docs/architecture/tr-registry.yaml`.)*

**Governing ADR(s)**: ADR-0011 (`.tres` authoring + entity-registry registration)
**ADR Decision Summary**: 7+ MVP enemies authored as `.tres` files in `assets/data/enemies/`. Distribution invariants: Tier-1 + Tier-2 each contain one of each MVP archetype (BRUISER + CASTER + ARMORED); Tier-3 is bruiser-only. Exactly one is_boss=true enemy (Ancient Rootking, Tier-3, base_hp=4818). All HP values within tier-band ranges.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `.tres` (text Resource) format; hand-authored / inspector-edited.

**Control Manifest Rules (Core Layer)**:
- **Required**: All enemy files in `assets/data/enemies/*.tres`; nothing hardcoded in GDScript. — ADR-0011
- **Required**: All MVP enemies registered as base-stats entries in `design/registry/entities.yaml`. — ADR-0011

---

## Acceptance Criteria

- [ ] **AC H-01 + TR-enemy-db-016**: minimum 7 enemy `.tres` files at `assets/data/enemies/`. Recommended count to satisfy both `min_content_count.enemies = 5` AND tier-distribution invariants below: 7 enemies (3 Tier-1 + 3 Tier-2 + 1 Tier-3 boss).
- [ ] **AC H-03 + TR-enemy-db-008**: tier distribution — at least 3 Tier-1 (one per MVP archetype), at least 3 Tier-2 (one per MVP archetype), at least 1 Tier-3
- [ ] **AC H-04 + TR-enemy-db-008**: archetype balance — Tier-1 set contains exactly one BRUISER + one CASTER + one ARMORED; Tier-2 set contains exactly one BRUISER + one CASTER + one ARMORED
- [ ] **AC H-07 + TR-enemy-db-009**: exactly one enemy has `is_boss = true` (the Ancient Rootking)
- [ ] **TR-enemy-db-017**: Ancient Rootking has `tier = 3`, `is_boss = true`, `base_hp = 4818` (locked value per GDD §D)
- [ ] **AC H-08 + TR-enemy-db-016**: HP values within tier bands — verify against GDD §D calibration tables (e.g., Tier-1 HP in [50, 74]; Tier-2 HP in [162, 242]; Tier-3 elite HP in [540, 820]; Ancient Rootking HP = 4818)
- [ ] **TR-enemy-db-020**: every enemy `sprite_path` and `death_anim_key` non-empty
- [ ] **TR-enemy-db-021**: `flavor_text` ≤ 120 chars (advisory; warning not error)
- [ ] **AC H-04**: `archetype` field on each enemy is a member of `EnemyArchetypes.MVP_SET` (BRUISER / CASTER / ARMORED)
- [ ] All 7 enemies resolvable via `DataRegistry.resolve("enemies", id)` after boot scan (smoke check)
- [ ] `design/registry/entities.yaml` updated with one entry per MVP enemy (cross-check existing Sprint 1 prior art at line ~110+)

---

## Implementation Notes

*Derived from ADR-0011 §Decision §`.tres` authoring pattern. Read GDD §D for canonical HP / attack / speed values per enemy.*

- Reference the existing `entities.yaml` (Sprint 1 prior art): the 8 MVP enemies for Forest Reach are likely already enumerated with canonical base stats. Cross-check before authoring `.tres` to avoid drift. Names commonly authored: Tier-1 `hollow_brute` / `bog_caster` / `iron_husk`; Tier-2 elites; Ancient Rootking boss.
- Use Godot inspector to author `.tres` files (or hand-author text format with `[gd_resource type="Resource" script_class="EnemyData" format=3 ...]` mirroring Sprint 2 economy_config.tres + class .tres precedent).
- For each enemy:
  - `id` matches filename (snake_case, no `.tres`)
  - `display_name` is human-readable (e.g., "Hollow Brute")
  - `tier ∈ {1, 2, 3}` per distribution
  - `archetype` is one of `EnemyArchetypes.MVP_SET` lowercase strings
  - `biome` field set to "forest_reach" (or matches biome id authoring in BiomeDungeonDatabase Story 003)
  - `base_hp` / `base_attack` / `base_speed` from GDD §D calibration tables
  - `sprite_path` follows convention `assets/art/enemies/{id}/sprite.png` (paths may not exist yet; story is data-only)
  - `death_anim_key` non-empty (placeholder OK)
  - `flavor_text` ≤ 120 chars; evocative
  - `is_boss = false` for all except Ancient Rootking
- Author the Ancient Rootking last; it's the Tier-3 boss with base_hp = 4818 (TR-enemy-db-017 locks this value verbatim — set directly, not via formula).
- entities.yaml registration: append entries if not already present (Sprint 1 prior art may have entries that need value-confirmation).

---

## Out of Scope

- Story 004: load-time schema validation (rejects unknown archetype, etc.)
- Story 005: kill-gold cross-system formula
- V1.0 enemy stubs (deferred)
- Sprite art (separate `/asset-spec` work — paths declared but PNGs land later)

---

## QA Test Cases

- **AC: 7+ enemies load**
  - **Given**: 7+ enemy `.tres` files at `assets/data/enemies/`
  - **When**: `EnemyDatabase.get_by_id(id)` for each id
  - **Then**: each returns non-null EnemyData; `tier ∈ {1,2,3}`; `id == filename-without-extension`
  - **Edge cases**: smoke check probe script (mirror Sprint 2 `tests/probes/probe_class_tres.gd` pattern) confirms all enemies parse + load

- **AC H-03 + H-04: tier + archetype distribution**
  - **Given**: all MVP enemies loaded
  - **When**: collect `(tier, archetype)` tuples
  - **Then**: Tier-1 set = {(1,BRUISER), (1,CASTER), (1,ARMORED)} exactly; Tier-2 set = {(2,BRUISER), (2,CASTER), (2,ARMORED)} exactly; Tier-3 ≥ 1 entry
  - **Edge cases**: deviation from this distribution flagged by Story 004's validator at load time

- **AC H-07: exactly one boss**
  - **Given**: all MVP enemies loaded
  - **When**: count enemies with `is_boss == true`
  - **Then**: exactly 1; that enemy has `tier == 3` and `id == "ancient_rootking"`
  - **Edge cases**: 0 bosses → load FAIL; 2+ bosses → load FAIL (Story 004 validator)

- **AC H-08: HP within tier bands**
  - **Given**: each enemy's `base_hp`
  - **When**: compared against GDD §D calibration band for its tier
  - **Then**: every value within band; Ancient Rootking == 4818 exactly
  - **Edge cases**: out-of-band → push_warning at load (advisory) — alternative is hard rejection in Story 004 (decide when picked up)

- **AC: entities.yaml registration**
  - **Given**: `design/registry/entities.yaml` post-update
  - **When**: parse the YAML
  - **Then**: 7+ entries present (one per MVP enemy) each with non-empty base stat fields
  - **Edge cases**: missing entry triggers entity-registry consistency-check failure

- **Smoke check**: full boot + 7 enemy resolves
  - **Given**: clean Godot project
  - **When**: `godot --headless --quit-after 1` boots
  - **Then**: zero ERROR-level logs; 7 enemies resolvable; **DataRegistry transitions to READY** when combined with biome-dungeon-database Story 003's content (TD-006 closure)

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**:
- 7+ `.tres` files in `assets/data/enemies/`
- `design/registry/entities.yaml` updated (or confirmed already in place from Sprint 1)
- `tests/probes/probe_enemy_tres.gd` (one-shot probe — mirror Sprint 2 `probe_class_tres.gd` pattern)
- A passing smoke check report at `production/qa/smoke-*.md`

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (EnemyData resource schema), Story 002 (EnemyDatabase autoload), Sprint 1 EnemyArchetypes constants
- **Unlocks**: Story 005 (kill-gold cross-system needs real enemy.tier values), BiomeDungeonDatabase Story 003 (Forest Reach floors reference enemy_ids — must resolve)
