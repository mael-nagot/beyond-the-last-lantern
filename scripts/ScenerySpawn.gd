class_name ScenerySpawn
extends Resource

## A biome's scenery-pool entry. Places copies of a single
## `SceneryData` across the walkable area of the dungeon using THREE
## additive passes — one per cell classification:
##
##   - Dead ends: a single-tile chance roll per dead-end cell.
##   - Corridor segments: per-segment chance + a coverage % for the
##     hit segments (e.g. "30% of corridors have scenery, and in
##     those, 20–50% of cells get a sprite").
##   - Rooms: per-room chance + coverage %.
##
## One SceneryData per spawn — biomes that mix trees and flowers use
## two ScenerySpawn entries. This matches the TrapSpawn / SpinnerSpawn
## shape (one TrapData per spawn) and keeps the placement bookkeeping
## (min_distance_to_same, coverage targets) per-type rather than
## tangled across a pool.
##
## Defaults: all three chances are 0.0 so a biome adopting
## `scenery_spawns` without filling the fields is a no-op rather than
## silently carpeting every level with sprites.
##
## Placement happens AFTER every other system (traps, spinners, items,
## objects, doors, key-doors, projectile traps, secret walls,
## teleporters, wall decorations, fillers). The placer knows every
## occupied cell, so the exclusion rules are simple set checks and
## non-walkable scenery runs a BFS reachability check before
## committing — same pattern chests + doors already use.

## The scenery template (sprite, walkable flag, world_height, y_offset,
## lean) this spawn places. One template per spawn — for variety, use
## multiple ScenerySpawn entries on the same biome.
@export var scenery: SceneryData

@export_group("Dead-end placement (per-tile)")
## Probability in [0, 1] that any given dead-end cell receives one
## sprite from THIS spawn. Rolled per dead-end. 0 disables the
## dead-end pass entirely. Single-tile binary — there is no coverage
## knob because a dead-end is one cell; either it gets a sprite or it
## doesn't.
@export_range(0.0, 1.0) var dead_end_chance: float = 0.0

@export_group("Corridor placement (per-segment)")
## Probability in [0, 1] that any given corridor segment receives
## scenery from THIS spawn. Rolled per segment, per spawn. A "segment"
## is the same maximal-connected-component of non-junction corridor
## cells used by trap / spinner clusters — see
## `LevelGenerator._detect_corridor_segments`. 0 disables corridor
## placement.
@export_range(0.0, 1.0) var corridor_segment_chance: float = 0.0
## Minimum percentage of eligible cells in a hit corridor segment to
## fill. The actual target rolls uniformly in [min, max] %. "Eligible"
## means walkable floor cells that satisfy the spawn's exclusion
## rules (no trap / chest / lever / etc., and for non-walkable
## scenery also no entrance / exit / items).
@export_range(0.0, 100.0) var corridor_coverage_min_percent: float = 10.0
## Maximum percentage of eligible cells in a hit corridor segment to
## fill. Must be ≥ `corridor_coverage_min_percent`.
@export_range(0.0, 100.0) var corridor_coverage_max_percent: float = 30.0

@export_group("Room placement (per-room)")
## Probability in [0, 1] that any given room receives scenery from
## THIS spawn. Rolled per room, per spawn. 0 disables the room pass.
@export_range(0.0, 1.0) var room_chance: float = 0.0
## Minimum percentage of eligible cells in a hit room to fill. The
## actual target rolls uniformly in [min, max] %.
@export_range(0.0, 100.0) var room_coverage_min_percent: float = 10.0
## Maximum percentage of eligible cells in a hit room to fill. Must
## be ≥ `room_coverage_min_percent`.
@export_range(0.0, 100.0) var room_coverage_max_percent: float = 30.0

@export_group("Spacing")
## Minimum Manhattan distance (in tiles) between two placements of
## the SAME `SceneryData`. Cross-spawn (trees and flowers, say) do
## NOT constrain each other — only "this tree to that tree". 0 = no
## spacing rule. Treated as a preference: when a coverage target
## can't be reached at the requested distance, the placer relaxes by
## 1 down to 0 so dense rolls still produce SOME scenery rather than
## a silent zero — same graceful-degrade pattern traps / spinners
## already use.
@export var min_distance_to_same: int = 0

# True iff this spawn's dead-end pass is meaningful.
func uses_dead_ends() -> bool:
	return dead_end_chance > 0.0

# True iff this spawn's corridor pass is meaningful.
func uses_corridors() -> bool:
	return corridor_segment_chance > 0.0 and corridor_coverage_max_percent > 0.0

# True iff this spawn's room pass is meaningful.
func uses_rooms() -> bool:
	return room_chance > 0.0 and room_coverage_max_percent > 0.0
