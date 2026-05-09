# Pre-Emptive Sprint Plan Cadence — RETIRED 2026-05-09

> **Status: RETIREMENT NOTICE 2026-05-09**. Per `production/sprints/sprint-21.md` S21-S3 task description, this document closes the 11-sprint pre-emptive cadence (Sprint 11 → Sprint 21) and establishes real-time `/sprint-plan` invocation as the Sprint 22+ planning workflow. No further `production/sprints/sprint-NN.md` files are pre-emptively authored.

---

## Why this document exists

For 11 consecutive sprints (Sprint 11 → Sprint 21, authored 2026-05-05 through 2026-05-09 in 4 calendar days), the project's autonomous-execution loop produced sprint plans for windows up to 18 weeks ahead of real-time. By Sprint 21's authoring (2026-05-09), the plan-stack reached Sprint 21's nominal window of 2026-08-29 — a 16-week pre-emption gap.

This cadence served the project well during Sprint 11–16 (the MVP-feature-complete arc). It produced diminishing-returns results during Sprint 17–20 (the post-MVP-feature-complete + V1.0-design-block arc). And by Sprint 21 it crossed into negative-value territory: any further pre-emptively-authored plan would be entirely rewritten before its window opened.

This doc names the pattern, captures the lessons, and replaces the cadence with a real-time workflow.

---

## What the cadence was

Each pre-emptive sprint plan was authored by an autonomous-execution session during the **prior** sprint's autonomous close-out. The pattern:

1. The autonomous well at the END of sprint N produces unspent autonomous capacity.
2. That capacity goes into authoring `production/sprints/sprint-(N+1).md`.
3. Sprint (N+1)'s plan is then available 6-18 weeks before its nominal window opens.
4. When the nominal window opens, the plan is `/sprint-plan`-revalidated against actual real-time state.

The cadence produced 11 plans:

| Sprint | Plan authored during | Pre-emption gap (weeks) | Notes |
|---|---|---|---|
| Sprint 11 | Sprint 10 close (real-time) | 0 | Last reactive plan; Sprint 11 was the MVP-feature-complete sprint |
| Sprint 12 | Sprint 11 close-out | ~3 | First pre-emptive plan |
| Sprint 13 | Sprint 12 close-out | ~5 | Real-time work was outpacing nominal windows by then |
| Sprint 14 | Sprint 13 mid-flight | ~7 | "Mid-flight" pattern emerged: autonomous capacity surplus mid-sprint |
| Sprint 15 | Sprint 14 mid-flight | ~9 | |
| Sprint 16 | Sprint 15 close | ~11 | Last "high autonomous output" sprint |
| Sprint 17 | Sprint 16 mid-flight | ~13 | First inflection: autonomous well shallowed |
| Sprint 18 | Sprint 17 close | ~14 | First post-MVP-feature-complete sprint |
| Sprint 19 | Sprint 18 close | ~15 | Pre-emption ratio forecast: 20–40% |
| Sprint 20 | Sprint 19 close | ~17 | Forecast 15–35% |
| **Sprint 21** | **Sprint 20 close (this session)** | **~18** | **Forecast 25–45%; FINAL pre-emptive plan** |

---

## The diminishing-returns curve

Three forces drove the diminishing-returns curve:

### 1. The planning artifact's signal-to-noise ratio decays with pre-emption gap

- **Gap of 0–4 weeks** (Sprint 11 → Sprint 13 era): the plan is largely actionable as-written. Real-time outcomes are predictable; scope changes are minor.
- **Gap of 5–11 weeks** (Sprint 14 → Sprint 16 era): the plan is scaffolding. ~50–70% of items survive to nominal window; the rest are rewritten. Still net-positive value because the scaffolding accelerates real-time `/sprint-plan` re-validation.
- **Gap of 12–17 weeks** (Sprint 17 → Sprint 20 era): the plan is mostly aspirational. ~20–40% of items survive; the rest depend on real-time outcomes (playtest findings, hardware availability, GDD review verdicts) that the pre-emptive author can't predict.
- **Gap of 18+ weeks** (Sprint 21 era): ~zero useful artifact. Every Must-Have item depends on outputs that don't exist yet at authoring time. The plan is a structural placeholder, not a decision document.

### 2. The autonomous well shallows after MVP-feature-complete

The project's autonomous-output capacity tracked the project's design-block maturity:

- **Sprint 11–16 era (Vertical-Slice → MVP-feature-complete)**: HIGH autonomous output. Most autonomous-doable work had clear scope (story implementation, GDD authoring, ADR decisions, test coverage). Pre-emption was a forcing function for "what else is autonomous-doable?".
- **Sprint 17–18 era (post-MVP-feature-complete polish)**: MEDIUM autonomous output. Settings overlay UI + Onboarding flow + cert-prep prerequisites surfaced as the next-doable items. Pre-emption ratio forecasts dropped to 35–55%.
- **Sprint 19–20 era (V1.0 design block)**: LOWER autonomous output. The V1.0 GDDs (Class Synergy + Prestige) were autonomous-doable as design-document authoring; the rest of Sprint 19/20 work was playtest-driven, hardware-gated, or creative-direction-gated. Forecast 15–35%.
- **Sprint 21+ era (V1.0 implementation + closed-beta + cert)**: MINIMAL autonomous output. Class Synergy + Prestige implementation IS autonomous-doable but depends on `/design-review` APPROVED status; everything else is gated on real-world inputs (playtester response, Steam Direct backend, Steam Deck hardware, creative/marketing voice). Forecast 25–45% but ONLY if review verdicts land in time.

### 3. Pre-emptive plans cannot model real-time creative direction

The cadence assumed that autonomous output could project sprint-level scope decisions forward. This held while the project was building features against a fixed scope (the MVP definition was locked). It broke down at the V1.0 design block: Prestige #31 vs Class Synergy #32 priority order, Steam page tagline A/B selection, hero silhouette art direction, beta tester recruitment criteria — these are creative-director-owned decisions that can't be projected forward without an actual decision-making session.

The Sprint 19+ pre-emptive plans got the AC-level structure right but could not commit on the priority sequencing or the cross-cutting creative-direction calls. Those decisions necessarily land in real-time.

---

## What replaces the cadence

**Real-time `/sprint-plan` invocation** at sprint kickoff:

1. The user invokes `/sprint-plan` (or its equivalent) at or near the actual sprint window opening.
2. The `/sprint-plan` skill reads:
   - `production/stage.txt` (current project stage)
   - The most-recent retrospective (carry-forward items)
   - The previous sprint's closure notes (in-flight work)
   - Active playtest reports (priority drivers)
   - Active GDD review verdicts (gates on implementation work)
   - Active hardware/cert/account state (gates on release-track work)
3. The skill produces a Sprint N plan that's actionable on the day of invocation.
4. No `production/sprints/sprint-(N+1).md` files are authored during sprint close-out.

The autonomous capacity that previously went into pre-emptive plans now goes into:

- **Implementation work** that the V1.0 implementation epics need (Class Synergy + Prestige + cert-prep + beta-cycle hotfixes).
- **Cross-cutting maintenance** (audit-cascade closures, stale-comment cleanup, systems-index Implementation Status updates, locale CSV maintenance).
- **Honest accounting** — when the autonomous well is dry, the session ends without inventing scope.

---

## Lessons learned

### 1. Pre-emptive cadence is a feature, not a bug — until it isn't

The cadence served two real needs:

- **Autonomous capacity utilization**: when the well had surplus, pre-emption converted it into stored planning value.
- **Forcing function for scope discovery**: authoring Sprint (N+1) ahead of time forced the autonomous executor to identify "what else is doable?" — a useful self-audit.

Both benefits decay as the project matures. The retirement decision is about recognizing the decay, not invalidating the cadence.

### 2. The MVP-feature-complete inflection is the cadence's natural shoulder

Looking at the Sprint 16 → Sprint 17 transition: pre-emption ratio dropped from ">95%" to forecast "35–55%" within ONE sprint. That's the inflection — the project's autonomous-doable space shrank dramatically once the feature-set locked.

If a future project follows a similar arc (rapid feature-build → polish → V1.0 design → V1.0 implementation), expect the cadence-natural-shoulder to land at the same MVP-feature-complete inflection. Don't fight the decay; retire the cadence at the shoulder.

### 3. Plan-stack height is a misleading signal

By Sprint 21 the plan-stack reached 18 weeks ahead. Naively, this looks like "we have 18 weeks of planned work." The reality: 18 weeks of scaffolding that will be rewritten when its window opens. Plan-stack height ≠ planning value.

A better signal: **plan-survival ratio** — what % of a pre-emptive plan's Must-Haves survive to nominal window unchanged? At gap=0 the ratio is ~100%. At gap=18+ the ratio is ~0%. The cadence should retire when the ratio drops below ~30%, which corresponds to a gap of ~12-15 weeks.

### 4. Diminishing returns are observable in real-time but underweighted

Sprint 17's forecast ("35–55% pre-emption ratio") was the first explicit signal that the cadence was decaying. Sprint 18, 19, 20 each lowered the forecast further. Sprint 21's plan explicitly named the upper bound. The signal was visible 4 sprints early; the retirement landed at the right time but could have landed at Sprint 19 with no loss of value.

Recommendation: in future projects, retire the cadence when the FORECAST first crosses below 50%, not when the plan-stack height reaches its diminishing-returns gap. The forecast is the leading indicator.

---

## Sprint 22+ planning workflow

When the user wants to plan Sprint 22, they invoke `/sprint-plan` (or the project's equivalent skill). The skill:

1. Reads current project state (see "What replaces the cadence" §3 inputs above)
2. Produces `production/sprints/sprint-22.md` actionable on that day
3. Does NOT pre-emptively author Sprint 23+

The autonomous executor MAY be invoked to support `/sprint-plan` (e.g., reading and summarizing recent retrospectives, scanning open PR review states, computing burndown deltas) — but does NOT author the plan unbidden.

The autonomous executor MAY also be invoked to author specific plan SECTIONS (risks list, dependencies list, sequencing recommendation) once the user has locked the Must-Haves. This is just-in-time delegation, not pre-emptive cadence.

---

## What this doc is NOT

- **Not a retrospective on the 11 plans**. Those exist as `production/retrospectives/sprint-NN-retrospective-*.md` per-sprint. This doc captures the META-pattern across the cadence.
- **Not a critique of pre-emptive planning as a category**. The cadence served the project well during Sprint 11–16. It outlived its useful range; that's normal.
- **Not a project-stage gate**. The project-stage signal (Pre-Production / Production / Polish / Release) is owned by `production/stage.txt` and `/gate-check`. This doc is orthogonal — it concerns the planning workflow, not the project's release readiness.
- **Not a binding restriction on future autonomous output**. If a future autonomous session has genuinely-autonomous-doable scope at sprint close, that scope should be EXECUTED (not pre-emptively planned for a future sprint). The retirement removes the planning-artifact-as-output channel; it does not remove autonomous output as a category.

---

## Cadence-retirement checklist

For audit clarity, the retirement is complete when:

- [x] Sprint 21 plan (`production/sprints/sprint-21.md`) authored as the 11th and final pre-emptive plan
- [x] This retirement doc (`PRE-EMPTIVE-CADENCE-RETIRED.md`) committed at `production/sprints/`
- [ ] Sprint 22+ shifts to real-time `/sprint-plan` invocation when the actual sprint window opens
- [ ] No future commit authors `production/sprints/sprint-22.md` ahead of its window without an explicit user directive

The third + fourth checkboxes are forward-looking — they tick at the point future sessions honor the retirement decision.

---

## References

- `production/sprints/sprint-21.md` §S21-S3 — the task that authored this doc
- `production/sprints/sprint-20.md` §S20-S2 — flagged Sprint 21 as recommended upper bound
- `production/sprints/sprint-19.md` opening note — first explicit "autonomous well IS dry" calibration
- `production/sprints/sprint-17.md` opening note — first inflection ("autonomous well shallowed")
- `production/sprints/sprint-11.md` — the last reactively-authored plan; cadence baseline
- `production/session-state/active.md` — running session-extract record (gitignored)
- CLAUDE.md → Context Management — file-backed state strategy that the cadence operationalized

---

## Notes

- Authored 2026-05-09 by S21-S3 autonomous-execution session (cadence-coherent: the doc that retires the cadence is itself the last cadence-driven autonomous output).
- 132-line Sprint 21 plan + this 200-line retirement doc + the 11 prior plans form the complete archive of the pre-emptive planning era.
- Future questions about why a particular Sprint NN plan looks the way it does should reference this doc as the META-context: pre-emptive plans are scaffolding, not contracts; their item-specific decisions are pre-emption-ratio-discounted by gap-to-nominal-window.
- The retirement is documented here, NOT in CLAUDE.md, because CLAUDE.md is for active workflow guidance — not for archived workflow patterns. If a future user opens a session and asks "should I write Sprint 22 now?", the answer routes through CLAUDE.md's `/sprint-plan` skill description, which (per this retirement) instructs real-time invocation at window-opening.
