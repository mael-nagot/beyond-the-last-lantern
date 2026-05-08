class_name BiomeTextureEntry
extends Resource

# One entry in a biome's wall / floor / ceiling texture pool. Pairs an
# albedo + normal so the two can never get out of sync (the previous
# flat-array setup picked them independently and could land
# wall_bark_01_albedo with wall_bark_02_normal). The placement flag-set
# scopes the entry to specific cell classifications: a "mossy dead-end"
# wall variant only spawns on dead-end cells; a "vaulted room ceiling"
# only on room cells; etc. Empty / unmatched arrays fall back to the
# full pool — see `pick_for`.

const PLACEMENT_CORRIDOR := 1
const PLACEMENT_ROOM     := 2
const PLACEMENT_DEAD_END := 4
const PLACEMENT_ANY      := PLACEMENT_CORRIDOR | PLACEMENT_ROOM | PLACEMENT_DEAD_END

@export var albedo: Texture2D
@export var normal: Texture2D
@export_flags("Corridor", "Room", "Dead End") var placement: int = PLACEMENT_ANY

func allows(placement_type: int) -> bool:
	return (placement & placement_type) != 0

# Deterministically picks one entry for the given (classification, cell_pos)
# pair. Same cell + same entry array = same pick every call, so textures
# don't reshuffle between mesh rebuilds, save/load, or replays of the
# same level seed. Filters by classification first; falls back to the
# full entry list if nothing matches (designer intent: render *something*
# rather than a blank face). Returns null only when the array is empty
# or contains no usable entries.
static func pick_for(entries: Array, classification: int, cell_pos: Vector2i) -> BiomeTextureEntry:
	if entries.is_empty():
		return null
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
	var hash: int = ((cell_pos.x * 7919) ^ (cell_pos.y * 6271)) & 0x7FFFFFFF
	return matching[hash % matching.size()]
