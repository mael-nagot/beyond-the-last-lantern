class_name SpinnerSpawn
extends Resource

# A biome's spinner-pool entry. Phase 8 Task 8.
#
# Mirrors `TrapSpawn` exactly (same field shape and naming) so a
# designer who has tuned a trap config can read this resource at a
# glance. Three placement modes are additive on the same spawn:
#
#   - Scattered:        `count_min`/`count_max` + `placement` flags
#                       (per-cell distance-driven placement).
#   - Corridor cluster: `corridor_segment_chance` per segment, runs
#                       of [`corridor_spinners_per_run_min`,
#                       `corridor_spinners_per_run_max`] contiguous
#                       cells per chosen segment.
#   - Room density:     `room_chance` per room, target coverage rolled
#                       in [`room_coverage_min_percent`,
#                       `room_coverage_max_percent`] with
#                       `room_min_spacing` between spinners in the
#                       same room.
#
# Defaults keep the corridor and room passes OFF so an existing biome
# that adopts spinner_spawns without tuning gets only the scattered
# behaviour. Set `count_min` / `count_max` to 0 to disable the
# scattered pass when using cluster/density modes exclusively.
#
# Placement flags reuse `ObjectSpawn.PLACEMENT_*` bits so the same
# `cells_by_type` dictionaries from `LevelGenerator._classify_floor_cells`
# work uniformly across traps, spinners, items, and objects.

## The spinner template this spawn places.
@export var spinner: SpinnerData

@export_group("Scattered placement (per-cell)")
## Minimum number of scattered spinners to place per level.
## Set to 0 to disable the scattered pass entirely (use cluster /
## room modes exclusively).
@export var count_min: int = 1
## Maximum number of scattered spinners to place per level. The
## actual count may be lower when distance / placement constraints
## can't be satisfied.
@export var count_max: int = 3
## Which cell classifications scattered spinners may spawn on.
## Corridor = main passages; Room = open spaces; Dead End = tunnel
## tips.
@export_flags("Corridor", "Room", "Dead End") var placement: int = ObjectSpawn.PLACEMENT_ANY

## Minimum Manhattan distance (in tiles) this spinner must keep from
## any already-placed SPINNER. Default 0 = no spacing rule. Treated
## as a preference: the placer relaxes the constraint by 1 down to 0
## if no candidate qualifies at the requested distance, so a tight
## biome config still produces SOME spinners rather than a silent
## zero — same graceful-degrade pattern objects / traps / items use.
@export var min_distance_to_other_spinner: int = 0

@export_group("Corridor cluster placement (per-segment)")
## Probability in [0, 1] that any given corridor segment receives a
## cluster of THIS spawn's spinner. Rolled per segment, per spawn.
## 0 disables corridor placement for this spawn entirely. 1 attempts
## a cluster in every eligible segment.
@export_range(0.0, 1.0) var corridor_segment_chance: float = 0.0
## Minimum length of a corridor cluster, in cells. Segments shorter
## than this are skipped (silent under-delivery is worse than
## placing fewer spinners).
@export var corridor_spinners_per_run_min: int = 1
## Maximum length of a corridor cluster, in cells. The actual run
## length rolls uniformly in [min, max], clamped to the segment's
## eligible-cell count.
@export var corridor_spinners_per_run_max: int = 3

@export_group("Room density placement (per-room)")
## Probability in [0, 1] that any given room receives spinners from
## THIS spawn. Rolled per room, per spawn — multiple spawns can
## share a room (e.g. CW + CCW variants both placed in one room).
## 0 disables the room pass entirely.
@export_range(0.0, 1.0) var room_chance: float = 0.0
## Minimum percentage of eligible room cells to fill with spinners
## (per room, per spawn). The actual target rolls uniformly in
## [min, max] %. Graceful-degrade: if `room_min_spacing` makes the
## target unreachable, places as many as fit and stops.
@export_range(0.0, 100.0) var room_coverage_min_percent: float = 10.0
## Maximum percentage of eligible room cells to fill. Must be ≥
## `room_coverage_min_percent`.
@export_range(0.0, 100.0) var room_coverage_max_percent: float = 30.0
## Manhattan distance (in tiles) every new spinner must keep from
## any existing spinner INSIDE THE SAME ROOM (cross-spawn — also
## respects spinners placed by earlier spawns). 0 = no spacing rule,
## spinners may be 4-adjacent. 1 = no two adjacent. 2+ = visibly
## scattered. Visual rule only — controls how clustered the decals
## look.
@export var room_min_spacing: int = 0
## When true, this spawn's room pass may add spinners to a room
## that already holds spinners from an earlier spawn's pass — useful
## for "this room has both CW AND CCW spinners" variety. When false,
## the room pass skips any room that already has spinners, giving
## each room a single-spawn identity.
@export var allow_mixed_room_spinners: bool = true

func allows(placement_type: int) -> bool:
	return (placement & placement_type) != 0

# True iff this spawn requests any corridor-cluster placement. Used
# by LevelGenerator to skip the corridor pass when chance is zero.
func uses_corridor_clusters() -> bool:
	return corridor_segment_chance > 0.0 and corridor_spinners_per_run_max > 0

# True iff this spawn requests any room-density placement. Used by
# LevelGenerator to skip the room pass when chance is zero.
func uses_room_density() -> bool:
	return room_chance > 0.0 and room_coverage_max_percent > 0.0
