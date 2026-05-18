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
	LOOT_ONLY,     # Stricter: the gated cells must be a chest OR a non-key
	               # floor item AND the wall MUST NOT also gate the exit,
	               # a lever, or any key. A secret wall behind the main
	               # path forces the player to find the secret to progress;
	               # LOOT_ONLY explicitly rejects that, leaving secret walls
	               # as optional side-paths to bonus loot.
}

## Minimum number of secret walls to attempt placing per level.
@export var count_min: int = 1
## Maximum number of secret walls to attempt placing per level.
## Actual count may be lower if the geometry can't satisfy the
## chosen `gate_mode` constraint.
@export var count_max: int = 1

## What the secret wall must hide.
## NONE = no requirement (the wall can sit anywhere — designer's risk
## that it hides nothing).
## ANY_CONTENT = sealing this edge must cut off at least one chest,
## lever, key, or exit cell from the entrance (default).
## LOOT_ONLY = stricter — must hide a chest or non-key floor item
## AND must NOT also gate progression (exit, lever, key). Lets
## designers ship secret walls as pure optional side-rewards.
@export var gate_mode: GateMode = GateMode.ANY_CONTENT

## Minimum Manhattan distance (in tiles) this secret wall must keep
## from any already-placed object (chests, doors, levers, traps,
## other secret walls). 0 = no spacing rule. Triggers farthest-point
## insertion when > 0, graceful degrade with warning when geometry
## can't satisfy.
@export var min_distance_to_other_object: int = 0
