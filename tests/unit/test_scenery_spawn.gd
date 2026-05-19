extends GutTest

func test_defaults_are_a_no_op() -> void:
	# Critical: a freshly-instanced ScenerySpawn (no fields touched)
	# must not place anything. Designers add an empty entry, fill in
	# fields gradually, and shouldn't be surprised by trees appearing
	# before they configure a chance.
	var spawn := ScenerySpawn.new()
	assert_null(spawn.scenery)
	assert_almost_eq(spawn.dead_end_chance, 0.0, 0.0001)
	assert_almost_eq(spawn.corridor_segment_chance, 0.0, 0.0001)
	assert_almost_eq(spawn.room_chance, 0.0, 0.0001)
	assert_false(spawn.uses_dead_ends())
	assert_false(spawn.uses_corridors())
	assert_false(spawn.uses_rooms())

func test_coverage_defaults() -> void:
	var spawn := ScenerySpawn.new()
	assert_almost_eq(spawn.corridor_coverage_min_percent, 10.0, 0.0001)
	assert_almost_eq(spawn.corridor_coverage_max_percent, 30.0, 0.0001)
	assert_almost_eq(spawn.room_coverage_min_percent, 10.0, 0.0001)
	assert_almost_eq(spawn.room_coverage_max_percent, 30.0, 0.0001)

func test_min_distance_to_same_default_zero() -> void:
	var spawn := ScenerySpawn.new()
	assert_eq(spawn.min_distance_to_same, 0)

# --- uses_* helpers ---

func test_uses_dead_ends_when_chance_set() -> void:
	var spawn := ScenerySpawn.new()
	spawn.dead_end_chance = 0.5
	assert_true(spawn.uses_dead_ends())

func test_uses_corridors_when_chance_set() -> void:
	var spawn := ScenerySpawn.new()
	spawn.corridor_segment_chance = 0.5
	assert_true(spawn.uses_corridors())

func test_uses_corridors_false_when_max_coverage_zero() -> void:
	# Edge case — designer set the chance but zeroed both coverage
	# knobs. The pass should be skipped entirely rather than rolling
	# a chance just to place zero sprites.
	var spawn := ScenerySpawn.new()
	spawn.corridor_segment_chance = 1.0
	spawn.corridor_coverage_min_percent = 0.0
	spawn.corridor_coverage_max_percent = 0.0
	assert_false(spawn.uses_corridors())

func test_uses_rooms_when_chance_set() -> void:
	var spawn := ScenerySpawn.new()
	spawn.room_chance = 0.5
	assert_true(spawn.uses_rooms())

func test_uses_rooms_false_when_max_coverage_zero() -> void:
	var spawn := ScenerySpawn.new()
	spawn.room_chance = 1.0
	spawn.room_coverage_min_percent = 0.0
	spawn.room_coverage_max_percent = 0.0
	assert_false(spawn.uses_rooms())
