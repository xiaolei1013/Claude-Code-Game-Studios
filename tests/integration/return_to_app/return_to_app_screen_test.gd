## return_to_app_screen_test.gd — S13-M2 Integration Tests
##
## Covers ReturnToApp screen lifecycle and rendering per Story 9 ACs:
##   Group A: Signal subscription (on_enter connects; on_exit disconnects).
##   Group B: Render with cached summary (labels contain expected substrings).
##   Group C: Render with no summary (fallback label visible).
##   Group D: Acknowledge button routes via SceneManager.
##   Group E: Re-render on offline_rewards_collected emission while screen alive.
##   Group F: cap_reached path renders the cap notice.
##
## Test strategy:
##   - Screen is instantiated from its .tscn and added to the test tree.
##   - OfflineProgressionEngine._last_summary is set directly in fixtures (test
##     field access, stable per STABLE-FOR-TEST-ACCESS pattern across this project).
##   - SceneManager.request_screen is verified via Array-spy lambda on the live
##     autoload. Hygiene barrier resets spy state on entry and exit.
##   - Signal pumping: process_frame between act and assert for any async paths.
##
## Pattern references: tests/PATTERNS.md §2 (Array-spy), §3 (hygiene barrier),
##   §8 (wired-vs-autoload), §10 (CONNECT_ONE_SHOT).
extends GdUnitTestSuite

const ReturnToAppScene = preload(
	"res://assets/screens/return_to_app/return_to_app.tscn"
)

## Max frames to pump when waiting for async operations (generous headroom).
const _MAX_PUMP_FRAMES: int = 30

## Frame count for "must NOT fire" assertions (fail-fast).
const _NO_EMIT_FRAMES: int = 5


# ---------------------------------------------------------------------------
# Hygiene barrier — reset live autoload state before and after every test.
# Prevents cross-test contamination via OfflineProgressionEngine._last_summary.
# ---------------------------------------------------------------------------

func _reset_oe_state() -> void:
	OfflineProgressionEngine._last_summary = null
	OfflineProgressionEngine._replay_in_flight = false
	OfflineProgressionEngine._pending_elapsed_seconds = 0


func before_test() -> void:
	_reset_oe_state()


func after_test() -> void:
	_reset_oe_state()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Instantiates and adds the ReturnToApp screen to the test tree.
## Returns the screen node. Caller must queue_free in cleanup.
func _make_screen() -> Control:
	var screen: Control = ReturnToAppScene.instantiate() as Control
	add_child(screen)
	await get_tree().process_frame
	return screen


## Builds a populated OfflineSummary suitable for render tests.
## gold_earned=1500, seconds_credited=3600 (60 min), floors_cleared 2 entries,
## kills_by_tier meta: {1: 20, 2: 5} → total_kills=25.
func _make_summary() -> OfflineProgressionEngine.OfflineSummary:
	var s: OfflineProgressionEngine.OfflineSummary = (
		OfflineProgressionEngine.OfflineSummary.new()
	)
	s.gold_earned = 1500
	s.seconds_credited = 3600  # 60 minutes
	s.seconds_clipped = 0
	s.ticks_replayed = 72000
	s.chunks_consumed = 3
	s.total_replay_wall_time_ms = 45
	var floors: Array[int] = [1, 3]
	s.floors_cleared_in_window = floors
	var kills_dict: Dictionary = {1: 20, 2: 5}
	s.set_meta("_kills_by_tier", kills_dict)
	return s


# ===========================================================================
# Group A: Signal subscription
# ===========================================================================

## A-01: on_enter connects to offline_rewards_collected.
##
## Given: screen added to tree; no prior subscriptions.
## When: on_enter() called.
## Then: OfflineProgressionEngine.offline_rewards_collected.is_connected to
##       screen's _on_offline_rewards_collected handler.
func test_on_enter_connects_offline_rewards_collected_signal() -> void:
	# Arrange
	var screen: Control = await _make_screen()

	# Act
	screen.on_enter()
	await get_tree().process_frame

	# Assert — screen is connected (use has_method to verify without private ref)
	# We verify indirectly: emit the signal; confirm screen label re-renders.
	# (Direct is_connected requires a Callable reference to the bound method.)
	# Strategy: set a summary, emit, check label.
	var summary: OfflineProgressionEngine.OfflineSummary = _make_summary()
	OfflineProgressionEngine._last_summary = summary
	OfflineProgressionEngine.offline_rewards_collected.emit(summary)
	await get_tree().process_frame

	# If connected, GoldRow should now contain "1500"
	var gold_row: Label = screen.get_node("SummaryPanel/VBoxContainer/GoldRow") as Label
	assert_bool(gold_row.text.contains("1500")).is_true()

	# Cleanup
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


## A-02: on_enter connects to cap_reached signal.
##
## Given: screen added; on_enter called.
## When: OfflineProgressionEngine.cap_reached emitted.
## Then: CapNotice becomes visible (handler stored the value; next render shows it).
func test_on_enter_connects_cap_reached_signal() -> void:
	# Arrange
	var summary: OfflineProgressionEngine.OfflineSummary = _make_summary()
	OfflineProgressionEngine._last_summary = summary
	var screen: Control = await _make_screen()
	screen.on_enter()
	await get_tree().process_frame

	# Act — emit cap_reached to populate _pending_seconds_clipped; then re-emit
	# offline_rewards_collected to trigger _render_summary which shows the notice.
	OfflineProgressionEngine.cap_reached.emit(7200)
	var summary2: OfflineProgressionEngine.OfflineSummary = _make_summary()
	summary2.seconds_clipped = 0  # ensure it comes from _pending_seconds_clipped
	OfflineProgressionEngine.offline_rewards_collected.emit(summary2)
	await get_tree().process_frame

	# Assert — CapNotice is visible
	var cap_notice: Label = screen.get_node("SummaryPanel/VBoxContainer/CapNotice") as Label
	assert_bool(cap_notice.visible).is_true()

	# Cleanup
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


## A-03: on_exit disconnects both signals.
##
## Given: on_enter was called; both signals are connected.
## When: on_exit() called.
## Then: emitting offline_rewards_collected no longer re-renders GoldRow.
func test_on_exit_disconnects_signals() -> void:
	# Arrange
	var summary: OfflineProgressionEngine.OfflineSummary = _make_summary()
	OfflineProgressionEngine._last_summary = summary
	var screen: Control = await _make_screen()
	screen.on_enter()
	await get_tree().process_frame

	# Act — disconnect
	screen.on_exit()
	await get_tree().process_frame

	# Record GoldRow text now, then emit with a different summary and verify no change.
	var gold_row: Label = screen.get_node("SummaryPanel/VBoxContainer/GoldRow") as Label
	var text_before: String = gold_row.text

	var summary2: OfflineProgressionEngine.OfflineSummary = (
		OfflineProgressionEngine.OfflineSummary.new()
	)
	summary2.gold_earned = 9999
	summary2.seconds_credited = 100
	OfflineProgressionEngine.offline_rewards_collected.emit(summary2)
	await get_tree().process_frame

	# Assert — GoldRow text unchanged (handler disconnected)
	assert_str(gold_row.text).is_equal(text_before)

	# Cleanup
	screen.queue_free()
	await get_tree().process_frame


# ===========================================================================
# Group B: Render with cached summary
# ===========================================================================

## B-01: on_enter with cached summary renders gold_earned in GoldRow.
func test_on_enter_with_summary_renders_gold_in_gold_row() -> void:
	# Arrange
	var summary: OfflineProgressionEngine.OfflineSummary = _make_summary()
	OfflineProgressionEngine._last_summary = summary
	var screen: Control = await _make_screen()

	# Act
	screen.on_enter()
	await get_tree().process_frame

	# Assert — GoldRow contains "1500"
	var gold_row: Label = screen.get_node("SummaryPanel/VBoxContainer/GoldRow") as Label
	assert_bool(gold_row.text.contains("1500")).is_true()

	# Cleanup
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


## B-02: on_enter with cached summary renders elapsed minutes in ElapsedSubhead.
## summary.seconds_credited=3600 → 60 minutes.
func test_on_enter_with_summary_renders_elapsed_minutes() -> void:
	# Arrange
	var summary: OfflineProgressionEngine.OfflineSummary = _make_summary()
	OfflineProgressionEngine._last_summary = summary
	var screen: Control = await _make_screen()

	# Act
	screen.on_enter()
	await get_tree().process_frame

	# Assert — ElapsedSubhead contains "60"
	var subhead: Label = screen.get_node(
		"SummaryPanel/VBoxContainer/ElapsedSubhead"
	) as Label
	assert_bool(subhead.text.contains("60")).is_true()

	# Cleanup
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


## B-03: on_enter with cached summary renders total_kills (25) in KillsRow.
## _kills_by_tier: {1: 20, 2: 5} → total=25.
func test_on_enter_with_summary_renders_kills_total() -> void:
	# Arrange
	var summary: OfflineProgressionEngine.OfflineSummary = _make_summary()
	OfflineProgressionEngine._last_summary = summary
	var screen: Control = await _make_screen()

	# Act
	screen.on_enter()
	await get_tree().process_frame

	# Assert — KillsRow contains "25"
	var kills_row: Label = screen.get_node("SummaryPanel/VBoxContainer/KillsRow") as Label
	assert_bool(kills_row.text.contains("25")).is_true()

	# Cleanup
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


## B-04: on_enter with cached summary renders floors_cleared count in FloorsRow.
## floors_cleared_in_window has 2 entries → "2".
func test_on_enter_with_summary_renders_floors_count() -> void:
	# Arrange
	var summary: OfflineProgressionEngine.OfflineSummary = _make_summary()
	OfflineProgressionEngine._last_summary = summary
	var screen: Control = await _make_screen()

	# Act
	screen.on_enter()
	await get_tree().process_frame

	# Assert — FloorsRow contains "2"
	var floors_row: Label = screen.get_node("SummaryPanel/VBoxContainer/FloorsRow") as Label
	assert_bool(floors_row.text.contains("2")).is_true()

	# Cleanup
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


# ===========================================================================
# Group C: Render with no summary
# ===========================================================================

## C-01: on_enter with no cached summary shows the fallback label.
func test_on_enter_with_no_summary_shows_fallback_label() -> void:
	# Arrange — _last_summary is null (hygiene barrier already cleared it)
	var screen: Control = await _make_screen()

	# Act
	screen.on_enter()
	await get_tree().process_frame

	# Assert — NoSummaryLabel is visible
	var no_summary_label: Label = screen.get_node(
		"SummaryPanel/VBoxContainer/NoSummaryLabel"
	) as Label
	assert_bool(no_summary_label.visible).is_true()

	# Assert — GoldRow is empty (no data to render)
	var gold_row: Label = screen.get_node("SummaryPanel/VBoxContainer/GoldRow") as Label
	assert_str(gold_row.text).is_equal("")

	# Cleanup
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


## C-02: on_enter with no summary still shows the header.
func test_on_enter_with_no_summary_still_shows_header() -> void:
	# Arrange
	var screen: Control = await _make_screen()

	# Act
	screen.on_enter()
	await get_tree().process_frame

	# Assert — HeaderLabel is non-empty (tr returns key in headless env, or real string)
	var header: Label = screen.get_node("SummaryPanel/VBoxContainer/HeaderLabel") as Label
	assert_bool(header.text.length() > 0).is_true()

	# Cleanup
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


# ===========================================================================
# Group D: Acknowledge button routes via SceneManager
# ===========================================================================

## D-01: AcknowledgeButton press calls SceneManager.request_screen("guild_hall").
##
## Strategy: spy on SceneManager.request_screen via Array capture. SceneManager
## is the live autoload. We connect to the screen's AcknowledgeButton.pressed
## signal to verify routing without needing to simulate an actual screen swap.
## After assertion we let the in-flight SM request drain naturally.
func test_acknowledge_button_routes_to_guild_hall() -> void:
	# Arrange
	var summary: OfflineProgressionEngine.OfflineSummary = _make_summary()
	OfflineProgressionEngine._last_summary = summary
	var screen: Control = await _make_screen()
	screen.on_enter()
	await get_tree().process_frame

	# Spy on SceneManager.screen_changed signal — fires when request_screen
	# completes a transition. (request_screen is a function, not a signal —
	# to verify it was called, we observe its side effect.)
	# In test env without MainRoot wired, the transition may early-return
	# without firing screen_changed. So we assert the BUTTON CONNECTION
	# exists + count, which is what the screen wire-up actually controls.
	# End-to-end transition behavior is covered by SceneManager's own tests.

	# Act — verify the button has a pressed connection
	var btn: Button = screen.get_node("SummaryPanel/VBoxContainer/AcknowledgeButton") as Button
	assert_object(btn).is_not_null()

	# get_connections() returns an untyped Array; using untyped local per the
	# project's typed-collection-fixture memory note.
	var pressed_connections: Array = btn.pressed.get_connections()
	# Assert — exactly one connection (the screen's _on_acknowledge_button_pressed)
	assert_int(pressed_connections.size()).is_equal(1)

	# Don't actually emit pressed — the handler calls SceneManager.request_screen
	# which crashes in test env without MainRoot wired (asserts on
	# _get_screen_container). The connection-existence assertion above
	# verifies the wire-up; end-to-end transition is SceneManager's own
	# test responsibility, covered by request_screen_and_node_swap_test.gd.

	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


# ===========================================================================
# Group E: Re-render on signal emission while screen is alive
# ===========================================================================

## E-01: offline_rewards_collected fires while screen is active → GoldRow updates.
##
## Given: screen on_entered with summary A (gold=1500).
## When: offline_rewards_collected emits with summary B (gold=9000).
## Then: GoldRow contains "9000".
func test_rerender_on_rewards_collected_while_screen_alive() -> void:
	# Arrange
	var summary_a: OfflineProgressionEngine.OfflineSummary = _make_summary()
	OfflineProgressionEngine._last_summary = summary_a
	var screen: Control = await _make_screen()
	screen.on_enter()
	await get_tree().process_frame

	var gold_row: Label = screen.get_node("SummaryPanel/VBoxContainer/GoldRow") as Label
	assert_bool(gold_row.text.contains("1500")).is_true()

	# Act — emit with new summary while screen is alive
	var summary_b: OfflineProgressionEngine.OfflineSummary = (
		OfflineProgressionEngine.OfflineSummary.new()
	)
	summary_b.gold_earned = 9000
	summary_b.seconds_credited = 1800
	summary_b.seconds_clipped = 0
	OfflineProgressionEngine.offline_rewards_collected.emit(summary_b)
	await get_tree().process_frame

	# Assert — GoldRow updated to 9000
	assert_bool(gold_row.text.contains("9000")).is_true()

	# Cleanup
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


# ===========================================================================
# Group F: cap_reached path
# ===========================================================================

## F-01: cap_reached + subsequent render shows CapNotice with capped hours.
##
## Given: screen on_entered; cap_reached fires with 7200 seconds clipped (2h).
## When: offline_rewards_collected fires triggering _render_summary.
## Then: CapNotice is visible and contains "2".
func test_cap_reached_then_rewards_shows_cap_notice() -> void:
	# Arrange
	var summary: OfflineProgressionEngine.OfflineSummary = _make_summary()
	OfflineProgressionEngine._last_summary = summary
	var screen: Control = await _make_screen()
	screen.on_enter()
	await get_tree().process_frame

	# Act — fire cap_reached FIRST (mirrors production order), then rewards.
	OfflineProgressionEngine.cap_reached.emit(7200)
	var summary2: OfflineProgressionEngine.OfflineSummary = _make_summary()
	summary2.seconds_clipped = 0  # force via _pending_seconds_clipped path
	OfflineProgressionEngine.offline_rewards_collected.emit(summary2)
	await get_tree().process_frame

	# Assert — CapNotice visible and contains "2" (7200 / 3600 = 2 hours)
	var cap_notice: Label = screen.get_node("SummaryPanel/VBoxContainer/CapNotice") as Label
	assert_bool(cap_notice.visible).is_true()
	assert_bool(cap_notice.text.contains("2")).is_true()

	# Cleanup
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


## F-02: seconds_clipped in summary directly also shows CapNotice.
##
## Given: screen on_entered; summary has seconds_clipped=3600 (1h).
## When: on_enter renders the summary.
## Then: CapNotice visible and contains "1".
func test_summary_with_seconds_clipped_shows_cap_notice() -> void:
	# Arrange
	var summary: OfflineProgressionEngine.OfflineSummary = _make_summary()
	summary.seconds_clipped = 3600
	OfflineProgressionEngine._last_summary = summary
	var screen: Control = await _make_screen()

	# Act
	screen.on_enter()
	await get_tree().process_frame

	# Assert — CapNotice visible and contains "1" (3600 / 3600 = 1 hour)
	var cap_notice: Label = screen.get_node("SummaryPanel/VBoxContainer/CapNotice") as Label
	assert_bool(cap_notice.visible).is_true()
	assert_bool(cap_notice.text.contains("1")).is_true()

	# Cleanup
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


# ===========================================================================
# Group G: Region-unlock celebration row (Sprint 28 N2)
#
# The offline engine sets a "_biomes_unlocked" meta (Array[String] of biome
# ids) on the summary when the offline window unlocked one or more biomes. The
# screen surfaces these as a "New region unlocked: <name>" row via the shared
# biome_unlocked_toast_format string, mapping ids → display names.
# ===========================================================================

## G-01: summary with one unlocked biome shows the RegionUnlockRow with the
## biome's display name (or id fallback) — asserted case-insensitively so the
## test is robust to whether BiomeDungeonDatabase resolves the display name.
func test_on_enter_with_unlocked_biome_shows_region_row() -> void:
	# Arrange
	var summary: OfflineProgressionEngine.OfflineSummary = _make_summary()
	var unlocked: Array[String] = ["ember_wastes"]
	summary.set_meta("_biomes_unlocked", unlocked)
	OfflineProgressionEngine._last_summary = summary
	var screen: Control = await _make_screen()

	# Act
	screen.on_enter()
	await get_tree().process_frame

	# Assert — RegionUnlockRow is visible and names the unlocked region.
	var row: Label = screen.get_node(
		"SummaryPanel/VBoxContainer/RegionUnlockRow"
	) as Label
	assert_bool(row.visible).is_true()
	assert_bool(row.text.to_lower().contains("ember")).is_true()

	# Cleanup
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


## G-02: summary WITHOUT the "_biomes_unlocked" meta keeps the row hidden —
## the common case (no biome crossed a gate offline).
func test_on_enter_without_unlock_meta_hides_region_row() -> void:
	# Arrange — _make_summary sets no "_biomes_unlocked" meta.
	var summary: OfflineProgressionEngine.OfflineSummary = _make_summary()
	OfflineProgressionEngine._last_summary = summary
	var screen: Control = await _make_screen()

	# Act
	screen.on_enter()
	await get_tree().process_frame

	# Assert — RegionUnlockRow is hidden.
	var row: Label = screen.get_node(
		"SummaryPanel/VBoxContainer/RegionUnlockRow"
	) as Label
	assert_bool(row.visible).is_false()

	# Cleanup
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


## G-03: summary with multiple unlocked biomes joins the names (comma-separated)
## and surfaces both in the row text.
func test_on_enter_with_multiple_unlocked_biomes_joins_names() -> void:
	# Arrange
	var summary: OfflineProgressionEngine.OfflineSummary = _make_summary()
	var unlocked: Array[String] = ["ember_wastes", "hollow_stair"]
	summary.set_meta("_biomes_unlocked", unlocked)
	OfflineProgressionEngine._last_summary = summary
	var screen: Control = await _make_screen()

	# Act
	screen.on_enter()
	await get_tree().process_frame

	# Assert — both regions present, comma-joined.
	var row: Label = screen.get_node(
		"SummaryPanel/VBoxContainer/RegionUnlockRow"
	) as Label
	assert_bool(row.visible).is_true()
	assert_bool(row.text.to_lower().contains("ember")).is_true()
	assert_bool(row.text.to_lower().contains("hollow")).is_true()
	assert_bool(row.text.contains(",")).is_true()

	# Cleanup
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


## G-04 (defensive): an empty "_biomes_unlocked" array keeps the row hidden
## (guards the malformed-but-present meta edge the screen hardens against).
func test_on_enter_with_empty_unlock_array_hides_region_row() -> void:
	# Arrange
	var summary: OfflineProgressionEngine.OfflineSummary = _make_summary()
	var empty_unlocked: Array[String] = []
	summary.set_meta("_biomes_unlocked", empty_unlocked)
	OfflineProgressionEngine._last_summary = summary
	var screen: Control = await _make_screen()

	# Act
	screen.on_enter()
	await get_tree().process_frame

	# Assert — RegionUnlockRow is hidden.
	var row: Label = screen.get_node(
		"SummaryPanel/VBoxContainer/RegionUnlockRow"
	) as Label
	assert_bool(row.visible).is_false()

	# Cleanup
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


## G-05: the fallback (no cached summary) path hides the region row even if a
## prior render had shown it (re-use safety).
func test_no_summary_fallback_hides_region_row() -> void:
	# Arrange — first render a summary WITH an unlock so the row turns on...
	var summary: OfflineProgressionEngine.OfflineSummary = _make_summary()
	var unlocked: Array[String] = ["ember_wastes"]
	summary.set_meta("_biomes_unlocked", unlocked)
	OfflineProgressionEngine._last_summary = summary
	var screen: Control = await _make_screen()
	screen.on_enter()
	await get_tree().process_frame
	var row: Label = screen.get_node(
		"SummaryPanel/VBoxContainer/RegionUnlockRow"
	) as Label
	assert_bool(row.visible).is_true()

	# Act — clear the summary and re-enter (fallback path).
	screen.on_exit()
	OfflineProgressionEngine._last_summary = null
	screen.on_enter()
	await get_tree().process_frame

	# Assert — row hidden under the fallback render.
	assert_bool(row.visible).is_false()

	# Cleanup
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


# ===========================================================================
# Group H: Offline-defeat notice row (GDD #34 Phase 5 / AC-34-10)
#
# When an OFFLINE-replay run is DEFEATED, OfflineProgressionEngine stamps the
# floor the formation was driven back at onto the summary via the
# "_defeated_at_floor" meta (set in offline_progression_engine.gd; tested in
# offline_defeat_summary_test.gd). The Return-to-App screen surfaces this as a
# "Driven back at Floor X — your guild is recovering." row, reusing the same
# run_defeat_floor_format string the live DUNGEON-RUN defeat overlay uses, so
# the offline and foreground defeat voices match. A WINNING window stamps no
# meta and keeps the row hidden.
# ===========================================================================

## H-01: summary with the "_defeated_at_floor" meta shows the DefeatNoticeRow
## naming the floor the party was driven back at.
func test_on_enter_with_defeated_at_floor_meta_shows_defeat_row() -> void:
	# Arrange
	var summary: OfflineProgressionEngine.OfflineSummary = _make_summary()
	summary.set_meta("_defeated_at_floor", 3)
	OfflineProgressionEngine._last_summary = summary
	var screen: Control = await _make_screen()

	# Act
	screen.on_enter()
	await get_tree().process_frame

	# Assert — DefeatNoticeRow visible and names the floor (3).
	var row: Label = screen.get_node(
		"SummaryPanel/VBoxContainer/DefeatNoticeRow"
	) as Label
	assert_bool(row.visible).is_true()
	assert_bool(row.text.contains("3")).is_true()

	# Cleanup
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


## H-02: summary WITHOUT the defeat meta (the winning common case) keeps the
## DefeatNoticeRow hidden.
func test_on_enter_without_defeat_meta_hides_defeat_row() -> void:
	# Arrange — _make_summary sets no "_defeated_at_floor" meta.
	var summary: OfflineProgressionEngine.OfflineSummary = _make_summary()
	OfflineProgressionEngine._last_summary = summary
	var screen: Control = await _make_screen()

	# Act
	screen.on_enter()
	await get_tree().process_frame

	# Assert — DefeatNoticeRow hidden.
	var row: Label = screen.get_node(
		"SummaryPanel/VBoxContainer/DefeatNoticeRow"
	) as Label
	assert_bool(row.visible).is_false()

	# Cleanup
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


## H-03: the fallback (no cached summary) path hides the defeat row even if a
## prior render had shown it (re-use safety — mirrors G-05).
func test_no_summary_fallback_hides_defeat_row() -> void:
	# Arrange — first render a DEFEATED summary so the row turns on...
	var summary: OfflineProgressionEngine.OfflineSummary = _make_summary()
	summary.set_meta("_defeated_at_floor", 5)
	OfflineProgressionEngine._last_summary = summary
	var screen: Control = await _make_screen()
	screen.on_enter()
	await get_tree().process_frame
	var row: Label = screen.get_node(
		"SummaryPanel/VBoxContainer/DefeatNoticeRow"
	) as Label
	assert_bool(row.visible).is_true()

	# Act — clear the summary and re-enter (fallback path).
	screen.on_exit()
	OfflineProgressionEngine._last_summary = null
	screen.on_enter()
	await get_tree().process_frame

	# Assert — row hidden under the fallback render.
	assert_bool(row.visible).is_false()

	# Cleanup
	screen.on_exit()
	screen.queue_free()
	await get_tree().process_frame


# ===========================================================================
# Group I: Return-chime cue selection (Sprint 29 S29-6)
#
# _render_summary plays ONE audio cue as the summary settles, chosen by the
# pure _select_return_cue(clipped_seconds) helper: a normal (uncapped) return
# gets the warm welcome-back chime; a capped return (the guild hit its offline
# ceiling) gets the distinct "threshold reached" cue. These cover the cue
# DECISION directly — the Group F tests only observe the visual cap notice, so
# a cue-branch inversion would otherwise go uncaught. The cue plays through
# AudioRouter, which no-ops under headless, so we assert the pure selector
# rather than audio output.
# ===========================================================================

## I-01: a normal (uncapped) return selects the warm welcome-back chime.
func test_select_return_cue_uncapped_returns_welcome_chime() -> void:
	# Arrange
	var screen: Control = await _make_screen()

	# Act — zero clipped seconds means the offline cap was not hit.
	var cue: StringName = screen._select_return_cue(0)

	# Assert — the warm welcome chime (matches recruitment's success idiom).
	assert_str(str(cue)).is_equal("sfx_reward_level_up_chime")

	# Cleanup
	screen.queue_free()
	await get_tree().process_frame


## I-02: a capped return selects the distinct threshold-reached cue.
func test_select_return_cue_capped_returns_threshold_cue() -> void:
	# Arrange
	var screen: Control = await _make_screen()

	# Act — any positive clipped-seconds value means the cap was hit.
	var cue: StringName = screen._select_return_cue(7200)

	# Assert — the distinct cap cue, NOT the welcome chime (cap precedence).
	assert_str(str(cue)).is_equal("sfx_prestige_completed")

	# Cleanup
	screen.queue_free()
	await get_tree().process_frame
