extends GutTest

# These tests rely on res://localization/strings.csv being registered as
# a translation in project.godot, which the localization scaffolding sets
# up. tr() returning the key itself indicates a missing translation.

func test_get_display_name_resolves_known_key() -> void:
	var data := ItemData.new()
	data.item_name = "item.health_potion.name"
	assert_eq(data.get_display_name(), "Health Potion")

func test_get_display_description_resolves_known_key() -> void:
	var data := ItemData.new()
	data.description = "item.health_potion.description"
	assert_eq(data.get_display_description(), "Restores 30 HP.")

func test_unknown_key_returns_the_key_itself() -> void:
	# Godot's tr() returns the input string when no translation matches.
	var data := ItemData.new()
	data.item_name = "item.does_not_exist.name"
	assert_eq(data.get_display_name(), "item.does_not_exist.name")

func test_default_field_values() -> void:
	var data := ItemData.new()
	assert_eq(data.item_name, "")
	assert_eq(data.description, "")
	assert_eq(data.category, ItemData.Category.CONSUMABLE)
	assert_eq(data.effect_type, ItemData.EffectType.NONE)
	assert_eq(data.effect_value, 0)
	assert_eq(data.stackable, true)
	assert_eq(data.stack_max, 9)
	assert_eq(data.dungeon_sprite_world_height, 0.5)
	assert_eq(data.dungeon_sprite_y_offset, 0.0)
	assert_eq(data.buy_price, 0)
	assert_eq(data.sell_price, 0)
