class_name FillerSpawn
extends Resource

## A biome's filler-pool entry. "Spawn N sprites picked from `fillers`
## on every WALL cell inside the grid, plus on every cell in a
## `border_ring_depth` ring of extra cells outside the grid."
##
## A biome can hold multiple FillerSpawn entries — one for trees, one
## for bushes, one for rocks — and the placer iterates them all.

## Sprite variants to pick from per placement. One entry = always that
## sprite; multiple = uniform random pick. Empty = the spawn is a no-op.
@export var fillers: Array[FillerData] = []

@export_group("Density")
## Minimum number of sprites to place per blocked cell.
## Each cell rolls a uniform integer in [density_min, density_max].
## Set both to the same value for a fixed density. Higher values
## make the forest visually denser at the cost of more draw calls.
@export var density_min: int = 2

## Maximum number of sprites to place per blocked cell.
## Must be ≥ density_min. Picked uniformly per cell.
@export var density_max: int = 4

@export_group("Placement Spread")
## How far each sprite can scatter from its cell centre, as a
## fraction of CELL_SIZE.
## 0.0 = every sprite stacked on the cell centre (Z-fights — bad).
## 0.5 = uniformly distributed anywhere inside the cell (max spread).
## Typical 0.35–0.45 leaves a small margin so sprites in adjacent
## cells don't seam-stitch perfectly.
@export_range(0.0, 0.5) var jitter_radius: float = 0.4

## How strongly to pull sprites in WALL cells that border a FLOOR
## cell toward the floor-adjacent edge of their cell. Only the
## TOWARDS-FLOOR axis is biased — the perpendicular (along-wall) axis
## keeps its full `jitter_radius` spread so a dense cell still
## scatters laterally instead of stacking in one spot.
## 0.0 = pure random jitter (organic but visually ambiguous — a
## tree can land far from the wall line and create the illusion of
## a walkable gap; the player tries to step forward and bumps an
## invisible wall).
## 1.0 = front-row sprites pinned to the cell edge facing the floor
## (clearest wall line).
## 0.7 is a strong wall-line read with some scatter for organic feel.
## Interior wall cells (no FLOOR neighbours) and isolated pillars
## (FLOOR on all 4 sides — direction sums to zero) ignore the bias
## and keep pure random jitter.
@export_range(0.0, 1.0) var front_row_bias: float = 0.7

## How many cells beyond the grid edge to also fill with sprites.
## Without this, the player walking to the edge of the grid would
## see the floor end → sky abruptly; with it, the playable area
## sits inside a thicker frame of trees that fades into fog.
## 0 = only WALL cells inside the grid (sharp edge of world).
## 4 = ~18 metres of extra trees in every direction (default,
## enough for fog to swallow the horizon line).
## Higher = more horizon depth but more sprites to draw.
@export_range(0, 16) var border_ring_depth: int = 4

@export_group("Per-instance Scale")
## Minimum scale multiplier applied to `FillerData.world_height`
## per sprite. Both `scale_min` and `scale_max` = 1.0 → every sprite
## renders at exactly its data's `world_height`. A small range like
## (0.85, 1.15) gives subtle height variety that breaks the obvious
## "every tree is the same height" tell.
@export var scale_min: float = 0.85

## Maximum scale multiplier applied to `FillerData.world_height` per
## sprite. Must be ≥ scale_min. Picked uniformly per sprite.
@export var scale_max: float = 1.15

# Resolve a per-sprite scale by sampling uniformly in
# [scale_min, scale_max]. Clamps degenerate inputs (max < min) so the
# placer never returns a non-positive multiplier.
func sample_scale(rng_value: float) -> float:
	var lo: float = max(0.01, scale_min)
	var hi: float = max(lo, scale_max)
	return lo + (hi - lo) * clamp(rng_value, 0.0, 1.0)

# Resolve a per-cell density by sampling uniformly in
# [density_min, density_max]. Negative inputs are clamped to 0.
func sample_density(rng_int: int) -> int:
	var lo: int = max(0, density_min)
	var hi: int = max(lo, density_max)
	if hi == lo:
		return lo
	# Caller passes any non-negative int; we squash it into the range.
	return lo + (rng_int % (hi - lo + 1))

# Pick a FillerData uniformly from `fillers`. Returns null when the
# pool is empty — placer should skip the spawn entirely in that case.
func pick_filler(rng_int: int) -> FillerData:
	if fillers.is_empty():
		return null
	var idx: int = rng_int % fillers.size()
	return fillers[idx]
