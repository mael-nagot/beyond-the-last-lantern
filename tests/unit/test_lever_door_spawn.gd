extends GutTest

func test_defaults_preserve_backward_compat() -> void:
	var spawn := LeverDoorSpawn.new()
	assert_eq(spawn.count_min, 1)
	assert_eq(spawn.count_max, 1)
	assert_eq(spawn.levers_per_cluster, 1)
	assert_eq(spawn.doors_per_cluster, 1)
	assert_eq(spawn.lever_logic, 0, "0 = AND")
	assert_eq(spawn.lever_placement, ObjectSpawn.PLACEMENT_DEFAULT)
	assert_eq(spawn.lever_min_distance_to_other_object, 0)
	assert_eq(spawn.door_min_distance_to_other_object, 0)
	assert_eq(spawn.lever_to_door_min_distance, 0)
	assert_eq(spawn.lever_to_door_max_distance, -1, "default should be unlimited (-1)")
	assert_false(spawn.door_must_gate_content)

func test_cluster_shape_fields_are_settable() -> void:
	var spawn := LeverDoorSpawn.new()
	spawn.levers_per_cluster = 3
	spawn.doors_per_cluster = 2
	spawn.lever_logic = 1
	assert_eq(spawn.levers_per_cluster, 3)
	assert_eq(spawn.doors_per_cluster, 2)
	assert_eq(spawn.lever_logic, 1, "1 = OR")

func test_holds_object_data_refs() -> void:
	var lever_data := ObjectData.new()
	lever_data.category = ObjectData.Category.LEVER
	var door_data := ObjectData.new()
	door_data.category = ObjectData.Category.DOOR
	var spawn := LeverDoorSpawn.new()
	spawn.lever_object = lever_data
	spawn.door_object = door_data
	assert_eq(spawn.lever_object, lever_data)
	assert_eq(spawn.door_object, door_data)
