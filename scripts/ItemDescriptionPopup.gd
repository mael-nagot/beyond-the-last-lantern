class_name ItemDescriptionPopup
extends Control

# Single-tap a populated bar slot to peek at the item's name and
# description with the per-instance icon (so visually-identical keys
# with different lock_ids still differentiate via their hue tint).
# Drag still wins over tap — the existing drag-to-use / drag-to-drop
# flows are unaffected because TextureButton.pressed only fires on a
# complete click cycle, not when a drag preempts it.

signal close_requested

var _instance: ItemInstance = null

var _backdrop: ColorRect
var _panel: Panel
var _icon: TextureRect
var _name_label: Label
var _description_label: Label
var _close_button: Button

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_layout()
	get_viewport().size_changed.connect(_on_viewport_resized)

func open(instance: ItemInstance) -> void:
	if instance == null or instance.data == null:
		return
	_instance = instance
	visible = true
	_refresh()

func close() -> void:
	visible = false
	_instance = null

func is_open() -> bool:
	return visible

func get_current_instance() -> ItemInstance:
	return _instance

# -------------------------------------------------------
# Construction
# -------------------------------------------------------

func _build_layout() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.gui_input.connect(_on_backdrop_input)
	add_child(_backdrop)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_panel = Panel.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.08, 0.06, 0.96)
	style.border_color = Color(0.85, 0.75, 0.55, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_icon)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.78))
	_panel.add_child(_name_label)

	_description_label = Label.new()
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_description_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.70))
	_panel.add_child(_description_label)

	_close_button = Button.new()
	_close_button.text = "✕"
	_close_button.pressed.connect(_on_close_pressed)
	_panel.add_child(_close_button)

func _on_viewport_resized() -> void:
	if visible:
		_layout()

func _refresh() -> void:
	_layout()
	if _instance == null or _instance.data == null:
		return
	_icon.texture = _instance.get_icon()
	_name_label.text = _instance.data.get_display_name()
	_description_label.text = _instance.data.get_display_description()

func _layout() -> void:
	var screen := get_viewport().get_visible_rect().size
	var short_side: float = min(screen.x, screen.y)
	var panel_w: float = short_side * 0.62
	var panel_h: float = short_side * 0.58
	_panel.size = Vector2(panel_w, panel_h)
	_panel.position = Vector2((screen.x - panel_w) * 0.5, (screen.y - panel_h) * 0.5)

	var pad: float = short_side * 0.025
	var close_size: float = short_side * 0.06

	_close_button.size = Vector2(close_size, close_size)
	_close_button.position = Vector2(panel_w - close_size - pad * 0.5, pad * 0.5)
	_close_button.add_theme_font_size_override("font_size", int(short_side * 0.035))

	var icon_size: float = short_side * 0.20
	_icon.size = Vector2(icon_size, icon_size)
	_icon.position = Vector2((panel_w - icon_size) * 0.5, pad + close_size * 0.25)

	var name_y: float = _icon.position.y + icon_size + pad * 0.5
	var name_h: float = short_side * 0.06
	_name_label.size = Vector2(panel_w - pad * 2, name_h)
	_name_label.position = Vector2(pad, name_y)
	_name_label.add_theme_font_size_override("font_size", int(short_side * 0.045))

	var desc_y: float = name_y + name_h + pad * 0.4
	var desc_h: float = panel_h - desc_y - pad
	_description_label.size = Vector2(panel_w - pad * 2, desc_h)
	_description_label.position = Vector2(pad, desc_y)
	_description_label.add_theme_font_size_override("font_size", int(short_side * 0.03))

# -------------------------------------------------------
# Input
# -------------------------------------------------------

func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_requested.emit()

func _on_close_pressed() -> void:
	close_requested.emit()
