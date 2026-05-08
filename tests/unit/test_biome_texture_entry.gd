extends GutTest

func test_defaults() -> void:
	var entry := BiomeTextureEntry.new()
	assert_null(entry.albedo)
	assert_null(entry.normal)
	assert_eq(entry.placement, BiomeTextureEntry.PLACEMENT_ANY)

func test_placement_any_equals_all_three_flags() -> void:
	var expected := BiomeTextureEntry.PLACEMENT_CORRIDOR \
		| BiomeTextureEntry.PLACEMENT_ROOM \
		| BiomeTextureEntry.PLACEMENT_DEAD_END
	assert_eq(BiomeTextureEntry.PLACEMENT_ANY, expected)

func test_allows_corridor_only() -> void:
	var entry := BiomeTextureEntry.new()
	entry.placement = BiomeTextureEntry.PLACEMENT_CORRIDOR
	assert_true(entry.allows(BiomeTextureEntry.PLACEMENT_CORRIDOR))
	assert_false(entry.allows(BiomeTextureEntry.PLACEMENT_ROOM))
	assert_false(entry.allows(BiomeTextureEntry.PLACEMENT_DEAD_END))

func test_allows_combined_room_and_dead_end() -> void:
	var entry := BiomeTextureEntry.new()
	entry.placement = BiomeTextureEntry.PLACEMENT_ROOM | BiomeTextureEntry.PLACEMENT_DEAD_END
	assert_false(entry.allows(BiomeTextureEntry.PLACEMENT_CORRIDOR))
	assert_true(entry.allows(BiomeTextureEntry.PLACEMENT_ROOM))
	assert_true(entry.allows(BiomeTextureEntry.PLACEMENT_DEAD_END))

func test_allows_any_returns_true_for_every_placement() -> void:
	var entry := BiomeTextureEntry.new()
	entry.placement = BiomeTextureEntry.PLACEMENT_ANY
	assert_true(entry.allows(BiomeTextureEntry.PLACEMENT_CORRIDOR))
	assert_true(entry.allows(BiomeTextureEntry.PLACEMENT_ROOM))
	assert_true(entry.allows(BiomeTextureEntry.PLACEMENT_DEAD_END))

func test_pick_for_returns_null_on_empty_array() -> void:
	var picked := BiomeTextureEntry.pick_for([], BiomeTextureEntry.PLACEMENT_ROOM, Vector2i(3, 4))
	assert_null(picked)

func test_pick_for_returns_null_when_array_only_has_nulls() -> void:
	var picked := BiomeTextureEntry.pick_for([null, null], BiomeTextureEntry.PLACEMENT_ROOM, Vector2i(3, 4))
	assert_null(picked)

func test_pick_for_only_returns_classification_match_when_one_exists() -> void:
	var corridor := _make_entry(BiomeTextureEntry.PLACEMENT_CORRIDOR)
	var room := _make_entry(BiomeTextureEntry.PLACEMENT_ROOM)
	var dead_end := _make_entry(BiomeTextureEntry.PLACEMENT_DEAD_END)
	var entries: Array = [corridor, room, dead_end]
	# Try multiple cells — every pick must land on the room entry, never
	# corridor / dead-end.
	for x in range(0, 5):
		for y in range(0, 5):
			var picked := BiomeTextureEntry.pick_for(
				entries, BiomeTextureEntry.PLACEMENT_ROOM, Vector2i(x, y))
			assert_eq(picked, room)

func test_pick_for_falls_back_to_full_array_when_no_match() -> void:
	# Only corridor entries; ask for a room cell. Must still get *something*.
	var corridor_a := _make_entry(BiomeTextureEntry.PLACEMENT_CORRIDOR)
	var corridor_b := _make_entry(BiomeTextureEntry.PLACEMENT_CORRIDOR)
	var entries: Array = [corridor_a, corridor_b]
	var picked := BiomeTextureEntry.pick_for(entries, BiomeTextureEntry.PLACEMENT_ROOM, Vector2i(2, 3))
	assert_true(picked == corridor_a or picked == corridor_b)

func test_pick_for_is_deterministic_per_cell_position() -> void:
	var entries: Array = [
		_make_entry(BiomeTextureEntry.PLACEMENT_ANY),
		_make_entry(BiomeTextureEntry.PLACEMENT_ANY),
		_make_entry(BiomeTextureEntry.PLACEMENT_ANY),
	]
	# Same (entries, classification, cell) → same pick on every call.
	var first := BiomeTextureEntry.pick_for(entries, BiomeTextureEntry.PLACEMENT_ROOM, Vector2i(7, 11))
	for _i in range(20):
		var again := BiomeTextureEntry.pick_for(entries, BiomeTextureEntry.PLACEMENT_ROOM, Vector2i(7, 11))
		assert_eq(again, first)

func test_pick_for_distributes_across_matching_entries() -> void:
	# With 3 matching entries and a sweep of cells, we should hit at
	# least 2 distinct entries (the hash isn't pathological). Also
	# guards against accidentally returning index 0 always.
	var entries: Array = [
		_make_entry(BiomeTextureEntry.PLACEMENT_ANY),
		_make_entry(BiomeTextureEntry.PLACEMENT_ANY),
		_make_entry(BiomeTextureEntry.PLACEMENT_ANY),
	]
	var hits: Dictionary = {}
	for x in range(0, 10):
		for y in range(0, 10):
			var picked := BiomeTextureEntry.pick_for(
				entries, BiomeTextureEntry.PLACEMENT_CORRIDOR, Vector2i(x, y))
			hits[picked] = true
	assert_gte(hits.size(), 2, "pick_for should reach more than one matching entry across a 10x10 sweep")

func test_pick_for_skips_null_entries() -> void:
	var room := _make_entry(BiomeTextureEntry.PLACEMENT_ROOM)
	var entries: Array = [null, room, null]
	var picked := BiomeTextureEntry.pick_for(entries, BiomeTextureEntry.PLACEMENT_ROOM, Vector2i(1, 2))
	assert_eq(picked, room)

func _make_entry(placement: int) -> BiomeTextureEntry:
	var e := BiomeTextureEntry.new()
	e.placement = placement
	return e
