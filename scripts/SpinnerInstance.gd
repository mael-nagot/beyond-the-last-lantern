class_name SpinnerInstance
extends RefCounted

# Runtime placement record for one spinner cell. Phase 8 Task 8.
#
# Lives on `GridCell.spinner` (slot parallel to `GridCell.trap` and
# `GridCell.object`). Placement enforces mutual exclusion across all
# three slots and against projectile-trap plate cells / floor item
# stacks — a spinner never shares a tile with a trap, chest, lever,
# pressure plate, or item.
#
# Each instance carries its OWN rolled-at-placement direction and
# rotation count. SpinnerData defines the allowed RANGE; the
# `LevelGenerator` rolls a concrete value per instance using the
# seeded RNG and stores it here. From then on this spinner ALWAYS
# spins the player by `rotations` 90° steps in `direction` —
# every trigger produces the same outcome (the user-facing rule:
# "a spinner always has the same direction and number of rotations,
# but different spinners can differ").

enum Direction {
	CLOCKWISE,
	COUNTER_CLOCKWISE,
}

var data: SpinnerData
# Resolved per-instance direction. SpinnerData.Direction.RANDOM is
# collapsed to CLOCKWISE or COUNTER_CLOCKWISE at placement time —
# this field never holds RANDOM.
var direction: int = Direction.CLOCKWISE
# Rolled in [data.min_spins, data.max_spins] once at placement, then
# fixed for the spinner's lifetime. Clamped to a minimum of 1 so a
# misconfigured 0-spin spinner still does something (and tests don't
# silently no-op).
var rotations: int = 1
# Cell this spinner occupies. Set by LevelGenerator at placement
# time — the renderer uses it to anchor the floor decal and Game.gd
# uses it for the "armed cell" re-trigger guard.
var cell: Vector2i = Vector2i.ZERO

static func create(p_data: SpinnerData, p_cell: Vector2i, p_direction: int, p_rotations: int) -> SpinnerInstance:
	var inst := SpinnerInstance.new()
	inst.data = p_data
	inst.cell = p_cell
	# Clamp direction to a real enum value — RANDOM is a *placement
	# policy*, not a runtime state. Callers that pass RANDOM should
	# resolve it before invoking create(); we defensively collapse it
	# here so a bug in the placer can't ship an unspun spinner.
	if p_direction == Direction.COUNTER_CLOCKWISE:
		inst.direction = Direction.COUNTER_CLOCKWISE
	else:
		inst.direction = Direction.CLOCKWISE
	inst.rotations = max(1, p_rotations)
	return inst

func is_clockwise() -> bool:
	return direction == Direction.CLOCKWISE
