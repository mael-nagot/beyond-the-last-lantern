class_name HUD
extends CanvasLayer

const UI_MARGIN     = 4.0
const SCREEN_MARGIN = 4.0

@onready var hud_root     : Control       = $HUDRoot
@onready var top_bar      : Control       = $HUDRoot/TopBar
@onready var party_panel  : Control       = $HUDRoot/PartyPanel
@onready var item_bar     : Control       = $HUDRoot/ItemBar
@onready var movement_pad : Control       = $HUDRoot/MovementPad
@onready var map_popup    : MapPopup      = $HUDRoot/MapPopup

var map_data: MapData

func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_resized)
	_apply_layout()

	# Wire map button
	var btn_map = top_bar.get_node("BtnMap")
	if btn_map:
		btn_map.pressed.connect(func(): map_popup.open())

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
		_layout_portrait(size)
	else:
		_layout_landscape(size)

func _layout_landscape(size: Vector2) -> void:
	var pad_size   = movement_pad.get_minimum_size()
	var party_size = party_panel.get_minimum_size()
	var top_height = max(top_bar.get_minimum_size().y, 60)

	var item_size  = item_bar.relayout(size.x - SCREEN_MARGIN * 2)

	var bottom_row  = max(party_size.y, pad_size.y)
	var total       = bottom_row + item_size.y + UI_MARGIN
	var available   = size.y - top_height
	var scale       = min(1.0, available / total)
	var s_item_h    = item_size.y * scale
	var s_bottom    = bottom_row * scale

	top_bar.position = Vector2(SCREEN_MARGIN, SCREEN_MARGIN)
	top_bar.size     = Vector2(size.x - SCREEN_MARGIN * 2, top_height)

	item_bar.position = Vector2(size.x * 0.5 - item_size.x * 0.5, size.y - s_item_h - SCREEN_MARGIN)
	item_bar.size     = item_size

	movement_pad.position = Vector2(size.x - pad_size.x - SCREEN_MARGIN, size.y - s_item_h - UI_MARGIN - s_bottom - SCREEN_MARGIN)
	movement_pad.size     = Vector2(pad_size.x, s_bottom)

	party_panel.position = Vector2(SCREEN_MARGIN, size.y - s_item_h - UI_MARGIN - party_panel.get_minimum_size().y - SCREEN_MARGIN)
	party_panel.size     = Vector2(size.x - pad_size.x - SCREEN_MARGIN * 2, party_panel.get_minimum_size().y)

func _layout_portrait(size: Vector2) -> void:
	var pad_size   = movement_pad.get_minimum_size()
	var top_height = max(top_bar.get_minimum_size().y, 60)

	top_bar.position = Vector2(SCREEN_MARGIN, SCREEN_MARGIN)
	top_bar.size     = Vector2(size.x - SCREEN_MARGIN * 2, top_height)

	movement_pad.position = Vector2(size.x - pad_size.x - SCREEN_MARGIN, size.y - pad_size.y - SCREEN_MARGIN)
	movement_pad.size     = pad_size

	var item_width = size.x - pad_size.x - SCREEN_MARGIN * 2
	var item_size  = item_bar.relayout(item_width)

	item_bar.position = Vector2(SCREEN_MARGIN, size.y - pad_size.y - SCREEN_MARGIN)
	item_bar.size     = item_size

	var bottom_height = max(pad_size.y, item_size.y)
	party_panel.position = Vector2(SCREEN_MARGIN, size.y - bottom_height - party_panel.get_minimum_size().y - UI_MARGIN - SCREEN_MARGIN)
	party_panel.size     = Vector2(size.x - SCREEN_MARGIN * 2, party_panel.get_minimum_size().y)
