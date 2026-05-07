class_name WallDecorationSpawn
extends Resource

# A biome's wall-decoration pool entry. "Spawn this decoration between
# count_min and count_max times on cells matching `placement` flags;
# attach it to one of the cell's wall sides (a side that abuts a WALL
# cell). Multiple decorations on the same cell are allowed — different
# wall sides — but a single wall face can hold only one decoration."
#
# Reuses `ObjectSpawn`'s placement flag bits so designers can think
# about chests / decos / traps with one mental model. Wall decos
# typically default to `Corridor | Room | Dead End` because every floor
# cell is potentially decoratable; designers narrow it down per spawn.

@export var decoration: WallDecorationData
@export var count_min: int = 0
@export var count_max: int = 0
@export_flags("Corridor", "Room", "Dead End") var placement: int = ObjectSpawn.PLACEMENT_ANY

# Minimum Manhattan distance (in tiles) this decoration must keep from
# any already-placed wall decoration. Helps spread torches along
# corridors instead of clustering them. 0 = no spacing rule.
@export var min_distance_to_other_decoration: int = 0

func allows(placement_type: int) -> bool:
	return (placement & placement_type) != 0
