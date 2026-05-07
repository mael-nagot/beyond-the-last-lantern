class_name DoorInstance
extends ObjectInstance

# Runtime state for a door placed on the EDGE between two adjacent
# floor cells. Doors are NEVER stored on a GridCell — they live
# exclusively in LevelGenerator.doors. This is structural: it makes
# it impossible for the cell-based renderer or movement code to see
# a door, so the previous "sometimes in the middle / sometimes on
# the edge" rendering bug cannot recur.
#
# cell_a and cell_b are stored canonically (smaller cell first under
# lex ordering: lower x, then lower y) so any pair (a, b) and (b, a)
# resolves to the same door.

var cell_a: Vector2i
var cell_b: Vector2i

# Back-link to any levers that toggle this door. Populated by
# LevelGenerator at placement time when this door is part of a
# LinkedObjectSpawn. Empty for decorative doors. Used by the click
# handler to refresh lever visuals after the door state changes
# (lever sprite mirrors door state via LeverInstance.get_visual_opened).
# 2b ships at most 1 entry; richer pairing extends naturally.
var linked_levers: Array = []  # Array[LeverInstance] — untyped to avoid cyclic typed-array trouble

# Phase 8 Task 2c — key-locked doors. Non-empty `lock_id` means the
# door requires an `ItemInstance` whose `get_key_id()` matches before
# it can be opened from a direct click. `unlocked` flips true the
# first time the player applies the key and stays true forever
# ("once unlocked, never re-locks"); subsequent clicks behave like
# a normal toggle. Set by LevelGenerator at placement time — for
# 2c, KeyDoorSpawn auto-generates per-pair lock_ids unless the
# spawn's lock_id_prefix is set, in which case ids share that
# prefix so one key can open many doors.
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
