extends GutTest

func test_defaults() -> void:
	var spawn := TeleporterSpawn.new()
	assert_null(spawn.data)
	assert_eq(spawn.count_min, 1)
	assert_eq(spawn.count_max, 1)
	assert_eq(spawn.min_distance_between_partners, 6)
	assert_eq(spawn.min_distance_to_other_object, 2)
	assert_eq(spawn.min_distance_to_other_teleporter, 4)

func test_zero_count_max_disables_generation() -> void:
	# Documents the "disable teleporters for this biome" idiom — set
	# count_max = 0 and the placer rolls 0 pairs every level. The
	# placer itself enforces this; the spawn just stores the config.
	var spawn := TeleporterSpawn.new()
	spawn.count_min = 0
	spawn.count_max = 0
	assert_eq(spawn.count_max, 0)
