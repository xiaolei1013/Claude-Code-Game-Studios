# Sprint 20 — 2026-08-19 to 2026-08-28 (9 working days, nominal)

> **Status: GROUNDWORK AUTHORED 2026-05-09** by S19-S3 autonomous-execution session, continuing the 9-sprint pre-emptive Sprint-N+1 plan cadence (Sprint 14 plan during Sprint 13 close → Sprint 15 plan during Sprint 14 close → Sprint 16 plan during Sprint 15 mid-flight → Sprint 17 plan during Sprint 16 mid-flight → Sprint 18 plan during Sprint 17 autonomous close-out → Sprint 19 plan during Sprint 18 autonomous close-out → this Sprint 20 plan during Sprint 19 autonomous close-out). 10th consecutive sprint plan authored before its nominal window. The planning artifact stack now reaches **17 weeks ahead of real-time** (Sprint 20 nominal window: 2026-08-19 → 2026-08-28; current real-time: 2026-05-09).

> **Calibration note**: at 17 weeks ahead, the cadence is well past timely. Pre-emption serves as a forcing function for "did we identify enough autonomous-doable items in this autonomous session?" rather than as a planning artifact that will be acted on in real-time. Re-validate via `/sprint-plan` before Sprint 20 kickoff (2026-08-19); the actual Sprint 19 outcomes — including whether Class Synergy #32 first-pass GDD shipped APPROVED via PR #20, and whether Steam Deck hardware materialized for S19-M5 + S19-S6 — will substantially reshape Sprint 20's contents.

## Sprint Goal

**Close the V1.0 design block + open the cert-prep track + ship the second V1.0 progression GDD.** Sprint 19 advanced ONE V1.0 stub GDD (Class Synergy #32 per S19-M3 PR #20). Sprint 20 closes the OTHER (Prestige #31). In parallel, Sprint 20 opens the cert-prep workstream: Steam store submission requirements checklist, build-pipeline parity validation across all 3 MVP platforms, and store-listing copy iteration.

**Definition of Sprint 20 success**: (a) Prestige #31 first-pass GDD APPROVED (or COMPLETE WITH NOTES if review surfaces revisions); (b) Sprint 19 retrospective committed; (c) Sprint 21 plan groundwork authored (continuing the pre-emptive cadence); (d) Steam cert-prep checklist authored (`production/release/steam-cert-prep-checklist.md`); (e) RC build pipeline produces artifacts on all 3 platforms (Linux Steam Deck + Windows + macOS) — confirms no platform-specific export-preset bugs.

## Capacity

- Total days: 9 (1.5 weeks at 6 days/week)
- Buffer (20%): 1.8 days reserved for unplanned work
- Available: **7.2 days**

**Calibration warning**: Sprint 20 is firmly **post-MVP-feature-complete**. Most work is doc + design + cert-prep + retro. Real-engineering autonomous surface is small. Pre-emption ratio forecast: 15–35%, continuing the downward trend.

## Pre-flight checklist (Day 0)

- [ ] Sprint 19 retrospective committed (`production/retrospectives/sprint-19-retrospective-<date>.md`)
- [ ] PR #20 (Class Synergy first-pass GDD) merged with APPROVED or REVISED-then-APPROVED verdict
- [ ] PR #19 (RC build pipeline scaffold) merged
- [ ] All Sprint 19 commits pushed to main
- [ ] `tests/` is green at Sprint 19 close (≥1763 tests / 0 failures expected — no test-surface change forecast for Sprint 19)
- [ ] If Sprint 19 S19-M5 was promoted from "scaffold COMPLETE" to "scaffold + verified Steam Deck artifact COMPLETE" by manual editor + hardware steps, the verification log lives at `production/qa/evidence/rc-build-verification-2026-08-XX.md`

## Tasks

### Must Have (Critical Path)

| Story ID | Task | Owners | Estimate (days) | Dep | Notes / AC |
|---|---|---|---|---|---|
| S20-M1 | **Prestige #31 first-pass GDD authoring** — promote `design/gdd/prestige-system.md` from STUB DRAFT (68 lines) to FIRST-PASS DRAFT. Mirror the Class Synergy PR #20 pattern: 8 required GDD sections + resolved Open Questions + ACs + cross-GDD §F.3 amendment list. Pairs with #32 as the V1.0 progression layer family. | game-designer + systems-designer | 1.5d | none |
| S20-M2 | **Steam cert-prep checklist authoring** — author `production/release/steam-cert-prep-checklist.md` covering: Steamworks SDK integration prereqs (DRM-free shipping vs Steam DRM tradeoff per `game-concept.md`), age rating filings (ESRB/PEGI/USK self-rating questionnaires), achievements + leaderboard schemas (skip for MVP per cozy-register), input prompt asset requirements (Steam Deck controller-vs-mouse/touch fork), trading card / community hub setup (V1.0+), localization pipeline finalization (en CSV → store description string set). Source: Steamworks documentation + project-specific decisions tagged in ADR-0008 + ADR-0016. | release-manager + writer | 1.0d | none |
| S20-M3 | **Sprint 19 retrospective** — track post-MVP-feature-complete cadence (Sprint 17–19 trend), document the autonomous-well shallowing pattern empirically, capture lessons from PR #19 (RC build pipeline gating on manual editor + hardware steps), PR #20 (V1.0 GDD authoring tempo), and any Sprint 19 M1/M2 playtest-driven calibration tweaks if S18-M3 playtest was actually executed. | producer + claude-code | 0.25d | Sprint 19 nominal window closed |
| S20-M4 | **RC build pipeline platform parity** — Sprint 19 S19-M5 shipped the scaffold (Linux Steam Deck primary; Windows + macOS presets configured but unverified). Sprint 20 closes the parity verification: install export templates on the dev workstation, run `tools/build/build.sh all` to produce Linux + Windows + macOS artifacts, document any platform-specific export-preset bugs that surface, and amend `tools/build/README.md` with corrections. | devops-engineer + release-manager | 1.0d | S19-M5 scaffold merged + export templates installed manually |
| S20-M5 | **Class Synergy V1.0 implementation epic authoring** — decompose the Class Synergy first-pass GDD (PR #20) into a Sprint 21+ implementation epic with story breakdown. Likely 4-5 stories spanning: (1) `FormationAssignment.detect_active_synergy` + RunSnapshot.synergy_id field; (2) `attribute_kill_gold` + `attribute_kill_xp` formula extension; (3) Audio integration (2 new cues + suppression); (4) Localization + reduce-motion + UI badge wiring; (5) Cross-GDD §F.3 bidirectional dependency amendments to 8 sibling GDDs. | producer + game-designer + lead-programmer | 0.75d | PR #20 merged with APPROVED status |

**Sprint 20 Must Have total**: ~4.5d. Within 7.2d available with ~2.7d for Should-Have absorption.

### Should Have

| Story ID | Task | Owners | Estimate | Dep |
|---|---|---|---|---|
| S20-S1 | **Steam page copy iteration #2** — Sprint 19 S19-S1 produced a first-pass draft (long description + short description + system requirements + screenshot captions). Sprint 20 iterates per writer feedback + Steam community-best-practices research; refines the elevator-pitch sentence; adds genre tags + similar-games comparisons. | writer + community-manager | 0.5d | S19-S1 first-pass committed |
| S20-S2 | **Sprint 21 plan groundwork** — 11th consecutive pre-emptively-authored sprint plan. Scope candidates: Class Synergy V1.0 implementation epic kickoff (per S20-M5), beta release candidate authoring, closed-beta playtester onboarding flow, post-launch live-ops scaffolding (telemetry events). | producer + claude-code | 0.25d | none |
| S20-S3 | **Cross-GDD audit pass — Class Synergy F.3 amendments** — execute the 8 sibling-GDD bidirectional-dependency amendments flagged in the Class Synergy PR #20 §F.3 (formation-assignment, dungeon-run-orchestrator, economy, hero-leveling, save-load, audio, matchup-resolver, hero-class-database). Single batch pass; one commit per GDD or one batched commit. | game-designer | 0.5d | PR #20 merged |
| S20-S4 | **ADR-0017 HD-2D pivot trigger re-evaluation** — Sprint 19 S19-S6 was forecast to surface Steam Deck performance numbers; if it did, re-evaluate ADR-0017's silent-MVP defensible default. If S19-S6 confirmed 60 fps stable at 1280×800 native, ADR-0017 stays unpivoted; if it surfaced sub-60 fps OR stuttering, the HD-2D pass becomes unblocked and S20-S4 promotes to a tracking ADR amendment. | technical-artist + technical-director | 0.5d | S19-S6 evidence |
| S20-S5 | **Locale CSV expansion #2** — Sprint 19 S19-S4 added Settings + Onboarding strings. Sprint 20 adds the 6 Class Synergy strings from PR #20 (`class_synergy_badge_steel_wall`, `_arcane_elite`, `_triple_threat` + `class_synergy_effect_*` triplet) + any Prestige #31 first-pass strings surfacing from S20-M1 authoring. Locale freeze for English-source corpus is the V1.0 launch milestone target. | localization-lead + writer | 0.25d | PR #20 merged + S20-M1 first-pass shipped |

### Nice to Have

| Story ID | Task | Owners | Estimate | Dep |
|---|---|---|---|---|
| S20-N1 | **Beta release candidate authoring** — first beta build artifact intended for closed-beta distribution. Includes version bump (`game-concept.md` versioning + `application/file_version` in export_presets.cfg), release notes, known-issues list. Gated on the 3-platform build-pipeline parity (S20-M4) closing. | release-manager + writer | 0.75d | S20-M4 done |
| S20-N2 | **Closed-beta playtester onboarding flow** — author the `production/release/closed-beta-onboarding.md` doc covering: tester recruitment criteria, NDA template (or freeware-license alternative), feedback channel setup (Discord vs Google Forms vs custom), bug-report template, demographic-coverage targets. | producer + community-manager | 0.5d | S20-N1 build artifact exists |
| S20-N3 | **Post-launch live-ops scaffolding — telemetry events** — author `production/live-ops/telemetry-events-v1.md` enumerating the V1.0 event taxonomy (cozy-register-respecting; opt-in; minimal PII). Per `game-concept.md` cozy-fantasy, no engagement-pressure events; just diagnostic + balance-tuning data points. | analytics-engineer + producer | 0.5d | game-concept.md cozy-register guidance reviewed |
| S20-N4 | **Save-format V2 migration scaffold** — Sprint 19 S19-N3 forecast a V2 schema bump on first V1.0 design landing a save-shape change. If Class Synergy PR #20 OR Prestige S20-M1 introduce save-shape changes (Class Synergy adds RunSnapshot.synergy_id; Prestige adds per-hero `prestige_level: int`), author the Sprint 21+ migration story for `_run_migration_chain` v1→v2. | gameplay-programmer | 1.0d | PR #20 + S20-M1 save-shape impact assessed |
| S20-N5 | **systems-index Implementation Status maintenance** — flip whichever systems' Status flipped during Sprint 19 (#32 Class Synergy from STUB DRAFT → FIRST-PASS DRAFT confirmed; potentially #31 Prestige promoted by S20-M1; potentially `tools/build/` cross-listed as new infra). | producer + claude-code | 0.25d | S20-M1 + S20-M5 done |
| S20-N6 | **Steam Deck verification badge submission rehearsal** — Steam Deck Verified program requires specific compatibility checks (controller mapping, default text size, screen-resolution support). Per technical-preferences.md, the project commits to 1280×800 native + 60 fps stable + touch-input parity. Author the rehearsal checklist + map current ACs to the badge requirements. | release-manager + ux-designer | 0.5d | none |

## Sprint 20 sequencing recommendation

- **Day 1 morning**: S20-M3 Sprint 19 retro (0.25d)
- **Day 1-3**: S20-M1 Prestige first-pass GDD (1.5d) — substantial design work; budget Day 1 afternoon through Day 3 morning
- **Day 3 afternoon**: S20-S3 Cross-GDD F.3 amendments for Class Synergy (0.5d) — paperwork; nice cool-down task after the design-heavy S20-M1
- **Day 4**: S20-M2 Steam cert-prep checklist (1.0d)
- **Day 5**: S20-M4 Build pipeline parity (1.0d)
- **Day 6 morning**: S20-M5 Class Synergy implementation epic (0.75d)
- **Day 6-7**: Should-Have absorption — S20-S1 + S20-S2 + S20-S5 (≤1.0d total)
- **Day 8-9**: Nice-to-Have absorption + buffer

**Anti-pattern to avoid**: don't try to ship Prestige #31 implementation in Sprint 20. The first-pass GDD is the deliverable; implementation lands in a Sprint 22+ epic alongside Class Synergy implementation. Sprint 20 is design-and-cert-prep, not feature implementation.

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **Prestige #31 first-pass surfaces gameplay-vision conflict** — Prestige is more abstract than Class Synergy; the design questions (cap-reset vs permanent multiplier vs cosmetic-unlock) require creative-director taste calls that may not converge in the autonomous loop. | MEDIUM–HIGH | MEDIUM | Author the GDD with explicit "preferred direction with alternative paths" framing per the Class Synergy PR #20 model. Surface the 3 main design forks as Open Questions for `/design-review` to resolve. Don't pretend to lock decisions the user must own. |
| **S20-M4 platform parity surfaces export-preset bugs** — Windows + macOS presets in Sprint 19 PR #19 were configured but unverified. First end-to-end multi-platform export run is a "known unknown" — likely 1-2 small fixes (icon path? bundle-id format?). | MEDIUM | LOW | Time-box at 1.0d; if a platform fails after 2h of debugging, scope-reduce to "Linux only verified; Windows + macOS scaffolded but pending Sprint 21 follow-up". |
| **PR #20 review verdict is REVISED rather than APPROVED** — Class Synergy first-pass may surface design-review concerns that block APPROVED status. | MEDIUM | LOW | If the verdict is REVISED, Sprint 20 absorbs the revision pass into S20-M5 (epic authoring depends on a stable GDD). If multiple revision passes, S20-M5 slips to Sprint 21 — acceptable. |
| **The autonomous well shallows below 15%** | HIGH (continuing trend) | LOW | Sprint 20 is structurally a design + cert-prep + retro sprint; most work is human-gated by design (creative-director vibes on Prestige; cert-prep details depend on Steamworks account state; release-manager voice on store copy). Continue using freed time for documentation polish + retroactive ADR cleanup. |
| **Sprint 19 outcomes substantially reshape Sprint 20** | HIGH | LOW (acknowledged) | This sprint plan is authored 17 weeks ahead. Sprint 19's actual outcomes — playtest findings, GDD review verdicts, hardware availability — will reshape Must Haves. Treat this plan as scaffolding; re-validate via `/sprint-plan` at Sprint 20 kickoff. |

## Dependencies on External Factors

- **PR #20 review**: Sprint 20 M5 (Class Synergy epic authoring) is gated on PR #20 merging with APPROVED. If REVISED, M5 absorbs the revision iteration.
- **Steam Deck hardware**: gates S20-M4 verification (artifact runnability) + S20-N6 badge rehearsal. Without hardware, both ship as scaffold-only.
- **Godot export templates installed**: gates S20-M4. The Sprint 19 PR #19 README documented the manual install step; Sprint 20 assumes that step has happened by Day 5.
- **Steamworks account access**: gates S20-M2 cert-prep specifics (checklist can be authored from public Steamworks docs without account access; account-specific items deferred to follow-up).
- **`/design-review` feedback velocity**: gates S20-M1 Prestige APPROVED status.

## Definition of Done for Sprint 20

- [ ] Prestige #31 first-pass GDD APPROVED (or COMPLETE WITH NOTES if revisions)
- [ ] Sprint 19 retrospective committed
- [ ] Sprint 21 plan groundwork authored
- [ ] Steam cert-prep checklist committed at `production/release/steam-cert-prep-checklist.md`
- [ ] `tools/build/build.sh all` produces artifacts on Linux + Windows + macOS (or a documented "platform X failed pending Sprint 21 fix" note)
- [ ] Class Synergy V1.0 implementation epic decomposed into stories at `production/epics/class-synergy-system/EPIC.md` + per-story files
- [ ] Cross-GDD F.3 amendments for Class Synergy applied to 8 sibling GDDs
- [ ] Steam page copy iteration #2 committed
- [ ] Locale CSV expansion #2 committed (6 Class Synergy keys + Prestige first-pass strings if any)
- [ ] Full unit + integration sweep ≥1763 tests, 0 failures (no test-surface change forecast for Sprint 20 since Class Synergy + Prestige implementation are Sprint 22+ scope)

## Sprint 21+ candidates (post-Sprint-20)

- Class Synergy V1.0 implementation epic kickoff (Story 1: detect_active_synergy + RunSnapshot.synergy_id field)
- Prestige V1.0 implementation epic authoring (decompose the S20-M1 GDD into stories)
- Save-format V2 migration story (if S20-N4 surfaced a save-shape change)
- Beta release candidate v0.1 (post-S20-N1) — first artifact for closed-beta tester distribution
- Closed-beta playtester recruitment (post-S20-N2 onboarding doc)
- Telemetry event implementation (per S20-N3 taxonomy doc)
- Steam Deck Verified badge submission (post-S20-N6 rehearsal)
- ADR-0017 HD-2D pivot if S19-S6 / S20-S4 surfaced invalidation
- ADR-0016 audio sourcing pivot if mobile port milestone enters scope
- Localization Pass 2 — non-English locales (gated on en CSV freeze + writer voice lock)

## Notes

- Authored 2026-05-09 by S19-S3 autonomous-execution session — 10th consecutive pre-emptively-authored sprint plan. Re-validate via `/sprint-plan` before Sprint 20 kickoff (2026-08-19); the actual Sprint 19 outcomes will substantially reshape Sprint 20's contents.
- Sprint 20 is the second **post-MVP-feature-complete** sprint. The pivot from "build features" to "polish + harden + cert + V1.0 GDDs" is now firmly the operating mode. Sprint 20 carries that forward without major shape change.
- **Pre-emption ratio forecast**: Sprint 20 forecast 15–35% — continuing the downward shift from Sprint 19's 20–40%. This is the steady-state for a project at MVP-feature-complete + V1.0-design-block-in-progress maturity.
- After Sprint 20, the project should have **both V1.0 progression GDDs at FIRST-PASS DRAFT or APPROVED** + **Steam cert-prep checklist** + **3-platform build artifacts** + **Class Synergy implementation epic decomposed** + **store listing copy iterated**. Sprint 21+ work transitions toward (a) implementation of the V1.0 progression layers, (b) cert submission rehearsals, (c) closed-beta release candidate authoring.
- **Plan-stack at 17 weeks ahead** — diminishing returns on further pre-emptive plan authoring. The 11th sprint plan (Sprint 21, authored in S20-S2) is the suggested upper bound; further pre-emption beyond that runs into "this plan will be entirely rewritten before its window opens" territory. Recommend stopping the pre-emptive cadence at Sprint 21 unless the autonomous well surfaces specific Sprint-22+ scope items that benefit from being captured.
