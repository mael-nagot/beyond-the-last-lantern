class_name ItemData
extends Resource

enum Category {
	CONSUMABLE,
	EQUIPMENT,
	THROWABLE,
	QUEST,
	KEY,
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

## Translation key for the item's display name (e.g.
## "item.health_potion.name"). NOT the literal English text — the
## English string lives in `res://localization/strings.csv`. Use
## `get_display_name()` to fetch the translated text.
@export var item_name: String = ""
## Translation key for the item's description tooltip (e.g.
## "item.health_potion.description"). Same key convention as
## `item_name`. Use `get_display_description()` to fetch the
## translated text.
@export_multiline var description: String = ""
## Item category. CONSUMABLE / EQUIPMENT / THROWABLE / QUEST / KEY.
## Drives where the item can be used (drag to character vs to
## dungeon) and which slots it can occupy.
@export var category: Category = Category.CONSUMABLE

@export_group("Effect")
## What happens when the item is consumed. NONE = no in-game effect
## (quest items, lore). HEAL_HP / HEAL_MP restore the character's
## stat by `effect_value`. STAT_BOOST / INFLICT_STATUS use both
## `effect_value` (magnitude) and `effect_duration` (turns).
@export var effect_type: EffectType = EffectType.NONE
## Magnitude of the effect (HP healed, MP restored, stat boost amount,
## damage dealt — depending on `effect_type`).
@export var effect_value: int = 0
## How long a temporary effect lasts, in turns. Only meaningful for
## STAT_BOOST and INFLICT_STATUS. 0 for instant effects.
@export var effect_duration: int = 0

@export_group("Stacking")
## When true, multiple of this item can pile into a single inventory
## slot (potions, arrows). When false, each piece needs its own slot
## (unique equipment).
@export var stackable: bool = true
## Maximum count per inventory slot when `stackable = true`. Picking
## up past this cap rolls over into a new slot.
@export var stack_max: int = 9

@export_group("Art")
## Square icon shown in the item bar, equipment slots, shops, and the
## loot popup. ~64×64 px is typical.
@export var icon: Texture2D
## Side-view sprite used as the Sprite3D billboard when this item
## sits on the dungeon floor. Transparent background expected.
@export var dungeon_sprite: Texture2D
## Real-world height (in metres) of the dungeon sprite. Decouples
## physical size from PNG resolution: a 64×64 and a 128×128 texture
## render identically when this is set to the same value. Typical
## potions: 0.4–0.6.
@export var dungeon_sprite_world_height: float = 0.5
## Vertical nudge of the dungeon sprite above the floor plane. Use
## to compensate for transparent padding at the bottom of the PNG
## (so the visible item sits on the ground, not floating above it).
@export var dungeon_sprite_y_offset: float = 0.0

@export_group("Sound")
## Played when the player picks up this item OR drops it onto the
## dungeon floor. Same clip used for both events (one short sound).
## Sounds are reusable across items — e.g. every potion shares
## res://assets/sounds/items/potion_pickup_drop1.ogg.
@export var pickup_drop_sound: AudioStream
## Played when the item is consumed / applied (drag to character).
## Null = silent. For items that have no "use" action (equipment,
## quest items, keys) this is ignored.
@export var use_sound: AudioStream

@export_group("Economy")
## Cost in gold to buy this item at a shop. 0 = not for sale.
@export var buy_price: int = 0
## Gold received when the player sells this item at a shop. Usually
## a fraction of `buy_price`. 0 = unsellable.
@export var sell_price: int = 0

@export_group("Lock")
## Non-empty marks this item as a KEY that unlocks any DoorInstance
## whose `lock_id` equals this string. Empty for non-key items.
## LevelGenerator's KeyDoorSpawn placement picks / generates the
## matching id at biome generation time, so designers usually leave
## this blank on the .tres and let the spawn fill it in. Kept as a
## .tres field too so static keys (handcrafted levels later) can
## hard-code the id.
@export var key_id: String = ""

func get_display_name() -> String:
	return tr(item_name)

func get_display_description() -> String:
	return tr(description)
