class_name LeverInstance
extends ObjectInstance

var linked_doors: Array = []  # Array[DoorInstance]
var pulled: bool = false

static func create_lever(p_data: ObjectData) -> LeverInstance:
	var inst := LeverInstance.new()
	inst.data = p_data
	return inst

func is_lever() -> bool:
	return true

func toggle() -> void:
	pulled = not pulled

func get_visual_opened() -> bool:
	return pulled
