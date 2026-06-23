# Hero Combat Presence & Animation — Human Playtest Runbook (GDD #35, AC-35-16, Story 016)

> **GDD**: `design/gdd/hero-combat-animation.md` (#35) · **ADR**: ADR-0025 (animation↔kill-schedule sync)
> **Epic**: `production/epics/hero-combat-animation/EPIC.md` — Story 016 (the closure gate)
> **Branch / PR**: `feat/hero-combat-animation` → **PR #240**
> **Author**: Epic implementation (2026-06-23)
> **Status**: `[ ]` Not yet executed — **this is the load-bearing closure gate for the epic.**

This is the **Playtest** evidence for Story 016 (AC-35-16, ADVISORY). Every **BLOCKING**
acceptance criterion (AC-35-06 → AC-35-15) is already locked by automated tests (see the
coverage table at the bottom). This runbook covers what automation **cannot** convey: the
**felt** quality of the beats, the **visual read** of the party at native resolution, and the
**on-hardware 60 fps** smoothness — the human-only half of AC-35-06 and AC-35-16.

---

## ⚠️ Precondition — run this against **merged `main`**, not the branch

Per project practice (100% green tests ≠ shipped) **and** the
`playtest-against-merged-main` lesson, the playtest is only meaningful against the code the
playtester's local `main` actually has. Before playing:

1. **Review + merge PR #240** (`feat/hero-combat-animation` → `main`).
2. `git checkout main && git pull` — confirm `git log --oneline -1` shows the epic merge.
3. Launch the project from that `main` working tree.

> If you playtest the branch directly that's fine for a smoke look, but the **gate** is only
> satisfied on merged `main` (this is the same discipline applied to the Defeat & Injury arc).

---

## Setup — reaching the dungeon view with a live party

1. Launch the game (editor **F5**, or an exported build for the min-spec pass below).
2. From the **Guild Hall**, ensure at least one hero is assigned to the active **formation**
   (recruit one first if the roster is empty).
3. **Dispatch** the formation into any biome/floor. The dungeon run view opens automatically
   (`SceneManager.request_screen("dungeon_run_view", …)` — there is no manual nav).

**Art note (not a bug):** all seven classes (archer · berserker · cleric · mage · paladin ·
rogue · warrior) ship a committed 4-frame idle strip, so **any** party shows animated
sprites — you don't need to curate a specific formation. Per-class **action** sheets
(attack/hit/victory/defeat) are **not** committed yet (Story 011's art spend is the other
external gate), so the reaction beats below play as **tween punches** (scale + brightness),
which is the permanent fallback by design — not a missing-art defect.

---

## The checklist — observe, compare to "Expected", mark Pass/Fail

### A. Presence & layout (AC-35-11)

| # | Do this | Expected | P/F |
|---|---------|----------|-----|
| A1 | Dispatch a **full** formation, open the view | **One hero sprite per occupied slot**, in a centered front-line row just below the enemy lineup. Count matches the party you dispatched — **not always 3**. | `[ ]` |
| A2 | Dispatch a **single-hero** formation | Exactly **one** hero at the row center; no phantom slots. | `[ ]` |
| A3 | Look at the whole 1280×800 frame | Heroes sit **on-screen, no overflow**; sprites are crisp pixel-art (nearest-neighbour), aspect-preserved in their ~72 px boxes. | `[ ]` |

### B. Idle animation & speed differential (Stories 006 / 014, §D.7)

| # | Do this | Expected | P/F |
|---|---------|----------|-----|
| B1 | Watch an idle hero on the dungeon view (no kills happening) | A calm looping "breathing" idle at the **full in-scene rate** (~6 fps). | `[ ]` |
| B2 | Open a **calm portrait** surface (Recruitment pool card, Hero-Detail header, Codex thumbnail, or the Start-Menu sprite row) | The same idle, but visibly **half-speed** (~3 fps) vs the dungeon — the deliberate in-scene-vs-portrait differential. | `[ ]` |
| B3 | Compare two **different** classes side by side (e.g. warrior vs mage) | Each class has its **own** distinct idle motion — no two classes share the same animation. | `[ ]` |

### C. Reaction beats — kills & boss (Stories 008 / 013, §C.4 / §D.2–D.5)

| # | Do this | Expected | P/F |
|---|---------|----------|-----|
| C1 | Watch as regular enemies die (kill counter ticks up) | A brief **strike punch** (slight scale-up + brightness flash, ~180 ms) on **one** hero, and **successive kills walk the party left-to-right** (synthetic round-robin cadence). | `[ ]` |
| C2 | Watch a **fast** kill cascade (many kills in a second) | Beats **coalesce** — no seizure-inducing strobe; visible punches cap at ~8/s and stay readable. | `[ ]` |
| C3 | Watch a **boss** die | A **bigger / longer** punch (~360 ms) on the **whole party** at once — the run's punctuation, distinct from the per-hero kill walk. | `[ ]` |

### D. Terminal beats — victory & defeat (Story 009, §E.5 / §E.9 / ADR-0021)

| # | Do this | Expected | P/F |
|---|---------|----------|-----|
| D1 | **Win** a floor for the **first time** | A **victory cheer** (whole-party rise/bloom, ~600 ms) plays **under the run-end overlay**, then the screen routes onward. | `[ ]` |
| D2 | **Lose** a run (dispatch an over-tier floor) | A **defeat slump** (a gentle sag + dim, party **stays fully visible** — **no fall, ragdoll, or gore**, ~700 ms), coordinated with the distinct defeat overlay; routes to the Guild Hall. | `[ ]` |
| D3 | At the moment a run ends (win or lose) | The looping idle **freezes** — the party holds its pose under the overlay (no idle "breathing" continues during the end card). | `[ ]` |

### E. reduce_motion accessibility sweep (Stories 010 / 015, §C.8, AC-35-07/08)

> Toggle the **Reduce Motion** setting ON (it sets `SceneManager.reduce_motion = true`).

| # | Do this | Expected | P/F |
|---|---------|----------|-----|
| E1 | With reduce-motion **ON**, open the dungeon view with a party | Heroes are **present and fully visible**, but **hold a single static frame** — no idle looping. | `[ ]` |
| E2 | With reduce-motion **ON**, watch kills / boss / a win / a loss | **No strike, victory, or slump motion** plays; heroes stay visible (defeat shows the static dim, no animated sag). | `[ ]` |
| E3 | With reduce-motion **ON**, open each calm portrait surface (recruit, hero-detail, codex, start-menu) | **None** of the four animate — every portrait holds a static frame, heroes still visible everywhere. | `[ ]` |
| E4 | Toggle reduce-motion **ON mid-session**, then re-open a surface / re-enter the view | The newly-rendered surface respects the **current** flag (it's read per render, not cached at launch). | `[ ]` |

### F. Read-only spectator contract (AC-35-10)

| # | Do this | Expected | P/F |
|---|---------|----------|-----|
| F1 | **Tap directly on a hero sprite** during a run | Nothing is consumed by the sprite — the tap behaves exactly as a tap on empty dungeon space (heroes never steal input). | `[ ]` |

### G. Min-spec / Steam Deck feel (AC-35-16 + on-hardware half of AC-35-06)

| # | Do this | Expected | P/F |
|---|---------|----------|-----|
| G1 | Run an exported build at **1280×800** on the min-spec target (Steam Deck or equivalent) | A full party + a busy kill cascade holds a **smooth ~60 fps**; no hitching attributable to the hero animation. | `[ ]` |
| G2 | Subjective read | The party reading "alive and reacting" **adds** to the run without distracting from the HP race / counters. | `[ ]` |

---

## Optional — capture a presence screenshot (per evidence-dir convention)

A static frame can be captured for the record using the **headful screenshot harness**
(project memory `godot-headful-screenshot-harness`): a throwaway `-s SceneTree` script run
**non-headless** (Vulkan/Metal), seeding a dispatched run, navigating to `dungeon_run_view`,
and saving the viewport to PNG at frame ≥ 16 (after the diorama builds and the idle advances).
Per convention the **PNG stays local/untracked** — commit only a short note here describing
what it showed (e.g. "4 heroes in the front line, mid-idle, no overflow at 1280×800").

> This is **optional**: the static presence claim is already covered structurally by
> `test_party_diorama_renders_one_sprite_per_occupied_slot_data_driven` +
> `…_slot_stashes_class_id_and_loads_idle_frame`. The human pass above is what the screenshot
> can't give — the **motion** and the **feel**.

---

## Automated coverage (the load-bearing structural proof)

Story 016's eyes confirm feel; the **contracts** are locked by these suites (all green,
run individually on local `Godot_mono` 4.6 — the full multi-dir run SIGABRTs at shutdown
locally, a known artifact, not a failure):

| Suite | Cases | What it locks |
|---|---|---|
| `tests/integration/scene_manager/dungeon_run_view_screen_test.gd` | 71 | The whole in-scene contract: diorama present + input-transparent (AC-35-10/14); **one sprite per occupied slot, count data-driven not hardcoded** (AC-35-11); idle loads + **advances** the frame (006); `_on_tick_fired` adds **no** hero work (AC-35-06); RUN_ENDED **freezes** idle (AC-35-15); kill/boss/victory/defeat beats connect→fire→disconnect end-to-end incl. **real signal emission**, coalescing (AC-35-09), precedence victory>boss>kill (AC-35-13), round-robin walk + boss whole-party, action-frame-vs-tween split, and the **full reduce-motion sweep** with heroes visible (AC-35-07/08). |
| `tests/unit/class_sprite_factory/class_sprite_factory_test.gd` | 28 | Idle frame slicing; reduce-motion **freezes on static frame 0** (`_process` off) + motion-on control + 3-arg default-stays-on; **shared-atlas draw-call budget** (K heroes of a class ≈ 1 sheet texture). |
| `tests/unit/class_sprite_factory/calm_surface_reduce_motion_wiring_test.gd` | 2 | Structural guard: **all four** calm portrait surfaces thread the reduce-motion flag **into** their `animate()` call + define the helper (the scaffolded-but-unwired regression net). |
| `tests/integration/recruitment/recruit_screen_contract_test.gd` | 16 | Group G drives the **real** `_render_pool_entry` path: portrait idle freezes under reduce-motion, animates without it. |
| `tests/unit/dungeon_run_orchestrator/*` (Story 007 hot-path guard) | — | `_on_tick_fired` source guard: **no** alloc / format string / `tr()` / tween / node creation at 20 Hz **with heroes on screen** (AC-35-06 BLOCKING). |

---

## Closure note

Per project practice, **100% green tests ≠ shipped**. This human playtest against merged
`main` is the **load-bearing closure gate** for the Hero Combat Presence epic. When sections
A–G pass (G1 on real min-spec hardware), mark this doc `[x] Pass`, flip Story 016 to **Done**
in `production/epics/hero-combat-animation/EPIC.md`, and the epic is complete.

The epic's **sibling external gate** — **Story 011** (per-class action-sprite **art spend**
+ artistic sign-off) — remains user-owned and is **not** required for this gate: the tween
beats are the permanent fallback, so the epic is fully playable and shippable without the
action art.

`[ ]` Pass · `[ ]` Fail · `[ ]` Not yet executed
