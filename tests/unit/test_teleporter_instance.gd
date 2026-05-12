extends GutTest

func _make_data() -> TeleporterData:
	return TeleporterData.new()

func test_create_sets_cells_and_data() -> void:
	var data := _make_data()
	var inst := TeleporterInstance.create(data, Vector2i(2, 3), Vector2i(9, 4), 0)
	assert_eq(inst.data, data)
	assert_eq(inst.cell_a, Vector2i(2, 3))
	assert_eq(inst.cell_b, Vector2i(9, 4))

func test_create_clamps_pair_index_to_non_negative() -> void:
	var inst := TeleporterInstance.create(_make_data(), Vector2i.ZERO, Vector2i(1, 0), -3)
	assert_eq(inst.pair_index, 0)

func test_create_preserves_positive_pair_index() -> void:
	var inst := TeleporterInstance.create(_make_data(), Vector2i.ZERO, Vector2i(1, 0), 5)
	assert_eq(inst.pair_index, 5)

func test_partner_of_returns_other_endpoint_from_a() -> void:
	var inst := TeleporterInstance.create(_make_data(), Vector2i(2, 3), Vector2i(9, 4), 0)
	assert_eq(inst.partner_of(Vector2i(2, 3)), Vector2i(9, 4))

func test_partner_of_returns_other_endpoint_from_b() -> void:
	var inst := TeleporterInstance.create(_make_data(), Vector2i(2, 3), Vector2i(9, 4), 0)
	assert_eq(inst.partner_of(Vector2i(9, 4)), Vector2i(2, 3))

func test_partner_of_returns_minus_one_for_non_endpoint() -> void:
	# Fail-safe: a bug that calls partner_of with the wrong cell must
	# NOT silently warp the player to cell_a — it should be detectable.
	var inst := TeleporterInstance.create(_make_data(), Vector2i(2, 3), Vector2i(9, 4), 0)
	assert_eq(inst.partner_of(Vector2i(0, 0)), Vector2i(-1, -1))
	assert_eq(inst.partner_of(Vector2i(5, 5)), Vector2i(-1, -1))

func test_endpoints_returns_both_cells_in_stable_order() -> void:
	var inst := TeleporterInstance.create(_make_data(), Vector2i(2, 3), Vector2i(9, 4), 0)
	var pts: Array = inst.endpoints()
	assert_eq(pts.size(), 2)
	assert_eq(pts[0], Vector2i(2, 3))
	assert_eq(pts[1], Vector2i(9, 4))

func test_has_endpoint_true_for_both_cells() -> void:
	var inst := TeleporterInstance.create(_make_data(), Vector2i(2, 3), Vector2i(9, 4), 0)
	assert_true(inst.has_endpoint(Vector2i(2, 3)))
	assert_true(inst.has_endpoint(Vector2i(9, 4)))

func test_has_endpoint_false_for_other_cells() -> void:
	var inst := TeleporterInstance.create(_make_data(), Vector2i(2, 3), Vector2i(9, 4), 0)
	assert_false(inst.has_endpoint(Vector2i(0, 0)))
	assert_false(inst.has_endpoint(Vector2i(5, 5)))

func test_self_loop_partner_resolves_to_same_cell() -> void:
	# Edge case: if a buggy placer ever creates a pair with cell_a ==
	# cell_b, partner_of should at least return the input cell rather
	# than (-1, -1). Documents the behaviour; the placer must still
	# reject this configuration.
	var inst := TeleporterInstance.create(_make_data(), Vector2i(4, 4), Vector2i(4, 4), 0)
	assert_eq(inst.partner_of(Vector2i(4, 4)), Vector2i(4, 4))
