# Below the Last Lantern — Assets Reference

## Folder Structure

```
res://assets/
├── biomes/                    ← BiomeData resource files (.tres)
│   ├── forest.tres            ← Forest biome (indoor — wall geometry)
│   └── sparse_forest.tres     ← Sparse Forest biome (outdoor — fillers + sky)
├── filler/                    ← FillerData resource files — see filler/README.md
│   └── sparse_forest_tree.tres
├── scenery/                   ← SceneryData resource files (walkable-area trees / flowers / mushrooms placed on FLOOR cells) — see scenery/README.md
├── items/                     ← ItemData resource files (.tres) — see items/README.md
├── textures/                  ← All texture image files
│   ├── biomes/
│   │   ├── forest/
│   │   │   ├── walls/         ← Wall textures for the forest biome
│   │   │   ├── floors/        ← Floor textures for the forest biome
│   │   │   └── ceilings/      ← Ceiling textures for the forest biome
│   │   └── sparse_forest/
│   │       ├── fillers/       ← Tree / rock / bush PNGs (outdoor filler sprites)
│   │       └── floors/        ← Floor textures (optional — reuses forest's by default)
│   │   (each biome's scenery PNGs live under .../<biome>/scenery/)
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

**Albedo textures (pixel art):**
```
Compress > Mode: Lossless
Process > sRGB: on
Mipmaps > Generate: on
```

> **Why Lossless, not VRAM Compressed?** VRAM Compressed (BCn / DXT block compression) is lossy — it averages 4×4 texel blocks and visibly softens hard pixel-art edges. Lossless keeps the source PNG pixels exactly as authored. The game's whole aesthetic is hand-drawn pixel art, so every albedo should be Lossless. (VRAM Compressed only makes sense for photographic textures or games that aren't pixel art.)

> **Source files must be PNG.** JPEG bakes lossy color smear into pixel-art edges before Godot ever sees the file — a `.jpg` will look soft no matter what the import settings say. Re-export from GIMP as PNG.

**Normal map textures:** (currently unused — see "no normal maps" under Art Style Guidelines below; kept here for reference if a future biome wants surface relief)
```
Compress > Mode: Lossless
Process > sRGB: off
Process > Normal Map Invert Y: off (try on if normals look inverted)
Mipmaps > Generate: on
Detect 3D: off
```

Click **Reimport** after changing any setting.

### Texture filtering (where pixel-art crispness actually comes from)

Godot 4 has no per-texture "Filter" import setting. Filter is set on the *consumer* (the material or sprite that samples the texture), and pixel art only stays crisp if every consumer uses **Nearest** filtering:

| Consumer | Where it's set | Mode |
|---|---|---|
| Biome wall / floor / ceiling materials | `DungeonView._build_material` | `TEXTURE_FILTER_NEAREST_WITH_MIPMAPS` |
| All in-world `Sprite3D` billboards (items, chests, traps, decorations, projectiles) | per-sprite `texture_filter` in `DungeonView.gd` | `TEXTURE_FILTER_NEAREST` |
| All 2D / UI textures | `project.godot` → `rendering/textures/canvas_textures/default_texture_filter=0` | Nearest (project-wide) |

If a new wall/floor/ceiling texture looks blurry in-engine while looking crisp in GIMP, the problem is almost always (a) the source file is JPEG, or (b) a new code path built a material without setting `texture_filter` to a Nearest variant. The "_WITH_MIPMAPS" suffix matters for the biome material because walls in fog get sampled at small screen sizes and pure Nearest sparkles/moirés at distance.

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
