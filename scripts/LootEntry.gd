class_name LootEntry
extends Resource

const PLACEMENT_CORRIDOR := 1
const PLACEMENT_ROOM     := 2
const PLACEMENT_DEAD_END := 4
const PLACEMENT_ANY      := PLACEMENT_CORRIDOR | PLACEMENT_ROOM | PLACEMENT_DEAD_END

@export var item: ItemData
@export var weight: int = 1
@export_flags("Corridor", "Room", "Dead End") var placement: int = PLACEMENT_ANY
# Minimum Manhattan distance (in tiles) this entry's spawn must keep
# from any already-placed floor item (of ANY kind, not just same-type).
# Default 0 = no spacing rule. Use ~3-5 to avoid clusters of identical
# potions piling on adjacent tiles. Treated as a preference: if the
# constraint can't be satisfied, the algorithm relaxes the distance by
# 1 down to 0 before giving up on this roll.
@export var min_distance_to_other_item: int = 0

func allows(placement_type: int) -> bool:
	return (placement & placement_type) != 0
