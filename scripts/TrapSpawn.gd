class_name TrapSpawn
extends Resource

# A biome's trap-pool entry. Phase 8 Task 3.
#
# Subtask A introduced a single "scattered" placement mode driven by
# `count_min` / `count_max` (N traps placed individually with a
# distance preference between them).
#
# Subtask B layers TWO additional placement modes that may run
# alongside the scattered pass on the same spawn:
#
#   - Corridor clusters: a per-segment chance, when fired, lays a
#     contiguous run of N trap cells inside a corridor segment. A
#     "segment" is a maximal connected component of non-junction
#     corridor cells (junctions = corridor cells with 3+ corridor
#     neighbours are excluded so two corridors meeting at a T don't
#     merge into one giant segment). See
#     `LevelGenerator._detect_corridor_segments()`.
#
#   - Room density (Subtask B2 — not in this PR yet).
#
# Modes are additive — a spawn can use any combination. Scattered +
# corridor clusters means: lay clusters in some segments, then drop a
# few extra individual traps anywhere allowed. Set `count_min = 0` to
# disable the scattered pass entirely; set `corridor_segment_chance =
# 0.0` to disable the corridor pass.
#
# Note: Trap PLACEMENT flags reuse ObjectSpawn's bit values verbatim
# (PLACEMENT_CORRIDOR / ROOM / DEAD_END) so cells_by_type dictionaries
# work uniformly.

@export var trap: TrapData

@export_group("Scattered placement (per-cell)")
@export var count_min: int = 1
@export var count_max: int = 3
@export_flags("Corridor", "Room", "Dead End") var placement: int = ObjectSpawn.PLACEMENT_ANY

# Manhattan distance (in tiles) this trap must keep from any other
# already-placed TRAP. Default 0 = no spacing rule. Treated as a
# preference: the placer relaxes the constraint by 1 down to 0 if it
# can't be satisfied at the requested distance, so a tight biome config
# still produces SOME traps rather than a silent zero.
@export var min_distance_to_other_trap: int = 0

@export_group("Corridor cluster placement (per-segment)")
# Probability in [0, 1] that any given corridor segment receives a
# cluster of THIS spawn's trap. Rolled per segment, per spawn. 0
# disables corridor placement for this spawn entirely. 1 attempts a
# cluster in every eligible segment.
@export_range(0.0, 1.0) var corridor_segment_chance: float = 0.0
# When a segment is chosen, the placer rolls a target N in
# [corridor_traps_per_run_min, corridor_traps_per_run_max] and lays N
# contiguous trap cells inside that segment. The target is clamped to
# the segment's eligible-cell count; if the segment's eligible-cell
# count is below `corridor_traps_per_run_min`, the segment is skipped
# (silent under-delivery is worse than placing fewer traps elsewhere).
@export var corridor_traps_per_run_min: int = 1
@export var corridor_traps_per_run_max: int = 3

func allows(placement_type: int) -> bool:
	return (placement & placement_type) != 0

# True iff this spawn requests any corridor-cluster placement at all.
# Used by LevelGenerator to skip the corridor pass entirely when
# `corridor_segment_chance` is zero (the common case for biomes that
# only want scattered traps).
func uses_corridor_clusters() -> bool:
	return corridor_segment_chance > 0.0 and corridor_traps_per_run_max > 0
