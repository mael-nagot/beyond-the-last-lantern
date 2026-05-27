class_name WallSwitchInstance
extends ObjectInstance

# Runtime state for a wall-mounted switch — a sibling to LeverInstance
# but anchored to a wall FACE, not a floor cell. Stored in
# `LevelGenerator.wall_switches`, NOT on `GridCell.object` (same
# structural rule as doors and wall decorations — switches live on
# faces, not cells, so the cell-based renderer / pathing code stays
# oblivious to them).
#
# A switch is identified from the player's perspective by:
#  - `view_cell`: the floor cell the player stands in to see and click
#    the switch.
#  - `view_side`: which side of that cell the switch is mounted on
#    (SIDE_NORTH / EAST / SOUTH / WEST = 0/1/2/3, matching the order
#    DungeonView iterates wall faces in `_build_mesh`).
#  - `along_offset`: signed offset along the wall direction in world
#    units (NOT cell units). Positive = right of the wall face's centre
#    as seen by the player facing INTO the wall; negative = left. 0 =
#    centred. Sampled at placement from `along_offset_min/max` on the
#    spawn with a random sign.
#
# Distance-0 placements ("on-door switches") have `view_cell` equal to
# one of the linked door's endpoints and `view_side` pointing across
# the door's edge. `is_on_door()` reports this case so the renderer +
# `hide_when_active` honour it.

const SIDE_NORTH: int = 0
const SIDE_EAST: int = 1
const SIDE_SOUTH: int = 2
const SIDE_WEST: int = 3

# Cardinal-direction Vector2i for each side (cell-space; positive Y is
# south to match GridCell's coordinate convention).
const SIDE_DIRS: Array[Vector2i] = [
	Vector2i(0, -1),  # NORTH
	Vector2i(1, 0),   # EAST
	Vector2i(0, 1),   # SOUTH
	Vector2i(-1, 0),  # WEST
]

var view_cell: Vector2i = Vector2i.ZERO
var view_side: int = SIDE_NORTH
var along_offset: float = 0.0

# Doors this switch controls. A click toggles ALL of them (mirrors
# LeverInstance.linked_doors). Populated at placement time by
# LevelGenerator; cross-linked with DoorInstance.linked_wall_switches.
var linked_doors: Array = []  # Array[DoorInstance]

# Mirrors LeverInstance.pulled — the switch's own clicked / un-clicked
# state. Kept for symmetry with LeverInstance even though
# `get_visual_opened` derives its visual from the linked doors instead
# (the player reads the switch's state from the doors it controls,
# not from the switch's own toggle — same convention as a real-world
# light switch where "the light is on" matters more than "the switch
# is up").
var pulled: bool = false

static func create_switch(p_data: ObjectData) -> WallSwitchInstance:
	var inst := WallSwitchInstance.new()
	inst.data = p_data
	return inst

static func dir_for_side(side: int) -> Vector2i:
	if side < 0 or side >= SIDE_DIRS.size():
		return Vector2i.ZERO
	return SIDE_DIRS[side]

func is_wall_switch() -> bool:
	return true

func toggle() -> void:
	pulled = not pulled

# True iff this switch sits ON one of its linked door's panels — i.e.
# `view_cell` is one endpoint of a linked door AND `view_side` points
# at the other endpoint. Used by the renderer (the switch on a hidden
# door's panel needs to be drawn on the door's quad, not on a real
# wall), by `hide_when_active` (only on-door switches respect that
# flag — see ObjectData.hide_when_active), and by MapPopup (the
# on-door dash collapses with the door slab in the open state).
func is_on_door() -> bool:
	if linked_doors.is_empty():
		return false
	var neighbour := view_cell + dir_for_side(view_side)
	for door in linked_doors:
		if door == null:
			continue
		var a: Vector2i = door.cell_a
		var b: Vector2i = door.cell_b
		if (view_cell == a and neighbour == b) or (view_cell == b and neighbour == a):
			return true
	return false

# Renderer reads this — same shape as LeverInstance. The switch's
# visual ("on" / "off" sprite) mirrors whether ANY linked door is
# currently open. This is what makes the player read the switch's
# state from across the room: "the switch is glowing → the door is
# open", regardless of which way the switch's own mechanical state
# went on the last click.
func get_visual_opened() -> bool:
	for door in linked_doors:
		if door != null and door.opened:
			return true
	return false

# True iff `data.hide_when_active` applies to THIS placement AND the
# linked doors are currently in the state that should hide the switch.
# Scoped to on-door switches per the design: off-door switches mounted
# on real walls have no visual problem to fix when the door opens (the
# wall they attach to keeps existing either way). On-door switches sit
# on a panel that disappears when the door opens — without this they'd
# hang in mid-air at the corridor midpoint. The flag therefore only
# fires when:
#   - `data.hide_when_active` is true (the variant opted in), AND
#   - the switch sits on the door panel itself (is_on_door()), AND
#   - at least one linked door is currently open.
# Renderer, click hit-test, and map drawing all consult this.
func should_hide() -> bool:
	if data == null or not data.hide_when_active:
		return false
	if not is_on_door():
		return false
	for door in linked_doors:
		if door != null and door.opened:
			return true
	return false
