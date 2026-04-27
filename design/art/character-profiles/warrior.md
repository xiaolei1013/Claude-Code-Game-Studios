# Warrior — Visual Profile

> **Class ID**: `warrior` | **Role**: Tank | **Counters**: Bruiser archetype
> **Tone reference**: Visual Identity Anchor in `design/gdd/game-concept.md`
> (cozy fantasy, warm-light palette, painterly HD-2D)

---

## Silhouette

A broad-shouldered figure built around a dominant kite shield. The shield's
upper rim sits roughly at shoulder height, creating a tall, unmistakable
rectangle against any backdrop. Read order at thumbnail size:

1. **Shield** — the largest single mass, occupying ~40% of the silhouette
2. **Helm** — domed, riveted, with a short horsehair tuft for vertical accent
3. **Pauldrons & greaves** — chunky armour plates, slightly oversized to read
   as "weighty" without straying into cartoon proportions
4. **Sword** — held low and forward, blade-down behind the shield. Visible
   from behind the shield to telegraph offence is held in reserve

Stance is grounded — feet planted wide, knees soft. The Warrior should feel
**immovable**, not aggressive. The reading at 32×32 is "wall with a person
attached," not "person with a weapon."

---

## Colour Palette

Anchor on **warm steel + lantern bronze** — protective metals lit by hearth
light, never cold or overcast.

| Role | Hex | Use |
|------|-----|-----|
| Primary armour | `#7A6F5C` | Dull warm steel — body of plate, helm |
| Armour highlight | `#C9B796` | Bevels, rivets, helm crest catching firelight |
| Armour shadow | `#3E372C` | Recessed plate seams, undersides |
| Shield body | `#8A4B2E` | Lacquered red-brown wood — the heart of the silhouette |
| Shield trim | `#D4A24C` | Brass band + central boss — the "lantern" highlight |
| Tunic / underlayer | `#B5654A` | Warm terracotta peeking at neck and joints |
| Skin | `#D9A07B` | Warm-toned, lit |
| Sword steel | `#9CA39E` | Slightly cool — only cool note in the palette, drawing the eye to held offence |

Avoid: pure greys, blues, or any saturated cool tone outside the sword. The
Warrior is **made of hearth metal**.

---

## Proposed Pose

**Guard stance, three-quarter facing right.**

- Weight slightly back-foot, front foot angled outward
- Shield raised to mid-chest, presented to camera-right (toward the dungeon)
- Sword held low at the hip, blade-down, partially obscured by shield
- Head turned a hair toward the threat — chin level, expression calm
- One small visual tell of warmth: a tiny lantern charm or guild ribbon tied
  to the shield strap, swinging slightly

This is a **defensive idle**. When the Warrior plays the attack frame, the
sword arcs from low-to-overhead in a single arc — the shield never drops.

---

## Matchup-Counter Visual Cue

> Warrior counters **bruiser** archetype (heavy melee, slow swings).

When a Warrior is matched against a bruiser enemy in the encounter preview /
combat ticker, surface a **shield-flash glyph** beside the matchup row:

- A small (16×16) icon of the Warrior's kite shield with a soft warm-yellow
  rim-light pulse (`#FFD479` → fade)
- Pulse duration: ~250ms, two beats per matchup display
- Audio cue (when player is on the Dispatch screen): a low, dampened "thunk" —
  the sound of a shield catching a blow

The visual reads as: **"this hero is ready for what's coming."** No text
required — the rim-light pulse is the language.

In-combat: when the Warrior actually intercepts a bruiser hit, the sprite
plays a one-frame brace pose (shield squared to the attacker) and emits the
same warm-yellow rim-light at half intensity — connecting the preview cue to
the live action.
