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
## already use. Measured CELL TO CELL (not sprite to sprite), so a
## cell with 5 flowers counts as one neighbour for distance checks.
@export var min_distance_to_same: int = 0

@export_group("Per-cell sprite count")
## Minimum number of sprites to emit per placed cell. 1 = a single
## sprite snapped to cell centre (right for clean trees / flowers /
## mushrooms — matches the original single-object-per-tile design).
## > 1 = a cluster of sprites scattered inside the cell (e.g. "3-5
## flowers on the same tile" or "2 trees clumped together"). Each
## placed cell rolls a uniform integer in [density_min, density_max].
## For NON-WALKABLE scenery (trees), the cell is blocked regardless
## of how many trees stand on it — extra sprites are pure visual
## variety on top of the first.
@export var density_min: int = 1
## Maximum number of sprites to emit per placed cell. Must be ≥
## density_min. Picked uniformly per placed cell.
@export var density_max: int = 1

@export_group("Sub-cell placement")
## How far each sprite can scatter from cell centre, as a fraction
## of CELL_SIZE.
## 0.0 = every sprite snaps to cell centre. With density == 1 this
## produces the clean "centred decoration" look — flowers sit dead-
## centre, trees stand straight up in the middle of the tile.
## With density > 1 and jitter == 0 every sprite stacks on the same
## spot and Z-fights; set jitter > 0 when bumping density.
## 0.5 = sprite can land anywhere inside the cell (maximum spread).
## Typical 0.25–0.4 for multi-sprite clusters — visible scatter
## without seam-stitching against adjacent cells.
@export_range(0.0, 0.5) var jitter_radius: float = 0.0

@export_group("Per-sprite scale")
## Minimum scale multiplier applied to `SceneryData.world_height`
## per sprite. 1.0 = no variance (the default — every sprite renders
## at exactly the data's world_height). A small range like (0.85,
## 1.15) gives subtle height variety so a multi-sprite cell doesn't
## read as obviously cloned trees / flowers. Mainly meaningful when
## density > 1; a single centred sprite looks identical regardless
## of scale roll, so leave at 1.0 for clean single-object cells.
@export var scale_min: float = 1.0
## Maximum scale multiplier. Must be ≥ scale_min. Picked uniformly
## per sprite.
@export var scale_max: float = 1.0

# True iff this spawn's dead-end pass is meaningful.
func uses_dead_ends() -> bool:
	return dead_end_chance > 0.0

# True iff this spawn's corridor pass is meaningful.
func uses_corridors() -> bool:
	return corridor_segment_chance > 0.0 and corridor_coverage_max_percent > 0.0

# True iff this spawn's room pass is meaningful.
func uses_rooms() -> bool:
	return room_chance > 0.0 and room_coverage_max_percent > 0.0

# Resolve a per-cell sprite count by sampling uniformly in
# [density_min, density_max]. Clamps to ≥ 1 so a designer who left
# both at 0 still gets one sprite per placed cell (silent zero would
# be worse — the placer already decided this cell deserves scenery).
func sample_density(rng_int: int) -> int:
	var lo: int = max(1, density_min)
	var hi: int = max(lo, density_max)
	if hi == lo:
		return lo
	return lo + (rng_int % (hi - lo + 1))

# Resolve a per-sprite scale by linearly interpolating in
# [scale_min, scale_max] at `t`. Clamps degenerate inputs (negative
# scale, max < min) to a strictly positive value so the renderer
# never collapses a sprite to zero pixel_size.
func sample_scale(rng_value: float) -> float:
	var lo: float = max(0.01, scale_min)
	var hi: float = max(lo, scale_max)
	return lo + (hi - lo) * clamp(rng_value, 0.0, 1.0)
