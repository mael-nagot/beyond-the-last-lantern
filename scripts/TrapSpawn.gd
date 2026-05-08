class_name TrapSpawn
extends Resource

# A biome's trap-pool entry. Each entry says "spawn this trap
# count_min..count_max times in cells matching `placement` flags".
# Phase 8 Task 3 — Subtask A: simple distance-based placement reusing
# the same flag bits as ObjectSpawn / LootEntry / WallDecorationSpawn
# so designers think about scenery, loot, and traps with one model.
#
# Subtask B will add corridor-segment / room-density placement modes
# layered on top of this resource (additional fields, same shape).
#
# Note: Trap PLACEMENT flags reuse ObjectSpawn's bit values verbatim
# (PLACEMENT_CORRIDOR / ROOM / DEAD_END) so cells_by_type dictionaries
# work uniformly.

@export var trap: TrapData
@export var count_min: int = 1
@export var count_max: int = 3
@export_flags("Corridor", "Room", "Dead End") var placement: int = ObjectSpawn.PLACEMENT_ANY

# Manhattan distance (in tiles) this trap must keep from any other
# already-placed TRAP. Default 0 = no spacing rule. Treated as a
# preference: the placer relaxes the constraint by 1 down to 0 if it
# can't be satisfied at the requested distance, so a tight biome config
# still produces SOME traps rather than a silent zero.
@export var min_distance_to_other_trap: int = 0

func allows(placement_type: int) -> bool:
	return (placement & placement_type) != 0
