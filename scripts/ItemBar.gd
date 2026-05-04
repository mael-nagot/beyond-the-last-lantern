class_name ItemBar
extends Container

const SLOT_COUNT   = 10
const SLOT_SPACING = 4

signal slot_clicked(index: int)

var _slots: Array = []

func _ready() -> void:
	for i in range(SLOT_COUNT):
		var slot = Panel.new()

		var style = StyleBoxFlat.new()
		style.bg_color       = Color(0.0, 0.0, 0.0, 0.3)
		style.border_color   = Color(1.0, 1.0, 1.0, 0.2)
		style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		slot.add_theme_stylebox_override("panel", style)

		var btn = TextureButton.new()
		btn.anchors_preset  = Control.PRESET_FULL_RECT
		btn.mouse_filter    = Control.MOUSE_FILTER_STOP
		var index = i
		btn.pressed.connect(func(): slot_clicked.emit(index))
		slot.add_child(btn)

		add_child(slot)
		_slots.append({"panel": slot, "button": btn})

func relayout(available_width: float) -> Vector2:
	var screen      = get_viewport().get_visible_rect().size
	var short_side  = min(screen.x, screen.y)

	var columns = 5
	var rows    = 2

	var slot_size = floor((available_width - SLOT_SPACING * (columns - 1)) / columns)
	var min_size  = short_side * 0.06
	var max_size  = short_side * 0.12
	slot_size     = clamp(slot_size, min_size, max_size)

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

	var total_size = Vector2(
		columns * slot_size + (columns - 1) * SLOT_SPACING,
		rows * slot_size + (rows - 1) * SLOT_SPACING
	)
	custom_minimum_size = total_size
	return total_size

func set_slot_icon(index: int, icon: Texture2D) -> void:
	if index >= 0 and index < _slots.size():
		_slots[index]["button"].texture_normal = icon
