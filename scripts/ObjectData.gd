class_name ObjectData
extends Resource

# Template for an interactable dungeon object (chests, doors, levers,
# traps, campfires, decorations). One .tres per object type lives in
# res://assets/objects/. Phase 8 Task 1 only uses CHEST.

enum Category {
	CHEST,
	DOOR,
	LEVER,
	TRAP,
	CAMPFIRE,
	DECORATION,
}

@export var name_key: String = ""        # translation key
@export_multiline var description_key: String = ""
@export var category: Category = Category.CHEST

@export_group("Placement")
@export var blocks_movement: bool = true

@export_group("Art")
@export var closed_sprite: Texture2D
@export var opened_sprite: Texture2D
@export var world_height: float = 1.0
# Forces the sprite to render at this exact world width regardless of
# texture aspect ratio. 0.0 = keep the texture's aspect (right for
# chests and small props). > 0 stretches horizontally — used by doors
# so a square wall texture renders at the corridor's CELL_SIZE width.
@export var world_width: float = 0.0
@export var y_offset: float = 0.0
# Shifts the sprite off the cell centre, toward whichever cardinal side
# the player is currently on. 0.0 = always centred (right for small
# decorations). For a chest, ~1.0–1.5 makes it sit close to the player's
# side of the tile so it reads as a solid object rather than a distant
# pixel cluster. The sprite snaps to the new offset whenever the player
# moves; with the player on the same axis there's no visible motion.
# Doors NEVER lean — leave at 0 for them.
@export var lean_toward_player: float = 0.0

@export_group("Interaction")
# When true (default): clicking the object toggles its state (chest
# opens, door swings, lever pulls). When false: the click still
# registers but the object plays `locked_sound` and the HUD shows a
# toast built from `locked_message_key` instead of changing state —
# used for doors that need a lever / key to actually open. The Area3D
# is created either way, so the player gets feedback rather than a
# silent dead click.
@export var interactable: bool = true

@export_group("Sound")
# Played on a successful interaction (chest opens, door swings, lever
# pulls).
@export var interact_sound: AudioStream
# Played when the click is REJECTED because `interactable = false` —
# the locked-door thunk / key-rattle. If null, no sound plays.
@export var locked_sound: AudioStream
# Translation key for the toast shown when a click is rejected
# (`interactable = false`). Empty = no toast.
@export var locked_message_key: String = ""

# Loot is configured per-placement on `ObjectSpawn.loot_table` (in the
# biome) — see scripts/LootTable.gd. That keeps the chest's visual
# template (this resource) reusable across many different loot
# configurations.

func get_display_name() -> String:
	return tr(name_key)

func get_display_description() -> String:
	return tr(description_key)
