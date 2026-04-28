class_name DungeonView
extends Node3D

@export var show_ceiling: bool = true
@export var camera_eye_height: float = 1.8
@export var wall_height: float = 6.3
const CELL_SIZE   = 4.6
const FACING_ANGLES = {
	Vector2i( 0, -1):    0.0,   # North
	Vector2i( 1,  0):  -90.0,   # East
	Vector2i( 0,  1): -180.0,   # South
	Vector2i(-1,  0): -270.0,   # West
}

var _current_angle: float = 0.0

@onready var camera      : Camera3D = $Camera
@onready var dungeon_root: Node3D   = $DungeonRoot

var generator: LevelGenerator

func setup(gen: LevelGenerator) -> void:
	generator = gen
	_build_mesh()
	_place_camera_at_entrance()

func _build_mesh() -> void:
	for child in dungeon_root.get_children():
		child.queue_free()

	for x in range(generator.grid_width):
		for y in range(generator.grid_height):
			var cell = generator.get_cell(x, y)
			if cell == null:
				continue

			var cx = x * CELL_SIZE + CELL_SIZE * 0.5
			var cy = y * CELL_SIZE + CELL_SIZE * 0.5

			if cell.cell_type == GridCell.CellType.WALL:
				_add_box(
					Vector3(cx, wall_height * 0.5, cy),
					CELL_SIZE, wall_height, CELL_SIZE,
					Color(0.6, 0.5, 0.4)
				)
			else:
				_add_box(
					Vector3(cx, 0.05, cy),
					CELL_SIZE, 0.1, CELL_SIZE,
					Color(0.4, 0.35, 0.3)
				)
				if show_ceiling:
					_add_box(
						Vector3(cx, wall_height - 0.05, cy),
						CELL_SIZE, 0.1, CELL_SIZE,
						Color(0.25, 0.22, 0.20)
					)

func _add_box(pos: Vector3, sx: float, sy: float, sz: float, color: Color) -> void:
	var mesh_instance  = MeshInstance3D.new()
	var box            = BoxMesh.new()
	box.size           = Vector3(sx, sy, sz)

	var mat          = StandardMaterial3D.new()
	mat.albedo_color = color
	box.surface_set_material(0, mat)

	mesh_instance.mesh     = box
	mesh_instance.position = pos
	dungeon_root.add_child(mesh_instance)

func _place_camera_at_entrance() -> void:
	var ep = generator.entrance_pos
	camera.position = _grid_to_world(ep.x, ep.y)
	# Angle is set later by PlayerController via set_initial_facing

func set_initial_facing(facing: Vector2i) -> void:
	_current_angle = FACING_ANGLES.get(facing, 0.0)
	camera.rotation_degrees.y = _current_angle
	print("Initial facing vector: ", facing)
	print("Initial facing direction: ", _current_angle)
	
func move_camera_to(grid_pos: Vector2i, facing: Vector2i) -> void:
	var target_pos = _grid_to_world(grid_pos.x, grid_pos.y)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(camera, "position", target_pos, 0.12)
	tween.tween_property(camera, "rotation_degrees:y", _current_angle, 0.12)

func rotate_camera_to(turn_right: bool) -> void:
	# If we turn RIGHT, the angle should decrease (0 -> -90 -> -180)
	# If we turn LEFT, the angle should increase
	_current_angle += -90.0 if turn_right else 90.0
	var tween = create_tween()
	tween.tween_property(camera, "rotation_degrees:y", _current_angle, 0.12)

func _grid_to_world(x: int, y: int) -> Vector3:
	return Vector3(
		x * CELL_SIZE + CELL_SIZE * 0.5,
		camera_eye_height,
		y * CELL_SIZE + CELL_SIZE * 0.5
	)
