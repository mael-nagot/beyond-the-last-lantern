extends GutTest

func test_defaults() -> void:
	var data := FillerData.new()
	assert_eq(data.name_key, "")
	assert_eq(data.description_key, "")
	assert_null(data.texture)
	assert_almost_eq(data.world_height, 4.0, 0.0001)
	assert_almost_eq(data.y_offset, 0.0, 0.0001)

func test_texture_assignment() -> void:
	var data := FillerData.new()
	var img := Image.create(8, 16, false, Image.FORMAT_RGBA8)
	data.texture = ImageTexture.create_from_image(img)
	assert_not_null(data.texture)
	assert_eq(data.texture.get_height(), 16)

func test_get_display_name_returns_tr_of_key() -> void:
	# Without a loaded translation, tr() returns the key unchanged.
	# Pin that contract so callers can rely on it instead of the
	# raw key field.
	var data := FillerData.new()
	data.name_key = "filler.test.name"
	assert_eq(data.get_display_name(), "filler.test.name")
