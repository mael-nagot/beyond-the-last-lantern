extends GutTest

const CHARACTER_SLOT_SCENE := preload("res://scenes/CharacterSlot.tscn")

func _make_slot() -> CharacterSlot:
	var slot: CharacterSlot = CHARACTER_SLOT_SCENE.instantiate()
	add_child_autofree(slot)
	return slot

func _make_potion(effect: int = ItemData.EffectType.HEAL_HP, value: int = 30) -> ItemData:
	var data := ItemData.new()
	data.item_name = "test.potion"
	data.effect_type = effect
	data.effect_value = value
	return data

func _make_drag_data(slot_index: int, item_data: ItemData) -> Dictionary:
	return {
		"type": ItemSlotButton.DRAG_TYPE,
		"slot_index": slot_index,
		"instance": ItemInstance.create(item_data, 1),
	}

# -------------------------------------------------------
# bind() and live updates
# -------------------------------------------------------

func test_bind_pushes_initial_hp_to_bar() -> void:
	var slot := _make_slot()
	var c := Character.create("x", 30)
	c.damage(10)
	slot.bind(c)
	assert_eq(slot.hp_bar.value, 20.0)
	assert_eq(slot.hp_bar.max_value, 30.0)

func test_bind_pushes_initial_mp_to_bar() -> void:
	var slot := _make_slot()
	var c := Character.create("x", 30, 25)
	c.current_mp = 7
	slot.bind(c)
	assert_eq(slot.mp_bar.value, 7.0)
	assert_eq(slot.mp_bar.max_value, 25.0)

func test_bind_updates_name_label() -> void:
	var slot := _make_slot()
	var c := Character.create("character.placeholder.warrior", 30)
	slot.bind(c)
	assert_eq(slot.name_label.text, "Warrior")

func test_changes_to_character_propagate_to_bar() -> void:
	var slot := _make_slot()
	var c := Character.create("x", 30)
	slot.bind(c)
	c.damage(12)
	assert_eq(slot.hp_bar.value, 18.0)

func test_rebind_disconnects_old_character() -> void:
	var slot := _make_slot()
	var first := Character.create("x", 30)
	slot.bind(first)
	var second := Character.create("y", 50)
	slot.bind(second)
	# First's signal must no longer drive the bar
	first.damage(5)
	assert_eq(slot.hp_bar.value, 50.0)
	assert_eq(slot.hp_bar.max_value, 50.0)

# -------------------------------------------------------
# _can_drop_data
# -------------------------------------------------------

func test_can_drop_false_with_no_character_bound() -> void:
	var slot := _make_slot()
	var data := _make_drag_data(0, _make_potion())
	assert_false(slot._can_drop_data(Vector2.ZERO, data))

func test_can_drop_false_for_non_dictionary_payload() -> void:
	var slot := _make_slot()
	slot.bind(Character.create("x", 30))
	assert_false(slot._can_drop_data(Vector2.ZERO, "not a dict"))

func test_can_drop_false_for_wrong_payload_type() -> void:
	var slot := _make_slot()
	slot.bind(Character.create("x", 30))
	assert_false(slot._can_drop_data(Vector2.ZERO, {"type": "wrong"}))

func test_can_drop_false_when_character_already_full_hp() -> void:
	var slot := _make_slot()
	slot.bind(Character.create("x", 30))
	var data := _make_drag_data(0, _make_potion())
	assert_false(slot._can_drop_data(Vector2.ZERO, data))

func test_can_drop_true_when_heal_potion_helps() -> void:
	var slot := _make_slot()
	var c := Character.create("x", 30)
	c.damage(10)
	slot.bind(c)
	var data := _make_drag_data(0, _make_potion())
	assert_true(slot._can_drop_data(Vector2.ZERO, data))

func test_can_drop_false_for_unsupported_effect() -> void:
	var slot := _make_slot()
	var c := Character.create("x", 30)
	c.damage(10)
	slot.bind(c)
	var data := _make_drag_data(0, _make_potion(ItemData.EffectType.DAMAGE, 30))
	assert_false(slot._can_drop_data(Vector2.ZERO, data))

# -------------------------------------------------------
# _drop_data
# -------------------------------------------------------

func test_drop_applies_effect_and_emits_consumed() -> void:
	var slot := _make_slot()
	var c := Character.create("x", 30)
	c.damage(10)
	slot.bind(c)
	watch_signals(slot)
	var data := _make_drag_data(3, _make_potion(ItemData.EffectType.HEAL_HP, 5))
	slot._drop_data(Vector2.ZERO, data)
	assert_eq(c.current_hp, 25)
	assert_signal_emitted_with_parameters(slot, "item_consumed", [3])

func test_drop_at_full_hp_emits_rejected_and_does_not_change_hp() -> void:
	var slot := _make_slot()
	var c := Character.create("x", 30)
	slot.bind(c)
	watch_signals(slot)
	var data := _make_drag_data(2, _make_potion(ItemData.EffectType.HEAL_HP, 5))
	slot._drop_data(Vector2.ZERO, data)
	assert_eq(c.current_hp, 30)
	assert_signal_emitted_with_parameters(slot, "item_rejected", [2])

func test_drop_with_null_character_emits_rejected() -> void:
	var slot := _make_slot()
	watch_signals(slot)
	var data := _make_drag_data(1, _make_potion())
	slot._drop_data(Vector2.ZERO, data)
	assert_signal_emitted(slot, "item_rejected")

# -------------------------------------------------------
# Mouse filter regression: drops on the slot's portrait, bars, name, and
# gaps should bubble up to _can_drop_data; drops on the action buttons
# should be rejected on the spot. If any of these flip we silently break
# the drag-drop UX, so guard them.
# -------------------------------------------------------

func test_slot_itself_is_stop_so_gaps_accept_drops() -> void:
	var slot := _make_slot()
	assert_eq(slot.mouse_filter, Control.MOUSE_FILTER_STOP)

func test_portrait_is_pass_so_drops_bubble_up() -> void:
	var slot := _make_slot()
	assert_eq(slot.portrait.mouse_filter, Control.MOUSE_FILTER_PASS)
	assert_eq(slot.portrait_frame.mouse_filter, Control.MOUSE_FILTER_PASS)

func test_bars_are_pass_so_drops_bubble_up() -> void:
	var slot := _make_slot()
	assert_eq(slot.hp_bar.mouse_filter, Control.MOUSE_FILTER_PASS)
	assert_eq(slot.mp_bar.mouse_filter, Control.MOUSE_FILTER_PASS)

func test_name_label_is_pass_so_drops_bubble_up() -> void:
	var slot := _make_slot()
	assert_eq(slot.name_label.mouse_filter, Control.MOUSE_FILTER_PASS)

func test_action_buttons_remain_stop_so_drops_are_rejected_there() -> void:
	var slot := _make_slot()
	assert_eq(slot.btn_attack.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(slot.btn_spell.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(slot.btn_defense.mouse_filter, Control.MOUSE_FILTER_STOP)
