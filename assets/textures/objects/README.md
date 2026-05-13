# Object Textures

Sprites for the dungeon Sprite3D billboards used by `ObjectData`, `TrapData`, `TeleporterData`, etc.

Stateful objects (chests, doors) typically need two textures — `closed` and `opened`. Non-stateful (campfires, decorations, teleporters) need only one.

## Naming Convention

```
[category]/[id]_[state].png  (stateful)
[category]/[id].png          (non-stateful)

Examples:
chest/chest_wooden_closed.png
chest/chest_wooden_opened.png
chest/chest_iron_closed.png
chest/chest_iron_opened.png
door/door_wooden_closed.png    (future)
door/door_wooden_opened.png    (future)
campfire/campfire_lit.png      (future)
teleporter/teleporter.png      (Phase 15 Task 6 — single rune circle, animated via the pulse driver in DungeonView)
```

## Recommended Sizes

128×128 to 256×256 PNG with transparent background. Pixel-art style, similar to item dungeon sprites. Aspect ratio is free — the renderer derives `pixel_size = world_height / texture_height` so wider-than-tall textures (e.g. 128×64 for a flat-disc teleporter) render correctly.

## Import Settings

Same as item dungeon sprites:
- `Compress > Mode: Lossless`
- `Process > sRGB: on`
- `Mipmaps > Generate: on`

Lossless (not VRAM Compressed) for pixel art — see `res://assets/README.md` "Texture filtering" section. Filter mode is NOT an import setting; it's set on the consuming `Sprite3D` (`TEXTURE_FILTER_NEAREST` in `DungeonView.gd`).
