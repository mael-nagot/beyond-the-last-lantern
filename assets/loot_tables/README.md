# Loot Tables

`LootTable` resources (`.tres`) configure what gets rolled into chests, and (later) what enemies drop on death and what quest rewards contain. Decoupled from the chest visuals (`ObjectData`) so the same chest can hold completely different loot in different biomes.

## Structure

```
LootTable
├── min_rolls: int        # how many items get added at minimum (1 roll = 1 item)
├── max_rolls: int        # cap on items rolled (rolled randomly between min and max)
└── entries: Array[LootTableEntry]
	└── each entry:
		├── item: ItemData              # what can be rolled
		├── weight: int                  # relative probability vs other entries
		└── allow_duplicates: bool       # if false, this entry can be picked at most once per chest
```

## Naming convention

```
[biome]_[chest_tier_or_purpose].tres

Examples:
forest_chest_basic.tres        — common pool for the forest biome
forest_chest_rare.tres         — gear-heavy table behind a rare chest
forest_chest_potions.tres      — potion-only restock chest
dungeon_chest_armor.tres       — future: armor-focused dungeon chest
```

## How it's used

A biome's `BiomeData.objects: Array[ObjectSpawn]` lists chest placements. Each `ObjectSpawn` has both `object: ObjectData` (which chest visual) and `loot_table: LootTable` (what's inside). The same `chest_wooden.tres` can appear in multiple `ObjectSpawn` entries, each with its own loot table — useful for "two of these chests have basic loot, one of them has the rare loot".

## Example: a forest "common" chest

- `min_rolls: 1`, `max_rolls: 3`
- entries:
  - `health_potion.tres`, weight 5, allow_duplicates true
  - `mana_potion.tres`, weight 3, allow_duplicates true
  - `iron_sword.tres`, weight 1, allow_duplicates **false** (can only appear once)
  - `leather_armor.tres`, weight 1, allow_duplicates **false**

A roll of "3 items" might give `[health_potion, health_potion, iron_sword]` — but never `[iron_sword, iron_sword, …]` because the sword entry was removed from the pool after its first pick.
