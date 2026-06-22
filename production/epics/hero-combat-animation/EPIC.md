# Epic: Hero Combat Presence & Animation

> **Layer**: Presentation
> **GDD**: `design/gdd/hero-combat-animation.md` (authored in Phase 0, Story 001)
> **Architecture Module**: `dungeon_run_view` screen + `HeroCombatAnimator` presentation nodes (NO autoload, NO new gameplay state) — governed by ADR-0025
> **Control Manifest Version**: 2026-04-24
> **Status**: In Progress (Phase 2 — Reaction Beats; Phases 0–1 Design/Architecture + Heroes On-Screen complete)
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
| ADR-0025: Hero Animation ↔ Kill-Schedule Sync (**Accepted** — Story 004) | How animation timing is driven absent per-hero attack events (cosmetic-react vs poll-schedule vs synthetic-events); enshrines the 20 Hz zero-alloc hot-path rule and reduce-motion suppression | MEDIUM |
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
| 004 | ADR-0025: animation ↔ kill-schedule sync model + 20 Hz zero-alloc hot-path rule + reduce-motion | P0 Arch | Architecture | **Done** (ADR-0025 **Accepted** 2026-06-22 — "two clocks, never the tick": free-running `_process` idle + signal-triggered reaction beats; 3 rejected alts [poll-schedule-per-tick, resolver-emits-per-hero, ~~synthetic-events~~ → deferred to Story 013]; enshrines the 20 Hz zero-alloc hot-path rule + reduce-motion-read-at-beat-time; aggregate-react resolves OQ-35-1; GDD↔ADR bidirectional) | ADR-0025, 0010 |
| 005 | Render the party heroes as sprites on `dungeon_run_view` (ClassSpriteFactory art), positioned per UX spec, layered with biome/VFX/enemies | P1 On-Screen | UI / Visual | **Done** (additive `PartyDioramaLayer` sibling on root, `MOUSE_FILTER_IGNORE`, z=1; centered `PartyFrontLine` HBox of 72px `TextureRect` slots below the enemy lineup; slot count **data-driven** from `HeroRoster.get_formation_heroes()` — NOT hardcoded; static idle frame 0 from `ClassSpriteFactory.get_idle_frames()`, class_id stashed in `&"hero_class_id"` meta for Story 006; verified by 5 render-assertion tests [3/2/0-hero count + warrior texture-load + input-transparent/z] — 34/34 suite pass, 0 orphans) | ADR-0008, 0019, 0025 |
| 006 | Wire existing idle animation to the on-screen hero sprites (`SpriteSheetAnimator`, `_process`-driven, NOT in the tick handler) | P1 On-Screen | UI / Visual | **Done** (`_make_hero_slot()` now calls `ClassSpriteFactory.animate(slot, class_id)` — replacing the static frame-0 set — which attaches a `_process`-driven `SpriteSheetAnimator` child `&"_IdleAnimator"` that loops the class breathing idle; structurally decoupled from `_on_tick_fired` per ADR-0025 §C.9 "two clocks, never the tick"; no-op + zero per-frame cost when art absent [≤1-frame → `set_process(false)`]; verified by 2 new tests [animator attached + `is_processing()`; deterministic `_process(0.2)` advances `slot.texture`] — 36/36 suite pass, 0 orphans) | ADR-0025 |
| 007 | Low-frequency hero-state reflection + extend the Story-012 per-tick budget test (prove 20 Hz hot path stays zero-alloc) | P1 On-Screen | Logic (Performance) | **Done** (added `SpriteSheetAnimator.set_animating(enabled)` — index-preserving pause/resume that honours the ≤1-frame static-card invariant; new screen helper `_set_party_idle_animating()` walks `PartyFrontLine` + toggles each `&"_IdleAnimator"`, hooked into `_on_state_changed`→RUN_ENDED to **freeze** the party idle as the §C.4 baseline transition [placed before the `_routed` guard so it fires on every RUN_ENDED entry, incl. a replayed duplicate]; factory animator-node-name const promoted to public `ANIMATOR_NODE_NAME` single-source-of-truth. **AC-35-06 [BLOCKING]** perf gate landed in the **CI-run integration suite** [`tests/perf/` is NOT in CI] as a SOURCE-level guard: extracts the `_on_tick_fired` body + asserts it contains none of 11 hero/alloc tokens [`create_tween`/`.new(`/`add_child`/`animate(`/diorama/animator/`get_formation_heroes`…] — proven non-vacuous by inject-and-revert. Verified: 4 new animator unit tests [incl. resume-continues-from-paused-frame] + 2 new integration tests [source guard + RUN_ENDED freezes both warrior idles] — 12/12 animator, 14/14 factory, 38/38 screen, 0 orphans) | ADR-0025, 0010 |
| 008 | `enemy_killed` / `boss_killed` → hero strike/flash reaction beat via tween (prestige/synergy tween technique) | P2 Reactions | Visual / Feel | **Done** (b423db5 — `_on_enemy_killed_beat`/`_on_boss_killed_beat` connected to `DungeonRunOrchestrator.enemy_killed`/`boss_killed` in `on_enter`, disconnected `on_exit`; enemy_killed now has TWO distinct consumers [existing gold-burst VFX + new hero beat, kept separate]. `_try_party_strike_beat()` = single gated entry: reduce_motion [read AT BEAT TIME] → coalescing [`BEAT_THROTTLE_MS`=120 ms anti-strobe via an injectable `_beat_now_ms` clock seam, `_last_beat_ms` init `-window`, mirroring `AudioRouter._throttle_now_ms`] → empty-party; a suppressed beat leaves the clock untouched. `_start_strike_tween()` = ONE shared party tween [`_active_beat_tween`], killed-and-replaced per beat [no cascade stacking], out-punch→settle via `set_parallel`+`chain`, `.from()` clean rest, centred pivot; party-aggregate per GDD §C.5/OQ-35-1. `_set_party_idle_animating` refactored onto a shared `_party_hero_slots()` helper. `on_exit` kills+clears the tween. Brightness flash built by component from `Color.WHITE` [keeps the no-hardcoded-Color manifest guard strict]. Story 007 source guard still green [tokens live only in beat methods, never `_on_tick_fired`]. Verified: 8 new integration tests [wiring; kill+boss fire when motion on; reduce_motion suppression w/ same-clock re-enable proof; 1000/1119/1120 coalescing boundary + `BEAT_THROTTLE_MS==120` pin; empty-party; end-to-end signal emission; on_exit kills tween] — 46/46 screen, 12/12 animator, 0 orphans, no new warnings) | ADR-0025 |
| 009 | `run_defeated` slump beat + win victory beat, coordinated with the run-end overlay (also addresses GDD #24 OQ-24-6) | P2 Reactions | Visual / Feel | **Done** (two new additive consumers — `_on_floor_cleared_beat` [← `floor_cleared_first_time`, skips `losing_run` exactly as the lantern-glow VFX does] → **victory beat**; `_on_run_defeated_beat` [← `run_defeated`] → **defeat slump** — connected `on_enter`, disconnected `on_exit`; each signal now has TWO distinct consumers [existing overlay/VFX feedback + new hero beat, kept separate]. Shared `_play_terminal_beat(victorious)` is **one-shot** via a `_terminal_beat_played` latch [reset in `on_enter`]: kills+replaces `_active_beat_tween`, reads `reduce_motion` **at beat time**. Victory = out-and-back scale punch [`1.0→1.10→1.0` via `BEAT_OUT_PHASE_RATIO`] + brightness bloom [`1.30`, built by component from `Color.WHITE`], TRANS_BACK/EASE_OUT→TRANS_SINE/EASE_IN; defeat = ONE-WAY **held** slump [scale `1.0→(0.97, 0.90)` + dim `→0.80`, NO chain-back — holds *under* the defeat overlay], TRANS_SINE/EASE_IN_OUT. Bottom-center pivot conveys §D.4 rise/sag without a `position` tween [HBox-managed child — scale+modulate only]. **Route ownership UNCHANGED**: `_on_state_changed`→RUN_ENDED stays the SOLE route+idle-freeze decision point [no double-route, AC-35-05 / §E.5]; the beats animate sprites only. **Precedence §E.9**: the latch gates `_try_party_strike_beat` [new gate 0, blocks a late kill striking after a terminal beat] and `_play_terminal_beat` supersedes an in-flight boss strike. Durations VICTORY_BEAT_MS=600 / DEFEAT_SLUMP_MS=700 both `<` RUN_END_DWELL_MS=1500 [test-pinned]. reduce_motion defeat → `_apply_defeat_slump_static` instant pose [§C.8, alpha stays 1.0 — heroes visible+dimmed]; reduce_motion victory = rest no-op. Color manifest guard + Story 007 hot-path source guard both still green. Verified: 11 new integration tests [wiring; victory-no-route; duration-cap; losing-run-no-victory-no-latch; defeat-slump-coordinated-no-route; victory-supersedes-boss-then-latch-blocks-late-kill; reduce_motion victory-suppressed-visible; reduce_motion defeat-static-dimmed; reads-RM-at-beat-time; empty-party no-op; on_exit kills terminal tween] — **57/57 screen suite pass, 0 orphans, no new warnings**) | ADR-0025, 0021 |
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

**Phase 0 (Design & Architecture) COMPLETE** — Stories 001–004 done: GDD #35 (`design/gdd/hero-combat-animation.md`, 8 sections + I/J; systems-index #35; #24 §F reverse-dep) · art-bible §5 ("Dungeon Combat Presence" + "Per-Class Action Poses" 4-beat table) · UX spec ("Hero Combat Presence (GDD #35)": center-stage placement, AGGREGATE HP decisive, z=1 sharp-plane layering, read-only, additive `PartyDioramaLayer`) · **ADR-0025 Accepted** (locks the §C.3 "two clocks, never the tick" sync model + §C.9 zero-alloc hot-path rule + reduce-motion suppression that Phases 1–3 build against).

**Phase 1 (Heroes On-Screen) COMPLETE** — Stories 005–007 done. Story 005 added an additive `PartyDioramaLayer` (sibling on root, `MOUSE_FILTER_IGNORE`, z=1 sharp plane in front of the tilt-shift DoF) holding a centered `PartyFrontLine` HBox of 72px nearest-neighbour `TextureRect` slots, one per OCCUPIED formation slot (count **data-driven** from `HeroRoster.get_formation_heroes()`, proven by 3/2/0-hero tests — never the hardcoded 3 the dominant bug class would have produced), each slot's `class_id` stashed in the `&"hero_class_id"` meta. Story 006 swapped the static frame-0 set in `_make_hero_slot()` for `ClassSpriteFactory.animate(slot, class_id)`, attaching a `_process`-driven `SpriteSheetAnimator` child `&"_IdleAnimator"` that loops the class breathing idle — structurally decoupled from `_on_tick_fired` (ADR-0025 §C.9 "two clocks, never the tick"), a zero-per-frame no-op when art is absent. Story 007 added `SpriteSheetAnimator.set_animating()` (index-preserving pause/resume honouring the ≤1-frame static-card invariant) + the screen helper `_set_party_idle_animating()`, hooked into `_on_state_changed`→RUN_ENDED to **freeze** the party idle as the §C.4 baseline transition, and landed the **AC-35-06 [BLOCKING]** hot-path guard in the CI-run integration suite (`tests/perf/` is NOT in CI) as a source-level token check on the extracted `_on_tick_fired` body — proven non-vacuous by inject-and-revert. Cumulative verification: 12/12 animator unit, 14/14 factory unit, 38/38 `dungeon_run_view_screen` integration — 0 orphans.

**Story 008 (Phase 2) COMPLETE** (b423db5) — `enemy_killed` / `boss_killed` now drive a party-aggregate strike/flash **reaction beat** via `create_tween()`, the first beat that makes the heroes visibly *react* to combat. The gated entry point `_try_party_strike_beat()` enforces ADR-0025's three gates in order — reduce_motion read AT BEAT TIME, then `BEAT_THROTTLE_MS`=120 ms anti-strobe coalescing (injectable `_beat_now_ms` clock seam + `-window` init, mirroring `AudioRouter`), then empty-party — and a single shared `_active_beat_tween` is killed-and-replaced per beat (no cascade stacking) and killed on `on_exit`. enemy_killed keeps the existing gold-burst VFX as a separate consumer. The Story 007 AC-35-06 [BLOCKING] hot-path source guard stays green. Verified: 8 new integration tests (46/46 `dungeon_run_view_screen`, 12/12 animator, 0 orphans, no new warnings).

**Story 009 (Phase 2) COMPLETE** — `floor_cleared_first_time` (win) and `run_defeated` (loss) now drive terminal **hero-sprite** beats as *additive* consumers alongside the existing overlay/VFX feedback: a dignified one-way **defeat slump** (scale-sag + dim, held under the defeat overlay per ADR-0021) and an out-and-back **victory punch** (scale bloom + brightness). The shared `_play_terminal_beat()` is a one-shot latch (`_terminal_beat_played`) that supersedes any in-flight boss strike and, via a new gate-0 on `_try_party_strike_beat`, blocks a late kill from striking after the run ends (§E.9 precedence). Crucially the beats animate sprites ONLY — `_on_state_changed`→RUN_ENDED remains the SOLE route+idle-freeze decision point, so there is **no double-route** (AC-35-05/§E.5), and both terminal durations (600/700 ms) finish inside RUN_END_DWELL_MS=1500. reduce_motion shows the defeat pose instantly (heroes visible+dimmed, §C.8); victory's rest state is a no-op. Also resolves GDD #24 OQ-24-6. Verified: 11 new integration tests, 57/57 `dungeon_run_view_screen` pass, 0 orphans, no new warnings.

**Now: Phase 2 — Story 010** — reduce-motion suppression **sweep** across *all* idle + reaction beats (idle loops, strike beats, terminal beats), consolidating the per-beat `reduce_motion`-read-at-beat-time checks already present in Stories 006–009 into one audited, test-covered guarantee (precedent: `prestige_fade_animation_test` AC-PR-18). Completing Story 010 closes Phase 2 (Reaction Beats). Phase 3's per-class art (Story 011, image-gen key) + Phase 4's human playtest (Story 016) remain the external-dependency gates surfaced to the user.
