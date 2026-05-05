extends GutTest

func test_defaults() -> void:
	var entry := LootTableEntry.new()
	assert_null(entry.item)
	assert_eq(entry.weight, 1)
	assert_true(entry.allow_duplicates)
