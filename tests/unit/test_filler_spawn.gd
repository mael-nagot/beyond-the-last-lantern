extends GutTest

func test_defaults() -> void:
	var spawn := FillerSpawn.new()
	assert_eq(spawn.fillers.size(), 0)
	assert_eq(spawn.density_min, 2)
	assert_eq(spawn.density_max, 4)
	assert_almost_eq(spawn.jitter_radius, 0.4, 0.0001)
	assert_almost_eq(spawn.front_row_bias, 0.7, 0.0001)
	assert_eq(spawn.border_ring_depth, 4)
	assert_almost_eq(spawn.scale_min, 0.85, 0.0001)
	assert_almost_eq(spawn.scale_max, 1.15, 0.0001)

func test_sample_density_returns_value_in_range() -> void:
	var spawn := FillerSpawn.new()
	spawn.density_min = 2
	spawn.density_max = 5
	for v in range(0, 50):
		var d: int = spawn.sample_density(v)
		assert_true(d >= 2, "density %d should be >= 2" % d)
		assert_true(d <= 5, "density %d should be <= 5" % d)

func test_sample_density_handles_fixed_value() -> void:
	var spawn := FillerSpawn.new()
	spawn.density_min = 3
	spawn.density_max = 3
	for v in range(0, 10):
		assert_eq(spawn.sample_density(v), 3)

func test_sample_density_clamps_negative_min() -> void:
	var spawn := FillerSpawn.new()
	spawn.density_min = -2
	spawn.density_max = 1
	for v in range(0, 10):
		var d: int = spawn.sample_density(v)
		assert_true(d >= 0, "density should never be negative")
		assert_true(d <= 1)

func test_sample_density_clamps_inverted_range() -> void:
	# max < min is a designer mistake; ensure the function doesn't
	# crash and returns the min value instead of a wrong-direction range.
	var spawn := FillerSpawn.new()
	spawn.density_min = 5
	spawn.density_max = 1
	for v in range(0, 10):
		assert_eq(spawn.sample_density(v), 5)

func test_sample_scale_stays_in_range() -> void:
	var spawn := FillerSpawn.new()
	spawn.scale_min = 0.8
	spawn.scale_max = 1.4
	for i in range(0, 50):
		var t: float = float(i) / 49.0
		var s: float = spawn.sample_scale(t)
		assert_true(s >= 0.8 - 0.0001, "scale %f should be >= 0.8" % s)
		assert_true(s <= 1.4 + 0.0001, "scale %f should be <= 1.4" % s)

func test_sample_scale_endpoints() -> void:
	var spawn := FillerSpawn.new()
	spawn.scale_min = 0.5
	spawn.scale_max = 2.0
	assert_almost_eq(spawn.sample_scale(0.0), 0.5, 0.0001)
	assert_almost_eq(spawn.sample_scale(1.0), 2.0, 0.0001)
	assert_almost_eq(spawn.sample_scale(0.5), 1.25, 0.0001)

func test_sample_scale_clamps_inverted_range() -> void:
	var spawn := FillerSpawn.new()
	spawn.scale_min = 2.0
	spawn.scale_max = 0.5
	# When max < min the function pins both ends to min so the placer
	# always returns a positive multiplier.
	assert_almost_eq(spawn.sample_scale(0.0), 2.0, 0.0001)
	assert_almost_eq(spawn.sample_scale(1.0), 2.0, 0.0001)

func test_sample_scale_never_returns_non_positive() -> void:
	# Degenerate input (zero or negative scale_min) should still produce
	# a strictly positive multiplier — otherwise the renderer would
	# compute pixel_size = 0 and collapse the sprite to nothing.
	var spawn := FillerSpawn.new()
	spawn.scale_min = 0.0
	spawn.scale_max = 0.0
	assert_true(spawn.sample_scale(0.5) > 0.0)

func test_pick_filler_returns_null_when_pool_empty() -> void:
	var spawn := FillerSpawn.new()
	assert_null(spawn.pick_filler(0))
	assert_null(spawn.pick_filler(7))

func test_pick_filler_returns_pool_entry() -> void:
	var spawn := FillerSpawn.new()
	var a := FillerData.new()
	var b := FillerData.new()
	spawn.fillers = [a, b]
	# Indices wrap modulo size, so every input maps to a valid entry.
	assert_same(spawn.pick_filler(0), a)
	assert_same(spawn.pick_filler(1), b)
	assert_same(spawn.pick_filler(2), a)
	assert_same(spawn.pick_filler(3), b)
