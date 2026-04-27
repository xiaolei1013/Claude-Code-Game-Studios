# Epic: Hero Roster

> **Layer**: Feature
> **GDD**: `design/gdd/hero-roster.md`
> **Architecture Module**: `HeroRoster` (autoload — rank position governed by ADR-0003 Amendment table)
> **Control Manifest Version**: 2026-04-24
> **Status**: Ready
> **Stories**: 10 defined (Ready)

## Overview

The Hero Roster is the player-state container for every hero the player owns.
Where the Hero Class Database (Core layer) defines class *templates*, the
Roster owns *instances* — each `HeroInstance` carries an immutable
`instance_id`, a `class_id` reference resolved through DataRegistry, a
`current_level`, and a generated personal `display_name`. The roster is a
typed dictionary persisted via the Save/Load `get_save_data` /
`load_save_data` consumer contract. Mutations funnel through three signals
(`hero_recruited`, `hero_leveled`, `hero_removed`) so HUD, recruit screen,
and economy can react without polling. An `xp` field is reserved on the
schema for V1.0 progression but is `0` and never displayed in MVP — heroes
level by spending gold per the Economy system. Implements Pillar 2 (Every
Class Feels Distinct — owns the player's hand-curated roster).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0012: Hero Roster Mutation + Identity | `instance_id` is the immutable cross-session reference; mutations are signal-driven not poll-driven; no Roster method may modify Class DB or Enemy DB state | LOW |
| ADR-0003: Autoload Rank Table Canonical | HeroRoster is an autoload past rank 2 (after SaveLoadSystem); zero-arg `_init` per Amendment #3 | LOW |
| ADR-0004: Save Envelope + HMAC Scheme | HeroRoster is item #2 in `CONSUMER_PATHS` (after Economy); `get_save_data` / `load_save_data` element-layer canonical naming (Pass 5F-propagation 2026-04-21) | LOW |
| ADR-0011: Resource Schemas Core Databases | `HeroInstance` references `class_id` (string) resolved at runtime — no direct `HeroClass` references stored | LOW |

## GDD Requirements Coverage

| Metric | Count |
|---|---|
| Total TRs (`TR-hero-roster-*`) | per `tr-registry.yaml` |
| Coverage | high (governed by ADR-0012 + DI-pattern across ADR-0009 / ADR-0003 Amendment #3) |
| Open gap | None at epic scope; story-level UX details may surface |

Full per-TR detail: `docs/architecture/requirements-traceability.md` §Feature Layer
+ `docs/architecture/tr-registry.yaml` (filter `TR-hero-roster-*`).

## Engine Compatibility Notes (Godot 4.6)

- `Dictionary` typed-key invariants per `docs/engine-reference/godot/`
- Signal connection at `_ready()` is safe across rank pairs (Claim 1 VERIFIED)
- No post-cutoff API risk — Roster is plain GDScript + signals + Dictionary

## Definition of Done

- All stories implemented, reviewed, closed via `/story-done`
- All acceptance criteria from `design/gdd/hero-roster.md` verified
- `tests/unit/hero_roster/` covers mutation paths, signal emissions, and `get_save_data` / `load_save_data` round-trip
- `tests/integration/hero_roster/` exercises Roster ↔ SaveLoadSystem ↔ Economy ↔ DataRegistry coherence
- No identifier in `HeroRoster` references `HeroClass` directly — all class lookups go through `DataRegistry.resolve("classes", class_id)`

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | HeroInstance RefCounted class + 5-field schema + to_dict / from_dict | Logic | Ready | ADR-0011 + 0012 |
| 002 | HeroRoster autoload skeleton + state fields + encapsulation | Logic | Ready | ADR-0012 + 0003 |
| 003 | roster_config.tres tuning knobs | Config/Data | Ready | ADR-0012 |
| 004 | add_hero + signals (hero_recruited / hero_leveled / hero_removed) | Logic | Ready | ADR-0012 |
| 005 | set_hero_level + set_formation_slot mutations | Logic | Ready | ADR-0012 |
| 006 | get_save_data / load_save_data round-trip + signal suppression | Integration | Ready | ADR-0004 + 0012 |
| 007 | Boot validation order + orphan handling + last-write-wins | Integration | Ready | ADR-0012 |
| 008 | First-launch Theron seed | Logic | Ready | ADR-0012 |
| 009 | Name pool generation + DataRegistry name_pools category | Integration | Ready | ADR-0012 + 0011 |
| 010 | Formation strength + accessors + AC H-14 perf | Logic (Performance) | Ready | ADR-0012 |

**Type breakdown**: 6 Logic + 3 Integration + 1 Config/Data.
**TR coverage**: TR-hero-roster-001..030 (full epic scope).
**Dependency order**: Story 001 → 002 → 003 → 004 → 005 → 006 → 007; Story 008/009/010 depend on 002+004 and may parallel-develop.

## Next Step

`/story-readiness production/epics/hero-roster/story-001-hero-instance-resource.md` to validate the first story, then `/dev-story` to begin implementation when Sprint 6 starts.
