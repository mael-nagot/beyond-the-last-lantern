class_name LinkedObjectSpawn
extends Resource

# A biome-level entry that spawns a LEVER + DOOR pair as a coherent
# unit. Lives in BiomeData.linked_objects (separate from the normal
# `objects` array so chests/decorative-doors keep their simple shape).
#
# Each spawn produces between count_min and count_max independent
# pairs. Within a single pair, LevelGenerator places:
#   1. A door on a 1-wide-corridor edge (same rules as decorative
#      doors in Task 2a).
#   2. A lever on a chest-style cell that's reachable from the
#      entrance even when this pair's door is treated as CLOSED, so
#      the lever is always usable to clear the obstacle.
# If either step fails, both are rolled back so we never ship orphan
# half-pairs.
#
# 2b ships with one-to-one pairing. The data shape uses ObjectData
# refs (not Arrays) for clarity at this scale; richer pairing
# (1 lever ↔ many doors and many levers ↔ 1 door) is a 2b follow-up
# tracked in ROADMAP and will extend LeverInstance.linked_doors and
# DoorInstance.linked_levers (which already use Arrays internally).

@export var lever_object: ObjectData
@export var door_object: ObjectData

@export var count_min: int = 1
@export var count_max: int = 1

# Where the lever is allowed to spawn (chest-style flags).
@export_flags("Corridor", "Room", "Dead End") var lever_placement: int = ObjectSpawn.PLACEMENT_DEFAULT

# Anti-clustering: minimum Manhattan distance from the lever to ANY
# already-placed cell-bound object (chests, other levers from earlier
# pairs) — NOT specifically to the lever's own paired door. Graceful-
# degrades by 1 down to 0 if no candidate qualifies, matching the
# chest / decorative-door convention.
@export var lever_min_distance_to_other_object: int = 0
# Same anti-clustering rule for the candidate DOOR's nearest endpoint
# vs. the nearest endpoint of any already-placed door.
@export var door_min_distance_to_other_object: int = 0

@export_group("Lever ↔ Door spread")
# Manhattan distance from the lever cell to the nearest endpoint of
# its OWN paired door. These shape the puzzle's flavour:
#   - Small min, small max → lever right next to its door (obvious)
#   - Large min, large max → lever hidden far away (a real detour)
#   - Wide range            → mix of both per spawn
# Hard constraints (no graceful degrade) — if no candidate cell fits,
# the pair is skipped with a warning so the designer notices and
# adjusts the bounds.
@export var lever_to_door_min_distance: int = 0
# Maximum Manhattan distance from the lever to its paired door. Use
# -1 for "unlimited" (anywhere reachable on the map).
@export var lever_to_door_max_distance: int = -1

# Reserved for Task 2c — when true, the door's placement requires
# that closing it cuts off something meaningful (chest cell or exit).
# 2b keeps it false: the door is decorative, the lever is just an
# alternative trigger.
@export var door_must_gate_content: bool = false
