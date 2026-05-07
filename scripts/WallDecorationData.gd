class_name WallDecorationData
extends Resource

# Template for a wall-mounted decoration (paintings, torches, lanterns,
# banners). Wall decos differ from cell-bound `ObjectData` in three
# fundamental ways:
#   - they live on a wall FACE (a side of a floor cell that abuts a
#     wall cell), not on the cell itself
#   - they never block movement and never carry interactions
#   - they may be animated (multi-frame `SpriteFrames`) for flickering
#     torches and similar effects
#
# Static decorations set `texture` and leave `frames` null; animated
# decorations set `frames` and leave `texture` null. The renderer picks
# `Sprite3D` or `AnimatedSprite3D` accordingly.

@export var name_key: String = ""        # translation key
@export_multiline var description_key: String = ""

@export_group("Art")
# Static art — used when `frames` is null. Single PNG.
@export var texture: Texture2D
# Animated art — when set, takes precedence over `texture`. The
# renderer uses an `AnimatedSprite3D` with this `SpriteFrames` resource
# and auto-plays the animation named `default_animation` (defaults to
# "idle" — Godot's `SpriteFrames` always ships at least one named
# animation, "default" by convention; designers should rename it to
# something descriptive like "idle" or "burn").
@export var frames: SpriteFrames
@export var default_animation: String = "idle"

# Real-world height in metres-equivalent units. The renderer derives
# `pixel_size` from `world_height / texture_height` so designers control
# the on-screen size regardless of the source texture's pixel size.
# (For animated decorations the first frame's height is used — keep
# every frame the same dimensions or the torch will pulse.)
@export var world_height: float = 1.5
# Vertical offset added to the wall midpoint. 0 places the decoration's
# centre at wall midheight. Positive shifts up. Useful when the source
# texture has padding at the top or bottom that we want to keep above
# (or below) the geometric centre of the wall face.
@export var y_offset: float = 0.0
# Horizontal nudge AWAY from the wall, in metres. 0 sits flush. A small
# positive value (~0.02) prevents Z-fighting with the wall texture
# beneath, which is rendered with triplanar mapping and may not be
# perfectly coplanar with the cell boundary.
@export var depth_offset: float = 0.02

@export_group("Light")
# When `light_energy > 0`, the renderer attaches an `OmniLight3D` as a
# child of the sprite — gives torches and lanterns a real glow without
# requiring a separate scene. Energy 0 = no light spawned (paintings).
@export var light_color: Color = Color(1.0, 0.7, 0.4)
@export var light_energy: float = 0.0
@export var light_range: float = 6.0

func is_animated() -> bool:
	return frames != null

func get_display_name() -> String:
	return tr(name_key)

func get_display_description() -> String:
	return tr(description_key)
