extends GutTest

func test_default_field_values() -> void:
	var spawn := ProjectileTrapSpawn.new()
	assert_null(spawn.trap)
	assert_eq(spawn.corridor_segment_chance, 0.0)
	assert_eq(spawn.max_escape_distance, 5)
	assert_eq(spawn.max_per_corridor_segment, 1)
	assert_eq(spawn.room_chance, 0.0)
	assert_eq(spawn.max_per_room, 2)
	assert_eq(spawn.max_plate_to_junction_distance, 2)
	assert_eq(spawn.min_plate_to_launcher_distance, 3)
	assert_eq(spawn.min_distance_to_other_projectile_trap, 3)

func test_uses_corridor_placement_when_chance_positive() -> void:
	var spawn := ProjectileTrapSpawn.new()
	spawn.corridor_segment_chance = 0.5
	assert_true(spawn.uses_corridor_placement())

func test_uses_corridor_placement_false_when_chance_zero() -> void:
	var spawn := ProjectileTrapSpawn.new()
	spawn.corridor_segment_chance = 0.0
	assert_false(spawn.uses_corridor_placement())

func test_uses_room_placement_when_chance_positive() -> void:
	var spawn := ProjectileTrapSpawn.new()
	spawn.room_chance = 0.3
	assert_true(spawn.uses_room_placement())

func test_uses_room_placement_false_when_chance_zero() -> void:
	var spawn := ProjectileTrapSpawn.new()
	spawn.room_chance = 0.0
	assert_false(spawn.uses_room_placement())
