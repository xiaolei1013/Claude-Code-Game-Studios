## CombatResolver — base class for the deterministic combat math kernel.
##
## Stateless instance class (NOT autoload, NOT static-only). Concrete impls
## (Story 003 [DefaultCombatResolver], test spies) override the public
## `emit_events_in_range` and `compute_offline_batch` entry points. The base
## class deliberately defines no method bodies — Godot 4 lacks `@abstract`
## on RefCounted, so the base is "interface by convention" enforced via code
## review + a structural CI lint (Story 008 of the matchup-resolver epic
## established the lint pattern; combat-resolution Story 010 mirrors it).
##
## Stateless invariant (TR-combat-001 + TR-027):
##   - Zero class-scope `var` declarations.
##   - Zero `signal` declarations (Orchestrator owns all signal emission).
##   - No caches, no RNG, no time-dependent reads, no float accumulation
##     across calls.
##   - Pure function of inputs: identical (formation, floor, tick range)
##     produces identical KillEvent stream every call (Pillar 1 offline
##     replay determinism).
##
## Two pure entry points (Story 006 + Story 007 implement bodies):
##   - `emit_events_in_range(snapshot, tick_lo, tick_hi) -> CombatTickEvents`
##     — foreground per-tick emission; per-event detail.
##   - `compute_offline_batch(snapshot, tick_budget) -> CombatBatchResult`
##     — offline-replay batch; aggregate counts only (no per-event Array
##     for 15k+ kill scenarios).
##
## Dependencies (Story 008 wires DI):
##   - MatchupResolver (constructor-injected) — invoked once per distinct
##     enemy archetype on the floor at DISPATCHING.
##
## ADR-0010: Combat Resolver Snapshot + Foreground/Offline Parity
## ADR-0009: Matchup Resolver DI (Combat consumes via constructor injection)
## ADR-0014: RunSnapshot Schema (CombatRunSnapshot is the persist payload)
class_name CombatResolver extends RefCounted

# DELIBERATELY EMPTY — no class-scope vars, no signals.
# Concrete subclasses (DefaultCombatResolver in Story 003, test spies) provide:
#   func emit_events_in_range(snapshot: CombatRunSnapshot, tick_lo: int, tick_hi: int) -> CombatTickEvents
#   func compute_offline_batch(snapshot: CombatRunSnapshot, tick_budget: int) -> CombatBatchResult
#
# Structural CI lint (Story 010) verifies this file remains free of `var ` /
# `signal ` declarations. The base instance class is constructible but has
# no useful behavior — production wiring uses DefaultCombatResolver via
# DungeonRunOrchestrator's lazy-default DI seam.
