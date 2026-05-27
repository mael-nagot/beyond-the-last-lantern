extends GutTest

func _make_switch_data(hide_when_active: bool = false) -> ObjectData:
	var data := ObjectData.new()
	data.category = ObjectData.Category.LEVER  # closest reusable category for a switch
	data.blocks_movement = false
	data.hide_when_active = hide_when_active
	return data

func _make_door_data(appears_as_wall: bool = false) -> ObjectData:
	var data := ObjectData.new()
	data.category = ObjectData.Category.DOOR
	data.blocks_movement = true
	data.appears_as_wall = appears_as_wall
	return data

func _make_door(a: Vector2i, b: Vector2i, opened: bool = false, appears_as_wall: bool = false) -> DoorInstance:
	var inst := DoorInstance.create_door(_make_door_data(appears_as_wall), a, b)
	inst.opened = opened
	return inst

# -------------------------------------------------------
# Subtype + creation
# -------------------------------------------------------

func test_create_switch_sets_data_and_clean_state() -> void:
	var data := _make_switch_data()
	var sw := WallSwitchInstance.create_switch(data)
	assert_eq(sw.data, data)
	assert_false(sw.opened)
	assert_false(sw.pulled)
	assert_eq(sw.linked_doors.size(), 0)
	assert_eq(sw.view_cell, Vector2i.ZERO)
	assert_eq(sw.view_side, WallSwitchInstance.SIDE_NORTH)
	assert_eq(sw.along_offset, 0.0)

func test_switch_is_object_instance_subtype() -> void:
	var sw := WallSwitchInstance.create_switch(_make_switch_data())
	assert_true(sw is ObjectInstance)

func test_is_wall_switch_true() -> void:
	var sw := WallSwitchInstance.create_switch(_make_switch_data())
	assert_true(sw.is_wall_switch())

# -------------------------------------------------------
# Direction helpers
# -------------------------------------------------------

func test_dir_for_side_matches_cardinals() -> void:
	assert_eq(WallSwitchInstance.dir_for_side(WallSwitchInstance.SIDE_NORTH), Vector2i(0, -1))
	assert_eq(WallSwitchInstance.dir_for_side(WallSwitchInstance.SIDE_EAST), Vector2i(1, 0))
	assert_eq(WallSwitchInstance.dir_for_side(WallSwitchInstance.SIDE_SOUTH), Vector2i(0, 1))
	assert_eq(WallSwitchInstance.dir_for_side(WallSwitchInstance.SIDE_WEST), Vector2i(-1, 0))

func test_dir_for_side_out_of_range_returns_zero() -> void:
	assert_eq(WallSwitchInstance.dir_for_side(-1), Vector2i.ZERO)
	assert_eq(WallSwitchInstance.dir_for_side(4), Vector2i.ZERO)

# -------------------------------------------------------
# toggle — flips the switch's own pulled state
# -------------------------------------------------------

func test_toggle_flips_pulled() -> void:
	var sw := WallSwitchInstance.create_switch(_make_switch_data())
	assert_false(sw.pulled)
	sw.toggle()
	assert_true(sw.pulled)
	sw.toggle()
	assert_false(sw.pulled)

# -------------------------------------------------------
# get_visual_opened — mirrors any linked door's opened state
# -------------------------------------------------------

func test_visual_opened_false_with_no_doors() -> void:
	var sw := WallSwitchInstance.create_switch(_make_switch_data())
	assert_false(sw.get_visual_opened())

func test_visual_opened_false_with_closed_doors() -> void:
	var sw := WallSwitchInstance.create_switch(_make_switch_data())
	sw.linked_doors = [_make_door(Vector2i(1, 1), Vector2i(1, 2), false)]
	assert_false(sw.get_visual_opened())

func test_visual_opened_true_when_any_linked_door_open() -> void:
	var sw := WallSwitchInstance.create_switch(_make_switch_data())
	sw.linked_doors = [
		_make_door(Vector2i(1, 1), Vector2i(1, 2), false),
		_make_door(Vector2i(3, 3), Vector2i(3, 4), true),
	]
	assert_true(sw.get_visual_opened())

func test_visual_state_independent_of_pulled_field() -> void:
	# The switch's own `pulled` field has no effect on `get_visual_opened`
	# — the renderer always reads "is any linked door open?".
	var sw := WallSwitchInstance.create_switch(_make_switch_data())
	sw.linked_doors = [_make_door(Vector2i(1, 1), Vector2i(1, 2), false)]
	sw.toggle()
	assert_false(sw.get_visual_opened(), "pulled flag must not flip visual state — door is still closed")

# -------------------------------------------------------
# is_on_door — view_cell matches a linked door's endpoint AND
# view_side points across the door's edge
# -------------------------------------------------------

func test_is_on_door_true_from_cell_a() -> void:
	var door := _make_door(Vector2i(1, 1), Vector2i(1, 2))
	var sw := WallSwitchInstance.create_switch(_make_switch_data())
	sw.linked_doors = [door]
	sw.view_cell = door.cell_a
	# direction from cell_a to cell_b is (0, 1) → SIDE_SOUTH
	sw.view_side = WallSwitchInstance.SIDE_SOUTH
	assert_true(sw.is_on_door())

func test_is_on_door_true_from_cell_b() -> void:
	var door := _make_door(Vector2i(1, 1), Vector2i(2, 1))
	var sw := WallSwitchInstance.create_switch(_make_switch_data())
	sw.linked_doors = [door]
	sw.view_cell = door.cell_b
	# direction from cell_b to cell_a is (-1, 0) → SIDE_WEST
	sw.view_side = WallSwitchInstance.SIDE_WEST
	assert_true(sw.is_on_door())

func test_is_on_door_false_when_view_cell_isnt_a_door_endpoint() -> void:
	var door := _make_door(Vector2i(1, 1), Vector2i(1, 2))
	var sw := WallSwitchInstance.create_switch(_make_switch_data())
	sw.linked_doors = [door]
	sw.view_cell = Vector2i(5, 5)
	sw.view_side = WallSwitchInstance.SIDE_NORTH
	assert_false(sw.is_on_door())

func test_is_on_door_false_when_side_points_elsewhere() -> void:
	var door := _make_door(Vector2i(1, 1), Vector2i(1, 2))
	var sw := WallSwitchInstance.create_switch(_make_switch_data())
	sw.linked_doors = [door]
	sw.view_cell = door.cell_a
	# view_side points NORTH but the door is to the SOUTH — wrong side
	sw.view_side = WallSwitchInstance.SIDE_NORTH
	assert_false(sw.is_on_door())

func test_is_on_door_false_with_no_linked_doors() -> void:
	var sw := WallSwitchInstance.create_switch(_make_switch_data())
	sw.view_cell = Vector2i(1, 1)
	sw.view_side = WallSwitchInstance.SIDE_NORTH
	assert_false(sw.is_on_door())

# -------------------------------------------------------
# should_hide — hide_when_active + is_on_door + any linked door open
# -------------------------------------------------------

func test_should_hide_false_when_flag_disabled() -> void:
	var door := _make_door(Vector2i(1, 1), Vector2i(1, 2), true)
	var sw := WallSwitchInstance.create_switch(_make_switch_data(false))
	sw.linked_doors = [door]
	sw.view_cell = door.cell_a
	sw.view_side = WallSwitchInstance.SIDE_SOUTH
	assert_false(sw.should_hide())

func test_should_hide_true_when_on_door_and_door_open() -> void:
	var door := _make_door(Vector2i(1, 1), Vector2i(1, 2), true)
	var sw := WallSwitchInstance.create_switch(_make_switch_data(true))
	sw.linked_doors = [door]
	sw.view_cell = door.cell_a
	sw.view_side = WallSwitchInstance.SIDE_SOUTH
	assert_true(sw.should_hide())

func test_should_hide_false_when_off_door_even_with_door_open() -> void:
	# Off-door switches ignore the flag — the wall the switch is
	# attached to keeps existing whether the door is open or closed,
	# so there's no visual problem to fix.
	var door := _make_door(Vector2i(1, 1), Vector2i(1, 2), true)
	var sw := WallSwitchInstance.create_switch(_make_switch_data(true))
	sw.linked_doors = [door]
	sw.view_cell = Vector2i(5, 5)
	sw.view_side = WallSwitchInstance.SIDE_NORTH
	assert_false(sw.should_hide())

func test_should_hide_false_when_on_door_but_door_closed() -> void:
	var door := _make_door(Vector2i(1, 1), Vector2i(1, 2), false)
	var sw := WallSwitchInstance.create_switch(_make_switch_data(true))
	sw.linked_doors = [door]
	sw.view_cell = door.cell_a
	sw.view_side = WallSwitchInstance.SIDE_SOUTH
	assert_false(sw.should_hide())
