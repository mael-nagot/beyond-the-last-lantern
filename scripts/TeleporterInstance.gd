class_name TeleporterInstance
extends RefCounted

# Runtime placement record for one teleporter PAIR. Phase 15 Task 6.
#
# Lives on `GridCell.teleporter` (slot parallel to `GridCell.object`,
# `GridCell.trap`, and `GridCell.spinner`). BOTH endpoints reference
# the SAME `TeleporterInstance` — `cell_a` and `cell_b` are stored on
# the instance so `partner_of(cell)` can resolve the destination from
# either side without an extra lookup table.
#
# Placement enforces mutual exclusion: a teleporter never shares a
# tile with a chest, lever, door endpoint, trap, spinner, pressure
# plate, floor item, entrance, or exit.

var data: TeleporterData
# The two paired cells. Canonical order is NOT enforced — `cell_a` is
# the first endpoint placed by the generator, `cell_b` is the partner.
# The renderer + map + warp logic all treat the pair symmetrically.
var cell_a: Vector2i = Vector2i.ZERO
var cell_b: Vector2i = Vector2i.ZERO
# Sequence number among teleporter pairs in this level (0-based).
# The MapPopup uses this to pick a unique hue per pair so the player
# can tell at a glance which two cells link. Unused by the warp logic
# itself.
var pair_index: int = 0

static func create(p_data: TeleporterData, p_cell_a: Vector2i, p_cell_b: Vector2i, p_pair_index: int) -> TeleporterInstance:
	var inst := TeleporterInstance.new()
	inst.data = p_data
	inst.cell_a = p_cell_a
	inst.cell_b = p_cell_b
	inst.pair_index = max(0, p_pair_index)
	return inst

# Returns the OTHER endpoint cell given one endpoint. Fail-safe: if
# `cell` is neither endpoint, returns Vector2i(-1, -1) so callers can
# detect the bug rather than silently warping to cell_a.
func partner_of(cell: Vector2i) -> Vector2i:
	if cell == cell_a:
		return cell_b
	if cell == cell_b:
		return cell_a
	return Vector2i(-1, -1)

# Convenience for iterating both endpoints. Order is stable
# (cell_a then cell_b) so callers that want a deterministic walk can
# rely on it.
func endpoints() -> Array:
	return [cell_a, cell_b]

# True iff `cell` is one of the two endpoints. Used by placement
# co-location checks.
func has_endpoint(cell: Vector2i) -> bool:
	return cell == cell_a or cell == cell_b
