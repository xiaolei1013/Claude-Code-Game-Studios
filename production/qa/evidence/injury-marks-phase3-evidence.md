# Injury Marks (Defeat & Injury Phase 3) — Visual Evidence (GDD #34, AC-34-09)

> **GDD**: `design/gdd/defeat-and-injury-system.md` §C.4, §H AC-34-09
> **ADR**: ADR-0021 (defeat-state pivot)
> **Phase**: 3 — Injury System (`feat/defeat-injury-phase3`)
> **Author**: Phase 3 implementation (2026-06-14)
> **Status**: `[x]` Captured (headful screenshot) — automated coverage green; human playtest still the closure gate

This document captures the **Visual/Feel** evidence for AC-34-09 (injured heroes
are visually marked) that automated state-assertion tests cannot fully convey.
Per the project convention, the PNG itself is kept local (the evidence dir tracks
markdown, not binary screenshots); this doc describes what was rendered and how to
reproduce it.

---

## AC-34-09 — Injured heroes are visually marked (roster + formation)

**Local artifact**: `production/qa/evidence/injury_marks_guild_hall_20260614.png`
(132 KB, captured 2026-06-14, untracked — local-only per evidence-dir convention).

**Capture method**: Headful screenshot harness (project memory:
`godot-headful-screenshot-harness`) — a throwaway `-s SceneTree` script run
NON-headless with the Vulkan driver, seeding a roster where one hero is injured
(`injured_until = now_ms + 30 min`) and the rest healthy, then rendering the
Guild Hall RosterPanel to PNG at frame ≥ 16.

**What the screenshot shows**:
- The **injured** hero (Lyra) is **faded to 50% opacity** (`INJURED_DIM_ALPHA`) and
  carries a top-right **"Injured · 30m"** badge.
- The **healthy** heroes (Theron, Vex) render at **full opacity** with **no badge**.
- The badge text is the primary, **non-color** signal (colorblind-safe per
  `ui-code.md` — the literal "Injured" word, not hue, conveys state).

**Pass condition**: A human can tell at a glance which hero cannot be dispatched,
without relying on color. ✅ Confirmed in the captured frame.

**Known minor polish nit (advisory, not blocking)**: on a narrow formation *picker*
card the badge can abut the "vs caster" summary text ("casterInjured · 30m") —
legible but crowded. Tracked as a follow-up polish item; does not affect the
guild-hall roster card or formation slots.

`[x]` Pass / `[ ]` Fail / `[ ]` Not yet executed

---

## Automated coverage (the load-bearing state assertions)

AC-34-09's structural contract is fully covered by automated tests — the
screenshot above only adds the human-visual confirmation the tests can't make.

| Suite | Cases | What it locks |
|---|---|---|
| `tests/unit/ui_framework/ui_framework_injury_test.gd` | 18 | `format_recovery_countdown` units (`45s`/`1m`/`30m`/`1h 2m`/empty); `mark_injured` dims to 0.5, adds an `InjuredBadge` Label child, badge is `MOUSE_FILTER_IGNORE`, idempotent (no stacking on re-mark), null-safe; `clear_injured` restores opacity + removes badge. |
| `tests/integration/guild_hall/roster_injury_mark_test.gd` | 6 | Live guild-hall roster: injured card has badge + is dimmed + badge is IGNORE; healthy card has no badge; a past `injured_until` reads as healthy; the `heroes_injured` signal re-marks a card live. |
| `tests/integration/formation_assignment/formation_injury_mark_test.gd` | 7 | Both the roster **picker** and occupied **formation slots** mark injured heroes; empty slots never carry a badge; the `heroes_injured` signal re-marks picker + slot live. |

**Combined Phase-3 run (2026-06-14, local `Godot_mono` 4.6.1)**: the four
UI/dispatch-gate suites report **37/37 PASSED, 0 failures, 0 orphans, exit 0**;
the L1–L3 + save-migration suites report **91/91 PASSED, 0 failures, 0 orphans,
exit 0**. No regressions: the two pre-existing
`formation_assignment_screen_test.gd` failures reproduce identically on a clean
`main` worktree and are unrelated to this change.

---

## Cross-reference

- AC-34-04 (dispatch gate) — the badge being `MOUSE_FILTER_IGNORE` is what keeps an
  injured hero **tappable** for inspection/slot-assignment while **only Dispatch**
  is gated; verified by
  `tests/integration/dungeon_run_orchestrator/orchestrator_injury_gate_test.gd`.
- Closure gate: per project practice, 100% green tests ≠ shipped — a human
  playtest against merged `main` remains the load-bearing closure gate for the
  Defeat & Injury arc.
