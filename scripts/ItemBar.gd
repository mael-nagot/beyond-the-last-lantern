class_name ItemBar
extends Container

const SLOT_COUNT   = 10
const SLOT_SPACING = 4

signal slot_clicked(index: int)
signal inventory_changed

var _slots: Array = []
var _inventory: Array[ItemInstance] = []

func _ready() -> void:
	_inventory.resize(SLOT_COUNT)
	for i in range(SLOT_COUNT):
		var slot = Panel.new()

		var style = StyleBoxFlat.new()
		style.bg_color       = Color(0.0, 0.0, 0.0, 0.3)
		style.border_color   = Color(1.0, 1.0, 1.0, 0.2)
		style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		slot.add_theme_stylebox_override("panel", style)

		var btn = TextureButton.new()
		btn.mouse_filter      = Control.MOUSE_FILTER_STOP
		btn.ignore_texture_size = true
		btn.stretch_mode      = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		var index = i
		btn.pressed.connect(func(): slot_clicked.emit(index))
		slot.add_child(btn)
		btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

		var count_label = Label.new()
		count_label.text = ""
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.vertical_alignment   = VERTICAL_ALIGNMENT_BOTTOM
		count_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		count_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		count_label.add_theme_constant_override("outline_size", 4)
		slot.add_child(count_label)
		count_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)

		add_child(slot)
		_slots.append({"panel": slot, "button": btn, "label": count_label})

func relayout(available_width: float) -> Vector2:
	var screen      = get_viewport().get_visible_rect().size
	var short_side  = min(screen.x, screen.y)

	var columns = 5
	var rows    = 2

	var slot_size = floor((available_width - SLOT_SPACING * (columns - 1)) / columns)
	var min_size  = short_side * 0.06
	var max_size  = short_side * 0.12
	slot_size     = clamp(slot_size, min_size, max_size)

	var label_font_size = int(max(10.0, slot_size * 0.30))

	for i in range(_slots.size()):
		var col = i % columns
		var row = i / columns
		var slot_panel = _slots[i]["panel"]
		slot_panel.custom_minimum_size = Vector2(slot_size, slot_size)
		slot_panel.position = Vector2(
			col * (slot_size + SLOT_SPACING),
			row * (slot_size + SLOT_SPACING)
		)
		slot_panel.size = Vector2(slot_size, slot_size)

		var label: Label = _slots[i]["label"]
		label.add_theme_font_size_override("font_size", label_font_size)
		var label_w = slot_size * 0.6
		var label_h = slot_size * 0.4
		label.position = Vector2(slot_size - label_w - 2, slot_size - label_h - 1)
		label.size = Vector2(label_w, label_h)

	var total_size = Vector2(
		columns * slot_size + (columns - 1) * SLOT_SPACING,
		rows * slot_size + (rows - 1) * SLOT_SPACING
	)
	custom_minimum_size = total_size
	return total_size

# -------------------------------------------------------
# Inventory model
# -------------------------------------------------------
func get_slot(index: int) -> ItemInstance:
	if index < 0 or index >= _inventory.size():
		return null
	return _inventory[index]

func set_slot(index: int, instance: ItemInstance) -> void:
	if index < 0 or index >= _inventory.size():
		push_error("ItemBar.set_slot: index %d out of range" % index)
		return
	_inventory[index] = instance
	_refresh_slot(index)
	inventory_changed.emit()

func clear_slot(index: int) -> void:
	set_slot(index, null)

func remove_one(index: int) -> ItemInstance:
	var inst := get_slot(index)
	if inst == null:
		return null
	inst.stack_count -= 1
	if inst.stack_count <= 0:
		_inventory[index] = null
	_refresh_slot(index)
	inventory_changed.emit()
	return inst

# Returns the leftover instance if the bar is full, otherwise null.
# Auto-stacks onto existing matching stacks first, then fills empty slots.
func add_item(instance: ItemInstance) -> ItemInstance:
	if instance == null or instance.data == null:
		return null

	if instance.data.stackable:
		for i in range(_inventory.size()):
			var existing = _inventory[i]
			if existing != null and existing.can_stack_with(instance):
				var room = existing.remaining_capacity()
				if room <= 0:
					continue
				var moved = min(room, instance.stack_count)
				existing.stack_count += moved
				instance.stack_count -= moved
				_refresh_slot(i)
				if instance.stack_count <= 0:
					inventory_changed.emit()
					return null

	for i in range(_inventory.size()):
		if _inventory[i] == null:
			_inventory[i] = instance
			_refresh_slot(i)
			inventory_changed.emit()
			return null

	inventory_changed.emit()
	return instance

func _refresh_slot(index: int) -> void:
	if index < 0 or index >= _slots.size():
		return
	var inst: ItemInstance = _inventory[index]
	var btn: TextureButton = _slots[index]["button"]
	var label: Label       = _slots[index]["label"]
	if inst == null or inst.data == null:
		btn.texture_normal = null
		label.text = ""
		return
	btn.texture_normal = inst.data.icon
	if inst.data.stackable and inst.stack_count > 1:
		label.text = str(inst.stack_count)
	else:
		label.text = ""
