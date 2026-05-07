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
	# Plain ObjectInstance has no is_lever() method, so we just ensure
	# that whatever a chest is, it isn't a LeverInstance.
	assert_false(chest is LeverInstance)

func test_lever_is_chest_returns_false() -> void:
	var lever := LeverInstance.create_lever(_make_lever_data())
	assert_false(lever.is_chest())

# -------------------------------------------------------
# get_visual_opened — derived from the lever's own pulled state
# -------------------------------------------------------

func test_orphan_lever_is_visually_closed() -> void:
	var lever := LeverInstance.create_lever(_make_lever_data())
	assert_false(lever.get_visual_opened())

func test_visual_state_tracks_pulled_field() -> void:
	# 2b follow-up: lever's visual derives from its OWN pulled bool,
	# not from any linked door. Pulling toggles `pulled`.
	var lever := LeverInstance.create_lever(_make_lever_data())
	assert_false(lever.get_visual_opened())
	lever.toggle()
	assert_true(lever.pulled)
	assert_true(lever.get_visual_opened())
	lever.toggle()
	assert_false(lever.pulled)
	assert_false(lever.get_visual_opened())

func test_visual_state_independent_of_linked_door_state() -> void:
	# Inverse of the old 2b "mirror" test: confirms that a lever's
	# sprite no longer follows its linked door — multi-door /
	# multi-lever clusters need each lever to track its own state.
	var lever := LeverInstance.create_lever(_make_lever_data())
	var door := _make_door(false)
	lever.linked_doors = [door]
	door.opened = true
	# Door is open but the lever was never pulled.
	assert_false(lever.get_visual_opened())

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
