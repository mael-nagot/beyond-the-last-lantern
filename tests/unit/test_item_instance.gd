extends GutTest

func _make_data(stackable: bool = true, stack_max: int = 9) -> ItemData:
	var data := ItemData.new()
	data.item_name = "test.item.name"
	data.stackable = stackable
	data.stack_max = stack_max
	return data

func test_create_uses_supplied_data_and_count() -> void:
	var data := _make_data()
	var inst := ItemInstance.create(data, 4)
	assert_eq(inst.data, data)
	assert_eq(inst.stack_count, 4)

func test_create_defaults_to_count_one() -> void:
	var inst := ItemInstance.create(_make_data())
	assert_eq(inst.stack_count, 1)

func test_create_clamps_count_to_at_least_one() -> void:
	var inst := ItemInstance.create(_make_data(), 0)
	assert_eq(inst.stack_count, 1)
	var neg := ItemInstance.create(_make_data(), -5)
	assert_eq(neg.stack_count, 1)

func test_can_stack_with_same_data() -> void:
	var data := _make_data()
	var a := ItemInstance.create(data, 1)
	var b := ItemInstance.create(data, 1)
	assert_true(a.can_stack_with(b))

func test_cannot_stack_with_different_data() -> void:
	var a := ItemInstance.create(_make_data(), 1)
	var b := ItemInstance.create(_make_data(), 1)
	assert_false(a.can_stack_with(b))

func test_cannot_stack_when_data_is_non_stackable() -> void:
	var data := _make_data(false)
	var a := ItemInstance.create(data, 1)
	var b := ItemInstance.create(data, 1)
	assert_false(a.can_stack_with(b))

func test_cannot_stack_with_null() -> void:
	var a := ItemInstance.create(_make_data(), 1)
	assert_false(a.can_stack_with(null))

func test_cannot_stack_when_data_is_null() -> void:
	var a := ItemInstance.create(_make_data(), 1)
	var bare := ItemInstance.new()
	assert_false(a.can_stack_with(bare))
	assert_false(bare.can_stack_with(a))

func test_remaining_capacity_reflects_stack_max() -> void:
	var data := _make_data(true, 9)
	var inst := ItemInstance.create(data, 3)
	assert_eq(inst.remaining_capacity(), 6)

func test_remaining_capacity_is_zero_when_full() -> void:
	var data := _make_data(true, 5)
	var inst := ItemInstance.create(data, 5)
	assert_eq(inst.remaining_capacity(), 0)

func test_remaining_capacity_is_zero_for_non_stackable() -> void:
	var data := _make_data(false, 9)
	var inst := ItemInstance.create(data, 1)
	assert_eq(inst.remaining_capacity(), 0)

func test_remaining_capacity_is_zero_with_null_data() -> void:
	var inst := ItemInstance.new()
	assert_eq(inst.remaining_capacity(), 0)

# -------------------------------------------------------
# Key id (Phase 8 Task 2c) — per-instance override of data.key_id
# so a single key .tres can serve auto-generated lock_ids across
# multiple doors in the same biome.
# -------------------------------------------------------

func test_get_key_id_defaults_empty() -> void:
	var inst := ItemInstance.create(_make_data(), 1)
	assert_eq(inst.get_key_id(), "")

func test_get_key_id_falls_back_to_data() -> void:
	var data := _make_data()
	data.key_id = "static_lock"
	var inst := ItemInstance.create(data, 1)
	assert_eq(inst.get_key_id(), "static_lock")

func test_get_key_id_instance_override_beats_data() -> void:
	var data := _make_data()
	data.key_id = "data_lock"
	var inst := ItemInstance.create(data, 1)
	inst.key_id = "instance_lock"
	assert_eq(inst.get_key_id(), "instance_lock")

func test_keys_with_different_ids_do_not_stack() -> void:
	# Two ItemInstances built from the same ItemData but with
	# different per-placement key_ids unlock different doors —
	# stacking them would lose information.
	var data := _make_data()
	var a := ItemInstance.create(data, 1)
	a.key_id = "lock_0"
	var b := ItemInstance.create(data, 1)
	b.key_id = "lock_1"
	assert_false(a.can_stack_with(b))

func test_keys_with_same_id_stack() -> void:
	var data := _make_data()
	var a := ItemInstance.create(data, 1)
	a.key_id = "lock_0"
	var b := ItemInstance.create(data, 1)
	b.key_id = "lock_0"
	assert_true(a.can_stack_with(b))

# -------------------------------------------------------
# Hue shift (Phase 8 Task 2c follow-up) — per-instance hue
# rotation baked into a recoloured icon + dungeon sprite, so
# visually-identical keys for different locks render in different
# colours. Replaces the earlier multiplicative-tint approach (which
# only produced brightness variations on strongly-coloured base
# sprites like a yellow key).
# -------------------------------------------------------

func test_hue_shift_defaults_zero() -> void:
	var inst := ItemInstance.create(_make_data(), 1)
	assert_eq(inst.hue_shift, 0.0)

func test_get_icon_falls_back_to_data_when_no_shift() -> void:
	var data := _make_data()
	# Create a tiny test icon so get_icon returns something non-null.
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0.8, 0.2))
	data.icon = ImageTexture.create_from_image(img)
	var inst := ItemInstance.create(data, 1)
	assert_eq(inst.get_icon(), data.icon,
		"with no hue shift applied, get_icon must return the data's icon")

func test_get_dungeon_sprite_falls_back_to_data_when_no_shift() -> void:
	var data := _make_data()
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0.8, 0.2))
	data.dungeon_sprite = ImageTexture.create_from_image(img)
	var inst := ItemInstance.create(data, 1)
	assert_eq(inst.get_dungeon_sprite(), data.dungeon_sprite)

func test_apply_hue_shift_zero_clears_cached_textures() -> void:
	var data := _make_data()
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0.8, 0.2))
	data.icon = ImageTexture.create_from_image(img)
	var inst := ItemInstance.create(data, 1)
	inst.apply_hue_shift(0.5)
	assert_ne(inst.get_icon(), data.icon, "non-zero shift should bake a new icon")
	inst.apply_hue_shift(0.0)
	assert_eq(inst.get_icon(), data.icon,
		"shift back to 0.0 should fall through to the original icon")

func test_apply_hue_shift_actually_rotates_pixel_hues() -> void:
	# Bake a 1×1 yellow texture and rotate by 0.5 (180°) — should
	# produce blue.
	var data := _make_data()
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color(1, 1, 0))  # pure yellow, hue ~0.166
	data.icon = ImageTexture.create_from_image(img)
	var inst := ItemInstance.create(data, 1)
	inst.apply_hue_shift(0.5)
	var baked: Texture2D = inst.get_icon()
	var baked_img: Image = baked.get_image()
	var pixel: Color = baked_img.get_pixel(0, 0)
	# Rotated yellow by 0.5 should be in the blue/violet range —
	# hue near 0.666. Allow some float slop.
	assert_almost_eq(pixel.h, 0.666, 0.05,
		"yellow rotated by 0.5 should land near blue (hue ~0.666)")
