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
Compress > Mode: Lossless (UI clarity)
Process > sRGB: on
Mipmaps > Generate: on
Filter: off (preserves pixel art crispness)
```

**Dungeon sprites (Sprite3D):**
```
Compress > Mode: VRAM Compressed
Process > sRGB: on
Mipmaps > Generate: on
Filter: off (preserves pixel art crispness)
```
