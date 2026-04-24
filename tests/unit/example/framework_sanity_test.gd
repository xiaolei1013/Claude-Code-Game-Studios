# Framework sanity check — confirms GdUnit4 is installed, discoverable, and executing.
# Delete this file once the first real unit test for a Lantern Guild system lands
# under tests/unit/[system]/.
extends GdUnitTestSuite


func test_arithmetic_sanity() -> void:
	assert_int(2 + 2).is_equal(4)


func test_string_sanity() -> void:
	assert_str("lantern" + "_" + "guild").is_equal("lantern_guild")


func test_typed_array_sanity() -> void:
	var xs: Array[int] = [1, 2, 3]
	assert_array(xs).has_size(3).contains([2])
