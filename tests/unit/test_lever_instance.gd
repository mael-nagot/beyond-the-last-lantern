extends GutTest

func _make_lever_data() -> ObjectData:
	var data := ObjectData.new()
	data.category = ObjectData.Category.LEVER
	return data

func _make_door_data() -> ObjectData:
	var data := ObjectData.new()
	data.category = ObjectData.Category.DOOR
	data.blocks_movement = true
	return data

func _make_door(opened: bool = false) -> DoorInstance:
	var inst := DoorInstance.create_door(_make_door_data(), Vector2i(0, 0), Vector2i(0, 1))
	inst.opened = opened
	return inst

# -------------------------------------------------------
# Subtype + creation
# -------------------------------------------------------

func test_create_lever_sets_data_and_clean_state() -> void:
	var data := _make_lever_data()
	var lever := LeverInstance.create_lever(data)
	assert_eq(lever.data, data)
	assert_false(lever.opened)
	assert_eq(lever.linked_doors.size(), 0)

func test_lever_is_object_instance_subtype() -> void:
	var lever := LeverInstance.create_lever(_make_lever_data())
	assert_true(lever is ObjectInstance)

func test_is_lever_true_for_levers_false_for_chests() -> void:
	var lever := LeverInstance.create_lever(_make_lever_data())
	assert_true(lever.is_lever())
	var chest_data := ObjectData.new()
	chest_data.category = ObjectData.Category.CHEST
	var chest := ObjectInstance.create(chest_data)
	# Plain ObjectInstance has no is_lever() method, so we just ensure
	# that whatever a chest is, it isn't a LeverInstance.
	assert_false(chest is LeverInstance)

func test_lever_is_chest_returns_false() -> void:
	var lever := LeverInstance.create_lever(_make_lever_data())
	assert_false(lever.is_chest())

# -------------------------------------------------------
# get_visual_opened — derives sprite state from linked doors
# -------------------------------------------------------

func test_orphan_lever_is_visually_closed() -> void:
	var lever := LeverInstance.create_lever(_make_lever_data())
	assert_false(lever.get_visual_opened())

func test_lever_mirrors_single_linked_door_state() -> void:
	var lever := LeverInstance.create_lever(_make_lever_data())
	var door := _make_door(false)
	lever.linked_doors = [door]
	assert_false(lever.get_visual_opened())
	door.opened = true
	assert_true(lever.get_visual_opened())

func test_lever_visually_open_when_any_linked_door_is_open() -> void:
	# 2b ships 1-to-1 but the data shape supports many; the
	# "any open" rule is what 2b commits to and the test pins it.
	var lever := LeverInstance.create_lever(_make_lever_data())
	var door_a := _make_door(false)
	var door_b := _make_door(false)
	lever.linked_doors = [door_a, door_b]
	assert_false(lever.get_visual_opened())
	door_b.opened = true
	assert_true(lever.get_visual_opened())

func test_lever_does_not_overwrite_chest_get_visual_opened_contract() -> void:
	# Sanity: a plain ObjectInstance still derives its visual from
	# its own `opened` field. The lever override doesn't bleed into
	# the parent class.
	var chest_data := ObjectData.new()
	chest_data.category = ObjectData.Category.CHEST
	var chest := ObjectInstance.create(chest_data)
	assert_false(chest.get_visual_opened())
	chest.opened = true
	assert_true(chest.get_visual_opened())
