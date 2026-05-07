# Prestige System (V1.0 stub) — GDD #31

> **Status: STUB DRAFT 2026-05-07** by post-Sprint-15-plan autonomous-execution session. **This is a V1.0 tier stub**, NOT a full first-pass GDD. Per Sprint 14 retro recommendation #4, this stub captures the system's identity + dependencies + open questions for the post-MVP authoring cycle. A full first-pass GDD is authored in the V1.0 design block when the post-Vertical-Slice work begins.

---

## A. Overview

**Prestige System** is the meta-progression layer that lets players reset capped progression in exchange for permanent multipliers / cosmetic unlocks / new content access. Per `game-concept.md` §Roadmap V1.0 tier ("+ prestige") + Hero Leveling GDD #15 §C.5 LEVEL_CAP overflow ("V1.0 prestige system #31 will be the lever to reset capped heroes for further progression").

The cozy register applies: prestige is voluntary, not pressure-driven. Player chooses when to prestige (no countdown timer, no FOMO event); the prestige action is a deliberate "reset and accelerate" decision made when the player feels their MVP run has plateaued. Per `game-concept.md` cozy fantasy: prestige is the long-game horizon that respects player agency.

Status: **deferred to V1.0 tier per `game-concept.md` §Roadmap**. MVP ships without prestige; the LEVEL_CAP=15 ceiling per Hero Leveling §C.5 IS the MVP terminal state. Prestige is the V1.0 "what next" answer.

---

## F. Dependencies (preliminary — full §F authoring deferred to V1.0 tier)

| System | Why | Surface used (preliminary) |
|---|---|---|
| **HeroRoster** (#9) | Reset surface | V1.0 add a `reset_for_prestige(class_id)` method that returns hero to level 1 + sets a per-hero `prestige_level: int` field. Persisted alongside existing 5-field schema. |
| **Hero Leveling** (#15) | LEVEL_CAP semantic | V1.0 prestige is the lever to reset LEVEL_CAP; the cap lifts post-prestige OR remains at 15 with a permanent multiplier. Resolution path is V1.0 design call. |
| **Economy** (#5) | Prestige cost / reward | Prestige consumes some economic resource (e.g., capped hero retired) and grants a multiplier on future runs. Specific cost-curve = V1.0 design call. |
| **DungeonRunOrchestrator** (#13) | Multiplier application | Per-run gold + XP multipliers applied at attribution time. Multiplier source = HeroRoster.get_total_prestige_multiplier() or similar. |
| **Save/Load System** (#3) | Persistence | New prestige_level fields added to per-hero schema + per-save schema (Roster + a global prestige multiplier). Schema migration via Save/Load GDD's versioning. |
| **Class Synergy System** (#32) | V1.0 sibling | Class Synergy is the other V1.0 progression layer; the two interact (prestiging unlocks synergies; synergies tune-multiply prestige output). |

### Reverse dependencies (preliminary)

- **Roster / Hero Detail Modal** (#22) — V1.0 adds a "Prestige" button to the hero detail modal when the hero is at LEVEL_CAP; current MVP modal hides the LevelUpButton at cap (Hero Detail GDD §C.5 step 1)
- **Onboarding** (#29) — V1.0 may add a one-time "you can prestige now" hint when the player's first hero hits LEVEL_CAP

---

## I. Open Questions for V1.0 Authoring Cycle

**OQ-31-1 — Prestige cost mechanism**
Options: (a) consume a single capped hero (cozy "this hero retires to teach the next generation"); (b) consume gold (prestige_cost as a curve); (c) hybrid (capped hero + gold). Cozy register suggests (a) — narrative-coherent + emotionally weighted. Resolution path: V1.0 design call.

**OQ-31-2 — Prestige reward type**
Options: (a) flat global multiplier (×1.05 per prestige; multiplicative stack); (b) class-specific multiplier (prestiging Theron grants Warrior class +10% gold/XP); (c) cosmetic unlock (prestiged hero ports get a parchment-warm crown overlay); (d) content unlock (prestiging unlocks Tier-2 hero classes). MVP sets BASE_RECRUIT[tier_2] = 8000 per Economy §G — Tier-2 access is gated by gold; prestige is an alternative unlock path. Resolution: V1.0 design — likely hybrid (a) + (c).

**OQ-31-3 — Prestige curve**
Each prestige costs more than the last (e.g., 1st prestige requires Tier-1 capped hero; 5th prestige requires Tier-2 capped hero). Curve formula = V1.0 economy-designer call.

**OQ-31-4 — LEVEL_CAP behavior post-prestige**
Options: (a) cap lifts (level 16+ accessible) — feels like infinite progression; (b) cap stays at 15 but permanent stat-multiplier compounds — feels like meta-progression; (c) cap stays + new "prestige tier" labeling overlays the level (e.g., "Prestige 1 · Level 7"). Resolution: V1.0 design — (b) preserves the predictable cap math while delivering post-cap progression.

**OQ-31-5 — Cozy register vs prestige urgency**
Prestige systems often produce FOMO (idle game tropes: "prestige now or lose this run's bonus"). The cozy register MUST resist this. Resolution: prestige is always voluntary; no time-limited prestige bonuses; no "prestige x in next 24h" prompts. Locked design floor for V1.0 authoring.

**OQ-31-6 — Save schema migration**
Adding a `prestige_level: int` field per HeroInstance + a global prestige multiplier on the Roster save namespace = save schema migration event. Per Save/Load GDD §C versioning, requires a migration path. V1.0 sprint authors the migration alongside the prestige feature.

**OQ-31-7 — Tutorial / onboarding for first-time prestige**
First-time prestige is conceptually heavy (reset progress for a multiplier). Onboarding GDD #29 doesn't currently cover it. V1.0 authoring expands #29 with a "prestige introduction" subsection OR creates a dedicated `prestige-onboarding.md` sub-GDD.

**OQ-31-8 — Successor scope: full first-pass GDD timing**
Authored when V1.0 design block begins (post-Vertical-Slice). Pairs with #32 Class Synergy authoring as the V1.0 sibling progression layer.

---

## Notes

- STUB GDD per Sprint 14 retro recommendation #4. Sections A, F, and I are the load-bearing content; B/C/D/E/G/H/J are deferred to V1.0 tier full-pass authoring.
- Closes systems-index.md row 31 status from "Not Started" → "STUB DRAFT 2026-05-07".
- Pairs with: Hero Leveling GDD #15 §C.5 (LEVEL_CAP overflow + prestige reference); Class Synergy GDD #32 (V1.0 sibling); Roster / Hero Detail Modal #22 (UI surface for the prestige button at LEVEL_CAP); Save/Load GDD #3 (schema migration path); Onboarding #29 (V1.0 tutorial expansion).
- The full first-pass GDD is authored when the V1.0 design block begins (post-Vertical-Slice tier per `game-concept.md` §Roadmap). Until then, this stub serves as the design-coverage placeholder + dependency declaration.
