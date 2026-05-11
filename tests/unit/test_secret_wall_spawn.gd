extends GutTest

func test_defaults() -> void:
	var spawn := SecretWallSpawn.new()
	assert_eq(spawn.count_min, 1)
	assert_eq(spawn.count_max, 1)
	assert_eq(spawn.gate_mode, SecretWallSpawn.GateMode.ANY_CONTENT)
	assert_eq(spawn.min_distance_to_other_object, 0)

func test_gate_mode_enum_values_are_distinct() -> void:
	# The placement logic dispatches on the integer values, so the
	# three modes must be distinct constants.
	assert_ne(SecretWallSpawn.GateMode.NONE, SecretWallSpawn.GateMode.ANY_CONTENT)
	assert_ne(SecretWallSpawn.GateMode.NONE, SecretWallSpawn.GateMode.LOOT_ONLY)
	assert_ne(SecretWallSpawn.GateMode.ANY_CONTENT, SecretWallSpawn.GateMode.LOOT_ONLY)
