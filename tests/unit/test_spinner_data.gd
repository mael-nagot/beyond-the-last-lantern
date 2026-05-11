extends GutTest

func test_default_field_values() -> void:
	var data := SpinnerData.new()
	assert_eq(data.name_key, "")
	assert_eq(data.description_key, "")
	assert_eq(data.min_spins, 1)
	assert_eq(data.max_spins, 3)
	assert_eq(data.direction, SpinnerData.Direction.RANDOM)
	assert_eq(data.spin_step_duration, 0.13)
	assert_null(data.decal_sprite)
	assert_eq(data.decal_world_size, 1.0)
	assert_eq(data.y_offset, 0.01)
	assert_eq(data.visual_rotation_degrees_per_second, 45.0)
	assert_null(data.spin_sound)

func test_get_display_name_unknown_key_falls_back_to_key() -> void:
	var data := SpinnerData.new()
	data.name_key = "spinner.does_not_exist.name"
	assert_eq(data.get_display_name(), "spinner.does_not_exist.name")

func test_get_display_description_unknown_key_falls_back_to_key() -> void:
	var data := SpinnerData.new()
	data.description_key = "spinner.does_not_exist.description"
	assert_eq(data.get_display_description(), "spinner.does_not_exist.description")

func test_direction_enum_has_three_policies() -> void:
	# The placer collapses RANDOM into concrete CW/CCW per instance —
	# guard against an enum refactor that drops one of the three.
	assert_eq(SpinnerData.Direction.CLOCKWISE, 0)
	assert_eq(SpinnerData.Direction.COUNTER_CLOCKWISE, 1)
	assert_eq(SpinnerData.Direction.RANDOM, 2)
