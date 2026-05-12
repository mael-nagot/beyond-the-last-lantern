class_name TeleporterData
extends Resource

# Visual + sound template for a placed teleporter cell. Phase 15 Task 6.
#
# One .tres per teleporter variant lives in res://assets/objects/.
# All endpoints of all teleporter pairs in a biome share a single
# TeleporterData via BiomeData.teleporter_spawn — there is no need
# for per-pair art in V1 (the map glyph hue varies per pair via the
# instance's pair_index; the floor decal and SFX are constant).
#
# Phase A uses this for a "dumb warp" — two random non-special floor
# cells form a pair and exchange the player when stepped on. Phase C
# (island topology) will reuse the same data class for the partitioned
# variant where the level is split into K islands and each pair
# bridges two islands.

@export var name_key: String = ""        # translation key
@export_multiline var description_key: String = ""

@export_group("Art")
# Top-down decal drawn flat on the floor (mirrors the spinner pattern).
# Optional — null = invisible teleporter (the warp still fires, the
# floor is just unmarked). Visible decals are strongly recommended so
# the player can spot teleporters.
@export var decal_sprite: Texture2D
# Animated rune-circle frames (optional). When set, the renderer uses
# AnimatedSprite3D instead of the static `decal_sprite` and auto-plays
# `default_animation`. Either `decal_sprite` or `frames` should be
# set; if both are set the renderer prefers `frames`.
@export var frames: SpriteFrames
# Decal size in world units. 1.0 = exactly one cell wide / deep.
@export var decal_world_size: float = 1.0
# Vertical offset above the floor plane. 0.01 keeps the decal above
# floor Z-fights (same convention as spinner / spike-trap decals).
@export var y_offset: float = 0.01

@export_group("Light")
# Warm glow under the rune circle. Set energy = 0 to disable the
# light entirely (no OmniLight3D spawned).
@export var light_color: Color = Color(1.0, 0.7, 0.4)
@export var light_energy: float = 1.0
@export var light_range: float = 3.0

@export_group("Audio")
# Played once when the player steps onto a teleporter and the warp
# fires. Non-spatial — the warp is a UI-feeling event.
@export var warp_sound: AudioStream
# Phase C: played once when the player tries to walk into a sealed
# wall (audible feedback that "there's no way through here, find the
# rune circle"). Unused in Phase A — sealed walls don't exist yet.
@export var seal_sound: AudioStream

func get_display_name() -> String:
	return tr(name_key)

func get_display_description() -> String:
	return tr(description_key)

# True iff the renderer should prefer the animated path. Documents the
# precedence rule (frames > decal_sprite) for the renderer + tests.
func is_animated() -> bool:
	return frames != null
