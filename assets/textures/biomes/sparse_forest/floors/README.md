# Sparse Forest — Floor Textures

Floor PNGs for the SparseForest biome. Two consumers:

- **`BiomeData.floor_textures`** — what the player walks on (the
  path through the forest). For the v1 prototype this reuses
  `assets/textures/biomes/forest/floors/forest floor_01.png` so the
  walkable area looks like the existing forest. Drop sparse-forest-
  specific path variants (grass paths, dirt trails) here when you
  want to diverge.
- **`BiomeData.filler_floor_textures`** — what extends under the
  trees and past the grid edge (the forest litter you see beyond
  the path). Empty falls back to `floor_textures` so the floor
  reads as one continuous surface. Drop forest-litter variants
  (fallen leaves, exposed roots, moss patches) here to make the
  under-tree ground visually distinct from the path.

Import settings: **Filter = Nearest** (same as the other biome
textures).
