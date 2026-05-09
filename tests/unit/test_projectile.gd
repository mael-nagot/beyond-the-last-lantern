extends GutTest

func test_create_sets_fields() -> void:
	var proj := Projectile.create(Vector2(3.0, 5.0), Vector2i(1, 0), 8.0)
	assert_eq(proj.direction, Vector2i(1, 0))
	assert_eq(proj.speed, 8.0)
	assert_eq(proj.position, Vector2(3.0, 5.0))
	assert_false(proj.has_hit_player)

func test_get_cell_rounds_to_nearest() -> void:
	var proj := Projectile.create(Vector2(3.4, 5.6), Vector2i(1, 0), 1.0)
	assert_eq(proj.get_cell(), Vector2i(3, 6))

func test_get_cell_at_exact_integer() -> void:
	var proj := Projectile.create(Vector2(3.0, 5.0), Vector2i(1, 0), 1.0)
	assert_eq(proj.get_cell(), Vector2i(3, 5))

func test_get_cell_at_midpoint_rounds_up() -> void:
	# 0.5 rounds to 1 with roundi
	var proj := Projectile.create(Vector2(3.5, 5.0), Vector2i(1, 0), 1.0)
	assert_eq(proj.get_cell(), Vector2i(4, 5))

func test_tick_advances_position_east() -> void:
	var proj := Projectile.create(Vector2(3.0, 5.0), Vector2i(1, 0), 10.0)
	proj.tick(0.1)
	assert_almost_eq(proj.position.x, 4.0, 0.001)
	assert_almost_eq(proj.position.y, 5.0, 0.001)

func test_tick_advances_position_south() -> void:
	var proj := Projectile.create(Vector2(3.0, 5.0), Vector2i(0, 1), 5.0)
	proj.tick(0.2)
	assert_almost_eq(proj.position.x, 3.0, 0.001)
	assert_almost_eq(proj.position.y, 6.0, 0.001)

func test_tick_advances_position_west() -> void:
	var proj := Projectile.create(Vector2(5.0, 3.0), Vector2i(-1, 0), 5.0)
	proj.tick(0.2)
	assert_almost_eq(proj.position.x, 4.0, 0.001)

func test_tick_advances_position_north() -> void:
	var proj := Projectile.create(Vector2(3.0, 5.0), Vector2i(0, -1), 5.0)
	proj.tick(0.2)
	assert_almost_eq(proj.position.y, 4.0, 0.001)

func test_tick_zero_delta_is_noop() -> void:
	var proj := Projectile.create(Vector2(3.0, 5.0), Vector2i(1, 0), 10.0)
	proj.tick(0.0)
	assert_eq(proj.position, Vector2(3.0, 5.0))

func test_tick_negative_delta_is_noop() -> void:
	var proj := Projectile.create(Vector2(3.0, 5.0), Vector2i(1, 0), 10.0)
	proj.tick(-1.0)
	assert_eq(proj.position, Vector2(3.0, 5.0))

func test_cells_entered_empty_when_no_transition() -> void:
	var proj := Projectile.create(Vector2(3.0, 5.0), Vector2i(1, 0), 1.0)
	proj.tick(0.01)  # moves 0.01 cells — stays in same cell
	assert_eq(proj.cells_entered_this_tick().size(), 0)

func test_cells_entered_one_cell_on_normal_transition() -> void:
	var proj := Projectile.create(Vector2(3.0, 5.0), Vector2i(1, 0), 5.0)
	proj.tick(0.25)  # moves 1.25 cells → position (4.25, 5) → enters cell (4, 5)
	var cells := proj.cells_entered_this_tick()
	assert_eq(cells.size(), 1)
	assert_eq(cells[0], Vector2i(4, 5))

func test_cells_entered_multiple_cells_on_fast_transition() -> void:
	# Speed 20, delta 0.15 → moves 3.0 cells.
	# Start at (3, 5), direction east → enters (4,5), (5,5), (6,5)
	var proj := Projectile.create(Vector2(3.0, 5.0), Vector2i(1, 0), 20.0)
	proj.tick(0.15)
	var cells := proj.cells_entered_this_tick()
	assert_eq(cells.size(), 3)
	assert_eq(cells[0], Vector2i(4, 5))
	assert_eq(cells[1], Vector2i(5, 5))
	assert_eq(cells[2], Vector2i(6, 5))

func test_cells_entered_resets_each_tick() -> void:
	var proj := Projectile.create(Vector2(3.0, 5.0), Vector2i(1, 0), 5.0)
	proj.tick(0.3)
	assert_true(proj.cells_entered_this_tick().size() > 0)
	proj.tick(0.01)  # tiny step, no new cell
	assert_eq(proj.cells_entered_this_tick().size(), 0)

func test_has_hit_player_starts_false() -> void:
	var proj := Projectile.create(Vector2(3.0, 5.0), Vector2i(1, 0), 5.0)
	assert_false(proj.has_hit_player)

func test_has_hit_player_can_be_set() -> void:
	var proj := Projectile.create(Vector2(3.0, 5.0), Vector2i(1, 0), 5.0)
	proj.has_hit_player = true
	assert_true(proj.has_hit_player)
