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

@export_group("Face-camera mode")
# When true, the decoration always faces the player (Y-axis billboard
# updated per frame from DungeonView), with its BASE pinned to the
# wall and its top leaning out into the corridor by `top_tilt_degrees`.
# Reads as a 3D object that the player walks around, instead of a
# flat sprite that disappears edge-on. Leave false for paintings and
# other decos that should sit flat on the wall.
@export var face_camera: bool = false
# How far the top of the decoration leans away from the wall toward
# the player, in degrees. Only applies when `face_camera = true`. The
# bottom stays anchored to the wall regardless of tilt. 0 = vertical
# (no lean). ~10–20° gives a torch a clear protruding silhouette
# without looking like it's about to fall off.
@export var top_tilt_degrees: float = 15.0

@export_group("Light")
# When `light_energy > 0`, the renderer attaches an `OmniLight3D` as a
# child of the sprite — gives torches and lanterns a real glow without
# requiring a separate scene. Energy 0 = no light spawned (paintings).
@export var light_color: Color = Color(1.0, 0.7, 0.4)
@export var light_energy: float = 0.0
@export var light_range: float = 6.0
# Vertical offset (in metres) of the light source relative to the
# sprite's CENTRE. 0 = at the centre. Positive = up. Used to position
# the bright spot on the flame instead of in the middle of the
# torch's wooden handle. The offset rotates with the sprite under
# `face_camera` tilt, so the glow tracks the flame as it leans.
@export var light_y_offset: float = 0.0
# Flicker magnitude as a fraction of base energy. 0 = no flicker
# (steady glow). 0.15–0.25 reads as a torch / candle flame; higher
# values feel jittery / unstable. Driven by a multi-octave sine in
# DungeonView's `_process`, with a per-placement phase offset so
# every torch flickers independently.
@export var light_flicker_amount: float = 0.0

func is_animated() -> bool:
	return frames != null

func get_display_name() -> String:
	return tr(name_key)

func get_display_description() -> String:
	return tr(description_key)
