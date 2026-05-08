extends GutTest

func test_defaults() -> void:
	var spawn := TrapSpawn.new()
	assert_null(spawn.trap)
	assert_eq(spawn.count_min, 1)
	assert_eq(spawn.count_max, 3)
	assert_eq(spawn.placement, ObjectSpawn.PLACEMENT_ANY)
	assert_eq(spawn.min_distance_to_other_trap, 0)

func test_default_placement_allows_all_three_classifications() -> void:
	var spawn := TrapSpawn.new()
	assert_true(spawn.allows(ObjectSpawn.PLACEMENT_CORRIDOR))
	assert_true(spawn.allows(ObjectSpawn.PLACEMENT_ROOM))
	assert_true(spawn.allows(ObjectSpawn.PLACEMENT_DEAD_END))

func test_corridor_only_placement_rejects_room_and_dead_end() -> void:
	var spawn := TrapSpawn.new()
	spawn.placement = ObjectSpawn.PLACEMENT_CORRIDOR
	assert_true(spawn.allows(ObjectSpawn.PLACEMENT_CORRIDOR))
	assert_false(spawn.allows(ObjectSpawn.PLACEMENT_ROOM))
	assert_false(spawn.allows(ObjectSpawn.PLACEMENT_DEAD_END))

func test_zero_placement_rejects_everything() -> void:
	var spawn := TrapSpawn.new()
	spawn.placement = 0
	assert_false(spawn.allows(ObjectSpawn.PLACEMENT_CORRIDOR))
	assert_false(spawn.allows(ObjectSpawn.PLACEMENT_ROOM))
	assert_false(spawn.allows(ObjectSpawn.PLACEMENT_DEAD_END))
