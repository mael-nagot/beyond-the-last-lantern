class_name MapPopup
extends Control

@export var debug_reveal_all: bool = false

var map_data: MapData
var generator: LevelGenerator
var player_pos: Vector2i = Vector2i.ZERO
var player_facing: Vector2i = Vector2i(0, -1)

var _blink_visible: bool = true
var _blink_timer: float = 0.0

@onready var background  : ColorRect = $Background
@onready var close_button: Button    = $CloseButton
@onready var map_draw    : Control   = $MapDrawArea

func _ready() -> void:
	visible = false
	close_button.text = "✕"
	close_button.pressed.connect(func(): close())

	var screen = get_viewport().get_visible_rect().size
	var short_side = min(screen.x, screen.y)
	close_button.custom_minimum_size = Vector2(short_side * 0.08, short_side * 0.08)
	close_button.add_theme_font_size_override("font_size", int(short_side * 0.04))

	background.color = Color(0.85, 0.75, 0.55, 0.95)

func setup(gen: LevelGenerator, data: MapData) -> void:
	generator = gen
	map_data  = data
	if debug_reveal_all:
		map_data.reveal_all()

const ANIM_DURATION   := 0.32
const OPEN_TILT_DEG   := -1.5
const COLLAPSED_SCALE := Vector2(0.05, 1.0)

var _anim_tween: Tween = null

func open() -> void:
	if _anim_tween != null and _anim_tween.is_running():
		_anim_tween.kill()
	visible = true
	_layout()
	map_draw.queue_redraw()
	SoundManager.play_map_open()
	_play_open_animation()

func close() -> void:
	if _anim_tween != null and _anim_tween.is_running():
		_anim_tween.kill()
	SoundManager.play_map_close()
	_play_close_animation()

func _play_open_animation() -> void:
	# Anchor the page at the top-left so the unfurl reads as a left
	# spine flipping the right-hand page open.
	pivot_offset = Vector2.ZERO
	scale = COLLAPSED_SCALE
	rotation = deg_to_rad(OPEN_TILT_DEG)
	modulate.a = 0.0
	_anim_tween = create_tween().set_parallel(true)
	_anim_tween.tween_property(self, "scale", Vector2.ONE, ANIM_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_anim_tween.tween_property(self, "rotation", 0.0, ANIM_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_anim_tween.tween_property(self, "modulate:a", 1.0, ANIM_DURATION * 0.5)

func _play_close_animation() -> void:
	pivot_offset = Vector2.ZERO
	var d := ANIM_DURATION * 0.7
	_anim_tween = create_tween().set_parallel(true)
	_anim_tween.tween_property(self, "scale", COLLAPSED_SCALE, d) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_anim_tween.tween_property(self, "rotation", deg_to_rad(OPEN_TILT_DEG), d) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_anim_tween.tween_property(self, "modulate:a", 0.0, d)
	_anim_tween.chain().tween_callback(_finish_close)

func _finish_close() -> void:
	visible = false
	# Restore identity transform so the next open() starts cleanly even
	# if the close animation was killed mid-flight.
	scale = Vector2.ONE
	rotation = 0.0
	modulate.a = 1.0

func update_player(pos: Vector2i, facing: Vector2i) -> void:
	player_pos    = pos
	player_facing = facing
	map_data.reveal_around(pos)
	if visible:
		map_draw.queue_redraw()

func _process(delta: float) -> void:
	if not visible:
		return
	_blink_timer += delta
	if _blink_timer >= 0.5:
		_blink_timer = 0.0
		_blink_visible = not _blink_visible
		map_draw.queue_redraw()

func _layout() -> void:
	var screen = get_viewport().get_visible_rect().size

	background.position = Vector2.ZERO
	background.size     = screen

	close_button.position = Vector2(8, 8)

	map_draw.position = Vector2(8, close_button.size.y + 16)
	map_draw.size     = Vector2(screen.x - 16, screen.y - close_button.size.y - 24)

	# Connect draw signal if not already
	if not map_draw.draw.is_connected(_on_map_draw):
		map_draw.draw.connect(_on_map_draw)

func _on_map_draw() -> void:
	if generator == null or map_data == null:
		return

	var draw_area = map_draw.size
	var is_portrait = draw_area.y > draw_area.x

	var cell_size: float
	if is_portrait:
		cell_size = draw_area.x / generator.grid_width
	else:
		cell_size = draw_area.y / generator.grid_height

	var map_width  = generator.grid_width  * cell_size
	var map_height = generator.grid_height * cell_size
	var offset = Vector2(
		(draw_area.x - map_width)  * 0.5,
		(draw_area.y - map_height) * 0.5
	)

	var wall_color  = Color(0.25, 0.15, 0.05)
	var floor_color = Color(0.65, 0.55, 0.35, 0.5)
	var exit_color  = Color(0.2, 0.8, 0.2)
	var player_color = Color(0.9, 0.1, 0.1)
	var line_width  = max(cell_size * 0.15, 1.5)

	for x in range(generator.grid_width):
		for y in range(generator.grid_height):
			var pos = Vector2i(x, y)
			if not map_data.is_explored(pos):
				continue

			var cell = generator.get_cell(x, y)
			if cell == null or cell.cell_type == GridCell.CellType.WALL:
				continue

			var rect_pos  = offset + Vector2(x * cell_size, y * cell_size)
			var rect_size = Vector2(cell_size, cell_size)

			# Draw floor tile
			map_draw.draw_rect(Rect2(rect_pos, rect_size), floor_color)

			# Draw wall edges as lines only
			if _has_wall(x, y - 1):
				map_draw.draw_line(rect_pos, rect_pos + Vector2(cell_size, 0), wall_color, line_width)
			if _has_wall(x, y + 1):
				map_draw.draw_line(rect_pos + Vector2(0, cell_size), rect_pos + Vector2(cell_size, cell_size), wall_color, line_width)
			if _has_wall(x - 1, y):
				map_draw.draw_line(rect_pos, rect_pos + Vector2(0, cell_size), wall_color, line_width)
			if _has_wall(x + 1, y):
				map_draw.draw_line(rect_pos + Vector2(cell_size, 0), rect_pos + Vector2(cell_size, cell_size), wall_color, line_width)

			# Draw object marker (chest, etc.) — small filled square in
			# the cell's centre. Opened chests render as an outline so
			# the player can tell what's already been looted.
			if cell.object != null and cell.object.data != null:
				_draw_object_marker(rect_pos, rect_size, cell_size, cell.object)

			# Draw exit — diamond shape
			if cell.cell_type == GridCell.CellType.EXIT:
				var center = rect_pos + rect_size * 0.5
				var s = cell_size * 0.35
				var diamond = PackedVector2Array([
					center + Vector2(0, -s),
					center + Vector2(s, 0),
					center + Vector2(0, s),
					center + Vector2(-s, 0),
				])
				map_draw.draw_colored_polygon(diamond, exit_color)
				for i in range(4):
					map_draw.draw_line(diamond[i], diamond[(i + 1) % 4], Color(0.1, 0.5, 0.1), line_width)

	# Draw player arrow (blinking, bigger)
	if _blink_visible:
		var player_center = offset + Vector2(
			player_pos.x * cell_size + cell_size * 0.5,
			player_pos.y * cell_size + cell_size * 0.5
		)
		var arrow_size = cell_size * 0.6
		_draw_player_arrow(player_center, player_facing, arrow_size, player_color)

func _draw_player_arrow(center: Vector2, facing: Vector2i, arrow_size: float, color: Color) -> void:
	var tip: Vector2
	var left: Vector2
	var right: Vector2

	# Arrow points in the facing direction
	var dir   = Vector2(facing.x, facing.y)
	var perp  = Vector2(-dir.y, dir.x)

	tip   = center + dir * arrow_size
	left  = center - dir * arrow_size * 0.5 + perp * arrow_size * 0.5
	right = center - dir * arrow_size * 0.5 - perp * arrow_size * 0.5

	var arrow = PackedVector2Array([tip, left, right])
	map_draw.draw_colored_polygon(arrow, color)

func _draw_object_marker(rect_pos: Vector2, rect_size: Vector2, cell_size: float, instance: ObjectInstance) -> void:
	var data: ObjectData = instance.data
	var center := rect_pos + rect_size * 0.5
	var marker_size: float = cell_size * 0.55
	var marker_rect := Rect2(center - Vector2(marker_size, marker_size) * 0.5,
		Vector2(marker_size, marker_size))
	var color: Color
	match data.category:
		ObjectData.Category.CHEST:
			color = Color(0.55, 0.30, 0.10)  # warm wood-brown
		_:
			color = Color(0.5, 0.5, 0.5)
	if instance.opened:
		# Outline only — visually marks "already looted".
		var w: float = max(cell_size * 0.08, 1.0)
		map_draw.draw_rect(marker_rect, color, false, w)
	else:
		map_draw.draw_rect(marker_rect, color)
		# A thin darker outline so the marker reads against the
		# parchment background even at small zoom.
		var border := Color(color.r * 0.6, color.g * 0.6, color.b * 0.6)
		var w: float = max(cell_size * 0.06, 1.0)
		map_draw.draw_rect(marker_rect, border, false, w)

func redraw() -> void:
	if map_draw != null:
		map_draw.queue_redraw()

func _has_wall(x: int, y: int) -> bool:
	var cell = generator.get_cell(x, y)
	if cell == null:
		return true
	return cell.cell_type == GridCell.CellType.WALL
