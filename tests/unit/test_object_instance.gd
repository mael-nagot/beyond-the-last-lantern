extends GutTest

func _make_data(category: int = ObjectData.Category.CHEST) -> ObjectData:
	var data := ObjectData.new()
	data.category = category
	return data

func test_create_sets_data_and_clean_state() -> void:
	var data := _make_data()
	var inst := ObjectInstance.create(data)
	assert_eq(inst.data, data)
	assert_false(inst.opened)
	assert_eq(inst.items.size(), 0)
	assert_null(inst.loot_table)

func test_is_chest_true_when_category_is_chest() -> void:
	var inst := ObjectInstance.create(_make_data(ObjectData.Category.CHEST))
	assert_true(inst.is_chest())

func test_is_chest_false_for_other_categories() -> void:
	for category in [
		ObjectData.Category.DOOR,
		ObjectData.Category.LEVER,
		ObjectData.Category.TRAP,
		ObjectData.Category.CAMPFIRE,
		ObjectData.Category.DECORATION,
	]:
		var inst := ObjectInstance.create(_make_data(category))
		assert_false(inst.is_chest(), "category %d should not be a chest" % category)

func test_is_chest_false_when_data_is_null() -> void:
	var inst := ObjectInstance.new()
	assert_false(inst.is_chest())

func test_has_remaining_loot_reflects_items_array() -> void:
	var inst := ObjectInstance.create(_make_data())
	assert_false(inst.has_remaining_loot())
	var item_data := ItemData.new()
	inst.items.append(ItemInstance.create(item_data, 1))
	assert_true(inst.has_remaining_loot())
	inst.items.clear()
	assert_false(inst.has_remaining_loot())
