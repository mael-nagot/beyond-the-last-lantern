class_name LootTableEntry
extends Resource

# One row inside a LootTable. Used for chest loot today; the same shape
# will fit enemy drops and quest rewards in later phases.

@export var item: ItemData
@export var weight: int = 1
# When false, this entry can only be picked once per roll session — a
# unique sword or armor that should never be duplicated even if the
# table is rolled multiple times. When true (default), the entry stays
# in the pool after each pick, so it can stack (e.g. several health
# potions in the same chest).
@export var allow_duplicates: bool = true
