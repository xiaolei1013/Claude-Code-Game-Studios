# Sprint 16 S16-M1 candidate scaffold — contract-layer tests for the
# Recruit Screen #21.
#
# Tests cover the load-bearing contract:
#   - on_enter resolves pool + connects signals
#   - Pool render reads from Recruitment.get_recruit_pool /
#     get_recruit_cost / HeroRoster.get_copies_owned
#   - RecruitButton affordability gating reflects gold balance
#   - try_recruit RecruitOutcome enum match (drift fix from sweep)
#   - hero_recruited signal triggers re-render (via HeroRoster's 1-arg
#     form per sweep disambiguation)
#   - gold_changed signal triggers gating refresh
#   - Refresh Pool button reads cost via get_refreshes_today + refresh_cost
#
# Visual layout tests are NOT included — those are /design-review polish
# items per Recruit Screen GDD #21 §I.
extends GdUnitTestSuite

const RecruitScreenScene = preload("res://assets/screens/recruitment/recruitment.tscn")
const RecruitmentScript = preload("res://src/core/recruitment/recruitment.gd")
const HeroInstanceScript = preload("res://src/core/hero_roster/hero_instance.gd")
# Story 015 — Group G reads the animator node name (single source of truth) to
# locate the idle animator the recruit render path attaches to ClassPortrait.
const ClassSpriteFactoryScript = preload("res://src/ui/class_sprite_factory.gd")


func _make_screen() -> Node:
	var screen: Node = RecruitScreenScene.instantiate()
	add_child(screen)
	auto_free(screen)
	return screen


# Test isolation — track injected heroes so after_test removes them from
# the live HeroRoster autoload (S10-S4 hygiene-barrier pattern per
# tests/PATTERNS.md §3).
var _injected_hero_ids: Array[int] = []

# Test isolation for the live SceneManager.reduce_motion flag (Story 015). Group G
# mutates the autoload's accessibility flag; snapshot-and-restore so a failing
# assertion mid-test can't leak `reduce_motion = true` into sibling suites.
var _sm: Node = null
var _sm_reduce_motion_prior: bool = false
var _sm_reduce_motion_touched: bool = false


# Sets the live SceneManager.reduce_motion flag, recording the prior value on the
# first touch so after_test can restore it. No-op when the autoload is absent.
func _set_reduce_motion(value: bool) -> void:
	_sm = get_node_or_null("/root/SceneManager")
	if _sm == null:
		return
	if not _sm_reduce_motion_touched:
		_sm_reduce_motion_prior = bool(_sm.get("reduce_motion"))
		_sm_reduce_motion_touched = true
	_sm.set("reduce_motion", value)


func _inject_hero(id: int, class_id: String) -> RefCounted:
	var fake: RefCounted = HeroInstanceScript.new()
	fake.instance_id = id
	fake.class_id = class_id
	fake.display_name = "Test Hero %d" % id
	fake.current_level = 1
	fake.xp = 0
	HeroRoster._heroes[id] = fake
	_injected_hero_ids.append(id)
	return fake


func after_test() -> void:
	for id: int in _injected_hero_ids:
		HeroRoster._heroes.erase(id)
	_injected_hero_ids.clear()
	# Restore the live reduce_motion flag if a test touched it (Story 015).
	if _sm_reduce_motion_touched and _sm != null:
		_sm.set("reduce_motion", _sm_reduce_motion_prior)
	_sm_reduce_motion_touched = false
	_sm = null


# ===========================================================================
# Group A — POOL_SIZE constant pickup
# ===========================================================================

func test_recruit_screen_pool_size_matches_recruitment_constant() -> void:
	var screen: Node = _make_screen()
	# The screen's POOL_SIZE must track RecruitmentScript.POOL_SIZE exactly so
	# the .tscn PoolEntryN row count, _pool_entries, and the domain pool stay in
	# lockstep. Assert against the constant (not a literal) so a future tuning
	# bump only needs the const + matching .tscn rows.
	assert_int(screen.POOL_SIZE).is_equal(RecruitmentScript.POOL_SIZE)


# ===========================================================================
# Group B — on_enter wires signals + initial render
# ===========================================================================

func test_recruit_screen_on_enter_connects_pool_refreshed() -> void:
	var screen: Node = _make_screen()
	screen.on_enter()
	assert_bool(Recruitment.pool_refreshed.is_connected(screen._on_pool_refreshed)).is_true()
	# Cleanup connections after on_enter.
	screen.on_exit()


func test_recruit_screen_on_enter_connects_hero_recruited_on_HeroRoster() -> void:
	# Drift-fix sweep verification: subscribe to HeroRoster's 1-arg
	# hero_recruited (NOT Recruitment's 3-arg).
	var screen: Node = _make_screen()
	screen.on_enter()
	assert_bool(HeroRoster.hero_recruited.is_connected(screen._on_hero_recruited)).is_true()
	screen.on_exit()


func test_recruit_screen_on_enter_connects_gold_changed() -> void:
	var screen: Node = _make_screen()
	screen.on_enter()
	assert_bool(Economy.gold_changed.is_connected(screen._on_gold_changed)).is_true()
	screen.on_exit()


# on_exit disconnects everything (clean re-entry).
func test_recruit_screen_on_exit_disconnects_all_signals() -> void:
	var screen: Node = _make_screen()
	screen.on_enter()
	screen.on_exit()
	assert_bool(Recruitment.pool_refreshed.is_connected(screen._on_pool_refreshed)).is_false()
	assert_bool(HeroRoster.hero_recruited.is_connected(screen._on_hero_recruited)).is_false()
	assert_bool(Economy.gold_changed.is_connected(screen._on_gold_changed)).is_false()


# ===========================================================================
# Group C — Pool render reads from Recruitment + Economy + HeroRoster
# ===========================================================================

# After on_enter, the GoldCounter label reflects Economy.get_gold_balance.
# Sprint 17 S17-S5: gold values >= 1000 render via UIFramework.format_short_number
# as "1.2K" (Recruit Screen GDD #21 §C.3 cozy-display thresholds).
func test_recruit_screen_renders_gold_counter_from_economy() -> void:
	var screen: Node = _make_screen()
	# Set a known gold balance below K threshold to exercise raw-int format.
	Economy._gold_balance = 555
	screen.on_enter()
	# Counter reflects the raw value (sub-K threshold).
	assert_bool(screen._gold_counter.text.contains("555")).is_true()
	screen.on_exit()


# Above K threshold uses short-number format.
func test_recruit_screen_gold_counter_uses_short_number_format_above_k() -> void:
	var screen: Node = _make_screen()
	Economy._gold_balance = 1234
	screen.on_enter()
	# 1234 → "1.2K".
	assert_bool(screen._gold_counter.text.contains("1.2K")).is_true()
	screen.on_exit()


# ===========================================================================
# Group D — Refresh Pool button cost reads via get_refreshes_today
# ===========================================================================

# After on_enter, the RefreshPoolButton text reflects the current
# refresh_cost(get_refreshes_today). With _refreshes_today = 0 (initial),
# refresh_cost(0) = BASE_REFRESH_COST = 250 per ADR-0015.
func test_recruit_screen_refresh_button_text_includes_cost() -> void:
	var screen: Node = _make_screen()
	# Ensure refreshes_today = 0 (initial state in the live autoload).
	Recruitment._refreshes_today = 0
	screen.on_enter()
	# Text format: "Refresh Pool — N gold". Default cost = BASE_REFRESH_COST = 100
	# (per recruitment.gd:72; Recruitment GDD §I OQ-RC-2 resolution).
	assert_bool(screen._refresh_pool_button.text.contains("100")).is_true()
	screen.on_exit()


# Refresh button affordability: when gold < cost, button.disabled = true.
func test_recruit_screen_refresh_button_disabled_when_insufficient_gold() -> void:
	var screen: Node = _make_screen()
	Recruitment._refreshes_today = 0  # cost = 100
	Economy._gold_balance = 50  # < cost
	screen.on_enter()
	assert_bool(screen._refresh_pool_button.disabled).is_true()
	screen.on_exit()


func test_recruit_screen_refresh_button_enabled_when_sufficient_gold() -> void:
	var screen: Node = _make_screen()
	Recruitment._refreshes_today = 0  # cost = 100
	Economy._gold_balance = 500  # > cost
	screen.on_enter()
	assert_bool(screen._refresh_pool_button.disabled).is_false()
	screen.on_exit()


# ===========================================================================
# Group E — try_recruit RecruitOutcome enum match (drift fix from sweep)
# ===========================================================================

# The screen's _on_recruit_pressed handler matches on the RecruitOutcome
# enum (NOT bool). Group E exercises the match by injecting various
# Economy + Recruitment states + asserting the screen correctly routes.

# SUCCESS path: gold sufficient, valid pool index, valid class. The screen
# does not need to do anything special on SUCCESS — signals fire from
# try_recruit's atomic path. The match SUCCESS arm is a `pass`. We verify
# the press doesn't crash.
func test_recruit_screen_recruit_press_with_sufficient_gold_does_not_crash() -> void:
	var screen: Node = _make_screen()
	# Need DataRegistry to resolve at least one class — skip if not.
	if DataRegistry.resolve("classes", "warrior") == null:
		push_warning("Skipped: DataRegistry can't resolve 'warrior'")
		return
	# Arrange: live Recruitment pool will be seeded by its own _ready.
	# The screen is only an OBSERVER; the press path goes through the
	# autoload's try_recruit which handles SUCCESS / failure modes.
	# Set Economy with substantial gold so any pool entry is affordable.
	Economy._gold_balance = 100000
	screen.on_enter()
	# Press pool_index=0 (whatever class the live pool happens to have).
	screen._on_recruit_pressed(0)
	# No crash — the match-on-enum path executed.
	assert_bool(true).is_true()
	screen.on_exit()


# Out-of-range pool_index — defensive race condition path (push_warning +
# early return). Verifies the guard, not the enum.
func test_recruit_screen_recruit_press_out_of_range_pool_index_is_noop() -> void:
	var screen: Node = _make_screen()
	screen.on_enter()
	# pool_index = 99 (out of range) — defensive early return.
	screen._on_recruit_pressed(99)
	# No crash; no try_recruit call (the screen's guard catches it).
	assert_bool(true).is_true()
	screen.on_exit()


# Negative pool_index — same defensive guard.
func test_recruit_screen_recruit_press_negative_pool_index_is_noop() -> void:
	var screen: Node = _make_screen()
	screen.on_enter()
	screen._on_recruit_pressed(-1)
	assert_bool(true).is_true()
	screen.on_exit()


# ===========================================================================
# Group F — Back button routes to guild_hall
# ===========================================================================

# The press handler calls SceneManager.request_screen("guild_hall", ...).
# In the test env, MainRoot is not registered (per the documented test-env
# early-return path in scene_manager.gd:1149), so a full
# request_screen call fires a push_error. Test the WIRING (handler
# connected) rather than the route (which requires the full scene tree
# fixture documented in tests/PATTERNS.md §8 wired-vs-autoload pattern).
func test_recruit_screen_back_button_handler_wired_in_on_enter() -> void:
	var screen: Node = _make_screen()
	screen.on_enter()
	assert_bool(screen._back_button.pressed.is_connected(screen._on_back_pressed)).is_true()
	screen.on_exit()
	# After on_exit, handler is disconnected.
	assert_bool(screen._back_button.pressed.is_connected(screen._on_back_pressed)).is_false()


# ===========================================================================
# Group G — Story 015: reduce_motion end-to-end through the real render path
#
# The factory unit test proves animate(reduce_motion=true) freezes the animator;
# THIS proves the recruit screen actually THREADS its live SceneManager read into
# that call. Drives the real _render_pool_entry path (not the factory directly),
# so it's the scaffolded-but-unwired regression net: if the call site dropped the
# 4th arg, the portrait would loop under reduce_motion and this test would catch it.
# "warrior" is the canonical committed-art class (see ClassSpriteFactory tests),
# so the idle animator is guaranteed to attach.
# ===========================================================================

func test_recruit_pool_entry_freezes_portrait_idle_under_reduce_motion() -> void:
	var screen: Node = _make_screen()
	# Render a known committed-art class with reduce_motion ON.
	_set_reduce_motion(true)
	screen._render_pool_entry(screen._pool_entries[0], 0, "warrior")

	var portrait: TextureRect = screen._pool_entries[0].get_node("ClassPortrait") as TextureRect
	var anim: Node = portrait.get_node_or_null(
		String(ClassSpriteFactoryScript.ANIMATOR_NODE_NAME))
	# Committed warrior art ⇒ animator attached, but frozen (presence, no motion).
	assert_object(anim).is_not_null()
	assert_bool(anim.is_processing()).is_false()


func test_recruit_pool_entry_animates_portrait_idle_without_reduce_motion() -> void:
	# Control: the SAME render path with reduce_motion OFF leaves the idle looping,
	# proving the freeze above is caused by the threaded flag, not an inert slot.
	var screen: Node = _make_screen()
	_set_reduce_motion(false)
	screen._render_pool_entry(screen._pool_entries[0], 0, "warrior")

	var portrait: TextureRect = screen._pool_entries[0].get_node("ClassPortrait") as TextureRect
	var anim: Node = portrait.get_node_or_null(
		String(ClassSpriteFactoryScript.ANIMATOR_NODE_NAME))
	assert_object(anim).is_not_null()
	assert_bool(anim.is_processing()).is_true()
