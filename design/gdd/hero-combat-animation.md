# Hero Combat Presence & Animation — GDD #35

> **Status: First-pass DRAFT 2026-06-22** authored under the `hero-combat-animation`
> Presentation-layer epic, Story 001. All 8 required sections (A–H) + 2 supplemental
> (I Open Questions & ADR Candidates, J Implementation Sequencing). Review mode: **solo**.
> **Forward-design** (not reverse-documentation): the system is not yet implemented —
> this GDD specifies the contract that Phases 1–4 build against. ADR-0025 (Story 004)
> formalizes the animation↔kill-schedule **sync model + hot-path rule**; this GDD owns
> the *what* (which beats animate, how heroes map onto aggregate combat, the cozy/
> read-only pillar preservation, reduce-motion behavior). Run `/design-review` after.

---

## A. Overview

**Hero Combat Presence & Animation** puts the player's dispatched heroes onto the
**Dungeon Run View** (GDD #24) and animates them reacting to combat. Today that screen
renders the biome background, an **aggregate** party-HP bar, the enemy lineup, tick/kill
counters, and a run-end overlay — but **not the heroes themselves**. The one screen the
player watches during the core loop shows everything *except* the heroes they recruited
and formed up. This system closes that gap.

It does **not** change combat. Combat remains the deterministic, tick-based,
party-**aggregate**-DPS model owned by `CombatResolver` + `DungeonRunOrchestrator`
(ADR-0010): the resolver emits **discrete kill events only** — there are no per-hero
attack events, no per-hero damage, no per-hero targeting. Therefore hero animation is
**scheduled cosmetic theater punctuated by the real combat signals that already fire**
(`enemy_killed`, `boss_killed`, `floor_cleared_first_time`, `run_defeated`,
`state_changed`), **not** a faithful per-hero combat simulation. The system renders one
animated hero sprite per occupied formation slot (count is **data-driven** —
`roster_config.formation_size`, default 3), drives a looping idle animation, and plays
short **reaction beats** when the combat signals arrive.

The work **reuses** the project's validated idle-animation components rather than
building a new framework: `ClassSpriteFactory.get_idle_frames(class_id)` (sheet-slicing,
`FRAME_COUNT = 4`) + `SpriteSheetAnimator` (`_process`-driven frame-swap at
`IDLE_FPS = 6.0`), already shipping on Recruit cards and the Hero Detail modal. Phases 1–2
ship the full player-visible win — heroes standing in the dungeon, idle-animating, and
reacting to kills / boss / first-clear / defeat — using **tween-based reaction beats that
need no new art** (the same technique as the existing prestige-fade and synergy-glow
tweens). Net-new per-class action art (attack/hit/victory sheets) is deferred to Phase 3.

This is a **presentation-only** system: **zero net-new gameplay state**. Two hard
invariants carry over from GDD #24 and are restated here as binding rules: (1) the
`_on_tick_fired` 20 Hz hot path stays **zero-allocation** — animation never touches it;
(2) the screen is **read-only** — heroes are spectacle, never input targets. ADR-0025
(Story 004) formalizes the timing/sync model and the hot-path rule.

---

## B. Player Fantasy

> *"I recruited these heroes. I chose this formation. Now I watch **them** — not a HP
> bar, not a counter — stand in the dungeon, breathing, striking when an enemy falls,
> punching the air when the floor clears, slumping wearily when the run is lost. The run
> is theirs, and I can see it."*

The cozy register from GDD #24 §B holds without amendment: **observation, not control.**
This system adds the *emotional anchor* the spectator screen has been missing. A party-HP
bar communicates state; **a hero sprite communicates ownership.** When the player sees the
specific classes they assembled standing in the biome they unlocked, the run stops being
an abstract resolve-and-report and becomes "my guild, working." That is the felt payoff.

Two design pillars constrain the fantasy:

- **Pillar 1 — No-Fail-State.** Defeat is never death. The `run_defeated` beat is a
  **dignified slump / weary retreat** (heroes sag, lanterns dim), honoring ADR-0021's
  defeat-as-pivot framing. No gore, no ragdoll, no "you lost" punishment animation. The
  heroes withdraw to fight another day — consistent with the Defeat & Injury System
  (GDD #34) where defeat costs time/condition, not lives.
- **Pillar 2 — The run feels meaningful.** Heroes visibly *reacting* to kills and the
  first-clear makes the ≥2-second perceived-run-duration (GDD #24 §B, S9-M2) land
  emotionally, not just temporally. The victory beat is the cozy celebration GDD #24's
  OQ-24-6 (run-end overlay animation) gestured at.

Critically, **the screen still never takes input** (GDD #24 §B): there is no tap-a-hero,
no select, no command. Heroes are **spectacle, not interface**. Presence is the point —
the heroes are *there* — and presence is independent of motion, which is why the
**reduce-motion** path keeps the heroes fully visible (static) rather than removing them.
Mechanical fidelity is explicitly *not* the goal: the player is not meant to read "which
hero dealt that kill" (combat is aggregate; that information does not exist). The fantasy
is **felt presence + emotional reaction**, delivered honestly within the aggregate model.

---

## C. Detailed Rules

### C.1 What renders

One hero sprite per **occupied formation slot** of the *dispatched* formation. The count
is **data-driven** (`roster_config.formation_size`, default 3, range 1–10) — the system
**never hardcodes 3**; it iterates the formation it is given. The formation is read from
the **run snapshot** (`DungeonRunOrchestrator.run_snapshot`, the deep-copied formation
locked at dispatch per ADR-0001), **not** from the live `HeroRoster` — so what renders is
exactly what was dispatched, even if the roster changes during the run.

Each hero sprite is a **`TextureRect`** (a `Control`), driven by a `SpriteSheetAnimator`
fed `ClassSpriteFactory.get_idle_frames(class_id)`. This is the identical component pair
already shipping on Recruit cards (96 px) and the Hero Detail modal — no new rendering
framework. The hero's `class_id` comes from the snapshot formation slot; the sprite asset
resolves to `assets/art/classes/[class_id]/sprite.png` via `ClassSpriteFactory` (which
uses `ResourceLoader.exists()` disk-first; see §E.3 for the missing-asset path).

### C.2 Idle animation — the baseline state

The default state of every on-screen hero is a **looping breathing idle**: `FRAME_COUNT`
(4) frames at `IDLE_FPS` (6.0), advanced by `SpriteSheetAnimator._process(delta)` on the
animator node. This `_process` driver is **per-sprite and independent of the tick system**
— it is **never** invoked from `_on_tick_fired`. `SpriteSheetAnimator` already disables
its own `_process` when handed ≤ 1 frames, which is exactly the reduce-motion path (§C.8).

### C.3 The animation ↔ combat sync model (central rule — ADR-0025)

Combat emits **discrete signals at human frequency** (a kill lands every ~0.3–3 s of
wall-clock, *not* every 50 ms tick). Hero animation is driven by exactly two clocks, and
**neither is the 20 Hz tick**:

1. **The idle loop** — continuous, `_process`-driven on the animator nodes (§C.2), gated
   by reduce-motion.
2. **Reaction beats** — discrete, triggered by the orchestrator's combat **signals**
   (§C.4), which fire at human frequency in signal handlers.

The 20 Hz `_on_tick_fired` handler gains **no hero-animation work whatsoever** (§C.9).
This is the contract ADR-0025 (Story 004) formalizes — including the alternatives it
rejects (polling the kill schedule on the tick; synthesizing per-hero attack events on
the tick) and *why* (both reintroduce hot-path cost the zero-alloc invariant forbids).
This GDD states the *what*; ADR-0025 states the *how* and records the decision.

### C.4 Reaction-beat catalogue

| Trigger signal (on `DungeonRunOrchestrator`) | Beat | Phase 2 (no art) | Phase 3 (with art) |
|---|---|---|---|
| `enemy_killed(tier, archetype, advantaged)` | **Strike pulse** — brief scale-punch + brightness flash on the party | tween | swap to attack frame where art exists (Story 012) |
| `boss_killed(enemy_id)` | **Boss strike** — a larger, slightly longer strike pulse | tween | attack/heavy frame |
| `floor_cleared_first_time(floor_index, biome_id, losing_run)` | **Victory beat** — a brief cheer/raise, coordinated with the run-end overlay (addresses GDD #24 OQ-24-6) | tween | victory frame |
| `run_defeated(floor_index, biome_id)` | **Slump beat** — heroes sag / lanterns dim, coordinated with the defeat overlay (ADR-0021, Pillar 1 — no gore) | tween | defeat frame |
| `state_changed(new, old)` | **Baseline transition** — entering `RUN_ENDED` stops the idle loop and yields to the terminal beat (victory or slump per `was_last_run_defeated()`) | n/a | n/a |

Phase 2 beats are **tween-based** (`create_tween()` / `SceneTreeTween`), the same
technique as the shipped prestige-fade and synergy-glow effects — **no new art required.**
Phase 3 (Stories 011–012) swaps the tween beat for a real per-class action frame *where
the art exists*, with the tween as the permanent fallback when it doesn't.

### C.5 Which hero reacts (the aggregate-attribution decision)

`enemy_killed` carries `(tier, archetype, advantaged)` — it does **not** carry a hero id,
because combat is aggregate and **no per-hero attribution exists**. Inventing one would be
a lie the rest of the game can't back up. Therefore:

- **MVP (Phase 2): the kill beat plays on the whole party** as a subtle synchronized
  pulse. This is honest (it implies "the party scored a kill," which is true) and simplest.
- **Optional (Phase 3, Story 013): a *synthetic* per-hero action cadence** derived from
  the **deterministic kill schedule** (ADR-0010) — e.g. rotate which hero pulses by kill
  index. This is richer theater but explicitly cosmetic; it must be **deterministic**
  (drive selection from the kill index / snapshot, **never** `randf()` in a way that could
  diverge from the offline-replay path). The MVP whole-party pulse sidesteps determinism
  risk entirely. ADR-0025 records this as the open sync sub-decision (OQ-35-1).

### C.6 Layering, position, and input

Heroes render **in front of** the biome background and compose with the enemy lineup + VFX
under the HD-2D pass (ADR-0019, GDD #26). Player heroes occupy the **left / near** side,
enemies the **right / far** side; exact placement, sizing, and spacing are owned by the
UX spec (`design/ux/dungeon-run-view.md`, Story 003).

**Every hero sprite + animator subtree is `MOUSE_FILTER_IGNORE`.** The dungeon view is a
read-only spectator; because `z_index` does **not** gate Godot input picking (input routes
by tree order), a hero `TextureRect` drawn "behind" UI could still steal taps unless its
whole subtree ignores the mouse. This is a hard rule (it caused two prior "can't tap"
playtest bugs on other screens).

### C.7 Lifecycle

Hero sprites are built in the screen's **`on_enter`**, *after* the run-snapshot formation
is available (the snapshot exists from dispatch; `on_enter` reads it the same way
`_refresh_display()` reads the snapshot in GDD #24 §C.6). Animators start in idle. On
**`on_exit`** the sprites + animators are freed with the screen (idempotent — a fresh
re-enter rebuilds cleanly, mirroring GDD #24's guard-reset discipline). No animator
`_process` driver outlives the screen.

### C.8 Reduce-motion behavior

When `SceneManager.reduce_motion` is `true` (the canonical flag, loaded from the
accessibility config; existing consumers: `guild_hall.gd`, `recruitment.gd`):

- **Idle animation is suppressed** — the hero shows a **single static frame** (frame 0).
  Implementation leans on `SpriteSheetAnimator` already disabling `_process` for ≤ 1
  frames (hand it a one-frame array, or simply do not start the animator).
- **All reaction beats are suppressed** — no tween. A terminal state (victory / slump)
  is shown as an **instant** non-animated state change, not an animated beat.
- **Heroes remain fully present and visible.** Presence ≠ motion (Pillar from §B);
  reduce-motion removes *animation*, never the heroes.

The flag is **read at beat time**, not cached at `on_enter`, so a mid-run toggle takes
effect immediately (§E.6). Precedent: `prestige_fade_animation_test` AC-PR-18; persistence
per ADR-0007 OQ-7.

**Implemented (Story 015 — full reduce-motion sweep across the calm portrait tier).**
The in-scene dungeon idle + all reaction beats already honoured `reduce_motion` (Stories
009/010). Story 015 closed the gap on the **four calm portrait surfaces** Story 014 had just
added (recruit card, hero-detail modal, codex entry, start-menu row): `ClassSpriteFactory.animate()`
gained a `reduce_motion: bool = false` 4th parameter. When `true` it still attaches the
animator and shows **frame 0**, then calls `set_animating(false)` to disable `_process` —
the hero is **present but still**, and the slot costs nothing per frame (AC-35-07). The flag
is **passed in**, not read inside the factory, keeping it pure-utility / autoload-free (mirrors
`VfxKit.spawn_burst(reduce_motion)`); each surface threads its own `_is_reduce_motion_enabled()`
read off `SceneManager`, re-evaluated on every (re)render — its "beat time" (§E.6). The
in-scene dungeon slot keeps the **default `false`** and gates its idle externally via Story
010's `_set_party_idle_animating`, so it is unchanged. Guarded three ways: a factory unit test
(freeze + motion-on control + default-stays-on), a recruit integration test driving the real
`_render_pool_entry` path end-to-end, and a structural wiring guard asserting all four surfaces
pass the flag *into* their `animate()` call (the scaffolded-but-unwired regression net).

**Min-spec / Steam Deck perf validation (Story 015, Part A).** The 20 Hz hot path is already
proven zero-alloc with heroes + animators on screen (Story 007, AC-35-06 — re-affirmed green
this story). The remaining draw-call/VRAM concern is pinned by a factory test proving every
frame of a class windows **one shared sheet texture** (an `AtlasTexture` over a single sheet),
so K on-screen heroes of a class cost ~1 sheet texture — cost scales with **class count**, not
hero count. The actual on-hardware **1280×800 @ 60fps** measurement is hardware-bound and is
**not** faked headlessly; it folds into the **Story 016 human playtest** closure gate (AC-35-16).

### C.9 Hot-path rule (binding, cross-ref GDD #24 §C.2 / §E.10)

`dungeon_run_view.gd._on_tick_fired` runs at **20 Hz** and MUST remain **zero-allocation**:
no format strings, no `tr()`, no `create_tween()`, no node creation, no per-hero iteration.
All hero-animation work lives in `_process` (idle) and in the human-frequency **signal
handlers** (beats). Story 007 extends the Story-012 per-tick performance test to prove the
hot path stays zero-alloc **with heroes + animators on screen.**

---

## D. Formulas

This is a presentation system; the "math" is **animation timing** and **beat
coalescing**, not gameplay. All values are **data-driven** (constants/exported config on
the hero-animation presentation node, never inline magic numbers) per the coding standard.

### D.1 Idle cadence (reused, not redefined)
`frame_period_sec = 1.0 / IDLE_FPS = 1.0 / 6.0 ≈ 0.1667 s/frame`; full loop =
`FRAME_COUNT / IDLE_FPS = 4 / 6.0 ≈ 0.667 s`. Source: `ClassSpriteFactory.IDLE_FPS = 6.0`,
`FRAME_COUNT = 4` (do not fork these — reuse the factory constants).

### D.2 Reaction-beat durations
- `KILL_BEAT_MS = 180` — strike pulse total (out-and-back). Short enough to keep up with a
  fast kill cadence (§D.5), long enough to register.
- `BOSS_BEAT_MS = 360` — boss strike, 2× the kill beat (a boss death is the run's punctuation).
- `VICTORY_BEAT_MS = 600` — cheer/raise; sits *within* the GDD #24 `RUN_END_DWELL_MS = 1500`
  window so the player sees it before the auto-route fires. Constraint:
  `VICTORY_BEAT_MS < RUN_END_DWELL_MS`.
- `DEFEAT_SLUMP_MS = 700` — slow sag (deliberately the slowest beat; weariness reads slow).
  Same `< RUN_END_DWELL_MS` constraint.

### D.3 Strike-pulse shape
Scale punch `1.0 → KILL_BEAT_SCALE_PUNCH → 1.0` with `KILL_BEAT_SCALE_PUNCH = 1.08`
(boss: `1.14`), eased (e.g. `TRANS_BACK`/`EASE_OUT` out, `EASE_IN` back). Brightness flash
`modulate` `1.0 → 1.25 → 1.0` over the same interval. Values chosen subtle — the cozy
register forbids a jarring strobe.

### D.4 Slump / victory shape
Slump: vertical offset `0 → +SLUMP_OFFSET_PX` (`SLUMP_OFFSET_PX = 6`, scaled to sprite
size) + `modulate` dim to `0.8`, eased `EASE_IN_OUT`. Victory: scale `1.0 → 1.10 → 1.0`
+ a small upward hop `0 → −HOP_PX → 0` (`HOP_PX = 8`).

### D.5 Beat coalescing (anti-strobe) — the load-bearing formula
Kills can cascade faster than a beat can comfortably play. A **coalescing window**
`BEAT_THROTTLE_MS = 120` bounds *visible* kill beats: a new kill beat is suppressed (its
kill is "absorbed" into the in-flight beat) if the previous visible kill beat began less
than `BEAT_THROTTLE_MS` ago.

`max_visible_kill_beats_per_sec = 1000 / BEAT_THROTTLE_MS ≈ 8.3/s`

This parallels the audio gold-chime throttle (audio-system §F.2, 250 ms) and is an
accessibility safeguard (no animation faster than ~8 Hz). The throttle uses an injectable
clock seam (a passed-in "now" / tick-derived timestamp), **not** a free-running
`Time.get_ticks_msec()` baked into logic — so it is testable deterministically (lesson
from the prestige audio-throttle fix: a 0-sentinel + engine-uptime clock mis-fired the
first call; use a `−window` sentinel + injectable clock).

### D.6 Worked example
A typical 5 s run that kills 12 enemies → avg `12 / 5 = 2.4` kills/s → beats fire ~every
`417 ms`, comfortably above the `120 ms` throttle, so **all 12 register**. A burst of 4
kills inside one `200 ms` window → only `ceil(200 / 120) = 2` visible beats; the other 2
kills are absorbed. No strobe; the party still visibly reacts.

### D.7 Portrait speed differential (Phase 4, Story 014)
In-scene dungeon heroes animate at full `IDLE_FPS`. Small portraits elsewhere (recruit /
hero-detail thumbnails) may animate calmer: `portrait_fps = IDLE_FPS × PORTRAIT_IDLE_FPS_RATIO`,
`PORTRAIT_IDLE_FPS_RATIO = 0.5` → `3.0 fps`. This is a Phase-4 polish knob (§G), not an
MVP gate.

**Implemented (Story 014):** `ClassSpriteFactory.PORTRAIT_IDLE_FPS_RATIO` / `PORTRAIT_IDLE_FPS`
consts (`PORTRAIT_IDLE_FPS = IDLE_FPS × PORTRAIT_IDLE_FPS_RATIO`). The dungeon in-scene slot
keeps the full `IDLE_FPS`; all four calm surfaces — recruit card, hero-detail modal, codex
entry, start-menu row — pass `PORTRAIT_IDLE_FPS` to `ClassSpriteFactory.animate()`. "Calm"
covers every non-dungeon surface per art-bible §8.1 ("meditative, not restless"), a superset
of the recruit/hero-detail thumbnails this section names.

---

## E. Edge Cases

Each case states **what happens**, not "handled gracefully."

**E.1 — `formation_size = 1` (solo dispatch).** Exactly one hero sprite renders, placed at
the formation's near-side anchor (UX spec centers a solo hero). Layout adapts; no empty
slots drawn.

**E.2 — Large formation (config `formation_size` up to 10).** The system renders **every
dispatched hero** but must not overflow off-screen. The UX spec (Story 003) owns a spacing
curve that **shrinks sprite size + tightens spacing** as the count grows; the rendering
code reads the per-count layout from the spec, it does not clip or drop heroes. Default 3
is the common case; 4–10 is a config/test case, not an MVP balance target.

**E.3 — A hero's class sprite asset is missing on disk.** `ClassSpriteFactory` resolves
disk-first via `ResourceLoader.exists()`; if the sheet is absent it returns no frames. The
hero slot is **still occupied** by a static placeholder (the factory's fallback texture);
the animator, handed an empty/≤1 frame array, disables its own `_process`. **No crash, no
empty gap.** (Guard committed-asset loads with `ResourceLoader.exists`, not
`FileAccess.file_exists` — the export-strips-source-PNG lesson.)

**E.4 — Kill cascade faster than `BEAT_THROTTLE_MS`.** Beats **coalesce** (§D.5): kills
inside the 120 ms window are absorbed into the in-flight beat. Visible kill beats are
capped at ~8.3/s. No strobe, no beat queue buildup.

**E.5 — `run_defeated` + the defeat overlay both fire.** The slump beat plays **before /
under** the run-end (defeat) overlay so the player sees the heroes sag, then the overlay.
The two are coordinated through the existing `_on_state_changed(RUN_ENDED)` route (GDD #24
§C.4) reading `was_last_run_defeated()` — the slump is **not** a second independent route
decision. No double-handling.

**E.6 — `reduce_motion` toggled mid-run.** The flag is read at **beat time** (§C.8), so the
next beat after the toggle respects the new value; the idle loop freezes (or resumes) on
the next state evaluation. No stale cached value, mirroring GDD #24's resume-time refresh.

**E.7 — A combat signal fires before hero sprites are built** (e.g. a kill during the
FADE_TO_BLACK race, before `on_enter` finishes building sprites). The beat handler
**no-ops** if the sprite set is empty — idle baseline only, no crash. (Same defensive
posture as GDD #24 §E.1's null-snapshot guard.)

**E.8 — A tick fires while a reaction-beat tween is in flight.** Fully independent: the
tween runs on the sprite/animator node; `_on_tick_fired` does its two label writes and
touches nothing animation-related. No interaction, no contention.

**E.9 — `boss_killed` and `floor_cleared_first_time` fire close together** (the boss kill
*is* the floor clear). Beat **precedence: victory > boss > kill.** The victory beat
supersedes any in-flight boss/kill beat on the same node (kill the prior tween, start the
victory beat) so the heroes don't play two conflicting motions at once.

**E.10 — `hero_leveled` fires mid-run** (the existing level-up toast, GDD #24 §C.5). The
toast is a separate transient `Label`, independent of hero sprites. **No extra hero beat in
MVP** (avoid coupling the toast to the sprites); the toast renders as it does today.

**E.11 — Defeat dignity (Pillar 1).** The slump must **not** read as death, ragdoll, or
gore: heroes sag / kneel and lanterns dim — a weary retreat, not a casualty. This is a
visual-review (ADVISORY) gate, but a hard design constraint per ADR-0021 + GDD #34.

**E.12 — Theme cascade not broken (ADR-0008).** Hero sprites are `Control`
(`TextureRect`) nodes added into the screen's Control tree. They must be added so they do
**not** sit as a `type="Node"` intermediate between a themed `Control` ancestor and its
themed descendants (which silently breaks the cascade with no error). Add them as leaves /
siblings, never as a non-Control parent of themed controls.

---

## F. Dependencies

### Hard dependencies

| System | Why | Surface used |
|---|---|---|
| **Dungeon Run View (#24)** | The host screen — this system adds hero sprites to it and coordinates with its overlay/route | `on_enter`/`on_exit` lifecycle; `run_snapshot` read; the `_on_state_changed(RUN_ENDED)` route (does **not** add to `_on_tick_fired`) |
| **Dungeon Run Orchestrator (#13)** | Combat signal source + formation/run-state owner | `enemy_killed`, `boss_killed`, `floor_cleared_first_time`, `run_defeated`, `state_changed` signals; `run_snapshot` (dispatched formation); `was_last_run_defeated()` |
| **Combat Resolution (#11)** | Defines the aggregate-DPS + discrete-kill-event model that makes animation cosmetic; the deterministic kill schedule is the only timing source available to the optional Story 013 | (read-only contract — no direct call) |
| **ClassSpriteFactory + SpriteSheetAnimator** (UI Framework #18 family) | The reused idle-animation components | `get_idle_frames(class_id)`, `slice_sheet`; `SpriteSheetAnimator.setup(target: TextureRect, frames, fps)` |
| **Hero Class Database (#6)** | `class_id` → sprite asset path | `assets/art/classes/[class_id]/sprite.png` (idle); Phase 3 adds action sheets |
| **Hero Roster (#9)** | Hero `class_id` per dispatched formation slot (via the snapshot's deep-copied formation) | snapshot formation slots |
| **SceneManager (#4)** | The reduce-motion accessibility flag | `SceneManager.reduce_motion` |
| **HD-2D Rendering Pipeline (#26) + VFX System (#27)** | Layering/compositing under the HD-2D pass; kill beats coexist with the existing gold-burst VFX | z-order / canvas layering per ADR-0019 |
| **ADR-0025** | The animation↔kill-schedule sync model + hot-path rule | — |
| **ADR-0021 / Defeat & Injury (#34)** | Defeat-presentation contract the slump beat honors (no gore; cozy) | — |
| **`design/ux/dungeon-run-view.md`** (Story 003) | Hero placement, sizing, spacing, per-count layout | layout spec |

### Reverse dependencies (bidirectional per design-doc rule)

- **Dungeon Run View (GDD #24)** — its §F is amended to list this system as a consumer
  that adds hero sprites + reaction beats and that **resolves OQ-24-6** (run-end overlay
  animation). The hero beats must not violate #24's read-only + zero-alloc invariants.
- **HD-2D Rendering Pipeline (#26)** — hero sprites become a layer it composes.
- **Art bible** (`design/art/art-bible.md`, Story 002) — gains the hero-dungeon-presence +
  per-class action-pose section that Phase 3 art (Story 011) is authored against.

---

## G. Tuning Knobs

All knobs are **data-driven** (constants / exported config on the hero-animation
presentation node), never hardcoded at call sites. Each lists a safe range + what it
affects. Sources link to §D.

| Knob | Default | Safe range | Affects | Source |
|---|---|---|---|---|
| `IDLE_FPS` *(reused from `ClassSpriteFactory`)* | 6.0 | 3.0–12.0 | Idle breathing speed. Below 3 = sluggish; above 12 = jittery | §D.1 |
| `KILL_BEAT_MS` | 180 | 80–400 | Strike-pulse length. Must stay ≥ `BEAT_THROTTLE_MS` to avoid clipped beats | §D.2 |
| `BOSS_BEAT_MS` | 360 | 150–700 | Boss-strike length | §D.2 |
| `VICTORY_BEAT_MS` | 600 | 200–1400 | Victory cheer. **Hard cap:** `< RUN_END_DWELL_MS` (1500) | §D.2 |
| `DEFEAT_SLUMP_MS` | 700 | 300–1400 | Slump speed. **Hard cap:** `< RUN_END_DWELL_MS` | §D.2 |
| `KILL_BEAT_SCALE_PUNCH` | 1.08 | 1.0–1.15 | Strike-pulse intensity. Above 1.15 = jarring (breaks cozy register) | §D.3 |
| `BOSS_BEAT_SCALE_PUNCH` | 1.14 | 1.0–1.20 | Boss-strike intensity | §D.3 |
| `BEAT_THROTTLE_MS` | 120 | 80–300 | Anti-strobe coalescing window. Below 80 risks >12 Hz flicker (accessibility); above 300 drops too many beats | §D.5 |
| `SLUMP_OFFSET_PX` | 6 | 2–16 | Slump sag distance (scaled to sprite size) | §D.4 |
| `HOP_PX` | 8 | 0–20 | Victory hop height | §D.4 |
| `PORTRAIT_IDLE_FPS_RATIO` *(Phase 4)* | 0.5 | 0.25–1.0 | Portrait calm-down vs in-scene speed (Story 014) | §D.7 |
| Hero sprite size (px) | *UX-owned* | per UX spec | On-screen hero scale + the §E.2 per-count shrink curve | Story 003 |

**Not knobs:** `FRAME_COUNT` (4 — fixed by the art sheet format) and `reduce_motion`
(an accessibility **flag**, not a tuning value — see §C.8). The beat **precedence** order
(victory > boss > kill, §E.9) is a fixed rule, not a knob.

---

## H. Acceptance Criteria

Each is pass/fail verifiable. Gate level in brackets: **[BLOCKING]** = automated test,
**[ADVISORY]** = visual/playtest sign-off (per coding-standards Test Evidence table).

**AC-35-01 — Heroes render, one per occupied slot [BLOCKING].** Dispatch a formation of
`K` heroes (`1 ≤ K ≤ formation_size`), enter `dungeon_run_view`; exactly `K` hero sprites
exist as children of the hero container, each bound to the correct slot `class_id` from
`run_snapshot`. Count is read from the snapshot, never the literal 3.

**AC-35-02 — Idle animation runs off the tick [BLOCKING].** Each hero sprite's
`SpriteSheetAnimator` advances `FRAME_COUNT` frames at `IDLE_FPS` via its own `_process`.
Assert the animator's frame index advances over simulated `_process` deltas **without any
`tick_fired` emission.**

**AC-35-03 — Kill / boss beats fire on signal [BLOCKING].** With heroes on screen, emit
`enemy_killed(...)` → a kill beat is triggered (observable tween / state flag on the party);
emit `boss_killed(...)` → the boss beat is triggered. (gdunit4:
`assert_signal(orch).wait_until(ms).is_emitted("enemy_killed")` drives it; assert the
animator/beat state changed.)

**AC-35-04 — Victory beat coordinates with the overlay [BLOCKING + ADVISORY].** Emit
`floor_cleared_first_time(...)` → the victory beat plays and completes **within**
`RUN_END_DWELL_MS`; the run-end overlay still shows + routes per GDD #24 AC-24-04
(no regression). Visual quality is ADVISORY.

**AC-35-05 — Defeat slump fires, cozy [BLOCKING + ADVISORY].** Emit `run_defeated(...)`
(→ `state_changed(RUN_ENDED)` with `was_last_run_defeated() == true`) → the slump beat
plays, coordinated with the defeat overlay (GDD #24 §C.4), no double-route. No-gore /
dignity is ADVISORY (Pillar 1 / ADR-0021).

**AC-35-06 — Hot path stays zero-alloc [BLOCKING].** The Story-012-style per-tick
performance test passes **with heroes + animators on screen** — `_on_tick_fired` adds no
allocation, format string, `tr()`, tween, or node creation. (Story 007 extends the existing
perf test.) *Verified (Story 015 re-affirm): Story 007 source-guard test green; the
shared-atlas draw-call budget is additionally pinned by
`class_sprite_factory_test.test_idle_frames_share_one_atlas_for_draw_call_budget`.*

**AC-35-07 — reduce_motion suppresses motion, keeps presence [BLOCKING].** With
`SceneManager.reduce_motion = true`: idle shows a single static frame (animator `_process`
disabled), all reaction beats are suppressed (no tween), and **all `K` hero sprites remain
visible.** *Verified (Story 015): `class_sprite_factory_test.test_animate_reduce_motion_freezes_idle_on_static_frame_zero`
(+ motion-on control) for the calm tier; `recruit_screen_contract_test` Group G drives the
real render path end-to-end; `calm_surface_reduce_motion_wiring_test` guards all four surfaces.
In-scene + beats covered by Stories 009/010.*

**AC-35-08 — reduce_motion read at beat time [BLOCKING].** Toggle `reduce_motion` after
`on_enter`; the next beat respects the new value (flag not cached at enter). *Verified
(Story 015, calm tier): each surface's `_is_reduce_motion_enabled()` is read inside
`_render_*`/`_make_*` on every (re)render — not cached at enter — so a re-render under a
toggled flag freezes (or resumes) the portrait idle.*

**AC-35-09 — Kill cascade coalesces, no strobe [BLOCKING].** Emit `N` `enemy_killed` within
one `BEAT_THROTTLE_MS` window; visible kill beats ≤ `ceil(window / BEAT_THROTTLE_MS)`.
Drive the throttle via the injectable clock seam (no wall-clock dependency).

**AC-35-10 — Read-only: hero sprites never consume input [BLOCKING].** Every hero sprite +
animator subtree has `mouse_filter == MOUSE_FILTER_IGNORE`. A simulated tap over a hero
sprite is not consumed by it (no input regression on the spectator screen).

**AC-35-11 — Layout adapts to count [BLOCKING].** `formation_size = 1` → one hero at the
solo anchor; a full formation → all heroes rendered with **no off-screen overflow** (each
sprite's rect stays within the hero container bounds per the §E.2 shrink curve).

**AC-35-12 — Missing class sprite → static placeholder, no crash [BLOCKING].** Dispatch a
hero whose `class_id` has no sprite sheet on disk; the slot renders the factory placeholder
statically; no error/crash; other heroes animate normally.

**AC-35-13 — Beat precedence victory > boss > kill [BLOCKING].** Emit `boss_killed` then
`floor_cleared_first_time` within one beat interval; the victory beat supersedes the
in-flight boss beat (only one terminal motion on the node).

**AC-35-14 — Theme cascade intact [BLOCKING].** Adding the hero sprite nodes does not break
sibling/descendant `Control` theme inheritance — no `type="Node"` intermediate is
introduced between a themed `Control` and its themed descendants (ADR-0008).

**AC-35-15 — Clean teardown [BLOCKING].** After `on_exit`, all hero sprites are freed and no
`SpriteSheetAnimator` `_process` driver remains active (no orphan animators across a
re-enter).

**AC-35-16 — Playtest gate [ADVISORY, Story 016].** A human dispatches a formation, opens
the dungeon view (against merged `main`), and sees their heroes **present, idle-animating,
and reacting** to kills / boss / first-clear / defeat — without dev intervention.

---

## I. Open Questions & ADR Candidates

**OQ-35-1 — Which hero reacts to a kill? → ADR-0025.** MVP = whole-party synchronized
pulse (honest under aggregate combat). Optional Phase-3 = synthetic per-hero cadence from
the deterministic kill schedule (Story 013). ADR-0025 records this sub-decision and the
determinism constraint (§C.5).

**OQ-35-2 — Do tween beats suffice for MVP, or is per-class action art required?**
**Resolved (this GDD):** tween beats (Phases 1–2) ship the player-visible win with **no new
art**. Real per-class action sheets (Story 011) are a Phase-3 enhancement, **spend-gated**
(image-gen pipeline + artistic sign-off), with the tween as permanent fallback.

**OQ-35-3 — Is the in-dungeon victory beat the right home, or does the Victory Moment
screen (#25) own celebration?** Boundary: the **in-dungeon** beat is a brief reaction
inside `RUN_END_DWELL_MS`; the full floor-clear **celebration** remains GDD #25's job.
This GDD's victory beat does not duplicate #25. Revisit if #25's flow changes.

**OQ-35-4 — Portrait speed differential + per-class secondary motion (Story 014).** Should
in-scene heroes animate livelier than thumbnails, and should each class have distinct
secondary idle motion (art-bible §8.1 "no hero reuses another's motion")? Phase-4 fidelity;
not MVP-gating.
**Resolved (Story 014):** YES to both — a code knob + an art-resident invariant. (1) The
in-scene dungeon party animates at full `IDLE_FPS` (6.0); every calm portrait/thumbnail
surface (recruit, hero-detail, codex, start-menu) animates at `PORTRAIT_IDLE_FPS`
(`IDLE_FPS × 0.5` = 3.0 fps), a §D.7/§G knob held as a single source of truth on
`ClassSpriteFactory`. (2) The per-class secondary motion is **art-resident** — baked into
each class's distinct 4-frame idle strip (art-bible §8.1); the code-boundary guarantee of
"no hero reuses another's motion" is that each class loads its OWN sheet via
`get_idle_frames(class_id)`, pinned by a non-reuse regression test (warrior vs mage window
different atlases). The speed differential itself is proven **behaviourally** (a delta
between the two frame intervals advances the in-scene animator but not the portrait one).

**OQ-35-5 — Should a leveled-up hero get a dedicated pulse?** MVP: no (the level-up toast
in GDD #24 §C.5 covers the moment; coupling it to sprites adds risk). Candidate Phase-4
polish if playtest wants it.

---

## J. Implementation Sequencing

Maps to the `hero-combat-animation` epic's 16 stories across 5 phases
(`production/epics/hero-combat-animation/EPIC.md`):

- **Phase 0 — Design & Architecture (Stories 001–004, BLOCKING prerequisite).** This GDD
  (001), the art-bible hero-presence section (002), the `dungeon-run-view` hero-placement
  UX spec (003), and **ADR-0025** (004 — locks the §C.3 sync model + §C.9 hot-path rule).
- **Phase 1 — Heroes On-Screen (005–007, first visible win).** Render the dispatched
  formation's sprites (§C.1), wire the reused idle animation (§C.2), and extend the
  Story-012 per-tick perf test (§C.9, AC-35-06).
- **Phase 2 — Reaction Beats (008–010, tween-based, no new art).** Kill/boss strike beats
  (§C.4), defeat-slump + victory beats coordinated with the run-end overlay (§E.5/§E.9,
  resolves OQ-24-6), and reduce-motion suppression across all beats (§C.8, AC-35-07/08).
  **Phases 1–2 deliver the full MVP fantasy.**
- **Phase 3 — Per-Class Action Art (011–013).** Author attack/hit/victory sheets via the
  asset pipeline (011 — **external: image-gen spend + sign-off**); the animation state
  machine that swaps tweens → frames where art exists (012); the optional synthetic
  per-hero cadence (013, OQ-35-1).
- **Phase 4 — Polish / A11y / Playtest (014–016).** Speed differential + per-class secondary
  motion (014, §D.7/OQ-35-4), min-spec / Steam Deck perf + full reduce-motion sweep (015),
  and the **human playtest gate** (016 — **external: human**, AC-35-16).

**External-dependency gates** (cannot be self-executed, surfaced to the user): Story 011
(art spend + artistic sign-off) and Story 016 (human playtest).

---

## Notes

- Authored 2026-06-22 under the `hero-combat-animation` epic (Story 001), review mode
  **solo**. Forward-design for an unimplemented system.
- Systems-index row added as system **#35** (Presentation layer).
- Run `/design-review design/gdd/hero-combat-animation.md` to surface drift; expected first
  verdict APPROVED or CONCERNS-only (lean, single-pass — per the "uiux/functions must
  progress" steer, this GDD is authored lean-but-complete, not multi-pass review churn).
