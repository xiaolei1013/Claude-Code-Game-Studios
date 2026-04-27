# Prototype: Idle Matchup Loop

> **PROTOTYPE — NOT FOR PRODUCTION**
> Created 2026-04-25. Do not import from this directory in `src/`.
> Do not refactor this code into production — production must be written from scratch.

## Core Question

> Does the `assign → idle → return → escalate` loop — gated by class-vs-biome
> matchup — produce a satisfying first-return moment?

## How to run

This is a **standalone Godot 4.6 sub-project** (separate `project.godot`). It is
isolated from the main project so the production autoloads (TickSystem,
DataRegistry) do not pollute the test.

```bash
godot --path prototypes/idle-matchup-loop
# or open the project in the Godot editor and press F5
```

If you do not have Godot 4.6 on PATH, point your installed editor at
`prototypes/idle-matchup-loop/project.godot` via Project Manager → Import.

## What's in the build

- 3 hero classes (Knight, Mage, Rogue) — distinguished by color swatch only
  (no pixel art; that is a deliberate omission)
- 3 enemy types (Brute, Caster, Beast) with rock-paper-scissors counters
- 5 floors, each with one primary enemy type favoring one class
- Recruit / level-up / formation toggle (max 3 active)
- A "Simulate: close 30 min" button that fast-forwards offline accumulation
  and prompts the return-to-app collect — this is the highest-value test
- Time compression: **1 real second = 1 in-game minute**. Documented bias:
  this likely flatters the loop versus real cadence; weigh observations
  accordingly.

## Time budget

Aim for one ~10 minute self-playtest, then 2–3 sessions with external
playtesters of 5–10 minutes each. Total elapsed effort: ~2 hours.

## Playtest protocol

For each session, observe and record:

1. **Time-to-first-comprehension** — how long before the playtester says (or
   demonstrates) they understand: "I recruit → I assign → time passes → I
   come back and collect"? Goal: under 90 seconds, **without explanation**.

2. **Class-vs-biome matchup legibility** — does the playtester notice the
   `Favors:` line and the per-slot `vs Brute: ×0.5` / `×2.0` multipliers
   without prompting? Did they reassign formation when descending to a floor
   that punishes their current composition? **Y/N + the moment they noticed.**

3. **First-return feel** — press "Simulate: close 30 min". Did the
   `Welcome back. +N gold pending` moment land emotionally? Use the test:
   *"Did you smile, lean forward, or ignore it?"* Be honest.

4. **Spend gravity** — after collecting offline loot, did the playtester
   *want* to spend it on a recruit/level-up/floor descent before doing
   anything else? If yes, the loop closes. If no, it does not.

5. **Stop point** — at what point did the session naturally end? "Out of
   things to spend on" is the target. "Bored" is a fail.

## Metrics auto-collected

On window close, the prototype prints to the console:

- Session length (real seconds)
- Elapsed in-game minutes
- Roster size
- Final gold + floor reached
- Collect taps
- Formation changes (proxy for engagement with the matchup decision)
- Time-to-first-recruit / first-collect / first-floor-clear (all in
  in-game minutes)

## What this prototype intentionally does NOT validate

- Long-term retention (no save/load — restart resets state)
- Visual identity (no art, no shaders, no animation)
- Audio feel (no audio at all)
- Mobile touch ergonomics (mouse only)
- Save-file integrity / anti-tamper (out of scope)

The next step after this prototype, regardless of result, is **NOT** to
polish this build. The result feeds back into the GDD and the production
build is written from scratch in `src/`.

## Output

Findings go in `REPORT.md` (sibling to this README) using the template from
the `/prototype` skill. Do not edit the prototype code based on playtest
findings — the prototype is a single-shot test, not an iterative build.
