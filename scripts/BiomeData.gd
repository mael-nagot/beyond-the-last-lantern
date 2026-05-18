class_name BiomeData
extends Resource

## Designer-friendly biome label (used in editor / debug logs).
## Not player-facing — display names go through the localization
## system, not this field.
@export var biome_name: String = "Forest"

@export_group("Wall Textures")
## Pool of wall texture variants for this biome. Each entry pairs an
## albedo with placement flags (Corridor / Room / Dead End) + weight +
## min-distance rules so the renderer picks variants per cell type.
## Multiple entries enable location-specific art (mossy dead-end
## walls, vaulted room walls, worn corridor walls). Empty / no match
## falls back to the full pool. See `BiomeTextureEntry`.
@export var wall_textures: Array[BiomeTextureEntry] = []

@export_group("Floor Textures")
## Pool of floor texture variants. Same shape as `wall_textures`.
@export var floor_textures: Array[BiomeTextureEntry] = []

@export_group("Ceiling Textures")
## Pool of ceiling texture variants. Same shape as `wall_textures`.
## Ignored when `show_ceiling = false` or `outdoor_mode = true`.
@export var ceiling_textures: Array[BiomeTextureEntry] = []

@export_group("Appearance")
## Height of wall geometry in world units. Player camera eye height is
## typically ~1.8; default 6.3 gives roughly 3× headroom — feels like
## a tall dungeon corridor.
@export var wall_height:    float = 6.3
## When true, a ceiling quad is drawn at the top of every walkable
## cell. Turn off for biomes that should feel open above (cathedrals,
## ruined zones). Forced off when `outdoor_mode = true`.
@export var show_ceiling:   bool  = true
## When true, exponential distance fog tints geometry past a certain
## range. Sells depth and hides the far edge of the grid. Disable
## only for brightly-lit indoor biomes where fog reads as smoke.
@export var fog_enabled:    bool  = true
## Fog tint colour. Usually matches the biome's dominant hue (deep
## green in forests, near-black in caves) so distant geometry fades
## into a believable haze.
@export var fog_color:      Color = Color(0.05, 0.10, 0.03)
## How thick the fog is. Higher = geometry fades closer to the camera.
## Typical 0.02–0.06. Above ~0.08 the player can't see the next cell
## clearly; below ~0.01 fog is almost invisible.
@export var fog_density:    float = 0.04
## Aerial-perspective amount. Blends distant geometry toward the fog
## colour even before density fully takes over. 0 = off; ~0.1–0.3
## strengthens the "atmospheric distance" feel.
@export var fog_aerial:     float = 0.1
## Tint of the ambient light that lifts shadowed areas. The dungeon
## uses ambient-only lighting (no directional sun) so this is the
## primary look-setting alongside fog.
@export var ambient_color:  Color = Color(0.6, 0.55, 0.4)
## Brightness multiplier on the ambient light. 1.0 = neutral; ~1.5
## brightens textures noticeably; <0.5 makes the dungeon feel dim
## and oppressive.
@export var ambient_energy: float = 1.2

@export_group("Outdoor Mode")
## When true, the renderer skips wall geometry entirely and the biome
## fills its impassable cells (and a configurable border ring beyond
## the grid edge) with billboarded sprites from `filler_spawns`
## instead. Used for open-air biomes like sparse forests or beaches
## where the "wall" is conceptually a tree-line or rock-line.
## `wall_decorations`, `projectile_trap_spawns`, and `secret_wall_spawns`
## all require real wall geometry — leave those arrays empty when
## `outdoor_mode = true`.
@export var outdoor_mode: bool = false

## Sprite pools spawned on WALL cells + border ring when
## `outdoor_mode = true`. Multiple entries allowed — e.g. one for big
## trees, one for ferns, one for rocks — and every entry is iterated
## by the placer so they layer. Ignored when outdoor_mode is false.
@export var filler_spawns: Array[FillerSpawn] = []

## Textures for the floor under fillers (and the floor extending past
## the grid edge). Same `BiomeTextureEntry` resource as the walkable
## floor pool — supports weights, placement flags, and
## min_distance_to_same so designers can mix forest litter, dirt
## patches, and exposed roots under the trees.
## Empty falls back to `floor_textures` (so a biome with one floor
## look everywhere doesn't need to duplicate the array). Only used
## when `outdoor_mode = true`.
@export var filler_floor_textures: Array[BiomeTextureEntry] = []

## How many cells beyond the grid edge to extend the outdoor floor
## in every direction. The floor is drawn under WALL cells inside
## the grid AND across this border ring outside it, so the player
## sees ground stretching out beneath the trees rather than a sharp
## edge of world.
## Defaults to 8 (the typical filler border is 4, plus extra slack
## so the floor visibly extends past the last tree before fog
## swallows it). Only used when `outdoor_mode = true`.
@export var outdoor_floor_extent: int = 8

## Flat background colour to override on the WorldEnvironment when
## entering this biome. Alpha = 0 means "don't override" (the
## WorldEnvironment keeps whatever background is currently set).
## Alpha > 0 swaps env.background_mode to BG_COLOR and applies the
## colour. Only takes effect for outdoor biomes (with walls in place
## the background colour is never visible anyway).
@export var sky_color: Color = Color(0.0, 0.0, 0.0, 0.0)

## Optional sky material override (PanoramaSkyMaterial,
## ProceduralSkyMaterial, PhysicalSkyMaterial). When non-null, takes
## precedence over `sky_color`: the renderer wraps it in a Sky
## resource and sets the env to BG_SKY.
## Path to upgrade from a flat colour to a textured sky later — drop
## a panorama PNG into a PanoramaSkyMaterial, assign it here, done.
@export var sky_material: Material = null

@export_group("Texture Mapping")
## When true, wall / floor / ceiling textures are sampled with
## triplanar mapping (projected from world XYZ rather than UV).
## Lets a single texture tile seamlessly across multi-cell surfaces
## without authoring per-cell UVs. Costs ~3× the texture samples per
## fragment — fine for indoor biomes, skip on big outdoor floors.
@export var use_triplanar: bool = false
## Triplanar blend sharpness. 0 = soft transitions between the three
## projection axes; 1 = hard switch (one axis dominates each fragment).
## ~0.5 is a balanced compromise.
@export var triplanar_sharpness: float = 0.5
## Y-axis offset applied to the triplanar projection (in world units),
## shifting where the floor / ceiling texture seams sit vertically.
## Tweak when a wall texture's horizontal feature lands awkwardly on
## the player's eye line.
@export var triplanar_y_offset: float = 0.5

@export_group("Level Generation — Grid")
## Width of the generated dungeon grid, in cells. Typical 21–41.
## Larger = longer runs, more content per level, more memory.
@export var grid_width: int = 31
## Height of the generated dungeon grid, in cells. Same range as
## `grid_width`. Square grids (width == height) are most common.
@export var grid_height: int = 31

@export_group("Level Generation — Entrance / Exit")
## Minimum Manhattan distance (in tiles) between the entrance and the
## exit. Prevents short "walk 3 tiles and you're done" levels. Higher
## values guarantee longer runs at the cost of more retries during
## generation.
@export var min_exit_distance: int = 10
## When true, the entrance is placed at a corridor dead-end. Reads as
## "you crawled in through a tunnel". When false, the entrance can be
## any floor cell (more open).
@export var entrance_at_dead_end: bool = true
## When true, the exit is placed at a corridor dead-end. Same intent
## as `entrance_at_dead_end`.
@export var exit_at_dead_end: bool = true

@export_group("Level Generation — Maze")
## Growing-Tree algorithm bias. 0.0 = always pick the most-recently-
## added frontier cell (long winding corridors, few branches —
## "labyrinth"). 1.0 = always pick a random frontier cell (lots of
## short branches — "bushy" cave). 0.3–0.5 is a good mix.
@export_range(0.0, 1.0) var maze_bias: float = 0.4
## How willing corridors are to bend. 0.0 = corridors prefer to keep
## going straight whenever possible. 1.0 = corridors bend at every
## opportunity. Higher = more disorienting, more dead-ends.
@export_range(0.0, 1.0) var wiggle: float = 1.0

@export_group("Level Generation — Corridor Width")
## Minimum corridor width in cells. 1 = classic single-tile corridor.
## 2+ = wider passages that feel open. Must be ≤ `corridor_max_width`.
@export var corridor_min_width: int = 1
## Maximum corridor width in cells. Must be ≥ `corridor_min_width`.
## Set both to the same value for fixed-width corridors throughout.
@export var corridor_max_width: int = 1
## Probability per step that corridor width re-rolls within
## [min, max]. 0 = width fixed once per corridor; 1 = width changes
## almost every step (chaotic). Only meaningful when min < max.
@export_range(0.0, 1.0) var width_change_chance: float = 0.15

@export_group("Level Generation — Rooms")
## How many rectangular rooms to attempt to punch into the maze.
## Actual count may be lower if overlap rejection fails. 0 = pure maze.
@export var room_count: int = 6
## Minimum side length of a room (in cells). Must be ≤ room_max_size.
@export var room_min_size: int = 3
## Maximum side length of a room. Rooms larger than the grid will be
## clamped during placement.
@export var room_max_size: int = 5

@export_group("Level Generation — Items")
## Floor loot pool. Each entry pairs an `ItemData` with a weight,
## placement flags (Corridor / Room / Dead End), and spacing rules.
@export var floor_loot: Array[LootEntry] = []
## Minimum number of floor items to place per level. Drawn from
## `floor_loot`. Set both min and max to 0 to disable floor loot.
@export var floor_items_min: int = 3
## Maximum number of floor items to place per level. Must be ≥
## floor_items_min.
@export var floor_items_max: int = 8

@export_group("Level Generation — Objects")
## Each ObjectSpawn entry has its own count_min/count_max so a biome
## can specify e.g. "1–3 wooden chests AND 0–1 iron chests". Placement
## (room / corridor / dead-end) is per-entry too.
@export var objects: Array[ObjectSpawn] = []
## Lever ↔ door pairs. Placed AFTER `objects` so chests and decorative
## doors are already in. Each entry produces count_min..count_max
## clusters; every lever is guaranteed reachable from the entrance
## even when its linked door is closed.
@export var linked_objects: Array[LinkedObjectSpawn] = []
## Key ↔ locked-door pairs. Placed AFTER linked objects. Each entry
## produces count_min..count_max pairs; the key is guaranteed
## reachable from the entrance WITHOUT crossing its own door first.
## Chain reachability tracks key collection so levers / keys / chests
## / exits behind locked doors are reachable in a sequential order
## the player can actually walk.
@export var key_door_spawns: Array[KeyDoorSpawn] = []

## Spike traps. Placed AFTER doors / linked objects / key doors but
## BEFORE items + decorations, so trap cells are excluded from item
## placement (the player can't pile loot onto a trap that would damage
## them on pickup approach) and traps never share a tile with chests /
## levers. Each entry can drive scattered + corridor-cluster +
## room-density placement.
@export var trap_spawns: Array[TrapSpawn] = []

## Projectile traps — wall-mounted launchers that fire across cells.
## Placed AFTER spike traps and BEFORE wall decorations so the shared
## wall-face registry prevents decorations from claiming a launcher's
## wall face. Separate system from `trap_spawns`: projectile traps
## live on wall faces, not floor cells.
@export var projectile_trap_spawns: Array[ProjectileTrapSpawn] = []

## Spinners — floor tiles that rotate the player a fixed number of
## 90° turns in a fixed direction when stepped on, disorienting them.
## Placed AFTER projectile traps (so plate cells are known and
## excluded) and BEFORE wall decorations. Each entry supports
## scattered + corridor-cluster + room-density placement the same way
## `trap_spawns` does.
@export var spinner_spawns: Array[SpinnerSpawn] = []

## Wall-mounted decorations (paintings, torches, lanterns). Placed
## LAST among scenery — they don't gate or interact with anything,
## they just dress wall faces. Each entry attaches its decoration to
## wall faces of cells matching `placement` flags. Banned in outdoor
## biomes (no wall geometry to attach to).
@export var wall_decorations: Array[WallDecorationSpawn] = []

## Secret walls — edge-based "fake walls" between two 1-wide-corridor
## floor cells. The renderer draws a normal-looking wall quad on the
## edge from both sides; the movement system never blocks the player
## (the cells underneath stay normal floor). The map shows the line
## at reduced opacity so observant players can spot it. Placed AFTER
## items so the LOOT_ONLY gate mode can validate that the wall
## actually hides a chest or floor item. Banned in outdoor biomes.
@export var secret_wall_spawns: Array[SecretWallSpawn] = []

## Teleporter config for this biome (SINGULAR — not an array — one
## teleporter style per biome). `island_count_max <= 1` = Phase A
## "shortcut" mode that places `count_min..count_max` random warp
## pairs. `island_count_max >= 2` = Phase C "island topology" mode
## that seals K-1 corridor cells and places K-1 warp pairs as a
## spanning tree connecting the resulting islands. Leave null to
## disable teleporters for the biome entirely.
@export var teleporter_spawn: TeleporterSpawn

@export_group("Sound")
## One sound is picked at random per step (forward / back / strafe).
## Empty array = silent footsteps. Per-biome so forest leaves and
## dungeon stone don't sound identical.
@export var move_sounds: Array[AudioStream] = []
# Reserved for Phase 19 — biome ambient / music loops will land here.
# @export var ambient_loop: AudioStream
