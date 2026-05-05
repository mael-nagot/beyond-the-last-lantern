extends GutTest

func test_defaults() -> void:
	var table := LootTable.new()
	assert_eq(table.min_rolls, 1)
	assert_eq(table.max_rolls, 3)
	assert_eq(table.entries.size(), 0)
