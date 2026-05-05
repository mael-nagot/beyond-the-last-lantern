class_name DungeonDropTarget
extends Control

# Transparent overlay that lives on top of the dungeon viewport and
# accepts ItemSlotButton drags. Emits item_dropped so DungeonView can
# place the stack on the player's current cell.

signal item_dropped(slot_index: int, instance: ItemInstance)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

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
