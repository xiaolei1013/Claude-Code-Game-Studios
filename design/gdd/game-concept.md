# Game Concept: Lantern Guild

*Created: 2026-04-18*
*Status: Draft*

---

## Elevator Pitch

> It's a **cozy fantasy idle-clicker** where you run a hero guild, dispatch class-based formations into dungeons, and return to find accumulated loot that funds stronger recruits — a relaxing escalation loop inspired by *Devil Lord: Half of World* with HD-2D pixel-art presentation.

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | Idle / Incremental (fantasy subgenre) |
| **Platform** | PC (Steam) — Primary. Mobile (iOS/Android) planned post-launch. |
| **Target Audience** | Cozy idle players who want collection + light tactical depth |
| **Player Count** | Single-player |
| **Session Length** | 2-5 minutes, 2-4× per day (session-based idle) |
| **Monetization** | Premium (one-time purchase), no IAP |
| **Estimated Scope** | Large (6-12 months full vision, solo) — MVP ships in 4-6 weeks |
| **Comparable Titles** | *Devil Lord: Half of World*, *Melvor Idle*, *Idle Champions of the Forgotten Realms* |

---

## Core Fantasy

You are a guildmaster. Your heroes aren't you — they're a growing roster of specialists you collect, equip, and send out. The power fantasy isn't action; it's **curation and escalation**: the moment you return to find your level-12 Rogue party cleared a dungeon that wrecked you yesterday. The game plays itself competently; your job is to make it play *better* next session.

---

## Unique Hook

*Like Devil Lord, and also* a strategic **class-vs-biome matchup layer** that turns idle dungeon-picking into a soft tactical puzzle — each biome favors certain hero classes, so formation assignment becomes the core strategic verb instead of real-time intervention. Paired with **HD-2D-inspired pixel art**, which is genuinely rare in the idle genre.

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics (What the player FEELS)

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Sensation** (sensory pleasure) | 3 | HD-2D-inspired pixel portraits, warm lantern lighting, satisfying reward-tap feedback |
| **Fantasy** (make-believe, role-playing) | 2 | Fantasy guildmaster — collect a roster of classic archetypes (knight, mage, rogue, cleric…) |
| **Narrative** (drama, story arc) | N/A | Deliberately minimal — flavor text only, no branching story |
| **Challenge** (obstacle course, mastery) | 5 | Light — class/biome matchup decisions, not reflex challenge |
| **Fellowship** (social connection) | N/A | Single-player, no social features in MVP |
| **Discovery** (exploration, secrets) | 4 | Unlocking new classes, biomes, synergies |
| **Expression** (self-expression, creativity) | 6 | Formation composition choices |
| **Submission** (relaxation, comfort zone) | **1 (primary)** | Session-based idle loop, offline progression, no fail-state |

### Key Dynamics (Emergent player behaviors)

- Players will check in on a daily rhythm (morning/evening), optimizing class-to-biome assignments
- Players will experiment with formation compositions when new classes unlock
- Players will chase "breakthrough moments" — the first time a previously impossible dungeon gets cleared after recruiting a counter-class

### Core Mechanics (Systems we build)

1. **Idle Dungeon Combat** — assigned formations auto-fight; offline progression accumulates loot
2. **Class-vs-Biome Matchup** — each biome has enemy types weak/strong against specific class roles
3. **Roster Recruitment & Leveling** — spend loot to recruit new classes and level existing heroes
4. **Progression Unlocks** — clearing dungeons unlocks new biomes, classes, and gear tiers

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** (freedom, meaningful choice) | Formation composition, dungeon priority, recruit order are all player-owned | **Core** |
| **Competence** (mastery, skill growth) | Clear feedback on matchup effectiveness; breakthrough moments reward optimization | Supporting |
| **Relatedness** (connection, belonging) | Heroes have names and portraits but no deep narrative relationships | Minimal |

### Player Type Appeal (Bartle Taxonomy)

- [x] **Achievers** — collection completeness, tier-by-tier unlocks, dungeon milestones
- [x] **Explorers** — new biomes, class synergy discovery, unlock trees
- [ ] **Socializers** — not a target in MVP
- [ ] **Killers/Competitors** — explicitly out of scope

### Flow State Design

- **Onboarding curve**: First session = 5 min. Recruit starting class → assign to tutorial dungeon → see first offline reward notification. No tutorial text longer than one line per screen.
- **Difficulty scaling**: Dungeon floors scale smoothly; no hard walls, only soft "efficiency cliffs" that suggest recruitment of a specific counter-class.
- **Feedback clarity**: Return-to-app screen shows accumulated loot and a dungeon progress summary. Matchup effectiveness displayed as a clear multiplier badge.
- **Recovery from failure**: There is no fail state. A losing run returns partial loot and a "try a different class" hint.

---

## Core Loop

### Moment-to-Moment (30 seconds)

Tap the "collect" button on accumulated idle rewards; tap a hero to view stats; drag-drop a hero into a formation slot. Primary tactile pleasure is **numbers arriving** with a warm audio-visual confirmation.

### Short-Term (5-15 minutes)

Collect → spend on recruits/upgrades → reassign formations to unlocked dungeons → close app. One session should always have a visible "something new" — either a recruit, a level-up, or a new floor unlocked.

### Session-Level (30-120 minutes)

Typical session is 2-5 minutes, not 30-120 — this is session-based idle. Players open the app 2-4× per day. Natural stopping point = "nothing left to spend," which is the signal to close and let idle accumulate again.

### Long-Term Progression

Days: unlock class tiers (Common → Rare → Epic). Weeks: unlock all 5 biomes, hit the prestige layer (V1.0). Months: mythic class collection completeness, endgame dungeons.

### Retention Hooks

- **Curiosity**: What does the next class tier look like? What biome is behind the locked door?
- **Investment**: A hand-tuned roster represents hours of decisions — players won't abandon it easily
- **Social**: N/A in MVP
- **Mastery**: Optimizing biome matchups; prestige efficiency calculation; discovering class synergies post-MVP

---

## Game Pillars

### Pillar 1: Respect the Player's Time

The game earns time by being there when the player returns, not by demanding attention.

*Design test*: If we're debating "timed event vs always-available content," we pick always-available.

### Pillar 2: Every Class Feels Distinct

Class identity is legible within 5 seconds — silhouette, role, matchup niche. No stat-reskins.

*Design test*: If we're debating "10 similar classes vs 5 unmistakable ones," we pick 5.

### Pillar 3: Matchup Is a Decision, Not a Reflex

Class-vs-enemy choices happen at the assignment layer (strategic), never mid-combat (reactive).

*Design test*: If we're debating "reactive combat intervention vs strategic formation planning," we pick formation.

### Pillar 4: HD-2D Pixel Pride

Visual presentation (portraits, dungeon art, idle anims) carries the cozy fantasy — art does the emotional heavy lifting, not narrative.

*Design test*: If we're debating "more classes vs more polished existing classes," we pick polish.

### Anti-Pillars (What This Game Is NOT)

- **NOT timed events / FOMO** — would compromise Pillar 1 (respect player time)
- **NOT real-money accelerators in MVP** — would compromise Pillar 1 and the cozy promise
- **NOT narrative branches or dialogue trees** — would compromise Pillar 4 (scope stays visual, not literary)
- **NOT PvP or synchronous multiplayer** — would compromise the cozy/solo fantasy and explodes scope

---

## Visual Identity Anchor

**Named direction**: *Lantern-Lit Pixel Diorama*

**One-line visual rule**: *Every scene must feel like a warm miniature you want to pick up.*

**Supporting principles**:

- **Silhouette-first class design** — every hero class is recognizable at 32px from silhouette alone. (Test: if two classes share a silhouette, one gets redesigned.)
- **Depth via blur, not parallax** — HD-2D tilt-shift background blur creates cozy intimacy; no busy parallax layers. (Test: if background motion distracts from heroes, cut it.)
- **Warm palette anchors** — ambers, dusk-purples, gold highlights. No pure-saturated reds or greens. (Test: if a color feels "alarming," desaturate it.)

**Color philosophy**: Warm dusk palette with lantern highlights — the whole game should feel "lit by fireflies indoors."

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| *Devil Lord: Half of World* | The recruit-to-overpower idle loop; offline progression; class collection | Class-vs-biome matchup layer; PC premium target, not mobile gacha | Proves the emotional beat works |
| *Octopath Traveler* | HD-2D pixel art direction; job/class variety as identity | Idle pacing, not JRPG turn-based combat | Visual north star |
| *Balatro* | Collection → composition → escalation run feel; Achiever+Explorer overlap | Strategic formation (not reactive cards); cozy not gambling-adjacent | Validates synergy-discovery joy |
| *Melvor Idle* | Proof minimal-graphics idle sells on Steam; passive session rhythm | Much higher art bar; fantasy-action not life-sim framing | Market proof for Steam idle |

**Non-game inspirations**: Studio Ghibli interior color palettes (warm lamplight); tabletop miniature photography (shallow depth-of-field dioramas); Pentiment-style illuminated-manuscript UI accents.

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 25-45 |
| **Gaming experience** | Mid-core; has played idle games before |
| **Time availability** | 10-20 minutes/day across multiple short sessions |
| **Platform preference** | Steam + Steam Deck (mobile audience targeted in later release) |
| **Current games they play** | *Melvor Idle*, *Loop Hero*, *Vampire Survivors*, cozy indie JRPGs |
| **What they're looking for** | Idle progression with a pixel-art soul instead of a spreadsheet |
| **What would turn them away** | Monetization pressure, FOMO events, pay-to-skip walls, obvious mobile-port UI |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Recommended Engine** | Deferred to `/setup-engine`. Project is pre-pinned to Godot 4.6; Godot is a strong fit for 2D pixel art, Steam export, and solo indie scope. Unity is a viable alternative. Both Godot and Unity export cleanly to iOS/Android for the planned mobile port. |
| **Key Technical Challenges** | Accurate offline progression math; save-file integrity and anti-tamper; balancing idle curves; pixel-perfect HD-2D rendering (tilt-shift DoF + warm lighting); **input-agnostic UI (mouse + touch-friendly from MVP to avoid a full UI rewrite for the mobile port)** |
| **Art Style** | 2D pixel art, HD-2D inspired (tilt-shift DoF + warm lighting overlays) |
| **Art Pipeline Complexity** | Medium — custom pixel art for heroes/enemies; asset packs feasible for MVP backgrounds |
| **Audio Needs** | **MVP: silent** (AudioRouter wired but silent until a pivot trigger fires per `docs/architecture/ADR-0016-audio-asset-sourcing-silent-mvp.md`). **V1.0+ scope**: ambient dungeon loops, UI tap feedback, low-key fanfare for unlocks per `design/gdd/audio-system.md` §C. Pivot triggers: 3+ playtests flag missing audio · ≥$200 budget approval · mobile port milestone (silent-on-mobile is a hard gate) · sprint capacity surplus enabling AI-generation pathway. |
| **Networking** | None |
| **Content Volume** | MVP: 3 classes, 1 biome (5 floors), ~8 enemy types. V1.0: 15-20 classes, 5 biomes, prestige layer |
| **Procedural Systems** | None in MVP. Possibly procedural run variance in V1.0 (randomized dungeon modifiers) |

---

## Risks and Open Questions

### Design Risks

- **Core loop shallowness in MVP** — with only 3 classes and 1 biome, matchup decisions may feel thin. Mitigation: make each class unmistakable; introduce enemy-type variety within the biome.
- **Session-based pacing may undersell engagement** — if the first-return feel isn't satisfying, retention craters immediately. This is the single highest-priority polish target.

### Technical Risks

- **Offline progression math** — notoriously hard to tune; bugs here break player trust. Budget explicit tuning passes.
- **HD-2D rendering fidelity** — achieving the Octopath-inspired look with pixel sprites requires custom shader work (tilt-shift blur, lighting overlays) that may slip MVP scope. Fallback: crisp pixel art without HD-2D shader layer for MVP, add shader polish in Vertical Slice tier.

### Market Risks

- **Idle genre is crowded** — differentiation rests heavily on the art direction and class-matchup hook landing with players.
- **Steam audience for idle games is smaller than mobile** — but more willing to pay premium once, which matches our monetization choice.

### Scope Risks

- **"Weeks" MVP timeline is aggressive** even for one dungeon. Realistic minimum: 4-6 weeks solo assuming asset-pack leveraging for backgrounds and placeholder sprites.
- **HD-2D art style** can easily grow into a multi-month art project by itself — guard rail: use the Visual Identity Anchor tests ruthlessly during asset review.

### Open Questions

- Is 3 classes enough to test the matchup hypothesis, or do we need 5 to feel distinct? (Answer via prototype playtest.)
- How aggressive should the offline progression curve be? (Answer via MVP tuning passes.)
- Does the class-vs-biome layer read clearly without tutorial text? (Answer via first-return usability test.)

---

## MVP Definition

**Core hypothesis**: *Players find the "assign → idle → return → escalate" loop satisfying enough to open the app multiple times per day without external push notifications.*

**Required for MVP**:

1. 3 hero classes with distinct silhouettes and class-counter roles
2. 1 dungeon biome with 5 floors and 5-8 enemy types mapped to the class-counter rules
3. Offline progression math that rewards return visits with visible accumulated loot
4. Recruit/level UI that lets players spend loot meaningfully
5. Formation assignment UI that reads matchup effectiveness clearly (mouse + touch friendly)
6. Save/load with basic anti-tamper for offline gains

**Explicitly NOT in MVP** (defer to later tiers):

- Prestige layer
- Multiple biomes
- Class synergies beyond matchup rules
- Bosses, raids, or event content
- Hero narrative flavor or dialogue
- Mobile port (design-ready but not built)

### Scope Tiers

| Tier | Content | Features | Timeline |
| ---- | ---- | ---- | ---- |
| **MVP** | 3 classes, 1 biome (5 floors) | Idle loop, recruit, assign, upgrade, save/load | 4-6 weeks solo |
| **Vertical Slice** | 5 classes, 2 biomes | + class tier system, HD-2D shader pass, polish | +4 weeks |
| **Alpha** | 10 classes, 3-4 biomes | + prestige, audio pass, full visual polish pass | 3-4 months total |
| **Full Vision** | 15-20 classes, 5 biomes, mythic tier | + class synergies, boss dungeons, endgame | 6-12 months total |
| **Post-Launch** | + mobile port | iOS/Android build, touch-optimized UI pass | Post V1.0 |

---

## Next Steps

- [ ] `/setup-engine` — configure engine (Godot 4.6 pre-pinned; validate or change)
- [ ] `/art-bible` — expand Visual Identity Anchor into full art bible (gates asset production)
- [ ] `/design-review design/gdd/game-concept.md` — validate concept completeness
- [ ] `/map-systems` — decompose into individual systems (idle math, roster, dungeon, UI, save)
- [ ] `/design-system [first-system]` — author per-system GDDs in dependency order
- [ ] `/create-architecture` — architecture blueprint + Required ADR list
- [ ] `/architecture-decision (×N)` — write ADRs per the Required list
- [ ] `/create-control-manifest` — compile decisions into actionable rules sheet
- [ ] `/gate-check` — validate readiness for production
- [ ] `/prototype` — throwaway prototype of the idle math + class matchup
- [ ] `/playtest-report` — validate core hypothesis
- [ ] `/sprint-plan new` — plan first production sprint
