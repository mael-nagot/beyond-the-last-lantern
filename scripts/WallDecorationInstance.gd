class_name WallDecorationInstance
extends RefCounted

# Runtime placement record for one wall decoration. Stored in
# `LevelGenerator.wall_decorations` (NOT on a `GridCell.object` —
# decorations live on wall FACES, not cells, like doors live on edges).
#
# `cell` is the floor cell the decoration is attached TO; `wall_dir` is
# the cardinal direction from that cell pointing INTO the wall. So a
# torch on the north wall of cell (5, 7) has cell = (5, 7) and
# wall_dir = (0, -1). The renderer uses these to anchor the sprite at
# the wall midpoint and Y-rotate it to face into the corridor.

const DIR_NORTH := Vector2i(0, -1)
const DIR_SOUTH := Vector2i(0, 1)
const DIR_WEST  := Vector2i(-1, 0)
const DIR_EAST  := Vector2i(1, 0)

var data: WallDecorationData
var cell: Vector2i
var wall_dir: Vector2i

static func create(p_data: WallDecorationData, p_cell: Vector2i, p_wall_dir: Vector2i) -> WallDecorationInstance:
	var inst := WallDecorationInstance.new()
	inst.data = p_data
	inst.cell = p_cell
	inst.wall_dir = p_wall_dir
	return inst

# Canonical key — uniquely identifies the wall face this decoration
# occupies. Used to prevent two decorations from stacking on the same
# wall face. "x,y|dx,dy" matches the format DoorInstance.edge_key uses.
static func face_key(p_cell: Vector2i, p_wall_dir: Vector2i) -> String:
	return "%d,%d|%d,%d" % [p_cell.x, p_cell.y, p_wall_dir.x, p_wall_dir.y]

func get_face_key() -> String:
	return face_key(cell, wall_dir)
