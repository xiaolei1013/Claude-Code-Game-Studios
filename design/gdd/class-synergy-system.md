# Class Synergy System (V1.0+ stub) — GDD #32

> **Status: STUB DRAFT 2026-05-07** by post-Sprint-15-plan autonomous-execution session. **This is a V1.0+ tier stub**, NOT a full first-pass GDD. Per Sprint 14 retro recommendation #4, this stub captures the system's identity + dependencies + open questions for the post-MVP authoring cycle. A full first-pass GDD is authored in the V1.0+ design block when the post-V1.0 work begins.

---

## A. Overview

**Class Synergy System** is the V1.0+ formation-bonus layer that adds bonus effects when specific class combinations dispatch together. Per `game-concept.md` §Roadmap "Full Vision" tier (also referenced as V1.0+) — Class Synergy is the meta-formation puzzle layer that emerges only AFTER the player has multiple classes recruited and starts experimenting with formation composition.

Examples (illustrative; final design = V1.0+ call):
- "Steel Wall" (3 Warriors): +25% formation HP
- "Triple Threat" (1 Warrior + 1 Mage + 1 Rogue): +15% kill XP across the run
- "Arcane Elite" (3 Mages): +50% Tier-3+ enemy gold

The cozy register applies: synergies are discoverable, not mandatory. Player who runs solo-class formations is not punished — they earn baseline rewards. Synergies are the "if you experiment with composition, you'll find these" layer per Pillar 1 (Tactical Foresight). Per `game-concept.md` Pillar 1: "Each formation choice teaches the player something about class interactions."

Status: **deferred to V1.0+ Full Vision tier per `game-concept.md` §Roadmap**. MVP ships with no class synergies — formation strength = sum of hero levels per `hero-roster.md` §C.10. Synergies are V1.0+ scope when the recruit pool covers the full class roster (Tier-2 unlocks via Prestige #31 or via gold gating).

---

## F. Dependencies (preliminary — full §F authoring deferred to V1.0+ tier)

| System | Why | Surface used (preliminary) |
|---|---|---|
| **Formation Assignment** (#17) | Synergy detection point | V1.0+ adds `FormationAssignment.detect_synergies(formation) -> Array[Synergy]` that runs at dispatch validation (or live during slot edit for player-facing preview) |
| **DungeonRunOrchestrator** (#13) | Synergy effect application | Per-run synergy multipliers applied alongside matchup multipliers in `attribute_kill_gold` (Sprint 8 S8-S3); requires extending the formula |
| **Hero Leveling** (#15) | Synergy XP modifiers | Synergies that boost XP (e.g., "Triple Threat" example) modify XP_PER_KILL or XP_PER_FLOOR_CLEAR per-run |
| **Economy** (#5) | Synergy gold modifiers | Synergies that boost gold modify BASE_KILL or BASE_RECRUIT gating per the synergy definition |
| **Recruit Screen** (#21) | Synergy preview | Player browsing the recruit pool sees "if you recruit this Mage, you'll have your 3rd Mage — Arcane Elite synergy unlocks" preview |
| **Matchup Assignment Screen** (#23) | Synergy + biome interaction | A synergy and a biome's dominant_archetype may compound (e.g., "Steel Wall" + Bruiser-favored biome = +25% HP × Warrior Bruiser counter); the screen displays the combined hint |
| **Roster / Hero Detail Modal** (#22) | Synergy availability indicator | Hero detail surfaces "this hero is part of N possible synergies" + lists them |
| **Prestige System** (#31) | V1.0 sibling | Prestiging may unlock new synergies (e.g., "your first prestige unlocks Steel Wall"); the two layers compound |

### Reverse dependencies (preliminary)

- **Combat Resolution** (#11) — synergies modify per-kill / per-floor combat output; the resolver reads from a synergy-aware multiplier set
- **Audio System** (#28) — synergy-active dispatch may trigger a special "synergy chime" cue at run start (V1.0+ audio-system.md expansion)

---

## I. Open Questions for V1.0+ Authoring Cycle

**OQ-32-1 — Synergy taxonomy**
Initial taxonomy candidates:
- **Composition synergies** (3-of-a-kind, 1+1+1 mix): the canonical examples (Steel Wall, Triple Threat, Arcane Elite)
- **Tier synergies** (3 same-tier heroes): "Veteran Squad" (3 Tier-1) / "Elite Vanguard" (3 Tier-2)
- **Level synergies** (3 same-level heroes): "Synchronized Strike" — niche; possibly cute
- **Identity synergies** (specific named heroes): "Old Friends" — Theron + Mira always synergize. V1.0+ may add hero-specific lore beats here.

Resolution: V1.0+ design call. Start with composition synergies (the most legible).

**OQ-32-2 — Synergy effect type**
Options:
- (a) Multiplicative (×1.25 HP, ×1.15 XP, ×1.5 gold) — clean math, predictable
- (b) Additive flat (+5 HP per hero, +10 XP per kill) — scales worse at high levels
- (c) Hybrid (some synergies multiplicative, some additive) — flexibility, more complex

Resolution: V1.0+ design call. Multiplicative is simplest + scales correctly; recommend default.

**OQ-32-3 — Synergy detection timing**
Options:
- (a) At dispatch validation (one-shot) — simplest
- (b) Live during slot edit (formation_assignment screen previews active synergies as the player edits) — better UX
- (c) Both (live preview + dispatch-time confirmation) — best UX, more code

Resolution: V1.0+ design call. (b) live preview is cozy-register-correct (player sees the synergy as they assemble the formation); recommend (b) or (c).

**OQ-32-4 — Synergy unlock cadence**
Options:
- (a) All synergies always available — discoverable via experimentation (cozy register)
- (b) Synergies unlock on first-clear of certain biomes — frontier fantasy hook (game-concept.md Pillar 1)
- (c) Synergies unlock via Prestige (#31) — meta-progression hook

Resolution: V1.0+ design call. Cozy register favors (a); the discovery moment ("oh — 3 Warriors synergize!") IS the reward. Recommend (a).

**OQ-32-5 — Synergy display rules**
The matchup_assignment_screen + recruit_screen + roster_screen all need synergy hints. Where does each surface what?
- Matchup screen: "this floor + your synergy → outcomes"
- Recruit screen: "recruiting this hero unlocks N synergies"
- Roster modal: "this hero appears in N synergy combinations"

Resolution: V1.0+ design call; defer until first synergy ships.

**OQ-32-6 — Anti-frustration: avoid synergy-or-lose framing**
Idle game synergy systems often produce "you MUST run the synergy to be efficient" pressure. Per cozy register Pillar 2 (Cozy Pacing — no pressure), synergies must be NICE-TO-HAVE not MANDATORY. Mitigation: synergy multipliers cap at +50% (no synergy that DOUBLES output); player who skips synergies still earns 67%+ of synergy-active income. Hard design floor for V1.0+ authoring.

**OQ-32-7 — Successor scope: full first-pass GDD timing**
Authored when V1.0+ design block begins (post-V1.0 prestige + post-Vertical-Slice). Pairs with #31 Prestige authoring as the V1.0+ progression layer family.

**OQ-32-8 — Cross-GDD integration with Combat Resolution**
Combat Resolution (#11) currently reads matchup multipliers; synergy multipliers are a sibling layer. V1.0+ authoring may produce a unified "RunModifier" abstraction that combines matchup + synergy + future buffs/debuffs. ADR-candidate when the third multiplier source emerges.

---

## Notes

- STUB GDD per Sprint 14 retro recommendation #4. Sections A, F, and I are the load-bearing content; B/C/D/E/G/H/J are deferred to V1.0+ tier full-pass authoring.
- Closes systems-index.md row 32 status from "Not Started" → "STUB DRAFT 2026-05-07".
- Pairs with: #31 Prestige System (V1.0 sibling progression layer); Formation Assignment GDD #17 (synergy detection point); Combat Resolution GDD #11 (per-kill multiplier extension); Recruit Screen GDD #21 (synergy preview surface); Roster / Hero Detail Modal #22 (per-hero synergy availability); Matchup Assignment Screen GDD #23 (synergy + biome compounding).
- The full first-pass GDD is authored when V1.0+ design block begins. Until then, this stub serves as the design-coverage placeholder + dependency declaration. The locked design floor (cozy register: synergies are nice-to-have, not mandatory; ≤+50% multiplier cap per OQ-32-6) is the load-bearing constraint for the eventual full authoring.
