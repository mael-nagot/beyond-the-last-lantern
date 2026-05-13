class_name TeleporterSpawn
extends Resource

# A biome's teleporter-pool config. Phase 15 Task 6.
#
# Singular (NOT array) on BiomeData — one teleporter style per biome.
# Each pair shares the same `data` (visual + SFX); the map glyph hue
# is auto-rotated per pair (via TeleporterInstance.pair_index) so the
# player can tell pairs apart on the map.
#
# Two modes share this resource (driven by `island_count_max`):
#
# - **Phase A "dumb warp" / shortcut mode** (`island_count_max <= 1`):
#   places `count_min..count_max` pairs at random non-special floor
#   cells. No partitioning — the warp is a pure shortcut.
#
# - **Phase C "island topology"** (`island_count_max >= 2`): runs
#   FIRST (after `_validate_path()`), seals `K-1` articulation
#   corridor cells to WALL where K is rolled in
#   `[island_count_min, island_count_max]`, then places K-1
#   teleporter pairs as a spanning tree connecting the K resulting
#   islands. The teleporter graph is the ONLY way to cross island
#   boundaries; chain reachability v3 makes lever / key / chest
#   placement automatically island-aware. `count_min/count_max` are
#   IGNORED in this mode (pair count is derived from K).

@export var data: TeleporterData

@export_group("Island topology (Phase C)")
# Inclusive range — the placer rolls one value per level in
# [island_count_min, island_count_max]. K islands → K-1 sealed
# articulation cells + K-1 teleporter pairs forming a spanning tree.
# Default `1` for both (NO partition) so existing biomes that only
# set `count_min/count_max` keep Phase A behaviour. Set both to 2 for
# the standard "one seal, one pair across" island topology.
@export var island_count_min: int = 1
@export var island_count_max: int = 1

# Minimum Manhattan distance from a sealed corridor cell to entrance
# AND to exit. Keeps the seal away from the player's start point and
# from the win condition — sealing right next to the entrance reads
# as "the level is broken", sealing right next to the exit defeats
# the partition's purpose because the player would walk straight to
# the exit without crossing the warp. Graceful degrade down to 0.
@export var min_seal_distance_to_entrance_exit: int = 4

# Minimum Manhattan distance between any two sealed corridor cells
# when K >= 3. Spreads seals out so K=3 doesn't bunch two walls into
# a 2-cell stub island. Graceful degrade down to 0. Ignored for K=2
# (only one seal). Ignored entirely when partitioning is disabled.
@export var min_seal_distance_between_seals: int = 5

# Minimum number of floor cells in the SMALLER component produced by
# a candidate seal. A seal that cuts off a 1-3 cell stub strands the
# warp on an empty stub with nothing for the player to do over there
# — they warp, see nothing, warp back. Default 8 cells: large enough
# to host a chest + a couple of items + breathing room. The placer
# rejects candidates below this threshold AND prefers candidates with
# LARGER smaller-island sizes (closer to a 50/50 split) so the warp
# typically leads to a meaningful sub-region rather than a stub.
@export var min_island_size: int = 8

@export_group("Shortcut pairs (Phase A mode + extras)")
# Inclusive range — the placer rolls one value in [count_min, count_max].
# - Phase A mode (island_count_max <= 1): this IS the pair count.
# - Phase C mode (island_count_max >= 2): IGNORED — pair count is K-1.
# Set both to 0 to disable shortcut pairs entirely.
@export var count_min: int = 1
@export var count_max: int = 1

@export_group("Pair geometry")
# Minimum Manhattan distance between a pair's two endpoints. Default
# 6 so a warp visibly traverses the map rather than feeling like a
# single step. Set 0 to disable the constraint. Treated as a
# preference: the placer relaxes the constraint by 1 down to 0 if no
# candidate qualifies (graceful degrade, same pattern as spinners /
# traps / items).
@export var min_distance_between_partners: int = 6

# Minimum Manhattan distance from EITHER endpoint to any cell that
# already holds an object (chest / lever / door endpoint), trap,
# spinner, pressure plate, or floor item. Also keeps a buffer from
# entrance / exit. Graceful degrade down to 0.
@export var min_distance_to_other_object: int = 2

# Minimum Manhattan distance from EITHER endpoint to any other
# teleporter endpoint placed earlier in this level. Keeps pairs from
# stacking on top of each other when more than one pair exists.
# Graceful degrade.
@export var min_distance_to_other_teleporter: int = 4

# Phase C predicate — true iff the placer should run the partition
# pass (seal articulation cells + spanning-tree pair placement). When
# false, the placer runs Phase A's "dumb random shortcut pairs"
# pipeline instead. Helper rather than raw comparison so the rule
# stays in one place.
func uses_partition() -> bool:
	return island_count_max >= 2
