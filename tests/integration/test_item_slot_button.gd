extends GutTest

# ItemSlotButton._get_drag_data calls set_drag_preview which needs the
# button to be in the scene tree. Build a real ItemBar and exercise the
# button it created at slot N.

func _make_data() -> ItemData:
	var data := ItemData.new()
	data.item_name = "test.item"
	data.stackable = true
	data.stack_max = 9
	# Tiny placeholder texture so set_drag_preview has something to work with
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0, 0, 1))
	data.icon = ImageTexture.create_from_image(img)
	return data

func _make_bar() -> ItemBar:
	var bar := ItemBar.new()
	add_child_autofree(bar)
	return bar

func _slot_button(bar: ItemBar, index: int) -> ItemSlotButton:
	return bar._slots[index]["button"] as ItemSlotButton

# -------------------------------------------------------
# Bar wiring: ItemBar must hand each button its index + bar_ref so the
# button can fetch its own contents at drag time.
# -------------------------------------------------------

func test_bar_creates_item_slot_buttons() -> void:
	var bar := _make_bar()
	for i in range(ItemBar.SLOT_COUNT):
		var btn := _slot_button(bar, i)
		assert_not_null(btn)

func test_each_button_has_its_index_and_bar_ref() -> void:
	var bar := _make_bar()
	for i in range(ItemBar.SLOT_COUNT):
		var btn := _slot_button(bar, i)
		assert_eq(btn.slot_index, i)
		assert_eq(btn.bar_ref, bar)

# -------------------------------------------------------
# _get_drag_data
# -------------------------------------------------------

func test_get_drag_data_returns_null_for_empty_slot() -> void:
	var bar := _make_bar()
	var btn := _slot_button(bar, 0)
	assert_null(btn._get_drag_data(Vector2.ZERO))

func test_get_drag_data_returns_null_when_bar_ref_missing() -> void:
	var btn := ItemSlotButton.new()
	add_child_autofree(btn)
	btn.slot_index = 0
	# bar_ref intentionally left null
	assert_null(btn._get_drag_data(Vector2.ZERO))

func test_build_drag_payload_returns_data_when_slot_has_item() -> void:
	# We don't call _get_drag_data() here because set_drag_preview() asserts
	# that a real drag is in progress, which it isn't in a unit test.
	# The null-return cases for _get_drag_data are covered above; this test
	# verifies the payload shape when the slot is populated.
	var bar := _make_bar()
	var data := _make_data()
	var instance := ItemInstance.create(data, 3)
	bar.set_slot(0, instance)
	var btn := _slot_button(bar, 0)

	var payload := btn.build_drag_payload()
	assert_false(payload.is_empty())
	assert_eq(payload["type"], ItemSlotButton.DRAG_TYPE)
	assert_eq(payload["slot_index"], 0)
	assert_eq(payload["instance"], instance)

func test_drag_type_constant_is_stable() -> void:
	# Other classes (DungeonDropTarget, CharacterSlot) compare against
	# ItemSlotButton.DRAG_TYPE — guard the constant so a rename doesn't
	# silently break drop validation everywhere.
	assert_eq(ItemSlotButton.DRAG_TYPE, "item")
