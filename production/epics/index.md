# Epics Index

> **Last Updated**: 2026-04-25
> **Engine**: Godot 4.6
> **Control Manifest Version**: 2026-04-24
> **Layers Processed**: Foundation ✅ · Core ✅ (4/5 — audio-system blocked on GDD) · Feature ✅ (5/9 — 4 systems blocked on GDDs) · Presentation

## Foundation Layer

| Epic | System | GDD | Governing ADRs | Risk | Stories | Status |
|---|---|---|---|---|---|---|
| [save-load-system](save-load-system/EPIC.md) | Save/Load System | [save-load-system.md](../../design/gdd/save-load-system.md) | ADR-0003, 0004, 0005, 0007, 0014 | **HIGH** | 15 (all Ready) | Ready |
| [tick-system](tick-system/EPIC.md) | Game Time & Tick System | [game-time-and-tick.md](../../design/gdd/game-time-and-tick.md) | ADR-0003, 0005, 0014 | MEDIUM | 11 (all Ready) | Ready |
| [data-registry](data-registry/EPIC.md) | Data Loading System | [data-loading.md](../../design/gdd/data-loading.md) | ADR-0003, 0006, 0011 | MEDIUM | 8 (all Ready) | Ready |
| [scene-manager](scene-manager/EPIC.md) | Scene/Screen Manager | [scene-screen-manager.md](../../design/gdd/scene-screen-manager.md) | ADR-0003, 0007, 0008, 0014 | **HIGH** | 10 (all Ready) | Ready |

**Foundation-layer flagged gap (not an epic)**: UI Framework / Theme (systems-index
Foundation #4) has no standalone GDD. ADR-0008 + art bible cover architecturally;
implementation cross-cuts Presentation-layer screen epics (wired up via
`UIFramework` static helpers + `parchment_theme.tres` preload). Revisit when
authoring Presentation-layer epics; consider a minimal UI Framework GDD if a
bounded epic is desired.

## Core Layer

| Epic | System | GDD | Governing ADRs | Risk | Stories | Status |
|---|---|---|---|---|---|---|
| [economy-system](economy-system/EPIC.md) | Economy | [economy-system.md](../../design/gdd/economy-system.md) | ADR-0002, 0003, 0004, 0005, 0011, 0013, 0014 | MEDIUM | 13 (4 done, 9 Ready) | Ready |
| [hero-class-database](hero-class-database/EPIC.md) | Hero Class Database | [hero-class-database.md](../../design/gdd/hero-class-database.md) | ADR-0003, 0006, 0011 | MEDIUM | 10 (3 done, 7 Ready) | Ready |
| [enemy-database](enemy-database/EPIC.md) | Enemy Database | [enemy-database.md](../../design/gdd/enemy-database.md) | ADR-0003, 0006, 0011 | MEDIUM | 6 (all Ready) | Ready |
| [biome-dungeon-database](biome-dungeon-database/EPIC.md) | Biome / Dungeon / Floor Database | [biome-dungeon-database.md](../../design/gdd/biome-dungeon-database.md) | ADR-0003, 0006, 0011, 0014 | MEDIUM | 7 (all Ready) | Ready |

**Core-layer flagged gap (not an epic yet)**: `audio-system` is named in the
systems index and has a planned ADR-C03 slot, but neither the GDD
(`design/gdd/audio-system.md`) nor ADR-C03 has been authored. **BLOCKED on
GDD authoring.** Once `/design-system audio-system` lands, run
`/architecture-decision audio-system` and then `/create-epics audio-system`.
Audio is not in the MVP critical path (per `design/gdd/game-concept.md`
§Audio Needs: "Moderate — ambient dungeon loops, UI tap feedback, low-key
fanfare for unlocks") and can be deferred to Sprint 4+ without blocking
core-loop work.

**Core-layer dependency note**: The four authored epics share rank-ordering
discipline (Economy 3 → HeroClassDB 4 → EnemyDB 5 → BiomeDungeonDB 6).
Stories must respect this autoload-rank order — EnemyDB stories cannot
reference HeroClassDB symbols that aren't published yet, and so on. The
`/create-stories` skill is expected to embed rank-lockstep guidance per
ADR-0003.

## Feature Layer

| Epic | System | GDD | Governing ADRs | Risk | Stories | Status |
|---|---|---|---|---|---|---|
| [hero-roster](hero-roster/EPIC.md) | Hero Roster | [hero-roster.md](../../design/gdd/hero-roster.md) | ADR-0003, 0004, 0011, 0012 | LOW | Not yet created | Ready |
| [matchup-resolver](matchup-resolver/EPIC.md) | Class-vs-Enemy Matchup Resolver | [class-vs-enemy-matchup-resolver.md](../../design/gdd/class-vs-enemy-matchup-resolver.md) | ADR-0003 Amend #3, 0009 | LOW | Not yet created | Ready |
| [combat-resolution](combat-resolution/EPIC.md) | Combat Resolution | [combat-resolution.md](../../design/gdd/combat-resolution.md) | ADR-0003 Amend #3, 0009, 0010, 0014 | MEDIUM | Not yet created | Ready |
| [dungeon-run-orchestrator](dungeon-run-orchestrator/EPIC.md) | Dungeon Run Orchestrator | [dungeon-run-orchestrator.md](../../design/gdd/dungeon-run-orchestrator.md) | ADR-0001, 0002, 0003 Amend #3, 0007, 0009, 0010, 0014 | MEDIUM | Not yet created | Ready |
| [floor-unlock-system](floor-unlock-system/EPIC.md) | Floor / Biome Unlock System | [floor-unlock-system.md](../../design/gdd/floor-unlock-system.md) | ADR-0002, 0003, 0007, 0011, 0014 | LOW | Not yet created | Ready |

**Feature-layer flagged gaps (no GDD authored yet)**: 4 systems from the
systems index lack GDDs and cannot become epics until designed:

1. **Recruitment System** — depends on Class DB + Roster + Economy. ADR-X04
   slot listed in `tr-registry.yaml`. Run `/design-system recruitment-system`
   first.
2. **Hero Leveling System** — partially covered by Economy (`level_cost`,
   `try_spend`) + Roster (`hero_leveled` signal); needs a thin GDD codifying
   the full level-up transaction surface (gold check → Economy.try_spend →
   Roster.level_hero → emit `hero_leveled`). Run `/design-system hero-leveling`.
3. **Formation Assignment System** — cross-cuts Roster + DungeonRun +
   Matchup Assignment Screen. May be a stub system absorbed into Roster +
   Orchestrator if scope is small. Run `/design-system formation-assignment-system`
   if a standalone GDD is warranted.
4. **Offline Progression Engine** ⚠️ HIGH-risk system — ADR-0014 Accepted
   but full GDD body design deferred. The orchestrator's offline-replay
   path covers the deterministic-batch contract; the Engine GDD owns
   foreground-resume cost-of-time and away-time-bucketing UX. Run
   `/design-system offline-progression-engine` BEFORE V1.0 (post-MVP-launch).

**Feature-layer Vertical Slice critical path**: hero-roster +
matchup-resolver + combat-resolution + dungeon-run-orchestrator +
floor-unlock-system together compose the playable core loop required by
the Pre-Production → Production gate. The 4 flagged-gap systems are
**deferrable** for the Vertical Slice — recruitment can be hardcoded,
leveling can defer, formation-assignment can route through Roster, and
offline progression is post-MVP.

**Feature-layer dependency note**: The MatchupResolver + CombatResolver are
RefCounted services (NOT autoloads) constructed via lazy-default DI inside
DungeonRunOrchestrator's `_ready()`. Per ADR-0003 Amendment #3, autoloads
must have zero-arg `_init`; DI seam is `set_*_resolver(spy)` BEFORE
`_ready()` for tests, lazy-default for production.



Planned epics (from systems-index §Feature Layer):
- hero-roster — `design/gdd/hero-roster.md` (ADR-0012)
- matchup-resolver — `design/gdd/class-vs-enemy-matchup-resolver.md` (ADR-0009)
- combat-resolution — `design/gdd/combat-resolution.md` (ADR-0010)
- offline-progression-engine — planned; covered by ADR-0014
- dungeon-run-orchestrator — `design/gdd/dungeon-run-orchestrator.md` (ADR-0001, 0010, 0014)
- recruitment-system — GDD not yet authored (ADR-X04 blocked)
- hero-leveling-system — GDD not yet authored
- floor-unlock-system — `design/gdd/floor-unlock-system.md` (ADR-0002)
- formation-assignment-system — GDD not yet authored (ADR-0001 covers)

## Presentation Layer

_Not yet processed. Run `/create-epics layer: presentation` when Feature layer nears completion._

Planned epics (from systems-index §Presentation Layer):
- guild-hall-screen, offline-rewards-screen, recruit-screen, roster-screen,
  matchup-assignment-screen, dungeon-run-view, unlock-victory-moment,
  hd-2d-rendering-pipeline, vfx-system

UI Framework / Theme story seeds land here (per Foundation-layer gap note above).

## Polish Layer

_Deferred until Presentation epics are underway._

- onboarding-first-session-flow
- settings-options-and-accessibility (resolves ADR-0007 OQ-7 `reduce_motion` persistence migration, ADR-0008 AccessKit dynamic modal coverage)

## V1.0 Stubs (deferred)

- prestige-system
- floor-unlock-designer-ui (ADR-X05 deferred; runtime fallback works for MVP)

## Progress

- **Foundation**: 4/4 epics defined, 4/4 decomposed into stories (2026-04-24). **44 stories total** (11 tick-system + 8 data-registry + 10 scene-manager + 15 save-load-system). Sprint 1 closed 2026-04-24 — TickSystem + DataRegistry implemented, both autoloads bootable.
- **Core**: 4/5 epics defined (2026-04-25), 4/5 **decomposed** (2026-04-25). **36 stories total** across the 4 epics (13 economy + 10 hero-class-db + 6 enemy-db + 7 biome-dungeon-db). audio-system deferred (GDD blocked). Sprint 2 closed 7 stories; Sprint 3 plans 8 Must Have + 3 Should + 2 Nice = 13 candidate stories from this pool.
- **Feature**: 0 epics defined.
- **Presentation**: 0 epics defined.

## Conventions

- Each epic lives in `production/epics/[epic-slug]/EPIC.md`.
- Stories generated by `/create-stories [epic-slug]` land in the same directory as `story-NNN-[slug].md`.
- Epic slugs match canonical architectural module names where possible (`tick-system`, `data-registry`, `scene-manager`) rather than GDD filenames (which retain original slugs for stable refs per ADR-0003 naming-drift protocol).
