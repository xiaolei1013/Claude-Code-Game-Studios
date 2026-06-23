# ADR-0020: Theme Skin Direction — Ratify Light-Parchment, Decline Dark-Mock Pivot

## Status

**Accepted 2026-06-08** — Sprint 28 S28-M3. Ratifies the light-parchment visual
identity already locked in `DESIGN.md` + the Art Bible as the binding direction
for the real-theme pass; records the dark-fantasy wireframe mock as the rejected
alternative. The greybox wireframes (PRs #172-176, #179, #180) skin **to
parchment**, not to dark.

> **Autonomous-default note**: selected as the defensible default per the user
> directive "move on to all tasks in gdd and sprint plan; I will verify the
> results after all tasks done" (2026-06-08). This ADR does not introduce a new
> direction — it formally closes the open "dark-mock vs light-parchment" question
> in favor of the *already-shipped* direction, which is the low-risk choice.
> **User ratification CONFIRMED 2026-06-23** — at end-of-batch verification the
> user ratified light-parchment and declined the dark-mock pivot. The ADR is now
> Accepted by user verification (see §Sign-Off Trail); the dark-mock alternative
> is formally closed.

## Date

2026-06-08

## Last Verified

2026-06-08

## Decision Makers

- Author (user) — final decision; **ratified by user verification 2026-06-23** (light-parchment confirmed, dark-mock declined)
- art-director — Art Bible §4 palette + Visual Identity Anchor adherence
- creative-director — cozy-register preservation
- godot-specialist — theme cascade (`parchment_theme.tres`) impact scope

## Summary

The project carries two competing visual directions:

1. **Light-parchment** — the locked, shipped identity. `DESIGN.md` §Color + the
   Art Bible §4 define a warm parchment-and-ink palette (Parchment Cream ground,
   Slate Ink type, Guild Amber / Lantern Gold accents). It is implemented in
   `assets/ui/parchment_theme.tres` (ADR-0008), composited by the warm-lantern
   overlay + HD-2D pipeline (ADR-0019), and applied across every shipped screen.

2. **Dark-mock** — the "Lantern Guild Prototype" design-handoff bundle (fetched
   2026-06-02) is a dark-fantasy register (Slate-Ink ground, lantern-glow accents
   on near-black). The wireframe pass deliberately rendered its *layout* as
   neutral greybox and **deferred the skin decision to this ADR** rather than
   adopt the dark palette.

**Decision: ratify light-parchment.** `DESIGN.md` §"Dark mode" already states the
position explicitly — *"the parchment-warm register IS the visual identity; there
is no alternate dark mode planned."* This ADR makes that binding for the
real-theme pass and records the rationale + the reversible post-launch escape
hatch (the "lantern dim" accessibility mode).

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | UI theming (Control theme cascade; no rendering-pipeline change) |
| **Knowledge Risk** | NONE — this ADR ratifies the status quo. No new engine API is introduced. The theme cascade (`Theme` resource on the root Control per ADR-0008) is unchanged. |
| **References Consulted** | `DESIGN.md` §Color + §"Dark mode"; `design/art/art-bible.md` §4 palette; ADR-0008 (theme cascade); ADR-0019 (HD-2D pipeline composites over parchment); `docs/engine-reference/godot/VERSION.md` (4.6 pin) |
| **Verification Required** | None for this decision (no code change). The downstream real-theme pass (greybox → parchment skin) carries its own per-screen visual verification. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0008 (UIFramework + parchment theme cascade — the baseline this ADR ratifies); ADR-0019 (HD-2D pipeline — warm-lantern + tilt-shift composite over the parchment ground) |
| **Supersedes** | None |
| **Enables** | The real-theme wireframe pass (greybox neutral-grey → parchment skin); the remaining screen restyles (Recruit 3-card, Hero Detail full, Settings/Pause, Prestige modal) proceed against parchment tokens with no palette ambiguity |
| **Numbering note** | ADR-0019 §"Pivot Triggers" speculatively forward-referenced a hypothetical "successor ADR-0020" for a *future HD-2D activation reversion*. That forward-reference is superseded by this numbering: three planning docs (`sprint-28.md`, `pending-decisions.md`, `sprint-status.yaml`) explicitly reserved ADR-0020 for the theme-skin decision. A future HD-2D reversion, if ever needed, takes the next free ADR number. |

## Context

The wireframe pass (pre-Sprint-28) implemented the Lantern Guild Prototype mock's
*layout* over the project's real Godot screens as neutral greybox, explicitly
deferring the dark-vs-light skin decision because it is a genuine conflict:

- The mock handoff is dark-fantasy.
- `DESIGN.md` (the locked design system) mandates light parchment and states
  plainly (§"Dark mode"): *"Not in MVP. The parchment-warm register IS the visual
  identity — there is no alternate dark mode planned. If post-launch playtest
  reveals battery / readability concerns on mobile, evaluate a 'lantern dim' mode
  (Slate Ink ground + Lantern Gold accent), but this is a Sprint 21+ topic."*

`CLAUDE.md` governs the tie-break: *"When the design system and the art bible
disagree, the art bible wins on visual direction; DESIGN.md wins on precise
tokens."* Here they do **not** disagree — the Art Bible §4 palette and DESIGN.md
§Color both describe the same warm parchment register. The only dissent is the
external mock, which is a handoff reference, not a locked project artifact.

Adopting the dark-mock would not be a skin swap; it would invalidate the entire
shipped visual stack: `parchment_theme.tres`, the warm-lantern overlay shader
(authored to wash *warm amber* over a *light* ground), the HD-2D biome-background
palette mapping, and the per-screen StyleBox vocabulary. Every shipped screen
would need re-skinning, and the cozy-register pillar (warm, inviting, low-pressure
— `game-concept.md`) is better served by parchment-warm than by dark-fantasy.

## Decision

### Decision 1: Light-parchment is the binding direction

The real-theme pass skins the greybox wireframes to the parchment palette defined
in `DESIGN.md` §Color (Art Bible §4). The dark-mock palette is **not** adopted.
The mock's *layout/structure* (already implemented as greybox) is retained; only
its palette is set aside.

### Decision 2: The greybox wireframes resolve to parchment

The neutral medium-grey structural widgets from the wireframe pass (`WireframeKit`)
are a temporary scaffold. The successor real-theme pass replaces neutral grey with
`parchment_theme.tres` Theme overrides + the StyleBox vocabulary in `DESIGN.md`
§"Component vocabulary". No layout reflow — the wireframes were built additively
against the same node paths (per the wireframe pass's hard-path constraint).

### Decision 3: Dark remains a reversible *post-launch accessibility* path, not an identity pivot

`DESIGN.md` §"Dark mode" already documents the only sanctioned dark direction: a
post-launch **"lantern dim"** mode (Slate Ink ground + Lantern Gold accent),
gated on real battery/readability data from a mobile playtest. This ADR does
**not** foreclose that — it declines to pivot the *core identity* to dark now.
The lantern-dim mode, if it ever ships, is an *alternate selectable theme* layered
on the parchment baseline, not a replacement for it.

### Pivot Triggers (for a future successor ADR)

A successor ADR may revisit this if any fire:

1. **User ratification reverses it** at end-of-batch verification (2026-06-08+).
   This is the immediate, expected check.
2. **Mobile playtest data** shows parchment-cream backgrounds cause a measurable
   battery or outdoor-readability problem → triggers the DESIGN.md "lantern dim"
   evaluation (an *additive* alternate theme, still not a core pivot).
3. **A creative-director re-direction** that re-frames the whole game's tone as
   dark-fantasy (would invalidate the cozy-register pillar — a far larger change
   than a theme skin, and out of scope here).

## Alternatives Considered

### Alternative 1: Pivot to the dark-mock palette

Adopt the design-handoff bundle's dark-fantasy register as the real theme.

**Rejected because**: it invalidates the entire shipped visual stack
(`parchment_theme.tres`, warm-lantern overlay, HD-2D biome palette, every screen's
StyleBox), contradicts the locked `DESIGN.md` identity + Art Bible §4, and works
against the cozy-register pillar. The cost is a full re-skin epic for an aesthetic
the project's own design system explicitly rejected for MVP. The mock is a layout
reference whose *structure* we already adopted (greybox); its palette is not
binding.

### Alternative 2: Ship both — a user-selectable dark/light toggle now

Build the dark-mock as a second selectable theme alongside parchment in MVP.

**Rejected because**: doubles the theming surface (two StyleBox sets, two palette
mappings, two warm-overlay variants) and the per-screen QA matrix, for a feature
`DESIGN.md` defers to post-launch. The "lantern dim" accessibility mode is the
sanctioned future home for a dark option, gated on real data — not MVP scope.

### Alternative 3: Keep deferring (stay greybox)

Leave the wireframes neutral-grey and postpone the skin decision again.

**Rejected because**: greybox is explicitly a scaffold, not a shippable skin. The
deferral has already blocked the real-theme pass + four screen restyles for a
sprint. The decision is low-risk (ratify the status quo) and unblocks visible
progress; continuing to defer is the worst option for player-visible polish.

## Consequences

### Positive

1. **Unblocks the real-theme pass.** Greybox → parchment skinning can proceed with
   zero palette ambiguity.
2. **Zero rework of the shipped visual stack.** `parchment_theme.tres`,
   warm-lantern overlay, and HD-2D palette mapping all stay valid.
3. **Remaining screen restyles unblocked.** Recruit (3-card draft), Hero Detail
   (full), Settings/Pause, and the Prestige modal restyle against locked parchment
   tokens.
4. **Cozy-register pillar reinforced.** Warm parchment serves the inviting,
   low-pressure fantasy better than dark-fantasy would.
5. **Dark option preserved, not destroyed.** The "lantern dim" accessibility path
   remains documented + reachable post-launch if data justifies it.

### Negative

1. **The dark-mock's mood is set aside.** The design-handoff bundle's dark-fantasy
   aesthetic is not adopted; only its layout/structure carries forward.
2. **Had the user ratified a dark pivot instead**, this ADR would have flipped to
   Superseded and a re-skin epic opened: new StyleBox set, re-authored warm-overlay
   for a dark ground, re-mapped HD-2D biome palette, and a per-screen visual re-pass.
   That path is now closed (ratified 2026-06-23); the avoided cost is recorded here
   as the rationale for why ratifying the status quo was the defensible default.

### Neutral

- The greybox wireframes still need their skin pass to parchment — that is
  separate, already-planned work (not this ADR).

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| User prefers the dark-mock at verification → ADR superseded | LOW-MED | MED | This ADR is a *ratification of the status quo*; reverting costs only this doc + a re-skin epic that would have been needed anyway under the dark path. No shipped code is wasted by choosing parchment first. |
| Mobile battery/readability data later favors dark | LOW | LOW | `DESIGN.md` "lantern dim" additive-theme path is the documented, pre-authorized mitigation; gated on real data, not speculation. |
| Greybox→parchment skin pass reveals a layout that only "reads" in dark | LOW | LOW | The wireframe layouts were structural (panel/grid/hierarchy), palette-agnostic; the warm-lantern overlay already validates that parchment + warm accents read well on the live screens. |

## GDD Requirements Addressed

- **`DESIGN.md` §Color + §"Dark mode"** — this ADR makes the documented
  "parchment IS the identity; no MVP dark mode" position binding for the
  real-theme pass and records the rationale + reversible post-launch path.
- **`design/art/art-bible.md` §4 (palette) + §Visual Identity Anchor** — ratified
  as the governing visual direction.
- **`design/gdd/game-concept.md` (cozy-register pillar)** — the chosen direction
  is the one that serves the pillar.
- **`design/gdd/ui-framework.md` + ADR-0008** — the theme cascade this ADR
  ratifies is unchanged; downstream restyles bind to it.

## Related

- **Baseline**: `docs/architecture/ADR-0008-ui-framework-dual-focus-parity-and-theme.md`
- **Composite-over relationship**: `docs/architecture/ADR-0019-hd2d-pipeline-activation.md`
- **Locked tokens**: `DESIGN.md` (§Color, §"Dark mode", §"Component vocabulary")
- **Visual direction**: `design/art/art-bible.md` §4
- **Open-question origin**: `production/pending-decisions.md` (theme-skin row);
  `production/sprints/sprint-28.md` S28-M3
- **Layout source (retained, re-skinned)**: the wireframe pass PRs #172-176, #179,
  #180 (`src/ui/wireframe_kit.gd`)

## Sign-Off Trail

- **2026-06-08** — Selected as the defensible autonomous default per the user
  directive "move on to all tasks; I will verify the results after all tasks
  done." Ratifies the already-locked `DESIGN.md` + Art Bible direction. **User
  ratification pending end-of-batch verification.**
- **2026-06-23** — **Accepted by user verification.** At end-of-batch close-out
  (Sprint 28 S28-M3) the user ratified light-parchment as the binding visual
  identity and declined the dark-mock pivot. Status stands at Accepted; the
  dark-mock alternative is formally closed (no re-skin epic opens).
