extends GutTest

func test_default_field_values() -> void:
	var data := ProjectileTrapData.new()
	assert_eq(data.name_key, "")
	assert_eq(data.description_key, "")
	assert_eq(data.trigger, ProjectileTrapData.Trigger.TIMED)
	assert_eq(data.damage, 5)
	assert_eq(data.status_effect, ProjectileTrapData.StatusEffect.NONE)
	assert_eq(data.status_duration, 0.0)
	assert_eq(data.status_damage_per_tick, 0.0)
	assert_null(data.projectile_sprite)
	assert_eq(data.projectile_speed, 5.0)
	assert_eq(data.projectile_world_height, 0.8)
	assert_eq(data.projectile_y_offset, 0.0)
	assert_null(data.launcher_sprite)
	assert_eq(data.launcher_world_height, 1.5)
	assert_eq(data.launcher_x_offset, 0.0)
	assert_eq(data.launcher_y_offset, 0.0)
	assert_eq(data.launcher_depth_offset, 0.02)
	assert_null(data.plate_sprite)
	assert_eq(data.plate_world_size, 0.8)
	assert_eq(data.timed_interval, 3.0)
	assert_eq(data.timed_initial_offset, 0.0)
	assert_eq(data.cooldown_after_impact, 0.0)
	assert_null(data.launch_sound)
	assert_null(data.impact_sound)
	assert_null(data.plate_sound)
	assert_eq(data.hearing_distance, 12.0)

func test_is_timed_true_for_timed_trigger() -> void:
	var data := ProjectileTrapData.new()
	data.trigger = ProjectileTrapData.Trigger.TIMED
	assert_true(data.is_timed())
	assert_false(data.is_pressure_plate())

func test_is_pressure_plate_true_for_pressure_plate_trigger() -> void:
	var data := ProjectileTrapData.new()
	data.trigger = ProjectileTrapData.Trigger.PRESSURE_PLATE
	assert_true(data.is_pressure_plate())
	assert_false(data.is_timed())

func test_get_display_name_resolves_known_key() -> void:
	var data := ProjectileTrapData.new()
	data.name_key = "projectile_trap.dart_timed.name"
	assert_eq(data.get_display_name(), tr("projectile_trap.dart_timed.name"))

func test_get_display_description_resolves_known_key() -> void:
	var data := ProjectileTrapData.new()
	data.description_key = "projectile_trap.dart_timed.description"
	assert_eq(data.get_display_description(), tr("projectile_trap.dart_timed.description"))

func test_unknown_key_falls_back_to_key_string() -> void:
	var data := ProjectileTrapData.new()
	data.name_key = "projectile_trap.does_not_exist.name"
	assert_eq(data.get_display_name(), "projectile_trap.does_not_exist.name")

func test_status_effect_enum_values_exist() -> void:
	assert_eq(ProjectileTrapData.StatusEffect.NONE, 0)
	assert_eq(ProjectileTrapData.StatusEffect.POISON, 1)
	assert_eq(ProjectileTrapData.StatusEffect.BURN, 2)
	assert_eq(ProjectileTrapData.StatusEffect.SLOW, 3)
