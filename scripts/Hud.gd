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

func _layout_landscape(size: Vector2) -> void:
	var pad_size   = movement_pad.get_minimum_size()
	var party_size = party_panel.get_minimum_size()
	var item_size  = item_bar.get_minimum_size()
	var top_size   = top_bar.get_minimum_size()

	# Top bar: top, full width
	top_bar.position = Vector2(0, 0)
	top_bar.size     = Vector2(size.x, max(top_size.y, 80))

	# Item bar: very bottom, full width
	item_bar.position = Vector2(0, size.y - item_size.y)
	item_bar.size     = Vector2(size.x, item_size.y)

	# Movement pad: above item bar, right side
	movement_pad.position = Vector2(size.x - pad_size.x, size.y - item_size.y - pad_size.y)

	# Party panel: above item bar, left side
	party_panel.position = Vector2(0, size.y - item_size.y - party_size.y)

func _layout_portrait(size: Vector2) -> void:
	var pad_size   = movement_pad.get_minimum_size()
	var party_size = party_panel.get_minimum_size()
	var item_size  = item_bar.get_minimum_size()
	var top_size   = top_bar.get_minimum_size()

	# Top bar: top, full width
	top_bar.position = Vector2(0, 0)
	top_bar.size     = Vector2(size.x, max(top_size.y, 80))

	# Item bar: very bottom, full width
	item_bar.position = Vector2(0, size.y - item_size.y)
	item_bar.size     = Vector2(size.x, item_size.y)

	# Movement pad: above item bar, center
	movement_pad.position = Vector2(size.x * 0.5 - pad_size.x * 0.5, size.y - item_size.y - pad_size.y)

	# Party panel: above movement pad, full width
	party_panel.position = Vector2(0, size.y - item_size.y - pad_size.y - party_size.y)
	party_panel.size     = Vector2(size.x, party_size.y)
