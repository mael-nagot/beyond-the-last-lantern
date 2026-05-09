# Below the Last Lantern — Assets Reference

## Folder Structure

```
res://assets/
├── biomes/                    ← BiomeData resource files (.tres)
│   └── forest.tres            ← Forest biome configuration
├── items/                     ← ItemData resource files (.tres) — see items/README.md
├── textures/                  ← All texture image files
│   ├── biomes/
│   │   └── forest/
│   │       ├── walls/         ← Wall textures for the forest biome
│   │       │   ├── wall_bark_01_albedo.png
│   │       │   └── wall_bark_01_normal.png
│   │       ├── floors/        ← Floor textures for the forest biome
│   │       │   ├── floor_dirt_01_albedo.png
│   │       │   └── floor_dirt_01_normal.png
│   │       └── ceilings/      ← Ceiling textures for the forest biome
│   │           ├── ceiling_canopy_01_albedo.png
│   │           └── ceiling_canopy_01_normal.png
│   └── items/                 ← Item textures — see textures/items/README.md
│       ├── icons/             ← Small square icons for the item bar
│       └── sprites/           ← Larger sprites for floor Sprite3D billboards
└── (future folders below)
```

### Planned Asset Folders (not yet created)

```
res://assets/
├── textures/
│   ├── biomes/
│   │   ├── forest/            ← done
│   │   ├── dungeon/           ← stone/brick dungeon biome
│   │   ├── swamp/             ← swamp/marsh biome
│   │   ├── underwater/        ← underwater biome
│   │   └── (more biomes)/
│   ├── items/
│   │   ├── icons/             ← small square icons for item bar, equipment, shops
│   │   └── sprites/           ← larger sprites for items on dungeon floor (Sprite3D)
│   ├── enemies/
│   │   └── sprites/           ← enemy sprites (Sprite3D billboards)
│   ├── characters/
│   │   └── portraits/         ← character portrait images for each class/gender
│   ├── objects/
│   │   ├── floor/             ← chest, campfire, trap sprites
│   │   └── wall/              ← lever, painting, torch, door sprites
│   ├── decorations/
│   │   └── torch/             ← per-decoration folder for multi-frame animations (torch_forest_01.png … _04.png)
│   └── ui/
│       ├── buttons/           ← custom button textures (if replacing default)
│       ├── panels/            ← panel background textures
│       └── map/               ← map overlay textures (parchment, compass)
├── biomes/                    ← BiomeData .tres files
├── items/                     ← ItemData .tres files (future)
├── enemies/                   ← EnemyData .tres files (future)
├── characters/                ← CharacterData .tres files (future)
├── spells/                    ← SpellData .tres files (future)
└── quests/                    ← QuestData .tres files (future)
```

---

## Biome Resource Files (.tres)

Each `.tres` file in `res://assets/biomes/` is a `BiomeData` resource configured in the Godot Inspector. It references texture files from the `textures/biomes/` folder.

### forest.tres (Forest Biome)

The first and currently only biome. Contains:
- Wall textures: hand-drawn bark/tree trunk textures with normal maps
- Floor textures: dirt and root textures with normal maps
- Ceiling textures: leaf canopy textures with normal maps
- Fog: dark green, low density for forest atmosphere
- Ambient light: warm natural tone
- Triplanar mapping: enabled for organic corner blending

---

## Texture Conventions

### Naming Convention

```
[surface]_[description]_[number]_[type].png

Examples:
wall_bark_01_albedo.png
wall_bark_01_normal.png
floor_dirt_02_albedo.png
ceiling_canopy_01_normal.png
```

### Texture Types

| Suffix | Purpose | Import Settings |
|---|---|---|
| `_albedo` | Base color texture | sRGB: on, Mipmaps: on |
| `_normal` | Normal map for surface relief | sRGB: off, Normal Map: on, Mipmaps: on, Detect 3D: off |

Additional texture types may be added later (roughness, AO, specular) but are not currently used.

### Recommended Sizes

- Wall/floor/ceiling textures: 512×512 or 256×256 pixels
- Item icons: 64×64 or 128×128 pixels
- Item dungeon sprites: 128×128 or 256×256 pixels (transparent background)
- Wall decoration sprites (paintings, torches, lanterns): 128×128 pixels (transparent background) — for animated decorations, every frame must be the **exact same dimensions** with the same anchor (mounting bracket pixel) across frames, or the sprite will jitter on loop
- Trap sprites (Phase 8 Task 3): TWO art pieces per trap variant — `<trap>_hole.png` (~64×64, **top-down view**, drawn as if seen from straight above the floor) and `<trap>_extended.png` (~64×128, **side view**, drawn as if seen at eye level looking horizontally). The hole sprite renders flat on the floor (`MeshInstance3D` quad lying horizontal); the extended sprite renders as a vertical billboard. They are intentionally drawn from different perspectives because they're rendered differently. A single hole+spike pair is replicated `grid_cols × grid_rows` times across the cell at runtime — designers do NOT pre-compose multi-spike artwork
- Projectile-trap art (Phase 8 Task 3 — Subtask C): up to FOUR art pieces per variant (in `objects/wall/` for the launcher, `objects/floor/` for the plate decal, `objects/projectiles/` for the in-flight sprites). The launcher (`<trap>_launcher.png`, ~128×128, side view drawn flush with the wall) renders as a wall-mounted Sprite3D. The optional pressure plate (`<trap>_plate.png`, ~128×128, top-down view) renders as a floor decal. The projectile uses Subtask C2's 4-direction system: `<trap>_projectile_front.png` is mandatory (the view the player sees when the projectile is coming at them); `_back`, `_left`, `_right` are optional and fall back to `_front`. Spherical projectiles (fireballs) only need `_front`; arrows need all four. All four projectile slots, when supplied, must share dimensions so the sprite doesn't pop sizes mid-flight. Suggested ~64×64 for projectiles
- Enemy sprites: 256×256 or 512×512 pixels (transparent background)
- Character portraits: 128×128 or 256×256 pixels

### Import Settings Reference

When importing textures in Godot, click the file in the FileSystem panel, go to the Import tab, and set:

**Albedo textures:**
```
Compress > Mode: VRAM Compressed
Process > sRGB: on
Mipmaps > Generate: on
```

**Normal map textures:**
```
Compress > Mode: VRAM Compressed
Process > sRGB: off
Process > Normal Map Invert Y: off (try on if normals look inverted)
Mipmaps > Generate: on
Detect 3D: off
```

Click **Reimport** after changing any setting.

---

## Art Style Guidelines

The game uses an old-school pixel art aesthetic inspired by Eye of the Beholder and Lands of Lore:

- **Hand-drawn 2D textures** applied to 3D flat quads (not 3D models)
- **Ambient-only lighting** — no harsh directional lights. Depth is painted into the textures.
- **Limited color palette** per biome — 16 to 32 colors for consistency
- **Fog** provides depth cues — distant walls fade into the fog color
- **No normal maps** — the chunky pixel-art look + the ambient-only lighting model don't benefit from per-pixel surface relief, and dropping them simplifies the texture pipeline (one albedo per `BiomeTextureEntry`)
- **Triplanar mapping** blends textures at corners for organic transitions (configurable per biome)
- **Objects and enemies** rendered as Sprite3D billboards (flat 2D sprites that face the camera)
- **Items** need two art pieces: a small icon and a larger dungeon floor sprite
