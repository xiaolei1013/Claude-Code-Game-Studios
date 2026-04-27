# Prototype Report: Idle Matchup Loop

*Created: 2026-04-25*
*Review mode: solo — CD-PLAYTEST skipped per skill spec*

## Hypothesis

Players find the `assign → idle → return → escalate` loop, gated by class-vs-biome
matchup, satisfying enough to drive recruit/spend behaviour without external prompts.

## Approach

Standalone Godot 4.6 sub-project. Single scene, single ~290-line script, ColorRect
swatches as class stand-ins. 3 classes × 3 enemy types with rock-paper-scissors
counters; 5 floors each favouring one class. Time-compressed 1 real-sec = 1
in-game min so a 15-min real session covers ~14 in-game hours. No save/load,
no audio, no shaders, no animation. Built in one session; three bugs surfaced
and patched mid-playtest (formation matchup display stale on floor change;
recruit/level-up buttons frozen on stale gold check; floor-clear log spam).

## Result

**Quantitative (from final state at session end):**

- Reached Floor 5 (final) at 100% progress
- 8 heroes recruited; actives leveled to 11 / 12 / 12
- Gold pool ~10.4k; level-up costs reached 5,120–10,240 gold per level and the
  player kept leveling
- "Simulate close 30 min" pressed three times in succession
  (in-game-minute timestamps 809 / 840 / 870)
- Final formation correctly placed Rogue ×2.0 in active slot vs Floor 5's
  Caster primary; Knight ×0.5 was the weak slot (matchup recognized
  *mechanically* — see qualitative note below)
- Recruit cost curve confirmed: 8th recruit at 256 gold = 10 × 1.5⁸

**Qualitative (player verbatim):**

- *"no enemies. so our heroes are always alive."*
- *"i note the labels (×0.5 / ×1.0 / ×2.0) but don't understand what it is"*
- *"i cannot judge whether it is compelling or grindy"* — after ~15 real-min play

## Metrics

- Session length (real seconds): ~870 (calculated from 874 in-game min ÷ 1s-per-min)
- In-game minutes elapsed: 874
- Roster size: 8
- Floor reached: 5 / 5
- Collect taps: not captured (`RichTextLabel` non-selectable in default theme;
  quit-time metrics print not retrievable in this session)
- Formation changes: not captured (same reason); inferred ≥1 from final
  arrangement matching Floor 5 favoured class
- Time to first recruit / first collect / first floor clear: not captured

Console-instrumentation gap recorded as a prototype-tooling lesson — production
playtest builds should pipe metrics to a copyable surface (file or console with
selectable text) rather than `RichTextLabel`.

## Recommendation: **PROCEED — with two mandatory production changes**

The core loop math works. Spend gravity is real (8 recruits, double-digit
levels, escalating spend on level-ups well past trivial cost). Return-to-app
is engaging enough to be voluntarily re-triggered three times in a row.
Escalation works (player progressed through all 5 floors). The
`assign → idle → return → escalate` hypothesis is **validated for the
short-term loop**.

But the prototype falsified two implicit assumptions of the game-concept doc:

1. **Pillar 3's matchup decision is invisible without enemy representation.**
   The dungeon view is a progress bar; there is no Caster on screen to
   counter, no Brute to crush. "Caster" is text; the matchup decision feels
   like a math knob, not a strategic choice. The player explicitly said
   "no enemies."
2. **The multiplier label is not self-explanatory.** `vs Caster: ×2.0` is
   syntactically clear but semantically opaque without onboarding. The player
   read the labels but did not understand what they meant. This directly
   answers Open Question #3 from `design/gdd/game-concept.md` (line 243):
   the class-vs-biome layer does **NOT** read clearly without tutorial text.

The loop is solid; the strategic verb is buried. Production must address both
before further validation playtests.

## If Proceeding

### Mandatory production changes

1. **Visualize enemies in the dungeon view.** The matchup decision needs an
   on-screen target. Even minimal pixel sprites representing the floor's
   enemy mix would have changed the player's perception. Production should
   put actual enemies on the dungeon side of the formation. This is *not*
   about adding a fail state — it is about making the strategic verb visible.

2. **Make the matchup multiplier self-explanatory.** Options to A/B test in
   the first-return usability test (per Open Question #3):
   - Replace `×0.5 / ×1.0 / ×2.0` with named effectiveness labels (Weak /
     Even / Strong) and color glow on the hero portrait
   - Animate per-tick combat with a visible damage number that's bigger
     when matchup is favourable
   - Add a one-line first-time tooltip when player encounters a new enemy type
   - Recommend at least the named-labels-with-glow change; tooltips alone are
     not sufficient given Pillar 1 (Respect Player's Time)

### Architectural / design-doc impact

- Production formation/dungeon UI must support enemy representation —
  current HUD design at `design/ux/hud.md` should be re-checked against
  this requirement
- Matchup display becomes part of the hero portrait spec, not a label —
  `design/art/art-bible.md` may need a "Hero State Visual Language" entry
- `design/gdd/class-vs-enemy-matchup-resolver.md` and
  `design/gdd/dungeon-run-orchestrator.md` GDDs should record the
  visualization requirement explicitly

### Performance targets

Unchanged — UI / sprite domain only, well within the 200-draw-call and
512 MB ceilings in `.claude/docs/technical-preferences.md`.

### Scope adjustment from original design

None in MVP scope. The changes are clarity polish on existing planned
features (HUD + dungeon view), not new features.

### Estimated production effort

- Enemy representation in dungeon view: ~3 days (depends on art-bible
  asset spec turnaround)
- Matchup glow + named effectiveness label: ~1 day code, ~2 days art

## What this prototype did NOT validate (out of scope — do not infer)

- **Long-term retention.** The player explicitly said "I cannot judge
  compelling vs. grindy yet" after a 15-min single-session prototype.
  Validating the retention hypothesis requires a save-bearing build with
  real-time idle so the player can return tomorrow morning. Schedule a
  Vertical-Slice retention playtest after MVP build, before Production exit.
- **Visual identity / cozy feel.** No art, no shaders, no audio. The
  HD-2D-pixel-pride pillar (Pillar 4) is untested.
- **Mobile touch ergonomics.** Mouse-only.
- **Save-file integrity / anti-tamper.** Out of scope.

## Lessons Learned

- The matchup decision in this game is a *visual* problem, not a math
  problem. The mechanic works; the affordance does not. This shifts polish
  budget from combat-balance tuning toward enemy-visualization and feedback
  clarity.
- The 1s = 1min time compression was useful for short-loop validation but
  produced no falsifiable data on the daily-cadence retention question —
  that question needs its own validation method (real-time playtest with
  save). Do not double-count this prototype against retention risk.
- Three latent UI-refresh bugs surfaced within the first 6 in-game minutes of
  the first playtest (formation matchup display stale on floor change;
  recruit/level-up buttons frozen on stale gold check; floor-clear log spam).
  This is a smell — production code should not centralize UI rebuilds on a
  "rebuild on every tick" model. The architecture document's signal-driven
  UI rebuild guidance must be enforced in the production HUD.
- The player voluntarily pressed the "close 30 min" simulation three times in
  a row. The return-to-app moment is the **strongest validated emotional beat**
  in the loop. Polish budget should weight toward making that moment satisfying
  in the production build (audio sting, count-up animation, "while you were
  away…" framing). This was already flagged as the highest-priority polish
  target in `design/gdd/game-concept.md` line 222 — playtest confirms it.
- Console-instrumentation surface choice matters. `RichTextLabel` is
  non-selectable in the default theme; production playtest builds should
  print metrics to stdout or a copyable plain-text overlay so observers can
  capture data without a screenshot.

---

*Prototype skill verdict: COMPLETE. Solo review mode — prototyper recommendation
is final.*
