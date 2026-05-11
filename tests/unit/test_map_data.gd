extends GutTest

# MapData depends on a LevelGenerator only for bounds-checking via get_cell()
# and grid_width/grid_height. We build a tiny grid by hand to avoid pulling in
# the full generation pipeline.

func _make_generator(w: int = 5, h: int = 5) -> LevelGenerator:
	var gen := LevelGenerator.new()
	autofree(gen)
	gen.grid_width = w
	gen.grid_height = h
	gen.grid = []
	for x in range(w):
		var col: Array = []
		for y in range(h):
			var c := GridCell.new()
			c.cell_type = GridCell.CellType.FLOOR
			col.append(c)
		gen.grid.append(col)
	return gen

func test_setup_stores_generator_reference() -> void:
	var gen := _make_generator()
	var map := MapData.new()
	map.setup(gen)
	assert_eq(map.generator, gen)

func test_unrevealed_position_is_not_explored() -> void:
	var map := MapData.new()
	map.setup(_make_generator())
	assert_false(map.is_explored(Vector2i(2, 2)))

func test_reveal_around_reveals_center_and_eight_neighbours() -> void:
	var map := MapData.new()
	map.setup(_make_generator())
	map.reveal_around(Vector2i(2, 2))
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			assert_true(map.is_explored(Vector2i(2 + dx, 2 + dy)),
				"expected (%d,%d) to be explored" % [2 + dx, 2 + dy])

func test_reveal_around_does_not_leak_outside_grid() -> void:
	var map := MapData.new()
	map.setup(_make_generator(5, 5))
	map.reveal_around(Vector2i(0, 0))
	# Out-of-bounds neighbours have no cell, so they should not be revealed.
	assert_false(map.is_explored(Vector2i(-1, 0)))
	assert_false(map.is_explored(Vector2i(0, -1)))
	assert_false(map.is_explored(Vector2i(-1, -1)))
	# In-bounds ones are revealed.
	assert_true(map.is_explored(Vector2i(0, 0)))
	assert_true(map.is_explored(Vector2i(1, 0)))
	assert_true(map.is_explored(Vector2i(0, 1)))
	assert_true(map.is_explored(Vector2i(1, 1)))

func test_reveal_all_marks_every_cell_explored() -> void:
	var map := MapData.new()
	var gen := _make_generator(3, 4)
	map.setup(gen)
	map.reveal_all()
	for x in range(gen.grid_width):
		for y in range(gen.grid_height):
			assert_true(map.is_explored(Vector2i(x, y)),
				"expected (%d,%d) to be explored after reveal_all" % [x, y])

func test_reveal_around_is_idempotent() -> void:
	var map := MapData.new()
	map.setup(_make_generator())
	map.reveal_around(Vector2i(2, 2))
	var first_count := map.explored.size()
	map.reveal_around(Vector2i(2, 2))
	assert_eq(map.explored.size(), first_count)

# -------------------------------------------------------
# Secret walls block the reveal — the cell behind the wall (and the
# diagonals on that side) must stay hidden until the player walks
# through. Without this, the map gives the secret away by exposing
# the corridor continuation.
# -------------------------------------------------------

func _add_secret_wall(gen: LevelGenerator, a: Vector2i, b: Vector2i) -> void:
	var inst := SecretWallInstance.create(a, b)
	gen.secret_walls.append(inst)
	gen._secret_walls_by_edge[SecretWallInstance.edge_key(a, b)] = inst

func test_reveal_around_skips_cell_behind_secret_wall() -> void:
	var map := MapData.new()
	var gen := _make_generator()
	_add_secret_wall(gen, Vector2i(2, 2), Vector2i(3, 2))
	map.setup(gen)
	map.reveal_around(Vector2i(2, 2))
	assert_true(map.is_explored(Vector2i(2, 2)), "player cell must always be explored")
	assert_false(map.is_explored(Vector2i(3, 2)),
		"cell directly behind the secret wall must stay hidden")

func test_reveal_around_skips_diagonals_adjacent_to_secret_wall() -> void:
	# Bent-corridor leak: with the wall east, the SE diagonal can be
	# the bend cell. Block diagonals on the blocked side too.
	var map := MapData.new()
	var gen := _make_generator()
	_add_secret_wall(gen, Vector2i(2, 2), Vector2i(3, 2))
	map.setup(gen)
	map.reveal_around(Vector2i(2, 2))
	assert_false(map.is_explored(Vector2i(3, 1)),
		"NE diagonal sits on the blocked east side — must stay hidden")
	assert_false(map.is_explored(Vector2i(3, 3)),
		"SE diagonal sits on the blocked east side — must stay hidden")

func test_reveal_around_still_reveals_opposite_side() -> void:
	# A wall on the east side mustn't affect what's revealed to the
	# west. The other orthogonals + their diagonals stay visible.
	var map := MapData.new()
	var gen := _make_generator()
	_add_secret_wall(gen, Vector2i(2, 2), Vector2i(3, 2))
	map.setup(gen)
	map.reveal_around(Vector2i(2, 2))
	assert_true(map.is_explored(Vector2i(1, 2)), "west orthogonal stays visible")
	assert_true(map.is_explored(Vector2i(2, 1)), "north orthogonal stays visible")
	assert_true(map.is_explored(Vector2i(2, 3)), "south orthogonal stays visible")
	assert_true(map.is_explored(Vector2i(1, 1)), "NW diagonal stays visible")
	assert_true(map.is_explored(Vector2i(1, 3)), "SW diagonal stays visible")

func test_reveal_around_unblocks_after_player_crosses_secret_wall() -> void:
	# After the player walks through, calling reveal_around from the
	# OTHER side reveals new ground beyond. The secret wall edge is
	# only "between cell_a and cell_b"; cell_b's east neighbour is
	# not blocked.
	var map := MapData.new()
	var gen := _make_generator()
	_add_secret_wall(gen, Vector2i(2, 2), Vector2i(3, 2))
	map.setup(gen)
	map.reveal_around(Vector2i(3, 2))
	assert_true(map.is_explored(Vector2i(3, 2)))
	assert_true(map.is_explored(Vector2i(4, 2)), "east of the far side stays revealable")
	# The original side stays hidden FROM cell_b's reveal, but was
	# already explored when the player stood there earlier — so
	# combined exploration over time covers both sides.
	assert_false(map.is_explored(Vector2i(2, 2)),
		"reveal_around from cell_b must not leak BACK through the secret wall on its own")
