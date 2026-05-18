class_name SpinnerData
extends Resource

# Template for a spinner placed on a dungeon floor cell. Phase 8 Task 8.
# One .tres per spinner variant lives in res://assets/objects/.
# Variants share this resource type but configure direction / rotation
# count / step duration / decal art / sound independently.
#
# Spinners are PASSIVE hazards — they don't extend ObjectData because
# they never gate placement, never get clicked, and have no
# opened/closed state. They live on `GridCell.spinner` (a slot
# parallel to `GridCell.trap`) so placement enforces "spinner OR trap
# OR chest / lever / projectile-plate, never two of those on the same
# tile".
#
# A SpinnerData defines the variant template: the allowed RANGE of
# rotation counts ([min_spins, max_spins]) and a direction policy
# (CLOCKWISE / COUNTER_CLOCKWISE / RANDOM). Each placed
# `SpinnerInstance` rolls a CONCRETE rotation count and direction
# once at placement time and keeps them for its lifetime — so a
# single spinner always spins the player the same way every trigger,
# but different spinners (even those sharing this SpinnerData) may
# disagree.

enum Direction {
	# Every instance rotates the player clockwise.
	CLOCKWISE,
	# Every instance rotates the player counter-clockwise.
	COUNTER_CLOCKWISE,
	# Each instance rolls CLOCKWISE or COUNTER_CLOCKWISE once at
	# placement (the LevelGenerator's seeded RNG decides) and keeps
	# the rolled direction for its lifetime. The same spinner always
	# spins the player the same way; different spinners with this
	# data may disagree.
	RANDOM,
}

@export var name_key: String = ""        # translation key
@export_multiline var description_key: String = ""

@export_group("Rotation")
# Inclusive range used by the placer to roll each instance's fixed
# rotation count. Set min == max for a fully deterministic spinner;
# a wider range gives each placed instance its own surprise factor.
# Values are number of 90° turns — 4 = a full revolution.
@export_range(1, 8) var min_spins: int = 1
@export_range(1, 8) var max_spins: int = 3
@export var direction: Direction = Direction.RANDOM

@export_group("Timing")
# Duration of each 90° turn during the chained spin. Must be >= 0.12
# to leave the rotation tween in DungeonView (`rotate_camera_to`,
# fixed at 0.12s) time to settle before the next step kicks in;
# shorter values produce a janky compound rotation as successive
# tweens fight for `camera.rotation_degrees:y`. Default 0.13 leaves
# a 0.01s buffer.
@export var spin_step_duration: float = 0.13

@export_group("Art")
# Top-down decal drawn flat on the floor (mirrors the spike-trap
# hole pattern). Optional — null = invisible spinner (the player
# only feels the spin). Visible decals are recommended so players
# can learn to recognise them.
@export var decal_sprite: Texture2D
# Decal size in world units. 1.0 = exactly one cell wide / deep.
@export var decal_world_size: float = 1.0
# Vertical offset above the floor plane. 0.01 keeps the decal above
# floor Z-fights (same convention as the spike-trap holes).
@export var y_offset: float = 0.01
## Continuous Y-axis rotation rate, in degrees per second, applied
## to the decal so the spinner visually advertises itself even when
## not triggered. 0 = static decal. ~45 = a leisurely swirl;
## ~180 = aggressive. Designers can crank this for hazard biomes.
## Combined with `visual_frame_count` for the stepped look: the rate
## still controls how FAST a full revolution completes (one revolution
## = 360 / rate seconds); the frame count just quantizes which angles
## the decal snaps to. Drop the rate when using a low frame count
## (4 frames at 45°/s reads as a clean tick; 4 frames at 180°/s reads
## as flicker).
@export var visual_rotation_degrees_per_second: float = 45.0
## Stepped-animation frame count for the decal rotation. 0 = smooth
## continuous spin (default — V1 behaviour). 4 / 6 / 8 = "spritesheet"
## look: the decal snaps to N equally-spaced angles per full
## revolution instead of rotating smoothly. Pair with a low
## `visual_rotation_degrees_per_second` so each tick reads as a
## deliberate frame rather than a flicker. Values >12 are technically
## allowed but visually indistinguishable from smooth.
@export_range(0, 16, 1) var visual_frame_count: int = 0

@export_group("Audio")
# Played once per 90° turn while the player is being spun. If null
# falls back to the global turn sound — designers can opt out of a
# bespoke spinner whoosh by leaving this empty.
@export var spin_sound: AudioStream

func get_display_name() -> String:
	return tr(name_key)

func get_display_description() -> String:
	return tr(description_key)
