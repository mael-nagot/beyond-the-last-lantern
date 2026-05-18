class_name ProjectileTrapSpawn
extends Resource

# A biome's projectile-trap pool entry. Phase 8 Task 3 — Subtask C.
#
# Two placement modes:
#
#   - Corridor: per-segment chance, when fired, attempts to mount up to
#     `corridor_max_per_segment` launchers inside the segment whose
#     fire direction reaches a junction within
#     `ProjectileTrapData.max_escape_distance` tiles. (Subtask C1.)
#
#   - Room: per-room chance (Subtask C5 — fields defined now,
#     placement code lands in C5).
#
# Modes are additive — a spawn can use either or both. Set
# `corridor_chance = 0.0` to disable the corridor pass; set
# `room_chance = 0.0` to disable the room pass. Defaults preserve
# silence (no projectile traps placed) until the developer opts in.
#
# Reuses `ObjectSpawn.PLACEMENT_*` flag bits so designers can think
# about objects / decorations / spike traps / projectile traps with
# one mental model.

## The projectile-trap template (launcher) this spawn places.
@export var trap: ProjectileTrapData

@export_group("Placement flags")
## Which cell classifications launchers may attach to. Corridor =
## standard 1-wide passage; Room = bigger open space; Dead End =
## tip of a tunnel. The placer skips the corridor pass if Corridor
## isn't ticked, and skips the room pass if Room isn't ticked.
@export_flags("Corridor", "Room", "Dead End") var placement: int = ObjectSpawn.PLACEMENT_ANY

@export_group("Corridor placement (per-segment)")
## Probability in [0, 1] that any given corridor segment receives a
## projectile launcher from this spawn. Rolled per segment, per
## spawn. 0 disables the corridor pass entirely. 1 attempts a
## launcher in every eligible segment.
@export_range(0.0, 1.0) var corridor_chance: float = 0.0
## Maximum launchers placed in a single corridor segment when the
## segment is chosen. Usually 1 — a corridor with two launchers
## feels like crossfire and undermines the "fire toward the
## junction" escape guarantee. Designers can crank this higher for
## set-piece moments.
@export var corridor_max_per_segment: int = 1

@export_group("Room placement (per-room) — Subtask C5")
## Probability in [0, 1] that any given room receives a projectile
## launcher from this spawn. 0 disables the room pass entirely.
@export_range(0.0, 1.0) var room_chance: float = 0.0
## Maximum launchers placed in a single room when the room is
## chosen. 1 keeps room launchers as set pieces; 2+ creates "kill
## room" scenarios where multiple lines of fire cross.
@export var room_max_per_room: int = 1

func allows(placement_type: int) -> bool:
	return (placement & placement_type) != 0

# True iff this spawn requests any corridor placement. Used by
# `LevelGenerator` to skip the corridor pass when chance is zero.
func uses_corridor() -> bool:
	return corridor_chance > 0.0 and corridor_max_per_segment > 0

# True iff this spawn requests any room placement. Used by
# `LevelGenerator` to skip the room pass when chance is zero. Wired
# in Subtask C5.
func uses_room() -> bool:
	return room_chance > 0.0 and room_max_per_room > 0
