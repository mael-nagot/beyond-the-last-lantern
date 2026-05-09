extends GutTest

func _make_timed_data(interval: float = 3.0, speed: float = 5.0, cooldown: float = 0.0) -> ProjectileTrapData:
	var data := ProjectileTrapData.new()
	data.trigger = ProjectileTrapData.Trigger.TIMED
	data.timed_interval = interval
	data.projectile_speed = speed
	data.cooldown_after_impact = cooldown
	data.damage = 5
	return data

func _make_plate_data(speed: float = 5.0, cooldown: float = 0.0) -> ProjectileTrapData:
	var data := ProjectileTrapData.new()
	data.trigger = ProjectileTrapData.Trigger.PRESSURE_PLATE
	data.projectile_speed = speed
	data.cooldown_after_impact = cooldown
	data.damage = 5
	return data

# Wall at cells with x < 0, y < 0, x >= 10, y >= 10.
# Everything else is passable.
func _is_passable(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < 10 and cell.y < 10

# Wall immediately east of (5, 5) for short-range tests.
func _is_passable_wall_at_8(cell: Vector2i) -> bool:
	return _is_passable(cell) and cell.x < 8


# --- creation ---

func test_create_timed_starts_idle() -> void:
	var inst := ProjectileTrapInstance.create(
		_make_timed_data(), Vector2i(5, 5), Vector2i(0, -1)
	)
	assert_eq(inst.state, ProjectileTrapInstance.State.IDLE)
	assert_eq(inst.launcher_cell, Vector2i(5, 5))
	assert_eq(inst.wall_dir, Vector2i(0, -1))
	assert_eq(inst.fire_direction, Vector2i(0, 1))
	assert_eq(inst.plate_cell, Vector2i(-1, -1))
	assert_null(inst.active_projectile)

func test_create_plate_starts_idle_with_plate_cell() -> void:
	var inst := ProjectileTrapInstance.create(
		_make_plate_data(), Vector2i(5, 5), Vector2i(0, -1), Vector2i(5, 3)
	)
	assert_eq(inst.state, ProjectileTrapInstance.State.IDLE)
	assert_eq(inst.plate_cell, Vector2i(5, 3))

func test_create_timed_with_initial_offset() -> void:
	var data := _make_timed_data(3.0)
	data.timed_initial_offset = 1.5
	var inst := ProjectileTrapInstance.create(data, Vector2i(5, 5), Vector2i(0, -1))
	assert_almost_eq(inst.timer, 1.5, 0.001)

func test_fire_direction_is_opposite_of_wall_dir() -> void:
	var inst := ProjectileTrapInstance.create(
		_make_timed_data(), Vector2i(5, 5), Vector2i(1, 0)
	)
	assert_eq(inst.fire_direction, Vector2i(-1, 0))


# --- TIMED lifecycle ---

func test_timed_fires_after_interval() -> void:
	var inst := ProjectileTrapInstance.create(
		_make_timed_data(2.0), Vector2i(5, 5), Vector2i(0, -1)
	)
	var event := inst.tick(1.0, _is_passable, Vector2i(0, 0))
	assert_eq(event, ProjectileTrapInstance.EVENT_NONE)
	assert_false(inst.has_active_projectile())

	event = inst.tick(1.0, _is_passable, Vector2i(0, 0))
	assert_eq(event, ProjectileTrapInstance.EVENT_LAUNCHED)
	assert_true(inst.has_active_projectile())
	assert_eq(inst.state, ProjectileTrapInstance.State.FIRING)

func test_timed_projectile_hits_wall() -> void:
	# Launcher at (5,5), wall_dir north (0,-1), fires south (0,1).
	# Wall at y=10. Speed 5 cells/sec. Start pos = (5, 5) + (0,-1)*0.4 = (5, 4.6).
	# Travel ~5.4 cells south to hit wall at y=10.
	var inst := ProjectileTrapInstance.create(
		_make_timed_data(0.1, 5.0), Vector2i(5, 5), Vector2i(0, -1)
	)
	# Fire
	inst.tick(0.1, _is_passable, Vector2i(0, 0))
	assert_true(inst.has_active_projectile())

	# Advance until wall hit (~1.1 seconds at speed 5)
	var event := ProjectileTrapInstance.EVENT_NONE
	for i in range(20):
		event = inst.tick(0.1, _is_passable, Vector2i(0, 0))
		if event & ProjectileTrapInstance.EVENT_IMPACT:
			break
	assert_true(event & ProjectileTrapInstance.EVENT_IMPACT != 0)
	assert_false(inst.has_active_projectile())

func test_timed_cycles_after_wall_hit() -> void:
	# After impact, should return to IDLE and count toward next launch.
	var inst := ProjectileTrapInstance.create(
		_make_timed_data(0.1, 100.0), Vector2i(5, 5), Vector2i(0, -1)
	)
	# Fire and immediately hit wall (speed 100 = ~0.05s to cross 5 cells)
	inst.tick(0.1, _is_passable, Vector2i(0, 0))  # LAUNCHED
	inst.tick(0.1, _is_passable, Vector2i(0, 0))  # IMPACT (fast projectile)
	assert_eq(inst.state, ProjectileTrapInstance.State.IDLE)

	# Should fire again after interval
	var event := inst.tick(0.1, _is_passable, Vector2i(0, 0))
	assert_eq(event, ProjectileTrapInstance.EVENT_LAUNCHED)

func test_timed_cooldown_delays_rearm() -> void:
	var inst := ProjectileTrapInstance.create(
		_make_timed_data(0.1, 100.0, 1.0), Vector2i(5, 5), Vector2i(0, -1)
	)
	inst.tick(0.1, _is_passable, Vector2i(0, 0))  # LAUNCHED
	inst.tick(0.1, _is_passable, Vector2i(0, 0))  # IMPACT → COOLDOWN
	assert_eq(inst.state, ProjectileTrapInstance.State.COOLDOWN)

	# Cooldown not finished
	inst.tick(0.5, _is_passable, Vector2i(0, 0))
	assert_eq(inst.state, ProjectileTrapInstance.State.COOLDOWN)

	# Cooldown finished → IDLE
	inst.tick(0.5, _is_passable, Vector2i(0, 0))
	assert_eq(inst.state, ProjectileTrapInstance.State.IDLE)


# --- PRESSURE_PLATE lifecycle ---

func test_plate_does_not_autofire() -> void:
	var inst := ProjectileTrapInstance.create(
		_make_plate_data(), Vector2i(5, 5), Vector2i(0, -1), Vector2i(5, 3)
	)
	inst.tick(10.0, _is_passable, Vector2i(0, 0))
	assert_false(inst.has_active_projectile())
	assert_eq(inst.state, ProjectileTrapInstance.State.IDLE)

func test_plate_fires_on_step() -> void:
	var inst := ProjectileTrapInstance.create(
		_make_plate_data(), Vector2i(5, 5), Vector2i(0, -1), Vector2i(5, 3)
	)
	var fired := inst.on_plate_stepped()
	assert_true(fired)
	assert_true(inst.has_active_projectile())
	assert_eq(inst.state, ProjectileTrapInstance.State.FIRING)

func test_plate_no_refire_while_in_flight() -> void:
	var inst := ProjectileTrapInstance.create(
		_make_plate_data(), Vector2i(5, 5), Vector2i(0, -1), Vector2i(5, 3)
	)
	inst.on_plate_stepped()
	assert_true(inst.has_active_projectile())
	var fired := inst.on_plate_stepped()
	assert_false(fired)

func test_plate_rearms_after_impact() -> void:
	var inst := ProjectileTrapInstance.create(
		_make_plate_data(100.0), Vector2i(5, 5), Vector2i(0, -1), Vector2i(5, 3)
	)
	inst.on_plate_stepped()
	# Fast projectile hits wall quickly
	inst.tick(0.2, _is_passable, Vector2i(0, 0))
	assert_false(inst.has_active_projectile())
	assert_eq(inst.state, ProjectileTrapInstance.State.IDLE)
	# Can fire again
	var fired := inst.on_plate_stepped()
	assert_true(fired)

func test_plate_on_timed_trap_returns_false() -> void:
	var inst := ProjectileTrapInstance.create(
		_make_timed_data(), Vector2i(5, 5), Vector2i(0, -1)
	)
	assert_false(inst.on_plate_stepped())


# --- player hit detection ---

func test_player_hit_when_on_projectile_path() -> void:
	# Launcher at (5,5), fires south. Player at (5,7).
	var inst := ProjectileTrapInstance.create(
		_make_timed_data(0.1, 5.0), Vector2i(5, 5), Vector2i(0, -1)
	)
	inst.tick(0.1, _is_passable, Vector2i(5, 7))  # LAUNCHED

	# Advance until player hit
	var hit := false
	for i in range(20):
		var event := inst.tick(0.1, _is_passable, Vector2i(5, 7))
		if event & ProjectileTrapInstance.EVENT_PLAYER_HIT:
			hit = true
			break
	assert_true(hit)

func test_player_hit_only_once_per_flight() -> void:
	# After hitting the player, has_hit_player prevents re-damage.
	var inst := ProjectileTrapInstance.create(
		_make_timed_data(0.1, 2.0), Vector2i(5, 5), Vector2i(0, -1)
	)
	inst.tick(0.1, _is_passable, Vector2i(5, 7))  # LAUNCHED

	var hit_count := 0
	for i in range(50):
		var event := inst.tick(0.05, _is_passable, Vector2i(5, 7))
		if event & ProjectileTrapInstance.EVENT_PLAYER_HIT:
			hit_count += 1
	assert_eq(hit_count, 1)

func test_player_not_hit_when_off_path() -> void:
	# Launcher fires south. Player is at (3, 7) — not on the path.
	var inst := ProjectileTrapInstance.create(
		_make_timed_data(0.1, 5.0), Vector2i(5, 5), Vector2i(0, -1)
	)
	inst.tick(0.1, _is_passable, Vector2i(3, 7))  # LAUNCHED

	var hit := false
	for i in range(30):
		var event := inst.tick(0.1, _is_passable, Vector2i(3, 7))
		if event & ProjectileTrapInstance.EVENT_PLAYER_HIT:
			hit = true
	assert_false(hit)

func test_player_hit_and_impact_same_tick() -> void:
	# Player stands next to a wall. Projectile hits player and wall
	# on the same tick when crossing into a wall cell.
	# Wall at x >= 8. Player at (7, 5). Launcher fires east.
	var inst := ProjectileTrapInstance.create(
		_make_timed_data(0.1, 5.0), Vector2i(5, 5), Vector2i(-1, 0)
	)
	inst.tick(0.1, _is_passable_wall_at_8, Vector2i(7, 5))  # LAUNCHED

	# Advance until the projectile reaches x=7 and then x=8 (wall)
	var got_hit := false
	var got_impact := false
	for i in range(30):
		var event := inst.tick(0.1, _is_passable_wall_at_8, Vector2i(7, 5))
		if event & ProjectileTrapInstance.EVENT_PLAYER_HIT:
			got_hit = true
		if event & ProjectileTrapInstance.EVENT_IMPACT:
			got_impact = true
		if got_impact:
			break
	assert_true(got_hit)
	assert_true(got_impact)


# --- null / edge cases ---

func test_tick_null_data_is_noop() -> void:
	var inst := ProjectileTrapInstance.new()
	assert_eq(inst.tick(1.0, _is_passable, Vector2i.ZERO), ProjectileTrapInstance.EVENT_NONE)

func test_tick_zero_delta_is_noop() -> void:
	var inst := ProjectileTrapInstance.create(
		_make_timed_data(0.1), Vector2i(5, 5), Vector2i(0, -1)
	)
	assert_eq(inst.tick(0.0, _is_passable, Vector2i.ZERO), ProjectileTrapInstance.EVENT_NONE)

func test_tick_negative_delta_is_noop() -> void:
	var inst := ProjectileTrapInstance.create(
		_make_timed_data(0.1), Vector2i(5, 5), Vector2i(0, -1)
	)
	assert_eq(inst.tick(-1.0, _is_passable, Vector2i.ZERO), ProjectileTrapInstance.EVENT_NONE)

func test_is_idle_reflects_state() -> void:
	var inst := ProjectileTrapInstance.create(
		_make_timed_data(1.0), Vector2i(5, 5), Vector2i(0, -1)
	)
	assert_true(inst.is_idle())
	inst.tick(1.0, _is_passable, Vector2i.ZERO)  # LAUNCHED
	assert_false(inst.is_idle())
