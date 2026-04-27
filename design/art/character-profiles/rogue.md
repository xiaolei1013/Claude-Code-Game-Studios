# Rogue — Visual Profile

> **Class ID**: `rogue` | **Role**: Precision | **Counters**: Armored archetype
> **Tone reference**: Visual Identity Anchor in `design/gdd/game-concept.md`
> (cozy fantasy, warm-light palette, painterly HD-2D)

---

## Silhouette

A compact, low-slung figure built around a **diagonal axis**. Where the
Warrior is a wall and the Mage is a column, the Rogue is a leaning
parallelogram. Read order at thumbnail size:

1. **Hooded cloak** — half-cape thrown over one shoulder, breaking the
   silhouette asymmetrically
2. **Twin daggers** — held in reverse grip, blades along the forearms, so
   the silhouette reads as "person with sharp elbows" before "person with
   knives"
3. **Crouched stance** — knees deeply bent, centre of gravity low. The
   shoulders sit no higher than mid-frame
4. **Trailing scarf or cord** — a thin horizontal accent line,
   counter-balancing the vertical hood peak

The Rogue should feel **light, kinetic, asymmetric**. At 32×32 the read is
"someone about to move," not "someone standing still." Even at idle, the
silhouette implies motion through its lean.

---

## Colour Palette

Anchor on **forest dusk + copper accents** — twilight colours, the
Lantern Guild's scout palette. Earthier than the Warrior's hearth metals,
brighter than the Mage's wine-darks.

| Role | Hex | Use |
|------|-----|-----|
| Cloak primary | `#3F4A38` | Deep moss-green — main cloak body |
| Cloak shadow | `#1F261B` | Folds, hood interior |
| Cloak highlight | `#6B7A5C` | Shoulder, hood peak catching light |
| Tunic / leathers | `#5A4031` | Rich saddle-brown — torso & leggings |
| Leather strap accents | `#8C5A33` | Belts, dagger sheaths |
| Skin | `#D9A07B` | Warm-toned, half-shadowed by hood |
| Scarf / cord | `#B5654A` | Warm terracotta — small but eye-catching |
| **Dagger blades** | `#B89060` | Aged copper-bronze — the matchup cue colour |
| Blade highlight | `#E8C386` | Sharp specular glint along the edge |

Note the **copper-bronze blades** rather than steel. This is intentional:
copper is the visual rhyme that ties the Rogue's combat read to their
counter cue (see below). It's also a quiet world-build note — Lantern
Guild rogues use mineral-treated blades that dull armour better than steel.

---

## Proposed Pose

**Pre-strike crouch, three-quarter facing right.**

- Deep crouch, weight forward over the lead foot, rear foot poised on the
  ball — ready to push off
- Both daggers held in **reverse grip**, blades flat along the forearms,
  pointing back toward the elbows
- Lead arm extended low and forward, blade hidden against the inner
  forearm — concealment-first
- Rear arm tucked behind the back, second blade fully concealed by the
  cloak — the player only sees one blade at a glance
- Head tilted down, hood casting a half-shadow across the upper face;
  one eye visible, catching the lantern-warm light from somewhere
  off-frame
- Cloak hangs asymmetrically — heavier drape on the rear shoulder, lighter
  on the lead

The idle anim is a slow, near-imperceptible weight-shift, foot to foot —
the pose never resets to neutral. The attack frame: a single explosive
forward step, both blades flashing to forward grip simultaneously, then
snapping back to reverse grip on recovery.

---

## Matchup-Counter Visual Cue

> Rogue counters **armored** archetype (heavily plated enemies).

When a Rogue is matched against an armored enemy, surface a **chip-and-spark
glyph** beside the matchup row:

- A small (16×16) icon of two crossed dagger silhouettes in copper-bronze
  (`#B89060`), with a single bright spark at the crossing point
- The spark **flares from a 1px point to a 6px star** over ~150ms, then
  fades; cycle repeats twice per matchup display
- A faint dust of small chips/flecks falls below the glyph, ~3 frames of
  copper-coloured particles — visual shorthand for "armour is being shaved"
- Audio cue (Dispatch screen): a sharp metallic *tink* — the sound of
  copper on plate — followed by a softer whisper of falling flakes

The visual reads as: **"this hero finds the seam."** The cue isn't
power — it's precision. Copper sparks specifically (not steel sparks)
to differentiate the Rogue's "I'll wear them down" feel from the
Warrior's "I'll hold them off" feel.

In-combat: when a Rogue attack lands on an armored enemy, a copper spark
emits at the impact point and a tiny chip-flake plays for ~6 frames. Same
palette, same cadence — preview and live read as one visual language.
