# Objects — Resource Files

This folder contains `ObjectData` resources (`.tres` files) — the data templates for every interactable in the dungeon.

Each `.tres` is configured in the Godot Inspector and references texture and sound files from `res://assets/textures/objects/` and `res://assets/sounds/objects/`.

## Naming Convention

```
[category]_[id].tres

Examples:
chest_wooden.tres
chest_iron.tres
door_wooden.tres        (future)
lever.tres              (future)
trap_spike.tres         (future)
campfire.tres           (future)
```

## Field Reference

See `ObjectData.gd` for the schema. Common fields across categories:

| Field | Purpose |
|---|---|
| `name_key` | Translation key for display name (e.g. `object.chest_wooden.name`) |
| `description_key` | Translation key for description |
| `category` | CHEST / DOOR / LEVER / TRAP / CAMPFIRE / DECORATION |
| `blocks_movement` | True for chests + doors; LevelGenerator validates BFS reachability after each placement |
| `closed_sprite` / `opened_sprite` | The Sprite3D textures used in the dungeon (latter is unused for non-stateful objects) |
| `world_height` / `y_offset` | Sprite size and vertical nudge in world units |
| `interact_sound` | Played on the first interaction (chest open, door open, etc.) |

**Loot is configured per-placement, not on the chest's `ObjectData`.** Each entry in a biome's `BiomeData.objects` array is an `ObjectSpawn` that pairs an `ObjectData` (visual + sound) with a `LootTable` (contents). The same `chest_wooden.tres` can appear in multiple spawn entries with different loot tables — see `res://assets/loot_tables/README.md`.

## Existing Objects

(Phase 8 Task 1 introduces `chest_wooden.tres` and `chest_iron.tres` — populate them in the Inspector after the code lands.)

## Per-biome spawning

Biomes define which objects spawn and how many via `BiomeData.objects: Array[ObjectSpawn]`. Each entry is `{ object, count_min, count_max, placement_flags }`. Default placement is `Room | Dead End` so chests don't pile up in corridors.
