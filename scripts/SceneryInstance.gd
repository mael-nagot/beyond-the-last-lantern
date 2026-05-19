class_name SceneryInstance
extends RefCounted

# Runtime placement record for ONE scenery sprite (tree, flower, etc.).
# Cells with `density > 1` produce N SceneryInstance entries that all
# share the same `cell` value but carry different `cell_offset` (sub-
# cell jitter) and `scale` (per-sprite height multiplier). The renderer
# emits one Sprite3D per instance.
#
# `GridCell.scenery` is a SINGLE pointer to one of the instances on
# this cell (set to the first one placed) — its only role is feeding
# `GridCell.is_blocked`, which is the same for every instance sharing
# the cell (`data.walkable` doesn't vary within a cell).

var data: SceneryData
var cell: Vector2i
# Sub-cell offset in fractions of CELL_SIZE — (0, 0) = cell centre,
# (±0.5, ±0.5) = corner. The placer samples per-sprite inside the
# spawn's `jitter_radius`. Single-sprite placements default to
# Vector2.ZERO so a centred decoration looks the same as before
# multi-sprite was added.
var cell_offset: Vector2 = Vector2.ZERO
# Per-sprite multiplier on `SceneryData.world_height` so a cluster
# of trees doesn't read as obviously cloned. 1.0 = render at the
# data's configured size. Defaults to 1.0 — single-sprite spawns
# typically leave the spawn's scale range at (1.0, 1.0).
var scale: float = 1.0

static func create(p_data: SceneryData, p_cell: Vector2i, p_cell_offset: Vector2 = Vector2.ZERO, p_scale: float = 1.0) -> SceneryInstance:
	var inst := SceneryInstance.new()
	inst.data = p_data
	inst.cell = p_cell
	inst.cell_offset = p_cell_offset
	inst.scale = p_scale
	return inst

# Convenience — mirrors the bool on the underlying data resource.
# Used by `GridCell.is_blocked` and the placer's exclusion filter.
func blocks_movement() -> bool:
	return data != null and not data.walkable
