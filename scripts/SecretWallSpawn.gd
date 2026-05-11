class_name SecretWallSpawn
extends Resource

# A biome-level spawn entry for a SECRET WALL. A secret wall lives on
# the edge between two adjacent 1-wide-corridor floor cells (same
# eligibility as doors) but unlike a door it never blocks movement —
# the player can walk through it freely in either direction. The
# illusion is purely visual: the DungeonView renders a normal-looking
# wall quad on that edge from both sides, so the player sees a wall
# until they walk into it. On the map the edge is marked with an "S"
# between the two perpendicular wall lines so the player has a hint
# something's there.
#
# Designers don't reference an ObjectData here — the wall texture is
# picked from the biome's existing `wall_textures` pool so the secret
# wall is indistinguishable from any other corridor wall. The spawn
# only configures placement (how many, with what content guarantee).

enum GateMode {
	NONE,          # No content-gating requirement. Designer's risk.
	ANY_CONTENT,   # Mirrors door must_gate_content: chest / lever / key / exit.
	LOOT_ONLY,     # Stricter: the gated content must be a chest or a floor item.
}

@export var count_min: int = 1
@export var count_max: int = 1

# When != NONE, placement only commits an edge if "treating this edge
# as a sealed wall" would cut off at least one content cell of the
# selected kind from the entrance. A secret wall that hides nothing is
# pointless, hence the default of ANY_CONTENT — the same gate-something
# rule key-locked doors enforce.
@export var gate_mode: GateMode = GateMode.ANY_CONTENT

# Minimum Manhattan distance (in tiles) this secret wall must keep
# from any already-placed object (chests, doors, levers, traps). 0 =
# no spacing rule. Mirrors ObjectSpawn.min_distance_to_other_object.
@export var min_distance_to_other_object: int = 0
