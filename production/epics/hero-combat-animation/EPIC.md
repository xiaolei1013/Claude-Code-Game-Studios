# Epic: Hero Combat Presence & Animation

> **Layer**: Presentation
> **GDD**: `design/gdd/hero-combat-animation.md` (authored in Phase 0, Story 001)
> **Architecture Module**: `dungeon_run_view` screen + `HeroCombatAnimator` presentation nodes (NO autoload, NO new gameplay state) — governed by ADR-0025
> **Control Manifest Version**: 2026-04-24
> **Status**: In Progress (Phase 0 — Design & Architecture)
> **Stories**: 16 defined across 5 phases

## Overview

Today the dungeon run screen (`assets/screens/dungeon_run_view/`) is a read-only
spectator view that renders the biome background, an **aggregate** party HP bar,
tick/kill counters, a run-end overlay, and a level-up toast. **The player's heroes
are not on screen at all** — the screen the player stares at during the core loop
shows everything *except* the heroes they recruited and formed up.

This epic puts the party's heroes on the dungeon screen and animates them in
response to combat. It does **not** change combat: combat remains the deterministic,
tick-based, party-**aggregate**-DPS model owned by `CombatResolver` +
`DungeonRunOrchestrator` (ADR-0010). The combat resolver emits **discrete kill
events only** — there are no per-hero attack events. Therefore hero animation is
**scheduled cosmetic theater punctuated by the real combat signals that already
fire** (`enemy_killed`, `boss_killed`, `floor_cleared_first_time`, `run_defeated`,
`state_changed`), NOT a faithful per-hero combat simulation. ADR-0025 locks how
animation timing is driven given this constraint.

The work reuses the project's existing, validated idle-animation system
(`ClassSpriteFactory` sheet-slicing + `SpriteSheetAnimator` `_process` frame driver,
already shipping on Recruit cards and the Hero Detail modal) rather than building a
new animation framework. Phases 1–2 ship the full player-visible win — heroes
standing in the dungeon, idle-animating, and reacting to kills/boss/defeat/victory —
using **tween-based reaction beats that need no new art** (same technique as the
existing prestige-fade and synergy-glow tweens). The expensive net-new art spend
(per-class attack/hit/victory sprite sheets) is deferred to Phase 3 so visible value
ships first.

**Hard constraint (Story-012 perf gate):** `dungeon_run_view.gd._on_tick_fired`
runs at 20 Hz (50 ms ticks) and MUST remain zero-allocation. All animation is
`_process`-driven on separate animator nodes and reacts to discrete, low-frequency
signals — **never** added to the tick handler.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0025: Hero Animation ↔ Kill-Schedule Sync (NEW — Story 004) | How animation timing is driven absent per-hero attack events (cosmetic-react vs poll-schedule vs synthetic-events); enshrines the 20 Hz zero-alloc hot-path rule and reduce-motion suppression | MEDIUM |
| ADR-0010: Combat Resolver Snapshot + Parity | Combat stays aggregate-DPS + discrete kill events; the kill schedule is the only deterministic timing source available to Story 013 | MEDIUM |
| ADR-0021: Defeat-State Pivot | Defeat presentation contract the run_defeated slump beat (Story 009) must honor | LOW |
| ADR-0008: Theme Skin / UI Framework | Hero sprites layer into a Control tree; theme cascades only through Control ancestors — sprite/animator nodes must not break sibling theme inheritance | MEDIUM |
| ADR-0019: HD-2D Pipeline Activation | Hero sprites compose with the biome background + VFX under the HD-2D pass; layering/z-order must respect the pipeline | MEDIUM |
| ADR-0024: MVP UI Icons Hand-Authored PNG | Art-authoring precedent for the Phase-3 per-class action sheets (Story 011) | LOW |

## GDD Requirements Coverage

| Metric | Count |
|---|---|
| Total TRs (`TR-hero-anim-*`) | registered during Phase 0 GDD authoring (Story 001) → `tr-registry.yaml` |
| Coverage | ADR-0025 covers the timing/sync + hot-path surface; existing idle-anim system covers rendering |
| Source signals (already emitted) | `enemy_killed`, `boss_killed`, `floor_cleared_first_time`, `run_defeated`, `state_changed` on `DungeonRunOrchestrator` |
| Net-new gameplay state | **none** — this is a presentation-only epic |

## Engine Compatibility Notes (Godot 4.6)

- **Zero-alloc hot path**: `_on_tick_fired` (20 Hz) must not gain any allocation, format string, or `tr()` call. Animation lives in `_process` on animator nodes and in signal handlers that fire at human frequency (kills, not ticks). Story 007 extends the Story-012 per-tick budget test to prove this.
- **Reuse, don't rebuild**: `ClassSpriteFactory.get_idle_frames()` (AtlasTexture sheet-slicing, `ResourceLoader.exists()` disk-first) + `SpriteSheetAnimator.setup()` (`_process` accumulator frame-swap, disables `_process` when frames ≤ 1) are already validated on Recruit cards + Hero Detail modal. Phase 1 attaches the same components to on-screen hero sprites.
- **Tween reaction beats**: follow the existing prestige-fade / synergy-glow precedent (`create_tween()`, presentation-only, no per-tick allocation). No new art needed for Phases 1–2.
- **Theme cascade (ADR-0008)**: theme inherits only through `Control` ancestors. Hero sprite/animator nodes (TextureRect / Node2D) must be added so they do not sit between a themed `Control` and its descendants (memory: a `type="Node"` intermediate silently breaks the cascade with no error).
- **Input picking**: `z_index` does NOT affect Godot input picking. The dungeon view is a read-only spectator — every hero sprite + animator subtree must be `MOUSE_FILTER_IGNORE` so it cannot steal taps from any control (memory: z_index overlays caused two "can't tap" playtest bugs).
- **Reduce-motion**: all idle + reaction motion must respect the `reduce_motion` accessibility flag. Precedent: `prestige_fade_animation_test` AC-PR-18; settings persistence per ADR-0007 OQ-7.
- **`.uid` sidecars**: any new `.gd` / `.tscn` / `.tres` gets its Godot 4.6 `.uid` committed in the same PR. `.tscn`/`.tres` `Color()` literals need 4 components.

## Definition of Done

- All 16 stories closed via `/story-done` **except** the two external-dependency gates, which are surfaced to the user: Story 011 (net-new per-class action art — needs the image-gen pipeline / API key) and Story 016 (human playtest — needs a human).
- GDD `hero-combat-animation.md` (8 required sections), ADR-0025 (Accepted), the art-bible hero-dungeon-presence section, and the `dungeon-run-view` hero-placement UX spec are authored and self-reviewed (solo review mode).
- Heroes render and idle-animate on `dungeon_run_view`; reaction beats fire on `enemy_killed` / `boss_killed` / `floor_cleared_first_time` (victory) / `run_defeated` (defeat); the `reduce_motion` flag suppresses all of them.
- The Story-012-style per-tick perf budget test is extended to prove `_on_tick_fired` stays zero-alloc with heroes + animators on screen.
- **Playtest gate (Story 016)**: a human dispatches a formation, opens the dungeon view, and sees their 3 heroes standing in the dungeon, idle-animating, and reacting to kills / boss / first-clear / defeat — without dev intervention.

## Stories

| # | Story | Phase | Type | Status | ADRs |
|---|-------|-------|------|--------|------|
| 001 | GDD: `hero-combat-animation.md` — which beats animate, formation→aggregate-DPS mapping, cozy/read-only pillar preservation, reduce-motion behavior | P0 Design | Design (GDD) | **Done** (GDD #35, 8 sections + I/J; systems-index row #35; #24 §F reverse-dep) | — |
| 002 | Art-bible: hero dungeon-presence section + per-class action-pose spec (attack/hit/victory) | P0 Design | Design (Art) | **Done** (art-bible §5: "Dungeon Combat Presence" + "Per-Class Action Poses" — 4-beat pose table for all 6 classes; no-reuse rule extended to actions; defeat=dignified slump per ADR-0021; 4-frame strip convention for pipeline reuse) | ADR-0024 |
| 003 | UX spec: `design/ux/dungeon-run-view.md` hero placement, sizes, per-hero vs aggregate HP, layering, read-only (no new input) | P0 Design | Design (UX) | **Done** ("Hero Combat Presence (GDD #35)" section in the existing UX spec: center-stage front-line placement, ~72px in-scene sprites, **AGGREGATE HP** decisive, z=1 sharp-plane layering, full MOUSE_FILTER_IGNORE read-only, additive `PartyDioramaLayer`; 10 ACs UX-DRV-HERO-01..10 + 3 OQs) | ADR-0008, 0019 |
| 004 | ADR-0025: animation ↔ kill-schedule sync model + 20 Hz zero-alloc hot-path rule + reduce-motion | P0 Arch | Architecture | Ready | ADR-0025, 0010 |
| 005 | Render the 3 party heroes as sprites on `dungeon_run_view` (ClassSpriteFactory art), positioned per UX spec, layered with biome/VFX/enemies | P1 On-Screen | UI / Visual | Backlog | ADR-0008, 0019 |
| 006 | Wire existing idle animation to the on-screen hero sprites (`SpriteSheetAnimator`, `_process`-driven, NOT in the tick handler) | P1 On-Screen | UI / Visual | Backlog | ADR-0025 |
| 007 | Low-frequency hero-state reflection + extend the Story-012 per-tick budget test (prove 20 Hz hot path stays zero-alloc) | P1 On-Screen | Logic (Performance) | Backlog | ADR-0025, 0010 |
| 008 | `enemy_killed` / `boss_killed` → hero strike/flash reaction beat via tween (prestige/synergy tween technique) | P2 Reactions | Visual / Feel | Backlog | ADR-0025 |
| 009 | `run_defeated` slump beat + win victory beat, coordinated with the run-end overlay (also addresses GDD #24 OQ-24-6) | P2 Reactions | Visual / Feel | Backlog | ADR-0025, 0021 |
| 010 | Reduce-motion suppression for all idle + reaction beats (precedent: `prestige_fade_animation_test` AC-PR-18) | P2 Reactions | UI (a11y) / Logic | Backlog | ADR-0025, 0007 |
| 011 | Author per-class attack / hit / victory sprite sheets via the asset pipeline (**net-new art — external dependency: image-gen key**) | P3 Action Art | Visual (Art) | Backlog | ADR-0024 |
| 012 | Hero animation state machine (idle ↔ attack ↔ hit ↔ victory/defeat); swap Phase-2 tweens for real frames where art exists | P3 Action Art | Logic + Visual | Backlog | ADR-0025 |
| 013 | (Optional, ADR-0025-dependent) Synthetic per-hero action cadence derived from the deterministic kill schedule | P3 Action Art | Logic | Backlog | ADR-0025, 0010 |
| 014 | Speed differential (portrait tier = 50% of in-scene) + per-class distinct secondary idle motion (art-bible §8.1 fidelity) | P4 Polish | Visual / Feel | Backlog | ADR-0024 |
| 015 | Min-spec / Steam Deck perf validation + full reduce-motion sweep across all hero-animation surfaces | P4 Polish | Logic (Performance) + QA | Backlog | ADR-0025 |
| 016 | **Human playtest gate** — player sees heroes present + reacting end-to-end against merged `main` (**external dependency: human**) | P4 Polish | Playtest | Backlog | — |

**Phase breakdown**: P0 Design & Architecture (001–004, BLOCKING prerequisite) · P1 Heroes On-Screen (005–007, first visible win) · P2 Reaction Beats (008–010, tween-based, no new art) · P3 Per-Class Action Art (011–013, expensive art spend) · P4 Polish / A11y / Playtest (014–016).

**Type breakdown**: 4 Design/Architecture + 5 Visual/Feel + 3 Logic/Perf + 2 UI + 1 Art-asset + 1 Playtest.

**External-dependency gates (cannot be self-executed)**: Story 011 (image-gen pipeline / API key) and Story 016 (human playtest).

## Next Step

**Stories 001–003 done** (GDD #35 — `design/gdd/hero-combat-animation.md`, 8 sections + I/J; systems-index #35; #24 §F reverse-dep · art-bible §5 — "Dungeon Combat Presence" + "Per-Class Action Poses" 4-beat table · UX spec — "Hero Combat Presence (GDD #35)" section: center-stage placement, AGGREGATE HP decisive, z=1 sharp-plane layering, read-only, additive `PartyDioramaLayer`). Remaining Phase 0: Story 004 (**ADR-0025** — locks the §C.3 sync model + §C.9 hot-path rule that Phases 1–3 build against; must reach **Accepted** before Phase 1 code). Then Phases 1–2 ship the full player-visible win with no new art; Phase 3's per-class art (Story 011) + Phase 4's human playtest (Story 016) are the external-dependency gates surfaced to the user.
