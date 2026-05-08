# Epic: Class-vs-Enemy Matchup Resolver

> **Layer**: Feature
> **GDD**: `design/gdd/class-vs-enemy-matchup-resolver.md`
> **Architecture Module**: `MatchupResolver` (`extends RefCounted`, NOT an autoload — DI service)
> **Control Manifest Version**: 2026-04-24
> **Status**: Complete (all stories shipped — see systems-index Implementation Status; per-story Status fields flipped 2026-05-08)
> **Stories**: 8 — authored 2026-04-26 via S6-M10 pre-flight

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

| # | Story | Type | Status | TR Coverage | ADR |
|---|-------|------|--------|-------------|-----|
| 001 | MatchupResolver base + MatchupResult value type | Logic | Ready | TR-001/002/005/006/007/030 | ADR-0009 |
| 002 | DefaultMatchupResolver + `_is_class_counter` + `resolve_formation_matchup` | Logic | Ready | TR-003/008/010/011/012/013/014/016/017/020 | ADR-0009 |
| 003 | `resolve_floor_matchup` + edge-case error guards | Logic | Ready | TR-009/015/018/019 | ADR-0009 |
| 004 | `effectiveness_label` hook (S4-N1 quick-spec carryover) | Logic | Ready | epic DoD | ADR-0009 |
| 005 | Determinism + offline-replay invariants | Integration | Ready | TR-021/022/023/024/025/029 | ADR-0009 + ADR-0014 |
| 006 | Orchestrator DI integration + spy-subclass test pattern | Integration | Ready | TR-004/026/032 | ADR-0009 + ADR-0003-A3 |
| 007 | Economy + Combat consumer wiring | Integration | Ready | TR-027/028 | ADR-0009 + ADR-0010 + ADR-0013 |
| 008 | Perf bench + structural CI lint + equality test pattern | Logic | Ready | TR-030/031/033 | ADR-0009 |

**Authored**: 2026-04-26 via Sprint 6 Story M10 (`/create-stories matchup-resolver`).
**Solo review mode**: QA-lead story-readiness gate skipped per `production/review-mode.txt = solo`. Stories carry minimal QA test case sketches; full qa-lead pass deferred to story implementation time.

## Next Step

Stories are backlog-ready for Sprint 7+. Critical path for Vertical Slice — this
is Pillar 3's load-bearing mechanism. Begin implementation with Story 001
(`/story-readiness production/epics/matchup-resolver/story-001-matchup-resolver-base-and-result-type.md`)
when sprint capacity allows.
