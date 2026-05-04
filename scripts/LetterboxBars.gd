class_name LetterboxBars
extends CanvasLayer

@export_group("Portrait")
@export_range(0.0, 0.35) var top_bar_portrait:    float = 0.35
@export_range(0.0, 0.35) var bottom_bar_portrait: float = 0.35

@export_group("Landscape")
@export_range(0.0, 0.35) var top_bar_landscape:    float = 0.0
@export_range(0.0, 0.35) var bottom_bar_landscape: float = 0.0

@export var bar_color: Color = Color(0.0, 0.0, 0.0, 1.0)

@onready var top_bar:    ColorRect = $TopBar
@onready var bottom_bar: ColorRect = $BottomBar

func _ready() -> void:
	top_bar.color    = bar_color
	bottom_bar.color = bar_color
	get_viewport().size_changed.connect(_update_bars)
	_update_bars()

func _update_bars() -> void:
	var screen      = get_viewport().get_visible_rect().size
	var is_portrait = screen.y > screen.x

	var top_pct    = top_bar_portrait if is_portrait else top_bar_landscape
	var bottom_pct = bottom_bar_portrait if is_portrait else bottom_bar_landscape

	var top_height    = screen.y * top_pct
	var bottom_height = screen.y * bottom_pct

	top_bar.position = Vector2(0, 0)
	top_bar.size     = Vector2(screen.x, top_height)
	top_bar.visible  = top_pct > 0.0

	bottom_bar.position = Vector2(0, screen.y - bottom_height)
	bottom_bar.size     = Vector2(screen.x, bottom_height)
	bottom_bar.visible  = bottom_pct > 0.0
