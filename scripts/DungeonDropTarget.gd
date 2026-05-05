class_name DungeonDropTarget
extends Control

# Transparent overlay that lives on top of the dungeon viewport.
#
# Two responsibilities:
#   - Catches ItemSlotButton drags landing on the dungeon view (drop
#     payload validated, item_dropped signal emitted).
#   - On left-click, raycasts from the camera through the click
#     position and, if the ray hits an Area3D tagged with object
#     metadata, emits object_clicked. This is how chest interaction
#     works without enabling the SubViewport's physics_object_picking
#     (which conflicts with the drag-drop mouse-filter setup).

const RAY_MAX_DISTANCE := 100.0

signal item_dropped(slot_index: int, instance: ItemInstance)
signal object_clicked(instance: ObjectInstance, grid_pos: Vector2i)

# Set by DungeonView after construction so we can project clicks to
# 3D world rays.
var camera: Camera3D = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

# -------------------------------------------------------
# Drag & drop
# -------------------------------------------------------

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if data.get("type") != ItemSlotButton.DRAG_TYPE:
		return false
	var instance = data.get("instance")
	return instance is ItemInstance

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var instance: ItemInstance = data.get("instance")
	var slot_index: int = data.get("slot_index", -1)
	item_dropped.emit(slot_index, instance)

# -------------------------------------------------------
# Click → 3D raycast → object_clicked signal
# -------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if not event.pressed:
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	# Drag-related events flow through _can_drop_data / _drop_data, not
	# _gui_input, but guard anyway in case the engine reorders things.
	if get_viewport().gui_is_dragging():
		return
	_handle_click(event.position)

func _handle_click(local_pos: Vector2) -> void:
	if camera == null:
		return
	var from := camera.project_ray_origin(local_pos)
	var dir  := camera.project_ray_normal(local_pos)
	var to   := from + dir * RAY_MAX_DISTANCE
	var space_state := camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas  = true
	query.collide_with_bodies = false
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return
	var collider = result.get("collider")
	if collider == null:
		return
	var instance = collider.get_meta("object_instance", null)
	var grid_pos = collider.get_meta("grid_pos", Vector2i(-1, -1))
	if instance is ObjectInstance:
		object_clicked.emit(instance, grid_pos)
