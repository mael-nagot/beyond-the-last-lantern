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

@export var item_name: String = ""
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

@export_group("Economy")
@export var buy_price: int = 0
@export var sell_price: int = 0
