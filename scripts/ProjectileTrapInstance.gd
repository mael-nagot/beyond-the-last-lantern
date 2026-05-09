class_name ProjectileTrapInstance
extends RefCounted

# Runtime placement record for one wall-mounted projectile launcher.
# Phase 8 Task 3 — Subtask C.
#
# Stored in `LevelGenerator.projectile_traps` (NOT on a `GridCell` —
# launchers live on wall FACES, not cells, like wall decorations).
#
# `cell` is the floor cell the launcher is attached TO; `wall_dir` is
# the cardinal direction from that cell pointing INTO the wall. So a
# launcher on the north wall of cell (5, 7) has cell = (5, 7) and
# wall_dir = (0, -1). The projectile then fires SOUTH (the opposite of
# wall_dir) into the corridor.
#
# **Subtask C1 scope:** placement record + `face_key` for the shared
# wall-face registry + `fire_direction` for the placement validator.
# Firing logic (timer / projectile spawn) lands in C2; pressure-plate
# linkage lands in C4.

const DIR_NORTH := Vector2i(0, -1)
const DIR_SOUTH := Vector2i(0, 1)
const DIR_WEST  := Vector2i(-1, 0)
const DIR_EAST  := Vector2i(1, 0)

# Sentinel for "no plate" — populated by Subtask C4 for PRESSURE_PLATE
# traps, left as Vector2i(-1, -1) for TIMED traps.
const NO_PLATE := Vector2i(-1, -1)

var data: ProjectileTrapData
var cell: Vector2i
var wall_dir: Vector2i
# PRESSURE_PLATE only. NO_PLATE for TIMED traps. Wired in Subtask C4.
var plate_cell: Vector2i = NO_PLATE
# TIMED only — phase-shift offset rolled at placement time so multiple
# TIMED traps don't fire in lockstep. Wired in Subtask C2.
var timed_offset: float = 0.0
# C2 will add `timer`, `in_flight`, `damage_latch` (per active
# projectile via `ProjectileInstance`) — not needed in C1's static
# placement-only landing.

static func create(p_data: ProjectileTrapData, p_cell: Vector2i, p_wall_dir: Vector2i) -> ProjectileTrapInstance:
	var inst := ProjectileTrapInstance.new()
	inst.data = p_data
	inst.cell = p_cell
	inst.wall_dir = p_wall_dir
	return inst

# Cardinal direction the projectile flies. Always opposite the wall
# the launcher is mounted on (i.e., away from the wall, into the
# corridor or room). Used by both placement (validation) and rendering
# (Y-rotation of the launcher sprite + future projectile spawn).
func fire_direction() -> Vector2i:
	return -wall_dir

# Canonical key — uniquely identifies the wall face this launcher
# occupies. Format matches `WallDecorationInstance.face_key` so the
# same `_wall_faces_used` dictionary on `LevelGenerator` blocks both
# decorations and launchers from claiming the same face.
static func face_key(p_cell: Vector2i, p_wall_dir: Vector2i) -> String:
	return "%d,%d|%d,%d" % [p_cell.x, p_cell.y, p_wall_dir.x, p_wall_dir.y]

func get_face_key() -> String:
	return face_key(cell, wall_dir)

# True iff this launcher has a linked pressure plate (Subtask C4).
# In C1 always false — `plate_cell` is left at NO_PLATE.
func has_plate() -> bool:
	return plate_cell != NO_PLATE
