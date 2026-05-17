class_name FillerSpawn
extends Resource

# A biome's filler-pool entry. "Spawn `density_min..density_max`
# sprites picked uniformly from `fillers` on every WALL cell inside
# the grid, plus on every cell in a `border_ring_depth` ring of
# extra cells outside the grid (so the playable area sits inside a
# thicker frame of trees that fades into fog instead of an abrupt
# edge of world)."
#
# A biome can hold multiple FillerSpawn entries — one for trees, one
# for bushes, one for rocks — and the renderer iterates them all. The
# spawn doesn't carry placement flags (Corridor/Room/Dead End) because
# fillers go on WALL cells, not floor cells; the "where" is implicit.

# Sprite variants to pick from per placement. One entry = always that
# sprite; multiple = uniform random pick. Empty = the spawn is a
# no-op.
@export var fillers: Array[FillerData] = []

@export_group("Density")
# Number of sprites to place per blocked cell. Picked uniformly per
# cell in [density_min, density_max]. Set both to the same value for
# a fixed density. 0 = the cell stays empty (you generally won't want
# this — that's what `border_ring_depth = 0` is for).
@export var density_min: int = 2
@export var density_max: int = 4

@export_group("Placement Spread")
# Maximum offset from the cell centre, as a fraction of CELL_SIZE.
# 0.0 = every sprite stacked on the cell centre (visibly bad — they
# Z-fight and look like one tree). 0.5 = uniformly distributed
# anywhere inside the cell. Typical values 0.35–0.45 — close to full
# spread but leaves a small margin so two sprites in adjacent cells
# don't seam-stitch perfectly.
@export_range(0.0, 0.5) var jitter_radius: float = 0.4

# Number of cells beyond the grid edge to also fill. 0 = only WALL
# cells inside the grid (you'll see floor end → sky abruptly at the
# grid border). 4 = 4 extra cells in every direction (~18 metres,
# enough for fog to swallow the horizon line). Higher = more horizon
# depth but more sprites to draw.
@export_range(0, 16) var border_ring_depth: int = 4

@export_group("Per-instance Scale")
# Random scale multiplier applied to `FillerData.world_height` per
# sprite. Both = 1.0 → every sprite renders at exactly its data's
# `world_height`. (0.85, 1.15) gives subtle size variety that breaks
# the obvious "every tree is the same height" tell.
@export var scale_min: float = 0.85
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
