extends GutTest

func test_default_field_values() -> void:
	var data := ObjectData.new()
	assert_eq(data.name_key, "")
	assert_eq(data.description_key, "")
	assert_eq(data.category, ObjectData.Category.CHEST)
	assert_true(data.blocks_movement)
	assert_null(data.closed_sprite)
	assert_null(data.opened_sprite)
	assert_eq(data.world_height, 1.0)
	assert_eq(data.y_offset, 0.0)
	assert_eq(data.lean_toward_player, 0.0)
	assert_eq(data.popup_delay, 0.0)
	assert_null(data.interact_sound)

func test_get_display_name_resolves_known_key() -> void:
	var data := ObjectData.new()
	data.name_key = "object.chest_wooden.name"
	assert_eq(data.get_display_name(), "Wooden Chest")

func test_get_display_description_resolves_known_key() -> void:
	var data := ObjectData.new()
	data.description_key = "object.chest_wooden.description"
	assert_eq(data.get_display_description(), "A sturdy wooden chest.")

func test_unknown_key_falls_back_to_key() -> void:
	var data := ObjectData.new()
	data.name_key = "object.does_not_exist.name"
	assert_eq(data.get_display_name(), "object.does_not_exist.name")
