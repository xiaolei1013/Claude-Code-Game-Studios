# Prestige System (V1.0 first-pass) — GDD #31

> **Status: FIRST-PASS DRAFT 2026-05-09** by Sprint 20 S20-M1 autonomous-execution session (authored 17 weeks ahead of nominal Sprint 20 window per the project's pre-emptive cadence). Promoted from STUB DRAFT 2026-05-07. Mirrors the Class Synergy first-pass GDD #32 pattern (PR #20 merged 2026-05-09). Covers all 8 required GDD sections. Open Questions OQ-31-1..7 from the stub are RESOLVED here per the recommended defaults; OQ-31-8 (timing) is closed by this draft. Per `production/sprints/sprint-20.md` S20-M1: "first-pass authoring is autonomous-doable; APPROVED verdict via /design-review is the user-gated portion" — this draft awaits `/design-review` for APPROVED status.

> **Pass 1 (this draft) scope locks**: hero-retirement-based prestige cost (no gold cost), flat global multiplier reward (×1.05 per prestige, capped at ×2.0 / 20 prestiges), level cap stays at 15 with multiplier compounding post-prestige (option b from OQ-31-4), Hall of Retired Heroes cosmetic surface, save schema V2 migration path. Cozy-register hard floor: prestige is ALWAYS voluntary, no FOMO timers, no urgency prompts (OQ-31-5 locked).

---

## A. Overview

**Prestige System** is the V1.0 meta-progression layer that lets players permanently retire LEVEL_CAP=15 heroes in exchange for a compounding global multiplier on future kill gold + kill XP. Per `game-concept.md` §Roadmap V1.0 tier ("+ prestige") + Hero Leveling GDD #15 §C.5 LEVEL_CAP overflow ("V1.0 prestige system #31 will be the lever to reset capped heroes for further progression").

The cozy register applies: prestige is **voluntary**, not pressure-driven. Player chooses when to prestige (no countdown timer, no FOMO event); the prestige action is a deliberate "this hero earned their retirement" decision made when the player feels their MVP run has plateaued. Per `game-concept.md` cozy fantasy: prestige is the long-game horizon that respects player agency.

The retired hero is **not deleted**. They join the **Hall of Retired Heroes** — a cosmetic gallery surface accessible from the guild_hall screen — with a parchment-warm crown overlay marking them as a Prestige hero. Player can see who retired, when, and at what tier. The narrative beat is "this hero retires to teach the next generation," not "this hero is sacrificed."

Status: **first-pass GDD pending `/design-review` APPROVED**. Implementation is V1.0 scope (post-MVP-ship). MVP ships with `prestige_multiplier = 1.0` hardcoded in the kill-gold + kill-xp formulas (no prestige active). The V1.0 implementation work lives in a future epic; this GDD is the design contract that work will follow.

---

## B. Player Fantasy

**Intended feeling**: "Theron has been with me since the beginning. He's level 15 and there's nowhere left to climb. But the Hall of Retired Heroes is calling — and the +5% gold I'd earn forever is real progress." The bittersweet decision moment when a player's first cap-15 hero is offered the prestige path. Not "I MUST prestige to be efficient" (that's the FOMO trap of incentive-structured idle games); but "this hero has earned their place in the Hall, and the guild benefits from their teaching."

The prestige system is **patient** — most players will NOT prestige on day one. The game ships with LEVEL_CAP=15 as the MVP terminal state; reaching cap is itself a milestone. Prestige is the V1.0 "what next" answer for players who've reached cap and want to keep escalating. The Hall of Retired Heroes is the visual reward — a cozy gallery of portraits that grows over time, each crowned with parchment-warm laurel.

**Feel-state taxonomy**:
- **First-prestige beat** — when a hero first hits LEVEL_CAP=15, the Hero Detail Modal grows a new "Prestige Hero" button. Player taps; a confirmation modal appears with cozy copy ("Theron has earned their retirement..."). Player confirms; the hero animates a soft fade to the Hall; the global prestige_count increments to 1; a single warm sting plays. NOT a fanfare animation. Cozy register.
- **Subsequent prestiges** — same beat, briefer audio (suppress_window per audio-system.md §F throttle). The cosmetic Hall view gains another portrait.
- **Hall visit** — player can open the Hall of Retired Heroes anytime from guild_hall. Portraits are ordered by retirement date. Hovering a portrait shows the hero's stats at retirement + the prestige_count they contributed to.
- **Prestige cap reached** — at PRESTIGE_MAX = 20 prestiges (OR PRESTIGE_MULTIPLIER_CAP = 2.0), the prestige button hides. The player has "fully prestiged"; further heroes can still hit LEVEL_CAP but the button is hidden. The Hall stays open; cosmetic surfaces continue to populate.

**Anti-patterns explicitly rejected**:
- No "prestige NOW or lose progress" framing. Prestige is always voluntary; no time-limited prestige bonuses; no countdown urgency.
- No prestige cost in gold. The cost IS the hero's retirement — narratively coherent, emotionally weighted, no economic pressure spiral.
- No prestige unlock pacing tied to time-played, hours-active, or biome-cleared. Prestige is available the moment a hero hits LEVEL_CAP=15.
- No "prestige stacks reset" mechanic. Once a hero is retired, the multiplier gain is permanent. No resets, no "prestige tier 2" that requires re-prestiging.
- No prestige-only content. All biomes, all classes, all systems are accessible without ever prestiging.

---

## C. Detailed Rules

### C.1 — Prestige eligibility

A hero is **prestige-eligible** when ALL of the following are true:
- `hero.level == LEVEL_CAP` (= 15 per `hero-roster.md` §C.10)
- The hero is currently in the active roster (not already in the Hall)
- The global `prestige_count < PRESTIGE_MAX` (= 20 per Tuning Knobs G)
- The global `prestige_multiplier < PRESTIGE_MULTIPLIER_CAP` (= 2.0 per Tuning Knobs G)

The Hero Detail Modal queries `HeroRoster.is_prestige_eligible(instance_id) -> bool` to decide whether to show the **Prestige Hero** button.

### C.2 — Prestige action

Player taps **Prestige Hero** in the Hero Detail Modal. The system shows a confirmation modal with writer-locked Pass-5E-style cozy copy:

> *"[hero_name] has earned their retirement. They'll join the Hall of Retired Heroes — your guild will remember them, and every future run will earn +5% more gold and XP, forever."*
>
> *[Prestige Hero] [Cancel]*

On `[Cancel]`: modal dismisses, no state change. Idempotent.

On `[Prestige Hero]`: the system synchronously:
1. Removes the hero from the active roster (`HeroRoster.remove_hero(instance_id)` — existing API).
2. Appends a `RetiredHeroRecord` to `HeroRoster._retired_hero_records: Array[Dictionary]` with the retired hero's snapshot at retirement time (display_name, class_id, level, retirement_unix_ts, prestige_index — see C.5 schema).
3. Increments global `_prestige_count: int += 1`.
4. Recomputes `_prestige_multiplier = 1.0 + (_prestige_count * PRESTIGE_GAIN_PER)`.
5. Emits `prestige_completed_signal(retired_record: Dictionary, new_prestige_count: int)` — Hall UI subscribes; AudioRouter subscribes for the warm sting cue.
6. Triggers a save persist (`SaveLoadSystem.request_full_persist("prestige_completed")`) so the action survives a crash.

The action is **synchronous** — no `await`, no deferred completion. By the time the modal dismisses, the hero is retired and the multiplier is updated.

### C.3 — Effect application

The prestige multiplier composes multiplicatively with the existing kill-output formula chain (Class Synergy GDD #32 §C.3 + dungeon-run-orchestrator.md §D.1):

```
attribute_kill_gold(tier, advantaged, losing_run, synergy_id, archetype) -> int:
    var matchup_multiplier: float = MATCHUP_GOLD_MULTIPLIER if advantaged else 1.0
    var loot_factor: float = LOSING_RUN_LOOT_FACTOR if losing_run else 1.0
    var synergy_multiplier: float = _resolve_synergy_gold_multiplier(synergy_id, archetype)
    var prestige_multiplier: float = HeroRoster.get_prestige_multiplier()
    return floori(BASE_KILL[tier] × matchup_multiplier × loot_factor × synergy_multiplier × prestige_multiplier)

attribute_kill_xp(tier, synergy_id) -> int:
    var synergy_multiplier: float = _resolve_synergy_xp_multiplier(synergy_id)
    var prestige_multiplier: float = HeroRoster.get_prestige_multiplier()
    return floori(BASE_XP_PER_KILL × tier × synergy_multiplier × prestige_multiplier)
```

`HeroRoster.get_prestige_multiplier() -> float` returns the current cached multiplier. Default 1.0 (no prestige yet). After N prestiges, returns `1.0 + N × 0.05` (clamped to PRESTIGE_MULTIPLIER_CAP = 2.0).

**Stacking semantics**: prestige stacks **multiplicatively** with matchup × loot × synergy. The 5-factor product stays well-bounded under cozy register caps:
- Max matchup = 1.5 (advantaged)
- Max loot factor = 1.0 (winning run)
- Max synergy = 1.5 (Class Synergy GDD §G hard floor)
- Max prestige = 2.0 (this GDD's hard cap)
- **Theoretical max combined**: 1.5 × 1.0 × 1.5 × 2.0 = 4.5× baseline output

Per cozy-register rule, this is an end-state late-game peak — most runs will see <2× combined multipliers. The 4.5× ceiling is a soft balance test that AC-PR-15 enforces via simulated runs.

### C.4 — Hall of Retired Heroes (UI surface)

> **Sprint 23 S23-M1 update (2026-05-15)**: the Hall is now a **Retired tab on Guild Hall's RosterPanel** — not a separate screen. The standalone `hall_of_retired_heroes` screen was retired; SceneManager registry shrank 7 → 6. See `guild-hall-screen.md` §F "V1.0 progression-layer additions". The card metadata format, multiplier badge rendering rules, sort order, and "no un-prestige" guarantee below all carry over to the tab implementation verbatim.

A Retired tab on `guild_hall.tscn`'s RosterPanel TabContainer (sibling to the Active tab). Layout:

- **List view**: each retired hero is a card with portrait + display_name + retirement metadata.
- **Card metadata**: "Theron · Warrior · Lv 15 · Retired Day 47" (Day = `floor((retirement_unix_ts - first_launch_unix_ts) / 86400)` per Tick System GDD #1 wall-clock semantics).
- **Sort order**: retirement date descending (newest first).
- **Card visual**: portrait at standard size + parchment-warm laurel crown overlay (Art Bible Visual Identity Anchor — gold + dusk-purple per Pillar 4).
- **No "un-prestige" button**. Retirement is permanent; the cozy register guarantees this so the player can prestige confidently.
- **Empty state**: the Retired tab is always visible (no visibility gate). When no retirees exist, a cozy "No retired heroes yet." placeholder card renders (locale key `hall_empty_state_placeholder`).

Localization keys (8 new):
- `prestige_button_label` — "Prestige Hero"
- `prestige_confirmation_modal_body` — the cozy copy from C.2
- `prestige_confirmation_button_confirm` — "Prestige Hero"
- `prestige_confirmation_button_cancel` — "Cancel"
- `prestige_complete_toast` — "[hero_name] joined the Hall of Retired Heroes."
- `hall_of_retired_heroes_title` — "Hall of Retired Heroes"
- `hall_card_metadata_format` — "%s · %s · Lv %d · Retired Day %d"
- `prestige_disabled_active_run_tooltip` — "Prestige a hero between runs."

### C.5 — Save schema (V2 migration)

V1.0 introduces a **save schema V2** bump (current = V1 per `save-load-system.md` `CURRENT_SAVE_VERSION = 1`). The migration adds:

**At the global Roster save namespace** (`HeroRoster.get_save_data()`):
- `prestige_count: int` — default 0 for V1→V2 migration
- `prestige_multiplier: float` — default 1.0 for V1→V2 migration
- `retired_hero_records: Array[Dictionary]` — default `[]` for V1→V2 migration

**Per `RetiredHeroRecord` Dictionary shape**:
```json
{
    "display_name": "Theron",
    "class_id": "warrior",
    "level_at_retirement": 15,
    "retirement_unix_ts": 1763028000,
    "prestige_index": 1
}
```

`prestige_index` is the 1-based index of the prestige that retired this hero (1st retired hero gets index 1, 2nd gets index 2, etc.). Used for ordering + future "you've prestiged N heroes" stats.

**V1→V2 migration body** (per `save-load-system.md` `_run_migration_chain`):
```gdscript
func _migrate_v1_to_v2(payload_v1: Dictionary) -> Dictionary:
    var payload_v2: Dictionary = payload_v1.duplicate(true)
    if payload_v2.has("HeroRoster"):
        var roster: Dictionary = payload_v2["HeroRoster"]
        roster["prestige_count"] = roster.get("prestige_count", 0)
        roster["prestige_multiplier"] = roster.get("prestige_multiplier", 1.0)
        var empty_records: Array = []
        roster["retired_hero_records"] = roster.get("retired_hero_records", empty_records)
        payload_v2["HeroRoster"] = roster
    return payload_v2
```

Forward-compat: V2 builds reading a V1 save default the new fields (idempotent on re-migration). V1 builds reading a V2 save reject (per `save-load-system.md` Story 010 future-version-rejection contract).

### C.6 — V1.0+ extension hooks (forward-looking)

The first-pass GDD is bounded to a single global multiplier + Hall cosmetic surface. The system is designed so V1.5+ can extend without schema migration:

- **Class-specific multipliers** (OQ-31-2 alternative b): if V1.5 wants per-class prestige multipliers (prestige a Warrior → all Warriors get +10%), the schema extension adds `class_prestige_multipliers: Dictionary[String, float]` to the Roster save namespace. V1.0's flat `prestige_multiplier` stays as a global baseline.
- **Cosmetic-only prestiges** (OQ-31-2 alternative c): if V1.5 wants a "cosmetic-only retirement" path (retire a hero for the Hall without the multiplier gain), add a `cosmetic_only: bool` field to `RetiredHeroRecord`. Default false in V1.0 first-pass.
- **Prestige-tier UI** (OQ-31-4 alternative c): if V1.5 wants "Prestige 1 · Level 7" overlays on heroes whose class has been prestiged-from, that's a UI-layer extension reading existing `RetiredHeroRecord` data. No schema change.
- **Prestige Onboarding tutorial** (OQ-31-7): V1.0 ships with the prestige button + confirmation modal copy as the inline tutorial. If V1.5 playtests reveal first-time prestige confusion, expand `onboarding-system.md` (#29) with a dedicated prestige introduction subsection.

---

## D. Formulas

### D.1 — Prestige multiplier resolution

```
HeroRoster.get_prestige_multiplier() -> float:
    return clampf(
        1.0 + (_prestige_count * PRESTIGE_GAIN_PER),
        1.0,
        PRESTIGE_MULTIPLIER_CAP
    )
```

**Variable definitions**:
- `_prestige_count: int` — incremented monotonically per prestige action; persisted in V2 save.
- `PRESTIGE_GAIN_PER: float` = 0.05 (5% per prestige; tuning knob)
- `PRESTIGE_MULTIPLIER_CAP: float` = 2.0 (hard cap; tuning knob)

**Expected output range**: 1.0 (no prestige) → 2.0 (cap reached at 20 prestiges).

**Worked example**:
- After 0 prestiges: `clampf(1.0, 1.0, 2.0) = 1.0` (baseline)
- After 1 prestige: `clampf(1.05, 1.0, 2.0) = 1.05`
- After 5 prestiges: `clampf(1.25, 1.0, 2.0) = 1.25`
- After 10 prestiges: `clampf(1.50, 1.0, 2.0) = 1.50`
- After 20 prestiges: `clampf(2.00, 1.0, 2.0) = 2.0`

### D.2 — Eligibility predicate

```
HeroRoster.is_prestige_eligible(instance_id: int) -> bool:
    var hero: HeroInstance = get_hero(instance_id)
    if hero == null:
        return false
    if hero.level != LEVEL_CAP:
        return false
    if _prestige_count >= PRESTIGE_MAX:
        return false
    if get_prestige_multiplier() >= PRESTIGE_MULTIPLIER_CAP:
        return false
    return true
```

**Variable definitions**:
- `LEVEL_CAP: int` = 15 (per `hero-roster.md` §C.10)
- `PRESTIGE_MAX: int` = 20 (tuning knob)

### D.3 — Prestige cost (locked: capped hero retirement only)

V1.0 first-pass locks the prestige cost as **one capped hero, no gold**. There is no formula — the cost is the hero. Per OQ-31-1 resolution (cozy register favors narrative-coherent retirement). V1.5+ may add a hybrid (capped hero + gold) but V1.0 keeps it pure.

### D.4 — Worked end-to-end example

Player's roster: Theron (Warrior, Lv 15), Mira (Mage, Lv 12), Erin (Rogue, Lv 8). Player decides to prestige Theron.

**Pre-prestige**: `_prestige_count = 0`, `_prestige_multiplier = 1.0`, 3 heroes, 0 retirees.

**Action**: Player taps "Prestige Hero" → confirmation → "Prestige Hero" confirm.

**Synchronous execution** (per C.2):
1. `HeroRoster.remove_hero(theron_instance_id)`.
2. Append `RetiredHeroRecord{display_name: "Theron", class_id: "warrior", level_at_retirement: 15, retirement_unix_ts: 1763028000, prestige_index: 1}`.
3. `_prestige_count` = 1.
4. `_prestige_multiplier` = 1.05.
5. `prestige_completed_signal` emits.
6. SaveLoadSystem persists.

**Post-prestige**: `_prestige_count = 1`, `_prestige_multiplier = 1.05`, 2 heroes, 1 retiree.

**Player's next dispatch**: Mira + Erin + recruited-Warrior at Forest Reach Floor 1. Tier-3 bruiser kill in advantaged matchup, no synergy, winning run:

```
attribute_kill_gold(3, true, false, "", "bruiser") =
    floori(BASE_KILL[3] × 1.5 × 1.0 × 1.0 × 1.05) =
    floori(50 × 1.5 × 1.05) = floori(78.75) = 78
```

vs. pre-prestige: `floori(50 × 1.5 × 1.0) = 75`. Bonus is +3 gold per tier-3 bruiser kill. Across 100 such kills in a run, that's +300 gold — meaningfully felt in the recruit-cost economy.

---

## E. Edge Cases

1. **Player prestiges their last hero**: HeroRoster's `remove_hero` enforces a "minimum-1-hero" invariant (per `hero-roster.md` §C.5 — first-launch seed guarantees at least one hero). If the player tries to prestige their only hero, `is_prestige_eligible` returns FALSE; the Prestige button is hidden. (V1.5+ could surface this hint inline; V1.0 first-pass relies on the button-hidden state.)

2. **Concurrent dispatch + prestige**: prestige action can only fire when the orchestrator is in NO_RUN state. During ACTIVE_FOREGROUND or ACTIVE_OFFLINE_REPLAY, the Hero Detail Modal's Prestige button is disabled (greyed out) with tooltip `tr("prestige_disabled_active_run_tooltip")`.

3. **Hero in active formation**: if the to-be-prestiged hero is currently in a formation slot, FormationAssignment.set_formation_slot auto-clears the slot (existing pattern from `formation-assignment-system.md` §C). Slot becomes empty; player must re-fill before next dispatch.

4. **Save during prestige action** (ultra-rare): if the player triggers a save persist during the synchronous prestige execution, SaveLoadSystem's coalesce contract (TR-save-load-046) drops the new persist trigger and lets the prestige's own `request_full_persist("prestige_completed")` fire. No mid-action save corruption.

5. **PRESTIGE_MAX reached + player taps prestige button**: button is hidden when `_prestige_count >= PRESTIGE_MAX` (per C.1). Defensive: even if a UI bug surfaces the button, `is_prestige_eligible` returns FALSE; the action body's debug-only `assert` would catch it; production fails silently with `push_error` + return.

6. **Save migration V1→V2**: covered by C.5. V1 saves are valid V2 saves with default field values. Idempotent if applied twice.

7. **V2 save loaded into a hypothetical V3 build**: per `save-load-system.md` future-version-rejection contract, V3 build reading V2 save runs `_migrate_v2_to_v3` if it exists; if not, future-version detection fires.

8. **Hall portrait orphaned by class_id removal**: if V1.5+ removes a class (unlikely — `class-vs-enemy-matchup-resolver.md` treats class_id as stable), the Hall would have orphaned portraits. Defensive: Hall card rendering uses `HeroClassDatabase.resolve_or_default(class_id)` falling back to a "Retired Hero (Class Lost)" placeholder. Cozy register: existing retirements never become invalid.

9. **Localization missing key**: per `ADR-0008` Localization-ready rule, all 8 new locale keys route through `tr()`. If a key is missing in a locale CSV, `tr()` returns the key string verbatim (Godot 4.6 default). UI degrades gracefully with the key visible — diagnostic-friendly, not a crash.

10. **Multiplier rendering precision**: the prestige multiplier is rendered to 2 decimal places ("×1.05", "×1.50") in the Hall + Hero Detail tooltips. AC-PR-13 enforces.

11. **Reduce-motion accessibility flag**: per `scene-manager.md` Story 009 reduce_motion support, the prestige confirmation modal's hero-fade-to-Hall animation is suppressed when `reduce_motion = true` — hero is removed instantly without the fade tween. Per Class Synergy GDD #32 §E.9 pattern.

12. **Anti-frustration: prestige feels mechanically meaningless on small numbers**: the +5% bonus rounds to 0 on small kill_gold values (BASE_KILL[1] = 10 → 1.05 = 10 still floori). Intentional — the prestige is a long-game compounding bonus, not a per-kill noticeable change. Players notice across hundreds of kills + later tiers. AC-PR-15 enforces minimum measurable effect across simulated long runs.

---

## F. Dependencies

### F.1 Forward dependencies (Prestige depends on these)

| System | Why | Surface used |
|---|---|---|
| **Hero Roster** (#9) | Roster mutation + multiplier source | New: `HeroRoster.is_prestige_eligible(instance_id)`, `HeroRoster.prestige_hero(instance_id) -> bool`, `HeroRoster.get_prestige_multiplier() -> float`. New private fields: `_prestige_count: int`, `_prestige_multiplier: float`, `_retired_hero_records: Array[Dictionary]`. New signal: `prestige_completed_signal(record: Dictionary, new_count: int)`. |
| **Hero Leveling** (#15) | LEVEL_CAP semantic (eligibility threshold) | `LEVEL_CAP = 15` (existing per Hero Leveling §C.5). No semantic change; Prestige reads the cap. |
| **DungeonRunOrchestrator** (#13) | Per-run gold + XP multiplier application | `attribute_kill_gold` + `attribute_kill_xp` formulas extend with `prestige_multiplier` factor (per C.3). 5-factor product: BASE × matchup × loot × synergy × prestige. |
| **Economy** (#5) | Constants location | `economy_config.tres` adds `PRESTIGE_GAIN_PER = 0.05`, `PRESTIGE_MULTIPLIER_CAP = 2.0`, `PRESTIGE_MAX = 20`. No formula change to Economy itself. |
| **Save/Load System** (#3) | V2 schema migration | New: `_migrate_v1_to_v2` body in `save_load_system.gd` per C.5. `CURRENT_SAVE_VERSION` bumps 1 → 2. The 3 new HeroRoster fields become V2 schema. |
| **Class Synergy System** (#32) | V1.0 sibling progression layer | Both ship in V1.0; multipliers stack multiplicatively per C.3 5-factor product. |
| **Hero Class Database** (#6) | class_id stable identifiers for Hall portraits | `HeroClassDatabase.resolve_or_default(class_id) -> HeroClass` (existing). |
| **Audio System** (#28) | Prestige action audio cues | New cues: `sfx_prestige_completed` (warm sting), `sfx_hall_card_revealed` (subtle parchment-rustle on Hall first-open). |
| **Scene Manager** (#4) | reduce_motion flag honoring | `SceneManager.reduce_motion` (existing). |
| **Locale Loader** (S9-M3 LocaleLoader autoload) | tr() string resolution | `assets/locale/en.csv` adds 8 new keys per C.4. |

### F.2 Reverse dependencies (these systems consume Prestige)

| System | Consumed surface | Why |
|---|---|---|
| **Hero Detail Modal** (#22) | `HeroRoster.is_prestige_eligible` + `HeroRoster.prestige_hero` | "Prestige Hero" button visibility + action |
| **Guild Hall Screen** (#19) | `HeroRoster._retired_hero_records.size()` + Hall view route | "Hall of Retired Heroes" button visibility + navigation target |
| **DungeonRunOrchestrator** (#13) | `HeroRoster.get_prestige_multiplier()` | Per-kill formula extension (C.3) |
| **Audio Router** (#28) | Two new cue triggers | Prestige completed + Hall card reveal chimes |
| **Onboarding System** (#29) | (V1.5+) Prestige introduction subsection | V1.5+ tutorial expansion if first-prestige confusion surfaces in playtest |

### F.3 Bidirectional confirmation

Per CLAUDE.md design-doc rules: "Dependencies must be bidirectional — if system A depends on B, B's doc must mention A."

The following GDDs need 2026-05-09 amendments to acknowledge Prestige as a consumer:
- `hero-roster.md` — add Prestige #31 to F (consumer; new public API + new private fields + new signal + V2 schema)
- `hero-leveling.md` — add Prestige #31 to F (consumer; reads LEVEL_CAP=15)
- `dungeon-run-orchestrator.md` — add Prestige #31 to F (consumer; per-kill formula extension; 5-factor product)
- `economy-system.md` — add Prestige #31 to F (consumer; 3 new constants in economy_config.tres)
- `save-load-system.md` — add Prestige #31 to F.consumers (consumer; V2 migration body + CURRENT_SAVE_VERSION bump 1→2)
- `audio-system.md` — add Prestige #31 to F (consumer; 2 new cues + throttle config)
- `class-synergy-system.md` — add Prestige #31 to F.cross-reference (V1.0 sibling; 5-factor product stacking)
- `hero-class-database.md` — add Prestige #31 to F (consumer; class_id resolver for Hall portraits)
- `roster-hero-detail-modal.md` — add Prestige #31 to F (consumer; new button + action surface)
- `guild-hall-screen.md` — add Prestige #31 to F (consumer; new Hall button + view)

These cross-GDD amendments are **deferred to a single batch pass** when the Prestige V1.0 implementation epic kicks off (Sprint 22+ scope per Sprint 20 plan), bundled with the Class Synergy F.3 amendments from PR #20 if not already shipped.

---

## G. Tuning Knobs

All knobs live in `assets/data/economy/economy_config.tres` (existing per `economy-system.md` §G).

| Knob | Type | Default | Safe Range | Affects |
|---|---|---|---|---|
| `PRESTIGE_GAIN_PER` | float | 0.05 | 0.02 – 0.10 | Per-prestige multiplier gain. >0.10 risks rapid escalation; <0.02 makes prestige feel pointless. |
| `PRESTIGE_MULTIPLIER_CAP` | float | 2.0 | 1.5 – 3.0 | Hard ceiling on the global multiplier. >3.0 risks late-game runaway. |
| `PRESTIGE_MAX` | int | 20 | 10 – 40 | Hard cap on total prestige actions. PRESTIGE_GAIN_PER × PRESTIGE_MAX must equal PRESTIGE_MULTIPLIER_CAP - 1.0; current values produce exactly 1.0 + 20×0.05 = 2.0. AC-PR-16 enforces this invariant. |
| `prestige_audio_suppress_window_seconds` | float | 2.0 | 0.5 – 5.0 | Throttle for `sfx_prestige_completed`. Per audio-system.md §F. |
| `prestige_confirmation_modal_minimum_dwell_seconds` | float | 0.0 | 0.0 – 1.5 | Minimum time the confirmation modal stays visible before [Prestige Hero] is enabled. Default 0.0; designer can raise to 0.5-1.0 if playtests show accidental prestiging. |
| `hall_card_animation_duration_seconds` | float | 0.3 | 0.0 – 1.0 | Hall card reveal-tween length. Honored by reduce_motion (collapses to 0.0 when flag is set). |

**Designer-tuning workflow**: change values in `economy_config.tres` via the Godot editor's Inspector; no code changes; tests pick up the new constants on next run via DataRegistry resolution. AC-PR-16 enforces the GAIN_PER × MAX = CAP - 1.0 invariant.

---

## H. Acceptance Criteria

All ACs are V1.0 implementation-targets (not MVP). They become BLOCKING on the V1.0 Prestige implementation epic; until then, the system ships with `prestige_multiplier = 1.0` hardcoded.

### AC-PR-01 — Eligibility: hero at LEVEL_CAP returns true
**Given**: Theron (Warrior, Lv 15); `_prestige_count = 0`. **When**: `is_prestige_eligible(theron_id)`. **Then**: `true`.

### AC-PR-02 — Eligibility: hero below LEVEL_CAP returns false
**Given**: Theron (Lv 14); `_prestige_count = 0`. **When**: `is_prestige_eligible`. **Then**: `false`.

### AC-PR-03 — Eligibility: PRESTIGE_MAX reached returns false
**Given**: Theron (Lv 15); `_prestige_count = 20`. **When**: `is_prestige_eligible`. **Then**: `false`.

### AC-PR-04 — Eligibility: PRESTIGE_MULTIPLIER_CAP reached returns false
**Given**: Theron (Lv 15); `_prestige_count = 20` AND `_prestige_multiplier = 2.0`. **When**: `is_prestige_eligible`. **Then**: `false` (defensive — both checked).

### AC-PR-05 — Eligibility: nonexistent hero returns false
**Given**: instance_id = 9999 (not in roster). **When**: `is_prestige_eligible(9999)`. **Then**: `false`. No crash.

### AC-PR-06 — Prestige action: hero removed from active roster
**Given**: Theron (Lv 15); confirm. **When**: `prestige_hero(theron_id)`. **Then**: Theron not in `get_all_heroes()`; roster size -1.

### AC-PR-07 — Prestige action: retired record appended
**When**: `prestige_hero` runs. **Then**: `_retired_hero_records.size()` +1. New record has `display_name = "Theron"`, `class_id = "warrior"`, `level_at_retirement = 15`, `prestige_index = 1`, `retirement_unix_ts > 0`.

### AC-PR-08 — Prestige action: count + multiplier updated
**Given**: pre-action `_prestige_count = 0`, multiplier = 1.0. **When**: `prestige_hero` runs. **Then**: `_prestige_count == 1`, `_prestige_multiplier == 1.05`.

### AC-PR-09 — Prestige action: signal emitted with correct payload
**When**: `prestige_hero` runs. **Then**: `prestige_completed_signal` emits exactly once. Payload: `record.display_name == "Theron"`, `new_count == 1`.

### AC-PR-10 — Prestige action: synchronous persist fires
**When**: `prestige_hero` body runs. **Then**: `SaveLoadSystem.request_full_persist("prestige_completed")` invoked synchronously before `prestige_hero` returns. Save file reflects post-action state.

### AC-PR-11 — Multiplier formula: linear scaling matches D.1
**Given**: a sequence of `_prestige_count` values 0..25. **When**: `get_prestige_multiplier()` runs for each. **Then**: returns 1.0, 1.05, 1.10, ..., 2.0 (clamped at PRESTIGE_MULTIPLIER_CAP for count >= 20). Parameterized test across all 26 values.

### AC-PR-12 — Save round-trip V2: prestige state persists
**Given**: post-prestige (`_prestige_count = 5`, multiplier = 1.25, 5 records); persist; reload. **When**: load completes. **Then**: in-memory state matches pre-persist. JSON int round-trip preserves types per project memory (int via `int()` cast on load).

### AC-PR-13 — Hall display format: multiplier rendered to 2 decimal places
**Given**: `_prestige_multiplier = 1.05`. **When**: Hall renders multiplier badge. **Then**: text is `"×1.05"` exactly. UI test enforces.

### AC-PR-14 — V1→V2 migration: existing V1 save loads with prestige defaults
**Given**: V1 save with no prestige fields. **When**: V2 build runs `_migrate_v1_to_v2`. **Then**: `_prestige_count == 0`, `_prestige_multiplier == 1.0`, `_retired_hero_records.size() == 0`. No migration error. Save re-persists under V2 (Story 010 post-migration re-persist contract).

### AC-PR-15 — Long-run prestige bonus measurable: 100-kill simulation
**Given**: `_prestige_multiplier = 1.05`; 100 simulated tier-3 bruiser kills, advantaged, winning. **When**: total gold summed. **Then**: total ≥ 5% more than the same 100 kills with multiplier = 1.0. Enforces measurable bonus across long runs.

### AC-PR-16 — Tuning invariant: GAIN_PER × MAX equals CAP - 1.0
**Given**: economy_config.tres values. **When**: static-analysis CI test runs. **Then**: asserts `abs((PRESTIGE_GAIN_PER * PRESTIGE_MAX) - (PRESTIGE_MULTIPLIER_CAP - 1.0)) < 1e-6`.

### AC-PR-17 — Localization: all 8 prestige strings route through tr()
**When**: prestige modal + Hall + button + toast render. **Then**: text from `tr("prestige_*")` keys. CI grep enforces no hardcoded strings in `assets/screens/hero_detail/` or `assets/screens/guild_hall/`.

### AC-PR-18 — Reduce-motion: hero-fade-to-Hall animation suppressed
**Given**: `SceneManager.reduce_motion = true`; player confirms prestige. **When**: `prestige_hero` runs. **Then**: hero removed instantly without fade tween; modal still shows; toast still shows; Hall card animation also instant.

### AC-PR-19 — Prestige during active run: button disabled
**Given**: orchestrator state == ACTIVE_FOREGROUND; modal opens. **When**: modal renders. **Then**: button disabled with `tr("prestige_disabled_active_run_tooltip")` tooltip.

### AC-PR-20 — Last-hero protection: button hidden
**Given**: roster has exactly 1 hero (Theron, Lv 15). **When**: modal renders. **Then**: button hidden.

### AC-PR-21 — Stacking: prestige × synergy × matchup multiplies cleanly
**Given**: multiplier = 1.05; synergy_id = "steel_wall"; tier-3 bruiser advantaged winning. **When**: `attribute_kill_gold(3, true, false, "steel_wall", "bruiser")`. **Then**: `floori(50 × 1.5 × 1.0 × 1.25 × 1.05) = floori(98.4375) = 98`. Verifies 5-factor product per C.3.

### AC-PR-22 — Performance: get_prestige_multiplier under 100µs p99
**Given**: any state. **When**: `get_prestige_multiplier()` runs 100 000 times. **Then**: p99 < 100µs (function is pure + O(1)).

---

## I. Open Questions

Resolved in this first-pass:
- **OQ-31-1** (cost mechanism): RESOLVED — capped hero retirement only.
- **OQ-31-2** (reward type): RESOLVED — flat global multiplier + Hall cosmetic surface.
- **OQ-31-3** (curve): RESOLVED — flat 5% per prestige; capped at 20 prestiges / 2.0 multiplier.
- **OQ-31-4** (LEVEL_CAP behavior): RESOLVED — option (b). Cap stays at 15; multiplier compounds.
- **OQ-31-5** (cozy-register vs urgency): RESOLVED — voluntary-only, no FOMO timers.
- **OQ-31-6** (save schema migration): RESOLVED — V1→V2 migration per C.5.
- **OQ-31-7** (onboarding): PARTIALLY RESOLVED — inline tutorial via confirmation modal copy; #29 expansion deferred to V1.5+.
- **OQ-31-8** (full first-pass GDD timing): RESOLVED by this draft.

Remaining open:
- **OQ-31-9 (NEW)** — interaction with Class Synergy in mid-prestige states: a player who's prestiged 5 of 6 heroes might find their roster too thin to compose synergy formations. Resolution: V1.0+ playtest data; recommend monitoring "synergy-active-runs / total-runs" ratio for prestiged players in telemetry (post-launch live-ops scope per Sprint 20 S20-N3).
- **OQ-31-10 (NEW)** — Hall portrait density in late-prestige states: with 20 retired heroes, the Hall view scrolls. UX needs a sort/filter affordance. Resolution: V1.0 first-pass UI is a simple scrolling list; V1.5 adds search + class-filter if late-prestige feedback surfaces.
- **OQ-31-11 (NEW)** — beta tester feedback on cozy-register positioning: "5% feels small" might be common feedback. Resolution: don't reactively raise PRESTIGE_GAIN_PER; instead, marketing copy + onboarding tutorial frames the prestige as long-game-bonus, not per-run-bonus. Revisit at Sprint 21+ playtest review.

---

## J. Cross-System Cross-Reference

Prestige is one of two V1.0 progression layers; pairs with Class Synergy #32 (PR #20 merged 2026-05-09). Both ship together in the V1.0 release block.

| Cross-system | Direction | Why |
|---|---|---|
| **Class Synergy #32** | V1.0 sibling | Per OQ-31-2, prestige does NOT unlock synergies (cozy register — synergies are always-available per Class Synergy GDD OQ-32-4). But prestige's multiplier stacks multiplicatively with synergy multiplier (5-factor product per C.3). |
| **Hero Leveling #15** | Forward dep | LEVEL_CAP=15 is the prestige eligibility threshold. No semantic change to leveling. |
| **Hero Roster #9** | Forward dep + central API host | Adds 3 public methods, 3 private fields, 1 signal. Schema migration V1→V2. |
| **Hero Detail Modal #22** | Reverse dep | New "Prestige Hero" button + confirmation modal. Per `roster-hero-detail-modal.md` §C.5 step 1, the LevelUpButton hides at cap; this GDD adds the Prestige button visibility logic. |
| **Guild Hall Screen #19** | Reverse dep | New "Hall of Retired Heroes" button + view. Per `guild-hall-screen.md` §F, button visibility gated on `_retired_hero_records.size() > 0`. |

---

## Notes

- First-pass GDD authored 2026-05-09 by Sprint 20 S20-M1 autonomous-execution session (17 weeks ahead of nominal Sprint 20 window). Promoted from STUB DRAFT 2026-05-07. All 8 required GDD sections present. Mirrors the Class Synergy first-pass GDD #32 pattern (PR #20 merged 2026-05-09).
- Awaiting `/design-review` for APPROVED status. Per Sprint 20 S20-M1 plan: "first-pass authoring is autonomous-doable; APPROVED verdict via /design-review is the user-gated portion."
- Closes systems-index.md row 31 status from "STUB DRAFT 2026-05-07" → "FIRST-PASS DRAFT 2026-05-09 (pending /design-review)".
- Per CLAUDE.md design-doc rules, F.3 lists 10 GDDs that need bidirectional-dependency amendments. Deferred to a single batch pass when the V1.0 Prestige implementation epic kicks off (Sprint 22+ scope), bundled with Class Synergy F.3 amendments if not already shipped.
- The cozy-register hard floor (prestige is voluntary, no FOMO, no countdown timers) is the load-bearing design constraint per OQ-31-5. Future prestige extensions must respect this floor or the design is non-shippable per Pillar 1 (Respect the Player's Time).
- The 5-factor multiplicative formula composition (BASE × matchup × loot × synergy × prestige) is now firmly established by the V1.0 design block. A future "RunModifier" abstraction (Class Synergy GDD §C.5 + OQ-32-8) becomes ADR-worthy if a 6th multiplier source emerges. Until then, 5 explicit factors is clearer than premature abstraction.
