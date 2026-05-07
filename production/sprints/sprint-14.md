# Sprint 14 — 2026-06-19 to 2026-06-28 (9 working days, nominal)

> **Status: GROUNDWORK AUTHORED 2026-05-06** by post-Sprint-13-S3 close-out session (autonomous-execution session continuing the Sprint 12 → 13 → 14 pre-emptive cadence). Re-validate via `/sprint-plan` if anything material changes between now and Sprint 14 kickoff. Sprint 13 nominally runs 2026-06-08 → 2026-06-17; Sprint 14 picks up immediately after.

## Sprint Goal

**Polish the cozy register and unblock the design-review backlog.** Sprint 13's autonomous pre-emption closed 3 of 4 Must Haves + every actionable Should Have; what carries forward is genuinely-gating work (audio sourcing decision, Settings GDD review pass) and fresh polish-bar items (Settings UI implementation, real XP curve replacing the S10-M4 stub, HD-2D shader pass). Sprint 14 turns that backlog into shipped polish.

**Definition of Sprint 14 success**: (a) the audio sourcing decision is locked in an ADR (silent OR sourced); (b) Settings overlay UI is implemented and live in Guild Hall; (c) the +1-per-clear XP stub is replaced with a real XP-curve formula per a hero-leveling GDD authored this sprint; (d) at least one HD-2D visual polish pass lands (tilt-shift OR warm-lantern overlay per Visual Identity Anchor).

## Capacity

- Total days: 9 (1.5 weeks at 6 days/week)
- Buffer (20%): 1.8 days reserved for unplanned work
- Available: **7.2 days**

**Calibration warning (per Sprint 12 + 13 retros): NO pre-emptive buffer remains.** Sprints 10-13 absorbed substantially more than planned via autonomous Day-0 pushes. Sprint 14 starts cold; plan for actual day-by-day execution at 1.0× plan estimate, NOT the 0.5–0.6× ratio Sprints 11-13 averaged. The pre-emptive surface area is exhausted: every remaining tractable item now requires either fresh authoring, a human decision, or a creative-direction call.

## Pre-flight checklist (Day 0)

- [ ] Settings GDD #30 has had at least one `/design-review` pass and is APPROVED or CONCERNS-only
- [ ] Audio sourcing decision is locked (S14-M1 below) — gating for S14-M3 and S14-N1
- [ ] Story 013 (orchestrator state buffering) verified live: `_buffered_state_change` field present, slow-path `_on_state_changed` is the sole RUN_ENDED handler, no screen-level early-detection block in `dungeon_run_view.gd`
- [ ] `tests/` is green at Sprint 13 close (≥1457 tests expected)
- [ ] Sprint 13 retrospective committed (extending Sprint 12's pattern)

## Tasks

### Must Have (Critical Path)

| Story ID | Task | Owners | Estimate (days) | Dep | Notes / AC |
|---|---|---|---|---|---|
| S14-M1 | **Audio asset sourcing decision** (carry-forward S13-M1) — author an ADR documenting commission vs. license vs. AI-generated vs. ship-MVP-silent. Decision is a creative + budget call; this story formalizes the choice and its consequences. If non-silent: sourcing pass authors all 11 SFX cues + 2 music beds + 2 stingers per audio-system.md §C.2 / §C.3 and places them at `assets/audio/<type>/<id>.<ext>` wrapped in `assets/data/<category>/<id>.tres` (per audio-system.md §C.6 path convention from S12-S5). If silent: update game-concept.md §Audio Needs to match; document AudioRouter as "wired but silent until post-MVP". | audio-director + creative-director | 0.5d (decision) + 1.0d (sourcing if non-silent) | none | ADR authored; if non-silent, all 11 SFX cues + 2 music beds resolve through DataRegistry; AudioRouter cue-dispatch tests in `audio_router_signal_handlers_test.gd` continue to pass; manual smoke verifies at least the level-up chime + UI tap chime + floor-clear fanfare audibly play. |
| S14-M2 | **Settings GDD #30 design-review pass + revisions** | game-designer + qa-lead | 0.5d | Settings GDD draft committed (S13 e0649c8) | `/design-review settings-options-accessibility.md` runs; expected 5–10 BLOCKING items per first-pass-GDD precedent (audio-system.md / recruitment-system.md). Revisions resolve in-GDD or refile cross-GDD as Open Questions. Verdict: APPROVED or CONCERNS-only. |
| S14-M3 | **Settings overlay UI implementation** (S13-S4 carry-forward, now unblocked) — implement the 5 stories from Settings GDD §J: overlay scene authoring + volume slider wiring + toggle wiring + save/reset/auto-save flows + edge cases (replay-gating, corruption recovery, headless). | ui-programmer + accessibility-specialist | 2.0d | S14-M2 APPROVED | All 14 ACs from Settings GDD §H pass via integration tests at `tests/integration/settings_overlay/`. Volume slider mapping per §C.2 (linear-to-dB with 20·log10). Mute hard-overrides per §C.3. reduce_motion round-trips through `user://settings.cfg` per S12-S2 contract. Locale dropdown reads `TranslationServer.get_loaded_locales()`. |
| S14-M4 | **Real XP curve formula + Hero Leveling GDD** (replaces S10-M4 stub `+1 per clear`) — author the missing Hero Leveling GDD #15 (currently "Not Started" in systems-index.md). Lock the XP-per-kill / XP-per-floor-clear formulas + the level cost curve already defined in S12-N5 (Economy.level_cost). Replace orchestrator's `_grant_stub_levels_to_formation` with real XP grant logic. | game-designer + economy-designer + gameplay-programmer | 1.5d | none | Hero Leveling GDD #15 has all 8 required sections + ACs locking XP-per-kill formula + per-floor-clear formula + max-level cap + XP-overflow handling. Orchestrator XP grant uses the formula; existing stub-XP test at `tests/unit/dungeon_run_orchestrator/stub_xp_grant_test.gd` updated. Cumulative test count holds 1457+ baseline. |
| S14-M5 | **HD-2D visual polish pass — tilt-shift depth-of-field OR warm-lantern overlay** (per Art Bible Visual Identity Anchor + design/gdd/audio-system.md OQ-AS-7 adjacency) — pick one of the two and ship a single shader pass. Tilt-shift is the riskier (per-camera depth math) but more visually distinctive; warm-lantern is the simpler (color-grade overlay) but pairs with the parchment theme. | godot-shader-specialist + technical-artist | 1.5d | none | Single shader landed at `assets/shaders/<name>.gdshader`; applied via SubViewport composition (godot 4.6 Forward+ pipeline). Manual screenshot evidence: before/after on guild_hall + dungeon_run_view + return_to_app screens. Performance budget: 60fps on Steam Deck native (1280×800), per `.claude/docs/technical-preferences.md`. |

**Sprint 14 Must Have total**: ~6.0d (S14-M1 sourcing branch decides) + 0.5d M2 + 2.0d M3 + 1.5d M4 + 1.5d M5 = 5.5d minimum (silent audio branch) or 6.0d (sourcing branch). Both fit within 7.2d available.

### Should Have

| Story ID | Task | Owners | Estimate | Dep |
|---|---|---|---|---|
| S14-S1 | **Manual re-playtest with persisted save** (S12-S1 + S13 carry-forward) — needs human play session | producer + qa-tester | 0.5d | M3 done |
| S14-S2 | **Sprint 13 retrospective** (continuing the Sprint 10/11/12 pattern) | producer + claude-code | 0.25d | sprint window closed |
| S14-S3 | **Onboarding / First-Session Flow** — implementation per GDD #29 (drafted in this session by autonomous push; pending /design-review). Adds STARTING_GOLD constant + integration test simulating cold-launch + manual smoke checklist. ~1.0d. | gameplay-programmer + ux-designer | 1.0d | GDD #29 /design-review APPROVED |
| S14-S4 | **Recruit Screen UI** (S13-N4 carry-forward; recruitment-system.md §J Story 7) | ui-programmer + ux-designer | 0.75d | UX pass for recruit-card layout |
| S14-S5 | **Guild Hall Screen full implementation** per Guild Hall GDD #19 (drafted in this session — current Sprint 8 S8-M4 stub is just the DispatchNavButton). Header bar + roster panel + recruit nav button gating + settings gear icon integration. 6 stories totaling ~3.0d per GDD §J. | ui-programmer + ux-designer | 3.0d | Guild Hall GDD #19 /design-review APPROVED; Settings GDD #30 review APPROVED (gear opens Settings overlay); replay_in_flight_changed signal landed (commit `54cd394`) ✓ |

### Nice to Have

| Story ID | Task | Owners | Estimate | Dep |
|---|---|---|---|---|
| S14-N1 | **AudioRouter `_test_play_*_log` debug-spy ADR** — codify the convention if S14-M3 Settings UI uses the same pattern (would make AudioRouter the 2nd consumer; ADR threshold met). | godot-gdscript-specialist | 0.25d | M3 in progress |
| S14-N2 | **Re-dispatch shortcut on main_menu** (S10-N2 carry-forward — 4-sprint deferred) — track last formation + bypass button + show/hide logic | ui-programmer | 0.5–0.75d | none |
| S14-N3 | **Audio bus volume sliders polished** (S13-N3 carry-forward) — pair with M3; if M3 lands the sliders cleanly, this is absorbed and N3 becomes a no-op. | ui-programmer | 0.0–0.25d | M3 done |

## Sprint 14 sequencing recommendation

- **Day 1 morning**: S14-M1 audio sourcing decision (gating). If commission timeline > 9 days, lock silent path; if AI-generated under license, do the sourcing in parallel with M3.
- **Day 1 afternoon**: S14-M2 `/design-review` on Settings GDD #30. Apply revisions same day if BLOCKING surface is < 5 items; otherwise carry to Day 2.
- **Day 2-4**: S14-M3 Settings overlay implementation. Follow the 5-story sequence in Settings GDD §J.
- **Day 4-5**: S14-M4 Hero Leveling GDD authoring + XP-curve implementation. Replace stub.
- **Day 5-7**: S14-M5 HD-2D shader pass.
- **Day 7+**: cherry-pick Should Haves — S14-S1 playtest (after M3 lands so volume + reduce_motion are testable), S14-S2 retro, S14-S3 onboarding GDD, S14-S4 RecruitScreen.

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **S14-M1 sourcing decision deadline-blocks M3 + N1** — if commission turnaround > 9 days, M3 ships with silent audio; the Settings volume sliders work mechanically but are sliders-with-no-audible-effect on the dev machine. Player can still hear the DIFFERENCE via mute toggle. | MEDIUM | LOW | Make decision binary on Day 1; silent fallback is a clean path that doesn't block M3. |
| **S14-M2 design-review surfaces > 10 BLOCKING items on Settings GDD** — the Pass-1 draft was authored autonomously without /design-review gate; substantial revision possible. | MEDIUM | MEDIUM | Time-box revision at 1.0d. If > 1.0d converges, defer M3 implementation to Sprint 15 — keep the sprint goal achievable on the other 3 Must Haves. |
| **S14-M4 Hero Leveling GDD is multi-system** — touches Hero Roster + Economy + Orchestrator + Combat (XP-on-kill is the canonical earn). Cross-GDD review may reveal contract drift. | MEDIUM | MEDIUM | Run `/review-all-gdds` after the hero-leveling.md draft lands to catch cross-system inconsistencies same-day. |
| **S14-M5 HD-2D shader pass on Steam Deck performance budget is unverified** — Forward+ pipeline + per-pixel post-effect at 1280×800 60fps is not guaranteed without profiling. | HIGH | MEDIUM | Profile early; if frame-time spikes > 16ms on Steam Deck native, drop to a cheaper effect (e.g., simpler color grade) and document the deferral. |
| **No pre-emptive buffer means Day 5+ slippage is real** — Sprints 11-13 averaged 0.5-0.6× plan estimate via autonomous Day-0 pushes. Sprint 14 has none of that buffer. | HIGH | MEDIUM | Hold strict 1.0× plan estimates. Defer aggressively if any Must Have hits >1.5× its estimate. Sprint 15 backlog absorbs slippage. |
| **The Sprint 14 plan is a Day-0 autonomous draft, not a /sprint-plan output** — re-validation via `/sprint-plan` may surface scope mismatches with the project state. | MEDIUM | LOW | Run `/sprint-plan` on Day 0 to verify; treat this groundwork as a starting point, not a locked plan. |

## Dependencies on External Factors

- **Audio sourcing budget / vendor availability** — gates S14-M1 non-silent path. Out of engineering scope.
- **Steam Deck profiling hardware** — gates S14-M5 performance-budget verification. Without real hardware, fall back to dev-machine profiling at the same resolution.
- **UX design pass for Settings overlay** — gates S14-M3 implementation polish (the GDD specifies layout but not visual polish).
- **`/design-review` skill availability + project lead time** — gates S14-M2.

## Definition of Done for Sprint 14

- [ ] All 5 Must Have tasks (S14-M1 through S14-M5) closed via `/story-done` with COMPLETE or COMPLETE WITH NOTES verdict
- [ ] Full unit + integration sweep ≥1500 tests, 0 failures, 0 errors
- [ ] Audio sourcing decision is documented (ADR) — silent OR non-silent, no ambiguity
- [ ] Settings overlay live in Guild Hall via gear icon; manual smoke confirms volume/mute/reduce_motion round-trip
- [ ] Hero Leveling GDD #15 status flips from "Not Started" to "Authored" or "APPROVED" in systems-index.md
- [ ] HD-2D shader pass live on at least one screen; before/after screenshots committed
- [ ] Sprint 14 retrospective committed at `production/retrospectives/sprint-14-retrospective-<date>.md`

## Sprint 15+ candidates (post-Sprint-14)

- HD-2D shader pass, second effect (whichever wasn't picked in M5)
- M3 schema migration when first save-version bump occurs (currently V1.0)
- ADR-X04 Recruitment determinism extension if MVP playtest reveals issues with the deterministic-pool UX
- Class Synergy System #32 (V1.0 stub → MVP if playtest demands it)
- Prestige System #31 (V1.0 stub)
- VFX System #27 (currently "Not Started")
- Localization rollout (TR strings + 1 non-English locale to validate the i18n pipeline)
- Sprint 13 deferred items not absorbed by Sprint 14 (S13-N1 ADR if not landed)

## Notes

- Authored 2026-05-06 by post-Sprint-13 close-out work (autonomous-execution session — same session that closed Sprint 12 + Sprint 13 plus drafted Settings GDD #30 + Story 013 spec/impl + tests/PATTERNS.md). Re-validate via `/sprint-plan` if anything material changes between now and Sprint 14 kickoff (2026-06-19).
- The Sprint 14 nominal date range follows the same 9-working-day cadence as Sprints 10-13.
- **Sprint 14 is the first sprint without pre-emptive buffer.** Sprint 12+13 retros warn: do not expect the Day-0 absorption pattern to repeat. Plan for actual day-by-day execution.
- After Sprint 14, MVP polish bar should be substantially closer to ship: cozy audio (or documented silent), full Settings, real XP, first HD-2D shader pass. Remaining Sprint 15+ work is content authoring + V1.0 stub elaboration + localization rollout.
