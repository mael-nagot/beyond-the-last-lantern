class_name ObjectInstance
extends RefCounted

# Runtime state for a single placed object on the dungeon grid. Mirrors
# the ItemData / ItemInstance pattern: ObjectData is the template,
# ObjectInstance carries per-placement state (whether the chest has
# been opened, what's currently inside it, etc.).

var data: ObjectData
var opened: bool = false
var items: Array[ItemInstance] = []
# The loot table that will be rolled the first time this chest is
# opened. Set by LevelGenerator at placement time (copied from the
# ObjectSpawn that produced it). Null = chest opens empty.
var loot_table: LootTable = null

static func create(p_data: ObjectData) -> ObjectInstance:
	var inst := ObjectInstance.new()
	inst.data = p_data
	return inst

func is_chest() -> bool:
	return data != null and data.category == ObjectData.Category.CHEST

func has_remaining_loot() -> bool:
	return not items.is_empty()
