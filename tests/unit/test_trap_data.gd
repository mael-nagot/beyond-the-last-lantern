extends GutTest

func test_default_field_values() -> void:
	var data := TrapData.new()
	assert_eq(data.name_key, "")
	assert_eq(data.description_key, "")
	assert_eq(data.trigger, TrapData.Trigger.STEP)
	assert_eq(data.damage, 5)
	assert_eq(data.step_activation_duration, 0.5)
	assert_eq(data.step_cooldown_duration, 1.5)
	assert_eq(data.timed_up_duration, 1.0)
	assert_eq(data.timed_down_duration, 2.0)
	assert_eq(data.timed_initial_offset, 0.0)
	assert_null(data.holes_sprite)
	assert_null(data.extended_sprite)
	assert_null(data.extended_sprite_frame1)
	assert_null(data.extended_sprite_frame2)
	assert_eq(data.extension_frame_duration, 0.03)
	assert_eq(data.world_height, 1.2)
	assert_eq(data.spike_world_width, 0.0)
	assert_eq(data.hole_world_size, 1.0)
	assert_eq(data.y_offset, 0.0)
	assert_eq(data.spike_lean_toward_player, 0.0)
	assert_eq(data.grid_cols, 2)
	assert_eq(data.grid_rows, 2)
	assert_eq(data.grid_inset, 0.3)
	assert_null(data.activate_sound)
	assert_null(data.deactivate_sound)
	assert_eq(data.hearing_distance, 8.0)

func test_is_step_true_for_step_trigger() -> void:
	var data := TrapData.new()
	data.trigger = TrapData.Trigger.STEP
	assert_true(data.is_step())
	assert_false(data.is_timed())

func test_is_timed_true_for_timed_trigger() -> void:
	var data := TrapData.new()
	data.trigger = TrapData.Trigger.TIMED
	assert_true(data.is_timed())
	assert_false(data.is_step())

func test_get_display_name_resolves_known_key() -> void:
	var data := TrapData.new()
	data.name_key = "trap.spike_step.name"
	assert_eq(data.get_display_name(), "Spike Trap")

func test_get_display_description_resolves_known_key() -> void:
	var data := TrapData.new()
	data.description_key = "trap.spike_step.description"
	assert_eq(data.get_display_description(), "Hidden floor spikes that snap up when stepped on.")

func test_unknown_key_falls_back_to_key() -> void:
	var data := TrapData.new()
	data.name_key = "trap.does_not_exist.name"
	assert_eq(data.get_display_name(), "trap.does_not_exist.name")
