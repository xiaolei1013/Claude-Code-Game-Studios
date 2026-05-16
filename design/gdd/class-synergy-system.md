# Class Synergy System (V1.0 first-pass) — GDD #32

> **Status: APPROVED 2026-05-10** (first pass authored 2026-05-09; APPROVED via `/design-review` 2026-05-10; re-review revisions 2026-05-14 closed 2 BLOCKING items before Sprint 18 M2 implementation). Scoped to the load-bearing 3-class MVP roster + FORMATION_SIZE=3; covers all 8 required GDD sections. Open Questions OQ-32-1..6 from the stub are RESOLVED here per the recommended defaults; OQ-32-7..8 deferred to a future ADR pass once a third multiplier source emerges. Implementation unblocked for Sprint 18 S18-M2.

> **Pass 1 (this draft) scope locks**: 4 first-pass synergies (3 mono-class + 1 mix), multiplicative effects, live preview at formation_assignment + dispatch-time confirmation, all synergies always-available (no unlock cadence), ≤+25% multiplier cap (well under the cozy-register hard floor of +50% from OQ-32-6). Revised 2026-05-14 review pass added Triple Strike (3-Rogue) for symmetric class treatment alongside Steel Wall (3-Warrior) and Arcane Elite (3-Mage).

---

## A. Overview

**Class Synergy System** is the V1.0 formation-bonus layer that rewards specific class compositions with conditional per-run multipliers on kill gold or kill XP. Per `game-concept.md` §Roadmap "V1.0" tier — Class Synergy is the meta-formation puzzle layer that emerges once the player's roster covers the full 3-class MVP set (Warrior + Mage + Rogue).

The cozy register applies: synergies are **discoverable, not mandatory**. A player who runs solo-class formations earns 100% of baseline rewards; synergies layer +20-25% on top under specific composition conditions. There is no synergy that DOUBLES output, no synergy that creates "must-run" pressure, and no synergy unlock pacing — all 3 first-pass synergies are always available for any player who has the required heroes recruited.

Per `game-concept.md` Pillar 1 (Tactical Foresight): "Each formation choice teaches the player something about class interactions." The synergy preview at the formation_assignment screen IS the teaching surface — the player sees "3 Warriors → Steel Wall (+25% kill gold vs Bruisers)" as they assemble the formation, learns the rule, and can choose whether to optimize for it.

Status: **first-pass GDD pending `/design-review` APPROVED**. Implementation is V1.0 scope (post-MVP-ship); MVP ships with synergy_multiplier = 1.0 hardcoded in `attribute_kill_gold`. The V1.0 implementation work lives in a future epic; this GDD is the design contract that work will follow.

---

## B. Player Fantasy

**Intended feeling**: "Oh — these three together work BETTER than apart." The discovery moment when a player notices their 3-Warrior formation is producing more gold against bruiser-heavy floors than their mixed formation did. Not "I MUST run Steel Wall to be efficient" (that's the slot-machine trap of incentive-structured idle games); but "I tried something on a hunch and it paid off."

The synergy system is **patient** — most players will run mixed formations early (because they only have 1-2 of any one class recruited). Synergies emerge naturally as the recruit pool deepens. The first time a player has 3 Warriors and dispatches them together, the formation_assignment screen shows the active Steel Wall badge with a soft cozy chime. That's the fantasy — the game noticed, the player feels seen, the gold flow validates.

**Feel-state taxonomy**:
- **Discovery** — first time a synergy activates, the formation panel highlights with a brief glow (per `assets/screens/formation_assignment/` UX pattern, NOT a modal interruption — cozy register forbids gameplay pauses for cosmetic events). Audio: a single warm sting cue.
- **Routine** — subsequent activations are quiet. The synergy badge stays visible but the activation chime is suppressed (suppress_window_seconds — see Tuning Knobs).
- **Strategic** — a player intentionally re-rolling their formation to hit a synergy gets the same audio-visual feedback as the first time, since composition has changed.

**Anti-patterns explicitly rejected**:
- No "synergy or you're falling behind" framing. Solo-class formations earn 100% of baseline.
- No synergy that breaks the +50% cozy-register cap (OQ-32-6 hard floor).
- No synergy unlock pacing tied to time-played, biome-cleared, or prestige-level. Synergies are always-available.
- No "synergy expires" timer. Synergies are formation-composition-conditional, not time-conditional.
- No "synergy stacks" or "double-synergy" mechanic in V1.0. One active synergy per formation.

---

## C. Detailed Rules

### C.1 — Synergy roster (V1.0 first-pass)

Four synergies ship in the first-pass V1.0 implementation: three mono-class (one per MVP class) plus one 1+1+1 mix. Each is keyed by an exact composition signature (multiset of `class_id` values across the formation's 3 slots). Order doesn't matter; class instance levels don't matter.

| ID | Display Name | Composition Signature | Effect | Conditional |
|---|---|---|---|---|
| **steel_wall** | Steel Wall | `{warrior, warrior, warrior}` | ×1.25 kill gold | Only on kills against `archetype = bruiser` |
| **arcane_elite** | Arcane Elite | `{mage, mage, mage}` | ×1.20 kill XP | Unconditional (all kills) |
| **triple_strike** | Triple Strike | `{rogue, rogue, rogue}` | ×1.25 kill gold | Only on kills against `archetype = armored` |
| **triple_threat** | Triple Threat | `{warrior, mage, rogue}` | ×1.15 kill gold | Unconditional (all kills) |

**Design rationale per synergy**:
- **Steel Wall** (3 Warriors, +25% gold vs Bruisers): conditional on archetype matchup, so the synergy *teaches* the player about the warrior-counters-bruiser relationship from `class-vs-enemy-matchup-resolver.md`. Non-bruiser kills get baseline gold. This forces the player to think about WHEN to deploy Steel Wall, not just "always run 3 Warriors".
- **Arcane Elite** (3 Mages, +20% XP): unconditional XP boost. Teaches "concentrate mages for accelerated leveling" — an investment archetype. Pairs naturally with Hero Leveling GDD #15's LEVEL_CAP=15 ceiling: Arcane Elite is the canonical "level-cap-rush" formation. Mages get the *investment* framing (XP) rather than the *exploit-the-matchup* framing (gold) used by Steel Wall and Triple Strike — distinguishes Mage's role as the long-term-curve class.
- **Triple Strike** (3 Rogues, +25% gold vs Armored): structurally parallel to Steel Wall. Conditional on archetype matchup per the Rogue-counters-Armored relationship in `class-vs-enemy-matchup-resolver.md`. Non-armored kills get baseline gold. The symmetric design (both 3-W and 3-R use the same +25% × counter-archetype shape) gives players the same discovery moment regardless of which class their recruit pool deepens into first. Added in the 2026-05-14 review pass to close the asymmetric-class-treatment gap from the 2026-05-09 first-pass draft.
- **Triple Threat** (1+1+1 mix, +15% gold): the "balanced" reward. Lower bonus than Steel Wall / Triple Strike but unconditional. Teaches that diversity has its own value. Caps at +15% so it stays under the mono-class conditional max — the conditional path rewards more aggressively when it triggers.

### C.2 — Synergy detection (live preview + dispatch-time confirmation)

Per OQ-32-3 resolution: BOTH live preview during slot edit AND dispatch-time confirmation.

**Live preview** (formation_assignment screen, per `formation-assignment-system.md`):
- Whenever the formation slot composition changes (player taps a slot to swap heroes), `FormationAssignment.detect_active_synergy(formation_snapshot) -> String` runs (returns the synergy_id string per §D.1, or `""` when no synergy matches).
- If a synergy matches (non-empty synergy_id), the formation panel shows a **synergy badge** with the synergy display name + effect summary text. Localized via `tr("class_synergy_badge_<id>")` keys (e.g., `class_synergy_badge_steel_wall`).
- If no synergy matches (empty synergy_id), the badge is hidden.
- The detection function is pure (no signals fired, no side effects); it's safe to call every slot edit. Idempotent.

**Dispatch-time confirmation** (DungeonRunOrchestrator, per `dungeon-run-orchestrator.md`):
- At dispatch (DISPATCHING state, before transition to ACTIVE_FOREGROUND), `DungeonRunOrchestrator.snapshot_synergy_for_run(formation_snapshot)` resolves the active synergy and stores the resulting `synergy_id: String` (or `""` if none) into `RunSnapshot.synergy_id`.
- The snapshot's `synergy_id` is then read by `attribute_kill_gold` and `attribute_kill_xp` per-kill to apply the multiplier.
- The dispatch-time snapshot is intentional: even if the player edits the formation MID-RUN (per ADR-0001 mid-run reassignment policy), the synergy active for the run is the one snapshotted at dispatch. Mid-run formation edits do NOT change the active synergy for that run.

### C.3 — Effect application

Per OQ-32-2 resolution: multiplicative effects only.

The Combat Resolution + Orchestrator integration extends `attribute_kill_gold` and (new) `attribute_kill_xp` with a `synergy_multiplier` factor. Per Pass-4B-Economy decision shape from Orchestrator GDD §D.1, the formula composition is multiplicative:

```
attribute_kill_gold(tier, advantaged, losing_run, synergy_id, archetype) -> int:
    var matchup_multiplier: float = MATCHUP_GOLD_MULTIPLIER if advantaged else 1.0
    var loot_factor: float = LOSING_RUN_LOOT_FACTOR if losing_run else 1.0
    var synergy_multiplier: float = _resolve_synergy_gold_multiplier(synergy_id, archetype)
    return floori(BASE_KILL[tier] × matchup_multiplier × loot_factor × synergy_multiplier)
```

Where `_resolve_synergy_gold_multiplier(synergy_id, archetype)` returns:
- `1.0` for `synergy_id == ""` (no synergy active)
- `STEEL_WALL_GOLD_MULT` (1.25) for `synergy_id == "steel_wall" AND archetype == "bruiser"`
- `1.0` for `synergy_id == "steel_wall" AND archetype != "bruiser"` (Steel Wall is conditional)
- `TRIPLE_STRIKE_GOLD_MULT` (1.25) for `synergy_id == "triple_strike" AND archetype == "armored"`
- `1.0` for `synergy_id == "triple_strike" AND archetype != "armored"` (Triple Strike is conditional)
- `TRIPLE_THREAT_GOLD_MULT` (1.15) for `synergy_id == "triple_threat"` (unconditional)
- `1.0` for `synergy_id == "arcane_elite"` (Arcane Elite affects XP, not gold)

The XP path mirrors the gold path: a new `attribute_kill_xp(tier, synergy_id) -> int` fires after `attribute_kill_gold` per kill. Its formula:

```
attribute_kill_xp(tier, synergy_id) -> int:
    var synergy_multiplier: float = _resolve_synergy_xp_multiplier(synergy_id)
    return floori(BASE_XP_PER_KILL × tier × synergy_multiplier)
```

Where `_resolve_synergy_xp_multiplier(synergy_id)` returns `ARCANE_ELITE_XP_MULT` (1.20) for `synergy_id == "arcane_elite"`, else `1.0`.

### C.4 — Audio + visual feedback (cozy register)

**Audio** (per `audio-system.md` audit-cascade integration):
- On synergy detection at slot edit (live preview): emit `class_synergy_detected_signal(synergy_id: String)`. AudioRouter subscribes; routes to `sfx_class_synergy_detected` cue. Per `audio-system.md` §F throttle, the cue suppresses re-fires within 2.0 s (suppress_window_seconds tuning knob below) so rapid slot toggles don't spam.
- On dispatch with active synergy: emit `class_synergy_dispatched_signal(synergy_id, run_id)`. AudioRouter routes to `sfx_class_synergy_dispatched` — a single warm sting at run start. NOT looped.
- No mid-run audio. The synergy is established at dispatch; the player has already "felt" it in the live preview.

**Visual** (per `formation-assignment-system.md` UX patterns):
- The formation panel shows a synergy badge (Label + small icon) when a synergy is active. Theme variation: `class_synergy_badge_active` (parchment + lantern-amber per Art Bible Visual Identity Anchor).
- During DungeonRunOrchestrator's RUN_STARTED state, `dungeon_run_view.tscn` shows the synergy display name + effect summary as a top-bar subtitle for the first 3.0 s of the run, then fades. Player has time to read it once.
- No popups. No modals. No fanfare animation. The synergy is a quiet bonus.

### C.5 — V1.0+ extension hooks (forward-looking)

The first-pass GDD is bounded to 3 composition synergies. The system is designed so V1.0+ can extend without schema migration:

- **More synergies**: appendable to the synergy roster table (C.1) without changing the formula in C.3 — `_resolve_synergy_*_multiplier` is a switch over `synergy_id`. New synergies = new switch arms.
- **Tier synergies / level synergies / identity synergies** (OQ-32-1 deferred items): same detection + effect surface; the `detect_active_synergy` function expands to check tier/level/identity criteria alongside composition. The `RunSnapshot.synergy_id` field is forward-compat.
- **Additive synergies** (OQ-32-2 deferred): if a future synergy is best expressed additively, the formula in C.3 can extend with a `+ flat_bonus` term gated by synergy_id. V1.0+ design call.
- **Synergy unlock cadence** (OQ-32-4 deferred): if V1.5+ wants to gate synergies behind first-clear or prestige, add a `_synergy_is_unlocked(synergy_id) -> bool` predicate at detection time. Backward-compatible — V1.0 always returns true.
- **Cross-system "RunModifier" abstraction** (OQ-32-8): when a third multiplier source (e.g., buff/debuff system) emerges, refactor the four-multiplier formula into a `RunModifier` aggregator. Until then, four explicit factors is clearer than premature abstraction.

### C.6 — V2 Tier Ladder (Sprint 24 S24-M1)

The V1.0 detection surface returns a `synergy_id` string ("steel_wall" / "arcane_elite" / "triple_strike" / "triple_threat" / ""). The **V2 Tier Ladder** layer maps that detection result into a categorical tier (None / Bronze / Silver / Gold / Platinum) for player-facing display surfaces (Dispatch SynergyPreviewLabel; future Guild Hall synergy summary; future toast / cue variants).

**Tier mapping (V1 → V2 first-pass)**:

| Tier | Synergy IDs (V1) | Rationale | Locale key |
|------|------------------|-----------|------------|
| **None** | `""` (no detection) | No matching composition. Cozy degrade — render `"Synergy: None"` rather than hiding. | `synergy_tier_none` → "None" |
| **Bronze** | (reserved for V2.5+) | Future: 2-of-a-kind without matching counter archetype. Documented for V2 GDD expansion; not yet emitted by `detect_active_synergy`. | `synergy_tier_bronze` → "Bronze" |
| **Silver** | (reserved for V2.5+) | Future: 2-of-a-kind WITH matching counter archetype (the partial-mono-class pattern that teaches matchup awareness without requiring 3-of-a-kind commitment). Not yet emitted. | `synergy_tier_silver` → "Silver" |
| **Gold** | `steel_wall`, `arcane_elite`, `triple_strike` | 3-of-a-kind mono-class synergies. The current V1 first-pass mono-class roster. Strong but specialized (Steel Wall/Triple Strike conditional on archetype; Arcane Elite unconditional XP). | `synergy_tier_gold` → "Gold" |
| **Platinum** | `triple_threat` | 1+1+1 balanced composition. Highest categorical tier because it represents full class-diversity coverage (unlocks every counter-archetype matchup simultaneously). Lower numerical bonus (+15% gold) but unconditional — the "balanced excellence" beat. | `synergy_tier_platinum` → "Platinum" |

**Tier-mapping function**:

```gdscript
# Returns the V2 tier name (lowercase enum string) for a V1 synergy_id.
# Pure function — safe to call every UI refresh. O(1) string switch.
static func synergy_id_to_tier(synergy_id: String) -> String:
    match synergy_id:
        "":               return "none"
        "steel_wall":     return "gold"
        "arcane_elite":   return "gold"
        "triple_strike":  return "gold"
        "triple_threat":  return "platinum"
        _:                return "none"  # defensive: unknown synergy_id degrades to None
```

**Why "Gold" for 3-mono-class and "Platinum" for 1+1+1**:

The temptation is to read tier as a strict numerical-bonus ranking (which would put Steel Wall's +25% above Triple Threat's +15%). The V2 categorical reading is intentionally different: tier represents **composition versatility**, not raw multiplier strength. Mono-class compositions are *strong-but-narrow* (one matchup window, deep specialty). 1+1+1 is *balanced-and-universal* (every matchup covered, broader applicability). Platinum names the latter as the "completeness" tier — matching the cozy-register design ethos that rewards diverse compositions, not min-maxing the highest-yield mono.

This split also future-proofs the tier ladder. Once V2.5+ adds Silver (2-of-a-kind with counter) and Bronze (2-of-a-kind without counter), the ladder reads cleanly:
- **None** = no detection
- **Bronze** = partial composition, no archetype counter
- **Silver** = partial composition with archetype counter
- **Gold** = full mono-class (any of 3 MVP variants)
- **Platinum** = balanced 1+1+1

Each tier teaches a distinct lesson: Bronze ("you need more of these"), Silver ("you're using their counter wisely"), Gold ("you committed; here's the mono-class payoff"), Platinum ("you balanced; here's the universal payoff").

**UI render surface (V2 first-pass scope = SynergyPreviewLabel only)**:

The Dispatch screen's `SynergyPreviewLabel` (added in Sprint 23 S23-N2) is the first consumer of the tier ladder. S24-M2 refreshes the label format from:

```
Synergy: {display_name}            (V1 first-pass — Sprint 23 S23-N2)
```

to:

```
Synergy: {tier} ({display_name})   (V2 first-pass — Sprint 24 S24-M2)
```

Examples:
- Empty composition → `Synergy: None`
- 3 warriors → `Synergy: Gold (Steel Wall)`
- 1+1+1 → `Synergy: Platinum (Triple Threat)`

The cozy `SynergyBadge` (animated detection-moment glow on Guild Hall + Dispatch) is unchanged in S24-M2 — it remains the *active cue* tied to the specific synergy_id, while the preview label is the *passive read* tied to the tier ladder. Future tier-coloring + iconography (per Sprint 25+ scope) will introduce per-tier visual treatment (Gold/Platinum medal icons, color-coded backgrounds matching the parchment palette).

**Acceptance criteria deferred to AC-CS-22+** (added in Sprint 24 S24-M1 implementation pass, not in this design amendment). The detection-accuracy ACs (AC-CS-01..05) remain authoritative for V1 detection; the V2 layer adds:
- AC-CS-22 — `synergy_id_to_tier("")` returns `"none"`
- AC-CS-23 — `synergy_id_to_tier("steel_wall")` returns `"gold"` (and `"arcane_elite"` + `"triple_strike"` likewise)
- AC-CS-24 — `synergy_id_to_tier("triple_threat")` returns `"platinum"`
- AC-CS-25 — `synergy_id_to_tier("<unknown_synergy>")` returns `"none"` (defensive)
- AC-CS-26 — SynergyPreviewLabel renders `"Synergy: {tier} ({display_name})"` per the V2 format

These ACs are referenced by S24-M2's test suite (`tests/unit/formation_assignment/synergy_preview_label_test.gd`).

---

## D. Formulas

### D.1 — Synergy detection predicate

```
detect_active_synergy(formation: FormationSnapshot) -> String:
    var class_ids: Array[String] = []
    for instance_id in formation.instance_ids:
        if instance_id == 0:
            return ""  # Empty slot — no synergy possible
        var hero: HeroInstance = HeroRoster.get_hero(instance_id)
        class_ids.append(hero.class_id)
    class_ids.sort()  # Sort for canonical multiset comparison

    if class_ids == ["mage", "mage", "mage"]:
        return "arcane_elite"
    if class_ids == ["warrior", "warrior", "warrior"]:
        return "steel_wall"
    if class_ids == ["rogue", "rogue", "rogue"]:
        return "triple_strike"
    if class_ids == ["mage", "rogue", "warrior"]:  # sorted alphabetically
        return "triple_threat"
    return ""
```

**Variable definitions**:
- `formation`: the FormationSnapshot from `formation-assignment-system.md` §C — frozen at dispatch.
- `instance_ids`: the 3-slot array (length always 3; FORMATION_SIZE per `hero-roster.md` §C.10).
- `class_ids`: derived multiset of class identifiers.

**Expected output range**: `""`, `"steel_wall"`, `"arcane_elite"`, `"triple_threat"`.

**Example**: formation = `[Theron(warrior, lvl 5), Mira(mage, lvl 3), unrecruited(rogue, lvl 1)]` → class_ids sorted = `["mage", "rogue", "warrior"]` → returns `"triple_threat"`.

### D.2 — Gold multiplier resolution

```
_resolve_synergy_gold_multiplier(synergy_id: String, archetype: String) -> float:
    if synergy_id == "":
        return 1.0
    if synergy_id == "steel_wall":
        return STEEL_WALL_GOLD_MULT if archetype == "bruiser" else 1.0
    if synergy_id == "triple_strike":
        return TRIPLE_STRIKE_GOLD_MULT if archetype == "armored" else 1.0
    if synergy_id == "triple_threat":
        return TRIPLE_THREAT_GOLD_MULT  # Unconditional
    # arcane_elite affects XP only; gold is baseline
    return 1.0
```

**Constants** (defined in `EconomyConfig.tres` per `economy-system.md` §G):
- `STEEL_WALL_GOLD_MULT: float = 1.25` (safe range 1.0–1.5)
- `TRIPLE_STRIKE_GOLD_MULT: float = 1.25` (safe range 1.0–1.5)
- `TRIPLE_THREAT_GOLD_MULT: float = 1.15` (safe range 1.0–1.5)

### D.3 — XP multiplier resolution

```
_resolve_synergy_xp_multiplier(synergy_id: String) -> float:
    if synergy_id == "":
        return 1.0
    if synergy_id == "arcane_elite":
        return ARCANE_ELITE_XP_MULT  # Unconditional
    return 1.0
```

**Constants**:
- `ARCANE_ELITE_XP_MULT: float = 1.20` (safe range 1.0–1.5)
- `BASE_XP_PER_KILL: int = 10` (per Hero Leveling GDD #15 §D — V1.0 introduces; MVP ships with stub +1-per-clear per S10-M4)

### D.4 — Worked example (composition + advantaged + losing run + Steel Wall + bruiser kill)

Player dispatches 3 Warriors against Forest Reach Floor 3, formation gets advantaged matchup (+1.5x via MATCHUP_GOLD_MULTIPLIER per `class-vs-enemy-matchup-resolver.md`), but the run is LOSING (×0.5 LOSING_RUN_LOOT_FACTOR per ADR-0002), and a Tier-2 Bruiser is killed.

```
BASE_KILL[2] = 25  # per economy_config.tres
matchup_multiplier = 1.5  # advantaged
loot_factor = 0.5  # losing run
synergy_multiplier = 1.25  # Steel Wall + bruiser

result = floori(25 × 1.5 × 0.5 × 1.25)
       = floori(23.4375)
       = 23
```

Same scenario but the kill is a Skirmisher (not Bruiser): synergy_multiplier collapses to 1.0; gold = `floori(25 × 1.5 × 0.5 × 1.0) = 18`. The Steel Wall bonus is +5 gold per bruiser kill in this scenario — ~28% effective reward over the non-synergy path on average bruiser-frequency floors.

---

## E. Edge Cases

1. **Empty formation slot during live preview**: `detect_active_synergy` returns `""` if any `instance_id == 0`. The synergy badge hides. No partial-synergy detection (all 3 slots must be filled).

2. **Duplicate hero in two slots**: HeroRoster's slot-mutation contract (`hero-roster.md` §C.5 set_formation_slot) auto-clears duplicates. Synergy detection runs on the post-clear formation. If the auto-clear results in a slot becoming empty, edge case 1 applies (synergy hides).

3. **Synergy active at dispatch, formation edited mid-run**: per ADR-0001 mid-run reassignment, the run's `synergy_id` is snapshotted at dispatch and is IMMUTABLE for the run's duration. The mid-run reassignment changes the run's hero list but does NOT recompute the synergy. The player can tap the synergy badge after a mid-run edit to reveal a "synergy persists from dispatch" disclosure (touch-first per `technical-preferences.md` Input section — no hover-only interactions; mobile + Steam Deck parity).

4. **Hero leveling mid-run**: synergies are composition-based, not level-based. A hero leveling up mid-run does NOT change the active synergy.

5. **Hero recruited/removed during run**: Recruitment is gated outside an active run (recruit_screen is not accessible during ACTIVE_FOREGROUND). N/A in V1.0 scope; if V1.5 lifts that gate, the snapshot-at-dispatch invariant in C.2 covers it.

6. **Save/load round-trip**: `RunSnapshot.synergy_id` persists in the active-run save namespace per `save-load-system.md` Story 016 round-trip contract. On load, the run resumes with the same synergy active. The hero list might have changed via roster orphan-recovery (ADR-0014 §2.3); the synergy_id stays as snapshotted (does NOT recompute against the post-recovery formation — that would violate the dispatch-time snapshot invariant).

7. **Save migration adds new synergy**: V1.5 ships a 4th synergy ("Veteran Squad" — 3 Tier-1). Existing saves with `synergy_id == "old_id_no_longer_valid"` are tolerated — the resolver returns 1.0 for unknown synergy_ids (forward-compat fallback). No save migration required per `save-load-system.md` schema-version contract.

8. **Audio cue suppression on rapid slot toggling**: the `class_synergy_detected_signal` fires on every slot edit. `audio-system.md`'s 2.0 s throttle prevents the cue from playing more than once per `suppress_window_seconds` window. Rapid toggling (player swapping heroes 5x/sec) plays the chime once.

9. **Reduce-motion accessibility flag**: per `scene-screen-manager.md` Story 009 reduce_motion support (user-toggleable per `settings-options-accessibility.md`), the formation panel's synergy-badge glow animation is suppressed (badge appears instantly without fade) when `reduce_motion = true`. The dispatch-time top-bar subtitle persists for the full 3.0 s (it's text, not motion).

10. **Localization (tr() of synergy display name + effect text)**: all player-facing synergy strings route through `tr()` per `ADR-0008` localization-ready rule. Locale CSV keys: `class_synergy_badge_steel_wall`, `class_synergy_badge_arcane_elite`, `class_synergy_badge_triple_strike`, `class_synergy_badge_triple_threat`, `class_synergy_effect_steel_wall`, `class_synergy_effect_arcane_elite`, `class_synergy_effect_triple_strike`, `class_synergy_effect_triple_threat`. Eight new keys total for V1.0 ship.

11. **Player has only Theron (1 Warrior) + auto-fills slots 2,3 from recruit pool**: until the player has 3 of any class OR a 1+1+1 mix recruited, NO synergy can activate. The player runs baseline formations; the synergy system is silent. Discovery happens naturally as the recruit pool deepens. This is the cozy register working as intended (no synergy unlock pressure).

12. **Class balance regression: synergy makes 3-Warrior dominant**: monitored via balance regression tests (see ACs below). If post-V1.0 playtest data shows >70% of dispatches use 3-Warrior, retune `STEEL_WALL_GOLD_MULT` down (from 1.25 → 1.20 → 1.15 etc.) until variance restored. Tuning is data-driven; the GDD's safe range (1.0–1.5) gives 5 levels of headroom.

---

## F. Dependencies

### F.1 Forward dependencies (Class Synergy depends on these)

| System | Why | Surface used |
|---|---|---|
| **Hero Roster** (#9) | Hero class_id source for detection | `HeroRoster.get_hero(instance_id) -> HeroInstance` (existing); `HeroInstance.class_id: String` (existing schema field) |
| **Formation Assignment** (#17) | Detection trigger point + live-preview UI host | New: `FormationAssignment.detect_active_synergy(snapshot) -> String` (V1.0 epic adds). Existing `formation-assignment-system.md` UX patterns reused for badge display. |
| **DungeonRunOrchestrator** (#13) | Dispatch-time snapshot + per-kill multiplier application | New: `DungeonRunOrchestrator.snapshot_synergy_for_run(snapshot) -> void` adds `synergy_id` to RunSnapshot. `attribute_kill_gold` formula extends with `synergy_multiplier` factor (D.2). New `attribute_kill_xp` formula (D.3). |
| **Hero Class Database** (#6) | class_id stable identifiers | `class_id` strings ("warrior", "mage", "rogue") match existing class_id schema in `assets/data/classes/*.tres` (verified via `class-vs-enemy-matchup-resolver.md` §F dependency surface). |
| **Class-vs-Enemy Matchup Resolver** (#10) | Archetype string source for Steel Wall conditional | `MatchupResolver.archetype_for_enemy(enemy_id) -> String` (existing); the resolver returns archetype strings ("bruiser", "skirmisher", etc.) that Steel Wall conditions on. |
| **Combat Resolution** (#11) | Per-kill output channel where synergy_multiplier applies | `attribute_kill_gold` extension is owned by Orchestrator #13 (per `dungeon-run-orchestrator.md` §D.1); Combat Resolution provides the per-kill schedule. |
| **Economy** (#5) | Gold credit destination + synergy constants location | `Economy.add_gold(amount)` (existing) consumes the synergy-modified output. `EconomyConfig.tres` hosts `STEEL_WALL_GOLD_MULT`, `TRIPLE_THREAT_GOLD_MULT`, `ARCANE_ELITE_XP_MULT`, `BASE_XP_PER_KILL`. |
| **Hero Leveling** (#15) | XP credit destination for Arcane Elite | New: `HeroRoster.add_xp(instance_id, xp_amount)` (V1.0 introduces per Hero Leveling §D — MVP ships with stub +1-per-clear via S10-M4). Arcane Elite's `synergy_multiplier` applies before this call. |
| **Save/Load System** (#3) | RunSnapshot persistence for `synergy_id` | `RunSnapshot.synergy_id: String` is added to the orchestrator save namespace per `save-load-system.md` Story 016. Forward-compat: missing field on load defaults to `""` (no migration required). |
| **Audio System** (#28) | Synergy detection + dispatch cues | New cues: `sfx_class_synergy_detected`, `sfx_class_synergy_dispatched`. AudioRouter subscribes to two new signals declared on FormationAssignment + DungeonRunOrchestrator. Per `audio-system.md` §F throttle (`suppress_window_seconds = 2.0`). |
| **Scene/Screen Manager** (#4) | reduce_motion flag honoring (badge glow suppression) | `SceneManager.reduce_motion: bool` (existing per Story 009; canonical doc `scene-screen-manager.md`; user-facing toggle defined in `settings-options-accessibility.md`). FormationAssignment screen reads this on theme variation selection. |
| **Locale Loader** (S9-M3 LocaleLoader autoload) | tr() string resolution for 6 new synergy keys | `assets/locale/en.csv` adds 6 keys per E.10. No code change to LocaleLoader. |

### F.2 Reverse dependencies (these systems consume Class Synergy)

| System | Consumed surface | Why |
|---|---|---|
| **Formation Assignment Screen** (#17) | `detect_active_synergy(snapshot)` + synergy badge UI | Live preview during slot edit |
| **Dungeon Run View** (#24) | `RunSnapshot.synergy_id` + display-name + effect text | Top-bar subtitle for first 3.0 s of run |
| **Recruit Screen** (#21) | "if you recruit this, you'll have N Mages → Arcane Elite unlocks" preview | V1.0+ extension; deferred to OQ-32-5 |
| **Roster / Hero Detail Modal** (#22) | "this hero appears in N synergies" hint | V1.0+ extension; deferred to OQ-32-5 |
| **Matchup Assignment Screen** (#23) | Steel Wall + biome dominant_archetype combined hint | V1.0+ extension; deferred to OQ-32-5 |
| **Audio Router** (#28) | Two new cue triggers | Synergy detection + dispatch chimes |

### F.3 Bidirectional confirmation

Per CLAUDE.md design-doc rules (`design-docs.md`): "Dependencies must be bidirectional — if system A depends on B, B's doc must mention A."

The following GDDs need 2026-05-09 amendments to acknowledge Class Synergy as a consumer:
- `formation-assignment-system.md` — add Class Synergy #32 to F (consumers; live preview hosting)
- `dungeon-run-orchestrator.md` — add Class Synergy #32 to F (consumer; RunSnapshot.synergy_id field + per-kill multiplier extension)
- `economy-system.md` — add Class Synergy #32 to F (consumer; STEEL_WALL_GOLD_MULT + TRIPLE_THREAT_GOLD_MULT + ARCANE_ELITE_XP_MULT + BASE_XP_PER_KILL constants)
- `hero-leveling.md` — add Class Synergy #32 to F (consumer; XP multiplier path)
- `save-load-system.md` — add Class Synergy #32 to F.consumers (consumer; RunSnapshot.synergy_id namespacing)
- `audio-system.md` — add Class Synergy #32 to F (consumer; 2 new cues)
- `class-vs-enemy-matchup-resolver.md` — add Class Synergy #32 to F (consumer; archetype string source)
- `hero-class-database.md` — add Class Synergy #32 to F (consumer; class_id stable identifiers)

These cross-GDD amendments are scheduled **inside Sprint 18 S18-M2** as a precondition to implementation work (one batch commit appending a "Class Synergy #32 — consumer of <surface>" entry to each consumer GDD's F.2 / consumers section). Per CLAUDE.md design-doc rules: dependencies must be bidirectional at amend-time. Prior plan had deferred this to Sprint 21+; revised 2026-05-14 review pass to fold the amendments into the live implementation sprint so the bidirectional rule holds when ClassSynergySystem.gd lands.

---

## G. Tuning Knobs

All knobs live in `assets/data/economy/economy_config.tres` (existing per `economy-system.md` §G). Designer-overridable without code changes; all are constrained to safe ranges.

| Knob | Type | Default | Safe Range | Affects |
|---|---|---|---|---|
| `STEEL_WALL_GOLD_MULT` | float | 1.25 | 1.0 – 1.5 | Steel Wall's bruiser-conditional gold bonus. >1.5 risks dominant 3-Warrior strategy per E.12 anti-frustration. |
| `TRIPLE_STRIKE_GOLD_MULT` | float | 1.25 | 1.0 – 1.5 | Triple Strike's armored-conditional gold bonus. Structurally parallel to Steel Wall (same default + safe range); tune in lockstep unless playtest data signals an asymmetric balance need. |
| `TRIPLE_THREAT_GOLD_MULT` | float | 1.15 | 1.0 – 1.5 | Triple Threat's unconditional gold bonus. Lower than mono-class conditional caps by design (unconditional vs conditional). |
| `ARCANE_ELITE_XP_MULT` | float | 1.20 | 1.0 – 1.5 | Arcane Elite's XP bonus across all kills. >1.5 risks "level-cap rush" dominant strategy. |
| `BASE_XP_PER_KILL` | int | 10 | 5 – 50 | Hero Leveling V1.0 base XP per tier-1 kill. Multiplied by tier in `attribute_kill_xp`. |
| `audio_suppress_window_seconds` (re-uses audio-system) | float | 2.0 | 0.5 – 5.0 | Throttle window for the `sfx_class_synergy_detected` cue. **Owned by `audio-system.md` §F** — Class Synergy does NOT introduce a separate synergy-specific knob. The audio system's per-cue throttle is the single source of truth. Listed here for designer-tuning visibility only. |
| `class_synergy_dispatch_subtitle_duration_seconds` | float | 3.0 | 1.5 – 5.0 | How long the dispatch-time top-bar subtitle stays visible at run start. |
| `class_synergy_badge_glow_duration_seconds` | float | 0.4 | 0.1 – 1.0 | Formation panel badge glow animation length. Suppressed entirely when `SceneManager.reduce_motion = true`. |

**Designer-tuning workflow**: change values in `economy_config.tres` via the Godot editor's Inspector; no code changes; tests pick up the new constants on next run via DataRegistry resolution. No save migration required (constants are per-build, not persisted per-save).

---

## H. Acceptance Criteria

All ACs are V1.0 implementation-targets (not MVP). They become BLOCKING on the V1.0 Class Synergy implementation epic; until then, the system ships with synergy_multiplier = 1.0 hardcoded (no synergies active).

### AC-CS-01 — Detection accuracy: 3-Warrior formation returns "steel_wall"
**Given**: HeroRoster contains 3 Warriors at formation slots 0/1/2.
**When**: `FormationAssignment.detect_active_synergy(snapshot)` runs.
**Then**: returns `"steel_wall"`. Order of slots does NOT matter (sort-based comparison per D.1).

### AC-CS-02 — Detection accuracy: 3-Mage formation returns "arcane_elite"
**Given**: HeroRoster contains 3 Mages at formation slots 0/1/2.
**When**: `detect_active_synergy(snapshot)` runs.
**Then**: returns `"arcane_elite"`.

### AC-CS-03 — Detection accuracy: 1+1+1 mix returns "triple_threat"
**Given**: formation = `[Warrior, Mage, Rogue]` in any order.
**When**: `detect_active_synergy(snapshot)` runs.
**Then**: returns `"triple_threat"`.

### AC-CS-04 — Detection accuracy: 2+1 mix returns ""
**Given**: formation = `[Warrior, Warrior, Mage]`.
**When**: `detect_active_synergy(snapshot)` runs.
**Then**: returns `""` (empty — no synergy active for 2+1 compositions in V1.0 first-pass).

### AC-CS-05 — Detection accuracy: empty slot returns ""
**Given**: formation has any `instance_id == 0` (empty slot).
**When**: `detect_active_synergy(snapshot)` runs.
**Then**: returns `""` regardless of the other 2 slots' classes.

### AC-CS-06 — Steel Wall conditional gold: bruiser kill applies multiplier
**Given**: RunSnapshot.synergy_id = "steel_wall"; tier-1 bruiser killed; matchup advantaged; not losing.
**When**: `attribute_kill_gold(1, true, false, "steel_wall", "bruiser")` runs.
**Then**: returns `floori(BASE_KILL[1] × 1.5 × 1.0 × 1.25)` (e.g., `floori(10 × 1.5 × 1.25) = 18`).

### AC-CS-07 — Steel Wall conditional gold: skirmisher kill does NOT apply multiplier
**Given**: same as AC-CS-06 except archetype = "skirmisher".
**When**: `attribute_kill_gold(1, true, false, "steel_wall", "skirmisher")` runs.
**Then**: returns `floori(BASE_KILL[1] × 1.5 × 1.0 × 1.0)` (e.g., 15). Steel Wall does NOT apply to non-bruiser kills.

### AC-CS-08 — Triple Threat unconditional gold: every kill gets multiplier
**Given**: synergy_id = "triple_threat"; any tier; any archetype; any matchup.
**When**: `attribute_kill_gold` runs.
**Then**: synergy_multiplier = 1.15 applied unconditionally.

### AC-CS-09 — Arcane Elite gold pathway: NOT affected
**Given**: synergy_id = "arcane_elite"; any tier; any archetype.
**When**: `attribute_kill_gold` runs.
**Then**: synergy_multiplier = 1.0 (Arcane Elite affects XP only, not gold). Verified by parity test against the no-synergy gold output.

### AC-CS-10 — Arcane Elite XP pathway: 1.20× multiplier applied
**Given**: synergy_id = "arcane_elite"; tier-2 kill.
**When**: `attribute_kill_xp(2, "arcane_elite")` runs.
**Then**: returns `floori(BASE_XP_PER_KILL × 2 × 1.20)` (e.g., `floori(10 × 2 × 1.20) = 24`).

### AC-CS-11 — No synergy: baseline gold + XP unchanged
**Given**: synergy_id = ""; any tier; any archetype.
**When**: `attribute_kill_gold` and `attribute_kill_xp` run.
**Then**: gold = baseline (no synergy multiplier); XP = baseline. Functionally MVP-identical for synergy_id="".

### AC-CS-12 — Save/load round-trip: synergy_id persists across launch
**Given**: active run with `RunSnapshot.synergy_id = "steel_wall"`; persist; reload.
**When**: load completes; orchestrator's `RunSnapshot.synergy_id` is read.
**Then**: equals `"steel_wall"` (verbatim string preservation per JSON round-trip; project memory `project_json_int_round_trip_typeof_pattern` doesn't apply since this is a String, not int).

### AC-CS-13 — Mid-run reassignment does NOT change active synergy
**Given**: dispatch with synergy_id = "steel_wall"; mid-run, player reassigns one slot from Warrior to Mage (formation now has 2W+1M; would NOT pass detection if recomputed).
**When**: orchestrator continues processing the run.
**Then**: `RunSnapshot.synergy_id` stays `"steel_wall"` for the rest of the run. Subsequent kills against bruisers still get the +25% bonus. ADR-0001 mid-run reassignment policy honored.

### AC-CS-14 — Audio cue suppression: rapid slot toggle plays chime once
**Given**: player rapidly swaps heroes such that `class_synergy_detected_signal` fires 5 times within 1.0 s.
**When**: AudioRouter processes the signal stream.
**Then**: `sfx_class_synergy_detected` plays once (per `audio-system.md` §F suppress_window_seconds = 2.0). Subsequent emissions within the window are throttled.

### AC-CS-15 — Localization: all 8 synergy strings route through `tr()`
**Given**: locale loader has English keys loaded.
**When**: synergy badge + effect summary render.
**Then**: text comes from `tr("class_synergy_badge_<id>")` + `tr("class_synergy_effect_<id>")` calls for all four synergies (steel_wall, arcane_elite, triple_strike, triple_threat — 8 keys total); CI grep enforces no hardcoded synergy display names anywhere in `assets/screens/formation_assignment/` or `assets/screens/dungeon_run_view/`.

### AC-CS-16 — Cozy-register hard floor: no PER-SYNERGY multiplier exceeds +50%
**Given**: any tuned configuration of all four synergy multipliers.
**When**: `_resolve_synergy_*_multiplier` returns a value.
**Then**: value is ≤ 1.5. Static-analysis CI test asserts that `STEEL_WALL_GOLD_MULT`, `TRIPLE_STRIKE_GOLD_MULT`, `TRIPLE_THREAT_GOLD_MULT`, `ARCANE_ELITE_XP_MULT` are all ≤ 1.5 in `economy_config.tres`. Per OQ-32-6 cozy register hard floor.

> **Scope clarification**: the ≤+50% floor is **per-synergy**, not compound. The full per-kill product (BASE_KILL × matchup_mult × loot_factor × synergy_mult × prestige_mult — see J cross-system table) can legitimately exceed +50% over baseline; that compound product is bounded by each factor's own cap, not by AC-CS-16. Future synergies must be compared against the per-synergy 1.5 ceiling, never against the compound peak.

### AC-CS-17 — Reduce-motion: badge glow animation suppressed
**Given**: `SceneManager.reduce_motion = true`; synergy detected on slot edit.
**When**: formation panel updates the badge.
**Then**: badge appears at full alpha instantly (no glow tween). Theme variation `class_synergy_badge_active_reduced_motion` used in lieu of the animated variant.

### AC-CS-18 — V1.5 forward-compat: unknown synergy_id falls back to 1.0
**Given**: a save loaded with `RunSnapshot.synergy_id = "veteran_squad"` (a hypothetical V1.5 synergy not in V1.0 first-pass).
**When**: V1.0 build's `_resolve_synergy_gold_multiplier("veteran_squad", ...)` runs.
**Then**: returns 1.0 (unknown synergy_id falls through to default). NO crash, NO push_error. Forward-compat saves are gracefully degraded.

### AC-CS-19 — Balance regression test: no mono-class composition dominates
**Given**: 100 simulated runs with random formations across the 10 possible 3-class compositions.
**When**: gold output is aggregated per composition.
**Then**: NO single mono-class composition (3-Warrior, 3-Mage, or 3-Rogue) has an average gold output more than 30% above the mean across all compositions — anti-frustration check per E.12. If 3-Warrior dominance triggers, retune `STEEL_WALL_GOLD_MULT` down. If 3-Rogue dominance triggers, retune `TRIPLE_STRIKE_GOLD_MULT` down. Per Tuning Knobs G safe ranges.

### AC-CS-20 — Performance: detection runs in <1ms p99
**Given**: any FormationSnapshot.
**When**: `detect_active_synergy(snapshot)` runs 10 000 times.
**Then**: p99 latency < 1 ms (function is pure + O(1); the 3-element sort is trivial). Required because detection runs every slot edit in the live-preview path.

### AC-CS-21 — Detection accuracy: 3-Rogue formation returns "triple_strike"
**Given**: HeroRoster contains 3 Rogues at formation slots 0/1/2.
**When**: `detect_active_synergy(snapshot)` runs.
**Then**: returns `"triple_strike"`. Order of slots does NOT matter (sort-based comparison per D.1).

### AC-CS-22 — Triple Strike conditional gold: armored kill applies multiplier
**Given**: RunSnapshot.synergy_id = "triple_strike"; tier-1 armored kill; matchup advantaged; not losing.
**When**: `attribute_kill_gold(1, true, false, "triple_strike", "armored")` runs.
**Then**: returns `floori(BASE_KILL[1] × 1.5 × 1.0 × 1.25)` (e.g., `floori(10 × 1.5 × 1.25) = 18`). Parallel to AC-CS-06 (Steel Wall vs bruiser).

### AC-CS-23 — Triple Strike conditional gold: non-armored kill does NOT apply multiplier
**Given**: same as AC-CS-22 except archetype = "skirmisher" (or any non-armored archetype).
**When**: `attribute_kill_gold(1, true, false, "triple_strike", "skirmisher")` runs.
**Then**: returns `floori(BASE_KILL[1] × 1.5 × 1.0 × 1.0)` (e.g., 15). Triple Strike does NOT apply to non-armored kills. Parallel to AC-CS-07 (Steel Wall vs skirmisher).

---

## I. Open Questions (V1.0+ design block)

Resolved in this first-pass:
- **OQ-32-1** (synergy taxonomy): RESOLVED — composition synergies only in V1.0 first-pass. Tier/level/identity synergies deferred to V1.0+ extension.
- **OQ-32-2** (effect type): RESOLVED — multiplicative only.
- **OQ-32-3** (detection timing): RESOLVED — both live preview + dispatch-time confirmation.
- **OQ-32-4** (unlock cadence): RESOLVED — all synergies always-available.
- **OQ-32-5** (display rules): RESOLVED for formation_assignment + dungeon_run_view. Recruit/Roster/Matchup display surfaces deferred to a V1.0+ UX iteration.
- **OQ-32-6** (anti-frustration ≤+50% cap): RESOLVED — multipliers capped at +50% (1.5x). Current first-pass values use ≤+25% (well under the cap). AC-CS-16 enforces.

Remaining open:
- **OQ-32-7** (full-pass GDD timing): RESOLVED by this draft. The GDD is now first-pass; the V1.5+ extension layer (additional synergies, additive effects, unlock cadence) has its own design block when V1.5 begins.
- **OQ-32-8** (RunModifier cross-GDD abstraction): DEFERRED. The 4-factor multiplicative formula in D.2 is explicit and clear; a "RunModifier" aggregator becomes ADR-worthy when a third multiplier source emerges (e.g., V1.5 buff/debuff system). No design action this pass.
- **OQ-32-9 (NEW)** — synergy implementation epic scope: this GDD's V1.0 implementation epic should ship as a single epic spanning Formation Assignment screen UI work + Orchestrator formula extension + Audio integration + Save/Load round-trip + 20 ACs above. Estimate: 4-5 stories, ~3-4 sprints of work post-MVP-launch. Refine when MVP-launch milestone defines the V1.0 sequencing.
- **OQ-32-10 (NEW)** — RecruitScreen "synergy preview" surface: when player browses the recruit pool, should the screen show "this hero unlocks synergy X" hints? Cozy register favors discovery (don't pre-spoil); but accessibility favors surface-the-rules. Resolution: V1.0+ UX pass; recommend hiding by default with an accessibility-toggle to opt-in.

---

## J. Cross-System Cross-Reference

Class Synergy is one of two V1.0 progression layers; pairs with Prestige #31. Both ship together in the V1.0 release block.

| Cross-system | Direction | Why |
|---|---|---|
| **Prestige #31** | V1.0 sibling | Per OQ-32-4, prestige does NOT gate synergy unlocks (cozy register). But prestige's permanent multipliers stack multiplicatively with synergy multipliers — a prestiged player running Steel Wall sees `prestige_mult × synergy_mult × matchup_mult × loot_factor × BASE_KILL`. The 5-factor product stays well-bounded under cozy register caps. |
| **Hero Leveling #15** | Forward dep | Arcane Elite XP path requires `BASE_XP_PER_KILL` (V1.0 introduces). MVP's stub +1-per-clear (S10-M4) is replaced when V1.0 Hero Leveling lands. |
| **Recruit Screen #21** | Reverse dep (deferred) | OQ-32-5 — synergy preview during recruit browse is V1.0+ UX. |
| **Combat Resolution #11** | Forward dep | Per-kill schedule is the data Class Synergy multiplies against. No schema change to Combat Resolution. |

---

## Notes

- First-pass GDD authored 2026-05-09 by Sprint 19 S19-M3 autonomous-execution session. Promoted from STUB DRAFT 2026-05-07. All 8 required GDD sections present (A Overview, B Player Fantasy, C Detailed Rules, D Formulas, E Edge Cases, F Dependencies, G Tuning Knobs, H Acceptance Criteria). Supplemental sections I (Open Questions) + J (Cross-System Cross-Reference) included per existing GDD pattern.
- Awaiting `/design-review` for APPROVED status. Per Sprint 19 S19-M3 plan: "design pass is autonomous-doable; APPROVED verdict via /design-review is the user-gated portion." This draft expects 1-2 review cycles before APPROVED — typical for first-pass GDDs in this project (see hero-class-database, dungeon-run-orchestrator pass histories).
- Closes systems-index.md row 32 status from "STUB DRAFT 2026-05-07" → "FIRST-PASS DRAFT 2026-05-09 (pending /design-review)".
- Per CLAUDE.md design-doc rules, F.3 lists 8 GDDs that need bidirectional-dependency amendments to acknowledge Class Synergy as a consumer. Those edits are scheduled inside Sprint 18 S18-M2 (revised 2026-05-14 from the prior Sprint 21+ deferral; the bidirectional rule must hold at the moment ClassSynergySystem.gd lands).
- The 4 first-pass synergies were chosen for **legibility** (3-of-a-kind + 1+1+1 mix are the most discoverable composition rules) and **symmetric coverage**: one synergy per mono-class composition (3W → Steel Wall, 3M → Arcane Elite, 3R → Triple Strike) plus the 1+1+1 mix (Triple Threat). This gives every player the same discovery moment regardless of which class their recruit pool deepens into first. V1.5+ can add 2+1 mixes, tier-based synergies, and identity-based synergies as the design space expands.
- The cozy-register hard floor (≤+50% multiplier per OQ-32-6) is the load-bearing design constraint. AC-CS-16 enforces it via static analysis of `economy_config.tres`. Future synergies must respect this floor or the design is non-shippable per Pillar 2 (Cozy Pacing).
