extends GutTest

# LootPopup creates a full-screen modal with a backdrop, panel, slots,
# and buttons. We exercise it inside the scene tree (add_child_autofree)
# so its programmatic _ready() builds the layout.

func _make_popup() -> LootPopup:
	var popup := LootPopup.new()
	add_child_autofree(popup)
	return popup

func _make_bar() -> ItemBar:
	var bar := ItemBar.new()
	add_child_autofree(bar)
	return bar

func _make_item_data() -> ItemData:
	var data := ItemData.new()
	data.item_name = "test.item"
	data.stackable = true
	data.stack_max = 9
	return data

func _make_chest_instance(item_count: int = 1, stack_size: int = 1) -> ObjectInstance:
	var data := ObjectData.new()
	data.category = ObjectData.Category.CHEST
	data.name_key = "object.chest_wooden.name"
	var inst := ObjectInstance.create(data)
	var item_data := _make_item_data()
	for i in range(item_count):
		inst.items.append(ItemInstance.create(item_data, stack_size))
	return inst

# -------------------------------------------------------
# Visibility
# -------------------------------------------------------

func test_starts_hidden() -> void:
	var popup := _make_popup()
	assert_false(popup.visible)

func test_open_makes_visible() -> void:
	var popup := _make_popup()
	popup.setup(_make_bar())
	popup.open(_make_chest_instance(2))
	assert_true(popup.visible)
	assert_true(popup.is_open())

func test_close_hides_and_clears_instance() -> void:
	var popup := _make_popup()
	popup.setup(_make_bar())
	popup.open(_make_chest_instance(1))
	popup.close()
	assert_false(popup.visible)
	assert_null(popup._instance)

# -------------------------------------------------------
# Title resolution
# -------------------------------------------------------

func test_title_uses_object_name_key_when_set() -> void:
	var popup := _make_popup()
	popup.setup(_make_bar())
	popup.open(_make_chest_instance(1))
	assert_eq(popup._title_label.text, "Wooden Chest")

func test_title_falls_back_to_generic_when_object_has_no_name() -> void:
	var popup := _make_popup()
	popup.setup(_make_bar())
	var data := ObjectData.new()
	data.name_key = ""
	var inst := ObjectInstance.create(data)
	inst.items.append(ItemInstance.create(_make_item_data(), 1))
	popup.open(inst)
	assert_eq(popup._title_label.text, tr(LootPopup.TITLE_KEY))

# -------------------------------------------------------
# Take All gating via would_fit_all
# -------------------------------------------------------

func test_take_all_enabled_when_bar_can_fit_everything() -> void:
	var popup := _make_popup()
	popup.setup(_make_bar())
	popup.open(_make_chest_instance(1))
	assert_false(popup._take_all_button.disabled)

func test_take_all_disabled_when_bar_is_full() -> void:
	var popup := _make_popup()
	var bar := _make_bar()
	# Fill every slot with non-stackable items so nothing else fits.
	var blocker := ItemData.new()
	blocker.stackable = false
	for i in range(ItemBar.SLOT_COUNT):
		bar.set_slot(i, ItemInstance.create(blocker, 1))
	popup.setup(bar)
	popup.open(_make_chest_instance(1))
	assert_true(popup._take_all_button.disabled)

# -------------------------------------------------------
# Signals
# -------------------------------------------------------

func test_close_button_emits_close_requested() -> void:
	var popup := _make_popup()
	popup.setup(_make_bar())
	popup.open(_make_chest_instance(1))
	watch_signals(popup)
	popup._on_close_pressed()
	assert_signal_emitted(popup, "close_requested")

func test_take_all_emits_take_all_requested() -> void:
	var popup := _make_popup()
	popup.setup(_make_bar())
	popup.open(_make_chest_instance(1))
	watch_signals(popup)
	popup._on_take_all_pressed()
	assert_signal_emitted(popup, "take_all_requested")

func test_slot_press_emits_item_taken_with_index() -> void:
	var popup := _make_popup()
	popup.setup(_make_bar())
	popup.open(_make_chest_instance(3))
	watch_signals(popup)
	popup._on_slot_pressed(2)
	assert_signal_emitted_with_parameters(popup, "item_taken", [2])
