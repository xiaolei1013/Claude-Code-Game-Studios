# Epic: Hero Roster

> **Layer**: Feature
> **GDD**: `design/gdd/hero-roster.md`
> **Architecture Module**: `HeroRoster` (autoload — rank position governed by ADR-0003 Amendment table)
> **Control Manifest Version**: 2026-04-24
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories hero-roster`

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

Not yet created. Run `/create-stories hero-roster` to break this epic into
implementable stories embedding ADR-0012, ADR-0004, and Pass-5F-propagation
canonical naming.

## Next Step

`/create-stories hero-roster` — produces story files at
`production/epics/hero-roster/story-*.md`.
