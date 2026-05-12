class_name TeleporterSpawn
extends Resource

# A biome's teleporter-pool config. Phase 15 Task 6.
#
# Singular (NOT array) on BiomeData — one teleporter style per biome.
# `count_min` / `count_max` drive the number of PAIRS placed per
# level. Each pair shares the same `data` (visual + SFX); the map
# glyph hue is auto-rotated per pair (via TeleporterInstance.pair_index)
# so the player can tell pairs apart on the map.
#
# Phase A (current): pairs are placed at random non-special floor
# cells satisfying the distance constraints. No partitioning — the
# warp is purely a shortcut. Phase C (island topology) will add
# island_count_min/max + seal-distance fields and replace the random
# placement with a partition-then-spanning-tree placement.

@export var data: TeleporterData

@export_group("Pair count")
# Inclusive range — the placer rolls one value per level in
# [count_min, count_max] and places that many pairs. Set count_max
# to 0 to disable teleporter generation for the biome entirely.
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
# stacking on top of each other when count > 1. Graceful degrade.
@export var min_distance_to_other_teleporter: int = 4
