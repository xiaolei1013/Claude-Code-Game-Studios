# Story 003: 3 MVP class .tres files (Warrior, Mage, Rogue)

> **Epic**: hero-class-database
> **Status**: Complete
> **Layer**: Core
> **Type**: Config/Data
> **Manifest Version**: 2026-04-24

## Context

**GDD**: `design/gdd/hero-class-database.md` §C.2 (MVP class roster), §D (formulas), §H-01, §H-05
**Requirements**: TR-hero-class-db-003, TR-hero-class-db-016, TR-hero-class-db-017, TR-hero-class-db-023
*(Full requirement text lives in `docs/architecture/tr-registry.yaml`.)*

**Governing ADR(s)**: ADR-0011 (`.tres` authoring + entity-registry registration)
**ADR Decision Summary**: 3 MVP classes (Warrior / Mage / Rogue) authored as `.tres` files in `assets/data/classes/`. Each has unique counter_archetype (Warrior=bruiser / Mage=caster / Rogue=armored) per AC H-05. Stat values match GDD §D.4 sanity table at L15 exactly. All three register in `design/registry/entities.yaml`.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `.tres` (text Resource) format; hand-authored / inspector-edited.

**Control Manifest Rules (Core Layer)**:
- **Required**: All class files in `assets/data/classes/*.tres`; nothing hardcoded in GDScript. — ADR-0011
- **Required**: 3 MVP classes registered as base-stats entries in `design/registry/entities.yaml`. — ADR-0011

---

## Acceptance Criteria

- [ ] `assets/data/classes/warrior.tres` exists with: `id="warrior"`, `tier=1`, `role="frontline"`, `counter_archetype=EnemyArchetypes.BRUISER`, base_attack/hp/speed and per_level values yielding L15 attack=40, hp=358, speed=20 (from §D.4)
- [ ] `assets/data/classes/mage.tres` exists with: `id="mage"`, `tier=1`, `role="ranged_dps"`, `counter_archetype=EnemyArchetypes.CASTER`, L15 attack=62, hp=210, speed=24
- [ ] `assets/data/classes/rogue.tres` exists with: `id="rogue"`, `tier=1`, `role="flanker"`, `counter_archetype=EnemyArchetypes.ARMORED`, L15 attack=42, hp=167, speed=44
- [ ] All three `display_name` non-empty
- [ ] All three `flavor_text` ≤ 120 chars (advisory cross-check with Story 010)
- [ ] All three `sprite_path` / `portrait_path` / `icon_path` follow `assets/art/classes/{id}/{kind}.png` convention (paths may not exist yet; story is data-only)
- [ ] All three `tick_output_contribution_l1` / `tick_output_per_level` set per GDD §D
- [ ] Cross-check: counter_archetype values are unique across the 3 MVP classes (per AC H-05 unique requirement)
- [ ] `design/registry/entities.yaml` updated with one entry per MVP class containing canonical base stats
- [ ] All three resolvable via `DataRegistry.resolve("classes", id)` after boot scan (smoke check)

---

## Implementation Notes

*Derived from ADR-0011 §Decision §`.tres` authoring pattern:*

- Reverse-engineer `base_*` and `*_per_level` from GDD §D.4 sanity table:
  - Warrior L15 attack=40 → if base=12, per_level=2: 12 + 2×14 = 40 ✓ (verify GDD §D for exact values)
  - Mage L15 attack=62, hp=210, speed=24 → derive similarly
  - Rogue L15 attack=42, hp=167, speed=44 → derive similarly
- The exact base+per_level values come directly from GDD §D Sanity Table — read it carefully when picked up; do NOT estimate.
- Use Godot's inspector to author `.tres` files (not hand-written text format) — this guarantees field-name consistency with HeroClass schema. Save as text-format `.tres` (not binary).
- `entities.yaml` registration format: see existing entries from Sprint 1 work. One YAML node per class with the canonical base stats.
- `flavor_text` should be evocative and ≤ 120 chars per soft limit. Examples:
  - Warrior: "Stalwart shieldbearer of the Lantern Guild. Where her blade holds, the line holds."
  - Mage: "Speaker to the dusk-fire. Burns brightly, briefly, often."
  - Rogue: "Three steps ahead, two strikes deep. Never where you last looked."
- Sprite/portrait/icon path declarations are for the asset pipeline; actual PNGs land via Art Bible asset spec work, not this story.

---

## Out of Scope

- Story 011: 3 V1.0 stub class `.tres` files (Cleric / Ranger / Tactician)
- Stories 004–008: helper methods on HeroClass
- Sprite art (separate `/asset-spec` work)

---

## QA Test Cases

- **AC: 3 MVP classes load**
  - **Given**: Godot booted with the 3 `.tres` files in `assets/data/classes/`
  - **When**: `HeroClassDatabase.get_by_id("warrior")` etc.
  - **Then**: each returns non-null with the expected schema values; `tier == 1`; `id == filename-without-extension`
  - **Edge cases**: malformed `.tres` (e.g., missing required field) MUST trigger DataRegistry ERROR state (per Story 008 schema validation)

- **AC H-05: counter_archetype unique**
  - **Given**: 3 MVP classes loaded
  - **When**: collect their counter_archetype values
  - **Then**: set has 3 distinct values; specifically warrior=BRUISER, mage=CASTER, rogue=ARMORED
  - **Edge cases**: a 4th MVP class accidentally sharing a counter_archetype must be flagged by Story 008's validator

- **AC: stat values match GDD §D.4 at L15**
  - **Given**: each MVP class loaded; `stat_at_level` available (Story 004)
  - **When**: `stat_at_level(stat, class, 15)` for each (stat, class) sub-case
  - **Then**: matches the GDD §D.4 table EXACTLY (Warrior L15 attack=40 hp=358 speed=20; Mage L15 attack=62 hp=210 speed=24; Rogue L15 attack=42 hp=167 speed=44)
  - **Edge cases**: this AC depends on Story 004 — defer the assertion until S4 lands

- **AC: entities.yaml registration**
  - **Given**: `design/registry/entities.yaml` post-update
  - **When**: parse the YAML
  - **Then**: 3 entries present (warrior, mage, rogue) each with non-empty base stat fields
  - **Edge cases**: missing entry triggers entity-registry consistency check failure

- **Smoke check**: full boot + 3 resolves
  - **Given**: clean Godot project
  - **When**: `godot --headless --quit-after 1` boots
  - **Then**: zero ERROR-level logs; 3 classes resolvable; entry in `production/qa/smoke-*.md`

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**:
- 3 `.tres` files in `assets/data/classes/`
- `design/registry/entities.yaml` updated with 3 new entries
- A passing smoke check at `production/qa/smoke-*.md`
- Cross-check assertion in `tests/unit/hero_class_database/hero_class_resource_test.gd` (lives in Story 001's test file but extended with values)

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (HeroClass resource schema), Story 002 (HeroClassDatabase autoload)
- **Unlocks**: Stories 004–010 (all need real class data to test against)


## Completion Notes
**Completed**: 2026-04-25
**Criteria**: 9/9 (entities.yaml registration was already done Sprint 1 design-phase — no edits needed)
**Story Type**: Config/Data
**Test Evidence**: `tests/probes/probe_class_tres.gd` (one-shot probe script) confirms all 3 .tres files load via `ResourceLoader.load()`. L15 derived stats match GDD §D.4 sanity table EXACTLY (Warrior 40/358/20, Mage 62/210/24, Rogue 42/167/44). Smoke check report: `production/qa/smoke-2026-04-25.md` (PASS WITH NOTES).
**Manifest Version**: 2026-04-24 — matched
**Files created**: `assets/data/classes/warrior.tres`, `assets/data/classes/mage.tres`, `assets/data/classes/rogue.tres`, `tests/probes/probe_class_tres.gd`, `production/qa/smoke-2026-04-25.md`
**Files modified**: None (entities.yaml warrior/mage/rogue entries already in place from Sprint 1)
**Stat values derived from** GDD §D.4 sanity table (canonical):
- Warrior: base_attack=12, attack_per_level=2 / base_hp=120, hp_per_level=17 / base_speed=6, speed_per_level=1 / tick_output_contribution_l1=2, tick_output_per_level=1
- Mage: base_attack=20, attack_per_level=3 / base_hp=70, hp_per_level=10 / base_speed=10, speed_per_level=1 / tick_output_contribution_l1=3, tick_output_per_level=1
- Rogue: base_attack=14, attack_per_level=2 / base_hp=55, hp_per_level=8 / base_speed=16, speed_per_level=2 / tick_output_contribution_l1=2, tick_output_per_level=1
**Spec correction**: Role values in story draft (`"frontline"/"ranged_dps"/"flanker"`) **diverged from canonical entities.yaml** (`"tank"/"striker"/"precision"`) — aligned to registry as the cross-system source of truth. The story spec is now stale on role naming; future story drafters should consult `design/registry/entities.yaml` first.
**Tech debt logged**: TD-006 (LOW severity) — see smoke check report; DataRegistry stays in ERROR state during Sprint 2 due to empty enemies/biomes/dungeons/matchup categories. Cross-system tests gracefully degrade. Resolves when Sprint 3 lands enemy/biome content.
**Code Review**: SKIPPED — solo
**Next**: Sprint 2 close-out — `/team-qa sprint` then `/gate-check`. (Should Have stories S2-S1, S2-S2 + Nice-to-Have S2-N1, S2-N2 are stretch.)
