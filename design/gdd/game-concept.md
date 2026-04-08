# Game Concept: Trizzle / Shadow Quest

*Created: 2026-04-07*
*Status: Approved*

---

## Elevator Pitch

> It's an action roguelite where you draft and combine skills mid-run to build
> devastating combos, fighting through 10 themed rooms in a dark fantasy world
> with two distinct character classes — a planted, destructive Mage and a fast,
> evasive Archer.

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | Action Roguelite / Real-time Action RPG |
| **Platform** | PC (Windows/Mac/Linux via Steam) primary, Mobile (Android/iOS) secondary |
| **Target Audience** | Mid-core to hardcore players who love build-crafting in action roguelites |
| **Player Count** | Single-player |
| **Session Length** | 15-30 minutes per run |
| **Monetization** | Premium (PC/Steam), F2P with IAP (Mobile) |
| **Estimated Scope** | Large (12-18 months, solo developer) |
| **Comparable Titles** | Hades, Dead Cells, Vampire Survivors, Slay the Spire |

---

## Core Fantasy

You are a master of arcane combinations. Every run is a fresh opportunity to
discover game-breaking skill synergies and demolish rooms with a custom-built
arsenal. The thrill isn't just killing enemies — it's the moment you realize
your draft picks created something absurdly powerful. Two classes offer two
fundamentally different ways to express that mastery: the Mage plants and
detonates, the Archer flows and kites.

---

## Unique Hook

Like Hades' tight room-based combat, AND ALSO you draft and combine 125+ skills
into synergistic builds that transform your playstyle mid-run — with two classes
that use the same skill pool in fundamentally different ways. The draft system
means no two runs play the same, and class choice changes not just your abilities
but your entire combat rhythm.

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics (What the player FEELS)

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Challenge** (mastery) | 1 | Tight combat with telegraphed attacks, Hard mode, Endless Mode scaling |
| **Expression** (build variety) | 2 | 125+ skills, draft combos, two classes with different playstyles |
| **Discovery** (finding synergies) | 3 | Skill combo system, new interactions to uncover each run |
| **Sensation** (combat juice) | 4 | Damage numbers, VFX, screen shake, rarity glow, warm gold progression feedback |
| **Fantasy** (dark fantasy) | 5 | Medieval fantasy setting, arcane powers, monstrous enemies |
| **Narrative** | N/A | Setting dressing only — not a core driver |
| **Fellowship** | N/A | Single-player game |
| **Submission** | N/A | Game is intentionally challenging, not relaxing |

### Key Dynamics (Emergent player behaviors)

- Players experiment with skill draft combinations to find synergies and "broken" builds
- Players develop class-specific strategies (Mage: AoE burst, Archer: kite and crit)
- Players replay rooms on Hard to test build viability under pressure
- Players push Endless Mode to see how far their build scales before breaking

### Core Mechanics (Systems we build)

1. Real-time combat with projectiles, melee, traps, and 27 status effects
2. Roguelite skill draft system — choose skills between rooms, build toward combos
3. Dual-class system — Mage and Archer with shared and exclusive skill pools
4. Multi-phase boss encounters with telegraphed patterns and phase-shift mechanics
5. Difficulty system — Normal/Hard with 5 simultaneous scaling axes

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** | Draft choices, class selection, build expression — every run is player-directed | Core |
| **Competence** | Telegraphed attacks reward skill, Hard mode proves mastery, Endless tracks progress | Core |
| **Relatedness** | N/A — single-player, no social systems | Minimal |

### Player Type Appeal (Bartle Taxonomy)

- [x] **Achievers** — Clear all rooms on Hard, reach high Endless waves, unlock Archer, complete achievements
- [x] **Explorers** — Discover skill combos, find optimal builds, understand system interactions
- [ ] **Socializers** — Not served (single-player)
- [ ] **Killers/Competitors** — Partially served via Endless Mode leaderboard potential

### Flow State Design

- **Onboarding curve**: Demo teaches Mage basics across early rooms. Each room introduces one new enemy type or trap. Skills are introduced gradually through drafts.
- **Difficulty scaling**: Normal teaches patterns, Hard tests mastery. 5-axis scaling (stats, count, healing, pacing, rewards) creates genuine pressure without unfairness.
- **Feedback clarity**: Damage numbers, health bars with numeric overlay, cooldown sweeps, status effect icons, rarity-colored skill cards, warm gold "you earned this" accent.
- **Recovery from failure**: Runs are 15-30 minutes. Death returns to room select. No permanent loss — knowledge carries forward. Hard mode is gated behind Normal clear (learn before proving).

---

## Core Loop

### Moment-to-Moment (30 seconds)

Move, dodge, aim skills at enemies, chain attacks, collect drops. Combat is
real-time with auto-aim assist on primary skills. The Mage plants and casts
(higher per-hit, slower); the Archer kites and fires (lower per-hit, faster).
Status effects (Burn, Freeze, Poison, etc.) create visual and tactical variety
every few seconds.

### Short-Term (5-15 minutes)

Clear a room's enemy waves → defeat the boss → draft new skills from 3 options
→ enter next room with a stronger build. Each room is a self-contained combat
challenge. The draft between rooms is where "one more run" psychology lives —
"if I pick Piercing Arrow here, it combos with Poison Arrow for AoE DoT..."

### Session-Level (30-120 minutes)

One full run: 10 rooms with escalating difficulty, boss encounters every room,
skill build growing throughout. Natural stopping point at run completion.
A session might include 1-3 runs depending on success. Hard mode and Endless
provide replay within the same session.

### Long-Term Progression

- Unlock Archer after clearing rooms as Mage
- Clear all 10 rooms on Normal, then Hard
- Master both classes with different build strategies
- Push Endless Mode for high wave counts
- Complete achievements (P2)
- Discover all skill combos and synergies

### Retention Hooks

- **Curiosity**: "What happens if I combine Multishot + Poison Arrow + Quickdraw?"
- **Investment**: Room-by-room unlock progress, Hard mode unlocks, build knowledge
- **Mastery**: Hard mode clears, Endless high scores, no-hit runs, speedruns
- **Social**: N/A (potential for community build-sharing post-launch)

---

## Game Pillars

### Pillar 1: Build-Craft Fantasy

The thrill of discovering and exploiting skill combos is the core reason to play.
Every design choice should create more opportunities for build expression.

*Design test*: "Should we add a new enemy type or a new skill?" → New skill
(more combo potential).

### Pillar 2: Readable Danger

Every threat is telegraphed, every death is the player's mistake. Fairness over
difficulty.

*Design test*: "Should this boss attack be faster or more visually distinct?" →
More visually distinct.

### Pillar 3: Two-Minute Mastery Cycle

Each room is a self-contained challenge that teaches something. Individual rooms
clear in 2-4 minutes; a full 10-room Normal run takes 15-30 minutes (lunch break).
A full 10-room Hard run is a marathon session (50-60 minutes) — this is intentional
for the proving-grounds audience, not the typical session.

*Design test*: "Should this room have 5 waves or 8?" → 5 (tighter, more
replayable).

### Pillar 4: Class Identity

Mage and Archer must feel fundamentally different, not just reskinned. Each class
changes HOW you play, not just what buttons you press.

*Design test*: "Should this skill work for both classes?" → Only if it plays
differently for each.

### Anti-Pillars (What This Game Is NOT)

- **NOT a meta-progression grind**: Power comes from in-run skill drafting, not
  grinding between runs. We cut Equipment, Forging, and Talent Tree specifically
  to protect this.
- **NOT an open world**: Rooms are discrete combat arenas, not connected spaces
  to explore. Tight, replayable encounters over sprawling maps.
- **NOT narrative-driven**: Story is setting dressing, not a core pillar. A player
  who skips every cutscene should still have the full experience.

---

## Visual Identity Anchor

- **Direction**: Dark Fantasy with Warm Progression
- **Visual rule**: The world is dark and atmospheric, but every moment of player
  achievement glows warm gold.
- **Principles**:
  - Restrained color — dark panels, near-black backgrounds, color is rare and
    meaningful (warm gold accent for progression, rarity colors for items)
  - Fantasy-book typography — Cinzel serif for display text gives personality
    beyond generic sans-serif roguelites
  - Combat clarity over spectacle — VFX must communicate gameplay state, not
    just look impressive
- **Color philosophy**: One warm accent (#D4A843 gold) + neutrals + semantic
  colors. Gold = "you earned this."
- **Reference games**: Hades (functional HUD, strong art direction), Dead Cells
  (customizable HUD density), Slay the Spire (clean card drafting)

See `production/Trizzle/DESIGN.md` for the full design system.

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| Hades | Tight room-based combat, phase-shifting bosses, roguelike structure | Skill draft/combo system instead of boon choices; two distinct classes | Validates room-based action roguelite loop |
| Dead Cells | Fast combat pacing, class feel, high replayability | Build-crafting depth over procedural level variety | Validates punchy combat + roguelite retention |
| Vampire Survivors | Build-scaling power fantasy, overwhelming screen-filling attacks | Skill-based combat requiring positioning, not passive survival | Validates "broken build" power fantasy |
| Slay the Spire | Draft-based build construction, synergy discovery | Real-time combat instead of turn-based cards | Validates draft mechanics creating replay variety |

**Non-game inspirations**: Dark fantasy illustration (Frank Frazetta, Wayne Reynolds),
the "one more hand" psychology of poker and deck-builders, the warm-gold-on-dark
aesthetic of illuminated manuscripts.

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 18-35 |
| **Gaming experience** | Mid-core to Hardcore |
| **Time availability** | 15-30 minute sessions on weeknights, longer on weekends |
| **Platform preference** | PC (Steam) primary, mobile for commute sessions |
| **Current games they play** | Hades, Dead Cells, Vampire Survivors, Slay the Spire |
| **What they're looking for** | Build-crafting depth in a tight action package with high replay value |
| **What would turn them away** | Excessive grinding between runs, unfair difficulty, lack of build variety, slow pacing |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Engine** | Unity 6000.3.11f1 (URP 17.3.0, Linear color space) |
| **Key Technical Challenges** | 125+ skill interactions create exponential edge cases; PC/Mobile platform split with separate scenes and UI; performance on mobile with many simultaneous VFX |
| **Art Style** | 3D stylized dark fantasy |
| **Art Pipeline Complexity** | Medium (custom 3D assets, existing asset library, ScriptableObject-driven data) |
| **Audio Needs** | Moderate (AudioManager + AudioDatabase, per-skill SFX, ambient combat audio) |
| **Networking** | None (single-player) |
| **Content Volume** | 10 rooms × 2 difficulties, 125+ skills, 2 playable characters, 5 bosses, 14 trap types, 30+ enemy types, Endless Mode |
| **Procedural Systems** | Wave composition variation via SpawnManager; skill draft randomization; enemy stat variation via ApplyRandomVariation() |

---

## Risks and Open Questions

### Design Risks
- Build diversity may narrow to a few dominant combos — mitigate with balance passes and combo database expansion
- Archer class may not feel differentiated enough from Mage — mitigate with distinct base skills and exclusive upgrade paths

### Technical Risks
- 125+ skill interactions create exponential edge case surface — mitigate with UpgradableSkill framework and systematic testing
- PC/Mobile dual platform with separate scenes increases maintenance burden — mitigate with shared core systems and platform-specific UI layers

### Market Risks
- Action roguelite genre is crowded (Hades, Dead Cells, Vampire Survivors all established) — differentiate on build-crafting depth
- Solo developer capacity limits content velocity — focus on replayability over content volume

### Scope Risks
- 10 rooms × 2 difficulties + Endless is a large content deliverable for solo dev — mitigate with room template/archetype system
- 5 unique bosses with multi-phase AI require significant design + implementation time — mitigate with shared ability template library

### Open Questions
- Archer unlock gating: available from start or after clearing N rooms as Mage?
- Boss loot: guaranteed drops or standard loot table?
- Post-launch content cadence: new characters? new rooms? seasonal events?

---

## MVP Definition

**The demo IS the shipped MVP** — available on Steam with Mage gameplay, limited
rooms, and the draft/combo system validated by real players.

**Core hypothesis for v1.0**: Adding a second class, difficulty tiers, expanded
rooms, and Endless Mode makes the game replayable for 20+ hours and justifies
a premium price point on Steam.

**Required for v1.0**:
1. Archer character with 2 unique base skills + 7 exclusive skills
2. 10 rooms with Normal/Hard difficulty
3. 5 multi-phase bosses
4. Endless Mode with scaling waves
5. Difficulty system with 5-axis scaling

**Explicitly NOT in v1.0** (defer to post-launch):
- Equipment system (cut — protects in-run build-craft pillar)
- Forging/Crafting (cut — same reason)
- Talent Tree / meta-progression (cut — same reason)
- Additional characters beyond Archer (post-launch)
- Achievements (P2 — implement after all gameplay is playable)

### Scope Tiers

| Tier | Content | Features | Timeline |
| ---- | ---- | ---- | ---- |
| **MVP** | Demo (shipped) — Mage, limited rooms | Core combat + draft system | Complete |
| **v1.0 Minimum** | 10 rooms, 2 classes | Difficulty system, boss phases, archer | 6-9 months |
| **v1.0 Full** | 10 rooms × 2 difficulties + Endless | All v1.0 scope + achievements | 12-18 months |
| **Post-Launch** | Additional characters, rooms, events | Live content updates | Ongoing |

---

## Existing Systems (Already Implemented)

The following 14 systems are shipped and functional in the demo:

| ID | System | Status |
|----|--------|--------|
| D1 | Core Combat | Approved |
| D2 | Health & Death | Approved |
| D3 | Status Effects (27 states) | Approved |
| D4 | Skill System (125+ skills) | Approved |
| D5 | Enemy AI (30 controllers) | Approved |
| D6 | Trap System (14 types) | Approved |
| D7 | Roguelite Draft | Approved |
| D8 | Loot & Drops | Approved |
| D9 | Shop | Approved |
| D10 | Currency | Approved |
| D11 | Save/Load | Approved |
| D12 | Localization (11 locales) | Approved |
| D13 | Audio | Approved |
| D14 | UI Framework (101+ components) | Approved |

See `design/gdd/systems-index.md` for the full v1.0 systems enumeration and
dependency map.

---

## Next Steps

- [x] Engine configured (`/setup-engine` — Unity 6000.3.11f1)
- [ ] Create visual identity specification (`/art-bible`)
- [ ] Validate concept completeness (`/design-review design/gdd/game-concept.md`)
- [ ] Design remaining systems (`/design-system` for E4, E1, N2, N3)
- [ ] Plan technical architecture (`/create-architecture`)
- [ ] Record architectural decisions (`/architecture-decision`)
- [ ] Validate readiness (`/gate-check`)
- [ ] Plan first sprint (`/sprint-plan new`)
