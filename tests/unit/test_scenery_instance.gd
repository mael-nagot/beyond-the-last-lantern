extends GutTest

func test_create_sets_fields() -> void:
	var data := SceneryData.new()
	var inst := SceneryInstance.create(data, Vector2i(3, 7))
	assert_same(inst.data, data)
	assert_eq(inst.cell, Vector2i(3, 7))

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
