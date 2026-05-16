# Sprint 24 — 2026-06-12 to 2026-06-25

> **Status: Day-0 plan authored 2026-05-16**, same-day close of Sprint 23.
> Eleventh consecutive same-day-compressed sprint (Sprint 14→15→16→17→18→19→20→21→22→23→24).
> Solo review mode.

## Sprint Goal

**Land the Class Synergy V2 tier ladder design + tier-aware preview label, ship UIFramework hygiene helpers consolidating Sprint 23's deferred duplication, author the Onboarding First-Session GDD, and clear the S23-S1 advisory polish that was deferred when playtest-14 passed.**

Sprint 23 closed cleanly with all 6 implementable stories shipped and playtest-15 PASS, but it deferred three pieces of work that should not slip further:
- **Class Synergy V2 tier ladder** — S23-N2 shipped the always-visible preview label but used V1 synergy names because the V2 tier design hadn't been authored. Sprint 24 closes this design loop and refreshes the label.
- **UIFramework helpers** — the post-`/simplify+/review` pass identified two duplications (clear-children pattern across 6+ sites; synergy display-name across 3 sites) that were deferred as advisory polish.
- **S23-S1 M4 clarity polish** — playtest-14 graded items c/d/e PASS, so S23-S1 dropped to advisory polish. Carrying as Sprint 24 Should Have so it actually lands instead of perpetually deferring.

**Definition of Sprint 24 success**:
(a) `class-synergy-system.md` extended with §V2 Tier Ladder mapping V1 synergies → None/Bronze/Silver/Gold/Platinum tiers; locale keys for tier display names;
(b) `SynergyPreviewLabel` on Dispatch screen renders tier names (Bronze/Silver/Gold/Platinum) per the new GDD, with tests refreshed;
(c) `UIFramework.clear_children_immediate(container)` + `UIFramework.synergy_display_name(synergy_id)` helpers shipped; 6+ pre-existing call sites of the clear-children pattern + 3 call sites of the synergy display-name pattern refactored to use the helpers;
(d) M4 clarity polish landed — empty-state copy/icon hint on screens with empty collections, tap-target audit confirming ≥44×44 logical px, Primary Button pattern applied to all primary CTAs;
(e) `design/gdd/onboarding-first-session.md` authored (8-section GDD; implementation deferred to Sprint 25+);
(f) `tests/helpers/hero_roster_test_fixture.gd` shipped; ~5 sites of repeated HeroRoster test setup refactored;
(g) Visual playtest validates the tier label changes + M4 clarity polish; retro committed.

## Capacity

- Total days: 10 (~2 weeks at 5 days/week, solo)
- Buffer (20%): 2.0 days reserved for unplanned work
- Available: **8.0 days**

**Calibration note**: Sprint 24 must-haves total 2.0d (matching Sprint 23 — light cadence). Must + Should = 5.0d, leaving 3.0d headroom for Nice to Haves. The light cadence is intentional: Sprint 23 surfaced the stacked-PR pitfall (lost 6 PRs to GitHub's stacked-merge semantics) — Sprint 24 process rules need to land cleanly without merge-cascade chaos.

## Pre-Plan Disposition (handle BEFORE Sprint 24 M1 starts)

| PR / Gate | Status | Action |
|-----------|--------|--------|
| **All Sprint 23 PRs** (#132–#139) | MERGED — playtest-14 + playtest-15 both PASS | None — Sprint 23 fully closed |
| **sprint-23 remote branches** | DELETED (manual cleanup 2026-05-16) | None |
| **Local stale branches** | DELETED (sprint-23/recovery-m2-through-m3, sprint-24/day-zero-plan-original) | None |

No pre-plan dispositions for Sprint 24 — clean slate.

## Tasks

### Must Have (Critical Path)

| ID | Task | Owner | Est. | Dependencies | Acceptance Criteria |
|----|------|-------|------|--------------|-------------------|
| S24-M1 | **Class Synergy V2 tier ladder GDD.** Amend `design/gdd/class-synergy-system.md` with a new `§V2 Tier Ladder` section: tier definitions (None/Bronze/Silver/Gold/Platinum), mapping from V1 synergy detection results to tier names, color/iconography hints for UI render (deferred to a future tier-aware polish sprint). 5 locale keys for tier display names (`synergy_tier_none`, `synergy_tier_bronze`, `synergy_tier_silver`, `synergy_tier_gold`, `synergy_tier_platinum`). | game-designer | 0.5d | none | `class-synergy-system.md §V2` exists with tier mapping table; 5 new locale keys in `en.csv`; cross-reference table updated in `class-synergy-system.md §F`; passes `/design-review` mental-pass (no `/design-review` invocation required for amendments of existing GDDs) |
| S24-M2 | **Tier-aware SynergyPreviewLabel refresh.** Update `formation_assignment.gd::_refresh_synergy_preview_label` to look up the tier name (Bronze/Silver/Gold/Platinum) per S24-M1 instead of rendering the V1 synergy display name directly. Format: `"Synergy: {tier_name} ({synergy_display_name})"` — both readouts visible (tier as the categorical, name as the specific). Empty composition still renders `"Synergy: None"`. Tests in `tests/unit/formation_assignment/synergy_preview_label_test.gd` updated to assert tier names. | godot-gdscript-specialist | 0.5d | S24-M1 | Preview label shows tier + name; 3 existing tests in synergy_preview_label_test.gd updated; 1+ new test asserting tier rendering for each MVP synergy → tier mapping; full suite green |
| S24-M3 | **UIFramework hygiene helpers.** `UIFramework.clear_children_immediate(container: Node)` consolidates the 6+ site duplication of "for child in get_children(): remove_child + queue_free". `UIFramework.synergy_display_name(synergy_id: String) -> String` consolidates the 3 sites of `tr("class_synergy_badge_" + synergy_id)` plus empty-check. Refactor: `guild_hall.gd::_clear_container_immediate` (delete; replace with helper); `formation_assignment.gd::_refresh_synergy_badge` + `_refresh_synergy_preview_label`; `guild_hall.gd::_on_prestige_completed` (which builds the display name inline). Tests added for the new helpers. | godot-gdscript-specialist | 0.5d | S24-M2 (synergy_display_name will be used by M2's label refresh) | Both helpers exist with doc comments; all call sites refactored; helper-specific tests in `tests/unit/ui_framework/ui_framework_helpers_test.gd`; full suite green; cumulative test count maintained |
| S24-M4 | **Sprint 24 visual playtest + retro.** Use `production/playtests/_template-visual-playtest.md`. Grade tier label render (M2), helper-refactored call sites still work (M3), clarity polish reads improved (S1). Retro doc + sprint-status.yaml closed. | xiaolei (human) + claude-code | 0.5d | M1 + M2 + M3 + S1 | playtest-16 committed with per-check verdict; sprint-24 retro committed; sprint-status.yaml all Must Haves marked done |

**Must Have total**: 2.0 days

### Should Have

| ID | Task | Owner | Est. | Dependencies | Notes |
|----|------|-------|------|--------------|-------|
| S24-S1 | **S23-S1 carryforward — M4 clarity polish.** Empty-state copy + icon hint on screens with empty collections (Guild Hall roster empty, Recruit pool exhausted, Dispatch slots empty); tap-target audit at mobile-equivalent resolution (≥44×44 logical px per DESIGN.md); every primary CTA uses Primary Button pattern (pattern #1 in interaction-patterns.md). | godot-gdscript-specialist | 1.0d | none | All 7 screens have descriptive empty states; primary CTAs use Primary Button pattern; tap-target audit passed; no unthemed Button nodes on primary actions |
| S24-S2 | **Onboarding First-Session GDD authoring.** Author `design/gdd/onboarding-first-session.md` per 8-section GDD template. First-time player sees Tutorial context (not bare Guild Hall). Define: trigger conditions (fresh save), step sequence (welcome → meet your guild → first dispatch → first run → return), skip conditions, save-flag persistence, dismissal grace. Implementation deferred to Sprint 25+. | game-designer | 1.0d | none | `onboarding-first-session.md` 8-section GDD; entry in `systems-index.md`; locale-key sketch (no implementation keys); cross-ref to `guild-hall-screen.md` §F |
| S24-S3 | **Test fixture helper for HeroRoster.** `tests/helpers/hero_roster_test_fixture.gd` with `reset_hero_roster()` (clears _heroes, _prestige_count, _prestige_multiplier, _retired_hero_records), `seed_warriors(n) -> Array[int]`, `snapshot_via_save_data() -> Dictionary`, `restore_via_load_save_data(snapshot)`. Refactor ~5 sites of duplicated test setup: `tests/unit/guild_hall/retired_tab_render_test.gd`, `tests/unit/formation_assignment/synergy_preview_label_test.gd`, `tests/integration/guild_hall/roster_panel_test.gd`, `tests/unit/formation_assignment/synergy_badge_test.gd`. | godot-gdscript-specialist | 0.5d | none | Helper file exists with doc comments; ≥3 test files refactored to use it; full suite green; no test count regression |

**Should Have total**: 2.5 days

### Nice to Have

| ID | Task | Owner | Est. | Notes |
|----|------|-------|------|-------|
| S24-N1 | **ClassPortraitFactory `fill_rect` optimization.** Replace nested `set_pixel` loops in `_build_portrait` with `Image.fill_rect(Rect2i, color)` for border (4 strip fills) + retain the diamond glyph as set_pixel (small mask, ~3k pixels). Cuts ~9k set_pixel calls per first-paint per class. Cache amortizes the cost in production, but the optimization makes intent clearer. | godot-gdscript-specialist | 0.5d | none |
| S24-N2 | **Floor Unlock System GDD authoring.** Author `design/gdd/floor-unlock-system.md` per 8-section GDD template. Progression gating prerequisite for late-game pacing: which floors unlock when (cleared-floor count, biome unlock dependencies), how the unlock UX surfaces to the player (no FOMO timers per cozy-register rule), save schema additions. Implementation deferred to Sprint 26+. | game-designer | 1.0d | none |
| S24-N3 | **Real product art ingestion (if art workstream lands an ETA).** When real PNG portraits / sprite art arrives, swap-in is non-blocking thanks to S23-S3's `HeroClass.portrait_path` consumer pattern. ClassPortraitFactory becomes the explicit fallback. No implementation work yet — this is a placeholder for "if art lands during sprint, ingest it here". | claude-code + asset-pipeline | 0.5d | art workstream ETA |

**Nice to Have total**: 2.0 days (1.0d if N3 dropped pending art)

## Carryover from Previous Sprint

| Task | Reason | New Estimate |
|------|--------|-------------|
| S23-S1 M4 clarity polish | playtest-14 graded c/d/e PASS — dropped to advisory polish from Sprint 23 Must Have | 1.0d → **S24-S1** |
| S23 review-cleanup deferrals (clear_children_immediate, synergy_display_name) | Sprint 23 `/simplify+/review` flagged as advisory polish; ship in Sprint 24 hygiene work | 0.5d → **S24-M3** |
| Class Synergy V2 tier ladder (deferred from S23-N2) | V2 design didn't exist when S23-N2 shipped; preview label used V1 names | 1.0d → **S24-M1 + S24-M2** (split into design + implementation) |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| **Stacked-PR pitfall repeats** (Sprint 23 lost 6 PRs to GitHub's stacked-merge semantics; cleaned up via recovery PR #139) | LOW | HIGH | **Process rule for Sprint 24: per-task PR with `base=main` ALWAYS.** No `--base sprint-24/<prior-task>` stacking. Each PR shows cumulative diff vs main; that's fine for ~50-line tasks. Sequential merge order preserved by the user clicking merge in numerical PR order. |
| **S24-M1 tier mapping is contentious** (None/Bronze/Silver/Gold/Platinum doesn't have a canonical mapping in the V1 synergy roster) | MED | MED | Anchor the mapping to existing V1 synergy strength: 3-of-a-kind = Gold (Steel Wall, Arcane Elite, Triple Strike); 2-of-a-kind with matching counter = Silver (theoretical); 2-of-a-kind without counter = Bronze (theoretical); 1-of-a-kind = None (no synergy). Acknowledge in §V2 GDD that the Silver/Bronze tiers don't have V1 implementations yet — they're documented for V2.5+ expansion. |
| **Onboarding GDD scope balloons into implementation** | MED | LOW | S24-S2 is design-only (no .gd / .tscn files). If first-session implementation feels easy after the GDD lands, that's Sprint 25 work — defer the temptation. |
| **M4 clarity polish (S24-S1) lacks specificity for "empty state on every screen"** | LOW | LOW | Scope locked to the 3 named screens (Guild Hall, Recruit, Dispatch). If playtest-16 surfaces empty-state gaps elsewhere, that's Sprint 25 work. |
| **Test fixture refactor (S24-S3) introduces subtle test isolation regressions** | LOW | MED | Refactor each test file individually; run the affected file after each refactor; commit each refactor separately so bisecting is cheap. |

## Dependencies on External Factors

- **No external dependencies for Must Have or Should Have.** Sprint 24 is fully autonomous-doable through M3.
- **N3 (real product art ingestion) depends on the art workstream**. If art doesn't land an ETA during the sprint window, N3 silently drops to Sprint 25 backlog.
- **M4 playtest is the only human-gated step** — same pattern as every prior sprint.

## Definition of Done for this Sprint

- [ ] Class Synergy V2 tier ladder §V2 amended into `class-synergy-system.md` (M1)
- [ ] `SynergyPreviewLabel` on Dispatch renders tier names per the new GDD (M2)
- [ ] `UIFramework.clear_children_immediate` + `synergy_display_name` helpers shipped + call sites refactored (M3)
- [ ] M4 clarity polish landed — empty states, tap targets, Primary Buttons (S1)
- [ ] `onboarding-first-session.md` 8-section GDD authored (S2)
- [ ] `tests/helpers/hero_roster_test_fixture.gd` shipped + ≥3 test files refactored (S3)
- [ ] Visual playtest PASS on tier label + clarity polish (M4)
- [ ] Sprint 24 retro committed; sprint-status.yaml all Must Haves marked done
- [ ] No S1 or S2 bugs; existing tests stay green; full suite re-run at M4 close
- [ ] Cumulative test count maintained or increased; 0 regressions
- [ ] **Sprint 24 PR-merge protocol followed**: every PR has `base=main`, merged sequentially. NO stacked PRs.

## Sprint 24 Process Rules (new this sprint)

1. **One PR per task, `base=main` always.** No stacked PRs. The Sprint 23 stacked-PR cascade lost 6 PRs to GitHub's merge semantics and required a recovery PR (#139) to clean up. Each Sprint 24 PR shows its cumulative-vs-main diff, which is fine for tasks under ~150 lines.

2. **Merge in numerical PR order.** PRs are still authored sequentially (M1 → M2 → M3 → S1 → S2 → S3 → N1 → N2 → M4 closure). The user clicks merge in that order. Each merge brings main forward; subsequent PR diffs auto-recompute vs the updated main.

3. **Honest dependency status check** (per Sprint 10 retro discipline carried forward): before starting any "wiring" task (M2, M3, S3 here), grep the codebase to verify dependencies are actually implemented, not just `Status: Ready`. Story files marked Ready don't guarantee prior deliverables shipped.

4. **Playtest gates are load-bearing**. 100% tests passing ≠ "shipped". M4 requires human playtest before declaring sprint goal MET.

5. **Defer over over-deliver** when scope is unclear. S24-S2 (Onboarding GDD) is design-only — resist the temptation to scaffold the first-session screen. That's Sprint 25 work.

## After Sprint 24

Sprint 25 candidates from the planning context:
- **Onboarding First-Session implementation** (S24-S2 GDD → screens + flow)
- **Class Synergy V2 tier coloring + iconography** (S24-M1 design hints → visual polish)
- **Floor Unlock System implementation** (S24-N2 GDD → progression gating)
- **Real product art ingestion** (S24-N3 carry if art workstream lands)
- **HD-2D polish pass** (S19-S21 carryover if Sprint 24 frees capacity)
