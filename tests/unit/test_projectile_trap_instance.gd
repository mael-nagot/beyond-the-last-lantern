extends GutTest

# Phase 8 Task 3 — Subtask C1.

func _make_data() -> ProjectileTrapData:
	return ProjectileTrapData.new()

func test_create_stores_data_cell_and_wall_dir() -> void:
	var data := _make_data()
	var inst := ProjectileTrapInstance.create(data, Vector2i(5, 7), ProjectileTrapInstance.DIR_NORTH)
	assert_eq(inst.data, data)
	assert_eq(inst.cell, Vector2i(5, 7))
	assert_eq(inst.wall_dir, Vector2i(0, -1))

func test_fire_direction_is_opposite_of_wall_dir() -> void:
	# Launcher mounted on the north wall fires south; mounted on the
	# east wall fires west. The renderer + flight code rely on this.
	var n := ProjectileTrapInstance.create(_make_data(), Vector2i(0, 0), ProjectileTrapInstance.DIR_NORTH)
	assert_eq(n.fire_direction(), Vector2i(0, 1), "north wall → fire south")
	var s := ProjectileTrapInstance.create(_make_data(), Vector2i(0, 0), ProjectileTrapInstance.DIR_SOUTH)
	assert_eq(s.fire_direction(), Vector2i(0, -1), "south wall → fire north")
	var e := ProjectileTrapInstance.create(_make_data(), Vector2i(0, 0), ProjectileTrapInstance.DIR_EAST)
	assert_eq(e.fire_direction(), Vector2i(-1, 0), "east wall → fire west")
	var w := ProjectileTrapInstance.create(_make_data(), Vector2i(0, 0), ProjectileTrapInstance.DIR_WEST)
	assert_eq(w.fire_direction(), Vector2i(1, 0), "west wall → fire east")

func test_face_key_is_unique_per_face() -> void:
	# Same format as WallDecorationInstance.face_key — both share the
	# generator's `_wall_faces_used` registry, so identical inputs MUST
	# produce identical keys.
	var ka := ProjectileTrapInstance.face_key(Vector2i(3, 4), Vector2i(0, -1))
	var kb := ProjectileTrapInstance.face_key(Vector2i(3, 4), Vector2i(0, 1))
	var kc := ProjectileTrapInstance.face_key(Vector2i(3, 5), Vector2i(0, -1))
	assert_ne(ka, kb, "different wall sides on same cell must collide-resist")
	assert_ne(ka, kc, "different cells with same wall side must collide-resist")

func test_face_key_format_matches_wall_decoration() -> void:
	# Wall decorations and projectile launchers MUST use the exact same
	# face-key string format — they share `_wall_faces_used` on
	# `LevelGenerator`. Drift between the two breaks exclusivity.
	var ptrap_key := ProjectileTrapInstance.face_key(Vector2i(2, 8), Vector2i(1, 0))
	var deco_key := WallDecorationInstance.face_key(Vector2i(2, 8), Vector2i(1, 0))
	assert_eq(ptrap_key, deco_key)

func test_get_face_key_matches_static_helper() -> void:
	var inst := ProjectileTrapInstance.create(_make_data(), Vector2i(2, 8), ProjectileTrapInstance.DIR_EAST)
	assert_eq(inst.get_face_key(), ProjectileTrapInstance.face_key(Vector2i(2, 8), Vector2i(1, 0)))

func test_no_plate_by_default() -> void:
	# Subtask C1 places launchers without plates; C4 will populate
	# `plate_cell` for PRESSURE_PLATE traps. The default sentinel must
	# read as "no plate".
	var inst := ProjectileTrapInstance.create(_make_data(), Vector2i(0, 0), ProjectileTrapInstance.DIR_NORTH)
	assert_eq(inst.plate_cell, ProjectileTrapInstance.NO_PLATE)
	assert_false(inst.has_plate())

func test_has_plate_true_when_plate_cell_set() -> void:
	var inst := ProjectileTrapInstance.create(_make_data(), Vector2i(0, 0), ProjectileTrapInstance.DIR_NORTH)
	inst.plate_cell = Vector2i(3, 5)
	assert_true(inst.has_plate())

func test_direction_constants() -> void:
	assert_eq(ProjectileTrapInstance.DIR_NORTH, Vector2i(0, -1))
	assert_eq(ProjectileTrapInstance.DIR_SOUTH, Vector2i(0, 1))
	assert_eq(ProjectileTrapInstance.DIR_WEST, Vector2i(-1, 0))
	assert_eq(ProjectileTrapInstance.DIR_EAST, Vector2i(1, 0))
