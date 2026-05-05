class_name HUD
extends CanvasLayer

const UI_MARGIN     = 4.0
const SCREEN_MARGIN = 4.0

@export var viewport_ratio_portrait:  float = 1.15
@export var viewport_ratio_landscape: float = 1.15
@export var min_viewport_ratio: float = 1.0

@onready var hud_root     : Control       = $HUDRoot
@onready var top_bar      : Control       = $HUDRoot/TopBar
@onready var party_panel  : Control       = $HUDRoot/PartyPanel
@onready var item_bar     : Control       = $HUDRoot/ItemBar
@onready var movement_pad : Control       = $HUDRoot/MovementPad
@onready var map_popup    : MapPopup      = $HUDRoot/MapPopup

var pickup_prompt: PickupPrompt
var map_data: MapData
var _dungeon_view: DungeonView = null

func _ready() -> void:
	pickup_prompt = PickupPrompt.new()
	pickup_prompt.name = "PickupPrompt"
	hud_root.add_child(pickup_prompt)

	get_viewport().size_changed.connect(_on_viewport_resized)
	_apply_layout()

	var btn_map = top_bar.get_node("BtnMap")
	if btn_map:
		btn_map.pressed.connect(func(): map_popup.open())

func setup_dungeon_view(dv: DungeonView) -> void:
	_dungeon_view = dv
	_apply_layout()

func setup_map(gen: LevelGenerator) -> void:
	map_data = MapData.new()
	map_data.setup(gen)
	map_popup.setup(gen, map_data)

func update_player_on_map(pos: Vector2i, facing: Vector2i) -> void:
	if map_popup:
		map_popup.update_player(pos, facing)

func _on_viewport_resized() -> void:
	_apply_layout()

func _apply_layout() -> void:
	var size = get_viewport().get_visible_rect().size
	var is_portrait = size.y > size.x

	if is_portrait:
		var ratio    = _calculate_portrait_ratio(size)
		var ui_scale = _calculate_portrait_ui_scale(size, ratio)
		if _dungeon_view:
			_dungeon_view.update_viewport_ratios(ratio, viewport_ratio_landscape)
		_layout_portrait(size, ratio, ui_scale)
	else:
		var ratio    = _calculate_landscape_ratio(size)
		var ui_scale = _calculate_landscape_ui_scale(size, ratio)
		if _dungeon_view:
			_dungeon_view.update_viewport_ratios(viewport_ratio_portrait, ratio)
		_layout_landscape(size, ratio, ui_scale)

func _calculate_portrait_ratio(size: Vector2) -> float:
	var pad_size   = movement_pad.get_minimum_size()
	var item_size  = item_bar.relayout(size.x - pad_size.x - SCREEN_MARGIN * 3)
	var party_size = party_panel.get_minimum_size()
	var PARTY_MARGIN = UI_MARGIN * 4

	var bottom_row_height = max(item_size.y, pad_size.y)
	var total_ui_height   = party_size.y + PARTY_MARGIN + bottom_row_height + SCREEN_MARGIN * 2

	var max_ratio = (size.y - total_ui_height) / size.x
	return clamp(max_ratio, min_viewport_ratio, viewport_ratio_portrait)

func _calculate_landscape_ratio(size: Vector2) -> float:
	var item_size  = item_bar.relayout(size.x * 0.4)
	var party_size = party_panel.get_minimum_size()
	var pad_size   = movement_pad.get_minimum_size()

	var total_ui_width = max(item_size.x, max(party_size.x, pad_size.x)) + SCREEN_MARGIN * 2

	var max_ratio = (size.x - total_ui_width) / size.y
	return clamp(max_ratio, min_viewport_ratio, viewport_ratio_landscape)

func _calculate_portrait_ui_scale(size: Vector2, ratio: float) -> float:
	if ratio > min_viewport_ratio:
		return 1.0

	var dungeon_height = size.x * min_viewport_ratio
	var available      = size.y - dungeon_height - SCREEN_MARGIN * 2

	var pad_size   = movement_pad.get_minimum_size()
	var item_size  = item_bar.relayout(size.x - pad_size.x - SCREEN_MARGIN * 3)
	var party_size = party_panel.get_minimum_size()
	var PARTY_MARGIN = UI_MARGIN * 4

	var bottom_row_height = max(item_size.y, pad_size.y)
	var total_ui_height   = party_size.y + PARTY_MARGIN + bottom_row_height

	if total_ui_height <= 0:
		return 1.0
	return clamp(available / total_ui_height, 0.5, 1.0)

func _calculate_landscape_ui_scale(size: Vector2, ratio: float) -> float:
	if ratio > min_viewport_ratio:
		return 1.0

	var dungeon_width = size.y * min_viewport_ratio
	var available     = size.x - dungeon_width - SCREEN_MARGIN * 2

	var item_size  = item_bar.relayout(available)
	var party_size = party_panel.get_minimum_size()
	var pad_size   = movement_pad.get_minimum_size()

	var max_width = max(item_size.x, max(party_size.x, pad_size.x))
	if max_width <= 0:
		return 1.0
	return clamp(available / max_width, 0.5, 1.0)

func _layout_landscape(size: Vector2, ratio: float, ui_scale: float = 1.0) -> void:
	var top_height = max(top_bar.get_minimum_size().y, 60)

	var dungeon_width = size.y * ratio
	var panel_x       = dungeon_width
	var panel_width   = size.x - dungeon_width

	top_bar.position = Vector2(SCREEN_MARGIN, SCREEN_MARGIN)
	top_bar.size     = Vector2(size.x - SCREEN_MARGIN * 2, top_height)

	var item_size = item_bar.relayout((panel_width - SCREEN_MARGIN * 2) * ui_scale)
	var item_x    = panel_x + (panel_width - item_size.x) * 0.5

	var party_size = party_panel.get_minimum_size() * ui_scale
	var party_x    = panel_x + (panel_width - party_size.x) * 0.5

	var pad_size = movement_pad.get_minimum_size() * ui_scale
	var pad_x    = panel_x + (panel_width - pad_size.x) * 0.5

	var total_ui_height = item_size.y + party_size.y + pad_size.y
	var available       = size.y - SCREEN_MARGIN * 2
	var spacing         = (available - total_ui_height) / 3.0
	spacing             = max(spacing, UI_MARGIN)

	var y = SCREEN_MARGIN + spacing * 0.5
	item_bar.position = Vector2(item_x, y)
	item_bar.size     = item_size

	y += item_size.y + spacing
	party_panel.position = Vector2(party_x, y)
	party_panel.size     = party_size

	y += party_size.y + spacing
	movement_pad.position = Vector2(pad_x, y)
	movement_pad.size     = pad_size

	_position_pickup_prompt(Vector2.ZERO, Vector2(dungeon_width, size.y), ui_scale)

func _layout_portrait(size: Vector2, ratio: float, ui_scale: float = 1.0) -> void:
	var top_height   = max(top_bar.get_minimum_size().y, 60)
	var PARTY_MARGIN = UI_MARGIN * 4 * ui_scale

	var dungeon_height = size.x * ratio
	var panel_y        = dungeon_height
	var panel_height   = size.y - dungeon_height

	top_bar.position = Vector2(SCREEN_MARGIN, SCREEN_MARGIN)
	top_bar.size     = Vector2(size.x - SCREEN_MARGIN * 2, top_height)

	var pad_size = movement_pad.get_minimum_size() * ui_scale

	var item_width = size.x - pad_size.x - SCREEN_MARGIN * 3
	var item_size  = item_bar.relayout(item_width)

	var party_size = party_panel.get_minimum_size() * ui_scale

	var bottom_row_height = max(item_size.y, pad_size.y)
	var total_ui_height   = party_size.y + PARTY_MARGIN + bottom_row_height

	var start_y = panel_y + (panel_height - total_ui_height) * 0.5

	var party_x = (size.x - party_size.x) * 0.5
	party_panel.position = Vector2(party_x, start_y)
	party_panel.size     = party_size

	var bottom_y = start_y + party_size.y + PARTY_MARGIN

	item_bar.position = Vector2(SCREEN_MARGIN, bottom_y + (bottom_row_height - item_size.y) * 0.5)
	item_bar.size     = item_size

	movement_pad.position = Vector2(size.x - pad_size.x - SCREEN_MARGIN, bottom_y + (bottom_row_height - pad_size.y) * 0.5)
	movement_pad.size     = pad_size

	_position_pickup_prompt(Vector2.ZERO, Vector2(size.x, dungeon_height), ui_scale)

func _position_pickup_prompt(area_pos: Vector2, area_size: Vector2, ui_scale: float) -> void:
	if pickup_prompt == null:
		return
	var short_side = min(area_size.x, area_size.y)
	var min_w = short_side * 0.30 * ui_scale
	var min_h = short_side * 0.08 * ui_scale
	pickup_prompt.custom_minimum_size = Vector2(min_w, min_h)
	pickup_prompt.size = Vector2(min_w, min_h)
	pickup_prompt.position = Vector2(
		area_pos.x + (area_size.x - min_w) * 0.5,
		area_pos.y + area_size.y - min_h - SCREEN_MARGIN * 2
	)
