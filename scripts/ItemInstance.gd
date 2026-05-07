class_name ItemInstance
extends RefCounted

var data: ItemData
var stack_count: int = 1
var durability: int = -1
# Per-placement override for keys. Two ItemInstances built from the
# same key ItemData but with different key_ids unlock different
# doors, so they CANNOT stack. Empty = fall through to data.key_id.
# Set by LevelGenerator's KeyDoorSpawn placement when the lock_id is
# auto-generated; left empty for hand-authored static keys.
var key_id: String = ""
# Hue rotation in [0.0, 1.0) applied at apply_hue_shift() time —
# bakes a per-instance recoloured icon + dungeon sprite. 0.0 means
# "use the data's textures as-is" (cached fields stay null and
# get_icon / get_dungeon_sprite fall through to data). Used by
# KeyDoorSpawn placement so visually-identical keys for different
# locks read as actually different colours, not just brightness
# variations of a multiplicative tint.
var hue_shift: float = 0.0
var _tinted_icon: Texture2D = null
var _tinted_dungeon_sprite: Texture2D = null

static func create(p_data: ItemData, p_count: int = 1) -> ItemInstance:
	var inst := ItemInstance.new()
	inst.data = p_data
	inst.stack_count = max(1, p_count)
	return inst

func get_key_id() -> String:
	# Per-instance override beats per-data default. Returns "" if the
	# item isn't a key at all.
	if key_id != "":
		return key_id
	if data != null:
		return data.key_id
	return ""

func can_stack_with(other: ItemInstance) -> bool:
	if other == null or data == null or other.data == null:
		return false
	if not data.stackable:
		return false
	if data != other.data:
		return false
	# Two keys with different key_ids unlock different doors — keep
	# them in separate stacks even when they share the .tres.
	if get_key_id() != other.get_key_id():
		return false
	return true

func remaining_capacity() -> int:
	if data == null or not data.stackable:
		return 0
	return max(0, data.stack_max - stack_count)

# -------------------------------------------------------
# Per-instance hue-shifted textures (Phase 8 Task 2c follow-up)
# -------------------------------------------------------

# Sets `hue_shift` and bakes recoloured copies of the data's icon
# and dungeon sprite. `shift` is a fraction in [0, 1) that's added
# to each pixel's HSV hue (preserving saturation, value, alpha).
# Pair 0's key calls this with shift = 0 (or doesn't call it at
# all) and falls back to the original textures.
func apply_hue_shift(shift: float) -> void:
	hue_shift = shift
	_tinted_icon = null
	_tinted_dungeon_sprite = null
	if shift == 0.0 or data == null:
		return
	if data.icon != null:
		_tinted_icon = _hue_shifted_texture(data.icon, shift)
	if data.dungeon_sprite != null:
		_tinted_dungeon_sprite = _hue_shifted_texture(data.dungeon_sprite, shift)

func get_icon() -> Texture2D:
	if _tinted_icon != null:
		return _tinted_icon
	if data != null:
		return data.icon
	return null

func get_dungeon_sprite() -> Texture2D:
	if _tinted_dungeon_sprite != null:
		return _tinted_dungeon_sprite
	if data != null:
		return data.dungeon_sprite
	return null

# Bakes a per-pixel hue-rotated copy of the source texture. Static
# so callers don't need an instance to use it (tests, debug tools).
# Per-pixel GDScript loop — fine for 64×64 / 128×128 art at level-
# gen time (~1–10 ms per texture); too slow for runtime per-frame.
static func _hue_shifted_texture(source: Texture2D, shift: float) -> ImageTexture:
	if source == null:
		return null
	var src_img: Image = source.get_image()
	if src_img == null:
		return null
	# Work on a duplicate so the source asset stays untouched, and
	# normalise to RGBA8 so set_pixel / get_pixel use predictable
	# component layout.
	var img: Image = src_img.duplicate() as Image
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var w: int = img.get_width()
	var h: int = img.get_height()
	for y in range(h):
		for x in range(w):
			var src: Color = img.get_pixel(x, y)
			if src.a == 0.0:
				continue
			var new_h: float = fmod(src.h + shift, 1.0)
			if new_h < 0.0:
				new_h += 1.0
			var rotated: Color = Color.from_hsv(new_h, src.s, src.v)
			rotated.a = src.a
			img.set_pixel(x, y, rotated)
	return ImageTexture.create_from_image(img)
