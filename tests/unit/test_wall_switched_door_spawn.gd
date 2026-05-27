extends GutTest

func test_defaults_preserve_one_shot_pair() -> void:
	var spawn := WallSwitchedDoorSpawn.new()
	assert_eq(spawn.count_min, 1)
	assert_eq(spawn.count_max, 1)
	assert_eq(spawn.min_wall_distance, 0)
	assert_eq(spawn.max_wall_distance, 0,
		"distance 0 default means the switch lands ON the door panel — simplest puzzle")
	assert_eq(spawn.along_offset_min, 0.0)
	assert_eq(spawn.along_offset_max, 0.0)
	assert_eq(spawn.door_min_distance_to_other_object, 0)
	assert_false(spawn.door_must_gate_content,
		"default false — decorative wall-switched doors are allowed (no required content behind)")

func test_holds_object_data_refs() -> void:
	var switch_data := ObjectData.new()
	switch_data.category = ObjectData.Category.LEVER
	var door_data := ObjectData.new()
	door_data.category = ObjectData.Category.DOOR
	var spawn := WallSwitchedDoorSpawn.new()
	spawn.switch_object = switch_data
	spawn.door_object = door_data
	assert_eq(spawn.switch_object, switch_data)
	assert_eq(spawn.door_object, door_data)

func test_count_range_settable() -> void:
	var spawn := WallSwitchedDoorSpawn.new()
	spawn.count_min = 2
	spawn.count_max = 4
	assert_eq(spawn.count_min, 2)
	assert_eq(spawn.count_max, 4)

func test_distance_range_settable() -> void:
	var spawn := WallSwitchedDoorSpawn.new()
	spawn.min_wall_distance = 1
	spawn.max_wall_distance = 3
	assert_eq(spawn.min_wall_distance, 1)
	assert_eq(spawn.max_wall_distance, 3)

func test_along_offset_range_settable() -> void:
	var spawn := WallSwitchedDoorSpawn.new()
	spawn.along_offset_min = 0.5
	spawn.along_offset_max = 1.5
	assert_eq(spawn.along_offset_min, 0.5)
	assert_eq(spawn.along_offset_max, 1.5)
