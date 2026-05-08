extends GutTest

func test_default_field_values() -> void:
	var c := AudioConfig.new()
	assert_null(c.map_open_sound)
	assert_null(c.map_close_sound)
	assert_null(c.negative_sound)
	assert_null(c.wall_bump_sound)
	assert_eq(c.turn_sounds.size(), 0)
	assert_null(c.pain_sound)
