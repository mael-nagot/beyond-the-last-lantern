# Items — Resource Files

This folder contains `ItemData` resources (`.tres` files) that define every item in the game.

Each `.tres` is configured in the Godot Inspector and references texture files from `res://assets/textures/items/`.

## Naming Convention

```
[item_id].tres

Examples:
health_potion.tres
mana_potion_small.tres
iron_sword.tres
```

## Field Reference

See `ItemData.gd` for the full schema. Common fields:

| Field | Purpose |
|---|---|
| `item_name` | Translation key for the display name (e.g. `item.health_potion.name`) — see `res://localization/` |
| `description` | Translation key for the tooltip text (e.g. `item.health_potion.description`) |
| `category` | CONSUMABLE, EQUIPMENT, THROWABLE, QUEST |
| `effect_type` | NONE, HEAL_HP, HEAL_MP, STAT_BOOST, CURE_STATUS, DAMAGE, INFLICT_STATUS |
| `effect_value` | Amount healed / damage dealt / boost size |
| `stackable` | Whether multiple copies can share one slot |
| `stack_max` | Max copies per stack (typical: 9) |
| `icon` | Texture shown in the item bar (small square) |
| `dungeon_sprite` | Texture shown when the item sits on the dungeon floor (Sprite3D) |
| `buy_price` / `sell_price` | Shop economy values |

## Existing Items

(none yet — first one will be `health_potion.tres`)
