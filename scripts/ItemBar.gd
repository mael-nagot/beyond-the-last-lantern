class_name ItemBar
extends HBoxContainer

const SLOT_COUNT = 10
const SLOT_SIZE  = 64

signal slot_clicked(index: int)

var _slots: Array = []

func _ready() -> void:
	for i in range(SLOT_COUNT):
		var slot = Panel.new()
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)

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
		_slots.append(btn)

func set_slot_icon(index: int, icon: Texture2D) -> void:
	if index >= 0 and index < _slots.size():
		_slots[index].texture_normal = icon
