class_name ItemInstance
extends RefCounted

var data: ItemData
var stack_count: int = 1
var durability: int = -1
# Per-placement override for keys. Two ItemInstances built from the
# same key ItemData but with different key_ids unlock different
# doors, so they CANNOT stack. Empty = fall through to data.key_id.
# Set by LevelGenerator's KeyDoorSpawn placement when the lock_id is
# auto-generated; left empty for hand-authored static keys.
var key_id: String = ""
# Color modulate applied wherever the item is rendered (icon
# button, dungeon floor sprite, loot popup slot). Default
# Color.WHITE = identity multiplier, no visible tint. Used by
# KeyDoorSpawn placement to give each pair's key a slightly
# different hue so the player can tell visually-identical keys
# apart at a glance.
var tint: Color = Color.WHITE

static func create(p_data: ItemData, p_count: int = 1) -> ItemInstance:
	var inst := ItemInstance.new()
	inst.data = p_data
	inst.stack_count = max(1, p_count)
	return inst

func get_key_id() -> String:
	# Per-instance override beats per-data default. Returns "" if the
	# item isn't a key at all.
	if key_id != "":
		return key_id
	if data != null:
		return data.key_id
	return ""

func can_stack_with(other: ItemInstance) -> bool:
	if other == null or data == null or other.data == null:
		return false
	if not data.stackable:
		return false
	if data != other.data:
		return false
	# Two keys with different key_ids unlock different doors — keep
	# them in separate stacks even when they share the .tres.
	if get_key_id() != other.get_key_id():
		return false
	return true

func remaining_capacity() -> int:
	if data == null or not data.stackable:
		return 0
	return max(0, data.stack_max - stack_count)
