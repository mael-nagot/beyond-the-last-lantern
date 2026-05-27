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

## Translation key for the object's display name (e.g.
## "object.chest_wooden.name"). Use `get_display_name()` to fetch
## the translated text.
@export var name_key: String = ""
## Translation key for the object's description tooltip. Use
## `get_display_description()` to fetch the translated text.
@export_multiline var description_key: String = ""
## Category — drives generator placement rules (chests need rooms,
## doors live on edges, etc.) and click-handling in Game.gd.
@export var category: Category = Category.CHEST

@export_group("Placement")
## When true, the object's cell is impassable until the object is
## "open". Chests block until looted (toggle), doors block until
## open, decorative props always block. False = walkable through
## (most levers, campfires, decals).
@export var blocks_movement: bool = true
## DOOR ONLY. When true, the door is rendered as a regular wall (using
## the biome's wall texture) while closed and as a complete void while
## open — a true secret passage. The closed_sprite / opened_sprite
## fields are ignored for the dungeon render path; the renderer
## samples the biome's wall_textures pool instead so the panel is
## pixel-indistinguishable from any other corridor wall. On the map
## the door draws as a wall line when closed and as nothing at all
## when open. Click-to-interact on the panel itself is disabled —
## only a paired WallSwitchInstance can toggle the door. Decorative
## doors and key/lever-locked doors leave this false. Reusable: any
## future hidden door variant (quest-gated, trade-cost-gated, …)
## flips this flag the same way.
@export var appears_as_wall: bool = false
## WALL-SWITCH ONLY (and only meaningful when the switch is mounted
## ON the linked door's panel itself — distance 0 placement; the
## flag is silently ignored for off-door switches because there's no
## visual problem to fix when a wall-mounted switch activates a real
## wall's worth of geometry). When true, after a linked door has been
## opened the switch — sprite, click area, and map dash — vanishes
## entirely. With no other way to re-close the door, this turns the
## puzzle into a permanent one-time use. Default false preserves the
## toggle behaviour (click again to close the door). Switches on
## off-door walls (distance > 0) ignore this flag — the wall they
## attach to keeps existing whether the door is open or closed, so
## there's no need to hide them.
@export var hide_when_active: bool = false

@export_group("Art")
## Sprite shown when `opened = false` (the default state — closed
## chest, closed door, un-pulled lever).
@export var closed_sprite: Texture2D
## Sprite shown when `opened = true` (looted chest, open door,
## pulled lever). Can be the same texture as `closed_sprite` for
## objects with no visual state change.
@export var opened_sprite: Texture2D
## Real-world height of the sprite, in metres. The renderer derives
## `pixel_size = world_height / texture_height` so a 64×64 PNG and
## a 128×128 PNG render at the same physical size.
@export var world_height: float = 1.0
## Forces the sprite to render at this exact world width regardless
## of texture aspect ratio. 0.0 = keep the texture's aspect (right
## for chests and small props). >0 stretches horizontally — used by
## doors so a square wall texture renders at the corridor's
## CELL_SIZE width.
@export var world_width: float = 0.0
## Vertical offset from the floor. 0 = bottom of the sprite sits at
## floor level. Positive raises it (floating prop, hanging lantern).
@export var y_offset: float = 0.0
## Shifts the sprite off the cell centre, toward whichever cardinal
## side the player is currently on. 0.0 = always centred (right for
## small decorations). For a chest, ~1.0–1.5 makes it sit close to
## the player's side of the tile so it reads as a solid object rather
## than a distant pixel cluster. The sprite snaps to the new offset
## whenever the player turns; with the player on the same axis there's
## no visible motion. Doors NEVER lean — leave at 0 for them.
@export var lean_toward_player: float = 0.0

@export_group("Interaction")
## When true (default): clicking the object toggles its state (chest
## opens, door swings, lever pulls). When false: the click still
## registers but the object plays `locked_sound` and the HUD shows a
## toast built from `locked_message_key` instead of changing state —
## used for doors that need a lever / key to actually open. The
## Area3D is created either way, so the player gets feedback rather
## than a silent dead click.
@export var interactable: bool = true
## Seconds to hold between flipping the object to its "opened" state
## (sprite swap + `interact_sound`) and showing any follow-up popup.
## Only chests use this today: it delays the loot popup so the open
## sprite and the open sound register before the modal covers the
## view — reads as "I opened the chest, *then* here's the loot"
## rather than the popup appearing instantly. 0.0 = no delay (popup
## opens immediately); ~0.3–0.5 is a good feel. Re-clicking an
## already-open chest skips the delay entirely.
@export var popup_delay: float = 0.0

@export_group("Sound")
## Played on a successful interaction (chest opens, door swings,
## lever pulls). Null = silent.
@export var interact_sound: AudioStream
## Played when the click is REJECTED because `interactable = false`
## — the locked-door thunk / key-rattle. Null = silent.
@export var locked_sound: AudioStream
## Translation key for the toast shown when a click is rejected
## (`interactable = false`). Empty = no toast.
@export var locked_message_key: String = ""
## Shown instead of `locked_message_key` when the player clicks a
## closed AND-logic lever-locked door with some (but not all) linked
## levers already pulled. Falls back to `locked_message_key` when
## empty.
@export var partial_locked_message_key: String = ""

# Loot is configured per-placement on `ObjectSpawn.loot_table` (in the
# biome) — see scripts/LootTable.gd. That keeps the chest's visual
# template (this resource) reusable across many different loot
# configurations.

func get_display_name() -> String:
	return tr(name_key)

func get_display_description() -> String:
	return tr(description_key)
