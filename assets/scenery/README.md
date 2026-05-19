# Scenery

`SceneryData` resources for the walkable-area scenery system —
trees, flowers, mushrooms, rocks placed INSIDE the dungeon on FLOOR
cells. Pulled in by each biome via `ScenerySpawn` entries on
`BiomeData.scenery_spawns`.

This is the indoor cousin of [`assets/filler/`](../filler/README.md):
fillers sit on WALL cells in outdoor biomes; scenery sits on FLOOR
cells in any biome (indoor or outdoor).

## File naming

`<biome_or_theme>_<id>.tres` — e.g. `forest_tree.tres`,
`forest_flower.tres`, `cave_mushroom.tres`. Group by biome so a
designer adding a new biome can find related sprites at a glance.

## Required fields

- `texture` — PNG with transparent background, taller than wide for
  trees, square-ish for flowers / rocks. Set Filter = Nearest on
  import to keep the pixel art crisp.
- `walkable` — true for flowers / grass / small mushrooms (player
  steps through); false for trees / big rocks (player can't enter
  the cell). Non-walkable scenery is BFS-validated at placement to
  guarantee the level stays solvable.
- `world_height` — real-world height in metres. Trees 3.5–5.0,
  bushes 0.6–1.2, flowers 0.2–0.5.
- `y_offset` — vertical nudge after the sprite's bottom is anchored
  to floor level. Positive lifts; negative pushes into the ground
  (useful when the PNG has transparent stem padding below).
- `lean_toward_player` — 0.0 for centred decorations (flowers); 1.0–
  1.5 for solid objects (trees) so they shift off cell-centre toward
  the player's side and read as 3D rather than a flat pixel cluster.
  Refreshed on player turn, NOT on movement — same wiring as chests.
- `name_key` / `description_key` — translation keys for editor /
  debug labels. Reserved for future map-cursor / bestiary use.

## Per-biome spawning

Biomes pull in scenery via `BiomeData.scenery_spawns: Array[ScenerySpawn]`.
Each `ScenerySpawn` holds:

| Knob | What it controls |
|---|---|
| `scenery` | The `SceneryData` template (one per spawn) |
| `dead_end_chance` | % of dead-end cells (single tile each) that get a sprite |
| `corridor_segment_chance` | % of corridor segments that get scenery |
| `corridor_coverage_min_percent` / `max_percent` | What fraction of the hit segment's eligible cells to fill |
| `room_chance` | % of rooms that get scenery |
| `room_coverage_min_percent` / `max_percent` | What fraction of the hit room's eligible cells to fill |
| `min_distance_to_same` | Manhattan distance between two placements of the SAME `SceneryData` |

All three chances default to 0.0 — an empty spawn entry is a no-op,
so designers can add a `ScenerySpawn` to a biome and tune one knob
at a time.

Mixing trees + flowers? Use TWO `ScenerySpawn` entries — one per
type. Cross-type spacing doesn't constrain (`min_distance_to_same`
only applies within ONE `SceneryData`), so a tree and a flower can
sit on adjacent cells.

## Existing scenery

- `forest_tree.tres` — first scenery resource. Non-walkable, uses
  the sparse-forest filler tree texture as a placeholder until the
  biome gets its own indoor-tree art.
