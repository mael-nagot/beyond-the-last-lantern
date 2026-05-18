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

## The decoration template to attach to wall faces.
@export var decoration: WallDecorationData
## Minimum number of decorations to attempt placing per level.
## Defaults to 0 — designers must opt in (decorations are
## scenery, not required for the biome to function).
@export var count_min: int = 0
## Maximum number of decorations to attempt placing per level. The
## actual count may be lower when distance / placement constraints
## or wall-face exclusivity (vs. launchers) can't be satisfied.
@export var count_max: int = 0
## Which cell classifications may have decorations attached to their
## walls. Corridor / Room / Dead End — same bits as
## `ObjectSpawn.placement`.
@export_flags("Corridor", "Room", "Dead End") var placement: int = ObjectSpawn.PLACEMENT_ANY

## Minimum Manhattan distance (in tiles) this decoration must keep
## from any already-placed wall decoration. Helps spread torches
## along corridors instead of clustering them. 0 = no spacing rule.
## Graceful-degrade — relaxes by 1 down to 0 if the constraint
## can't be satisfied (same pattern chests use).
@export var min_distance_to_other_decoration: int = 0

func allows(placement_type: int) -> bool:
	return (placement & placement_type) != 0
