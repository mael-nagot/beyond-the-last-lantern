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
