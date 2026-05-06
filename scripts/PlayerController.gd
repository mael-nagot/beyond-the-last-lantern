class_name PlayerController
extends Node

enum Direction { NORTH, EAST, SOUTH, WEST }

var grid_pos: Vector2i = Vector2i.ZERO
var facing:   Direction = Direction.NORTH

var _view:      DungeonView
var _generator: LevelGenerator

const DIR_VECTORS = {
	Direction.NORTH: Vector2i( 0, -1),
	Direction.EAST:  Vector2i( 1,  0),
	Direction.SOUTH: Vector2i( 0,  1),
	Direction.WEST:  Vector2i(-1,  0),
}

const TURN_ORDER = [Direction.NORTH, Direction.EAST, Direction.SOUTH, Direction.WEST]

func setup(view: DungeonView, gen: LevelGenerator) -> void:
	_view = view
	_generator = gen
	grid_pos = gen.entrance_pos

	var possible_dirs = [Direction.NORTH, Direction.EAST, Direction.SOUTH, Direction.WEST]
	var found_good_facing = false

	# 1. BEST CASE: Look for a hallway (2 cells of floor)
	for dir in possible_dirs:
		var delta = DIR_VECTORS[dir]
		if _is_walkable(grid_pos + delta) and _is_walkable(grid_pos + delta * 2):
			facing = dir
			found_good_facing = true
			break # Stop as soon as we find a hallway!

	# 2. SECOND BEST: If no hallway, just look for ANY floor
	if not found_good_facing:
		for dir in possible_dirs:
			if _is_walkable(grid_pos + DIR_VECTORS[dir]):
				facing = dir
				found_good_facing = true
				break

	# 3. FALLBACK: If surrounded by walls, just face NORTH
	if not found_good_facing:
		facing = Direction.NORTH

	_view.set_initial_facing(DIR_VECTORS[facing])

# Helper function to keep code clean
func _is_walkable(pos: Vector2i) -> bool:
	var cell = _generator.get_cell(pos.x, pos.y)
	return cell != null and not cell.is_blocked
	

func move_forward()  -> void: _step(DIR_VECTORS[facing])
func move_backward() -> void: _step(-DIR_VECTORS[facing])

func strafe_left() -> void:
	_step(DIR_VECTORS[_turn_left(facing)])

func strafe_right() -> void:
	_step(DIR_VECTORS[_turn_right(facing)])

func turn_left() -> void:
	facing = _turn_left(facing)
	_view.rotate_camera_to(false, DIR_VECTORS[facing])
	SoundManager.play_turn()

func turn_right() -> void:
	facing = _turn_right(facing)
	_view.rotate_camera_to(true, DIR_VECTORS[facing])
	SoundManager.play_turn()

func _step(delta: Vector2i) -> void:
	var target = grid_pos + delta
	var cell   = _generator.get_cell(target.x, target.y)
	# Wall-bump if the target cell itself is blocked OR if a closed
	# door blocks the edge between the current cell and the target.
	# Edge check works for both axis-aligned moves and strafes since
	# every move goes between two orthogonally adjacent cells.
	if cell and not cell.is_blocked and not _generator.is_edge_blocked(grid_pos, target):
		grid_pos = target
		_update_camera()
		SoundManager.play_move()
	else:
		SoundManager.play_wall_bump()
		_view.shake_camera()

func _update_camera() -> void:
	_view.move_camera_to(grid_pos, DIR_VECTORS[facing])

func _turn_left(d: Direction) -> Direction:
	return TURN_ORDER[(TURN_ORDER.find(d) + 3) % 4]

func _turn_right(d: Direction) -> Direction:
	return TURN_ORDER[(TURN_ORDER.find(d) + 1) % 4]
