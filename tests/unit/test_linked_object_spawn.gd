extends GutTest

func test_defaults_to_one_pair_with_default_lever_placement() -> void:
	var spawn := LinkedObjectSpawn.new()
	assert_eq(spawn.count_min, 1)
	assert_eq(spawn.count_max, 1)
	assert_eq(spawn.lever_placement, ObjectSpawn.PLACEMENT_DEFAULT)
	assert_eq(spawn.lever_min_distance_to_other_object, 0)
	assert_eq(spawn.door_min_distance_to_other_object, 0)
	assert_false(spawn.door_must_gate_content)

func test_holds_object_data_refs() -> void:
	var lever_data := ObjectData.new()
	lever_data.category = ObjectData.Category.LEVER
	var door_data := ObjectData.new()
	door_data.category = ObjectData.Category.DOOR
	var spawn := LinkedObjectSpawn.new()
	spawn.lever_object = lever_data
	spawn.door_object = door_data
	assert_eq(spawn.lever_object, lever_data)
	assert_eq(spawn.door_object, door_data)
