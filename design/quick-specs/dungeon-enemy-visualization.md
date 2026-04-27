# Quick-Spec: Dungeon Enemy Visualization (Prototype-Finding Propagation)

> **Status**: Draft (2026-04-25)
> **Author**: solo dev (acting as game-designer + ux-designer + art-director)
> **Type**: Quick-Spec (UI presentation change — no gameplay rule changes)
> **Sprint**: 4 (S4-N2, Nice to Have / pre-flight)
> **Estimated effort**: < 4 hours design time + downstream GDD/UX updates
> **Source finding**: `prototypes/idle-matchup-loop/REPORT.md` — player verbatim *"no enemies. so our heroes are always alive."*

---

## Summary

The prototype playtest of `idle-matchup-loop` revealed that the Dungeon Run
view as currently spec'd (a progress bar + "Floor 3: Wolf Hollow — primary:
Beast" header text) does NOT communicate that combat is happening. Player
verbatim:

> *"no enemies. so our heroes are always alive."*

This is the foundational legibility gap that defeats Pillar 3 (*"Matchup Is a
Decision, Not a Reflex"*) — there's nothing visible on screen for the matchup
to operate against. The matchup-effectiveness labels (per the parallel
quick-spec `matchup-visualization-revision.md`) are necessary but not
sufficient; the player also needs to **see what is being countered**.

This quick-spec proposes a UI-presentation revision: add **visual enemy
representation** to the dungeon-run view — visible enemy figures (or at
minimum visible archetype icons) alongside the existing progress bar.

This is NOT a request for a fail state. The cozy-fantasy promise (Pillar 1:
no fail state) is preserved. What changes is *visibility of what's already
happening under the hood*.

---

## Why this is a quick-spec, not a full GDD revision

The change does NOT modify:
- The combat resolution math in `design/gdd/combat-resolution.md` §D
  (battles still resolve abstractly per ADR-0010)
- Any economy / kill-bonus / floor-clear rule
- The dungeon run state machine in `design/gdd/dungeon-run-orchestrator.md` §C
- Any ADR (existing combat resolver + matchup resolver remain unchanged)

The change DOES modify:
- The dungeon-run view rendering in `design/ux/hud.md` (currently
  progress-bar-only)
- The Formation Assignment Screen's preview area (V1.0+ — author against
  this contract from day one)
- The `dungeon-run-view` Presentation-layer epic story (Sprint 5+)

This is a presentation revision, not a rule change — quick-spec scope.

---

## Decision

### Add per-archetype enemy representation to the dungeon view

**Old presentation** (per prototype's actual render + current HUD spec):

```
Floor 3: Wolf Hollow — primary: Beast
Favors: Knight
[==============23%========================]
```

A label and a progress bar. The combat is invisible.

**New presentation** (this quick-spec):

```
Floor 3: Wolf Hollow
+----------------------+    +----------------------+
|    [Knight portrait] |    | [Beast enemy sprite] |
|    [Mage portrait]   |    | [Beast enemy sprite] |
|    [Rogue portrait]  |    | [Beast enemy sprite] |
+----------------------+    +----------------------+
        Formation                   Enemies
[==============23%========================]
        Progress to floor clear
```

Two side-by-side composition slots — formation (left) and enemies (right) —
plus the existing progress bar below. The combat is visible.

### What "enemy representation" means at MVP

- **Pixel sprites if available** (per Art Bible Section 2 sprite-pride
  promise): each enemy in the floor's `enemy_list` is rendered as a small
  sprite (32-48 px) in the enemies slot. Stacked vertically or in a small
  grid.
- **ColorRect placeholders if sprites are not yet authored** (Sprint 5
  intermediate state): a colored swatch keyed to archetype:
  - Bruiser → muted rust
  - Caster → dusk purple
  - Armored → moss green
  - (V1.0 archetypes use additional palette keys per Art Bible §1)
- Enemy count is shown numerically below or inline if the count > 3 (avoids
  visual clutter at high counts).
- A killed enemy fades out (1-second fade per ADR-0010 combat-resolution
  contract); the slot collapses to surviving enemies.

### What "enemy representation" does NOT mean at MVP

- **NOT a real-time combat animation.** The cozy-fantasy idle promise is
  that combat is abstract; visualizing the participants does not require
  visualizing the combat itself.
- **NOT health bars per enemy.** Players don't need per-enemy HP tracking;
  the floor progress bar is the aggregate.
- **NOT manual targeting.** Players cannot click an enemy to focus
  attacks — combat resolution is automated per ADR-0010.

The enemies are visible *participants*, not *interactive entities*.

---

## Cross-system impact

| Document | Action | Sprint |
|---|---|---|
| `design/gdd/dungeon-run-orchestrator.md` | Add §F.x "Visual Representation Contract" subsection citing this quick-spec | Sprint 5 |
| `design/gdd/biome-dungeon-database.md` | Cross-link from §C floor schema (`enemy_list[].enemy_id` → resolved enemy provides `sprite_path`) — already in place per Sprint 3 S3-M2 EnemyData schema; verify the path convention for the new visual treatment | Sprint 5 (verification only; no new schema work) |
| `design/ux/hud.md` | Update dungeon-run view rendering spec — add formation slot + enemy slot side-by-side composition, retain existing progress bar | Pre-Sprint-5 (this quick-spec is the source) |
| Future `design/ux/dungeon-run-view.md` (Presentation epic) | Author against this composition contract from day one | Sprint 5-6 |
| Future `design/ux/matchup-assignment-screen.md` (V1.0+) | Reuse the formation-slot + enemy-slot composition for the assignment-preview UI | V1.0 |
| `design/ux/interaction-patterns.md` | Add new pattern: `formation-vs-enemies-composition` (side-by-side participant display) | Sprint 5 |
| `design/registry/entities.yaml` | No change — sprite paths already in EnemyData per Sprint 3 | — |
| Art bible | No change to color philosophy; verify archetype palette keys are documented in Section 1 (likely already covered) | — |
| ADRs | No new ADR | — |

---

## Implementation hint (for Sprint 5+ implementer)

- The dungeon-run view is in the Presentation-layer epic; story will be
  authored in the `dungeon-run-view` epic when Presentation-layer
  decomposition begins (Sprint 5+).
- Data flow: dungeon-run-orchestrator publishes the current floor's
  `enemy_list` to the view; the view subscribes and renders one
  formation-slot + N enemy-slots accordingly.
- Sprite sourcing: `EnemyData.sprite_path` per Sprint 3 S3-M2 schema
  (`assets/art/enemies/{id}/sprite.png` convention). PNGs land in art-spec
  passes via `/asset-spec` (Sprint 5-6).
- ColorRect fallback for the intermediate state when sprites are not yet
  authored: render the archetype-keyed palette swatch behind a small
  archetype-icon (a stylized bruiser-fist / caster-eye / armored-shield).
  This is the same pattern the prototype used — it's acceptable as MVP
  release art if sprite production slips.
- Death animation: cross-reference the existing `enemy_death` animation
  contract per ADR-0010 + EnemyData.death_anim_key. ColorRect placeholders
  use a 1-second fade-to-transparent in lieu of a real death anim.

---

## Acceptance criteria for the quick-spec itself

- [ ] When implemented, ≥1 non-developer playtester naturally describes
  the dungeon-run view as "my heroes fighting these enemies" (or
  equivalent participant framing) — not as "watching a progress bar"
- [ ] When implemented, the player can identify the floor's archetype
  composition without reading the floor name (visual sufficiency)
- [ ] When implemented, killed enemies visibly disappear within ~1 second
  of the kill — preserves the satisfying-feedback loop from the
  prototype's emergent-spend gravity
- [ ] No layout regression: formation + enemies + progress bar fit the
  existing dungeon-run view canvas at all target resolutions (1280×800,
  1920×1080, mobile portrait)
- [ ] ColorRect fallback (when sprites not yet authored) is visually
  distinct enough that archetype is identifiable at 32 px — required to
  avoid the prototype's regression where archetype was conveyed by text
  alone
- [ ] Standard accessibility tier maintained: archetype is communicated
  via shape (icon overlay on the swatch) + position (left = formation,
  right = enemies), NOT color alone
- [ ] Reduced-motion preference: enemy-death fade is replaced by
  instant disappear (no fade)

---

## Open questions

1. **Do living enemies need any idle animation?** Recommended: NO at MVP.
   A pixel-sprite at 32-48 px doesn't need to animate to be a participant;
   the combat is invisible by design. V1.0 may add subtle 2-frame idle
   loops for warmth (per Art Bible's "warm miniature" identity), but it's
   not blocking.
2. **What about boss enemies?** Boss floor (F5 with Ancient Rootking) shows
   a single enemy — should it be larger / centered / spotlit? Recommended:
   yes, scale Boss sprites at 1.5× the standard enemy size and add a
   subtle lantern-gold outline (the same palette token as Strong-matchup
   highlights per the parallel quick-spec). Pillar 4 (HD-2D pixel pride)
   benefits from boss-moments getting visual weight.
3. **Spawn animation for enemies that appear after a kill (e.g., reinforcements)?**
   Out of MVP scope per `design/gdd/biome-dungeon-database.md` §C
   (deterministic enemy_list, no dynamic spawns). Only relevant if V1.0
   adds dynamic spawn floors; defer.
4. **Should the player be able to scroll / pan if the enemy slot has more
   enemies than fit visibly?** Recommended: NO — cap the visible enemy
   slot at 6 visible at a time; if the floor has more, show "+N more"
   indicator. Idle game UX should not require navigation gestures during
   the cozy-watch loop.
5. **Touch-tap on an enemy — is that a meaningful affordance?**
   Recommended: tooltip-on-tap (shows enemy name + archetype + per-hero
   matchup state), but NOT a targeting affordance. Tooltip is the
   information surface; combat resolution stays automated.

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
> 2. **The multiplier label is not self-explanatory.** [...]

This quick-spec addresses item #1. Item #2 is addressed by the parallel
quick-spec at `design/quick-specs/matchup-visualization-revision.md` (S4-N1).

Together, the two quick-specs propagate the prototype's headline findings
into actionable Sprint 5+ Presentation-layer work.

---

## Verdict (this quick-spec's own status)

**APPROVED** for propagation when the dungeon-run-view Presentation-layer
epic decomposes (Sprint 5+). The downstream GDD updates can be made in
lockstep with the implementation story. The ColorRect fallback path means
this revision is shippable even if sprite art slips behind the
implementation timeline.
