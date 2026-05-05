class_name LootEntry
extends Resource

const PLACEMENT_CORRIDOR := 1
const PLACEMENT_ROOM     := 2
const PLACEMENT_DEAD_END := 4
const PLACEMENT_ANY      := PLACEMENT_CORRIDOR | PLACEMENT_ROOM | PLACEMENT_DEAD_END

@export var item: ItemData
@export var weight: int = 1
@export_flags("Corridor", "Room", "Dead End") var placement: int = PLACEMENT_ANY

func allows(placement_type: int) -> bool:
	return (placement & placement_type) != 0
