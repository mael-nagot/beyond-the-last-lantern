class_name ItemData
extends Resource

enum Category {
	CONSUMABLE,
	EQUIPMENT,
	THROWABLE,
	QUEST,
}

enum EffectType {
	NONE,
	HEAL_HP,
	HEAL_MP,
	STAT_BOOST,
	CURE_STATUS,
	DAMAGE,
	INFLICT_STATUS,
}

# Translation key (e.g. "item.health_potion.name"). See res://localization/.
@export var item_name: String = ""
# Translation key (e.g. "item.health_potion.description"). See res://localization/.
@export_multiline var description: String = ""
@export var category: Category = Category.CONSUMABLE

@export_group("Effect")
@export var effect_type: EffectType = EffectType.NONE
@export var effect_value: int = 0
@export var effect_duration: int = 0

@export_group("Stacking")
@export var stackable: bool = true
@export var stack_max: int = 9

@export_group("Art")
@export var icon: Texture2D
@export var dungeon_sprite: Texture2D
@export var dungeon_sprite_world_height: float = 0.5
@export var dungeon_sprite_y_offset: float = 0.0

@export_group("Economy")
@export var buy_price: int = 0
@export var sell_price: int = 0

func get_display_name() -> String:
	return tr(item_name)

func get_display_description() -> String:
	return tr(description)
