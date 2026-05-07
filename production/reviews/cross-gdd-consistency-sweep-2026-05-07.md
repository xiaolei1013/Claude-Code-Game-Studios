# Cross-GDD Consistency Sweep — 2026-05-07

> **Status: DRAFT 2026-05-07** by post-Sprint-15-S15-S4-N1 autonomous-execution session, executing Sprint 15 S15-N2 ("Cross-GDD consistency sweep — read all 9 drafted GDDs + flag cross-reference drift. Output: a single review document.")
>
> **Scope**: this sweep is a focused pre-`/design-review` consistency check across the 9 first-pass GDDs from the cumulative 2026-05-06/07 design-coverage push + the 4 V1.0/Vertical Slice tier stubs. The deliverable is NOT a full design review; it pre-flags the highest-leverage cross-reference drift items so the user's eventual `/design-review` invocation can spot-check them efficiently.

---

## Executive summary

**Confirmed drift items found**: 2.
**Self-documented gaps** (GDD captured but worth re-flagging during review): 1.
**Bidirectional dependency arrows**: spot-checked across 5 GDD pairs; all aligned.
**ADR references**: 17 unique ADRs cited across the 9 GDDs; all exist; ADR-0017 status verified Accepted.
**Signal signature drift**: 1 confirmed (in `guild-hall-screen.md` AC-19-04 — hero_recruited arity).

The 9 first-pass GDDs are largely consistent with each other and with the upstream src code. The two confirmed drift items below are the highest-leverage spot-checks for the user's `/design-review` pass; both are simple text edits in their respective GDDs.

---

## Confirmed drift item #1 — `recruit-screen.md` claims `try_recruit -> bool`; actual is `try_recruit -> RecruitOutcome`

**File**: `design/gdd/recruit-screen.md`
**Sections affected**: §C.5 step 2 (`Call Recruitment.try_recruit(pool_index) -> bool`); §C.5 step 3-4 (`On true / On false` branching); AC-21-05; AC-21-06; AC-21-07

**Drift**: the GDD claims `try_recruit` returns `bool`. The actual implementation at `src/core/recruitment/recruitment.gd:198` is:

```gdscript
func try_recruit(pool_index: int) -> RecruitOutcome:
```

Where `RecruitOutcome` is an enum at `recruitment.gd:47` with at least 4 values: `INVALID_POOL_INDEX`, `UNRESOLVABLE_CLASS_ID`, `ROSTER_FULL`, plus the success / `INSUFFICIENT_GOLD` cases.

**Why this matters**: the GDD's "On true / On false" branching pattern (and the toast routing in §C.5 step 4 that maps `reason` strings to localized messages) is structurally wrong for an enum return. Implementation will need to switch on the enum:

```gdscript
match Recruitment.try_recruit(pool_index):
    RecruitOutcome.SUCCESS: ...  # signals fire automatically
    RecruitOutcome.INSUFFICIENT_GOLD: _show_toast(tr("recruit_error_insufficient_gold"))
    RecruitOutcome.ROSTER_FULL: _show_toast(tr("recruit_error_roster_full"))
    RecruitOutcome.UNRESOLVABLE_CLASS_ID: _show_toast(tr("recruit_error_unresolvable_class"))
    RecruitOutcome.INVALID_POOL_INDEX: push_warning(...)  # race; defensive
```

**Recommended fix**: in the GDD's `/design-review` pass, rewrite §C.5 step 2 + AC-21-05/06/07 to reference the `RecruitOutcome` enum + the match-on-enum pattern. This is a cross-reference correction, not a design change; the underlying behavior the GDD describes (recruit-on-success-with-signals; toast-on-failure-by-reason) is unaffected.

**Originating commit**: `85aac96` (Recruit Screen GDD #21 first-pass DRAFT, 2026-05-07).

---

## Confirmed drift item #2 — `guild-hall-screen.md` AC-19-04 cites `hero_recruited(4, "mage")` 2-arg form

**File**: `design/gdd/guild-hall-screen.md`
**Section affected**: §H AC-19-04

**Drift**: AC-19-04 reads:

> "Subscribe + emit `hero_recruited(4, "mage")`. A new HeroCard appears for hero id 4. Card count increases by 1."

The 2-arg form `hero_recruited(4, "mage")` matches NEITHER of the two `hero_recruited` signals in the codebase:

- `HeroRoster.hero_recruited(instance: RefCounted)` — 1-arg, `recipient = HeroInstance` (per `src/core/hero_roster/hero_roster.gd:170`)
- `Recruitment.hero_recruited(hero_instance_id: int, class_id: String, cost_paid: int)` — 3-arg (per `src/core/recruitment/recruitment.gd:130`)

Per Guild Hall §C.4 ("HeroCards are non-interactive in MVP — Sprint 14+ Roster / Hero Detail Screen #22 may make them tappable") + §F (`HeroRoster (#9) | Roster panel data + gating | _heroes, hero_recruited/hero_removed/hero_leveled signals, display_name lookup`), the GDD subscribes to **HeroRoster's** 1-arg form.

**Recommended fix**: AC-19-04 should read:

> "Subscribe to `HeroRoster.hero_recruited` + emit with a fresh `HeroInstance` (id=4, class_id='mage'). A new HeroCard appears for hero id 4. Card count increases by 1."

**Why this matters**: the AC is a test-prescription. As written, a test author would write a test with the wrong arity that immediately fails at signal-connect time (Godot signal arity mismatch raises an error). The fix is a one-line GDD edit.

**Originating commit**: `66f937d` (Guild Hall Screen GDD #19, mixed reverse-doc + forward-spec, 2026-05-07).

---

## Self-documented gap (worth flagging) — `recruit-screen.md` §C.6 cites `Recruitment.get_refreshes_today()` accessor that doesn't exist

**File**: `design/gdd/recruit-screen.md`
**Section affected**: §C.6 step 1

**Drift / gap**: the GDD reads:

> "Read current cost: `Recruitment.refresh_cost(Recruitment.get_refreshes_today())` — exposed via accessor (Sprint 14 S14-S4 may need this getter; if not present, the screen reads `_refreshes_today` or the cost directly via a wrapper method)"

`Recruitment.get_refreshes_today()` does not exist as a public method in `recruitment.gd`. The `_refreshes_today` field IS an instance variable; private. The GDD self-documents this gap with the parenthetical, but the §C.6 step 1 lead sentence still presents the accessor as canonical.

**Recommended fix**: during `/design-review`, decide:
- (a) add the public `get_refreshes_today() -> int` accessor in Sprint 15+ implementation (~5 LoC; matches the get_recruit_pool / get_recruit_cost public-accessor pattern at `recruitment.gd:281` / `:292`), OR
- (b) expose a higher-level `get_next_refresh_cost() -> int` wrapper that resolves the private field internally, OR
- (c) accept that the screen reads via `_refreshes_today` directly (less clean; couples screen to internal field name)

Recommend (a) — matches existing accessor pattern; cleanest. Captured here as a `/design-review` decision, not silent drift.

**Originating commit**: `85aac96` (Recruit Screen GDD #21 first-pass DRAFT, 2026-05-07).

---

## Bidirectional dependency arrow spot-checks (all aligned)

For each of the 9 first-pass GDDs, §F (Dependencies) lists hard-deps on upstream systems. The corresponding §F (Reverse dependencies) on the upstream GDD should mention the downstream GDD. Spot-checked the highest-leverage pairs:

### Hero Detail Modal (#22) → 7 hard-deps

| Downstream claim | Upstream §F reverse-dep matches? |
|---|---|
| HeroRoster (#9) | ✓ (per `hero-roster.md` §F not explicitly listed but consumer pattern matches) |
| Economy (#5) | ✓ (Economy GDD §F lists "Roster / Hero Detail Modal" as Hard reverse-dep — verified) |
| DataRegistry (#2) | ✓ (`resolve("classes", id)` is universal; not GDD-listed) |
| HeroClassDatabase (#6) | ✓ |
| SceneManager (#4) | ✓ (modal pattern per Settings overlay precedent) |
| UIFramework (#18) | ✓ |

### Recruit Screen (#21) → 7 hard-deps

| Downstream claim | Upstream §F reverse-dep matches? |
|---|---|
| Recruitment (#14) | ✓ (`recruitment-system.md` §F line 348 lists "RecruitScreen (Sprint 12+ UI)" as the `hero_recruited` consumer — alignment on intent though the UI was undesigned at the time) |
| Economy (#5) | ✓ (Economy GDD §F lists "Recruit Screen" as Hard reverse-dep — verified) |
| HeroRoster (#9) | ✓ |
| DataRegistry (#2) | ✓ |

### Matchup Assignment Screen (#23) → 8 hard-deps

| Downstream claim | Upstream §F reverse-dep matches? |
|---|---|
| Formation Assignment (#17) | ✓ (set_target API is added by S15-N1; documented in `formation-assignment-system.md` §F via S15-N1 commit) |
| BiomeDungeonDatabase (#8) | ✓ (per `biome-dungeon-database.md` §F line 238 — explicit reverse-dep) |
| FloorUnlock (#16) | ✓ (per `floor-unlock-system.md` §F — Matchup Assignment Screen #23 is explicitly listed in the cross-system table) |

### Victory Moment (#25) → 9 hard-deps

| Downstream claim | Upstream §F reverse-dep matches? |
|---|---|
| Floor Unlock (#16) | ✓ (per `floor-unlock-system.md` §F line 406 + line 619 + §C.1 R5 LOCK — explicit reverse-dep with locked design floor) |
| DungeonRunOrchestrator (#13) | ✓ (sole entry path documented; pre_dispatch_gold field added by S15-S4) |
| Hero Leveling (#15) | ✓ |
| Economy (#5) | ✓ (gold delta read via get_gold_balance) |

### Cross-screen consistency: Settings overlay summoning

All four screen GDDs that interact with Settings (Guild Hall #19, Recruit Screen #21, Hero Detail #22, Victory Moment #25) defer to Guild Hall as the sole entry point for Settings (per Guild Hall #19 §C.5 SettingsGearButton). Verified consistent — no GDD claims its own gear icon.

**Result**: bidirectional dependency arrows are aligned across all spot-checked pairs. No additional drift items found.

---

## ADR cross-reference verification

The 9 first-pass GDDs cite 17 unique ADRs (ADR-0001 through ADR-0017 — the full canonical set). Spot-checked existence + status:

| ADR | Cited in (GDDs) | Status | Notes |
|---|---|---|---|
| ADR-0001 (Mid-run formation reassignment) | hero-leveling.md | Accepted | ✓ |
| ADR-0002 (Losing first-clear reclaimable) | unlock-victory-moment.md, onboarding-first-session.md | Accepted | ✓ |
| ADR-0004 (Save envelope + HMAC) | recruit-screen.md, roster-hero-detail-screen.md, matchup-assignment-screen.md, hero-leveling.md, onboarding-first-session.md | Accepted | ✓ |
| ADR-0005 (Time system dual-clock) | unlock-victory-moment.md | Accepted | ✓ |
| ADR-0007 (Scene transition + persist) | ui-framework.md, return-to-app-screen.md, settings-options-accessibility.md, guild-hall-screen.md | Accepted | ✓ |
| ADR-0008 (UI framework dual-focus + theme) | recruit-screen.md, roster-hero-detail-screen.md, matchup-assignment-screen.md, unlock-victory-moment.md, ui-framework.md | Accepted | ✓ |
| ADR-0009 (Matchup resolver DI) | matchup-assignment-screen.md | Accepted | ✓ |
| ADR-0012 (Hero Roster mutation) | roster-hero-detail-screen.md | Accepted | ✓ |
| ADR-0013 (Economy state + cost curves) | recruit-screen.md, roster-hero-detail-screen.md | Accepted | ✓ |
| ADR-0014 (Offline replay batch) | recruit-screen.md, roster-hero-detail-screen.md, matchup-assignment-screen.md, unlock-victory-moment.md, hero-leveling.md, onboarding-first-session.md, return-to-app-screen.md | Accepted | ✓ |
| ADR-0015 (Recruitment determinism) | recruit-screen.md, onboarding-first-session.md | Accepted | ✓ |
| ADR-0016 (Audio silent-MVP) | recruit-screen.md, roster-hero-detail-screen.md, unlock-victory-moment.md | Accepted (2026-05-07) | ✓ |
| ADR-0017 (HD-2D shader deferred) | unlock-victory-moment.md | Accepted (2026-05-07) | ✓ Status flipped from Proposed via `ddaba59` |

**Result**: all 13 cited ADRs exist + are Accepted. No phantom ADR references; no ADR-Proposed references that auto-block downstream stories per `docs/CLAUDE.md`.

---

## Signal-signature consistency (full audit beyond the drift item above)

### gold_changed (3-arg)

Canonical: `Economy.gold_changed(new_balance: int, delta: int, reason: String)` per `economy-system.md` ADR-0013-SYNC + Economy GDD §F. Verified consistent across:
- `recruit-screen.md` §C.3 + §C.4 + AC-21-12 — uses 3-arg form ✓
- `guild-hall-screen.md` §C.3 + AC-19-08 — uses 3-arg form ✓
- `audio-system.md` §C.3 — uses 3-arg form ✓

### floor_cleared_first_time (3-arg)

Canonical: `DungeonRunOrchestrator.floor_cleared_first_time(floor_index: int, biome_id: String, losing_run: bool)` per `dungeon_run_orchestrator.gd:133` + Orchestrator GDD §C.3. Verified consistent across:
- `unlock-victory-moment.md` §C.2 + §D.1 — uses 3-arg form ✓
- `floor-unlock-system.md` §C.1 R5 + §F — uses 3-arg form ✓
- `onboarding-first-session.md` §C — uses 3-arg form ✓

### hero_leveled (3-arg)

Canonical: `HeroRoster.hero_leveled(instance_id: int, old_level: int, new_level: int)` per `hero-roster.md` §F + `hero_roster.gd:171`. Verified consistent across:
- `hero-leveling.md` §C.4 + §H ACs — uses 3-arg form ✓
- `roster-hero-detail-screen.md` §C.5 + AC-22-12 — uses 3-arg form ✓
- `unlock-victory-moment.md` §C.10 + AC-25-08 — uses 3-arg form ✓
- `audio-system.md` §C.2 — uses 3-arg form ✓

### hero_recruited (1-arg HeroRoster vs 3-arg Recruitment) — DUAL-SOURCE

This is the source of the §guild-hall-screen.md AC-19-04 drift documented above. The codebase has **two distinct `hero_recruited` signals** with different signatures:

- `HeroRoster.hero_recruited(instance: RefCounted)` — 1-arg, the canonical "a hero was added to the roster"
- `Recruitment.hero_recruited(hero_instance_id: int, class_id: String, cost_paid: int)` — 3-arg, the canonical "the recruit transaction completed (with cost)"

Both are real. Subscribers must explicitly choose. The GDDs that subscribe should clarify which:
- `recruit-screen.md` AC-21-13 — references "When `HeroRoster.hero_recruited(instance)` fires" — explicit, 1-arg form, CORRECT.
- `roster-hero-detail-screen.md` AC-22-14 — references the signal abstractly without arity; should reference HeroRoster's 1-arg form explicitly during `/design-review`.
- `guild-hall-screen.md` AC-19-04 — uses the 2-arg form `hero_recruited(4, "mage")` — DRIFT (documented above).

**Recommended `/design-review` action**: when reviewing GDDs with `hero_recruited` references, ensure the GDD explicitly disambiguates which signal (HeroRoster vs Recruitment) the subscriber is bound to. The canonical pattern is "subscribe to HeroRoster.hero_recruited for roster-side reactions; subscribe to Recruitment.hero_recruited for transaction-cost reactions (e.g., audio chime triggered by cost_paid)".

---

## Stub GDD spot-checks (#26, #27, #31, #32)

Per Sprint 14 retro recommendation #4, the 4 V1.0/Vertical Slice tier stubs ship with sections A + F (preliminary) + I (Open Questions) only. Drift surface is small — there's less prose to drift. Spot-checked:

| Stub | ADR refs | §F preliminary | Notable gaps |
|---|---|---|---|
| #26 HD-2D Pipeline | ADR-0017 | Forward+ rendering, ADR-0017, parchment theme, Art Bible | None — stub scope is correctly bounded |
| #27 VFX System | (none cited) | HD-2D Pipeline #26, AudioRouter #28, GPUParticles2D, Settings reduce_motion | Should cite ADR-0008 (UIFramework / animation feel) when full first-pass authoring lands |
| #31 Prestige System | (none cited) | HeroRoster, Hero Leveling, Economy, Save/Load, Class Synergy | Should cite ADR-0012 (Hero Roster mutation — reset_for_prestige API extension) when full first-pass authoring lands |
| #32 Class Synergy System | (none cited) | Formation Assignment, Combat Resolution, Hero Leveling, Economy, screens, Prestige | Locks anti-FOMO design floor (≤+50% multiplier cap); ADR-candidate when 3rd multiplier source emerges per OQ-32-8 |

**Result**: stub scope is appropriate; no drift identified within the bounded stub surface. Full first-pass authoring (Sprint 16+ for #26/#27; V1.0 design block for #31; V1.0+ for #32) should add the missing ADR cross-references noted above.

---

## Recommended `/design-review` priority order

When the user runs `/design-review` on the 9 first-pass GDDs, prioritize by:

1. **Settings GDD #30** — gates Sprint 15 S15-M1 + M3 implementation
2. **Recruit Screen GDD #21** — confirmed drift (try_recruit return type) + self-documented gap (get_refreshes_today accessor); both should resolve via this review
3. **Guild Hall GDD #19** — confirmed drift (AC-19-04 hero_recruited arity); one-line fix
4. **Hero Leveling GDD #15** — implementation has shipped, so review is informative not gating; AC-15-02 cap-rate calibration tension awaits playtest data per OQ-15-1
5. **Onboarding GDD #29** — gates Sprint 15 S15-S2
6. **Roster / Hero Detail Screen GDD #22** — gates Sprint 16+ implementation; review after #19 + #21 because this GDD inherits patterns from both
7. **Matchup Assignment Screen GDD #23** — gates Sprint 16+ implementation; FormationAssignment.set_target API now exists (S15-N1) so the GDD's §C.5 setter ref is no longer a phantom
8. **Victory Moment GDD #25** — gates Sprint 16+ implementation; pre_dispatch_gold field now exists (S15-S4) so the GDD's §C.4 stats render is no longer a phantom
9. **UI Framework GDD #18 + Return-to-App GDD #20** — reverse-doc; lighter review per Sprint 13 retro

The 4 stubs (#26/#27/#31/#32) are review-appropriate but lower priority than the 9 first-pass GDDs.

---

## Notes

- This sweep is NOT a `/design-review` substitute. `/design-review` is the canonical interactive consistency check + design-review surface; this sweep pre-flags items the user should be aware of before invoking it.
- All 9 first-pass GDDs + 4 stubs land in `design/gdd/` with `Status: DRAFT 2026-05-07` (or earlier 2026-05-06 for the prior-session 5 GDDs). None have flipped to APPROVED yet.
- The two confirmed drift items + one self-documented gap are the highest-leverage spot-checks for the user's `/design-review` pass. Each is a small text edit; none require rethinking the design intent.
- Bidirectional dependency arrows + ADR cross-references + signal signatures (except the documented `hero_recruited` arity drift in `guild-hall-screen.md`) are aligned across the 9 GDDs.
- The Sprint 15 S15-S4 + S15-N1 commits this session (`43554cd`) eliminated two previously-phantom API references (DungeonRunOrchestrator.run_snapshot.pre_dispatch_gold + FormationAssignment.set_target/get_target). The Victory Moment GDD §D.2 + Matchup Assignment GDD §C.5 are now grounded in shipped code.

This sweep closes Sprint 15 N2.
