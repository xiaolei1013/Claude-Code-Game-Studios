---
name: Lantern Guild Project Context
description: Core facts about the Lantern Guild game project — concept, engine, design order, GDD status, and high-risk flags
type: project
---

Lantern Guild is a cozy fantasy idle-clicker. Session-based: 2-5 min sessions 2-4x/day. Player manages a hero guild, assigns class formations to dungeons, returns to accumulated loot. Steam primary, mobile post-launch.

**Engine**: Godot 4.6 + GDScript. LLM knowledge gap HIGH — verify 4.5/4.6 APIs against `docs/engine-reference/godot/` before suggesting any API call.

**Four pillars**: (1) Respect Player's Time, (2) Every Class Feels Distinct, (3) Matchup Is a Decision Not a Reflex, (4) HD-2D Pixel Pride.

**Design order** (first 4): Game Time & Tick → Data Loading → Save/Load (in progress) → Economy.

**GDD status as of 2026-04-19**: #1 Game Time complete, #2 Data Loading complete, #3 Save/Load Sections C/D/E/G written (A/B/F/H pending + security-engineer anti-tamper integration).

**Registry constants** (do not redefine): TICKS_PER_SECOND=20, offline_cap_seconds=28800, REWIND_TOLERANCE_SECONDS=60.

**Why**: Idle games are system-heavy. Foundation GDDs (Time, Data Loading, Save/Load) are load-bearing — errors propagate to Economy, Offline Engine, and all feature systems.

**How to apply**: Always read `design/registry/entities.yaml` before authoring any new GDD to catch cross-system constant conflicts. Check `design/gdd/game-time-and-tick.md` for any formula or constant that touches timestamps or ticks.
