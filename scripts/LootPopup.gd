class_name LootPopup
extends Control

# Full-screen modal that shows a chest's current contents. Click a slot
# to take that single ItemInstance into the bar; "Take All" transfers
# everything (only enabled when the dry-run says it'll all fit). Items
# that don't fit stay on the ObjectInstance so the player can come back.

const TITLE_KEY     := "ui.loot.title_chest"
const TAKE_ALL_KEY  := "ui.loot.take_all"
const SLOT_COLUMNS  := 4

signal item_taken(slot_index: int)
signal take_all_requested
signal close_requested

var _instance: ObjectInstance = null
var _bar: ItemBar = null

var _backdrop: ColorRect
var _panel: Panel
var _title_label: Label
var _grid: GridContainer
var _take_all_button: Button
var _close_button: Button
var _slot_panels: Array[Panel] = []

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_layout()

func setup(item_bar: ItemBar) -> void:
	# Lets the popup ask the bar whether a "take all" would actually fit
	# without modifying anything. Set once at HUD setup time.
	_bar = item_bar

func open(instance: ObjectInstance) -> void:
	_instance = instance
	visible = true
	_refresh()

func close() -> void:
	visible = false
	_instance = null

func is_open() -> bool:
	return visible

func get_current_instance() -> ObjectInstance:
	return _instance

func refresh() -> void:
	_refresh()

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

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.78))
	_panel.add_child(_title_label)

	_close_button = Button.new()
	_close_button.text = "✕"
	_close_button.pressed.connect(_on_close_pressed)
	_panel.add_child(_close_button)

	_grid = GridContainer.new()
	_grid.columns = SLOT_COLUMNS
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	_panel.add_child(_grid)

	_take_all_button = Button.new()
	_take_all_button.pressed.connect(_on_take_all_pressed)
	_panel.add_child(_take_all_button)

func _on_viewport_resized() -> void:
	_layout()

func _refresh() -> void:
	_layout()
	if _instance == null:
		return
	_title_label.text = _resolve_title()
	_take_all_button.text = tr(TAKE_ALL_KEY)
	_take_all_button.disabled = not _can_take_all()
	_rebuild_slots()

func _resolve_title() -> String:
	if _instance != null and _instance.data != null and _instance.data.name_key != "":
		return _instance.data.get_display_name()
	return tr(TITLE_KEY)

func _can_take_all() -> bool:
	if _instance == null or _bar == null:
		return false
	if _instance.items.is_empty():
		return false
	return _bar.would_fit_all(_instance.items)

func _rebuild_slots() -> void:
	for panel in _slot_panels:
		panel.queue_free()
	_slot_panels.clear()
	if _instance == null:
		return

	var screen := get_viewport().get_visible_rect().size
	var short_side: float = min(screen.x, screen.y)
	var slot_size: float  = short_side * 0.10

	for i in range(_instance.items.size()):
		var inst: ItemInstance = _instance.items[i]
		if inst == null or inst.data == null:
			continue
		var slot := _make_slot(inst, slot_size, i)
		_grid.add_child(slot)
		_slot_panels.append(slot)

func _make_slot(inst: ItemInstance, slot_size: float, slot_index: int) -> Panel:
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(slot_size, slot_size)
	slot.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0, 0, 0, 0.35)
	style.border_color = Color(1, 1, 1, 0.18)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	slot.add_theme_stylebox_override("panel", style)

	var btn := TextureButton.new()
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.texture_normal = inst.data.icon
	# Per-instance tint (Color.WHITE = no visible tint). Keys for
	# different locks share a .tres but get slightly different
	# tints so the player can tell them apart visually.
	btn.modulate = inst.tint
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.pressed.connect(_on_slot_pressed.bind(slot_index))
	slot.add_child(btn)
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	if inst.data.stackable and inst.stack_count > 1:
		var label := Label.new()
		label.text = str(inst.stack_count)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		label.add_theme_constant_override("outline_size", 4)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(label)
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	return slot

# -------------------------------------------------------
# Layout
# -------------------------------------------------------

func _layout() -> void:
	var screen := get_viewport().get_visible_rect().size
	var short_side: float = min(screen.x, screen.y)
	var panel_w: float = short_side * 0.78
	var panel_h: float = short_side * 0.66
	_panel.size = Vector2(panel_w, panel_h)
	_panel.position = Vector2((screen.x - panel_w) * 0.5, (screen.y - panel_h) * 0.5)

	var pad: float = short_side * 0.025
	var title_h: float = short_side * 0.06
	var btn_h: float = short_side * 0.07

	_title_label.add_theme_font_size_override("font_size", int(short_side * 0.04))
	_title_label.position = Vector2(pad, pad)
	_title_label.size = Vector2(panel_w - pad * 2, title_h)

	_close_button.size = Vector2(short_side * 0.06, short_side * 0.06)
	_close_button.position = Vector2(panel_w - _close_button.size.x - pad * 0.5, pad * 0.5)
	_close_button.add_theme_font_size_override("font_size", int(short_side * 0.035))

	var grid_y: float = pad + title_h + pad * 0.5
	var grid_h: float = panel_h - grid_y - btn_h - pad * 1.5
	_grid.position = Vector2(pad, grid_y)
	_grid.size = Vector2(panel_w - pad * 2, grid_h)

	_take_all_button.size = Vector2(short_side * 0.30, btn_h)
	_take_all_button.position = Vector2(
		(panel_w - _take_all_button.size.x) * 0.5,
		panel_h - btn_h - pad * 0.5
	)
	_take_all_button.add_theme_font_size_override("font_size", int(short_side * 0.03))

# -------------------------------------------------------
# Input
# -------------------------------------------------------

func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_requested.emit()

func _on_close_pressed() -> void:
	close_requested.emit()

func _on_slot_pressed(slot_index: int) -> void:
	item_taken.emit(slot_index)

func _on_take_all_pressed() -> void:
	take_all_requested.emit()
