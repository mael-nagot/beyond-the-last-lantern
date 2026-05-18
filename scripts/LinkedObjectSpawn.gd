class_name LinkedObjectSpawn
extends Resource

## The lever .tres to place. Should be an ObjectData of category
## LEVER. One per cluster member, count controlled by
## `levers_per_cluster`.
@export var lever_object: ObjectData
## The door .tres to place. Should be an ObjectData of category DOOR.
## One per cluster member, count controlled by `doors_per_cluster`.
@export var door_object: ObjectData

## Minimum number of CLUSTERS to place per level (a cluster = M
## levers cross-linked to N doors). Not the lever / door count
## directly — see `levers_per_cluster` / `doors_per_cluster`.
@export var count_min: int = 1
## Maximum number of clusters to place per level. Placement attempts
## up to this many; the actual count may be lower if the geometry
## can't accommodate them all (chain reachability rolls back failed
## clusters atomically).
@export var count_max: int = 1

@export_group("Cluster shape")
## How many levers each cluster contains. Multiple levers per door
## set up "find both switches" or "any switch opens it" puzzles
## depending on `lever_logic`.
@export var levers_per_cluster: int = 1
## How many doors each cluster contains. All doors in a cluster
## share the SAME lever set and the SAME `lever_logic`.
@export var doors_per_cluster: int = 1
## How a door evaluates its linked levers' pulled states. AND = ALL
## levers must be pulled before the door opens (puzzle). OR = ANY
## one pulled lever opens the door (shortcut / convenience).
@export_enum("AND", "OR") var lever_logic: int = 0

@export_group("Lever placement")
## Which cell classifications a lever may land on. Corridors give a
## "find the switch" feel; rooms feel more "set piece"; dead-ends are
## "hidden tucked away".
@export_flags("Corridor", "Room", "Dead End") var lever_placement: int = ObjectSpawn.PLACEMENT_DEFAULT
## Minimum Manhattan distance from each lever to ANY already-placed
## object (chests, doors, other levers, traps). Graceful degrade —
## relaxes by 1 down to 0 if no candidate qualifies. 0 = no rule.
@export var lever_min_distance_to_other_object: int = 0

@export_group("Door placement")
## Minimum Manhattan distance from each door's endpoints to ANY
## already-placed object. Graceful degrade. 0 = no rule.
@export var door_min_distance_to_other_object: int = 0

@export_group("Lever ↔ Door spread")
## Minimum Manhattan distance between each lever and the NEAREST
## door endpoint of its cluster. Small (~1–3) = lever sits visibly
## near the door. Large (~10+) = lever is hidden far away ("search
## for it"). Graceful degrade after ~30 attempts.
@export var lever_to_door_min_distance: int = 0
## Maximum Manhattan distance between each lever and the nearest
## cluster door endpoint. -1 = unlimited. Graceful degrade after
## ~30 attempts.
@export var lever_to_door_max_distance: int = -1

@export_group("Gating")
## When true, at least one door in the cluster must gate something
## meaningful (a chest, lever, key, or exit cell becomes unreachable
## when this door is closed). Failed clusters are rolled back
## atomically (all doors + all levers). Default false: decorative
## lever-door clusters are allowed.
@export var door_must_gate_content: bool = false
