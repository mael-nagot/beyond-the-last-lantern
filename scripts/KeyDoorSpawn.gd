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
#
# Two pairs from the same spawn share `lock_id_prefix` but get
# distinct generated suffixes by default (one key per door). To
# share ONE key across multiple doors of this spawn, leave the
# prefix set and set `share_lock_id` true (currently reserved — not
# wired in 2c v1).

# -----------------------------------------------------------------
# Key spawn-location flags. Multiple = pick one per key, fall back.
# -----------------------------------------------------------------
const KEY_LOCATION_FLOOR := 1
const KEY_LOCATION_CHEST := 2
const KEY_LOCATION_ENEMY_DROP := 4
const KEY_LOCATION_DEFAULT := KEY_LOCATION_FLOOR

@export var door_object: ObjectData
@export var key_item: ItemData

@export var count_min: int = 1
@export var count_max: int = 1

# Designer-friendly id prefix. Empty = auto-generated per spawn.
# When set, generated lock_ids look like "<prefix>_0", "<prefix>_1",
# … — useful for grouping related locks ("copper_0", "copper_1") and
# (later) sharing a single key across siblings.
@export var lock_id_prefix: String = ""

# 2c default true: a lock that gates nothing is pointless. The
# placement enforces "closing this door alone cuts off at least one
# chest / lever / key / exit cell" when this is on.
@export var door_must_gate_content: bool = true

@export_group("Key spawn location")
@export_flags("Floor", "Chest", "Enemy Drop") var key_spawn_locations: int = KEY_LOCATION_DEFAULT
# Weighted ordering for the per-pair location lottery. When multiple
# flags are enabled, the placement picks an ordering by weighted
# random — the first pick is "primary" (tried first), the rest are
# fallbacks in case the primary has no eligible candidate. Higher
# weight = more likely to be picked first. Setting a weight to 0
# disables that location even if its flag is on. Defaults make all
# enabled locations equally likely (the original behaviour).
@export var floor_weight: int = 1
@export var chest_weight: int = 1
@export var enemy_drop_weight: int = 1
# When true, a single chest may host multiple keys (from this spawn
# OR earlier ones). When false (the default), a chest already
# holding ANY key is skipped and the placement falls through to the
# next candidate chest — prevents the "two keys in one chest" feel
# that makes one chest unusually rich and dilutes the puzzle.
@export var allow_multiple_keys_per_chest: bool = false

@export_group("Floor placement (when KEY_LOCATION_FLOOR is enabled)")
# Where the key can land when spawned on the floor — chest-style
# flags. Mirror of LeverPlacement.
@export_flags("Corridor", "Room", "Dead End") var key_floor_placement: int = ObjectSpawn.PLACEMENT_DEFAULT

@export_group("Anti-clustering (Manhattan tiles vs. ANY existing object)")
@export var key_min_distance_to_other_object: int = 0
@export var door_min_distance_to_other_object: int = 0

@export_group("Key ↔ door spread (HARD bounds, no graceful degrade)")
# Manhattan distance from the key to its OWN paired door. Same shape
# as LinkedObjectSpawn's lever_to_door range — small means the key
# is found nearby ("here's the door, here's the key"), large means
# the key is hidden far away (real exploration). max_distance = -1
# means unlimited.
@export var key_to_door_min_distance: int = 0
@export var key_to_door_max_distance: int = -1

# Returns true iff this spawn allows the key to land in `location_bit`.
func allows_location(location_bit: int) -> bool:
	return (key_spawn_locations & location_bit) != 0
