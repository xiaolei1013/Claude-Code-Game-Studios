# Floor/Biome Unlock System GDD — Lantern Guild

> **GDD #16 in systems index** (Feature layer, MVP)
> **Status**: Pass-9 revised 2026-04-21 — in-GDD content APPROVED for MVP runtime behavior; **all cross-GDD blockers resolved 2026-04-21** (I.14 Save/Load #3 `save_file_path` knob; I.15 Orchestrator offline `floor_cleared_first_time.emit`). **Pass-PROBE-EXECUTED 2026-04-21 REOPENED I.11** — the §C.1 R3 designer-UI ProjectSettings pattern was empirically FALSIFIED on Godot 4.6.1 (the fourth consecutive wrong engine-idiom claim in this GDD's audit chain). The code-block pattern still works as a RUNTIME fallback (MVP unaffected), but the editor-surfaced-knob designer-UI story needs a `@tool`/EditorPlugin rewrite before V1.0 multi-biome authoring. Runtime fallback is sufficient for MVP single-biome play; designer-UI fix deferred to V1.0. See §I.11 Open Question + `docs/engine-reference/godot/modules/autoload.md` Claim 2 + Claim 3 empirical record.
> **Created**: 2026-04-20
> **Last Updated**: 2026-04-21 (Pass-9 — closes 6 NEW BLOCKING in-GDD + 9 CONCERN + 3 NICE; 3 user design decisions captured; 5 specialists; cross-pass surfacing rate dropped from 12→6 but not yet converged — third consecutive wrong engine-idiom claim (`PROPERTY_HINT_PLACEHOLDER_TEXT`) caught by 3-specialist cross-model convergence, confirming the I.11 per-pass engine-idiom-verification lesson)
> **Authors**: game-designer + systems-designer + main session
> **Depends on**: `design/gdd/biome-dungeon-database.md` (#8), `design/gdd/save-load-system.md` (#3)
> **Referenced by**: Dungeon Run Orchestrator (#13, APPROVED — AC-ORC-13 promotes ADVISORY → BLOCKING when this GDD lands), Formation Assignment (#17), Guild Hall Screen (#19), Matchup Assignment Screen (#23), Unlock/Victory Moment (#25)
> **Implements Pillar**: Pillar 1 (Respect the Player's Time — permanent unlocks, no regression) + Pillar 3 (gates the matchup-decision surface by controlling which floors are available for dispatch)
> **Creative Director Review (CD-GDD-ALIGN)**: SKIPPED — Solo review mode

---

## A. Overview

The Floor/Biome Unlock System is the persistent progression gate that answers *"which floors can the player dispatch a formation to right now?"* It sits between the static Biome/Dungeon Database (which defines *what content exists*) and the Dungeon Run Orchestrator (which decides *whether a specific dispatch is legal*). The system holds a single piece of durable state: for each biome, the highest floor_index the player has ever first-cleared — a monotonic integer that advances on any clear (WIN or LOSING; no fail state per Pillar 1) and is never rolled back. A fresh save starts with Forest Reach's F1 unlocked and nothing else; every other floor becomes available by clearing the one before it.

The system has a visible player-facing moment — the *"you just unlocked the next floor"* beat that the game concept flags as the MVP's core breakthrough emotion — but the rendering of that moment is owned by the Unlock/Victory Moment UI (#25). This GDD owns the **state transition** and the **access gate**; the UI GDD owns the **payoff presentation**. Similarly, the floor-clear gold idempotency gate (`Economy.floor_clear_bonus_credited`, per ADR-0002) is a **separate** layer that operates in parallel on the same first-clear event — Economy decides whether to pay out gold, this system decides whether the floor is henceforth accessible.

MVP scope is deliberately narrow: one active biome (Forest Reach), five floors, linear-within-biome unlock. Biome-level unlock is schema-ready but V1.0 content — the MVP simply treats the one `status: "active"` biome as unconditionally accessible and filters the four `planned_v1` stubs from all UI surfaces. The system closes the three-way dependency of Orchestrator → Biome DB → Save/Load: Orchestrator queries `is_unlocked(floor_index)` at DISPATCHING; Biome DB provides the floor catalog; Save/Load persists unlock state across sessions via the standard `get_save_data`/`load_save_data` consumer contract (Pass 4B-SaveLoad Rules 10–14).

## B. Player Fantasy

The core feeling this system authors is *territorial memory*. A cleared floor isn't a trophy — it's ground the guild has walked. The player opens Forest Reach and sees, at a glance, the shape of their progress: Floors 1 and 2 rendered in full color, their miniature dioramas populated with the little pixel-art creatures and lantern-posts the player has come to know; Floor 3, newly unlocked, rendered in the warmer, closer palette of *"this is where we are now"*; Floor 4 still a soft pencil sketch, inviting.

The promise underneath is quiet and absolute: *the ground you've walked stays walked*. Hard floors don't punish a tired return with lost progress. A losing first-clear still advances the lantern, because the guild was *present* there — and presence, in Lantern Guild, is what counts. This honors Pillar 1 at its most emotional register: the game is never waiting to take something from you. It only ever hands you a little more of the forest. The curation fantasy — *"my roster earned this map"* — is the quiet, cumulative core.

**Boundary note**: this GDD authors the *felt truth* of the unlock moment; the sensory performance (fanfare audio, animation, screen presentation) is owned by **Unlock/Victory Moment UI (#25)**. This section is the source-of-truth reference #25 should anchor to when specifying the fanfare's register — cozy and quiet, never triumphant-cinematic; *"the lantern moved one step further,"* not *"NEW CHAPTER UNLOCKED!!!"*.

**Strategic read acknowledgment (Pass-4 edit 2026-04-21 — corrected from Pass-3 framing)**: R5 (LOSING first-clear advances the lantern identically to WIN) combined with ADR-0002 (LOSING first-clear pays half the floor-clear bonus; the missing half is reclaimable on a later WIN as a *delta credit*, per Economy AC H-14 Sub-AC 14-losing-first-then-win-reclaim) creates a rational player strategy: send a deliberately weak formation for a guaranteed LOSING first-clear, then send the full formation on a replay to collect the second half. **There is no gold surplus** from this strategy — total gold credited per floor is capped at `FLOOR_CLEAR_BONUS[floor_index]` regardless of path (Economy's monotonic-credit invariant; LOSING-then-WIN nets the same total as a single WIN). Pass-3's earlier "~15k gold surplus across MVP lifetime" claim was arithmetically wrong; it operated on a pre-ADR-0002 mental model where LOSING-grind would have been additive rather than delta-credited. The actual seam is *pacing and fantasy*: a deliberately weak roster can advance the unlock gate as fast as a strong one, weakening the *"my roster earned this map"* curation read. We accept this in the MVP because (a) cozy-game register: the game does not punish bad strategy; (b) the 5-floor content budget caps how many times the seam matters; (c) Pillar 1 (*"presence is what counts"*) takes precedence over closing the seam. **This becomes a V1.0 live-ops tuning concern** if (a) floor count grows substantially, (b) a live-ops event introduces a per-run reward channel that *is* additive (i.e., not under monotonic-credit), or (c) per-run matchup bonus stacks in ways that compound the LOSING-grind payoff above zero. Registered as Open Question I.9.

**Presence is first-clear, not first-dispatch (Pass-4 edit 2026-04-21; Pass-9 edit 2026-04-21 — closes game-designer BLOCKING P9-B-1: disambiguated "loses" from "LOSING first-clear")**: the *"ground you've walked stays walked"* fantasy is delivered mechanically by `highest_cleared` advancing on `floor_cleared_first_time`. A player who dispatches to F3 and **abandons the run before it completes** (quits the app mid-combat, force-closes, or the run is otherwise interrupted without reaching `floor_cleared_first_time`) **has not advanced the lantern** — the signal did not fire, so the system records no presence. A **completed LOSING run** is different: it reaches `floor_cleared_first_time(floor_index, biome_id, losing_run=true)` and advances the lantern identically to a WIN (per R5). This is the MVP definition of presence: the run must *complete* (WIN or LOSING) for the lantern to move; abandonment does not count. Per-dispatch presence tracking (a `VISITED` sub-state) was considered and deferred to V1.0 — it would require a schema change (per-floor bool flag) and a new UI palette tier, both out of scope for the unlock system's MVP weight. UI #25 should anchor its fanfare to first-clear (signal firing), not first-dispatch. **This distinction is load-bearing for the §F Cross-System Behavioral Constraints mini-table row 4** — downstream GDD authors (#25, #17, #19, #23) must read "first-clear" as "the signal fired," NOT as "the player won."

**ACCESSIBLE visual is identical regardless of unlock path (Pass-4 edit 2026-04-21)**: a floor that becomes ACCESSIBLE because the predecessor was WIN-cleared and a floor that becomes ACCESSIBLE because the predecessor was LOSING-cleared render in the **same warm "this is where we are now" palette**. The system does not record `losing_unlock` on a per-floor basis, and UI consumers (#19, #23, #25) MUST NOT branch on how a floor reached ACCESSIBLE. Same rationale as the LOSING fanfare register lock in §C.1 R5: cozy-game says presence is presence; the game does not visibly distinguish how you arrived. (Pass-6 edit 2026-04-21 — cross-ref for UI #25's designer: this constraint was a deliberate Pass-4 design decision; the rationale chain is the same as the fanfare lock above. If you want to challenge it, the appeal path is the same — playtest evidence + design brief.)

## C. Detailed Design

### C.1 Core Rules

**R1 — Public API surface**. The system exposes the following methods on the `FloorUnlockSystem` autoload Node. There is one canonical query signature matching the Orchestrator's locked AC-ORC-13 contract:

```gdscript
class_name FloorUnlockSystem extends Node

# Internal state: typed dictionary, monotonic non-decreasing per key.
# Pass-3 edit 2026-04-21: explicit declaration + JSON int-cast policy (see §E "save file contains a value").
# Pass-8 edit 2026-04-21 — closes CONCERN C-14 (qa-lead P8-N-1): `_unlock_state` is a
# STABLE-FOR-TEST-ACCESS private field. Sub-AC 08-non-numeric (+ 08-null, 08-bool) assert
# `_unlock_state.has(biome_id) == true` to verify the §E step 6 write-not-skip invariant.
# Renaming this field breaks those assertions without a behavioral regression. Do NOT
# rename without also updating the assertions. If a refactor needs a different internal
# name, add a `has_biome_state(biome_id: String) -> bool` public accessor and migrate
# the Sub-ACs in the same PR.
var _unlock_state: Dictionary[String, int] = {}

# Test-injection DI for clamp warnings (Pass-4 edit 2026-04-21 — see R1-DI-pattern below).
# Production: dispatches to push_warning. Test fixtures override with a capturing closure.
var _warning_logger: Callable = func(msg: String) -> void: push_warning(msg)

# Test-injection DI for invalid-signal errors (Pass-7 edit 2026-04-21 — closes BLOCKING-5
# from Pass-6: AC-FU-04 / AC-FU-05 previously cited non-existent GdUnit4 method
# `assert_no_error_messages()`. This DI mirrors the _warning_logger pattern and aligns
# with the Orchestrator §J.4 _error_logger pattern that the rest of the codebase uses
# (matchup-resolver, combat-resolution, orchestrator). Test fixtures override with a
# capturing closure; production dispatches to push_error directly.
var _error_logger: Callable = func(msg: String) -> void: push_error(msg)

# Debug/QA flag (Pass-4 edit 2026-04-21 — declaration was missing from Pass-3 R1 list).
# Not @export — toggling is via test fixture or in-editor inspector hack only; never user-facing.
# Override is checked inside `get_floor_state` (§C.2) so all UI consumers (Guild Hall, Formation
# Assignment, Matchup Assignment) see the same "all unlocked" view as the Orchestrator gate
# (Pass-6 edit 2026-04-21 — closes CONCERN-9 from Pass-5 systems-designer review).
var debug_unlock_all: bool = false

# Designer-tunable knob for prototype biome swapping.
# Pass-7 edit 2026-04-21: reverted from `@export var` to plain `var` populated from
# ProjectSettings in _ready(). Pass-6's @export rationale was wrong — @export fields on
# autoload Nodes are NOT Inspector-surfaced via normal editor workflow (autoloads are not
# selectable in the Scene tree panel). The ProjectSettings pattern below is genuinely
# designer-accessible via Godot's Project Settings UI without a code edit or Remote-debug
# session. V1.0 removes this field when biome-context injection lands per §C.1 R1 V1.0
# evolution note. Validated in _ready() — must reference a biome with status="active".
var active_biome_mvp: String = "forest_reach"

# Per-biome floor count cache. Pass-7 edit 2026-04-21 — closes Pass-6 CONCERN systems-C-5
# + godot-C-5: declaration site was missing in Pass-6, referenced 5+ times as if
# always-available. Populated in _ready() from DataRegistry after active-biome validation.
# SCREAMING_SNAKE_CASE naming is intentional — this is derived-but-immutable after boot;
# it reads as a const-like lookup from the consumer's perspective. Unit tests that
# construct FloorUnlockSystem.new() must either run _ready() with a DataRegistry stub
# or set this field directly before calling other methods (e.g.,
# `floor_unlock.BIOME_FLOOR_COUNT = {"forest_reach": 5}` in before_each).
var BIOME_FLOOR_COUNT: Dictionary[String, int] = {}

func is_unlocked(floor_index: int) -> bool
func is_unlocked_in_biome(biome_id: String, floor_index: int) -> bool  # Pass-10 / S17-N3: V1.0+ multi-biome variant; matchup screen #23 caller
func is_biome_available(biome_id: String) -> bool
func is_biome_completed(biome_id: String) -> bool
func get_available_biomes() -> Array[String]
func get_highest_cleared(biome_id: String) -> int
func get_floor_state(biome_id: String, floor_index: int) -> FloorState
# Public signal (R11 — UI live-update on frontier advance):
signal floor_unlocked(biome_id: String, floor_index: int)
## Standard Save/Load consumer contract per Save/Load GDD #3 Rule 10.
## `data` is the **unwrapped interior dict** — Save/Load strips the "floor_unlock" namespace
## key before calling. Payload shape: `{"highest_cleared": {biome_id: int}}`. Missing key on
## load → fresh-save default (R2). Pass-4 edit 2026-04-21: contract level locked here.
func get_save_data() -> Dictionary
func load_save_data(data: Dictionary) -> void
# Debug/test only; guarded by OS.is_debug_build():
func debug_set_highest_cleared(biome_id: String, floor_index: int) -> void
func debug_reset() -> void
# Private helpers and signal handler (connected in _ready):
func _active_biome_id() -> String:  # MVP body: `return active_biome_mvp` (Pass-6 edit — was `ACTIVE_BIOME_MVP` const; promoted to @export var per I.11 closure).
func _on_floor_cleared_first_time(floor_index: int, biome_id: String, losing_run: bool) -> void
```

The `is_unlocked(floor_index: int) -> bool` method is verbatim the Orchestrator-facing contract. Internally it resolves the active biome (MVP: hardcoded `"forest_reach"` via private `_active_biome_id() -> String`; V1.0: injected via biome-context source, requires Orchestrator contract bump). The `is_floor_unlocked(floor_id: String)` form referenced in Biome DB E.1 is **retired** via propagation edit — see R1-note below and Section F.

**R1-typing**: `_unlock_state` is a typed `Dictionary[String, int]` (Godot 4.4+). JSON deserialization in `load_save_data` MUST run the full per-value processing sequence — type guard → lossy-cast warning → cast → under-range clamp → over-range clamp → write — before the int reaches the typed dict. `JSON.parse_string` returns numeric values as `float`; writing a `float` into a typed `Dictionary[String, int]` raises at runtime in **debug builds**. Pass-8 edit 2026-04-21 — closes CONCERN C-1 (cross-model godot-gdscript + godot-specialist): release-build enforcement of typed containers in GDScript is advisory; implementers MUST NOT rely on the typed-dict raise as a production safety net. **`int()` cast in §E step 3 is the load-bearing production protection regardless of build type.** The cast itself (`int(loaded_value)`) is mechanically simple, but the surrounding guards (Pass-4 added type-guard for non-numeric values + lossy-cast warning) are load-bearing — without them, a hand-edited save with a non-numeric value (`"foo"`) silently zeroes via `int("foo") == 0`. See §E "load_save_data per-value processing order" for the locked sequence.

**R1-DI-pattern** (Pass-4 edit 2026-04-21 — accuracy correction): One injectable dependency, `_warning_logger: Callable`, exists solely to make `push_warning` assertions testable in GdUnit4 (AC-FU-08). Production: defaults to a closure that calls `push_warning(msg)` directly — always callable, no `is_valid()` guard needed at call sites. Test fixtures override the field with a capturing closure (`func(msg): captured.append(msg)`) before any handler runs. **This is structurally distinct from the Orchestrator §J.4 `_error_logger` pattern** (which uses an invalid-Callable default + `is_valid()` guard at every call site + dedicated `set_error_logger()` setter) — both are valid Callable-DI shapes, but the defensive defaults differ. Pass-3's earlier "matches §J.4" claim was overstated and has been corrected here. The Pass-3 `_save_load_system: Object` DI was removed in Pass-4 along with the phantom `mark_dirty()` call (see §C.1 R9 below) — the field had no remaining production purpose.

**Production-path coverage note** (Pass-6 edit 2026-04-21 — closes Pass-5 CONCERN-17): the production closure (`func(msg): push_warning(msg)`) is exercised at runtime via manual smoke-check and playtest, NOT by automated unit tests. Every AC that touches `_warning_logger` (AC-FU-04, AC-FU-08 + Sub-ACs, AC-FU-15) overrides the field with a capturing closure before the WHEN. This is intentional — the production closure cannot be intercepted in GdUnit4 without DI, and the DI exists precisely to enable testing. A coverage-tooling pass that flags `push_warning` in the default closure as "never called" is reading the test environment correctly; this is not a test gap, it is an engine boundary.

**R1-note (propagation edit required)**: Biome DB GDD #8, Section E.1 currently cites `FloorUnlockSystem.is_floor_unlocked(floor_id: String)`. This signature is retired in favor of `FloorUnlock.is_unlocked(floor_index: int)`. The fix is a targeted text edit in the Biome DB's Edge Cases — no code migration, since Biome DB is pure content. Recorded in Section F as a required downstream edit.

**R2 — Fresh-save default state**. On a new save (no prior unlock history), `_unlock_state` contains exactly one entry: `{"forest_reach": 0}`. A value of `0` means "no floors ever cleared in this biome; F1 is accessible." The four `planned_v1` biomes (Sunken Ruins, Ember Cavern, Thornwood Depths, Arcane Spire) are **not seeded** into the dict — absence is the signal that the biome is unavailable, which avoids polluting saves with content the player has not been shown.

**R3 — Unlock advancement trigger**. FloorUnlockSystem subscribes to the Orchestrator's `floor_cleared_first_time` signal in `_ready()`. The Save/Load consumer contract is the standard Rule-10 direct-call pattern (SaveLoadSystem calls `get_save_data()` / `load_save_data()` on each consumer at serialization boundaries — no explicit registration). Pass-3 edit 2026-04-21 removed the prior `SaveLoadSystem.register_consumer("floor_unlock", self)` call (that method does not exist in Save/Load GDD #3's API; cross-GDD naming drift).

```gdscript
func _ready() -> void:
    # Pass-8 edit 2026-04-21 — closes BLOCKING-1: ProjectSettings.get_setting ALONE does not
    # surface the custom key in the editor Project Settings UI (Pass-7 claim was wrong).
    # set_initial_value + add_property_info register the key so it appears in the UI under
    # a custom "Floor Unlock" category after first game launch. User design decision D1.
    #
    # Pass-PROBE-EXECUTED edit 2026-04-21 — CRITICAL CORRECTION: the Pass-8 pattern below is
    # **empirically INCOMPLETE** for the designer-UI story. `ProjectSettings.save()` persists
    # only values that DIFFER from the initial value, so `set_setting(k, X) + set_initial_value(k, X)`
    # with equal values never lands in `project.godot` and therefore never appears in the
    # editor Project Settings UI (verified 2026-04-21 via `tests/probes/godot_autoload_probe.gd`
    # on Godot 4.6.1.stable.mono.official). Additionally, `add_property_info()` attaches hint
    # metadata only to the RUNNING PROCESS's ProjectSettings singleton — the editor process
    # never sees the hint registration unless a `@tool` script or EditorPlugin runs at editor
    # load time. See `docs/engine-reference/godot/modules/autoload.md` Claim 2 + Claim 3
    # empirical findings (Change log Pass-PROBE-EXECUTED entry).
    #
    # **MVP impact**: the code below still works as a RUNTIME fallback — `get_setting(key, default)`
    # returns "forest_reach" when the key isn't persisted, so the game plays correctly. The
    # designer-UI story (editor-surfaced knob with tooltip hint) is BROKEN until a `@tool`-script
    # or EditorPlugin registration path lands. Tracked as a V1.0-or-post-MVP follow-up
    # (Open Question I.11 update + Save/Load review log Pass-PROBE-EXECUTED entry).
    #
    # For MVP, the `active_biome_mvp` designer-knob workflow degrades to: designer edits
    # `project.godot` by hand adding `[floor_unlock] active_biome_mvp="forest_reach"`, OR
    # designer edits this source file's default constant. Both are acceptable for a single-
    # biome MVP; V1.0 multi-biome authoring will need the proper @tool/EditorPlugin pattern.
    var _active_biome_setting := "floor_unlock/active_biome_mvp"
    if not ProjectSettings.has_setting(_active_biome_setting):
        ProjectSettings.set_setting(_active_biome_setting, "forest_reach")
    ProjectSettings.set_initial_value(_active_biome_setting, "forest_reach")
    ProjectSettings.add_property_info({
        "name": _active_biome_setting,
        "type": TYPE_STRING,
        # Pass-9 edit 2026-04-21 — closes cross-model CONCERN (godot-specialist +
        # godot-gdscript + systems-designer 3-specialist agreement; third consecutive
        # wrong engine-idiom claim per I.11 lesson): PROPERTY_HINT_PLACEHOLDER_TEXT
        # renders the hint_string as greyed-out placeholder text INSIDE the input
        # field (LineEdit-style), which is confusing for documentation-style hints.
        # PROPERTY_HINT_NONE is correct for descriptive help where hint_string is
        # prose documentation of valid values, not a UI placeholder overlay.
        # (Pass-PROBE-EXECUTED note: this claim is EMPIRICALLY INCONCLUSIVE — the probe
        # could not discriminate between HINT_NONE and HINT_PLACEHOLDER_TEXT because
        # the editor never received the add_property_info call. Needs @tool probe.)
        "hint": PROPERTY_HINT_NONE,
        "hint_string": "biome_id with status=\"active\" in Biome DB",
    })
    active_biome_mvp = ProjectSettings.get_setting(_active_biome_setting, "forest_reach")
    # Validate against Biome DB — prevent soft-brick if designer set an invalid biome_id
    # (Pass-7 edit — closes Pass-6 CONCERN systems-C-2: active_biome_mvp had no validator).
    var _valid_active_biomes: Array = DataRegistry.get_all_ids("biomes").filter(
        func(id: String) -> bool:
            var b := DataRegistry.resolve("biomes", id) as Biome
            return b != null and b.status == "active"
    )
    if not _valid_active_biomes.has(active_biome_mvp):
        # Pass-8 edit — closes CONCERN godot-N-1: the fallback must ALSO verify
        # "forest_reach" is in _valid_active_biomes (a V1.0 content migration that removes
        # forest_reach would otherwise silently mis-configure). If forest_reach itself is
        # absent, fall back to whatever the first active biome is, or hard-error.
        _error_logger.call("FloorUnlockSystem: active_biome_mvp='%s' is not an active biome" % active_biome_mvp)
        if _valid_active_biomes.has("forest_reach"):
            active_biome_mvp = "forest_reach"
        elif not _valid_active_biomes.is_empty():
            active_biome_mvp = _valid_active_biomes[0]
            _error_logger.call("FloorUnlockSystem: 'forest_reach' not in active biomes; falling back to '%s'" % active_biome_mvp)
        else:
            _error_logger.call("FloorUnlockSystem: no active biomes in DataRegistry; system is soft-bricked")
            return  # Leave BIOME_FLOOR_COUNT empty; queries will return LOCKED/UNAVAILABLE.
    # Populate BIOME_FLOOR_COUNT from DataRegistry (closes Pass-6 CONCERN systems-C-5 +
    # godot-C-5: declaration site was missing). Field declared at class level as
    # `var BIOME_FLOOR_COUNT: Dictionary[String, int] = {}` — initialized here at boot.
    for biome_id in _valid_active_biomes:
        var biome := DataRegistry.resolve("biomes", biome_id) as Biome
        BIOME_FLOOR_COUNT[biome_id] = biome.dungeons[0].floors.size()  # MVP: single dungeon per biome; V1.0 multi-dungeon → I.13
    # Signal subscription — autoload identifier resolution.
    # Pass-8 edit 2026-04-21 — closes BLOCKING-2 (D2 user decision): the identifier
    # `DungeonRunOrchestrator` below resolves via Godot's autoload registry — i.e., the
    # Node registered at `/root/DungeonRunOrchestrator` per the project.godot [autoload]
    # section entry. The script's `class_name` is ORTHOGONAL to this lookup (class_name
    # is a compile-time type identifier; the autoload global is the scene-tree Node).
    # The load-bearing constraint is that the registered autoload name in project.godot
    # matches the bare identifier used in code (`DungeonRunOrchestrator.x` here).
    # Renaming class_name does NOT break this connection; renaming the autoload
    # registration does. (Pass-7's earlier "class_name must match autoload name" claim
    # was mechanically wrong — corrected here.)
    # Pass-8 edit — closes BLOCKING-4: connection MUST NOT use CONNECT_DEFERRED.
    # AC-FU-14 asserts the handler runs synchronously with the emit; a deferred
    # connection would make THEN clauses observe pre-signal state and all integration
    # assertions would silently fail. Default (0 flags) is synchronous — correct.
    DungeonRunOrchestrator.floor_cleared_first_time.connect(_on_floor_cleared_first_time)
    # Save/Load discovers consumers via GDD #3 Rule 10 direct-call contract;
    # no registration call needed. Pass-4 edit 2026-04-21: removed `_save_load_system`
    # autoload ref resolution along with the phantom `mark_dirty()` call (§C.1 R9).
    print_verbose("FloorUnlockSystem: subscribed to floor_cleared_first_time")
```

Note on `print_verbose` (Pass-4 edit 2026-04-21; Pass-8 mechanism-correction): this line only outputs when verbose mode is active at launch — controlled by the `--verbose` command-line flag or the `debug/settings/stdout/verbose_stdout` project setting. This is a **runtime launch-flag check** (via `OS.is_stdout_verbose()`), NOT a build-type compile-time elimination. Standard release-template launches do not pass `--verbose`, so the line is silenced in shipped games — but if a player launches with `--verbose`, output reappears. It is a **dev-only diagnostic**, not a production audit trail. The §E "before _ready() has subscribed" edge case is verified at boot by Godot's autoload-list invariant, not by this log line.

The signal's payload is extended (propagation edit to Orchestrator GDD #13, Section C.3 and F — see Section F below) to: `floor_cleared_first_time(floor_index: int, biome_id: String, losing_run: bool)`. **Pass-7 edit 2026-04-21 — closes Pass-6 BLOCKING-2: existing subscribers are NOT automatically compatible.** Godot 4.x signal emission with a Callable-to-signal arity mismatch raises a runtime error ("Signal 'X' argument count mismatch"), not a silent truncation. Pass-3 through Pass-6 assumed silent-truncation behavior without engine verification. Every pre-existing 1-arg subscriber MUST be updated to accept the new params with default values, i.e. `func _on_floor_cleared_first_time(floor_index: int, biome_id: String = "", losing_run: bool = false)`. The propagation edits required to update existing subscribers are listed in §F as items #5 (Economy) and #6 (Dungeon Run View #24) — both are BLOCKING before this GDD can be considered safely implementable. The handler advances state via `advance_unlock` semantics (R4 + R9).

**R4 — Monotonicity invariant**. For every biome_id in `_unlock_state`, the value is strictly monotone non-decreasing over the save's lifetime. No code path (including Save/Load restore, signal handler, V1.0 prestige stub) decrements the value. If a save-load operation produces a lower value than the in-memory value (e.g., stale save applied), the in-memory value wins and a `push_warning` is logged — but this state is rejected at the Save/Load layer (Rule 14 integrity) before reaching this system. **R4 exceptions (Pass-7 edit 2026-04-21 — closes Pass-6 CONCERN systems-C-3; Pass-8 edit 2026-04-21 — closes CONCERN C-7: enumerates BOTH decrement paths)**. Two `load_save_data` clamp branches may write a value lower than an in-memory state, both intentional:
1. **§E step 5 over-range clamp**: when a content patch shrinks `BIOME_FLOOR_COUNT[biome_id]` (e.g., Forest Reach goes from 5 → 3 floors in a content revision, and a save with `highest_cleared=5` now clamps to `3`). Prevents phantom CLEARED states for floors that no longer exist.
2. **§E step 4 under-range clamp**: a malformed or tampered save with a negative value clamps to `0`. This is a "decrement" only in a technical sense (`0 < -3` is false in signed-int comparison, so it's actually a *correction*, not a decrement of legitimate state — but the written value is lower than any pre-existing legitimate in-memory value would be).

Both clamped values become the new monotonic baseline going forward. The invariant holds **within a normally-progressing session**; both exceptions are LOAD-time corrections of save-file pathology, not runtime state rollbacks. Pass-8 edit — closes CONCERN C-8: the R4 monotonicity invariant applies within-session only; crash-recovery across sessions is CONDITIONAL on Offline Engine #12's replay correctly refiring `floor_cleared_first_time` (see §C.1 R9 comment + I.12). Cross-session monotonicity is not provable from this GDD alone.

**R5 — LOSING first-clear advances the unlock gate**. A clear is a clear regardless of `losing_run`. When `_on_floor_cleared_first_time` receives `losing_run: true`, it advances unlock state identically to a WIN. This is the Pillar 1 commitment made explicit in Section B (*"the guild was present there — and presence, in Lantern Guild, is what counts"*). The `losing_run` param is accepted but not read by **this system** — it exists in the payload for other subscribers' use (Economy's ADR-0002 gold-bonus halving path calls `try_award_floor_clear` directly rather than subscribing to the signal per Economy §C.5; UI #25's fanfare deliberately does not branch on `losing_run` per the §C.1 R5 fanfare-register lock below). Pass-8 edit 2026-04-21 — closes CONCERN C-6: the param is GLOBALLY load-bearing in the signal payload even though Floor Unlock itself does not read it. Implementers must preserve it in the payload shape (propagation edits #6/#7 in §F); a future subscriber that omits default values and receives a short payload would raise at runtime.

**LOSING fanfare register** (Pass-4 edit 2026-04-21 — locks the design floor for UI #25): the Unlock/Victory Moment UI #25 fires the **identical fanfare** for WIN and LOSING first-clears. Pillar 1 is absolute here — the system does not second-guess how presence was established. Same audio cue, same animation, same intensity, same color palette. #25 does not branch on `losing_run`. The design rationale is cozy-game register: a first-clear is a first-clear; introducing visual or audio differentiation (even subtle) reads as a soft punishment for losing, which the game does not do. Pass-3's earlier wording ("#25 may paint a softer version") opened a design fork that is now explicitly closed.

**Tradeoff acknowledged** (Pass-6 edit 2026-04-21 — closes Pass-5 game-designer CONCERN-2): "no differentiation" is not the only alternative to "punishment." A legitimate cozy-design alternative would be a *differentiated cozy register* — a quieter, warmer, more intimate version of the same beat on LOSING ("the guild made it through, exhausted but present") versus a slightly more energetic version on WIN. Cozy games (e.g., Stardew Valley) routinely modulate tone on hardship without reading as punitive. We rejected this alternative for MVP because (a) it requires UI #25 to maintain two fanfare assets per floor, doubling Audio Director + technical-artist scope; (b) the discrimination is subtle enough that some players will read it as a soft punishment regardless of intent; (c) the §B "presence is presence" framing is cleaner with a single fanfare register. **UI #25 may petition this constraint with a design brief if a meaningful counter-case emerges from playtest** (e.g., players reporting the WIN fanfare reads as celebratory in a way that makes the LOSING-grind seam more visible). Otherwise, treat as locked.

**R6 — F5 (boss floor) completion**. Clearing F5 advances `_unlock_state["forest_reach"]` to 5. No floor beyond F5 exists in MVP — the Orchestrator's `is_unlocked(6)` call returns `false` (R2 default, since highest_cleared + 1 = 6 but no F6 exists in Biome DB; Orchestrator should never make this call, but the system is defensive). Biome-completion is a **derived** property, not a persisted field: `is_biome_completed(biome_id)` returns `highest_cleared == BIOME_FLOOR_COUNT[biome_id]` (MVP constant `BIOME_FLOOR_COUNT["forest_reach"] = 5`, derivable from `DataRegistry.resolve("biomes", biome_id).dungeons[0].floors.size()` at boot).

**R7 — `planned_v1` biome filter ownership**. FloorUnlockSystem is the authoritative source of "which biomes are currently playable." UI consumers (Formation Assignment #17, Matchup Assignment Screen #23, Guild Hall Screen #19) call `get_available_biomes()` and do NOT read Biome DB's `status` field directly. This keeps the filter in one place and avoids drift if V1.0 adds cross-biome gate conditions that aren't expressible in a static `status` enum. Internally, MVP implementation of `get_available_biomes()`:

```gdscript
func get_available_biomes() -> Array[String]:
    var result: Array[String] = []
    for biome_id in DataRegistry.get_all_ids("biomes"):
        var biome := DataRegistry.resolve("biomes", biome_id) as Biome
        if biome.status == "active":
            result.append(biome_id)
    return result
```

V1.0 evolves this with cross-biome prerequisite checks (e.g., `if is_biome_completed("forest_reach"): allow "sunken_ruins"`). The signature does not change — only the internal rules.

**R8 — Cross-biome unlock scope boundary**. MVP: `is_biome_available(biome_id)` returns `true` for the single `status="active"` biome (`"forest_reach"`) and `false` for `planned_v1` stubs. V1.0: biome-chain unlock rules plug into this method. **This GDD makes no V1.0 biome-unlock-order design decisions** — those are deferred to a future V1.0 design pass (registered in Section I Open Questions). The schema (Dictionary keyed by biome_id) accommodates it with no migration.

**R9 — Idempotency**. The signal handler advances unlock state only if the incoming `floor_index` strictly exceeds the current value. The canonical formulation is the `max()` form from §D.4 — `_on_floor_cleared_first_time` and `advance_unlock` (§D.4) MUST produce byte-identical state mutation:

```gdscript
func _on_floor_cleared_first_time(floor_index: int, biome_id: String, losing_run: bool) -> void:
    # Pass-9 edit 2026-04-21 — closes systems-designer BLOCKING P9-B-1: §E documented
    # an is_biome_available(biome_id) guard that did not exist in this code block
    # (doc-vs-code drift). Guard now added as the FIRST check — V1.0-defensive against
    # a biome whose status rolls back from "active" → "planned_v1" mid-session while
    # BIOME_FLOOR_COUNT still holds the stale entry.
    if not is_biome_available(biome_id):
        _error_logger.call("FloorUnlockSystem: unavailable biome_id='%s' attempted advance" % biome_id)
        return
    # Pass-9 edit 2026-04-21 — closes systems-designer BLOCKING P9-B-2: converted from
    # bare push_error to _error_logger.call() for DI consistency with every other error
    # path. Sub-AC 05-dataregistry-miss in §H now exercises this branch.
    # Separate DataRegistry-miss case from invalid-index for diagnosability (Pass-3 edit 2026-04-21).
    if not BIOME_FLOOR_COUNT.has(biome_id):
        _error_logger.call("FloorUnlockSystem: biome_id='%s' not in BIOME_FLOOR_COUNT (DataRegistry miss?)" % biome_id)
        return
    if floor_index < 1 or floor_index > BIOME_FLOOR_COUNT[biome_id]:
        _error_logger.call("FloorUnlockSystem: invalid floor_index=%d for biome=%s (valid range 1..%d)" %
                   [floor_index, biome_id, BIOME_FLOOR_COUNT[biome_id]])
        return
    # Canonical advance semantics — matches §D.4 advance_unlock exactly:
    var current: int = _unlock_state.get(biome_id, 0)
    var h_new: int = max(current, floor_index)
    if h_new > current:
        _unlock_state[biome_id] = h_new
        # Pass-4 edit 2026-04-21: removed `_save_load_system.mark_dirty()` call.
        # The method is not part of Save/Load GDD #3's public API. Save/Load's
        # heartbeat (60s cadence per Save/Load Rule 5) captures the advanced
        # state on the next persist; worst-case data-loss window is one
        # heartbeat interval. Pass-7 edit 2026-04-21 — closes BLOCKING-8:
        # crash-in-window recovery is CONDITIONAL on the Offline Progression
        # Engine (#12, undesigned). If the app dies inside the 60s window,
        # the Orchestrator snapshot replay on next launch refires
        # `floor_cleared_first_time` ONLY IF the Offline Engine correctly
        # invokes `compute_offline_run` for the elapsed tick budget that
        # covers the floor-clear tick. If Offline Engine design places the
        # clear outside the replay window (or if Offline Engine hasn't
        # landed yet), the unlock is permanently lost. Tracked as I.12.
        # R9's idempotent advance converges IF the refire happens.
    # else: silent idempotent no-op
```

Duplicate signals, out-of-order save/load replay, and re-dispatch of an already-cleared floor are all safe no-ops. The `max()` form is written identically in §D.4 so the invariant "`_unlock_state[biome_id]` is monotone non-decreasing" is visible in both places.

**R10 — 1-based indexing convention**. `floor_index` is 1-based throughout, consistent with `FLOOR_CLEAR_BONUS[1..5]` (Pass 4A lock) and Economy's `try_award_floor_clear(floor_index)` range guard. `floor_index == 0` is the **sentinel for "no floors cleared yet"** in the stored counter only — it is never a valid query argument. `is_unlocked(0)` returns `false`. `_on_floor_cleared_first_time(0, ...)` logs `push_error` and returns.

**R11 — `floor_unlocked` signal (UI live-update on frontier advance)** _(Pass-10 edit 2026-05-07 — Sprint 17 S17-N2; closes Sprint 16 S16-M3 Matchup Assignment cross-GDD sweep iteration #3 drift item; Matchup Assignment Screen GDD #23 §C.2 + §E.3 + AC-23-15 reference this signal)._ The system emits `floor_unlocked(biome_id: String, floor_index: int)` exactly once per successful frontier advance in `_on_floor_cleared_first_time`, identifying the newly-ACCESSIBLE floor (`highest_cleared + 1` after the advance). The emission is bounded by biome floor count — final-floor clears (where `h_new == BIOME_FLOOR_COUNT[biome_id]`) emit nothing because no further floor exists to unlock. The signal is **NOT emitted** on: idempotent re-clears (R9 no-op path; the frontier did not move); validation rejections (out-of-range `floor_index`, unavailable `biome_id`; the early-return guards run before any state mutation); or `load_save_data` hydration (the loader writes `_unlock_state` directly, bypassing the signal handler — session restore must be silent so UI consumers don't fanfare on every save reload). Per R5, LOSING and WIN first-clears emit identically — the param is ignored by the firing predicate. **Subscriber compatibility**: per Pass-7 BLOCKING-2 lesson, signal arity is load-bearing; consumers MUST accept the 2-arg payload exactly. **Connect timing**: subscribers connect at `_ready()` per ADR-0003, no `CONNECT_DEFERRED` (mirroring R3's orchestrator-side rule).

---

### C.2 States and Transitions

Each floor is always in exactly one of four states. State is **derived** from two facts: (a) the biome's availability per R7, and (b) the biome's `highest_cleared` counter. State is not persisted per-floor — only the counter is.

| State | Condition | Dispatchable? | UI visual (per §B) |
|---|---|---|---|
| `UNAVAILABLE` | Biome is not in `get_available_biomes()` — i.e., `status="planned_v1"` or V1.0 gate unmet | No | Hidden from UI entirely |
| `LOCKED` | Biome available AND `floor_index > highest_cleared + 1` | No | Pencil sketch / ghosted |
| `ACCESSIBLE` | Biome available AND `floor_index == highest_cleared + 1` (or `floor_index == 1` with `highest_cleared == 0`) | Yes | Warmer "this is where we are now" palette |
| `CLEARED` | Biome available AND `floor_index <= highest_cleared` | Yes (replay always legal) | Full color diorama; populated lantern-posts |

**State derivation** (single public method used by `is_unlocked` and all UI consumers):

```gdscript
enum FloorState { UNAVAILABLE, LOCKED, ACCESSIBLE, CLEARED }

func get_floor_state(biome_id: String, floor_index: int) -> FloorState:
    if not is_biome_available(biome_id):
        return FloorState.UNAVAILABLE
    # Pass-4 edit 2026-04-21: explicit floor-index range guards. R10 sentinel
    # (`floor_index == 0` or negative is never valid) and post-content-downgrade
    # safety (`floor_index > N` for a biome whose floor count shrank) — both
    # were undefended in Pass-3, opening `is_unlocked(0) == true` and phantom
    # CLEARED tiles for trimmed biomes.
    if floor_index < 1:
        return FloorState.LOCKED
    var floor_count: int = BIOME_FLOOR_COUNT.get(biome_id, 0)
    if floor_index > floor_count:
        return FloorState.LOCKED  # Out of biome range; never accessible regardless of clear history.
    # Pass-6 edit 2026-04-21: `debug_unlock_all` override (G.2). Placed AFTER the range
    # guards so out-of-range queries still report LOCKED (debug flag does not invent floors
    # the biome doesn't have). Placed BEFORE the highest/CLEARED branches so all valid
    # in-range floors report CLEARED uniformly (UI palette consistency in QA smoke sessions).
    if debug_unlock_all and OS.is_debug_build():
        return FloorState.CLEARED
    var highest: int = _unlock_state.get(biome_id, 0)
    if floor_index <= highest:
        return FloorState.CLEARED
    if floor_index == highest + 1:
        return FloorState.ACCESSIBLE
    return FloorState.LOCKED

func is_unlocked(floor_index: int) -> bool:
    var state := get_floor_state(_active_biome_id(), floor_index)
    return state == FloorState.ACCESSIBLE or state == FloorState.CLEARED
```

**Transition table** (floor-level; biome-level `UNAVAILABLE → AVAILABLE` is V1.0 out-of-scope):

| From → To | Trigger | Guard |
|---|---|---|
| `LOCKED → ACCESSIBLE` | Predecessor floor `ACCESSIBLE → CLEARED` | `floor_index == new_highest_cleared + 1` |
| `ACCESSIBLE → CLEARED` | `floor_cleared_first_time(floor_index, biome_id, losing_run)` | `floor_index == highest_cleared + 1` (else idempotent no-op per R9) |
| `UNAVAILABLE → *` | Biome `status` changes `"planned_v1"` → `"active"` (content patch / V1.0 release) | Boot-time only; not runtime |
| `CLEARED → CLEARED` (self-loop) | Replay dispatch | No state change in `_unlock_state` (R4 monotonicity). **Note (Pass-4 edit 2026-04-21)**: the `floor_cleared_first_time` signal still fires on replay (per §C.3 ordering — Orchestrator's per-dispatch `floor_clear_emitted` flag resets between dispatches). UI #25 receives the event and uses `get_highest_cleared` to distinguish advance from replay. *This system* makes no state change; *downstream subscribers* still get the signal. |

**Terminal state**: `CLEARED` is terminal for MVP. No mechanic rolls it back. V1.0 prestige (stub system #31) would be the first candidate to challenge this; any such design requires an ADR.

**Why per-biome counter, not per-floor bitset**: The monotonic counter enforces the "no-gaps" invariant as a mathematical consequence (you cannot have F1 and F3 cleared but F2 locked). It is **structurally parallel** to Economy's `floor_clear_bonus_credited: Dictionary[int, int]` (ADR-0002) in two narrow respects only — both store monotone non-decreasing integers in a Dictionary, and both serialize to JSON int payloads cleanly. The two systems differ in semantics: Economy keys by `floor_index: int` and stores per-floor accumulated gold (delta-credit pattern); Floor Unlock keys by `biome_id: String` and stores a per-biome high-water mark (max-form pattern). **Do not apply ADR-0002's delta-credit logic to Floor Unlock advance** — they are not interchangeable patterns. (Pass-4 edit 2026-04-21: corrected the prior "isomorphic" claim, which was structurally false and could mislead an implementer.) The tradeoff: non-contiguous unlock (e.g., a V1.0 prestige "start at F3" affordance) cannot be represented — that is intentionally unsupported in MVP, and if V1.0 needs it, the schema migration is a per-floor bitset plus an ADR documenting the change.

---

### C.3 System Interactions

**Autoload registration order** (Godot `ProjectSettings > Autoloads`, top to bottom):

1. `DataRegistry` (static content catalog)
2. `SaveLoadSystem` (consumer registry)
3. `Economy` (gold gate for floor-clear bonus)
4. `FloorUnlock` **← this system; registered autoload name is `FloorUnlock` (script `class_name` is `FloorUnlockSystem`; per Pass-8 D2 decision, these are orthogonal — the autoload name is what appears at `/root/FloorUnlock` and in bare-name code references like Biome DB §E.1's `FloorUnlock.is_unlocked(...)`). Must be registered before Orchestrator so signal subscription is live at Orchestrator's first emission.**
5. `DungeonRunOrchestrator` (emits `floor_cleared_first_time` after the first cleared tick in any run)

**Pass-8 edit 2026-04-21 — closes CONCERN C-10 (systems-designer)**: the GDD body uses both the autoload name `FloorUnlock` (in §F propagation edits, Biome DB §E.1 reference, Save/Load namespace-key context) and the script `class_name` `FloorUnlockSystem` (in §C.1 R1 class declaration, §C.3 signal handler references, autoload `_ready()` diagnostics). These are INTENTIONALLY different per the D2 decision; the autoload name is the shorter form used at call sites, and the class_name is used for type annotations + test-mode `.new()` construction. An implementer registering the autoload under the name `FloorUnlockSystem` would break every `FloorUnlock.x` call site; the correct registered name is `FloorUnlock`.

**Same-tick signal ordering** (within Orchestrator's `_on_tick_fired`):

1. Orchestrator calls `Economy.add_gold(...)` for kills
2. On first-clear detection, Orchestrator calls `Economy.try_award_floor_clear(floor_index, bonus_amount)`
3. Orchestrator emits `floor_cleared_first_time(floor_index, biome_id, losing_run)`
4. FloorUnlockSystem's `_on_floor_cleared_first_time` handler runs — dict write only (no `mark_dirty()` call; that method is not on Save/Load #3's API per Pass-4 fix — see §C.1 R9 comment for the heartbeat-capture rationale)
5. (Subsequent heartbeat persists capture the advanced state, ≤60s default cadence)

Save/Load heartbeat persists at a 60s default cadence (Save/Load Rule 5; the interval is owned by the Time System's `heartbeat_interval_seconds` knob — 60s is the default, not a hard contract). In the worst case, an advance is not yet persisted when the session ends abruptly. Pass-8 edit 2026-04-21 — closes BLOCKING-12 (aligning this prose with §C.1 R9 + I.12): recovery on next launch is CONDITIONAL on the Offline Progression Engine (#12, undesigned) correctly invoking `compute_offline_run` for the elapsed tick budget AND on the Orchestrator's offline path emitting `floor_cleared_first_time` (currently absent from `compute_offline_run` per Orchestrator §C.4 lines 258–296 — see I.15). If both conditions hold, the signal refires and R9's idempotent advance converges. If either fails, the unlock is permanently lost and Pillar 1 is violated for the crash window. Pass-6 stated "no data loss" as settled fact; Pass-7 weakened R9's comment to "recovered IF Offline Engine replays correctly"; Pass-8 propagates the same conditional here to eliminate the intra-document contradiction. (Pass-6 edit 2026-04-21: corrected stale "2s cadence" + stale "mark-dirty" prose that survived Pass-4's code-side fixes.)

**Consumer interaction table**:

| Consumer | Reads/Writes | Method called | Contract |
|---|---|---|---|
| **Dungeon Run Orchestrator (#13)** | Reads | `is_unlocked(floor_index: int) -> bool` at DISPATCHING | Locked per AC-ORC-13. `false` → `validation_failed("floor_locked", {floor_index})` → RUN_ENDED |
| **Biome/Dungeon DB (#8)** | — (no runtime call) | Biome DB is static content. E.1 edge case text is **propagation-edited** to cite `FloorUnlock.is_unlocked(floor_index)` instead of the retired String form | Retired `is_floor_unlocked(floor_id)` — R1-note |
| **Guild Hall Screen (#19)** | Reads | `get_floor_state(biome_id, floor_index)`, `get_highest_cleared(biome_id)`, `get_available_biomes()`, `is_biome_completed(biome_id)` | UI paint: diorama per-floor state + biome roster. Reads on screen-enter + on `floor_cleared_first_time` signal (not polling) |
| **Formation Assignment (#17)** | Reads | `is_unlocked(floor_index)`, `get_available_biomes()`, `get_floor_state(...)` | Disables locked floors in the picker. Orchestrator remains the authoritative gate (defense-in-depth) |
| **Matchup Assignment Screen (#23)** | Reads | `is_unlocked(floor_index)`, `get_available_biomes()` | Filters locked floors from matchup-select UI |
| **Unlock/Victory Moment UI (#25)** | Reads (event-driven) | Subscribes directly to Orchestrator's `floor_cleared_first_time`. Reads `get_highest_cleared` to classify the event (is this a new-high or a re-clear?) | Fires fanfare only on newly-accessible advancement. Reads state, does not mutate |
| **Save/Load System (#3)** | Reads + writes | `get_save_data() -> Dictionary` / `load_save_data(data: Dictionary) -> void` | Namespace key: `"floor_unlock"`. Payload shape: `{"highest_cleared": {"forest_reach": int}}`. Missing key → fresh-save default. Pure int payload — Rule 13/14 float concerns do not apply |

**Signal-payload propagation edits required (flagged in §F)**:

1. **Orchestrator GDD #13**, §C.3 signal list + §F Downstream Dependents row for Dungeon Run View (#24): extend `floor_cleared_first_time(floor_index: int)` → `floor_cleared_first_time(floor_index: int, biome_id: String, losing_run: bool)`. Additive payload extension; existing subscribers remain compatible.
2. **Biome/Dungeon DB GDD #8**, §E.1: replace `FloorUnlockSystem.is_floor_unlocked(floor_id)` reference with Orchestrator-mediated validation note citing `FloorUnlock.is_unlocked(floor_index)`.
3. **Save/Load GDD #3**, §Consumer table / Rule 10: add FloorUnlockSystem as a registered consumer under namespace key `"floor_unlock"`.

## D. Formulas

Floor Unlock has no balance curves or scaling formulas — its "formulas" are Boolean/enum predicates derived from the Section C state model. Each is rendered in the skill's variable-table + output-range format for implementation unambiguity.

### D.1 `is_unlocked(floor_index)` — Orchestrator dispatch predicate

`is_unlocked` is the Orchestrator-facing contract (AC-ORC-13). It resolves whether a floor is dispatchable under the active biome.

```
is_unlocked(floor_index) = is_biome_available(_active_biome_id())
                          AND floor_index >= 1
                          AND floor_index <= (_unlock_state[_active_biome_id()] + 1)
                          AND floor_index <= BIOME_FLOOR_COUNT[_active_biome_id()]
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `floor_index` | `f` | int | `1–5` (MVP) | 1-based floor index within the active biome |
| `_active_biome_id()` | `b` | String | `"forest_reach"` (MVP) | Active biome key; MVP-hardcoded, V1.0 injected |
| `_unlock_state[b]` | `h` | int | `0–5` (MVP) | Highest floor ever cleared in biome `b`; `0` = nothing cleared |
| `BIOME_FLOOR_COUNT[b]` | `N` | int | `5` (MVP, Forest Reach) | Number of floors in biome `b`; derived from `DataRegistry.resolve("biomes", b).dungeons[0].floors.size()` |

**Output Range:** `{false, true}`

**Example (MVP, Forest Reach, player has first-cleared F2)**:

- `_unlock_state = {"forest_reach": 2}`, `BIOME_FLOOR_COUNT["forest_reach"] = 5`
- `is_unlocked(1)` → `true` (1 ≤ 2+1 = 3 and 1 ≤ 5)
- `is_unlocked(2)` → `true` (2 ≤ 3 and 2 ≤ 5)
- `is_unlocked(3)` → `true` (3 ≤ 3 and 3 ≤ 5) — the "next floor to try"
- `is_unlocked(4)` → `false` (4 > 3)
- `is_unlocked(5)` → `false` (5 > 3)
- `is_unlocked(6)` → `false` (6 > 5, out of biome range)
- `is_unlocked(0)` → `false` (fails `f ≥ 1` guard)

### D.2 `get_floor_state(biome_id, floor_index)` — UI state derivation

The full enum derivation used by UI consumers. Distinguishes `CLEARED` (player has beaten this floor) from `ACCESSIBLE` (next floor to try) — needed for the Player Fantasy §B diorama palette per floor.

```
get_floor_state(b, f):
    if NOT is_biome_available(b):                return UNAVAILABLE
    # Pass-6 edit 2026-04-21: Pass-4 added these two guards to §C.2 GDScript
    # (lines 184, 187) to close `is_unlocked(0) == true` (R10 sentinel violation)
    # and the post-content-downgrade phantom-CLEARED gap. The §D.2 pseudocode was
    # NOT updated in Pass-4, leaving a doc-vs-code drift: for f=0/highest=1 the
    # pre-Pass-6 pseudocode returned CLEARED while the GDScript correctly returned
    # LOCKED. Pseudocode now mirrors §C.2 exactly.
    if f < 1:                                    return LOCKED
    N = BIOME_FLOOR_COUNT.get(b, 0)
    if f > N:                                    return LOCKED  # out of biome range
    # Pass-6 edit 2026-04-21: debug_unlock_all override (G.2) — see §C.2 GDScript
    # for placement rationale (after range guards, before highest/CLEARED branch).
    if debug_unlock_all AND OS.is_debug_build(): return CLEARED
    # Pass-7 edit 2026-04-21 — closes BLOCKING-4: cache highest once to byte-mirror
    # §C.2 GDScript's `var highest: int = _unlock_state.get(biome_id, 0)`. Pass-6
    # pseudocode called .get() twice inline, violating the byte-identical standard
    # that Pass-4 set for §D.4.
    h = _unlock_state.get(b, 0)
    if f <= h:                                   return CLEARED
    if f == h + 1:                               return ACCESSIBLE
    else:                                         return LOCKED
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `biome_id` | `b` | String | active or planned_v1 biome ids | Caller-supplied biome key |
| `floor_index` | `f` | int | `1–N` where `N = BIOME_FLOOR_COUNT[b]` | 1-based floor index |
| `_unlock_state.get(b, 0)` | `h` | int | `0–N` | Highest cleared; `0` if biome never touched (missing-key default) |

**Output Range:** `{UNAVAILABLE, LOCKED, ACCESSIBLE, CLEARED}` (FloorState enum)

**Example (MVP)**:

- Biome `"forest_reach"` (active), `h = 2`:
  - `get_floor_state("forest_reach", 1)` → `CLEARED`
  - `get_floor_state("forest_reach", 2)` → `CLEARED`
  - `get_floor_state("forest_reach", 3)` → `ACCESSIBLE`
  - `get_floor_state("forest_reach", 4)` → `LOCKED`
  - `get_floor_state("forest_reach", 5)` → `LOCKED`
  - **Out-of-range cases** (Pass-6 edit 2026-04-21 — anchors the new guards):
    - `get_floor_state("forest_reach", 0)` → `LOCKED` (R10 sentinel; never a valid query)
    - `get_floor_state("forest_reach", -1)` → `LOCKED`
    - `get_floor_state("forest_reach", 6)` → `LOCKED` (out of biome range; no F6 in MVP)
    - `get_floor_state("forest_reach", 99)` → `LOCKED`
- Biome `"sunken_ruins"` (`status="planned_v1"`), any `f`:
  - `get_floor_state("sunken_ruins", *)` → `UNAVAILABLE`

### D.3 `is_biome_completed(biome_id)` — derived completion predicate

```
is_biome_completed(b) = N > 0
                       AND _unlock_state.get(b, 0) == BIOME_FLOOR_COUNT.get(b, 0)
                       AND is_biome_available(b)
```

The explicit `N > 0` guard (Pass-3 edit 2026-04-21) prevents a V1.0 false-positive where a biome ships with `status="active"` but `N = 0` floors (partial-ship staging state). Without this guard, `0 == 0 AND true` returns `true`, incorrectly marking the biome completed and triggering any downstream biome-chain unlock. The guard is independent of `is_biome_available` — we do not rely on a shared-state assumption between the two.

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| `_unlock_state.get(b, 0)` | `h` | int | `0–N` | Highest cleared in biome `b`; default 0 |
| `BIOME_FLOOR_COUNT.get(b, 0)` | `N` | int | `0, 5` (MVP) | Floor count in biome `b`; `0` if biome doesn't exist OR is staged-but-empty — guards against V1.0 biome that has not shipped yet |

**Output Range:** `{false, true}`

**Example (MVP)**:

- Biome `"forest_reach"`, `h = 5`, `N = 5` → `true` (biome completed; F5 Rootking beaten)
- Biome `"forest_reach"`, `h = 4`, `N = 5` → `false`
- Biome `"sunken_ruins"`, `h = 0`, `N = 0` (empty stub) → `false` (`N > 0` guard rejects first; `is_biome_available` also returns false — two independent rejections)
- **V1.0 partial-ship case**: Biome `"new_biome"`, `h = 0`, `N = 0`, `is_biome_available = true` (status flipped early) → `false` (`N > 0` guard is the sole rejection — independent of `is_biome_available`)

**MVP consumer**: none directly (no gameplay hook). V1.0 consumer: biome-chain unlock rules inside `is_biome_available` for chained biomes.

### D.4 Monotonic advance semantics (state mutation rule)

Not a predicate — the rule that governs `_unlock_state[b]` mutation. Belongs here because its invariant (`h` is monotone non-decreasing) is the mathematical foundation of R4 + R9. The implementation code in §C.1 R9 is the source-of-truth; this pseudocode reproduces its semantics for review readability. (Pass-4 edit 2026-04-21: the prior "byte-identical" claim was false — the Pass-3 pseudocode wrote `_unlock_state[b]` unconditionally while the GDScript wrote only on advance. Both formulations were behaviorally equivalent, but the divergence undermined the audit invariant. Pseudocode now mirrors the GDScript exactly.)

```
advance_unlock(f, b):
    # Pass-9 edit 2026-04-21 — mirrors §C.1 R9 exactly (systems-designer BLOCKING P9-B-1 + P9-B-2):
    # (1) unavailable-biome guard added FIRST; (2) all error emissions route through _error_logger DI.
    if NOT is_biome_available(b):
        _error_logger.call("FloorUnlockSystem: unavailable biome_id='%s' attempted advance" % b)
        REJECT
    # Diagnosable error separation: DataRegistry-miss vs invalid-index.
    if NOT BIOME_FLOOR_COUNT.has(b):
        _error_logger.call("FloorUnlockSystem: biome_id='%s' not in BIOME_FLOOR_COUNT (DataRegistry miss?)" % b)
        REJECT
    if f < 1 OR f > BIOME_FLOOR_COUNT[b]:
        _error_logger.call("FloorUnlockSystem: invalid floor_index=%d for biome=%s (valid range 1..%d)" %
                   [f, b, BIOME_FLOOR_COUNT[b]])
        REJECT
    # Canonical max-form advance:
    h_prev = _unlock_state.get(b, 0)
    h_new  = max(h_prev, f)
    if h_new > h_prev:
        _unlock_state[b] = h_new   # write only on actual advance
    # else: silent idempotent no-op (no write, no side effects)
```

**Invariant**: `∀ t2 > t1, _unlock_state[b](t2) ≥ _unlock_state[b](t1)` (monotone non-decreasing over all time).

**Consequence**: `get_floor_state` is also monotone with respect to each floor's state progression: a floor only ever moves `LOCKED → ACCESSIBLE → CLEARED`, never the reverse. No floor is ever re-LOCKED.

## E. Edge Cases

- **If a LOSING first-clear fires (`hp_bonus_factor < 0.5` on the clear loop)**: `_on_floor_cleared_first_time` advances `_unlock_state[biome_id]` identically to a WIN. The lantern moves. Economy halves the gold bonus per ADR-0002; Floor Unlock is orthogonal to that decision. Rationale: Pillar 1 commitment made explicit in §B. Never re-debate this rule mid-implementation.

- **If `floor_cleared_first_time` fires before `FloorUnlockSystem._ready()` has subscribed**: autoload ordering violation; **impossible by design** under the order specified in §C.3 (FloorUnlockSystem registers at rank 4; Orchestrator at rank 5). The `print_verbose` log line in `_ready()` (§C.1 R3) is a **dev-only diagnostic** — it is suppressed in production builds and does not provide a production audit trail. Pass-4 edit 2026-04-21: corrected the prior "auditable in session logs" framing. The structural defense is the autoload-list invariant verified at boot by Godot, plus Sub-AC 14-autoload-order's manual smoke-check (and Open Question I.10's proposed CI parse). If this edge case is ever observed in practice, the autoload order is wrong — not the handler.

- **If save file contains a biome_id that no longer resolves in `DataRegistry`** (e.g., content cut between releases, renamed biome): `load_save_data` keeps the stale key in `_unlock_state` but logs `push_warning("FloorUnlockSystem: unknown biome_id '%s' in save; preserving for forward-compat" % biome_id)`. It is not deleted — a future DLC/patch re-adding the biome under the same id should re-activate the player's progress. Queries (`is_unlocked`, `get_floor_state`) filter it out via `is_biome_available` which returns `false` for unknown biomes.

- **If save file is missing the `"floor_unlock"` namespace key** (fresh save, pre-#16 save restored from a previous MVP build, or partial save corruption): `load_save_data` treats missing key as absent payload and initializes `_unlock_state = {"forest_reach": 0}` (R2 fresh-save default). No error. This is the correct forward-compat contract — a player restoring an old save gets fresh unlock state, loses no other data, and simply re-earns floor access by re-clearing F1.

- **`load_save_data` per-value processing order** (Pass-4 edit 2026-04-21 — locks the sequence so the under/over/cast guards interact predictably): for each `(biome_id, loaded_value)` pair, `load_save_data` runs the following in order:
  1. **Type guard** — if `typeof(loaded_value) not in [TYPE_INT, TYPE_FLOAT]` (e.g., a String from a hand-edited save), log `_warning_logger.call("FloorUnlockSystem: non-numeric value type %s for biome '%s'; resetting to 0" % [typeof(loaded_value), biome_id])` and write `0`. **Stop processing this entry.** Pass-7 edit 2026-04-21 — closes BLOCKING-9: locked the type-check mechanism to `typeof()` int codes. Pass-6 prose said "`loaded_value` is not `int` or `float`" without specifying the check, leaving a gap where a QA engineer could read the guard as "parseable as number" and test with `"3.7"` (String that looks like a float). GDScript `typeof("3.7") == TYPE_STRING`, so the guard correctly rejects it and resets to 0 — the intent matches the spec, but the prose now states this explicitly. Without this guard, `int("foo")` returns `0` silently, indistinguishable from a legitimate fresh-save value.
  2. **Lossy-cast warning** — if `loaded_value is float and loaded_value != floor(loaded_value)` (e.g., `3.7`), log `_warning_logger.call("FloorUnlockSystem: non-integer float %s for biome '%s'; truncating to %d" % [loaded_value, biome_id, int(loaded_value)])`. **Continue processing — over-range clamp in step 5 may still apply** (Pass-6 edit 2026-04-21 — closes Pass-5 CONCERN-8: a value like `99.7` correctly produces TWO warnings, one from this step and one from step 5; the implementation must NOT short-circuit). Pass-6 edit also corrected the lossy-detection spelling from `floori()` (int-returning, mixes float != int) to `floor()` (float-returning, clean float != float comparison) — for MVP-range values harmless either way, but `floor` is type-cleaner.
  3. **Cast** — write `int(loaded_value)` into a temporary local. Required because `JSON.parse_string` returns all numbers as `float`; writing a `float` into a typed `Dictionary[String, int]` raises at runtime (R1-typing).
  4. **Under-range clamp** — if cast result `< 0`, clamp to `0` and log `_warning_logger.call("FloorUnlockSystem: clamped negative highest_cleared %d → 0 for biome %s" % [cast_value, biome_id])`. Without this, `get_floor_state` would return `LOCKED` for all indices (including F1) for that biome, bricking the player.
  5. **Over-range clamp** — if cast result `> BIOME_FLOOR_COUNT.get(biome_id, 0)`, clamp to `BIOME_FLOOR_COUNT.get(biome_id, 0)` and log `_warning_logger.call("FloorUnlockSystem: clamped out-of-range highest_cleared %d → %d for biome %s" % [cast_value, clamped_value, biome_id])`. Handles save-edit tampering (e.g., `99`) AND post-content-downgrade (e.g., a biome whose floor count shrank in a content patch — verified in §D.3 N>0 guard). Pass-8 edit 2026-04-21 — closes CONCERN C-9: MUST use `.get(biome_id, 0)` form, NOT direct key access `[biome_id]`. If `BIOME_FLOOR_COUNT` has not been populated (test-path where `_ready()` was not run — see AC-FU-08 setup), direct key access raises, but `.get(biome_id, 0)` returns `0`, which causes ANY non-zero cast value to clamp to `0` (safe — reduces to fresh-save default). Implementations must be empty-dict-safe at this step so the AC-FU-08 Sub-ACs don't fail by crash instead of by assertion.
  6. **Write** — `_unlock_state[biome_id] = clamped_int_value`.

  Clamp-rather-than-reject is the rule across all clamp guards: the player should not be denied a legitimate save if a minor integrity violation is detectable-and-fixable. Save/Load's anti-tamper layer (GDD #3) is the authoritative gate for "reject this save entirely."

- **If `floor_cleared_first_time` fires with `floor_index < 1` or `floor_index > BIOME_FLOOR_COUNT[biome_id]`**: handler routes `_error_logger.call("FloorUnlockSystem: invalid floor_index=%d for biome=%s (valid range 1..%d)" % [floor_index, biome_id, BIOME_FLOOR_COUNT[biome_id]])` and returns without mutation. Rationale: this indicates Orchestrator contract violation — treat as a loud engineering failure, not silent tolerance. An invalid advance must NEVER silently succeed. Pass-3 edit 2026-04-21 split the prior combined error into two distinct messages: one for "`biome_id` not in BIOME_FLOOR_COUNT dict" (DataRegistry miss) and one for "`floor_index` out of range for known biome" — same return-without-mutation behavior, different diagnostic text (see §C.1 R9 code and §D.4 pseudocode). Pass-9 edit 2026-04-21 — closes systems-designer BLOCKING P9-B-2: emission converted from bare `push_error` to `_error_logger.call()` for DI consistency with every other error path in the system; AC-FU-05 Sub-AC 05-dataregistry-miss now exercises this branch.

- **If `floor_cleared_first_time` fires with `biome_id` not in `get_available_biomes()` (e.g., a `planned_v1` biome somehow emitted)**: handler routes `_error_logger.call("FloorUnlockSystem: unavailable biome_id='%s' attempted advance" % biome_id)` and returns without mutation. Pass-9 edit 2026-04-21 — closes systems-designer BLOCKING P9-B-1: this guard is now actually implemented as the FIRST check in §C.1 R9 (prior passes documented the guard in §E without adding the code). V1.0-defensive against a biome whose status rolls back from "active" → "planned_v1" mid-session while `BIOME_FLOOR_COUNT` still holds the stale entry. AC-FU-05 Sub-AC 05-unavailable-biome now exercises this branch.

- **If the same `(floor_index, biome_id)` signal fires twice in the same tick** (duplicate emission bug in Orchestrator, or signal ricochet): first call advances (if applicable); second call falls through R9's idempotency check (`floor_index > current` is `false`) and is a silent no-op. No double-mark, no double-save-dirty. Safe.

- **If the player replays an already-CLEARED floor and wins/loses again**: Orchestrator's `floor_clear_emitted` per-dispatch flag still fires on first-clear-of-this-dispatch, causing `floor_cleared_first_time` to re-emit. Floor Unlock receives it; R9 idempotency makes it a silent no-op. Economy's own monotonic-credit gate (ADR-0002) separately rejects duplicate gold. Both gates converge safely; neither mutates.

- **If a `planned_v1` biome's `status` is flipped to `"active"` in a content patch while the player has an existing save**: on next load, `get_available_biomes()` starts returning the new biome_id. If `_unlock_state` does not yet have a key for that biome, the default `0` applies (F1 of the new biome becomes `ACCESSIBLE`). This is the intended forward-compat path for V1.0 biome rollouts — no migration script needed. Edge case worth testing in V1.0 release QA, not MVP.

- **If `DataRegistry.resolve("biomes", biome_id)` fails mid-call** (resource load error): `BIOME_FLOOR_COUNT[biome_id]` cannot be computed. `load_save_data` skips the biome with `push_error("FloorUnlockSystem: DataRegistry could not resolve biome '%s'; skipping unlock state entry" % biome_id)`. Partial load — other biomes load normally. Player sees an error toast on session start (via error_logger contract Pass 5C §J) and can repair by reinstalling; their save data is preserved.

- **If mid-session the Orchestrator autoload is freed and re-instantiated** (hot-reload during dev, or V1.0 post-content-patch reset): FloorUnlockSystem's `floor_cleared_first_time.connect(...)` from its `_ready()` was bound to the old Orchestrator instance. The connection is now stale; no signals arrive. Defense: not an MVP production concern (autoloads are process-lifetime in release builds). In dev, a `tool` annotation or developer-visible reconnect hook may be useful, but it is scope creep for MVP. Flagged in §I Open Questions as a V1.0-polish item.

## F. Dependencies

### Upstream Dependencies

| Upstream | Hard/Soft | Interface |
|---|---|---|
| **Biome/Dungeon Database (#8)** (`design/gdd/biome-dungeon-database.md`) | Hard | `DataRegistry.resolve("biomes", biome_id) -> Biome`; read-only access to `Biome.status`, `Biome.dungeons[0].floors.size()` for `BIOME_FLOOR_COUNT[biome_id]` derivation |
| **Save/Load System (#3)** (`design/gdd/save-load-system.md`) | Hard | Consumer contract: `get_save_data() -> Dictionary` / `load_save_data(data: Dictionary)`; namespace key `"floor_unlock"` (Save/Load unwraps before calling consumer); discovered via Rule 10 direct-call contract (no registration). Obeys Rules 10–14 (Pass 4B-SaveLoad). Pass-3 edit 2026-04-21 removed the prior `register_consumer` reference which did not match Save/Load GDD #3's actual API. |
| **Data Loading System (#2)** | Hard (transitive via Biome DB) | Indirect — relies on `DataRegistry` being `READY` before `_ready()` runs. Autoload order (C.3) enforces this |
| **Dungeon Run Orchestrator (#13)** (signal source only) | Hard | Subscribes to `DungeonRunOrchestrator.floor_cleared_first_time(floor_index: int, biome_id: String, losing_run: bool)`. **Requires the propagation edit specified in §C.3** — current Orchestrator signal payload is `(floor_index: int)` only |

### Downstream Dependents

| Consumer | Hard/Soft | What they read |
|---|---|---|
| **Dungeon Run Orchestrator (#13)** (query consumer; note the bidirectional relationship — signal source AND query caller) | Hard | `FloorUnlock.is_unlocked(floor_index: int) -> bool` at DISPATCHING (AC-ORC-13 contract) |
| **Guild Hall Screen (#19)** (undesigned) | Hard | `get_floor_state(biome_id, floor_index)`, `get_highest_cleared(biome_id)`, `get_available_biomes()`, `is_biome_completed(biome_id)` |
| **Formation Assignment (#17)** (undesigned) | Hard | `is_unlocked(floor_index)`, `get_available_biomes()`, `get_floor_state(...)` for picker UI filtering |
| **Matchup Assignment Screen (#23)** (undesigned) | Hard | `is_unlocked(floor_index)`, `get_available_biomes()`; subscribes to `FloorUnlock.floor_unlocked(biome_id, floor_index)` (R11) for live-update re-render of the affected FloorButton during offline-replay flush (AC-23-15) |
| **Unlock/Victory Moment UI (#25)** (undesigned) | Hard | Subscribes to `DungeonRunOrchestrator.floor_cleared_first_time` **independently**; reads `FloorUnlock.get_highest_cleared(biome_id)` to classify new-high vs replay |
| **Save/Load System (#3)** | Hard | Calls `get_save_data` / `load_save_data`; manages `"floor_unlock"` namespace persistence |

### Bidirectional Consistency Check

- `design/gdd/biome-dungeon-database.md` §C.6 + §F lists this system as downstream ✅. ~~Propagation edit required: §E.1 cites retired signature~~ ✅ **DONE** — Pass-7 edit 2026-04-21: verified §E.1 line 335 now uses the authoritative `FloorUnlock.is_unlocked(floor.floor_index)` form; Pass-6 bidirectional-consistency row was stale (the edit had been applied in Pass-2 timeframe).
- `design/gdd/save-load-system.md` Rule 10 + §Consumer table now lists FloorUnlockSystem ✅ (Floor-Unlock-Propagation-Edit-2 applied 2026-04-20; verified at `design/gdd/save-load-system.md` line 460 with the canonical `get_save_data`/`load_save_data` contract + namespace key `"floor_unlock"` + payload shape). Pass-6 edit 2026-04-21 — flipped stale ⚠️ to ✅; the Pass-2 propagation edit was completed in Pass-3 timeframe but §F was not updated to reflect it.
- `design/gdd/dungeon-run-orchestrator.md` §F lists Floor Unlock System (#16) as dependency ✅. **Propagation edit required**: §C.3 signal definition + §F Downstream Dependents row for Dungeon Run View (#24) must extend `floor_cleared_first_time` payload to `(floor_index: int, biome_id: String, losing_run: bool)`.
- `design/gdd/economy-system.md` §C.2.3 + §C.2.3a reference ADR-0002's `floor_clear_bonus_credited` monotonic-credit gate — **no conflict**; Floor Unlock's `_unlock_state` is a parallel-but-separate gate for access (not gold). Reviewer-visible symmetry noted; no edit required.

### Propagation Edits Required Before This GDD is Considered Complete

These edits are **not** optional — they are cross-GDD dependencies surfaced by this system's design. Bundle them before marking Floor Unlock "Approved":

1. ~~**Biome/Dungeon DB GDD #8**, §E.1 text: replace `FloorUnlockSystem.is_floor_unlocked(floor_id)` → `FloorUnlock.is_unlocked(floor_index)`~~ ✅ **DONE** (verified at `design/gdd/biome-dungeon-database.md` line 335 — the signature now reads `FloorUnlock.is_unlocked(floor.floor_index)` with the citation "2026-04-20 Floor-Unlock-Propagation-Edit-1"). Pass-7 edit 2026-04-21 — flipped stale "required" to ✅ DONE; Pass-6 bidirectional consistency table noted the edit as still-required even though it had been applied in the Pass-2 timeframe. One-line edit; no cascade.

2. ~~**Save/Load System GDD #3**, Consumer Table~~ ✅ **DONE** (Floor-Unlock-Propagation-Edit-2 applied 2026-04-20; verified at `design/gdd/save-load-system.md` line 460). Pass-6 edit 2026-04-21 — marked complete; the row is in place with the canonical contract.

3. **Dungeon Run Orchestrator GDD #13**, §C.3 signal definition + §F Downstream Dependent row for Dungeon Run View (#24): extend `floor_cleared_first_time(floor_index: int)` → `floor_cleared_first_time(floor_index: int, biome_id: String, losing_run: bool)`. Also propagate to AC-ORC-10 if it references the signal payload explicitly.

4. **Dungeon Run Orchestrator GDD #13**, §E.12 MVP-scaffolding note + §H AC-ORC-13 gate level: remove the F1-only stub reference (per §E.12 removal signal); promote AC-ORC-13 gate from ADVISORY to BLOCKING with verification clause updated to call FloorUnlockSystem directly (not the Orchestrator's inlined stub).

5. **`design/registry/entities.yaml`**: add the `FloorUnlockSystem`-owned constants + formulas surfaced in §C/§D. Full list in Phase 5 registry update (to be done at end of GDD authoring).

6. **Economy System GDD (`design/gdd/economy-system.md`)** — ~~Pass-7 edit 2026-04-21 — closes BLOCKING-2: Economy's `floor_cleared_first_time` subscriber must be updated to accept the extended 3-arg payload with default values~~ ✅ **VERIFIED NO ACTION NEEDED Pass-8 2026-04-21 (D3 user decision; closes Pass-8 BLOCKING-8)**. Economy GDD §C.5 line 187 explicitly states: *"Economy no longer relies on a `floor_cleared_first_time` signal for gold crediting; signal-receive pattern deprecated for the first-clear path in favour of the direct method call (the Orchestrator owns `losing_run` state and must compute the correct `bonus_amount` before calling)."* Orchestrator calls `Economy.try_award_floor_clear(floor_index, bonus_amount) -> bool` directly for the first-clear path (Economy §C.2.3a). Retained in this list as an **anti-regression trip-wire**: if a future Economy revision re-adds signal subscription to `floor_cleared_first_time`, that handler MUST use the 3-arg signature with default values (`func _on_floor_cleared_first_time(floor_index: int, biome_id: String = "", losing_run: bool = false)`) because Godot 4.x signal emission with a Callable-to-signal arity mismatch raises at runtime. **Cross-GDD drift flagged for Economy Pass-5 follow-up**: Economy §C.5 line 481 contains an example block describing Orchestrator emitting `floor_cleared_first_time` during tick replay and Economy handling it — this contradicts Economy's own §C.5 line 187 deprecation and should be harmonized by Economy's next revision pass. Not Floor Unlock #16's to fix.

7. **Dungeon Run View GDD #24** (undesigned) — Pass-7 edit 2026-04-21 — closes BLOCKING-2: when GDD #24 is authored, its `floor_cleared_first_time` handler MUST use the 3-arg signature with default values. Flag this in the #24 design pass rather than as a cross-GDD propagation edit now (no #24 subscriber code exists to break yet). **Recommendation**: `/design-system` authoring for #24 references this edit as a hard constraint.

### Cross-System Behavioral Constraints (Pass-8 edit 2026-04-21 — NEW; closes BLOCKING-11 via D5 user decision)

The following behavioral MUST NOTs live in §B (Player Fantasy) and §C.1 R5 but bind downstream UI consumers. They are NOT API contracts; dependency-table rows carry API shape only. This mini-table exists so downstream GDD authors discover the constraints before specifying their systems. When authoring #17/#19/#23/#25, copy the relevant row into that GDD's §E or §C explicitly.

| Consumer GDD | Constraint | Source | Rationale |
|---|---|---|---|
| **Unlock/Victory Moment UI #25** | MUST fire the identical fanfare for WIN and LOSING first-clears (no audio, animation, palette, or intensity differentiation) | §C.1 R5 LOSING fanfare register lock | Pillar 1 cozy-register: any differentiation reads as soft punishment for losing, which the game does not do. Appeal path: playtest evidence + design brief to game-designer. |
| **Guild Hall Screen #19, Formation Assignment #17, Matchup Assignment Screen #23, Unlock/Victory Moment #25** | MUST NOT branch on how a floor became ACCESSIBLE (WIN-cleared predecessor vs LOSING-cleared predecessor) — identical warm "this is where we are now" palette regardless. **Affirmative spec (Pass-9 edit 2026-04-21 — closes systems-designer CONCERN P9-C-4)**: ACCESSIBLE floors SHOULD render in the warm "this is where we are now" palette described in §B (warmer-and-closer than LOCKED's pencil-sketch; less saturated than CLEARED's full-color diorama). Art Bible + UI #19 design brief own the specific palette values; §B + §C.2 transition table anchor the register. | §B ACCESSIBLE-visual-identical paragraph + §C.2 transition table | Same rationale as above; "presence is presence." The system does not record `losing_unlock` per-floor; any UI reading WIN-vs-LOSING path would be inventing state that doesn't exist. Appeal path as above. |
| **Guild Hall Screen #19** | `UNAVAILABLE` floors (biome `status="planned_v1"` OR V1.0 gate unmet) MUST be hidden from UI entirely — not shown as locked-with-teaser | §C.2 transition table "UNAVAILABLE" row + §B acknowledgment | **MDA rationale (Pass-9 edit 2026-04-21 — closes game-designer BLOCKING P9-B-2)**: A complete 5-floor biome reads as a *contained world* — the player's lantern has a knowable edge, and the forest is finite in the way a cozy-fantasy setting should be. V1.0 content hints (teaser tiles for Sunken Ruins, Ember Cavern, etc.) fracture that containment and shift the register from *invitation* to *upsell* — "look what you could have if you paid/played more" is precisely the register the cozy-idle genre is built to avoid. Prevents pre-launching V1.0 content into MVP players' field of view as a secondary effect. **Appeal path**: UI #19 may petition this constraint via design brief + playtest evidence if the retention-hook case emerges from cohort data (e.g., drop-off rate after F5 clear exceeds 50%, indicating players are hitting the edge without a next-biome hook and disengaging). The appeal path is symmetric to row 1's LOSING-fanfare register lock — playtest is the arbiter; the default is hidden-entirely. |
| **Unlock/Victory Moment UI #25** | MUST anchor fanfare to first-clear (signal firing), NOT first-dispatch — a player who dispatches + quits mid-run does NOT receive a fanfare | §B "presence is first-clear" paragraph | MVP definition of presence: run must reach `floor_cleared_first_time` for the lantern to move. Per-dispatch visit tracking deferred to V1.0 (requires schema change). |

Each constraint should be repeated in the consumer GDD's §E Edge Cases or §C Detailed Rules when that GDD is authored, with a back-reference to this table. /design-system authoring for any of #17/#19/#23/#25 should scan this mini-table as a first step.

## G. Tuning Knobs

### G.1 Runtime Tuning Knobs (Designer-Accessible)

Floor Unlock is primarily infrastructure; most tunable values live in Biome DB (floor content) or Economy (bonus amounts). This system has a short list:

| Knob | Current | Safe Range | Effect |
|---|---|---|---|
| `active_biome_mvp` (Pass-9 edit — full chain: Pass-6 `@export var` → Pass-7 `ProjectSettings.get_setting` → Pass-8 `set_initial_value` + `add_property_info` registration + `get_setting` read → Pass-9 `PROPERTY_HINT_NONE` correction for descriptive hint. Pass-6's @export rationale was wrong — autoload @export fields are NOT Inspector-surfaced. Pass-7's bare `get_setting` rationale was ALSO wrong — the key is invisible in the Project Settings UI without `set_initial_value` registration. Pass-9 cross-model 3-specialist finding: `PROPERTY_HINT_PLACEHOLDER_TEXT` renders the hint_string as a confusing in-field placeholder overlay; `PROPERTY_HINT_NONE` is correct for descriptive documentation — see I.11) | `"forest_reach"` | Any biome_id with `status="active"` in Biome DB — validated in `_ready()` after `get_setting` read; invalid value logs via `_error_logger` and falls back to `"forest_reach"` (or first active biome if forest_reach itself is gone, per Pass-8 godot-N-1 fix) | The single-biome knob read by `_active_biome_id()`. **Designer workflow (Pass-9 edit 2026-04-21 — closes game-designer CONCERN P9-C-1: explicit numbered sequence to prevent the "designers can change without code edit" claim from hiding the first-run prerequisite)**: **(1)** Run the game once in the editor (F5 / Play). The first `_ready()` call registers `floor_unlock/active_biome_mvp` via `set_initial_value` + `add_property_info`. **(2)** Close the game. **(3)** Open **Project → Project Settings**. The key now appears under a custom "Floor Unlock" category (Godot derives category labels from the path prefix before the first `/`). **(4)** Modify the value to any biome_id with `status="active"` in Biome DB (MVP: only `"forest_reach"`; V1.0: more options as biomes activate). **(5)** Save. Changes take effect on the next game launch. Before step 1, the key is invisible in the UI — this is the one-time-registration tradeoff Pass-8 D1 accepted (vs a separate @tool editor-plugin bootstrap, rejected as higher scope). A fresh-cloned project with no prior game runs WILL NOT show this key until step 1 completes. V1.0 removes this knob when multi-biome context is injected per §C.1 R1 |
| `BIOME_FLOOR_COUNT` | `{"forest_reach": 5}` | Derived, not hand-tuned | Actually computed at boot from `DataRegistry.resolve("biomes", b).dungeons[0].floors.size()`. Documented as a knob only for the unlikely case that a designer wants to soft-cap unlock advancement below the authored floor count for a limited-time event. Safe range: `1 ≤ N ≤ authored_count` |

### G.2 Debug/Development Flags (Not Shipped)

| Flag | Default | Guard | Effect |
|---|---|---|---|
| `debug_unlock_all` | `false` | `OS.is_debug_build()` | If `true`, `is_unlocked` returns `true` for all `floor_index` in `[1, BIOME_FLOOR_COUNT[_active_biome_id()]]`. Used by QA for full-floor smoke tests without first-clear grind |
| `debug_set_highest_cleared(biome_id, floor_index)` | — | `OS.is_debug_build()` | Test affordance for GdUnit4 fixtures. See §C.1 R1 method list |
| `debug_reset()` | — | `OS.is_debug_build()` | Resets `_unlock_state` to fresh-save defaults. Used by QA to re-run the first-session unlock cadence without file manipulation |

### G.3 V1.0 Tuning Surface (Forward-Compat, Not Active in MVP)

When V1.0 biome-chain unlocks land, additional tuning knobs will be introduced on `is_biome_available`:

- Cross-biome prerequisite rules (e.g., `"sunken_ruins"` requires `is_biome_completed("forest_reach")`)
- Soft-lock / hard-lock semantics (preview locked biomes vs fully hide them)
- Biome-unlock gold cost as an alternative to clear-gated progression (opt-in; not in current MVP direction)

These are **not** knobs in MVP — listed here only to document the V1.0 evolution path. The schema stability is the contract: adding V1.0 rules does not break MVP saves.

## H. Acceptance Criteria

All criteria use Given-When-Then format. **15 BLOCKING criteria + 1 ADVISORY sub-AC (Sub-AC 14-autoload-order) = 16 Classification Summary rows.** Pass-8 edit 2026-04-21 — closes BLOCKING-6 (qa-lead count-mismatch): prior "15 criteria total, all writeable today" conflicted with the 16-row table because Sub-AC 14-autoload-order has its own row at ADVISORY. The count is now reconciled: 15 is the BLOCKING count, 16 is the total table-row count including the one ADVISORY sub-AC which is PROSE-READY (not automatable today) until I.10's CI script lands.

### Common fixture preconditions (Pass-8 edit 2026-04-21 — closes BLOCKING-7)

Every unit AC below that uses `FloorUnlockSystem.new()` construction (AC-FU-01 through AC-FU-12) REQUIRES the following `before_each` setup, because `FloorUnlockSystem.new()` does NOT run `_ready()` (autoload init is not exercised for `.new()`-constructed instances) and therefore leaves `BIOME_FLOOR_COUNT` as `{}`. Omitting this setup causes `get_floor_state` to return `LOCKED` for every in-range floor (the `f > N` guard at §C.2 fires with `N=0`), breaking AC-FU-01's F1=ACCESSIBLE assertion and every subsequent AC:

```gdscript
func before_each() -> void:
    # Pass-9 edit 2026-04-21 — closes systems-designer CONCERN P9-C-3: the class_name
    # `FloorUnlockSystem` is used for `.new()` construction in unit tests. The autoload
    # name `FloorUnlock` is used for bare-identifier autoload queries in production code
    # (e.g., `FloorUnlock.is_unlocked(...)`). These are INTENTIONALLY different per the
    # Pass-8 D2 decision — do NOT write `FloorUnlock.new()` (that attempts .new() on the
    # singleton Node, which is incorrect).
    floor_unlock = FloorUnlockSystem.new()
    floor_unlock.BIOME_FLOOR_COUNT = {"forest_reach": 5}
    floor_unlock._warning_logger = func(msg: String) -> void: captured_warnings.append(msg)
    floor_unlock._error_logger   = func(msg: String) -> void: captured_errors.append(msg)
    # Integration ACs (AC-FU-13/14/15 re-activation half) use real autoload tree and do NOT
    # need this setup — _ready() runs and populates BIOME_FLOOR_COUNT from DataRegistry.
```

This block is the anchor for every unit-AC GIVEN below. Each AC's GIVEN still describes its own state-specific setup (e.g., `_unlock_state["forest_reach"] = 1` via `debug_set_highest_cleared`), but the `BIOME_FLOOR_COUNT` + DI overrides above are ASSUMED and not repeated.

### AC-FU-01 — Fresh-Save Default: F1 ACCESSIBLE, F2–F5 LOCKED (Logic, BLOCKING)

**GIVEN** `FloorUnlockSystem` initialized with no prior save data (equivalent to `load_save_data({})` — missing `"floor_unlock"` key per §E "missing save key")
**WHEN** `get_floor_state("forest_reach", f)` is called for each `f` in `[1, 2, 3, 4, 5]`
**THEN**
- `get_floor_state("forest_reach", 1)` → `FloorState.ACCESSIBLE`
- `get_floor_state("forest_reach", 2..5)` → `FloorState.LOCKED`
- `_unlock_state["forest_reach"] == 0`
- `is_unlocked(1) == true`, `is_unlocked(2) == false`

*Verification approach*: Automated unit test in `tests/unit/floor_unlock/test_fresh_save_defaults.gd`

### AC-FU-02 — WIN First-Clear of F1 Advances Unlock: F2 Becomes ACCESSIBLE (Logic, BLOCKING)

**GIVEN** `FloorUnlockSystem` in fresh-save state (`_unlock_state["forest_reach"] == 0`)
**WHEN** `_on_floor_cleared_first_time(1, "forest_reach", false)` is called (WIN first-clear)
**THEN**
- `_unlock_state["forest_reach"] == 1`
- `get_floor_state("forest_reach", 1)` → `FloorState.CLEARED`
- `get_floor_state("forest_reach", 2)` → `FloorState.ACCESSIBLE`
- `get_floor_state("forest_reach", 3)` → `FloorState.LOCKED`
- `is_unlocked(1) == true`, `is_unlocked(2) == true`, `is_unlocked(3) == false`

### AC-FU-03 — LOSING First-Clear of F1 Advances Unlock Identically to WIN (Logic, BLOCKING)

**GIVEN** `FloorUnlockSystem` in fresh-save state
**WHEN** `_on_floor_cleared_first_time(1, "forest_reach", true)` is called (`losing_run: true`)
**THEN** outcome is byte-for-byte identical to AC-FU-02:
- `_unlock_state["forest_reach"] == 1`
- `get_floor_state("forest_reach", 2)` → `FloorState.ACCESSIBLE`
- `is_unlocked(2) == true`

Note: this test must be written as a separate test case (not calling the WIN test), so the R5 guarantee — that `losing_run` is accepted but not read — is verifiable in isolation.

### AC-FU-04 — Duplicate Signal Is a Silent No-Op (Logic, BLOCKING)

**GIVEN** `FloorUnlockSystem` with `_unlock_state["forest_reach"] == 1` (F1 already cleared via a prior `_on_floor_cleared_first_time(1, "forest_reach", false)` call in the test setup), AND both DIs overridden with capturing closures: `var captured_warnings: Array[String] = []; floor_unlock._warning_logger = func(msg: String): captured_warnings.append(msg); var captured_errors: Array[String] = []; floor_unlock._error_logger = func(msg: String): captured_errors.append(msg)` (Pass-7 edit 2026-04-21 — closes BLOCKING-5: adds _error_logger DI capture alongside the existing _warning_logger capture, replacing the non-existent GdUnit4 `assert_no_error_messages()` reference from Pass-6)
**WHEN** `_on_floor_cleared_first_time(1, "forest_reach", false)` is called a second time
**THEN**
- `_unlock_state["forest_reach"] == 1` (unchanged — the canonical no-op assertion)
- `get_floor_state("forest_reach", 2)` → `FloorState.ACCESSIBLE` (not `CLEARED`)
- `captured_errors.is_empty()` (no `push_error` emitted — duplicate is silent, not an error)
- `captured_warnings.is_empty()` (no warnings — duplicate is silent)

*Verification approach* (Pass-4 edit 2026-04-21 — simplified after `mark_dirty()` phantom removal): the no-op behavior is asserted directly via `_unlock_state` invariance. The Pass-3 `SpySaveLoadSystem` mark_dirty-count fixture has been **removed** because `mark_dirty()` was a phantom call on Save/Load's API (see §C.1 R9). Save persistence is now Save/Load's heartbeat concern, not Floor Unlock's; "no save was triggered" is no longer a Floor Unlock contract assertion.

*Sub-AC 04-also-replay* (Pass-3 edit 2026-04-21, retained — addresses replay-below-current path): **GIVEN** `_unlock_state["forest_reach"] == 3` (set up via `debug_set_highest_cleared("forest_reach", 3)` in test fixture), **WHEN** `_on_floor_cleared_first_time(1, "forest_reach", false)` fires (re-dispatch of already-cleared F1), **THEN** `_unlock_state["forest_reach"] == 3` (unchanged; `1 < 3` no-op); `captured.is_empty()`; no push_error. Exercises the sub-range `floor_index < current` branch of R9's max-form, which the primary AC-FU-04 (`floor_index == current` boundary) does not cover.

*Sub-AC 02-continuing-advance* (Pass-4 edit 2026-04-21 — closes the post-F1 advance boundary gap): **GIVEN** `_unlock_state["forest_reach"] == 2` (set up via `debug_set_highest_cleared("forest_reach", 2)`), **WHEN** `_on_floor_cleared_first_time(3, "forest_reach", false)` fires (the canonical post-F1 advance — `floor_index == current + 1` with `current > 0`), **THEN** `_unlock_state["forest_reach"] == 3`; `get_floor_state("forest_reach", 3) == FloorState.CLEARED`; `get_floor_state("forest_reach", 4) == FloorState.ACCESSIBLE`. AC-FU-02 covers the `current == 0` boundary; AC-FU-11 covers the F4→F5 boundary; this Sub-AC covers the interior advance path that was previously untested.

### AC-FU-05 — Out-of-Range Signal Logs Error and Does Not Mutate (Logic, BLOCKING)

**GIVEN** `FloorUnlockSystem` in fresh-save state, AND `_error_logger` DI overridden with a capturing closure: `var captured_errors: Array[String] = []; floor_unlock._error_logger = func(msg: String): captured_errors.append(msg)` (Pass-7 edit 2026-04-21 — closes BLOCKING-5: replaces implicit `push_error` capture with explicit DI capture, consistent with AC-FU-04)
**WHEN** `_on_floor_cleared_first_time(0, "forest_reach", false)` is called (`floor_index < 1`)
**THEN** `captured_errors.size() == 1`; `captured_errors[0].begins_with("FloorUnlockSystem: invalid floor_index=")` AND `captured_errors[0].contains("floor_index=0")` AND `captured_errors[0].contains("biome=forest_reach")`; `_unlock_state.get("forest_reach", 0) == 0`; state unchanged.

Pass-8 edit 2026-04-21 — closes qa-lead BLOCKING P8-B-2: prior exact-string equality (`captured_errors[0] == "FloorUnlockSystem: invalid floor_index=0 for biome=forest_reach (valid range 1..5)"`) was false precision — any non-behavioral wording refactor (e.g., `"invalid"` → `"out-of-range"`) would break CI. `begins_with` + `contains` assertions lock the load-bearing signal (prefix + offending floor_index + offending biome_id) without coupling to the full message format. The over-range value `5` is no longer asserted because it's derived from `BIOME_FLOOR_COUNT[biome_id]` and couples the test to the fixture setup unnecessarily.

**Format-string test-intent note (Pass-9 edit 2026-04-21 — closes game-designer CONCERN P9-C-3)**: `contains("biome=forest_reach")` is intentional and locks the `biome=%s` format used in §C.1 R9's invalid-floor-index message (produces `biome=forest_reach`). This is DISTINCT from the `biome_id='%s'` format used in the DataRegistry-miss and unavailable-biome messages (Sub-ACs 05-dataregistry-miss + 05-unavailable-biome below). A future implementer who "harmonizes" these format strings to a single shape would break this assertion — the format-string divergence is load-bearing for test diagnosability, not an authoring oversight.

**AND WHEN** `_on_floor_cleared_first_time(6, "forest_reach", false)` is called (`floor_index > BIOME_FLOOR_COUNT`) after resetting captured_errors
**THEN** `captured_errors.size() == 1`; `captured_errors[0].begins_with("FloorUnlockSystem: invalid floor_index=")` AND `captured_errors[0].contains("floor_index=6")`; no mutation.

**AND WHEN** `_on_floor_cleared_first_time(-1, "forest_reach", false)` is called (negative `floor_index`, Pass-6 edit 2026-04-21 closes Pass-5 CONCERN-11: the predicate path verified `is_unlocked(-1)` but the signal-handler path was untested for negative indices) after resetting captured_errors
**THEN** `captured_errors.size() == 1`; `captured_errors[0].begins_with("FloorUnlockSystem: invalid floor_index=")` AND `captured_errors[0].contains("floor_index=-1")`; `_unlock_state.get("forest_reach", 0) == 0`; state unchanged.

*Sub-AC 05-predicate-boundaries* (Pass-4 edit 2026-04-21 — closes the `is_unlocked(0)` and `is_unlocked(-1)` sentinel-violation gap; Pass-6 edit 2026-04-21 — extends to over-range `is_unlocked` per Pass-5 CONCERN-14 + R10's named defensive case `is_unlocked(6) → false`): **GIVEN** `_unlock_state["forest_reach"] == 1` (post-F1 first-clear), **WHEN** the predicate is queried at sentinel, negative, and over-range values, **THEN**:
- `is_unlocked(0)` → `false` (R10 sentinel — not a valid query argument)
- `is_unlocked(-1)` → `false` (negative index never accessible)
- `is_unlocked(-999)` → `false`
- `is_unlocked(6)` → `false` (R10 named defensive case — Orchestrator should never call but system is defensive; Pass-6 edit)
- `is_unlocked(99)` → `false` (over-range; Pass-6 edit)
- `get_floor_state("forest_reach", 0)` → `FloorState.LOCKED`
- `get_floor_state("forest_reach", -1)` → `FloorState.LOCKED`
- `get_floor_state("forest_reach", 6)` → `FloorState.LOCKED` (out of biome range)
- `get_floor_state("forest_reach", 99)` → `FloorState.LOCKED`

This Sub-AC verifies the §C.2 `floor_index < 1` and `floor_index > N` guards added in Pass-4. Without them, `is_unlocked(0)` returned `true` in Pass-3 (because `0 <= highest=1` falsely matched the `CLEARED` branch), violating R10's documented sentinel commitment. Pass-6 over-range `is_unlocked` cases verify the same guards propagate through the `is_unlocked → get_floor_state` delegation chain (Pass-5 caught that direct `get_floor_state` over-range was tested but the public `is_unlocked` over-range path was implicit-only).

*Sub-AC 05-dataregistry-miss* (Pass-9 edit 2026-04-21 — NEW; closes systems-designer BLOCKING P9-B-2: exercises the `BIOME_FLOOR_COUNT.has()` miss branch now routed through `_error_logger`): **GIVEN** `FloorUnlockSystem` (fresh instance) with `_error_logger` DI overridden by a capturing closure, AND `floor_unlock.BIOME_FLOOR_COUNT = {"forest_reach": 5}` (common fixture setup — so only `"forest_reach"` is present), **WHEN** `_on_floor_cleared_first_time(1, "sunken_ruins", false)` is called (biome_id NOT in `BIOME_FLOOR_COUNT`; assumes `sunken_ruins` passes the `is_biome_available` check OR the check is stubbed to return true for this test — see setup note), **THEN** `captured_errors.size() == 1`; `captured_errors[0].begins_with("FloorUnlockSystem: biome_id=")` AND `captured_errors[0].contains("not in BIOME_FLOOR_COUNT")` AND `captured_errors[0].contains("sunken_ruins")`; `_unlock_state.has("sunken_ruins") == false` (no state mutation). **Setup note**: to reach the `BIOME_FLOOR_COUNT.has()` check, the `is_biome_available` guard must pass first — in the test context this is achieved either by (a) configuring the DataRegistry fixture to return `"sunken_ruins"` as `status="active"` (making it available in the query) while deliberately omitting it from `BIOME_FLOOR_COUNT`, OR (b) temporarily overriding `is_biome_available` via a test seam. The DataRegistry-miss case is reachable in production when a biome's definition fails to load after status validation — the guard order in §C.1 R9 is intentional.

*Sub-AC 05-unavailable-biome* (Pass-9 edit 2026-04-21 — NEW; closes systems-designer BLOCKING P9-B-1: exercises the `is_biome_available` guard newly added to §C.1 R9 + §D.4): **GIVEN** `FloorUnlockSystem` (fresh instance) with `_error_logger` DI overridden by a capturing closure, AND DataRegistry configured so `"sunken_ruins"` has `status="planned_v1"` (so `is_biome_available("sunken_ruins")` returns `false`), **WHEN** `_on_floor_cleared_first_time(1, "sunken_ruins", false)` is called, **THEN** `captured_errors.size() == 1`; `captured_errors[0].begins_with("FloorUnlockSystem: unavailable biome_id=")` AND `captured_errors[0].contains("sunken_ruins")`; `_unlock_state.has("sunken_ruins") == false`. Verifies the first guard in §C.1 R9 (the unavailable-biome check placed BEFORE the BIOME_FLOOR_COUNT check). In MVP, this branch is unreachable via real signal emission (only `"forest_reach"` is active) but is defensive against V1.0 status-rollback bugs.

### AC-FU-06 — Save/Load Round-Trip: Pre-Save State Survives (Integration, BLOCKING)

**GIVEN** `FloorUnlockSystem` has `_unlock_state = {"forest_reach": 3}` (F3 cleared, F4 accessible)
**WHEN** `get_save_data()` is called → result stored → `load_save_data(result)` called on a fresh instance
**THEN**
- `get_highest_cleared("forest_reach") == 3`
- `get_floor_state("forest_reach", 3)` → `FloorState.CLEARED`
- `get_floor_state("forest_reach", 4)` → `FloorState.ACCESSIBLE`
- `get_floor_state("forest_reach", 5)` → `FloorState.LOCKED`
- Save payload shape: `{"highest_cleared": {"forest_reach": 3}}` under namespace `"floor_unlock"`

*HMAC bypass note* (Pass-6 edit 2026-04-21 — closes Pass-5 CONCERN-12): this AC calls `get_save_data()` and `load_save_data()` directly on the FloorUnlockSystem instance — it does NOT exercise SaveLoadSystem's binary envelope, HMAC layer, or `integrity_check_enabled` knob (Save/Load GDD #3 line 488). The test verifies the consumer-contract round-trip (payload shape + state restoration) in isolation. Save/Load's HMAC integrity is verified by Save/Load GDD #3's own AC-SL-01 + AC-SL-09 (anti-tamper), not here. If a sprint engineer wants an end-to-end Floor-Unlock-through-SaveLoad-binary-envelope test, that requires a Save/Load Mode-2 fixture not currently in the AC list — flag as a future Save/Load test addition, not a Floor Unlock #16 concern.

### AC-FU-07 — Missing Save Key Produces Fresh-Save Default (Logic, BLOCKING)

**GIVEN** `FloorUnlockSystem` (no prior state)
**WHEN** `load_save_data({})` is called (empty dict — `"floor_unlock"` key absent)
**THEN**
- No `push_error` is emitted
- `get_highest_cleared("forest_reach") == 0`
- `get_floor_state("forest_reach", 1)` → `FloorState.ACCESSIBLE`
- `_unlock_state == {"forest_reach": 0}`

### AC-FU-08 — Out-of-Range Saved Value Is Clamped with Warning (Logic, BLOCKING)

**Assertion-style note (Pass-9 edit 2026-04-21 — closes systems-designer CONCERN P9-C-1)**: the Sub-ACs below continue to use exact-string equality on `captured[0]` for documentation of the §E step-ordering contract. The primary AC-FU-08 + its Sub-ACs are intentionally MORE strict than AC-FU-05's Pass-8 loosening to `begins_with` + `contains`, because each Sub-AC here targets a distinct §E step (step 1 type-guard, step 2 lossy-cast, step 4 under-range, step 5 over-range) and the exact message content is the test's means of identifying which step fired. If a future implementer refactors the message wording for clarity, they must update both the §E spec AND the Sub-ACs in the same PR — the exact-string coupling is deliberate. For AC-FU-05 the load-bearing signal is "an error fired at all + with the right offending values"; for AC-FU-08 it is "the RIGHT error fired from the RIGHT §E step." Different signals, different assertion strategies.

**GIVEN** `FloorUnlockSystem` (fresh instance) with `_warning_logger` DI overridden by a capturing Callable (per §C.1 R1-DI-pattern): `var captured: Array[String] = []; floor_unlock._warning_logger = func(msg: String): captured.append(msg)`
**WHEN** `load_save_data({"highest_cleared": {"forest_reach": 99}})` is called (passed as the unwrapped interior dict — per §C.1 R1 doc comment, Save/Load strips the `"floor_unlock"` namespace key before calling the consumer)
**THEN**
- `captured.size() == 1`
- `captured[0] == "FloorUnlockSystem: clamped out-of-range highest_cleared 99 → 5 for biome forest_reach"`
- `get_highest_cleared("forest_reach") == 5`
- `get_floor_state("forest_reach", 5)` → `FloorState.CLEARED`
- `is_biome_completed("forest_reach") == true`

*Sub-AC 08-negative* (Pass-3 edit, retained — symmetric with over-range case): **GIVEN** same DI setup, **WHEN** `load_save_data({"highest_cleared": {"forest_reach": -3}})` is called, **THEN** `captured[0] == "FloorUnlockSystem: clamped negative highest_cleared -3 → 0 for biome forest_reach"`; `get_highest_cleared("forest_reach") == 0`; `get_floor_state("forest_reach", 1) == FloorState.ACCESSIBLE`. Verifies the under-range clamp guard (§E step 4).

*Sub-AC 08-float-cast-clean* (Pass-3 edit, retained — JSON deserialization integer-valued float): **GIVEN** same DI setup, **WHEN** `load_save_data({"highest_cleared": {"forest_reach": 3.0}})` is called (simulating JSON.parse_string returning a clean float), **THEN** no runtime error; `get_highest_cleared("forest_reach") == 3`; `captured.is_empty()` (no warning — 3.0 is in range and the cast is lossless). Verifies the `int(loaded_value)` cast required by R1-typing (§E step 3).

*Sub-AC 08-float-cast-lossy* (Pass-4 edit 2026-04-21 — locks the lossy-cast warning policy from §E step 2): **GIVEN** same DI setup, **WHEN** `load_save_data({"highest_cleared": {"forest_reach": 3.7}})` is called (simulating either save-edit tampering or a future bug that wrote a non-integer float), **THEN** no runtime error; `get_highest_cleared("forest_reach") == 3` (truncated); `captured.size() == 1`; `captured[0] == "FloorUnlockSystem: non-integer float 3.7 for biome 'forest_reach'; truncating to 3"`. Verifies the lossy-cast warning emitted in §E step 2 — silent truncation would mask data corruption signals.

*Sub-AC 08-non-numeric* (Pass-4 edit 2026-04-21 — closes the `int("foo") == 0` silent-erasure gap; Pass-6 edit 2026-04-21 — closes Pass-5 BLOCKING-5: adds explicit-write assertion to break the tautology): **GIVEN** same DI setup, **WHEN** `load_save_data({"highest_cleared": {"forest_reach": "foo"}})` is called (simulating a hand-edited save with a wrong type), **THEN** no runtime error; `_unlock_state.has("forest_reach") == true` (key explicitly written by step 6 — Pass-6 edit added this assertion to verify the type guard performs the reset-write rather than silently skipping; `get_highest_cleared` alone cannot distinguish "key written with 0" from "key absent, default 0 returned via `.get(b, 0)`"); `get_highest_cleared("forest_reach") == 0` (reset to fresh-save sentinel); `captured.size() == 1`; `captured[0]` matches `"FloorUnlockSystem: non-numeric value type [N] for biome 'forest_reach'; resetting to 0"` (where `[N]` is the GDScript `typeof(...)` int code for a String). Verifies §E step 1 type guard. Without this guard, `int("foo")` silently returns 0 — indistinguishable from a legitimate fresh-save value. **The `_unlock_state.has()` assertion is load-bearing**: an implementation that handles the type-guard early-exit by skipping step 6 (instead of writing 0) would pass the `get_highest_cleared == 0` assertion but fail this `has()` assertion.

**Sub-AC test isolation contract (Pass-9 edit 2026-04-21 — closes qa-lead BLOCKING P9-B-1)**: Each Sub-AC below (08-negative, 08-float-cast-clean, 08-float-cast-lossy, 08-non-numeric, 08-null, 08-bool, 08-float-lossy-and-overrange) is an INDEPENDENT `@test` function in the GdUnit4 suite. "GIVEN same DI setup" means the `before_each` fixture (§H preamble) re-runs for each Sub-AC, producing a fresh `captured: Array[String] = []` via the capturing closure. `captured.size() == 1` assertions are therefore per-test, not per-suite-cumulative. An implementation that collapses multiple Sub-ACs into a single `@test` function with sequential WHEN clauses and a shared `captured` array would break every Sub-AC assertion after the first — DO NOT do this. This reset contract is load-bearing for the assertion precision across the full AC-FU-08 sub-AC matrix.

*Sub-AC 08-null* (Pass-8 edit 2026-04-21 — NEW; closes BLOCKING-10 from systems-designer: JSON `null` is a valid JSON value from `JSON.parse_string`, and a hand-edited save that blanks a value produces `null` — type guard must catch it): **GIVEN** same DI setup (fresh `captured` array per Sub-AC test isolation contract above), **WHEN** `load_save_data({"highest_cleared": {"forest_reach": null}})` is called, **THEN** no runtime error; `_unlock_state.has("forest_reach") == true` (key explicitly written per §E step 1 reset + step 6 write); `get_highest_cleared("forest_reach") == 0`; `captured.size() == 1`; `captured[0]` matches the format `"FloorUnlockSystem: non-numeric value type 0 for biome 'forest_reach'; resetting to 0"` (`TYPE_NIL == 0` in GDScript). Verifies that §E step 1's `typeof(loaded_value) not in [TYPE_INT, TYPE_FLOAT]` guard correctly rejects TYPE_NIL.

*Sub-AC 08-bool* (Pass-8 edit 2026-04-21 — NEW; closes BLOCKING-10 from systems-designer: a hand-edited save with `true`/`false` in place of an integer is another attack vector): **GIVEN** same DI setup (fresh `captured` array per Sub-AC test isolation contract above), **WHEN** `load_save_data({"highest_cleared": {"forest_reach": true}})` is called, **THEN** no runtime error; `_unlock_state.has("forest_reach") == true`; `get_highest_cleared("forest_reach") == 0`; `captured.size() == 1`; `captured[0]` matches the format `"FloorUnlockSystem: non-numeric value type 1 for biome 'forest_reach'; resetting to 0"` (`TYPE_BOOL == 1` in GDScript). Without this sub-AC, a naïve implementation that special-cased `bool` as "truthy-numeric" (writing `1` for `true`, `0` for `false`) would pass AC-FU-08 but silently grant an unearned unlock. The assertion locks the behavior to reset-with-warning regardless of bool value.

*Sub-AC 08-float-lossy-and-overrange* (Pass-6 edit 2026-04-21 — NEW; closes Pass-5 CONCERN-8 dual-warning case): **GIVEN** same DI setup, **WHEN** `load_save_data({"highest_cleared": {"forest_reach": 99.7}})` is called (a value that triggers BOTH §E step 2 lossy-cast warning AND §E step 5 over-range clamp warning), **THEN** no runtime error; `captured.size() == 2` (TWO warnings — implementation must NOT short-circuit after step 2); `captured[0] == "FloorUnlockSystem: non-integer float 99.7 for biome 'forest_reach'; truncating to 99"`; `captured[1] == "FloorUnlockSystem: clamped out-of-range highest_cleared 99 → 5 for biome forest_reach"`; `get_highest_cleared("forest_reach") == 5`; `get_floor_state("forest_reach", 5) == FloorState.CLEARED`; `is_biome_completed("forest_reach") == true`. This Sub-AC documents the dual-warning behavior as expected (Pass-5 caught it as ambiguous in §E; Pass-6 step 2 wording now says "Continue processing — over-range clamp in step 5 may still apply", and this Sub-AC anchors that contract).

### AC-FU-09 — `get_floor_state` Correctness Across All Four Enum Values (Logic, BLOCKING)

**GIVEN** `FloorUnlockSystem` with `_unlock_state = {"forest_reach": 2}`; biome `"sunken_ruins"` has `status="planned_v1"` in DataRegistry. **DataRegistry fixture (Pass-9 edit 2026-04-21 — closes qa-lead CONCERN P9-C-1)**: this AC queries `get_floor_state` with `"sunken_ruins"`, which internally calls `is_biome_available("sunken_ruins")` → `DataRegistry.resolve("biomes", "sunken_ruins")`. Since `FloorUnlockSystem.new()` in `before_each` does NOT run `_ready()` (autoload init skipped), the test MUST explicitly provide DataRegistry state — either via (a) `DataRegistry.data_root_path = "res://tests/fixtures/biomes_with_planned_v1"` + `DataRegistry.hot_reload("biomes")` in `before_each` (recommended — closer to production), OR (b) a test seam that stubs `is_biome_available` to return `false` for `"sunken_ruins"` and `true` for `"forest_reach"` (lighter but couples test to internal implementation).
**WHEN** `get_floor_state` is queried for each relevant combination
**THEN** all four enum values are exercised:
- `get_floor_state("forest_reach", 1)` → `CLEARED`
- `get_floor_state("forest_reach", 2)` → `CLEARED`
- `get_floor_state("forest_reach", 3)` → `ACCESSIBLE`
- `get_floor_state("forest_reach", 4..5)` → `LOCKED`
- `get_floor_state("sunken_ruins", 1)` → `UNAVAILABLE`

### AC-FU-10 — `planned_v1` Biome Is Unavailable (Logic, BLOCKING)

**GIVEN** DataRegistry has `"sunken_ruins"` with `status="planned_v1"`. **DataRegistry fixture requirement (Pass-9 edit 2026-04-21 — same as AC-FU-09 per qa-lead CONCERN P9-C-1)**: because `FloorUnlockSystem.new()` skips `_ready()`, the test MUST provide DataRegistry state explicitly (either via `data_root_path` + `hot_reload` or via a test seam). `is_biome_available` internally calls `DataRegistry.resolve("biomes", ...)` and `get_available_biomes()` iterates `DataRegistry.get_all_ids("biomes")` — both require DataRegistry to be READY with fixture content for `"forest_reach"` (active) AND `"sunken_ruins"` (planned_v1).
**WHEN** `is_biome_available("sunken_ruins")` is called
**THEN** returns `false`

**AND WHEN** `get_available_biomes()` is called
**THEN** `"sunken_ruins"` is NOT in the result; `"forest_reach"` IS in the result; MVP result has exactly 1 element.

### AC-FU-11 — `is_biome_completed` Transitions false→true on F5 Clear (Logic, BLOCKING)

**GIVEN** `FloorUnlockSystem` with `_unlock_state["forest_reach"] == 4`
**WHEN** `is_biome_completed("forest_reach")` is called → result recorded
**AND** `_on_floor_cleared_first_time(5, "forest_reach", false)` fires (F5 boss first-clear)
**AND** `is_biome_completed("forest_reach")` is called again
**THEN**
- First call → `false`
- Second call → `true`
- `get_highest_cleared("forest_reach") == 5`
- `is_unlocked(5) == true` (F5 itself becomes CLEARED)
- `is_unlocked(6) == false` (no F6 exists)

### AC-FU-12 — State Monotonicity: `_unlock_state` Never Decreases (Logic, BLOCKING)

**GIVEN** `FloorUnlockSystem` that has advanced to `_unlock_state["forest_reach"] == 3`
**WHEN** either of the following is attempted:
- (a) `_on_floor_cleared_first_time(1, "forest_reach", false)` fires (a floor already cleared)
- (b) `_on_floor_cleared_first_time(2, "forest_reach", false)` fires (another already-cleared)

**THEN** in both cases:
- `get_highest_cleared("forest_reach") == 3` (value unchanged; max-form advance is no-op when `floor_index < current`)
- No `push_error` emitted (valid in-range floor_index; just a no-op advance)

*Retired case (c)* (Pass-3 edit 2026-04-21): The prior case (c) — `load_save_data` called with a lower value while in-memory state was `3` — described an impossible production sequence. Per Save/Load GDD #3 Rule 10, `load_save_data` is called exactly once at app launch during the LOADING state, before any state has advanced. A mid-session load call does not occur. The R4 monotonicity invariant across the save/load boundary is already covered by AC-FU-06 (round-trip preserves state). The sub-range replay path (`floor_index < current` during a signal) is now covered by AC-FU-04 Sub-AC 04-also-replay.

### AC-FU-13 — Orchestrator Integration: Locked Floor Rejected at DISPATCHING (Integration, BLOCKING) ✅ **WRITEABLE-WITH-CI-CONSTRAINT Pass-9 2026-04-21**

**Pass-9 edit 2026-04-21 — closes qa-lead BLOCKING P9-B-2**: prior "WRITEABLE" classification implied the `before_each` filesystem-delete strategy (`rm user://save_slot_1.dat*`) was sufficient for test isolation. GdUnit4's lifecycle defeats this: the engine boots ALL autoloads (rank 1-5) and runs their `_ready()` methods BEFORE the test runner takes over and calls `before_each`. By the time `before_each` can delete the save file, `SaveLoadSystem._ready()` has already read it and called `load_save_data()` on FloorUnlockSystem. The AC is still writeable, but ONLY under a specific CI constraint: **filesystem cleanup MUST happen as a pre-launch shell step BEFORE the Godot process starts**. Example (GitHub Actions):
```yaml
- name: Clear save data before test run
  run: rm -f ~/.local/share/godot/app_userdata/LanternGuild/save_slot_1.dat*
- name: Run GdUnit4 integration tests
  run: godot --headless --script tests/gdunit4_runner.gd
```
OR: run the AC in a dedicated fresh-workspace GdUnit4 project with a guaranteed-clean `user://` directory. The `before_each` filesystem-delete remains as belt-and-braces defense (useful for iterative tests within a session after the pre-launch clean), but is NOT sufficient alone. This constraint lifts to full WRITEABLE when Save/Load #3 resolves I.14 (public `save_file_path` knob or `debug_reset_to_fresh()` API), at which point the test can redirect the save path per-test without filesystem access.

**GIVEN** `DungeonRunOrchestrator` and `FloorUnlockSystem` both running as initialized project autoloads (Mode-2 per Orchestrator §J.3 — real autoload tree, no `.new()` construction). **Test fixture preconditions** (Pass-4 edit 2026-04-21 — locks the setup that Pass-3 left implicit):
- `FloorUnlockSystem.debug_reset()` called in `before_each` to guarantee `_unlock_state == {"forest_reach": 0}` (fresh-save state). This is required because GdUnit4 does not guarantee autoload state isolation between tests.
- `DataRegistry.state == READY` (asserted in `before_each`). The autoload init order in `project.godot` (Sub-AC 14-autoload-order) ensures `DataRegistry._ready()` completes before this test runs, but the assertion is cheap insurance against test-order flakiness.
- **Save/Load isolation strategy** (Pass-6 edit 2026-04-21 — closes Pass-5 BLOCKING-4: prior hedge "if such a method exists" was a fixture-not-writable confession; verified `SaveLoadSystem.debug_reset_to_fresh()` does NOT exist in Save/Load GDD #3; Pass-7 edit 2026-04-21 — closes BLOCKING-7: locked the execution-order invariant; **Pass-8 edit 2026-04-21 — closes BLOCKING-3**: verified `SaveLoadSystem.save_file_path` ALSO does NOT exist as a public tuning knob in Save/Load GDD #3 — Save/Load's canonical slot path is constructed via `save_slot_path(slot: int) -> String` helper and is not a settable field. Pass-7 replaced one phantom API (`debug_reset_to_fresh()`) with another (`save_file_path`). Pass-8 refiles this as cross-GDD dependency I.14): `FloorUnlockSystem.debug_reset()` is sufficient for THIS AC's invariant **in isolation**, but prior-run persisted state CAN leak into autoload `_ready()` via Save/Load's Rule-10 direct-call contract unless Save/Load #3 exposes either a `save_file_path` public tuning knob OR a `debug_reset_to_fresh()` API. Until then, the test MUST be run in a fresh Godot test-project workspace (GdUnit4's default behavior) OR the test suite MUST manually delete `user://save_slot_1.dat` + `user://save_slot_1.dat.bak` in `before_each` before any autoload `_ready()` call — a filesystem-level isolation strategy that does not depend on a Save/Load API addition. Tracked as I.14. Execution order in Mode-2 GdUnit4 integration tests: (1) Godot boots autoloads in rank order — DataRegistry, SaveLoadSystem, Economy, FloorUnlock, DungeonRunOrchestrator; (2) SaveLoadSystem's `_ready()` calls `load_save_data()` on each registered consumer, reading from `save_slot_path(1)` = `user://save_slot_1.dat`; (3) the test's `before_each` runs AFTER all `_ready()` calls complete; (4) `FloorUnlockSystem.debug_reset()` in `before_each` forces `_unlock_state = {"forest_reach": 0}` regardless of what step (2) loaded. The filesystem-level cleanup (deleting `user://save_slot_1.dat` + `.bak` before the test workspace boots, or running in a fresh GdUnit4 test project) is belt-and-braces — it ensures step (2) does not load stale production state in the first place. AC-FU-13's THEN clauses assert on (a) FloorUnlock state (`is_unlocked(5) == false`), (b) Orchestrator state transitions (`NO_RUN → DISPATCHING → RUN_ENDED`), (c) Orchestrator signal emission (`validation_failed.emit(...)`), and (d) CombatResolver non-invocation. **None of these THEN clauses depend on SaveLoadSystem state** once the fixture preconditions are met. **Constraint on test placement**: do not co-locate this test in a GdUnit4 suite that also exercises `SaveLoadSystem` persist paths without the same `save_file_path` redirect — the persist could race with `FloorUnlockSystem.debug_reset()` and re-populate `_unlock_state` from a stale persisted value, breaking the fresh-save precondition. Recommended placement: `tests/integration/orchestrator/dispatch_gate_test.gd` as a standalone integration test. If a future sprint wants Save/Load Mode-2 round-trip coverage paired with Floor Unlock dispatch, that requires a `SaveLoadSystem.debug_reset()` API addition — flag as a Save/Load GDD #3 follow-up Open Question, not a Floor Unlock #16 BLOCKING.

**WHEN** dispatch is triggered for `floor_index = 5` via the Orchestrator's public dispatch entry point
**THEN**
- `FloorUnlock.is_unlocked(5)` returns `false` (verified by direct query in test setup)
- State transitions `NO_RUN → DISPATCHING → RUN_ENDED`
- `validation_failed.emit("floor_locked", {floor_index: 5})` fires exactly once
- `CombatResolver.compute_offline_batch` is NOT called
- Orchestrator's final state is `RUN_ENDED`

*Writeable status*: **WRITEABLE**. Unblocked by Orchestrator GDD #13 Floor-Unlock-Propagation-Edit-3 (2026-04-20, signal payload extension + AC-ORC-13 BLOCKING promotion). Test lives in `tests/integration/orchestrator/` (Mode-2 scope), not `tests/unit/`. Paired with Orchestrator AC-ORC-13 Sub-AC 13-fresh-save as the integration-side anchor.

*Wiring note (Pass-3 edit 2026-04-21, retained)*: The prior AC-FU-13 GIVEN cited "§J.3 Mode-1 with a real FloorUnlockSystem" — incorrect because §J.3 Mode-1 constructs `DungeonRunOrchestrator.new()` without any FloorUnlockSystem DI, and no such DI exists in Orchestrator's public API. Mode-2 (real autoload tree) is the correct scope. If a future sprint wants Mode-1 scope, that requires an Orchestrator GDD revision to add `set_floor_unlock_system()` DI — out of scope for this AC.

### AC-FU-14 — Signal Subscription Live at Orchestrator Emission (Integration, BLOCKING) ✅ **Reclassified Pass-7 Mode-2**

**GIVEN** `FloorUnlock` and `DungeonRunOrchestrator` both running as initialized project autoloads (Mode-2 per Orchestrator §J.3 — real autoload tree, no `.new()` construction; matches AC-FU-13's pattern), with autoload rank ordering from §C.3 respected (FloorUnlock rank 4, DungeonRunOrchestrator rank 5). **Test fixture preconditions** (Pass-8 edit 2026-04-21 — closes CONCERN C-12: boilerplate repeated explicitly rather than relying on "see AC-FU-13"):
- `FloorUnlock.debug_reset()` in `before_each` to guarantee `_unlock_state == {"forest_reach": 0}`.
- Filesystem-level save isolation: delete `user://save_slot_1.dat` + `.bak` before workspace boot, OR run in a fresh GdUnit4 test project, to prevent prior-run state leak (per AC-FU-13 isolation strategy; depends on I.14 cross-GDD resolution of Save/Load #3's missing public save-path knob).
- **Connection-mode invariant** (Pass-8 edit 2026-04-21 — closes BLOCKING-4): verify that `FloorUnlock`'s `_ready()` connects via default flags (`0`), NOT `CONNECT_DEFERRED`. A deferred connection would push handler execution to the end of the current frame; the THEN clauses below assert immediately after `.emit()` and would silently observe pre-signal state. The `_ready()` block at §C.1 R3 is specified to use default-flag `.connect(...)` — this AC is fragile to any future refactor that adds `CONNECT_DEFERRED` without updating the WHEN to include an explicit `await get_tree().process_frame`. Test MUST assert synchronous dispatch before proceeding: `assert_bool(DungeonRunOrchestrator.floor_cleared_first_time.is_connected(FloorUnlock._on_floor_cleared_first_time)).is_true()` AND `assert_int(DungeonRunOrchestrator.floor_cleared_first_time.get_connections().filter(func(c): return c.flags & CONNECT_DEFERRED).size()).is_equal(0)`.

Pass-7 edit 2026-04-21 — closes BLOCKING-1 (prior pass): the Pass-6 "sibling Node instances (NOT via Godot's autoload system)" framing could not pass because `FloorUnlockSystem._ready()` connects to `DungeonRunOrchestrator` the autoload singleton via bare-name autoload lookup — a test that manually constructs both nodes would connect to a DIFFERENT instance than the one the test emits on, causing the handler never to fire and THEN clauses to silently fail. Mode-2 reclassification resolves this by using the real autoload instances throughout.

**WHEN** `DungeonRunOrchestrator.floor_cleared_first_time.emit(2, "forest_reach", false)` fires (synchronously — no `await` needed given the invariant asserted above)
**THEN**
- `FloorUnlock._on_floor_cleared_first_time` is invoked exactly once (verified via `captured_signals` counter or similar spy)
- `get_highest_cleared("forest_reach") == 2` after the emission
- `get_floor_state("forest_reach", 3)` → `FloorState.ACCESSIBLE`

*Writeable status*: **WRITEABLE**. Unblocked by Orchestrator GDD #13 Floor-Unlock-Propagation-Edit-3 (2026-04-20, signal payload extension). Verifies the subscription + handler dispatch behavior under the real autoload system (the production execution path). Test lives in `tests/integration/floor_unlock/`. Pass-7 tradeoff vs prior sibling-Node framing: the subscription mechanism is no longer tested in isolation from autoload init, but that isolation was illusory under Pass-6's GIVEN (see BLOCKING-1 closure above).

*Sub-AC 14-autoload-order* (Pass-4 edit 2026-04-21 — reclassified ADVISORY; Pass-6 edit 2026-04-21 — defines template/verifier/trigger per Pass-5 CONCERN-16): GdUnit4 cannot exercise Godot's autoload system. The autoload rank ordering (FloorUnlockSystem at rank 4, DungeonRunOrchestrator at rank 5 per §C.3) is verified as a **manual configuration check** with the following operational definition (added Pass-6 to close the "nobody runs this" gap):
- **Template**: `production/qa/smoke-checks/autoload-order.md` (to be created when QA tooling lands; until then, the verifier follows this AC's prose directly)
- **Verifier**: `qa-tester` (delegated by `qa-lead` via `/smoke-check`)
- **Trigger cadence**: every release-candidate build + any sprint that touches `project.godot` (verifier flag: `git diff <prev-tag>..HEAD project.godot` is non-empty)
- **Steps**: open `project.godot`, locate the `[autoload]` section, confirm `FloorUnlockSystem=` line appears before `DungeonRunOrchestrator=` line. Pass condition: rank ordering matches §C.3. Fail condition: any reorder requires either (a) reverting the reorder, or (b) re-running this AC's automated half AND verifying signal subscription survives the new order.

**Gate level: ADVISORY** (down from BLOCKING in Pass-3). **Status: PROSE-READY, NOT AUTOMATABLE TODAY** (Pass-8 edit 2026-04-21 — closes qa-lead BLOCKING P8-B-5: "writeable today" was false because the template file at `production/qa/smoke-checks/autoload-order.md` is TBD and the smoke-check directory may not exist). The AC prose above IS usable as a manual smoke-check checklist today — a verifier can open `project.godot` and follow the Steps directly — but the template-authoring deliverable tracked at I.10 is the artifact that would make this CI-automatable. Until I.10's CI parse script and `production/qa/smoke-checks/autoload-order.md` template both land, this sub-AC counts as ADVISORY prose-ready, not BLOCKING writeable. Promoting it back to BLOCKING is the right call once both artifacts ship.

### AC-FU-15 — Stale Biome ID in Save Preserved with Warning (Logic, BLOCKING) ✅ **NEW Pass-4 2026-04-21**

**GIVEN** `FloorUnlockSystem` (fresh instance) with `_warning_logger` DI overridden by a capturing closure (same setup as AC-FU-08); DataRegistry contains `"forest_reach"` (active) but does NOT contain `"deleted_biome"` (e.g., a biome from a prior MVP build that was renamed or removed)
**WHEN** `load_save_data({"highest_cleared": {"forest_reach": 2, "deleted_biome": 3}})` is called
**THEN**
- `captured.size() == 1`
- `captured[0]` matches `"FloorUnlockSystem: unknown biome_id 'deleted_biome' in save; preserving for forward-compat"`
- `_unlock_state["forest_reach"] == 2` (legitimate biome loaded normally)
- `_unlock_state["deleted_biome"] == 3` (preserved, NOT deleted — forward-compat per §E "stale biome_id" edge case)
- `is_biome_available("deleted_biome") == false` (filtered out of UI surfaces)
- `get_floor_state("deleted_biome", 1) == FloorState.UNAVAILABLE`
- `get_available_biomes() == ["forest_reach"]` (stale biome does not pollute the available list)

Verifies the §E "stale biome_id" forward-compat contract: a future DLC/patch re-adding the biome under the same id should re-activate the player's progress without requiring a save migration. (Pass-4 promotion rationale: Pass-3's `_warning_logger` DI made this trivially testable; the prior "Intentionally Deferred AC-FU-15" deferral was based on Pass-2's unassertable spec, which no longer holds. The cost of the AC is ~15 lines of test code; the cost of omission is silent loss of unlock data on biome rename. Promote.)

**AND WHEN** DataRegistry is reinitialized with a fixture directory containing `deleted_biome.tres` (status="active", dungeons[0].floors.size() == 5) — mechanism (Pass-8 edit 2026-04-21 — closes CONCERN C-11 from qa-lead: names the call sequence + build-mode requirement explicitly):

**Required build mode**: the test MUST run under a Godot editor/debug build (NOT a release export template) because `hot_reload_enabled` defaults to `false` in ship builds per Data Loading GDD #2 line 184. GdUnit4 integration tests invoked via `godot --headless --script tests/gdunit4_runner.gd` in debug mode satisfy this.

**Call sequence**:
```gdscript
# Step 1: Redirect DataRegistry's content root to a fixture path.
# `data_root_path` is a public String tuning knob per Data Loading GDD #2 §Tuning Knobs
# line 183 — dev-builds-only affordance; redirects all subsequent resource loads.
DataRegistry.data_root_path = "res://tests/fixtures/data_reactivated"
# The fixture directory must contain `forest_reach.tres` (original, active) +
# `deleted_biome.tres` (new, active, 5 floors) under the `biomes/` subdirectory
# layout DataRegistry expects.

# Step 2: Re-enumerate the biomes category via the existing hot-reload API
# (Data Loading GDD #2 §Rule 8 line 73 — `hot_reload(content_type: String)`).
# This clears the biomes category index, re-enumerates the new data_root_path,
# and re-registers resources. State transitions READY → HOT_RELOAD → READY per
# the table at line 90. Emits `hot_reload_complete("biomes")` on completion.
DataRegistry.hot_reload("biomes")

# Step 3: Wait for the hot-reload-complete signal so state derivation sees
# the re-registered Biome resources.
await DataRegistry.hot_reload_complete
```

Pass-7 edit 2026-04-21 — closes BLOCKING-6: Pass-6 cited `DataRegistry.stub_biome()` which does not exist in Data Loading GDD #2, and the fallback "direct cache write via OS.is_debug_build() guard" was not specific enough to be writable. Pass-8 corrects the Pass-7 "existing reload path" hand-wave by naming `hot_reload("biomes")` explicitly.
**THEN** the preserved counter drives correct state derivation without a save migration:
- `is_biome_available("deleted_biome") == true`
- `get_floor_state("deleted_biome", 1)` → `FloorState.CLEARED`
- `get_floor_state("deleted_biome", 2)` → `FloorState.CLEARED`
- `get_floor_state("deleted_biome", 3)` → `FloorState.CLEARED`
- `get_floor_state("deleted_biome", 4)` → `FloorState.ACCESSIBLE`
- `get_floor_state("deleted_biome", 5)` → `FloorState.LOCKED`
- `get_available_biomes()` now contains both `"forest_reach"` AND `"deleted_biome"`

(Pass-6 edit 2026-04-21 — closes Pass-5 BLOCKING-6: the AC previously verified preservation but never tested the re-activation path, which is the entire business value of preservation over deletion. A half-tested forward-compat contract gives false confidence that future biome re-add will "just work" — this AND WHEN/THEN closes that loop. Pass-7 edit 2026-04-21 — corrected the AND WHEN mechanism: Pass-6 cited `DataRegistry.stub_biome()` which does not exist in Data Loading GDD #2. Replaced with the `data_root_path` tuning-knob redirect which IS documented as a dev-build test affordance in GDD #2.)

### Classification Summary

(Pass-6 edit 2026-04-21 — added Test Location column per Pass-5 CONCERN-15: AC-FU-13 lives in `tests/integration/orchestrator/`, AC-FU-14 lives in `tests/integration/floor_unlock/`, but the prior table's Type column hid this split from sprint engineers allocating test-file creation.)

| AC ID | Description | Type | Gate | Test Location | Writeable Today |
|---|---|---|---|---|---|
| AC-FU-01 | Fresh-save default: F1 ACCESSIBLE, F2–F5 LOCKED | Logic | BLOCKING | `tests/unit/floor_unlock/` | YES |
| AC-FU-02 | WIN first-clear of F1 → F2 ACCESSIBLE | Logic | BLOCKING | `tests/unit/floor_unlock/` | YES |
| AC-FU-03 | LOSING first-clear advances identically to WIN | Logic | BLOCKING | `tests/unit/floor_unlock/` | YES |
| AC-FU-04 | Duplicate signal silent no-op (+ Sub-ACs 04-also-replay, 02-continuing-advance) | Logic | BLOCKING | `tests/unit/floor_unlock/` | YES (Pass-7: `_error_logger` DI + `captured_errors.is_empty()` assertion replace non-existent `assert_no_error_messages()`; Pass-6: reference added but API was imaginary; Pass-4: spy fixture removed) |
| AC-FU-05 | Out-of-range signal logs push_error, no mutation (+ Sub-ACs 05-predicate-boundaries, 05-dataregistry-miss, 05-unavailable-biome) | Logic | BLOCKING | `tests/unit/floor_unlock/` | YES (Pass-9: Sub-ACs 05-dataregistry-miss + 05-unavailable-biome added closing SD BLOCKINGs P9-B-1 + P9-B-2 — exercise the new `is_biome_available` guard and the DI-routed DataRegistry-miss branch; Pass-8: `begins_with` + `contains` loosening; Pass-7: `_error_logger` DI + `captured_errors[0]` format assertion; Pass-6: `_on_floor_cleared_first_time(-1, ...)` case + `is_unlocked(6)/(99)` added; Pass-4: predicate-boundary Sub-AC added) |
| AC-FU-06 | Save/Load round-trip preserves state (consumer-contract scope; HMAC bypass note) | Integration | BLOCKING | `tests/integration/floor_unlock/` | YES (Pass-6: HMAC bypass note added) |
| AC-FU-07 | Missing save key → fresh-save default | Logic | BLOCKING | `tests/unit/floor_unlock/` | YES |
| AC-FU-08 | Out-of-range saved value clamped with warning (+ Sub-ACs 08-negative, 08-float-cast-clean, 08-float-cast-lossy, 08-non-numeric, 08-null, 08-bool, 08-float-lossy-and-overrange) | Logic | BLOCKING | `tests/unit/floor_unlock/` | YES (Pass-8: 08-null + 08-bool Sub-ACs added closing BLOCKING-10; Pass-6: `_unlock_state.has(...)` assertion + 08-float-lossy-and-overrange Sub-AC added; Pass-4: lossy-cast + non-numeric Sub-ACs added) |
| AC-FU-09 | `get_floor_state` covers all four enum values | Logic | BLOCKING | `tests/unit/floor_unlock/` | YES (DataRegistry stub) |
| AC-FU-10 | `planned_v1` biome unavailable & absent from `get_available_biomes` | Logic | BLOCKING | `tests/unit/floor_unlock/` | YES (DataRegistry stub) |
| AC-FU-11 | `is_biome_completed` false→true on F5 clear | Logic | BLOCKING | `tests/unit/floor_unlock/` | YES |
| AC-FU-12 | State monotonicity: `_unlock_state` never decreases | Logic | BLOCKING | `tests/unit/floor_unlock/` | YES |
| AC-FU-13 | Orchestrator integration: locked floor → RUN_ENDED (Mode-2 integration) | Integration | BLOCKING | `tests/integration/orchestrator/` | ✅ WRITEABLE-WITH-CI-CONSTRAINT (Pass-9: filesystem cleanup MUST run as pre-launch shell step before Godot boots — `before_each` delete is post-autoload-boot and cannot isolate; closes qa-lead BLOCKING P9-B-2. Pass-6: verified-API-only isolation strategy + test placement constraint added; Pass-4: explicit fixture preconditions added) |
| AC-FU-14 | Signal subscription live at Orchestrator emission | Integration | BLOCKING | `tests/integration/floor_unlock/` | ✅ WRITEABLE (Pass-7: reclassified to Mode-2 real autoload tree — sibling-node construction from Pass-3/4/5/6 could not pass because `_ready()` connects to autoload singleton via class_name, not to a manually-constructed sibling; Mode-2 uses production execution path) |
| Sub-AC 14-autoload-order | `[autoload]` section ordering | Manual smoke-check | **ADVISORY** | `production/qa/smoke-checks/autoload-order.md` (template TBD) | **PROSE-READY** (Pass-8 edit — closes qa-lead BLOCKING P8-B-5: NOT "writeable today"; AC prose is usable as manual checklist, but the template file + smoke-check directory are TBD until I.10 ships both a CI parse script and the template authored by qa-lead) |
| AC-FU-15 | Stale biome_id in save preserved with warning + re-activation forward-compat | Logic | BLOCKING | `tests/unit/floor_unlock/` (primary) + `tests/integration/floor_unlock/` (re-activation step — `data_root_path` redirect requires real autoload tree) | ✅ Pass-7 re-activation mechanism corrected to use existing Data Loading `data_root_path` tuning knob (GDD #2 line 183) — Pass-6 cited non-existent `DataRegistry.stub_biome()`; Pass-4 NEW + Pass-6 continuation step added |
| AC-FU-16 | `floor_unlocked` signal emits exactly once per frontier advance — and only on advance (not on idempotent replay, final-floor clear, validation rejection, or `load_save_data` hydration); LOSING/WIN parity per R5 | Logic | BLOCKING | `tests/unit/floor_unlock_system/floor_unlock_system_test.gd` (Group F2) | ✅ Pass-10 NEW 2026-05-07 — closes Sprint 16 S16-M3 sweep #3 drift (Matchup Assignment GDD #23 §C.2 + §E.3 + AC-23-15 reference signal); 6 Sub-ACs cover advance / replay / final-floor / LOSING / validation-reject / hydration paths |

### Intentionally Deferred (Out of MVP Scope)

- **V1.0 biome-chain unlock**: `is_biome_available("sunken_ruins")` transitions `false→true` when `is_biome_completed("forest_reach")` — deferred to V1.0 biome-chain design pass (§I Open Questions). Schema accommodates it; the rule is not yet designed.
- **Content-patch biome activation**: loading an existing save after a `planned_v1→active` status flip — a V1.0 release-QA integration test.
- **`debug_unlock_all` flag suppresses locks** (G.2) — a smoke-check concern; test via manual `/smoke-check`, not CI.
- **Cozy-register experiential AC** (Pass-4 deferral): a playtest acceptance criterion ("blind first-time clearer describes unlock as calm/satisfying/quiet, not exciting/flashy") is the right validation but lives in `/playtest-report` cadence, not in the GDD's automated AC list. Add to playtest checklist when UI #25 ships.

### Upstream Blocker Note (✅ RESOLVED Pass-3 2026-04-21)

AC-FU-13 and AC-FU-14 share a single root-cause blocker that is now resolved: Orchestrator GDD §C.3 + §F propagation edits #3 (extending `floor_cleared_first_time` to 3-param payload) and #4 (removing the MVP F1-only stub, promoting AC-ORC-13 to BLOCKING) were applied 2026-04-20 via Floor-Unlock-Propagation-Edit-3.

**Pass-9 edit 2026-04-21 wiring changes** (Pass-8 fresh-context independent Pass-9 re-review was expected to return APPROVED or CONCERNS-only; instead surfaced 6 NEW BLOCKING + 9 CONCERN + 3 NICE across 5 specialists. Per-pass surfacing rate dropped 12→6 — first downward trend after six cycles — but cycle still not converged. Of the 6 BLOCKINGs: 2 systems-designer doc-vs-code drift (§E phantom guard that wasn't in R9 code; §C.1 R9 `push_error` that bypassed the `_error_logger` DI pattern); 2 qa-lead testability (Sub-ACs 08-null/bool shared `captured` array accumulation; AC-FU-13 `before_each` filesystem cleanup runs AFTER autoload boot); 2 game-designer fantasy-propagation (§B ¶4 "loses" ambiguity cascading through §F mini-table; §F row 3 MUST NOT locked without MDA defense). The cross-model 3-specialist CONCERN on `PROPERTY_HINT_PLACEHOLDER_TEXT` → `PROPERTY_HINT_NONE` is the THIRD consecutive wrong engine-idiom claim (Pass-6 `@export`, Pass-7 bare `get_setting`, Pass-8 wrong hint constant) — confirming the I.11 per-pass engine-idiom-verification lesson that was not executed pre-Pass-9. 3 user design decisions captured (D1 §E guard-add to R9; D2 §B ¶4 "abandons the run before it completes"; D3 §F row 3 MDA rationale + appeal path). All 6 BLOCKING resolved in-GDD. Inter-specialist disagreement from Pass-8 on autoload rank-order `_ready()` signal availability now definitively RESOLVED: both godot-gdscript AND godot-specialist returned CORRECT-AS-WRITTEN this pass; all autoload nodes added to scene tree before any `_ready()` fires.):

- §C.1 R3 `add_property_info` call: `PROPERTY_HINT_PLACEHOLDER_TEXT` → `PROPERTY_HINT_NONE` (cross-model 3-specialist CONCERN — godot-specialist + godot-gdscript + systems-designer agreement; third consecutive wrong engine-idiom claim).
- §C.1 R9 handler: added `is_biome_available(biome_id)` guard as the FIRST check (systems-designer BLOCKING P9-B-1 + D1 user decision — closes §E doc-vs-code drift where the guard was documented but not implemented). V1.0-defensive against status-rollback bugs.
- §C.1 R9 handler: converted `push_error(...)` calls for BIOME_FLOOR_COUNT miss + invalid-floor-index branches to `_error_logger.call(...)` for DI consistency with every other error path (systems-designer BLOCKING P9-B-2).
- §D.4 pseudocode: mirrored the §C.1 R9 changes exactly (new unavailable-biome guard + DI-routed errors).
- §E edge-case prose: updated "invalid floor_index" and "unavailable biome" paragraphs to cite `_error_logger.call()` (Pass-9 DI routing) and note that the unavailable-biome guard is NOW actually implemented in R9 (prior passes documented it in §E without code — closed Pass-9 SD B-1).
- §B ¶4 "Presence is first-clear, not first-dispatch": replaced "loses partway through" with "abandons the run before it completes" + disambiguation of incomplete-run vs LOSING-first-clear (game-designer BLOCKING P9-B-1 + D2 user decision). Added explicit note that the distinction is load-bearing for §F mini-table row 4 propagation.
- §F mini-table row 3 (Guild Hall #19 UNAVAILABLE=hidden): added MDA player-fantasy rationale ("contained world" / "invitation vs upsell" register) + symmetric appeal path matching row 1 (game-designer BLOCKING P9-B-2 + D3 user decision). Downstream author now has design-authority context + challenge path.
- §F mini-table row 2 (ACCESSIBLE-visual MUST NOT): added affirmative spec citing warm "this is where we are now" palette per §B + §C.2 (systems-designer CONCERN P9-C-4 — closes "prohibits without spec" gap).
- §H AC-FU-05: added Sub-AC 05-dataregistry-miss + Sub-AC 05-unavailable-biome (Pass-9 SD B-1 + B-2 closure); added format-string test-intent note preserving `biome=%s` vs `biome_id='%s'` divergence (game-designer CONCERN P9-C-3).
- §H AC-FU-08 preamble: added assertion-style note explaining why Sub-ACs retain exact-string equality (step-identification signal) rather than loosening to `begins_with`/`contains` like AC-FU-05 (different load-bearing test signals) (systems-designer CONCERN P9-C-1).
- §H AC-FU-08 Sub-ACs 08-null + 08-bool: added Sub-AC test-isolation contract explicitly stating each Sub-AC is an independent `@test` function with fresh `captured` array via re-run `before_each` (qa-lead BLOCKING P9-B-1 — closes cumulative `captured.size()` order-dependence).
- §H AC-FU-09 + AC-FU-10: added DataRegistry fixture specification to GIVEN (qa-lead CONCERN P9-C-1 — unit ACs using `FloorUnlockSystem.new()` cannot rely on `_ready()`-populated DataRegistry state).
- §H AC-FU-13: reclassified "WRITEABLE" → "WRITEABLE-WITH-CI-CONSTRAINT" with precise pre-launch filesystem-cleanup instructions (qa-lead BLOCKING P9-B-2 — `before_each` runs post-autoload-boot and cannot achieve save isolation alone).
- §H common fixture preconditions block: added inline comment distinguishing `FloorUnlockSystem` (class_name for `.new()` construction) from `FloorUnlock` (autoload name for queries) to prevent downstream GDD authors writing `FloorUnlock.new()` (systems-designer CONCERN P9-C-3).
- §G.1 `active_biome_mvp` knob row: explicit 5-step numbered designer workflow (game-designer CONCERN P9-C-1 — documents the "run the game once first" prerequisite that Pass-8's "designers can change without code edit" phrasing hid).
- GDD header status: "block APPROVED verdict" phrasing clarified to "in-GDD content APPROVED pending I.14 + I.15 upstream resolution" (game-designer NICE P9-N-2 + systems-designer NICE P9-N-1).
- Classification Summary: updated AC-FU-05 row (new Sub-ACs) + AC-FU-13 row (WRITEABLE-WITH-CI-CONSTRAINT).

Pass-9 specialist findings deliberately not actioned (recorded for traceability):
- game-designer CONCERN P9-C-2 (§B opening paragraph overstep into undesigned UI specifics like "soft pencil sketch" + "little pixel-art creatures"): valid — these specifics belong in Art Bible or #19 design brief, not §B. Bundled with deferred fantasy-framing pass (game-designer C8-1 + N8-1 + this).
- game-designer NICE P9-N-1 (§B paragraph reorder for emotional arc): bundle with fantasy-framing pass above.
- godot-gdscript NICE (minor `_active_biome_id()` body stub visibility): acceptable as inline comment; skip.
- qa-lead CONCERN P9-C-2 (Sub-AC 14-autoload-order template TBD process gap): ADVISORY gate is appropriate; recorded as sprint-zero deliverable for qa-lead when QA tooling lands. Not a GDD edit this pass.

**Cross-pass pattern** (author note — updated after Pass-9): per-pass BLOCKING surfacing rate 12→6→6→10→12→6. Pass-9 is the first downward trend. Two structural defect clusters remain — testability (qa-lead + systems-designer cross-specialist) and engine-idiom (godot-gdscript + godot-specialist cross-specialist). The empirical Godot boot probe recommended in Pass-7 + Pass-8 review logs has still not been run; it is the single highest-leverage pre-Pass-10 action (resolves `PROPERTY_HINT_NONE` verification AND the autoload rank-order question left as "evidence weighs toward godot-specialist"). Recommendation: run the probe before implementation commits, NOT before Pass-10 re-review — Pass-9's resolution is now consistent with both specialists' positions and does not need further doc revision to hold. Further Floor Unlock #16 Pass-10 re-review is optional; cross-GDD I.14 + I.15 resolution in Save/Load #3 and Orchestrator #13 is mandatory.

---

**Pass-8 edit 2026-04-21 wiring changes** (Pass-7 fresh-context independent re-review was expected to return APPROVED or CONCERNS-only; instead surfaced 12 NEW BLOCKING + 14 CONCERN + 4 NICE across 5 specialists — including the new godot-specialist engine-idiom verification pass recommended in Pass-7's review-log author note. The per-pass defect-surfacing rate is still not converging; of the 12 Pass-8 BLOCKINGs, 2 are flaws in Pass-7's own fixes (the ProjectSettings auto-UI claim and the phantom Economy subscriber propagation edit), same self-introduced-false-precision pattern Pass-6 exhibited. 4 user design decisions captured; 10 of 12 BLOCKING resolved in-GDD; 2 refiled as cross-GDD Open Questions I.14 + I.15):

- §C.1 R1 `_unlock_state`: added stable-for-test-access annotation (CONCERN C-14 / P8-N-1: sub-ACs assert `_unlock_state.has(...)`; rename breaks tests without behavioral regression).
- §C.1 R1-typing: qualified "raises at runtime" as debug-build-only; explicitly named §E step 3 `int()` cast as production-safe protection regardless of build type (CONCERN C-1 — cross-model godot-gdscript + godot-specialist).
- §C.1 R3 `_ready()` `active_biome_mvp` setup: full chain reworked to `ProjectSettings.set_initial_value(...)` + `ProjectSettings.add_property_info(...)` + `ProjectSettings.get_setting(...)` (BLOCKING-1 + D1 user decision: Pass-7's bare `get_setting` claim was wrong — key is invisible in editor UI without `set_initial_value` registration; cross-model godot-gdscript + godot-specialist convergence). §G.1 knob row updated to reflect full workflow; §I.11 closure note amended with second-pass correction of engine-idiom-inheritance lesson.
- §C.1 R3 `_ready()` validator fallback: added `_valid_active_biomes.has("forest_reach")` guard + first-active-biome fallback + soft-brick return (CONCERN godot-N-1: V1.0 content migration that removes forest_reach would otherwise silently mis-configure).
- §C.1 R3 autoload-identifier comment: replaced Pass-7's factually-wrong "`class_name` must match autoload name" claim with accurate constraint (BLOCKING-2 + D2 user decision: `class_name` is orthogonal to autoload singleton access; the load-bearing constraint is that the registered autoload name in `project.godot` matches the bare identifier used in code).
- §C.1 R3 `_ready()` connect call: added explicit MUST-NOT-use-CONNECT_DEFERRED comment (BLOCKING-4 from qa-lead: AC-FU-14 asserts synchronous dispatch; a deferred connection would silently fail all THEN clauses).
- §C.1 R3 `print_verbose` comment: corrected from "suppressed in production builds" (build-type language) to "suppressed when `--verbose` not passed at launch" (runtime launch-flag check via `OS.is_stdout_verbose()`) (CONCERN C-2 — godot-gdscript engine-idiom correction).
- §C.1 R4: enumerated BOTH clamp exceptions (step 4 under-range + step 5 over-range) as the only defined decrement paths; noted monotonicity invariant applies within-session only; cross-session recovery conditional on Offline Engine #12 per I.12 (CONCERN C-7 + C-8 from systems-designer).
- §C.1 R5: clarified `losing_run` is not read by Floor Unlock but IS globally load-bearing in signal payload (CONCERN C-6: implementers must preserve it in propagation edits #6/#7).
- §C.3 autoload order: explicitly decoupled autoload registered name (`FloorUnlock`) from script `class_name` (`FloorUnlockSystem`) per D2 decision; closes CONCERN C-10 (systems-designer: Biome DB §E.1 line 335 uses `FloorUnlock.is_unlocked(...)` short form which IS the autoload name, not a typo).
- §C.3 step 5 prose: matched "No data loss" conditional language to §C.1 R9 + I.12 + new I.15 (BLOCKING-12 from game-designer: prior prose contradicted R9's conditional claim in the same document). Recovery explicitly named as CONDITIONAL on both Offline Engine #12 replay AND Orchestrator §C.4 offline-path emit (currently absent — see I.15).
- §E step 5 over-range clamp: locked `.get(biome_id, 0)` form (not direct key access `[biome_id]`) for empty-dict safety (CONCERN C-9: prevents AC-FU-08 Sub-ACs from failing-by-crash instead of failing-by-assertion when `BIOME_FLOOR_COUNT` unpopulated).
- §F propagation edit #6: rephrased from "Economy subscriber MUST be updated" to "Verified no subscriber exists per Economy §C.5 line 187 — retained as anti-regression trip-wire" (BLOCKING-8 + D3 user decision: Economy deprecated signal subscription in Pass 4B-Economy; Pass-7 edit was cross-GDD-phantom same class as Pass-6's `DataRegistry.stub_biome()`). Also flagged Economy §C.5 line 481 contradiction as cross-GDD drift for Economy Pass-5 follow-up (not Floor Unlock's to fix).
- §F: NEW "Cross-System Behavioral Constraints" mini-table (BLOCKING-11 + D5 user decision from game-designer B8-1): tabulates behavioral MUST NOTs per consumer GDD (#17/#19/#23/#25) with §B/§C.1 R5 cross-refs, closing the propagation gap where the MUST NOTs lived in §B only but bound 4 undesigned downstream UIs.
- §H preamble: added common fixture-preconditions block documenting the `BIOME_FLOOR_COUNT = {"forest_reach": 5}` + DI-override `before_each` setup mandatory for every unit AC (BLOCKING-7 from qa-lead P8-B-1 + systems-designer B-4: `FloorUnlockSystem.new()` leaves dict empty, causing F1=LOCKED crashes on every unit test without this setup); reconciled count to "15 BLOCKING + 1 ADVISORY sub-AC = 16 table rows" (BLOCKING-6 from qa-lead P8-B-6).
- §H AC-FU-05: replaced hard-coded error-message exact-string equality with `begins_with` + `contains` assertions on the load-bearing signal (prefix + floor_index + biome_id) (qa-lead BLOCKING P8-B-2: prior exact-string equality was fragile to non-behavioral message-wording refactors).
- §H AC-FU-08: added Sub-AC 08-null (TYPE_NIL / JSON `null`) + Sub-AC 08-bool (TYPE_BOOL) (BLOCKING-10 from systems-designer: §E step 1 type guard handles these correctly but no sub-AC verified; attack vectors unlocked).
- §H AC-FU-13: refiled `SaveLoadSystem.save_file_path` redirect to I.14 as cross-GDD Save/Load dependency (BLOCKING-3 from qa-lead P8-B-3: verified `save_file_path` does not exist as a public knob — same phantom-API failure class as Pass-6's `DataRegistry.stub_biome()`); replaced with filesystem-level cleanup + fresh-test-project guidance until Save/Load #3 ships the knob or `debug_reset_to_fresh()` API.
- §H AC-FU-14: added CONNECT_DEFERRED-forbidden invariant assertion in GIVEN (BLOCKING-4); repeated save_file_path isolation context inline rather than "see AC-FU-13" (CONCERN C-12 from systems-designer N-2: sprint engineer reading only AC-FU-14 would miss it).
- §H AC-FU-15: replaced "reload DataRegistry via its existing reload path" hand-wave with explicit `DataRegistry.data_root_path = ...; DataRegistry.hot_reload("biomes"); await DataRegistry.hot_reload_complete` call sequence + `hot_reload_enabled` build-mode requirement (CONCERN C-11 from qa-lead P8-C-1: Pass-7 correctly identified `data_root_path` + `hot_reload` existence but did not name the call sequence).
- §H Sub-AC 14-autoload-order: reclassified "writeable today" → "PROSE-READY, NOT AUTOMATABLE TODAY" (BLOCKING-5 from qa-lead P8-B-5: template at `production/qa/smoke-checks/autoload-order.md` is TBD; same fixture-not-writable-confession class as Pass-6's phantom API references).
- §I: NEW I.14 (Save/Load #3 public save-path knob dependency) closing BLOCKING-3 by refile; NEW I.15 (Orchestrator #13 offline-path emit missing + Economy §C.5 line 481 triple-contradiction) closing BLOCKING-9 by refile.
- §I.11: amended closure note with Pass-8 `set_initial_value` + `add_property_info` correction + reinforced engine-idiom-verification lesson across two passes (Pass-6 @export → Pass-7 bare get_setting → Pass-8 full registration).

Pass-8 specialist findings deliberately not actioned in this pass (recorded for traceability):
- systems-designer C-2 retained: R4 exception clause now enumerates both cases — CLOSED above.
- systems-designer C-5 retained: Biome DB line 335 uses `FloorUnlock.is_unlocked(...)` — resolved by D2 (autoload name is intentionally `FloorUnlock`; script class_name is `FloorUnlockSystem`).
- qa-lead P8-N-1 `_unlock_state` rename-breaks-tests annotation — CLOSED above (C-14 annotation added to §C.1 R1).
- game-designer C8-1 §B "walked vs completed" prose contradiction: retained as-is — still unfixed 5 passes old, but requires a §B rewrite outside Pass-8 scope; worth a dedicated fantasy-framing pass. Recommend revisit after first-return playtest.
- game-designer C8-2 I.9 trigger not actionable (no measurement window, instrumentation spec, response-protocol owner): retained — analytics-engineer owns instrumentation spec when #12 ships; response protocol belongs with game-designer + live-ops-designer when signal fires; premature to design the response menu now.
- game-designer C8-3 No AC verifies Economy propagation: superseded by BLOCKING-8 closure — edit #6 is now an anti-regression trip-wire, not an action item needing AC coverage.
- game-designer C8-4 §C.1 R5 `losing_run` wording: CLOSED above (C-6 amendment in §C.1 R5).
- game-designer N8-1 §B paragraph ordering: deferred — pure edit but requires fantasy-framing rewrite; bundle with C8-1.
- game-designer N8-2 I.12 cross-ref to Offline Engine #12: valid; record here — when Offline Engine #12 is authored, its §F Dependencies MUST require a Floor Unlock #16 recovery-claim re-review (cross-ref to I.12 + I.15) before #12 can be APPROVED.
- godot-gdscript Item 4 lambda-in-field Callable: retained as low-concern for autoload-owned Node state (not Resource — serialization not applicable).
- godot-gdscript Item 5 godot-C-1 typed-dict 4.5/4.6 stability: CLOSED above (C-1 qualification).
- godot-gdscript Item 6 godot-C-2 `.new()` double-instantiation: retained — no Godot 4.6 engine guard exists; Mode-1 vs Mode-2 distinction is the correct mitigation.
- godot-gdscript Item 7 godot-C-4 `OS.is_debug_build()` cost: confirmed negligible; cross-specialist with godot-specialist Claim 7.
- godot-gdscript Item 8: DISAGREEMENT with godot-specialist Claim 6 on autoload `_ready()` ordering. godot-gdscript argued rank-4 cannot connect to rank-5 Orchestrator because the node doesn't exist yet; godot-specialist returned CORRECT-AS-WRITTEN citing that all autoload nodes are added to scene tree before any `_ready()` fires (signal object exists at connect-time). Evidence weighs toward godot-specialist; godot-gdscript's own analysis oscillated mid-reasoning. Recommended: empirical 5-line boot probe before implementation (document result in `docs/engine-reference/godot/modules/autoload.md` per Pass-8 process recommendation).
- godot-specialist Claim 4 typed dict release enforcement: CLOSED above (C-1 qualification).

**Pass-7 edit 2026-04-21 wiring changes** (Pass-6's fresh-context independent re-review was expected to return APPROVED or CONCERNS-only; instead surfaced 10 NEW BLOCKING + 14 CONCERN + 6 NICE — the per-pass defect-surfacing rate is still ahead of the closure rate. 4 user design decisions captured this pass):
- §C.1 R1 `active_biome_mvp`: reverted from Pass-6's `@export var` to plain `var` populated via `ProjectSettings.get_setting("floor_unlock/active_biome_mvp", ...)` in `_ready()` (BLOCKING-3 + user decision: @export on autoload is NOT Inspector-surfaced in normal editor workflow — Pass-5 NTH-2 confirmation was wrong; ProjectSettings pattern is genuinely designer-accessible).
- §C.1 R1 field list: added `_error_logger: Callable` DI (BLOCKING-5 + user decision: replaces non-existent GdUnit4 `assert_no_error_messages()` with DI pattern matching Orchestrator §J.4, combat-resolution, matchup-resolver) + added class-level `BIOME_FLOOR_COUNT: Dictionary[String, int]` declaration (Pass-6 CONCERN systems-C-5 + godot-C-5: referenced 5+ times but never declared).
- §C.1 R3 `_ready()`: (a) ProjectSettings-load of `active_biome_mvp` with validator that resets invalid values via `_error_logger` (CONCERN systems-C-2: Pass-6 "validated against Biome DB" was aspirational prose with no code); (b) population of `BIOME_FLOOR_COUNT` from DataRegistry post-validation; (c) note on class_name/autoload-name identity requirement as a load-bearing implementation constraint (BLOCKING-10).
- §C.1 R3 (signal payload paragraph): corrected Pass-3→Pass-6 "remain compatible" claim — Godot 4.x raises on signal/Callable arity mismatch, not silent truncation. Existing Economy + Dungeon Run View #24 subscribers MUST be updated with default-parameter values (BLOCKING-2 + user decision: propagation edits #6 + #7 added to §F).
- §C.1 R4: added explicit exception clause for §E step 5 content-patch clamp (Pass-6 CONCERN systems-C-3: R4 "no code path decrements" was contradicted by the clamp; exception now documented as the only defined decrement path).
- §C.1 R9 comment: weakened "no data loss" recovery claim to "recovered IF Offline Engine correctly replays" (BLOCKING-8). The recovery chain is load-bearing for Pillar 1 but conditional on Offline Progression Engine #12 (undesigned). Tracked as I.12.
- §D.2 pseudocode: added `h = _unlock_state.get(b, 0)` cache before CLEARED/ACCESSIBLE checks to byte-mirror §C.2 GDScript's `var highest` (BLOCKING-4: Pass-6 pseudocode called `.get()` twice inline, violating the byte-identical standard Pass-4 set for §D.4).
- §E step 1: locked type-check mechanism to `typeof(loaded_value) not in [TYPE_INT, TYPE_FLOAT]` (BLOCKING-9: Pass-6 prose "not int or float" was under-specified; a QA engineer could read it as "parseable as number" and test with `"3.7"` string — clarified that GDScript's `typeof()` makes the check rigorous).
- §F propagation edit #1: flipped stale "required" row to ✅ DONE (verified at Biome DB §E.1 line 335; the edit had been applied in Pass-2 timeframe but §F was not updated). Bidirectional consistency check row also updated.
- §F propagation edits #6 + #7: NEW — Economy subscriber update + Dungeon Run View #24 design-time constraint for the 3-arg signal payload with default values (BLOCKING-2 propagation).
- §H AC-FU-04: replaced `assert_no_error_messages()` with `_error_logger` DI + `captured_errors.is_empty()` (BLOCKING-5).
- §H AC-FU-05: replaced implicit `push_error` capture with `_error_logger` DI + `captured_errors[0]` format match (BLOCKING-5).
- §H AC-FU-13: added `SaveLoadSystem.save_file_path` temp-redirect precondition + documented the autoload-`_ready()` vs test-`before_each` execution order invariant (BLOCKING-7: Pass-6 "do not co-locate" prose was convention, not technical guarantee).
- §H AC-FU-14: reclassified from "sibling Node instances" to "real autoload tree Mode-2" matching AC-FU-13 (BLOCKING-1 + user decision: sibling-node test could not pass because `_ready()` connects to autoload singleton via class_name, not to test sibling).
- §H AC-FU-15: replaced non-existent `DataRegistry.stub_biome()` with existing `data_root_path` tuning-knob redirect (BLOCKING-6). Reclassified primary test location to mixed unit + integration because the re-activation step requires real autoload tree.
- §H preamble: corrected stale "14 criteria total (12 writeable today + 2 pending)" to "15 criteria total, all writeable today" (NICE-5: stale since Pass-4 AC-FU-15 promotion).
- §I.11: reopened and re-closed via ProjectSettings pattern. Pass-6 closure was based on Pass-5 NTH-2 "confirmed" claim that was not engine-verified. Corrected resolution records the lesson: engine-idiom claims require per-pass verification against Godot docs, not inheritance from prior-pass notes.
- §I.12: NEW — Offline Engine dependency on crash-in-window recovery (BLOCKING-8).
- §I.13: NEW — `dungeons[0]` V1.0 multi-dungeon landmine (Pass-6 game-C-7 + systems-N-1 deferral had no tracking entry).

Pass-6 specialist findings deliberately not actioned in Pass-7 (recorded for traceability):
- game-B-1 (§B fantasy defense hand-waves the LOSING-grind tension): design-judgment call, not mechanical defect. The "no gold surplus" defense is arithmetically correct; the game-designer argues §B should rewrite the fantasy framing to match the mechanics rather than defend the fantasy framing. User retained Pass-6 framing. Recommend revisiting after first-return playtest generates actual experiential data.
- game-B-2 (identical fanfare lock rationale is weak): user retained Pass-6 framing with the UI #25 appeal path. Acknowledged as tradeoff; playtest is the arbiter.
- game-B-3 (ACCESSIBLE visual MUST NOT over-specifies undesigned systems): user retained Pass-6 framing. Acknowledged that the "MUST NOT" is currently binding on UI #25/#19/#23 without those systems having been consulted; appeal path in §B applies here too.
- game-C-1 (30% threshold uncalibrated): valid signal-interpretation concern. Retained as-is; analytics-engineer will refine the metric when instrumentation lands.
- game-C-2 (§B "walked" vs "completed" contradiction): valid. Not corrected in this pass to avoid further §B surgery without user input; worth revisiting on the next fantasy-framing pass.
- game-C-3 (UNAVAILABLE = hidden contradicts retention hook): valid — but UI rendering is downstream of this GDD; flagged to UI #19 designer when that system is authored. Not corrected here because the MUST NOT is user-accepted per game-B-3.
- game-C-4 (I.9 has no response protocol): valid — but the response-protocol design belongs with game-designer + live-ops-designer when the 30% signal actually fires. Retained I.9's current trip-wire form; a design-call response menu would be premature.
- game-C-5 (no owner for deferred cozy-register experiential AC): recorded here — when UI #25 ships, `/playtest-report` should include a "cozy register" section authored by game-designer. No GDD edit in this pass.
- game-C-8 (cozy-register as unexamined axiom cumulatively hollowing Pillar 3): valid risk-framing. Worth carrying to a design-director review when one is invoked (solo mode currently skips that gate); not mechanically actionable here.
- systems-C-4 (Mode-2 cross-GDD definition coupling): valid but low-priority. Adding a local "Mode-2 means real autoload tree, no `.new()` construction" gloss in Floor Unlock is tempting; retained cross-ref to Orchestrator §J.3 to avoid drift.
- systems-C-5 (Rule 13/14 float concerns claim misleading): valid — §C.3 consumer table row could mislead an engineer into thinking §E step 3 is optional. Considered minor; retained as-is because §E step 3 is separately and clearly stated.
- systems-C-6 (typed dict enforcement advisory in release): valid — typed dict is not a safety net in release builds. §E step 3's `int()` cast is the real protection. Kept R1-typing wording; worth a future spec-precision pass.
- systems-C-7 (`is_unlocked` CLEARED-vs-ACCESSIBLE distinction not documented): valid — `is_unlocked` is a coarse gate, not a state discriminator. Minor; callers needing the distinction use `get_floor_state`.
- systems-C-8 (synchronous signal guarantee not stated): valid — a `call_deferred` on `_on_floor_cleared_first_time` would silently break persist safety. Not documented in this pass; worth adding to an implementation-constraint checklist when sprint planning lands.
- qa-C-2 (Sub-AC 08 index-ordered assertions brittle): valid — set-containment would be more refactor-tolerant. Retained index form as documenting the §E step ordering contract explicitly.
- qa-C-3 (`typeof()` int code for String not stated): valid — tester needs `TYPE_STRING == 4` knowledge. Minor; the wildcard format string accepts any int, so the test still passes regardless.
- qa-C-4 (Sub-AC 14-autoload-order template author unnamed): valid — qa-lead owns template authoring when QA tooling lands. Recorded here.
- qa-C-5 (AC-FU-06 HMAC end-to-end test has no owner): valid — belongs as a Save/Load #3 follow-up Open Question, not Floor Unlock #16. Flag at Save/Load review.
- qa-C-6 (private-var coupling in ACs): valid — `_unlock_state.has(...)` test couples to internal var name. Retained because a `get_raw_state()` accessor adds API surface for testing-only concerns.
- qa-C-7 (AC-FU-09 over-range LOCKED scope ambiguity): valid — Sub-AC 05-predicate-boundaries covers it. Test co-location is the engineer's call at implementation time.
- qa-C-8 (AC-FU-13 WHEN dispatch method name not cited): valid — Orchestrator is signal-driven (`dispatch_pressed`), not method-driven. Tester must cross-ref Orchestrator GDD for the signal name. Low-urgency.
- qa-C-9 (AC-FU-14 sibling-node `_ready()` autoload-ref): **fixed as BLOCKING-1 above** via Mode-2 reclassification.
- godot-C-1 (typed dict 4.5/4.6 stability unverified): valid — Godot 4.5/4.6 are HIGH migration risk per VERSION.md. Kept R1-typing wording; worth engine-test verification pre-implementation.
- godot-C-2 (class_name on autoload enables `.new()` double-instantiation): valid — unit tests calling `FloorUnlockSystem.new()` create non-singleton instances. Implicit in the Mode-1 vs Mode-2 distinction the GDD already draws.
- godot-C-3 (lambda-in-field Callable not serialization-safe): valid — named-method pattern is cleaner. Retained lambda form for consistency with existing code blocks.
- godot-C-4 (`OS.is_debug_build()` per-frame cost): not a real concern at MVP scale (5 floors × a few UI frames). Recorded.
- godot-C-5 (`BIOME_FLOOR_COUNT` declaration): **fixed above** via class-level `var BIOME_FLOOR_COUNT: Dictionary[String, int] = {}` declaration + `_ready()` population.
- godot-C-6 (`_active_biome_id()` V1.0 evolution underspecified): valid — the V1.0 injection mechanism is not sketched. Deferred to V1.0 design pass.
- godot-C-7 (`enum FloorState` scope ambiguity): valid — the Pass-5 NTH-6 dismissal accepted copy-paste risk. Retained (the fenced code block is interpreted correctly by an experienced GDScript reviewer).
- NICE items from all specialists: recorded in this traceability log but not applied individually.

**Pass-6 edit 2026-04-21 wiring changes** (Pass-5 fresh-context independent re-review surfaced 6 NEW BLOCKING + 14 CONCERN + 8 NICE items the same-session Pass-4 verification missed; all 6 BLOCKING + 14 CONCERN + 4 NICE resolved here):
- §C.3 step 4 (line 231): "dict write + mark-dirty" → "dict write only" stale-reference fix (BLOCKING-2; same anti-pattern shape as the prior `mark_dirty()` phantom Pass-4 had just fixed at the code level).
- §C.3 line 234: "2s cadence" → "60s cadence" stale-constant fix (BLOCKING-3; the inline value contradicted the Save/Load Rule 5 citation in the same sentence).
- §D.2 pseudocode: added `f < 1` and `f > N` guards to mirror §C.2 GDScript (BLOCKING-1; Pass-4 fixed §D.4 doc-vs-code drift but missed §D.2 — same drift class returned).
- §H AC-FU-08 Sub-AC 08-non-numeric: added `_unlock_state.has("forest_reach") == true` assertion to break the `get_highest_cleared == 0` tautology (BLOCKING-5; the prior assertion couldn't distinguish "key written with 0" from "key absent, default 0 returned").
- §H AC-FU-13: replaced the "if such a method exists" hedge with verified-API-only isolation strategy + test placement constraint (BLOCKING-4; Save/Load GDD #3 has no `debug_reset_to_fresh()` method, so the hedge was a fixture-not-writable confession).
- §H AC-FU-15: added re-activation continuation step (DataRegistry.stub_biome → state derivation verification) to close the half-tested forward-compat contract (BLOCKING-6; the entire business value of preservation over deletion was previously untested).
- §C.1 R1: promoted `ACTIVE_BIOME_MVP` to `@export var active_biome_mvp` + closed I.11 (NTH-5 user decision: designer-friendly Godot-idiomatic knob).
- §C.2 + §D.2: added `debug_unlock_all` override placement inside `get_floor_state` (CONCERN-9 user decision: UI consistency in QA smoke sessions).
- §B LOSING-fanfare paragraph: added explicit tradeoff acknowledgment + UI #25 design-brief appeal path (CONCERN-18 user decision: acknowledge that "no differentiation" isn't the only cozy alternative).
- §B ACCESSIBLE-visual paragraph: added cross-ref noting Pass-4 deliberation rationale (CONCERN-19; UI #25 designer needs the recorded "why").
- §I.9: added NOW-observable playtest threshold (LOSING-first-clear rate > 30% on F3+) + analytics-engineer instrumentation owner (CONCERN-20; converts passive "we accept" into an active sentinel).
- §H AC-FU-04: added explicit GdUnit4 `assert_no_error_messages()` reference (CONCERN-13).
- §H AC-FU-05: added `_on_floor_cleared_first_time(-1, ...)` signal-handler test case (CONCERN-11).
- §H Sub-AC 05-predicate-boundaries: added `is_unlocked(6)` and `is_unlocked(99)` over-range cases through the `is_unlocked → get_floor_state` delegation chain (CONCERN-14).
- §H AC-FU-06: added HMAC-bypass note (CONCERN-12; consumer-contract test does not exercise Save/Load's binary envelope).
- §H AC-FU-08: added Sub-AC 08-float-lossy-and-overrange for the dual-warning case (`99.7` triggers both step 2 lossy-truncate AND step 5 over-range) (CONCERN-8).
- §H Sub-AC 14-autoload-order: defined template/verifier/trigger to convert ADVISORY into a real smoke-check line item (CONCERN-16).
- §H Classification Summary: added Test Location column to surface the `tests/integration/orchestrator/` vs `tests/integration/floor_unlock/` split for AC-FU-13 vs AC-FU-14 (CONCERN-15).
- §C.1 R1 R1-DI-pattern: added production-path coverage gap note — `_warning_logger` default closure is intentionally not unit-tested, the DI exists for testability (CONCERN-17).
- §F line 437 + propagation-edit list item #2: cleared stale ⚠️ flagging Save/Load consumer table edit as still-open when it had been done 2026-04-20 (CONCERN-7).
- §I.2: corrected stale "BLOCKED without edit #3" framing to RESOLVED (NTH-3).
- §E step 2: corrected `floori` → `floor` spelling for type-clean float comparison + added "Continue processing — over-range clamp in step 5 may still apply" guidance (CONCERN-21 + CONCERN-8).
- §D.2 examples: added f=0/-1/6/99 out-of-range cases to anchor the new guards (CONCERN-10).

Pass-5 specialist findings deliberately not actioned (recorded for traceability):
- NTH-1: `≤60s` wording in §C.3 step 5 — incorporated inline as part of BLOCKING-3 fix.
- NTH-2: I.2 stale framing — incorporated as the I.2 update above.
- NTH-3: Sub-AC 04-also-replay GIVEN doesn't reset `captured` — `before_each` test infrastructure concern, not a GDD specification gap. Defer to story-readiness (test-helpers skill will set up `before_each` per project test convention).
- NTH-4: §C.1 R9 `max() + if` redundancy explanation — defer; the audit-readability rationale is implicit and an experienced GDScript reviewer will recognize the dual-form.
- NTH-6: `enum FloorState` declaration scope — implementation concern, not a GDD spec; the GDScript code block at §C.2 lines 173-198 shows the enum + functions in a single fenced block which a Godot dev will correctly interpret as class-level declarations.
- NTH-7: `dungeons[0]` over-commits to single-dungeon biomes — defer to V1.0 multi-dungeon biome design pass; flagging now creates noise for an MVP that ships single-dungeon-per-biome.
- NTH-8: Save/Load #3 cross-GDD naming inconsistency — carryover from Pass-4 cross-GDD finding; out of scope for Floor Unlock #16 (Save/Load Pass-5 needed independently).

**Pass-4 edit 2026-04-21 wiring changes** (independent re-review surfaced 12 new BLOCKING items; all resolved here):
- §C.1 R1: dropped vestigial `_save_load_system` DI; added `debug_unlock_all` field declaration; locked `load_save_data` namespace contract (receives unwrapped interior dict); added `_active_biome_id()` helper signature.
- §C.1 R1-DI-pattern: corrected the Pass-3 "matches Orchestrator §J.4" overstatement — Floor Unlock's working-closure default + direct dispatch is structurally distinct from Orchestrator's invalid-Callable + is_valid guard.
- §C.1 R3: removed `_save_load_system` autoload resolution; `print_verbose` reframed as dev-only diagnostic (not a production audit trail).
- §C.1 R5: locked LOSING fanfare register — UI #25 fires the **identical** fanfare for WIN and LOSING first-clears (cozy-game absolute; no soft-punishment fork).
- §C.1 R9: removed phantom `_save_load_system.mark_dirty()` call; replaced with explanatory comment about Save/Load heartbeat capture.
- §C.2 `get_floor_state`: added `floor_index < 1` and `floor_index > N` guards. Closes the `is_unlocked(0) == true` sentinel-violation gap and the post-content-downgrade phantom-CLEARED gap.
- §C.2 transition table: `CLEARED → CLEARED` row clarified — signal still fires on replay; UI #25 must use `get_highest_cleared` to distinguish advance from replay.
- §C.2 mental-model note: "isomorphic to ADR-0002" rewritten as "structurally parallel monotonic patterns" — the systems differ in key type and credit semantics.
- §B: corrected the LOSING-grind framing — there is no gold surplus (ADR-0002 monotonic-credit caps at full bonus); the seam is pacing/fantasy. Added MVP-simplification acknowledgment (presence = first-clear, not first-dispatch). Added ACCESSIBLE-visual lock (identical regardless of WIN/LOSING unlock path).
- §D.4: pseudocode synced with §R9 GDScript (write only on advance); removed false byte-identical claim.
- §E: locked `load_save_data` per-value processing order (type guard → lossy-cast warning → cast → under-range clamp → over-range clamp → write). Added type guard for non-numeric values to close the `int("foo") == 0` silent-erasure gap.
- §H AC-FU-04: dropped `SpySaveLoadSystem` fixture (no longer needed after `mark_dirty` removal); simplified to `_unlock_state` invariance assertion. Added Sub-AC 02-continuing-advance closing the post-F1 advance boundary gap.
- §H AC-FU-05: added Sub-AC 05-predicate-boundaries verifying `is_unlocked(0)/-1` returns `false` and `get_floor_state` boundary handling.
- §H AC-FU-08: added Sub-AC 08-float-cast-lossy (locks lossy-cast warning policy) and Sub-AC 08-non-numeric (locks type-guard behavior).
- §H AC-FU-13: added explicit fixture preconditions (`debug_reset()` setup, `DataRegistry.state == READY` assertion, prior-test save-state isolation).
- §H Sub-AC 14-autoload-order: reclassified BLOCKING → ADVISORY (manual smoke-check; promote back when I.10 CI script lands).
- §H AC-FU-15: promoted from "Intentionally Deferred" → BLOCKING AC (DI now makes the test trivial; cost-of-omission is silent unlock-data loss on biome rename).
- §I.4: softened wording — signal-race claim is "unverified pending UI #25's autoload rank," not "no race."
- §I.11: new Open Question for `ACTIVE_BIOME_MVP` `@export` promotion (deferred from Pass-1 review without record).

**Pass-3 edit 2026-04-21 wiring changes** (retained for audit history):
- AC-FU-13: reclassified from §J.3 Mode-1 unit test → Mode-2 integration test.
- AC-FU-14: autoload-order portion of GIVEN split to Sub-AC 14-autoload-order.
- AC-FU-12: case (c) retired (impossible production sequence per Save/Load Rule 10).
- AC-FU-04/08: capturing-Callable DI for `push_warning` testability.

## I. Open Questions

| # | Question | Owner | Target Resolution |
|---|---|---|---|
| I.1 | **V1.0 biome-chain unlock rule** — when a second biome flips from `planned_v1` to `active`, what's the prerequisite predicate? Candidates: (a) `is_biome_completed(previous_biome)`, (b) reach floor N of previous biome, (c) gold cost, (d) time-gated. The schema accommodates any of these; the design is deferred. | game-designer + systems-designer | V1.0 scope-planning pass (post-MVP) |
| I.2 | **Propagation edit bundling** ✅ **RESOLVED 2026-04-20 — CLOSED** (Pass-6 edit 2026-04-21 — corrected stale "BLOCKED without edit #3" framing per Pass-5 NTH-3): all 3 propagation edits (Biome DB §E.1 signature update, Save/Load consumer table row, Orchestrator §C.3 signal payload extension + AC-ORC-13 BLOCKING promotion) were applied 2026-04-20 via Floor-Unlock-Propagation-Edit-1/2/3. AC-FU-13/14 are now WRITEABLE (verified at "Upstream Blocker Note" line 724). This Open Question is left in the table as historical record but is no longer an open question. | producer + systems-designer | RESOLVED 2026-04-20 |
| I.3 | **V1.0 prestige interaction** — when Prestige System (#31, V1.0 stub) ships, does prestige reset `_unlock_state`? Strong default: NO (cozy game, no progression regression); but requires an ADR if prestige ever wants to re-gate content for replay cadence. | game-designer + narrative-director (thematic framing) | V1.0 prestige design pass — blocked on #31 GDD |
| I.4 | **Unlock fanfare timing vs state mutation ordering** (Pass-4 edit 2026-04-21 — softened wording) — Unlock/Victory Moment UI (#25) fires the fanfare. Order: (a) Floor Unlock advances state → (b) Orchestrator emits `floor_cleared_first_time` → (c) #25 reads `get_highest_cleared` to classify new-high vs replay. But #25 also subscribes to the same signal — so (b) and (c) run in the same frame as (a). Whether there is a race where #25 reads stale state depends on Godot's signal-dispatch ordering, which is determined by subscription registration order, which depends on each subscriber's autoload rank. FloorUnlockSystem subscribes at autoload rank 4. UI #25's autoload rank is **not yet established** (system is undesigned). The race is **unverified, not absent**. §C.3 must not claim safety until #25's rank is locked relative to FloorUnlockSystem. | ux-designer (owning #25) + systems-designer | Before `/design-system unlock-victory-moment` (#25) |
| I.5 | **Debug flag `debug_unlock_all` shipping policy** — ship to release QA builds? Useful for live smoke checks but risks enabling in production by misconfiguration. Alternatives: (a) dev-build-only guard per G.2 (current default), (b) QA-build guard (different from release), (c) gate behind a console command with developer mode enabled. | tools-programmer + qa-lead | Before first QA build |
| I.6 | **Hot-reload reconnection** — §E "mid-session Orchestrator re-instantiated" flags that signal connections go stale on autoload re-creation. Dev-only concern in MVP; V1.0 content-patch rollouts (if they use engine hot-reload) may hit this. Is a reconnect affordance worth building? Or does content-patch policy require a full app restart? | systems-designer + devops-engineer | Before first V1.0 content patch |
| I.7 | **Cross-biome replay policy (V1.0)** — if the player has unlocked 3 biomes, can they replay any cleared floor in any unlocked biome at will? MVP answer trivially yes (one biome). V1.0 needs the answer explicit — are there narrative/progression reasons to soft-gate old-biome replays? Strong default: no gate (cozy-idle says return wherever). | game-designer | V1.0 biome-chain design pass |
| I.8 | **Gold-cost unlock alternative** — live-ops-designer may propose paying gold to skip clear-gated progression. Strong recommendation: **do not ship this in V1.0** — it violates the "territorial memory / ground you've walked" fantasy established in §B (you can't pay for presence). Worth documenting the anti-pattern so it doesn't accidentally land in a live-ops event. | live-ops-designer + creative-director | Post-launch live-ops scoping |
| I.9 | **LOSING-grind strategic read** (Pass-4 edit 2026-04-21 — corrected from Pass-3 framing; Pass-6 edit 2026-04-21 — adds NOW-observable playtest threshold per Pass-5 game-designer CONCERN-5) — R5 + ADR-0002 combination creates a rational "LOSING first-clear then WIN replay" strategy. **There is no gold surplus** under ADR-0002's monotonic-credit invariant (Economy AC H-14 Sub-AC 14-losing-first-then-win-reclaim caps total credit per floor at full bonus, regardless of path). Pass-3's "~15k surplus" claim was arithmetically wrong. The actual seam is **pacing and fantasy**: deliberate-LOSING advances the unlock gate without strategic effort, weakening the curation read. MVP impact bounded by 5-floor content budget + Pillar 1 commitment to "presence is what counts." Acknowledged in §B as accepted tradeoff. **NOW-observable escalation trigger** (Pass-6): if MVP playtest analytics shows LOSING-first-clear rate > 30% on F3+ first-clears across the playtest cohort, escalate to game-designer + live-ops-designer pre-V1.0 — that signal indicates the seam is being exploited routinely rather than emerging organically, and Pillar 3 ("matchup is a decision") is at risk. Below 30%, treat as accepted tradeoff. Becomes V1.0 BLOCKING tuning concern if (a) floor count grows substantially, (b) a live-ops event introduces a per-run reward channel that *is* additive (i.e., not under monotonic-credit), or (c) per-run matchup bonus stacks in ways that compound the LOSING-grind payoff above zero. | game-designer + live-ops-designer + economy-designer + analytics-engineer | V1.0 scope-planning pass + live-ops design; analytics-engineer instruments LOSING-first-clear rate pre-MVP-playtest |
| I.10 | **Autoload-order CI check** (Pass-3 edit 2026-04-21) — Sub-AC 14-autoload-order currently specifies manual smoke-check verification that `FloorUnlockSystem` (rank 4) precedes `DungeonRunOrchestrator` (rank 5) in `project.godot` `[autoload]` section. Pass-4 reclassified the Sub-AC as ADVISORY because a manual check that nobody runs is false-confidence. A CI-side parse of `project.godot` is cheap (~5 lines of shell) and catches silent reorders from unrelated PRs. Worth a shared test helper across all autoload-order-sensitive systems (Economy, Save/Load, Floor Unlock, Orchestrator). When this lands, promote Sub-AC 14-autoload-order back to BLOCKING with the script as the verifier. | devops-engineer + qa-lead | Pre-implementation sprint |
| I.11 | **`ACTIVE_BIOME_MVP` designer-accessible tuning knob** ✅ **RESOLVED Pass-9 2026-04-21 — CLOSED via ProjectSettings pattern WITH `set_initial_value` + `add_property_info(PROPERTY_HINT_NONE)`** (Pass-9 third-consecutive-correction of engine-idiom claim: Pass-6 used `@export var` (wrong — autoload @export not Inspector-surfaced); Pass-7 used bare `ProjectSettings.get_setting` (wrong — key invisible in UI without registration); Pass-8 added `set_initial_value` + `add_property_info` with `PROPERTY_HINT_PLACEHOLDER_TEXT` (wrong — renders hint_string as confusing in-field placeholder overlay rather than descriptive documentation). Pass-9 final correction: `PROPERTY_HINT_NONE` is correct for descriptive documentation where hint_string is prose about valid values. Surfaced by 3-specialist cross-model convergence (godot-specialist + godot-gdscript + systems-designer all independently flagged this Pass-9). **Lesson re-recorded for the third consecutive pass**: engine-idiom claims must be verified against Godot documentation per-pass AND empirically probed before implementation commits; inheritance from prior-pass "confirmed" notes has failed three times in a row regardless of which specialists "confirmed" them. The empirical probe recommended in Pass-7 + Pass-8 review logs has still not been run — pre-implementation execution is now strongly recommended. Prior Pass-8 resolution text (historical, superseded):
`ProjectSettings.get_setting("floor_unlock/active_biome_mvp", "forest_reach")` (Pass-8 further-correction of Pass-7 claim; see below). Pass-7's resolution used `ProjectSettings.get_setting("floor_unlock/active_biome_mvp", "forest_reach")` in `_ready()` and claimed "genuinely designer-accessible without code edit." **Pass-8 found that claim also wrong**: `get_setting(key, default)` alone only provides a runtime fallback; the key does NOT appear in the editor Project Settings UI until it is registered via `ProjectSettings.set_initial_value(...)` plus (optionally) `ProjectSettings.add_property_info(...)`. Without those calls the key is invisible to designers. Pass-8's resolution adds both calls in `_ready()` ahead of `get_setting` — first game-launch registers the key; it then appears under a custom category in Project Settings UI for all subsequent editor sessions. V1.0 removes this knob entirely when biome-context injection lands. **Lesson recorded, reinforced across two passes**: engine-idiom claims (`@export` on autoload, `get_setting` UI auto-surfacing) must be verified against Godot documentation per-pass, not inherited from prior-pass "confirmed" notes. Pass-6 inherited from Pass-5; Pass-7 inherited from same-session reasoning; Pass-8 inherited from same-session reasoning — all three were wrong. Pass-9 resolution verified against 3-specialist cross-model convergence flagging PROPERTY_HINT_PLACEHOLDER_TEXT as incorrect. **The pattern now three-consecutive wrong claims confirms that "cross-model convergence" inside a single review cycle is NOT sufficient evidence** — empirical Godot probe is the only reliable verification. Run the probe before implementation. | systems-designer + tools-programmer | RESOLVED Pass-9 2026-04-21 |
| I.12 | **Offline Engine dependency on crash-in-window recovery** (Pass-7 edit 2026-04-21 — NEW; closes BLOCKING-8) — §C.1 R9 and §C.3 step 5 describe a crash-in-window recovery chain: if the app dies between a floor clear and the next Save/Load heartbeat (worst case 60s window), the Orchestrator snapshot replay on next launch refires `floor_cleared_first_time`, and R9's idempotent advance converges. This recovery is CONDITIONAL on the Offline Progression Engine (#12, undesigned) correctly invoking `compute_offline_run` for the elapsed tick budget that covers the floor-clear tick. If Offline Engine design places the clear outside the replay window, or if Offline Engine hasn't landed, the unlock is permanently lost. Pass-6 stated "no data loss" as settled fact; Pass-7 weakened to "recovered IF Offline Engine replays correctly." This is load-bearing for Pillar 1 ("ground you've walked stays walked") — if Offline Engine doesn't replay the clear, the player loses presence on a crash. When #12 ships, re-review this GDD's recovery claim against #12's replay semantics and confirm the refire reaches `_on_floor_cleared_first_time`. If not, escalate to a save-on-advance dirty-tracking design (cross-GDD with Save/Load #3). | systems-designer + ai-programmer (#12 owner) | When Offline Engine #12 is designed |
| I.14 | **Save/Load #3 public save-path knob (or `debug_reset_to_fresh()` API) for AC-FU-13 + AC-FU-14 isolation** (Pass-8 edit 2026-04-21 — NEW; closes BLOCKING-3 by refile). Pass-7 specified `SaveLoadSystem.save_file_path` redirect as the isolation mechanism for Mode-2 integration ACs; Pass-8 verified that knob does not exist in Save/Load GDD #3 (canonical slot path is constructed via `save_slot_path(slot: int) -> String` helper, not a settable field). Same failure class as Pass-6's `DataRegistry.stub_biome()` + `SaveLoadSystem.debug_reset_to_fresh()` phantom API references. Fallback in AC-FU-13/14 is filesystem-level cleanup (delete `user://save_slot_1.dat` + `.bak` before workspace boot), which works but is fragile to platform differences + parallel test runs. The durable fix lives in Save/Load #3: either (a) expose `save_file_path` (or a similarly-named knob) as a public String field that redirects slot-path construction, or (b) add `debug_reset_to_fresh()` as a public API. Either is a small Save/Load API addition; neither is Floor Unlock's to make. File against Save/Load #3's Pass-5 follow-up. | qa-lead (identification) + systems-designer (cross-GDD file) → Save/Load #3 owner | Save/Load #3 Pass-5 |
| I.15 | **Orchestrator #13 offline-path does not emit `floor_cleared_first_time`** (Pass-8 edit 2026-04-21 — NEW; closes BLOCKING-9 by refile). Orchestrator GDD §C.4 `compute_offline_run` (lines 258–296) correctly calls `Economy.try_award_floor_clear(...)` and sets `snapshot.floor_clear_emitted = true`, but does NOT emit `floor_cleared_first_time`. This means FloorUnlock's `_on_floor_cleared_first_time` handler is NOT invoked on offline first-clears — `_unlock_state` never advances, UI #25's fanfare never fires, and Pillar 1 ("ground you've walked stays walked") is silently violated for the dominant MVP play pattern (idle game = mostly offline play). The fix lives in Orchestrator #13 §C.4: add `floor_cleared_first_time.emit(snapshot.floor.floor_index, snapshot.biome_id, snapshot.losing_run)` at the same ordering point in the offline path as in foreground (§C.3 line 249), AFTER `Economy.try_award_floor_clear(...)` + setting `floor_clear_emitted = true`. **BLOCKING before Floor Unlock #16 can ship**: Orchestrator #13 Pass-5E APPROVED verdict did not flag this (the foreground path is correct; the offline path was added in Pass-5 without the emit). Cross-GDD finding; file against Orchestrator #13's next revision cycle. Note: Economy GDD §C.5 line 481 contains a contradicting example block that claims Orchestrator emits the signal in offline path AND Economy handles it — this is triple-contradictory (Orchestrator §C.4 does NOT emit; Economy §C.5 line 187 says Economy does NOT subscribe; Economy §C.5 line 481 says both do). File the Economy line-481 block for Economy Pass-5 follow-up as separate cross-GDD drift. | systems-designer (identification) → Orchestrator #13 owner + Economy #5 owner | Orchestrator #13 next revision; Economy #5 next revision |
| I.13 | **`dungeons[0]` hard-code in `BIOME_FLOOR_COUNT` derivation** (Pass-7 edit 2026-04-21 — NEW; closes game-C-7 + systems-N-1 deferral that had no tracking entry) — §C.1 R1 `_ready()` initialization, §D.1 variable table, §G.1 knob table, and §F upstream row all derive floor count via `DataRegistry.resolve("biomes", biome_id).dungeons[0].floors.size()`. V1.0 multi-dungeon biomes (e.g., a day/night variant of Forest Reach) will silently produce wrong floor counts for the second+ dungeon branch. MVP ships single-dungeon-per-biome, so this is deferrable. But leaving it as an unregistered NTH creates a V1.0 landmine nobody has tooling to find. When V1.0 multi-dungeon content is introduced, `BIOME_FLOOR_COUNT` must become either a per-dungeon-index lookup or a sum/max across all dungeons in the biome — the choice depends on the V1.0 biome-chain design. | systems-designer + game-designer | Before V1.0 multi-dungeon biome content lands |

**Note**: I.2 is closed (RESOLVED 2026-04-20). **I.11 REOPENED 2026-04-21 by Pass-PROBE-EXECUTED empirical finding** — the Pass-9 closure via ProjectSettings pattern with `set_initial_value` + `add_property_info(PROPERTY_HINT_NONE)` was EMPIRICALLY FALSIFIED by the `tests/probes/godot_autoload_probe.gd` run on Godot 4.6.1.stable.mono.official 2026-04-21. Two material findings: (a) `save()` persists only values that differ from the initial value, so `set_setting(k, X) + set_initial_value(k, X)` with equal values produces no disk delta and the key never appears in the editor Project Settings UI; (b) `add_property_info(...)` registers hint metadata in the CALLING PROCESS's ProjectSettings singleton — the editor process never sees the game-process registration, so hint_string and hint-constant rendering cannot be tested without a `@tool` script or EditorPlugin registering at editor load time. The Pass-9 closure is therefore the **FOURTH consecutive wrong engine-idiom claim** (Pass-6 `@export`, Pass-7 bare `get_setting`, Pass-8 `set_initial_value`-suffices, Pass-9 `PROPERTY_HINT_NONE`-correct — all four falsified by empirical probe). The §C.1 R3 code block works as a RUNTIME fallback (`get_setting(key, default)` returns the hardcoded default "forest_reach" when the key isn't persisted) — MVP play is unaffected. The DESIGNER-UI story (editor-surfaced knob with proper tooltip hint) is **BROKEN** until a `@tool`/EditorPlugin pattern is authored + empirically verified. See `docs/engine-reference/godot/modules/autoload.md` Claim 2 + Claim 3 + Change log Pass-PROBE-EXECUTED entry for the full empirical record + three candidate correct patterns. Deferred to V1.0 multi-biome authoring cycle; not MVP-blocking because the runtime fallback is sufficient for a single-biome MVP. Lesson extension: empirical probe execution is now the ONLY acceptable evidence for engine-idiom claims; no further cross-model specialist convergence should be treated as sufficient for claims about ProjectSettings, autoload, or other engine-state APIs until a probe result is captured in `autoload.md`. I.9 is a V1.0 concern with a NOW-observable >30% LOSING-first-clear-rate threshold on F3+. I.12 is Offline-Engine-blocked; re-review Floor Unlock #16 recovery claim when #12 lands. I.13 is V1.0 multi-dungeon-content-blocked. I.14 + I.15 are both RESOLVED 2026-04-21 (I.14 via Save/Load Pass-5A + Pass-5B-emergency; I.15 via Orchestrator Pass-I.15-fix). The other questions are V1.0 / pre-implementation / post-launch.
