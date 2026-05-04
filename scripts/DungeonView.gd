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

func setup(gen: LevelGenerator) -> void:
	generator = gen
	_build_mesh()
	_place_camera_at_entrance()
	_apply_biome_environment()
	_update_viewport_size()
	get_viewport().size_changed.connect(_on_viewport_resized)

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

func move_camera_to(grid_pos: Vector2i, facing: Vector2i) -> void:
	_current_grid_pos = grid_pos
	_current_facing   = facing
	var target_pos    = _grid_to_world(grid_pos.x, grid_pos.y)
	var tween         = create_tween()
	tween.set_parallel(true)
	tween.tween_property(camera, "position", target_pos, 0.12)
	tween.tween_property(camera, "rotation_degrees:y", _current_angle, 0.12)

func rotate_camera_to(turn_right: bool) -> void:
	_current_angle += -90.0 if turn_right else 90.0
	var tween = create_tween()
	tween.tween_property(camera, "rotation_degrees:y", _current_angle, 0.12)

func _grid_to_world(x: int, y: int, facing: Vector2i = Vector2i.ZERO) -> Vector3:
	return Vector3(
		x * CELL_SIZE + CELL_SIZE * 0.5,
		camera_eye_height,
		y * CELL_SIZE + CELL_SIZE * 0.5
	)
