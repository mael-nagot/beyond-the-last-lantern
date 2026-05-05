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
