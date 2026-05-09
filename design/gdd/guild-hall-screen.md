# Guild Hall Screen — GDD #19

> **Status: First-pass DRAFT 2026-05-07** by autonomous-execution session. All 8 required sections (A–H) + 2 supplemental (I Open Questions, J Implementation Sequencing) per `.claude/docs/coding-standards.md`. **Mixed reverse-doc + forward-spec:** the screen has a Sprint 8 S8-M4 stub shipped (single Dispatch nav button); this GDD specifies the full MVP Guild Hall surface. Run `/design-review` before declaring APPROVED.

---

## A. Overview

**Guild Hall** is the **home screen** the player sees most. After cold-launch (per Onboarding GDD #29), after a dispatched run completes (per Dungeon Run View GDD #24 routes here), after dismissing Settings (per Settings GDD #30) or Return-to-App (per GDD #20) — Guild Hall is where the player returns. It owns:

1. **Roster panel** — visible list of all owned heroes (per HeroRoster #9 `_heroes` Dictionary), sortable
2. **Gold counter** — top-right, live-updating from Economy.gold_changed
3. **Dispatch nav button** — primary CTA, routes to formation_assignment
4. **Recruit nav button** — routes to recruit_screen (#21), gated on `Economy._gold_balance >= cheapest pool entry cost`
5. **Settings gear icon** — top-right corner, opens Settings overlay (#30) via SceneManager.show_modal — gated on `OfflineProgressionEngine.is_replay_in_flight() == false`

The MVP shipped state (Sprint 8 S8-M4) is a stub: just the Dispatch nav button. The full-screen authoring is Sprint 14+ scope (S14 candidate; not currently in sprint-14.md but should be).

The screen is **read-only on roster/gold panels** — the player observes their state. Only the nav buttons + gear icon are interactive.

---

## B. Player Fantasy

> *"I open the game. I see my heroes — there's Theron, my warrior. I see my gold — 450 coins. There's a big 'Dispatch' button glowing softly. There's also a 'Recruit' button — dimmed when I can't afford anything, lit up when I can. The settings gear is in the corner; I rarely touch it but it's there. Everything is parchment-warm; everything is one tap away."*

The cozy register sets the bar: **the home screen has nothing to learn**. Every visible element teaches its own affordance — the gold counter is a number, the Dispatch button is a button, the roster panel shows hero cards (level, class, name). No tutorial overlay; no "tap here to start"; no welcome banner.

Critical Pillar 4 (one-tap-to-action): Dispatch is always the primary CTA. No matter what the player is doing in the game, they should be at most 2 taps away from dispatching: tap "Guild Hall nav back" (if they're elsewhere) → tap "Dispatch". Pillar 2 (run feels meaningful) starts here — the moment of intent before the run.

---

## C. Detailed Rules

### C.1 Layout

PanelContainer applied with parchment theme (`UIFramework.apply_parchment_panel`). Anchors fullscreen.

VBoxContainer rows in order:
1. **HeaderBar** (top, ~80px tall):
   - Left: HeaderLabel — `tr("guild_hall_title")` ("Lantern Guild")
   - Right: GoldCounter (Label with coin icon prefix + integer value) + SettingsGearButton
2. **RosterPanel** (center, scrollable VBox of HeroCard nodes — one card per owned hero, sorted by current_level descending then by class_id alphabetically):
   - Each HeroCard: parchment sub-panel showing display_name + class_id + current_level + a slim XP-progress bar + (V1.0+) class icon
   - HeroCards are non-interactive in MVP — Sprint 14+ Roster / Hero Detail Screen #22 may make them tappable
3. **NavBar** (bottom, ~120px tall):
   - DispatchNavButton (large, parchment-styled, primary CTA)
   - RecruitNavButton (smaller, secondary, dimmed when insufficient gold)

### C.2 Lifecycle hooks

`on_enter`:
- Connect `Economy.gold_changed` → `_on_gold_changed` (idempotent via `is_connected`)
- Connect `HeroRoster.hero_recruited` + `hero_removed` + `hero_leveled` → `_refresh_roster_panel` (sub-handler that rebuilds the HeroCard list)
- Connect `OfflineProgressionEngine.replay_in_flight_changed` → `_refresh_settings_gear_gating` (so the gear icon disables/enables as replay state changes)
- Wire DispatchNavButton.pressed → `_on_dispatch_nav_pressed`
- Wire RecruitNavButton.pressed → `_on_recruit_nav_pressed`
- Wire SettingsGearButton.gui_input → `_on_settings_gear_input` (touch-feedback wired via UIFramework)
- Initial render: `_refresh_gold_counter()`, `_refresh_roster_panel()`, `_refresh_recruit_button_gating()`, `_refresh_settings_gear_gating()`

`on_exit`:
- Disconnect ALL connected signals (idempotent via `is_connected`)

`on_pause` (when Settings overlay opens via show_modal):
- No animation pause needed; the screen has no animations in MVP. Empty body.

`on_resume`:
- Re-render gold + roster (defensive snap, in case the modal mutated state — Settings overlay can change reduce_motion which doesn't affect this screen, but a future modal might).

### C.3 Gold counter

- Reads `Economy._gold_balance` directly on render
- `_on_gold_changed(new_balance, _delta, _reason)` updates the display via `_refresh_gold_counter`
- Display format: `format_localized("guild_hall_gold_format", [new_balance])` ("%d gold" — locale-safe)
- During offline replay: per audio-system.md §F.2, gold_changed fires per gold-add event but the audio chime is throttled to ≤4/sec. The visual counter updates every event (cheap, no throttle) so the player sees the count rise smoothly.

### C.4 Recruit button gating

`_refresh_recruit_button_gating`:
- Reads `Recruitment.get_recruit_pool()` + iterates each pool entry's `get_recruit_cost(i)` to find the cheapest
- If `Economy._gold_balance >= cheapest_cost`: button enabled, full opacity
- Else: button disabled, dimmed (modulate.a = 0.4); tooltip `format_localized("guild_hall_recruit_tooltip_insufficient_format", [cheapest_cost - Economy._gold_balance])` ("Need %d more gold")

Re-fired on every `gold_changed` AND every `pool_refreshed` (recruitment-system.md C.7). The button's gating snaps as gold accrues + as pool refreshes.

### C.5 Settings gear icon gating

`_refresh_settings_gear_gating`:
- If `OfflineProgressionEngine.is_replay_in_flight() == true`: gear disabled, dimmed; tooltip "Settings available after replay completes." per Settings GDD #30 §E.6
- Else: gear enabled, parchment-themed normal

Re-fired on `OfflineProgressionEngine.replay_in_flight_changed` signal (NOT yet shipped — currently OE has `is_replay_in_flight()` getter but no signal for state-change notification — see OQ-19-1 below for the gap).

### C.6 Dispatch nav button

`_on_dispatch_nav_pressed`:
- `SceneManager.request_screen("formation_assignment", SceneManager.TransitionType.CROSS_FADE)`
- Standard 150ms cross-fade

The button is the screen's primary CTA — visually the largest interactive element. Touch-feedback wired via `UIFramework.wire_touch_feedback`. Audio: UI tap chime per S12-M6 AC-AS-14.

### C.7 Recruit nav button

`_on_recruit_nav_pressed`:
- `SceneManager.request_screen("recruit_screen", SceneManager.TransitionType.CROSS_FADE)`
- Same transition pattern as Dispatch
- Disabled state (insufficient gold): tap is no-op (Button.disabled prevents emit); tooltip optionally shows on hover/long-press

### C.8 Settings gear icon

`_on_settings_gear_input(event)`:
- Filters to mouse-button-down OR screen-touch-down (per UIFramework.wire_touch_feedback pattern)
- If gating allows (replay not in flight): instantiates the SettingsOverlay scene + calls `SceneManager.show_modal(settings_overlay)` per Settings GDD #30 §C.1 + S12-S2 contract

### C.9 First-launch render

Per Onboarding GDD #29 §C.3, first-launch arrival at Guild Hall:
- Roster shows seeded Theron (single HeroCard, level 1, warrior)
- Gold counter shows 100 (STARTING_GOLD)
- DispatchNavButton enabled (Theron in formation_slot 0)
- RecruitNavButton dimmed (need 50 more gold)
- SettingsGearButton enabled (no replay in flight)

No "Welcome!" toast. No "Tap Dispatch to begin" arrow. The seeded state IS the tutorial.

### C.10 Save/Load behavior

The screen has NO save state. It's a transient view that re-derives all display from the underlying autoloads (HeroRoster, Economy, Recruitment, OfflineProgressionEngine). On hydration, the screen's state is automatically correct on next render.

### C.11 Locale keys

`assets/locale/en.csv` keys (Sprint 14+ amendment when this GDD's implementation lands):
- `guild_hall_title` — "Lantern Guild"
- `guild_hall_gold_format` — "%d gold"
- `guild_hall_dispatch_button` — "Dispatch"
- `guild_hall_recruit_button` — "Recruit"
- `guild_hall_recruit_tooltip_insufficient_format` — "Need %d more gold"
- `guild_hall_settings_tooltip_replay_in_flight` — "Settings available after replay completes."
- `guild_hall_hero_card_format` — "%s (Level %d %s)" (display_name, level, class_id)
- `guild_hall_hero_card_xp_format` — "XP %d / %d" (current xp, threshold)

---

## D. Formulas

### D.1 Cheapest-recruit gating
`cheapest_cost = min(Recruitment.get_recruit_cost(i) for i in 0..pool_size-1)` — filter -1 (orphan) entries.

### D.2 XP-progress bar fill
Per Hero Leveling GDD #15: `progress_fraction = hero.xp / xp_threshold(hero.current_level)`. Rendered as 0..1 of the bar's width.

### D.3 No other formulas
The screen is pure rendering; gameplay math lives in upstream systems.

---

## E. Edge Cases

### E.1 Empty roster (post-corruption)
If HeroRoster has zero heroes (corruption recovery + first-launch failed; should never happen in production), the RosterPanel shows an empty placeholder "No heroes yet — recruit one to begin." Cozy register; no panic banner.

### E.2 Recruit pool is empty
If `Recruitment.get_recruit_pool().size() == 0` (config drift — should never happen), the RecruitNavButton is disabled with tooltip "No heroes available to recruit." Defensive.

### E.3 Gold counter overflows
`Economy._gold_balance` is clamped to GOLD_SANITY_CAP per Economy GDD §E. The display uses `str(int)` which handles the full int range. No special formatting (no commas, no K/M abbreviation in MVP). Sprint 14+ may add abbreviation if late-game balance produces 9-digit values.

### E.4 Replay-in-flight gear disable
Per OQ-19-1: the OE `replay_in_flight_changed` signal doesn't currently exist. MVP could poll on enter + on every gold_changed, OR add the signal. Recommended: add the signal in Sprint 14+ S14-M3 alongside Settings overlay UI implementation.

### E.5 Tap on disabled Dispatch button
With NO formation members (impossible per current invariants — Theron is always in slot 0 unless explicitly removed), the Dispatch button SHOULD disable. Mitigation: re-fire `_refresh_dispatch_button_gating` on every `formation_slot_changed` signal (not yet declared on FormationAssignment per #17 §C — Sprint 14+ amendment).

### E.6 Settings gear tap during a replay race
Edge: gear is enabled, player taps, BETWEEN tap and modal-show OE starts a replay. Result: modal opens; settings shown; player can adjust. The replay continues in background (per OE replay-in-flight invariant — single concurrent replay). Functional. The gating PREVENTS opening DURING a replay; doesn't prevent after-the-fact.

### E.7 Headless render
Per S12 retro: `_test_play_*_log` patterns + UIFramework's headless-safe helpers. Guild Hall renders correctly without an audio device + without a display (test env).

### E.8 Cold-launch boot timing
Per Onboarding GDD #29 §E.6: cold-launch on min-spec hardware can take 1-2 seconds. The player sees Guild Hall's empty placeholder (PanelContainer + theme + parchment color) for ~500ms while autoloads boot. NOT special-cased in MVP; Sprint 15+ candidate for a loading splash if playtest reveals the cold-launch flash.

### E.9 Multiple rapid Dispatch taps
The first tap fires `request_screen` which transitions the SceneManager to TRANSITIONING. Second tap fires `request_screen` AGAIN — SceneManager queues into `_queued_request` per ADR-0007. The queued request fires after the first transition completes — but that lands at formation_assignment, not back on Guild Hall. So the queued request becomes a re-request to formation_assignment (idempotent if same screen). No crash; minor wasted transition.

### E.10 hero_leveled fires while player is on Guild Hall
Hero Leveling GDD #15 §C.4 multi-level cascade emits N hero_leveled signals. Guild Hall's `_refresh_roster_panel` handler re-renders the affected HeroCard's level + XP bar. Multiple cascading fires within the same frame coalesce visually (Godot's redraw batching) but the data is correct.

---

## F. Dependencies

### Hard dependencies

| System | Why | Surface used |
|---|---|---|
| `Economy` (#5) | Gold counter source | `_gold_balance`, `gold_changed` signal |
| `HeroRoster` (#9) | Roster panel data + gating | `_heroes`, `hero_recruited`/`hero_removed`/`hero_leveled` signals, `display_name` lookup |
| `Recruitment` (#14) | Recruit button gating | `get_recruit_pool`, `get_recruit_cost(i)`, `pool_refreshed` signal |
| `SceneManager` (#4) | Routing + modal show | `request_screen`, `show_modal`, `transition_complete` |
| `OfflineProgressionEngine` (#12) | Settings gear gating | `is_replay_in_flight()`, `replay_in_flight_changed` (NOT YET SHIPPED — see OQ-19-1) |
| `UIFramework` (#18) | Theme + helpers | `apply_parchment_panel`, `wire_touch_feedback`, `format_localized`, `suppress_keyboard_focus` |
| `Screen` base class (#18 §C.2) | Lifecycle hooks | on_enter / on_exit / on_pause / on_resume |
| `assets/locale/en.csv` | Locale keys | 8 keys per §C.11 |
| `Settings overlay` (#30) | Modal opened from gear icon | Instantiate scene + call `SceneManager.show_modal(modal)` |

### Reverse dependencies

- `Onboarding` (#29) — Guild Hall is the first screen the player sees on first-launch
- `Dungeon Run View` (#24) — routes here on RUN_ENDED auto-route
- `formation_assignment` (#17) — back-navigation lands here (per ADR-0007 transition contract)
- `Recruit Screen` (#21) — back-navigation lands here

### V1.0 progression-layer additions (added 2026-05-09)

The following V1.0-tier system extends this screen:

- **Prestige System** (#31, V1.0 first-pass 2026-05-09) — adds a "Hall of Retired Heroes" button visible only when `HeroRoster._retired_hero_records.size() > 0` (i.e., the player has prestiged at least one hero). The button routes to a new gallery view showing retired-hero portraits with parchment-warm laurel crown overlays per Art Bible Visual Identity Anchor. Locale key: `hall_of_retired_heroes_title`. The button is hidden in fresh-save first-launch state and reveals after the first prestige action. Per `prestige-system.md` §C.4 + §F.

---

## G. Tuning Knobs

### Header bar height
- ~80px at Steam Deck native (1280×800). Tunable via .tscn min_size.

### Roster panel scroll behavior
- ScrollContainer with snap-to-card scrolling (Sprint 14+ may polish). MVP: simple vertical scroll.

### Recruit button gating threshold
- `cheapest_cost` per Formula D.1. Tunable indirectly via Economy.BASE_RECRUIT + RECRUIT_RATIO + Recruitment pool generation.

### Settings gear position
- Top-right corner. Locked per cozy register convention; not a knob.

---

## H. Acceptance Criteria

**AC-19-01 — Gold counter displays Economy._gold_balance**
On enter: `_gold_label.text` matches `format_localized("guild_hall_gold_format", [Economy._gold_balance])`.

**AC-19-02 — Gold counter updates on gold_changed**
Subscribe + emit `gold_changed(450, 50, "kill")`. `_gold_label.text` matches new value within one frame.

**AC-19-03 — Roster panel shows one HeroCard per hero in HeroRoster._heroes**
With 3 heroes seeded: 3 HeroCard children spawned in RosterPanel. Each card displays the hero's display_name + class_id + current_level.

**AC-19-04 — Roster panel updates on hero_recruited**
Subscribe to `HeroRoster.hero_recruited(instance: HeroInstance)` (1-arg per `hero_roster.gd:170`; NOT the 3-arg `Recruitment.hero_recruited` — see Cross-GDD Consistency Sweep 2026-05-07 for the dual-source disambiguation). Emit with a fresh `HeroInstance` (instance_id=4, class_id="mage"). A new HeroCard appears for hero id 4. Card count increases by 1.

**AC-19-05 — Roster panel updates on hero_removed**
Same pattern, removal.

**AC-19-06 — Roster panel updates on hero_leveled**
Subscribe + emit `hero_leveled(1, 4, 5)`. The HeroCard for hero 1 reflects current_level=5.

**AC-19-07 — Dispatch button routes to formation_assignment**
Tap DispatchNavButton → `SceneManager.request_screen("formation_assignment", CROSS_FADE)` invoked.

**AC-19-08 — Recruit button gating: enabled when affordable**
With Economy._gold_balance >= cheapest_pool_cost: button enabled, modulate.a == 1.0.

**AC-19-09 — Recruit button gating: disabled when not affordable**
With Economy._gold_balance < cheapest_pool_cost: button disabled, modulate.a < 1.0.

**AC-19-10 — Recruit button routes to recruit_screen**
With sufficient gold: tap → `SceneManager.request_screen("recruit_screen", CROSS_FADE)`.

**AC-19-11 — Settings gear opens overlay via show_modal**
Tap gear (with replay not in flight): SettingsOverlay scene instantiated; `SceneManager.show_modal(modal)` invoked.

**AC-19-12 — Settings gear gating: disabled during replay**
With `OfflineProgressionEngine.is_replay_in_flight() == true`: gear disabled, modulate.a < 1.0. Tap is no-op.

**AC-19-13 — on_exit disconnects all connected signals**
After on_exit: gold_changed / hero_recruited / hero_removed / hero_leveled / pool_refreshed / replay_in_flight_changed all `is_connected == false`.

**AC-19-14 — Touch feedback wired on all interactive Controls**
DispatchNavButton, RecruitNavButton, SettingsGearButton all have `_TOUCH_FEEDBACK_META`. Tap fires `sfx_ui_tap` per S12-M6 AC-AS-14.

**AC-19-15 — Locale keys all present in en.csv**
8 keys per §C.11 exist with non-empty translations.

---

## I. Open Questions & ADR Candidates

**OQ-19-1 — `OfflineProgressionEngine.replay_in_flight_changed` signal**
The Settings gear gating in §C.5 needs a state-change signal so the gear icon enables/disables reactively. Currently OE has `is_replay_in_flight()` getter but no change signal. Sprint 14+ amendment to OE: declare `signal replay_in_flight_changed(in_flight: bool)` + emit at the boundaries of `run_offline_replay`. Sprint 14+ scope; not gating MVP since OE replay only fires at boot (Settings gear is enabled by the time the player can interact with Guild Hall).

**OQ-19-2 — HeroCard interactivity**
MVP locks HeroCards as non-interactive. Sprint 14+ Roster / Hero Detail Screen #22 may make them tappable to navigate to a detail view. Needs UX pass for the card-tap affordance.

**OQ-19-3 — Late-game gold abbreviation**
9-digit gold values overflow the header bar. Sprint 15+ candidate for K/M/B abbreviation.

**OQ-19-4 — Cold-launch loading splash**
Per Onboarding GDD #29 OQ-29-1: min-spec hardware shows empty Guild Hall for ~500ms. A parchment loading splash would mask this. Sprint 15+ candidate.

**OQ-19-5 — First-launch celebration**
Should the FIRST-EVER Guild Hall view show a subtle "Welcome to the Lantern Guild" subtitle (one line, fades in 500ms, fades out after 3s)? MVP says NO — strictly diegetic. V1.0+ may add as a soft onboarding accent.

**OQ-19-6 — Roster sort options**
Currently sorted by current_level descending then class_id alphabetically. Sprint 14+ may add player-choosable sort (level / class / display_name / recruit-date). UX pass needed.

---

## J. Implementation Sequencing (mixed reverse-doc + Sprint 14+ scope)

The Sprint 8 S8-M4 stub shipped only the DispatchNavButton (~30 lines). Full Guild Hall authoring is **Sprint 14+ scope** (NOT yet in sprint-14.md; should be added):

1. **Story 1 (~0.5d)** — Header bar (HeaderLabel + GoldCounter + SettingsGearButton). Wire gold_changed subscription + initial render. ACs 19-01, 19-02, 19-15.
2. **Story 2 (~1.0d)** — Roster panel + HeroCard subscene authoring. Wire hero_recruited / hero_removed / hero_leveled subscriptions. ACs 19-03, 19-04, 19-05, 19-06.
3. **Story 3 (~0.5d)** — Recruit nav button + gating logic. Wire pool_refreshed + gold_changed → re-render. ACs 19-08, 19-09, 19-10.
4. **Story 4 (~0.5d)** — Settings gear icon + show_modal integration. ACs 19-11, 19-12. **Depends on `replay_in_flight_changed` signal landing in OE per OQ-19-1.**
5. **Story 5 (~0.25d)** — locale keys in en.csv. AC-19-15.
6. **Story 6 (~0.25d)** — Integration test at `tests/integration/scene_manager/guild_hall_screen_test.gd`. Cover ACs 19-01 through 19-15.

Total Sprint 14+ scope: ~3.0 days. Larger than typical screen because Guild Hall integrates 4 autoloads + 2 navigation paths + 1 modal entry point.

---

## Notes

- Authored 2026-05-07 by autonomous-execution session. Mixed reverse-doc (Sprint 8 S8-M4 stub) + forward-spec (full MVP screen).
- This GDD has NOT yet had a `/design-review` pass. Run before declaring APPROVED. Expect 5-10 BLOCKING items per first-pass-GDD precedent.
- Closes the design-coverage gap that's existed since project inception. systems-index.md row 19 ("Not Started" since Sprint 1) flips to DRAFT.
- 7 first-pass GDDs drafted this autonomous-execution session (Settings #30, Hero Leveling #15, Onboarding #29, UI Framework #18, Return-to-App #20, Dungeon Run View #24, Guild Hall #19). systems-index "Not Started" count: 14 → 8.
- Sprint 14 plan should add this implementation as a new Must Have or Should Have row (currently silent on Guild Hall).
