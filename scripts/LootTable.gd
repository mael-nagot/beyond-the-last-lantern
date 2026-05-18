class_name LootTable
extends Resource

# A reusable bag of weighted items with min/max draw counts. Used for
# chest contents now; will fit enemy drops and quest rewards later
# without changes. One .tres per loot table lives in
# res://assets/loot_tables/. Reference it from a ChestSpawn (or future
# DropSpawn) so the same chest visual can be paired with different loot
# pools per biome / difficulty / location.

## Minimum number of items rolled from this table per draw (e.g. per
## chest opened). Each roll independently picks one entry weighted by
## its `weight`, respecting `allow_duplicates`.
@export var min_rolls: int = 1
## Maximum number of items rolled per draw. The actual count is
## uniform in [min_rolls, max_rolls]. Set both to the same value for
## a fixed yield.
@export var max_rolls: int = 3
## The weighted entries this table can draw from. Each entry pairs
## an `ItemData` with a `weight` and an `allow_duplicates` flag.
@export var entries: Array[LootTableEntry] = []
