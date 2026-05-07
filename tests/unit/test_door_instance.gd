extends GutTest

func _make_data(blocks: bool = true) -> ObjectData:
	var data := ObjectData.new()
	data.category = ObjectData.Category.DOOR
	data.blocks_movement = blocks
	data.name_key = "test.door"
	return data

# -------------------------------------------------------
# canonical_pair / edge_key — the same edge always resolves
# to the same key regardless of input order, so doors can't
# accidentally be stored twice.
# -------------------------------------------------------

func test_canonical_pair_orders_by_x_then_y() -> void:
	var a := Vector2i(3, 5)
	var b := Vector2i(4, 5)
	var pair: Array = DoorInstance.canonical_pair(a, b)
	assert_eq(pair[0], a)
	assert_eq(pair[1], b)

func test_canonical_pair_swaps_when_first_arg_larger() -> void:
	var pair: Array = DoorInstance.canonical_pair(Vector2i(4, 5), Vector2i(3, 5))
	assert_eq(pair[0], Vector2i(3, 5))
	assert_eq(pair[1], Vector2i(4, 5))

func test_canonical_pair_breaks_x_tie_with_y() -> void:
	var pair: Array = DoorInstance.canonical_pair(Vector2i(3, 6), Vector2i(3, 5))
	assert_eq(pair[0], Vector2i(3, 5))
	assert_eq(pair[1], Vector2i(3, 6))

func test_edge_key_is_order_independent() -> void:
	var a := Vector2i(7, 2)
	var b := Vector2i(7, 3)
	assert_eq(DoorInstance.edge_key(a, b), DoorInstance.edge_key(b, a))

func test_edge_key_distinguishes_different_edges() -> void:
	var k1 := DoorInstance.edge_key(Vector2i(3, 5), Vector2i(4, 5))
	var k2 := DoorInstance.edge_key(Vector2i(3, 5), Vector2i(3, 6))
	assert_ne(k1, k2)

# -------------------------------------------------------
# create_door — stores cells canonically and links data.
# -------------------------------------------------------

func test_create_door_stores_canonical_cells() -> void:
	var data := _make_data()
	var inst := DoorInstance.create_door(data, Vector2i(4, 5), Vector2i(3, 5))
	assert_eq(inst.cell_a, Vector2i(3, 5))
	assert_eq(inst.cell_b, Vector2i(4, 5))
	assert_eq(inst.data, data)
	assert_false(inst.opened)

func test_create_door_starts_closed() -> void:
	var inst := DoorInstance.create_door(_make_data(), Vector2i(0, 0), Vector2i(0, 1))
	assert_false(inst.opened)

# -------------------------------------------------------
# axis() — derives orientation from cells, no stored field.
# -------------------------------------------------------

func test_axis_horizontal_for_east_west_corridor() -> void:
	var inst := DoorInstance.create_door(_make_data(), Vector2i(3, 5), Vector2i(4, 5))
	assert_eq(inst.axis(), Vector2i(1, 0))

func test_axis_vertical_for_north_south_corridor() -> void:
	var inst := DoorInstance.create_door(_make_data(), Vector2i(3, 5), Vector2i(3, 6))
	assert_eq(inst.axis(), Vector2i(0, 1))

# -------------------------------------------------------
# is_edge_blocked — single source of truth for movement.
# -------------------------------------------------------

func test_closed_blocking_door_blocks_edge() -> void:
	var inst := DoorInstance.create_door(_make_data(true), Vector2i(0, 0), Vector2i(0, 1))
	inst.opened = false
	assert_true(inst.is_edge_blocked())

func test_open_door_does_not_block() -> void:
	var inst := DoorInstance.create_door(_make_data(true), Vector2i(0, 0), Vector2i(0, 1))
	inst.opened = true
	assert_false(inst.is_edge_blocked())

func test_non_blocking_door_never_blocks_even_when_closed() -> void:
	# Reserved for future archways: visually look like closed doors but
	# never actually obstruct movement.
	var inst := DoorInstance.create_door(_make_data(false), Vector2i(0, 0), Vector2i(0, 1))
	inst.opened = false
	assert_false(inst.is_edge_blocked())

func test_door_with_null_data_does_not_block() -> void:
	var inst := DoorInstance.new()
	inst.data = null
	assert_false(inst.is_edge_blocked())

# -------------------------------------------------------
# DoorInstance is a kind of ObjectInstance (so the existing
# Area3D meta + click signal plumbing flows through unchanged)
# but is_chest() is still false for it.
# -------------------------------------------------------

func test_door_is_object_instance_subtype() -> void:
	var inst := DoorInstance.create_door(_make_data(), Vector2i(0, 0), Vector2i(0, 1))
	assert_true(inst is ObjectInstance)

func test_door_is_chest_returns_false() -> void:
	var inst := DoorInstance.create_door(_make_data(), Vector2i(0, 0), Vector2i(0, 1))
	assert_false(inst.is_chest())

func test_door_is_door_returns_true() -> void:
	var inst := DoorInstance.create_door(_make_data(), Vector2i(0, 0), Vector2i(0, 1))
	assert_true(inst.is_door())

# -------------------------------------------------------
# Key locks (Phase 8 Task 2c)
# -------------------------------------------------------

func test_door_defaults_unlocked_when_no_lock_id() -> void:
	var inst := DoorInstance.create_door(_make_data(), Vector2i(0, 0), Vector2i(0, 1))
	assert_eq(inst.lock_id, "")
	assert_false(inst.unlocked)
	assert_false(inst.is_key_locked())

func test_door_with_lock_id_is_key_locked_until_unlocked() -> void:
	var inst := DoorInstance.create_door(_make_data(), Vector2i(0, 0), Vector2i(0, 1))
	inst.lock_id = "copper_0"
	assert_true(inst.is_key_locked())

func test_unlock_is_sticky() -> void:
	var inst := DoorInstance.create_door(_make_data(), Vector2i(0, 0), Vector2i(0, 1))
	inst.lock_id = "copper_0"
	inst.unlocked = true
	assert_false(inst.is_key_locked())
	assert_eq(inst.lock_id, "copper_0", "lock_id must persist post-unlock")

# -------------------------------------------------------
# Lever locks (Phase 8 Task 2b M:N)
# -------------------------------------------------------

func _make_lever(pulled: bool = false) -> LeverInstance:
	var data := ObjectData.new()
	data.category = ObjectData.Category.LEVER
	var lever := LeverInstance.create_lever(data)
	lever.pulled = pulled
	return lever

func test_door_without_levers_is_not_lever_locked() -> void:
	var inst := DoorInstance.create_door(_make_data(), Vector2i(0, 0), Vector2i(0, 1))
	assert_false(inst.is_lever_locked())

func test_door_with_levers_is_lever_locked() -> void:
	var inst := DoorInstance.create_door(_make_data(), Vector2i(0, 0), Vector2i(0, 1))
	inst.linked_levers = [_make_lever()]
	assert_true(inst.is_lever_locked())

func test_lever_logic_defaults_to_and() -> void:
	var inst := DoorInstance.create_door(_make_data(), Vector2i(0, 0), Vector2i(0, 1))
	assert_eq(inst.lever_logic, DoorInstance.LeverLogic.AND)

func test_compute_lever_opened_no_levers_returns_opened_field() -> void:
	var inst := DoorInstance.create_door(_make_data(), Vector2i(0, 0), Vector2i(0, 1))
	inst.opened = false
	assert_false(inst.compute_lever_opened())
	inst.opened = true
	assert_true(inst.compute_lever_opened())

func test_compute_lever_opened_and_all_pulled() -> void:
	var inst := DoorInstance.create_door(_make_data(), Vector2i(0, 0), Vector2i(0, 1))
	inst.lever_logic = DoorInstance.LeverLogic.AND
	inst.linked_levers = [_make_lever(true), _make_lever(true)]
	assert_true(inst.compute_lever_opened())

func test_compute_lever_opened_and_not_all_pulled() -> void:
	var inst := DoorInstance.create_door(_make_data(), Vector2i(0, 0), Vector2i(0, 1))
	inst.lever_logic = DoorInstance.LeverLogic.AND
	inst.linked_levers = [_make_lever(true), _make_lever(false)]
	assert_false(inst.compute_lever_opened())

func test_compute_lever_opened_and_none_pulled() -> void:
	var inst := DoorInstance.create_door(_make_data(), Vector2i(0, 0), Vector2i(0, 1))
	inst.lever_logic = DoorInstance.LeverLogic.AND
	inst.linked_levers = [_make_lever(false), _make_lever(false)]
	assert_false(inst.compute_lever_opened())

func test_compute_lever_opened_or_any_pulled() -> void:
	var inst := DoorInstance.create_door(_make_data(), Vector2i(0, 0), Vector2i(0, 1))
	inst.lever_logic = DoorInstance.LeverLogic.OR
	inst.linked_levers = [_make_lever(false), _make_lever(true)]
	assert_true(inst.compute_lever_opened())

func test_compute_lever_opened_or_none_pulled() -> void:
	var inst := DoorInstance.create_door(_make_data(), Vector2i(0, 0), Vector2i(0, 1))
	inst.lever_logic = DoorInstance.LeverLogic.OR
	inst.linked_levers = [_make_lever(false), _make_lever(false)]
	assert_false(inst.compute_lever_opened())

func test_compute_lever_opened_and_handles_null_lever() -> void:
	var inst := DoorInstance.create_door(_make_data(), Vector2i(0, 0), Vector2i(0, 1))
	inst.lever_logic = DoorInstance.LeverLogic.AND
	inst.linked_levers = [null, _make_lever(true)]
	assert_false(inst.compute_lever_opened(), "null lever in AND chain blocks opening")

func test_compute_lever_opened_or_skips_null_lever() -> void:
	var inst := DoorInstance.create_door(_make_data(), Vector2i(0, 0), Vector2i(0, 1))
	inst.lever_logic = DoorInstance.LeverLogic.OR
	inst.linked_levers = [null, _make_lever(true)]
	assert_true(inst.compute_lever_opened(), "null lever in OR chain doesn't block")
