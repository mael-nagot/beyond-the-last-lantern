class_name ObjectSpawn
extends Resource

# A biome's object-pool entry. Each entry says "spawn this object type
# count_min..count_max times in cells matching `placement` flags".
# Defaults to Room | Dead End so chests don't pile up in corridors.

const PLACEMENT_CORRIDOR := 1
const PLACEMENT_ROOM     := 2
const PLACEMENT_DEAD_END := 4
const PLACEMENT_ANY      := PLACEMENT_CORRIDOR | PLACEMENT_ROOM | PLACEMENT_DEAD_END
const PLACEMENT_DEFAULT  := PLACEMENT_ROOM | PLACEMENT_DEAD_END

@export var object: ObjectData
@export var count_min: int = 1
@export var count_max: int = 1
@export_flags("Corridor", "Room", "Dead End") var placement: int = PLACEMENT_DEFAULT
# Per-spawn loot. The same `object` (e.g. chest_wooden.tres) can appear
# in multiple ObjectSpawn entries with different loot tables — that's
# how the same chest visual ends up holding different contents in
# different biome configurations.
@export var loot_table: LootTable

# Minimum Manhattan distance (in tiles) this object must keep from any
# already-placed object (of ANY type, not just same-type). Default 0 =
# no spacing rule. Use ~4-5 to keep chests visually distinct from each
# other.
@export var min_distance_to_other_object: int = 0

func allows(placement_type: int) -> bool:
	return (placement & placement_type) != 0
