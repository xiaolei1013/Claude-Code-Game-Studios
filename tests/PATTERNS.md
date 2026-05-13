# Test Patterns

Idioms and patterns for tests in this project. Read this BEFORE authoring a new test suite — many patterns here exist because rediscovering them cost real time.

> **Companion to `tests/README.md`** which covers infrastructure (how to run tests, where they live, naming, coverage targets). This file covers HOW to write them.

---

## 1. gdunit4 signal API surface

This project uses gdunit4 4.6.x (`addons/gdUnit4/`). The canonical signal-assertion API is:

```gdscript
# Wait up to ms for emission. Resolves immediately if already emitted.
await assert_signal(instance).wait_until(2000).is_emitted("signal_name")

# Assert NOT emitted within ms (use a SHORT timeout — this is fail-fast).
await assert_signal(instance).wait_until(300).is_not_emitted("signal_name")

# Synchronous: assert the signal has ALREADY fired (no waiting).
assert_signal(instance).is_emitted(callable_or_name, [optional_args])
```

**Does NOT exist in this project's gdunit4** (do NOT generate these — they will fail at parse or runtime):

| Don't write | Use instead |
|---|---|
| `watch_signals(obj)` | (no setup needed; `assert_signal(obj)` works directly) |
| `assert_signal(SIGNAL).was_emitted_once()` | `await assert_signal(instance).wait_until(ms).is_emitted("signal_name")` |
| `get_signal_emissions(obj)` | Array-spy lambda capture (see §2 below) |
| `clear_signal_emissions(obj)` | Disconnect + reconnect, OR use Array-spy and clear the array |
| `monitor_signals(obj)` | (no setup needed) |
| `raise_error("msg")` in tests | `push_error("msg")` if you need a side-effect emit; otherwise `assert_*().is_*()` produces the failure |
| `.with_message("custom failure msg")` | `.override_failure_message("custom failure msg")` |

**Why this matters**: S12-M5 (`fa6dfd9`) initially had a 25-test suite authored against this fictional API; every test failed at parse or with timeout. Rewrite cost ~0.5d. Prevent by validating against the actual API surface (`addons/gdUnit4/src/GdUnitSignalAssert.gd`) before authoring.

---

## 2. Array-spy lambda capture (canonical signal-args capture)

gdunit's signal asserts only verify whether a signal fired — they don't directly capture the emitted args. To assert on args, use the **Array-spy lambda pattern**:

```gdscript
# Counter-only spy — Array[int] for mutable-by-reference counter
var fire_count: Array[int] = [0]
instance.signal_name.connect(
    func(_arg1, _arg2): fire_count[0] += 1,
    CONNECT_ONE_SHOT  # or omit for continuous tracking
)

# Trigger emission
instance.do_thing()

# Wait for emission
await assert_signal(instance).wait_until(2000).is_emitted("signal_name")

# Assert
assert_int(fire_count[0]).is_equal(1)
```

```gdscript
# Args-capture spy — Array[Variant] capturing a single emission's args
var captured: Array = [null]  # untyped Array so any Variant fits
instance.signal_name.connect(
    func(arg1, arg2): captured[0] = {"arg1": arg1, "arg2": arg2},
    CONNECT_ONE_SHOT
)

instance.do_thing()
await assert_signal(instance).wait_until(2000).is_emitted("signal_name")

# Assert on captured args
assert_object(captured[0]).is_not_null()
assert_int(captured[0].arg1).is_equal(expected_value)
```

**Why a 1-element Array, not a `var`?** GDScript lambdas capture by value — primitive locals can't be mutated from inside. Reference types (Array, Dictionary) CAN be mutated by reference. The 1-element Array is the smallest reference-type wrapper.

**Canonical precedent**: `tests/integration/scene_manager/request_screen_and_node_swap_test.gd:56`.

---

## 3. Hygiene-barrier pattern (reset-on-entry-and-exit)

When tests touch live autoloads (state-bearing singletons at `/root/Foo`), cross-test contamination is the #1 source of flaky failures. The fix is **reset-on-entry-and-exit**, NOT snapshot+restore.

```gdscript
func _reset_autoload_state() -> void:
    var foo: Node = get_node_or_null("/root/Foo")
    if foo == null:
        return
    foo._some_state.clear()
    foo._some_flag = false
    foo._some_counter = 0


func before_test() -> void:
    _reset_autoload_state()


func after_test() -> void:
    _reset_autoload_state()
```

**Why reset, not snapshot+restore?** Snapshot+restore preserves contamination introduced by a prior test (you snapshot the contaminated state, run the test on contaminated state, restore the contaminated state). Reset cleans the slate on entry AND exit, so every test starts from a known clean state regardless of ordering.

**Canonical precedent**: `tests/unit/dungeon_run_orchestrator/autoload_skeleton_and_di_test.gd` header documents the rationale; pattern is used in `tests/integration/offline_progression_engine/offline_batch_chunking_test.gd:33` and `tests/unit/audio_router/audio_router_signal_handlers_test.gd:30`.

**Sprint origin**: Sprint 10 S10-S4 lesson; S12-M5 verification reused it.

---

## 4. ConfigFile / `user://` test isolation (path-override)

Autoloads that read from `user://*.cfg` at boot will pick up state leaked by prior test runs (the `user://` namespace persists across `Godot --headless` invocations). Tests MUST override the path to an isolated location.

**Production code** exposes the path as a member, defaulting to the production path:

```gdscript
# In src/core/scene_manager/scene_manager.gd
var _settings_cfg_path: String = "user://settings.cfg"

func _load_interim_settings() -> void:
    var cfg := ConfigFile.new()
    var err: Error = cfg.load(_settings_cfg_path)  # NOT a literal "user://..."
    ...
```

**Test fixture** overrides BEFORE `add_child()` triggers `_ready()`:

```gdscript
var _test_settings_path: String = ""

func before_test() -> void:
    _test_settings_path = "user://test_%d_settings.cfg" % Time.get_ticks_msec()


func after_test() -> void:
    if FileAccess.file_exists(_test_settings_path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(_test_settings_path))


func _make_wired_thing() -> Node:
    var sm: Node = SceneManagerScript.new()
    sm._settings_cfg_path = _test_settings_path  # ← BEFORE add_child
    add_child(sm)  # ← _ready() now reads from the isolated path
    ...
```

**Recovery on dev machine** if `user://settings.cfg` was leaked by a prior test run:
- macOS: `rm -f ~/Library/Application\ Support/Godot/app_userdata/<project>/settings.cfg`
- Linux: `rm -f ~/.local/share/godot/app_userdata/<project>/settings.cfg`
- Windows: `del %APPDATA%\Godot\app_userdata\<project>\settings.cfg`

**Canonical precedent**: `tests/integration/scene_manager/reduce_motion_clamp_test.gd:43`, `tests/integration/scene_manager/offline_replay_modal_coordination_test.gd:26`.

**Sprint origin**: S12-S2 — leaked `reduce_motion=true` silently broke `crossfade_timing_test.gd` 150ms structural assertions.

---

## 5. Async-API-change regression audit

When a public method changes from synchronous to async (gains `await ...` inside its body), pre-existing callers that don't `await` will fail silently — the next-line assertion runs at the first internal suspension before post-await work executes.

**Audit checklist** when changing sync → async:

1. Grep ALL callers, both production and test:
   ```bash
   grep -rn "method_name(" src/ tests/ assets/
   ```
2. For each caller, decide:
   - Already async? Add `await` to the call site.
   - Sync test? Update: either await + assert later, OR `for i in N: await get_tree().process_frame` then assert spy, OR restructure as a signal listener.
   - Sync production caller? May need contract update — async-implies-coroutine-suspension is a public-surface change, not just an implementation detail.
3. **Document at the change site AND in the function's surface comment** that the function is now async.
4. Run the full test sweep, not just the immediate change's tests, before declaring done.

**Canonical fix pattern** when test must be made async-aware:

```gdscript
# OLD (broken when method becomes async):
func test_method_emits_signal() -> void:
    obj.do_thing()
    assert_int(spy[0]).is_equal(1)  # spy not populated yet — method suspended internally

# NEW (await + capture):
func test_method_emits_signal() -> void:
    var captured = [null]
    obj.signal_name.connect(
        func(s): captured[0] = s, CONNECT_ONE_SHOT)
    obj.do_thing()
    await assert_signal(obj).wait_until(5000).is_emitted("signal_name")
    assert_object(captured[0]).is_not_null()
```

**Sprint origin**: S12-M5 changed `OfflineProgressionEngine.run_offline_replay` from sync stub to async chunked loop; 3 pre-existing skeleton tests failed silently with `Out of bounds get index '0'` until updated.

---

## 6. Debug-build spy field (`_test_*_log` for headless test observability)

When a public method has side effects that produce no observable result in headless mode (e.g., audio cue dispatch with no audio device), populate a debug-build-only log field that tests can inspect.

```gdscript
# In src/core/audio_router/audio_router.gd
var _test_play_sfx_log: Array = []

func play_sfx(sfx_id: StringName, pitch_scale: float = 1.0, volume_mult: float = 1.0) -> AudioStreamPlayer:
    if _headless_mode:
        return null

    if OS.is_debug_build():
        _test_play_sfx_log.append({
            "sfx_id": sfx_id,
            "pitch_scale": pitch_scale,
            "volume_mult": volume_mult,
        })

    # ... actual side-effect work
```

Tests inspect the log without needing an audio device:

```gdscript
func test_kill_chime_pitch_for_tier_3() -> void:
    _reset_audio_router()  # clears _test_play_sfx_log
    var ar: Node = _get_ar()

    ar._on_enemy_killed(3, "troll", false)

    var entry: Dictionary = _last_play(&"sfx_combat_enemy_kill")
    assert_float(float(entry.get("pitch_scale", 0.0))).is_equal_approx(1.00, 0.001)
```

**Caveats**:
- Gate behind `OS.is_debug_build()` so release builds carry zero overhead.
- Headless mode AudioRouter (`_headless_mode = true` when no audio device) returns BEFORE the log append — so tests on truly headless CI won't see entries. macOS dev box has CoreAudio devices so `_headless_mode = false` and the spy works there.
- The pattern is currently used only in AudioRouter. If a 2nd autoload adopts it, codify in an ADR.

**Canonical precedent**: `src/core/audio_router/audio_router.gd:133`, consumed in `tests/unit/audio_router/audio_router_signal_handlers_test.gd:60`.

**Sprint origin**: S12-M6 — needed to verify cue dispatch logic without sound assets present.

---

## 7. CI grep / forbidden-pattern enforcement

For ADR rules expressible as "no code path can do X", encode the rule as a test that greps the source and fails if X appears. The test serves two roles: enforcement at CI time AND living documentation of why the pattern is forbidden.

```gdscript
func test_no_direct_gold_changed_emit_during_replay_path() -> void:
    var source: String = _read_file("res://src/core/economy/economy.gd")
    var lines = source.split("\n")
    for i in range(lines.size()):
        var line = lines[i]
        if "gold_changed.emit" in line:
            var has_guard = false
            for j in range(maxi(0, i - 5), i + 1):
                if "_is_offline_replay" in lines[j]:
                    has_guard = true
                    break
            if not has_guard:
                # permitted only inside flush_offline_signals
                var in_flush = false
                for j in range(maxi(0, i - 10), i + 1):
                    if "func flush_offline_signals" in lines[j]:
                        in_flush = true
                        break
                assert_that(in_flush).override_failure_message(
                    "Unguarded gold_changed.emit at line %d" % (i + 1)
                ).is_true()
```

**Pattern**: read the source file, walk lines, check the rule's predicate, fail with a precise location message.

**Canonical precedent**: `tests/unit/offline_progression_engine/offline_forbidden_patterns_ci_grep_test.gd` (10 tests covering ADR-0014's 5 forbidden patterns).

**Sprint origin**: S12-M5 — ADR-0014 specifies forbidden patterns for the offline replay path; grep enforcement keeps them honest as the codebase evolves.

---

## 8. Wired-vs-autoload test pattern (SceneManager precedent)

For autoloads, you have two test surfaces:

- **Live autoload at `/root/Foo`** — used when the test needs the actual production wiring (CONSUMER_PATHS, signal subscriptions across other autoloads). Apply the hygiene-barrier pattern (§3) so order-independence holds within the shared session.
- **Wired non-autoload instance** — instantiate `FooScript.new()`, manually wire the dependencies the production autoload would have, and add to a test-controlled tree. Pattern when the test needs to control rank ordering, override paths, or test boot semantics in isolation.

The wired pattern is canonical in `tests/integration/scene_manager/request_screen_and_node_swap_test.gd:56`:

```gdscript
const SceneManagerScript = preload("res://src/core/scene_manager/scene_manager.gd")

func _make_wired_scene_manager() -> Array:
    # Order matters: add_child(sm) FIRST while MainRoot is absent, so
    # sm._ready() → _on_registry_ready() hits the test-env guard at
    # scene_manager.gd:959 and skips the boot auto-route.
    var sm: Node = SceneManagerScript.new()
    sm._settings_cfg_path = "user://test_isolated.cfg"  # see §4
    sm.state = SceneManagerScript.State.IDLE
    add_child(sm)
    await get_tree().process_frame

    var packed_main_root: PackedScene = load(MAIN_ROOT_SCENE_PATH) as PackedScene
    var main_root: Control = packed_main_root.instantiate() as Control
    get_tree().root.add_child(main_root)
    await get_tree().process_frame

    sm.state = SceneManagerScript.State.IDLE
    return [sm, main_root]


func _cleanup_wired(sm: Node, main_root: Node) -> void:
    if is_instance_valid(sm):
        sm.queue_free()
    if is_instance_valid(main_root):
        main_root.queue_free()
    await get_tree().process_frame
    await get_tree().process_frame
```

The order-of-operations comment is load-bearing — Sprint 10 S10-S3 was a 71-test failure cascade caused by adding `MainRoot` to `/root` before the SceneManager.

---

## 9. Test fixture order-of-operations gotcha

When a test adds multiple nodes to `/root` or to a parent tree, the order matters because `_ready()` fires synchronously on `add_child()` and may register signal connections, run boot scans, or transition state.

**Rule of thumb**: add the LISTENER autoload FIRST, then the SOURCE node, so the listener's `_ready()` registers handlers before the source emits anything.

**Counter-example fix**: `_make_wired_sm` in `request_screen_and_node_swap_test.gd:60` documents the explicit reason — adding MainRoot before SceneManager triggered the SM's `_on_registry_ready` boot auto-route, which then raced with explicit `request_screen` calls in test bodies.

---

## 10. Typed-collection literal assignment in test fixtures

Fields declared with strong typed-collection types — `Array[Dictionary]`, `Array[int]`, `Dictionary[int, int]`, etc. — runtime-reject untyped literal assignment at the property-set site. Tests that try to seed such a field with an inline `[...]` or `{...}` literal fail with:

```
Invalid assignment of property or key 'X' with value of type 'Array' on a base object of type 'Y'
```

**Wrong** — direct literal assignment to a `Array[Dictionary]` field:

```gdscript
orch._offline_pending_first_clears = [
    {"floor_index": 1, "biome_id": "x", "losing_run": false},
]
# SCRIPT ERROR — the literal is untyped Array, not Array[Dictionary]
```

**Right** — assign through a typed local:

```gdscript
var clears: Array[Dictionary] = [
    {"floor_index": 1, "biome_id": "x", "losing_run": false},
]
orch._offline_pending_first_clears = clears
```

Same gotcha applies to:
- `Array[int]` / `Array[String]` / `Array[Resource]` fields
- `Dictionary[K, V]` fields (Godot 4.4+)
- Any custom-typed Array (`Array[HeroInstance]`)

The runtime check is intentional — it prevents silent type drift on later mutations. The fix is mechanical (one typed-local var); apply consistently across test seeding code.

**Detection**: gdunit4 reports the failure as a SCRIPT ERROR mid-test, not a test-assertion failure. Look for "Invalid assignment of property" in the test log when a fixture-setup test fails inexplicably.

---

## 11a. auto_free in `_make_*` factory helpers (preserve orphan-zero baseline)

When a test factory helper instantiates a `Node`-extending type via `.new()` (typical for autoloads constructed outside the scene tree), the returned Node is NOT auto-freed by Godot — `Node.new()` returns an unparented Node that leaks at suite teardown. This shows up in the gdunit4 sweep as "N orphan nodes" warnings.

```gdscript
# WRONG — leaks one Node per call; sweep reports orphans accumulating across the suite.
func _make_sls() -> Node:
    return SaveLoadScript.new()

# RIGHT — auto_free registers the Node for cleanup at test end.
func _make_sls() -> Node:
    var sls: Node = SaveLoadScript.new()
    auto_free(sls)
    return sls
```

The canonical pattern is at `tests/unit/floor_unlock_system/floor_unlock_system_test.gd:_make_floor_unlock_with_stubs`. RefCounted-extending types (`extends RefCounted`) auto-clean via reference-counting; the `auto_free` is only required for `extends Node` (or descendant) types instantiated outside the scene tree.

Why it matters: a 0-orphan baseline means a future genuinely-leaked Node surfaces immediately as "1 orphan" in CI. A baseline of "15 orphans (pre-existing)" hides the new leak in the noise. Treat the orphan count as a leak detector, not a tolerance band.

---

## 11b. Clear class-level signal-spy fields in `before_test`, not mid-test

gdunit4 does NOT auto-clear class-level fields between tests. Class-level spy arrays/counters accumulate across tests — a spy that captured one signal in test A will carry that captured value into test B's assertions.

```gdscript
# WRONG — spy state carries across tests; "expected size 1, got 2" failures
var _load_failed_calls: Array[Dictionary] = []

func before_test() -> void:
    _reset_save_load_state()
    # forgot to clear _load_failed_calls — bleeds across tests

# RIGHT — explicit clear in before_test
func before_test() -> void:
    _reset_save_load_state()
    _load_failed_calls.clear()
    _load_completed_calls.clear()
    _tamper_calls = 0
```

Discovered during S18-N4 (forged-envelope migration test) — V0 test passed but V2 test failed at `_load_failed_calls.size().is_equal(1)` with actual size 2 because V0's load_failed call was still in the array.

Some test files (`save_persist_roundtrip_test.gd`) clear spies mid-test before the relevant assertion. That works for single-suite scenarios but doesn't generalize when adding new tests later — the next test author will reuse the spy field and forget the mid-test clear. The `before_test` hoist is the safer default.

---

## 12. CONNECT_ONE_SHOT for spies that should fire exactly once

When the spy is set up to verify a single emission, prefer `CONNECT_ONE_SHOT` so the lambda auto-disconnects after firing:

```gdscript
instance.signal_name.connect(
    func(s): captured[0] = s,
    CONNECT_ONE_SHOT
)
```

This prevents the spy from being re-fired by a subsequent test if the after_test cleanup doesn't disconnect it.

For continuous-emission spies (counters), omit the flag and ensure cleanup explicitly disconnects in `after_test`.

---

## 13. Lifecycle-asymmetry: check both halves of an API pair

When SceneManager (or any other system) exposes a pair of complementary methods — show/hide, open/close, push/pop, request/release — they should call equivalent lifecycle hooks. If one half automatically invokes a hook and the other doesn't, the asymmetric half WILL be the next bug.

### Canonical example (Sprint 14)

`SceneManager.request_screen()` automatically calls `new_screen.on_enter()` after the transition completes. `SceneManager.show_modal()` (added later for caller-owned modals) added the modal to the tree but did NOT call `on_enter()`. Hero Detail's `_render_all` ran inside `on_enter`, so the modal opened with `.tscn` placeholder labels ("Hero Name" / "Class" / "Level 1") instead of real hero data.

| Bug surfaced | Fix shipped |
|---|---|
| PR #58 (v0.0.0.17) — visible to playtest | Caller (Guild Hall) manually called `modal.on_enter()` after `show_modal()` |
| PR #59 (v0.0.0.18) — root cause fix | `show_modal()` now auto-calls `on_enter()`; `hide_modal()` symmetrically auto-calls `on_exit()`. Locked in by `tests/unit/scene_manager/show_modal_lifecycle_test.gd` (8 cases). |

### Detection heuristic

When you see one of these patterns, immediately check both halves:

```gdscript
# Symmetric (good):
func push_screen(s): ... s.on_enter()       # ✅ hook fires
func pop_screen(s):  s.on_exit()  ...       # ✅ hook fires

# Asymmetric (bug class):
func push_screen(s): ... s.on_enter()       # ✅ hook fires
func pop_screen(s):  ...                    # ❌ on_exit never called → signal handlers leak
```

### Test contract that catches it

When adding the second half of an API pair, write the regression test FIRST:

```gdscript
# Given a SpyScreen (records hook_log on each lifecycle call)
# When the new API method is called
# Then the spy's hook_log records on_enter (or on_exit, etc.) exactly once,
# at the right time (after add_child, after state transition, before queue_free).
```

`tests/unit/scene_manager/show_modal_lifecycle_test.gd` is the template — it asserts not just that the hook fired, but that the modal was in the tree at hook time + state was PAUSED at hook time + plain Controls (no Screen base) are skipped gracefully (`is Screen` type guard, not `has_method` — Story 004 contract forbids `has_method` in `scene_manager.gd`).

### Why the rule matters

The PR #58 visible bug was caught by the screenshot the user shared. But the bug class — "caller has to remember a lifecycle hook the API doesn't fire automatically" — is *invisible* in code review because absence-of-a-call is hard to spot. The regression test in PR #59 locks the contract by exercising the production code path; future callers cannot reintroduce the bug.

---

## 14. PanelContainer single-child rule

`PanelContainer` is a Godot single-child layout primitive. It sizes itself to its child and anchors that child to fill its rect. Adding multiple direct children stacks them all at the panel's (0,0) with no layout — every child renders on top of every other.

### Canonical example (Sprint 15)

Hero Detail modal had this structure:

```
DetailPanel (PanelContainer)
├── HeaderRow (HBoxContainer)
├── StatsBlock (VBoxContainer)
└── ActionRow (HBoxContainer)
```

PanelContainer anchored all three rows to the same rect — DisplayName, ClassName, Level, XP, and "warriors total" all overlapped in a single ~150px-tall stack. Hidden for weeks behind placeholder labels + a too-transparent dim backdrop; surfaced only when PR #58 + PR #65 made the real labels visible.

### The fix is always the same

Wrap in a layout container (almost always a `VBoxContainer`):

```
DetailPanel (PanelContainer)
└── ContentVBox (VBoxContainer)        ← the wrapper PanelContainer needs
    ├── HeaderRow
    ├── StatsBlock
    └── ActionRow
```

Both other modals in the project use this pattern correctly:
- `settings.tscn`: `Panel (PanelContainer) → VBox (VBoxContainer) → rows`
- `victory_moment.tscn`: `CenterPanel (PanelContainer) → CenterVBox (VBoxContainer) → rows`

### CI guard

`tests/unit/scene_layout/panel_container_single_child_ci_test.gd` scans every `.tscn` in `assets/` and `src/` and asserts no PanelContainer has more than one direct child. If you add a regression, the test prints the offending file + node path so you know exactly where to insert the missing VBoxContainer.

### Why this bug class is sneaky

The visible symptom — overlapping text — looks like a font / theme bug or a positioning issue. Developers reach for `anchors_preset` or `custom_minimum_size` adjustments and the symptom doesn't go away because the root cause is layout container choice, not layout numbers. Knowing the single-child rule shortcuts the diagnosis from ~30 min to ~30 sec.

---

## Cross-references

- `tests/README.md` — infrastructure (how to run, where files live, naming, coverage)
- `.claude/docs/coding-standards.md` — story-type → test-evidence matrix
- `.claude/rules/test-standards.md` — naming + arrange/act/assert + determinism rules
- Sprint retrospectives in `production/retrospectives/` — the source of most patterns here

## Pattern origins

| Pattern | Sprint of origin | Discovery cost |
|---|---|---|
| Array-spy lambda capture | Sprint 5–6 era | Inherited; canonical pattern |
| Hygiene-barrier reset-on-entry-and-exit | Sprint 10 S10-S4 | ~0.4d (snapshot+restore was wrong primitive) |
| ConfigFile `_settings_cfg_path` override | Sprint 12 S12-S2 | ~0.2d (leaked `reduce_motion=true` broke unrelated tests) |
| Async-API-change caller audit | Sprint 12 S12-M5 | ~0.1d (3 skeleton tests failed silently) |
| Debug-build `_test_*_log` spy | Sprint 12 S12-M6 | New pattern; ADR candidate if 2nd consumer adopts |
| gdunit4 API correction | Sprint 12 S12-M5 | ~0.5d (25 tests against fictional API rewritten) |
| CI grep forbidden-pattern | Sprint 12 S12-M5 | New pattern from ADR-0014 enforcement need |
| Wired-vs-autoload + order-of-operations | Sprint 10 S10-S3 | 71-test failure cascade until reordered |
| auto_free in `_make_*` factory helpers | Sprint 18 hygiene cycle (commit `f826643`) | ~0.2d (15-orphan baseline masked detection) |
| Clear spy fields in `before_test` | Sprint 18 hygiene cycle (commit `e42c657`) | ~0.1d (V2 test sized 2 vs expected 1) |
| Typed-collection literal-rejection | Sprint 11 S11-X10 (Recruitment) — re-surfaced Sprint 14 S14-M4 Story 4 | Fix is mechanical; the gotcha resurfaces every time net-new test code seeds a typed-collection field |
| Lifecycle-asymmetry: check both halves of an API pair | Sprint 14 PR #58 → PR #59 (`show_modal` vs `request_screen`) | ~0.5d (visible bug surfaced by playtest screenshot; root-cause fix + regression suite landed next PR) |
| PanelContainer single-child rule | Sprint 15 PR #69 (Hero Detail modal layout collapse) | ~0.25d once root cause identified; multiple weeks hidden behind placeholder labels + dim backdrop transparency before surfacing |
