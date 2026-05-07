extends GutTest

func test_defaults() -> void:
	var data := WallDecorationData.new()
	assert_null(data.texture)
	assert_null(data.frames)
	assert_eq(data.default_animation, "idle")
	assert_eq(data.world_height, 1.5)
	assert_eq(data.y_offset, 0.0)
	assert_almost_eq(data.depth_offset, 0.02, 0.0001)
	assert_false(data.face_camera)
	assert_almost_eq(data.top_tilt_degrees, 15.0, 0.0001)
	assert_eq(data.light_energy, 0.0)

func test_is_animated_false_when_only_texture_set() -> void:
	var data := WallDecorationData.new()
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	data.texture = ImageTexture.create_from_image(img)
	assert_false(data.is_animated())

func test_is_animated_true_when_frames_set() -> void:
	var data := WallDecorationData.new()
	data.frames = SpriteFrames.new()
	assert_true(data.is_animated())

func test_frames_take_precedence_over_texture() -> void:
	# Both set is allowed (designer mistake) — the renderer picks
	# `frames` (animated path) per is_animated()'s contract. Pin that.
	var data := WallDecorationData.new()
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	data.texture = ImageTexture.create_from_image(img)
	data.frames = SpriteFrames.new()
	assert_true(data.is_animated())
