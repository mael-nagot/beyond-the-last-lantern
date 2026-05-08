extends GutTest

func test_defaults() -> void:
	var entry := BiomeTextureEntry.new()
	assert_null(entry.albedo)
	assert_null(entry.normal)
	assert_eq(entry.placement, BiomeTextureEntry.PLACEMENT_ANY)
	assert_eq(entry.weight, 1)
	assert_eq(entry.min_distance_to_same, 0)

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

func test_pick_for_weight_zero_excluded_when_others_have_weight() -> void:
	var weighted := _make_entry(BiomeTextureEntry.PLACEMENT_ANY)
	weighted.weight = 5
	var disabled := _make_entry(BiomeTextureEntry.PLACEMENT_ANY)
	disabled.weight = 0
	var entries: Array = [disabled, weighted]
	# Sweep cells; only the weight-5 entry should ever come back.
	for x in range(0, 6):
		for y in range(0, 6):
			var picked := BiomeTextureEntry.pick_for(
				entries, BiomeTextureEntry.PLACEMENT_CORRIDOR, Vector2i(x, y))
			assert_eq(picked, weighted)

func test_pick_for_all_zero_weights_falls_back_to_uniform() -> void:
	# Pathological: every matching entry has weight 0. Picker must
	# still return something rather than crashing on `% 0`.
	var a := _make_entry(BiomeTextureEntry.PLACEMENT_ANY)
	a.weight = 0
	var b := _make_entry(BiomeTextureEntry.PLACEMENT_ANY)
	b.weight = 0
	var entries: Array = [a, b]
	var picked := BiomeTextureEntry.pick_for(
		entries, BiomeTextureEntry.PLACEMENT_CORRIDOR, Vector2i(2, 2))
	assert_true(picked == a or picked == b)

func test_pick_for_weight_distribution_skews_toward_higher_weight() -> void:
	# A: weight 9, B: weight 1 → A should land on roughly 90% of cells.
	# We just assert A wins by a wide margin (don't pin an exact ratio,
	# the hash isn't a perfect uniform RNG over a small grid).
	var a := _make_entry(BiomeTextureEntry.PLACEMENT_ANY)
	a.weight = 9
	var b := _make_entry(BiomeTextureEntry.PLACEMENT_ANY)
	b.weight = 1
	var entries: Array = [a, b]
	var a_count := 0
	var b_count := 0
	for x in range(0, 20):
		for y in range(0, 20):
			var picked := BiomeTextureEntry.pick_for(
				entries, BiomeTextureEntry.PLACEMENT_CORRIDOR, Vector2i(x, y))
			if picked == a:
				a_count += 1
			elif picked == b:
				b_count += 1
	assert_gt(a_count, b_count * 3, "weight 9 should dominate weight 1 across 400 cells")

func test_pick_for_min_distance_excludes_nearby_same_entry() -> void:
	# Single-entry pool with min_distance 5. After a placement at
	# (0, 0), cells within Manhattan distance 5 should fall back to the
	# matching set (which is just this one entry, so they get it
	# anyway). Verify history is honoured rather than crashing.
	var spaced := _make_entry(BiomeTextureEntry.PLACEMENT_ANY)
	spaced.min_distance_to_same = 5
	var history: Dictionary = {spaced: [Vector2i(0, 0)]}
	var picked := BiomeTextureEntry.pick_for(
		[spaced], BiomeTextureEntry.PLACEMENT_CORRIDOR, Vector2i(2, 2), history)
	assert_eq(picked, spaced, "single-entry pool falls back to forced pick when distance excludes everything")

func test_pick_for_min_distance_chooses_other_entry_when_available() -> void:
	# Two entries; A has min_distance 5 and is already placed at (0, 0);
	# B has no constraint. Cell (2, 2) is Manhattan distance 4 from A's
	# placement → A is ineligible, picker must return B.
	var spaced := _make_entry(BiomeTextureEntry.PLACEMENT_ANY)
	spaced.min_distance_to_same = 5
	var unrestricted := _make_entry(BiomeTextureEntry.PLACEMENT_ANY)
	var entries: Array = [spaced, unrestricted]
	var history: Dictionary = {spaced: [Vector2i(0, 0)]}
	var picked := BiomeTextureEntry.pick_for(
		entries, BiomeTextureEntry.PLACEMENT_CORRIDOR, Vector2i(2, 2), history)
	assert_eq(picked, unrestricted)

func test_pick_for_min_distance_allows_same_entry_when_far_enough() -> void:
	var spaced := _make_entry(BiomeTextureEntry.PLACEMENT_ANY)
	spaced.min_distance_to_same = 3
	var other := _make_entry(BiomeTextureEntry.PLACEMENT_ANY)
	# Skew the weight so the unrestricted picker would normally favour
	# `spaced` — proves the distance filter isn't accidentally blocking
	# it when the constraint IS satisfied.
	spaced.weight = 100
	other.weight = 1
	var history: Dictionary = {spaced: [Vector2i(0, 0)]}
	# (5, 5) is Manhattan distance 10 — well outside 3.
	var picked := BiomeTextureEntry.pick_for(
		[spaced, other], BiomeTextureEntry.PLACEMENT_CORRIDOR, Vector2i(5, 5), history)
	assert_eq(picked, spaced)

func _make_entry(placement: int) -> BiomeTextureEntry:
	var e := BiomeTextureEntry.new()
	e.placement = placement
	return e
