class_name MapPopup
extends Control

@export var debug_reveal_all: bool = false
# When true, draws a small upward-pointing triangle on every trap cell:
# red for STEP traps, orange for TIMED. Off by default — leaks design
# info to the player. Flip on in the Inspector while validating Phase 8
# Task 3 trap placement (Subtask B).
@export var debug_show_traps: bool = true
# When true, draws a small arrow on every explored projectile-trap
# launcher cell, pointing in the projectile's fire direction. Mirrors
# `debug_show_traps` — off by default in shipping, flipped on in the
# Inspector to validate Subtask C placement (corridor coverage,
# escape distance, fire direction toward junctions).
@export var debug_show_projectile_traps: bool = true

var map_data: MapData
var generator: LevelGenerator
var player_pos: Vector2i = Vector2i.ZERO
var player_facing: Vector2i = Vector2i(0, -1)

signal pause_requested
signal pause_released

var _blink_visible: bool = true
var _blink_timer: float = 0.0
var _paused: bool = false  # Whether THIS popup is currently a pause source

@onready var background  : ColorRect = $Background
@onready var close_button: Button    = $CloseButton
@onready var map_draw    : Control   = $MapDrawArea

func _ready() -> void:
	# PROCESS_MODE_ALWAYS so our open / close tweens, blink _process,
	# and the ✕ button keep working while the SceneTree is paused.
	# (It's MapPopup that *causes* the pause, after all.)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	close_button.text = "✕"
	close_button.pressed.connect(func(): close())

	var screen = get_viewport().get_visible_rect().size
	var short_side = min(screen.x, screen.y)
	close_button.custom_minimum_size = Vector2(short_side * 0.08, short_side * 0.08)
	close_button.add_theme_font_size_override("font_size", int(short_side * 0.04))

	background.color = Color(0.85, 0.75, 0.55, 1.0)

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
	_request_pause()

func close() -> void:
	if _anim_tween != null and _anim_tween.is_running():
		_anim_tween.kill()
	SoundManager.play_map_close()
	_play_close_animation()

func is_open() -> bool:
	# True from open() until _finish_close flips visible to false
	# (i.e. for the full close animation tail). Game.gd reads this
	# in tests / debug. The runtime input gate goes through
	# `get_tree().paused` instead so future settings / inventory
	# popups gate input the same way without re-checking each one.
	return visible

func _request_pause() -> void:
	# Idempotent — repeated open() during a close-tween shouldn't
	# stack pause sources, and HUD's source set already de-dupes by
	# id, but we keep this clean too.
	if _paused:
		return
	_paused = true
	pause_requested.emit()

func _release_pause() -> void:
	if not _paused:
		return
	_paused = false
	pause_released.emit()

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
	_release_pause()

func _exit_tree() -> void:
	# Defensive: if the popup is removed (scene change, freed) while
	# still holding the pause source, release it so we never leave
	# the SceneTree paused with no popup to close it.
	_release_pause()

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

			# Draw trap marker (debug only) — small upward-pointing
			# triangle. Used to validate Phase 8 Task 3 placement.
			if debug_show_traps and cell.trap != null:
				_draw_trap_marker(rect_pos, rect_size, cell_size, cell.trap)

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

	# Draw projectile-trap launcher arrows (debug only) on top of any
	# floor / object markers in the same cell, but BENEATH the player
	# arrow. The launcher's host cell is the floor cell adjacent to
	# the wall the launcher is mounted on; the arrow points in the
	# projectile's fire direction. PRESSURE_PLATE traps additionally
	# get a small square marker on their plate cell (Subtask C4) so
	# the developer can verify the plate sits on the projectile path
	# at the right distance from launcher + junction.
	if debug_show_projectile_traps:
		for ptrap in generator.projectile_traps:
			if ptrap == null or ptrap.data == null:
				continue
			if not map_data.is_explored(ptrap.cell):
				continue
			var pcell: GridCell = generator.get_cell(ptrap.cell.x, ptrap.cell.y)
			if pcell == null:
				continue
			var prect_pos: Vector2 = offset + Vector2(ptrap.cell.x * cell_size, ptrap.cell.y * cell_size)
			_draw_projectile_trap_marker(prect_pos, cell_size, ptrap)
			if ptrap.has_plate() and map_data.is_explored(ptrap.plate_cell):
				var plate_rect_pos: Vector2 = offset + Vector2(ptrap.plate_cell.x * cell_size, ptrap.plate_cell.y * cell_size)
				_draw_projectile_plate_marker(plate_rect_pos, cell_size)

	# Draw doors as thin slabs on cell boundaries. Filled when the
	# door currently blocks; outline-only when it's open. Only drawn
	# if BOTH endpoint cells have been explored, so the slab doesn't
	# leak fog-of-war info about unvisited corridors.
	for door in generator.doors:
		if door == null:
			continue
		if not map_data.is_explored(door.cell_a) or not map_data.is_explored(door.cell_b):
			continue
		_draw_door_slab(door, offset, cell_size, line_width)

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
	# Levers render as a smaller diamond so they read as distinct from
	# chests at a glance even though both are cell-bound.
	if instance is LeverInstance:
		_draw_lever_marker(center, cell_size, instance as LeverInstance)
		return
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

func _draw_lever_marker(center: Vector2, cell_size: float, lever: LeverInstance) -> void:
	# Small grey diamond, filled when un-pulled, outline-only when pulled.
	var s: float = cell_size * 0.30
	var diamond := PackedVector2Array([
		center + Vector2(0, -s),
		center + Vector2(s, 0),
		center + Vector2(0, s),
		center + Vector2(-s, 0),
	])
	var color := Color(0.40, 0.42, 0.48)  # slate / iron tone
	var line_width: float = max(cell_size * 0.08, 1.0)
	if lever.get_visual_opened():
		# Lever pulled — outline only.
		for i in range(4):
			map_draw.draw_line(diamond[i], diamond[(i + 1) % 4], color, line_width)
	else:
		map_draw.draw_colored_polygon(diamond, color)
		var border := Color(color.r * 0.5, color.g * 0.5, color.b * 0.5)
		for i in range(4):
			map_draw.draw_line(diamond[i], diamond[(i + 1) % 4], border, max(line_width * 0.6, 1.0))

func _draw_trap_marker(rect_pos: Vector2, rect_size: Vector2, cell_size: float, trap: TrapInstance) -> void:
	# Small upward-pointing filled triangle inside the cell. STEP traps
	# get a sharp red (one-shot HP tax); TIMED traps get a warmer orange
	# (cyclic warning). Same shape so the player reads "spike here"
	# regardless; the tint distinguishes the two trigger modes.
	if trap == null or trap.data == null:
		return
	var center := rect_pos + rect_size * 0.5
	var s: float = cell_size * 0.32
	var triangle := PackedVector2Array([
		center + Vector2(0.0, -s),     # tip (top)
		center + Vector2(s, s * 0.7),  # bottom-right
		center + Vector2(-s, s * 0.7), # bottom-left
	])
	var color: Color
	if trap.data.is_timed():
		color = Color(0.95, 0.55, 0.10)  # warning orange
	else:
		color = Color(0.85, 0.15, 0.15)  # sharp red
	map_draw.draw_colored_polygon(triangle, color)
	# Thin darker outline so the marker reads against the parchment
	# background even at small zoom.
	var border := Color(color.r * 0.5, color.g * 0.5, color.b * 0.5)
	var lw: float = max(cell_size * 0.06, 1.0)
	for i in range(3):
		map_draw.draw_line(triangle[i], triangle[(i + 1) % 3], border, lw)

func _draw_projectile_trap_marker(rect_pos: Vector2, cell_size: float, ptrap: ProjectileTrapInstance) -> void:
	# Small arrow drawn ON THE WALL EDGE between the host cell and the
	# wall the launcher is mounted on, pointing in the projectile's
	# fire direction (= -wall_dir, i.e. INTO the host cell and on into
	# the corridor). The arrow's BASE sits on the wall edge so the
	# marker reads as "the launcher is on this wall, firing this way"
	# rather than "the launcher is on the floor". Cyan-ish so it's
	# distinct from spike-trap triangles (red/orange), door slabs
	# (brown), and the player arrow (red).
	var fire: Vector2i = ptrap.fire_direction()
	var wall_dir: Vector2i = ptrap.wall_dir
	if fire == Vector2i.ZERO:
		return
	# Wall-edge midpoint = cell centre shifted half a cell toward the
	# wall the launcher is mounted on.
	var center: Vector2 = rect_pos + Vector2(cell_size * 0.5, cell_size * 0.5)
	var edge_mid: Vector2 = center + Vector2(float(wall_dir.x), float(wall_dir.y)) * cell_size * 0.5
	var dir := Vector2(float(fire.x), float(fire.y)).normalized()
	var perp := Vector2(-dir.y, dir.x)
	# Arrow tip extends from the wall edge in the fire direction. Length
	# is most of a cell so the arrow is readable at typical map zoom.
	var tip: Vector2 = edge_mid + dir * cell_size * 0.75
	# Base sits ON the wall edge, splayed perpendicular to the fire
	# direction (= along the wall axis).
	var base_l: Vector2 = edge_mid + perp * cell_size * 0.22
	var base_r: Vector2 = edge_mid - perp * cell_size * 0.22
	var color := Color(0.20, 0.65, 0.85)  # launcher cyan — distinct from spike red/orange
	var poly := PackedVector2Array([tip, base_l, base_r])
	map_draw.draw_colored_polygon(poly, color)
	var border := Color(color.r * 0.5, color.g * 0.5, color.b * 0.5)
	var lw: float = max(cell_size * 0.06, 1.0)
	for i in range(3):
		map_draw.draw_line(poly[i], poly[(i + 1) % 3], border, lw)

func _draw_projectile_plate_marker(rect_pos: Vector2, cell_size: float) -> void:
	# Phase 8 Task 3 — Subtask C4. Small filled square in the plate
	# cell, same launcher-cyan tint as the launcher arrow so the
	# developer reads them as a pair. Centred and sized to ~40% of the
	# cell so it doesn't overpower other markers (chests, levers).
	var size: float = cell_size * 0.4
	var center: Vector2 = rect_pos + Vector2(cell_size * 0.5, cell_size * 0.5)
	var marker_rect := Rect2(center - Vector2(size, size) * 0.5, Vector2(size, size))
	var color := Color(0.20, 0.65, 0.85)  # same launcher cyan
	map_draw.draw_rect(marker_rect, color)
	var border := Color(color.r * 0.5, color.g * 0.5, color.b * 0.5)
	map_draw.draw_rect(marker_rect, border, false, max(cell_size * 0.06, 1.0))

func _draw_door_slab(door: DoorInstance, offset: Vector2, cell_size: float, line_width: float) -> void:
	# A door sits on the boundary between cell_a and cell_b. The slab
	# is a thin rectangle perpendicular to the corridor axis, centred
	# on that boundary, with length spanning the corridor width.
	var axis: Vector2i = door.axis()
	var thickness: float = max(cell_size * 0.22, 2.0)
	var span: float = cell_size * 0.78
	var slab: Rect2
	if axis == Vector2i(1, 0):
		# E-W corridor → boundary is the vertical line at x = cell_b.x * cell_size,
		# slab runs vertically (along Y), narrow horizontally (along X).
		var bx: float = float(door.cell_b.x) * cell_size + offset.x
		var cy: float = (float(door.cell_a.y) + 0.5) * cell_size + offset.y
		slab = Rect2(
			Vector2(bx - thickness * 0.5, cy - span * 0.5),
			Vector2(thickness, span)
		)
	else:
		# N-S corridor → boundary is the horizontal line at y = cell_b.y * cell_size,
		# slab runs horizontally (along X), narrow vertically (along Y).
		var by: float = float(door.cell_b.y) * cell_size + offset.y
		var cx: float = (float(door.cell_a.x) + 0.5) * cell_size + offset.x
		slab = Rect2(
			Vector2(cx - span * 0.5, by - thickness * 0.5),
			Vector2(span, thickness)
		)
	var color := Color(0.45, 0.25, 0.10)  # door brown, distinct from chest
	if door.is_edge_blocked():
		map_draw.draw_rect(slab, color)
		var border := Color(color.r * 0.6, color.g * 0.6, color.b * 0.6)
		map_draw.draw_rect(slab, border, false, max(line_width * 0.5, 1.0))
	else:
		map_draw.draw_rect(slab, color, false, max(line_width * 0.7, 1.0))

func redraw() -> void:
	if map_draw != null:
		map_draw.queue_redraw()

func _has_wall(x: int, y: int) -> bool:
	var cell = generator.get_cell(x, y)
	if cell == null:
		return true
	return cell.cell_type == GridCell.CellType.WALL
