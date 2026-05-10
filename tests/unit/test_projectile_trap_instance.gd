extends GutTest

# Phase 8 Task 3 — Subtask C1.

func _make_data() -> ProjectileTrapData:
	return ProjectileTrapData.new()

func test_create_stores_data_cell_and_wall_dir() -> void:
	var data := _make_data()
	var inst := ProjectileTrapInstance.create(data, Vector2i(5, 7), ProjectileTrapInstance.DIR_NORTH)
	assert_eq(inst.data, data)
	assert_eq(inst.cell, Vector2i(5, 7))
	assert_eq(inst.wall_dir, Vector2i(0, -1))

func test_fire_direction_is_opposite_of_wall_dir() -> void:
	# Launcher mounted on the north wall fires south; mounted on the
	# east wall fires west. The renderer + flight code rely on this.
	var n := ProjectileTrapInstance.create(_make_data(), Vector2i(0, 0), ProjectileTrapInstance.DIR_NORTH)
	assert_eq(n.fire_direction(), Vector2i(0, 1), "north wall → fire south")
	var s := ProjectileTrapInstance.create(_make_data(), Vector2i(0, 0), ProjectileTrapInstance.DIR_SOUTH)
	assert_eq(s.fire_direction(), Vector2i(0, -1), "south wall → fire north")
	var e := ProjectileTrapInstance.create(_make_data(), Vector2i(0, 0), ProjectileTrapInstance.DIR_EAST)
	assert_eq(e.fire_direction(), Vector2i(-1, 0), "east wall → fire west")
	var w := ProjectileTrapInstance.create(_make_data(), Vector2i(0, 0), ProjectileTrapInstance.DIR_WEST)
	assert_eq(w.fire_direction(), Vector2i(1, 0), "west wall → fire east")

func test_face_key_is_unique_per_face() -> void:
	# Same format as WallDecorationInstance.face_key — both share the
	# generator's `_wall_faces_used` registry, so identical inputs MUST
	# produce identical keys.
	var ka := ProjectileTrapInstance.face_key(Vector2i(3, 4), Vector2i(0, -1))
	var kb := ProjectileTrapInstance.face_key(Vector2i(3, 4), Vector2i(0, 1))
	var kc := ProjectileTrapInstance.face_key(Vector2i(3, 5), Vector2i(0, -1))
	assert_ne(ka, kb, "different wall sides on same cell must collide-resist")
	assert_ne(ka, kc, "different cells with same wall side must collide-resist")

func test_face_key_format_matches_wall_decoration() -> void:
	# Wall decorations and projectile launchers MUST use the exact same
	# face-key string format — they share `_wall_faces_used` on
	# `LevelGenerator`. Drift between the two breaks exclusivity.
	var ptrap_key := ProjectileTrapInstance.face_key(Vector2i(2, 8), Vector2i(1, 0))
	var deco_key := WallDecorationInstance.face_key(Vector2i(2, 8), Vector2i(1, 0))
	assert_eq(ptrap_key, deco_key)

func test_get_face_key_matches_static_helper() -> void:
	var inst := ProjectileTrapInstance.create(_make_data(), Vector2i(2, 8), ProjectileTrapInstance.DIR_EAST)
	assert_eq(inst.get_face_key(), ProjectileTrapInstance.face_key(Vector2i(2, 8), Vector2i(1, 0)))

func test_no_plate_by_default() -> void:
	# Subtask C1 places launchers without plates; C4 will populate
	# `plate_cell` for PRESSURE_PLATE traps. The default sentinel must
	# read as "no plate".
	var inst := ProjectileTrapInstance.create(_make_data(), Vector2i(0, 0), ProjectileTrapInstance.DIR_NORTH)
	assert_eq(inst.plate_cell, ProjectileTrapInstance.NO_PLATE)
	assert_false(inst.has_plate())

func test_has_plate_true_when_plate_cell_set() -> void:
	var inst := ProjectileTrapInstance.create(_make_data(), Vector2i(0, 0), ProjectileTrapInstance.DIR_NORTH)
	inst.plate_cell = Vector2i(3, 5)
	assert_true(inst.has_plate())

func test_direction_constants() -> void:
	assert_eq(ProjectileTrapInstance.DIR_NORTH, Vector2i(0, -1))
	assert_eq(ProjectileTrapInstance.DIR_SOUTH, Vector2i(0, 1))
	assert_eq(ProjectileTrapInstance.DIR_WEST, Vector2i(-1, 0))
	assert_eq(ProjectileTrapInstance.DIR_EAST, Vector2i(1, 0))

# --- TIMED firing (Subtask C2) ---

func _make_timed_data(period: float = 2.0, initial_offset: float = 0.0) -> ProjectileTrapData:
	var data := ProjectileTrapData.new()
	data.trigger = ProjectileTrapData.Trigger.TIMED
	data.timed_period = period
	data.timed_initial_offset = initial_offset
	data.speed_cells_per_second = 8.0
	return data

func test_create_initialises_timer_to_data_offset_for_timed() -> void:
	var data := _make_timed_data(2.0, 0.7)
	var inst := ProjectileTrapInstance.create(data, Vector2i(3, 4), ProjectileTrapInstance.DIR_NORTH)
	assert_eq(inst.timed_offset, 0.7)
	assert_eq(inst.timer, 0.7)

func test_create_leaves_timer_zero_for_pressure_plate() -> void:
	# PRESSURE_PLATE traps don't tick by clock — they fire on player
	# step (Subtask C4). The timer / offset fields should stay at 0
	# regardless of any data fields.
	var data := _make_data()
	data.trigger = ProjectileTrapData.Trigger.PRESSURE_PLATE
	var inst := ProjectileTrapInstance.create(data, Vector2i(0, 0), ProjectileTrapInstance.DIR_NORTH)
	assert_eq(inst.timer, 0.0)
	assert_eq(inst.timed_offset, 0.0)

func test_tick_returns_null_until_period_elapsed() -> void:
	var data := _make_timed_data(2.0)
	var inst := ProjectileTrapInstance.create(data, Vector2i(3, 4), ProjectileTrapInstance.DIR_NORTH)
	# Advance 1.5s — still under the 2.0s period, so no spawn.
	assert_null(inst.tick(0.5))
	assert_null(inst.tick(1.0))
	assert_almost_eq(inst.timer, 1.5, 0.0001)

func test_tick_spawns_projectile_on_period_rollover() -> void:
	var data := _make_timed_data(1.0)
	var inst := ProjectileTrapInstance.create(data, Vector2i(3, 4), ProjectileTrapInstance.DIR_NORTH)
	# 1.0s exactly — fires.
	var spawned: ProjectileInstance = inst.tick(1.0)
	assert_not_null(spawned, "should spawn at exactly the period boundary")
	assert_eq(spawned.data, data)
	assert_eq(spawned.direction, Vector2i(0, 1), "north wall fires south")

func test_tick_resets_timer_after_rollover() -> void:
	var data := _make_timed_data(1.0)
	var inst := ProjectileTrapInstance.create(data, Vector2i(0, 0), ProjectileTrapInstance.DIR_NORTH)
	inst.tick(1.0)
	# After rollover the timer holds the leftover time (here exactly 0)
	# so the next cycle starts cleanly. fposmod handles delta > period
	# too — see the next test.
	assert_almost_eq(inst.timer, 0.0, 0.0001)

func test_tick_handles_long_delta_via_fposmod() -> void:
	# Single tick of 3.5s with a 1.0s period — should still spawn one
	# projectile and leave timer at fposmod(3.5, 1.0) = 0.5. We don't
	# spawn three projectiles in one tick (would feel like a burst);
	# the placer's TIMED contract is "one shot per period rollover the
	# tick observes", which is good enough at 60fps.
	var data := _make_timed_data(1.0)
	var inst := ProjectileTrapInstance.create(data, Vector2i(0, 0), ProjectileTrapInstance.DIR_NORTH)
	var spawned: ProjectileInstance = inst.tick(3.5)
	assert_not_null(spawned)
	assert_almost_eq(inst.timer, 0.5, 0.0001)

func test_tick_returns_null_for_pressure_plate_data() -> void:
	# Subtask C2 only wires TIMED firing. PRESSURE_PLATE traps never
	# tick by clock; their tick should be a no-op.
	var data := _make_data()
	data.trigger = ProjectileTrapData.Trigger.PRESSURE_PLATE
	var inst := ProjectileTrapInstance.create(data, Vector2i(0, 0), ProjectileTrapInstance.DIR_NORTH)
	assert_null(inst.tick(10.0))

func test_tick_null_data_is_noop() -> void:
	var inst := ProjectileTrapInstance.new()
	# data deliberately null
	assert_null(inst.tick(1.0))

func test_spawned_projectile_starts_at_wall_face_inside_host_cell() -> void:
	# Host cell (3, 4), wall north → wall face is at y = 4.0 (top of
	# cell). Projectile starts at (cell.x + 0.5, cell.y) = (3.5, 4.0)
	# and travels south (direction (0, 1)) — the cell-space starting
	# y = 4.0 is exactly the boundary between the wall cell (3, 3) and
	# the host floor cell (3, 4).
	var data := _make_timed_data(0.5)
	var inst := ProjectileTrapInstance.create(data, Vector2i(3, 4), ProjectileTrapInstance.DIR_NORTH)
	var spawned: ProjectileInstance = inst.tick(0.5)
	assert_not_null(spawned)
	assert_almost_eq(spawned.cell_pos.x, 3.5, 0.0001)
	assert_almost_eq(spawned.cell_pos.y, 4.0, 0.0001)

func test_spawned_projectile_direction_matches_fire_direction() -> void:
	# Sanity: every wall-mount direction produces a projectile flying
	# in the opposite cardinal direction.
	var cases := [
		[ProjectileTrapInstance.DIR_NORTH, Vector2i(0, 1)],
		[ProjectileTrapInstance.DIR_SOUTH, Vector2i(0, -1)],
		[ProjectileTrapInstance.DIR_EAST,  Vector2i(-1, 0)],
		[ProjectileTrapInstance.DIR_WEST,  Vector2i(1, 0)],
	]
	for case in cases:
		var wall: Vector2i = case[0]
		var expected_dir: Vector2i = case[1]
		var data := _make_timed_data(0.1)
		var inst := ProjectileTrapInstance.create(data, Vector2i(3, 4), wall)
		var spawned: ProjectileInstance = inst.tick(0.1)
		assert_not_null(spawned)
		assert_eq(spawned.direction, expected_dir, "wall=%s" % wall)

# --- Subtask C4: PRESSURE_PLATE in-flight lock + spawn_projectile ---

func _make_plate_data() -> ProjectileTrapData:
	var data := ProjectileTrapData.new()
	data.trigger = ProjectileTrapData.Trigger.PRESSURE_PLATE
	data.speed_cells_per_second = 8.0
	return data

func test_spawn_projectile_sets_launcher_back_ref() -> void:
	# Game.gd reads `proj.launcher` on IMPACT to clear the launcher's
	# in_flight flag. Without the back-ref a PRESSURE_PLATE trap
	# would lock forever after its first shot.
	var data := _make_timed_data(1.0)
	var inst := ProjectileTrapInstance.create(data, Vector2i(3, 4), ProjectileTrapInstance.DIR_NORTH)
	var spawned := inst.spawn_projectile()
	assert_not_null(spawned)
	assert_eq(spawned.launcher, inst, "back-ref must point to the firing launcher")

func test_spawn_projectile_sets_in_flight_for_pressure_plate() -> void:
	# A successful spawn_projectile on a PRESSURE_PLATE launcher must
	# flip in_flight true so the plate can't re-trigger before IMPACT.
	var inst := ProjectileTrapInstance.create(_make_plate_data(), Vector2i(3, 4), ProjectileTrapInstance.DIR_NORTH)
	assert_false(inst.in_flight, "fresh launcher starts with no projectile in flight")
	var spawned := inst.spawn_projectile()
	assert_not_null(spawned)
	assert_true(inst.in_flight, "in_flight must be set after a successful spawn")

func test_spawn_projectile_does_not_set_in_flight_for_timed() -> void:
	# TIMED traps don't gate by in_flight — their period drives
	# everything. Setting in_flight on TIMED would do no harm but the
	# code intentionally leaves it false so the field cleanly
	# reflects "PRESSURE_PLATE has a live projectile".
	var inst := ProjectileTrapInstance.create(_make_timed_data(1.0), Vector2i(3, 4), ProjectileTrapInstance.DIR_NORTH)
	var spawned := inst.spawn_projectile()
	assert_not_null(spawned)
	assert_false(inst.in_flight, "TIMED traps must not flip in_flight on spawn")

func test_spawn_projectile_blocks_when_pressure_plate_in_flight() -> void:
	# The whole point of the lock — once a projectile is in flight
	# from a PRESSURE_PLATE launcher, the plate can't re-trigger.
	var inst := ProjectileTrapInstance.create(_make_plate_data(), Vector2i(3, 4), ProjectileTrapInstance.DIR_NORTH)
	var first := inst.spawn_projectile()
	assert_not_null(first)
	var second := inst.spawn_projectile()
	assert_null(second, "second spawn while in_flight must return null")

func test_spawn_projectile_succeeds_again_after_in_flight_cleared() -> void:
	# Game.gd clears in_flight on IMPACT; once cleared the plate
	# fires again on the next step.
	var inst := ProjectileTrapInstance.create(_make_plate_data(), Vector2i(3, 4), ProjectileTrapInstance.DIR_NORTH)
	assert_not_null(inst.spawn_projectile())
	# Simulate IMPACT clearing the lock.
	inst.in_flight = false
	assert_not_null(inst.spawn_projectile(), "next spawn must succeed once lock clears")
