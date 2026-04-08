# Art Bible — Trizzle / Shadow Quest

> **Created**: 2026-04-07
> **Status**: Approved
> **Game**: Medieval Fantasy Action Roguelite
> **Engine**: Unity 6000.3.11f1 (URP 17.3.0)
> **Platforms**: PC (Steam) primary, Mobile (Android/iOS) secondary

See `production/Trizzle/DESIGN.md` for the full implementation-level design system
(colors, typography, spacing, motion, component specs). This art bible establishes
the creative direction that the design system implements.

---

## 1. Visual Identity Statement

**One-line visual rule**: The world is dark and atmospheric, but every moment of
player achievement glows warm gold.

**Supporting principles**:

1. **Restrained color**: Dark panels, near-black backgrounds, color is rare and
   meaningful. When color appears, it communicates gameplay state, not decoration.
   *Design test*: "Should this element be colored?" — Only if it communicates
   a player-relevant state (danger, reward, rarity, status effect). If purely
   decorative, it stays dark/neutral.

2. **Fantasy-book personality**: Cinzel serif typography and warm parchment text
   give the UI the feel of an illuminated manuscript, not a generic sci-fi HUD.
   *Design test*: "Should this UI feel modern or archaic?" — Archaic, always.
   The game is set in a medieval fantasy world. The UI belongs in that world.

3. **Combat clarity over spectacle**: VFX must communicate gameplay state first,
   look impressive second. If a visual effect is beautiful but obscures a boss
   telegraph, the effect is wrong.
   *Design test*: "Is this VFX readable at maximum enemy density?" — If not,
   simplify until it is. Pillar 2 (Readable Danger) overrides visual fidelity.

**Visual Identity Anchor**: Dark Fantasy with Warm Progression.
- Color philosophy: One warm accent (#D4A843 gold) + neutrals + semantic colors.
  Gold = "you earned this."
- Reference games: Hades (functional HUD, strong art direction), Dead Cells
  (customizable HUD density), Slay the Spire (clean card drafting), Soulstone
  Survivors (dark fantasy roguelite visual space)

---

## 2. Mood & Atmosphere

| Game State | Primary Emotion | Lighting Character | Atmospheric Adjectives | Energy Level |
|---|---|---|---|---|
| **Combat** | Focused urgency | Cool ambient base (#0D0D12) + warm spot hits on player; high contrast; rim-lit from above-rear to silhouette enemies | Tense, readable, gritty, kinetic | High |
| **Boss Encounter** | Dread becoming triumph | Dominant cool tint shifts toward boss's signature hue (desaturated red, sickly purple, or deep teal); player remains warm-lit; vignette tightens | Oppressive, theatrical, dangerous, mythic | Very High |
| **Skill Draft** | Anticipation / agency | Light pulls inward — panels are the only illuminated objects; dark surround, gold card borders catch eye; ambient cools to near-black | Deliberate, reverent, quiet, weighted | Low — sudden calm after combat |
| **Menu / Preparation** | Curiosity / readiness | Neutral warm ambient (#1A1A24 surface); gentle god-ray or subtle particle float; no hard shadows | Contemplative, steady, inviting | Low |
| **Victory / Results** | Earned satisfaction | Burst of warm gold light (#D4A843) radiating outward from screen center; desaturated background pushes gold forward; directional light from below | Luminous, warm, conclusive, ceremonial | Medium — release, not frenzy |
| **Death** | Resignation (not punishment) | All color desaturates to near-monochrome cool grey-blue; vignette crushes black hard; single cool light from above | Cold, still, quiet, stark | Very Low |

**Lighting philosophy notes:**
- Warm gold accent is a **reward trigger** — it appears ONLY when the player earns
  something (crit hit, level up, draft pick, victory). Never decorative.
- Boss encounter lighting is boss-specific but always desaturated so the player's
  warm rim-light stands out in contrast. The player is never visually "swallowed"
  by a boss room.
- Death does not use red (reserved for health status). Desaturated-cold treatment
  avoids confusion with damage feedback.
- Skill Draft transition: audio + lighting communicate "safe moment." This is the
  game's breath — lighting must support the psychological pause.

---

## 3. Shape Language

### Character Silhouette Philosophy

**Rule**: At game camera distance (~8-12 units behind and above), every character
must read as a distinct silhouette in under 200ms. If it needs color to
differentiate, the silhouette has failed.

| Character | Silhouette Target | Key Differentiator | Shape Vocabulary |
|---|---|---|---|
| **Mage** | Wide base, planted stance, large spell-casting gesture space | Robe flare at bottom; staff/orb creates secondary point above head | Circles, arcs, radial — spells emanate from fixed center |
| **Archer** | Narrow profile, mid-crouch ready stance, elongated vertical read | Bow creates asymmetric horizontal line; quiver on back | Triangles, diagonals, pointed — motion implied at rest |

**Silhouette test**: Both characters side-by-side as solid black shapes must be
distinguishable at 512px height (approximating game camera distance).

### Environment Geometry

- **Room style**: Medieval crypt-dungeon with architectural clarity. Rectangular
  or octagonal footprints, high vaulted ceilings, clear navigable floor plane.
- **Wall language**: Thick stone, strong right angles, archways for depth, no
  smooth surfaces. Roughness communicates age and danger.
- **Navigable vs decorative**: Navigable space reads as flat, slightly lighter
  stone. Decorative walls recede with darker tiling. Gameplay signal, not just
  aesthetic — supports Pillar 2 (Readable Danger).

### UI Shape Grammar

UI echoes the architecture: **rigid geometry, cut corners**.

- Buttons: 4px border radius (slightly cut, never fully rounded — authority)
- Panels: 8px border radius (heavier container feel)
- Modals: 12px border radius (softest element, still anchored)
- Skill cards: rectangular with notched-corner icon box (echoes stone inscriptions)
- **Contrast principle**: UI shapes are angular and deliberate against the soft,
  atmospheric world. World is moody and blurred; UI cuts through with hard edges.

### Hero Shapes vs Supporting Shapes

- **Hero shapes (player, boss)**: Complex silhouettes with multiple read points.
  Allowed decorative detail.
- **Regular enemies**: Simpler 2-3 point silhouettes. Readable at-a-glance only.
- **UI primary elements**: Geometric precision — defined, bordered, clean.
- **UI ambient elements**: Can carry organic texture fill, but outer shape is
  always rectilinear.

---

## 4. Color System

### Primary Palette

| Role | Color | Hex | Usage |
|------|-------|-----|-------|
| **Background** | Near-black blue | #0D0D12 | Base world/UI background |
| **Surface** | Dark panel | #1A1A24 | UI overlays, card backgrounds |
| **Surface Hover** | Subtle lift | #222230 | Interactive element hover state |
| **Primary Text** | Warm parchment | #E8E0D0 | All body text — warm off-white |
| **Muted Text** | Soft gray-purple | #8A8490 | Secondary info, descriptions |
| **Accent** | Warm gold | #D4A843 | Progression, headings, currency, CTA, selected states |
| **Accent Dim** | Pressed gold | #B8903A | Pressed/hover variant |
| **Border** | Subtle divider | #2A2A38 | Panel borders |

### Semantic Color Usage

| Semantic | Color | Hex | What it communicates |
|----------|-------|-----|---------------------|
| **Health** | Red | #C44040 | Damage, HP loss, danger to player. Background: #3A1818 |
| **Mana/Energy** | Blue | #3D8EC9 | Resource pool, ability cost. Background: #162A3A |
| **Buff** | Green | #4CAF50 | Positive status effect active |
| **Debuff** | Red | #E05555 | Negative status effect active |
| **Gold/Reward** | Warm gold | #D4A843 | "You earned this" — progression moments |

### Rarity Colors (Genre Convention)

| Rarity | Color | Hex | Notes |
|--------|-------|-----|-------|
| Common | White | #FFFFFF | Clean, no glow |
| Rare | Blue | #2C70DD | Subtle border glow |
| Epic | Purple | #9B30FF | Pulse animation on border |
| Legendary | Gold | #FFD700 | Distinct from accent gold (#D4A843) — brighter, pure gold |

### Colorblind Safety

- Rarity system uses **distinct hue channels** (white/blue/purple/gold) — passes
  most colorblind modes.
- Status effects (buff green / debuff red) use **icons alongside color** — never
  color alone.
- Damage numbers use **size + animation** in addition to color (critical = larger
  + gold glow, not just color change).

---

## 5. Character Design Direction

### Player Character Archetypes

**Mage — "The Planted Caster"**
- Robed, slightly heavyset silhouette, slow-deliberate pose language
- Color: cool dark robes (desaturated navy/near-black), warm accent on magical
  focal points (spell-channeling hands, staff crystal)
- Face: obscured or shadowed — power comes from the spells, not the person
- Upgrade states: rarity-tier escalation on staff/orb only. Outfit stays dark;
  the held power item glows.

**Archer — "The Swift Hunter"**
- Lean, narrow, mid-crouch-ready stance, asymmetric bow profile
- Color: muted earth tones (leather, dark olive, dark brown), cool accent on
  fletching/bowstring when abilities activate
- Face: visible (contrasts Mage) — personality through body language and expression
- Movement animations are the primary character read — always looks about to dodge
- Upgrade states: quiver fills with glowing arrows; bow arm gains subtle VFX trace

**Both classes**: Dark palettes with zero visual clutter at default state. Complexity
added through VFX on skill activation, not base costume ornamentation.

### Enemy Visual Hierarchy

| Tier | Visual Rules | Size | Silhouette Complexity |
|---|---|---|---|
| **Regular** | Single muted hue; no glow; 2-3 point silhouette | 0.8-1.0x player height | Simple |
| **Elite** | Same species + one glow accent; slightly larger | 1.1-1.3x player height | Medium (one added feature) |
| **Boss** | Full silhouette redesign; dynamic element; phase-shift changes lighting | 1.5-2.5x player height | Complex |

**Tier test**: Remove all colors. Regular and Elite of the same species must be
distinguishable by silhouette alone at game camera distance.

### Distinguishing Feature Rules (Pillar 2: Readable Danger)

1. Attack telegraph shape is unique per enemy type — no two share the same wind-up
2. Status effect enemies carry a visible aura matching the effect color
3. Elite enemies carry one consistent color-accent marker per species
4. Boss phase shifts are announced visually before mechanically active

### LOD Philosophy

- Camera: fixed 3/4 overhead, ~10 units back. Character screen height: 80-120px at 1080p.
- Do not model what the camera cannot see (undersides, boot soles).
- Characters: one albedo + one normal map. No complex PBR chains.
- Animation priority: idle, move, attack, hit, death must be highly readable.
  Secondary animations (blink, fidget) are low priority.
- Mobile LOD: 50% polygon reduction, silhouette rules still apply.

---

## 6. Environment Design Language

### Room / Arena Architectural Style

- **Archetype**: Medieval crypt, dungeon, ruined fortress. Always inside a built
  structure — never outdoors, never natural cave.
- **Floor plan**: Defined combat arena 20-40 units across. Clear entry/exit
  markers (arched doorways with distinct lighting). No hidden pockets — everything
  the player can stand on is visible from 90% of the arena.
- **Verticality**: Ceiling height at least 3x player height. Lets projectile VFX
  arc naturally, reinforces scale and threat.
- **Damage-readable**: Traps and hazards have a visual warning ring or floor
  marking visible even when inactive. Pillar 2 applies to environment.

### Texture Philosophy (Stylized PBR for URP)

- **Style**: Stylized, not realistic. Visible directional brushstroke or stipple
  in albedo — reads better at camera distance and survives mobile compression.
- **Albedo**: Rich desaturated base tones (dark grey, cold stone, aged wood brown).
  Hand-painted variation within tight value range (no more than 30% value spread).
- **Normals**: Moderate detail for surface read without photorealistic roughness.
- **Emissive**: Reserved for narrative priority: magical runes, trap indicators,
  elite markers, loot drops. Environment ambient emissive is low and cool-toned.
- **Mobile**: Environment prop atlases at 1024px. Unique assets at 512px max
  unless hero props.

### Prop Density Rules

- **Combat rooms**: Low-medium density. At least 60% of floor traversable with
  no obstacles. Props at room perimeter.
- **Transition areas**: Denser atmospheric dressing acceptable (barrels, bones,
  sconces, banners). Not combat spaces.
- **No prop soup**: 3-5 prop categories per room. Repeat with scale/rotation
  variation. Do not add unique prop types to fill space.
- **Layer order**: Background wall → Mid-ground structure (pillars, arches) →
  Foreground perimeter props → No props on navigable floor center.

### Environmental Storytelling

Not narrative-driven (see anti-pillars). Atmospheric dressing only.

- Rooms tell one sentence, not a paragraph. One detail implying history.
- Enemy type and environment match (fire enemies → scorch marks, undead → burial markers).
- No lore objects requiring stopping. No readable scrolls or plaque text.
- Lighting anchors story: boss room centerpiece lit with boss signature lighting
  before encounter begins.

---

## 7. UI/HUD Visual Direction

### Typography

| Role | Font | Weight | Size | Usage |
|------|------|--------|------|-------|
| Hero/Title | Cinzel | 700 | 36px | Main titles, screen headers |
| Section Heading | Cinzel | 600 | 24px | Panel headers, draft screen titles |
| Subheading | Source Sans 3 | 600 | 18px | Subsections, stat categories |
| Body | Source Sans 3 | 400 | 14px | Descriptions, dialog, skill text |
| Caption/Label | Source Sans 3 | 600 | 12px | Uppercase, letter-spacing 1-2px |
| HUD Overlay | Source Sans 3 | 600 | 10px | In-combat overlays |
| Data/Numbers | Source Sans 3 | Tabular | Varies | Damage numbers, stats, timers |

CJK locales: Noto Serif CJK (display), Noto Sans CJK (body). All fonts bundled.

### Layout

- **HUD placement**: Health/mana top-left, currency/wave top-right, action bar
  bottom-center, buffs/debuffs bottom-left
- **Skill draft**: Centered modal overlay, 3 cards horizontal, dark semi-transparent
  backdrop
- **Menus**: Full-screen dark panels with primary/secondary hierarchy
- **Border radius**: sm 4px (buttons), md 8px (panels), lg 12px (modals)

### Combat Feedback

- **Damage numbers**: Source Sans 3, 700 weight, tabular-nums. Normal: 28px white.
  Critical: 40px gold with text-shadow glow. Float up + fade.
- **Health bar**: Gradient fill (dark-to-light within color). Smooth lerp on change.
  Numeric overlay (e.g., "72/100").
- **Status effects**: 24px icons with colored borders. Green = buff, red = debuff.
  Scale-pop animation on apply.
- **Skill cooldown**: Dark overlay sweeping up on action bar. Icon dims during cooldown.
- **Hit feedback**: Brief white flash on damaged character sprite.

### Skill Card Design

- Border: 2px solid, colored by rarity
- Background: #1A1A24 surface
- Layout: Icon (56px circle, rarity-tinted BG) → Name (Cinzel, rarity color) →
  Description (Source Sans 3, muted) → Rarity label (12px uppercase)
- Hover: translateY(-4px), box-shadow with rarity color at 20% opacity
- Selected: border brightens, subtle glow

### Motion

- **Philosophy**: Intentional — motion serves gameplay clarity, not decoration
- **Easing**: enter: ease-out, exit: ease-in, move: ease-in-out
- **Durations**: micro 50-100ms (button), short 150-250ms (panel), medium 250-400ms
  (card entrance), long 400-700ms (result screen)
- Skill card entrance: slide up + fade, staggered 50ms per card
- Rarity glow: subtle pulse on Epic/Legendary borders
- Damage numbers: float up + fade over 1s
- Health bar: smooth lerp (not instant snap)
- Room transition: fade to black (0.5s)
- Buff/debuff icons: scale pop on apply (100ms)

### Accessibility

- Primary text on background: 14.7:1 contrast ratio (exceeds WCAG AAA)
- Touch targets: minimum 44px (action slots 48px)
- Rarity: distinct hue channels + icon backup for colorblind safety
- Full keyboard navigation for menus, skill selection, dialog panels

---

## 8. Asset Standards

### File Formats

| Asset Type | Format | Notes |
|---|---|---|
| Textures | PNG (source), imported as Unity compressed | Max 2048px PC, 1024px mobile |
| Models | FBX | Export from DCC with Y-up, 1 unit = 1 meter |
| Animations | FBX (embedded) or .anim | Humanoid rig for characters |
| Audio | WAV (source), OGG (runtime) | 44.1kHz, 16-bit minimum |
| UI sprites | PNG with alpha | Power-of-2 atlas sheets preferred |

### Texture Resolution Tiers

| Category | PC Resolution | Mobile Resolution |
|---|---|---|
| Player character | 2048x2048 | 1024x1024 |
| Boss | 2048x2048 | 1024x1024 |
| Regular enemy | 1024x1024 | 512x512 |
| Environment prop | 512x512 | 256x256 |
| Environment atlas | 2048x2048 | 1024x1024 |
| UI element | 256x256 max | 256x256 max |
| VFX texture | 256x256 | 128x128 |

### Polygon Budgets

| Category | PC Budget | Mobile Budget |
|---|---|---|
| Player character | 8,000-12,000 tris | 4,000-6,000 tris |
| Boss | 10,000-15,000 tris | 5,000-8,000 tris |
| Regular enemy | 3,000-5,000 tris | 1,500-2,500 tris |
| Environment prop | 500-2,000 tris | 250-1,000 tris |
| Room total | <100,000 tris | <50,000 tris |

### Performance Constraints (from technical-preferences.md)

- **Target**: 60 fps on both platforms
- **Draw calls**: <200 (mobile), <500 (PC)
- **Memory ceiling**: 1 GB (mobile), 4 GB (PC)
- **Material slots per object**: 1-2 max (supports batching)
- **LOD levels**: 2 per character (full, mobile-simplified at 50% poly)

### Naming Conventions

- Textures: `T_[AssetName]_[Type].png` (e.g., `T_Mage_Albedo.png`, `T_Mage_Normal.png`)
- Models: `SM_[AssetName].fbx` (static mesh) or `SK_[AssetName].fbx` (skeletal)
- Materials: `M_[AssetName].mat`
- Animations: `A_[CharacterName]_[Action].anim`
- VFX: `VFX_[EffectName].prefab`
- UI sprites: `UI_[ElementName].png`

### Export Checklist

- [ ] Textures: power-of-2 dimensions, no alpha channel unless required
- [ ] Models: triangulated, no n-gons, clean UV unwrap, single UV channel
- [ ] Materials: URP Lit shader unless VFX (then URP Unlit or custom)
- [ ] Pivot: center-bottom for characters, center for props
- [ ] Scale: 1 unit = 1 meter, no scale transforms baked

---

## 9. Reference Direction

### Reference 1: Hades (Supergiant Games, 2020)

**What to take**: HUD design philosophy — minimal, consistently positioned, every
element earns screen space. Strong character identity at roguelite camera distance.
Warm accent light on player character even in dark environments.

**What to avoid**: Richly illustrated portrait art and voiced dialogue (no budget).
Painterly saturated palette with competing warm tones — Trizzle is more restrained.

**Why it matters**: Target comp for functional HUD readability and proving that
strong art direction makes short-run loops feel premium.

### Reference 2: Dead Cells (Motion Twin, 2018)

**What to take**: Combat juice density — every hit has a distinct visual response.
Enemy telegraph clarity — visually distinct attack wind-ups that become learnable.

**What to avoid**: Pixel art aesthetic (Trizzle is 3D stylized). Overly complex
environmental detail competing with combat reads in busy rooms.

**Why it matters**: Gold standard for real-time action roguelite combat feedback.
Pillar 2 (Readable Danger) measured against Dead Cells' telegraph clarity.

### Reference 3: Slay the Spire (MegaCrit, 2017)

**What to take**: Card visual design language — dark surface, rarity-colored border,
icon+name+stat+description hierarchy. Draft choice as ceremony, not list item.

**What to avoid**: Flat UI chrome and light pastel backgrounds. Overloaded keyword
text on cards — prioritize icon and short descriptor.

**Why it matters**: Reference for Skill Draft UI — the most critical non-combat
moment in each run. Card presentation must carry psychological weight.

### Reference 4: Soulstone Survivors (Game Smithing Limited, 2022)

**What to take**: Dark fantasy visual language at action-roguelite camera angle.
How emissive particle effects layer on dark environment without destroying
readability. Enemy density management as a visual problem.

**What to avoid**: Screen saturation from overlapping VFX — budget VFX complexity
per active skill, no unbounded particle stacking. Generic dark-fantasy
brownification — Trizzle maintains cool-dark #0D0D12 blue-black.

**Why it matters**: Exact genre position (dark fantasy action roguelite). Direct
benchmark for VFX clarity and environment distinctiveness.

### Reference 5: Illuminated Manuscripts (Medieval European, 1100-1500 CE)

**What to take**: Gold-on-dark decorative language — warm gold (#D4A843) against
near-black has direct precedent in manuscript borders. Gold means significance.
Parchment-warm text (#E8E0D0) reads as page-of-a-book. Cinzel serif echoes Roman
inscription letterforms. Restrained color with one luminous accent.

**What to avoid**: Literal manuscript illustration style (flat, no depth). Religious
iconography or specific historical imagery.

**Why it matters**: Grounds the "why" of the color choices. When a team member
questions the gold accent: "In this tradition, gold is sacred. Every element that
earns gold must deserve it."
