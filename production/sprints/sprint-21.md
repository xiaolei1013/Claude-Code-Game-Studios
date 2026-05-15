# Sprint 21 — 2026-05-15 to 2026-05-28 (10 working days)

> **Status: Day-0 plan authored 2026-05-15**, same-day close of Sprint 20.
> Eighth consecutive same-day-compressed sprint (Sprint 14→15→16→17→18→19→20→21).
> Solo review mode.

## Sprint Goal

**Sweep the design system across the remaining live screens — apply DESIGN.md + the pattern library to Formation Assignment and Recruit Screen — and close the 3 process discipline items surfaced in the Sprint 20 retro.**

Sprint 20 shipped the design system + the first end-to-end application (Guild Hall) + visual playtest PASS. The translation pipeline (DESIGN.md tokens → Godot Theme overrides) held without surprises. Sprint 21 is the **broader-application sweep** — proving the system holds across a second and third screen, where Formation Assignment introduces interactive selection patterns (Slot Button + Two-Tap Assignment Flow) and Recruit Screen introduces transactional patterns (Pool Entry Card + Affordability Gating + Cross-Fade Refresh). All five new patterns landed in the Sprint 20 pattern library (S20-M4); Sprint 21 is the implementation sprint that consumes them.

In parallel, Sprint 21 trials three process disciplines from the Sprint 20 retro: **sprint-status flip-on-merge** (bundle the `status: done` flip into the implementation PR, not a separate bookkeeping pass), **`.uid` sidecar tracking** (stage `.uid` files alongside their `.gd` parents in every PR), and **playtest-branch verification** (before recommending playtest, verify the deliverable is on the playtester's main, not just on a CI-green branch).

**Definition of Sprint 21 success**:
(a) Formation Assignment theme implementation: DESIGN.md tokens applied to `formation_assignment.tscn`; Slot Button variant + Two-Tap Assignment Flow pattern in the slot interaction; mid-run modal styling matches UX-FA-15..21 spec;
(b) Recruit Screen theme implementation: DESIGN.md tokens applied to `recruitment.tscn`; Pool Entry Card variant + Affordability Gating + Cross-Fade Refresh per UX-RS-01..20;
(c) Each theme implementation includes the `sprint-status.yaml` status flip in the same PR that closes its story (process trial);
(d) Each theme implementation stages its sibling `.uid` files alongside any new `.gd` files (process trial);
(e) Sprint 21 playtest validates Formation Assignment + Recruit Screen feel right against the cozy register; recommended playtest method explicitly references "after PR-X merges to main and you pull" (process trial);
(f) Sprint 21 retro captures lessons + Sprint 22 setup.

## Capacity

- Total days: 10 (~2 weeks at 5 days/week, solo)
- Buffer (20%): 2.0 days reserved for unplanned work
- Available: **8.0 days**

**Calibration note**: Sprint 21 is implementation-heavy on two screens with infrastructure already built. The DESIGN.md translation pipeline is validated (S20-M5 playtest PASS); pattern library has all 5 needed patterns (S20-M4); both UX specs are complete (#112 + #113 pre-plan). Risk is LOW — this is execution, not discovery. The biggest unknown is whether Formation Assignment's interactive selection state (selected/unselected/swap-target/locked-during-run) reads correctly post-theme; the spec calls out 21 ACs covering this and the existing tests should still pass.

## Tasks

### Must Have (Critical Path)

| ID | Task | Owner | Est. | Dependencies | Acceptance Criteria |
|----|------|-------|------|--------------|-------------------|
| S21-M1 | **Formation Assignment theme implementation** — apply DESIGN.md + UX-FA spec to `formation_assignment.tscn` + `.gd`. Slot Button theme variation (per interaction-patterns #12); Two-Tap Assignment Flow polish (per pattern #13); mid-run modal styling. Process trial: include `sprint-status.yaml` status flip + `.uid` sidecars in same PR. | godot-gdscript-specialist | 1.0d | none | UX-FA-01..21 spec ACs satisfied; existing tests green; new tests assert Slot Button theme variation application + selected/unselected/locked state visuals; sprint-status flipped in same PR; `.uid` sidecars staged |
| S21-M2 | **Recruit Screen theme implementation** — apply DESIGN.md + UX-RS spec to `recruitment.tscn` + `.gd`. Pool Entry Card theme variation (per interaction-patterns #14); Affordability Gating (per pattern #15); Cross-Fade Refresh on pool refresh (per pattern #20 per UX-RS-10). Process trial: include `sprint-status.yaml` status flip + `.uid` sidecars in same PR. | godot-gdscript-specialist | 1.0d | none (parallel to M1) | UX-RS-01..20 spec ACs satisfied; existing tests green; new tests assert Pool Entry Card theme + Affordability Gating visual states + Cross-Fade Refresh on pool refresh; sprint-status flipped in same PR; `.uid` sidecars staged |
| S21-M3 | **Sprint 21 visual playtest** — validate Formation Assignment + Recruit Screen against the cozy register. Process trial: playtest doc explicitly captures "playtested AFTER PR #X merged to main" verification step. 6 checks: (a) Formation slot selection feels clear; (b) mid-run modal warns correctly (ADR-0001 guardrail); (c) Recruit affordability gating reads at a glance; (d) Pool refresh cross-fade animates per spec; (e) Tap targets remain ≥44×44; (f) Cozy register holds across both screens. | xiaolei (human) | 0.5d | M1 + M2 | `production/playtests/playtest-13-formation-recruit-refresh-2026-05-??.md` committed with verdict on all 6 checks |
| S21-M4 | **Sprint 21 retrospective** | producer + claude-code | 0.25d | M3 | Retro doc committed; sprint-status.yaml closed |

**Must Have total**: 2.75 days

### Should Have

| ID | Task | Owner | Est. | Dependencies | Notes |
|----|------|-------|------|--------------|-------|
| S21-S1 | **Visual-correctness playtest checklist template** — third-time carry from S19 retro action #5 and S20 retro action #6. Author a small `production/playtests/_template-visual-playtest.md` that asks "PASS/FAIL per check" rather than aggregate sign-off. Used by future visual sprints (Sprint 22+) to make per-check verdicts observable. Effort tiny; twice-deferred is the warning sign — non-negotiable for Sprint 21. | claude-code | 0.1d | none | Template committed; references playtest-11 (S19-M5) and playtest-12 (S20-M6) as prior art; ready for Sprint 22 use |
| S21-S2 | **ClassPortrait placeholder art** — generate 6 placeholder class portrait textures (Warrior / Mage / Rogue / Cleric / Ranger / Tactician) as parchment-cream squares with the class's IM Fell English first letter inset in Slate Ink. Carried from S20-N1. Resolves OQ-RS-01 from Recruit Screen spec. Drop-in replacement for real art when it arrives. | claude-code + godot-shader-specialist | 0.5d | M2 | 6 PNG textures committed at `assets/textures/class_portraits/`; theme-tinted preview verified |

**Should Have total**: 0.6 days

### Nice to Have

| ID | Task | Owner | Est. | Notes |
|----|------|-------|------|-------|
| S21-N1 | **Proactive pattern application — DungeonRunView + Victory Moment partial theming** — apply LedgerRow + Conditional Strip patterns to the two next-most-visible screens (DRV's enemy-killed feed; Victory Moment's reward strip). Polish-tier; pulls in only if M+S complete with playtest headroom. Defers Hero Detail Modal + Matchup Assignment as larger interventions for Sprint 22. | godot-gdscript-specialist | 1.0d | M1 + M2 + S1 + S2 | UX-DRV-* and UX-VM-* spec partial-application; existing tests stay green |

**Nice to Have total**: 1.0 days

## Carryover from Previous Sprint

| Task | Reason | New Estimate |
|------|--------|-------------|
| S20-S1 → S21-M1 | Formation Assignment theme implementation; promoted to Must Have because DESIGN.md pipeline validated in S20-M5; no longer experimental | 1.0d (was 0.75d — slight bump for process-trial overhead) |
| S20-S2 → S21-M2 | Recruit Screen theme implementation; same logic as M1; parallel implementation possible | 1.0d (was 0.75d — same overhead) |
| S20-N1 → S21-S2 | ClassPortrait placeholder; carried from S20 nice-to-have; promoted to Should Have because Recruit Screen ships in M2 and the placeholder gap is now visible | 0.5d (unchanged) |
| S19 retro #5 / S20 retro #6 → S21-S1 | Visual-correctness playtest checklist template; THIRD-time carry; non-negotiable | 0.1d |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Formation Assignment selected/swap-target state visuals don't read clearly post-theme | LOW-MED | MED | M3 playtest is the gate; 21 ACs in spec cover the state machine. If a state misreads, revert that specific theme override (not the whole sprint); reuse Sprint 18 N1 disabled-by-default precedent for selective rollback. |
| Cross-Fade Refresh animation on Recruit pool refresh exposes a Godot Tween edge case (Reduce Motion, accessibility) | LOW | LOW | Tween already used in N1 toast / fanfare; pattern is validated. Reduce Motion path explicitly tested in tween_reduce_motion tests; reuse the same guard. |
| Process trial (3 disciplines bundled in M1+M2) adds friction that slows implementation below 1.0d/screen | LOW | LOW | Trial is intentional load-bearing; if pace genuinely suffers, scope-defer the playtest-branch verification check (it's the least mechanically embedded of the three). The status flip + `.uid` tracking are both <5min/PR overhead. |
| N1 (DungeonRunView + Victory Moment partial theming) over-scopes Sprint 21 if user pulls it in but underestimates DRV's hot-path constraints | LOW | MED | N1 is explicitly Nice to Have; the UX-DRV spec's hot-path zero-alloc constraint (codified in spec ACs) is the guard. If N1 starts and DRV's render path looks expensive, defer DRV's theming and only apply to Victory Moment. |

## Dependencies on External Factors

- **Real product art** (user's separate workstream, no ETA): Sprint 21 does not gate on real art. S2 placeholder portraits ship to fill the OQ-RS-01 gap; when real art arrives, S2 textures are a drop-in replacement.
- **No external blocking dependencies otherwise** — all patterns, specs, fonts, theme infrastructure already shipped in Sprint 20.

## Definition of Done for this Sprint

- [ ] All Must Have tasks completed and reviewed
- [ ] Formation Assignment renders the DESIGN.md system; UX-FA-01..21 ACs satisfied (M1)
- [ ] Recruit Screen renders the DESIGN.md system; UX-RS-01..20 ACs satisfied (M2)
- [ ] Both M1 and M2 PRs include the `sprint-status.yaml` status flip + `.uid` sidecars in-PR (process trial)
- [ ] Sprint 21 playtest PASS on all 6 checks (M3)
- [ ] Sprint 21 retro committed; sprint-status.yaml all Must Haves marked done (M4)
- [ ] Visual-correctness playtest checklist template committed (S1) — third-time carry retired
- [ ] No S1 or S2 bugs introduced; existing tests stay green
- [ ] Cumulative test count maintained (4462 PASS or higher); 0 regressions

## Open Questions Resolved at Plan Time

- **Q**: Should Sprint 21 also tackle DungeonRunView + Victory Moment + Hero Detail Modal + Matchup Assignment theme implementations?
  - **A**: No. Sprint 21 caps at the 2 screens specced + applied via pattern library (Formation Assignment + Recruit Screen). DRV + Victory Moment are N1 polish-tier IF headroom exists. Hero Detail Modal + Matchup Assignment are Sprint 22 candidates. **Rationale**: validating the design system across 2 mechanically-different screens (selection + transaction) before committing to the broader sweep is the conservative move that proves the system holds before scaling.
- **Q**: Should the process-trial discipline items (sprint-status flip-on-merge, `.uid` tracking, playtest-branch verification) be their own Must Have, or embedded in M1+M2?
  - **A**: Embedded. They are process changes that ride along with the implementation work, not standalone deliverables. A separate "process trial" Must Have would be theater — the discipline only matters if it shows up in real PRs. M1 and M2 are the carriers.
- **Q**: Does Sprint 21 need a new ADR?
  - **A**: No. Both theme implementations apply existing DESIGN.md tokens and existing pattern library entries; no new architectural decisions are made. The Sprint 21 retro may surface lessons that become future ADRs.

## Pre-Plan Deliverables (already merged 2026-05-14 through 2026-05-15, NOT counted in sprint scope)

These foundation pieces shipped before Sprint 21 began; they constitute the infrastructure the plan builds on:

| PR | Deliverable | Sprint |
|----|-------------|--------|
| #111 | DESIGN.md — design system source of truth | Sprint 20 pre-plan |
| #112 | Formation Assignment UX spec | Sprint 20 pre-plan |
| #113 | Recruit Screen UX spec | Sprint 20 pre-plan |
| #115 | Font sourcing (Lora + IM Fell English) wired into parchment_theme | Sprint 20 M2 |
| #118 | Pattern library 9 → 20 (Slot Button, Two-Tap Flow, Pool Entry Card, Affordability Gating, Cross-Fade Refresh added) | Sprint 20 M4 |
| #119 | Guild Hall theme implementation — first end-to-end pipeline validation | Sprint 20 M5 |
| #120 | Sprint 20 close-out — process discipline lessons surfaced for Sprint 21 trial | Sprint 20 M6+M7 |

## After Sprint 21

If the process-trial disciplines hold (sprint-status stays in sync, `.uid` files commit cleanly, playtest gates explicitly verify branch state), Sprint 22 inherits them as baseline. Sprint 22 candidate themes from the Sprint 20 + 21 retros:
- **Hero Detail Modal + Matchup Assignment theme implementations** (the 2 remaining specced-but-not-yet-applied screens)
- **DungeonRunView + Victory Moment** (if not pulled in via Sprint 21 N1)
- **Real product art ingestion** (if user's separate workstream lands an ETA)
- **Audio direction pass** — sound design has been quiet for several sprints; the visual side is now mature enough to anchor audio decisions against
