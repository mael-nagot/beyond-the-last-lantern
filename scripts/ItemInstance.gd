class_name ItemInstance
extends RefCounted

var data: ItemData
var stack_count: int = 1
var durability: int = -1

static func create(p_data: ItemData, p_count: int = 1) -> ItemInstance:
	var inst := ItemInstance.new()
	inst.data = p_data
	inst.stack_count = max(1, p_count)
	return inst

func can_stack_with(other: ItemInstance) -> bool:
	if other == null or data == null or other.data == null:
		return false
	if not data.stackable:
		return false
	return data == other.data

func remaining_capacity() -> int:
	if data == null or not data.stackable:
		return 0
	return max(0, data.stack_max - stack_count)
