class_name LeverInstance
extends ObjectInstance

# A clickable lever — cell-bound (lives on GridCell.object exactly
# like a chest), but with a side-link to one or more doors that the
# pull toggles remotely. 2b ships with 1 lever ↔ 1 door. The Array
# shape is in place for the 2b follow-up (1 lever ↔ many doors AND
# many levers ↔ 1 door — see DoorInstance.linked_levers).
#
# The lever doesn't carry its own open/closed state — it MIRRORS the
# linked door(s). `get_visual_opened()` is the override that the
# renderer reads to pick the closed vs opened sprite, so chests stay
# unaffected.

var linked_doors: Array = []  # Array[DoorInstance] — typed at runtime to avoid cyclic typed-array trouble

static func create_lever(p_data: ObjectData) -> LeverInstance:
	var inst := LeverInstance.new()
	inst.data = p_data
	return inst

func is_lever() -> bool:
	return true

# Renderer-facing predicate. The lever appears "open" if ANY linked
# door is currently open. With multi-door pairing this matches the
# intuition "at least one path is unblocked"; with a single door it
# trivially mirrors that door's state. An orphan lever (no links) is
# never visually open.
func get_visual_opened() -> bool:
	for door in linked_doors:
		if door != null and door.opened:
			return true
	return false
