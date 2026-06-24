# Sprint 30 — 2026-06-24 to 2026-07-07

## Sprint Goal
Land the **victory-moment ceremony** — the one large un-built juice beat on the
core loop (GDD #25, explicitly deferred to S30 by the code itself at
`victory_moment.gd:7-9` / `:356`) — plus targeted reward-float and defeat-weight
polish, closing the visible-feel gaps a playtester notices on win/lose.

## Capacity
- Total days: 14
- Buffer (20%): 2.8 days reserved for unplanned work
- Available: ~11 days
- Continues the same-day-compressed **solo** cadence (S14 onward). S29 ran
  informally via PRs #244–#249 (greybox→parchment re-skin + 4 audio chimes +
  settings scale-in), so the formal tracker was stale at S28; this is the first
  formally-planned sprint since.

## Tasks

### Must Have (Critical Path)
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| S30-M1 | **Victory-moment ceremony animations** (GDD #25 §C). The screen + S29 parchment chrome are built; the code explicitly defers the ceremony juice to S30. | godot-specialist | 1.0 | none | (a) DimBackdrop fades `0→target` alpha on enter; (b) stat rows + loot tiles reveal **staggered**, not all-at-once; (c) ContinuationPromptLabel **pulses** (replaces the bare `.visible=true` at `victory_moment.gd:290`); (d) a **victory audio sting** plays via AudioRouter on enter (none today — grep-confirmed no audio refs in the file); (e) ALL beats reduce-motion-clamped (snap to final state, no tween) per the project motion axis; (f) tap-to-continue still interrupts at any point — TapCatcher stays last-child + the documented playtest-fix contract is intact; (g) integration test asserts cue selection + reduce-motion snap |

### Should Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| S30-S1 | **Reward-number floats** on the dungeon run (GDD #27) — rising "+N gold" / level-up text via `WireframeKit.float_layer()` + `VfxKit` palette constants | godot-specialist | 0.5 | S30-M1 (shares animation review) | (a) float spawns on **kill-gold-credit and level-up events ONLY** — **NOT** per-hit damage numbers (ADR-0025: per-hero attack attribution "would be a fiction"; the resolver does not model per-hit damage); (b) uses `VfxKit.LANTERN_GOLD` / `MOSS_SAGE` — no raw `Color()` literals (dungeon_run_view AC-7); (c) reduce-motion → snap / no float; (d) pooled / auto-freed, ≤ Steam-Deck budget (~24/burst); (e) **validated against redundancy** with the existing kill gold-sparkle burst in the M1-bundled playtest — droppable if it reads as clutter |

### Nice to Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| S30-N1 | **Defeat-moment weight pass** (GDD #34) — the `run_defeated` overlay gets fade + somber audio parity with the victory beat | godot-specialist | 0.5 | S30-M1 | (a) defeat overlay fades in (parchment, reduce-motion clamped); (b) a distinct somber AudioRouter cue (≠ the victory sting); (c) tap-to-continue unaffected |
| S30-N2 | **OQ-27-1 VFX follow-up**: the `aura` / `bubble` / `batwing` demo textures at `assets/art/demo/vfx/` exist but are **unwired** (grep-confirmed — nothing references them). Wire to a real `VfxKit` consumer with a named event, OR formally retire them. | technical-artist | 0.5 | none | Either bound to a `VfxKit.spawn_burst` call site with a named GDD-#27 event, OR moved out of the demo path with a one-line decision note — no unused-asset ambiguity left behind |

## Carryover from Previous Sprint
| Task | Reason | New Estimate |
|------|--------|-------------|
| — None — | S28 closed all 9 planned stories + the 2 grep-surfaced G-stories (`sprint-status.yaml` @ S28: all `done`). S28-N1 VfxKit shipped via PR #204; S30-N2 is a **fresh** OQ-27-1 follow-up, not a carryover. | — |

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| S29 theme re-skin + 4 chimes (PRs #244–#249) are **human-unvalidated** visual/feel work | High | Med | Bundle ONE human playtest covering S29 output **and** S30-M1 ceremony before S30 closeout — folded into DoD, not a blocking pre-gate (user chose to plan first) |
| S30-S1 reward floats **duplicate** the existing kill gold-sparkle burst → clutter | Med | Low | Scope to reward events only; make the playtest the kill/keep decision; S1 is Should-Have and droppable |
| Ceremony stagger fights the existing TapCatcher tap-to-continue | Low | Med | M1-AC(f): TapCatcher stays last-child + interrupt; reuse the documented `victory_moment.gd` playtest-fix contract |

## Dependencies on External Factors
- None. All stories implement **existing** GDDs (#25, #27, #34) against
  already-built screens — no new GDD authoring, no new asset generation
  required (N2 may *retire* assets).

## Definition of Done for this Sprint
- [ ] S30-M1 completed and passing acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-30.md`)
- [ ] All Logic/Integration stories have passing unit/integration tests (M1 cue-selection + reduce-motion snap)
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] **One human playtest** covering S29 theme/chime output + S30-M1 ceremony — sign-off recorded (this closes the open S29 playtest gate)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged (per-task PR → main, no stacked PRs)

## Grep-first findings that reshaped this plan (dropped candidates)
- ❌ **"Hero Detail real content"** — `assets/screens/hero_detail/hero_detail_modal.gd`
  is a **735-line shipped screen** (GDD #22 §C.1–C.6: per-hero stats, affordable
  Level-Up `try_spend` transaction, prestige fade animation, portrait sourcing,
  toasts). The 8-line `assets/overlays/hero_detail/hero_detail.gd` is an
  *intentional* ADR-0007 SceneManager-registration stub, not a reachable
  placeholder. Scoping it would re-build shipped work.
- ❌ **"confirm_save content"** — same intentional ADR-0007 8-line stub; an
  autosave idle game has no established need for a confirm-save dialog. Dropped.
- ❌ **dungeon_run_view particle / strike VFX** — already shipped (1767 lines:
  VfxKit bursts kill→gold-sparkle / level-up→parchment-shimmer / floor-clear,
  strike-pulse beats kill/boss/victory, brightness flashes, per-hero strike
  rotation, throttling).

> **Scope check:** all S30 stories implement existing GDDs against built screens;
> no new epic scope was added. `/scope-check` not required.
