---
name: Project Lantern Guild
description: Cozy fantasy idle-clicker in active design phase — Godot 4.6 + GDScript, PC/Steam primary, mobile post-launch
type: project
---

**Lantern Guild** is a cozy fantasy idle-clicker. Design phase active as of 2026-04-19.

**Why:** Solo dev indie project targeting Steam (PC primary), Steam Deck supported, mobile (iOS/Android) post-launch.

**How to apply:** All QA plans must account for GdUnit4 test framework, 80% minimum coverage requirement for balance formulas and offline-progression math, and the per-kill evaluation model that drives the Pillar 3 economic hook (matchup multiplier). Offline determinism is non-negotiable — any logic story touching the Economy or Matchup Resolver must have unit tests before Done.

Key GDDs authored as of 2026-04-19:
- Economy System (#4), Hero Class Database (#5), Enemy Database (#6), Biome/Dungeon Database, Hero Roster (#9), Class-vs-Enemy Matchup Resolver (#10 — In Design)

Class-vs-Enemy Matchup Resolver specifics:
- Stateless static utility class (MatchupResolver), two public methods
- Per-kill evaluation model (not per-run or per-floor aggregate)
- Empty-formation guard: returns {false, []} immediately, no iteration
- Unknown archetypes (beast/construct/incorporeal in MVP): return false, no crash
- matched_archetypes: deduplicated, alphabetically sorted
- Offline Engine uses snapshot + has() lookup, not re-calling resolver per kill
- E.2 (null class_data), E.3 (empty/null archetype), E.10 (stale snapshot) are documented edge cases requiring test coverage
