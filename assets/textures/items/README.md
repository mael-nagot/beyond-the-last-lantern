# Item Textures

Two textures per item:

- `icons/` — small square (64×64 or 128×128) shown in the item bar, equipment slots, and shop UI
- `sprites/` — larger transparent-background sprite (128×128 or 256×256) used as the `Sprite3D` billboard when the item sits on the dungeon floor

## Naming Convention

```
[item_id].png

icons/health_potion.png
sprites/health_potion.png
```

Use the same `[item_id]` for both files so they pair up obviously with the `.tres` in `res://assets/items/[item_id].tres`.

## Import Settings

**Icons (UI):**
```
Compress > Mode: Lossless
Process > sRGB: on
Mipmaps > Generate: on
```

**Dungeon sprites (Sprite3D):**
```
Compress > Mode: Lossless
Process > sRGB: on
Mipmaps > Generate: on
```

> Lossless (not VRAM Compressed) for pixel art — see `res://assets/README.md` "Texture filtering" section for the full explanation. Filter mode is NOT an import setting; it's set on the consuming `Sprite3D` (`TEXTURE_FILTER_NEAREST` in `DungeonView.gd`).
