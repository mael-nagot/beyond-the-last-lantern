extends GutTest

func _make_data() -> WallDecorationData:
	return WallDecorationData.new()

func test_create_stores_data_cell_and_dir() -> void:
	var data := _make_data()
	var inst := WallDecorationInstance.create(data, Vector2i(5, 7), WallDecorationInstance.DIR_NORTH)
	assert_eq(inst.data, data)
	assert_eq(inst.cell, Vector2i(5, 7))
	assert_eq(inst.wall_dir, Vector2i(0, -1))

func test_face_key_is_unique_per_face() -> void:
	var ka := WallDecorationInstance.face_key(Vector2i(3, 4), Vector2i(0, -1))
	var kb := WallDecorationInstance.face_key(Vector2i(3, 4), Vector2i(0, 1))
	var kc := WallDecorationInstance.face_key(Vector2i(3, 5), Vector2i(0, -1))
	assert_ne(ka, kb, "different wall sides on same cell must collide-resist")
	assert_ne(ka, kc, "different cells with same wall side must collide-resist")

func test_get_face_key_matches_static_helper() -> void:
	var inst := WallDecorationInstance.create(_make_data(), Vector2i(2, 8), WallDecorationInstance.DIR_EAST)
	assert_eq(inst.get_face_key(), WallDecorationInstance.face_key(Vector2i(2, 8), Vector2i(1, 0)))

func test_direction_constants() -> void:
	assert_eq(WallDecorationInstance.DIR_NORTH, Vector2i(0, -1))
	assert_eq(WallDecorationInstance.DIR_SOUTH, Vector2i(0, 1))
	assert_eq(WallDecorationInstance.DIR_WEST, Vector2i(-1, 0))
	assert_eq(WallDecorationInstance.DIR_EAST, Vector2i(1, 0))
