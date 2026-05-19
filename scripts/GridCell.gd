class_name GridCell
extends Resource

enum CellType { WALL, FLOOR, ENTRANCE, EXIT }

## What this cell represents on the map: WALL (impassable),
## FLOOR (walkable empty space), ENTRANCE (the player spawn point),
## EXIT (the level goal). Set by `LevelGenerator` during generation.
@export var cell_type: CellType = CellType.WALL

## True when this cell has a wall on its north side. Walls are stored
## per-cell so two adjacent floor cells with a wall between them both
## have the wall flagged on their facing side. Set by LevelGenerator.
@export var wall_north: bool = true
## True when this cell has a wall on its south side. See `wall_north`.
@export var wall_south: bool = true
## True when this cell has a wall on its east side. See `wall_north`.
@export var wall_east: bool  = true
## True when this cell has a wall on its west side. See `wall_north`.
@export var wall_west: bool  = true

# Object placed on this cell (null = none). One ObjectInstance per cell
# for now; multi-tile objects deferred.
var object: ObjectInstance = null

# Trap placed on this cell (null = none). Separate from `object` so a
# chest never collides with a trap on the same tile (placement code
# enforces "trap OR object, not both"). Traps don't block movement;
# the player walks onto the cell, takes damage, walks off again.
var trap: TrapInstance = null

# Spinner placed on this cell (null = none). Separate slot from `trap`
# and `object` so a spinner never collides with a chest, lever, trap,
# projectile-trap plate, or floor item — the placer enforces all five
# exclusions. Spinners don't block movement; the player walks onto
# the cell, gets rotated by the spinner's fixed direction + count,
# and walks off again.
var spinner: SpinnerInstance = null

# Teleporter endpoint placed on this cell (null = none). Fourth
# parallel slot alongside `object`, `trap`, and `spinner`. Placement
# enforces mutual exclusion against every other special-content slot
# AND against floor items / entrance / exit. Teleporters don't block
# movement; the player walks onto the cell and is warped to the
# pair's partner cell. Both endpoints of a pair point to the SAME
# TeleporterInstance — use `inst.partner_of(this_cell_pos)` to resolve
# the destination.
var teleporter: TeleporterInstance = null

# Scenery placed on this cell (null = none). Fifth parallel slot —
# trees, flowers, mushrooms, rocks placed by the scenery pass which
# runs LAST in level generation. Walkable scenery (flowers) doesn't
# block movement; non-walkable scenery (trees) does — see
# `is_blocked` below. Mutual exclusion against every other special-
# content slot is enforced by the placer, so a scenery cell never
# also holds a chest / lever / trap / spinner / teleporter / items.
var scenery: SceneryInstance = null

# Items dropped on this cell (Array[ItemInstance]). Multiple items pile up.
var items: Array = []

# Is anything blocking movement through this cell? Walls always block.
# A cell with an object that has `blocks_movement = true` (chests, doors)
# also blocks the player. A cell with non-walkable scenery (a tree)
# blocks too — same per-cell-mutex semantics, so the player can never
# step on a tree. Traps / spinners / teleporters / walkable scenery
# NEVER block.
var is_blocked: bool:
	get:
		if cell_type == CellType.WALL:
			return true
		if object != null and object.data != null and object.data.blocks_movement:
			return true
		if scenery != null and scenery.blocks_movement():
			return true
		return false
