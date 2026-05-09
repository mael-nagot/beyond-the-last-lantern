extends GutTest

# Phase 8 Task 3 — Subtask C1.

func test_default_field_values() -> void:
	var data := ProjectileTrapData.new()
	assert_eq(data.name_key, "")
	assert_eq(data.description_key, "")
	assert_eq(data.trigger, ProjectileTrapData.Trigger.TIMED)
	assert_eq(data.damage, 8)
	assert_eq(data.speed_cells_per_second, 8.0)
	assert_eq(data.timed_period, 2.5)
	assert_eq(data.timed_initial_offset, 0.0)
	assert_eq(data.max_escape_distance, 5)
	assert_eq(data.min_distance_to_other_projectile_trap, 6)
	assert_eq(data.min_plate_to_launcher_distance, 2)
	assert_eq(data.max_plate_to_junction_distance, 4)
	assert_eq(data.status_effect_id, "")
	assert_eq(data.status_effect_duration, 0.0)
	assert_eq(data.status_effect_magnitude, 0.0)
	assert_null(data.launcher_texture)
	assert_eq(data.launcher_world_height, 1.0)
	assert_eq(data.launcher_horizontal_offset, 0.0)
	assert_eq(data.launcher_y_offset, 0.0)
	assert_eq(data.launcher_depth_offset, 0.02)
	assert_null(data.projectile_sprite_front)
	assert_null(data.projectile_sprite_back)
	assert_null(data.projectile_sprite_left)
	assert_null(data.projectile_sprite_right)
	assert_eq(data.projectile_world_height, 0.5)
	assert_eq(data.projectile_y_offset, 0.0)
	assert_null(data.plate_texture)
	assert_eq(data.plate_world_size, 0.7)
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

func test_projectile_sprite_for_front_returns_front() -> void:
	var data := ProjectileTrapData.new()
	var front := PlaceholderTexture2D.new()
	data.projectile_sprite_front = front
	assert_same(front, data.projectile_sprite_for(ProjectileTrapData.ProjectileView.FRONT))

func test_projectile_sprite_for_back_returns_back_when_set() -> void:
	var data := ProjectileTrapData.new()
	var front := PlaceholderTexture2D.new()
	var back := PlaceholderTexture2D.new()
	data.projectile_sprite_front = front
	data.projectile_sprite_back = back
	assert_same(back, data.projectile_sprite_for(ProjectileTrapData.ProjectileView.BACK))

func test_projectile_sprite_for_back_falls_back_to_front_when_null() -> void:
	# Spherical projectiles (fireballs) only define front. The picker
	# must return front for any null override so the renderer doesn't
	# need per-variant code.
	var data := ProjectileTrapData.new()
	var front := PlaceholderTexture2D.new()
	data.projectile_sprite_front = front
	assert_same(front, data.projectile_sprite_for(ProjectileTrapData.ProjectileView.BACK))
	assert_same(front, data.projectile_sprite_for(ProjectileTrapData.ProjectileView.LEFT))
	assert_same(front, data.projectile_sprite_for(ProjectileTrapData.ProjectileView.RIGHT))

func test_projectile_sprite_for_left_independent_from_right() -> void:
	# Arrows look different from each side (tip vs fletching, profile
	# orientation). Left/right slots must resolve independently.
	var data := ProjectileTrapData.new()
	var front := PlaceholderTexture2D.new()
	var left := PlaceholderTexture2D.new()
	var right := PlaceholderTexture2D.new()
	data.projectile_sprite_front = front
	data.projectile_sprite_left = left
	data.projectile_sprite_right = right
	assert_same(left, data.projectile_sprite_for(ProjectileTrapData.ProjectileView.LEFT))
	assert_same(right, data.projectile_sprite_for(ProjectileTrapData.ProjectileView.RIGHT))
	assert_ne(data.projectile_sprite_for(ProjectileTrapData.ProjectileView.LEFT),
		data.projectile_sprite_for(ProjectileTrapData.ProjectileView.RIGHT))

func test_unknown_key_falls_back_to_key() -> void:
	var data := ProjectileTrapData.new()
	data.name_key = "projectile_trap.does_not_exist.name"
	assert_eq(data.get_display_name(), "projectile_trap.does_not_exist.name")
