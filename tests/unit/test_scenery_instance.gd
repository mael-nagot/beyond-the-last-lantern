extends GutTest

func test_create_sets_fields() -> void:
	var data := SceneryData.new()
	var inst := SceneryInstance.create(data, Vector2i(3, 7))
	assert_same(inst.data, data)
	assert_eq(inst.cell, Vector2i(3, 7))
	assert_eq(inst.cell_offset, Vector2.ZERO,
		"default cell_offset should be zero so single-sprite placements stay centred")
	assert_almost_eq(inst.scale, 1.0, 0.0001,
		"default scale should be 1.0 so single-sprite placements render at data world_height")

func test_create_with_offset_and_scale() -> void:
	var data := SceneryData.new()
	var inst := SceneryInstance.create(data, Vector2i(4, 4), Vector2(0.25, -0.3), 1.2)
	assert_eq(inst.cell_offset, Vector2(0.25, -0.3))
	assert_almost_eq(inst.scale, 1.2, 0.0001)

func test_blocks_movement_false_for_walkable() -> void:
	var data := SceneryData.new()
	data.walkable = true
	var inst := SceneryInstance.create(data, Vector2i(0, 0))
	assert_false(inst.blocks_movement())

func test_blocks_movement_true_for_non_walkable() -> void:
	var data := SceneryData.new()
	data.walkable = false
	var inst := SceneryInstance.create(data, Vector2i(0, 0))
	assert_true(inst.blocks_movement())

func test_blocks_movement_safe_when_data_null() -> void:
	# Defensive — the placer never produces an instance with null data,
	# but if anything ever does (e.g. a half-loaded resource), the
	# is_blocked path on GridCell must not crash.
	var inst := SceneryInstance.new()
	assert_false(inst.blocks_movement())
