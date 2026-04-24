# HUD Design: Lantern Guild

> **Status**: Draft (v0.1 — initial scope; expands as screens implement)
> **Author**: ux-designer
> **Last Updated**: 2026-04-24
> **Game**: Lantern Guild (cozy fantasy idle-clicker, Godot 4.6, GDScript)
> **Platform Targets**: PC (Steam) + Steam Deck (primary); iOS / Android (post-launch)
> **Related GDDs**:
> - `design/gdd/hero-roster.md`
> - `design/gdd/dungeon-run-orchestrator.md`
> - `design/gdd/floor-unlock-system.md`
> - `design/gdd/economy.md`
> - `design/gdd/matchup-resolver.md`
> - `design/gdd/combat-resolution.md`
> - `design/gdd/time-system.md`
> **Related ADRs**:
> - ADR-0007 (scene transitions, `reduce_motion`, modal push/pop)
> - ADR-0008 (UI framework, parchment theme, dual-focus mouse/touch, 44-px tap target, colorblind-safe matchup icons, two-font-max)
> - ADR-0014 (offline replay batching, reward-reveal modal)
> **Accessibility Tier**: Standard (see `design/accessibility-requirements.md`)
> **Style Reference**: `design/art/art-bible.md` — §4 Color System (Parchment Cream, Lantern Gold, Dusk Purple, Ember Glow), §7 UI/HUD Visual Direction, §8 Asset Standards
> **Interaction Patterns**: `design/ux/interaction-patterns.md`

> **v0.1 scope note**: This HUD design is broad-stroke only. Per-element
> detailed interaction design (exact animation timings beyond pattern defaults,
> precise pixel metrics, full state-transition tables) is deferred until
> Production-phase story authoring. This document establishes information
> architecture, screen states, and the ADR/GDD binding of each element —
> enough to begin sprint planning and story decomposition, not enough to
> implement without follow-up.

---

## 1. Overview

The Lantern Guild HUD is the player's persistent view during active gameplay.
Because this is an idle-clicker — and because most of the game state is
passive (dungeon runs auto-resolve, gold accumulates over time, heroes level
from kills) — the HUD is less about **moment-to-moment decision support** and
more about **cozy, readable state surfacing**. The player's primary actions
are infrequent and low-stress: dispatch a formation, claim offline rewards,
recruit a new hero, edit a formation. The HUD must make these one-tap easy
without demanding constant attention.

This screen is where the player spends most of their time, and it anchors the
game's player fantasy: you are a guildmaster watching your parties work, not
a fighter pressing buttons.

---

## 2. Goals & Non-goals

**Goals**:

1. **At-a-glance state surfacing** — gold balance, active floor, formation status, and matchup advantage readable in under 2 seconds without eye tracking across the screen.
2. **One-tap primary action** — dispatch or recall a formation from the HUD without opening a sub-screen.
3. **Cozy motion** — state changes tween at reward-celebratory speed (400ms-ish), but `reduce_motion` clamps to instant per ADR-0007.
4. **Mouse + single-finger touch parity** — every interaction works with a mouse click or a 44×44-px tap target. No hover-only, no right-click, no drag-precision.
5. **Matchup clarity** — the class-vs-biome matchup indicator is on the HUD, always, using the shape+color triple (ADR-0008) so players can feel advantage or disadvantage before they dispatch.

**Non-goals**:

1. Combat-tier information density. The HUD does not show per-hero HP, damage-per-second, or abilities-used.
2. Full formation editing. The HUD is for dispatch/recall and status; formation composition is a sub-screen.
3. Inventory / ability bars. There is no player-controlled inventory in MVP.
4. Per-element pixel-precise layout. This is v0.1 — final layout comes during story authoring.

---

## 3. Information Architecture

### Always-Visible Information

| Information | Why Always Show | Zone |
|-------------|----------------|------|
| Gold balance | Currency decisions (recruit, upgrade) are always open to the player | Persistent header (top) |
| Current floor indicator | Orients player to current progression context | Persistent header (top) |
| Settings gear icon | Universal affordance for quick access to audio, reduced motion, remapping | Persistent header (top-right) |
| Active formation slots (3) | The subject of the game — who is fighting right now | Center |
| Dungeon run status (loop, ticks elapsed, kills this dispatch) | Feeds player's sense of momentum | Center |
| Matchup indicator (colorblind-safe triple) | Core strategic signal — advantage/neutral/disadvantage vs. current biome | Center, adjacent to formation |
| Dispatch / Recall button | The one primary action of the HUD | Bottom action zone |
| Formation Edit / Roster buttons | Secondary but frequent navigation | Bottom action zone |

### Contextual (appears when triggered)

- **Toast notifications**: gold drip, hero leveled, first-clear-awarded (see interaction-patterns.md Toast pattern).
- **Modal overlays**: offline-reward reveal (ADR-0014), mid-run reassign warning (ADR-0001), save-failed (ADR-0007). Documented here but specced in the interaction pattern library as Confirm-Dismiss Modal.

### On-Demand (via navigation, not on HUD)

- Full hero roster detail
- Formation editor detail
- Floor selection tree (the HUD shows the *current* floor only)
- Settings menu
- Help / tutorial archive

---

## 4. Visual Layout (v0.1 — ASCII sketch, not final)

```
┌────────────────────────────────────────────────────────────┐
│  [gold 12,480 Gold ]     Floor 2: Mossglen Hollow     [⚙]  │  ← persistent header
├────────────────────────────────────────────────────────────┤
│                                                            │
│                                                            │
│        ┌──────┐   ┌──────┐   ┌──────┐                      │
│        │ HERO │   │ HERO │   │ HERO │                      │
│        │ slot │   │ slot │   │ slot │                      │
│        │  1   │   │  2   │   │  3   │       [▲ advantage]  │  ← matchup indicator
│        │      │   │      │   │      │                      │
│        │ Lv 4 │   │ Lv 3 │   │ Lv 5 │                      │
│        └──────┘   └──────┘   └──────┘                      │
│                                                            │
│              Loop 12  ·  Ticks 340  ·  Kills 28            │  ← run status readout
│                                                            │
│                                                            │
├────────────────────────────────────────────────────────────┤
│  [ Roster ]      [ DISPATCH / RECALL ]      [ Formation ]  │  ← bottom action zone
└────────────────────────────────────────────────────────────┘
   [toast container — bottom-right corner, stacks vertically]
```

**Zones**:

- **Top header** (~8% vertical): Gold counter (left), floor indicator (center), settings gear (right). Always visible.
- **Center area** (~70% vertical): Formation slots (top of center), matchup indicator (right edge of formation row), run status readout (below formation).
- **Bottom action zone** (~15% vertical): Secondary button (Roster), Primary button (Dispatch / Recall), Secondary button (Formation). Three equal-width slots for touch reachability.
- **Notification layer** (overlays): toast container anchored bottom-right; modal overlays dim the entire screen (ADR-0007 `push_overlay`).

---

## 5. Screen States

| State | What's Visible | What's Different | Triggered By |
|-------|---------------|------------------|--------------|
| **Idle — no formation dispatched** | All header + center layout; Dispatch button active; run status reads "—" | Formation slots may be empty or filled; Dispatch is disabled if fewer than N (GDD-defined) slots filled | Default state after recall or startup with no active dispatch |
| **Idle — formation dispatched** | All elements; Dispatch button becomes Recall | Run status animates (loop++, ticks++, kills++); gold counter tweens on gold drip events | Player taps Dispatch; dungeon run orchestrator begins ticking |
| **Offline — just returned** | All elements; offline-reward reveal modal appears over HUD | Modal blocks HUD until dismissed; toasts are suppressed during modal (modal is the reveal channel per ADR-0014) | Game resumes after offline window; `_is_offline_replay` flag true |
| **Mid-run reassign in progress** | All elements; reassign warning modal appears | Warning modal explains that changes apply next dispatch, not this run (ADR-0001 `MID_RUN_REASSIGN_WARNING_ENABLED`) | Player opens Formation editor while dispatched |
| **Dispatch refused — no formation** | All elements; inline message near Dispatch button ("Add ≥N heroes to dispatch") | Dispatch button visually disabled (40% opacity, no tap response) | Player taps Dispatch with insufficient formation |
| **Save failed — abort** | Modal overlay replaces HUD input surface | Save-failed Confirm-Dismiss Modal (Primary "Try Again" / Secondary "Stay Here" per ADR-0007) | Save system reports failure |
| **Settings open** | Header remains; center/bottom are replaced by settings sub-screen | N/A — this is a scene push, not an overlay | Player taps settings gear |

---

## 6. Interactions (Element ↔ ADR / GDD Binding)

| Element | Interaction | Bound To |
|---------|------------|----------|
| Gold counter | Listens to `gold_changed` signal; tweens on update unless `_is_offline_replay` or `reduce_motion` | Economy GDD, ADR-0013 (economy state), ADR-0007 (reduce_motion), ADR-0014 (offline replay) |
| Floor indicator | Reads current floor from Floor Unlock System autoload; updates on floor-change event | Floor Unlock GDD, ADR-0003 (autoload rank) |
| Settings gear | Tap → push settings scene via `SceneManager.push_scene` | ADR-0007 (scene transitions) |
| Hero slot (×3) | Tap → push formation editor sub-screen for that slot | Hero Roster GDD, ADR-0012 (hero identity) |
| Matchup indicator | Display-only; reads from Matchup Resolver | Matchup Resolver GDD, ADR-0008 (colorblind-safe icons), ADR-0009 (matchup DI) |
| Run status readout | Listens to Dungeon Run Orchestrator signals (`loop_incremented`, `tick_elapsed`, `kill_registered`) | Dungeon Run Orchestrator GDD, ADR-0010 (combat resolver parity) |
| Dispatch / Recall button | Primary button pattern; context-sensitive; fires dispatch or recall action | Dungeon Run Orchestrator GDD; uses Primary Button pattern |
| Roster button | Secondary button pattern; push roster scene | Hero Roster GDD; uses Secondary Button pattern |
| Formation button | Secondary button pattern; push formation editor scene; triggers mid-run reassign warning modal if dispatched | ADR-0001; uses Secondary Button + Confirm-Dismiss Modal patterns |
| Toasts (gold, level, first-clear) | Toast pattern with merge rule; suppressed during offline replay | Economy GDD, Hero Roster GDD, Floor Unlock GDD; uses Toast pattern |
| Offline-reward modal | Confirm-Dismiss Modal with reward-reveal variant (ADR-0014 ≥100ms reveal, cozy animation) | Time System GDD, ADR-0014 |
| Save-failed modal | Confirm-Dismiss Modal per ADR-0007 | Save/Load GDD, ADR-0007 |

---

## 7. Accessibility Notes

All HUD elements inherit the Standard-tier commitments documented in
`design/accessibility-requirements.md`. HUD-specific callouts:

- **Tap targets**: every interactive element on the HUD ≥ 44 × 44 logical px. Verified at debug time by `UIFramework.assert_tap_target_min` (ADR-0008).
- **Dual-focus parity**: every interactive element reachable by mouse click and single-finger tap. No hover-only affordances. No right-click actions.
- **Colorblind-safe matchup**: the matchup indicator uses shape + color triple (Lantern Gold triangle-up / Parchment Cream circle / Dusk Purple triangle-down) locked by ADR-0008. Paired with a text label at all times.
- **Reduced motion**: when `reduce_motion` flag is set (ADR-0007), the gold-counter tween, run-status counter animations, and modal open/close animations are replaced with instant state changes. The offline-reward modal's cozy reveal ceremony is replaced with a static reward-number reveal.
- **Contrast**: all HUD text meets WCAG AA 4.5:1 against the parchment theme background. Semitransparent panels (if any) are an open question — target ratio TBD (see accessibility-requirements.md).
- **Two-font-max**: gold counter uses Information font for the number and Identity font for the "Gold" label; floor indicator uses Information font; button labels use Identity font. No third font introduced.
- **Screen reader**: AccessKit exposes the counter as a live-region for gold-balance updates, the floor indicator as a static label, the buttons as roles. Open question: does AccessKit fire update events for dynamically-shown modal overlays (the offline-reward modal is the primary concern).

---

## 8. Patterns Used

Every interactive element on this HUD references a pattern in
`design/ux/interaction-patterns.md`:

- **Primary Button** — Dispatch / Recall button.
- **Secondary Button** — Roster button, Formation button, settings gear icon button.
- **Confirm-Dismiss Modal** — offline-reward reveal, mid-run reassign warning, save-failed retry.
- **Toast Notification** — gold drip, hero leveled, first-clear awarded.
- **Matchup Indicator** — the colorblind-safe triple in the center area.
- **Currency Counter** — the gold balance in the header.

If a future HUD iteration introduces an interaction not already in the pattern
library, add it to the pattern library first.

---

## 9. Platform Adaptation (v0.1 — deferred detail)

| Platform | Resolution | Notes |
|----------|-----------|-------|
| PC — windowed / fullscreen | 1280×720 min, scaling up | Reference resolution is 1920×1080. HUD zones expressed in %, not absolute px. |
| Steam Deck | 1280×800 fixed | Tap target exception: 33 actual px acceptable (ADR-0008). All HUD elements already exceed this since the 44-logical-px floor maps to ≥33 actual-px on Deck. |
| Mobile (post-launch) | 360×640 min, 414×896 common | Portrait-capable: HUD layout designed to reflow to vertical; formation slots stack if needed. Post-launch work; v0.1 does not resolve mobile-specific zones. |

---

## 10. Acceptance Criteria (v0.1 — scope is initial HUD)

**v0.1 acceptance** (this document):

- [x] Information architecture categorizes every HUD surface element into Always / Contextual / On-Demand
- [x] Every interactive element binds to an ADR or GDD
- [x] Every interactive element references a pattern from `design/ux/interaction-patterns.md`
- [x] Every screen state transition identifies its trigger
- [x] Accessibility Standard-tier commitments are linked and HUD-specific items called out
- [x] `reduce_motion` behavior is specified for every animated element
- [x] Tap-target assertion is called out for every interactive element

**Deferred to v1.0** (Production story authoring):

- [ ] Pixel-precise layout at reference resolution 1920×1080
- [ ] Motion-timing tuning per element (final values within the patterns' allowed ranges)
- [ ] Platform-specific zone reflows for Steam Deck and mobile portrait
- [ ] Full text-scaling test matrix at 100% / 125% (accessibility-requirements.md scope)
- [ ] Per-element screen-reader announcement copy

---

## 11. Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| Where exactly does the matchup indicator sit relative to the formation row on narrow (portrait-mobile) layouts? | ux-designer | Before mobile port milestone | Unresolved |
| Does the run-status readout (loop / ticks / kills) need pause animation during `reduce_motion`, or does it snap to end-of-tick value? | ux-designer + game-designer | Before HUD v1.0 | Unresolved |
| Should the gold counter's tween speed scale with the gold delta size? (Large offline returns produce a very long tween otherwise.) | ux-designer | Before HUD v1.0 | Unresolved |
| Does the floor indicator double as a tap target to open the floor-selection tree, or does that require a separate button? | ux-designer + game-designer | Before v1.0 | Unresolved — lean toward tappable for discoverability, but keep the 44-px rule |
| Godot 4.6 AccessKit — does it fire update events for dynamically-shown modal overlays? (Shared open question with pattern library and accessibility-requirements.) | ux-designer | Before first HUD implementation story | Unresolved |

---

*End of document — v0.1.*
