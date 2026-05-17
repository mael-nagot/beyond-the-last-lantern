# Sparse Forest — Filler Sprites

Tree / bush / rock PNGs spawned outside the walkable area of the
SparseForest biome (and other outdoor biomes that reuse the same
sprites). One PNG per silhouette variant.

## Conventions

- Transparent background (alpha channel)
- Taller than wide for trees, square-ish for rocks
- 256–512 px tall is plenty — `FillerData.world_height` controls the
  real-world size, not the PNG resolution
- Import settings: **Filter = Nearest** (keeps pixel art crisp)

## Files

- `tree_01.png` — primary tree silhouette referenced by
  [`assets/filler/sparse_forest_tree.tres`](../../../../filler/sparse_forest_tree.tres).
  **Drop the PNG here before testing the SparseForest biome** — without
  it the FillerData will load with no texture and the level will look
  empty outside the walkable area.

Add more variants as `tree_02.png`, `bush_01.png`, etc., and reference
them from new `FillerData` resources in `assets/filler/`.
