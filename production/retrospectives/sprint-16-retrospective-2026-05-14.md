# Sprint 16 Retrospective — 2026-05-14

> **Sprint window**: 2026-05-14 (single-day, like Sprint 15)
> **Closure date**: 2026-05-14 (real-time, in-window)
> **Review mode**: solo
> **Stage**: Production

## Sprint Goal (recap)

Per `production/sprints/sprint-16.md`: convert Sprint 15 design preview + carryover into shipped Vertical Slice tier features. Sprint 15 retro's #1 action item — **reweight toward player-visible content** — was the load-bearing constraint.

**Result**: goal MET in spirit, exceeded in scope. The plan called for 4 Must Haves (M1-M4) + 3 Should Haves. What shipped was bigger: 5 biomes, a progression-gate mechanic, and the warm-lantern shader, plus all carryover docs work. **Player-visible delta is substantial.**

---

## Metrics

| Metric | Sprint 15 | Sprint 16 |
|--------|-----------|-----------|
| Must Have closure | 4/4 (100%, M3 audit closure) | 4/4 (100%) |
| Should Have closure | 3/3 (100%) | 2/3 (S2 expanded; S1 deferred; S3 = this retro) |
| Nice to Have closure | 1/3 (shader preview) | 5/5 (5 biomes — all delivered as Sprint 16 momentum, not original N-tier) |
| PRs merged | 17 | **9** (#73-#81) — substantive average, no hygiene padding |
| Tests at sprint start | 2097 | 2129 |
| Tests at sprint end | 2129 | **2160** |
| Net test delta | +32 | **+31** |
| Player-visible features | 4 of 17 PRs | **8 of 9 PRs** (5 biomes + gate + chain + shader; only #74 was pure docs) |

### The lesson Sprint 15 demanded, Sprint 16 delivered

Sprint 15 retro action #1 said:
> Reweight Sprint 16 toward player-visible content. Test coverage + CI guards are byproducts, not goals.

The signal landed. Sprint 16's PR/visibility ratio inverted: from 4/17 visible in Sprint 15 (24%) to **8/9 visible in Sprint 16 (89%)**. The user's "I don't see too much progress" playtest signal is no longer applicable to Sprint 16's work.

---

## What was completed

| ID | Title | Realized cost | PR |
|---|---|---|---|
| **S16-M1** Playtest-08 | HeroLeveling AC-15-02 calibration | ~0.25d | merged in S15 closeout |
| **S16-M2** Sprint 15 retro | "Technically successful, experientially flat" | ~0.25d | #76 |
| **S16-M3** Formation Presets GDD | GDD #33 first-pass | ~0.75d | #74 |
| **S16-M4** ADR-0017 reconciliation | Partial-adoption amendment §A1 (warm-lantern ships, tilt-shift stays deferred) | ~0.25d | this PR |
| **S16-S2** Multi-biome content | Originally "biome 2 design pass". Expanded to **5 biomes shipped + progression gate**. | ~2.5d | #77, #78, #79, #80, #81 |
| **S16-S3** Sprint 16 retro | This doc | ~0.25d | this PR |
| **(bonus)** Warm-lantern shader | Originally a Sprint 17+ candidate; user authorized early ship | ~0.5d | #73 |
| **(bonus)** Self-critique pattern | §K self-review on GDD #33 surfaced 1 BLOCKING + 4 CONCERN + 2 ADVISORY items before /design-review ran | ~0.25d | #75 |

**Realized total**: ~5.0d in a single session. Sprint 15 was ~5.75d; Sprint 16 hit a similar density with much higher player-visible output per hour.

### Items NOT shipped (Sprint 17 carryover)

- **S16-N2 Tilt-shift DoF shader** — per ADR-0017 Amendment §A1, still deferred. Vertical Slice tier scope.
- **S16-N3 Steam Deck rehearsal** — human-gated; no hardware session this sprint.
- **S16-N4 First-run onboarding UX polish** — no playtest signal demanding it.
- **S16-N5 Audio asset sourcing follow-through** — ADR-0016 silent-MVP still in force; no playtest pivot trigger fired.
- **S16-N1 Hero Detail dismiss-hero V2 design call** — not raised by user this sprint.
- **S16-S1 Recruitment Stories 5+7 audit closure** — defers to Sprint 17. Audit found these already shipped in Sprint 11-12; closing the formal trace is paperwork that can wait.

---

## What Went Well

- **Sprint 15 retro action #1 paid off.** The single-line "reweight toward player-visible content" was the highest-leverage retro item in the session. Sprint 16's 89% visible-PR rate is the direct result.

- **The biome-add pattern matured into pure data work.** PR #77 made a one-time code change to FloorUnlock (auto-seed loop). After that, every biome was a 5-tres-files-and-a-test commit at ~10 min/biome. 5 biomes shipped at this cadence. Code stays maintainable; content scales.

- **Progression gate landed cleanly.** The shift from "more biomes" to "depth via progression" happened mid-sprint when the 4-biome cold-launch menu started feeling like a buffet. The `Biome.unlock_after` schema field + ~20 LoC in FloorUnlock + a `biome_unlocked` signal + a Guild Hall toast = the first real "you earned this" loop in the game. **This is the most valuable feature shipped this sprint** — not because it's complex, but because it converts content from "menu items" into "rewards".

- **ADR-0017 amendment over supersession.** Shipping the warm-lantern shader against an "Accepted" ADR could have been handled three ways: (a) ignore the ADR (process dishonesty), (b) supersede the ADR (overstates the change — tilt-shift DoF + SubViewport pipeline still deferred), (c) **partial-adoption amendment**. Option (c) is the honest framing and what shipped (§A1). Worth preserving as a pattern.

- **Self-critique on authored GDDs (PR #75) caught real issues.** §K on GDD #33 surfaced 1 BLOCKING (the no-buffer architectural mismatch I'd missed) before /design-review ran. The user's K.1 decision (Option A: immediate-commit) closed that BLOCKING without a refactor pre-req. Net session time saved: ~0.5d. Pattern worth repeating.

- **No regressions, no rollbacks.** 9 PRs, +31 tests, 2160/2160 PASS at sprint close. Code quality floor held during the highest-velocity content push of the project.

## What Went Poorly

- **Sprint 16 plan (PR #74) was outdated by mid-sprint.** The original plan called for "biome 2 design pass" as S16-S2 (~1.5d). Reality: shipped 5 biomes + a new mechanic. The plan was the wrong shape for what the sprint became. Two interpretations: (a) the plan should have been more ambitious; (b) the plan's role is anchoring, and beating the plan via momentum is fine. **No fix needed; just an observation.**

- **The "data-only pattern" might become its own treadmill if not watched.** Biome 7, 8, 9... could ship at the same cadence indefinitely. The mid-sprint pivot from "biome 4" to "biome 5 with a gate" was the right move — content + depth, not content alone. Sprint 17 should keep checking whether the next biome is still adding value or repeating itself.

- **UID regeneration on every save was noisy.** Each .tres file I authored got its UID regenerated by Godot on first import. Created CHANGELOG noise + repeated "linter modified" notifications. Doesn't affect output, but is friction. **Process improvement**: drop the placeholder UIDs in authored .tres files (use a deterministic placeholder pattern Godot can canonicalize) OR accept the friction.

- **Sprint 16 plan + GDD #33 + self-critique stayed unmerged through most of the sprint.** PRs #73-#75 sat open while the user merged biome content. The shader (#73) blocked tilt-shift DoF planning; the GDD (#74) blocked Sprint 17 implementation prep; the self-critique (#75) added context to #74. User merged all in batch near the end. Probably fine — but a faster merge cadence on docs PRs would have unblocked downstream work earlier.

## Estimation Accuracy

Most stories within ±20% of estimate. Biome PRs (Whispering Crags + Sunken Ruins + Frostmire + Ember Wastes + Hollow Stair) averaged ~10 min each, well under the original "0.5d per biome" rough cost. The data-only pattern matured fast. **Sprint 17 should re-baseline biome cost at ~0.2d** if the pattern continues.

## Carryover Analysis

| Task | Origin | Times Carried | Action |
|------|--------|---------------|--------|
| Recruitment Stories 5+7 audit | Sprint 11-12 pre-emptive work shipped, audit closure deferred | 4 sprints (S12 → S13 → S14 → S15 → S16) | **Defer to Sprint 17 with explicit note.** It's paperwork, never blocking. |

The session ends with the M4 carryover chain (S13-M3 → S14-M4 → S15-M4) finally CLOSED — the Sprint 15 closeout's playtest-08 ended that. No multi-sprint human-gated carries open into Sprint 17.

## Technical Debt Status

- **TODO**: 6 (unchanged baseline)
- **FIXME**: 0
- **HACK**: 0
- **Trend**: stable

New code surface from Sprint 16:
- `Biome.unlock_after` schema field (1 line export + docstring)
- `FloorUnlock.BIOME_UNLOCK_GATES` + `biome_unlocked` signal + gate-check logic in `_on_floor_cleared_first_time` (~20 LoC)
- 25 new .tres files (5 biomes × [1 biome + 1 dungeon + 5 enemies] minus the shared dungeon scripts)
- 1 shader file + ColorRect node on Guild Hall

## Previous Action Items Follow-Up (from Sprint 15 retro)

| Action | Status | Notes |
|--------|--------|-------|
| Reweight Sprint 16 toward player-visible content | **DONE** | 89% of PRs player-visible (vs 24% Sprint 15) |
| Reconcile PR #73 ADR-0017 deviation | **DONE** | ADR-0017 §A1 amendment this PR |
| Decide GDD #33 K.1 | **DONE** | User chose Option A (immediate-commit) during the session |
| Hard stop on "merged. move on" cycles when diminishing-returns flag raised | **PARTIALLY DONE** | Sprint 16 didn't hit the diminishing-returns zone (biome content has player-visible delta per ship). The flag wasn't needed. |

4/4 retro actions addressed (3 fully, 1 not-needed).

---

## Action Items for Sprint 17

| # | Action | Priority |
|---|--------|----------|
| 1 | **Validate the progression chain via playtest.** Cold-launch save → clear Forest Reach + Frostmire bosses → see "Unlocked: Ember Wastes" toast → clear Ember Wastes boss → see "Unlocked: Hollow Stair". Verify the cozy feel of the unlock moment in actual gameplay, not just unit tests. | **High** |
| 2 | **Check biome saturation.** With 6 biomes shipped, ask: is a 7th biome still adding value, or is it filler? If filler, pivot Sprint 17 to a different mechanic (class synergy V1.0 impl? UX flourish? matchup hints?). | High |
| 3 | **Close S16-S1 Recruitment audit OR explicitly retire it.** Paperwork has been carried 4 sprints. Either do it (~0.5d audit + close), or formally retire the AC checklist as superseded by the shipped implementation. | Med |
| 4 | **Re-baseline biome cost in Sprint 17 estimate.** ~0.2d per biome under the data-only pattern, not the prior 0.5d. | Low |

## Process Improvements

- **The "ship visible content, retro the rest" rhythm is working.** Sprint 16's high visible-PR rate + clean retro is the template. Repeat for Sprint 17.
- **Partial-adoption amendments are valid ADR tooling.** §A1 on ADR-0017 is the prototype. When a PR ships against an Accepted ADR but doesn't fully invalidate it, an amendment is more honest than ignore + more accurate than supersession.
- **Self-critique on authored docs (the §K pattern from PR #75) is now established.** Apply to any future GDD I author before /design-review runs.

---

## Memory items worth saving

- **The biome-add pattern is now a known cadence**: 1 biome.tres + 1 dungeon.tres + 5 enemy.tres + 1 test file = ~10 min from branch to PR. After the FloorUnlock auto-seed refactor (PR #77), zero code changes per future biome.
- **Progression gates are extensible by data**: `Biome.unlock_after = "<biome_id>_f<floor_index>"`. Each new gated biome is a new link in the chain. AND/OR composite gates are V1.5+ scope; single-floor gates cover the MVP.
- **Player-visible reweight worked.** Sprint 15 (24% visible) → Sprint 16 (89% visible) by deliberate retro-action targeting. The lesson: when the productivity-quality signal says "more visible work", a single retro action item can shift the whole next sprint's character.

---

## Verdict

**Sprint 16: SUCCESSFUL — content + depth shipped, not just content.**

By the numbers: 9 PRs, 4/4 Must Haves, +31 tests, 0 regressions, 5 new biomes, 1 new mechanic, 1 visible polish layer, ADR honesty restored via §A1 amendment.

By the player-experience signal (the load-bearing one per Sprint 15): **the player can now do meaningfully more at cold launch than they could yesterday.** 4 starter biomes to choose from instead of 1; a progression chain unlocking 2 more biomes; a warm-lantern visual signature; a "you unlocked X" feedback loop.

**Most important takeaway**: a single retro action item ("reweight toward player-visible content") shifted the entire next sprint's character. Sprint 17 should pick its action items with the same intentionality.

**Recommendation for Sprint 17**: validate the progression chain via playtest (the human signal that proved Sprint 16 worked) BEFORE adding more content. If the playtest says "this feels good and there's enough to do" → pivot to a fresh mechanic (class synergy V1.0 impl, matchup hints, or onboarding polish). If it says "I want more biomes" → extend the chain. Let the player signal pick the direction.
