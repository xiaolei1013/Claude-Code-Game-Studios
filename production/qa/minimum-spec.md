# QA Minimum-Spec Hardware Profile

> **Status**: Scaffold authored (Pass-5C 2026-04-21 — empty targets; population deferred to first pre-playtest QA cycle).
> **Author**: qa-lead + main session
> **Consumed By**: AC-SL-11 (persist performance), AC-SL-12 (load performance), and any future performance AC across all GDDs.
> **Scope**: The "minimum spec" is the lowest hardware profile the game commits to supporting at launch. Performance ACs are evaluated against these targets; a game that passes on a reference PC but fails on a 2016 mobile is not shipping-ready.

## Purpose

`production/qa/minimum-spec.md` is the authoritative binding between performance ACs in GDDs and the real hardware against which those ACs are verified. Before any performance AC can be marked "ready for QA execution," QA MUST resolve the AC's device tier against a row in this file and record the specific hardware used in the evidence file under `production/qa/evidence/`.

This file is consumed by:
- **AC-SL-11 (Save/Load persist performance)** — <20 ms PC, <50 ms mobile on minimum spec.
- **AC-SL-12 (Save/Load load performance)** — <50 ms PC, <100 ms mobile on minimum spec.
- Future performance ACs across all GDDs (combat resolution timing, offline-credit compute, scene transition, etc.) SHOULD reference this file rather than restate hardware targets inline.

## Tier Structure

Three tiers, all MVP-relevant:

1. **PC Minimum** — the floor PC configuration the game supports at launch.
2. **Steam Deck** — Valve's handheld at native resolution/refresh.
3. **Mobile Minimum** — the oldest iOS + Android device profile supported.

Each tier has a corresponding reference device QA physically owns (or uses via a cloud-device farm) and a published CPU/GPU/RAM/storage profile.

## Tier Specifications (TO POPULATE)

### PC Minimum

| Field | Target | Source / Rationale |
|---|---|---|
| OS | _TBD_ | Resolve against Steam hardware survey + FUNDING pillar |
| CPU | _TBD_ | — |
| GPU | _TBD_ | — |
| RAM | _TBD_ (≤ 512 MB budget per `.claude/docs/technical-preferences.md`) | — |
| Storage | _TBD_ (SSD vs HDD affects load AC-SL-12) | — |
| Display | _TBD_ | — |
| Reference device | _TBD_ (QA owns: _device ID_) | — |

### Steam Deck

| Field | Target | Source / Rationale |
|---|---|---|
| Model | _TBD_ (LCD / OLED / future revisions) | — |
| Resolution / Refresh | 1280×800 / 60 Hz (per `.claude/docs/technical-preferences.md`) | Pinned |
| Storage | _TBD_ (eMMC vs NVMe) | — |
| Reference device | _TBD_ (QA owns: _device ID_) | — |

### Mobile Minimum

| Field | iOS Target | Android Target | Source / Rationale |
|---|---|---|---|
| OS version floor | _TBD_ | _TBD_ | — |
| CPU | _TBD_ | _TBD_ | — |
| GPU | _TBD_ | _TBD_ | — |
| RAM | _TBD_ (≤ 256 MB budget per tech-preferences) | _TBD_ | — |
| Storage | _TBD_ | _TBD_ | — |
| Reference device | _TBD_ (QA owns: _model_) | _TBD_ (QA owns: _model_) | — |

## Evidence Discipline

When a performance AC is executed, the evidence file under `production/qa/evidence/` MUST contain:

- The tier row used (e.g., "PC Minimum" or "Mobile Minimum — iOS").
- The specific reference device ID (QA's physical device — not a generalization).
- The exact measured value (p50, p95, p99 — not a single sample).
- The AC's stated budget for that tier.
- Pass/fail judgment with any caveats (thermal throttling, battery-saver mode, etc.).

## Update Procedure

- **When minimum-spec targets change** (e.g., product decides to raise iOS floor from iOS 14 to iOS 16), this file is updated in the same PR as the marketing/store-page claim; GDDs that reference minimum-spec targets do NOT restate the values — they reference this file.
- **When a new reference device is procured**, the tier row's "Reference device" field is updated; prior evidence captured against the old device is marked historical in the evidence log but not retroactively invalidated.
- **When a new performance AC is authored**, the AC SHOULD reference this file by tier name (e.g., "on PC Minimum") rather than inline hardware specs.

## Outstanding Population Work

Before the first Save/Load story is marked "ready for QA execution":

- [ ] Population task owned by: qa-lead (consulted: producer for scope, art-director for resolution targets, engine-specialist for GPU driver baselines).
- [ ] Reference PC procured + profile published.
- [ ] Steam Deck LCD + OLED profiles published.
- [ ] Mobile reference devices procured (iOS + Android) + profiles published.
- [ ] This file's TBD cells filled; scaffold → populated marker in the Status line.

Until population completes, AC-SL-11 and AC-SL-12 are `[FIXTURE-READY / EXECUTION-GATED-MINIMUM-SPEC]` — QA authors the timing probes against the reference PC immediately available to the project, records results, and marks them provisional pending the minimum-spec population pass.

---

**Pass-5C Note (2026-04-21):** This file exists as a scaffold so that AC-SL-11 and AC-SL-12 have a concrete referent for their "minimum-spec hardware" clause. Populating the TBD cells is a scope item owned by qa-lead, sequenced with the first pre-playtest QA cycle — NOT with the current Save/Load #3 GDD review arc. Creating the scaffold now prevents the AC text from being a forward-reference to a non-existent file, which would have failed `/design-review --depth lean` on AC testability grounds.
