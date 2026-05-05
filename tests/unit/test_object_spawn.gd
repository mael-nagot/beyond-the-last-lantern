extends GutTest

func test_defaults() -> void:
	var spawn := ObjectSpawn.new()
	assert_null(spawn.object)
	assert_eq(spawn.count_min, 1)
	assert_eq(spawn.count_max, 1)
	assert_eq(spawn.placement, ObjectSpawn.PLACEMENT_DEFAULT)
	assert_null(spawn.loot_table)

func test_default_placement_is_room_or_dead_end_not_corridor() -> void:
	var spawn := ObjectSpawn.new()
	assert_true(spawn.allows(ObjectSpawn.PLACEMENT_ROOM))
	assert_true(spawn.allows(ObjectSpawn.PLACEMENT_DEAD_END))
	assert_false(spawn.allows(ObjectSpawn.PLACEMENT_CORRIDOR))

func test_placement_any_includes_corridor() -> void:
	var spawn := ObjectSpawn.new()
	spawn.placement = ObjectSpawn.PLACEMENT_ANY
	assert_true(spawn.allows(ObjectSpawn.PLACEMENT_CORRIDOR))
	assert_true(spawn.allows(ObjectSpawn.PLACEMENT_ROOM))
	assert_true(spawn.allows(ObjectSpawn.PLACEMENT_DEAD_END))

func test_allows_zero_placement_rejects_everything() -> void:
	var spawn := ObjectSpawn.new()
	spawn.placement = 0
	assert_false(spawn.allows(ObjectSpawn.PLACEMENT_CORRIDOR))
	assert_false(spawn.allows(ObjectSpawn.PLACEMENT_ROOM))
	assert_false(spawn.allows(ObjectSpawn.PLACEMENT_DEAD_END))
