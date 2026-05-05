extends GutTest

func _make_data(stackable: bool = true, stack_max: int = 9) -> ItemData:
	var data := ItemData.new()
	data.item_name = "test.item.name"
	data.stackable = stackable
	data.stack_max = stack_max
	return data

func test_create_uses_supplied_data_and_count() -> void:
	var data := _make_data()
	var inst := ItemInstance.create(data, 4)
	assert_eq(inst.data, data)
	assert_eq(inst.stack_count, 4)

func test_create_defaults_to_count_one() -> void:
	var inst := ItemInstance.create(_make_data())
	assert_eq(inst.stack_count, 1)

func test_create_clamps_count_to_at_least_one() -> void:
	var inst := ItemInstance.create(_make_data(), 0)
	assert_eq(inst.stack_count, 1)
	var neg := ItemInstance.create(_make_data(), -5)
	assert_eq(neg.stack_count, 1)

func test_can_stack_with_same_data() -> void:
	var data := _make_data()
	var a := ItemInstance.create(data, 1)
	var b := ItemInstance.create(data, 1)
	assert_true(a.can_stack_with(b))

func test_cannot_stack_with_different_data() -> void:
	var a := ItemInstance.create(_make_data(), 1)
	var b := ItemInstance.create(_make_data(), 1)
	assert_false(a.can_stack_with(b))

func test_cannot_stack_when_data_is_non_stackable() -> void:
	var data := _make_data(false)
	var a := ItemInstance.create(data, 1)
	var b := ItemInstance.create(data, 1)
	assert_false(a.can_stack_with(b))

func test_cannot_stack_with_null() -> void:
	var a := ItemInstance.create(_make_data(), 1)
	assert_false(a.can_stack_with(null))

func test_cannot_stack_when_data_is_null() -> void:
	var a := ItemInstance.create(_make_data(), 1)
	var bare := ItemInstance.new()
	assert_false(a.can_stack_with(bare))
	assert_false(bare.can_stack_with(a))

func test_remaining_capacity_reflects_stack_max() -> void:
	var data := _make_data(true, 9)
	var inst := ItemInstance.create(data, 3)
	assert_eq(inst.remaining_capacity(), 6)

func test_remaining_capacity_is_zero_when_full() -> void:
	var data := _make_data(true, 5)
	var inst := ItemInstance.create(data, 5)
	assert_eq(inst.remaining_capacity(), 0)

func test_remaining_capacity_is_zero_for_non_stackable() -> void:
	var data := _make_data(false, 9)
	var inst := ItemInstance.create(data, 1)
	assert_eq(inst.remaining_capacity(), 0)

func test_remaining_capacity_is_zero_with_null_data() -> void:
	var inst := ItemInstance.new()
	assert_eq(inst.remaining_capacity(), 0)
