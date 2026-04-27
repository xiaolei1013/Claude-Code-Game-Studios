# Art Bible: Lantern Guild

*Created: 2026-04-18*
*Status: v1.0 Approved (Sprint 8 S8-N10 — 2026-04-27)*
*Visual Identity Anchor: Lantern-Lit Pixel Diorama*
*One-line visual rule: **Every scene must feel like a warm miniature you want to pick up.***

> **Art Director Sign-Off (AD-ART-BIBLE)**: APPROVED WITH CONDITIONS — see `design/art/ad-art-bible-signoff-2026-04-27.md` for the full review report. Structural completeness 9/9; tonal consistency verified against Visual Identity Anchor + character profiles + UX specs. 4 non-blocking conditions tracked for Sprint 9+ polish (explicit §5↔character-profiles cross-links; §2/§9 post-playtest refresh; §8 budgets re-validation after first real-asset batch; accessibility-specialist cross-review).

---

## Table of Contents

1. [Visual Identity Statement](#section-1-visual-identity-statement)
2. [Mood & Atmosphere](#section-2-mood--atmosphere)
3. [Shape Language](#section-3-shape-language)
4. [Color System](#section-4-color-system)
5. [Character Design Direction](#section-5-character-design-direction)
6. [Environment Design Language](#section-6-environment-design-language)
7. [UI/HUD Visual Direction](#section-7-uihud-visual-direction)
8. [Asset Standards](#section-8-asset-standards)
9. [Reference Direction](#section-9-reference-direction)

---

## Section 1: Visual Identity Statement

**Named Direction: *Lantern-Lit Pixel Diorama***

**One-line visual rule: *Every scene must feel like a warm miniature you want to pick up.***

This game is not an action game that happens to use pixel art. It is a cabinet of curiosities where every hero portrait, every dungeon floor, and every inventory slot radiates the warmth of something hand-crafted and lit from within. The HD-2D technique is not decoration — it is the primary emotional delivery mechanism. Where the game has no narrative, the art must carry full weight of "I want to stay here." Every asset decision starts with: does this feel like something someone made with care, under a warm lamp, for you to look at?

Three supporting principles govern every visual decision made on this project.

### Principle 1: Silhouette-First Class Identity

Every hero class must be recognizable from its silhouette alone at 32 pixels wide, before color, texture, or animation play any role.

*Design test:* When two proposed hero classes look interchangeable in a grayscale silhouette pass, one of them gets redesigned — not recolored — before any color work begins. Color is confirmation, not identification.

*Pillar served:* **Every Class Feels Distinct (Pillar 2).** A player glancing at their formation panel in a 2-minute play session cannot afford to misread a silhouette. The silhouette is the UI.

### Principle 2: Depth Through Blur, Not Motion

The sense of three-dimensional intimacy — the "miniature" quality — is achieved entirely through the tilt-shift depth-of-field treatment. Background elements are soft; the hero layer is sharp; foreground props may carry a mild vignette. No scrolling parallax layers. Background motion pulls the eye away from the hero roster and breaks the diorama illusion.

*Design test:* If a proposed background treatment creates any horizontal or vertical movement behind the hero layer during normal gameplay, it is removed or replaced with a static blurred plate. Seasonal or time-of-day lighting shifts are expressed through a color grade overlay, not through moving layers.

*Pillar served:* **HD-2D Pixel Pride (Pillar 4)** and **Respect the Player's Time (Pillar 1).** Busy backgrounds punish the returning player who is trying to read their dungeon results quickly.

### Principle 3: Warm Palette Anchoring — "Lit by Fireflies Indoors"

The entire game lives in the amber-to-dusk-purple color temperature band. No pure-saturated primary colors. Red is desaturated to rust; green is desaturated to sage or moss. The brightest, most saturated color in any scene is a warm lantern gold — reserved exclusively for rewards, unlocks, and progression moments.

*Design test:* If a color in a proposed asset would read as "alarming" rather than "inviting" in isolation — pure red health bars, neon green poison, electric blue magic — it is pulled back into the warm palette. Danger is expressed with cooler dusk-purple, not with hue contrast against a warm ground. Exception: colorblind-safety backup cues (see Section 4) may use shape and icon rather than hue.

*Pillar served:* **HD-2D Pixel Pride (Pillar 4).** The cozy emotional register lives or dies on this principle. A single unanchored saturated color in a screenshot destroys the "warm miniature" read.

---

## Section 2: Mood & Atmosphere

The Guild Hall is the emotional home of the game — every other state is a variation that eventually resolves back to it. The atmospheric language of each state must be visually distinct enough that players feel the shift, but all states remain within the Lantern-Lit Diorama family. Nothing should feel jarring; only different inflections of the same lamp-lit world.

### Guild Hall (Dominant State)

*Primary emotion:* Warm competence. The player is home, surrounded by evidence of their own good work. Safe abundance.

*Lighting character:* Interior warm amber, 2700K temperature equivalent. Late afternoon light bleeding through high windows, competing with and losing to the lantern light from below. High warmth, low contrast. Shadows are soft purple-brown, never black. Think Ghibli's smithy scenes — productive calm.

*Atmospheric descriptors:* Hearthside stillness. Trophies on the wall. A roster board that's filling in. Dust motes in shaft light. The smell of old wood (implied through texture).

*Energy level:* Low-medium. The hall breathes slowly. Hero idle animations cycle at half the speed of dungeon state. A tavern that's between rush hours — occupied, not empty, not crowded.

### Dungeon Run (Watching Idle Auto-Combat)

*Primary emotion:* Confident anticipation. The player is watching their investment perform. Not anxiety — curiosity. "Will they make it?"

*Lighting character:* Cooler than Guild Hall. Ambient is muted blue-grey with the hero party carrying warm torch light with them into the frame. The dungeon is cold; the heroes are warm. Color temperature contrast: 4500K background, 2900K hero lighting.

*Atmospheric descriptors:* Stone wet with age. Torchlight halos on rough walls. Distant clinking. Enemy units emerge from the darker edge of the diorama. Shadows have more contrast than Guild Hall — the dungeon is a place that doesn't belong to the player yet.

*Energy level:* Medium. Combat idles faster than Guild Hall. Enemy sprites have a restless quality — swaying, pacing — where guild heroes stood calmly. The floor shakes faintly on heavy hits (camera micro-offset, not sprite animation).

### Return-to-App (First Screen After Offline Gains)

*Primary emotion:* Delight of discovery. The specific pleasure of finding more than expected. A gift that was earned.

*Lighting character:* A moment of heightened warmth — the lantern gold is more present here than in any other state. The loot display is backlit by a warm gradient that fades once the player begins tapping. This is the game's maximum color saturation moment, and it's brief by design.

*Atmospheric descriptors:* Coins catching light. A ledger page filling itself in. The guild board with new checkmarks. Small celebratory particles — not explosive, more like falling embers or drifting sparks. The sensation of opening a well-packed chest.

*Energy level:* High-brief. The Return screen is the game's single highest-energy moment, designed to last exactly as long as the player's first few taps. It resolves back to Guild Hall energy within 3-5 seconds of interaction. Never lets itself overstay.

> **UX hard constraint (this screen is the first impression of every session):** Accumulated loot numbers must be legible within one frame of the screen appearing. Atmospheric parchment texture and ink ornaments are permitted but must NOT obscure the number readout. If art treatment reduces legibility of the primary number, atmosphere yields. This is the single highest-risk panel in the entire UI.

### Recruit / Class Detail (Inspecting a Hero Card)

*Primary emotion:* Connoisseur's appreciation. The pleasure of examining a thing made well. Pride of ownership anticipated.

*Lighting character:* Vignette focus — the hero card is pin-lit, everything outside the card darkens to a warm charcoal. Like a collector's spotlight on a single miniature. The card background is a deep parchment amber with the character portrait rendered in full HD-2D detail tier.

*Atmospheric descriptors:* A portrait with presence. Marginalia in ink at the card edges (passive flavor). Class role icon rendered in lantern gold. Faint texture of aged paper under the art. The sense that this character exists beyond the stats column.

*Energy level:* Low. The recruit screen is where a player deliberates. Silence is welcome. Idle animations on the portrait are minimal — a breath cycle, an eye blink. The card does not fight for attention; it rewards sustained looking.

### Matchup Assignment (Formation → Dungeon Screen)

*Primary emotion:* Strategic clarity. The satisfying click of a plan coming together. Legible complexity — not overwhelming, but with visible depth.

*Lighting character:* Split-temperature design. The left panel (your formation) uses Guild Hall warm amber. The right panel (dungeon enemy preview) uses the cooler dungeon palette from Dungeon Run. The center — the assignment interface — is neutral parchment, mediating between both. Players can feel which side belongs to them.

*Atmospheric descriptors:* A war table. Parchment map with wax-seal accents. Class role icons arranged by hand. Enemy thumbnails with legible threat markers. The sense of deliberate placement — this is the game's primary strategic verb happening.

*Energy level:* Low-medium. Deliberate. No hurry. Animation on this screen is minimal — icon placement has a soft settle, like moving pieces on a board. Nothing pulses or demands a tap.

### Victory / Unlock Moment (New Floor or New Class)

*Primary emotion:* Earned revelation. The emotional beat of "I built that." Not surprise (the player planned this) — the satisfaction of a prediction confirmed plus the excitement of what comes next.

*Lighting character:* A brief lantern-gold flare from the center of the screen, fading within 1.5 seconds to the ambient of the current game state (Guild Hall if returning from a run, Dungeon if still active). The flare is warm, not white. It is sunrise, not lightning.

*Atmospheric descriptors:* The guild board gaining a new entry. A class portrait sliding into frame with a soft reveal. Ink-drawn flourishes framing the unlock (illuminated manuscript style — Pentiment DNA here). A class unlock shows the hero standing in their home lighting, not in combat. They are recruited; they belong to the guild now.

*Energy level:* High-brief, same as Return-to-App but with more ceremony. The unlock reveal holds for 2-3 seconds before the player can interact — the art earns one uninterrupted moment of attention, then steps aside. After the reveal, Guild Hall energy reasserts immediately.

---

## Section 3: Shape Language

### Character Silhouette Philosophy

The 32-pixel silhouette test is the primary design constraint for all hero classes. A silhouette is readable when a player with no game knowledge, shown only a black rectangle at 32px wide, can correctly name the archetype. This means shape must substitute entirely for color, texture, and detail.

The three MVP classes establish the silhouette grammar that all future classes extend from:

**Warrior** — Mass over elegance. Wide shoulders, shield on left arm creating an asymmetric horizontal extension, sword or axe carried low on the right. The silhouette should be the widest hero in the roster. Stance is grounded — low center of gravity. No flowing fabrics; the warrior is a compact, armored rectangle with a distinctive weapon protrusion that reads as "armament" not "tool."

**Mage** — Vertical accent over horizontal mass. Staff or focus extending above the head is the distinguishing read — the silhouette apex is always higher than the Warrior's. Robes flare slightly at the base (a cone or bell shape from waist down), creating contrast with the narrow upper body. The silhouette should be the tallest-appearing hero, even if the pixel height is identical to the Warrior, because the staff extends the vertical read.

**Rogue** — Asymmetry and lean. Where the Warrior is symmetric and the Mage is vertically centered, the Rogue's silhouette leans — a mid-action pose bias, crouched slightly, one arm extended or held differently from the other. Cloaks, hoods, or wrapped elements compress the horizontal width to narrower than Warrior. The dagger held reverse-grip creates a forearm silhouette that reads as neither sword nor staff — it is specific.

For **V1.0 classes:**

- **Cleric** distinguishes with a raised implement (censer, lantern, holy symbol) above or beside the head — sharing the Mage's vertical quality but with a rounder, more grounded body shape.
- **Ranger** takes the Rogue's lean but extends it horizontally with a bow at full draw — the widest read after Warrior but in a different plane (weapon extended forward or sideways, not held inward).
- **Tactician** (command class) signals command through a deliberate stillness — upright, coat or tabard creating a squared-off lower silhouette, a pointing or raised arm giving a one-sided horizontal extension different from the Warrior's weapon read.

No two classes in the roster at any tier may share a primary silhouette shape. If a new class reads as "smaller Warrior" or "Mage with a sword," the class silhouette is redesigned before color work proceeds.

### Enemy Silhouette Philosophy

Enemies must signal threat-type and biome-type from silhouette alone, but they must never read as genuinely alarming. The cozy pillar is a hard constraint: a player opening the app during a lunch break must not feel a spike of stress at their enemy design.

The technique is deliberate stylization without menace. Large enemies are round or blocky, not angular and sharp. Insectoid or skeletal enemies use curves on their extensions rather than spike shapes. "Threatening" is expressed through scale relative to the hero sprites, not through edge sharpness. An enemy that is twice the hero's width reads as a challenge; an enemy with needle-sharp spines reads as hostile in a way that breaks the cozy register.

Enemy silhouettes must also communicate their class counter relationship. Armored enemies have silhouettes that favor Rogue counter reads (low openings, slow-rotating forms). Spellcasting enemies have visual apparatus — wand, staff, orb — that the Mage recognizes as a mirror threat. Physical bruisers telegraph to Warriors. This visual counter-legibility is a design requirement, not a decoration choice.

### Environment Geometry

Guild Hall geometry is rounded, nested, and slightly irregular — hand-built, not architect-designed. Doorframes are slightly off-square. Shelves are recessed into stone walls that aren't perfectly flat. This imperfection is intentional: it signals age, care, and personality. Curved arches, vaulted ceilings (implied by the top of the frame), and alcoves. Organic stonework with moss accents at joints.

Dungeon geometry is more geometric and repetitive — the dungeon was carved or constructed with intent, not grown. Stone tiles, repeating archways, predictable column spacing. But because the game must stay cozy, dungeons lean toward the ancient and mossy rather than the forbidding and sharp. The difference between Guild Hall and dungeon is "organic irregular" vs. "geometric aged," not "warm" vs. "cold and threatening."

Prop geometry follows the same rule: all hero-controlled objects (furniture, equipment racks, notice boards) have a slight handmade quality — beveled corners, asymmetric wear. Enemy-associated objects (dungeon traps, enemy camps) use more regular geometry with broken or crumbling edges. Shape communicates ownership.

### UI Shape Grammar

The UI operates as a distinct layer from the world art but is integrated thematically through the illuminated manuscript reference. The governing metaphor is: the interface is a guild ledger that has been decorated by someone who cares about it. Panels are parchment-textured with ink-drawn borders. Corners use rounded ink-flourish ornaments. Button shapes are slightly irregular trapezoids or rounded rectangles that look cut from parchment, not extruded from a design system.

The UI does not mimic world geometry directly — it is not trying to look like a stone wall or a dungeon floor. But it uses the same warmth logic: panels are warm-toned, borders are ink or gold, interactive elements pulse with the same lantern-gold that communicates progression. There is a clear visual hierarchy: world art lives in the back, the UI parchment layer sits in front of it, and reward/unlock moments break through both layers with particle and flare effects.

The shape grammar test: if a UI element reads as a generic mobile game interface when shown in isolation, it needs the illuminated-manuscript treatment applied — ink border, parchment fill, or ink-flourish ornament at corners.

### Visual Weight Distribution

Heroes are always the heaviest visual element in any scene they occupy. Enemy designs are slightly lower contrast against their background than heroes are against theirs — this communicates "your guild is the subject of this game."

UI elements that communicate player agency (assignment slots, recruit buttons) are in the same warm-anchor color range as hero sprites. UI elements that communicate state or information (floor counters, biome labels) are in cooler, lower-saturation tones. Gold is reserved for completion, acquisition, and progression moments — it draws the eye exactly when the game wants attention.

Backgrounds and environment props recede through the DoF blur. Environmental storytelling details (biome-indicating flora, enemy-type props) are present in the sharpest background layer but do not compete with the hero tier for attention.

---

## Section 4: Color System

### Primary Palette

The following seven colors form the complete semantic palette of Lantern Guild. All other colors used in the game are desaturated or value-shifted variations of these anchors — never additions to the palette.

| Name | Hex | Role | Semantic Meaning |
|---|---|---|---|
| Guild Amber | `#C8872A` | Primary world warm | Player-controlled territory; the guild itself; safety; the player's side of any split-palette screen |
| Lantern Gold | `#F2B83B` | Reward and progression highlight | Acquisition, unlocks, gold currency; the game's highest-attention color; used only at reward moments and on progression UI elements |
| Parchment Cream | `#EDE0C4` | UI ground, card backgrounds | Neutrality, information, legibility ground; the "listening" color — it holds other colors without competing |
| Dusk Purple | `#5B4A72` | Enemy territory, dungeon ambient | Challenge, the unknown, the space that belongs to the dungeon not the player; any element associated with risk or the enemy side |
| Moss Sage | `#7A8C5E` | Environmental accent, nature biomes | The world outside the guild; living things; biome identity for forest and surface environments |
| Ember Rust | `#A84C2F` | Danger indicator, enemy power | Escalating difficulty, enemy tier signals, the warning register (desaturated enough to stay within cozy palette but reads as "pay attention here") |
| Slate Ink | `#2C2838` | Typography, deep shadow, outline | All text rendering, sprite outlines, the darkest shadow tone; never pure black; always carries the purple temperature of the Dusk Purple family |

### Semantic Color Usage in Gameplay

*Lantern Gold* is the player's reward signal. It appears on: accumulated loot displays, level-up confirmations, class unlock reveals, currency icons, and the matchup "bonus" badge when a formation has an advantage. Players will learn to associate this gold with "something good happened." It must not appear on enemy elements, negative feedback, or neutral information.

*Guild Amber* grounds everything belonging to the player. Hero sprites carry amber in their lighting pass. Guild Hall props are amber-lit. The warm side of the Matchup Assignment screen is amber. It communicates: this is yours, you built this.

*Dusk Purple* communicates: this does not belong to you yet. Dungeon backgrounds are dusk-purple-graded. Enemy silhouettes are purple-tinted in their unlit areas. The locked dungeon floors use a purple overlay. When a formation has a matchup disadvantage, the penalty badge uses dusk purple. Players learn: purple means proceed with awareness.

*Ember Rust* escalates within the dusk-purple family to communicate active danger signals. Enemy high-tier indicators, the "difficulty spike" visual on floor select, incoming damage animations. It is never used for player-controlled elements. It is never bright red — always the desaturated, brownish version that reads as warning without triggering genuine stress.

*Moss Sage* is the forest and surface world. It appears in biome accents, environmental props belonging to living biomes (Forest Reach, the starting biome), and the edge highlights of nature-type enemy silhouettes.

*Parchment Cream* is the UI's foundation. Every panel, card, and information layer sits on this ground. It reads as warm without competing with Gold or Amber.

*Slate Ink* replaces black in all uses. Text, sprite outlines, deep shadows. The purple warmth of Slate Ink prevents any element from reading as cold or sterile.

### Per-Biome Color Rules

The five V1.0 biomes are:

**Forest Reach (MVP biome):** Dominant accent — Moss Sage with Guild Amber atmospheric lighting. Dungeon background palette: layered greens pulled toward sage and olive, never saturated emerald. Enemy coloration: organic browns, bark textures, poisonous accents in muted yellow-green (never neon). Lighting: filtered through canopy, creating amber-dappled pools in an otherwise cool-green environment. The forest is the friendliest dungeon — closest to the guild's warmth in palette temperature.

**Sunken Ruins:** Dominant accent — weathered ochre and Dusk Purple deepening toward blue-grey. Structures of pale stone overgrown with moss. Water reflections introduce cool grey-blue as the only cold color in the palette — desaturated and dark enough to stay within the cozy register. Lighting: shafts from broken ceilings, Lantern Gold pools from ancient sconces still burning. Enemy palette: pale, bleached, slightly translucent — spirits, constructs, animated stone.

**Ember Cavern:** Dominant accent — Ember Rust and deep charcoal, with Lantern Gold appearing as actual lava or bioluminescent crystal veins. This is the warmest dungeon — higher contrast than Forest Reach but still firmly amber-side. Enemy palette: fire-adjacent deep oranges and blacks; the one biome where enemies can carry warm colors, but the player's heroes must remain more amber than the enemy oranges to maintain team legibility.

**Thornwood Depths:** Dominant accent — Dusk Purple deepening toward blue-black, with Moss Sage accents now dried and dead (grey-green). The "deep forest" at night. Enemy palette: insectoid, fungi-lit with muted bioluminescence (pale lavender only — never electric). This is the game's darkest biome. The DoF blur on backgrounds deepens here, and the hero lighting hold their amber warmth more strongly, creating the maximum warm-vs-cool contrast ratio in the game.

**Arcane Spire:** Dominant accent — Parchment Cream and Lantern Gold as structural materials, Dusk Purple as magical energy. This is where the fantasy escalates — the spire was built by someone powerful. Enemy palette: crystalline structures, magical light sources in the dusk-purple family. The "final" V1.0 biome has the richest visual density but must still obey the no-pure-saturated-color rule. All magic is warm-gold or dusk-purple, never electric blue or green.

### UI Palette

The UI uses the Parchment Cream as its ground throughout all game states, with Slate Ink for typography and Guild Amber and Lantern Gold for interactive states (hover equivalent on PC, tap feedback on mobile). The UI palette does not shift by biome — the interface remains consistently warm and parchment-grounded regardless of which dungeon floor is visible behind it. This anchors the player in the guild register even during dungeon runs.

The only UI palette variation is a subtle warmth-increase on the Return-to-App screen, where the parchment elements briefly pick up a Lantern Gold color grade before resolving back to standard cream. This is a deliberate reward-state signal.

### Colorblind Safety

Three pairs in the primary palette require backup cues:

**Guild Amber vs Ember Rust (protanopia/deuteranopia):** These two can collapse to similar perceived values for ~8% of players. Backup cue: Guild Amber elements (player-controlled) carry a small shield or house icon marker in any UI context where the pair appears together. Ember Rust elements (danger/enemy tier) carry a small flame or upward-arrow icon. Shape and icon carry the distinction; color is secondary confirmation.

**Moss Sage vs Dusk Purple (tritanopia):** These can read as similar blue-grey values for tritanopic players. Backup cue: biome-indicating sage elements use a leaf or tree outline motif; dusk-purple dungeon elements use a door or portal shape motif. Biome selectors use both color and icon always.

**Lantern Gold vs Parchment Cream (low-contrast check):** At small sizes, these two can merge in low-vision scenarios. Backup cue: all Lantern Gold elements carry a Slate Ink outline at 1px minimum. Reward moment text is always Lantern Gold on Slate Ink ground, never on Parchment Cream, to ensure sufficient contrast ratio (minimum 4.5:1 per WCAG AA).

---

## Section 5: Character Design Direction

### Visual Archetype Style

Lantern Guild heroes are *warm-heroic with readable exaggeration* — not cute (avoids juvenile read that conflicts with the premium-game positioning), not grimly realistic (would destroy the cozy pillar), not painterly in a loose way (would conflict with the precision pixel-art identity). The north star is: "a hero you want in your roster, made with the same craft as the world they inhabit." Proportions are slightly exaggerated toward fantasy — heads approximately 1/5 of body height for portrait renders, giving enough face to read expression at card size. In-scene sprites are more stylized — closer to 1/4 head ratio for silhouette readability.

The exaggeration rule: every hero's defining visual element is slightly larger than anatomically correct. A Warrior's shield covers more of their left side than a historical shield would. A Mage's staff is slightly taller than their body height. A Rogue's hood is slightly deeper. These are visual emphasis decisions, not cartoon distortion. The goal is for the class-defining element to read immediately.

### Distinguishing Feature Rules Per Class

**Warrior** — Defining visual element is armor volume — specifically the shoulder pauldrons and shield combined. The shield should be the single largest geometric element in the silhouette. Color anchor: steel-grey with Guild Amber warmth applied through lit surfaces; no chrome or silver-white that would read as cold. Idle animation emphasis: the shield arm settles, the sword arm relaxes but remains ready. The Warrior's expression set: composed, watchful, capable. Never aggressive or angry — the Warrior is your protector, not your berserker.

**Mage** — Defining visual element is the staff finial (top ornament) — this single element should be unique per Mage variant and should be the first design decision for any Mage subclass. Staff finials carry the game's most expressive use of the dusk-purple magical register — the only place in the hero roster where purple is a primary color, because the Mage's magic is the player's tool even when it looks like the dungeon's color. Robes use the Parchment Cream family. Expression set: focused, curious, slightly apart-from-the-world. The Mage is not warm in personality — they are valuable.

**Rogue** — Defining visual element is the hood and the asymmetric arm. Hood should be deep enough to cast shadow across the upper half of the face at idle — mystery is built into the neutral pose. The off-hand dagger (reverse grip) creates a forearm silhouette that reads uniquely against both sword and staff. Color anchor: desaturated dark browns and deep blues in the Slate Ink family, with a single accent color (a lantern-amber clasp or a blade catching light) that connects them to the guild register. Expression set: knowing, still, measuring. The Rogue is watching; they're always already aware.

**Cleric** — Defining visual element is a raised luminous implement — lantern, censer, or holy symbol — positioned above and to the side of the head. This creates a vertical accent that rhymes with the Mage's staff read but differs through placement (off-axis, not centered) and through the implement's design language (round, warm, sacred rather than pointed, purple, arcane). Color anchor: warm whites and Guild Ambers — the Cleric's palette is the warmest on the roster, reinforcing their support role. Expression set: serene, open, generous.

**Ranger** — Defining visual element is the bow at the full extension of the draw arm — creating a horizontal reach that extends the hero's visual width beyond their body. Where the Warrior's width comes from armor mass, the Ranger's comes from active extension. Quiver positioned on the back creates a secondary vertical element behind the right shoulder. Color anchor: Moss Sage with leather browns, the most naturalistic palette on the roster. Expression set: patient, scanning, outdoor.

**Tactician (Command Class)** — Defining visual element is a large military map, folded orders, or commander's baton — a non-combat implement that signals coordination rather than direct force. Upright posture distinguishes them from the Rogue's lean and the Warrior's planted stance. Coat or tabard creates a squared lower silhouette unlike any other class. Color anchor: deep Parchment Cream and Guild Amber — the Tactician wears the guild's administrative colors; they are the bureaucracy of violence. Expression set: evaluating, directing, one step ahead.

### Enemy Type Visual Rules

Enemies follow a three-property rule: *biome material + scale signal + counter-class hint.* Every enemy must be designable from these three properties alone before any stylistic flourishes are added.

*Biome material* is the texture read — a Forest Reach enemy is bark, leaf, vine, fur; a Sunken Ruins enemy is cracked stone, lichen, spectral light; an Ember Cavern enemy is igneous rock, hot metal, ash. The material read tells the player instantly which dungeon this enemy belongs to.

*Scale signal* communicates difficulty tier. Enemies within a biome grow in sprite size across floor tiers — not dramatically, but each tier should be visibly larger than the previous. Small enemies (floor 1-2) fit within a single hero sprite height. Boss-tier enemies (floor 5) are approximately double the hero sprite in width.

*Counter-class hint* means the enemy's design must telegraph which hero class is effective against it, without a tutorial. Armored enemies have visible joint gaps that suggest the Rogue's precise strike. Spellcasting enemies mirror the Mage's visual apparatus — they carry a focus or perform a cast animation. High-health bruiser enemies invite the Warrior through sheer opposing mass.

### Expression and Pose Style

Hero sprites use *expressive-minimal* posing: full expression is held in the portrait tier; in-scene sprites carry simplified, exaggerated expression that reads at 32px. This is not stiff (idle animations are required, see below); it is legible. An in-scene sprite should communicate emotional state from across the screen. A happy sprite is visibly happier than a neutral one; a damaged sprite's posture changes visibly. The constraint is that expressiveness comes from pose and silhouette shift, not from facial detail (which cannot render at the in-scene resolution).

This choice is justified by Pillar 4 (HD-2D Pixel Pride) and Pillar 2 (Every Class Feels Distinct). Pose IS personality at small scale.

### LOD Philosophy (Portrait vs In-Scene)

Two rendering tiers, both pixel art but different detail and proportion conventions:

**Portrait tier** (used in Recruit screen, class detail, Victory unlock reveals): Full character from waist up or full body at approximately 96-128px height. Face readable, expression clear, class-defining element rendered in full detail. This is the showcase tier — the equivalent of a trading card illustration. It is the highest-quality pixel work in the game.

**In-scene tier** (used in dungeon runs, formation panel, idle animations in Guild Hall): Full body at 32-48px. Silhouette-first, exaggerated proportion, simplified face. The same character but rendered for instant recognition at distance. The in-scene sprite is NOT a downscale of the portrait — it is a separate design that optimizes for silhouette and animation readability.

Maintaining both tiers is non-negotiable for Pillar 2. A character that only exists at portrait detail fails the class-legibility test; a character that only exists at sprite resolution fails the HD-2D Pixel Pride test.

### Idle Animation Philosophy

Every hero must have a multi-phase idle animation in both portrait and in-scene tiers. This is a cozy-pillar requirement — a completely static hero sprite reads as unfinished, and a roster that doesn't breathe breaks the "alive miniature" quality.

**In-scene idle minimum:** a 4-8 frame cycle that includes at least one complete breath cycle (chest/torso displacement), one secondary motion unique to the class (Warrior's shield settle, Mage's staff light pulse, Rogue's cloak drift, Cleric's implement glow, Ranger's bow-arm micro-adjust, Tactician's document glance). Secondary motion is the class's personality expressed through habit.

**Portrait tier idle minimum:** a 6-12 frame cycle with subtler motion. The portrait hero breathes, blinks, and performs their secondary motion at half the speed of their in-scene sprite. Portrait idles are meditative, not restless.

No hero may reuse another hero's secondary idle motion. The secondary motion is as identity-defining as the silhouette.

---

## Section 6: Environment Design Language

### Architectural Style

The Guild Hall is an old building that has been continuously inhabited and incrementally improved. It predates the current guildmaster. The architecture is a fantasy vernacular that owes more to Northern European medieval guild halls than to high-fantasy castles — functional stone construction with accumulated wooden additions, warm textiles, trophy displays, and well-worn surfaces. The building has a history readable through its surfaces: stone walls at the base, timber framing visible in upper sections, stone floors worn smooth by decades of boots.

Dungeon architecture is older and more formal than the guild. Dungeons were built with intent — by cultures whose specific aesthetic each biome expresses. The Forest Reach dungeon is ancient woodland infrastructure (root-reinforced earthwork walls, carved stone markers grown over with moss). The Sunken Ruins are the remnants of an advanced but failed civilization (precise stone, decorative friezes now damaged, geometric tiling broken by time). The Ember Cavern is natural with adaptive construction (lava channels redirected through carved stone, heat-proof metal supports). The Thornwood Depths are organic architecture overtaken (what was once constructed has been consumed by root and fungus). The Arcane Spire is deliberately constructed by someone with power (stone that shouldn't be able to float, arranged in impossible geometries made stable by magic whose source is absent).

The design principle: the world has more history than the player will ever fully explore. Architecture signals that history without narrating it. Environmental storytelling happens through material and style, not through text.

### Texture Philosophy

All textures are pixel-art native — no photographic overlays, no vector-rendered smoothness on world art. The HD-2D treatment is applied as a post-process lighting and depth-of-field layer over pixel-art assets; the assets themselves must read as pixel art at 1:1 scale.

Within the pixel art convention: surfaces have visible tile boundaries that are designed to read as intentional (a stone wall tile that shows individual stones, not a uniform grey rectangle). Surface age is expressed through dithering patterns in darker crevices, not through alpha-channel overlays. Wear marks are painted into the sprite, not procedurally generated.

The tilt-shift DoF treatment should be designed with the asset artist aware of which depth layer their asset occupies: hero layer (sharp), hero-adjacent prop layer (sharp to slight softening), background environmental layer (moderate blur), distant background layer (strong blur, loses pixel grid readability). An asset's final in-game appearance includes the DoF pass — artists must not design purely for the asset's 1:1 pixel appearance.

### Prop Density Rules

Guild Hall is dense with props. The guild is a lived-in space and density communicates inhabitation. Trophy racks, notice boards, equipment storage, a hearth, a bar or commissary counter, character portraits on walls, a guild board with pinned parchments. The prop density should increase over time as a visual progression signal — a guild with 10 heroes has more trophies and more notice board activity than a guild with 3. Prop density communicates success. The rule: every new major milestone should have a prop counterpart visible in the Guild Hall view.

Dungeons are sparse. The dungeon floors are adventures, not homes. Enemy presence and environmental hazard are the dungeon's content, not prop decoration. A dungeon floor should have no more than 3-5 background props (a torch sconce, a broken pillar, a chest, a biome-specific material detail). The sparseness of dungeons makes the guild feel richer by contrast — this is the visual manifestation of the core emotional arc: dungeons are temporary; the guild is home.

This rule has a design payoff: when the player returns from a dungeon run to the Guild Hall, the visual shift from sparse to dense is itself a "homecoming" signal. The density contrast is a designed emotional beat.

### Environmental Storytelling

Each biome communicates its enemy types through props and materials before any enemy sprites appear. These are the player's biome-legibility cues — the visual system that lets formation matchup feel intuitive rather than tutorial-dependent.

**Forest Reach:** Claw marks on trees at knee height suggest animal-type enemies. Disturbed ground and overturned mushrooms suggest something large has been through. Webbing in upper corners suggests insect-type enemies in later floors.

**Sunken Ruins:** Torch sconces that burn without fuel suggest spectral enemies. Carved reliefs depicting armored warriors suggest animated construct enemies. Water-filled lower areas with displaced sediment suggest aquatic or submerged-type enemies.

**Ember Cavern:** Charred ground markings in circular patterns suggest fire-breath enemies. Claw-drag marks in hardened lava suggest heavy reptilian movement. Arranged stones in deliberate patterns suggest enemies with intelligence.

**Thornwood Depths:** Bioluminescent fungi patterns match enemy glowing accents, allowing players to identify enemy types from the fungi they grow near. Husked shells (things that were prey) indicate predator enemy types. Web-and-silk construction suggests enemies that enclose and constrict.

**Arcane Spire:** Magical residue patterns on floors (scorch shapes, crystal growth patterns) indicate the spell schools of enemies. Broken containment structures suggest enemies that were once prisoners. Intact magical machinery indicates enemies that maintain or operate it.

The storytelling rule: every biome must contain at least two environmental props that function as enemy-type telegraphs. These props must be readable to a player who has never seen the enemy — the prop tells the story first.

---

## Section 7: UI/HUD Visual Direction

### UX Constraints (Binding — Art Direction Must Accommodate)

These constraints come from the game's UX profile (session-based idle, touch-parity-from-MVP, no fail state). All visual direction below must satisfy these:

- **Legibility over atmosphere on reward panels.** The Return-to-App screen is where cozy games most commonly fail. If parchment texture or ink ornamentation obscures the accumulated-loot number, atmosphere yields.
- **Touch/mouse parity from MVP.** No hover-only state reveals any information. No right-click-only. No drag precision thresholds under 24 logical pixels.
- **Tap targets ≥44×44 logical pixels** on all interactive elements (cards, buttons, formation slots, hero tiles).
- **Font legibility floor**: body text minimum 16px logical size; identity/accent font minimum 24px logical size. Hand-lettered accent font is never used for body copy or stats.
- **Colorblind backup cues mandatory** for any UI element using a Section 4 palette pair flagged for colorblind risk. Icon or shape always accompanies color for matchup effectiveness, biome identity, and damage type.
- **Animation budget: ≤150ms for UI transitions** (except reward ceremonies, which may run up to 800ms). Reward-moment animation must reveal the primary number within the first 100ms even if the full ceremony continues after.
- **No idle animation demands attention.** Pulses, glows, and ambient motion on UI elements must be subtle enough that a player reading the screen is not pulled toward them involuntarily.

### Diegetic Framing Philosophy

The Lantern Guild UI operates as a *semi-diegetic layer* — it exists within the game world's logic but does not pretend to be fully embedded in 3D space. The governing metaphor is the guild ledger and notice board: the game's UI is documentation that the guildmaster themselves would produce and consult. Formation panels are roster sheets. Dungeon selectors are mission briefing documents. Loot summaries are accounting ledgers.

This framing decision serves the Visual Identity Anchor directly: the UI being "a warm document in a warm world" means even a fully-text screen with no world art behind it carries the diorama feel through the parchment texture, ink borders, and lantern-gold highlighting. The UI does not drop out of the game world when the world art is not visible.

What this means practically: all UI panels use the parchment texture as their background. Panels do not float on a flat-color backdrop; they sit on a darkened version of the current game state's world art, with the parchment panel rendered as a physical document placed in front of it. Closing a panel should feel like setting down a piece of paper, not closing a digital window.

### Typography Direction

Two fonts maximum for the entire game. One serves information; one serves identity.

**Information font** — A humanist sans-serif or semi-serif in the hand-lettered tradition — legible at small sizes, slightly irregular letterforms that read as handwritten without actually being illegible. Must support all Latin characters plus common Unicode punctuation for localization readiness. Primary use: all in-game statistics, descriptions, floor labels, hero names, numerical values. The key quality: it must read as something a person wrote, not something a computer generated, while remaining fully legible at 16px.

**Identity/accent font** — A display typeface in the illuminated manuscript tradition — used exclusively for section headers, unlock announcement titles, biome names, and the game's own title treatment. Used sparingly, only at sizes where its detail can read (minimum 24px). This font is the Pentiment DNA made explicit — ink-drawn letterforms with the slight variation of calligraphic tools. It is never used for body copy or stat labels. Every use of the identity font is a deliberate art direction decision, not a default.

**Weight hierarchy:** Guild Amber or Lantern Gold for primary labels and reward values; Slate Ink for all body copy, stats, and secondary labels; Parchment Cream reversed on Slate Ink ground for maximum contrast situations (Victory banners, major unlock titles).

### Iconography Style

Icons are *pixel-outlined with fill* — they share the visual language of the character sprites but simplified to 16×16 or 24×24 pixel canvases. Not flat vector icons (too modern, breaks the handmade register); not purely illustrated (inconsistent with the pixel-art identity of the world). The icon style rule: if an icon's outline were thickened and it were given depth, it should look like it could be a prop in the Guild Hall world.

**Currency icon (gold coin):** pixel circle with a lantern-gold fill and a Slate Ink G-rune or guild mark interior. Reflects the Lantern Gold semantic exactly.

**Class role icons:** directly derived from the character's defining visual element reduced to icon scale. The Warrior icon is a shield. The Mage icon is a staff finial. The Rogue icon is a reverse-grip dagger. The Cleric icon is a sacred light implement. The Ranger icon is a bow. The Tactician icon is a folded orders/map. Each icon must pass the 16px silhouette test the same way the character sprite does.

**Matchup effectiveness icons:** a three-state system. Advantage: Lantern Gold upward triangle with a class role icon inset. Neutral: Parchment Cream circle. Disadvantage: Dusk Purple downward triangle. Shape encodes the state (backup cue for colorblind safety); color reinforces it.

### Animation Feel for UI

UI animation is *stately with warm snappiness* — not bouncy (feels toy-like, under-premium), not purely mechanical (cold, app-like). The governing feel is: heavy objects settling into place. A panel opening should have a quick initial motion (75ms) followed by a slight overshoot and a very fast settle (25ms) — the motion of a book being placed on a table with care. Total animation duration for most UI transitions: under 150ms.

**Reward-moment animations** are the exception. Loot delivery, level-up confirmations, and class unlock reveals have longer ceremony durations (400-800ms) with multi-phase motion: an appearance, a hold, and a settle. These are the game's primary satisfying beats — their animation earns a longer budget. **The primary number must render within the first 100ms of the animation**, even if the ceremony continues after — see UX Constraints.

**Idle states on interactive UI elements:** subtle. A button awaiting press has a very slow (3-4 second cycle) warmth pulse in its Lantern Gold elements — like a coal glowing with breath. This communicates interactivity without demanding attention. The pulse is not a bounce; it is a temperature change.

**Touch feedback:** every tap produces an immediate visual response within one frame (16ms). The response is a scale pulse of approximately 1.05× for 80ms, followed by return to 1.0×. This must be felt on mobile before it is seen — the scale is small, but it is instant.

### Preserving "Warm Miniature" Feel Inside Menus

The risk in a menu-heavy idle game is that players spend more time reading interfaces than looking at world art, and interfaces have historically been where the cozy feel evaporates into functional utility. The following techniques are required, not optional, for any full-screen menu that obscures the world view entirely.

**Parchment texture with depth:** The UI background is never a flat color — it is always the parchment texture with at minimum a warm vignette darkening at the corners. The texture should be subtle at game scale but present at any zoom level.

**Ink flourish ornaments:** Every panel corner uses a simple ink-drawn ornament — a vine curl, a geometric interlace, a compass-star — rendered in Slate Ink at low opacity over the parchment. These are 1-4 pixel-art elements, not vector imports. The ornaments communicate care without consuming attention.

**Lantern-underlit background:** On any full-screen panel, the parchment sits above a darkened, blurred version of the current world art — not the game's full render, but a static pre-rendered plate that communicates "you are still in the guild." The plate is blurred to 60-70% opacity and desaturated by 30%. The world persists behind the ledger.

**Warm type on warm ground:** Even in a dense information screen (roster list, skill description), no text renders on a cold-white or pure-black ground. The coldest background a text element can use is the Slate Ink color, and it warms its text with Parchment Cream. The "clinical" feeling that pure white text fields create is specifically forbidden.

**The test for any menu screen:** take a screenshot and show it to someone unfamiliar with the game. They should be able to say "this is a fantasy game, probably cozy" from the menu alone. If they say "this looks like a spreadsheet," the parchment and ink-flourish treatment has been under-applied. If they say "I can't read it quickly," the treatment has been over-applied.

---

## Section 8: Asset Standards

### 8.1 Governing Principles

These standards are binding on every asset that enters the repository. They are not aspirational — a story that produces an asset is not Done until the asset satisfies the requirements in this section. The standards are written for two simultaneous realities: the desktop Forward+ renderer running at 1920×1080 on day one, and a mobile port that must ship from the same asset tree without an art rebuild.

Every rule in this section has a reason. Where a rule requires a tradeoff, that tradeoff is made explicit.

### 8.2 File Format Standards

#### 8.2.1 Per-Category Format Table

| Asset Category | Delivery Format | Bit Depth | Color Profile | Lossless? | Notes |
|---|---|---|---|---|---|
| Hero sprites (all frames) | PNG-32 | 8 bits/channel | sRGB | Yes | Full alpha required; never indexed PNG |
| Enemy sprites (all frames) | PNG-32 | 8 bits/channel | sRGB | Yes | Same as hero |
| Dungeon backgrounds (painterly layer) | PNG-24 | 8 bits/channel | sRGB | Yes | No alpha needed; opaque base layer |
| Background depth-matte layers | PNG-32 | 8 bits/channel | sRGB | Yes | Alpha used for foreground occlusion compositing |
| UI icons (≤64×64) | PNG-32 | 8 bits/channel | sRGB | Yes | No WebP — Godot atlas packer needs consistent format |
| UI portraits (≤256×256) | PNG-32 | 8 bits/channel | sRGB | Yes | Must round-trip losslessly through SpriteFrames |
| FX / particle sprite sheets | PNG-32 | 8 bits/channel | sRGB | Yes | Additive-blend FX require premultiplied alpha |
| Fonts — body | TTF or OTF | N/A | N/A | N/A | Vector; imported as DynamicFont in Godot |
| Fonts — hand-lettered accent | TTF or OTF | N/A | N/A | N/A | Bitmap fallback allowed if < 5 glyphs needed |

**WebP is prohibited** for sprite assets in this project. Godot 4.x can import WebP, but the format introduces lossy ringing artifacts at hard pixel edges — exactly the wrong artifact type for pixel art. It is acceptable only for non-pixel decorative backgrounds that are never atlased.

**SVG is prohibited** for game-facing art assets. Godot rasterizes SVG at import time; the rasterization is not pixel-crisp. SVG is permitted only for design mockups and internal documentation figures.

#### 8.2.2 sRGB vs Linear — Godot 4.6 Specifics

Godot 4.6 with the Forward+ renderer operates in linear color space internally. The import system handles the conversion.

- All color textures (sprites, backgrounds, portraits, UI icons) **must be tagged sRGB at import** (`srgb: true` in the `.import` file). Godot will convert to linear at load time.
- FX textures used purely for opacity/alpha masks (not color) should be imported as **linear** (`srgb: false`) to avoid double-gamma correction on a non-color channel.
- Normal maps, if ever introduced, are always **linear** (`srgb: false`). Not used in MVP.
- Source PNG files saved by artists should be in sRGB color space (standard Aseprite/Photoshop default).

> **Godot 4.4+ note:** Shader texture uniform types changed from `Texture2D` to `Texture` base type. If the lantern-lighting shader samples sprite textures as uniforms, declare them as `uniform sampler2D` in `.gdshader` files. Verify against `/docs/engine-reference/godot/breaking-changes.md` before authoring shader code.

#### 8.2.3 Premultiplied Alpha for Additive FX

Particle textures used with additive or screen blend modes — lantern motes, unlock sparkles, damage glow — must be exported with **premultiplied alpha** from Aseprite or Photoshop. Non-premultiplied additive sprites produce a dark-fringe artifact at sprite edges against bright backgrounds. Aseprite: File → Export → check "Premultiply Alpha". In Godot, set the sprite's `CanvasItem` material blend mode to `Add` or `Screen`; premultiplied alpha is not a Godot import setting, it is a source-file property.

### 8.3 Resolution Tiers and Pixel Scale

#### 8.3.1 Foundational Scale Rule

The HD-2D look is achieved by rendering pixel sprites at an integer-scaled "game resolution" composited over high-resolution painterly backgrounds. This project uses a **3× pixel scale multiplier**:

- Base sprite resolution = the pixel dimensions of the source art
- Game viewport renders at 480×270 (16:9, pixel grid) — equivalent to a 3× upscale of the "pixel art world" at 1280×720 target
- Godot renders this viewport via a `SubViewport` with `CanvasItem` stretch mode, upscaled 3× to fill the window

At 1280×800 (Steam Deck), the 480×270 viewport fills the screen at 2.96× — close enough to 3× that no visible interpolation artifact appears with nearest-neighbor scaling.

This means sprite dimensions below refer to **source art pixel counts** — the pixel dimensions you draw in Aseprite. On-screen these appear 3× larger.

#### 8.3.2 Sprite Resolution Table

| Asset Category | Source Resolution | Animated? | Typical Frame Count | On-Screen Size at 3× |
|---|---|---|---|---|
| Hero — idle | 32×48 px | Yes | 4–6 frames | 96×144 screen px |
| Hero — attack | 32×48 px | Yes | 6–8 frames | 96×144 screen px |
| Hero — portrait (roster card) | 48×48 px | No | 1 | 144×144 screen px |
| Hero — portrait (detail view) | 96×96 px | No | 1 | — (displayed at native, not 3×) |
| Enemy — idle | 32×32 px (small), 48×48 px (large) | Yes | 4–6 frames | 96×96 / 144×144 |
| Enemy — attack | Same as idle frame size | Yes | 4–8 frames | Same |
| Enemy — death | Same as idle frame size | Yes | 6–10 frames | Same |
| Dungeon background (base layer) | 480×270 px painterly | No | 1 | Full viewport |
| Dungeon bg depth-matte layer | 480×270 px | No | 1–2 (static or subtle loop) | Full viewport |
| UI icon (class / resource / stat) | 16×16 px | No | 1 | 48×48 screen px at 3× |
| UI icon (biome / dungeon card) | 32×32 px | No | 1 | 96×96 screen px at 3× |
| FX / particle sprite | 16×16 px typical | Yes (sprite sheet) | 4–8 | variable (world-space) |
| Damage number glyphs | Part of font / bitmap | N/A | N/A | Rendered via Label/font |

#### 8.3.3 Hero Detail Portrait — Why Two Tiers

The roster card portrait (48×48 source) is drawn for the 3× pipeline — it reads clearly in the idle-clicker card list. The detail view portrait (96×96 source) is displayed when a player taps a hero for the close-up panel; it is rendered at 1:1 (no scaling) to reveal brush/pixel detail. These are two distinct art deliverables — they share composition and palette but are drawn independently. Do not try to upscale the 48×48 and call it the detail portrait.

#### 8.3.4 Background Resolution — Mobile Memory Tradeoff

Dungeon backgrounds are the largest single textures in the game. The painterly style means high detail at 480×270 with warm-light texture.

| Configuration | Background Delivery | Memory per Background | Notes |
|---|---|---|---|
| Desktop (MVP) | 480×270 base + up to 3 depth-matte layers | ~0.5 MB per layer (RGBA8) | Separate layers enable shader-composited tilt-shift blur |
| Mobile post-launch | 960×540 combined bake (pre-composited) | ~2 MB per scene, 1 texture | Layers are pre-baked offline; mobile loads one texture |
| Steam Deck | Same as Desktop | Same as Desktop | Steam Deck RAM is not a constraint vs 256 MB mobile ceiling |

The mobile combined bake is produced by the art pipeline tool, not by artists. Artists deliver the layered desktop originals; the pipeline bakes the mobile variant. **Artists never hand-author the mobile bake** — this prevents drift between tiers.

> Calculation: 480×270 RGBA8 = 480 × 270 × 4 bytes = 518,400 bytes ≈ 0.5 MB per layer. Three layers per scene = ~1.5 MB. MVP has 5 dungeon floors, 1 biome = ~7.5 MB for all dungeon backgrounds at desktop quality. Well within the 512 MB ceiling.

### 8.4 Naming Conventions

#### 8.4.1 Directory Structure Under `assets/`

```
assets/
├── art/
│   ├── heroes/
│   │   ├── warrior/
│   │   │   ├── hero_warrior_idle.png          # sprite sheet
│   │   │   ├── hero_warrior_attack.png
│   │   │   ├── hero_warrior_portrait_sm.png   # 48×48 roster card portrait
│   │   │   └── hero_warrior_portrait_lg.png   # 96×96 detail portrait
│   │   └── [class-slug]/
│   ├── enemies/
│   │   ├── floor_slime/
│   │   │   ├── enemy_floor_slime_idle.png
│   │   │   ├── enemy_floor_slime_attack.png
│   │   │   └── enemy_floor_slime_death.png
│   │   └── [enemy-slug]/
│   ├── backgrounds/
│   │   ├── biome_dungeon_b1/
│   │   │   ├── bg_dungeon_b1_base.png         # painterly base layer
│   │   │   ├── bg_dungeon_b1_depth_near.png   # depth-matte near plane
│   │   │   └── bg_dungeon_b1_depth_far.png    # depth-matte far plane
│   │   └── [biome-slug]/
│   └── ui/
│       ├── icons/
│       │   ├── ui_icon_gold.png
│       │   ├── ui_icon_class_warrior.png
│       │   ├── ui_icon_biome_dungeon.png
│       │   └── ui_badge_stat_atk.png
│       └── portraits/
│           └── (mirrors heroes/ portrait files)
├── vfx/
│   ├── particles/
│   │   ├── vfx_lantern_mote_sheet.png         # sprite sheet, 4 frames, 16×16 each
│   │   ├── vfx_unlock_sparkle_sheet.png
│   │   └── vfx_damage_hit_flash.png
│   └── shaders/                               # see assets/shaders/
├── shaders/
│   ├── lantern_overlay.gdshader
│   ├── tilt_shift_blur.gdshader
│   └── color_grade.gdshader
└── fonts/
    ├── body_font.ttf
    └── accent_font.ttf
```

#### 8.4.2 Filename Patterns

All filenames are snake_case. No spaces, no CamelCase, no hyphens.

| Asset Type | Pattern | Example |
|---|---|---|
| Hero sprite sheet | `hero_[class]_[anim].png` | `hero_warrior_idle.png` |
| Hero portrait small | `hero_[class]_portrait_sm.png` | `hero_rogue_portrait_sm.png` |
| Hero portrait large | `hero_[class]_portrait_lg.png` | `hero_mage_portrait_lg.png` |
| Enemy sprite sheet | `enemy_[slug]_[anim].png` | `enemy_cave_bat_death.png` |
| Background base | `bg_[biome]_[floor]_base.png` | `bg_dungeon_b2_base.png` |
| Background depth layer | `bg_[biome]_[floor]_depth_[near\|far].png` | `bg_dungeon_b2_depth_near.png` |
| UI icon (generic) | `ui_icon_[item].png` | `ui_icon_gold.png` |
| UI icon (class) | `ui_icon_class_[class].png` | `ui_icon_class_cleric.png` |
| UI icon (biome) | `ui_icon_biome_[biome].png` | `ui_icon_biome_forest.png` |
| UI stat badge | `ui_badge_stat_[stat].png` | `ui_badge_stat_def.png` |
| VFX sheet | `vfx_[effect]_sheet.png` | `vfx_lantern_mote_sheet.png` |
| Shader file | `[effect_name].gdshader` | `tilt_shift_blur.gdshader` |
| Font — body | `body_font.[ttf\|otf]` | `body_font.ttf` |
| Font — accent | `accent_font.[ttf\|otf]` | `accent_font.ttf` |

#### 8.4.3 Animation Frame Naming

This project uses **Godot `AnimatedSprite2D` + `SpriteFrames` resource** for all animated sprites. Frames are not individually named files in the repository; instead, each animation is a single horizontal sprite sheet PNG, and SpriteFrames slices it at import time.

Sprite sheet layout rules:
- All frames for a single animation on **one horizontal row**
- Frame size is uniform across the row (no variable-width packing)
- Frame count encoded in the SpriteFrames resource, not the filename
- Example: `hero_warrior_idle.png` = 4 frames of 32×48 = 128×48 px source image

The SpriteFrames resource for each hero lives at:

```
assets/art/heroes/[class]/[Class]SpriteFrames.tres
```

Example: `assets/art/heroes/warrior/WarriorSpriteFrames.tres`

Animation names within SpriteFrames use snake_case: `idle`, `attack`, `death`, `hurt`.

### 8.5 Import Settings

#### 8.5.1 Pixel Art Import Defaults — Required Settings

Godot's default import settings are wrong for pixel art. Every sprite in this project must override these:

| Setting | Required Value | Why |
|---|---|---|
| `filter` | `Nearest` (no filter) | Linear filter blurs pixel edges — always wrong for pixel art |
| `mipmaps/generate` | `false` | Mipmaps blur sprites when downscaled; pixel art should never downsample in-scene |
| `compress/mode` | `Lossless` | Preserves pixel-exact colors; lossy compression introduces banding on flat-color sprites |
| `process/fix_alpha_border` | `true` | Prevents dark halos on transparent pixel edges |
| `process/premult_alpha` | `false` for normal sprites; `true` for additive FX sprites | See Section 8.2.3 |
| `process/hdr_as_srgb` | `false` | Not applicable for 8-bit PNG |
| `process/size_limit` | `0` (no limit) | Never let Godot silently resize a source sprite |
| `srgb` | `true` for color textures; `false` for alpha-mask-only textures | See Section 8.2.2 |
| `detect_3d/compress_to` | `disabled` | Godot will try to auto-detect 3D textures; sprites are never 3D |

#### 8.5.2 Import Preset Strategy

**Commit all `.import` files to version control.** This is non-negotiable.

Rationale: Godot regenerates `.import` files from project defaults on re-import if they are absent. Project defaults are bilinear-filtered and mipmap-enabled — exactly wrong for pixel art. Without committed import files, any contributor (or CI) who runs a clean import will silently destroy pixel fidelity on every sprite in the game. The `.import` files are not build artifacts; they are configuration.

`.gitignore` must not include `*.import`. Verify the project `.gitignore` does not inadvertently include this pattern (common "Godot .gitignore" templates sometimes do).

#### 8.5.3 Per-Category Import Preset Names

Create these presets in `Project → Import Presets` and assign them by directory:

| Preset Name | Applies To | Key Overrides vs Default |
|---|---|---|
| `pixel_sprite` | `assets/art/heroes/`, `assets/art/enemies/` | `filter=Nearest`, `mipmaps=false`, `compress=Lossless`, `srgb=true`, `fix_alpha_border=true` |
| `pixel_background` | `assets/art/backgrounds/` | Same as `pixel_sprite`; `process/premult_alpha=false` |
| `pixel_ui` | `assets/art/ui/` | Same as `pixel_sprite`; do not set `fix_alpha_border` on icons that intentionally have no padding |
| `vfx_additive` | `assets/vfx/particles/` | `filter=Nearest`, `mipmaps=false`, `compress=Lossless`, `srgb=true`, `premult_alpha=true` |
| `font_body` | `assets/fonts/body_font.*` | Godot DynamicFont; no special override |
| `font_accent` | `assets/fonts/accent_font.*` | Same as `font_body` |

### 8.6 Texture Atlas Plan

#### 8.6.1 AtlasTexture vs Sprite Sheets — Godot 4.6 Decision

This project uses **horizontal sprite sheets per animation** (see Section 8.4.3), not Godot's `AtlasTexture` resource for sprite packing.

Rationale:
- `AtlasTexture` packs multiple unrelated sprites into one texture to reduce draw calls via batching. For an idle clicker with < 200 draw call budget, batching pressure is low in MVP.
- Sprite sheets per animation are simpler to author, simpler to hand-off between art and code, and map directly to Godot's `SpriteFrames.add_frame()` API which expects a source texture + region rect.
- Atlas packing becomes valuable when the same sprites are drawn many times per frame (e.g., 100-instance particle systems). Hero and enemy sprites are drawn at most a handful of times per frame.

**Revisit for V1.0** if draw call count approaches 150+ per frame and profiling shows batching gain from a packed atlas.

#### 8.6.2 UI Icon Atlas — Exception

UI icons are the one category where atlasing is appropriate from MVP. There are ~20–40 small icons (16×16 and 32×32), drawn repeatedly in the roster panel and dungeon card grid. Pack all UI icons into a single `ui_icons_atlas.png` (max 256×256 source, 512×512 at 4× scale if needed). Reference individual icons via `AtlasTexture` sub-resources.

### 8.7 LOD Philosophy

#### 8.7.1 Pixel Art Has No Traditional LOD

2D pixel sprites do not benefit from polygon-reduction LOD. What this project does have is **resolution and layer LOD** based on platform and scene complexity.

| LOD Tier | Platform | Hero/Enemy Sprites | Backgrounds | Particle Systems |
|---|---|---|---|---|
| High (default PC) | Desktop, Steam Deck | Full sprite sheet, all anims loaded | 3-layer composited (base + 2 depth mattes) | Full particle count |
| Low (mobile post-launch) | iOS/Android | Same sprite sheets (no change) | Single pre-baked combined texture | Reduced particle count (50% cap) |
| Background (battery-saver) | Mobile, backgrounded | Animations paused | No change | All particle systems paused |

Sprites are identical across platform tiers — the memory delta comes entirely from background layer count and particle system activity.

#### 8.7.2 Portrait Two-Tier LOD

- `_sm` (48×48): loaded always, used in all roster cards and formation slots
- `_lg` (96×96): loaded on demand when the player opens the hero detail panel; freed when the panel closes

The `_lg` portrait must be loaded via `ResourceLoader.load_threaded_request()` to avoid a frame hitch on panel open. It is never preloaded in the scene tree.

### 8.8 Shader and Material Standards

#### 8.8.1 The HD-2D Visual Pass

The "Lantern-Lit Pixel Diorama" look requires three visual effects:

1. **Tilt-shift vertical blur** — soft blur on the near and far background depth-matte layers, sharpest at the hero plane
2. **Warm-light overlay blend** — a radial gradient lantern-light texture composited over the scene in Screen or Add blend mode
3. **Color grade** — mild contrast lift and warm push (amber-shift) applied globally

These are **scene-level post-processing effects**, not per-sprite materials.

#### 8.8.2 Where the Shaders Live — Godot 4.6 Architecture

The HD-2D visual pass is implemented via Godot's **`Compositor` + `CompositorEffect` system** introduced in Godot 4.3.

```
WorldEnvironment
└── Compositor
    ├── CompositorEffect: TiltShiftBlurEffect    (tilt_shift_blur.gdshader)
    ├── CompositorEffect: LanternOverlayEffect   (lantern_overlay.gdshader)
    └── CompositorEffect: ColorGradeEffect       (color_grade.gdshader)
```

> **Godot 4.6 rendering note:** Glow now processes before tonemapping with screen blending mode (changed in 4.6 from post-tonemapping). If the lantern overlay is implemented using WorldEnvironment glow rather than a bespoke CompositorEffect, the intensity must be re-tuned. Prefer the explicit `CompositorEffect` path for predictable behavior across versions.

#### 8.8.3 Per-Sprite vs Scene-Level Shaders — The Rule

**Scene-level CompositorEffect only for HD-2D pass. Per-sprite shaders are prohibited for the visual identity pass.**

Per-sprite shaders (assigning a `ShaderMaterial` to individual `AnimatedSprite2D` nodes) have a direct draw call cost: each unique material breaks sprite batching. At 10 heroes + 8 enemies on screen, per-sprite shaders would fragment the batching into dozens of separate draw calls.

The single exception: a hero **hurt-flash** shader (`hero_hurt_flash.gdshader`) that desaturates or tints a sprite white on damage hit is acceptable as a per-sprite material because it is brief (2–4 frames), applied to at most one sprite at a time, and has no scene-level equivalent.

#### 8.8.4 Shader File Standards

- All shaders live in `assets/shaders/`
- File extension: `.gdshader` (Godot 4.x uses `.gdshader`, not `.shader`)
- Each shader file must include a header comment block:

```glsl
// Shader: tilt_shift_blur.gdshader
// Category: HD-2D post-process
// Pass: CompositorEffect — applied to full viewport
// Parameters:
//   blur_strength: float (0.0–8.0) — gaussian kernel width in pixels
//   focus_y_center: float (0.0–1.0) — normalized Y position of sharpest plane
//   focus_band_width: float (0.0–1.0) — proportion of viewport that stays sharp
// Mobile: YES — Forward+ with SMAA disabled on mobile
// Performance: ~0.3ms on desktop, ~0.8ms on Mali-G77 class GPU
```

- Shader parameters are the art director's tuning knobs — expose them as `uniform` values; never hardcode artistic constants inside shader math
- All shader uniforms exposed as exported variables in their GDScript `CompositorEffect` class

### 8.9 Performance Budgets and Hard Constraints

#### 8.9.1 Texture Memory Budget

Target: all textures loaded in a single dungeon scene stay within **64 MB** on desktop and **32 MB** on mobile.

Calculation method:

```
memory_bytes = sum(width × height × bytes_per_pixel for each loaded texture)
bytes_per_pixel: RGBA8 = 4, RGB8 = 3, compressed (ETC2/BC) = 0.5–1
```

| Asset Set | Estimated Memory (RGBA8 uncompressed) |
|---|---|
| 3 hero sprite sheets (128×48 × 4 frames avg) | ~0.07 MB |
| 8 enemy sprite sheets (128×32 × 4 frames avg) | ~0.05 MB |
| Desktop: 3 background layers at 480×270 | ~1.5 MB |
| Mobile: 1 combined background at 960×540 | ~2.0 MB |
| UI icons atlas (256×256) | ~0.25 MB |
| VFX sprite sheets × 4 | ~0.02 MB |
| **Total MVP scene estimate (desktop)** | **~2.0 MB** |
| **Total MVP scene estimate (mobile)** | **~2.4 MB** |

MVP is well under budget. The 32 MB mobile ceiling exists to absorb V1.0 expansion (5 biomes, 20 classes) without a memory architecture rethink.

#### 8.9.2 Draw Call Limits

Project budget: **< 200 draw calls per frame** (from technical-preferences.md). Practical target for an idle game: < 80 per frame.

| Element | Expected Draw Calls |
|---|---|
| Background layers (3 layers) | 3 |
| Hero sprites (up to 5 heroes visible) | 1–5 (batch-eligible) |
| Enemy sprites (up to 8 visible) | 1–8 (batch-eligible) |
| UI (HUD, roster cards, icons) | ~20–40 |
| CompositorEffect passes (3) | 3 |
| Particle systems | 1–4 |
| **Total estimate** | **~30–65** |

#### 8.9.3 Particle Count Limits

| FX Type | Max Concurrent Particles |
|---|---|
| Lantern ambient motes (background) | 40 |
| Unlock sparkle burst | 60 (one-shot; freed after 2s) |
| Damage hit flash | 20 (per-hit; < 0.5s) |
| Loot collection burst | 30 (per-collection tap) |
| **Total concurrent (worst case)** | **150** |
| **Mobile cap** | **75 (50% reduction)** |

All `GPUParticles2D` nodes must have `emitting = false` when not in use and `one_shot = true` for burst effects. Do not leave continuous emitters running off-screen.

#### 8.9.4 Sprite and Mesh Constraints

- **No nine-patch sprites over 256×256 source** — NinePatches force a draw call split
- **No texture repeat on non-power-of-two textures** — if a shader uses `hint_repeat`, texture dimensions must be power-of-two (64, 128, 256, 512)
- **GPUParticles2D mesh**: if a particle system uses a custom mesh, max 16 vertices

#### 8.9.5 Material Slot Practical Limits

- Heroes and enemies: **zero** assigned `ShaderMaterial` in normal gameplay, except `hero_hurt_flash.gdshader` on hit
- Backgrounds: **zero** assigned shader material — tilt-shift is applied at the Compositor level
- UI nodes: **zero** shader materials. All UI visual styling through `StyleBox` and `Theme` resources

### 8.10 Known Tradeoffs and Post-Launch Upgrade Path

| Tradeoff | Art Director Ideal | MVP Ship Decision | Revisit Trigger |
|---|---|---|---|
| **Lighting granularity** | Per-sprite dynamic lighting | Scene-level warm-light overlay via CompositorEffect only | Post-launch PC enhancement pass; mobile never gets per-sprite lighting |
| **Background fidelity on mobile** | Fully layered 3-plane composited backgrounds | Pre-baked single-texture composite | V2.0 if mobile hardware tier improves |
| **Background parallax** | Subtle hero-plane parallax on scroll | No parallax (conflicts with "depth via blur, not parallax" rule) | Out of scope by design |
| **Anti-aliasing on pixel sprites** | Perfectly crisp at all scales | SMAA 1x enabled on desktop (Godot 4.5+); nearest-neighbor scaling on mobile | Validate SMAA availability in Godot 4.6 Project Settings |
| **Shader Baker** | All shaders pre-compiled (Godot 4.5+) | Enable Shader Baker for 3 CompositorEffect shaders | Verify on by default in 4.6 |
| **Portrait hand-paint quality** | Fully hand-illustrated portraits at 256×256+ | 96×96 pixel-art detail view; 48×48 roster | V1.0 art pass: add 256×256 illustrated portrait tier |
| **Font rendering** | Hinted, kerned, full Unicode body font | Two fonts, Latin character set only in MVP | Localization pass post-V1.0 |

### 8.11 Asset Review Checklist

Every asset story must pass this checklist before the pull request merges:

**Format and file**
- [ ] PNG-32 (or TTF/OTF for fonts), no WebP, no SVG
- [ ] Color profile: sRGB in source file
- [ ] No indexed PNG, no 16-bit PNG
- [ ] Premultiplied alpha only on additive FX sprites

**Resolution and scale**
- [ ] Source dimensions match the resolution table in Section 8.3.2
- [ ] Sprite sheet frame count matches SpriteFrames resource configuration
- [ ] Detail portrait (`_lg`) delivered if a new hero class is being merged

**Naming**
- [ ] Filename is snake_case, matches pattern in Section 8.4.2
- [ ] File placed in correct directory per Section 8.4.1
- [ ] SpriteFrames `.tres` file placed alongside sprites in class folder

**Import settings**
- [ ] `.import` file committed alongside the PNG
- [ ] Correct preset applied (pixel_sprite / pixel_background / pixel_ui / vfx_additive)
- [ ] `filter = Nearest` confirmed in `.import` file
- [ ] `mipmaps/generate = false` confirmed

**Memory**
- [ ] Scene texture memory sum recalculated after adding the asset
- [ ] Still within 64 MB desktop / 32 MB mobile ceiling

**Shader / material**
- [ ] No new `ShaderMaterial` assigned to sprite nodes (unless `hero_hurt_flash.gdshader`)
- [ ] Any new `.gdshader` file includes the required header comment block

---

## Section 9: Reference Direction

### Reference 1: Octopath Traveler (Square Enix, 2018)

*What to take specifically:* The per-character lighting pass on sprites — Octopath applies a distinct directional light to each character sprite so that characters feel illuminated by their environment rather than self-lit. In Lantern Guild, this means every in-scene hero sprite receives a lighting overlay that shifts by game state (warmer in Guild Hall, cooler in dungeon). Also take: the pixel-art layering approach where foreground objects are crisply rendered and background elements degrade through blur into painterly softness — the exact technical basis of the "diorama" feel.

*What to explicitly avoid:* The overworld map aesthetic (top-down travel map with isolated character sprites) does not apply to Lantern Guild's screens. Do not reference Octopath's color palette directly — Octopath uses cool blue-whites as dominant contrast colors; Lantern Guild replaces all of these with warm ambers and purples. The "JRPG town" visual density of NPCs and readable world details is out of scope — our Guild Hall is curated, not populated.

### Reference 2: Pentiment (Obsidian, 2022)

*What to take specifically:* The manuscript-page UI approach — every interface element reads as something drawn on a physical document with ink and pigment. Take the specific technique of using hand-lettered running ornaments and marginal illustrations at the edges of information panels: small ink drawings that relate to the content without directly labeling it. Also take: Pentiment's text animation, where words appear as if being written in real time. This can be selectively applied to unlock announcement titles and biome introduction cards in Lantern Guild.

*What to explicitly avoid:* Pentiment's color is deliberately muted and historical — ochre, sepia, parchment with very limited color. Lantern Guild uses Pentiment's document language but applies it to a warmer, more saturated palette with full Lantern Gold highlights. Do not mute the palette to match Pentiment's historical register. Also avoid: Pentiment's monochrome character designs — Lantern Guild heroes are in full color.

### Reference 3: Studio Ghibli Interior Lighting (Howl's Moving Castle, Spirited Away — interior scenes)

*What to take specifically:* The specific quality of lamp-lit interiors where warm orange light competes with cool exterior light and the warm source wins. In Howl's Moving Castle, the Witch's Sitting Room and Sophie's workroom use this split — interior warmth vs exterior cold — as a constant visual grammar. Take the specific color relationships: warm amber on near surfaces, cool grey-purple on shadowed areas, warm-lit characters in a cool environment. Also take: the visual weight given to functional objects in Ghibli interiors — pots, jars, tools, books as world-building through prop design, not through text.

*What to explicitly avoid:* Ghibli's animation fluidity is not achievable in pixel art at indie scope, and attempting it will result in uncanny valley pixel-art that does not read as either style cleanly. The reference is for lighting philosophy and color temperature design, not for animation technique. Do not attempt Ghibli-style hair or fabric motion physics.

### Reference 4: Tabletop Miniature Photography (Games Workshop, Warhammer Fantasy)

*What to take specifically:* The composition discipline of shallow depth-of-field photography as applied to small-scale painted objects — specifically, the technique of shooting miniatures at eye-level rather than from above, which creates a "character standing in their world" quality rather than a "game board viewed from above" quality. This eye-level perspective is the correct camera framing for all Lantern Guild dungeon and guild hall views. Also take: the way miniature photographers light their subjects with a key light from above-front and a warm fill from below-back, creating a sense of physical presence that flat 2D lighting does not achieve. The sprite lighting pass should simulate this: top-front sharp lighting, warm underlight fill.

*What to explicitly avoid:* The grim-dark color palette of many Warhammer miniatures — dark greens, dirty browns, blood reds, cold blacks. This reference is purely compositional and lighting-technical. Lantern Guild has nothing in common with the Warhammer aesthetic register and any dark or military color reference from this source should be explicitly discarded.

### Reference 5: Hollow Knight — Environment Art (Team Cherry, 2017)

*What to take specifically:* The technique of using environmental silhouette layering — distinct background planes at different levels of detail and value — to create depth in a 2D game world without parallax. Hollow Knight achieves extraordinary spatial depth through value contrast between planes, not through motion. In Lantern Guild, take this layering discipline: the dungeon backgrounds should have 3-4 distinct value planes, each slightly lighter/more detailed than the last as they recede, before the DoF blur pass is applied. The blur is more effective when the underlying art already has value separation.

*What to explicitly avoid:* Hollow Knight's emotional register is melancholic, vast, and lonely — the opposite of the cozy-intimate target. Do not reference Hollow Knight's subject matter, palette (its signature blacks and desaturated purples are cold, not warm), enemy design aesthetic (angular, chitinous, tragic), or atmosphere. The reference is purely technical: depth-via-value-layering as a compositional technique, applied to a completely different emotional palette.

---

*Art Bible — Lantern Guild. Version 1.0 draft. Authored by art-director (sections 1–7, 9) and technical-artist (section 8). UX constraints in Section 7 reviewed by ux-designer.*
*Last updated: 2026-04-18*
