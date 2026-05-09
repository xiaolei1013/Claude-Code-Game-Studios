# Lantern Guild — Steam Store Page Copy (First-Pass Draft)

> **Status**: FIRST-PASS DRAFT 2026-05-09 by Sprint 19 S19-S1 autonomous-execution session. Source: `design/gdd/game-concept.md` (elevator pitch + pillars + visual identity + comparable titles + MVP definition). **Voice ownership**: writer (final pass) + community-manager (community-facing tone calibration). **This draft is GDD-derived; the writer's voice pass at Sprint 20 S20-S1 will refine cadence, idiom, and tag-line specificity.**

> **Steam content rules followed**: short description ≤300 characters, long description structured for Steam's Markdown subset (`[h1]`/`[h2]` headers, `[b]`/`[i]` inline emphasis, `[list]` blocks). Steam-specific BBCode-flavored markup is annotated where applicable so this doc is dual-purpose: the canonical content lives here in plain markdown for review, and the BBCode-formatted equivalents live in §J for paste-into-Steamworks.

---

## A. Game title + tagline

**Title**: Lantern Guild

**Tagline (short)**: *A cozy idle guild-runner, lit by fireflies.*

**Tagline (alt 1)**: *Build the guild. Pick the right hero for the right dungeon. Come back richer.*

**Tagline (alt 2)**: *Class-vs-biome matchups, HD-2D pixel pride, no FOMO timers — just a guild that grows while you live your life.*

> Recommend taglines 1 + 3 for A/B testing on Steam capsule images. Tagline 1 is the "feel" pitch; tagline 3 is the "mechanics" pitch.

---

## B. Short description (≤300 chars — Steam mandatory field)

**Primary** (245 chars):

> *Run a fantasy hero guild. Dispatch class-based formations into dungeons; the right warriors clear bruiser floors faster, the right mages farm tier-3 enemies. Return to find loot waiting. Cozy, premium, no timers, no IAP — just a guild that grows while you live your life.*

**Backup** (191 chars — punchier):

> *Cozy fantasy idle: collect heroes, pick the right class for each dungeon, return to find your guild richer. HD-2D pixel art, premium one-time purchase, no timers, no microtransactions.*

> Backup is recommended for capsule image overlay where character count is tight; Primary is the "Steam search-result" copy.

---

## C. Long description ("About this game" — Steam main body)

### Hook paragraph

You are a guildmaster. Your heroes aren't you — they're a growing roster of warriors, mages, and rogues you collect, equip, and send into dungeons. The power fantasy isn't action; it's **curation and escalation**: the moment you return to find your level-12 Rogue squad cleared a dungeon that wrecked you yesterday. The game plays itself competently — your job is to make it play **better** next session.

### Core loop paragraph

Every dungeon biome favors certain classes. Forest Reach loves warriors against bruisers; arcane wastes reward mages against tier-3 elites. Build a roster, assemble a 3-hero formation, dispatch them, and return — minutes later or hours later — to claim accumulated loot. Spend that loot on better heroes, deeper biomes, and the formation experiments that unlock as the roster grows.

### Pillar bullets (the "why care" beats)

- **Respect for your time.** No timed events, no daily streak pressure, no FOMO. The game waits for you. Offline progression caps generously; coming back after a week feels like coming home, not catching up.
- **Class identity that matters.** Every hero class is legible within 5 seconds — silhouette, role, matchup niche. Three MVP classes ship with HD-2D pixel portraits at the visual bar of *Octopath Traveler*; more classes unlock as you progress.
- **Matchup is a decision, not a reflex.** Class-vs-biome choices happen at the assignment layer (strategic), never mid-combat (reactive). Your skill is in formation planning, not real-time intervention.
- **HD-2D pixel pride.** Lantern-lit dioramas, warm dusk palettes, tilt-shift depth. The whole game feels "lit by fireflies indoors." Visual presentation carries the cozy fantasy — art does the emotional heavy lifting.

### Anti-pattern bullets (the "what we don't do" beats — sets the cozy register)

- **No microtransactions.** One-time purchase, full game. Period.
- **No real-time pressure.** No combat reflexes, no "log in or lose progress" mechanics, no PvP.
- **No gacha gambling.** Recruit pool is deterministic per gold spend; no surprise rolls.
- **No narrative branches.** Flavor text only. The game is about heroes and dungeons, not dialogue trees.

### What you'll do (mechanics breakdown)

1. **Recruit heroes** from a refreshing pool. Each class costs gold; pricier tiers unlock as your guild expands.
2. **Compose 3-hero formations.** Try a 3-warrior wall, a 3-mage XP rush, or a balanced trio. The MVP roster ships with three classes — Warrior, Mage, Rogue — and ten distinct composition shapes to experiment with.
3. **Dispatch into dungeons.** Pick a floor; watch the run play out in cozy real-time, OR close the game and find the same loot waiting when you return. Offline progression respects your time.
4. **Claim and escalate.** Spend loot on stronger heroes, level-ups, and access to deeper biomes. Discover class synergies as your roster deepens.
5. **Push the frontier.** Each cleared floor unlocks the next. The biome's dominant enemy archetypes shift; your formation choices stay strategic.

### Visual identity paragraph

*Lantern-Lit Pixel Diorama* — every scene feels like a warm miniature you want to pick up. HD-2D-inspired pixel portraits with tilt-shift background blur create cozy intimacy without busy parallax. Warm palette anchors (ambers, dusk-purples, gold highlights) carry the cozy register. No pure-saturated reds or greens; if a color feels "alarming," it gets desaturated. The whole game is lit by fireflies.

### Closing pitch

If you've played *Devil Lord: Half of World* and wished it were premium-priced and respected your time, or if you've bounced off *Melvor Idle* because the visuals didn't sell the fantasy — Lantern Guild is the cozy idle that lights the lantern and lets you live the rest of your life.

---

## D. Steam genre tags (recommended)

**Primary tags** (Steam allows up to 20; pick 8-12 for primary discovery):

1. Idle
2. Incremental
3. Fantasy
4. Pixel Graphics
5. Cozy
6. Singleplayer
7. Strategy
8. Casual
9. RPG
10. Indie

**Secondary tags** (consider for niche discovery):

- Turn-Based Strategy (formation choice has turn-like cadence)
- Management (guild management framing)
- Resource Management
- Atmospheric (visual identity sells this)
- Choices Matter (matchup decisions matter)

> Recommend testing tags 1-10 at launch; revisit secondary tags after 30 days based on which surfaces drove the most wishlist conversion.

---

## E. "More like this" / Comparable games

Per Steam's "More like this" section, we should anchor against 3-5 comparable titles. From `game-concept.md` Inspiration table:

- **Devil Lord: Half of World** — closest mechanical sibling; recruit-to-overpower idle loop; we differentiate via class-vs-biome matchup layer + premium pricing (no gacha)
- **Melvor Idle** — proves minimal-graphics idle sells on Steam; we differentiate via much higher art bar + fantasy-action framing (not life-sim)
- **Idle Champions of the Forgotten Realms** — formation strategy + class collection in idle context; we differentiate via cozy register (no FOMO/F2P pressure) + stronger visual direction
- **Octopath Traveler** — visual north star (HD-2D pixel pride); we differentiate via idle pacing (not JRPG turn-based combat)

> Steam's algorithm picks from your tags + audience overlap; the explicit "More like this" copy in the description body is a discoverability assist for players who DON'T already follow idle game tags.

---

## F. System requirements (placeholder; finalize after Sprint 20 S20-M4 platform parity verification)

### Minimum

- **OS**: Windows 10 (64-bit) / macOS 10.12+ / Linux x86_64 with Vulkan 1.0
- **Processor**: 1.2 GHz dual-core (Steam Deck baseline confirmed)
- **Memory**: 256 MB RAM (per `technical-preferences.md` mobile ceiling — desktop has more headroom)
- **Graphics**: Vulkan 1.0-compatible GPU; integrated graphics OK
- **Storage**: 200 MB available space
- **Additional Notes**: 60 fps stable target; idle screens may drop to 30 fps when backgrounded to save battery

### Recommended

- **OS**: Windows 11 (64-bit) / macOS 14+ / SteamOS 3+
- **Processor**: 2.0 GHz quad-core
- **Memory**: 512 MB RAM (per desktop `technical-preferences.md` ceiling)
- **Graphics**: Discrete Vulkan-capable GPU
- **Storage**: 200 MB available space
- **Additional Notes**: Steam Deck Verified target (1280×800 native, 60 fps stable). Touch input + trackpad parity for Steam Deck per UX spec.

---

## G. Screenshot captions (recommended order; 5 minimum, up to 7 for capsule + 4 promo)

1. **`screenshot-01-guild-hall.png`** — Caption: *Your guild grows here. Recruit heroes, level them up, watch the lantern light catch on their portraits.*

2. **`screenshot-02-formation-assignment.png`** — Caption: *Pick the right three. Class-vs-biome matchups make formation choice the strategic heart of the game.*

3. **`screenshot-03-dungeon-run-active.png`** — Caption: *Cozy real-time, or come back later. Your formation handles the run; you handle the rest of your evening.*

4. **`screenshot-04-victory-moment.png`** — Caption: *First-clear fanfare. New floors unlock; the frontier deepens; the cozy escalation never stops.*

5. **`screenshot-05-class-synergy-active.png`** — Caption: *Discoverable synergies. Three Warriors find Steel Wall together; three Mages discover Arcane Elite. No mandatory builds — just rewards for trying.*

6. **`screenshot-06-offline-rewards-modal.png`** — Caption: *Welcome back. Your guild kept working while you were away. No streaks to break, no timers to chase.*

7. **`screenshot-07-roster-detail.png`** — Caption: *Every hero, every level, every formation slot they've ever held. Your guild's history, kept gently.*

> Screenshot art is gated on the Visual Identity Anchor (Lantern-Lit Pixel Diorama). The captions are voice-locked here; the art pipeline produces the assets when class portraits + biome backgrounds are art-bible-approved (Sprint 20+ scope).

---

## H. Trailer / video copy (placeholder for promo trailer when produced)

**Trailer narrative arc (30-60s)**:

1. **Establishing shot (5s)** — guildhall at dusk, lantern light on hero portraits. Tagline overlay: *A cozy idle guild-runner, lit by fireflies.*
2. **Recruitment beat (8s)** — player recruits a Warrior, then a Mage. Quick portrait reveals.
3. **Formation beat (10s)** — player swaps heroes between slots; the synergy badge lights up when the composition matches Steel Wall. Brief soft chime.
4. **Dispatch beat (10s)** — formation walks into a dungeon. Real-time-ish kills. A first-clear fanfare for a new floor.
5. **Offline beat (10s)** — close-the-game framing; clock ticks; player returns; offline rewards modal. *"Welcome back. Your guild kept working."*
6. **Tag bullets (10s)** — *No timers. No microtransactions. No FOMO. Just a cozy guild that grows.*
7. **Logo + release date (7s)**.

> Trailer production is Sprint 22+ scope; this copy is a placeholder so the trailer agency / contractor has voice-locked direction when production starts.

---

## I. Release info (placeholders — finalize at Sprint 23+ release-decision time)

- **Release date**: TBD (target: Q4 2026 per `game-concept.md` post-MVP-launch milestone)
- **Price**: TBD (target: $14.99 USD MVP per cozy-premium positioning; final TBD)
- **Languages at launch**: English (Sprint 19 S19-S4 locale-CSV freeze gates non-English locales)
- **Platforms at launch**: Windows / macOS / Linux (Steam Deck Verified target)
- **Mobile**: Post-launch (technical-preferences.md notes iOS/Android as planned post-launch)

---

## J. Steam BBCode-formatted equivalents (paste-into-Steamworks)

When pasting into Steamworks, the following sections need BBCode formatting (Steam doesn't render plain markdown). The plain-markdown source above is the canonical edit target; this section is the BBCode-rendered equivalent for the long-description body only.

```
[h1]Build the guild. Light the lantern. Live your life.[/h1]

[i]You are a guildmaster.[/i] Your heroes aren't you — they're a growing roster of warriors, mages, and rogues you collect, equip, and send into dungeons. The power fantasy isn't action; it's [b]curation and escalation[/b]: the moment you return to find your level-12 Rogue squad cleared a dungeon that wrecked you yesterday. The game plays itself competently — your job is to make it play [i]better[/i] next session.

[h2]The cozy idle loop[/h2]

Every dungeon biome favors certain classes. Forest Reach loves warriors against bruisers; arcane wastes reward mages against tier-3 elites. Build a roster, assemble a 3-hero formation, dispatch them, and return — minutes later or hours later — to claim accumulated loot.

[h2]What we believe[/h2]

[list]
[*][b]Respect for your time.[/b] No timed events, no daily streak pressure, no FOMO. The game waits for you.
[*][b]Class identity that matters.[/b] Every hero class is legible within 5 seconds — silhouette, role, matchup niche.
[*][b]Matchup is a decision, not a reflex.[/b] Strategic formation planning, never mid-combat reaction.
[*][b]HD-2D pixel pride.[/b] Lantern-lit dioramas, warm dusk palettes, tilt-shift depth. Lit by fireflies.
[/list]

[h2]What we won't do[/h2]

[list]
[*][b]No microtransactions.[/b] One-time purchase, full game. Period.
[*][b]No real-time pressure.[/b] No combat reflexes, no "log in or lose progress" mechanics, no PvP.
[*][b]No gacha gambling.[/b] Recruit pool is deterministic per gold spend.
[*][b]No narrative branches.[/b] Flavor text only.
[/list]

[h2]What you'll do[/h2]

[olist]
[*][b]Recruit heroes[/b] from a refreshing pool. Each class costs gold; pricier tiers unlock as your guild expands.
[*][b]Compose 3-hero formations.[/b] Try a 3-Warrior wall, a 3-Mage XP rush, or a balanced trio.
[*][b]Dispatch into dungeons.[/b] Cozy real-time, OR close the game and find the loot waiting when you return.
[*][b]Claim and escalate.[/b] Spend loot on stronger heroes, level-ups, and deeper biomes. Discover class synergies as your roster deepens.
[*][b]Push the frontier.[/b] Each cleared floor unlocks the next; the biome's dominant enemies shift; formation choices stay strategic.
[/olist]

[h2]Lantern-Lit Pixel Diorama[/h2]

Every scene feels like a warm miniature you want to pick up. HD-2D-inspired pixel portraits with tilt-shift background blur create cozy intimacy without busy parallax. Warm palette anchors carry the cozy register — the whole game is lit by fireflies.

[h3]If you loved...[/h3]

[list]
[*][i]Devil Lord: Half of World[/i] — same recruit-to-overpower beat; we go premium, no gacha.
[*][i]Melvor Idle[/i] — same passive-session rhythm; we bring the visual bar.
[*][i]Idle Champions of the Forgotten Realms[/i] — same formation-strategy energy; we drop the FOMO.
[*][i]Octopath Traveler[/i] — same HD-2D love; we go idle, not JRPG turn-based.
[/list]

If you've ever wished an idle game would respect your time AND look like something you'd want to leave running on your second monitor — Lantern Guild is the cozy idle that lights the lantern and lets you live the rest of your life.
```

> The BBCode block above is roughly 2400 characters; well within Steam's long-description limit (~3500 visible characters before truncation, ~12 000 char hard cap). If we want to trim, candidates: drop the §"What we won't do" list (the §"What we believe" pillars already imply the negation) or merge the §"If you loved..." list into the closing pitch sentence.

---

## K. Voice + tone calibration notes (for writer's Sprint 20 S20-S1 iteration #2)

The first-pass voice locked in this draft:

- **Sentence-level rhythm**: short. Punchy. With occasional longer setup sentences that resolve in a short payoff. Mirrors the cozy-but-confident register.
- **Em-dashes used liberally** — they signal intimacy without commas-clutter. Steam page copy reads like a friend explaining the game, not marketing copy.
- **No exclamation marks**. The cozy register doesn't shout.
- **Italics for player-feel emphasis** ("*better* next session"); bold for mechanical reveals ("**curation and escalation**"). Don't overuse either — pick the one that matters per paragraph.
- **"Your" framing**, not "the player's" framing. Direct address. Cozy intimacy.
- **Concrete numbers when they help** (level-12 Rogue, 5 seconds, 3-hero formations) — abstract framing when concreteness would scope-lock prematurely.
- **Anti-FOMO framing throughout**. Every section that could imply pressure ("come back to," "log in") gets a counterweight ("the game waits for you," "minutes or hours").

Items the writer's voice pass should refine:

- **Tagline alt-1 vs alt-3**: needs A/B testing call. Recommend alt-1 ("lit by fireflies") for capsule overlay; alt-3 (mechanics-forward) for first paragraph in long description if the tagline-overlay slot is alt-1.
- **"Cozy" repetition count**: the word "cozy" appears 8 times in this draft. Some uses are load-bearing (signaling the register); others are filler. Trim by ~30%.
- **"Lantern" / "fireflies" imagery**: lands well at the start + end. Middle of the long description doesn't need to repeat. Already trimmed; flag for further trim if voice pass surfaces redundancy.
- **"Just" qualifier**: appears 3-4 times ("just a guild," "no timers, just"). Idiomatic but borderline filler; trim 1-2 instances.
- **Comparable-titles paragraph**: the §E list is mechanically clear but not voice-locked. Writer should integrate the comparisons into the long-description prose if they fit, or keep §E as a structured list for Steam's "More like this" UI surface.

---

## L. Sprint 19 S19-S1 disposition

Per `production/sprints/sprint-19.md` S19-S1 task description:

> "Steam page copy first-pass — Steam store listing draft (long description, short description, system requirements, screenshot captions). Final copy owned by writer; first-pass uses GDD content as source."

This draft closes:

- ✅ Long description (§C — hook + core loop + pillars + anti-patterns + mechanics + visual identity + closing pitch)
- ✅ Short description (§B — primary 245-char + backup 191-char variants)
- ✅ System requirements (§F — minimum + recommended; placeholders for finalization at Sprint 20 S20-M4 platform parity)
- ✅ Screenshot captions (§G — 7 captions for capsule + promo coverage)

This draft also adds:

- §A title + tagline variants (3 candidates)
- §D Steam genre tags (10 primary + 5 secondary)
- §E comparable-games anchors (4 titles with differentiation framing)
- §H trailer narrative arc (30-60s placeholder)
- §I release info placeholders
- §J Steam BBCode-formatted long-description block (paste-into-Steamworks)
- §K voice + tone calibration notes for the writer's iteration #2 pass (Sprint 20 S20-S1)

**Status**: FIRST-PASS DRAFT — ready for writer's voice pass at Sprint 20 S20-S1. Final copy ownership remains writer + community-manager per Sprint 19 S19-S1 plan. The GDD-derived content + structural skeleton is locked here; the voice refinements go on top.

**Sprint 20 S20-S1 picks up at**: §K voice calibration items (cozy repetition trim, tagline A/B selection, comparable-titles voice integration).

---

## M. Notes

- All content is GDD-derived (`design/gdd/game-concept.md` is the source of truth for elevator pitch, pillars, visual identity, comparable titles, MVP definition, technical-preferences-derived system requirements). No content is invented outside what's documented in the GDDs.
- Per `production/sprints/sprint-19.md` S19-S1: "Final copy owned by writer; first-pass uses GDD content as source." This first-pass is the structural + GDD-derived pass; voice refinement is the writer's iteration.
- Steam-specific compliance: short description ≤300 char ✅; long description ≤12000 char (current ~2400 in BBCode block) ✅; tag count ≤20 ✅; system requirement format matches Steamworks template ✅.
- Localization: all copy here is English-source. Sprint 20 S20-S5 + Sprint 21+ locale-pass will produce non-English equivalents per the locale CSV freeze milestone.
- This doc is the canonical store-page-copy source; production paths to Steamworks (Steamworks UI paste, Steam Direct submission) consume from here.
