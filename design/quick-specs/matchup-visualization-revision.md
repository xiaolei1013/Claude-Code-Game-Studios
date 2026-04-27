# Quick-Spec: Matchup Visualization Revision (Prototype-Finding Propagation)

> **Status**: Draft (2026-04-25)
> **Author**: solo dev (acting as game-designer + ux-designer)
> **Type**: Quick-Spec (UI presentation change — no gameplay rule changes)
> **Sprint**: 4 (S4-N1, Nice to Have / pre-flight)
> **Estimated effort**: < 4 hours design time + downstream GDD/UX updates
> **Source finding**: `prototypes/idle-matchup-loop/REPORT.md` — "Falsified" Open Question #3 from `design/gdd/game-concept.md` line 243

---

## Summary

The prototype playtest of `idle-matchup-loop` falsified Open Question #3 from
the game concept ("Does the class-vs-biome layer read clearly without tutorial
text?" — answer: **NO**). Player verbatim:

> *"i note the labels (×0.5 / ×1.0 / ×2.0) but don't understand what it is"*

Pillar 3 of the entire game (*"Matchup Is a Decision, Not a Reflex"*) depends
on the matchup multiplier reading **clearly and instantly**. The numeric
multiplier syntax is technically clear but semantically opaque without
onboarding.

This quick-spec proposes a UI-presentation revision: replace the numeric
multiplier labels with **named effectiveness** (Weak / Even / Strong) plus a
**per-hero portrait glow** indicating effectiveness state. The underlying
math (×0.5 / ×1.0 / ×2.0) stays in code; only the player-facing presentation
changes.

---

## Why this is a quick-spec, not a full GDD revision

The change does NOT modify:
- The matchup math in `design/gdd/class-vs-enemy-matchup-resolver.md` §D
  (formulas remain ×0.5 / ×1.0 / ×2.0 internally)
- The Pillar 3 design pillar in `design/gdd/game-concept.md`
- The matchup gating rule in `design/gdd/economy-system.md` §C.2.4
  (per-kill majority threshold)
- Any ADR (the matchup multiplier remains a runtime-resolved float)

The change DOES modify:
- The player-facing label rendering in the Formation slot UI (per
  `design/ux/hud.md` and `prototypes/idle-matchup-loop/Main.tscn`'s formation
  slot pattern)
- The per-hero portrait visual treatment (effectiveness glow)
- The future Matchup Assignment Screen (Presentation-layer epic, Sprint 5+)

This is a presentation revision, not a rule change — quick-spec scope.

---

## Decision

### Replace numeric labels with named effectiveness

**Old presentation** (per current HUD spec + prototype's actual rendering):

```
Formation slot
+--------------+
|   [portrait]  |
|   Knight lvl 5|
|   vs Caster: ×0.5  ← OPAQUE LABEL
+--------------+
```

**New presentation** (this quick-spec):

```
Formation slot
+--------------+
|   [portrait + WEAK GLOW]
|   Knight lvl 5|
|   Weak vs Caster   ← NAMED EFFECTIVENESS
+--------------+
```

### Effectiveness vocabulary (locked)

| Underlying multiplier | Player-facing label | Hero portrait treatment |
|---|---|---|
| `×2.0` (counter-archetype matched) | **Strong** | Lantern-gold pulsing glow (per `lantern-glow-backdrop` palette; localized to portrait outline) |
| `×1.0` (neutral) | **Even** | No glow; portrait neutral |
| `×0.5` (counter-archetype mismatched) | **Weak** | Dusk-purple desaturated outline; reduced-saturation portrait body |

Three states only. No gradients, no fractional values exposed to the player.

### Vocabulary rationale

- "Weak / Even / Strong" reads in 1 word; matches established game vocabulary
  from comparable cozy-fantasy systems (Slay the Spire archetype matchups;
  Pokemon's Super Effective / Not Very Effective).
- Avoids "Counter / Neutral / Countered" — too technical, reads as
  developer-facing.
- Avoids "Bonus / None / Penalty" — reads punitive on the Weak side, which
  conflicts with Pillar 1 (the cozy-fantasy promise: no fail state, no harsh
  feedback).
- The lantern-gold glow on Strong matches the broader Visual Identity Anchor
  (lantern gold reserved for rewards / unlocks / progression moments per
  Art Bible §1).

---

## Cross-system impact

| Document | Action | Sprint |
|---|---|---|
| `design/gdd/class-vs-enemy-matchup-resolver.md` | Add §F.x "Player-Facing Presentation" subsection citing this quick-spec; do NOT change §D formulas | Sprint 5 (when matchup-resolver Feature epic decomposes) |
| `design/gdd/dungeon-run-orchestrator.md` | Add reference: matchup-effectiveness label is supplied by the resolver as `effectiveness_label: String` ∈ {"Weak", "Even", "Strong"} alongside the numeric multiplier | Sprint 5 |
| `design/ux/hud.md` | Update Formation slot rendering spec — replace numeric label with named effectiveness + glow | Pre-Sprint-5 (this quick-spec is the source) |
| `design/ux/interaction-patterns.md` | Add new pattern: `effectiveness-glow` (per-portrait outline glow with 3 states) | Sprint 5 |
| Future `design/ux/matchup-assignment-screen.md` (V1.0+) | Author against this presentation contract from day one | V1.0 |
| `design/registry/entities.yaml` | No change — effectiveness is computed, not authored | — |
| ADRs | No new ADR; existing matchup-resolver ADR-0009 is unaffected | — |

The localization burden goes UP slightly (3 new player-facing strings:
"Weak", "Even", "Strong" — but each is a single common-vocabulary word that
translates cleanly to all target languages with minimal expansion).

---

## Implementation hint (for Sprint 5+ implementer)

- In the matchup resolver's runtime API: `MatchupResolver.resolve(...)`
  should return BOTH the multiplier (float) AND the effectiveness label
  (String). E.g., `MatchupResult { multiplier: float, effectiveness: String }`.
- Mapping is fixed per the lock above: 2.0 → "Strong", 1.0 → "Even",
  0.5 → "Weak". No rounding logic needed (matchup multiplier is a fixed
  enum of 3 values per ADR-0009).
- The per-hero portrait glow is a UI concern — `effectiveness-glow`
  pattern (to be added to `interaction-patterns.md` in Sprint 5) renders
  the glow based on the resolved effectiveness label.
- The numeric multiplier stays in tooltips (mouse hover / long-press)
  for power-user transparency: "×2.0 — Strong matchup."

---

## Acceptance criteria for the quick-spec itself (validation that this revision lands cleanly)

- [ ] When implemented, ≥1 non-developer playtester independently identifies
  the matchup decision as a strategic choice (not a math knob) without
  prompting
- [ ] When implemented, ≥1 playtester says some variant of "I picked Knight
  for the Beast floor because he's Strong against them" — i.e., the named
  effectiveness vocabulary is in active use
- [ ] No localization-pass blocker: "Weak / Even / Strong" all fit the
  Formation slot label area at +40% expansion (German + French)
- [ ] The numeric multiplier stays accessible via tooltip / long-press for
  power users who want the raw value
- [ ] Standard accessibility tier maintained: effectiveness state is
  communicated via icon (glow) + text (label), NOT color alone
- [ ] Reduced-motion preference: lantern-gold glow on Strong is replaced by
  static lantern-gold outline (same color, no pulse)

---

## Open questions

1. **Does the per-hero glow need to animate, or is a static outline sufficient?**
   Recommended: pulse on the Strong matchup (subtle 2-second cycle ≤5%
   opacity variance, similar to `lantern-glow-backdrop`). Stays cozy, draws
   eye, doesn't distract.
2. **Should the Weak label show a defensive icon (shield-with-X)?**
   Recommended: NO — keep label-only for Weak. Visual punishment conflicts
   with Pillar 1 (no fail state). The dusk-purple desaturation already
   communicates "this hero won't excel here" without doom signaling.
3. **What about partial matchups (e.g., 2-of-3 formation slots have the
   Strong archetype)?** Per ADR-0009 majority-threshold rule, the FORMATION
   has one effectiveness state derived from the majority. Per-hero labels
   show the per-hero state (which is independent of formation majority).
   This is intentional — players see both "my Knight is Strong here" AND
   "my formation is Even overall." The full discussion belongs in the
   matchup-assignment-screen UX spec when authored.

---

## Source playtest record

From `prototypes/idle-matchup-loop/REPORT.md`:

> **Verdict**: PROCEED with two mandatory production changes.
>
> 1. **Pillar 3's matchup decision is invisible without enemy
>    representation.** The dungeon view is a progress bar; there is no
>    Caster on screen to counter, no Brute to crush. "Caster" is text;
>    the matchup decision feels like a math knob, not a strategic choice.
>    The player explicitly said "no enemies."
> 2. **The multiplier label is not self-explanatory.** `vs Caster: ×2.0`
>    is syntactically clear but semantically opaque without onboarding.
>    The player read the labels but did not understand what they meant.

This quick-spec addresses item #2. Item #1 is addressed by the parallel
quick-spec at `design/quick-specs/dungeon-enemy-visualization.md` (S4-N2).

---

## Verdict (this quick-spec's own status)

**APPROVED** for propagation when matchup-resolver Feature epic decomposes
(Sprint 5+). The downstream GDD updates can be made in lockstep with the
implementation story.
