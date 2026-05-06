class_name DungeonView
extends Node3D

@export var show_ceiling: bool = true
@export var camera_eye_height: float = 1.8
@export var wall_height: float = 6.3
@export var biome: BiomeData
@export var fov: float = 100
@export var viewport_ratio_portrait:  float = 1.15
@export var viewport_ratio_landscape: float = 1.15

const CELL_SIZE = 4.6
const ITEM_MAX_VISIBLE_PER_TILE = 3
const ITEM_STACK_OFFSETS: Array[Vector3] = [
	Vector3( 0.0, 0.0,  0.0),
	Vector3( 0.5, 0.0, -0.4),
	Vector3(-0.5, 0.0,  0.3),
]
const FACING_ANGLES = {
	Vector2i( 0, -1):    0.0,   # North
	Vector2i( 1,  0):  -90.0,   # East
	Vector2i( 0,  1): -180.0,   # South
	Vector2i(-1,  0): -270.0,   # West
}

var _current_angle: float = 0.0
var _current_facing: Vector2i = Vector2i(0, -1)
var _current_grid_pos: Vector2i = Vector2i.ZERO

@onready var viewport_container : SubViewportContainer = $SubViewportContainer
@onready var sub_viewport       : SubViewport          = $SubViewportContainer/SubViewport
@onready var camera             : Camera3D             = $SubViewportContainer/SubViewport/Camera
@onready var dungeon_root       : Node3D               = $SubViewportContainer/SubViewport/DungeonRoot
@onready var world_env          : WorldEnvironment      = $SubViewportContainer/SubViewport/WorldEnvironment

var generator: LevelGenerator
var _items_root: Node3D
var _objects_root: Node3D
var _doors_root: Node3D
var _object_sprites: Dictionary = {}  # Vector2i -> Sprite3D (for cheap per-move repositioning)
var drop_target: DungeonDropTarget

func setup(gen: LevelGenerator) -> void:
	generator = gen
	_ensure_items_root()
	_ensure_objects_root()
	_ensure_doors_root()
	_ensure_drop_target()
	_build_mesh()
	_build_objects()
	_build_doors()
	_build_items()
	_place_camera_at_entrance()
	_apply_biome_environment()
	_update_viewport_size()
	get_viewport().size_changed.connect(_on_viewport_resized)

func _ensure_items_root() -> void:
	if _items_root != null and is_instance_valid(_items_root):
		return
	_items_root = Node3D.new()
	_items_root.name = "ItemsRoot"
	sub_viewport.add_child(_items_root)

func _ensure_objects_root() -> void:
	if _objects_root != null and is_instance_valid(_objects_root):
		return
	_objects_root = Node3D.new()
	_objects_root.name = "ObjectsRoot"
	sub_viewport.add_child(_objects_root)

func _ensure_doors_root() -> void:
	if _doors_root != null and is_instance_valid(_doors_root):
		return
	_doors_root = Node3D.new()
	_doors_root.name = "DoorsRoot"
	sub_viewport.add_child(_doors_root)

func _ensure_drop_target() -> void:
	if drop_target != null and is_instance_valid(drop_target):
		return
	# SubViewportContainer captures input by default and rejects drops
	# (it has no _can_drop_data of its own). Disable its capture so the
	# overlay we add can receive drag events instead.
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drop_target = DungeonDropTarget.new()
	drop_target.name = "DropTarget"
	drop_target.camera = camera
	viewport_container.add_child(drop_target)
	drop_target.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _on_viewport_resized() -> void:
	_update_viewport_size()

func _update_viewport_size() -> void:
	var screen      = get_viewport().get_visible_rect().size
	var is_portrait = screen.y > screen.x

	var vp_width: int
	var vp_height: int

	if is_portrait:
		vp_width  = int(screen.x)
		vp_height = int(screen.x * viewport_ratio_portrait)
	else:
		vp_height = int(screen.y)
		vp_width  = int(screen.y * viewport_ratio_landscape)

	sub_viewport.size       = Vector2i(vp_width, vp_height)
	viewport_container.size = Vector2(vp_width, vp_height)

	if is_portrait:
		viewport_container.position = Vector2((screen.x - vp_width) * 0.5, 0)
	else:
		viewport_container.position = Vector2(0, (screen.y - vp_height) * 0.5)

	camera.fov = fov

	# Force black background in the sub viewport
	sub_viewport.transparent_bg = false
	RenderingServer.set_default_clear_color(Color(0.0, 0.0, 0.0, 1.0))

func update_viewport_ratios(portrait_ratio: float, landscape_ratio: float) -> void:
	viewport_ratio_portrait  = portrait_ratio
	viewport_ratio_landscape = landscape_ratio
	_update_viewport_size()

func _build_mesh() -> void:
	for child in dungeon_root.get_children():
		child.queue_free()

	for x in range(generator.grid_width):
		for y in range(generator.grid_height):
			var cell = generator.get_cell(x, y)
			if cell == null or cell.cell_type == GridCell.CellType.WALL:
				continue

			var cx = x * CELL_SIZE + CELL_SIZE * 0.5
			var cy = y * CELL_SIZE + CELL_SIZE * 0.5

			_add_horizontal_quad(
				Vector3(cx, 0.0, cy),
				_make_material(biome.floor_albedo, biome.floor_normal)
			)

			if show_ceiling:
				_add_horizontal_quad(
					Vector3(cx, wall_height, cy),
					_make_material(biome.ceiling_albedo, biome.ceiling_normal),
					true
				)

			var neighbours = [
				[Vector2i( 0, -1), Vector3(cx, wall_height * 0.5, cy - CELL_SIZE * 0.5),   0.0],
				[Vector2i( 0,  1), Vector3(cx, wall_height * 0.5, cy + CELL_SIZE * 0.5), 180.0],
				[Vector2i(-1,  0), Vector3(cx - CELL_SIZE * 0.5, wall_height * 0.5, cy),  90.0],
				[Vector2i( 1,  0), Vector3(cx + CELL_SIZE * 0.5, wall_height * 0.5, cy), 270.0],
			]
			for n in neighbours:
				var dir   = n[0] as Vector2i
				var npos  = Vector2i(x + dir.x, y + dir.y)
				var ncell = generator.get_cell(npos.x, npos.y)
				if ncell and ncell.cell_type == GridCell.CellType.WALL:
					_add_vertical_quad(n[1], n[2], _make_material(biome.wall_albedo, biome.wall_normal))

func rebuild_items() -> void:
	if _items_root == null:
		return
	_build_items()

func rebuild_objects() -> void:
	if _objects_root == null:
		return
	_build_objects()

func rebuild_doors() -> void:
	if _doors_root == null:
		return
	_build_doors()

func _build_objects() -> void:
	for child in _objects_root.get_children():
		child.queue_free()
	_object_sprites.clear()
	for x in range(generator.grid_width):
		for y in range(generator.grid_height):
			var cell: GridCell = generator.get_cell(x, y)
			if cell == null or cell.object == null or cell.object.data == null:
				continue
			var data: ObjectData = cell.object.data
			# get_visual_opened() lets a LeverInstance derive its sprite
			# from its linked door's state; for a chest it just mirrors
			# the chest's own `opened` flag.
			var tex: Texture2D = data.opened_sprite if (cell.object.get_visual_opened() and data.opened_sprite != null) else data.closed_sprite
			if tex == null:
				continue
			var grid_pos := Vector2i(x, y)

			var sprite := Sprite3D.new()
			sprite.texture = tex
			var tex_h: int = max(1, tex.get_height())
			sprite.pixel_size = data.world_height / float(tex_h)
			sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			sprite.position = _object_position(grid_pos, data)

			# Click pickability — Area3D + matching box collider. The
			# DungeonDropTarget raycasts on left-click to find these.
			var area := Area3D.new()
			area.input_ray_pickable = true
			area.set_meta("object_instance", cell.object)
			area.set_meta("grid_pos", grid_pos)
			var col := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(data.world_height, data.world_height, data.world_height)
			col.shape = box
			area.add_child(col)
			sprite.add_child(area)

			_objects_root.add_child(sprite)
			_object_sprites[grid_pos] = sprite

func _object_position(grid_pos: Vector2i, data: ObjectData) -> Vector3:
	var cx: float = grid_pos.x * CELL_SIZE + CELL_SIZE * 0.5
	var cz: float = grid_pos.y * CELL_SIZE + CELL_SIZE * 0.5
	var ox: float = 0.0
	var oz: float = 0.0
	if data.lean_toward_player > 0.0:
		var diff := _current_grid_pos - grid_pos
		# Lean along the axis the PLAYER is currently facing (turning is
		# what switches the lean axis; strafing one tile sideways keeps
		# you on the same axis so the chest stays on the same side).
		# If the player has zero displacement along the facing axis but
		# is offset on the other, fall back to that other axis so the
		# chest still picks a side.
		var prefer_x: bool = abs(_current_facing.x) > abs(_current_facing.y)
		if prefer_x and diff.x != 0:
			ox = float(signi(diff.x)) * data.lean_toward_player
		elif (not prefer_x) and diff.y != 0:
			oz = float(signi(diff.y)) * data.lean_toward_player
		elif diff.x != 0:
			ox = float(signi(diff.x)) * data.lean_toward_player
		elif diff.y != 0:
			oz = float(signi(diff.y)) * data.lean_toward_player
	return Vector3(cx + ox, data.world_height * 0.5 + data.y_offset, cz + oz)

func _refresh_object_positions() -> void:
	# Cheap per-move update — only sprites whose cell.object.data has a
	# non-zero lean actually need new positions, but the per-call work
	# is trivial (O(n) over ~10 chests) so we just iterate them all.
	for grid_pos in _object_sprites.keys():
		var sprite: Sprite3D = _object_sprites[grid_pos]
		if not is_instance_valid(sprite):
			continue
		var cell: GridCell = generator.get_cell(grid_pos.x, grid_pos.y)
		if cell == null or cell.object == null or cell.object.data == null:
			continue
		sprite.position = _object_position(grid_pos, cell.object.data)

# -------------------------------------------------------
# Doors — edge-based, fully static once placed. NEVER repositioned
# on player movement / turn. Position and orientation are derived
# entirely from (cell_a, cell_b) on the DoorInstance.
# -------------------------------------------------------
func _build_doors() -> void:
	for child in _doors_root.get_children():
		child.queue_free()
	if generator == null:
		return
	for door in generator.doors:
		if door == null or door.data == null:
			continue
		var node := _make_door_node(door)
		if node != null:
			_doors_root.add_child(node)

func _make_door_node(door: DoorInstance) -> Node3D:
	var data: ObjectData = door.data
	var tex: Texture2D = data.opened_sprite if (door.opened and data.opened_sprite != null) else data.closed_sprite
	if tex == null:
		return null

	# Anchor the whole door (visual + collider) at the edge midpoint
	# so position is computed once and never drifts.
	var root := Node3D.new()
	root.position = _door_position(door)
	root.rotation_degrees = Vector3(0.0, _door_y_rotation_deg(door), 0.0)

	var sprite := Sprite3D.new()
	sprite.texture = tex
	var tex_w: int = max(1, tex.get_width())
	var tex_h: int = max(1, tex.get_height())
	sprite.pixel_size = data.world_height / float(tex_h)
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	# Sprite3D is centred — the root already sits at (mid_x, world_h/2 + y_off, mid_z),
	# so the sprite stays at local origin.
	sprite.position = Vector3.ZERO
	# Stretch horizontally so a square wall texture renders at corridor
	# proportions. world_width = 0 keeps the texture's natural aspect.
	if data.world_width > 0.0:
		var natural_world_width: float = float(tex_w) * sprite.pixel_size
		if natural_world_width > 0.0:
			sprite.scale = Vector3(data.world_width / natural_world_width, 1.0, 1.0)
	root.add_child(sprite)

	# Click pickability lives on a sibling Area3D so the sprite's
	# scale.x doesn't deform the collider. The Area3D is created
	# REGARDLESS of `data.interactable` — that flag now controls
	# whether the click toggles the door or just plays feedback
	# (locked sound + toast). Either way, the click must register.
	var area := Area3D.new()
	area.input_ray_pickable = true
	area.set_meta("object_instance", door)
	# grid_pos is meaningless for an edge object; expose cell_a as
	# a stable single-cell sentinel for handlers that expect one.
	area.set_meta("grid_pos", door.cell_a)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var box_width: float = data.world_width if data.world_width > 0.0 else CELL_SIZE
	box.size = Vector3(box_width, data.world_height, 0.6)
	col.shape = box
	area.add_child(col)
	root.add_child(area)

	return root

func _door_position(door: DoorInstance) -> Vector3:
	# Midpoint between cell centres. With cell_a + cell_b canonically
	# sorted (axis is (1,0) or (0,1)), this lands exactly on the cell
	# boundary along the corridor axis.
	var mid_x: float = (float(door.cell_a.x + door.cell_b.x) + 1.0) * 0.5 * CELL_SIZE
	var mid_z: float = (float(door.cell_a.y + door.cell_b.y) + 1.0) * 0.5 * CELL_SIZE
	var y: float = door.data.world_height * 0.5 + door.data.y_offset
	return Vector3(mid_x, y, mid_z)

func _door_y_rotation_deg(door: DoorInstance) -> float:
	# Default Sprite3D faces local -Z. To make the door's plane sit on
	# the cell boundary we rotate around Y depending on the corridor's
	# axis:
	#   axis (1,0) (E-W corridor) → door faces +/- X → rotate 90°
	#   axis (0,1) (N-S corridor) → door faces +/- Z → rotate 0°
	if door.axis() == Vector2i(1, 0):
		return 90.0
	return 0.0

func _build_items() -> void:
	for child in _items_root.get_children():
		child.queue_free()

	for x in range(generator.grid_width):
		for y in range(generator.grid_height):
			var cell: GridCell = generator.get_cell(x, y)
			if cell == null or cell.items.is_empty():
				continue
			var cx := x * CELL_SIZE + CELL_SIZE * 0.5
			var cz := y * CELL_SIZE + CELL_SIZE * 0.5
			var visible_count: int = min(cell.items.size(), ITEM_MAX_VISIBLE_PER_TILE)
			for i in range(visible_count):
				var inst: ItemInstance = cell.items[i]
				if inst == null or inst.data == null or inst.data.dungeon_sprite == null:
					continue
				var sprite := _make_item_sprite(inst.data)
				var offset: Vector3 = ITEM_STACK_OFFSETS[i]
				var sprite_y: float = inst.data.dungeon_sprite_world_height * 0.5 + inst.data.dungeon_sprite_y_offset
				sprite.position = Vector3(cx + offset.x, sprite_y, cz + offset.z)
				_items_root.add_child(sprite)

func _make_item_sprite(data: ItemData) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = data.dungeon_sprite
	var tex_h: int = max(1, data.dungeon_sprite.get_height())
	sprite.pixel_size = data.dungeon_sprite_world_height / float(tex_h)
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	return sprite

func _make_material(albedo_set: Array, normal_set: Array = []) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()

	if albedo_set.size() > 0:
		mat.albedo_texture = albedo_set[randi() % albedo_set.size()]

	if normal_set.size() > 0:
		mat.normal_enabled = true
		mat.normal_texture = normal_set[randi() % normal_set.size()]
		mat.normal_scale   = 0.5

	if biome.use_triplanar:
		var scale_x = 1.0 / CELL_SIZE
		var scale_y = 1.0 / wall_height
		var scale_z = 1.0 / CELL_SIZE
		mat.uv1_triplanar           = true
		mat.uv1_triplanar_sharpness = biome.triplanar_sharpness
		mat.uv1_scale               = Vector3(scale_x, scale_y, scale_z)
		mat.uv1_offset              = Vector3(0.0, biome.triplanar_y_offset, 0.0)

	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	return mat

func _apply_biome_environment() -> void:
	var env = world_env.environment
	
	if env == null:
		push_error("No Environment resource on WorldEnvironment node")
		return

	env.fog_enabled              = biome.fog_enabled
	env.fog_light_color          = biome.fog_color
	env.fog_light_energy         = 1.0
	env.fog_density              = biome.fog_density
	env.fog_aerial_perspective   = biome.fog_aerial

	env.ambient_light_source     = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color      = biome.ambient_color
	env.ambient_light_energy     = biome.ambient_energy	

func _add_horizontal_quad(pos: Vector3, mat: StandardMaterial3D, flip: bool = false) -> void:
	var mesh_instance              = MeshInstance3D.new()
	var quad                       = QuadMesh.new()
	quad.size                      = Vector2(CELL_SIZE, CELL_SIZE)
	quad.surface_set_material(0, mat)
	mesh_instance.mesh             = quad
	mesh_instance.position         = pos
	mesh_instance.rotation_degrees = Vector3(-90.0 if not flip else 90.0, 0, 0)
	dungeon_root.add_child(mesh_instance)

func _add_vertical_quad(pos: Vector3, y_rotation: float, mat: StandardMaterial3D) -> void:
	var mesh_instance              = MeshInstance3D.new()
	var quad                       = QuadMesh.new()
	quad.size                      = Vector2(CELL_SIZE, wall_height)
	quad.surface_set_material(0, mat)
	mesh_instance.mesh             = quad
	mesh_instance.position         = pos
	mesh_instance.rotation_degrees = Vector3(0, y_rotation, 0)
	dungeon_root.add_child(mesh_instance)

func _place_camera_at_entrance() -> void:
	var ep = generator.entrance_pos
	_current_grid_pos = ep
	camera.position = _grid_to_world(ep.x, ep.y)

func set_initial_facing(facing: Vector2i) -> void:
	_current_facing           = facing
	_current_angle            = FACING_ANGLES.get(facing, 0.0)
	camera.rotation_degrees.y = _current_angle
	camera.position           = _grid_to_world(_current_grid_pos.x, _current_grid_pos.y)
	_refresh_object_positions()

func move_camera_to(grid_pos: Vector2i, facing: Vector2i) -> void:
	_current_grid_pos = grid_pos
	_current_facing   = facing
	var target_pos    = _grid_to_world(grid_pos.x, grid_pos.y)
	var tween         = create_tween()
	tween.set_parallel(true)
	tween.tween_property(camera, "position", target_pos, 0.12)
	tween.tween_property(camera, "rotation_degrees:y", _current_angle, 0.12)
	# Object positions are intentionally NOT refreshed here — the lean
	# axis is tied to facing, so the chest only re-leans when the player
	# turns. Refreshing on move would visibly snap the chest mid-step.

func rotate_camera_to(turn_right: bool, facing: Vector2i = Vector2i.ZERO) -> void:
	_current_angle += -90.0 if turn_right else 90.0
	if facing != Vector2i.ZERO:
		_current_facing = facing
	var tween = create_tween()
	tween.tween_property(camera, "rotation_degrees:y", _current_angle, 0.12)
	_refresh_object_positions()

const SHAKE_INTENSITY := 0.12
const SHAKE_DURATION  := 0.18
const SHAKE_STEPS     := 5

var _shake_tween: Tween = null
var _shake_origin: Vector3 = Vector3.ZERO

# Brief omni-directional jolt of the camera position. Used for wall
# bumps and rejected interactions (locked-door click feedback).
# `magnitude` scales the base SHAKE_INTENSITY: 1.0 = full wall bump,
# ~0.4 = a softer "click on locked thing" jolt. Safe to call rapid-
# fire — an active shake is killed and the camera reset before a
# fresh shake starts so successive shakes don't drift.
func shake_camera(magnitude: float = 1.0) -> void:
	if _shake_tween != null and _shake_tween.is_running():
		_shake_tween.kill()
		camera.position = _shake_origin
	_shake_origin = camera.position
	_shake_tween = create_tween()
	var intensity: float = SHAKE_INTENSITY * magnitude
	var step_dur := SHAKE_DURATION / float(SHAKE_STEPS)
	for i in range(SHAKE_STEPS):
		var decay := 1.0 - float(i) / float(SHAKE_STEPS)
		var offset := Vector3(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity) * 0.4,
			randf_range(-intensity, intensity),
		) * decay
		_shake_tween.tween_property(camera, "position", _shake_origin + offset, step_dur)
	_shake_tween.tween_property(camera, "position", _shake_origin, step_dur)

func _grid_to_world(x: int, y: int) -> Vector3:
	return Vector3(
		x * CELL_SIZE + CELL_SIZE * 0.5,
		camera_eye_height,
		y * CELL_SIZE + CELL_SIZE * 0.5
	)
