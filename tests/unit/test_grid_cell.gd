extends GutTest

func test_default_cell_is_a_wall() -> void:
	var cell := GridCell.new()
	assert_eq(cell.cell_type, GridCell.CellType.WALL)

func test_wall_cell_is_blocked() -> void:
	var cell := GridCell.new()
	cell.cell_type = GridCell.CellType.WALL
	assert_true(cell.is_blocked)

func test_floor_cell_is_not_blocked() -> void:
	var cell := GridCell.new()
	cell.cell_type = GridCell.CellType.FLOOR
	assert_false(cell.is_blocked)

func test_entrance_and_exit_are_not_blocked() -> void:
	var entrance := GridCell.new()
	entrance.cell_type = GridCell.CellType.ENTRANCE
	assert_false(entrance.is_blocked)

	var exit := GridCell.new()
	exit.cell_type = GridCell.CellType.EXIT
	assert_false(exit.is_blocked)

func test_default_items_array_is_empty() -> void:
	var cell := GridCell.new()
	assert_eq(cell.items.size(), 0)

func test_items_array_can_hold_multiple_items() -> void:
	var cell := GridCell.new()
	var data := ItemData.new()
	data.item_name = "test.x"
	cell.items.append(ItemInstance.create(data, 1))
	cell.items.append(ItemInstance.create(data, 1))
	assert_eq(cell.items.size(), 2)

func test_default_walls_present_on_all_sides() -> void:
	var cell := GridCell.new()
	assert_true(cell.wall_north)
	assert_true(cell.wall_south)
	assert_true(cell.wall_east)
	assert_true(cell.wall_west)

func test_default_object_is_null() -> void:
	var cell := GridCell.new()
	assert_null(cell.object)

func test_floor_with_blocking_object_is_blocked() -> void:
	var cell := GridCell.new()
	cell.cell_type = GridCell.CellType.FLOOR
	var data := ObjectData.new()
	data.blocks_movement = true
	cell.object = ObjectInstance.create(data)
	assert_true(cell.is_blocked)

func test_floor_with_non_blocking_object_is_not_blocked() -> void:
	var cell := GridCell.new()
	cell.cell_type = GridCell.CellType.FLOOR
	var data := ObjectData.new()
	data.blocks_movement = false
	cell.object = ObjectInstance.create(data)
	assert_false(cell.is_blocked)

func test_default_trap_is_null() -> void:
	var cell := GridCell.new()
	assert_null(cell.trap)

func test_floor_with_trap_is_not_blocked() -> void:
	# Traps don't block movement — the player walks onto the cell to
	# take damage. Confirms is_blocked ignores the trap slot entirely.
	var cell := GridCell.new()
	cell.cell_type = GridCell.CellType.FLOOR
	var data := TrapData.new()
	cell.trap = TrapInstance.create(data, Vector2i.ZERO)
	assert_false(cell.is_blocked)

func test_default_spinner_is_null() -> void:
	var cell := GridCell.new()
	assert_null(cell.spinner)

func test_floor_with_spinner_is_not_blocked() -> void:
	# Spinners don't block movement either — the player must walk
	# onto the cell to trigger the rotation. is_blocked should ignore
	# the spinner slot the same way it ignores the trap slot.
	var cell := GridCell.new()
	cell.cell_type = GridCell.CellType.FLOOR
	var data := SpinnerData.new()
	cell.spinner = SpinnerInstance.create(data, Vector2i.ZERO, SpinnerInstance.Direction.CLOCKWISE, 1)
	assert_false(cell.is_blocked)

func test_default_teleporter_is_null() -> void:
	var cell := GridCell.new()
	assert_null(cell.teleporter)

func test_floor_with_teleporter_is_not_blocked() -> void:
	# Teleporters never block movement — the player must step onto
	# the cell to trigger the warp. is_blocked should ignore the
	# teleporter slot the same way it ignores trap and spinner.
	var cell := GridCell.new()
	cell.cell_type = GridCell.CellType.FLOOR
	var data := TeleporterData.new()
	cell.teleporter = TeleporterInstance.create(data, Vector2i(1, 1), Vector2i(5, 5), 0)
	assert_false(cell.is_blocked)
