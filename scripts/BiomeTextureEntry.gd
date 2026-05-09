class_name BiomeTextureEntry
extends Resource

# One entry in a biome's wall / floor / ceiling texture pool. Holds
# the albedo texture and a placement flag-set that scopes the entry to
# specific cell classifications: a "mossy dead-end" wall variant only
# spawns on dead-end cells; a "vaulted room ceiling" only on room
# cells; etc. Empty / unmatched arrays fall back to the full pool —
# see `pick_for`.
#
# Normal maps were intentionally dropped — the chunky pixel art + the
# ambient-only lighting model don't benefit from per-pixel surface
# relief, and bundling a `normal` field on the entry was the original
# motivation for grouping albedo+normal together (so they couldn't
# desync). Without normals, the entry is just (albedo + scope rules).

const PLACEMENT_CORRIDOR := 1
const PLACEMENT_ROOM     := 2
const PLACEMENT_DEAD_END := 4
const PLACEMENT_ANY      := PLACEMENT_CORRIDOR | PLACEMENT_ROOM | PLACEMENT_DEAD_END

@export var albedo: Texture2D
@export_flags("Corridor", "Room", "Dead End") var placement: int = PLACEMENT_ANY

# Relative pick frequency among entries that pass classification +
# distance filters. weight = 0 excludes the entry from rolls (useful
# for designers temporarily disabling a variant without removing it);
# negative values are clamped to 0. If every eligible entry has weight
# 0 we fall back to a uniform pick so a quad never goes blank.
@export var weight: int = 1

# Minimum Manhattan distance (in tiles) to the nearest already-placed
# cell using the SAME entry. Use ~3-5 to spread a "rare cracked stone"
# variant out instead of letting it cluster. 0 = no spacing rule. If
# the constraint can't be satisfied at a cell (every matching entry
# would violate its own rule), the picker relaxes the rule and picks
# anyway — better a slight cluster than a missing texture.
@export var min_distance_to_same: int = 0

func allows(placement_type: int) -> bool:
	return (placement & placement_type) != 0

# Deterministically picks one entry for the given (classification, cell_pos)
# pair. Same cell + same entry array + same history = same pick every
# call, so textures don't reshuffle between mesh rebuilds, save/load,
# or replays of the same level seed.
#
# `placed_history` maps each entry to an array of cell positions where
# it has already been placed (caller appends after picking). Pass an
# empty dictionary when distance constraints aren't relevant (tests,
# single-pick callers).
#
# Filter order: classification → min_distance → weighted-by-hash pick.
# Each filter falls back to the previous stage's set if it would empty
# the pool — designer intent is "render *something* rather than a
# blank face".
static func pick_for(
	entries: Array,
	classification: int,
	cell_pos: Vector2i,
	placed_history: Dictionary = {}
) -> BiomeTextureEntry:
	if entries.is_empty():
		return null
	# Stage 1: classification match, with full-pool fallback.
	var matching: Array = []
	for entry in entries:
		if entry != null and entry.allows(classification):
			matching.append(entry)
	if matching.is_empty():
		for entry in entries:
			if entry != null:
				matching.append(entry)
	if matching.is_empty():
		return null
	# Stage 2: distance filter. An entry is eligible if no prior
	# placement of the SAME entry sits within its `min_distance_to_same`
	# Manhattan tiles of `cell_pos`. Falls back to the matching pool if
	# the constraint excludes everything.
	var eligible: Array = []
	for entry in matching:
		if _passes_distance(entry, cell_pos, placed_history):
			eligible.append(entry)
	if eligible.is_empty():
		eligible = matching
	# Stage 3: deterministic weighted pick from a position hash.
	return _weighted_pick(eligible, cell_pos)

static func _passes_distance(
	entry: BiomeTextureEntry,
	cell_pos: Vector2i,
	placed_history: Dictionary
) -> bool:
	var min_dist: int = entry.min_distance_to_same
	if min_dist <= 0:
		return true
	if not placed_history.has(entry):
		return true
	for prev in placed_history[entry]:
		var d: int = abs(cell_pos.x - prev.x) + abs(cell_pos.y - prev.y)
		if d < min_dist:
			return false
	return true

static func _weighted_pick(entries: Array, cell_pos: Vector2i) -> BiomeTextureEntry:
	var total: int = 0
	for entry in entries:
		total += max(0, entry.weight)
	var pos_hash: int = ((cell_pos.x * 7919) ^ (cell_pos.y * 6271)) & 0x7FFFFFFF
	# Degenerate: every entry has weight 0. Fall back to uniform pick
	# so the quad still gets a texture instead of crashing.
	if total <= 0:
		return entries[pos_hash % entries.size()]
	var roll: int = pos_hash % total
	var cumulative: int = 0
	for entry in entries:
		cumulative += max(0, entry.weight)
		if roll < cumulative:
			return entry
	return entries[entries.size() - 1]
