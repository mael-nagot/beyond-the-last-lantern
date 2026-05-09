extends GutTest

# Phase 8 Task 3 — Subtask C1.

func test_defaults() -> void:
	var spawn := ProjectileTrapSpawn.new()
	assert_null(spawn.trap)
	assert_eq(spawn.placement, ObjectSpawn.PLACEMENT_ANY)
	assert_eq(spawn.corridor_chance, 0.0)
	assert_eq(spawn.corridor_max_per_segment, 1)
	assert_eq(spawn.room_chance, 0.0)
	assert_eq(spawn.room_max_per_room, 1)

func test_default_placement_allows_all_three_classifications() -> void:
	var spawn := ProjectileTrapSpawn.new()
	assert_true(spawn.allows(ObjectSpawn.PLACEMENT_CORRIDOR))
	assert_true(spawn.allows(ObjectSpawn.PLACEMENT_ROOM))
	assert_true(spawn.allows(ObjectSpawn.PLACEMENT_DEAD_END))

func test_corridor_only_placement_rejects_room() -> void:
	var spawn := ProjectileTrapSpawn.new()
	spawn.placement = ObjectSpawn.PLACEMENT_CORRIDOR
	assert_true(spawn.allows(ObjectSpawn.PLACEMENT_CORRIDOR))
	assert_false(spawn.allows(ObjectSpawn.PLACEMENT_ROOM))

func test_uses_corridor_false_by_default() -> void:
	# Defaults must keep biomes silent — projectile traps are opt-in.
	var spawn := ProjectileTrapSpawn.new()
	assert_false(spawn.uses_corridor())

func test_uses_corridor_when_chance_set() -> void:
	var spawn := ProjectileTrapSpawn.new()
	spawn.corridor_chance = 0.5
	assert_true(spawn.uses_corridor())

func test_uses_corridor_false_when_max_zero() -> void:
	# Designer setting max=0 explicitly disables corridor placement
	# even with non-zero chance — guards against rolling segments
	# that produce zero launchers.
	var spawn := ProjectileTrapSpawn.new()
	spawn.corridor_chance = 1.0
	spawn.corridor_max_per_segment = 0
	assert_false(spawn.uses_corridor())

func test_uses_room_false_by_default() -> void:
	var spawn := ProjectileTrapSpawn.new()
	assert_false(spawn.uses_room())

func test_uses_room_when_chance_set() -> void:
	var spawn := ProjectileTrapSpawn.new()
	spawn.room_chance = 0.5
	assert_true(spawn.uses_room())
