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
	assert_false(lever.pulled)
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
	assert_false(chest is LeverInstance)

func test_lever_is_chest_returns_false() -> void:
	var lever := LeverInstance.create_lever(_make_lever_data())
	assert_false(lever.is_chest())

# -------------------------------------------------------
# toggle — flips the lever's own pulled state
# -------------------------------------------------------

func test_toggle_flips_pulled() -> void:
	var lever := LeverInstance.create_lever(_make_lever_data())
	assert_false(lever.pulled)
	lever.toggle()
	assert_true(lever.pulled)
	lever.toggle()
	assert_false(lever.pulled)

# -------------------------------------------------------
# get_visual_opened — mirrors pulled state directly
# -------------------------------------------------------

func test_unpulled_lever_is_visually_closed() -> void:
	var lever := LeverInstance.create_lever(_make_lever_data())
	assert_false(lever.get_visual_opened())

func test_pulled_lever_is_visually_open() -> void:
	var lever := LeverInstance.create_lever(_make_lever_data())
	lever.toggle()
	assert_true(lever.get_visual_opened())

func test_visual_state_independent_of_linked_doors() -> void:
	var lever := LeverInstance.create_lever(_make_lever_data())
	var door := _make_door(true)
	lever.linked_doors = [door]
	assert_false(lever.get_visual_opened(), "unpulled lever stays visually closed regardless of door state")
	lever.toggle()
	assert_true(lever.get_visual_opened())
	door.opened = false
	assert_true(lever.get_visual_opened(), "pulled lever stays visually open regardless of door state")

func test_lever_does_not_overwrite_chest_get_visual_opened_contract() -> void:
	var chest_data := ObjectData.new()
	chest_data.category = ObjectData.Category.CHEST
	var chest := ObjectInstance.create(chest_data)
	assert_false(chest.get_visual_opened())
	chest.opened = true
	assert_true(chest.get_visual_opened())
