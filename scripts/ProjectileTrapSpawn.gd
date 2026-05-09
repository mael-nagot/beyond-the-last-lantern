class_name ProjectileTrapSpawn
extends Resource

# A biome's projectile-trap pool entry. Phase 8 Task 3 follow-up.
#
# Controls WHERE and HOW MANY wall-mounted projectile traps are placed
# during level generation. Two placement modes (additive):
#
#   - Corridor: launcher at one extremity of a corridor segment, firing
#     toward a junction so the player has an escape route. Segment must
#     be short enough that the player can reach the junction in time
#     (capped by `max_escape_distance`).
#
#   - Room: launcher on an eligible wall face inside a room. The
#     projectile path is traced in full — if it would exit the room
#     into a corridor, the face is rejected (prevents unavoidable
#     damage in corridors).
#
# PRESSURE_PLATE traps additionally place a floor plate linked to the
# launcher. Distance constraints ensure the plate is close enough to
# an escape route (junction or room exit) and far enough from the
# launcher for the player to see the projectile and react.

@export var trap: ProjectileTrapData

@export_group("Corridor placement")
# Probability in [0, 1] that any given corridor segment receives a
# launcher of this type. Rolled per segment. 0 disables corridor
# placement entirely.
@export_range(0.0, 1.0) var corridor_segment_chance: float = 0.0
# Max segment length (in cells) from launcher to the nearest junction.
# Caps how far the player has to run to reach safety. Segments longer
# than this are skipped.
@export var max_escape_distance: int = 5
# Max launchers of this type per corridor segment. Usually 1 — a
# single launcher per corridor end.
@export var max_per_corridor_segment: int = 1

@export_group("Room placement")
# Probability in [0, 1] that any given room receives launchers of
# this type. Rolled per room. 0 disables room placement entirely.
@export_range(0.0, 1.0) var room_chance: float = 0.0
# Max launchers of this type per room.
@export var max_per_room: int = 2

@export_group("Pressure plate placement")
# Max distance (in cells) from the pressure plate to the nearest
# junction (corridor) or room exit. Keeps the plate close enough to
# an escape route so the player can dodge after triggering.
@export var max_plate_to_junction_distance: int = 2
# Min distance (in cells) from the pressure plate to the launcher.
# Ensures the projectile has enough travel time for the player to
# see it and react (plate too close to launcher = projectile arrives
# instantly).
@export var min_plate_to_launcher_distance: int = 3

@export_group("Spreading")
# Manhattan distance (in tiles) this trap's launchers must keep from
# any other already-placed projectile trap launcher. Graceful-
# degrade-by-1 down to 0 if the constraint can't be satisfied.
@export var min_distance_to_other_projectile_trap: int = 3


func uses_corridor_placement() -> bool:
	return corridor_segment_chance > 0.0

func uses_room_placement() -> bool:
	return room_chance > 0.0
