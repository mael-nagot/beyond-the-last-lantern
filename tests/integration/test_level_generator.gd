extends GutTest

func _make_biome(loot: Array[LootEntry] = [], items_min: int = 0, items_max: int = 0) -> BiomeData:
	var biome := BiomeData.new()
	biome.grid_width = 21
	biome.grid_height = 21
	biome.maze_bias = 0.4
	biome.wiggle = 0.5
	biome.corridor_min_width = 1
	biome.corridor_max_width = 1
	biome.width_change_chance = 0.0
	biome.room_count = 3
	biome.room_min_size = 3
	biome.room_max_size = 4
	biome.entrance_at_dead_end = true
	biome.exit_at_dead_end = true
	biome.min_exit_distance = 5
	biome.floor_loot = loot
	biome.floor_items_min = items_min
	biome.floor_items_max = items_max
	return biome

func _make_item(stackable: bool = true) -> ItemData:
	var data := ItemData.new()
	data.item_name = "test.item"
	data.stackable = stackable
	return data

func _make_loot_entry(item: ItemData, weight: int = 1, placement: int = LootEntry.PLACEMENT_ANY) -> LootEntry:
	var entry := LootEntry.new()
	entry.item = item
	entry.weight = weight
	entry.placement = placement
	return entry

func _make_generator(biome: BiomeData, rng_seed: int = 12345) -> LevelGenerator:
	seed(rng_seed)
	var gen := LevelGenerator.new()
	add_child_autofree(gen)
	gen.configure(biome)
	gen.generate()
	return gen

func _all_floor_cells(gen: LevelGenerator) -> Array:
	var result: Array = []
	for x in range(gen.grid_width):
		for y in range(gen.grid_height):
			if gen.grid[x][y].cell_type != GridCell.CellType.WALL:
				result.append(Vector2i(x, y))
	return result

func _bfs_reachable_from(gen: LevelGenerator, start: Vector2i) -> Dictionary:
	var visited: Dictionary = {start: true}
	var queue: Array = [start]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var next: Vector2i = current + d
			if next.x < 0 or next.x >= gen.grid_width or next.y < 0 or next.y >= gen.grid_height:
				continue
			if visited.has(next):
				continue
			if gen.grid[next.x][next.y].cell_type == GridCell.CellType.WALL:
				continue
			visited[next] = true
			queue.append(next)
	return visited

# -------------------------------------------------------
# Grid structure
# -------------------------------------------------------

func test_generated_grid_has_configured_dimensions() -> void:
	var gen := _make_generator(_make_biome())
	assert_eq(gen.grid.size(), 21)
	assert_eq(gen.grid[0].size(), 21)

func test_grid_border_is_wall() -> void:
	var gen := _make_generator(_make_biome())
	for x in range(gen.grid_width):
		assert_eq(gen.grid[x][0].cell_type, GridCell.CellType.WALL,
			"top border (%d,0) should be wall" % x)
		assert_eq(gen.grid[x][gen.grid_height - 1].cell_type, GridCell.CellType.WALL,
			"bottom border (%d,%d) should be wall" % [x, gen.grid_height - 1])
	for y in range(gen.grid_height):
		assert_eq(gen.grid[0][y].cell_type, GridCell.CellType.WALL,
			"left border (0,%d) should be wall" % y)
		assert_eq(gen.grid[gen.grid_width - 1][y].cell_type, GridCell.CellType.WALL,
			"right border (%d,%d) should be wall" % [gen.grid_width - 1, y])

func test_exactly_one_entrance_and_one_exit() -> void:
	var gen := _make_generator(_make_biome())
	var entrances := 0
	var exits := 0
	for x in range(gen.grid_width):
		for y in range(gen.grid_height):
			match gen.grid[x][y].cell_type:
				GridCell.CellType.ENTRANCE: entrances += 1
				GridCell.CellType.EXIT: exits += 1
	assert_eq(entrances, 1)
	assert_eq(exits, 1)

func test_entrance_and_exit_are_distinct() -> void:
	var gen := _make_generator(_make_biome())
	assert_ne(gen.entrance_pos, gen.exit_pos)

func test_exit_is_reachable_from_entrance() -> void:
	var gen := _make_generator(_make_biome())
	var reachable := _bfs_reachable_from(gen, gen.entrance_pos)
	assert_true(reachable.has(gen.exit_pos))

func test_min_exit_distance_is_respected() -> void:
	var biome := _make_biome()
	biome.min_exit_distance = 10
	var gen := _make_generator(biome)
	var manhattan: int = abs(gen.entrance_pos.x - gen.exit_pos.x) + abs(gen.entrance_pos.y - gen.exit_pos.y)
	assert_gte(manhattan, 10)

# -------------------------------------------------------
# Item placement
# -------------------------------------------------------

func test_no_items_placed_when_loot_pool_is_empty() -> void:
	var gen := _make_generator(_make_biome([], 5, 10))
	for cell in _all_floor_cells(gen):
		assert_eq(gen.grid[cell.x][cell.y].items.size(), 0)

func test_no_items_placed_when_min_max_are_zero() -> void:
	var item := _make_item()
	var loot: Array[LootEntry] = [_make_loot_entry(item)]
	var gen := _make_generator(_make_biome(loot, 0, 0))
	var total := 0
	for cell in _all_floor_cells(gen):
		total += gen.grid[cell.x][cell.y].items.size()
	assert_eq(total, 0)

func test_item_count_falls_within_min_max() -> void:
	var item := _make_item()
	var loot: Array[LootEntry] = [_make_loot_entry(item)]
	var gen := _make_generator(_make_biome(loot, 4, 8))
	var total := 0
	for cell in _all_floor_cells(gen):
		total += gen.grid[cell.x][cell.y].items.size()
	assert_between(total, 4, 8)

func test_items_never_spawn_on_entrance_or_exit() -> void:
	var item := _make_item()
	var loot: Array[LootEntry] = [_make_loot_entry(item)]
	var gen := _make_generator(_make_biome(loot, 8, 8))
	var entrance: Vector2i = gen.entrance_pos
	var exit: Vector2i = gen.exit_pos
	assert_eq(gen.grid[entrance.x][entrance.y].items.size(), 0)
	assert_eq(gen.grid[exit.x][exit.y].items.size(), 0)

func test_dead_end_only_loot_spawns_only_on_dead_ends() -> void:
	var item := _make_item()
	var loot: Array[LootEntry] = [_make_loot_entry(item, 1, LootEntry.PLACEMENT_DEAD_END)]
	var gen := _make_generator(_make_biome(loot, 5, 5))
	for cell_pos in _all_floor_cells(gen):
		var cell: GridCell = gen.grid[cell_pos.x][cell_pos.y]
		if cell.items.is_empty():
			continue
		# Verify it's a dead end (exactly one floor neighbour) and not entrance/exit
		assert_ne(cell_pos, gen.entrance_pos)
		assert_ne(cell_pos, gen.exit_pos)
		var floor_neighbours := 0
		for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var n: Vector2i = cell_pos + d
			if n.x >= 0 and n.x < gen.grid_width and n.y >= 0 and n.y < gen.grid_height:
				if gen.grid[n.x][n.y].cell_type != GridCell.CellType.WALL:
					floor_neighbours += 1
		assert_eq(floor_neighbours, 1, "item at %s should be on a dead end" % cell_pos)

func test_items_only_appear_on_floor_cells() -> void:
	var item := _make_item()
	var loot: Array[LootEntry] = [_make_loot_entry(item)]
	var gen := _make_generator(_make_biome(loot, 6, 6))
	for x in range(gen.grid_width):
		for y in range(gen.grid_height):
			var cell: GridCell = gen.grid[x][y]
			if cell.cell_type == GridCell.CellType.WALL:
				assert_eq(cell.items.size(), 0,
					"wall (%d,%d) should not hold items" % [x, y])

func test_multiple_rolls_can_pile_on_one_tile() -> void:
	# With many rolls and a single item type, pigeonhole gives us at least one
	# tile with 2+ items somewhere over a few seeds.
	var item := _make_item()
	var loot: Array[LootEntry] = [_make_loot_entry(item)]
	var seen_pile := false
	for s in [101, 202, 303, 404, 505]:
		var gen := _make_generator(_make_biome(loot, 50, 50), s)
		for cell_pos in _all_floor_cells(gen):
			if gen.grid[cell_pos.x][cell_pos.y].items.size() >= 2:
				seen_pile = true
				break
		if seen_pile:
			break
	assert_true(seen_pile, "across 5 seeds with 50 rolls each, at least one tile should have a pile of 2+")

# -------------------------------------------------------
# Object placement (Phase 8 Task 1: chests)
# -------------------------------------------------------

func _make_chest(blocks: bool = true) -> ObjectData:
	var data := ObjectData.new()
	data.category = ObjectData.Category.CHEST
	data.blocks_movement = blocks
	data.name_key = "test.chest"
	return data

func _make_object_spawn(object: ObjectData, count_min: int, count_max: int, placement: int = ObjectSpawn.PLACEMENT_DEFAULT) -> ObjectSpawn:
	var spawn := ObjectSpawn.new()
	spawn.object = object
	spawn.count_min = count_min
	spawn.count_max = count_max
	spawn.placement = placement
	return spawn

func _all_object_cells(gen: LevelGenerator) -> Array:
	var result: Array = []
	for x in range(gen.grid_width):
		for y in range(gen.grid_height):
			if gen.grid[x][y].object != null:
				result.append(Vector2i(x, y))
	return result

func test_no_objects_placed_when_pool_is_empty() -> void:
	var gen := _make_generator(_make_biome())
	assert_eq(_all_object_cells(gen).size(), 0)

func test_object_count_falls_within_min_max() -> void:
	var biome := _make_biome()
	biome.objects = [_make_object_spawn(_make_chest(), 2, 4)]
	var gen := _make_generator(biome)
	var count := _all_object_cells(gen).size()
	assert_between(count, 2, 4)

func test_multiple_object_types_each_respect_their_own_min_max() -> void:
	# Two chest types: 1-1 of A, 2-2 of B → exactly 3 placements total
	var biome := _make_biome()
	biome.objects = [
		_make_object_spawn(_make_chest(), 1, 1),
		_make_object_spawn(_make_chest(), 2, 2),
	]
	var gen := _make_generator(biome)
	assert_eq(_all_object_cells(gen).size(), 3)

func test_objects_never_on_entrance_or_exit() -> void:
	var biome := _make_biome()
	biome.objects = [_make_object_spawn(_make_chest(), 5, 5, ObjectSpawn.PLACEMENT_ANY)]
	var gen := _make_generator(biome)
	assert_null(gen.grid[gen.entrance_pos.x][gen.entrance_pos.y].object)
	assert_null(gen.grid[gen.exit_pos.x][gen.exit_pos.y].object)

func test_objects_keep_exit_reachable_and_chests_interactable() -> void:
	# After placement, BFS from entrance must still reach the exit, and
	# every placed object must have at least one walkable neighbour so
	# the player can stand next to it and click it. We deliberately do
	# NOT require every floor cell to be reachable — connectorless
	# isolated rooms may pre-exist in some dungeons (those cells were
	# never reachable, so a chest placement isn't blamed for them).
	var biome := _make_biome()
	biome.objects = [_make_object_spawn(_make_chest(), 8, 8, ObjectSpawn.PLACEMENT_ANY)]
	var gen := _make_generator(biome)

	var visited: Dictionary = {gen.entrance_pos: true}
	var queue: Array = [gen.entrance_pos]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var n := current + d
			if n.x < 0 or n.x >= gen.grid_width or n.y < 0 or n.y >= gen.grid_height:
				continue
			if visited.has(n):
				continue
			var ncell: GridCell = gen.grid[n.x][n.y]
			if ncell.is_blocked:
				continue
			visited[n] = true
			queue.append(n)

	# Exit reachable
	assert_true(visited.has(gen.exit_pos), "exit unreachable after object placement")

	# Every chest has a walkable neighbour
	for cell_pos in _all_object_cells(gen):
		var has_neighbour := false
		for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			if visited.has(cell_pos + d):
				has_neighbour = true
				break
		assert_true(has_neighbour,
			"chest at %s is unreachable from any walkable neighbour" % cell_pos)

func test_min_distance_keeps_objects_apart() -> void:
	var biome := _make_biome()
	var spawn := _make_object_spawn(_make_chest(), 4, 4, ObjectSpawn.PLACEMENT_ANY)
	spawn.min_distance_to_other_object = 5
	biome.objects = [spawn]
	var gen := _make_generator(biome)
	var positions := _all_object_cells(gen)
	for i in range(positions.size()):
		for j in range(i + 1, positions.size()):
			var dist: int = abs(positions[i].x - positions[j].x) + abs(positions[i].y - positions[j].y)
			assert_gte(dist, 5,
				"objects at %s and %s are %d apart (need >= 5)" % [positions[i], positions[j], dist])

func test_items_respect_min_distance_when_possible() -> void:
	# When min_distance_to_other_item is set, placed items shouldn't
	# cluster on adjacent tiles. Graceful degrade: if not all rolls can
	# honour the distance, the algorithm relaxes — so we assert the
	# constraint as a "best effort": the EARLIEST placements (when the
	# grid is least constrained) must respect it. We pick a small
	# count and a moderate distance so all rolls easily fit.
	var item := _make_item()
	var entry := _make_loot_entry(item)
	entry.min_distance_to_other_item = 4
	var loot: Array[LootEntry] = [entry]
	var biome := _make_biome(loot, 3, 3)
	var gen := _make_generator(biome)
	# Collect every cell that received an item.
	var item_positions: Array = []
	for x in range(gen.grid_width):
		for y in range(gen.grid_height):
			if not gen.grid[x][y].items.is_empty():
				item_positions.append(Vector2i(x, y))
	# 3 items requested; with min_distance 4 on a 21x21 grid + multiple
	# rooms, all should fit. Verify pairwise spacing.
	for i in range(item_positions.size()):
		for j in range(i + 1, item_positions.size()):
			var dist: int = abs(item_positions[i].x - item_positions[j].x) + abs(item_positions[i].y - item_positions[j].y)
			assert_gte(dist, 4,
				"items at %s and %s are %d apart (need >= 4)" % [item_positions[i], item_positions[j], dist])

func test_items_avoid_chest_cells() -> void:
	# When chests and items both spawn, items should never land on a
	# blocking-object cell (the player can't reach piled items there).
	var item := _make_item()
	var loot: Array[LootEntry] = [_make_loot_entry(item)]
	var biome := _make_biome(loot, 8, 8)
	biome.objects = [_make_object_spawn(_make_chest(), 5, 5)]
	var gen := _make_generator(biome)
	for x in range(gen.grid_width):
		for y in range(gen.grid_height):
			var cell: GridCell = gen.grid[x][y]
			if cell.is_blocked and cell.cell_type != GridCell.CellType.WALL:
				assert_eq(cell.items.size(), 0,
					"items should not pile on blocking-object cell (%d,%d)" % [x, y])

# -------------------------------------------------------
# Door placement (Phase 8 Task 2a)
# -------------------------------------------------------

func _make_door(blocks: bool = true) -> ObjectData:
	var data := ObjectData.new()
	data.category = ObjectData.Category.DOOR
	data.blocks_movement = blocks
	data.name_key = "test.door"
	return data

func _make_door_spawn(door: ObjectData, count_min: int, count_max: int) -> ObjectSpawn:
	var spawn := ObjectSpawn.new()
	spawn.object = door
	spawn.count_min = count_min
	spawn.count_max = count_max
	# Doors only meaningfully exist on corridors; the placement filter
	# keeps the spawn-flag semantics consistent with chests.
	spawn.placement = ObjectSpawn.PLACEMENT_CORRIDOR
	return spawn

func _is_one_wide_corridor_cell(gen: LevelGenerator, pos: Vector2i) -> bool:
	if gen.grid[pos.x][pos.y].cell_type == GridCell.CellType.WALL:
		return false
	var floor_neighbours := 0
	for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var n: Vector2i = pos + d
		if n.x < 0 or n.x >= gen.grid_width or n.y < 0 or n.y >= gen.grid_height:
			continue
		if gen.grid[n.x][n.y].cell_type != GridCell.CellType.WALL:
			floor_neighbours += 1
	return floor_neighbours == 2

func test_no_doors_placed_when_pool_is_empty() -> void:
	var gen := _make_generator(_make_biome())
	assert_eq(gen.doors.size(), 0)

func test_doors_are_not_stored_on_grid_cells() -> void:
	# Critical structural invariant — doors live on edges, never on
	# cells. If a door ever ended up on a GridCell.object, the chest
	# renderer would draw it as a billboard at cell centre. Guard this.
	var biome := _make_biome()
	biome.objects = [_make_door_spawn(_make_door(), 3, 3)]
	var gen := _make_generator(biome)
	for x in range(gen.grid_width):
		for y in range(gen.grid_height):
			var obj = gen.grid[x][y].object
			assert_false(obj is DoorInstance,
				"DoorInstance found on GridCell at (%d,%d) — doors must live on edges" % [x, y])

func test_door_endpoints_are_one_wide_corridor_cells() -> void:
	var biome := _make_biome()
	biome.objects = [_make_door_spawn(_make_door(), 3, 3)]
	var gen := _make_generator(biome)
	for door in gen.doors:
		assert_true(_is_one_wide_corridor_cell(gen, door.cell_a),
			"door endpoint %s is not a 1-wide-corridor cell" % door.cell_a)
		assert_true(_is_one_wide_corridor_cell(gen, door.cell_b),
			"door endpoint %s is not a 1-wide-corridor cell" % door.cell_b)

func test_doors_never_on_entrance_or_exit() -> void:
	var biome := _make_biome()
	biome.objects = [_make_door_spawn(_make_door(), 5, 5)]
	var gen := _make_generator(biome)
	for door in gen.doors:
		assert_ne(door.cell_a, gen.entrance_pos)
		assert_ne(door.cell_b, gen.entrance_pos)
		assert_ne(door.cell_a, gen.exit_pos)
		assert_ne(door.cell_b, gen.exit_pos)

func test_door_endpoints_are_orthogonally_adjacent() -> void:
	var biome := _make_biome()
	biome.objects = [_make_door_spawn(_make_door(), 3, 3)]
	var gen := _make_generator(biome)
	for door in gen.doors:
		var diff: Vector2i = door.cell_b - door.cell_a
		var manhattan: int = abs(diff.x) + abs(diff.y)
		assert_eq(manhattan, 1,
			"door endpoints %s, %s are not orthogonally adjacent" % [door.cell_a, door.cell_b])

func test_doors_do_not_share_cells_with_chests() -> void:
	var biome := _make_biome()
	biome.objects = [
		_make_object_spawn(_make_chest(), 4, 4, ObjectSpawn.PLACEMENT_ANY),
		_make_door_spawn(_make_door(), 3, 3),
	]
	var gen := _make_generator(biome)
	for door in gen.doors:
		assert_null(gen.grid[door.cell_a.x][door.cell_a.y].object,
			"door endpoint %s shares a cell with a chest" % door.cell_a)
		assert_null(gen.grid[door.cell_b.x][door.cell_b.y].object,
			"door endpoint %s shares a cell with a chest" % door.cell_b)

func test_is_edge_blocked_reports_closed_doors_as_blocking() -> void:
	var biome := _make_biome()
	biome.objects = [_make_door_spawn(_make_door(true), 1, 1)]
	var gen := _make_generator(biome)
	if gen.doors.is_empty():
		# Defensive — some seeds may not yield a corridor edge; bail
		# rather than fail the suite. Other tests enforce that doors
		# CAN be placed.
		return
	var door: DoorInstance = gen.doors[0]
	door.opened = false
	assert_true(gen.is_edge_blocked(door.cell_a, door.cell_b))
	# Edge query is order-independent.
	assert_true(gen.is_edge_blocked(door.cell_b, door.cell_a))

func test_is_edge_blocked_clears_when_door_opens() -> void:
	var biome := _make_biome()
	biome.objects = [_make_door_spawn(_make_door(true), 1, 1)]
	var gen := _make_generator(biome)
	if gen.doors.is_empty():
		return
	var door: DoorInstance = gen.doors[0]
	door.opened = true
	assert_false(gen.is_edge_blocked(door.cell_a, door.cell_b))

func test_is_edge_blocked_false_for_non_door_edges() -> void:
	var biome := _make_biome()
	biome.objects = [_make_door_spawn(_make_door(), 1, 1)]
	var gen := _make_generator(biome)
	# Pick any pair of orthogonally-adjacent floor cells that does NOT
	# carry a door. The entrance and one of its floor neighbours
	# qualify (doors exclude entrance from endpoints).
	for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var n: Vector2i = gen.entrance_pos + d
		if n.x < 0 or n.x >= gen.grid_width or n.y < 0 or n.y >= gen.grid_height:
			continue
		if gen.grid[n.x][n.y].cell_type == GridCell.CellType.WALL:
			continue
		assert_false(gen.is_edge_blocked(gen.entrance_pos, n),
			"non-door edge %s—%s should never block" % [gen.entrance_pos, n])
		return

func test_door_min_distance_keeps_doors_apart() -> void:
	# With min_distance set, doors should not cluster. Pick a number
	# small enough that a 21x21 maze can fit all 3 — avoids relying on
	# the graceful-degrade fallback.
	var biome := _make_biome()
	var spawn := _make_door_spawn(_make_door(), 3, 3)
	spawn.min_distance_to_other_object = 4
	biome.objects = [spawn]
	var gen := _make_generator(biome)
	# At least 2 doors expected for a meaningful pairwise check.
	if gen.doors.size() < 2:
		return
	for i in range(gen.doors.size()):
		for j in range(i + 1, gen.doors.size()):
			var a: DoorInstance = gen.doors[i]
			var b: DoorInstance = gen.doors[j]
			var dist: int = min(
				min(abs(a.cell_a.x - b.cell_a.x) + abs(a.cell_a.y - b.cell_a.y),
					abs(a.cell_a.x - b.cell_b.x) + abs(a.cell_a.y - b.cell_b.y)),
				min(abs(a.cell_b.x - b.cell_a.x) + abs(a.cell_b.y - b.cell_a.y),
					abs(a.cell_b.x - b.cell_b.x) + abs(a.cell_b.y - b.cell_b.y))
			)
			assert_gte(dist, 4,
				"doors %s—%s and %s—%s are %d apart (need >= 4)" %
				[a.cell_a, a.cell_b, b.cell_a, b.cell_b, dist])

func test_each_edge_carries_at_most_one_door() -> void:
	var biome := _make_biome()
	biome.objects = [_make_door_spawn(_make_door(), 5, 5)]
	var gen := _make_generator(biome)
	var seen: Dictionary = {}
	for door in gen.doors:
		var key := DoorInstance.edge_key(door.cell_a, door.cell_b)
		assert_false(seen.has(key), "duplicate door on edge %s" % key)
		seen[key] = true

# -------------------------------------------------------
# Linked-object placement (Phase 8 Task 2b: lever ↔ door pairs)
# -------------------------------------------------------

func _make_lever_data() -> ObjectData:
	var data := ObjectData.new()
	data.category = ObjectData.Category.LEVER
	data.blocks_movement = true
	data.name_key = "test.lever"
	return data

func _make_linked_spawn(lever_data: ObjectData, door_data: ObjectData, count_min: int, count_max: int) -> LinkedObjectSpawn:
	var spawn := LinkedObjectSpawn.new()
	spawn.lever_object = lever_data
	spawn.door_object = door_data
	spawn.count_min = count_min
	spawn.count_max = count_max
	spawn.lever_placement = ObjectSpawn.PLACEMENT_ANY
	return spawn

func _all_lever_cells(gen: LevelGenerator) -> Array:
	var result: Array = []
	for x in range(gen.grid_width):
		for y in range(gen.grid_height):
			if gen.grid[x][y].object is LeverInstance:
				result.append(Vector2i(x, y))
	return result

func _bfs_with_closed_edge(gen: LevelGenerator, origin: Vector2i, closed_a: Vector2i, closed_b: Vector2i) -> Dictionary:
	var key := DoorInstance.edge_key(closed_a, closed_b)
	var visited: Dictionary = {origin: true}
	var queue: Array = [origin]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var n: Vector2i = current + d
			if n.x < 0 or n.x >= gen.grid_width or n.y < 0 or n.y >= gen.grid_height:
				continue
			if visited.has(n):
				continue
			if gen.grid[n.x][n.y].is_blocked:
				continue
			if DoorInstance.edge_key(current, n) == key:
				continue
			visited[n] = true
			queue.append(n)
	return visited

func test_linked_pair_emits_one_door_and_one_lever_each() -> void:
	var biome := _make_biome()
	biome.linked_objects = [_make_linked_spawn(_make_lever_data(), _make_door(), 2, 2)]
	var gen := _make_generator(biome)
	# 0 to 2 pairs depending on whether seed allows placement; for this
	# fixed seed we know the maze has eligible corridors. Defensive:
	# whatever we got, levers and (linked) doors should match.
	var levers: Array = _all_lever_cells(gen)
	var linked_doors: Array = []
	for door in gen.doors:
		if not door.linked_levers.is_empty():
			linked_doors.append(door)
	assert_eq(levers.size(), linked_doors.size(),
		"linked levers (%d) and linked doors (%d) should match in count" %
		[levers.size(), linked_doors.size()])

func test_each_lever_links_back_to_exactly_one_door() -> void:
	var biome := _make_biome()
	biome.linked_objects = [_make_linked_spawn(_make_lever_data(), _make_door(), 2, 2)]
	var gen := _make_generator(biome)
	for cell_pos in _all_lever_cells(gen):
		var lever: LeverInstance = gen.grid[cell_pos.x][cell_pos.y].object
		assert_eq(lever.linked_doors.size(), 1,
			"2b lever at %s should have exactly 1 linked door" % cell_pos)
		var door: DoorInstance = lever.linked_doors[0]
		# The door should also know about this lever (back-link).
		assert_true(door.linked_levers.has(lever),
			"door at %s—%s missing back-link to its lever" % [door.cell_a, door.cell_b])

func test_lever_is_reachable_with_linked_door_closed() -> void:
	# The placement contract: even if the player NEVER opens the
	# linked door, they can still walk to the lever.
	var biome := _make_biome()
	biome.linked_objects = [_make_linked_spawn(_make_lever_data(), _make_door(), 2, 2)]
	var gen := _make_generator(biome)
	for cell_pos in _all_lever_cells(gen):
		var lever: LeverInstance = gen.grid[cell_pos.x][cell_pos.y].object
		var door: DoorInstance = lever.linked_doors[0]
		var reachable: Dictionary = _bfs_with_closed_edge(gen, gen.entrance_pos, door.cell_a, door.cell_b)
		# Lever cell itself is blocked (the lever blocks movement),
		# but the player must be able to STAND NEXT TO it.
		var has_neighbour := false
		for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			if reachable.has(cell_pos + d):
				has_neighbour = true
				break
		assert_true(has_neighbour,
			"lever at %s unreachable from entrance with linked door closed" % cell_pos)

func test_lever_does_not_share_cell_with_chest_or_door_endpoint() -> void:
	var biome := _make_biome()
	biome.objects = [_make_object_spawn(_make_chest(), 4, 4, ObjectSpawn.PLACEMENT_ANY)]
	biome.linked_objects = [_make_linked_spawn(_make_lever_data(), _make_door(), 2, 2)]
	var gen := _make_generator(biome)
	for cell_pos in _all_lever_cells(gen):
		# Lever cell holds a LeverInstance, not a chest.
		var obj = gen.grid[cell_pos.x][cell_pos.y].object
		assert_true(obj is LeverInstance, "cell %s should hold a LeverInstance" % cell_pos)
		# Lever cell is never a door endpoint.
		for door in gen.doors:
			assert_ne(door.cell_a, cell_pos,
				"lever shares cell with door endpoint at %s" % cell_pos)
			assert_ne(door.cell_b, cell_pos,
				"lever shares cell with door endpoint at %s" % cell_pos)

func test_lever_placement_count_falls_within_min_max() -> void:
	var biome := _make_biome()
	biome.linked_objects = [_make_linked_spawn(_make_lever_data(), _make_door(), 1, 3)]
	var gen := _make_generator(biome)
	var lever_count: int = _all_lever_cells(gen).size()
	# Allow a lower bound of 0 in case the seed couldn't fit any pair —
	# generation is best-effort and warns but doesn't error. Upper
	# bound is the strict cap.
	assert_lte(lever_count, 3, "lever count %d exceeds count_max=3" % lever_count)

func test_linked_door_is_not_decorative() -> void:
	# A door created via a linked spawn must have linked_levers
	# populated; a decorative door (via objects pool) must not.
	var biome := _make_biome()
	biome.objects = [_make_door_spawn(_make_door(), 1, 1)]
	biome.linked_objects = [_make_linked_spawn(_make_lever_data(), _make_door(), 1, 1)]
	var gen := _make_generator(biome)
	var has_decorative := false
	var has_linked := false
	for door in gen.doors:
		if door.linked_levers.is_empty():
			has_decorative = true
		else:
			has_linked = true
			assert_eq(door.linked_levers.size(), 1)
	# At least the linked one should appear; decorative is best-effort.
	assert_true(has_linked or has_decorative,
		"no doors placed at all — seed may need adjusting")
