class_name GridCell
extends Resource

enum CellType { WALL, FLOOR, ENTRANCE, EXIT }

@export var cell_type: CellType = CellType.WALL

# Which sides have a wall (true = wall present)
@export var wall_north: bool = true
@export var wall_south: bool = true
@export var wall_east: bool  = true
@export var wall_west: bool  = true

# What object sits on this cell (null = empty)
@export var object_id: String = ""

# Is anything blocking movement through this cell?
var is_blocked: bool:
	get:
		return cell_type == CellType.WALL
