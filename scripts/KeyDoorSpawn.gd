class_name KeyDoorSpawn
extends Resource

# A biome-level entry that spawns a key-locked DOOR + a matching KEY
# item as a coherent puzzle unit. Lives in BiomeData.key_door_spawns.
#
# For each pair, LevelGenerator:
#   1. Picks a 1-wide-corridor edge for the door (same eligibility as
#      decorative / lever-locked doors). The door starts CLOSED with
#      a generated lock_id ("<prefix>_<index>") that only the placed
#      key can open.
#   2. Picks a spawn location for the key according to
#      `key_spawn_locations` flags — Floor, inside an existing Chest,
#      or as an Enemy Drop (reserved for Phase 10). Multiple flags =
#      placement picks one at random per key, with fallback to the
#      others if the first choice can't fit.
#   3. Validates with chain reachability v2: the key must be
#      reachable WITHOUT having to cross this lock first, and after
#      the player picks it up, the rest of the world (chests, levers,
#      keys, exit) must remain reachable.

# -----------------------------------------------------------------
# Key spawn-location flags. Multiple = pick one per key, fall back.
# -----------------------------------------------------------------
const KEY_LOCATION_FLOOR := 1
const KEY_LOCATION_CHEST := 2
const KEY_LOCATION_ENEMY_DROP := 4
const KEY_LOCATION_DEFAULT := KEY_LOCATION_FLOOR

## The door .tres to place. Should be an ObjectData of category DOOR
## with `blocks_movement = true` and `interactable = false` (the
## key-locked branch handles unlocking instead of the toggle path).
@export var door_object: ObjectData
## The key .tres to place. Should be an ItemData of category KEY.
## A per-pair lock_id is auto-assigned at placement time, so the
## same key resource can be reused across many spawns.
@export var key_item: ItemData

## Minimum number of key↔door pairs to place from this spawn entry.
@export var count_min: int = 1
## Maximum number of pairs. Placement attempts up to this many; if
## the level geometry can't accommodate them all (chain reachability
## fails), the actual count may be lower.
@export var count_max: int = 1

## Designer-friendly id prefix. Empty = auto-generated per spawn.
## When set, generated lock_ids look like "<prefix>_0", "<prefix>_1",
## … — useful for grouping related locks ("copper_0", "copper_1") and
## (later) sharing a single key across siblings.
@export var lock_id_prefix: String = ""

## When true, placement enforces that closing this door alone cuts
## off at least one chest / lever / key / exit cell — making the lock
## meaningful. Default true: a lock that gates nothing is pointless.
@export var door_must_gate_content: bool = true

@export_group("Key spawn location")
## Where the key may spawn: Floor (loose item on the ground), Chest
## (appended to an existing chest's loot), Enemy Drop (Phase 10, not
## yet wired). Tick multiple to let the per-pair lottery decide.
@export_flags("Floor", "Chest", "Enemy Drop") var key_spawn_locations: int = KEY_LOCATION_DEFAULT
## Weight for the Floor option in the per-pair location lottery.
## Higher = more likely to be tried first. 0 disables Floor even if
## its flag is on. Defaults make all enabled locations equally
## likely (the original behaviour).
@export var floor_weight: int = 1
## Weight for the Chest option in the per-pair location lottery.
## See `floor_weight`.
@export var chest_weight: int = 1
## Weight for the Enemy Drop option in the per-pair location lottery.
## See `floor_weight`. (Enemy Drop currently warns and falls through
## — wired in Phase 10.)
@export var enemy_drop_weight: int = 1
## When true, a single chest may host multiple keys (from this spawn
## OR earlier ones). When false (the default), a chest already
## holding ANY key is skipped and the placement falls through to the
## next candidate chest — prevents the "two keys in one chest" feel
## that makes one chest unusually rich and dilutes the puzzle.
@export var allow_multiple_keys_per_chest: bool = false

@export_group("Floor placement (when KEY_LOCATION_FLOOR is enabled)")
## Which cell classifications the key may land on when spawned on
## the floor. Mirrors `ObjectSpawn.placement` flags.
@export_flags("Corridor", "Room", "Dead End") var key_floor_placement: int = ObjectSpawn.PLACEMENT_DEFAULT

@export_group("Anti-clustering (Manhattan tiles vs. ANY existing object)")
## Minimum Manhattan distance from this key to any already-placed
## object (chest / lever / door endpoint / trap / spinner / item).
## Graceful degrade — relaxes by 1 down to 0 if the constraint can't
## be satisfied. 0 = no spacing rule.
@export var key_min_distance_to_other_object: int = 0
## Minimum Manhattan distance from this door's endpoints to any
## already-placed object. Same graceful-degrade behaviour as
## `key_min_distance_to_other_object`.
@export var door_min_distance_to_other_object: int = 0

@export_group("Key ↔ door spread (HARD bounds, no graceful degrade)")
## Manhattan distance from the key to its OWN paired door. Same shape
## as LinkedObjectSpawn's lever_to_door range — small means the key
## is found nearby ("here's the door, here's the key"), large means
## the key is hidden far away (real exploration). max_distance = -1
## means unlimited.
@export var key_to_door_min_distance: int = 0
## Maximum Manhattan distance from the key to its paired door. -1 =
## unlimited (anywhere in the level). See `key_to_door_min_distance`.
@export var key_to_door_max_distance: int = -1

# Returns true iff this spawn allows the key to land in `location_bit`.
func allows_location(location_bit: int) -> bool:
	return (key_spawn_locations & location_bit) != 0
