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

# --- Per-cell density + jitter + scale ---

func test_density_and_scale_defaults_are_single_centred_sprite() -> void:
	# Critical default — existing biomes assume one centred sprite
	# per placed cell. Multi-sprite is OPT-IN via density_max > 1.
	var spawn := ScenerySpawn.new()
	assert_eq(spawn.density_min, 1)
	assert_eq(spawn.density_max, 1)
	assert_almost_eq(spawn.jitter_radius, 0.0, 0.0001)
	assert_almost_eq(spawn.scale_min, 1.0, 0.0001)
	assert_almost_eq(spawn.scale_max, 1.0, 0.0001)

func test_sample_density_in_range() -> void:
	var spawn := ScenerySpawn.new()
	spawn.density_min = 2
	spawn.density_max = 5
	for v in range(0, 50):
		var d: int = spawn.sample_density(v)
		assert_true(d >= 2, "density %d should be >= 2" % d)
		assert_true(d <= 5, "density %d should be <= 5" % d)

func test_sample_density_clamps_to_at_least_one() -> void:
	# Designer left both at 0 — but a commit reaching this helper has
	# already decided the cell deserves scenery, so the placer must
	# get at least one sprite. Silent zero is a worse failure mode
	# than "always one centred sprite".
	var spawn := ScenerySpawn.new()
	spawn.density_min = 0
	spawn.density_max = 0
	for v in range(0, 10):
		assert_eq(spawn.sample_density(v), 1)

func test_sample_density_clamps_inverted_range() -> void:
	# Designer mistake (max < min): pin both ends to min so the helper
	# never crashes and never returns a non-positive count.
	var spawn := ScenerySpawn.new()
	spawn.density_min = 5
	spawn.density_max = 2
	for v in range(0, 10):
		assert_eq(spawn.sample_density(v), 5)

func test_sample_scale_endpoints() -> void:
	var spawn := ScenerySpawn.new()
	spawn.scale_min = 0.5
	spawn.scale_max = 2.0
	assert_almost_eq(spawn.sample_scale(0.0), 0.5, 0.0001)
	assert_almost_eq(spawn.sample_scale(1.0), 2.0, 0.0001)
	assert_almost_eq(spawn.sample_scale(0.5), 1.25, 0.0001)

func test_sample_scale_never_returns_non_positive() -> void:
	# Degenerate input (zero or negative scale_min) must still produce
	# a strictly positive multiplier — otherwise pixel_size collapses
	# to 0 and the sprite disappears.
	var spawn := ScenerySpawn.new()
	spawn.scale_min = 0.0
	spawn.scale_max = 0.0
	assert_true(spawn.sample_scale(0.5) > 0.0)

func test_sample_scale_clamps_inverted_range() -> void:
	var spawn := ScenerySpawn.new()
	spawn.scale_min = 2.0
	spawn.scale_max = 0.5
	# max < min should pin both ends to min instead of producing a
	# reversed range.
	assert_almost_eq(spawn.sample_scale(0.0), 2.0, 0.0001)
	assert_almost_eq(spawn.sample_scale(1.0), 2.0, 0.0001)
