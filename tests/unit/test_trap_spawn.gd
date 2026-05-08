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

# --- Corridor cluster fields (Subtask B) ---

func test_corridor_cluster_defaults() -> void:
	# Defaults must keep Subtask A's scattered-only behaviour intact —
	# corridor clusters opt-in only.
	var spawn := TrapSpawn.new()
	assert_eq(spawn.corridor_segment_chance, 0.0)
	assert_eq(spawn.corridor_traps_per_run_min, 1)
	assert_eq(spawn.corridor_traps_per_run_max, 3)

func test_uses_corridor_clusters_false_by_default() -> void:
	var spawn := TrapSpawn.new()
	assert_false(spawn.uses_corridor_clusters())

func test_uses_corridor_clusters_when_chance_set() -> void:
	var spawn := TrapSpawn.new()
	spawn.corridor_segment_chance = 0.5
	assert_true(spawn.uses_corridor_clusters())

func test_uses_corridor_clusters_false_when_max_zero() -> void:
	# A designer setting max=0 explicitly disables clusters even if
	# chance is non-zero — guards against silent zero-length runs.
	var spawn := TrapSpawn.new()
	spawn.corridor_segment_chance = 1.0
	spawn.corridor_traps_per_run_max = 0
	assert_false(spawn.uses_corridor_clusters())
