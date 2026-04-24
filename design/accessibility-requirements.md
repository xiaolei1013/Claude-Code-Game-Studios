# Accessibility Requirements: Lantern Guild

> **Status**: Committed
> **Author**: ux-designer / producer
> **Last Updated**: 2026-04-24
> **Accessibility Tier Target**: Standard
> **Platform(s)**: PC (Steam) + Steam Deck (primary launch); iOS / Android (post-launch mobile port)
> **External Standards Targeted**:
> - WCAG 2.1 Level AA — body text contrast, focus visibility, non-color indicators
> - Steam Input — controller / mouse remapping at the platform layer
> - Xbox Accessibility Guidelines (XAG) — N/A (no console release planned)
> - PlayStation Accessibility Guidelines — N/A (no console release planned)
> - Apple / Google Accessibility Guidelines — deferred to mobile port milestone
> **Accessibility Consultant**: None engaged (solo-developer capacity)
> **Linked Documents**:
> - `design/gdd/systems-index.md`
> - `design/ux/interaction-patterns.md`
> - `design/art/art-bible.md`
> - `docs/architecture/ADR-0007-scene-transition-and-persist-coupling.md`
> - `docs/architecture/ADR-0008-ui-framework-dual-focus-parity-and-theme.md`

> **Why this document exists**: Per-screen accessibility annotations belong in
> UX specs. This document captures Lantern Guild's project-wide accessibility
> commitments, the feature matrix across all systems, the test plan, and the
> audit history. It is created during Technical Setup and updated as features
> are added.
>
> **When to update**: After each `/gate-check` pass, after any audit, and
> whenever a new system is added to the systems index.

---

## Accessibility Tier Definition

### Tier Definitions (shared project vocabulary)

| Tier | Core Commitment | Typical Effort |
|------|----------------|----------------|
| **Basic** | Legible text, no color-only signals, independent volume sliders, no photosensitivity risk. | Low — design constraints |
| **Standard** | Basic + full input remapping, adjustable text size, ≥1 colorblind mode, no un-extendable timed inputs, subtitle support for any voiced content. | Medium |
| **Comprehensive** | Standard + screen reader for menus, mono audio, HUD repositioning, reduced motion mode, visual indicators for critical audio. | High |
| **Exemplary** | Comprehensive + full subtitle customization, high contrast mode, cognitive load assists, haptic alternatives, external accessibility audit. | Very High |

### This Project's Commitment

**Target Tier**: **Standard**

**Rationale**: Lantern Guild is a cozy fantasy idle-clicker with mouse and
single-finger touch parity as the only input modes — which structurally
eliminates the most severe motor barriers common in action games and makes the
Basic → Standard jump almost free. Several Standard-tier features are already
committed in architecture: ADR-0008 locks a colorblind-safe matchup triple
(shape + color), a two-font-max rule, a debug-time tap-target assertion at
44 logical pixels, and an explicit dual-focus (mouse + touch) model. ADR-0007
provides a `reduce_motion` flag that clamps scene transitions to 50ms and
replaces ceremony animations with instant cuts plus a reward-number reveal —
which is the core of a reduced-motion mode, already scoped as Comprehensive
in the generic template but already-happening here. The Steam + mobile target
audience overlaps heavily with players who benefit from Standard (WCAG AA,
remapping, colorblind support). Solo-dev capacity makes Comprehensive and
Exemplary out of scope: there is no budget for platform-specific screen reader
engineering, external audits, or tactile alternatives. No console release
removes the one certification path (XAG) that would have forced a higher tier.

**Features explicitly in scope (beyond generic Standard baseline — these are
already committed via ADRs)**:

- **Colorblind-safe matchup indicators** — Lantern Gold upward triangle for
  advantage, Parchment Cream circle for neutral, Dusk Purple downward triangle
  for disadvantage. Elevated because the core loop relies on class-vs-biome
  matchup feedback being read at a glance. Locked by ADR-0008.
- **Motion reduction mode (`reduce_motion` flag)** — scene transitions clamp to
  50ms, ceremony animations are replaced with instant cuts and a reward-number
  reveal. Locked by ADR-0007.
- **Dual-focus parity** — every interactive element is reachable by mouse hover
  *and* single-finger tap; no hover-only, no right-click-only, no drag-precision
  interactions. Locked by ADR-0008 and reinforced in technical-preferences.md.
- **Debug-time tap-target assertion** — `UIFramework.assert_tap_target_min`
  checks 44 logical px at development time. Locked by ADR-0008.

**Features explicitly out of scope**:

- **Screen reader support for the in-game world** — Godot 4.6 AccessKit covers
  menus only. Lantern Guild has minimal "world" (it is menu-centric), so this
  is a smaller gap than in an action RPG, but the commitment is still
  Comprehensive-tier and out of scope.
- **Full subtitle customization (font/color/background/position)** — there is
  no voiced dialogue in MVP. Subtitles are N/A across the board.
- **One-hand / gamepad / alternative-controller mode** — Lantern Guild is
  mouse + touch only by design. Gamepad support is explicitly declined in
  technical-preferences.md.
- **Tactile/haptic alternatives** — no console release; PC controllers are
  not a target input; no haptic API integration.
- **External accessibility audit** — Exemplary-tier; solo-developer scope.

---

## Visual Accessibility

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Minimum text size — menu UI | Standard | All menu screens | Not Started | 20px minimum at 1080p for body copy; identity font larger for headings. ADR-0008 two-font-max rule applies. |
| Minimum text size — HUD | Standard | Active gameplay HUD | Not Started | 20px minimum for gold counter, floor indicator, formation stats. See `design/ux/hud.md`. |
| Text contrast — UI text on parchment theme | Standard | All UI text | Not Started | 4.5:1 minimum (WCAG AA) against Parchment Cream background. Semitransparent panels are an open question — target ratio TBD. |
| Colorblind mode — Protanopia | Standard | All color-coded gameplay (matchup triple, currency icons) | Not Started | Matchup icons use shape + color (ADR-0008) — already safe. Verify with Coblis on HUD screenshots. |
| Colorblind mode — Deuteranopia | Standard | Same as above | Not Started | Same implementation; verify with Coblis. |
| Colorblind mode — Tritanopia | Standard | Same as above | Not Started | Dusk Purple ↔ Lantern Gold axis is the risk; shape triple still disambiguates. |
| Color-as-only-indicator audit | Basic | All UI and gameplay | Not Started | See audit table below. |
| UI scaling | Standard | All UI elements | Not Started | 100%–125% range for MVP (not full 75–150% — reduced scope to ship). |
| Motion reduction mode | Standard (elevated via ADR-0007) | Scene transitions, ceremony animations, currency counter tween | Partial | `reduce_motion` flag clamps transitions to 50ms; replaces ceremony with instant cut + reward-number reveal. See ADR-0007. |
| Screen flash / strobe warning | Basic | All VFX | Not Started | Idle-clicker VFX is low-intensity; pre-launch warning screen still required. |
| Subtitles — all forms | — | N/A | N/A | **No voiced dialogue in MVP.** Subtitles are not applicable. |

### Color-as-Only-Indicator Audit

| Location | Color Signal | What It Communicates | Non-Color Backup | Status |
|----------|-------------|---------------------|-----------------|--------|
| Matchup indicator | Gold / Cream / Purple | Advantage / Neutral / Disadvantage | Triangle-up / circle / triangle-down (shape encodes meaning per ADR-0008) | Addressed (ADR-0008) |
| Currency counter | Lantern Gold | Gold balance | Coin icon + "Gold" label (two-font rule) | Addressed |
| Hero class-tier icons | Border color by rarity | Common / Uncommon / Rare / Epic | Tier pip count (1–4 pips) on icon corner | Not Started |
| Floor indicator | Dusk Purple background tint | Current biome is dangerous-tier | Floor number + biome name always visible | Addressed (text primary) |

---

## Motor Accessibility

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Full input remapping | Standard | Mouse button bindings | Not Started | Steam Input provides platform-level remapping. In-game remap may be deferred if Steam Input covers all mouse actions. |
| Input method switching | Standard | PC | Not Started | Player must be able to switch between mouse and touchscreen (Steam Deck) at any moment without restart. UI hints should be input-agnostic (no "click" vs. "tap" copy). |
| Hold-to-press alternatives | Standard | All hold inputs | Compliant by design | Lantern Guild has no sustained-hold inputs. Idle-clicker is tap-only. |
| Rapid input alternatives | Standard | Any button mashing | Compliant by design | Auto-battler core loop — no mashing. Gold-drip feedback is a passive click at the player's pace. |
| Input timing adjustments | Standard | Timed inputs | Compliant by design | No timed inputs anywhere in the MVP loop. Offline replay is batch-resolved; dungeon runs are auto-resolved ticks. |
| Tap target minimum size | Standard | All interactive elements | Partial | ADR-0008: 44 logical px floor; Steam Deck 33 actual-px accepted. `UIFramework.assert_tap_target_min` enforces at debug time. |
| HUD element repositioning | Comprehensive | All HUD elements | Out of scope | Deferred — solo-dev capacity. Documented in Known Intentional Limitations. |

Out-of-scope rows (with rationale — not included as table entries because
they are entirely N/A for this game type):

- **Aim assist** — N/A. No ranged combat; no aiming; auto-battler resolves
  combat without player aim input.
- **Platforming / traversal assists** — N/A. No platforming.
- **Auto-sprint / movement assists** — N/A. Player does not move a character.
- **One-hand mode** — N/A. No multi-input simultaneous actions.

---

## Cognitive Accessibility

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Pause anywhere | Basic | All gameplay states | Compliant by design | Lantern Guild is an idle-clicker. Closing the game IS pausing — offline-replay mechanics mean the game state is always recoverable. Modal overlays pause active inputs per ADR-0007 `SceneManager.push_overlay`. |
| Tutorial persistence | Standard | First-run flow + system introductions | Not Started | Each GDD system that introduces new mechanics (Formation Editor, Dispatch, Offline Rewards) must expose the tutorial from a Help section at any time. |
| Quest / objective clarity | Standard | Floor unlock progression | Not Started | Current floor + remaining clears-to-unlock always visible in HUD header. |
| Reading time for UI | Standard | All auto-dismissing toasts | Not Started | Toasts display for ≥5 seconds (Standard floor). Reward modals (offline return, first-clear) are player-dismissed, never auto-dismiss. |
| Cognitive load documentation | Comprehensive | Per system in systems-index.md | Not Started | See Per-Feature Accessibility Matrix below. Lantern Guild's core loop is 3–4 simultaneous tracked items (gold balance, formation state, current floor, active run tick) — within safe cognitive load. |
| Navigation assists | Limited scope | World / floor navigation | Not Started | Idle-clicker has ≤6 screens total. No fast-travel system needed; no waypoints; all navigation is one or two taps from HUD. |
| Difficulty options | Standard | Dungeon run difficulty | Not Started | Investigate whether an easier formation-recommendation assist (auto-suggest optimal matchup) is appropriate for a cozy-tier audience. Open question. |

---

## Auditory Accessibility

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Independent volume controls | Basic | Music / SFX / UI buses | Not Started | Three independent sliders. **No Voice bus** — no voiced content. Persist to save profile. Range 0–100%, default 80%. |
| Visual representations for directional audio | Comprehensive | Off-screen events | Compliant by design | No off-screen threats in an idle-clicker. All state is visible on-screen via HUD. |
| Hearing aid compatibility / frequency audit | Standard | All audio cues | Not Started | Audit SFX for high-frequency-only critical cues. Gold-drip chime, first-clear fanfare, offline-return chime must have frequency headroom; verify at implementation. |
| Mono audio option | Comprehensive | Global audio | Out of scope | Out of scope for Standard tier. Documented in Known Intentional Limitations. |
| Subtitles / closed captions | — | N/A | N/A | **No voiced dialogue in MVP.** No narration. All text is written UI copy, already visual. |

### Gameplay-Critical SFX Audit

| Sound Effect | What It Communicates | Visual Backup | Caption Required | Status |
|-------------|---------------------|--------------|-----------------|--------|
| Gold drip chime | Gold awarded to balance | Gold counter ticks up + toast "Gold +N" | No — visual is primary | Not Started |
| First-clear fanfare | Floor first-cleared | Modal overlay with reward reveal (ADR-0014) | No — modal is primary | Not Started |
| Offline-return chime | Player returning after offline progression | Offline-reward reveal modal | No — modal is primary | Not Started |
| Dispatch confirm | Formation successfully dispatched | Dispatch button transitions to Recall state | No — button state change is primary | Not Started |

> All SFX are secondary / confirmatory. The visual channel carries the
> primary gameplay signal in every case — this is a deliberate design choice
> that benefits deaf and hard-of-hearing players by default.

---

## Platform Accessibility API Integration

| Platform | API / Standard | Features Planned | Status | Notes |
|----------|---------------|-----------------|--------|-------|
| Steam (PC) | Steam Input, Steam overlay accessibility | Controller / mouse remapping via Steam Input; subtitle support N/A | Not Started | Steam Input handles platform-level remapping. In-game mouse-button remap may be deferred if Steam Input covers it. |
| PC (Screen Reader) | JAWS / NVDA / Windows Narrator via Godot 4.6 AccessKit | Menu navigation announcements | Partial | Godot 4.6 AccessKit covers menus. Verify it fires update events for dynamically-shown modal overlays (see Open Questions). |
| Steam Deck | Steam Input + touchscreen | Tap target 33 actual-px minimum (ADR-0008 exception); input method switching | Not Started | Touchscreen is primary on Deck for UX consistency with mobile port. |
| iOS | UIAccessibility / VoiceOver | Deferred to mobile port milestone | Deferred | Out of scope for PC launch. |
| Android | AccessibilityService / TalkBack | Deferred to mobile port milestone | Deferred | Out of scope for PC launch. |
| Xbox / PlayStation | — | N/A | N/A | No console release planned. |

---

## Per-Feature Accessibility Matrix

One row per GDD'd system. Flags the accessibility surface each system touches.

| System (GDD) | Visual Concerns | Motor Concerns | Cognitive Concerns | Auditory Concerns | Addressed | Notes |
|--------------|----------------|---------------|-------------------|------------------|-----------|-------|
| Hero Roster | Rarity border color on hero cards | Tap targets on roster tiles (scrollable list) | Comparing hero stats across multiple tiles | None | Partial | Tier pip count backup for rarity; assert_tap_target_min enforced |
| Hero Class Database | Class-tier icon color | None | Identifying class by icon at glance | None | Not Started | Icons must encode class by shape, not color alone |
| Enemy Database | Enemy sprite color variants | None | None | Enemy defeat SFX (low priority) | Not Started | Review enemy sprite legibility under all three colorblind simulations |
| Biome Dungeon Database | Biome background tint (Mossglen green, etc.) | None | Reading biome name + level + difficulty | Ambient biome audio | Not Started | Text-primary — biome name always visible |
| Matchup Resolver | **Matchup triple (core accessibility surface)** | None | Understanding advantage/neutral/disadvantage at glance | None | Addressed | Shape + color triple locked by ADR-0008 |
| Combat Resolution | Damage numbers — color by type | None | Tracking loop count + kills + damage dealt | Hit SFX | Partial | Damage numbers need +/- prefix, not color-only; opt-out for photosensitive players |
| Dungeon Run Orchestrator | Run progress bar fill | Recall button tap target | Tracking tick progress + reward accumulation | Run-complete SFX | Not Started | HUD spec covers this in v0.1 |
| Economy | Gold counter tween | None | Tracking gold balance and upcoming costs | Gold-drip chime | Addressed | `reduce_motion` disables tween; counter snaps to new value |
| Floor Unlock System | Lock icon on locked floors | Tap target on floor selector | Understanding why a floor is locked | First-clear fanfare | Not Started | Lock state must be text ("Clear Floor 1 x5 to unlock"), not icon-only |
| Time System | Offline duration display | None | Understanding elapsed time + offline cap | Offline-return chime | Not Started | Offline replay batches are invisible to accessibility |
| Save / Load | Save-failed modal | Retry / Stay Here buttons (44px min) | Understanding save state | Save-failed SFX (optional) | Not Started | Modal uses confirm-dismiss pattern |
| Scene / Screen Manager | Scene transition animation | None | None (instant orientation) | None | Addressed | `reduce_motion` flag clamps to 50ms (ADR-0007) |
| Data Loading | Loading spinner | None | None | None | Not Started | Loading state uses standard pattern |

---

## Accessibility Test Plan

| Feature | Test Method | Test Cases | Pass Criteria | Responsible | Status |
|---------|------------|------------|--------------|-------------|--------|
| Text contrast ratios | Automated — contrast analyzer on HUD and menu screenshots | All text/background combinations in parchment theme; semitransparent panels at all opacity levels | Body text ≥ 4.5:1; large text ≥ 3:1 | ux-designer | Not Started |
| Colorblind modes | Manual — Coblis on HUD + matchup + roster screenshots | Gameplay, formation editor, matchup indicator at all three CVD types | No essential information lost in any mode | ux-designer | Not Started |
| Input remapping | Manual — Steam Input remap all mouse actions, complete first-dispatch loop | Default bindings → alternative bindings → no conflicts | All actions accessible after remap; persists across restart | qa-tester | Not Started |
| Tap-target assertion | Automated — `UIFramework.assert_tap_target_min` runs in debug CI | Every interactive Control across all scenes | No assertion failures in CI | tech-lead | Not Started |
| Reduced motion mode | Manual — enable `reduce_motion` flag, run full happy-path session | All scene transitions; ceremony animations; currency counter tween; offline-reward reveal | No animations >50ms; reward-number reveal replaces ceremony | ux-designer | Not Started |
| Cognitive load audit | Manual — map each system's simultaneous tracked items | Per per-feature matrix above | No system asks player to track >4 items simultaneously | game-designer | Not Started |
| Subtitle accuracy | N/A | N/A | N/A (no voiced content) | — | N/A |
| User testing | **None planned in MVP** | — | — | producer | Out of scope — solo-dev capacity |

> **Known testing limitation**: No player user testing is planned for MVP due
> to solo-developer capacity. All testing is automated or internal manual.
> Post-launch, evaluate paid user testing against Standard-tier features via
> AbleGamers Player Panel for a v1.1 improvement pass.

---

## Known Intentional Limitations

| Feature | Tier Required | Why Not Included | Risk / Impact | Mitigation |
|---------|--------------|-----------------|--------------|------------|
| Screen reader support for in-game world | Exemplary | Godot 4.6 AccessKit covers menus only; Lantern Guild has minimal "world," but any non-menu state is not screen-reader accessible | Affects blind and low-vision players who can navigate menus but cannot independently perceive dungeon run state | All critical state is duplicated in accessible menu views (roster, floor list); dungeon run state is derived, not a primary player-controlled action |
| Full subtitle customization | Comprehensive | No voiced dialogue in MVP — subtitles are entirely N/A | None — feature does not exist | Revisit if post-launch content adds voiced narration |
| One-hand / gamepad / alternative controller mode | Standard → Comprehensive | Lantern Guild is mouse + single-finger touch only by design. There are no multi-input combinations, no sustained holds, and no inputs that require two hands in the first place | Niche — the game is structurally one-hand-compatible; the limitation is only that we do not advertise it or test with adaptive hardware | Document that single-finger touch is the fully-supported input path |
| Tactile / haptic alternatives for audio cues | Exemplary | No console release; PC controllers not a target input; no haptic API integration in scope | Affects deaf players who would benefit from haptic feedback as a redundant channel — but since no SFX is sole-channel gameplay-critical, the impact is minimal | Visual channel already carries all primary signals (see Gameplay-Critical SFX Audit) |
| External third-party accessibility audit | Exemplary | Solo-developer budget excludes paid audits | Risk of unknown accessibility gaps discovered only at player-review time | Schedule an AbleGamers Player Panel review for v1.1 post-launch if budget allows |
| HUD element repositioning | Comprehensive | Deferred — additional UI architecture work; idle-clicker HUD is small enough that default layout is workable for most players | Players with head-tracking / eye-gaze hardware may have reduced peripheral visibility of corner elements | Evaluate if player requests surface post-launch |

---

## Audit History

| Date | Auditor | Type | Scope | Findings Summary | Status |
|------|---------|------|-------|-----------------|--------|
| 2026-04-24 | ux-designer + producer (internal) | Tier commitment | Project-wide | Standard tier committed; per-feature matrix initialized with 13 systems; test plan drafted | Committed |

---

## External Resources

| Resource | URL | Relevance |
|----------|-----|-----------|
| WCAG 2.1 | https://www.w3.org/TR/WCAG21/ | Contrast ratios, focus visibility |
| Game Accessibility Guidelines | https://gameaccessibilityguidelines.com | Genre-aware checklist |
| Colour Blindness Simulator (Coblis) | https://www.color-blindness.com/coblis-color-blindness-simulator/ | Free CVD simulation for HUD screenshots |
| Steam Input documentation | https://partner.steamgames.com/doc/features/steam_input | Platform-level remapping |
| Godot 4.6 migration guide | https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.6.html | AccessKit behavior notes |

---

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| Does Godot 4.6 AccessKit fire update events for dynamically-shown modal overlays (e.g., the dungeon-completion reward modal)? If not, modal content may be silent to screen readers. | ux-designer | Before first HUD implementation story | Unresolved — verify in `docs/engine-reference/godot/` |
| What WCAG AA contrast ratio do we target for parchment-theme semitransparent panels (commonly 4.5:1 on solid backgrounds — but panels sit over variable world art)? | ux-designer | Before HUD v1.0 | Unresolved — measure worst-case once art bible palettes are finalized |
| Should Lantern Guild expose a "recommended formation" assist toggle for cognitively-tired players, given the matchup system is the main decision point? | game-designer | Before Pre-Production story authoring | Unresolved — evaluate against cozy-tier audience expectations |

---

*End of document.*
