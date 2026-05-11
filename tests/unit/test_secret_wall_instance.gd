extends GutTest

# -------------------------------------------------------
# canonical_pair / edge_key — same edge always resolves to the same
# key regardless of input order, so a secret wall can never be indexed
# twice in the generator's lookup table.
# -------------------------------------------------------

func test_canonical_pair_orders_by_x_then_y() -> void:
	var a := Vector2i(3, 5)
	var b := Vector2i(4, 5)
	var pair: Array = SecretWallInstance.canonical_pair(a, b)
	assert_eq(pair[0], a)
	assert_eq(pair[1], b)

func test_canonical_pair_swaps_when_first_arg_larger() -> void:
	var pair: Array = SecretWallInstance.canonical_pair(Vector2i(4, 5), Vector2i(3, 5))
	assert_eq(pair[0], Vector2i(3, 5))
	assert_eq(pair[1], Vector2i(4, 5))

func test_canonical_pair_breaks_x_tie_with_y() -> void:
	var pair: Array = SecretWallInstance.canonical_pair(Vector2i(3, 6), Vector2i(3, 5))
	assert_eq(pair[0], Vector2i(3, 5))
	assert_eq(pair[1], Vector2i(3, 6))

func test_edge_key_is_order_independent() -> void:
	var a := Vector2i(7, 2)
	var b := Vector2i(7, 3)
	assert_eq(SecretWallInstance.edge_key(a, b), SecretWallInstance.edge_key(b, a))

func test_edge_key_distinguishes_different_edges() -> void:
	var k1 := SecretWallInstance.edge_key(Vector2i(3, 5), Vector2i(4, 5))
	var k2 := SecretWallInstance.edge_key(Vector2i(3, 5), Vector2i(3, 6))
	assert_ne(k1, k2)

# A secret wall edge and a door edge use the same edge_key shape, so
# the generator can cross-check the two registries by string equality.
func test_edge_key_matches_door_instance_edge_key() -> void:
	var a := Vector2i(2, 4)
	var b := Vector2i(3, 4)
	assert_eq(SecretWallInstance.edge_key(a, b), DoorInstance.edge_key(a, b))

# -------------------------------------------------------
# create — stores canonical cells and gives back an instance.
# -------------------------------------------------------

func test_create_stores_canonical_cells() -> void:
	var inst := SecretWallInstance.create(Vector2i(4, 5), Vector2i(3, 5))
	assert_eq(inst.cell_a, Vector2i(3, 5))
	assert_eq(inst.cell_b, Vector2i(4, 5))

# -------------------------------------------------------
# axis() — derived from cells (no stored field).
# -------------------------------------------------------

func test_axis_horizontal_for_east_west_corridor() -> void:
	var inst := SecretWallInstance.create(Vector2i(3, 5), Vector2i(4, 5))
	assert_eq(inst.axis(), Vector2i(1, 0))

func test_axis_vertical_for_north_south_corridor() -> void:
	var inst := SecretWallInstance.create(Vector2i(3, 5), Vector2i(3, 6))
	assert_eq(inst.axis(), Vector2i(0, 1))
