extends GutTest

func test_defaults() -> void:
	var data := SceneryData.new()
	assert_eq(data.name_key, "")
	assert_eq(data.description_key, "")
	assert_true(data.walkable, "scenery should default to walkable so an unconfigured resource never blocks the dungeon")
	assert_null(data.texture)
	assert_almost_eq(data.world_height, 1.0, 0.0001)
	assert_almost_eq(data.y_offset, 0.0, 0.0001)
	assert_almost_eq(data.lean_toward_player, 0.0, 0.0001)

func test_non_walkable_flag() -> void:
	var data := SceneryData.new()
	data.walkable = false
	assert_false(data.walkable)

func test_get_display_name_returns_tr_of_key() -> void:
	var data := SceneryData.new()
	data.name_key = "scenery.test.name"
	# tr() returns the key itself when no translation is registered,
	# which is exactly what we want to assert against.
	assert_eq(data.get_display_name(), tr("scenery.test.name"))

func test_get_display_description_returns_tr_of_key() -> void:
	var data := SceneryData.new()
	data.description_key = "scenery.test.description"
	assert_eq(data.get_display_description(), tr("scenery.test.description"))
