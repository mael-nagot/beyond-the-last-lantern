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

## The object template to spawn (chest, door, lever, decoration, …).
@export var object: ObjectData
## Minimum number of this object to attempt placing per level.
@export var count_min: int = 1
## Maximum number of this object to attempt placing per level. The
## actual count may be lower when the geometry can't satisfy
## reachability / distance / placement constraints.
@export var count_max: int = 1
## Which cell classifications this object may spawn on. Defaults to
## Room | Dead End so chests don't pile up in corridors. Doors need
## Corridor (they live on 1-wide corridor edges).
@export_flags("Corridor", "Room", "Dead End") var placement: int = PLACEMENT_DEFAULT
## Per-spawn loot pool (chests only). The same `object` (e.g.
## chest_wooden.tres) can appear in multiple ObjectSpawn entries with
## different loot tables — that's how the same chest visual ends up
## holding different contents in different biome configurations.
## Leave null for non-chest objects.
@export var loot_table: LootTable

## Minimum Manhattan distance (in tiles) this object must keep from
## any already-placed object (of ANY type, not just same-type).
## Default 0 = no spacing rule. Use ~4–5 to keep chests visually
## distinct from each other. Triggers farthest-point insertion;
## graceful degrade with a warning when geometry can't satisfy.
@export var min_distance_to_other_object: int = 0

## When true (for DOOR category), placement requires that closing
## this door alone cuts off at least one chest cell or the exit —
## making the door a meaningful gate. Default false: decorative
## doors that can spawn anywhere a 1-cell-wide corridor accepts them.
@export var must_gate_content: bool = false

func allows(placement_type: int) -> bool:
	return (placement & placement_type) != 0
