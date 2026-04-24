# Cross-GDD Review Report

**Date**: 2026-04-19
**Reviewer**: main session (`/review-all-gdds full`)
**Review mode**: solo (CD-SYSTEMS skipped)
**GDDs reviewed**: 8
**Inputs**: `game-concept.md`, `systems-index.md`, `design/registry/entities.yaml`, plus all 8 system GDDs:

- `game-time-and-tick.md` (#1)
- `data-loading.md` (#2)
- `save-load-system.md` (#3)
- `scene-screen-manager.md` (#4)
- `economy-system.md` (#5)
- `hero-class-database.md` (#6)
- `enemy-database.md` (#7)
- `biome-dungeon-database.md` (#8)

---

## Verdict: **CONCERNS** (post-fix)

Initial verdict was **FAIL** with 3 blocking items. All three were resolved inline during this review pass — see "Inline Fixes Applied" below. Remaining items are warning-level only; architecture may proceed but the warnings should be tracked for resolution before/during Offline Engine GDD authoring and the first MVP playtest.

---

## Inline Fixes Applied

1. **Deleted orphan stub** — `design/gdd/data-loading-system.md` was an empty TODO skeleton; the real GDD is `data-loading.md`. File removed.
2. **Registry value corrected** — `design/registry/entities.yaml` `REWIND_TOLERANCE_SECONDS` updated from `60` → `300` to match Time System GDD's revised default; added `save-load-system.md` to `referenced_by`; bumped `revised: 2026-04-19` and `last_updated: 2026-04-19`.
3. **Save/Load Time integration completed** — `save-load-system.md` Section C "Interactions with Other Systems → Time System", "Persist Triggers" table, "Upstream Dependencies" table, AC-SL-01, and "Bidirectional Consistency" section all updated to:
   - Persist + restore both `last_persist_unix_ts` AND `t_session_high_water` via `get_session_high_water()`/`set_session_high_water()`
   - State that both timestamp fields MUST be HMAC-covered (the high-water mark is the in-session-rewind defense per Time System AC-TICK-05b)
   - Add `scene_boundary_persist` to the Persist Triggers table with the abort-on-failure contract
   - Add Scene/Screen Manager to the Upstream Dependencies table

---

## Consistency Issues

### Blocking (resolved inline)

🔴 **C-01: `t_session_high_water` field missing from Save/Load's Time integration spec** — RESOLVED
- Time System (revised 2026-04-19) requires Save/Load to persist + sign both `last_persist_unix_ts` AND `t_session_high_water`. AC-TICK-05b's in-session-rewind detection depends on the high-water mark surviving the round-trip.
- Save/Load was written before the Time revision; only mentioned `last_persist_unix_ts`.
- **Fix applied**: Save/Load Section C, AC-SL-01, Dependencies table, and Bidirectional Consistency all updated. See Inline Fixes #3.

🔴 **C-02: Registry drift — `REWIND_TOLERANCE_SECONDS` value stale** — RESOLVED
- `entities.yaml` had `value: 60`; authoritative GDD says 300.
- **Fix applied**: Registry updated. See Inline Fixes #2.

🔴 **C-03: Orphan stub `data-loading-system.md`** — RESOLVED
- **Fix applied**: File deleted. See Inline Fixes #1.

### Warnings (not blocking)

⚠ **C-04: `scene_boundary_persist` signal contract** — Now consistent
- Was: Scene Manager declared the signal; Save/Load didn't list it.
- Now: Save/Load Persist Triggers + Dependencies + Bidirectional Consistency all reference it. (Verified during inline fix.)

⚠ **C-05: `roster.get_formation_strength()` is a one-sided contract**
- Economy declares dependence on it; Hero Roster GDD does not yet exist.
- Acceptable — Economy's Open Questions flags it. Hero Roster GDD must respect this signature when written.

⚠ **C-06: `tick_output_contribution_l1` / `tick_output_per_level` are unowned forward-declarations**
- Hero Class DB declares them; Economy formula doesn't read them; Dungeon Run Orchestrator GDD (consumer) doesn't exist yet.
- Self-flagged in Hero Class DB C.7. Risk: dead schema if Orchestrator ultimately doesn't consume them. Revisit at Orchestrator authoring.

⚠ **C-07: Floor-clear bonus offline-replay policy spans two GDDs without single owner**
- Economy E.4 + H-03 implies first-clear idempotency via `floors_cleared_bonus_awarded[]` guard.
- Biome/Dungeon C.7 + D.3 flags the policy as unresolved (1:226 ratio at F5; 3.04M gold inflation if retriggers).
- Reconcilable today (Economy's idempotency guard already prevents duplication), but Biome/Dungeon doesn't cite the resolution. Either Biome/Dungeon should cite Economy H-03, or Offline Engine GDD must lock the contract explicitly. **Recommended**: Offline Engine GDD authors the explicit policy statement and both upstream GDDs cite it.

---

## Game Design Issues

### Warnings

⚠ **D-01: F1 has zero `armored` enemies — Rogue gets no counter target on tutorial floor**
- Biome/Dungeon C.4 distribution: Warrior 3 / Mage 1 / **Rogue 0** on Floor 1.
- A Day-1 player who recruits a Rogue first sees no matchup payoff until Floor 2. Risk: undermines Pillar 3's "matchup matters" lesson during onboarding.
- Self-flagged in Biome/Dungeon C.7 ("Disposition: keep, contextualize via tutorial copy"). Acceptable IF Onboarding GDD compensates with tutorial copy. Re-check after first playtest.

⚠ **D-02: F5 boss is single-archetype `bruiser` — Mage/Rogue-focused players earn no matchup bonus on the MVP finale**
- Floor 5 = 1 Ancient Rootking (`bruiser` only). +40g matchup delta only available with a Warrior in formation.
- A player who built a Mage-and-Rogue-heavy roster (legitimate Pillar 2 expression) gets economically rewarded on the climax kill for the class they didn't invest in.
- Self-flagged in both Enemy DB and Biome/Dungeon GDDs. Mitigated by raw DPS contribution (Mage+Rogue carry 74 of 130 formation ATK), but the matchup-gold delta on the most economically significant kill in MVP lands squarely on Warrior owners.
- **Recommendation**: First playtest validates whether Mage/Rogue investment still feels meaningful on Floor 5; if not, consider hybrid boss archetype or biome-2 V1.0 boss as the alternate-class showcase.

### Pass

✅ **D-03: Cognitive load** — 3 simultaneously active systems (roster curation, formation assignment, recruit/level decisions); idle drip is passive. Comfortably under the 4-system cognitive ceiling.
✅ **D-04: Pillar alignment** — All 8 GDDs explicitly cite served pillars. No anti-pillar violations (no FOMO, no IAP, no narrative branches, no synchronous multiplayer).
✅ **D-05: Player fantasy coherence** — All systems serve the "guildmaster/curator" identity consistently. No identity conflicts.
✅ **D-06: Economic loops** — Single currency (gold). Sources: drip, kill bonuses, floor-clear bonuses. Sinks: recruitment, leveling. No infinite source / no-sink condition. Geometric escalation (1.8× recruit, 1.6× level) maintains scarcity. Sanity cap at 1T provides int64 headroom (6 OOM).
✅ **D-07: Difficulty curves** — Enemy HP per tier (52–72 / 185–225 / 680, 2200), hero stats (~3× L15/L1), and Economy curves are co-calibrated; D.6 pacing model + Enemy DB rounds-to-kill calibration align.

---

## Cross-System Scenario Issues

Scenarios walked: 4
- S-01: Cold launch with 6h offline gains
- S-02: Boss kill during offline replay
- S-03: Settings overlay during dungeon run + heartbeat fires
- S-04: Same-second BG↔FG cycle

### Resolved Blockers

🔴 **S-01: Cold launch — `t_session_high_water` round-trip undefined** — RESOLVED via C-01 fix.

### Warnings

⚠ **S-03: Settings overlay during dungeon run + heartbeat tick**
- Trigger: player opens Settings mid-run; 60s heartbeat tick arrives.
- Sequence: Scene Manager → PAUSED → `get_tree().paused = true`. Time System tick loop must use `PROCESS_MODE_ALWAYS` + manual `if get_tree().paused: return` guard (per Scene Manager C.6 WARN). Heartbeat persist is a Save/Load concern, not a tick.
- Risk: if implementer follows naive `PROCESS_MODE_PAUSABLE`, heartbeat stops too — extending data-loss window during long Settings sessions.
- Already flagged in Scene Manager C.6 + Time System E11. **Recommendation**: control manifest must call this out as a binding implementation rule.

### Info

ℹ **S-02: Boss kill during offline replay** — Working as designed. Orchestrator emits `enemy_killed(3, true)` → Economy adds 120g via `kill_bonus(3) × 1.5` → Orchestrator emits `floor_cleared_first_time(5)` → Economy idempotently adds 18,000g. Boss-death fanfare correctly suppressed during replay; Return-to-App `events_log` carries the celebration.

ℹ **S-04: Same-second BG↔FG cycle** — Time System E9 covers; one-shot replay flag prevents re-run. No issue.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority | Status |
|-----|--------|------|----------|--------|
| `save-load-system.md` | Missing `t_session_high_water` round-trip | Consistency | Blocking | ✅ FIXED |
| `data-loading-system.md` | Orphan stub | Consistency | Blocking | ✅ DELETED |
| `design/registry/entities.yaml` | Stale `REWIND_TOLERANCE_SECONDS` value | Consistency | Blocking | ✅ FIXED |
| `biome-dungeon-database.md` | F1 archetype + F5 single-archetype boss | Design Theory | Warning | OPEN — playtest |
| `economy-system.md` ↔ `biome-dungeon-database.md` | Floor-clear-bonus offline policy not jointly cited | Consistency | Warning | OPEN — Offline Engine GDD locks |
| `hero-class-database.md` | `tick_output_*` unowned forward-decl | Consistency | Warning | OPEN — Orchestrator GDD |
| `economy-system.md` | `roster.get_formation_strength()` one-sided contract | Consistency | Warning | OPEN — Hero Roster GDD |

---

## Pillar Coverage Audit

| Pillar | GDDs serving it (explicit) |
|---|---|
| Pillar 1 (Respect Player Time) | Time System, Save/Load, Economy, Scene Manager (indirect) |
| Pillar 2 (Every Class Feels Distinct) | Hero Class DB, Enemy DB (telegraphs counter), Biome/Dungeon (per-floor archetype variety), Data Loading (indirect) |
| Pillar 3 (Matchup Is a Decision) | Hero Class DB (counter_archetype tag), Enemy DB (archetype tag), Biome/Dungeon (per-floor distribution), Economy (1.5× multiplier) |
| Pillar 4 (HD-2D Pixel Pride) | Scene Manager (animation budget per Art Bible), Enemy DB (silhouette contracts), Biome/Dungeon (palette + environmental storytelling), Data Loading (indirect) |

All 4 pillars served by ≥3 GDDs. No "orphan pillar." No anti-pillar violations.

---

## Next Recommended Action

With the 3 blocking items fixed, architecture preparation could begin, but **the recommended path is to continue Feature-layer GDD authoring** (Hero Roster #9 next) before architecture, because:
- 3 of 5 remaining warnings (`tick_output` ownership, `formation_strength_factor`, floor-clear-bonus policy) are open against undesigned downstream GDDs (Roster, Orchestrator, Offline Engine). Authoring those 3 GDDs naturally resolves the warnings.
- Foundation + Core layers (8 GDDs) only cover 8 of 25 MVP systems — architecting now would lock in interfaces against undesigned consumers.
- The 2 design warnings (F1 Rogue / F5 boss archetype) need playtest validation, not pre-architecture resolution.

**Recommended immediate next step**: `/design-system "Hero Roster"` (system #9). Resolves the `formation_strength_factor` warning by virtue of authoring the producer.

**Strong alternative**: `/design-system "Class-vs-Enemy Matchup Resolver"` (#10) — tightest integration point across Class DB + Enemy DB; validates the matchup contract in practice.
