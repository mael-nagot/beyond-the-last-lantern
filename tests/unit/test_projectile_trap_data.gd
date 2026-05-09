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
	assert_null(data.projectile_back_sprite)
	assert_null(data.projectile_left_sprite)
	assert_null(data.projectile_right_sprite)
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

func test_sprite_for_view_fallback_when_no_overrides() -> void:
	var data := ProjectileTrapData.new()
	var front := PlaceholderTexture2D.new()
	data.projectile_sprite = front
	assert_eq(data.get_projectile_sprite_for_view(Vector2i(1, 0), Vector2i(-1, 0)), front)
	assert_eq(data.get_projectile_sprite_for_view(Vector2i(1, 0), Vector2i(1, 0)), front)
	assert_eq(data.get_projectile_sprite_for_view(Vector2i(1, 0), Vector2i(0, -1)), front)
	assert_eq(data.get_projectile_sprite_for_view(Vector2i(1, 0), Vector2i(0, 1)), front)

func test_sprite_for_view_front_when_camera_opposes_fire() -> void:
	var data := ProjectileTrapData.new()
	var front := PlaceholderTexture2D.new()
	var back := PlaceholderTexture2D.new()
	data.projectile_sprite = front
	data.projectile_back_sprite = back
	# Fires east, camera faces west → projectile coming toward camera = front
	assert_eq(data.get_projectile_sprite_for_view(Vector2i(1, 0), Vector2i(-1, 0)), front)
	# Fires north, camera faces south → front
	assert_eq(data.get_projectile_sprite_for_view(Vector2i(0, -1), Vector2i(0, 1)), front)

func test_sprite_for_view_back_when_camera_matches_fire() -> void:
	var data := ProjectileTrapData.new()
	var front := PlaceholderTexture2D.new()
	var back := PlaceholderTexture2D.new()
	data.projectile_sprite = front
	data.projectile_back_sprite = back
	# Fires east, camera faces east → projectile going away = back
	assert_eq(data.get_projectile_sprite_for_view(Vector2i(1, 0), Vector2i(1, 0)), back)
	# Fires south, camera faces south → back
	assert_eq(data.get_projectile_sprite_for_view(Vector2i(0, 1), Vector2i(0, 1)), back)

func test_sprite_for_view_back_fallback_to_front() -> void:
	var data := ProjectileTrapData.new()
	var front := PlaceholderTexture2D.new()
	data.projectile_sprite = front
	# No back sprite → falls back to front
	assert_eq(data.get_projectile_sprite_for_view(Vector2i(1, 0), Vector2i(1, 0)), front)

func test_sprite_for_view_left_and_right() -> void:
	var data := ProjectileTrapData.new()
	var front := PlaceholderTexture2D.new()
	var left := PlaceholderTexture2D.new()
	var right := PlaceholderTexture2D.new()
	data.projectile_sprite = front
	data.projectile_left_sprite = left
	data.projectile_right_sprite = right
	# Fires east (1,0). Left of projectile = north.
	# Camera faces south (0,1) → sees the left side
	assert_eq(data.get_projectile_sprite_for_view(Vector2i(1, 0), Vector2i(0, 1)), left)
	# Camera faces north (0,-1) → sees the right side
	assert_eq(data.get_projectile_sprite_for_view(Vector2i(1, 0), Vector2i(0, -1)), right)
	# Fires south (0,1). Left of projectile = east.
	# Camera faces west (-1,0) → sees the left side
	assert_eq(data.get_projectile_sprite_for_view(Vector2i(0, 1), Vector2i(-1, 0)), left)
	# Camera faces east (1,0) → sees the right side
	assert_eq(data.get_projectile_sprite_for_view(Vector2i(0, 1), Vector2i(1, 0)), right)

func test_sprite_for_view_side_fallback_to_front() -> void:
	var data := ProjectileTrapData.new()
	var front := PlaceholderTexture2D.new()
	data.projectile_sprite = front
	# No left/right sprites → falls back to front
	assert_eq(data.get_projectile_sprite_for_view(Vector2i(1, 0), Vector2i(0, 1)), front)
	assert_eq(data.get_projectile_sprite_for_view(Vector2i(1, 0), Vector2i(0, -1)), front)

func test_status_effect_enum_values_exist() -> void:
	assert_eq(ProjectileTrapData.StatusEffect.NONE, 0)
	assert_eq(ProjectileTrapData.StatusEffect.POISON, 1)
	assert_eq(ProjectileTrapData.StatusEffect.BURN, 2)
	assert_eq(ProjectileTrapData.StatusEffect.SLOW, 3)
