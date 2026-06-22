# ADR-0025: Hero Animation ↔ Kill-Schedule Sync — Two Presentation Clocks, Never the Tick

## Status

Accepted

> Authored **and** ratified 2026-06-22 under the autonomous `hero-combat-animation`
> epic directive, **solo** review mode (`production/review-mode.txt` = solo → no
> separate director gate). Ratified to **Accepted** so Phase 1 (Story 005+) is not
> auto-blocked per the "stories referencing a Proposed ADR are auto-blocked" rule.
> A **veto-after** window applies (ADR-0024 cadence): the user may veto or amend any
> "recorded for veto" decision below; this ADR is the binding contract for Stories
> 005–015 until then.

## Date

2026-06-22 (authored under the standing directive to finish the hero-combat-animation
epic; this is the BLOCKING Phase-0 architecture gate the GDD #35 §C.3 sync model and
§C.9 hot-path rule were written against)

## Last Verified

2026-06-22

## Decision Makers

- Author (user) — final decision; set the "put heroes on the dungeon screen + animate them" directive and the autonomous epic goal
- godot-specialist — `_process` vs tick-handler placement, `Tween` lifecycle, `SpriteSheetAnimator` reuse (advisory)
- technical-director — the 20 Hz zero-alloc hot-path invariant + combat-model non-interference with ADR-0010 (advisory)

## Summary

Combat in this game is **aggregate and tick-deterministic**: `CombatResolver` is
stateless, emits **zero signals**, and resolves a **party-aggregate DPS** closed-form
**kill schedule** (per-kill `KillEvent.kill_tick`, no RNG, no time reads — ADR-0010).
The resolver produces **discrete kill events only** — there are **no per-hero attack
events**. So "animate the heroes reacting to combat" cannot mean "play a hero's attack
when that hero swings," because no such per-hero event exists.

This ADR locks how hero animation timing is driven given that constraint:

**Hero animation runs on TWO independent presentation clocks, and NEITHER is the 20 Hz
combat tick:**

1. **Idle loop** — a free-running `_process` accumulator on each `SpriteSheetAnimator`
   (the already-shipping component), independent of combat entirely.
2. **Reaction beats** — triggered by the **existing human-frequency orchestrator
   signals** (`enemy_killed`, `boss_killed`, `floor_cleared_first_time`,
   `run_defeated`), realized as `Tween`-based beats (Phase 2, no new art) or one-shot
   frame strips (Phase 3).

The combat tick handler `dungeon_run_view.gd._on_tick_fired` (20 Hz) **gains nothing** —
it stays the two label assignments it is today. Animation is **cosmetic theater
punctuated by real signals**, not a per-hero combat simulation. Reaction is
**party-aggregate** (a kill pulses the *whole party*, mirroring the single HP pool),
which is truthful to the aggregate-DPS model. `reduce_motion` suppresses all of it.

An **optional** richer mode (Story 013) may precompute a synthetic *per-hero* action
cadence from the deterministic kill schedule **at loop-entry** and replay it via
`_process` — but it is explicitly **forbidden from polling the schedule per tick**.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Presentation only — `dungeon_run_view` + new `PartyDioramaLayer` / `HeroCombatAnimator` nodes (`TextureRect` + `SpriteSheetAnimator` + `SceneTreeTween`). NO autoload, NO new gameplay state, NO combat-model change. |
| **Knowledge Risk** | LOW — `Node._process(delta)`, `Node.create_tween()` / `SceneTreeTween`, `TextureRect`, signal `connect`/`disconnect`, and the project's own `ClassSpriteFactory` + `SpriteSheetAnimator` are all stable since 4.0 and already shipping on Recruit cards + the Hero Detail modal. No post-cutoff API surface. |
| **References Consulted** | ADR-0010 (combat resolver — stateless, zero-signal, per-event `KillEvent.kill_tick` schedule); `design/gdd/hero-combat-animation.md` (#35) §C.3/§C.5/§C.8/§C.9 + §D.5; `design/gdd/dungeon-run-view.md` (#24, hot-path invariant + OQ-24-6); `assets/screens/dungeon_run_view/dungeon_run_view.gd` (`_on_tick_fired`, signal subscriptions, `_build_wireframe_once`); `src/ui/sprite_sheet_animator.gd` + `src/ui/class_sprite_factory.gd`; `.claude/rules/engine-code.md` (zero-alloc hot path); `prestige_fade_animation_test` (reduce-motion precedent, AC-PR-18) |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | (1) Story 007 extends the Story-012 per-tick budget test to prove `_on_tick_fired` stays **zero-allocation** with N heroes + animators + (idle or beating) on screen; (2) a reduce-motion test (prestige-fade pattern) proving idle holds frame 0 and every beat is suppressed; (3) a lifecycle test proving `on_exit` kills all tweens + frees animators with no orphaned `_process`; (4) headful render of the dungeon view with the party present + a kill beat. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | **ADR-0010** (the combat model this ADR animates *around* — aggregate DPS, stateless zero-signal resolver, the deterministic per-event kill schedule that is the *only* timing source Story 013 may use); **ADR-0008** (theme cascade — hero/animator nodes must not break sibling theme inheritance); **ADR-0019** (HD-2D layering — heroes compose in the sharp focal plane); **ADR-0021** (defeat-state pivot — the `run_defeated` slump beat honors the dignified, no-fail defeat contract); **ADR-0007** (reduce-motion settings persistence seam) |
| **Supersedes** | None |
| **Enables** | Stories 005–015 of the hero-combat-animation epic (heroes on screen, idle wiring, reaction beats, defeat/victory beats, reduce-motion, the Phase-3 action-frame state machine, and the optional Story-013 synthetic cadence) |
| **Blocks** | Any hero-combat-animation Phase-1+ implementation story until this ADR is **Accepted** (satisfied as of 2026-06-22) |

## Context

### Problem Statement

GDD #35 puts the party's heroes on `dungeon_run_view` and animates them reacting to
combat. The naïve mental model — "play hero A's attack animation when hero A attacks" —
**does not map onto this game's combat**. The resolver (ADR-0010) computes a
party-**aggregate** DPS and a closed-form **kill schedule**; it attributes no damage to
individual heroes and emits no per-hero events. The screen is also the project's
**canonical hot-path performance surface**: `_on_tick_fired` runs at 20 Hz and is
constrained to near-zero work (two label assignments) by the engine-code zero-alloc
invariant and the Story-012 budget test. A decision is needed — *before* any Phase-1
code — for how animation timing is driven without (a) inventing per-hero combat events
or (b) loading the 20 Hz hot path.

### Current State (pre-this-ADR)

- `CombatResolver` is `class_name CombatResolver extends RefCounted`, **zero class-scope
  `var`, zero `signal`**, not an autoload (ADR-0010). It returns `CombatTickEvents`
  (foreground, per-event `kills: Array[KillEvent]`) or `CombatBatchResult` (offline,
  aggregate-only). Each `KillEvent` carries a `kill_tick: int`.
- `DungeonRunOrchestrator` dispatches the human-frequency signals the screen already
  subscribes to in `on_enter`: `enemy_killed(tier, archetype, advantaged)`,
  `boss_killed(enemy_id)`, `floor_cleared_first_time(floor_index, biome_id, losing_run)`,
  `run_defeated(floor_index, biome_id)`, `state_changed(new, old)`. (`HeroRoster.hero_leveled`
  and `TickSystem.tick_fired` are also subscribed.)
- `dungeon_run_view.gd._on_tick_fired` updates the tick + kill labels only. The screen
  renders heroes today **only as text tiles** in the greybox Party HUD — no hero sprites.
- `ClassSpriteFactory.get_idle_frames(class_id)` (4-frame sheet-slice, `ResourceLoader.exists`
  disk-first) + `SpriteSheetAnimator.setup(target, frames, fps)` (`_process` accumulator
  frame-swap; disables `_process` when frames ≤ 1) are validated and shipping elsewhere.

### Constraints

- **20 Hz zero-alloc hot path is sacred** (engine-code rule + Story-012 gate): no
  allocation, format string, `tr()`, `create_tween()`, or node creation may enter
  `_on_tick_fired`. This is the dominant constraint.
- **Do not change combat** (ADR-0010): the resolver stays stateless, zero-signal,
  aggregate-DPS; foreground/offline parity must not be disturbed. Animation is a pure
  consumer of already-emitted signals.
- **Reuse, don't rebuild**: the validated idle-animation components must carry Phases 1–2
  with no new framework and no new art.
- **Accessibility**: `reduce_motion` must suppress all idle + reaction motion (precedent:
  `prestige_fade_animation_test` AC-PR-18), read at beat time so a mid-run toggle is honored.
- **Read-only screen**: animation nodes must not steal input (`MOUSE_FILTER_IGNORE` whole
  subtree; `z_index` does not gate input picking).

## Decision

**Drive hero animation from two independent presentation clocks — a free-running
`_process` idle loop and signal-triggered reaction beats — neither of which is the 20 Hz
combat tick. The tick handler gains nothing. Reaction beats are triggered only by the
existing human-frequency orchestrator signals and are party-aggregate. `reduce_motion`
suppresses all of it. A per-hero synthetic cadence is permitted (Story 013) only if
precomputed at loop-entry from the deterministic kill schedule and replayed via
`_process` — never polled per tick.**

### Architecture

```
   COMBAT (unchanged — ADR-0010)                 PRESENTATION (this ADR)
   ─────────────────────────────                 ────────────────────────
   CombatResolver (stateless, 0 signals)
     └─ closed-form kill schedule
        (KillEvent.kill_tick, no RNG)
                │
                ▼
   DungeonRunOrchestrator
     ├─ tick_fired (20 Hz) ───────────────►  _on_tick_fired:  2 label assigns ONLY.
     │                                         ZERO animation work. (Story-007 budget test)
     │
     ├─ enemy_killed / boss_killed ───────►  reaction-beat handler (human frequency):
     ├─ floor_cleared_first_time ─────────►    coalesce (BEAT_THROTTLE_MS) → start a Tween
     └─ run_defeated ─────────────────────►    (Phase 2) or one-shot frame strip (Phase 3)
                                                       │
   SpriteSheetAnimator._process(delta) ────────────────┘  idle loop, free-running,
     (own clock; disables _process when frames ≤ 1)        INDEPENDENT of the tick

   reduce_motion (read at beat time) ──► idle holds frame 0; every beat suppressed.

   [OPTIONAL Story 013] at loop-entry, read the loop's KillEvent.kill_tick[] ONCE,
     precompute a per-hero action cadence, replay via _process. NEVER per-tick polling.
```

### Key decisions (recorded for veto)

- **Two clocks, never the tick.** The 20 Hz `_on_tick_fired` is off-limits to animation.
  Idle is a `_process` accumulator; beats are signal-triggered. This is the single
  load-bearing rule the rest of the epic builds on.
- **Reaction is party-aggregate, not per-hero.** A kill pulses the whole party (GDD #35
  §C.5). This is *truthful* to the aggregate-DPS / single-HP-pool model — per-hero attack
  attribution would be a fiction the resolver can't back (mirrors the aggregate-HP
  decision in the UX spec). Resolves GDD #35 OQ-35-1: "which hero animates?" → **the
  party, together.**
- **Beats coalesce (anti-strobe).** Rapid kill cascades collapse to one beat within
  `BEAT_THROTTLE_MS` (GDD #35 §D.5), via an **injectable clock seam** (not raw
  `Time.get_ticks_msec()`) so the throttle is deterministically testable — per the
  prestige-audio-throttle lesson (a 0-sentinel + engine-uptime clock mis-fires at low
  uptime; use a `-window` sentinel + injectable clock).
- **Reduce-motion read at beat time**, not cached at build — honors a mid-run toggle
  (GDD #35 §E.6). Idle → static frame 0 (heroes stay *present*; presence ≠ motion).
- **Story 013 is allowed but gated.** Synthetic per-hero cadence may read
  `KillEvent.kill_tick[]` **once per loop at loop-entry** and replay via `_process`. It
  **must not** read the schedule, allocate, or branch per tick. If Story 013 cannot meet
  the hot-path rule, it is dropped — it is explicitly optional.
- **Lifecycle is owned by `on_exit`.** All tweens are killed and the `PartyDioramaLayer`
  (and its animators) freed on screen exit; no tween or `_process` outlives the run.

## Alternatives Considered

### Alternative 1: Cosmetic-react — two clocks, signal-triggered beats — CHOSEN

- **Description**: Free-running `_process` idle + reaction beats fired by the existing
  human-frequency signals. The tick handler is untouched.
- **Pros**: Trivially preserves the zero-alloc hot path (nothing is added to it); reuses
  the validated `ClassSpriteFactory`/`SpriteSheetAnimator`/`Tween` stack; ships Phases 1–2
  with **no new art**; zero combat-model risk (pure signal consumer); aggregate reaction
  is truthful to aggregate combat.
- **Cons**: No per-hero attribution in MVP (a kill pulses the whole party, not "the rogue
  who landed it") — acceptable and intentional.
- **Rejection Reason**: N/A — chosen.

### Alternative 2: Poll the kill schedule / hero state inside `_on_tick_fired` (20 Hz) — REJECTED

- **Description**: Each tick, read the schedule or per-hero state and drive animation.
- **Cons**: **Directly violates the zero-alloc hot-path invariant** (Story-012 gate); puts
  per-frame branching/allocation on the one surface the whole project protects. This is
  precisely the anti-pattern this ADR exists to forbid.
- **Rejection Reason**: Breaks the hot-path budget; non-negotiable.

### Alternative 3: Make `CombatResolver` emit per-hero attack signals — REJECTED

- **Description**: Change combat to attribute damage per hero and emit per-hero events so
  each hero animates on its own swing.
- **Cons**: Violates ADR-0010 on every axis (stateless, zero-signal, aggregate DPS); a
  large, high-risk combat-model change for a cosmetic gain; jeopardizes foreground/offline
  parity (AC-COMBAT-10). The "per-hero attack" it would emit is itself a fabrication — the
  model has no per-hero damage.
- **Rejection Reason**: Disproportionate, parity-breaking, and contradicts the combat model.

### Alternative 4: Synthetic per-hero cadence from the schedule — DEFERRED (Story 013, optional)

- **Description**: Precompute a per-hero action cadence from the deterministic
  `KillEvent.kill_tick[]` at loop-entry; replay via `_process`.
- **Pros**: Richer per-hero theater while staying cosmetic and deterministic.
- **Cons**: Added complexity; only viable if it never touches the per-tick path.
- **Rejection Reason**: Not rejected — **deferred** and gated behind the hot-path rule.
  MVP ships on Alternative 1; Story 013 is a bonus, not a dependency.

## Consequences

### Positive

- The 20 Hz hot path is provably untouched — animation cannot regress it (Story-007 test
  is the CI gate).
- Phases 1–2 deliver the full player-visible win (heroes present, idle-animating, reacting
  to kills/boss/defeat/victory) with **no new art** and **no combat change** — directly
  serves the "UI/UX and functions not progressing" feedback.
- Reuses only validated components; no new animation framework to maintain.
- Aggregate reaction keeps the presentation honest to the model and dovetails with the
  aggregate-HP UX decision.

### Negative

- No per-hero attribution in MVP (intentional; Story 013 may add a synthetic cadence).
- A second clock (idle `_process` + transient beat tweens) exists alongside the tick — the
  lifecycle teardown must be disciplined (covered by the `on_exit` rule + a test).

### Neutral

- Beats are throttled/coalesced, so on a heavy kill cascade the party pulses once, not 10×
  — a deliberate feel choice (calm/cozy register), not a fidelity loss.
- Animation nodes are `MOUSE_FILTER_IGNORE`; the read-only screen contract is unchanged.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| A future change adds animation work to `_on_tick_fired` (hot-path regression) | MEDIUM | HIGH | Story 007 extends the Story-012 per-tick zero-alloc budget test as a **blocking CI gate**; this ADR names the rule explicitly |
| Beat strobing on a rapid kill cascade | MEDIUM | LOW | `BEAT_THROTTLE_MS` coalescing via an injectable clock seam (GDD #35 §D.5); deterministically tested |
| Tween / `_process` leak across run-end or screen exit | LOW | MEDIUM | `on_exit` kills all tweens + frees `PartyDioramaLayer`; lifecycle test asserts no orphan |
| `reduce_motion` not honored on a mid-run toggle | LOW | LOW | Flag read **at beat time**, not cached; reduce-motion test (prestige-fade pattern) |
| Story 013 quietly reintroduces per-tick polling | LOW | HIGH | ADR forbids it in writing; the same Story-007 budget test guards it; Story 013 is droppable |

## Performance Implications

| Metric | Before | Expected After | Budget |
|--------|--------|----------------|--------|
| `_on_tick_fired` work (20 Hz) | 2 label assignments, zero alloc | **unchanged** — 2 label assignments, zero alloc | 0 allocations/tick (Story-012/007 gate) |
| Idle animation | none | N × `SpriteSheetAnimator._process` frame-swap (N ≤ `formation_size`); no per-frame alloc | 16.6 ms frame (idle screen, never CPU-bound) |
| Reaction beats | none | transient `Tween`s, started on human-frequency signals (≤ a few/sec after coalescing), GC'd on finish | negligible |
| Draw calls | biome + HUD + enemies | + N textured hero quads | <200 draw calls/frame |
| Memory | — | N `TextureRect`s + shared sliced `AtlasTexture` frames (reused via `ClassSpriteFactory`) | 256 MB mobile / 512 MB PC |

## Validation Criteria

- [x] ADR authored against ADR-0010's actual combat contract (stateless, zero-signal,
      per-event `KillEvent.kill_tick` schedule) and GDD #35 §C.3/§C.5/§C.8/§C.9/§D.5.
- [ ] **Story 007**: the Story-012 per-tick budget test, extended to assert
      `_on_tick_fired` allocates nothing with the party present + idle-animating + a beat
      in flight — green in CI.
- [ ] **Reduce-motion test**: with `reduce_motion` on, idle holds frame 0 and every
      reaction beat is suppressed; toggling mid-run is honored at the next beat.
- [ ] **Lifecycle test**: after `on_exit`, all beat tweens are killed and
      `PartyDioramaLayer` + animators are freed; no orphaned `_process`.
- [ ] **Headful render**: dungeon view with the party present + an `enemy_killed` beat
      firing (QA evidence PNG).
- [ ] User **veto-after** window on the "recorded for veto" decisions (aggregate-only MVP
      reaction; Story 013 deferral; beat-coalescing feel).

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|--------------|--------|-------------|----------------------------|
| `design/gdd/hero-combat-animation.md` (#35) | Hero Combat Presence | §C.3 animation↔combat sync model | Locks the two-clocks-never-the-tick model |
| #35 | Hero Combat Presence | §C.9 20 Hz zero-alloc hot-path rule | Formalizes the rule + names the Story-007 CI gate |
| #35 | Hero Combat Presence | §C.5 aggregate attribution | Party-aggregate reaction; resolves OQ-35-1 (the party animates together) |
| #35 | Hero Combat Presence | §C.8 / §E.6 reduce-motion | Idle holds frame 0; beats suppressed; flag read at beat time |
| #35 | Hero Combat Presence | §D.5 beat coalescing | `BEAT_THROTTLE_MS` + injectable clock seam |
| `design/gdd/dungeon-run-view.md` (#24) | Dungeon Run View | OQ-24-6 run-end animation | The `run_defeated` slump + first-clear victory beats hook the existing run-end overlay (Story 009) |
| ADR-0010 | Combat Resolver | Statelessness + aggregate parity preserved | Animation is a pure signal consumer; resolver is untouched |

## Related

- **ADR-0010** (combat resolver — the model this animates around: aggregate DPS, zero
  signals, the deterministic `KillEvent.kill_tick` schedule)
- **ADR-0021** (defeat-state pivot — the dignified no-fail defeat the slump beat honors)
- **ADR-0008** (theme cascade), **ADR-0019** (HD-2D layering), **ADR-0007** (reduce-motion persistence)
- GDD: `design/gdd/hero-combat-animation.md` (#35) §C.3/§C.5/§C.8/§C.9/§D.5; `design/gdd/dungeon-run-view.md` (#24) OQ-24-6
- UX: `design/ux/dungeon-run-view.md` § "Hero Combat Presence (GDD #35)"
- Art: `design/art/art-bible.md` §5 "Dungeon Combat Presence" + "Per-Class Action Poses"
- Components: `src/ui/class_sprite_factory.gd`, `src/ui/sprite_sheet_animator.gd`
- Hot path: `assets/screens/dungeon_run_view/dungeon_run_view.gd` `_on_tick_fired`
- Precedent: `prestige_fade_animation_test` (reduce-motion AC-PR-18)
