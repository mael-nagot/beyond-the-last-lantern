extends GutTest

# ItemDescriptionPopup is a programmatic Control built in _ready(),
# so we exercise it inside the scene tree (add_child_autofree) the
# same way LootPopup is tested.

func _make_popup() -> ItemDescriptionPopup:
	var popup := ItemDescriptionPopup.new()
	add_child_autofree(popup)
	return popup

func _make_item_data() -> ItemData:
	var data := ItemData.new()
	data.item_name = "item.health_potion.name"
	data.description = "item.health_potion.description"
	return data

# -------------------------------------------------------
# Visibility
# -------------------------------------------------------

func test_starts_hidden() -> void:
	var popup := _make_popup()
	assert_false(popup.visible)
	assert_false(popup.is_open())

func test_open_makes_visible() -> void:
	var popup := _make_popup()
	popup.open(ItemInstance.create(_make_item_data(), 1))
	assert_true(popup.visible)
	assert_true(popup.is_open())

func test_close_hides_and_clears_instance() -> void:
	var popup := _make_popup()
	popup.open(ItemInstance.create(_make_item_data(), 1))
	popup.close()
	assert_false(popup.visible)
	assert_null(popup.get_current_instance())

func test_open_with_null_instance_is_a_noop() -> void:
	var popup := _make_popup()
	popup.open(null)
	assert_false(popup.visible)

func test_open_with_dataless_instance_is_a_noop() -> void:
	var popup := _make_popup()
	var inst := ItemInstance.new()
	popup.open(inst)
	assert_false(popup.visible)

# -------------------------------------------------------
# Display content
# -------------------------------------------------------

func test_displays_translated_name_and_description() -> void:
	var popup := _make_popup()
	popup.open(ItemInstance.create(_make_item_data(), 1))
	assert_eq(popup._name_label.text, tr("item.health_potion.name"))
	assert_eq(popup._description_label.text, tr("item.health_potion.description"))

func test_uses_per_instance_icon_for_hue_shifted_keys() -> void:
	# A key with apply_hue_shift > 0 produces a baked tinted icon
	# via get_icon(); the popup must show that, not data.icon.
	var data := ItemData.new()
	data.item_name = "item.key_forest.name"
	data.description = "item.key_forest.description"
	# Build a tiny solid-colour image so the hue shift produces a
	# real ImageTexture rather than null.
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0, 0, 1))
	data.icon = ImageTexture.create_from_image(img)
	var inst := ItemInstance.create(data, 1)
	inst.apply_hue_shift(0.4)

	var popup := _make_popup()
	popup.open(inst)
	assert_eq(popup._icon.texture, inst.get_icon())
	assert_ne(popup._icon.texture, data.icon)

# -------------------------------------------------------
# Signals
# -------------------------------------------------------

func test_close_button_emits_close_requested() -> void:
	var popup := _make_popup()
	popup.open(ItemInstance.create(_make_item_data(), 1))
	watch_signals(popup)
	popup._on_close_pressed()
	assert_signal_emitted(popup, "close_requested")

func test_backdrop_click_emits_close_requested() -> void:
	var popup := _make_popup()
	popup.open(ItemInstance.create(_make_item_data(), 1))
	watch_signals(popup)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	popup._on_backdrop_input(event)
	assert_signal_emitted(popup, "close_requested")
