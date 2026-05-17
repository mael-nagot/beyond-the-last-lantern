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

- `tree01.png` — primary tree silhouette referenced by
  [`assets/filler/sparse_forest_tree.tres`](../../../../filler/sparse_forest_tree.tres).
- `tree02.png` — second variant referenced as an inline `FillerData`
  sub-resource inside the SparseForest biome `.tres`.

Add more variants as `tree03.png`, `bush01.png`, `rock01.png`, etc.,
and reference them either from new `FillerData` resources in
`assets/filler/` or as inline sub-resources on the biome.
