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
# contiguous trap cells inside that segment. Both bounds are SOFT —
# when the segment has fewer eligible cells than `corridor_traps_per_run_min`,
# the placer just lays as many as fit (rather than skipping the
# segment entirely). The original "skip if too short" rule left
# short corridors leading to dead-ends bare, which read as "the
# placer forgot this corridor". `corridor_traps_per_run_max` is also
# clamped to the segment's eligible-cell count.
@export var corridor_traps_per_run_min: int = 1
@export var corridor_traps_per_run_max: int = 3

@export_group("Room density placement (per-room)")
# Probability in [0, 1] that any given room receives traps from THIS
# spawn. Rolled per room, per spawn — multiple spawns can share a
# room (e.g. STEP + TIMED mixed in one room for variety). 0 disables
# the room pass entirely.
@export_range(0.0, 1.0) var room_chance: float = 0.0
# When a room is chosen, the placer rolls a target percentage of
# eligible room cells in [min, max] and tries to place that many
# traps. Graceful-degrade: if `room_min_spacing` makes the target
# unreachable, places as many as fit and stops.
@export_range(0.0, 100.0) var room_coverage_min_percent: float = 10.0
@export_range(0.0, 100.0) var room_coverage_max_percent: float = 30.0
# Manhattan distance (in tiles) every new trap must keep from any
# existing trap INSIDE THE SAME ROOM (cross-spawn — also respects
# traps placed by earlier spawns). 0 = no spacing rule, traps may be
# 4-adjacent to each other. 1 = no two adjacent (chess-king-style
# spread). 2+ = visibly scattered. This is a VISUAL rule — it
# controls how clustered the trap art looks.
@export var room_min_spacing: int = 0
# Max Manhattan distance from any walkable cell in the room to a
# non-trap walkable cell. With high coverage rolls, dense rooms can
# leave the player surrounded by traps with no foothold to retreat
# to — this rule is the GAMEPLAY guarantee that a step-to-safety is
# always within reach. 0 = disabled. 2 means every walkable cell has
# a non-trap walkable cell within 2 Manhattan tiles. Enforced
# pre-placement: a candidate trap that would violate the rule for any
# walkable cell is rejected, so the placer naturally caps coverage at
# whatever the rule allows. The check considers cells inside AND just
# outside the room — corridor cells adjacent to the room count as
# valid retreat (the player can step out).
@export var room_max_distance_to_safe_cell: int = 0
# When true, this spawn's room pass may add traps to a room that
# already holds traps from an earlier spawn's pass — useful for
# "this room has both step AND timed hazards" variety. When false,
# the room pass skips any room that already has traps, giving each
# room a single-spawn identity (analogous to the one-spawn-per-
# corridor-segment rule used by clusters). The cross-spawn
# `room_min_spacing` rule still applies in the mixed case so the
# shared room doesn't oversaturate.
@export var allow_mixed_room_traps: bool = true

func allows(placement_type: int) -> bool:
	return (placement & placement_type) != 0

# True iff this spawn requests any corridor-cluster placement at all.
# Used by LevelGenerator to skip the corridor pass entirely when
# `corridor_segment_chance` is zero (the common case for biomes that
# only want scattered traps).
func uses_corridor_clusters() -> bool:
	return corridor_segment_chance > 0.0 and corridor_traps_per_run_max > 0

# True iff this spawn requests any room-density placement. Used by
# LevelGenerator to skip the room pass when chance is zero.
func uses_room_density() -> bool:
	return room_chance > 0.0 and room_coverage_max_percent > 0.0
