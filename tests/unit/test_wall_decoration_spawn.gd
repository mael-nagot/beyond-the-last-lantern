extends GutTest

func test_defaults() -> void:
	var spawn := WallDecorationSpawn.new()
	assert_null(spawn.decoration)
	assert_eq(spawn.count_min, 0)
	assert_eq(spawn.count_max, 0)
	assert_eq(spawn.placement, ObjectSpawn.PLACEMENT_ANY)
	assert_eq(spawn.min_distance_to_other_decoration, 0)

func test_allows_corridor_when_corridor_flag_set() -> void:
	var spawn := WallDecorationSpawn.new()
	spawn.placement = ObjectSpawn.PLACEMENT_CORRIDOR
	assert_true(spawn.allows(ObjectSpawn.PLACEMENT_CORRIDOR))
	assert_false(spawn.allows(ObjectSpawn.PLACEMENT_ROOM))
	assert_false(spawn.allows(ObjectSpawn.PLACEMENT_DEAD_END))

func test_allows_combined_flags() -> void:
	var spawn := WallDecorationSpawn.new()
	spawn.placement = ObjectSpawn.PLACEMENT_ROOM | ObjectSpawn.PLACEMENT_DEAD_END
	assert_false(spawn.allows(ObjectSpawn.PLACEMENT_CORRIDOR))
	assert_true(spawn.allows(ObjectSpawn.PLACEMENT_ROOM))
	assert_true(spawn.allows(ObjectSpawn.PLACEMENT_DEAD_END))
