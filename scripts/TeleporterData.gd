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
# Upright pixel-art sprite for the teleporter (Sprite3D billboard,
# BILLBOARD_FIXED_Y — rotates around the world Y axis to face the
# player, stays vertical like chests / levers). Optional — null =
# invisible teleporter (the warp still fires, the cell is just
# unmarked but the optional light still glows). Visible sprites are
# strongly recommended so the player can spot teleporter endpoints.
@export var sprite: Texture2D
# Animated sprite frames (optional). When set, the renderer uses
# AnimatedSprite3D instead of the static `sprite` and auto-plays
# `default_animation`. Either `sprite` or `frames` should be set; if
# both are set the renderer prefers `frames`.
@export var frames: SpriteFrames
# Sprite height in world units. The renderer derives `pixel_size`
# from `world_height / texture_height` (same pattern as chest / lever
# / spike sprites) so designers control real-world size without
# fiddling with per-sprite scale.
@export var world_height: float = 1.8
# Vertical offset added to the sprite's centre position (which is
# anchored at `world_height * 0.5` above the floor so the sprite sits
# ON the floor, not floating). Useful for nudging a rune circle
# upward if the source art has transparent padding at the bottom.
@export var y_offset: float = 0.0
# Sprite opacity in [0, 1]. 1 = fully opaque (Godot's default), <1 =
# semi-transparent (sells "this is a magical projection, not a
# physical prop"). Applied via the Sprite3D / AnimatedSprite3D
# `modulate.a`. Note: `alpha_cut = ALPHA_CUT_DISCARD` still hard-cuts
# the texture's transparent BACKGROUND — the sprite outline stays
# crisp; only the opaque pixels are blended at this alpha.
@export_range(0.0, 1.0, 0.05) var alpha: float = 0.8
# Brightness multiplier on the sprite's RGB channels. 1.0 = normal,
# >1 = HDR-boosted (combined with the WorldEnvironment's Glow pass
# this produces a noticeable bloom around the rune). 1.5–2.5 reads
# as a soft magical glow; >3 typically blows the silhouette out so
# only its outline remains. Applied via Sprite3D `modulate.rgb`, so
# it multiplies the texture's existing colour rather than adding to
# it. Set to 1.0 to disable the boost (purely texture-as-is).
@export_range(0.0, 4.0, 0.1) var glow_multiplier: float = 1.5

@export_group("Living energy pulse")
# Variation in glow + alpha + light energy each pulse cycle, in
# [0, 1]. 0 = static (no pulse), 0.5 = ±50% swing, 1.0 = full off-to-
# brighter-than-base swing. The sprite cycles between
# (base * (1 - pulse_amount), base * (1 + pulse_amount)) using a
# sine wave; the light's energy follows the SAME phase so the bloom
# and the cast glow breathe together. Defaults to 0.5 — clearly
# perceptible "alive" feel without being seizure-inducing.
@export_range(0.0, 1.0, 0.05) var pulse_amount: float = 0.5
# How fast the pulse cycles, in radians per second. ~PI (3.14) =
# one full breath per ~2 seconds, which reads as "calm energy".
# 2*PI = one breath per second (agitated). 0 disables the pulse
# entirely regardless of `pulse_amount`.
@export_range(0.0, 12.0, 0.1) var pulse_speed: float = 3.0
# Per-pair phase offset (radians) so consecutive pairs don't pulse
# in lockstep. The renderer multiplies this by
# `TeleporterInstance.pair_index` to compute each pair's starting
# phase — both endpoints of the SAME pair stay in sync (they're "one
# magic"), but different pairs feel independent. ~1.6 (a bit over
# PI/2) gives a noticeable offset without looking like a chase.
@export_range(0.0, 6.3, 0.1) var pulse_phase_per_pair: float = 1.6
## Stepped-animation frame count for the pulse. 0 = smooth sine
## breathing (default — V1 behaviour). 4 / 6 / 8 = "spritesheet"
## look: the glow + alpha + light energy snap between N discrete
## brightness levels along the sine cycle instead of interpolating.
## The cycle SPEED is still controlled by `pulse_speed` (one full
## breath = `2π / pulse_speed` seconds); the frame count quantizes
## which brightness levels show up. Values >12 are technically
## allowed but visually indistinguishable from smooth.
@export_range(0, 16, 1) var pulse_frame_count: int = 0

@export_group("Placement offset")
# How far (in world units) the sprite shifts toward the player
# along the player's current facing axis — same mechanic chests use
# (`ObjectData.lean_toward_player`) to break the centred-on-cell
# look. 0 = sprite sits exactly at cell centre (no lean). 0.2–0.4 =
# subtle "the rune is leaning toward you", 0.6+ = obvious "the rune
# is greeting you". Recomputed on player turn (NOT on movement, same
# as the chest lean), so the rune doesn't visibly snap mid-step.
@export_range(0.0, 1.5, 0.05) var lean_toward_player: float = 0.0

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
# precedence rule (frames > sprite) for the renderer + tests.
func is_animated() -> bool:
	return frames != null
