extends GutTest

# Phase 8 Task 3 — Subtask C2.

func _make_data(speed: float = 8.0) -> ProjectileTrapData:
	var data := ProjectileTrapData.new()
	data.speed_cells_per_second = speed
	# Provide a placeholder projectile_sprite_front so the unit-test
	# resource passes the data-side null checks. The sprite picker
	# returns it for any view fallback.
	data.projectile_sprite_front = PlaceholderTexture2D.new()
	return data

# Builds an Array[Array[GridCell]] of size w × h with every cell as
# FLOOR by default and the cells in `walls` marked as WALL. Mirrors
# `LevelGenerator.grid` shape so `ProjectileInstance.tick(grid, ...)`
# can iterate it without needing the full generator.
func _make_grid(w: int, h: int, walls: Array = []) -> Array:
	var g: Array = []
	for x in range(w):
		var col: Array = []
		for y in range(h):
			var c := GridCell.new()
			c.cell_type = GridCell.CellType.FLOOR
			col.append(c)
		g.append(col)
	for pos in walls:
		var p: Vector2i = pos
		g[p.x][p.y].cell_type = GridCell.CellType.WALL
	return g

# --- Construction ---

func test_create_stores_data_position_direction() -> void:
	var data := _make_data()
	var inst := ProjectileInstance.create(data, Vector2(3.5, 5.5), Vector2i(1, 0))
	assert_eq(inst.data, data)
	assert_eq(inst.cell_pos, Vector2(3.5, 5.5))
	assert_eq(inst.direction, Vector2i(1, 0))

func test_damage_latch_defaults_to_false() -> void:
	# Field is wired in C2 (defined now, used in C3). Tests that flow
	# damage in C3 will assert it flips correctly; here we only assert
	# the default so a refactor doesn't accidentally start it true.
	var inst := ProjectileInstance.create(_make_data(), Vector2.ZERO, Vector2i(1, 0))
	assert_false(inst.damage_latch)

# --- tick advances position ---

func test_tick_advances_along_fire_direction() -> void:
	# speed = 10 cells/s, delta = 0.1s → travels 1 cell.
	var data := _make_data(10.0)
	var inst := ProjectileInstance.create(data, Vector2(2.5, 5.5), Vector2i(1, 0))
	var grid := _make_grid(20, 10)
	var event: int = inst.tick(0.1, grid, 20, 10)
	assert_eq(event, ProjectileInstance.Event.NONE)
	assert_almost_eq(inst.cell_pos.x, 3.5, 0.0001)
	assert_eq(inst.cell_pos.y, 5.5)

func test_tick_zero_delta_does_not_advance() -> void:
	var inst := ProjectileInstance.create(_make_data(), Vector2(2.5, 5.5), Vector2i(1, 0))
	var grid := _make_grid(10, 10)
	var event: int = inst.tick(0.0, grid, 10, 10)
	assert_eq(event, ProjectileInstance.Event.NONE)
	assert_eq(inst.cell_pos, Vector2(2.5, 5.5))

func test_tick_null_data_is_noop() -> void:
	var inst := ProjectileInstance.new()
	# data deliberately left null
	var grid := _make_grid(10, 10)
	var event: int = inst.tick(0.1, grid, 10, 10)
	assert_eq(event, ProjectileInstance.Event.NONE)

# --- Wall impact ---

func test_tick_returns_impact_when_entering_wall() -> void:
	# Wall directly in front of the projectile. After one tick at
	# enough speed to enter the wall cell, IMPACT.
	var data := _make_data(10.0)
	var inst := ProjectileInstance.create(data, Vector2(2.5, 5.5), Vector2i(1, 0))
	var grid := _make_grid(20, 10, [Vector2i(3, 5)])
	var event: int = inst.tick(0.1, grid, 20, 10)
	assert_eq(event, ProjectileInstance.Event.IMPACT)

func test_tick_clamps_position_to_wall_face_east() -> void:
	# Direction east. Wall at column 5. The projectile must clamp at
	# x = 5.0 (the wall's west face), not penetrate further into x=6+.
	var data := _make_data(100.0)  # high speed so it would overshoot far
	var inst := ProjectileInstance.create(data, Vector2(2.5, 5.5), Vector2i(1, 0))
	var grid := _make_grid(20, 10, [Vector2i(5, 5)])
	inst.tick(1.0, grid, 20, 10)
	assert_almost_eq(inst.cell_pos.x, 5.0, 0.0001)
	assert_eq(inst.cell_pos.y, 5.5)

func test_tick_clamps_position_to_wall_face_west() -> void:
	# Direction west. Wall at column 1. Projectile must clamp at the
	# wall's EAST face, x = 2.0 (= wall_cell.x + 1).
	var data := _make_data(100.0)
	var inst := ProjectileInstance.create(data, Vector2(5.5, 3.5), Vector2i(-1, 0))
	var grid := _make_grid(20, 10, [Vector2i(1, 3)])
	inst.tick(1.0, grid, 20, 10)
	assert_almost_eq(inst.cell_pos.x, 2.0, 0.0001)
	assert_eq(inst.cell_pos.y, 3.5)

func test_tick_clamps_position_to_wall_face_south() -> void:
	# Direction south. Wall at row 8. Projectile clamps at the wall's
	# NORTH face, y = 8.0.
	var data := _make_data(100.0)
	var inst := ProjectileInstance.create(data, Vector2(3.5, 2.5), Vector2i(0, 1))
	var grid := _make_grid(10, 20, [Vector2i(3, 8)])
	inst.tick(1.0, grid, 10, 20)
	assert_almost_eq(inst.cell_pos.y, 8.0, 0.0001)
	assert_eq(inst.cell_pos.x, 3.5)

func test_tick_high_speed_hits_first_wall_not_skips_past() -> void:
	# Speed is high enough for the projectile to "land" past a wall in
	# a single tick if we naively just floor(new_pos). The walker must
	# detect the FIRST wall cell along the path, not whichever cell
	# the new position happened to fall on.
	var data := _make_data(1000.0)
	var inst := ProjectileInstance.create(data, Vector2(0.5, 5.5), Vector2i(1, 0))
	# Wall at column 3 — projectile should clamp at x = 3.0.
	# Cell 5 is also a wall but should be invisible (passed unimpeded
	# would land at x≈100 without any wall check, demonstrating the
	# bug we want to prevent).
	var grid := _make_grid(20, 10, [Vector2i(3, 5), Vector2i(5, 5)])
	var event: int = inst.tick(1.0, grid, 20, 10)
	assert_eq(event, ProjectileInstance.Event.IMPACT)
	assert_almost_eq(inst.cell_pos.x, 3.0, 0.0001)

func test_tick_off_grid_returns_impact() -> void:
	# Defensive — projectile travels off the grid edge before hitting a
	# wall (shouldn't happen on a real level since the border is wall,
	# but guard against malformed grids).
	var data := _make_data(100.0)
	var inst := ProjectileInstance.create(data, Vector2(8.5, 4.5), Vector2i(1, 0))
	var grid := _make_grid(10, 10)  # no walls anywhere
	var event: int = inst.tick(1.0, grid, 10, 10)
	assert_eq(event, ProjectileInstance.Event.IMPACT)

# --- 4-direction sprite picker (static, pure) ---

func test_view_for_camera_front_when_camera_opposite_fire() -> void:
	# Fire east, camera looks west → camera sees the projectile coming
	# at it = FRONT view.
	assert_eq(
		ProjectileInstance.view_for_camera(Vector2i(1, 0), Vector2(-1, 0)),
		ProjectileInstance.CameraView.FRONT
	)

func test_view_for_camera_back_when_camera_same_as_fire() -> void:
	# Fire east, camera looks east → sees the projectile from behind.
	assert_eq(
		ProjectileInstance.view_for_camera(Vector2i(1, 0), Vector2(1, 0)),
		ProjectileInstance.CameraView.BACK
	)

func test_view_for_camera_right_when_perpendicular_north_camera() -> void:
	# Fire east; camera looks north (forward = (0, -1) in cell-space).
	# The camera is south of the projectile looking north, so it sees
	# the projectile's south side, which is its RIGHT (looking from
	# the projectile's east-facing POV). See the cross-product
	# derivation in `ProjectileInstance.view_for_camera`.
	assert_eq(
		ProjectileInstance.view_for_camera(Vector2i(1, 0), Vector2(0, -1)),
		ProjectileInstance.CameraView.RIGHT
	)

func test_view_for_camera_left_when_perpendicular_south_camera() -> void:
	# Fire east, camera looks south (forward = (0, 1)) → sees LEFT side.
	assert_eq(
		ProjectileInstance.view_for_camera(Vector2i(1, 0), Vector2(0, 1)),
		ProjectileInstance.CameraView.LEFT
	)

func test_view_for_camera_handles_all_four_fire_directions() -> void:
	# Drive the matrix exhaustively — for each cardinal fire direction,
	# the four cardinal camera-forwards must produce the expected view.
	# Encoded as fire → (cam_forward → expected_view) so a future
	# refactor can't introduce an asymmetry without flipping a test.
	var cases := [
		# Fire east
		[Vector2i(1, 0), Vector2(-1, 0), ProjectileInstance.CameraView.FRONT],
		[Vector2i(1, 0), Vector2(1, 0),  ProjectileInstance.CameraView.BACK],
		[Vector2i(1, 0), Vector2(0, -1), ProjectileInstance.CameraView.RIGHT],
		[Vector2i(1, 0), Vector2(0, 1),  ProjectileInstance.CameraView.LEFT],
		# Fire west — flip BACK/FRONT and LEFT/RIGHT vs east
		[Vector2i(-1, 0), Vector2(-1, 0), ProjectileInstance.CameraView.BACK],
		[Vector2i(-1, 0), Vector2(1, 0),  ProjectileInstance.CameraView.FRONT],
		[Vector2i(-1, 0), Vector2(0, -1), ProjectileInstance.CameraView.LEFT],
		[Vector2i(-1, 0), Vector2(0, 1),  ProjectileInstance.CameraView.RIGHT],
		# Fire south
		[Vector2i(0, 1), Vector2(0, -1), ProjectileInstance.CameraView.FRONT],
		[Vector2i(0, 1), Vector2(0, 1),  ProjectileInstance.CameraView.BACK],
		[Vector2i(0, 1), Vector2(-1, 0), ProjectileInstance.CameraView.LEFT],
		[Vector2i(0, 1), Vector2(1, 0),  ProjectileInstance.CameraView.RIGHT],
		# Fire north
		[Vector2i(0, -1), Vector2(0, 1),  ProjectileInstance.CameraView.FRONT],
		[Vector2i(0, -1), Vector2(0, -1), ProjectileInstance.CameraView.BACK],
		[Vector2i(0, -1), Vector2(1, 0),  ProjectileInstance.CameraView.LEFT],
		[Vector2i(0, -1), Vector2(-1, 0), ProjectileInstance.CameraView.RIGHT],
	]
	for case in cases:
		var fire: Vector2i = case[0]
		var cam: Vector2 = case[1]
		var expected: int = case[2]
		assert_eq(
			ProjectileInstance.view_for_camera(fire, cam),
			expected,
			"fire=%s cam=%s" % [fire, cam]
		)

func test_view_for_camera_zero_inputs_fall_back_to_front() -> void:
	# Defensive — neither zero direction nor zero camera-forward should
	# crash; both fall back to FRONT so the renderer keeps drawing
	# something.
	assert_eq(
		ProjectileInstance.view_for_camera(Vector2i.ZERO, Vector2(1, 0)),
		ProjectileInstance.CameraView.FRONT
	)
	assert_eq(
		ProjectileInstance.view_for_camera(Vector2i(1, 0), Vector2.ZERO),
		ProjectileInstance.CameraView.FRONT
	)

# --- Damage to player (Subtask C3) ---

func _make_damaging_data(dmg: int = 8) -> ProjectileTrapData:
	var data := _make_data()
	data.damage = dmg
	return data

func test_consume_damage_returns_true_when_at_player_cell() -> void:
	# Projectile float-cell `(5.5, 7.0)` floors to grid cell `(5, 7)`.
	# A player at `(5, 7)` is exactly there → damage applies.
	var inst := ProjectileInstance.create(_make_damaging_data(8), Vector2(5.5, 7.0), Vector2i(1, 0))
	assert_true(inst.consume_damage_for_player(Vector2i(5, 7)))

func test_consume_damage_sets_latch_on_success() -> void:
	# After a successful damage call, the latch is set so the same
	# projectile can never damage again (even on later ticks where it
	# might pass through the same cell).
	var inst := ProjectileInstance.create(_make_damaging_data(8), Vector2(5.5, 7.0), Vector2i(1, 0))
	inst.consume_damage_for_player(Vector2i(5, 7))
	assert_true(inst.damage_latch)

func test_consume_damage_returns_false_on_second_call_same_cell() -> void:
	# Two calls in a row with the player at the projectile cell — the
	# first returns true and sets the latch; the second returns false.
	# A single projectile damages once per flight, even if multiple
	# frames see it on the player's cell.
	var inst := ProjectileInstance.create(_make_damaging_data(8), Vector2(5.5, 7.0), Vector2i(1, 0))
	assert_true(inst.consume_damage_for_player(Vector2i(5, 7)))
	assert_false(inst.consume_damage_for_player(Vector2i(5, 7)))

func test_consume_damage_returns_false_when_not_at_player_cell() -> void:
	var inst := ProjectileInstance.create(_make_damaging_data(8), Vector2(2.5, 5.5), Vector2i(1, 0))
	assert_false(inst.consume_damage_for_player(Vector2i(8, 8)))
	# And the latch must NOT be set — a non-hit shouldn't trip the
	# latch and lock out a real future hit on the same projectile.
	assert_false(inst.damage_latch)

func test_consume_damage_returns_false_for_zero_damage_data() -> void:
	# Harmless prop projectile — zero damage. The wrapper short-circuits
	# without tripping the latch, so a future variant tweak (set damage
	# to >0) would start damaging without weird latched-state carryover.
	var inst := ProjectileInstance.create(_make_damaging_data(0), Vector2(5.5, 7.0), Vector2i(1, 0))
	assert_false(inst.consume_damage_for_player(Vector2i(5, 7)))
	assert_false(inst.damage_latch)

func test_consume_damage_returns_false_with_null_data() -> void:
	# Defensive — should never crash on a malformed instance.
	var inst := ProjectileInstance.new()
	assert_false(inst.consume_damage_for_player(Vector2i(0, 0)))
	assert_false(inst.damage_latch)

func test_consume_damage_floors_continuous_position_correctly() -> void:
	# `cell_pos.x = 5.99` is still inside grid cell 5 (the cell covers
	# `[5, 6)`). Floor must be 5, so a player at (5, 7) is hit even
	# when the projectile is near the cell's far edge.
	var inst := ProjectileInstance.create(_make_damaging_data(8), Vector2(5.99, 7.5), Vector2i(1, 0))
	assert_true(inst.consume_damage_for_player(Vector2i(5, 7)))

func test_consume_damage_returns_false_when_already_latched() -> void:
	# Bypass the wrapper to set the latch, then assert the wrapper
	# refuses to fire — covers any future caller that might set the
	# latch directly (e.g. unit tests, debug tooling).
	var inst := ProjectileInstance.create(_make_damaging_data(8), Vector2(5.5, 7.0), Vector2i(1, 0))
	inst.damage_latch = true
	assert_false(inst.consume_damage_for_player(Vector2i(5, 7)))
