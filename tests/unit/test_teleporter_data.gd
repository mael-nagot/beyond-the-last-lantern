extends GutTest

func test_default_field_values() -> void:
	var data := TeleporterData.new()
	assert_eq(data.name_key, "")
	assert_eq(data.description_key, "")
	assert_null(data.decal_sprite)
	assert_null(data.frames)
	assert_eq(data.decal_world_size, 1.0)
	assert_eq(data.y_offset, 0.01)
	assert_eq(data.light_color, Color(1.0, 0.7, 0.4))
	assert_eq(data.light_energy, 1.0)
	assert_eq(data.light_range, 3.0)
	assert_null(data.warp_sound)
	assert_null(data.seal_sound)

func test_get_display_name_unknown_key_falls_back_to_key() -> void:
	var data := TeleporterData.new()
	data.name_key = "object.teleporter_does_not_exist.name"
	assert_eq(data.get_display_name(), "object.teleporter_does_not_exist.name")

func test_get_display_description_unknown_key_falls_back_to_key() -> void:
	var data := TeleporterData.new()
	data.description_key = "object.teleporter_does_not_exist.description"
	assert_eq(data.get_display_description(), "object.teleporter_does_not_exist.description")

func test_is_animated_false_when_frames_null() -> void:
	var data := TeleporterData.new()
	assert_false(data.is_animated())

func test_is_animated_true_when_frames_set() -> void:
	var data := TeleporterData.new()
	data.frames = SpriteFrames.new()
	assert_true(data.is_animated())

func test_is_animated_prefers_frames_even_when_decal_also_set() -> void:
	# Renderer precedence: frames > decal_sprite. Lock the rule so a
	# future refactor that flips it gets caught by tests.
	var data := TeleporterData.new()
	data.decal_sprite = PlaceholderTexture2D.new()
	data.frames = SpriteFrames.new()
	assert_true(data.is_animated())
