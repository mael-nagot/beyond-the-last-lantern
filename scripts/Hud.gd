class_name HUD
extends CanvasLayer

@onready var hud_root      : Control         = $HUDRoot
@onready var top_bar       : Control         = $HUDRoot/TopBar

@onready var party_panel   : Control         = $HUDRoot/PartyPanel
@onready var item_bar      : Control         = $HUDRoot/ItemBar
@onready var movement_pad  : Control         = $HUDRoot/MovementPad

func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_resized)
	_apply_layout()

func _on_viewport_resized() -> void:
	_apply_layout()

func _apply_layout() -> void:
	var size = get_viewport().get_visible_rect().size
	var is_portrait = size.y > size.x

	if is_portrait:
		_layout_portrait(size)
	else:
		_layout_landscape(size)

const UI_MARGIN = 4.0

func _layout_landscape(size: Vector2) -> void:
	var pad_size   = movement_pad.get_minimum_size()
	var party_size = party_panel.get_minimum_size()
	var item_size  = item_bar.get_minimum_size()
	var top_height = max(top_bar.get_minimum_size().y, 60)

	var bottom_row  = max(party_size.y, pad_size.y)
	var total       = bottom_row + item_size.y + UI_MARGIN
	var available   = size.y - top_height
	var scale       = min(1.0, available / total)
	var s_item_h    = item_size.y * scale
	var s_bottom    = bottom_row * scale

	top_bar.position = Vector2(0, 0)
	top_bar.size     = Vector2(size.x, top_height)

	item_bar.position = Vector2(size.x * 0.5 - item_size.x * 0.5, size.y - s_item_h)
	item_bar.size     = Vector2(item_size.x, s_item_h)

	movement_pad.position = Vector2(size.x - pad_size.x, size.y - s_item_h - UI_MARGIN - s_bottom)
	movement_pad.size     = Vector2(pad_size.x, s_bottom)

	party_panel.position = Vector2(0, size.y - s_item_h - UI_MARGIN - party_panel.get_minimum_size().y)
	party_panel.size     = Vector2(size.x - pad_size.x, party_panel.get_minimum_size().y)

func _layout_portrait(size: Vector2) -> void:
	var pad_size   = movement_pad.get_minimum_size()
	var party_size = party_panel.get_minimum_size()
	var item_size  = item_bar.get_minimum_size()
	var top_height = max(top_bar.get_minimum_size().y, 60)

	var bottom_row    = max(pad_size.y, party_size.y)
	var total         = bottom_row + item_size.y + UI_MARGIN
	var available     = size.y - top_height
	var max_ui        = available * 0.6
	var scale         = min(1.0, max_ui / total)
	var s_item_h      = item_size.y * scale
	var s_bottom      = bottom_row * scale

	top_bar.position = Vector2(0, 0)
	top_bar.size     = Vector2(size.x, top_height)

	item_bar.position = Vector2(size.x * 0.5 - item_size.x * 0.5, size.y - s_item_h)
	item_bar.size     = Vector2(item_size.x, s_item_h)

	var bottom_y = size.y - s_item_h - UI_MARGIN - s_bottom

	party_panel.position = Vector2(0, size.y - s_item_h - UI_MARGIN - party_panel.get_minimum_size().y)
	party_panel.size     = Vector2(size.x - pad_size.x, party_panel.get_minimum_size().y)

	movement_pad.position = Vector2(size.x - pad_size.x, bottom_y)
	movement_pad.size     = Vector2(pad_size.x, s_bottom)
