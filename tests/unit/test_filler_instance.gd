extends GutTest

func test_create_assigns_all_fields() -> void:
	var data := FillerData.new()
	data.world_height = 5.0
	var inst := FillerInstance.create(data, Vector2i(3, -2), Vector2(0.1, -0.3), 1.25)
	assert_same(inst.data, data)
	assert_eq(inst.cell, Vector2i(3, -2))
	assert_almost_eq(inst.cell_offset.x, 0.1, 0.0001)
	assert_almost_eq(inst.cell_offset.y, -0.3, 0.0001)
	assert_almost_eq(inst.scale, 1.25, 0.0001)

func test_create_accepts_out_of_grid_cells() -> void:
	# Border-ring fillers live at negative cell coords or coords past
	# grid_width/height. The instance must accept those without any
	# special handling — they're just numbers to it.
	var data := FillerData.new()
	var inst := FillerInstance.create(data, Vector2i(-5, 30), Vector2.ZERO, 1.0)
	assert_eq(inst.cell, Vector2i(-5, 30))
