extends GutTest

func test_defaults() -> void:
	var spawn := KeyDoorSpawn.new()
	assert_eq(spawn.count_min, 1)
	assert_eq(spawn.count_max, 1)
	assert_eq(spawn.lock_id_prefix, "")
	assert_true(spawn.door_must_gate_content,
		"door_must_gate_content defaults true — a lock that gates nothing is pointless")
	assert_eq(spawn.key_spawn_locations, KeyDoorSpawn.KEY_LOCATION_DEFAULT)
	assert_eq(spawn.key_spawn_locations, KeyDoorSpawn.KEY_LOCATION_FLOOR,
		"default location must be FLOOR")
	assert_eq(spawn.key_floor_placement, ObjectSpawn.PLACEMENT_DEFAULT)
	assert_eq(spawn.key_min_distance_to_other_object, 0)
	assert_eq(spawn.door_min_distance_to_other_object, 0)
	assert_eq(spawn.key_to_door_min_distance, 0)
	assert_eq(spawn.key_to_door_max_distance, -1)
	assert_eq(spawn.floor_weight, 1, "default location weight is even (1 each)")
	assert_eq(spawn.chest_weight, 1)
	assert_eq(spawn.enemy_drop_weight, 1)
	assert_false(spawn.allow_multiple_keys_per_chest,
		"defaults to false — a chest hosts at most one key")

func test_allows_location_for_single_flag() -> void:
	var spawn := KeyDoorSpawn.new()
	spawn.key_spawn_locations = KeyDoorSpawn.KEY_LOCATION_FLOOR
	assert_true(spawn.allows_location(KeyDoorSpawn.KEY_LOCATION_FLOOR))
	assert_false(spawn.allows_location(KeyDoorSpawn.KEY_LOCATION_CHEST))
	assert_false(spawn.allows_location(KeyDoorSpawn.KEY_LOCATION_ENEMY_DROP))

func test_allows_location_for_combined_flags() -> void:
	var spawn := KeyDoorSpawn.new()
	spawn.key_spawn_locations = (
		KeyDoorSpawn.KEY_LOCATION_FLOOR |
		KeyDoorSpawn.KEY_LOCATION_CHEST
	)
	assert_true(spawn.allows_location(KeyDoorSpawn.KEY_LOCATION_FLOOR))
	assert_true(spawn.allows_location(KeyDoorSpawn.KEY_LOCATION_CHEST))
	assert_false(spawn.allows_location(KeyDoorSpawn.KEY_LOCATION_ENEMY_DROP))

func test_holds_object_data_refs() -> void:
	var key_data := ItemData.new()
	key_data.category = ItemData.Category.KEY
	var door_data := ObjectData.new()
	door_data.category = ObjectData.Category.DOOR
	var spawn := KeyDoorSpawn.new()
	spawn.key_item = key_data
	spawn.door_object = door_data
	assert_eq(spawn.key_item, key_data)
	assert_eq(spawn.door_object, door_data)
