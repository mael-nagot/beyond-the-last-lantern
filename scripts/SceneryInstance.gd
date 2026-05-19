class_name SceneryInstance
extends RefCounted

# Runtime placement record for one scenery sprite (tree, flower, etc.).
# Stored on `GridCell.scenery` and mirrored in the flat
# `LevelGenerator.scenery` list so the renderer can iterate without a
# per-cell scan.
#
# Scenery is per-cell — one SceneryInstance per cell at most. The
# `walkable` behaviour comes from `data.walkable`; non-walkable scenery
# makes the cell behave like a chest (`GridCell.is_blocked == true`).

var data: SceneryData
var cell: Vector2i

static func create(p_data: SceneryData, p_cell: Vector2i) -> SceneryInstance:
	var inst := SceneryInstance.new()
	inst.data = p_data
	inst.cell = p_cell
	return inst

# Convenience — mirrors the bool on the underlying data resource.
# Used by `GridCell.is_blocked` and the placer's exclusion filter.
func blocks_movement() -> bool:
	return data != null and not data.walkable
