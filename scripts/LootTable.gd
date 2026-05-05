class_name LootTable
extends Resource

# A reusable bag of weighted items with min/max draw counts. Used for
# chest contents now; will fit enemy drops and quest rewards later
# without changes. One .tres per loot table lives in
# res://assets/loot_tables/. Reference it from a ChestSpawn (or future
# DropSpawn) so the same chest visual can be paired with different loot
# pools per biome / difficulty / location.

@export var min_rolls: int = 1
@export var max_rolls: int = 3
@export var entries: Array[LootTableEntry] = []
