# Wall decoration textures

One subfolder per decoration. For animated decorations, each folder holds the multi-frame PNG sequence used by a `SpriteFrames` resource (see `res://assets/decorations/README.md`).

## Naming convention

```
<name>_NN.png    — animated frame N (zero-padded, starts at 01)
<name>.png       — single frame (static painting)
```

## Frame rules (animated)

- **All frames must be the same pixel dimensions.** Mismatch → torch jitters as it loops.
- **Same anchor across frames.** Keep the mounting bracket / handle pixel at the same coordinates in every frame; only the part that should move (the flame) should move. Otherwise the torch wobbles on the wall.
- **Transparent background** (PNG alpha).
- **128×128** is the recommended size — bottom 1/3 for the bracket, top 2/3 for the flame works well.

## Import settings

For each frame, in the Godot Import tab:
- `Compress > Mode`: VRAM Compressed (or Lossless if pixel-art crispness suffers)
- `Process > sRGB`: on
- `Mipmaps > Generate`: on
- `Filter`: **Nearest** (Linear blurs pixel art) — set under `Compress > Mode` if available, or via the Sprite3D's `texture_filter` (already set by the renderer)
