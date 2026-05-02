class_name PartyPanel
extends HBoxContainer

@onready var slots: Array[CharacterSlot] = [
	$Slot0,
	$Slot1,
	$Slot2,
]

func get_slot(index: int) -> CharacterSlot:
	if index >= 0 and index < slots.size():
		return slots[index]
	return null
