# Godot 4.6 — Autoload & ProjectSettings Behavior (Authoritative Reference)

> **Status**: **Probe EXECUTED 2026-04-21 on Godot 4.6.1.stable.mono.official (Apple M2 Max, Metal).** Claim 1 promoted `[CONVERGED] → [VERIFIED]`. Claim 2 **FALSIFIED as documented** (Pass-8 pattern produces no disk persistence when current == initial) — empirical correction captured below; full designer-UI verification deferred pending a `@tool`/EditorPlugin probe. Claim 3 **INCONCLUSIVE** (editor process never called `add_property_info`; both HINT_NONE and HINT_PLACEHOLDER_TEXT variants rendered as plain String fields in the editor UI) — needs a separate `@tool`-script probe.
> **Created**: 2026-04-21 (Floor Unlock #16 Pass-9 recommendation — close the three-consecutive-wrong-engine-idiom-claim pattern by replacing inherited-from-prior-pass evidence with empirical verification).
> **Authors**: main session synthesizing godot-specialist + godot-gdscript-specialist + systems-designer Pass-9 findings; Pass-PROBE-EXECUTED 2026-04-21 main session + user empirical probe execution.
> **Update cadence**: after every empirical probe run; never from inheritance.

---

## Why this doc exists

Floor Unlock GDD #16 review Passes 6, 7, and 8 each produced a confidently-stated engine-idiom claim that Pass-(N+1) had to retract:

| Pass | Wrong claim | Source of "confirmation" | Corrected in |
|---|---|---|---|
| 6 | `@export var` on autoload Node surfaces in Inspector via normal editor workflow | Pass-5 godot-gdscript NTH-2 "confirmed" | Pass-7 |
| 7 | `ProjectSettings.get_setting(key, default)` alone surfaces the custom key in the editor Project Settings UI | Pass-6 + same-session reasoning | Pass-8 |
| 8 | `PROPERTY_HINT_PLACEHOLDER_TEXT` is the correct hint for descriptive documentation on a `TYPE_STRING` ProjectSettings key | Pass-8 cross-model godot-gdscript + godot-specialist convergence | Pass-9 |

Three consecutive passes. Each correction came from independent re-review, not from the pass that introduced the error. **Cross-model specialist convergence inside a single review cycle is NOT sufficient evidence** — Pass-8's claim had cross-model agreement and was still wrong. Only empirical verification is authoritative.

This doc is the authoritative source for autoload + ProjectSettings behavior going forward. Every claim below has a status tag indicating its evidence level:

- **[VERIFIED]** — confirmed by running `tests/probes/godot_autoload_probe.gd` in a scratch Godot 4.6 project. Include the stdout excerpt + probe run date.
- **[CONVERGED]** — multiple specialists agreed in a review cycle, but NOT yet empirically verified. Treat as provisional.
- **[SPECULATION]** — single specialist or inference. Do not rely on in design decisions.

---

## Claim 1 — Autoload rank-order `_ready()` signal availability

**Claim**: A rank-N autoload can connect to a rank-(N+1) autoload's signal in its own `_ready()`. All autoload nodes are added to the scene tree root before any `_ready()` fires. Signal objects exist the moment the owning Node exists; they do not depend on the owner's `_ready()` having run.

**Evidence level**: **[VERIFIED]** — empirical probe executed 2026-04-21 on Godot 4.6.1.stable.mono.official (Apple M2 Max, Metal backend). Probe script at `tests/probes/godot_autoload_probe.gd`; live probe scripts at `../../../../godot/probe_source.gd` + `../../../../godot/probe_sink.gd` (sibling scratch project, outside the main repo).

**Why this matters**: FloorUnlockSystem (rank 4 autoload) connects to `DungeonRunOrchestrator.floor_cleared_first_time` (rank 5) in its `_ready()` (see `design/gdd/floor-unlock-system.md` §C.1 R3). If this claim is wrong, the subscription silently fails to establish, the handler never fires, and Pillar 1 ("ground you've walked stays walked") is broken on every floor clear.

**Probe procedure** (summarized; full script in `tests/probes/godot_autoload_probe.gd`):
1. Register `ProbeSource` (rank 1) + `ProbeSink` (rank 2) as autoloads in a scratch Godot 4.6 project.
2. `ProbeSink._ready()` connects to `ProbeSource.probe_signal_fired`.
3. `ProbeSource._ready()` emits the signal (deferred, so the connection is established first).
4. Verify `ProbeSink` receives the signal.

**Expected stdout** (if claim holds):
```
[PROBE] ProbeSource._ready() fired at tree_time=<T1>
[PROBE] ProbeSink._ready() fired at tree_time=<T2>
[PROBE] ProbeSink sees /root/ProbeSource node: True
[PROBE] ProbeSink received probe_signal_fired(42) — CLAIM 1 CONFIRMED
```

**Empirical results (captured 2026-04-21 on Godot 4.6.1.stable.mono.official, Apple M2 Max, Metal backend, headless CLI run via `Godot --path <project>`)**:

```
[PROBE] ProbeSource._ready() fired at tree_time=648
[PROBE] ProbeSink._ready() fired at tree_time=648
[PROBE] ProbeSink sees /root/ProbeSource node: true
[PROBE] Bare identifier ProbeSource == node: true
[PROBE] ProbeSink connected to probe_signal_fired
[PROBE] ProbeSource emitting probe_signal_fired(42)
[PROBE] ProbeSink received probe_signal_fired(42) — CLAIM 1 CONFIRMED
```

All four sub-claims hold in the verified run: (a) both autoloads' `_ready()` fired at the same `tree_time` (648 ms), confirming both nodes were in the tree before either `_ready()` ran; (b) `get_node_or_null("/root/ProbeSource")` returned non-null from inside ProbeSink's `_ready()`; (c) bare-identifier resolution `ProbeSource == <node>` returned `true`; (d) deferred signal emission reached the connected listener. Godot 4.6's autoload initialization is rank-ordered at `_ready()` invocation level, but node instantiation (and therefore signal-object addressability) is complete before any `_ready()` fires.

**Save/Load implementation-story gate (added Pass-5D 2026-04-21 by `design/gdd/save-load-system.md` §C.3):** Claim 1 `[CONVERGED] → [VERIFIED]` promotion **LANDED 2026-04-21** via this probe. **Save/Load implementation stories are now un-gated and ready to be marked execution-ready.** Save/Load is autoload rank 2 and connects to rank-3+ consumers' signal objects at its own `_ready()` time; Claim 1 being VERIFIED means this pattern is safe. Probe actual execution cost: ~5 minutes total (including editor setup, two probe iterations for Claim 2 hypothesis refinement, and editor UI inspection for Claim 3).

---

## Claim 2 — ProjectSettings custom-key registration

**Original Pass-8/9 claim** (NOW EMPIRICALLY FALSIFIED as written — see below): For a custom `TYPE_STRING` ProjectSettings key to appear in the editor's Project Settings UI, three calls in the autoload's `_ready()` are sufficient:

```gdscript
# ORIGINAL PATTERN — PASS-8 / PASS-9 — FALSIFIED 2026-04-21
var key := "floor_unlock/active_biome_mvp"
if not ProjectSettings.has_setting(key):
    ProjectSettings.set_setting(key, "forest_reach")     # current = "forest_reach"
ProjectSettings.set_initial_value(key, "forest_reach")    # initial = "forest_reach"  ← SAME AS CURRENT
ProjectSettings.add_property_info({
    "name": key,
    "type": TYPE_STRING,
    "hint": PROPERTY_HINT_NONE,
    "hint_string": "biome_id with status=\"active\" in Biome DB",
})
var value: String = ProjectSettings.get_setting(key, "forest_reach")
```

**Evidence level**: **[FALSIFIED-AS-WRITTEN]** — probe executed 2026-04-21 on Godot 4.6.1.stable.mono.official. The pattern **does NOT persist the key to `project.godot`** and therefore the key **does NOT appear in the editor's Project Settings UI**.

### Empirical finding: `ProjectSettings.save()` persists ONLY values that differ from their initial value

The probe registered four keys in parallel:

| Key | `set_setting(...)` value | `set_initial_value(...)` | `save()` result | Persisted to `project.godot`? |
|---|---|---|---|---|
| `probe_registration/a_hint_none_equal` | `"default_a"` | `"default_a"` (same) | OK=0 | **NO** |
| `probe_registration/b_hint_placeholder_equal` | `""` | `""` (same) | OK=0 | **NO** |
| `probe_registration/c_hint_none_diff` | `"override_c"` | `"default_c"` (different) | OK=0 | **YES** |
| `probe_registration/d_hint_placeholder_diff` | `"override_d"` | `""` (different) | OK=0 | **YES** |

Post-probe `project.godot` on disk contained only:

```
[probe_registration]

c_hint_none_diff="override_c"
d_hint_placeholder_diff="override_d"
```

`save()` returned OK=0 for all four registrations, but only the two where `current != initial` produced a disk delta. This is consistent with Godot's general "persist only non-default values" pattern (the same logic that keeps `project.godot` small by omitting engine defaults).

### Editor UI appearance (separate verification, 2026-04-21)

After the probe ran and the keys persisted, reopening the editor and navigating to **Project → Project Settings → General** tab:

- A category **"Probe Registration"** appeared in the left sidebar (derived from the `probe_registration/` key prefix — confirming the category-from-prefix convention).
- Two rows visible under that category: `C Hint None Diff` with value `override_c`, and `D Hint Placeholder Diff` with value `override_d`. Both rendered as plain String LineEdit fields.
- Keys A and B were **absent from the UI** (because they never persisted to `project.godot` — the editor has no way to know they exist).
- **Advanced Settings toggle was OFF** in the observation screenshot, yet the custom keys were still visible. The toggle appears to gate built-in engine settings, not registered custom keys.

### Correct pattern — OPEN QUESTION pending a `@tool` probe

The game-runtime-only `add_property_info(...)` call does NOT reach the editor process. For the editor UI to render proper type hints + descriptive text, the registration must happen in the **editor's own ProjectSettings singleton**, not the game's. Three candidate patterns exist but are NOT YET empirically verified:

1. **`@tool` script on the autoload** — prepend `@tool` to `probe_sink.gd`. Godot will run `_enter_tree()` / `_ready()` in the editor process too, so `add_property_info` registers into the editor's singleton. Caveat: `@tool` on an autoload may have side-effects (editor-time mutation of project state, hot-reload issues, save-on-quit loop), so the pattern needs careful scoping.

2. **`EditorPlugin`** (separate from the game autoloads) — a proper Godot plugin at `res://addons/<name>/plugin.gd` with `_enter_tree()` calling the registration block. Runs only in editor context, doesn't pollute the game's autoload rank order, and is the pattern Godot documentation recommends for editor-side configuration. Downsides: more setup; plugin must be enabled in Project Settings → Plugins tab.

3. **Hybrid**: game autoload persists the key (via `current != initial`) so it appears in `project.godot`; a lightweight `@tool` script or EditorPlugin separately calls `add_property_info` at editor load time to attach the hint metadata.

For designer-facing tuning knobs like Floor Unlock's `active_biome_mvp`, the most likely correct pattern is **#3 (hybrid)** because:
- The game needs the key at runtime with a known default.
- The editor needs the hint metadata for proper UI rendering.
- Neither process can do both jobs alone in Godot 4.6.

**Recommended next step**: author a second probe (`probe_editor_plugin.gd` with `@tool` + `_enter_tree()` registering hint metadata) and re-run the empirical test. Defer until a Floor Unlock implementation story needs the knob surfaced (currently unblocked for story-authoring because the knob has a usable runtime fallback via `get_setting(key, "forest_reach")`).

### Implications for Floor Unlock #16 §G.1 + §I.11

Floor Unlock documents this pattern as the designer workflow for `active_biome_mvp`. The empirical result means:

- The **runtime fallback** (`ProjectSettings.get_setting(key, "forest_reach")` returning the hardcoded default when the key isn't persisted) works and is sufficient for MVP playability.
- The **designer-UI story** (designer changes biome without a code edit) requires either pattern #1/#2/#3 above, which is NOT yet empirically verified.
- §I.11's "three consecutive wrong engine-idiom claims" lesson extends: Pass-8 is now a **fourth** wrong claim empirically falsified. The correction (set_initial_value differing from set_setting) is mechanical but the hint-metadata-in-editor story still needs `@tool`/EditorPlugin verification. The pattern of "cross-model specialist convergence is insufficient" continues to hold.

---

## Claim 3 — `PROPERTY_HINT_NONE` vs `PROPERTY_HINT_PLACEHOLDER_TEXT` rendering

**Claim**: For a `TYPE_STRING` ProjectSettings key where `hint_string` is prose documentation (e.g., "biome_id with status=\"active\" in Biome DB"), `PROPERTY_HINT_NONE` is correct. `hint_string` renders as a tooltip or description adjacent to the input field.

`PROPERTY_HINT_PLACEHOLDER_TEXT` renders `hint_string` INSIDE the input field as greyed-out placeholder text (visible only when the field is empty). This is correct for LineEdit-style export properties where the author wants a "type something here" affordance — it is NOT correct for descriptive documentation. Pass-8 used `PROPERTY_HINT_PLACEHOLDER_TEXT` for a documentation hint; Pass-9 cross-model CONCERN (3 specialists independently) corrected this to `PROPERTY_HINT_NONE`.

**Evidence level**: **[INCONCLUSIVE]** — probe executed 2026-04-21 but the test did not discriminate between the two hint constants because the editor process never received the `add_property_info(...)` registration (see Claim 2 above). A proper test requires a `@tool` script or EditorPlugin that registers the hint metadata at editor load time.

**Why this matters**: If the claim is wrong (e.g., `PROPERTY_HINT_NONE` hides the hint_string entirely rather than showing it as tooltip), the designer workflow story is incomplete and a different hint constant may be needed. Pass-9 evidence is cross-model, but Pass-8 also had cross-model evidence.

**Empirical observation (2026-04-21)**:

Both variants (`c_hint_none_diff` with `PROPERTY_HINT_NONE` + `d_hint_placeholder_diff` with `PROPERTY_HINT_PLACEHOLDER_TEXT`) rendered in the editor UI as **identical plain String LineEdit fields** with their persisted values filled in (`override_c` + `override_d`). No hint_string text was visible in either row — not as tooltip, not as description, not as in-field placeholder. The `d_hint_placeholder_diff` field had a value (`override_d`), so even if HINT_PLACEHOLDER_TEXT worked correctly, its placeholder would not render when the field is non-empty — so the test was ambiguous on that axis.

**Why the test was inconclusive**:

`ProjectSettings.add_property_info(...)` attaches type + hint metadata to the **running process's** ProjectSettings singleton. When the probe ran via `Godot --path <project>` (game process), the registration landed in the game's singleton and vanished when the game quit. The editor process (a separate Godot invocation) loaded `project.godot` from disk, saw the keys' VALUES in the `[probe_registration]` section, but had no type/hint metadata — so it fell back to rendering them as untyped strings. The editor process never saw `add_property_info(...)`.

**What a proper Claim 3 probe looks like (not yet executed)**:

Mark the registration script as `@tool` so it runs in the editor context as well as the game context:

```gdscript
@tool
extends Node

func _enter_tree() -> void:
    # Registration runs in BOTH game and editor processes because @tool.
    # The editor process receives add_property_info at project load, so the
    # editor UI renders hints correctly.
    _register_settings()

func _register_settings() -> void:
    # ... same body as probe_sink.gd's registration block ...
```

`@tool` on an autoload has caveats (editor-time mutation of project state, hot-reload issues, `save()` calls potentially corrupting `project.godot` during editor shutdown) so the pattern needs careful scoping — typically an `EditorPlugin` is cleaner. Neither pattern is empirically verified in this project yet; document here when a `@tool`-probe run captures the result.

**Empirical results (INCONCLUSIVE, 2026-04-21)**:

```
Variant A (PROPERTY_HINT_NONE): rendered as plain String LineEdit, no visible hint_string anywhere
Variant B (PROPERTY_HINT_PLACEHOLDER_TEXT): rendered as plain String LineEdit, no visible hint_string anywhere
Winner for descriptive documentation: UNDETERMINED (editor process never received add_property_info)
Next probe required: @tool-script OR EditorPlugin registration path
```

---

## Claim 4 — Autoload `_init()` argument passing

**Status**: `[VERIFIED]` (empirical probe 2026-04-22, Godot 4.6.1.stable.mono.official, Apple M2 Max).

### Claim

Godot's autoload system instantiates registered scripts via `_create_instance()` (see `modules/gdscript/gdscript.cpp:200`) which calls the script's `_init()` with **zero arguments**. There is no mechanism in `project.godot` `[autoload]` or the Project Settings → Autoload UI to supply constructor arguments. An autoload script whose `_init` declares **required** parameters (no default values) cannot be instantiated — Godot emits a runtime error `"Method expected N argument(s), but called with 0"` at boot and the autoload Node is never added to `/root`.

**Corollary**: dependency injection into autoload singletons must happen AFTER `_init()` — typically in `_ready()` (self-wiring) or via a named method called from `_ready()` (named DI seam). Arguments MAY appear on `_init` if ALL parameters have default values (Godot fills in the defaults since it's calling with zero args).

### Permitted patterns on autoload Nodes

**Pattern A — lazy-default with public setters** (recommended; project-wide canonical per ADR-0009 + `dungeon-run-orchestrator.md` §J.1 Option A):
```gdscript
extends Node
var _matchup_resolver: MatchupResolver = null
var _combat_resolver: CombatResolver = null

func _init() -> void:
    pass  # zero-arg; DI does not happen here

func _ready() -> void:
    if _combat_resolver == null:
        _combat_resolver = DefaultCombatResolver.new()   # production default; fails closed
    if _matchup_resolver == null:
        _matchup_resolver = DefaultMatchupResolver.new()

func set_matchup_resolver(resolver: MatchupResolver) -> void:   # test-facing
    assert(resolver != null)
    _matchup_resolver = resolver

func set_combat_resolver(resolver: CombatResolver) -> void:     # test-facing
    assert(resolver != null)
    _combat_resolver = resolver
```

Tests call `autoload.set_foo(spy)` BEFORE `add_child(autoload)` (or before direct `autoload._ready()` call). The null-check in `_ready()` short-circuits when a spy is already installed; production boot installs defaults when no spy was pre-injected. **Fails closed** — a ship build with no test harness still boots playable with defaults. This is the canonical project pattern for autoload-level DI.

**Pattern B — named `wire_dependencies()` seam called from `_ready()`** (valid alternative for simple autoloads without a "must-succeed-without-DI" fails-closed requirement):
```gdscript
extends Node
var _matchup_resolver: MatchupResolver
var _combat_resolver: CombatResolver
func _ready() -> void:
    wire_dependencies(DefaultCombatResolver.new(), DefaultMatchupResolver.new())
func wire_dependencies(c: CombatResolver, m: MatchupResolver) -> void:
    _combat_resolver = c
    _matchup_resolver = m
```
Tests construct the autoload standalone (not added to scene tree, so `_ready` does not fire) and call `wire_dependencies(spy_c, spy_m)` explicitly. **Fails open** — a ship build where `_ready()` is bypassed (e.g., via a refactor that moves wiring elsewhere) can crash at first use with "resolver is null". Use this pattern only when a strict single-injection-point is the design priority AND the "fails open" risk is acceptable. The Orchestrator considered and rejected this via §J.7 Option E rejection ("fails open vs fails closed").

**Pattern C — `_init` with all-defaulted args** (permitted but discouraged because DI through `_init` is effectively impossible for autoloads):
```gdscript
extends Node
func _init(a: int = 0, b: String = "") -> void:  # Godot calls _init() with zero args; defaults fill in
    pass
```

### Forbidden pattern on autoload Nodes

```gdscript
extends Node
func _init(a: int, b: int) -> void:  # REQUIRED args — boot error
    pass
```

Boot output (from the 2026-04-22 probe):
```
ERROR: Error constructing a GDScriptInstance: 'Node(probe_source.gd)::_init':
Method expected 2 argument(s), but called with 0
   at: _create_instance (modules/gdscript/gdscript.cpp:200)
```

The autoload Node fails to instantiate. Its `_init` body never runs; its `_ready` body never runs; it is never added to `/root`. Other autoloads (ranked before or after) continue to instantiate independently — one autoload's failure does not block siblings.

### Non-autoload construction (`.new(args)` works normally)

RefCounted or Node classes that are NOT registered as autoloads retain full `.new(args)` support. `DefaultMatchupResolver extends RefCounted` with `func _init(config: ResolverConfig) -> void` instantiated via `DefaultMatchupResolver.new(config)` works as documented. The zero-arg constraint applies ONLY to the autoload system's instantiation path, not to user-code `.new()` calls.

### Empirical evidence (2026-04-22 Pass-INIT-PROBE)

**Pass 1 (falsification)** — autoload `probe_source.gd` with `func _init(a: int, b: int) -> void` and required args:

```
Godot Engine v4.6.1.stable.mono.official.14d19694e - https://godotengine.org

ERROR: Error constructing a GDScriptInstance: 'Node(probe_source.gd)::_init':
Method expected 2 argument(s), but called with 0
   at: _create_instance (modules/gdscript/gdscript.cpp:200)
[SINK] _ready() fired — quit driver active
[SINK] 1s elapsed — quitting with code 0
```

`_init` body never printed; `_ready` body never printed; sibling ProbeSink autoload fired normally. Error source identifies `_create_instance` in `modules/gdscript/gdscript.cpp:200` as the exact call site.

**Pass 2 (confirmation — Option B pattern)** — autoload with zero-arg `_init()` + `_ready()` calls `wire_dependencies(...)` + inner-class `RefCounted.new(args)`:

```
Godot Engine v4.6.1.stable.mono.official.14d19694e - https://godotengine.org

[WIRE-PASS-2] _init() fired — autoload instantiated with zero args as expected
[WIRE-PASS-2] _ready() fired; _init_fired=true
[WIRE-PASS-2] FalsifyResolver._init(100, 'hello') executed via .new(args)
[WIRE-PASS-2] FalsifyResolver.new(100, 'hello') succeeded; resolver.a=100 resolver.b='hello'
[WIRE-PASS-2] wire_dependencies(100, 'hello') stored values
[WIRE-PASS-2] post-wire: _wired_a=100 _wired_b='hello'
[WIRE-PASS-2] OPTION B PATTERN CONFIRMED — all assertions pass
[SINK] _ready() fired — quit driver active
[SINK] 1s elapsed — quitting with code 0
```

All assertions passed: autoload's zero-arg `_init()` fires; `_ready()` invokes `wire_dependencies(100, "hello")`; `_wired_a` + `_wired_b` populated correctly; inner-class `FalsifyResolver extends RefCounted` with `_init(initial_a: int, initial_b: String)` instantiates cleanly via `.new(100, "hello")`. The MatchupResolver non-autoload construction path is verified.

### Impact on project architecture

- **ADR-0003 Amendment #2** (Accepted 2026-04-22) language "*injected via `DungeonRunOrchestrator._init(combat_resolver, matchup_resolver)`*" is **mechanically impossible** for an autoload Orchestrator. Amendment #3 (2026-04-22, same day) corrects the language to Pattern A's lazy-default-with-setters (two public setters + null-check in `_ready()`) per the already-locked `dungeon-run-orchestrator.md` §J.1 Option A decision.
- **ADR-0009** (Matchup Resolver DI) adopts Pattern A as the canonical project-wide pattern for all autoload-level DI, codifying `dungeon-run-orchestrator.md` §J.1 Option A at ADR level. An initial draft proposed Pattern B via godot-specialist Step 4.5 recommendation; the draft was rolled back before lockstep-propagation completed once the §J.1 locked-decision conflict was caught (§J.7 Option E rejection rationale: "fails open vs fails closed").
- **architecture.md §Non-Autoload Pure-Function Modules + §Module Ownership Map**: corrected in lockstep with ADR-0003 Amendment #3.

---

## Related design references

- `design/gdd/floor-unlock-system.md` §C.1 R3 — the canonical implementation of Claims 1+2+3 in project code.
- `design/gdd/floor-unlock-system.md` §I.11 — history of the three-consecutive-wrong-engine-idiom pattern + the lesson recorded.
- `design/gdd/reviews/floor-unlock-system-review-log.md` — per-pass evidence trail.

## Related engine-reference docs

- `docs/engine-reference/godot/VERSION.md` — pinned Godot 4.6 + training-cutoff notice.
- `docs/engine-reference/godot/modules/input.md`, `physics.md`, etc. — sibling module references for other subsystems.

---

## Change log

- 2026-04-21 — Initial authoring (Pass-9 Floor Unlock review). Three claims, all [CONVERGED], no [VERIFIED]. Probe script at `tests/probes/godot_autoload_probe.gd` ready to run in a scratch Godot 4.6 project.
- 2026-04-21 (Pass-5D Save/Load) — Added Save/Load implementation-story BLOCKING prerequisite note to Claim 1. Save/Load GDD §C.3 rank-2 assignment load-bears on Claim 1 holding; probe-execution + CONVERGED→VERIFIED promotion is a story-authoring gate. No change to the claim itself; evidence level remains [CONVERGED].
- 2026-04-21 (Pass-PROBE-EXECUTED, **same day**) — Probe executed on Godot 4.6.1.stable.mono.official (Apple M2 Max, Metal backend). Live probe scripts at sibling scratch project `/Users/xiaolei/work/godot-project/godot/` (`probe_source.gd`, `probe_sink.gd`, `main.tscn`, `project.godot`). Outcomes:
  - **Claim 1 promoted `[CONVERGED] → [VERIFIED]`**: full stdout trace in Claim 1 Empirical-results block. Both autoloads' `_ready()` fired at the same `tree_time=648` ms; ProbeSink connected to ProbeSource.probe_signal_fired in its own `_ready()`; deferred signal emission reached the listener. **Save/Load implementation stories un-gated** — the BLOCKING prerequisite on story-authoring added Pass-5D is now satisfied.
  - **Claim 2 marked `[FALSIFIED-AS-WRITTEN]`**: Pass-8 pattern `set_setting(k, X) + set_initial_value(k, X)` with matching values does NOT persist to `project.godot` (empirical finding — Godot's `save()` writes only non-default values). Corrected pattern requires `current != initial` for disk persistence AND `@tool`/EditorPlugin for editor-UI hint metadata. Three candidate patterns documented (pure `@tool`, EditorPlugin, hybrid); empirical verification deferred pending the first Floor Unlock story that needs the knob surfaced (runtime fallback via `get_setting(key, default)` works and is sufficient for MVP playability).
  - **Claim 3 marked `[INCONCLUSIVE]`**: both PROPERTY_HINT_NONE and PROPERTY_HINT_PLACEHOLDER_TEXT variants rendered identically as plain String LineEdit fields because the editor process never received `add_property_info(...)` — the metadata lived only in the game process's singleton and vanished at game exit. Proper test requires `@tool`/EditorPlugin probe.
  - Pattern lesson (extension of §I.11): Pass-8 is the **fourth consecutive wrong engine-idiom claim** falsified after the empirical probe. Cross-model specialist convergence continues to be insufficient evidence; only empirical verification is authoritative.
- 2026-04-22 (Pass-INIT-PROBE, ADR-0009 Step 4.5 discovery) — godot-specialist Step 4.5 review of the drafted ADR-0009 (Matchup Resolver DI) BLOCKED on a load-bearing engine-state claim: "Godot's autoload system calls `_init()` with zero arguments; an autoload with required `_init(args)` cannot be instantiated". Probe executed the same day on Godot 4.6.1.stable.mono.official (Apple M2 Max). Live probe scripts overwrote the sibling scratch project `probe_source.gd` + `probe_sink.gd` in two passes:
  - **Pass 1 (falsification)**: autoload `_init(a: int, b: int)` → Godot emitted `ERROR: 'Node(probe_source.gd)::_init': Method expected 2 argument(s), but called with 0` at `_create_instance (modules/gdscript/gdscript.cpp:200)`. `_init` + `_ready` bodies never ran; sibling ProbeSink autoload fired normally.
  - **Pass 2 (confirmation — Option B pattern)**: autoload with zero-arg `_init()` + `_ready()` calling `wire_dependencies(100, "hello")` + non-autoload inner class `FalsifyResolver extends RefCounted` via `.new(100, "hello")` — all 7 assertion lines printed; Option B pattern works cleanly.
  - **New Claim 4 authored** `[VERIFIED]`, documenting Permitted patterns (A: lazy-default with public setters — canonical per ADR-0009 + `dungeon-run-orchestrator.md` §J.1; B: named `wire_dependencies` seam — valid but fails open; C: `_init` with all-defaulted args — discouraged) and the Forbidden pattern (autoload `_init` with required args).
  - **Impact**: ADR-0003 Amendment #2's phrasing "injected via `DungeonRunOrchestrator._init(combat_resolver, matchup_resolver)`" is mechanically impossible → ADR-0003 Amendment #3 (same day) corrects to Pattern A (lazy-default with two public setters + null-check in `_ready()`). architecture.md §Non-Autoload Pure-Function Modules + §Module Ownership Map corrected in lockstep. ADR-0009 codifies the Pattern A decision already locked in `dungeon-run-orchestrator.md` §J.1 Option A.
  - **Mid-lockstep rollback**: initial ADR-0009 draft proposed Pattern B (godot-specialist Step 4.5 recommendation). After writing 4 of 7 lockstep files, review of `dungeon-run-orchestrator.md` §J.1 surfaced that the Orchestrator GDD had already considered and rejected Pattern B's equivalent (§J.7 Option E: "fails open vs fails closed"). Rolled back — Pattern A adopted. Added lesson to §Change log: **ADR authoring MUST read GDD wiring sections (§J, §F, §C etc.) BEFORE specialist consult**, not after, to prevent proposing patterns the GDD already evaluated and rejected.
  - **Pattern lesson reinforcement**: this is the **fifth** engine-state claim that passed cross-model specialist convergence only to be falsified/refined by a ~5-minute empirical probe. Lesson #1 (empirical probes are the only authoritative evidence for engine-state API claims) continues to generalize. ADR authoring should ALWAYS probe load-bearing autoload/lifecycle claims before Accept; cross-model convergence is insufficient.
