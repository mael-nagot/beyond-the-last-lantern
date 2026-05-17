class_name FillerInstance
extends RefCounted

# Runtime placement record for one outdoor-filler sprite. Stored in
# `LevelGenerator.fillers`. Carries grid-space coordinates (matching
# every other generator output); the renderer multiplies by CELL_SIZE
# at draw time.
#
# Differences from WallDecorationInstance:
#   - `cell` may be OUTSIDE the grid (border-ring fillers have
#     negative cell coords or coords >= grid_width/grid_height).
#   - `cell_offset` is a sub-cell jitter in fractions of CELL_SIZE
#     where (0, 0) = cell centre and (±0.5, ±0.5) = corner. The
#     placer samples per-sprite from the spawn's jitter_radius.
#   - `scale` is a per-sprite multiplier on `FillerData.world_height`
#     so the same texture renders with subtle size variety.

var data: FillerData
var cell: Vector2i
var cell_offset: Vector2
var scale: float

static func create(p_data: FillerData, p_cell: Vector2i, p_cell_offset: Vector2, p_scale: float) -> FillerInstance:
	var inst := FillerInstance.new()
	inst.data = p_data
	inst.cell = p_cell
	inst.cell_offset = p_cell_offset
	inst.scale = p_scale
	return inst
