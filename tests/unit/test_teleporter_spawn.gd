extends GutTest

func test_defaults() -> void:
	var spawn := TeleporterSpawn.new()
	assert_null(spawn.data)
	assert_eq(spawn.count_min, 1)
	assert_eq(spawn.count_max, 1)
	assert_eq(spawn.min_distance_between_partners, 6)
	assert_eq(spawn.min_distance_to_other_object, 2)
	assert_eq(spawn.min_distance_to_other_teleporter, 4)
	# Phase C fields default to NO partition so legacy biomes that
	# only configure count_min/count_max keep Phase A behaviour.
	assert_eq(spawn.island_count_min, 1)
	assert_eq(spawn.island_count_max, 1)
	assert_eq(spawn.min_seal_distance_to_entrance_exit, 4)
	assert_eq(spawn.min_seal_distance_between_seals, 5)
	# Minimum island size — defaults to 8 cells so a partition that
	# strands a 1-3 cell stub gets rejected by the seal picker.
	assert_eq(spawn.min_island_size, 8)

func test_zero_count_max_disables_generation() -> void:
	# Documents the "disable teleporters for this biome" idiom — set
	# count_max = 0 and the placer rolls 0 pairs every level. The
	# placer itself enforces this; the spawn just stores the config.
	var spawn := TeleporterSpawn.new()
	spawn.count_min = 0
	spawn.count_max = 0
	assert_eq(spawn.count_max, 0)

func test_uses_partition_false_by_default() -> void:
	# Backwards compat: a spawn that only sets count_min/count_max
	# (Phase A shape) MUST NOT trigger the partition pass.
	var spawn := TeleporterSpawn.new()
	assert_false(spawn.uses_partition())

func test_uses_partition_true_when_island_count_max_is_two() -> void:
	var spawn := TeleporterSpawn.new()
	spawn.island_count_min = 2
	spawn.island_count_max = 2
	assert_true(spawn.uses_partition())

func test_uses_partition_true_when_island_count_max_is_three() -> void:
	# K=3 is also partition mode — 2 seals, 2 pairs as a spanning tree.
	var spawn := TeleporterSpawn.new()
	spawn.island_count_min = 2
	spawn.island_count_max = 3
	assert_true(spawn.uses_partition())

func test_uses_partition_false_when_island_count_max_is_one() -> void:
	# Explicit guard for the boundary: island_count_max = 1 means
	# "exactly one island" which is the whole-map, no-partition state.
	var spawn := TeleporterSpawn.new()
	spawn.island_count_min = 1
	spawn.island_count_max = 1
	assert_false(spawn.uses_partition())
