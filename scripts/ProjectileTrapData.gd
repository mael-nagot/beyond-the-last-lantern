class_name ProjectileTrapData
extends Resource

# Template for a wall-mounted projectile trap. Phase 8 Task 3 follow-up.
#
# Wall-mounted launchers fire a projectile in a fixed direction
# (perpendicular to the wall face) that travels cell-by-cell until
# hitting a wall. Two trigger modes:
#   - TIMED: fires periodically on an interval
#   - PRESSURE_PLATE: fires when the player steps on a linked floor
#     plate (separate cell from the launcher)
#
# The launcher texture renders on the wall face (like a wall decoration)
# and the projectile is a Sprite3D billboard that moves through the
# dungeon — our first moving non-player entity.
#
# Distinct from TrapData because these traps are wall-mounted (not
# cell-bound), carry a projectile flight phase, and use a different
# placement model (corridor extremity / room wall face).

enum Trigger {
	# Fires at regular intervals regardless of player position.
	# `timed_interval` controls seconds between shots.
	TIMED,
	# Fires when the player steps on a linked floor plate. The plate
	# is placed separately (same corridor or room). Won't re-fire
	# while a projectile is still in flight.
	PRESSURE_PLATE,
}

enum StatusEffect {
	NONE,
	POISON,
	BURN,
	SLOW,
}

@export var name_key: String = ""
@export_multiline var description_key: String = ""

@export_group("Trigger")
@export var trigger: Trigger = Trigger.TIMED

@export_group("Damage")
@export var damage: int = 5
# Status effect applied on hit. The field exists from day one but
# actual application is deferred until Character gets a status system
# (Phase 10 combat will also need it).
@export var status_effect: StatusEffect = StatusEffect.NONE
@export var status_duration: float = 0.0
@export var status_damage_per_tick: float = 0.0

@export_group("Projectile")
@export var projectile_sprite: Texture2D
# Travel speed in cells per second. At 60 fps and 5 cells/sec the
# projectile moves ~0.08 cells per frame — no risk of skipping a cell.
# Values above ~20 at 30 fps would need the frame-skip tracking in
# Projectile.cells_entered_this_tick().
@export var projectile_speed: float = 5.0
@export var projectile_world_height: float = 0.8
@export var projectile_y_offset: float = 0.0

@export_group("Launcher Art")
# Wall-mounted launcher texture. Rendered on the wall face like a
# wall decoration, centered with configurable offset.
@export var launcher_sprite: Texture2D
@export var launcher_world_height: float = 1.5
# Horizontal offset on the wall face. 0 = centered. Positive shifts
# right when facing the wall.
@export var launcher_x_offset: float = 0.0
# Vertical offset from wall midheight. 0 = centered. Positive = up.
@export var launcher_y_offset: float = 0.0
# Depth offset from the wall surface (prevents Z-fighting).
@export var launcher_depth_offset: float = 0.02

@export_group("Pressure Plate Art")
# Floor plate texture. Rendered as a flat decal on the floor (like
# spike trap hole decals). Only used for PRESSURE_PLATE trigger.
@export var plate_sprite: Texture2D
@export var plate_world_size: float = 0.8

@export_group("Timing — TIMED")
# Seconds between shots. The countdown starts after the previous
# projectile hits a wall (or from level start for the first shot).
@export var timed_interval: float = 3.0
# Phase shift (seconds added to the timer at spawn) so multiple TIMED
# traps in the same corridor don't fire in lockstep. The placer may
# add a pseudo-random offset on top.
@export var timed_initial_offset: float = 0.0

@export_group("Timing — General")
# Brief delay after a projectile hits a wall before the trap re-arms.
# For TIMED, the interval timer starts AFTER this cooldown. For
# PRESSURE_PLATE, the plate can't be re-triggered during this window.
# 0 = immediate re-arm.
@export var cooldown_after_impact: float = 0.0

@export_group("Audio")
@export var launch_sound: AudioStream
@export var impact_sound: AudioStream
# Played when the player steps on the pressure plate. Only used for
# PRESSURE_PLATE trigger.
@export var plate_sound: AudioStream
# Max hearing distance in world units (tiles × CELL_SIZE). Used to
# gate TIMED trap launch/impact audio — outside this range the sounds
# are silent. PRESSURE_PLATE traps always play at full volume since
# the player is right at the plate.
@export var hearing_distance: float = 12.0


func get_display_name() -> String:
	return tr(name_key)

func get_display_description() -> String:
	return tr(description_key)

func is_timed() -> bool:
	return trigger == Trigger.TIMED

func is_pressure_plate() -> bool:
	return trigger == Trigger.PRESSURE_PLATE
