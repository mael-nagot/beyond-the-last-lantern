extends GutTest

func _make_data(min_spins: int = 1, max_spins: int = 3, policy: int = SpinnerData.Direction.RANDOM) -> SpinnerData:
	var data := SpinnerData.new()
	data.min_spins = min_spins
	data.max_spins = max_spins
	data.direction = policy
	return data

func test_create_sets_cell_and_data() -> void:
	var data := _make_data()
	var inst := SpinnerInstance.create(data, Vector2i(4, 7), SpinnerInstance.Direction.CLOCKWISE, 2)
	assert_eq(inst.cell, Vector2i(4, 7))
	assert_eq(inst.data, data)

func test_create_stores_resolved_direction() -> void:
	var inst_cw := SpinnerInstance.create(_make_data(), Vector2i.ZERO, SpinnerInstance.Direction.CLOCKWISE, 1)
	assert_eq(inst_cw.direction, SpinnerInstance.Direction.CLOCKWISE)
	assert_true(inst_cw.is_clockwise())
	var inst_ccw := SpinnerInstance.create(_make_data(), Vector2i.ZERO, SpinnerInstance.Direction.COUNTER_CLOCKWISE, 1)
	assert_eq(inst_ccw.direction, SpinnerInstance.Direction.COUNTER_CLOCKWISE)
	assert_false(inst_ccw.is_clockwise())

func test_create_clamps_rotations_to_minimum_of_1() -> void:
	# A misconfigured 0-spin spinner should still produce a runnable
	# instance (1 spin) rather than silently no-op the player.
	var inst := SpinnerInstance.create(_make_data(), Vector2i.ZERO, SpinnerInstance.Direction.CLOCKWISE, 0)
	assert_eq(inst.rotations, 1)
	var inst_neg := SpinnerInstance.create(_make_data(), Vector2i.ZERO, SpinnerInstance.Direction.CLOCKWISE, -3)
	assert_eq(inst_neg.rotations, 1)

func test_create_preserves_positive_rotations() -> void:
	var inst := SpinnerInstance.create(_make_data(), Vector2i.ZERO, SpinnerInstance.Direction.CLOCKWISE, 5)
	assert_eq(inst.rotations, 5)

func test_create_collapses_invalid_direction_to_clockwise() -> void:
	# Defensive: if the placer ever passes a Direction.RANDOM value
	# (a SpinnerData policy, not a runtime direction), the instance
	# falls through to CLOCKWISE rather than carrying an invalid
	# state.
	var inst := SpinnerInstance.create(_make_data(), Vector2i.ZERO, 99, 1)
	assert_eq(inst.direction, SpinnerInstance.Direction.CLOCKWISE)

func test_direction_enum_has_two_concrete_values() -> void:
	# SpinnerInstance.Direction is the runtime enum — RANDOM should NOT
	# appear here. Guard against an accidental enum copy from SpinnerData.
	assert_eq(SpinnerInstance.Direction.CLOCKWISE, 0)
	assert_eq(SpinnerInstance.Direction.COUNTER_CLOCKWISE, 1)
