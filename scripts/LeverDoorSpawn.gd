class_name LeverDoorSpawn
extends Resource

@export var lever_object: ObjectData
@export var door_object: ObjectData

# count_min / count_max now count CLUSTERS.
@export var count_min: int = 1
@export var count_max: int = 1

@export_group("Cluster shape")
@export var levers_per_cluster: int = 1
@export var doors_per_cluster: int = 1
# 0 = AND (all levers must be pulled), 1 = OR (any one suffices).
@export_enum("AND", "OR") var lever_logic: int = 0

@export_group("Lever placement")
@export_flags("Corridor", "Room", "Dead End") var lever_placement: int = ObjectSpawn.PLACEMENT_DEFAULT
@export var lever_min_distance_to_other_object: int = 0

@export_group("Door placement")
@export var door_min_distance_to_other_object: int = 0

@export_group("Lever ↔ Door spread")
@export var lever_to_door_min_distance: int = 0
@export var lever_to_door_max_distance: int = -1

@export_group("Gating")
@export var door_must_gate_content: bool = false
