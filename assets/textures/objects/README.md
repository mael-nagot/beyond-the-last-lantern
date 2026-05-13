# Object Textures

Sprites for the dungeon Sprite3D billboards used by `ObjectData`.

Stateful objects (chests, doors) typically need two textures — `closed` and `opened`. Non-stateful (campfires, decorations) need only one.

## Naming Convention

```
[category]/[id]_[state].png

Examples:
chest/chest_wooden_closed.png
chest/chest_wooden_opened.png
chest/chest_iron_closed.png
chest/chest_iron_opened.png
door/door_wooden_closed.png    (future)
door/door_wooden_opened.png    (future)
campfire/campfire_lit.png      (future)
```

## Recommended Sizes

128×128 to 256×256 PNG with transparent background. Pixel-art style, similar to item dungeon sprites.

## Import Settings

Same as item dungeon sprites:
- `Compress > Mode: Lossless`
- `Process > sRGB: on`
- `Mipmaps > Generate: on`

Lossless (not VRAM Compressed) for pixel art — see `res://assets/README.md` "Texture filtering" section. Filter mode is NOT an import setting; it's set on the consuming `Sprite3D` (`TEXTURE_FILTER_NEAREST` in `DungeonView.gd`).
