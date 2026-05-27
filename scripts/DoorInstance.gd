class_name DoorInstance
extends ObjectInstance

enum LeverLogic { AND = 0, OR = 1 }

var cell_a: Vector2i
var cell_b: Vector2i

var linked_levers: Array = []  # Array[LeverInstance]
var lever_logic: int = LeverLogic.AND

# Wall-mounted switches that control this door (Phase 8 — wall switch
# system). Populated by LevelGenerator for `WallSwitchedDoorSpawn`
# clusters; empty for every other door variant. The back-link lives
# here purely so Game.gd can refresh the switch's visual ("open" /
# "closed" sprite swap) after the door toggles — same role
# `linked_levers` plays for lever-pairs.
var linked_wall_switches: Array = []  # Array[WallSwitchInstance]

var lock_id: String = ""
var unlocked: bool = false

static func canonical_pair(a: Vector2i, b: Vector2i) -> Array:
	if a.x < b.x or (a.x == b.x and a.y < b.y):
		return [a, b]
	return [b, a]

static func edge_key(a: Vector2i, b: Vector2i) -> String:
	var pair: Array = canonical_pair(a, b)
	var lo: Vector2i = pair[0]
	var hi: Vector2i = pair[1]
	return "%d,%d|%d,%d" % [lo.x, lo.y, hi.x, hi.y]

static func create_door(p_data: ObjectData, a: Vector2i, b: Vector2i) -> DoorInstance:
	var inst := DoorInstance.new()
	inst.data = p_data
	var pair: Array = canonical_pair(a, b)
	inst.cell_a = pair[0]
	inst.cell_b = pair[1]
	return inst

# (1, 0) for an east-west corridor, (0, 1) for a north-south corridor.
# Always non-negative because cells are canonically sorted.
func axis() -> Vector2i:
	return cell_b - cell_a

# True iff this door currently blocks the edge it sits on. A door
# with blocks_movement = false (e.g. a future archway) NEVER blocks.
func is_edge_blocked() -> bool:
	if data == null or not data.blocks_movement:
		return false
	return not opened

func is_door() -> bool:
	return true

# True when the door currently demands a key. Once `unlocked` flips
# true, this returns false even if `lock_id` is still set — the
# unlock is sticky.
func is_key_locked() -> bool:
	return lock_id != "" and not unlocked

func is_lever_locked() -> bool:
	return not linked_levers.is_empty()

func compute_lever_opened() -> bool:
	if linked_levers.is_empty():
		return opened
	if lever_logic == LeverLogic.AND:
		for lever in linked_levers:
			if lever == null or not lever.pulled:
				return false
		return true
	else:
		for lever in linked_levers:
			if lever != null and lever.pulled:
				return true
		return false
