# Epic: Class-vs-Enemy Matchup Resolver

> **Layer**: Feature
> **GDD**: `design/gdd/class-vs-enemy-matchup-resolver.md`
> **Architecture Module**: `MatchupResolver` (`extends RefCounted`, NOT an autoload — DI service)
> **Control Manifest Version**: 2026-04-24
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories matchup-resolver`

## Overview

The Matchup Resolver is the smallest system in *Lantern Guild* by lines of
code and the largest by emotional weight: a stateless resolver whose single
job is to decide whether a formation has matchup advantage against an enemy
or floor. The resolver returns a `bool` (`is_matchup_advantaged`) plus
per-archetype counter detail the UI needs to explain *why*. That `bool`
flips a `1.0` to a `1.5` in Economy's `kill_bonus` formula — the entire
Pillar 3 ("Matchup Is a Decision, Not a Reflex") economic hook.

Per ADR-0009, aggregation is **majority threshold** — a formation is
advantaged against an enemy archetype iff strictly more than `formation.size() / 2`
heroes counter that archetype (integer division). For MVP `FORMATION_SIZE = 3`
this means at least 2 of 3 slots must counter. Crossing the threshold yields
a single `1.5×` (no per-hero stacking beyond threshold) — forcing the
specialist-vs-generalist decision the pillar promises.

Per ADR-0003 Amendment #3, the resolver is constructed via the
**lazy-default-with-public-setters** DI pattern (NOT autoload, NOT
`_init(args)`). Production wiring uses `set_matchup_resolver(spy)` BEFORE
`_ready()` for tests; lazy-default `DefaultMatchupResolver.new()` inside
DungeonRunOrchestrator's `_ready()` for production.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0009: Matchup Resolver DI + Majority Threshold | `class_name MatchupResolver extends RefCounted`; `DefaultMatchupResolver` concrete impl; majority-threshold (not boolean OR); spy-subclass test pattern | LOW |
| ADR-0003 Amendment #3: Autoload `_init` Zero-Arg | Resolver is NOT an autoload; constructed via lazy-default + `set_matchup_resolver(spy)` test seam | LOW (empirically verified Pass-INIT-PROBE 2026-04-22 on Godot 4.6.1) |

## GDD Requirements Coverage

| Metric | Count |
|---|---|
| Total TRs (`TR-matchup-resolver-*`) | per `tr-registry.yaml` |
| Coverage | high (single ADR codifies entire surface) |
| Open gap | None — system is deliberately small |

## Engine Compatibility Notes (Godot 4.6)

- `extends RefCounted` lifetime is automatic — never call `.free()` on resolver instances
- DI seam works because `set_*_resolver(spy)` runs BEFORE `_ready()` per
  Orchestrator GDD §J.1 Option A (locked pattern)
- No post-cutoff API risk

## Definition of Done

- All stories implemented, reviewed, closed via `/story-done`
- All acceptance criteria from `design/gdd/class-vs-enemy-matchup-resolver.md` verified
- `tests/unit/matchup_resolver/` covers `is_class_counter` (already shipped in S4-N3) and `resolve_formation_matchup` for all formation × floor combinations in the MVP content table
- Threshold edge cases verified: 2/3 counters → advantaged; 1/3 → not advantaged; 3/3 → advantaged (no extra stacking)
- Spy-subclass DI test pattern works in both production-wiring and test-injection paths
- **S4-N1 quick-spec** integrated: resolver returns `effectiveness_label: String` ∈ {"Weak", "Even", "Strong"} alongside the multiplier (per design/quick-specs/matchup-visualization-revision.md)

## Stories

Not yet created. Run `/create-stories matchup-resolver` to author.

## Next Step

`/create-stories matchup-resolver`. Critical path for Vertical Slice — this
is Pillar 3's load-bearing mechanism.
