# Recruit Screen — GDD #21

> **Status: First-pass DRAFT 2026-05-07** by post-Sprint-14-S14-N2 close-out autonomous-execution session, continuing the Sprint-14-prep design-coverage push (Settings/Hero Leveling/Onboarding/UI Framework/Return-to-App). All 8 required sections (A–H) + 2 supplemental (I Open Questions, J Implementation Sequencing) per `.claude/docs/coding-standards.md`. Run `/design-review` before APPROVED. Closes the systems-index #21 "Not Started" gap that has existed since project inception. Unblocks Sprint 14 S14-S4 (RecruitScreen UI implementation, currently held on "needs UX pass for recruit-card layout").

---

## A. Overview

**Recruit Screen** is the Guild Hall sub-screen where the player browses the deterministic recruit pool (3 entries per ADR-0015 / `Recruitment.POOL_SIZE = 3`) and spends gold to grow their roster. Each pool entry shows class portrait + class name + recruit cost + ownership count; tapping "Recruit" calls `Recruitment.try_recruit(pool_index)` which atomically charges Economy gold and adds a hero to HeroRoster. A "Refresh pool" button rerolls all 3 entries for `refresh_cost(refreshes_today)` gold. The screen also displays a persistent "back to Guild Hall" navigation.

The screen is **read-only on roster panel state** — the player observes their gold balance + ownership counts, but can only mutate state via the Recruit and Refresh buttons. State changes propagate live via `Recruitment.pool_refreshed` and `HeroRoster.hero_recruited` signals.

This GDD documents the Sprint 14 S14-S4 implementation target (Recruitment GDD `recruitment-system.md` §J Story 7 — RecruitScreen wire-up) and the screen-side ACs that pair with the autoload-side ACs in `recruitment-system.md` §H.

---

## B. Player Fantasy

> *"I open the Recruit screen. I see three classes — a Warrior, a Rogue, a Mage. Their costs are 150g, 270g, 8000g. I have 1100g — I can afford the first two but not the Mage. The Recruit buttons under the affordable ones are bright; the Mage's is dimmed but still shows the cost so I know what to save for. I tap 'Recruit' on the Warrior; my gold drops to 950g, the entry shows '(owned: 4)' instead of '(owned: 3)' as the new copy slots into my roster, and the cost on that row jumps to 270g (the next-copy cost). No surprises, no timers, no FOMO. I leave when I want; the pool stays the same on next visit."*

The cozy register applies, per the `recruitment-system.md` §B Player Fantasy:
- **Anticipation, not anxiety.** Costs are deterministic per ADR-0013; what the player sees is what they'll be charged at try_recruit time.
- **No timers, no limited-time offers.** Pool entries refresh on first-clear OR on paid refresh — both player-controlled triggers.
- **Owned-count visible at all times.** The recruit cost increases per copy already owned (`recruit_cost(class_id, copies_owned)` per ADR-0013); showing `(owned: N)` per row makes the curve legible.
- **Insufficient-gold rows are dimmed but informative.** Player can see what they'd need to save up; never hidden, never grayed-out-without-explanation.

The screen is the second player-facing destination after Guild Hall (per Guild Hall GDD #19 §C.7 RecruitNavButton routing). Its presence in the cozy register is "the long-game shop where I plan upgrades", contrasted with Guild Hall ("the home I return to") and the dungeon run view ("the tense moment of dispatch").

---

## C. Detailed Rules

### C.1 Layout

The Control hierarchy follows the Guild Hall pattern (per `guild-hall-screen.md` §C.1):

```
recruit_screen.tscn (Control, anchors_preset = 15 full-rect)
├── HeaderBar (PanelContainer, parchment-themed via UIFramework.apply_parchment_panel)
│   ├── BackButton (Button, "← Guild Hall", parchment-themed)
│   ├── Spacer
│   ├── ScreenTitleLabel (Label, "Recruit", IdentityHeader theme variation)
│   ├── Spacer
│   └── GoldCounter (Label, parchment-themed; mirrors Guild Hall §C.3 layout)
├── PoolPanel (PanelContainer, parchment-themed; vertical scroll via VBoxContainer if pool grows past 3)
│   ├── PoolEntry[0] (HBoxContainer)
│   │   ├── ClassPortrait (TextureRect, 96×96 logical px placeholder; pulls from HeroClass.portrait when present)
│   │   ├── EntryDetails (VBoxContainer)
│   │   │   ├── ClassNameLabel (Label, IdentityHeader theme variation)
│   │   │   ├── CostLabel (Label, "150g")
│   │   │   └── OwnedLabel (Label, "(owned: 3)" — small text, slate-ink secondary color)
│   │   └── RecruitButton (Button, "Recruit", parchment-themed; SelectedSlotButton variation when affordable)
│   ├── PoolEntry[1] — same shape
│   └── PoolEntry[2] — same shape
└── FooterBar (PanelContainer)
    └── RefreshPoolButton (Button, "Refresh Pool (250g)", parchment-themed; cost label is dynamic)
```

Sizing/spacing notes (anchored to UIFramework + Art Bible §4):
- HeaderBar height: 60–80 logical px (consistent with Guild Hall HeaderBar).
- PoolPanel pool-entry row height: ≥120 logical px (96 portrait + 24 padding) to keep tap target ≥44×44 per `.claude/docs/technical-preferences.md` Touch Support requirement.
- Vertical spacing between entries: 8–16 logical px parchment gutter.
- FooterBar height: 60–80 logical px (consistent visual weight with HeaderBar).
- Total screen height target: fits 1280×800 Steam Deck native + 800px-tall mobile portrait; if pool grows past 3 entries (post-MVP scope), VBoxContainer scrolls.

### C.2 Lifecycle hooks

`recruit_screen.gd` extends `Screen` (per `src/core/scene_manager/screen.gd`); on_enter / on_exit / on_pause / on_resume per the existing screen pattern.

**on_enter:**
- Connect `Recruitment.pool_refreshed` → `_on_pool_refreshed` (re-renders all 3 entries when pool rerolls)
- Connect `HeroRoster.hero_recruited` → `_on_hero_recruited` (refreshes the affected entry's owned-count + cost; refreshes gold counter)
- Connect `Economy.gold_changed` → `_on_gold_changed` (refreshes gold counter + recruit-button affordability gating across all entries)
- Wire BackButton.pressed → `_on_back_pressed`
- Wire RecruitButton[i].pressed (per entry) → `_on_recruit_pressed.bind(i)` (BIND captures pool_index per row)
- Wire RefreshPoolButton.pressed → `_on_refresh_pressed`
- Touch-feedback wired on all buttons via `UIFrameworkScript.wire_touch_feedback` (idempotent via meta sentinel per S10-M2)
- Initial render: `_refresh_pool_panel()`, `_refresh_gold_counter()`, `_refresh_refresh_button_cost()`

**on_exit:**
- Disconnect all 3 signals + 3 + N button presses (where N = POOL_SIZE recruit buttons)

**on_pause / on_resume:**
- pass — no per-frame state; screen rebuilds via on_enter on re-entry

### C.3 Gold counter

Same contract as `guild-hall-screen.md` §C.3:
- Reads from `Economy.get_gold_balance()` on enter + on every `gold_changed` signal
- Format via `format_short_number` from UIFramework when balance ≥ 1000 ("1.2k", "4.5M") per Economy GDD §G display thresholds
- Updated reason-string-aware: `gold_changed(new_balance, delta, reason)` — the `reason == "recruit"` causes a brief +/- amber pulse animation on the counter (subtle, ≤300ms) to confirm the spend; other reasons render without pulse

### C.4 Pool entry render

`_refresh_pool_panel()`:
1. Read `Recruitment.get_recruit_pool() -> Array[String]` (returns deep copy of `_current_pool`)
2. For each pool_index (0..2):
   a. Resolve class via `DataRegistry.resolve("classes", class_id)` — returns HeroClass resource
   b. If null (orphan class — content patch removed it): hide the row + push_warning. Defensive against save corruption / content drift.
   c. Set ClassPortrait.texture from HeroClass.portrait (placeholder when absent)
   d. Set ClassNameLabel.text from HeroClass.display_name (locale-aware via TranslationServer.translate)
   e. Set CostLabel.text from `Recruitment.get_recruit_cost(pool_index)` formatted via `format_short_number`
   f. Set OwnedLabel.text to localized "(owned: %d)" % HeroRoster.get_copies_owned(class_id) — uses `tr("recruit_owned_format")`
   g. Set RecruitButton.disabled based on affordability: `Economy.get_gold_balance() >= cost`
   h. Set RecruitButton theme variation: SelectedSlotButton (warm) when affordable; default (dimmed) when not

Re-rendered on every `pool_refreshed`, `hero_recruited`, `gold_changed`. Each re-render is idempotent (readers observe whatever state is current at the call moment).

### C.5 Recruit interaction

`_on_recruit_pressed(pool_index: int)`:
1. Defensive check: `pool_index in [0, POOL_SIZE)` — push_warning + return on out-of-range (race condition during refresh)
2. Call `Recruitment.try_recruit(pool_index) -> RecruitOutcome` (per `recruitment.gd:198` — returns the enum at `recruitment.gd:47` with values `SUCCESS / INSUFFICIENT_GOLD / ROSTER_FULL / INVALID_POOL_INDEX / UNRESOLVABLE_CLASS_ID`)
3. Match on the returned enum:
   - `SUCCESS`: `Recruitment.try_recruit` already handled atomic try_spend + add_hero; signals fire (`HeroRoster.hero_recruited(instance)` 1-arg from HeroRoster — see §F dependency table — AND `Recruitment.hero_recruited(instance_id, class_id, cost_paid)` 3-arg from Recruitment with the cost-paid summary; `gold_changed` from Economy with reason="recruit"). Screen subscribers re-render automatically.
   - `INSUFFICIENT_GOLD`: `_show_toast(tr("recruit_error_insufficient_gold"))` — "Not enough gold."
   - `ROSTER_FULL`: `_show_toast(tr("recruit_error_roster_full"))` — "Roster full." (MVP — no dismiss UI yet; V1.0+ may extend with action hint when retire UI ships)
   - `UNRESOLVABLE_CLASS_ID`: `_show_toast(tr("recruit_error_unresolvable_class"))` — "This class is no longer available." (orphan class — content drift defensive)
   - `INVALID_POOL_INDEX`: defensive race condition (visibility check should prevent); push_warning + skip toast (player retap re-evaluates pool)

The "atomic" semantic per Recruitment GDD §C.5 (single-writer + try_spend → add_hero) means partial failures cannot occur — either both happen or neither does. The screen does not need rollback handling; it just listens for failure-outcome enum values.

### C.6 Pool refresh interaction

`_on_refresh_pressed()`:
1. Read current cost: `Recruitment.refresh_cost(Recruitment.get_refreshes_today())` — both accessors exist as of Sprint 16 S16-N1 (per Cross-GDD Consistency Sweep 2026-05-07 §Self-documented gap closure). The screen passes the session-paid-refresh count to the cost-curve formula without touching the private `_refreshes_today` field.
2. Defensive check: `Economy.get_gold_balance() >= cost` — disable button if insufficient (mirrors C.4 affordability)
3. Call `Recruitment.refresh_pool_paid() -> bool`
4. On true: `pool_refreshed` signal fires → `_on_pool_refreshed` re-renders. Refresh button cost label updates via `_refresh_refresh_button_cost` (the refreshes_today counter incremented)
5. On false: toast "Not enough gold." (race condition — gold dropped between visibility check and call)

The refresh button is **always visible**, even when unaffordable. Dimmed when unaffordable; player sees the cost they'd need to save up (consistent with C.4 cost-visible-when-unaffordable rule).

### C.7 Free refresh on first-clear

When `floor_cleared_first_time` fires (cross-screen — the player can be in the dungeon_run_view while this fires), Recruitment auto-refreshes the pool internally. If the player THEN navigates to the Recruit screen, on_enter renders the new pool. No special UI handling — `pool_refreshed` signal is the canonical notification path; whether the player is currently on the screen is irrelevant.

Edge case: if the player IS on the recruit screen when `floor_cleared_first_time` fires (rare but possible in V1.0 with offline-replay-during-screen sequencing), the pool re-renders mid-screen with a soft parchment-fade transition (300ms cross-fade per ADR-0008 timing).

### C.8 Settings overlay co-existence

The Recruit screen does NOT have its own Settings gear icon (per Guild Hall GDD #19 §C.5 — the gear icon lives only on Guild Hall). Player exits to Guild Hall to access Settings.

### C.9 Empty pool handling

If `Recruitment.get_recruit_pool()` returns an empty Array (orphan-class refresh failure or first-launch race), render a single placeholder row: "No heroes available. Tap Refresh Pool to reroll." Refresh button remains active. push_warning on empty-pool render so test-env flakes surface in CI logs.

This state is genuinely unexpected in production (Recruitment seeds the pool on _ready per ADR-0015); the placeholder is a cozy safety net rather than a regular state.

---

## D. Formulas

### D.1 Recruit cost (cross-reference)

Per ADR-0013 + `recruitment-system.md` §D.1:
```
recruit_cost(class_id, copies_owned) = floori(BASE_RECRUIT[tier] × RECRUIT_RATIO^copies_owned)
```
Read via `Recruitment.get_recruit_cost(pool_index)` which resolves `class_id` from the pool entry + queries `HeroRoster.get_copies_owned`.

The Recruit screen does NOT compute this independently — it READS via the accessor. Cost-stability per AC-RC-11 (recruitment-system.md §H): the cost shown at render time is the cost charged at try_recruit time, even if `copies_owned` increments between (the next render cycle picks up the new value).

### D.2 Refresh cost (cross-reference)

Per `recruitment-system.md` §D.2 + ADR-0015:
```
refresh_cost(refreshes_today) = BASE_REFRESH_COST × (1 + REFRESH_COST_MULT × refreshes_today)
```
Where defaults: `BASE_REFRESH_COST = 250`, `REFRESH_COST_MULT = 2.0`.

So:
- 1st refresh today: 250g
- 2nd refresh today: 750g
- 3rd refresh today: 1250g
- … etc.

Player-controlled gate against spam-rerolling. The Recruit screen displays the CURRENT cost (next refresh's cost) in the Refresh button label.

### D.3 Affordability check

```
is_affordable(cost) = Economy.get_gold_balance() >= cost
```
Pure read; does NOT mutate state. Used in C.4 (per-row recruit-button gating) + C.6 (refresh-button gating).

### D.4 Owned-count display

Per `hero-roster.md`:
```
owned(class_id) = HeroRoster.get_copies_owned(class_id)
```
Returns the count of heroes with the given class_id currently in the roster. Used in C.4 row render.

---

## E. Edge Cases

### E.1 Insufficient gold for any pool entry
Player has gold < cheapest pool entry cost. All RecruitButtons dimmed. Refresh button gated separately on `refresh_cost`. Screen still navigable; player can browse + leave to grind dungeons. This is the cozy "save-up" UX — the screen INFORMS the player of what they need without blocking access.

### E.2 Roster full at recruit time
Player at `_heroes.size() == max_roster_size()`. `try_recruit` returns false with reason="roster_full" (per Recruitment §E.2). Screen shows toast. MVP has no dismiss UI; player must spend heroes via dungeon dispatch (which doesn't actually remove them — V1.0+ adds a roster-dismiss UI). Toast text reflects MVP reality: "Roster full." (no action hint).

### E.3 Pool entry's class becomes unresolvable mid-screen
Content patch / live-ops removes a class. DataRegistry returns null on next resolve. Affected row is hidden via push_warning per C.4 step 2.b. Refresh Pool corrects on next reroll. Defensive but not a normal state.

### E.4 Pool refresh during a recruit attempt
Race condition: player taps Recruit at pool_index=2; before try_recruit completes, `floor_cleared_first_time` fires, triggering `Recruitment.refresh_pool()` internally. The pool changes between the player's tap and the `try_recruit` execution. Per Recruitment GDD §E.5, `try_recruit` is single-frame atomic — the pool_index resolved at call time matches the pool that was current at call time. The newly-rolled pool replaces afterward; screen re-renders via `pool_refreshed` after the recruit completes. Player gets the hero they tapped on; the post-recruit pool reflects the auto-refresh.

### E.5 Pool already fully owned (corner case)
All 3 pool entries are classes the player already owns at high copies-count. Costs are all visible but high. Affordability gating is the primary gate. Cozy-register-correct: the player can refresh (paid) to seek lower-cost slots, or save up + recruit anyway (the cost curve is monotonic per ADR-0013 — every recruit makes the next more expensive but the player owns the choice).

### E.6 Save / load mid-screen
Player is on Recruit screen when SaveLoadSystem persists (heartbeat or scene boundary). Per Recruitment §C.8 + ADR-0004, `_suppress_signals == true` during hydration suppresses pool_refreshed. The screen's on_enter re-renders fresh on next visit. Mid-screen re-render during a heartbeat-persist is suppressed by the same flag chain at the autoload layer; screen subscribers don't fire spurious refreshes.

### E.7 First-launch with empty pool
First-launch race: Recruitment seeds pool on _ready BEFORE first Guild Hall navigation. By the time the player taps RecruitNavButton on Guild Hall, the pool is populated. If a save-corruption path leaves the pool empty (E.7 of recruitment-system.md), C.9 placeholder renders. Refresh Pool corrects.

### E.8 Locale change mid-screen
Player toggles locale in Settings (Vertical Slice tier — not MVP). All text re-renders on next on_enter; static labels would not update mid-screen (MVP doesn't ship locale toggle on this screen). When locale toggle ships in V1.0+, the screen subscribes to TranslationServer.locale_changed and triggers a full re-render.

### E.9 reduce_motion accessibility flag
Per ADR-0008 + Settings GDD #30, reduce_motion = true disables the gold-counter pulse animation (C.3) and the pool-fade transition (C.7). Recruit Button touch-feedback (UIFramework.wire_touch_feedback) is reduced to a 1.0× scale (no pulse) per the existing accessibility contract.

### E.10 Tap during `_replay_in_flight`
Per Sprint 14 + Guild Hall GDD #19 §C.5, Settings gear is disabled during offline replay. The Recruit screen does NOT have a gear icon (C.8), but the player CAN navigate to Recruit during replay. RecruitButton + RefreshPoolButton remain enabled (Recruitment is not gated by replay state — the player can spend gold during replay if they have it). However, Economy.gold_changed during replay is suppressed per ADR-0014 §C.6, so the gold counter does NOT re-render mid-replay; it picks up the post-flush value via the aggregate gold_changed emit.

---

## F. Dependencies

### Hard dependencies (Recruit Screen requires these to function)

| System | Why | Surface used |
|---|---|---|
| `Recruitment` (#14) | Pool source + transaction owner | `get_recruit_pool()`, `get_recruit_cost(pool_index)`, `try_recruit(pool_index)`, `refresh_pool_paid()`, `refresh_cost(refreshes_today)`, `pool_refreshed` signal |
| `Economy` (#5) | Gold balance + spend | `get_gold_balance()`, `gold_changed` signal |
| `HeroRoster` (#9) | Owned-count display | `get_copies_owned(class_id)`, `hero_recruited` signal |
| `DataRegistry` (#2) | Class resource resolution | `resolve("classes", class_id)` |
| `HeroClassDatabase` (#6) | Class portrait + display name | per-class data via DataRegistry |
| `SceneManager` (#4) | Navigation back to Guild Hall | `request_screen("guild_hall", TransitionType.CROSS_FADE)` |
| `UIFramework` (#18) | Theme + touch feedback | `apply_parchment_panel`, `wire_touch_feedback`, `format_short_number`, `format_localized` |
| `TranslationServer` (Godot built-in) | Localization | `translate(StringName)` for static-context labels |

### Reverse dependencies (systems that depend on Recruit Screen)

- **Guild Hall Screen** (#19) — RecruitNavButton routes here per §C.7
- **Onboarding** (#29) — first-recruit prompt may surface Recruit screen as the player's "first sub-destination" per onboarding flow

### Soft dependencies (Recruit Screen enhances these but is not required for them)

- **AudioRouter** (#28) — UI tap chime fires via `UIFramework.wire_touch_feedback` hook on every Button. recruit-success chime fires via AudioRouter's `hero_recruited` subscriber per audio-system.md (AC-AS-12, deferred until non-silent assets ship per ADR-0016).

---

## G. Tuning Knobs

### Layout knobs (parchment_theme + screen.tscn)
- ClassPortrait size: default 96×96 logical px. Tunable in screen.tscn; tap target stays ≥44×44.
- Pool-entry row height: ≥120 logical px (portrait + padding).
- Vertical spacing between entries: 8–16 logical px.

### Animation knobs (UIFramework constants per ADR-0008)
- TOUCH_PULSE_SCALE: 1.05 (per UIFramework). reduce_motion → 1.0 (no pulse).
- TOUCH_PULSE_EXPAND_SEC: 0.08 (UIFramework).
- TOUCH_PULSE_RETURN_SEC: 0.016 (UIFramework).
- Pool-refresh cross-fade duration: 300ms (matches ADR-0008 CROSS_FADE timing). reduce_motion → instant (0ms).
- Gold-counter pulse on recruit-spend: ≤300ms amber pulse. reduce_motion → no pulse.

### Toast knobs (cross-reference to formation_assignment toast)
- Toast linger: 3.0s (formation_assignment precedent).
- Toast fade: 0.6s (matches level-up toast per S10-M4).

### Recruit-cost / refresh-cost (cross-reference, NOT owned by this screen)
- BASE_RECRUIT, RECRUIT_RATIO: per Recruitment GDD §G + EconomyConfig.
- BASE_REFRESH_COST, REFRESH_COST_MULT: per Recruitment GDD §G + EconomyConfig.

### Per-row owned-count cap on display
- MVP: display "(owned: N)" for any N ≥ 0.
- V1.0+: consider capping display at "(owned: 99+)" to avoid runaway label width once players reach absurd counts. Tuning knob: `OWNED_COUNT_DISPLAY_CAP: int = 99`.

---

## H. Acceptance Criteria

**AC-21-01 — Pool render shows POOL_SIZE entries**
On enter, the screen renders exactly `Recruitment.POOL_SIZE` (= 3) PoolEntry rows, each with portrait + class name + cost + owned-count + Recruit button.

**AC-21-02 — Cost label matches Recruitment.get_recruit_cost**
For each pool_index in [0, POOL_SIZE), the cost label displays the formatted value of `Recruitment.get_recruit_cost(pool_index)`.

**AC-21-03 — Owned-count label matches HeroRoster.get_copies_owned**
For each pool entry, the OwnedLabel reads `HeroRoster.get_copies_owned(class_id)` of the resolved class.

**AC-21-04 — Recruit button affordability gating**
For each pool entry, the RecruitButton.disabled = (gold_balance < cost). Affordable rows render with SelectedSlotButton theme variation (warm); unaffordable rows render dimmed but still interactive (showing the cost).

**AC-21-05 — Recruit press atomic transaction**
Tapping the RecruitButton at pool_index=N calls `Recruitment.try_recruit(N) -> RecruitOutcome`. On `RecruitOutcome.SUCCESS`, `HeroRoster.hero_recruited(instance)` (1-arg) + `Recruitment.hero_recruited(instance_id, class_id, cost_paid)` (3-arg) + `gold_changed` signals fire from Recruitment's atomic dispatch (per Recruitment AC-RC-09); screen re-renders gold counter + the affected entry's cost (which jumps per ADR-0013 cost curve) + owned-count.

**AC-21-06 — Insufficient-gold try_recruit shows toast**
If the player's gold drops between render and tap (race condition), `try_recruit` returns `RecruitOutcome.INSUFFICIENT_GOLD`; the screen displays the localized toast "Not enough gold." for 3.0s.

**AC-21-07 — Roster-full try_recruit shows toast**
If the player's roster is at max_roster_size at tap time, `try_recruit` returns `RecruitOutcome.ROSTER_FULL`; the screen displays "Roster full." toast for 3.0s.

**AC-21-08 — Refresh Pool button shows current cost**
The RefreshPoolButton's text includes the localized cost from `Recruitment.refresh_cost(refreshes_today)`. The cost updates after each successful refresh (the curve advances per ADR-0015).

**AC-21-09 — Refresh Pool press rerolls the pool**
Tapping RefreshPoolButton with sufficient gold calls `Recruitment.refresh_pool_paid()`; on success, the pool re-renders with new entries via `pool_refreshed` signal subscriber.

**AC-21-10 — Refresh Pool insufficient-gold toast**
If gold < refresh_cost, the RefreshPoolButton is dimmed; tapping it (in case of race) shows toast "Not enough gold." for 3.0s.

**AC-21-11 — Pool refresh signal triggers full re-render**
When `Recruitment.pool_refreshed(new_pool)` fires (from any source — paid refresh, free first-clear refresh, save-load hydration), the screen re-renders all 3 pool entries.

**AC-21-12 — gold_changed updates counter + affordability**
When `Economy.gold_changed(new_balance, delta, reason)` fires, the GoldCounter updates AND every RecruitButton's `disabled` state re-evaluates. If reason="recruit", the gold counter pulses amber (300ms; reduce_motion suppresses).

**AC-21-13 — hero_recruited refreshes entry cost + owned-count**
When `HeroRoster.hero_recruited(instance)` fires, the entry whose class_id matches the recruited hero's class re-renders its cost (per ADR-0013 next-copy formula) + owned-count.

**AC-21-14 — Back button navigates to Guild Hall**
Tapping BackButton routes to `guild_hall` screen via `SceneManager.request_screen("guild_hall", CROSS_FADE)`.

**AC-21-15 — reduce_motion suppresses pool-fade + gold-pulse**
When `Settings.reduce_motion == true` (per Settings GDD #30 §C), pool-refresh cross-fade is instant (0ms) and gold-counter pulse is suppressed (no animation, value snap-updates).

**AC-21-16 — Empty pool placeholder render**
When `get_recruit_pool()` returns an empty Array, the screen renders a single placeholder row "No heroes available. Tap Refresh Pool to reroll." with the RefreshPoolButton remaining active. push_warning on empty-pool render.

**AC-21-17 — Touch-feedback on all buttons**
RecruitButton[i], RefreshPoolButton, and BackButton all have `UIFramework.wire_touch_feedback` applied. Idempotent (re-entering screen does not double-wire). reduce_motion → 1.0× scale (no pulse).

**AC-21-18 — Locale-aware labels**
ClassNameLabel reads `tr(class_data.display_name_key)` (or equivalent locale-keyed accessor); CostLabel + OwnedLabel use locale-formatted numbers per UIFramework.format_short_number. Toast strings are locale-keyed.

---

## I. Open Questions & ADR Candidates

**OQ-21-1 — Recruit-success animation**
MVP toast is simple text. Should successful recruit add a brief animation (e.g., the new hero's portrait flying from the pool entry into the off-screen Guild Hall direction) for sensory pleasure? Cozy-register precedent (Stardew, Slay the Spire's deck-up moments) suggests YES; MVP scope says NO (defer to V1.0 polish). Document for Sprint 15+ candidate.

**OQ-21-2 — Cost preview tooltip**
Should hovering / long-tapping a pool entry show a tooltip with "Next copy will cost: <formatted>" so the player can plan multi-recruits? MVP says NO — the cost label updates after each recruit anyway (AC-21-13). V1.0+ may add tooltip if playtest reveals planning-friction.

**OQ-21-3 — Class portrait sourcing**
Each HeroClass needs a portrait Texture2D. MVP is parchment-themed pixel art; sourcing follows Art Bible §4 + the ADR-0016 audio precedent (silent-MVP if assets unavailable; placeholder texture meanwhile). Soft-dep — screen ships with placeholder rectangles colored per tier if portraits absent.

**OQ-21-4 — Multi-recruit batch UI**
Player may want to recruit 5 copies of a class at once (after grinding gold for them). MVP shows a single Recruit button per row; multi-recruit batching is V1.0+ scope. Possible UX: long-press to open count picker.

**OQ-21-5 — Pool-size scaling**
MVP POOL_SIZE = 3 fits cleanly in 1280×800 + portrait layout. V1.0+ may want POOL_SIZE = 5 (more variety). Layout already supports VBoxContainer scroll if expanded; tuning knob in `recruitment-system.md` §G.

**OQ-21-6 — Refresh button position**
MVP places it in FooterBar. Alternative: above the pool (like a "shuffle" button on a card draw). MVP keeps Footer for pattern consistency with formation_assignment + dungeon_run_view footer Dispatch buttons.

**OQ-21-7 — First-clear free-refresh feedback**
When the auto-refresh fires (free, on first-clear), should the screen show a brief "+ free refresh" indicator? MVP says NO — `pool_refreshed` triggers a silent re-render. V1.0+ may add a 1.5s subtle "Pool refreshed!" tooltip if playtest reveals players miss the free-refresh signal.

**OQ-21-8 — Roster-full UX in MVP**
MVP has no roster-dismiss UI. AC-21-07 toast just says "Roster full." A V1.0+ roster screen will add hero-retire UI. Should MVP toast hint at this future feature ("Roster full. Retire a hero to make room.") or stay generic to avoid implying a feature that doesn't exist yet? **Resolution path**: stay generic for MVP per cozy-register-no-frustration; revisit when retire-UI ships.

---

## J. Implementation Sequencing (Sprint 14 S14-S4 candidate)

This GDD is design-first; implementation is Sprint 14 S14-S4 scope (~0.75d per the sprint plan). Pre-sequenced as 5 stories:

1. **Story 1 (~0.15d)** — `recruit_screen.tscn` authoring per §C.1 layout. Anchor preset 15 + parchment-themed PanelContainers + 3 PoolEntry HBoxContainers (placeholder content) + HeaderBar/FooterBar. Editor work; no .gd changes required.
2. **Story 2 (~0.2d)** — `recruit_screen.gd` lifecycle hooks per §C.2. on_enter / on_exit signal subscriptions; BackButton wiring; touch_feedback on all buttons. No render logic yet.
3. **Story 3 (~0.2d)** — Pool render per §C.4. `_refresh_pool_panel` reads Recruitment + Economy + HeroRoster + DataRegistry; populates PoolEntry rows. Tests for ACs 21-01, 21-02, 21-03, 21-04.
4. **Story 4 (~0.15d)** — Recruit + Refresh interaction per §C.5 + §C.6. `_on_recruit_pressed`, `_on_refresh_pressed`, toast helpers. Tests for ACs 21-05, 21-06, 21-07, 21-09, 21-10.
5. **Story 5 (~0.05d)** — Polish + edge cases per §C.7 + §C.9 + §E. reduce_motion respected; empty-pool placeholder; gold-counter pulse on recruit. Tests for ACs 21-15, 21-16, 21-17.

Total Sprint 14 scope: ~0.75d. Matches sprint-14.md S14-S4 estimate.

---

## Notes

- Authored 2026-05-07 by post-Sprint-14-S14-N2 close-out autonomous-execution session, continuing the Sprint-14-prep design-coverage push (5 prior first-pass GDDs from 2026-05-06 + 1 ADR sign-off pending + this 6th first-pass GDD). systems-index.md row 21 status flips from "Not Started" to "DRAFT 2026-05-07".
- All ACs are testable via patterns documented in `tests/PATTERNS.md`.
- This GDD has NOT yet had a `/design-review` pass. Run before declaring APPROVED. Expect review to surface ~5–10 BLOCKING items per the audio-system.md / recruitment-system.md / Settings / Hero Leveling first-pass-GDD precedent.
- Closes the design-coverage gap for Recruit Screen that has existed since the Sprint 1 GDD-authoring pass — systems-index.md row 21 has been "Not Started" since project inception.
- This GDD pairs with Recruitment GDD #14 (`recruitment-system.md`) — the autoload-side mechanics + transaction logic. The Recruit Screen GDD is the player-facing surface that consumes those signals and accessors.
- Implementation is pre-scheduled for Sprint 14 S14-S4. UX-pass dependency noted on the sprint plan can be relaxed now that the GDD documents the layout intent — UX pass remains valuable for visual polish but no longer gates story-authoring.
