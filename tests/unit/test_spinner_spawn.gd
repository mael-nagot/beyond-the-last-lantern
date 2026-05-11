extends GutTest

func test_defaults() -> void:
	var spawn := SpinnerSpawn.new()
	assert_null(spawn.spinner)
	assert_eq(spawn.count_min, 1)
	assert_eq(spawn.count_max, 3)
	assert_eq(spawn.placement, ObjectSpawn.PLACEMENT_ANY)
	assert_eq(spawn.min_distance_to_other_spinner, 0)

func test_default_placement_allows_all_three_classifications() -> void:
	var spawn := SpinnerSpawn.new()
	assert_true(spawn.allows(ObjectSpawn.PLACEMENT_CORRIDOR))
	assert_true(spawn.allows(ObjectSpawn.PLACEMENT_ROOM))
	assert_true(spawn.allows(ObjectSpawn.PLACEMENT_DEAD_END))

func test_corridor_only_placement_rejects_room_and_dead_end() -> void:
	var spawn := SpinnerSpawn.new()
	spawn.placement = ObjectSpawn.PLACEMENT_CORRIDOR
	assert_true(spawn.allows(ObjectSpawn.PLACEMENT_CORRIDOR))
	assert_false(spawn.allows(ObjectSpawn.PLACEMENT_ROOM))
	assert_false(spawn.allows(ObjectSpawn.PLACEMENT_DEAD_END))

func test_zero_placement_rejects_everything() -> void:
	var spawn := SpinnerSpawn.new()
	spawn.placement = 0
	assert_false(spawn.allows(ObjectSpawn.PLACEMENT_CORRIDOR))
	assert_false(spawn.allows(ObjectSpawn.PLACEMENT_ROOM))
	assert_false(spawn.allows(ObjectSpawn.PLACEMENT_DEAD_END))

# --- Corridor cluster fields ---

func test_corridor_cluster_defaults() -> void:
	var spawn := SpinnerSpawn.new()
	assert_eq(spawn.corridor_segment_chance, 0.0)
	assert_eq(spawn.corridor_spinners_per_run_min, 1)
	assert_eq(spawn.corridor_spinners_per_run_max, 3)

func test_uses_corridor_clusters_false_by_default() -> void:
	var spawn := SpinnerSpawn.new()
	assert_false(spawn.uses_corridor_clusters())

func test_uses_corridor_clusters_when_chance_set() -> void:
	var spawn := SpinnerSpawn.new()
	spawn.corridor_segment_chance = 0.5
	assert_true(spawn.uses_corridor_clusters())

func test_uses_corridor_clusters_false_when_max_zero() -> void:
	var spawn := SpinnerSpawn.new()
	spawn.corridor_segment_chance = 1.0
	spawn.corridor_spinners_per_run_max = 0
	assert_false(spawn.uses_corridor_clusters())

# --- Room density fields ---

func test_room_density_defaults() -> void:
	var spawn := SpinnerSpawn.new()
	assert_eq(spawn.room_chance, 0.0)
	assert_eq(spawn.room_coverage_min_percent, 10.0)
	assert_eq(spawn.room_coverage_max_percent, 30.0)
	assert_eq(spawn.room_min_spacing, 0)
	assert_true(spawn.allow_mixed_room_spinners)

func test_uses_room_density_false_by_default() -> void:
	var spawn := SpinnerSpawn.new()
	assert_false(spawn.uses_room_density())

func test_uses_room_density_when_chance_set() -> void:
	var spawn := SpinnerSpawn.new()
	spawn.room_chance = 0.5
	assert_true(spawn.uses_room_density())

func test_uses_room_density_false_when_max_coverage_zero() -> void:
	var spawn := SpinnerSpawn.new()
	spawn.room_chance = 1.0
	spawn.room_coverage_max_percent = 0.0
	assert_false(spawn.uses_room_density())
