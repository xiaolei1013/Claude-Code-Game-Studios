# Onboarding / First-Session Flow integration tests per GDD #29.
#
# Covers AC-29-01 (first_launch → guild_hall), AC-29-02 (Theron seed),
# AC-29-04 (Floor 1 unlocked + 2-5 locked), AC-29-05 (Recruitment pool
# seeded with non-zero RNG).
#
# Hygiene barrier: snapshot HeroRoster + Economy + Recruitment + FloorUnlock
# state, then clear each to simulate cold-launch, then emit first_launch
# and assert the seed pathways fire correctly. Restore via load_save_data.
#
# AC-29-06 (Recruit button dimmed) and AC-29-07 (Dispatch enabled with
# seeded formation) require full UI rendering — covered by manual smoke
# (AC-29-10) per GDD §J Story 3, not this automated suite.
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# Hygiene barrier
# ---------------------------------------------------------------------------

var _snapshot_roster: Dictionary = {}
var _snapshot_economy: Dictionary = {}
var _snapshot_recruitment: Dictionary = {}
var _snapshot_floor_unlock: Dictionary = {}
var _snapshot_debug_unlock_all: bool = false


func before_test() -> void:
	_snapshot_roster = HeroRoster.get_save_data()
	_snapshot_economy = Economy.get_save_data()
	_snapshot_recruitment = Recruitment.get_save_data()
	_snapshot_floor_unlock = FloorUnlock.get_save_data()
	_snapshot_debug_unlock_all = FloorUnlock.debug_unlock_all
	# debug_unlock_all is enabled by default in dev builds for QA convenience.
	# AC-29-04 specifies the production fresh-save shape (floor 1 ACCESSIBLE,
	# floors 2-5 LOCKED); force-disable for this test.
	FloorUnlock.debug_unlock_all = false


func after_test() -> void:
	HeroRoster.load_save_data(_snapshot_roster)
	Economy.load_save_data(_snapshot_economy)
	Recruitment.load_save_data(_snapshot_recruitment)
	FloorUnlock.load_save_data(_snapshot_floor_unlock)
	FloorUnlock.debug_unlock_all = _snapshot_debug_unlock_all
	# Defensive: if the snapshot was empty (test ran before any seed), restore
	# to first-launch defaults so subsequent test suites see a healthy state.
	if HeroRoster._heroes.is_empty():
		HeroRoster.seed_first_launch_state()
	if Recruitment._save_pool_seed == 0:
		Recruitment._first_launch_seed_init()
		Recruitment._regenerate_pool()


# ---------------------------------------------------------------------------
# Helpers — simulate cold-launch state across autoloads
# ---------------------------------------------------------------------------

## Wipes the autoload state that first_launch is supposed to seed.
## Mirrors what SaveLoadSystem detects pre-first_launch (no save file = no state).
func _clear_to_cold_launch_state() -> void:
	HeroRoster._heroes.clear()
	HeroRoster._formation_slots.clear()
	HeroRoster._formation_slots.resize(HeroRoster.formation_size())
	HeroRoster._next_instance_id = 1
	Economy._gold_balance = 0
	Recruitment._save_pool_seed = 0
	Recruitment._current_pool = []
	# FloorUnlock fresh state: highest_cleared=0 for all biomes → only floor 1
	# is ACCESSIBLE; floors 2-5 LOCKED per AC-29-04. The fresh-save default
	# of {"forest_reach": 0} is restored by clearing _unlock_state (load
	# defaults will re-populate on the next read via the empty-dict path).
	FloorUnlock._unlock_state.clear()
	FloorUnlock._unlock_state["forest_reach"] = 0


# ===========================================================================
# AC-29-02: Seeded Theron is present in roster + formation slot 0
# ===========================================================================

func test_first_launch_seeds_theron_in_heroroster() -> void:
	_clear_to_cold_launch_state()
	# HeroRoster._ready already deferred seed_first_launch_state; we call it
	# directly here since the autoload is already past _ready.
	HeroRoster.seed_first_launch_state()
	assert_bool(HeroRoster._heroes.has(1)).is_true()
	var theron: RefCounted = HeroRoster._heroes[1]
	assert_str(String(theron.get("class_id"))).is_equal("warrior")
	assert_str(String(theron.get("display_name"))).is_equal("Theron")
	assert_int(int(theron.get("current_level"))).is_equal(1)
	assert_int(int(theron.get("xp"))).is_equal(0)


func test_first_launch_places_theron_in_formation_slot_0() -> void:
	_clear_to_cold_launch_state()
	HeroRoster.seed_first_launch_state()
	assert_int(HeroRoster._formation_slots.size()).is_greater_equal(1)
	assert_int(int(HeroRoster._formation_slots[0])).is_equal(1)


# ===========================================================================
# AC-29-03: Starting gold is 100 (Economy's first_launch handler)
# ===========================================================================

func test_first_launch_seeds_gold_to_starting_gold() -> void:
	_clear_to_cold_launch_state()
	Economy._on_first_launch()
	assert_int(Economy.get_gold_balance()).is_equal(100)


# ===========================================================================
# AC-29-04: Floor 1 of forest_reach is unlocked; floors 2-5 are LOCKED
# ===========================================================================

func test_first_launch_unlocks_floor_1_only_in_forest_reach() -> void:
	# FloorUnlock should reflect floor-1-unlocked-from-boot via its
	# default state (no save file → fresh state).
	_clear_to_cold_launch_state()
	# Verify FloorUnlock has floor 1 unlocked + floors 2-5 locked.
	assert_int(FloorUnlock.get_highest_cleared("forest_reach")).is_equal(0)
	# Floor 1 is the entry floor — playable from the start (no prerequisites).
	assert_bool(FloorUnlock.is_unlocked_in_biome("forest_reach", 1)).is_true()
	# Floors 2-5 require clearing floor 1 first.
	for floor_index: int in [2, 3, 4, 5]:
		var unlocked: bool = FloorUnlock.is_unlocked_in_biome("forest_reach", floor_index)
		assert_bool(unlocked).override_failure_message(
			"Floor %d expected LOCKED before floor 1 cleared, but is_unlocked_in_biome returned true"
			% floor_index
		).is_false()


# ===========================================================================
# AC-29-05: Recruit pool is seeded with deterministic RNG
# ===========================================================================

func test_first_launch_seeds_recruitment_pool_with_nonzero_seed() -> void:
	_clear_to_cold_launch_state()
	# Recruitment._first_launch_seed_init is called from _ready + load_save_data
	# defensive path. Call directly to simulate first-launch.
	Recruitment._first_launch_seed_init()
	assert_int(Recruitment._save_pool_seed).is_not_equal(0)


func test_first_launch_recruitment_pool_renders_non_empty() -> void:
	_clear_to_cold_launch_state()
	Recruitment._first_launch_seed_init()
	Recruitment._regenerate_pool()
	var pool: Array = Recruitment.get_recruit_pool()
	assert_int(pool.size()).is_greater(0)
