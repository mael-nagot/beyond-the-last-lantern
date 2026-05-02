class_name ItemBar
extends HBoxContainer

const SLOT_COUNT   = 10
const SLOT_SPACING = 4

signal slot_clicked(index: int)

var _slots: Array = []

func _ready() -> void:
	add_theme_constant_override("separation", SLOT_SPACING)

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

	get_viewport().size_changed.connect(_resize_slots)
	_resize_slots()

func _resize_slots() -> void:
	var screen          = get_viewport().get_visible_rect().size
	var short_side      = min(screen.x, screen.y)
	var total_spacing   = SLOT_SPACING * (SLOT_COUNT - 1)
	var slot_size       = floor((screen.x - total_spacing) / SLOT_COUNT)
	slot_size           = clamp(slot_size, short_side * 0.06, short_side * 0.10)

	for entry in _slots:
		entry["panel"].custom_minimum_size = Vector2(slot_size, slot_size)

func set_slot_icon(index: int, icon: Texture2D) -> void:
	if index >= 0 and index < _slots.size():
		_slots[index]["button"].texture_normal = icon
