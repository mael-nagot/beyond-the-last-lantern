class_name ProjectileTrapData
extends Resource

# Template for a wall-mounted launcher that fires projectiles across the
# dungeon. Phase 8 Task 3 — Subtask C.
#
# This is a SEPARATE system from `TrapData` (spike traps). Reasons:
#   - Projectile traps are wall-mounted (not cell-bound) — they live on
#     a wall FACE like wall decorations, sharing the
#     `LevelGenerator._wall_faces_used` registry so a face never holds
#     both a launcher and a decoration.
#   - They have a flight phase — a projectile travels axis-aligned
#     across cells until it hits a wall.
#   - Their placement logic is fundamentally different (escape-distance
#     rule for corridors, in-room path validation for rooms,
#     pressure-plate cell linkage).
#
# One .tres per variant lives in `res://assets/objects/`. Different
# variants (fireball timed, poison dart, fireball pressure, ice shard)
# share this resource type but configure damage / sprites / sounds /
# status effects independently — no code branches per variant.
#
# **Subtask scope:** C1 lands the data fields, corridor placement, and
# static launcher rendering. The flight phase (C2), damage (C3),
# pressure plates (C4), room placement (C5), and status-effect
# gameplay (deferred to a later phase) all reuse this resource as-is.

enum Trigger {
	# Fires at fixed intervals. `timed_initial_offset` phase-shifts each
	# placed trap so multiple TIMED launchers in the same area don't
	# fire in sync. (The placer applies a per-trap pseudo-random offset
	# on top of this base value at spawn time.)
	TIMED,
	# Fires when the player steps on a linked floor plate. The plate
	# cell is chosen by the placer to satisfy `min_plate_to_launcher_distance`
	# (so the projectile has visible travel time after triggering) and
	# `max_plate_to_junction_distance` (so the player can sprint to the
	# junction and escape). PRESSURE_PLATE launchers are locked from
	# re-triggering while their previous projectile is still in flight
	# (gameplay rule: "the player can't trigger a second projectile
	# before the first lands").
	PRESSURE_PLATE,
}

@export var name_key: String = ""        # translation key
@export_multiline var description_key: String = ""

@export_group("Trigger")
@export var trigger: Trigger = Trigger.TIMED

@export_group("Damage")
# Applied to all 3 party members on the first frame the projectile's
# cell enters the player's cell. Pass-through with a per-projectile
# latch — the same projectile cannot damage twice. Damage gameplay
# lands in Subtask C3.
@export var damage: int = 8

@export_group("Flight")
# Speed in cells per second. The projectile advances along its fixed
# axis-aligned `fire_direction` (opposite the wall it's mounted on)
# until it hits a wall. Higher values feel like darts, lower values
# like fireballs. Used in Subtask C2.
@export var speed_cells_per_second: float = 8.0

@export_group("Timing — TIMED")
# Period in seconds between launches. Half a second feels frantic,
# 3+ seconds feels lurking. Independent of the player's actions.
@export var timed_period: float = 2.5
# Per-instance phase shift (seconds added to the timer at spawn) so
# multiple TIMED traps don't fire in lockstep. The placer applies a
# pseudo-random offset within [0, timed_period) on top of this base
# value, so the developer can leave this at 0 in most variants.
@export var timed_initial_offset: float = 0.0

@export_group("Placement — Corridor")
# Maximum tiles between the launcher cell and the corridor junction
# the projectile fires toward (a corridor cell with 3+ corridor
# neighbours — a T or crossroads). Caps how long the player has to
# spend in the firing line before reaching a perpendicular escape.
# Used in Subtask C1.
@export var max_escape_distance: int = 5
# Minimum Manhattan distance between this launcher and ANY other
# placed projectile-trap launcher. No graceful degrade — if the rule
# can't be satisfied, the launcher is simply skipped. Spreads
# launchers across the dungeon so the player isn't fenced into a
# corridor of crossfire.
@export var min_distance_to_other_projectile_trap: int = 6

@export_group("Placement — Pressure Plate (PRESSURE_PLATE only)")
# Minimum tiles between the plate cell and the launcher. The
# projectile needs visible travel time so the player can react after
# stepping on the plate. 0 would mean "instant hit" — usually unfair.
# Used in Subtask C4.
@export var min_plate_to_launcher_distance: int = 2
# Maximum tiles between the plate cell and the nearest corridor
# junction. After triggering, the player has to reach the junction
# to escape; this caps how far that detour can be. Plates inside
# rooms ignore this (rooms have no junction concept). Used in C4.
@export var max_plate_to_junction_distance: int = 4

@export_group("Status Effect (data only — gameplay deferred)")
# Status effects on hit (poison, burn, slow) are part of the data
# model now so we don't reshape the resource later. Their gameplay
# application is deferred to a later phase that introduces party
# status effects across all damage sources (traps, enemy attacks,
# environmental hazards).
#
# Empty `status_effect_id` = no status effect. Conventional ids:
# "poison" (DOT), "burn" (DOT), "slow" (movement penalty). Designers
# can add new ids without code changes; the future status-effect
# system will look them up.
@export var status_effect_id: String = ""
@export var status_effect_duration: float = 0.0
@export var status_effect_magnitude: float = 0.0

@export_group("Art — Launcher")
# Wall-mounted sprite (the visible launcher mouth). Rendered as a
# Sprite3D at the wall-face midpoint. The renderer derives
# `pixel_size = launcher_world_height / texture_height`.
@export var launcher_texture: Texture2D
# Real-world height of the launcher sprite in metres-equivalent units.
@export var launcher_world_height: float = 1.0
# Horizontal nudge along the wall, in metres. 0 = centred on the wall
# face. Positive shifts in the wall's tangent direction. Useful when
# the source PNG has visible padding on one side.
@export var launcher_horizontal_offset: float = 0.0
# Vertical offset added to the wall midheight, in metres. 0 places the
# launcher's centre at wall midheight. Positive shifts up.
@export var launcher_y_offset: float = 0.0
# Nudge AWAY from the wall, in metres. 0 sits flush. ~0.02 prevents
# Z-fighting against the triplanar-mapped wall texture.
@export var launcher_depth_offset: float = 0.02

@export_group("Art — Projectile (4-direction)")
# 4-direction sprite system. The projectile's appearance changes based
# on the camera's viewing angle relative to the flight direction.
# Since the player camera is always at a cardinal angle, there are
# exactly 4 possible relative views:
#   - FRONT: camera looks toward the projectile that's coming at it
#     (mandatory — also the fallback for any null override below)
#   - BACK: camera looks the same direction the projectile is travelling
#   - LEFT / RIGHT: camera perpendicular to flight axis (left/right are
#     from the projectile's own frame of reference — standing behind
#     it, looking in fire direction)
# A spherical projectile (fireball) only needs FRONT. An arrow uses all
# 4 (tip, fletching, two profiles). Used in Subtask C2.
@export var projectile_sprite_front: Texture2D
@export var projectile_sprite_back: Texture2D
@export var projectile_sprite_left: Texture2D
@export var projectile_sprite_right: Texture2D
# Real-world height of the projectile sprite in metres-equivalent units.
@export var projectile_world_height: float = 0.5
# Vertical offset from the cell's midheight. 0 = waist-high.
@export var projectile_y_offset: float = 0.0

@export_group("Art — Pressure Plate (PRESSURE_PLATE only)")
# Floor decal. Flat MeshInstance3D quad on the floor, same technique
# as spike trap holes. Used in Subtask C4.
@export var plate_texture: Texture2D
# Cell-relative size of the plate quad (world units). 1.0 = fills the
# cell. Default 0.7 leaves a bit of floor visible around the plate.
@export var plate_world_size: float = 0.7

@export_group("Audio")
# Played when the launcher fires (one new projectile spawned). For
# TIMED traps this routes through SoundManager with a manual
# hearing-distance gate (same pattern spike timed traps use — Godot's
# spatial audio inside a SubViewport was unreliable). PRESSURE_PLATE
# traps always play at full volume since the player is right at the
# plate. Used in Subtask C2 / C4.
@export var launch_sound: AudioStream
# Played when the projectile hits a wall. Same audio routing as
# `launch_sound`.
@export var impact_sound: AudioStream
# PRESSURE_PLATE only — played when the player steps on the plate.
# Always full volume.
@export var plate_sound: AudioStream
# Linear distance falloff (world units) for TIMED traps' launch +
# impact audio. Beyond this radius the sound is silent. Mirrors
# `TrapData.hearing_distance`.
@export var hearing_distance: float = 12.0

func get_display_name() -> String:
	return tr(name_key)

func get_display_description() -> String:
	return tr(description_key)

func is_timed() -> bool:
	return trigger == Trigger.TIMED

func is_pressure_plate() -> bool:
	return trigger == Trigger.PRESSURE_PLATE

# 4-direction sprite resolution. Returns the appropriate texture for
# the given camera-relative view, falling back to FRONT when an
# optional slot is null. FRONT itself has no fallback — variants must
# set it (the resource is unusable without it). Used in C2.
enum ProjectileView { FRONT, BACK, LEFT, RIGHT }

func projectile_sprite_for(view: int) -> Texture2D:
	match view:
		ProjectileView.BACK:
			return projectile_sprite_back if projectile_sprite_back != null else projectile_sprite_front
		ProjectileView.LEFT:
			return projectile_sprite_left if projectile_sprite_left != null else projectile_sprite_front
		ProjectileView.RIGHT:
			return projectile_sprite_right if projectile_sprite_right != null else projectile_sprite_front
		_:
			return projectile_sprite_front
