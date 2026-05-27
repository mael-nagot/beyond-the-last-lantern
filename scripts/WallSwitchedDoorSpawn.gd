class_name WallSwitchedDoorSpawn
extends Resource

# Biome-level entry that spawns wall-switch ↔ door pairs (sibling to
# `LinkedObjectSpawn` for levers and `KeyDoorSpawn` for keys). Each
# entry produces `count_min..count_max` pairs; each pair has one
# wall-mounted switch wired to one door.
#
# The puzzle shape mirrors LinkedObjectSpawn (one switch opens its
# paired door) but the placement math is fundamentally different —
# the switch lives on a wall FACE, not a floor cell, so it doesn't
# go through `cells_by_type` candidate buckets. Distance from the
# door is configured in Manhattan CELLS (`min/max_wall_distance`) and
# the lateral offset along the wall is configured in WORLD UNITS
# (`along_offset_min/max`) for consistency with the rest of
# ObjectData (`world_height`, `world_width`, `y_offset`, …).
#
# The intended use case is hidden doors: pair a `door_object` with
# `appears_as_wall = true` (so it renders as a regular wall while
# closed and disappears when open) with a switch sprite that sits
# either ON the panel itself (`max_wall_distance = 0`) or on a
# nearby real wall (`max_wall_distance > 0`). The switch is the only
# visible cue and the only interaction surface — clicking elsewhere
# on the (hidden) wall does nothing.
#
# Decorative wall-switched doors (regular visible door + a wall
# switch) also work — just leave `door_object.appears_as_wall = false`.

## The switch .tres to place. Should be an ObjectData with a switch-
## like sprite pair (closed_sprite = idle, opened_sprite = activated).
## When `hide_when_active = true` on this resource, the switch hides
## entirely after its linked door opens, turning the puzzle into a
## one-shot — only honoured for on-door (`max_wall_distance = 0`)
## placements.
@export var switch_object: ObjectData
## The door .tres to place. Should be an ObjectData of category DOOR.
## Set `appears_as_wall = true` on the door resource for a true
## secret-passage feel (wall texture closed, void open). Decorative
## visible doors also work — leave the flag false.
@export var door_object: ObjectData

## Minimum number of switch ↔ door pairs to place per level. The
## actual count may be lower if the geometry can't accommodate them
## all (each failed pair is rolled back atomically — no orphan halves
## ever ship).
@export var count_min: int = 1
## Maximum number of pairs to place per level.
@export var count_max: int = 1

@export_group("Switch placement")
## Minimum Manhattan distance (in CELLS) from the switch's view cell
## to either endpoint of the linked door. 0 = the switch may sit ON
## the door panel itself (the switch's view side points across the
## door's edge). The actual distance for each placement is sampled
## uniformly across the buckets in [min, max] that have at least one
## valid candidate — buckets with no candidates are skipped rather
## than stalling generation. Default 0.
@export var min_wall_distance: int = 0
## Maximum Manhattan distance (in CELLS) from the switch to a linked-
## door endpoint. With min = max = 0 the switch always sits on the
## door panel. With min = 0, max = 1 the placer flips between on-door
## and one-cell-away. With min = 2, max = 4 the switch lives on a
## nearby wall and the player has to look around to find it.
@export var max_wall_distance: int = 0

## Lower bound on the absolute lateral offset (in WORLD UNITS) of the
## switch along its wall direction. 0 = the switch may sit at the
## wall face's centre. Sampling: `abs_offset` is rolled uniformly in
## [along_offset_min, along_offset_max] and the sign is then
## randomised (50/50 left vs right of centre). World units because
## the rest of ObjectData speaks in world units (world_height,
## world_width, y_offset, lean_toward_player); a cell is ~4.6 world
## units wide so usable absolute values land roughly in 0.0–2.0.
@export var along_offset_min: float = 0.0
## Upper bound on the absolute lateral offset. Set both to the same
## value for a fixed offset; set both to 0 for switches that always
## sit at the wall face centre. Defaults to 0 = centred.
@export var along_offset_max: float = 0.0

@export_group("Door placement")
## Minimum Manhattan distance from each door's endpoints to ANY
## already-placed object (chests, doors, levers, traps, other wall-
## switched doors). Graceful degrade — relaxes by 1 down to 0 if no
## candidate qualifies. 0 = no rule.
@export var door_min_distance_to_other_object: int = 0

@export_group("Gating")
## When true, each placed door must gate something meaningful (at
## least one chest, lever, key, or exit cell becomes unreachable when
## the door is closed). Failed placements are rolled back atomically
## — door + switch removed together. Default false so a decorative
## wall-switched door (no required content behind it) is allowed.
@export var door_must_gate_content: bool = false
