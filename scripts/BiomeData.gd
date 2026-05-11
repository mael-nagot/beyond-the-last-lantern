class_name BiomeData
extends Resource

@export var biome_name: String = "Forest"

# Each entry pairs an albedo + normal so the two can never be picked
# independently (the previous flat-array setup could land
# wall_bark_01_albedo with wall_bark_02_normal). Each entry also carries
# placement flags (Corridor / Room / Dead End) so designers can author
# location-specific art — mossy dead-end walls, vaulted room ceilings,
# worn corridor floors. Empty match = fall back to the full pool.
@export_group("Wall Textures")
@export var wall_textures: Array[BiomeTextureEntry] = []

@export_group("Floor Textures")
@export var floor_textures: Array[BiomeTextureEntry] = []

@export_group("Ceiling Textures")
@export var ceiling_textures: Array[BiomeTextureEntry] = []

@export_group("Appearance")
@export var wall_height:    float = 6.3
@export var show_ceiling:   bool  = true
@export var fog_enabled:    bool  = true
@export var fog_color:      Color = Color(0.05, 0.10, 0.03)
@export var fog_density:    float = 0.04
@export var fog_aerial:     float = 0.1
@export var ambient_color:  Color = Color(0.6, 0.55, 0.4)
@export var ambient_energy: float = 1.2

@export_group("Texture Mapping")
@export var use_triplanar: bool = false
@export var triplanar_sharpness: float = 0.5
@export var triplanar_y_offset: float = 0.5

@export_group("Level Generation — Grid")
@export var grid_width: int = 31
@export var grid_height: int = 31

@export_group("Level Generation — Entrance / Exit")
@export var min_exit_distance: int = 10
@export var entrance_at_dead_end: bool = true
@export var exit_at_dead_end: bool = true

@export_group("Level Generation — Maze")
@export_range(0.0, 1.0) var maze_bias: float = 0.4
@export_range(0.0, 1.0) var wiggle: float = 1.0

@export_group("Level Generation — Corridor Width")
@export var corridor_min_width: int = 1
@export var corridor_max_width: int = 1
@export_range(0.0, 1.0) var width_change_chance: float = 0.15

@export_group("Level Generation — Rooms")
@export var room_count: int = 6
@export var room_min_size: int = 3
@export var room_max_size: int = 5

@export_group("Level Generation — Items")
@export var floor_loot: Array[LootEntry] = []
@export var floor_items_min: int = 3
@export var floor_items_max: int = 8

@export_group("Level Generation — Objects")
# Each ObjectSpawn entry has its own count_min/count_max so a biome can
# specify e.g. "1-3 wooden chests AND 0-1 iron chests". Placement (room
# / corridor / dead-end) is per-entry too.
@export var objects: Array[ObjectSpawn] = []
# Lever ↔ door pairs. Placed AFTER `objects` so chests and decorative
# doors are already in. Each entry produces count_min..count_max
# pairs; the lever is guaranteed reachable from the entrance even
# when its linked door is closed.
@export var linked_objects: Array[LinkedObjectSpawn] = []
# Key ↔ locked-door pairs (Phase 8 Task 2c). Placed AFTER linked
# objects. Each entry produces count_min..count_max pairs; the key
# is guaranteed reachable from the entrance WITHOUT crossing its own
# door first. Chain reachability v2 also tracks key collection so
# levers / keys / chests / exits behind locked doors are reachable
# in a sequential order the player can actually walk.
@export var key_door_spawns: Array[KeyDoorSpawn] = []

# Traps (Phase 8 Task 3 — Subtask A). Placed AFTER doors / linked
# objects / key doors but BEFORE items + decorations, so trap cells
# are excluded from item placement (the player can't pile loot onto
# a trap that would damage them on pickup approach) and traps never
# share a tile with chests / levers. Each entry produces
# count_min..count_max single-cell trap placements.
@export var trap_spawns: Array[TrapSpawn] = []

# Projectile traps (Phase 8 Task 3 — Subtask C). Wall-mounted
# launchers that fire across cells. Placed AFTER spike traps and
# BEFORE wall decorations so the shared `_wall_faces_used` registry
# blocks decorations from claiming a launcher's wall face. Separate
# system from `trap_spawns` — projectile traps live on wall faces,
# not floor cells.
@export var projectile_trap_spawns: Array[ProjectileTrapSpawn] = []

# Spinners (Phase 8 Task 8). Floor tiles that rotate the player a
# fixed number of 90° turns in a fixed direction when stepped on,
# disorienting them. Placed AFTER projectile traps (so plate cells
# are known and excluded) and BEFORE wall decorations. Each entry
# can drive scattered + corridor-cluster + room-density placement
# the same way `trap_spawns` does.
@export var spinner_spawns: Array[SpinnerSpawn] = []

# Wall-mounted decorations (paintings, torches, lanterns). Placed
# LAST among scenery — they don't gate or interact with anything,
# they just dress wall faces. Each entry attaches its decoration to
# wall faces of cells matching `placement` flags.
@export var wall_decorations: Array[WallDecorationSpawn] = []

# Secret walls — edge-based "fake walls" between two 1-wide corridor
# floor cells. The renderer draws a normal-looking wall quad on the
# edge from both sides; the movement system never blocks the player
# (the cells underneath stay normal floor). On the map the edge is
# annotated with an "S" so the player gets a hint. Placed AFTER
# items so the LOOT_ONLY gate mode can validate that the wall
# actually hides a chest or floor item.
@export var secret_wall_spawns: Array[SecretWallSpawn] = []

@export_group("Sound")
# One sound is picked at random per step (forward/back/strafe). Empty
# array = silent. Per-biome so forest leaves and dungeon stone differ.
@export var move_sounds: Array[AudioStream] = []
# Reserved for Phase 19 — biome ambient / music loops will land here.
# @export var ambient_loop: AudioStream
