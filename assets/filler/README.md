# Fillers

`FillerData` resources for the outdoor-biome filler system (trees,
rocks, bushes, etc.). One `.tres` per silhouette variant. Pulled in by
each outdoor biome via a `FillerSpawn` entry on its `filler_spawns`
array.

Fillers are pure decoration — they never block, never interact, never
animate. They sit on WALL cells inside the grid and on the configured
border ring outside it whenever the host biome has `outdoor_mode = true`.

## File naming

`<biome_or_theme>_<sprite>.tres` — e.g. `sparse_forest_tree.tres`,
`beach_rock.tres`, `swamp_reed.tres`. Group by theme so a designer
adding a new outdoor biome can find related silhouettes at a glance.

## Required fields

- `texture` — PNG with transparent background, taller than wide for
  trees, square-ish for rocks. Set Filter = Nearest on import to keep
  the pixel-art crisp.
- `world_height` — real-world height in metres. A tree reads as a
  tree at roughly 3.5–5.0; a bush 0.6–1.2; a rock 0.4–1.5.
- `y_offset` — vertical nudge after the sprite's bottom is anchored
  to floor level. Positive lifts the sprite; negative pushes it into
  the ground (useful when the PNG has transparent padding below).
- `name_key` / `description_key` — translation keys for editor and
  debug labels (never displayed to the player today, but reserved for
  future map-cursor / bestiary use).
