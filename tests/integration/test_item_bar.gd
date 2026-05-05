extends GutTest

# ItemBar.new() creates UI panels in _ready(); it must be inside the scene
# tree before we exercise it. add_child_autofree handles cleanup.

func _make_data(stackable: bool = true, stack_max: int = 9) -> ItemData:
	var data := ItemData.new()
	data.item_name = "test.item"
	data.stackable = stackable
	data.stack_max = stack_max
	return data

func _make_bar() -> ItemBar:
	var bar := ItemBar.new()
	add_child_autofree(bar)
	return bar

func test_inventory_starts_empty() -> void:
	var bar := _make_bar()
	for i in range(ItemBar.SLOT_COUNT):
		assert_null(bar.get_slot(i), "slot %d should start empty" % i)

func test_add_item_to_empty_bar_lands_in_slot_zero() -> void:
	var bar := _make_bar()
	var data := _make_data()
	var leftover := bar.add_item(ItemInstance.create(data, 1))
	assert_null(leftover)
	assert_not_null(bar.get_slot(0))
	assert_eq(bar.get_slot(0).data, data)
	assert_eq(bar.get_slot(0).stack_count, 1)

func test_add_item_stacks_onto_existing_compatible_stack() -> void:
	var bar := _make_bar()
	var data := _make_data()
	bar.add_item(ItemInstance.create(data, 2))
	var leftover := bar.add_item(ItemInstance.create(data, 3))
	assert_null(leftover)
	assert_eq(bar.get_slot(0).stack_count, 5)
	assert_null(bar.get_slot(1), "should not have spilled into slot 1")

func test_add_item_overflows_into_next_slot_when_stack_full() -> void:
	var bar := _make_bar()
	var data := _make_data(true, 9)
	bar.add_item(ItemInstance.create(data, 7))
	# Adding 5 more: 2 fill slot 0 to its max, 3 spill into slot 1
	var leftover := bar.add_item(ItemInstance.create(data, 5))
	assert_null(leftover)
	assert_eq(bar.get_slot(0).stack_count, 9)
	assert_eq(bar.get_slot(1).stack_count, 3)

func test_non_stackable_items_each_take_their_own_slot() -> void:
	var bar := _make_bar()
	var data := _make_data(false)
	bar.add_item(ItemInstance.create(data, 1))
	bar.add_item(ItemInstance.create(data, 1))
	assert_not_null(bar.get_slot(0))
	assert_not_null(bar.get_slot(1))

func test_add_item_returns_leftover_when_bar_full() -> void:
	var bar := _make_bar()
	var data_a := _make_data(false)  # non-stackable so each takes a slot
	for i in range(ItemBar.SLOT_COUNT):
		bar.add_item(ItemInstance.create(data_a, 1))
	# Bar is full of non-stackable items; new non-stackable item has nowhere to go.
	var data_b := _make_data(false)
	var extra := ItemInstance.create(data_b, 1)
	var leftover := bar.add_item(extra)
	assert_eq(leftover, extra)
	assert_eq(leftover.stack_count, 1)

func test_add_item_partially_stacks_then_returns_leftover() -> void:
	var bar := _make_bar()
	var data := _make_data(true, 9)
	# Fill all 10 slots with stacks of 8 (= 80 capacity used, 10 capacity remaining)
	for i in range(ItemBar.SLOT_COUNT):
		bar.set_slot(i, ItemInstance.create(data, 8))
	# Try to add 25 — only 10 fit (1 unit per existing slot)
	var leftover := bar.add_item(ItemInstance.create(data, 25))
	assert_not_null(leftover)
	assert_eq(leftover.stack_count, 15)
	for i in range(ItemBar.SLOT_COUNT):
		assert_eq(bar.get_slot(i).stack_count, 9)

func test_add_item_with_null_returns_null() -> void:
	var bar := _make_bar()
	assert_null(bar.add_item(null))

func test_set_slot_replaces_contents() -> void:
	var bar := _make_bar()
	var data_a := _make_data()
	var data_b := _make_data()
	bar.set_slot(3, ItemInstance.create(data_a, 1))
	bar.set_slot(3, ItemInstance.create(data_b, 1))
	assert_eq(bar.get_slot(3).data, data_b)

func test_clear_slot_empties_a_slot() -> void:
	var bar := _make_bar()
	var data := _make_data()
	bar.set_slot(2, ItemInstance.create(data, 4))
	bar.clear_slot(2)
	assert_null(bar.get_slot(2))

func test_remove_one_decrements_stack() -> void:
	var bar := _make_bar()
	var data := _make_data()
	bar.set_slot(0, ItemInstance.create(data, 3))
	bar.remove_one(0)
	assert_eq(bar.get_slot(0).stack_count, 2)

func test_remove_one_clears_slot_when_stack_reaches_zero() -> void:
	var bar := _make_bar()
	var data := _make_data()
	bar.set_slot(0, ItemInstance.create(data, 1))
	bar.remove_one(0)
	assert_null(bar.get_slot(0))

func test_remove_one_on_empty_slot_is_noop() -> void:
	var bar := _make_bar()
	var result = bar.remove_one(5)
	assert_null(result)
	assert_null(bar.get_slot(5))

func test_inventory_changed_signal_fires_on_add_item() -> void:
	var bar := _make_bar()
	watch_signals(bar)
	bar.add_item(ItemInstance.create(_make_data(), 1))
	assert_signal_emitted(bar, "inventory_changed")

func test_inventory_changed_signal_fires_on_set_slot() -> void:
	var bar := _make_bar()
	watch_signals(bar)
	bar.set_slot(0, ItemInstance.create(_make_data(), 1))
	assert_signal_emitted(bar, "inventory_changed")

func test_inventory_changed_signal_fires_on_remove_one() -> void:
	var bar := _make_bar()
	bar.set_slot(0, ItemInstance.create(_make_data(), 2))
	watch_signals(bar)
	bar.remove_one(0)
	assert_signal_emitted(bar, "inventory_changed")

func test_get_slot_out_of_range_returns_null() -> void:
	var bar := _make_bar()
	assert_null(bar.get_slot(-1))
	assert_null(bar.get_slot(ItemBar.SLOT_COUNT))
	assert_null(bar.get_slot(999))

# -------------------------------------------------------
# pickup_from
# -------------------------------------------------------

func test_pickup_from_drains_all_items_when_bar_has_room() -> void:
	var bar := _make_bar()
	var cell := GridCell.new()
	var data := _make_data()
	cell.items.append(ItemInstance.create(data, 1))
	cell.items.append(ItemInstance.create(data, 2))
	var transferred := bar.pickup_from(cell)
	assert_eq(transferred, 3)  # 1 + 2 individual items moved
	assert_eq(cell.items.size(), 0)
	assert_not_null(bar.get_slot(0))
	assert_eq(bar.get_slot(0).stack_count, 3)

func test_pickup_from_leaves_items_when_bar_is_full() -> void:
	var bar := _make_bar()
	var data_full := _make_data(false)  # non-stackable so each takes a slot
	for i in range(ItemBar.SLOT_COUNT):
		bar.add_item(ItemInstance.create(data_full, 1))

	var cell := GridCell.new()
	var data_new := _make_data(false)
	var orphan := ItemInstance.create(data_new, 1)
	cell.items.append(orphan)
	var transferred := bar.pickup_from(cell)
	assert_eq(transferred, 0)
	assert_eq(cell.items.size(), 1)
	assert_eq(cell.items[0], orphan)

func test_pickup_from_partial_keeps_leftover_on_cell() -> void:
	# Bar holds 10 stacks of 8 (every slot used, capacity for 10 more);
	# cell has a stack of 25. 10 should transfer (filling each existing
	# stack to 9), leaving 15 on the cell.
	var bar := _make_bar()
	var data := _make_data(true, 9)
	for i in range(ItemBar.SLOT_COUNT):
		bar.set_slot(i, ItemInstance.create(data, 8))

	var cell := GridCell.new()
	cell.items.append(ItemInstance.create(data, 25))
	var transferred := bar.pickup_from(cell)
	assert_eq(transferred, 10)
	assert_eq(cell.items.size(), 1)
	assert_eq(cell.items[0].stack_count, 15)

	for i in range(ItemBar.SLOT_COUNT):
		assert_eq(bar.get_slot(i).stack_count, 9)

func test_pickup_from_partial_via_existing_stack_only() -> void:
	# Bar slot 0 has 7 of stack_max 9; the rest of the bar is full of
	# non-stackable items so no empty slot is available. Cell has a stack
	# of 5 of the same item. 2 should auto-merge into slot 0; 3 stay.
	var bar := _make_bar()
	var data := _make_data(true, 9)
	bar.set_slot(0, ItemInstance.create(data, 7))
	var blocker := _make_data(false)
	for i in range(1, ItemBar.SLOT_COUNT):
		bar.set_slot(i, ItemInstance.create(blocker, 1))

	var cell := GridCell.new()
	cell.items.append(ItemInstance.create(data, 5))
	var transferred := bar.pickup_from(cell)
	assert_eq(transferred, 2)
	assert_eq(bar.get_slot(0).stack_count, 9)
	assert_eq(cell.items.size(), 1)
	assert_eq(cell.items[0].stack_count, 3)

func test_pickup_from_empty_cell_is_noop() -> void:
	var bar := _make_bar()
	var cell := GridCell.new()
	assert_eq(bar.pickup_from(cell), 0)
	assert_eq(cell.items.size(), 0)
	for i in range(ItemBar.SLOT_COUNT):
		assert_null(bar.get_slot(i))

func test_pickup_from_null_cell_returns_zero() -> void:
	var bar := _make_bar()
	assert_eq(bar.pickup_from(null), 0)
