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

## The trap template this spawn places (spike STEP or TIMED variant).
@export var trap: TrapData

@export_group("Scattered placement (per-cell)")
## Minimum number of scattered traps to place per level. Set to 0
## to disable the scattered pass entirely (use cluster / room modes
## exclusively).
@export var count_min: int = 1
## Maximum number of scattered traps to place per level. Actual
## count may be lower if distance / placement constraints can't be
## satisfied.
@export var count_max: int = 3
## Which cell classifications scattered traps may spawn on.
## Corridor / Room / Dead End — same bits as `ObjectSpawn.placement`.
@export_flags("Corridor", "Room", "Dead End") var placement: int = ObjectSpawn.PLACEMENT_ANY

## Manhattan distance (in tiles) this trap must keep from any other
## already-placed TRAP. Default 0 = no spacing rule. Treated as a
## preference: the placer relaxes the constraint by 1 down to 0 if
## it can't be satisfied at the requested distance, so a tight biome
## config still produces SOME traps rather than a silent zero.
@export var min_distance_to_other_trap: int = 0

@export_group("Corridor cluster placement (per-segment)")
## Probability in [0, 1] that any given corridor segment receives a
## cluster of THIS spawn's trap. Rolled per segment, per spawn. 0
## disables corridor placement for this spawn entirely. 1 attempts
## a cluster in every eligible segment.
@export_range(0.0, 1.0) var corridor_segment_chance: float = 0.0
## Minimum cluster length, in cells. Segments shorter than this are
## skipped (silent under-delivery is worse than placing fewer
## traps).
@export var corridor_traps_per_run_min: int = 1
## Maximum cluster length, in cells. Actual length rolls uniformly
## in [min, max], clamped to the segment's eligible-cell count.
@export var corridor_traps_per_run_max: int = 3

@export_group("Room density placement (per-room)")
## Probability in [0, 1] that any given room receives traps from
## THIS spawn. Rolled per room, per spawn — multiple spawns can
## share a room (e.g. STEP + TIMED mixed in one room for variety).
## 0 disables the room pass entirely.
@export_range(0.0, 1.0) var room_chance: float = 0.0
## Minimum percentage of eligible room cells to fill with traps (per
## room, per spawn). The actual target rolls uniformly in [min, max]
## %. Graceful-degrade: if `room_min_spacing` makes the target
## unreachable, places as many as fit and stops.
@export_range(0.0, 100.0) var room_coverage_min_percent: float = 10.0
## Maximum percentage of eligible room cells to fill. Must be ≥
## `room_coverage_min_percent`.
@export_range(0.0, 100.0) var room_coverage_max_percent: float = 30.0
## Manhattan distance (in tiles) every new trap must keep from any
## existing trap INSIDE THE SAME ROOM (cross-spawn — also respects
## traps placed by earlier spawns). 0 = no spacing rule, traps may
## be 4-adjacent. 1 = no two adjacent (chess-king-style spread).
## 2+ = visibly scattered. VISUAL rule only — controls how clustered
## the trap art looks.
@export var room_min_spacing: int = 0
## Max Manhattan distance from any walkable cell in the room to a
## non-trap walkable cell. With high coverage rolls, dense rooms can
## leave the player surrounded by traps with no foothold to retreat
## to — this rule is the GAMEPLAY guarantee that a step-to-safety
## is always within reach. 0 = disabled. 2 means every walkable cell
## has a non-trap walkable cell within 2 Manhattan tiles. Enforced
## pre-placement; the placer naturally caps coverage at whatever the
## rule allows. Counts cells inside AND just outside the room —
## corridor cells adjacent to the room count as valid retreat.
@export var room_max_distance_to_safe_cell: int = 0
## When true, this spawn's room pass may add traps to a room that
## already holds traps from an earlier spawn's pass — useful for
## "this room has both STEP AND TIMED hazards" variety. When false,
## the room pass skips any room that already has traps, giving each
## room a single-spawn identity. The cross-spawn `room_min_spacing`
## rule still applies in the mixed case so the shared room doesn't
## oversaturate.
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
