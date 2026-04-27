# Mage — Visual Profile

> **Class ID**: `mage` | **Role**: Striker | **Counters**: Caster archetype
> **Tone reference**: Visual Identity Anchor in `design/gdd/game-concept.md`
> (cozy fantasy, warm-light palette, painterly HD-2D)

---

## Silhouette

A tall, slender figure organised around two strong vertical lines — the
**staff** and the **trailing hem of a long coat or robe**. Read order at
thumbnail size:

1. **Staff** — held upright, taller than the figure, topped with a
   teardrop-shaped lantern crystal. The staff is the silhouette's spine
2. **Hood / cowl** — pulled partway back so the face reads, but the cowl
   creates a sharp angular peak above the head
3. **Robe hem** — sweeps back and down behind the figure, giving motion
   even while idle
4. **Forearm wrappings** — leather-bound bracers, asymmetric (one full,
   one half), for visual interest at the gesture hand

Stance is **upright but never rigid** — slight forward lean, off-hand
relaxed and palm-up at hip height as if catching motes of light. The Mage
should feel **focused, not flashy**. At 32×32 the read is "vertical figure
with a glowing stick," distinct from any other class.

---

## Colour Palette

Anchor on **deep wine + lantern-amber** — the colours of a study lit by a
single oil lamp at dusk. Warm darks dominate; the only bright note is the
crystal at the staff's tip.

| Role | Hex | Use |
|------|-----|-----|
| Robe primary | `#3E2A3A` | Deep wine-purple — main coat body |
| Robe shadow | `#1F1422` | Folds, undersides of hem |
| Robe highlight | `#6B4A5C` | Shoulder ridges, cowl peak |
| Underlayer / tunic | `#9C5A3D` | Warm rust visible at chest opening |
| Leather wrappings | `#5C3A2A` | Bracers, belt, boot tops |
| Skin | `#E0B391` | Lit warmly from below by the staff crystal |
| Staff wood | `#3A2A1E` | Dark walnut, almost black at silhouette edges |
| **Crystal core** | `#FFC36B` | The single bright value — warm amber, the lantern note |
| Crystal glow halo | `#FFE3A8` | Soft falloff around the crystal, ~8px feathered |

The crystal's glow is the **only place in the Mage palette that approaches
white**. Everything else is dark-warm. This makes the magic feel like
light, not effects.

---

## Proposed Pose

**Casting-ready, three-quarter facing right.**

- Stance slightly forward, weight on the front foot
- Staff held vertical in the rear hand, crystal up — light spilling onto
  the cowl and shoulder
- Forward hand extended palm-up at hip height, fingers loosely curled
  as if cradling an unseen ember
- Head tilted a touch forward, eyes downcast toward the open palm —
  reading as **focus**, not menace
- Robe hem drifts back-right, frozen mid-flutter, suggesting the air
  around the Mage doesn't quite obey gravity

The idle anim is a slow rise-fall of the open palm: light gathers, dims,
gathers — a candle breathing. The attack frame: the palm snaps forward and
the crystal flares; no big arm swing, the magic does the work.

---

## Matchup-Counter Visual Cue

> Mage counters **caster** archetype (enemy spellcasters / projectile
> threats).

When a Mage is matched against a caster enemy, surface a **rune-circle
glyph** beside the matchup row:

- A small (16×16) icon of a stylised circular rune in warm amber
  (`#FFC36B`), inscribed with three short tick-marks
- The rune **rotates 90°** over ~400ms, two beats per matchup display,
  with a soft amber bloom on the inner ring
- Audio cue (Dispatch screen): a soft chime — wind through brass — pitched
  warm, not crystalline

The visual reads as: **"this hero unmakes their tricks."** The rotation is
the language — caster vs. caster is a battle of who finishes their working
first, and the Mage is *already turning*.

In-combat: when the Mage's attack lands on a caster, a single-frame rune
flashes at the impact point in the same amber palette. Same glyph, same
rotation cadence — the preview cue and the live moment share visual DNA.
