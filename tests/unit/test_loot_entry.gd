extends GutTest

func test_defaults() -> void:
	var entry := LootEntry.new()
	assert_eq(entry.item, null)
	assert_eq(entry.weight, 1)
	assert_eq(entry.placement, LootEntry.PLACEMENT_ANY)

func test_placement_any_equals_all_three_flags() -> void:
	var expected := LootEntry.PLACEMENT_CORRIDOR | LootEntry.PLACEMENT_ROOM | LootEntry.PLACEMENT_DEAD_END
	assert_eq(LootEntry.PLACEMENT_ANY, expected)

func test_allows_corridor_only() -> void:
	var entry := LootEntry.new()
	entry.placement = LootEntry.PLACEMENT_CORRIDOR
	assert_true(entry.allows(LootEntry.PLACEMENT_CORRIDOR))
	assert_false(entry.allows(LootEntry.PLACEMENT_ROOM))
	assert_false(entry.allows(LootEntry.PLACEMENT_DEAD_END))

func test_allows_room_only() -> void:
	var entry := LootEntry.new()
	entry.placement = LootEntry.PLACEMENT_ROOM
	assert_false(entry.allows(LootEntry.PLACEMENT_CORRIDOR))
	assert_true(entry.allows(LootEntry.PLACEMENT_ROOM))
	assert_false(entry.allows(LootEntry.PLACEMENT_DEAD_END))

func test_allows_dead_end_only() -> void:
	var entry := LootEntry.new()
	entry.placement = LootEntry.PLACEMENT_DEAD_END
	assert_false(entry.allows(LootEntry.PLACEMENT_CORRIDOR))
	assert_false(entry.allows(LootEntry.PLACEMENT_ROOM))
	assert_true(entry.allows(LootEntry.PLACEMENT_DEAD_END))

func test_allows_combined_corridor_and_room() -> void:
	var entry := LootEntry.new()
	entry.placement = LootEntry.PLACEMENT_CORRIDOR | LootEntry.PLACEMENT_ROOM
	assert_true(entry.allows(LootEntry.PLACEMENT_CORRIDOR))
	assert_true(entry.allows(LootEntry.PLACEMENT_ROOM))
	assert_false(entry.allows(LootEntry.PLACEMENT_DEAD_END))

func test_allows_any_returns_true_for_every_placement() -> void:
	var entry := LootEntry.new()
	entry.placement = LootEntry.PLACEMENT_ANY
	assert_true(entry.allows(LootEntry.PLACEMENT_CORRIDOR))
	assert_true(entry.allows(LootEntry.PLACEMENT_ROOM))
	assert_true(entry.allows(LootEntry.PLACEMENT_DEAD_END))

func test_allows_returns_false_when_placement_is_zero() -> void:
	var entry := LootEntry.new()
	entry.placement = 0
	assert_false(entry.allows(LootEntry.PLACEMENT_CORRIDOR))
	assert_false(entry.allows(LootEntry.PLACEMENT_ROOM))
	assert_false(entry.allows(LootEntry.PLACEMENT_DEAD_END))
