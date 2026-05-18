class_name TrapData
extends Resource

# Template for a trap placed on a dungeon floor cell. Phase 8 Task 3.
# One .tres per trap variant lives in res://assets/objects/. Different
# variants (step-trigger spike, timed spike, fireball, etc.) share this
# resource type but configure damage / timing / sprites independently.
#
# Traps are PASSIVE hazards — they don't extend ObjectData because they
# never gate placement, never get clicked, and have no opened/closed
# inventory state. They live on `GridCell.trap` (separate slot from
# `GridCell.object`) and render through DungeonView's traps path: a flat
# floor decal for the holes (always visible) + per-spike vertical
# billboards (visible only when extended).

enum Trigger {
	# Spikes pop up when the player steps onto the cell, deal damage
	# once, stay up for `step_activation_duration`, then retract and
	# enter a `step_cooldown_duration` lockout before they can fire
	# again. Player can stand on the cell during cooldown without
	# taking damage.
	STEP,
	# Spikes cycle independently of the player. RETRACTED for
	# `timed_down_duration`, then EXTENDED for `timed_up_duration`,
	# repeating forever. Damage applies on the RETRACTED→EXTENDED
	# transition iff the player is standing on the cell at that moment.
	TIMED,
}

## Translation key for the trap's display name. Use
## `get_display_name()` to fetch the translated text.
@export var name_key: String = ""
## Translation key for the trap's description tooltip.
@export_multiline var description_key: String = ""

@export_group("Trigger")
## What activates the trap. STEP = fires when the player steps onto
## the cell, has a cooldown. TIMED = cycles on its own clock, damages
## the player if they're on the cell when spikes extend.
@export var trigger: Trigger = Trigger.STEP

@export_group("Damage")
## Applied to all 3 party members when the trap fires. <= 0 treated
## as no damage (useful for harmless prop / decorative traps).
@export var damage: int = 5

@export_group("Timing — STEP")
## How long spikes stay extended after a step trigger, in seconds.
@export var step_activation_duration: float = 0.5
## Lockout period after spikes retract, in seconds. The trap won't
## re-trigger even if the player steps off and back on during this
## window. 0 = no cooldown (re-triggers every entry).
@export var step_cooldown_duration: float = 1.5

@export_group("Timing — TIMED")
## How long spikes stay extended each cycle, in seconds.
@export var timed_up_duration: float = 1.0
## How long spikes stay retracted each cycle, in seconds. Total
## cycle = up + down.
@export var timed_down_duration: float = 2.0
## Per-instance phase shift (seconds added to the timer at spawn)
## so multiple traps don't activate in lockstep. The placer applies
## a pseudo-random offset within [0, timed_up + timed_down) on top
## of this base value, so most variants can leave this at 0.
@export var timed_initial_offset: float = 0.0

@export_group("Art")
## Single hole sprite — top-down view, transparent background.
## Rendered as a FLAT MeshInstance3D quad on the floor. Drawn
## once per grid cell in the trap's grid_cols × grid_rows pattern.
@export var holes_sprite: Texture2D
## Single spike sprite — side view, transparent background.
## Rendered as a vertical Sprite3D BILLBOARD_FIXED_Y, anchored
## bottom-on-floor. Visible only when the trap is EXTENDED.
@export var extended_sprite: Texture2D
## Per-spike height in world units. Default 1.2 keeps the spike
## visually substantial against the default 1.0-unit hole; smaller
## values feel like floor pricks, larger values like room-filling
## skewers. The renderer derives `pixel_size = world_height /
## texture_height`, so a 64×128 spike texture at world_height=1.2
## renders as ~0.6 wide × 1.2 tall — base ~half the hole width.
@export var world_height: float = 1.2
## Per-spike base width in world units. 0 = preserve the texture's
## natural aspect (width = texture_width × pixel_size). Set to a
## specific value (e.g. equal to `hole_world_size`) to force the
## spike base to match the hole opening regardless of how the
## artist proportioned the source PNG. Implemented via
## `Sprite3D.scale.x` so the sprite stretches horizontally without
## affecting its vertical pixel scaling.
@export var spike_world_width: float = 0.0
## Cell-relative size of each individual hole (world units).
## 1.0 = a hole fills the slot it's drawn in (cell divided into
## grid_cols × grid_rows). 0 = derive from the texture's natural
## pixel size.
@export var hole_world_size: float = 1.0
## Vertical offset for the spikes' bottom anchor, in case the
## artist left transparent padding at the bottom of
## `extended_sprite`.
@export var y_offset: float = 0.0
## Cell-relative shift applied to the SPIKE subtree (only — the
## floor holes stay anchored to the cell centre) toward whichever
## cardinal side the player is currently on. Mirrors
## `ObjectData.lean_toward_player` but only nudges the vertical
## sprites, so the spikes feel like they protrude near the player
## while the holes remain a cell-wide permanent feature.
## 0.0 = no lean (spikes centred over their holes).
## ~0.5–1.0 = noticeable forward push when viewing the trap from
## an adjacent cell. Refreshed only on player turn — refreshing on
## move would visibly snap the spikes mid-step.
@export var spike_lean_toward_player: float = 0.0

@export_group("Layout — Per Cell")
## Number of spike+hole columns distributed across one grid cell.
## Total per cell = grid_cols × grid_rows. (1, 1) = single spike;
## (2, 2) = 4 spikes; (3, 3) = 9 spikes packed.
@export var grid_cols: int = 2
## Number of spike+hole rows distributed across one grid cell.
## See `grid_cols`.
@export var grid_rows: int = 2
## Inset of the spike+hole grid from the cell edges, as a fraction.
## 0.0 = grid touches the cell edges; 0.5 = bunched at centre.
## Default 0.3 keeps spikes well inside the tile so the player can
## clearly read the cell boundary.
@export_range(0.0, 0.5) var grid_inset: float = 0.3

@export_group("Audio")
## Played on RETRACTED → EXTENDED transition (spikes pop up).
@export var activate_sound: AudioStream
## Played on EXTENDED → RETRACTED transition (spikes go down).
@export var deactivate_sound: AudioStream
## Hearing-distance gate (world units, ≈ Manhattan tiles ×
## CELL_SIZE) for the trap's audio. Beyond this distance the sound
## is silent. Only meaningful for TIMED traps — STEP traps fire
## right at the player's feet, so they play through SoundManager's
## non-spatial pool at full volume.
@export var hearing_distance: float = 8.0

func get_display_name() -> String:
	return tr(name_key)

func get_display_description() -> String:
	return tr(description_key)

func is_step() -> bool:
	return trigger == Trigger.STEP

func is_timed() -> bool:
	return trigger == Trigger.TIMED
