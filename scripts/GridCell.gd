class_name GridCell
extends Resource

enum CellType { WALL, FLOOR, ENTRANCE, EXIT }

@export var cell_type: CellType = CellType.WALL

# Which sides have a wall (true = wall present)
@export var wall_north: bool = true
@export var wall_south: bool = true
@export var wall_east: bool  = true
@export var wall_west: bool  = true

# Object placed on this cell (null = none). One ObjectInstance per cell
# for now; multi-tile objects deferred.
var object: ObjectInstance = null

# Trap placed on this cell (null = none). Separate from `object` so a
# chest never collides with a trap on the same tile (placement code
# enforces "trap OR object, not both"). Traps don't block movement;
# the player walks onto the cell, takes damage, walks off again.
var trap: TrapInstance = null

# Items dropped on this cell (Array[ItemInstance]). Multiple items pile up.
var items: Array = []

# Is anything blocking movement through this cell? Walls always block.
# A cell with an object that has `blocks_movement = true` (chests, doors)
# also blocks the player. The object's blocked state takes precedence
# even if it sits on a FLOOR cell. Traps NEVER block — they live in
# their own slot and exist to be walked onto.
var is_blocked: bool:
	get:
		if cell_type == CellType.WALL:
			return true
		if object != null and object.data != null and object.data.blocks_movement:
			return true
		return false
