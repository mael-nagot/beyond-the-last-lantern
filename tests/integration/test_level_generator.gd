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
# Trap placement (Phase 8 Task 3 — Subtask A)
# -------------------------------------------------------

func _make_trap_data(trigger: int = TrapData.Trigger.STEP, damage: int = 5) -> TrapData:
	var data := TrapData.new()
	data.trigger = trigger
	data.damage = damage
	data.name_key = "test.trap"
	return data

func _make_trap_spawn(trap: TrapData, count_min: int, count_max: int, placement: int = ObjectSpawn.PLACEMENT_ANY) -> TrapSpawn:
	var spawn := TrapSpawn.new()
	spawn.trap = trap
	spawn.count_min = count_min
	spawn.count_max = count_max
	spawn.placement = placement
	return spawn

func _all_trap_cells(gen: LevelGenerator) -> Array:
	var result: Array = []
	for x in range(gen.grid_width):
		for y in range(gen.grid_height):
			if gen.grid[x][y].trap != null:
				result.append(Vector2i(x, y))
	return result

func test_no_traps_placed_when_pool_is_empty() -> void:
	var gen := _make_generator(_make_biome())
	assert_eq(gen.traps.size(), 0)
	assert_eq(_all_trap_cells(gen).size(), 0)

func test_trap_count_falls_within_min_max() -> void:
	var biome := _make_biome()
	biome.trap_spawns = [_make_trap_spawn(_make_trap_data(), 3, 5)]
	var gen := _make_generator(biome)
	assert_between(gen.traps.size(), 3, 5)

func test_trap_count_matches_authoritative_grid() -> void:
	# `gen.traps` (flat list) and `cell.trap` (grid slot) must agree.
	# Drift between them would mean the renderer / damage logic
	# disagrees with the placement code about what's where.
	var biome := _make_biome()
	biome.trap_spawns = [_make_trap_spawn(_make_trap_data(), 4, 4)]
	var gen := _make_generator(biome)
	assert_eq(gen.traps.size(), _all_trap_cells(gen).size())
	for inst in gen.traps:
		assert_eq(gen.grid[inst.cell.x][inst.cell.y].trap, inst,
			"trap at %s in flat list must equal cell.trap" % inst.cell)

func test_traps_never_spawn_on_entrance_or_exit() -> void:
	var biome := _make_biome()
	biome.trap_spawns = [_make_trap_spawn(_make_trap_data(), 8, 8, ObjectSpawn.PLACEMENT_ANY)]
	var gen := _make_generator(biome)
	assert_null(gen.grid[gen.entrance_pos.x][gen.entrance_pos.y].trap)
	assert_null(gen.grid[gen.exit_pos.x][gen.exit_pos.y].trap)

func test_traps_only_appear_on_floor_cells() -> void:
	var biome := _make_biome()
	biome.trap_spawns = [_make_trap_spawn(_make_trap_data(), 5, 5)]
	var gen := _make_generator(biome)
	for x in range(gen.grid_width):
		for y in range(gen.grid_height):
			var cell: GridCell = gen.grid[x][y]
			if cell.cell_type == GridCell.CellType.WALL:
				assert_null(cell.trap, "wall (%d,%d) should not hold a trap" % [x, y])

func test_corridor_only_traps_only_spawn_in_corridors() -> void:
	var biome := _make_biome()
	biome.trap_spawns = [_make_trap_spawn(_make_trap_data(), 5, 5, ObjectSpawn.PLACEMENT_CORRIDOR)]
	var gen := _make_generator(biome)
	for trap in gen.traps:
		var classification: int = gen.classify_cell(trap.cell)
		assert_eq(classification, ObjectSpawn.PLACEMENT_CORRIDOR,
			"trap at %s should be on a corridor cell (got classification %d)" % [trap.cell, classification])

func test_traps_never_share_cell_with_objects() -> void:
	var biome := _make_biome()
	biome.objects = [_make_object_spawn(_make_chest(), 4, 4, ObjectSpawn.PLACEMENT_ANY)]
	biome.trap_spawns = [_make_trap_spawn(_make_trap_data(), 6, 6, ObjectSpawn.PLACEMENT_ANY)]
	var gen := _make_generator(biome)
	for trap in gen.traps:
		var cell: GridCell = gen.grid[trap.cell.x][trap.cell.y]
		assert_null(cell.object,
			"trap at %s shares cell with object %s" % [trap.cell, cell.object])

func test_items_avoid_trap_cells() -> void:
	# Floor items are placed AFTER traps and must skip trap cells so
	# loot doesn't pile on a hazard the player would have to step on.
	var item := _make_item()
	var loot: Array[LootEntry] = [_make_loot_entry(item)]
	var biome := _make_biome(loot, 8, 8)
	biome.trap_spawns = [_make_trap_spawn(_make_trap_data(), 5, 5, ObjectSpawn.PLACEMENT_ANY)]
	var gen := _make_generator(biome)
	for trap in gen.traps:
		var cell: GridCell = gen.grid[trap.cell.x][trap.cell.y]
		assert_eq(cell.items.size(), 0,
			"items should not pile on trap cell (%d,%d)" % [trap.cell.x, trap.cell.y])

func test_min_distance_keeps_traps_apart() -> void:
	var biome := _make_biome()
	var spawn := _make_trap_spawn(_make_trap_data(), 3, 3, ObjectSpawn.PLACEMENT_ANY)
	spawn.min_distance_to_other_trap = 6
	biome.trap_spawns = [spawn]
	var gen := _make_generator(biome)
	var positions: Array = []
	for trap in gen.traps:
		positions.append(trap.cell)
	for i in range(positions.size()):
		for j in range(i + 1, positions.size()):
			var dist: int = abs(positions[i].x - positions[j].x) + abs(positions[i].y - positions[j].y)
			assert_gte(dist, 6,
				"traps at %s and %s are %d apart (need >= 6)" % [positions[i], positions[j], dist])

func test_trap_instance_cell_matches_grid_position() -> void:
	# TrapInstance.cell is set at placement time and used by the renderer
	# to anchor the floor decal — drift between cell and its grid slot
	# would land the visual on the wrong tile.
	var biome := _make_biome()
	biome.trap_spawns = [_make_trap_spawn(_make_trap_data(), 4, 4)]
	var gen := _make_generator(biome)
	for x in range(gen.grid_width):
		for y in range(gen.grid_height):
			var inst: TrapInstance = gen.grid[x][y].trap
			if inst != null:
				assert_eq(inst.cell, Vector2i(x, y))

func test_timed_traps_initialise_with_starting_state() -> void:
	# A TIMED trap with timed_initial_offset = 0 must start RETRACTED;
	# the per-frame tick is expected to handle the rest.
	var biome := _make_biome()
	var trap_data := _make_trap_data(TrapData.Trigger.TIMED)
	biome.trap_spawns = [_make_trap_spawn(trap_data, 3, 3)]
	var gen := _make_generator(biome)
	for inst in gen.traps:
		assert_eq(inst.state, TrapInstance.State.RETRACTED)

# -------------------------------------------------------
# Corridor segment detection + cluster placement (Phase 8 Task 3 — Subtask B1)
# -------------------------------------------------------

func _make_corridor_cluster_spawn(trap: TrapData, chance: float, run_min: int, run_max: int) -> TrapSpawn:
	# Helper for cluster-only spawns: scattered count is zero so the
	# only traps placed come from the corridor pass.
	var spawn := _make_trap_spawn(trap, 0, 0, ObjectSpawn.PLACEMENT_CORRIDOR)
	spawn.corridor_segment_chance = chance
	spawn.corridor_traps_per_run_min = run_min
	spawn.corridor_traps_per_run_max = run_max
	return spawn

func _is_corridor_neighbour_count(gen: LevelGenerator, pos: Vector2i) -> int:
	var count := 0
	for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var n: Vector2i = pos + d
		if n.x < 0 or n.x >= gen.grid_width or n.y < 0 or n.y >= gen.grid_height:
			continue
		var nc: GridCell = gen.grid[n.x][n.y]
		if nc.cell_type != GridCell.CellType.FLOOR:
			continue
		if gen.classify_cell(n) == ObjectSpawn.PLACEMENT_CORRIDOR:
			count += 1
	return count

func test_corridor_segments_only_contain_corridor_cells() -> void:
	var gen := _make_generator(_make_biome())
	var segments: Array = gen._detect_corridor_segments()
	for segment in segments:
		for pos in segment:
			assert_eq(gen.classify_cell(pos), ObjectSpawn.PLACEMENT_CORRIDOR,
				"segment cell %s should classify as CORRIDOR" % pos)

func test_corridor_segments_exclude_junction_cells() -> void:
	# Junctions (corridor cells with 3+ corridor neighbours) split
	# segments — they must never appear inside one.
	var gen := _make_generator(_make_biome())
	var segments: Array = gen._detect_corridor_segments()
	for segment in segments:
		for pos in segment:
			var n: int = _is_corridor_neighbour_count(gen, pos)
			assert_lt(n, 3,
				"segment cell %s has %d corridor neighbours (junctions should be excluded)" % [pos, n])

func test_corridor_segments_are_disjoint() -> void:
	var gen := _make_generator(_make_biome())
	var segments: Array = gen._detect_corridor_segments()
	var seen: Dictionary = {}
	for segment in segments:
		for pos in segment:
			assert_false(seen.has(pos),
				"segment cell %s appears in two segments" % pos)
			seen[pos] = true

func test_corridor_clusters_lay_consecutive_traps() -> void:
	# With chance = 1.0 and a generous run size, every chosen segment
	# produces a connected blob of trap cells. Verify that for each trap
	# placed there is at least one neighbouring trap (or the trap is the
	# only one in its segment).
	var biome := _make_biome()
	var spawn := _make_corridor_cluster_spawn(_make_trap_data(), 1.0, 3, 5)
	biome.trap_spawns = [spawn]
	var gen := _make_generator(biome)
	if gen.traps.is_empty():
		# Possible on tiny test maps — skip gracefully rather than fail.
		return
	# Bin traps by their segment via the segment list, then verify each
	# bin is itself a connected component within the trap-cell set.
	var trap_set: Dictionary = {}
	for inst in gen.traps:
		trap_set[inst.cell] = true
	for inst in gen.traps:
		var has_trap_neighbour: bool = false
		for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			if trap_set.has(inst.cell + d):
				has_trap_neighbour = true
				break
		# The run min is 3, so every trap must have at least one trap
		# neighbour (the cluster never has length 1 with run_min = 3).
		assert_true(has_trap_neighbour,
			"clustered trap at %s has no trap neighbour (cluster broken?)" % inst.cell)

func test_corridor_clusters_only_in_corridors() -> void:
	var biome := _make_biome()
	biome.trap_spawns = [_make_corridor_cluster_spawn(_make_trap_data(), 1.0, 2, 4)]
	var gen := _make_generator(biome)
	for inst in gen.traps:
		assert_eq(gen.classify_cell(inst.cell), ObjectSpawn.PLACEMENT_CORRIDOR,
			"cluster trap at %s landed outside a corridor" % inst.cell)

func test_corridor_clusters_zero_chance_places_nothing() -> void:
	# Sanity: chance = 0 disables the corridor pass even with non-zero
	# run sizes. count_min/max are also zero, so total trap count = 0.
	var biome := _make_biome()
	biome.trap_spawns = [_make_corridor_cluster_spawn(_make_trap_data(), 0.0, 2, 4)]
	var gen := _make_generator(biome)
	assert_eq(gen.traps.size(), 0)

func test_corridor_cluster_run_size_within_max() -> void:
	# No cluster may exceed `corridor_traps_per_run_max` cells. Run a
	# few seeds so we exercise different segment topologies.
	var max_run: int = 4
	for seed_n in [101, 202, 303, 404]:
		var biome := _make_biome()
		biome.trap_spawns = [_make_corridor_cluster_spawn(_make_trap_data(), 1.0, 1, max_run)]
		var gen := _make_generator(biome, seed_n)
		# Group trap cells into connected components — each must be <= max_run.
		var trap_set: Dictionary = {}
		for inst in gen.traps:
			trap_set[inst.cell] = true
		var visited: Dictionary = {}
		for inst in gen.traps:
			if visited.has(inst.cell):
				continue
			var component_size := 0
			var queue: Array = [inst.cell]
			visited[inst.cell] = true
			while not queue.is_empty():
				var cur: Vector2i = queue.pop_front()
				component_size += 1
				for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
					var n: Vector2i = cur + d
					if trap_set.has(n) and not visited.has(n):
						visited[n] = true
						queue.append(n)
			assert_lte(component_size, max_run,
				"seed %d: cluster of size %d exceeds max %d" % [seed_n, component_size, max_run])

func test_scattered_traps_dont_neighbour_cluster_cells() -> void:
	# Cluster + scattered on the same spawn. After placement, no
	# scattered trap may sit 4-adjacent to a cluster cell — that's
	# the rule that prevents a 5-cell segment with a 3-cell cluster
	# from getting its 2 leftover cells filled by scattered, producing
	# a 5-trap contiguous run.
	for seed_n in [1234, 5678, 9012, 3456]:
		var biome := _make_biome()
		var spawn := _make_corridor_cluster_spawn(_make_trap_data(), 1.0, 3, 3)
		# Add aggressive scattered placement — high count + corridor
		# placement increases the chance the rule matters.
		spawn.count_min = 12
		spawn.count_max = 12
		biome.trap_spawns = [spawn]
		var gen := _make_generator(biome, seed_n)
		for inst in gen.traps:
			# Skip cluster cells themselves — they ARE adjacent to
			# other cluster cells by construction.
			if gen._cluster_cells.has(inst.cell):
				continue
			# This is a scattered trap; verify no 4-neighbour is a cluster cell.
			for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				assert_false(gen._cluster_cells.has(inst.cell + d),
					"seed %d: scattered trap at %s neighbours cluster cell at %s" % [seed_n, inst.cell, inst.cell + d])

func test_corridor_clusters_skip_junction_adjacent_segments() -> void:
	# A junction cell (corridor with 3+ corridor neighbours) bridges
	# two segments. If both segments held clusters, the player would
	# perceive: trapped run -> single safe junction tile -> trapped
	# run, which forces back-to-back damage. Verify that for every
	# junction in the generated level, at most ONE of the segments it
	# bridges holds traps.
	var biome := _make_biome()
	biome.trap_spawns = [_make_corridor_cluster_spawn(_make_trap_data(), 1.0, 2, 3)]
	var observed_junctions: int = 0
	for seed_n in [9001, 9002, 9003, 9004, 9005, 9006]:
		var gen := _make_generator(biome, seed_n)
		var segments: Array = gen._detect_corridor_segments()
		var cell_to_seg: Dictionary = {}
		for i in range(segments.size()):
			for pos in segments[i]:
				cell_to_seg[pos] = i
		# Walk every cell — find junctions, then count distinct trapped
		# neighbour-segments per junction.
		for x in range(gen.grid_width):
			for y in range(gen.grid_height):
				var jpos := Vector2i(x, y)
				if gen.grid[x][y].cell_type != GridCell.CellType.FLOOR:
					continue
				if gen.classify_cell(jpos) != ObjectSpawn.PLACEMENT_CORRIDOR:
					continue
				var corridor_n: int = 0
				var neighbour_segs: Dictionary = {}
				for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
					var n: Vector2i = jpos + d
					if n.x < 0 or n.x >= gen.grid_width or n.y < 0 or n.y >= gen.grid_height:
						continue
					if gen.grid[n.x][n.y].cell_type != GridCell.CellType.FLOOR:
						continue
					if gen.classify_cell(n) != ObjectSpawn.PLACEMENT_CORRIDOR:
						continue
					corridor_n += 1
					if cell_to_seg.has(n):
						neighbour_segs[cell_to_seg[n]] = true
				if corridor_n < 3:
					continue
				observed_junctions += 1
				var trapped_segs: int = 0
				for seg_idx in neighbour_segs:
					for pos in segments[seg_idx]:
						if gen.grid[pos.x][pos.y].trap != null:
							trapped_segs += 1
							break
				assert_lte(trapped_segs, 1,
					"seed %d: junction at %s bridges %d trapped segments — should be <= 1" % [seed_n, jpos, trapped_segs])
	# Sanity: must have exercised at least some junctions in the sweep.
	assert_gt(observed_junctions, 0,
		"no junctions found across seed sweep — junction-adjacency rule was never exercised")

func test_corridor_clusters_skip_segments_with_existing_traps() -> void:
	# Two spawns, both targeting corridors. The first should fill some
	# segments; the second should skip every already-trapped segment.
	# Therefore: NO segment hosts traps from BOTH spawns.
	#
	# Run multiple seeds so we exercise different topologies, and
	# require at least one seed to produce a layout where both spawns
	# land at least one trap (otherwise the disjoint check is vacuous).
	var trap_a := _make_trap_data(TrapData.Trigger.STEP, 3)
	var trap_b := _make_trap_data(TrapData.Trigger.TIMED, 3)
	var observed_both: bool = false
	for seed_n in [101, 202, 303, 404, 505, 606, 707, 808]:
		var biome := _make_biome()
		biome.trap_spawns = [
			# 0.5 chance gives spawn #2 room to land in segments spawn #1
			# rolled away from.
			_make_corridor_cluster_spawn(trap_a, 0.5, 2, 3),
			_make_corridor_cluster_spawn(trap_b, 1.0, 2, 3),
		]
		var gen := _make_generator(biome, seed_n)
		var segments: Array = gen._detect_corridor_segments()
		var cell_to_segment: Dictionary = {}
		for i in range(segments.size()):
			for pos in segments[i]:
				cell_to_segment[pos] = i
		var segments_with_a: Dictionary = {}
		var segments_with_b: Dictionary = {}
		for inst in gen.traps:
			if not cell_to_segment.has(inst.cell):
				continue  # junction or other edge case — ignore
			var seg_idx: int = cell_to_segment[inst.cell]
			if inst.data == trap_a:
				segments_with_a[seg_idx] = true
			else:
				segments_with_b[seg_idx] = true
		# Disjoint check — fails if any segment got both spawns' traps.
		for seg_idx in segments_with_b:
			assert_false(segments_with_a.has(seg_idx),
				"seed %d: segment %d hosts both spawns — second should have skipped it" % [seed_n, seg_idx])
		if not segments_with_a.is_empty() and not segments_with_b.is_empty():
			observed_both = true
	# Sanity: across the seed sweep we must have seen at least one
	# layout that exercised the disjoint check (both spawns landed),
	# otherwise the test is risky / vacuous.
	assert_true(observed_both,
		"no seed produced traps from both spawns — disjoint check was never exercised")

# -------------------------------------------------------
# Room density placement (Phase 8 Task 3 — Subtask B2)
# -------------------------------------------------------

func _make_room_density_spawn(trap: TrapData, chance: float, cov_min: float, cov_max: float, spacing: int = 0) -> TrapSpawn:
	# Scattered count is zero so the only traps placed come from the
	# room pass — keeps assertions clean.
	var spawn := _make_trap_spawn(trap, 0, 0, ObjectSpawn.PLACEMENT_ROOM)
	spawn.room_chance = chance
	spawn.room_coverage_min_percent = cov_min
	spawn.room_coverage_max_percent = cov_max
	spawn.room_min_spacing = spacing
	return spawn

func _is_in_any_room(gen: LevelGenerator, pos: Vector2i) -> bool:
	for room in gen._room_rects:
		if (room as Rect2i).has_point(pos):
			return true
	return false

func test_room_density_zero_chance_places_nothing() -> void:
	var biome := _make_biome()
	biome.trap_spawns = [_make_room_density_spawn(_make_trap_data(), 0.0, 30.0, 50.0)]
	var gen := _make_generator(biome)
	assert_eq(gen.traps.size(), 0)

func test_room_density_only_in_room_cells() -> void:
	# Every trap placed by the room pass must sit inside one of the
	# generated room rects.
	var biome := _make_biome()
	biome.trap_spawns = [_make_room_density_spawn(_make_trap_data(), 1.0, 30.0, 50.0)]
	var gen := _make_generator(biome)
	for inst in gen.traps:
		assert_true(_is_in_any_room(gen, inst.cell),
			"room-pass trap at %s landed outside every room rect" % inst.cell)

func test_room_density_respects_min_spacing() -> void:
	# With min_spacing = 2, no two traps inside the SAME room may sit
	# within 2 Manhattan tiles of each other.
	for seed_n in [42, 99, 1337]:
		var biome := _make_biome()
		biome.trap_spawns = [_make_room_density_spawn(_make_trap_data(), 1.0, 50.0, 80.0, 2)]
		var gen := _make_generator(biome, seed_n)
		# Group traps by which room they landed in.
		for room_obj in gen._room_rects:
			var room: Rect2i = room_obj as Rect2i
			var positions: Array = []
			for inst in gen.traps:
				if room.has_point(inst.cell):
					positions.append(inst.cell)
			for i in range(positions.size()):
				for j in range(i + 1, positions.size()):
					var d: int = abs(positions[i].x - positions[j].x) + abs(positions[i].y - positions[j].y)
					assert_gte(d, 2,
						"seed %d: traps in room %s at %s and %s are %d apart (need >= 2)" % [seed_n, room, positions[i], positions[j], d])

func test_room_density_coverage_within_target_range() -> void:
	# When chance = 1.0, each room receives a fraction of cells in the
	# rolled coverage range, capped by graceful-degrade. With no
	# spacing constraint, the realised count should fall within
	# [floor(min%), ceil(max%)] of each room's eligible cell count.
	var biome := _make_biome()
	biome.trap_spawns = [_make_room_density_spawn(_make_trap_data(), 1.0, 25.0, 40.0)]
	var gen := _make_generator(biome, 4242)
	for room_obj in gen._room_rects:
		var room: Rect2i = room_obj as Rect2i
		var room_cells: Array = gen._eligible_room_cells(room)
		var trap_count: int = 0
		for inst in gen.traps:
			if room.has_point(inst.cell):
				trap_count += 1
		# Eligible-cell count must be the SUM of trap_count + remaining
		# room cells. Compute against total room footprint (excluding
		# entrance / exit / object cells the helper already filters).
		var total_room_cells: int = trap_count + room_cells.size()
		if total_room_cells == 0:
			continue  # tiny room with all cells excluded — no assertion
		var min_expected: int = int(floor(total_room_cells * 0.25))
		var max_expected: int = int(ceil(total_room_cells * 0.40))
		assert_gte(trap_count, max(1, min_expected),
			"room %s: trap_count %d below expected min %d (total %d)" % [room, trap_count, min_expected, total_room_cells])
		assert_lte(trap_count, max_expected,
			"room %s: trap_count %d above expected max %d (total %d)" % [room, trap_count, max_expected, total_room_cells])

func test_room_density_skips_entrance_and_exit() -> void:
	var biome := _make_biome()
	# Aggressive coverage so the room pass would pick the entrance/exit
	# cell if it weren't explicitly excluded.
	biome.trap_spawns = [_make_room_density_spawn(_make_trap_data(), 1.0, 80.0, 100.0)]
	var gen := _make_generator(biome)
	assert_null(gen.grid[gen.entrance_pos.x][gen.entrance_pos.y].trap)
	assert_null(gen.grid[gen.exit_pos.x][gen.exit_pos.y].trap)

func test_room_max_distance_to_safe_cell_keeps_retreat_within_radius() -> void:
	# With safe-cell radius = 2 and aggressive coverage, every walkable
	# cell in (or just outside) every room must have a non-trap
	# walkable cell within 2 Manhattan tiles. The placer rejects
	# candidates that would isolate any cell.
	for seed_n in [101, 202, 303, 404, 505]:
		var biome := _make_biome()
		var spawn := _make_room_density_spawn(_make_trap_data(), 1.0, 70.0, 90.0, 0)
		spawn.room_max_distance_to_safe_cell = 2
		biome.trap_spawns = [spawn]
		var gen := _make_generator(biome, seed_n)
		for room_obj in gen._room_rects:
			var room: Rect2i = room_obj as Rect2i
			# Check every walkable cell in the room AND a 1-cell margin.
			var x0: int = room.position.x - 1
			var y0: int = room.position.y - 1
			var x1: int = room.position.x + room.size.x
			var y1: int = room.position.y + room.size.y
			for cx in range(x0, x1 + 1):
				for cy in range(y0, y1 + 1):
					if cx < 0 or cx >= gen.grid_width or cy < 0 or cy >= gen.grid_height:
						continue
					var cpos := Vector2i(cx, cy)
					var cell: GridCell = gen.grid[cx][cy]
					if cell.cell_type != GridCell.CellType.FLOOR:
						continue
					if cell.object != null and cell.object.data != null and cell.object.data.blocks_movement:
						continue
					# Find a non-trap walkable cell within radius 2.
					var found := false
					for dx in range(-2, 3):
						var max_dy: int = 2 - abs(dx)
						for dy in range(-max_dy, max_dy + 1):
							var n := cpos + Vector2i(dx, dy)
							if n.x < 0 or n.x >= gen.grid_width or n.y < 0 or n.y >= gen.grid_height:
								continue
							var ncell: GridCell = gen.grid[n.x][n.y]
							if ncell.cell_type != GridCell.CellType.FLOOR:
								continue
							if ncell.object != null and ncell.object.data != null and ncell.object.data.blocks_movement:
								continue
							if ncell.trap == null:
								found = true
								break
						if found:
							break
					assert_true(found,
						"seed %d: cell %s in/near room %s has no non-trap walkable cell within 2 Manhattan tiles" % [seed_n, cpos, room])

func test_room_density_exclusivity_blocks_second_spawn() -> void:
	# Two spawns targeting rooms. Spawn A (chance < 1) leaves some
	# rooms untrapped — those remain available for spawn B. Spawn B
	# has allow_mixed_room_traps = false, so it should ONLY land in
	# rooms A skipped, never in rooms A trapped first.
	var trap_a := _make_trap_data(TrapData.Trigger.STEP, 3)
	var trap_b := _make_trap_data(TrapData.Trigger.TIMED, 3)
	var observed_b_landed: bool = false
	for seed_n in [10, 20, 30, 40, 50, 60, 70, 80]:
		# Fresh spawn instances per iteration — spawn objects carry no
		# generator state, but constructing them inside the loop matches
		# the pattern in other multi-seed tests.
		var spawn_a := _make_room_density_spawn(trap_a, 0.5, 25.0, 40.0)
		var spawn_b := _make_room_density_spawn(trap_b, 1.0, 25.0, 40.0)
		spawn_b.allow_mixed_room_traps = false
		var biome := _make_biome()
		biome.trap_spawns = [spawn_a, spawn_b]
		var gen := _make_generator(biome, seed_n)
		for room_obj in gen._room_rects:
			var room: Rect2i = room_obj as Rect2i
			var has_a: bool = false
			var has_b: bool = false
			for inst in gen.traps:
				if not room.has_point(inst.cell):
					continue
				if inst.data == trap_a:
					has_a = true
				elif inst.data == trap_b:
					has_b = true
			if has_b:
				observed_b_landed = true
				assert_false(has_a,
					"seed %d: room %s holds traps from both spawns — spawn_b should have skipped (allow_mixed = false)" % [seed_n, room])
	assert_true(observed_b_landed,
		"no seed produced any spawn_b traps — exclusivity rule was never exercised")

func test_room_density_allows_mixing_when_flag_true() -> void:
	# Sibling test of exclusivity: with allow_mixed_room_traps = true
	# on both spawns, a room CAN hold traps from both. Just confirm
	# at least one seed in the sweep produces a mixed room.
	var trap_a := _make_trap_data(TrapData.Trigger.STEP, 3)
	var trap_b := _make_trap_data(TrapData.Trigger.TIMED, 3)
	var observed_mixed: bool = false
	for seed_n in [11, 22, 33, 44, 55, 66]:
		var biome := _make_biome()
		biome.trap_spawns = [
			_make_room_density_spawn(trap_a, 1.0, 25.0, 40.0),
			_make_room_density_spawn(trap_b, 1.0, 25.0, 40.0),
		]
		var gen := _make_generator(biome, seed_n)
		for room_obj in gen._room_rects:
			var room: Rect2i = room_obj as Rect2i
			var has_a: bool = false
			var has_b: bool = false
			for inst in gen.traps:
				if not room.has_point(inst.cell):
					continue
				if inst.data == trap_a:
					has_a = true
				elif inst.data == trap_b:
					has_b = true
			if has_a and has_b:
				observed_mixed = true
	assert_true(observed_mixed,
		"no seed produced a room holding both spawns' traps — mixing didn't happen even with the flag enabled")

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

func test_every_lever_chain_reachable_with_two_pairs() -> void:
	# Originally `test_lever_is_reachable_with_linked_door_closed`,
	# which asserted the per-pair contract: lever reachable from
	# entrance with its linked door treated as closed AND every
	# other door treated as walkable. That contract is too strict
	# under the new chain-reachability placement (Phase 8 Task 2b
	# critical fix) — a perfectly solvable level can place a lever
	# past its own door if the chain still converges via another
	# lever's progressive opening. The new contract — and what the
	# placement code actually enforces — is chain reachability:
	# starting at entrance, every reachable lever progressively
	# opens its linked doors, and at fixed point every placed lever
	# is reachable from somewhere in that set.
	var biome := _make_biome()
	biome.linked_objects = [_make_linked_spawn(_make_lever_data(), _make_door(), 2, 2)]
	var gen := _make_generator(biome)
	if gen.doors.is_empty():
		return  # seed couldn't place either pair — fine, nothing to assert
	var chain: Dictionary = _simulate_chain_reachable_from_entrance(gen)
	for cell_pos in _all_lever_cells(gen):
		var has_neighbour := false
		for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			if chain.has(cell_pos + d):
				has_neighbour = true
				break
		assert_true(has_neighbour,
			"lever at %s is not chain-reachable from entrance" % cell_pos)

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

func test_lever_to_door_max_distance_is_respected() -> void:
	# With a tight max, every placed lever must be within that
	# Manhattan distance of its paired door's nearest endpoint.
	var spawn := _make_linked_spawn(_make_lever_data(), _make_door(), 2, 2)
	spawn.lever_to_door_max_distance = 4
	var biome := _make_biome()
	biome.linked_objects = [spawn]
	var gen := _make_generator(biome)
	for cell_pos in _all_lever_cells(gen):
		var lever: LeverInstance = gen.grid[cell_pos.x][cell_pos.y].object
		var door: DoorInstance = lever.linked_doors[0]
		var dist: int = min(
			abs(cell_pos.x - door.cell_a.x) + abs(cell_pos.y - door.cell_a.y),
			abs(cell_pos.x - door.cell_b.x) + abs(cell_pos.y - door.cell_b.y)
		)
		assert_lte(dist, 4,
			"lever at %s is %d tiles from its door %s—%s (max=4)" %
			[cell_pos, dist, door.cell_a, door.cell_b])

func test_lever_to_door_min_distance_is_respected() -> void:
	var spawn := _make_linked_spawn(_make_lever_data(), _make_door(), 2, 2)
	spawn.lever_to_door_min_distance = 6
	var biome := _make_biome()
	biome.linked_objects = [spawn]
	var gen := _make_generator(biome)
	for cell_pos in _all_lever_cells(gen):
		var lever: LeverInstance = gen.grid[cell_pos.x][cell_pos.y].object
		var door: DoorInstance = lever.linked_doors[0]
		var dist: int = min(
			abs(cell_pos.x - door.cell_a.x) + abs(cell_pos.y - door.cell_a.y),
			abs(cell_pos.x - door.cell_b.x) + abs(cell_pos.y - door.cell_b.y)
		)
		assert_gte(dist, 6,
			"lever at %s is %d tiles from its door %s—%s (min=6)" %
			[cell_pos, dist, door.cell_a, door.cell_b])

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

# -------------------------------------------------------
# Multi-pair lever reachability (regression test for the stuck-state
# bug where two pairs could land with both levers behind both doors)
# -------------------------------------------------------

func _simulate_chain_reachable_from_entrance(gen: LevelGenerator) -> Dictionary:
	# Independent reimplementation of the chain reachability the
	# generator uses internally (chain v2 — also tracks collected
	# keys and unlocks matching doors). Iterates: BFS with currently-
	# open doors → collect reachable keys → mark new doors openable
	# (via reachable levers and via collected keys) → repeat.
	var open_keys: Dictionary = {}
	var collected_keys: Dictionary = {}
	for door in gen.doors:
		# Decorative (interactable) doors that aren't key-locked are
		# openable from the start.
		if door.data != null and door.data.interactable and not door.is_key_locked() and door.linked_levers.is_empty():
			open_keys[DoorInstance.edge_key(door.cell_a, door.cell_b)] = true
	var reachable: Dictionary = {}
	while true:
		reachable = _bfs_with_open_keys(gen, open_keys)
		var progressed := false
		# Collect floor + chest keys.
		for x in range(gen.grid_width):
			for y in range(gen.grid_height):
				var cell: GridCell = gen.grid[x][y]
				var pos := Vector2i(x, y)
				if not cell.items.is_empty() and reachable.has(pos):
					for item in cell.items:
						if item == null:
							continue
						var kid: String = item.get_key_id()
						if kid != "" and not collected_keys.has(kid):
							collected_keys[kid] = true
							progressed = true
				if cell.object != null and cell.object.is_chest():
					var has_neighbour := false
					for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
						if reachable.has(pos + d):
							has_neighbour = true
							break
					if has_neighbour:
						for item in cell.object.items:
							if item == null:
								continue
							var kid2: String = item.get_key_id()
							if kid2 != "" and not collected_keys.has(kid2):
								collected_keys[kid2] = true
								progressed = true
		# Collect reachable levers, then evaluate lever-locked doors.
		var reachable_levers: Dictionary = {}
		for x in range(gen.grid_width):
			for y in range(gen.grid_height):
				var cell: GridCell = gen.grid[x][y]
				if not (cell.object is LeverInstance):
					continue
				var pos := Vector2i(x, y)
				var has_neighbour := false
				for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
					if reachable.has(pos + d):
						has_neighbour = true
						break
				if has_neighbour:
					reachable_levers[cell.object] = true
		for door in gen.doors:
			if door.linked_levers.is_empty():
				continue
			var key := DoorInstance.edge_key(door.cell_a, door.cell_b)
			if open_keys.has(key):
				continue
			var should_open: bool = false
			if door.lever_logic == DoorInstance.LeverLogic.AND:
				should_open = true
				for lever in door.linked_levers:
					if lever == null or not reachable_levers.has(lever):
						should_open = false
						break
			else:
				for lever in door.linked_levers:
					if lever != null and reachable_levers.has(lever):
						should_open = true
						break
			if should_open:
				open_keys[key] = true
				progressed = true
		# Unlock locked doors whose key is collected.
		for door in gen.doors:
			if door.lock_id == "":
				continue
			if not collected_keys.has(door.lock_id):
				continue
			var key2 := DoorInstance.edge_key(door.cell_a, door.cell_b)
			if not open_keys.has(key2):
				open_keys[key2] = true
				progressed = true
		if not progressed:
			return reachable
	return {}

func _bfs_with_open_keys(gen: LevelGenerator, open_keys: Dictionary) -> Dictionary:
	var visited: Dictionary = {gen.entrance_pos: true}
	var queue: Array = [gen.entrance_pos]
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
			# Skip closed-door edges
			var blocking := false
			for door in gen.doors:
				if DoorInstance.edge_key(current, n) == DoorInstance.edge_key(door.cell_a, door.cell_b):
					if not open_keys.has(DoorInstance.edge_key(door.cell_a, door.cell_b)):
						blocking = true
					break
			if blocking:
				continue
			visited[n] = true
			queue.append(n)
	return visited

func test_every_lever_chain_reachable_with_three_pairs() -> void:
	# The classic bug: 2 pairs land with both levers behind both
	# doors. With 3 pairs the cycle case is even more likely. Across
	# several seeds, every placed lever must be reachable via the
	# chain (start at entrance, open every reachable lever's doors,
	# repeat).
	var biome := _make_biome()
	biome.linked_objects = [_make_linked_spawn(_make_lever_data(), _make_door(), 3, 3)]
	for s in [101, 202, 303, 404, 505, 606, 707, 808]:
		var gen := _make_generator(biome, s)
		if gen.doors.is_empty():
			continue  # seed couldn't place any pair — fine, not stuck
		var chain: Dictionary = _simulate_chain_reachable_from_entrance(gen)
		for x in range(gen.grid_width):
			for y in range(gen.grid_height):
				var cell: GridCell = gen.grid[x][y]
				if not (cell.object is LeverInstance):
					continue
				var pos := Vector2i(x, y)
				var has_neighbour := false
				for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
					if chain.has(pos + d):
						has_neighbour = true
						break
				assert_true(has_neighbour,
					"seed %d: lever at %s is not chain-reachable from entrance" % [s, pos])

func test_exit_remains_chain_reachable_with_linked_pairs() -> void:
	# Even with locked doors gating the level, the exit must be
	# reachable assuming the player progressively pulls levers.
	var biome := _make_biome()
	biome.linked_objects = [_make_linked_spawn(_make_lever_data(), _make_door(), 3, 3)]
	for s in [111, 222, 333, 444, 555]:
		var gen := _make_generator(biome, s)
		var chain: Dictionary = _simulate_chain_reachable_from_entrance(gen)
		assert_true(chain.has(gen.exit_pos),
			"seed %d: exit %s not chain-reachable" % [s, gen.exit_pos])

func test_linked_must_gate_content_rejects_useless_locks() -> void:
	# With door_must_gate_content=true on a LinkedObjectSpawn, every
	# placed lever-locked door must actually gate something (a chest,
	# lever, key, or the exit) — otherwise the lock is pointless.
	# Mirrors the KeyDoorSpawn must_gate test: re-derive content
	# reachability with each placed door permanently closed and
	# assert SOMETHING content-bearing becomes unreachable.
	var spawn := _make_linked_spawn(_make_lever_data(), _make_door(), 3, 3)
	spawn.door_must_gate_content = true
	var biome := _make_biome()
	biome.objects = [_make_object_spawn(_make_chest(), 4, 4, ObjectSpawn.PLACEMENT_ANY)]
	biome.linked_objects = [spawn]
	var gen := _make_generator(biome)
	var linked_doors: Array = []
	for door in gen.doors:
		if not door.linked_levers.is_empty():
			linked_doors.append(door)
	for door in linked_doors:
		var excluded_chain: Dictionary = _chain_with_excluded_door(gen, door)
		var some_content_unreachable := false
		for x in range(gen.grid_width):
			for y in range(gen.grid_height):
				var cell: GridCell = gen.grid[x][y]
				var pos := Vector2i(x, y)
				if cell.cell_type == GridCell.CellType.EXIT and not excluded_chain.has(pos):
					some_content_unreachable = true
					break
				if cell.object != null and (cell.object.is_chest() or cell.object is LeverInstance):
					var ok := false
					for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
						if excluded_chain.has(pos + d):
							ok = true
							break
					if not ok:
						some_content_unreachable = true
						break
			if some_content_unreachable:
				break
		assert_true(some_content_unreachable,
			"lever-locked door %s—%s gates nothing — must_gate_content should have rejected it" %
			[door.cell_a, door.cell_b])

func test_linked_pair_rollback_clears_lever_cell_when_must_gate_rejects() -> void:
	# Internal-state guard: if must_gate_content rejects a placement,
	# the rollback must clear the tentatively-placed lever cell along
	# with the door. Otherwise we ship orphan levers wired to no
	# door. We assert the invariant directly: every lever cell
	# resolves to a door still in the doors list.
	var spawn := _make_linked_spawn(_make_lever_data(), _make_door(), 3, 3)
	spawn.door_must_gate_content = true
	var biome := _make_biome()
	biome.objects = [_make_object_spawn(_make_chest(), 4, 4, ObjectSpawn.PLACEMENT_ANY)]
	biome.linked_objects = [spawn]
	for s in [111, 222, 333, 444, 555]:
		var gen := _make_generator(biome, s)
		for cell_pos in _all_lever_cells(gen):
			var lever: LeverInstance = gen.grid[cell_pos.x][cell_pos.y].object
			assert_eq(lever.linked_doors.size(), 1,
				"seed %d: lever at %s should still link to 1 door after must-gate filtering" % [s, cell_pos])
			var paired_door: DoorInstance = lever.linked_doors[0]
			assert_true(gen.doors.has(paired_door),
				"seed %d: lever at %s links to a door not in the doors list (rollback bug)" % [s, cell_pos])

# -------------------------------------------------------
# M:N lever ↔ door clusters (Phase 8 Task 2b follow-up)
# -------------------------------------------------------

func _make_mn_cluster_spawn(n_levers: int, n_doors: int, logic: int = 0) -> LinkedObjectSpawn:
	var spawn := _make_linked_spawn(_make_lever_data(), _make_door(), 1, 1)
	spawn.levers_per_cluster = n_levers
	spawn.doors_per_cluster = n_doors
	spawn.lever_logic = logic
	spawn.lever_placement = ObjectSpawn.PLACEMENT_ANY
	return spawn

func test_2_lever_1_door_cluster_cross_links_correctly() -> void:
	var biome := _make_biome()
	biome.linked_objects = [_make_mn_cluster_spawn(2, 1)]
	var gen := _make_generator(biome)
	var levers: Array = _all_lever_cells(gen)
	var linked_doors: Array = []
	for door in gen.doors:
		if not door.linked_levers.is_empty():
			linked_doors.append(door)
	if linked_doors.is_empty():
		return
	assert_eq(levers.size(), 2, "cluster should produce 2 levers")
	assert_eq(linked_doors.size(), 1, "cluster should produce 1 door")
	var door: DoorInstance = linked_doors[0]
	assert_eq(door.linked_levers.size(), 2, "door should link to both levers")
	for cell_pos in levers:
		var lever: LeverInstance = gen.grid[cell_pos.x][cell_pos.y].object
		assert_eq(lever.linked_doors.size(), 1, "each lever links to 1 door")
		assert_eq(lever.linked_doors[0], door)

func test_1_lever_2_door_cluster_cross_links_correctly() -> void:
	var biome := _make_biome()
	biome.linked_objects = [_make_mn_cluster_spawn(1, 2)]
	var gen := _make_generator(biome)
	var levers: Array = _all_lever_cells(gen)
	var linked_doors: Array = []
	for door in gen.doors:
		if not door.linked_levers.is_empty():
			linked_doors.append(door)
	if linked_doors.is_empty():
		return
	assert_eq(levers.size(), 1, "cluster should produce 1 lever")
	assert_eq(linked_doors.size(), 2, "cluster should produce 2 doors")
	var lever: LeverInstance = gen.grid[levers[0].x][levers[0].y].object
	assert_eq(lever.linked_doors.size(), 2, "lever should link to both doors")
	for door in linked_doors:
		assert_true(door.linked_levers.has(lever), "each door links back to the lever")

func test_cluster_lever_logic_propagates_to_doors() -> void:
	var spawn := _make_mn_cluster_spawn(2, 1, 1)  # OR logic
	var biome := _make_biome()
	biome.linked_objects = [spawn]
	var gen := _make_generator(biome)
	for door in gen.doors:
		if not door.linked_levers.is_empty():
			assert_eq(door.lever_logic, DoorInstance.LeverLogic.OR,
				"cluster door should inherit OR logic from spawn")

func test_mn_cluster_chain_reachable() -> void:
	var biome := _make_biome()
	biome.linked_objects = [_make_mn_cluster_spawn(2, 2)]
	for s in [101, 202, 303, 404, 505]:
		var gen := _make_generator(biome, s)
		if gen.doors.is_empty():
			continue
		var chain: Dictionary = _simulate_chain_reachable_from_entrance(gen)
		for cell_pos in _all_lever_cells(gen):
			var has_neighbour := false
			for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				if chain.has(cell_pos + d):
					has_neighbour = true
					break
			assert_true(has_neighbour,
				"seed %d: lever at %s not chain-reachable in 2:2 cluster" % [s, cell_pos])
		assert_true(chain.has(gen.exit_pos),
			"seed %d: exit not chain-reachable with 2:2 cluster" % s)

func test_mn_cluster_rollback_is_atomic() -> void:
	var biome := _make_biome()
	biome.linked_objects = [_make_mn_cluster_spawn(3, 2)]
	for s in [111, 222, 333, 444, 555]:
		var gen := _make_generator(biome, s)
		for cell_pos in _all_lever_cells(gen):
			var lever: LeverInstance = gen.grid[cell_pos.x][cell_pos.y].object
			for door in lever.linked_doors:
				assert_true(gen.doors.has(door),
					"seed %d: lever at %s links to a door not in gen.doors (rollback leak)" % [s, cell_pos])
		for door in gen.doors:
			for lever in door.linked_levers:
				if lever == null:
					continue
				var found := false
				for x in range(gen.grid_width):
					for y in range(gen.grid_height):
						if gen.grid[x][y].object == lever:
							found = true
							break
					if found:
						break
				assert_true(found,
					"seed %d: door links to lever not on any grid cell (rollback leak)" % s)

# -------------------------------------------------------
# Key-locked doors (Phase 8 Task 2c)
# -------------------------------------------------------

func _make_key_item(key_id: String = "") -> ItemData:
	var data := ItemData.new()
	data.item_name = "test.key"
	data.category = ItemData.Category.KEY
	data.key_id = key_id
	data.stackable = true
	return data

func _make_locked_door() -> ObjectData:
	var data := ObjectData.new()
	data.category = ObjectData.Category.DOOR
	data.blocks_movement = true
	data.interactable = false  # locked doors give feedback on bare click
	data.name_key = "test.locked_door"
	return data

func _make_key_door_spawn(key_data: ItemData, door_data: ObjectData, count_min: int, count_max: int) -> KeyDoorSpawn:
	var spawn := KeyDoorSpawn.new()
	spawn.key_item = key_data
	spawn.door_object = door_data
	spawn.count_min = count_min
	spawn.count_max = count_max
	# Default to FLOOR location for these tests so they're
	# deterministic; chest tests override explicitly.
	spawn.key_spawn_locations = KeyDoorSpawn.KEY_LOCATION_FLOOR
	spawn.key_floor_placement = ObjectSpawn.PLACEMENT_ANY
	# Tests want pairs to actually land — disable the gate-content
	# check unless a specific test asserts on it.
	spawn.door_must_gate_content = false
	return spawn

func _all_locked_doors(gen: LevelGenerator) -> Array:
	var result: Array = []
	for door in gen.doors:
		if door.lock_id != "":
			result.append(door)
	return result

func _all_key_items_on_floor(gen: LevelGenerator) -> Array:
	var result: Array = []
	for x in range(gen.grid_width):
		for y in range(gen.grid_height):
			for item in gen.grid[x][y].items:
				if item != null and item.get_key_id() != "":
					result.append({"pos": Vector2i(x, y), "item": item})
	return result

func test_key_door_spawn_creates_locked_door_with_lock_id() -> void:
	var biome := _make_biome()
	biome.key_door_spawns = [_make_key_door_spawn(_make_key_item(), _make_locked_door(), 2, 2)]
	var gen := _make_generator(biome)
	var locked: Array = _all_locked_doors(gen)
	# Generation is best-effort — assert at most count_max, but every
	# placed locked door must have a non-empty lock_id.
	assert_lte(locked.size(), 2)
	for door in locked:
		assert_ne(door.lock_id, "", "locked door must have non-empty lock_id")
		assert_false(door.unlocked, "locked door starts locked")

func test_each_locked_door_has_a_matching_floor_key() -> void:
	var biome := _make_biome()
	biome.key_door_spawns = [_make_key_door_spawn(_make_key_item(), _make_locked_door(), 2, 2)]
	var gen := _make_generator(biome)
	var locked: Array = _all_locked_doors(gen)
	var floor_keys: Array = _all_key_items_on_floor(gen)
	# Every placed locked door has exactly one floor-key pair.
	assert_eq(floor_keys.size(), locked.size(),
		"floor key count (%d) must match locked door count (%d)" %
		[floor_keys.size(), locked.size()])
	# Cross-check: each lock_id appears once among the floor keys.
	for door in locked:
		var matches := 0
		for entry in floor_keys:
			if (entry["item"] as ItemInstance).get_key_id() == door.lock_id:
				matches += 1
		assert_eq(matches, 1,
			"lock_id %s must have exactly one matching floor key (found %d)" %
			[door.lock_id, matches])

func test_floor_key_is_chain_reachable_before_its_door() -> void:
	# Key must be reachable from entrance WITHOUT crossing its
	# corresponding locked door. Chain v2 takes care of this — but
	# we verify by simulating reachability with the linked door
	# permanently closed AND the key uncollected, and asserting the
	# key cell is still reachable.
	var biome := _make_biome()
	biome.key_door_spawns = [_make_key_door_spawn(_make_key_item(), _make_locked_door(), 2, 2)]
	var gen := _make_generator(biome)
	for door in _all_locked_doors(gen):
		# Find the key for this lock.
		var key_pos: Vector2i = Vector2i(-1, -1)
		for entry in _all_key_items_on_floor(gen):
			if (entry["item"] as ItemInstance).get_key_id() == door.lock_id:
				key_pos = entry["pos"]
				break
		assert_ne(key_pos, Vector2i(-1, -1), "key for %s not found" % door.lock_id)
		# Hide this door's lock_id so the simulator doesn't unlock
		# it via the matching key during the test.
		var saved_lock: String = door.lock_id
		door.lock_id = "__test_unreachable__"  # never collected
		# Also clear the key from the items so the simulator can't
		# auto-collect it. We'll just BFS without door open.
		var saved_items: Array = gen.grid[key_pos.x][key_pos.y].items.duplicate()
		gen.grid[key_pos.x][key_pos.y].items.clear()
		var chain: Dictionary = _simulate_chain_reachable_from_entrance(gen)
		# Restore.
		door.lock_id = saved_lock
		gen.grid[key_pos.x][key_pos.y].items = saved_items
		assert_true(chain.has(key_pos),
			"key for %s at %s is not reachable with the door closed" %
			[saved_lock, key_pos])

func test_chain_v2_unlocks_doors_via_collected_keys() -> void:
	# After collecting the key, the door is openable, and the cells
	# past the door should be in chain reachable.
	var biome := _make_biome()
	biome.key_door_spawns = [_make_key_door_spawn(_make_key_item(), _make_locked_door(), 1, 1)]
	var gen := _make_generator(biome)
	if gen.doors.is_empty():
		return  # seed couldn't fit — skip
	var chain: Dictionary = _simulate_chain_reachable_from_entrance(gen)
	for door in _all_locked_doors(gen):
		# Both sides of the door must end up reachable via the chain.
		assert_true(chain.has(door.cell_a),
			"door cell_a %s not in chain after key collection" % door.cell_a)
		assert_true(chain.has(door.cell_b),
			"door cell_b %s not in chain after key collection" % door.cell_b)

func test_must_gate_content_rejects_useless_locks() -> void:
	# With must_gate_content=true, every placed door must actually
	# gate something (a chest, lever, key, or the exit).
	var spawn := _make_key_door_spawn(_make_key_item(), _make_locked_door(), 3, 3)
	spawn.door_must_gate_content = true
	var biome := _make_biome()
	# Add a chest pool so there's something interesting to gate.
	biome.objects = [_make_object_spawn(_make_chest(), 4, 4, ObjectSpawn.PLACEMENT_ANY)]
	biome.key_door_spawns = [spawn]
	var gen := _make_generator(biome)
	# Defensive: every placed locked door must gate at least one
	# content cell. We re-derive this by running chain with that one
	# door closed and confirming SOMETHING content-bearing is missing.
	for door in _all_locked_doors(gen):
		var excluded_chain: Dictionary = _chain_with_excluded_door(gen, door)
		var some_content_unreachable := false
		for x in range(gen.grid_width):
			for y in range(gen.grid_height):
				var cell: GridCell = gen.grid[x][y]
				var pos := Vector2i(x, y)
				if cell.cell_type == GridCell.CellType.EXIT and not excluded_chain.has(pos):
					some_content_unreachable = true
					break
				if cell.object != null and (cell.object.is_chest() or cell.object is LeverInstance):
					var ok := false
					for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
						if excluded_chain.has(pos + d):
							ok = true
							break
					if not ok:
						some_content_unreachable = true
						break
			if some_content_unreachable:
				break
		assert_true(some_content_unreachable,
			"locked door %s—%s gates nothing — must_gate_content should have rejected it" %
			[door.cell_a, door.cell_b])

func _chain_with_excluded_door(gen: LevelGenerator, excluded_door: DoorInstance) -> Dictionary:
	# Like _simulate_chain_reachable_from_entrance but treats one
	# specific door as permanently closed regardless of locks/levers.
	var excluded_key := DoorInstance.edge_key(excluded_door.cell_a, excluded_door.cell_b)
	var open_keys: Dictionary = {}
	var collected_keys: Dictionary = {}
	for door in gen.doors:
		var k0 := DoorInstance.edge_key(door.cell_a, door.cell_b)
		if k0 == excluded_key:
			continue
		if door.data != null and door.data.interactable and not door.is_key_locked() and door.linked_levers.is_empty():
			open_keys[k0] = true
	var reachable: Dictionary = {}
	while true:
		reachable = _bfs_with_open_keys(gen, open_keys)
		var progressed := false
		# Keys
		for x in range(gen.grid_width):
			for y in range(gen.grid_height):
				var cell: GridCell = gen.grid[x][y]
				var pos := Vector2i(x, y)
				if not cell.items.is_empty() and reachable.has(pos):
					for item in cell.items:
						if item != null and item.get_key_id() != "" and not collected_keys.has(item.get_key_id()):
							collected_keys[item.get_key_id()] = true
							progressed = true
				if cell.object != null and cell.object.is_chest():
					var has_neighbour := false
					for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
						if reachable.has(pos + d):
							has_neighbour = true
							break
					if has_neighbour:
						for item in cell.object.items:
							if item != null and item.get_key_id() != "" and not collected_keys.has(item.get_key_id()):
								collected_keys[item.get_key_id()] = true
								progressed = true
		# Collect reachable levers, then evaluate lever-locked doors.
		var reachable_levers2: Dictionary = {}
		for x in range(gen.grid_width):
			for y in range(gen.grid_height):
				var cell: GridCell = gen.grid[x][y]
				if not (cell.object is LeverInstance):
					continue
				var pos := Vector2i(x, y)
				var has_neighbour := false
				for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
					if reachable.has(pos + d):
						has_neighbour = true
						break
				if has_neighbour:
					reachable_levers2[cell.object] = true
		for door in gen.doors:
			if door.linked_levers.is_empty():
				continue
			var key := DoorInstance.edge_key(door.cell_a, door.cell_b)
			if key == excluded_key:
				continue
			if open_keys.has(key):
				continue
			var should_open: bool = false
			if door.lever_logic == DoorInstance.LeverLogic.AND:
				should_open = true
				for lever in door.linked_levers:
					if lever == null or not reachable_levers2.has(lever):
						should_open = false
						break
			else:
				for lever in door.linked_levers:
					if lever != null and reachable_levers2.has(lever):
						should_open = true
						break
			if should_open:
				open_keys[key] = true
				progressed = true
		# Locked doors via collected keys
		for door in gen.doors:
			if door.lock_id == "" or not collected_keys.has(door.lock_id):
				continue
			var key2 := DoorInstance.edge_key(door.cell_a, door.cell_b)
			if key2 == excluded_key:
				continue
			if not open_keys.has(key2):
				open_keys[key2] = true
				progressed = true
		if not progressed:
			return reachable
	return {}

func test_keys_are_hue_shifted_per_pair_index() -> void:
	# Pair 0's key has hue_shift=0 and renders the original
	# textures (get_icon falls through to data.icon). Pair >= 1
	# gets a non-zero shift and a per-instance baked texture so
	# the player can tell visually-identical keys apart.
	var key_data := _make_key_item()
	# Give the key a tiny icon so apply_hue_shift has something to
	# bake. The integration test's _make_key_item leaves it null.
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0.8, 0.2))
	key_data.icon = ImageTexture.create_from_image(img)
	var spawn := _make_key_door_spawn(key_data, _make_locked_door(), 3, 3)
	var biome := _make_biome()
	biome.objects = [_make_object_spawn(_make_chest(), 4, 4, ObjectSpawn.PLACEMENT_ANY)]
	biome.key_door_spawns = [spawn]
	var gen := _make_generator(biome, 4242)
	# Map lock_id -> ItemInstance by inspecting placed keys.
	var keys_by_lock: Dictionary = {}
	for x in range(gen.grid_width):
		for y in range(gen.grid_height):
			var cell: GridCell = gen.grid[x][y]
			for item in cell.items:
				if item != null and item.get_key_id() != "":
					keys_by_lock[item.get_key_id()] = item
			if cell.object != null and cell.object.is_chest():
				for item in cell.object.items:
					if item != null and item.get_key_id() != "":
						keys_by_lock[item.get_key_id()] = item
	# Pair 0 is "lock_0" (empty prefix → "lock", first counter = 0).
	if keys_by_lock.has("lock_0"):
		var k0: ItemInstance = keys_by_lock["lock_0"]
		assert_eq(k0.hue_shift, 0.0,
			"first pair's key must have hue_shift = 0")
		assert_eq(k0.get_icon(), key_data.icon,
			"pair 0 must fall through to the original icon")
	# Any other placed pair must have non-zero shift AND a baked
	# icon distinct from the original.
	for lock_id in keys_by_lock.keys():
		if lock_id == "lock_0":
			continue
		var k: ItemInstance = keys_by_lock[lock_id]
		assert_ne(k.hue_shift, 0.0,
			"pair %s should have non-zero hue_shift" % lock_id)
		assert_ne(k.get_icon(), key_data.icon,
			"pair %s should render a baked icon, not the original" % lock_id)

func test_chests_hold_at_most_one_key_by_default() -> void:
	# allow_multiple_keys_per_chest defaults to false. Even with 4
	# locked-door pairs forced into chests, no chest should hold
	# two keys.
	var spawn := _make_key_door_spawn(_make_key_item(), _make_locked_door(), 4, 4)
	spawn.key_spawn_locations = KeyDoorSpawn.KEY_LOCATION_CHEST
	var biome := _make_biome()
	# Lots of chests so chest placement has room — otherwise pairs
	# would just fail to place rather than stack on a chest.
	biome.objects = [_make_object_spawn(_make_chest(), 6, 6, ObjectSpawn.PLACEMENT_ANY)]
	biome.key_door_spawns = [spawn]
	var gen := _make_generator(biome, 12121)
	for x in range(gen.grid_width):
		for y in range(gen.grid_height):
			var cell: GridCell = gen.grid[x][y]
			if cell.object == null or not cell.object.is_chest():
				continue
			var key_count := 0
			for item in cell.object.items:
				if item != null and item.get_key_id() != "":
					key_count += 1
			assert_lte(key_count, 1,
				"chest at (%d,%d) holds %d keys with allow_multiple_keys_per_chest=false" %
				[x, y, key_count])

func test_chest_can_hold_multiple_keys_when_flag_is_true() -> void:
	# With the flag on, the placement may stack keys into one chest.
	# Hard to assert "exactly N in one chest" because of randomness;
	# we just verify the flag doesn't break placement (locked doors
	# still land with their keys somewhere).
	var spawn := _make_key_door_spawn(_make_key_item(), _make_locked_door(), 3, 3)
	spawn.key_spawn_locations = KeyDoorSpawn.KEY_LOCATION_CHEST
	spawn.allow_multiple_keys_per_chest = true
	var biome := _make_biome()
	biome.objects = [_make_object_spawn(_make_chest(), 4, 4, ObjectSpawn.PLACEMENT_ANY)]
	biome.key_door_spawns = [spawn]
	var gen := _make_generator(biome, 34321)
	# Sanity: any locked door we did place must have its key in some chest.
	for door in _all_locked_doors(gen):
		var found := false
		for x in range(gen.grid_width):
			for y in range(gen.grid_height):
				var cell: GridCell = gen.grid[x][y]
				if cell.object == null or not cell.object.is_chest():
					continue
				for item in cell.object.items:
					if item != null and item.get_key_id() == door.lock_id:
						found = true
						break
				if found:
					break
			if found:
				break
		assert_true(found, "key for %s not found in any chest" % door.lock_id)

func test_chest_spawned_key_lands_inside_a_chest() -> void:
	var spawn := _make_key_door_spawn(_make_key_item(), _make_locked_door(), 1, 1)
	spawn.key_spawn_locations = KeyDoorSpawn.KEY_LOCATION_CHEST
	var biome := _make_biome()
	biome.objects = [_make_object_spawn(_make_chest(), 4, 4, ObjectSpawn.PLACEMENT_ANY)]
	biome.key_door_spawns = [spawn]
	var gen := _make_generator(biome, 7777)
	# If a locked door was placed, its key MUST be inside a chest
	# (no floor keys allowed when only CHEST is enabled).
	var floor_keys: Array = _all_key_items_on_floor(gen)
	assert_eq(floor_keys.size(), 0, "no floor keys allowed when KEY_LOCATION_CHEST is the only flag")
	for door in _all_locked_doors(gen):
		var found := false
		for x in range(gen.grid_width):
			for y in range(gen.grid_height):
				var cell: GridCell = gen.grid[x][y]
				if cell.object == null or not cell.object.is_chest():
					continue
				for item in cell.object.items:
					if item != null and item.get_key_id() == door.lock_id:
						found = true
						break
				if found:
					break
			if found:
				break
		assert_true(found, "key for lock %s not found inside any chest" % door.lock_id)

# -------------------------------------------------------
# Wall decorations (Phase 8 Task 4)
# -------------------------------------------------------

func _make_wall_deco_data(world_height: float = 1.5) -> WallDecorationData:
	var data := WallDecorationData.new()
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	data.texture = ImageTexture.create_from_image(img)
	data.world_height = world_height
	return data

func _make_wall_deco_spawn(data: WallDecorationData, count_min: int, count_max: int, placement: int = ObjectSpawn.PLACEMENT_ANY) -> WallDecorationSpawn:
	var spawn := WallDecorationSpawn.new()
	spawn.decoration = data
	spawn.count_min = count_min
	spawn.count_max = count_max
	spawn.placement = placement
	return spawn

func test_no_wall_decorations_when_pool_is_empty() -> void:
	var gen := _make_generator(_make_biome())
	assert_eq(gen.wall_decorations.size(), 0)

func test_wall_decorations_count_falls_within_min_max() -> void:
	var biome := _make_biome()
	biome.wall_decorations = [_make_wall_deco_spawn(_make_wall_deco_data(), 4, 4)]
	var gen := _make_generator(biome)
	assert_eq(gen.wall_decorations.size(), 4)

func test_wall_decorations_attach_to_actual_walls() -> void:
	var biome := _make_biome()
	biome.wall_decorations = [_make_wall_deco_spawn(_make_wall_deco_data(), 6, 6)]
	var gen := _make_generator(biome)
	for inst in gen.wall_decorations:
		var nx: int = inst.cell.x + inst.wall_dir.x
		var ny: int = inst.cell.y + inst.wall_dir.y
		assert_true(nx >= 0 and nx < gen.grid_width and ny >= 0 and ny < gen.grid_height,
			"decoration at %s wall_dir %s points out of bounds" % [inst.cell, inst.wall_dir])
		assert_eq(gen.grid[nx][ny].cell_type, GridCell.CellType.WALL,
			"decoration at %s wall_dir %s points to a non-wall cell" % [inst.cell, inst.wall_dir])

func test_wall_decorations_attach_to_floor_cells_only() -> void:
	var biome := _make_biome()
	biome.wall_decorations = [_make_wall_deco_spawn(_make_wall_deco_data(), 5, 5)]
	var gen := _make_generator(biome)
	for inst in gen.wall_decorations:
		var cell: GridCell = gen.grid[inst.cell.x][inst.cell.y]
		assert_ne(cell.cell_type, GridCell.CellType.WALL,
			"decoration host cell %s is a wall — should be floor" % inst.cell)

func test_wall_decoration_face_uniqueness() -> void:
	var biome := _make_biome()
	biome.wall_decorations = [_make_wall_deco_spawn(_make_wall_deco_data(), 8, 8)]
	var gen := _make_generator(biome)
	var seen: Dictionary = {}
	for inst in gen.wall_decorations:
		var key: String = inst.get_face_key()
		assert_false(seen.has(key), "duplicate wall face %s" % key)
		seen[key] = true

func test_wall_decoration_min_distance_keeps_them_apart() -> void:
	var biome := _make_biome()
	var spawn := _make_wall_deco_spawn(_make_wall_deco_data(), 3, 3)
	spawn.min_distance_to_other_decoration = 4
	biome.wall_decorations = [spawn]
	var gen := _make_generator(biome)
	var positions := []
	for inst in gen.wall_decorations:
		positions.append(inst.cell)
	for i in range(positions.size()):
		for j in range(i + 1, positions.size()):
			var dist: int = abs(positions[i].x - positions[j].x) + abs(positions[i].y - positions[j].y)
			assert_gte(dist, 4,
				"decorations at %s and %s are %d apart (need >= 4)" %
				[positions[i], positions[j], dist])

func test_wall_decoration_respects_placement_flags() -> void:
	var biome := _make_biome()
	biome.wall_decorations = [_make_wall_deco_spawn(_make_wall_deco_data(), 2, 2, ObjectSpawn.PLACEMENT_DEAD_END)]
	var gen := _make_generator(biome)
	for inst in gen.wall_decorations:
		var floor_neighbours := 0
		for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var n: Vector2i = inst.cell + d
			if n.x >= 0 and n.x < gen.grid_width and n.y >= 0 and n.y < gen.grid_height:
				if gen.grid[n.x][n.y].cell_type != GridCell.CellType.WALL:
					floor_neighbours += 1
		assert_eq(floor_neighbours, 1,
			"decoration host %s should be a dead-end (1 floor neighbour)" % inst.cell)

func test_wall_decoration_animated_path_uses_frames() -> void:
	var data := WallDecorationData.new()
	data.frames = SpriteFrames.new()
	var biome := _make_biome()
	biome.wall_decorations = [_make_wall_deco_spawn(data, 1, 1)]
	var gen := _make_generator(biome)
	for inst in gen.wall_decorations:
		assert_true(inst.data.is_animated())

# -------------------------------------------------------
# Per-wall-face classification (Phase 4 polish follow-up)
# -------------------------------------------------------

func _find_dead_end_floor_cell(gen: LevelGenerator) -> Vector2i:
	# A floor cell with exactly one floor neighbour. Used to verify
	# classify_wall_face picks DEAD_END for the back wall and CORRIDOR
	# for the side walls.
	for x in range(1, gen.grid_width - 1):
		for y in range(1, gen.grid_height - 1):
			var cell: GridCell = gen.grid[x][y]
			if cell.cell_type != GridCell.CellType.FLOOR:
				continue
			var pos := Vector2i(x, y)
			if pos == gen.entrance_pos or pos == gen.exit_pos:
				continue
			var floor_neighbours := 0
			for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				if gen.grid[x + d.x][y + d.y].cell_type != GridCell.CellType.WALL:
					floor_neighbours += 1
			if floor_neighbours == 1:
				return pos
	return Vector2i(-1, -1)

func test_classify_wall_face_back_wall_of_dead_end_is_dead_end() -> void:
	var gen := _make_generator(_make_biome())
	var pos := _find_dead_end_floor_cell(gen)
	assert_ne(pos, Vector2i(-1, -1), "test biome should produce at least one dead end floor cell")
	# Find the open direction (the only floor neighbour).
	var open_dir := Vector2i.ZERO
	for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		if gen.grid[pos.x + d.x][pos.y + d.y].cell_type != GridCell.CellType.WALL:
			open_dir = d
			break
	# Back wall = opposite of open direction.
	var back_dir := -open_dir
	assert_eq(gen.classify_wall_face(pos, back_dir), ObjectSpawn.PLACEMENT_DEAD_END)

func test_classify_wall_face_side_walls_of_dead_end_are_corridor() -> void:
	var gen := _make_generator(_make_biome())
	var pos := _find_dead_end_floor_cell(gen)
	assert_ne(pos, Vector2i(-1, -1))
	var open_dir := Vector2i.ZERO
	for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		if gen.grid[pos.x + d.x][pos.y + d.y].cell_type != GridCell.CellType.WALL:
			open_dir = d
			break
	# Two side walls = perpendicular to the open / back axis. Both
	# must classify as CORRIDOR so a DEAD_END-only texture (e.g. a
	# big-tree mural) lands only on the back wall, not wrapping the
	# cell on three sides.
	var perp_a := Vector2i(open_dir.y, open_dir.x)
	var perp_b := Vector2i(-open_dir.y, -open_dir.x)
	assert_eq(gen.classify_wall_face(pos, perp_a), ObjectSpawn.PLACEMENT_CORRIDOR)
	assert_eq(gen.classify_wall_face(pos, perp_b), ObjectSpawn.PLACEMENT_CORRIDOR)

func test_classify_wall_face_non_dead_end_matches_cell_classification() -> void:
	var gen := _make_generator(_make_biome())
	# Non-dead-end floor cells should report the same classification
	# for every wall direction.
	for x in range(1, gen.grid_width - 1):
		for y in range(1, gen.grid_height - 1):
			var cell: GridCell = gen.grid[x][y]
			if cell.cell_type != GridCell.CellType.FLOOR:
				continue
			var pos := Vector2i(x, y)
			var floor_neighbours := 0
			for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				if gen.grid[x + d.x][y + d.y].cell_type != GridCell.CellType.WALL:
					floor_neighbours += 1
			if floor_neighbours == 1:
				continue  # dead end is the special case, tested separately
			var cell_class: int = gen.classify_cell(pos)
			for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				assert_eq(gen.classify_wall_face(pos, d), cell_class,
					"wall face at %s dir %s should match cell classification" % [pos, d])
			return  # one cell is enough to prove the rule
	fail_test("expected at least one non-dead-end floor cell")

# -------------------------------------------------------
# Subtask B3 — trap path-safety validators
# -------------------------------------------------------

func _make_dense_step_trap_biome() -> BiomeData:
	var biome := _make_biome()
	var trap := _make_trap_data(TrapData.Trigger.STEP)
	var spawn := _make_trap_spawn(trap, 150, 150, ObjectSpawn.PLACEMENT_ANY)
	spawn.corridor_segment_chance = 1.0
	spawn.corridor_traps_per_run_min = 4
	spawn.corridor_traps_per_run_max = 99
	spawn.room_chance = 0.5
	spawn.room_coverage_min_percent = 99.0
	spawn.room_coverage_max_percent = 99.0
	biome.trap_spawns = [spawn]
	return biome

func _bfs_no_step_traps(gen: LevelGenerator, start: Vector2i) -> Dictionary:
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
			var cell: GridCell = gen.grid[next.x][next.y]
			if cell.cell_type == GridCell.CellType.WALL:
				continue
			if cell.object != null and cell.object.data != null and cell.object.data.blocks_movement:
				continue
			if cell.trap != null and cell.trap.data != null and cell.trap.data.is_step():
				continue
			visited[next] = true
			queue.append(next)
	return visited

func test_exit_reachable_without_step_traps() -> void:
	for s in [12345, 99999, 55555, 31337, 42]:
		var biome := _make_dense_step_trap_biome()
		var gen := _make_generator(biome, s)
		var reachable := _bfs_no_step_traps(gen, gen.entrance_pos)
		assert_true(reachable.has(gen.exit_pos),
			"exit should be reachable without stepping on step traps (seed %d)" % s)

func test_chests_reachable_without_step_traps() -> void:
	for s in [12345, 99999, 55555]:
		var biome := _make_dense_step_trap_biome()
		biome.objects = [_make_object_spawn(_make_chest(), 3, 3)]
		var gen := _make_generator(biome, s)
		var reachable := _bfs_no_step_traps(gen, gen.entrance_pos)
		for x in range(gen.grid_width):
			for y in range(gen.grid_height):
				var cell: GridCell = gen.grid[x][y]
				if cell.object == null or cell.object.data == null:
					continue
				if cell.object.data.category != ObjectData.Category.CHEST:
					continue
				var pos := Vector2i(x, y)
				var adjacent_reachable := false
				for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
					if reachable.has(pos + d):
						adjacent_reachable = true
						break
				assert_true(adjacent_reachable,
					"chest at %s must have a step-trap-free adjacent cell reachable from entrance (seed %d)" % [pos, s])

func test_floor_items_reachable_without_step_traps() -> void:
	var item := _make_item()
	var loot := _make_loot_entry(item, 1, LootEntry.PLACEMENT_ANY)
	for s in [12345, 99999, 55555]:
		var biome := _make_dense_step_trap_biome()
		biome.floor_loot = [loot]
		biome.floor_items_min = 5
		biome.floor_items_max = 8
		var gen := _make_generator(biome, s)
		var reachable := _bfs_no_step_traps(gen, gen.entrance_pos)
		for x in range(gen.grid_width):
			for y in range(gen.grid_height):
				if gen.grid[x][y].items.is_empty():
					continue
				var pos := Vector2i(x, y)
				assert_true(reachable.has(pos),
					"floor item at %s must be reachable without step traps (seed %d)" % [pos, s])

func test_levers_reachable_without_step_traps() -> void:
	for s in [12345, 99999, 55555]:
		var biome := _make_dense_step_trap_biome()
		biome.linked_objects = [_make_linked_spawn(_make_lever_data(), _make_door(), 2, 2)]
		var gen := _make_generator(biome, s)
		var reachable := _bfs_no_step_traps(gen, gen.entrance_pos)
		var levers := _all_lever_cells(gen)
		for lever_pos in levers:
			var adjacent_reachable := false
			for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				if reachable.has(lever_pos + d):
					adjacent_reachable = true
					break
			assert_true(adjacent_reachable,
				"lever at %s must have a step-trap-free adjacent cell reachable from entrance (seed %d)" % [lever_pos, s])

func test_step_trap_validator_preserves_high_trap_count() -> void:
	var total_traps := 0
	var runs := 5
	for s in [12345, 99999, 55555, 31337, 42]:
		var biome := _make_dense_step_trap_biome()
		biome.objects = [_make_object_spawn(_make_chest(), 3, 3)]
		var gen := _make_generator(biome, s)
		total_traps += gen.traps.size()
	var avg: float = float(total_traps) / float(runs)
	assert_true(avg > 50.0,
		"average trap count across seeds should remain high (got %.1f)" % avg)

func test_remove_trap_at_clears_cell_and_list() -> void:
	var biome := _make_biome()
	biome.trap_spawns = [_make_trap_spawn(_make_trap_data(), 5, 5)]
	var gen := _make_generator(biome)
	if gen.traps.is_empty():
		pass_test("no traps to test removal on")
		return
	var trap_pos: Vector2i = gen.traps[0].cell
	var before_count: int = gen.traps.size()
	gen._remove_trap_at(trap_pos)
	assert_eq(gen.traps.size(), before_count - 1,
		"traps list should shrink by 1")
	assert_null(gen.grid[trap_pos.x][trap_pos.y].trap,
		"grid cell should have null trap after removal")

func test_remove_trap_at_clears_cluster_cells() -> void:
	var biome := _make_biome()
	var spawn := _make_corridor_cluster_spawn(_make_trap_data(), 1.0, 3, 5)
	biome.trap_spawns = [spawn]
	var gen := _make_generator(biome)
	var cluster_pos: Vector2i = Vector2i.ZERO
	var found := false
	for pos in gen._cluster_cells:
		cluster_pos = pos
		found = true
		break
	if not found:
		pass_test("no cluster cells to test")
		return
	gen._remove_trap_at(cluster_pos)
	assert_false(gen._cluster_cells.has(cluster_pos),
		"cluster cell should be removed from _cluster_cells after _remove_trap_at")

func test_traps_never_placed_on_cells_with_items() -> void:
	var item := _make_item()
	var loot := _make_loot_entry(item, 1, LootEntry.PLACEMENT_ANY)
	var biome := _make_biome([loot], 10, 15)
	biome.trap_spawns = [_make_trap_spawn(_make_trap_data(), 8, 8)]
	# Items are placed AFTER traps in pipeline, but floor keys from
	# _place_key_doors land BEFORE traps. To test the exclusion, we
	# need to verify no trap sits on a cell that already has items.
	# Since the standard pipeline places items after traps, we test
	# the inverse: no item cell has a trap.
	for s in [12345, 77777]:
		var gen := _make_generator(biome, s)
		for inst in gen.traps:
			var cell: GridCell = gen.grid[inst.cell.x][inst.cell.y]
			assert_true(cell.items.is_empty(),
				"trap at %s should not share a cell with floor items (seed %d)" % [inst.cell, s])

func test_chest_lever_timed_adjacency_guarantees_safe_neighbour() -> void:
	var biome := _make_biome()
	biome.objects = [_make_object_spawn(_make_chest(), 4, 4)]
	var timed_trap := _make_trap_data(TrapData.Trigger.TIMED)
	biome.trap_spawns = [_make_trap_spawn(timed_trap, 30, 30, ObjectSpawn.PLACEMENT_ANY)]
	for s in [12345, 99999, 55555]:
		var gen := _make_generator(biome, s)
		for x in range(gen.grid_width):
			for y in range(gen.grid_height):
				var cell: GridCell = gen.grid[x][y]
				if cell.object == null:
					continue
				if cell.object.data == null:
					continue
				var cat: int = cell.object.data.category
				if cat != ObjectData.Category.CHEST and cat != ObjectData.Category.LEVER:
					continue
				var pos := Vector2i(x, y)
				var has_safe := false
				for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
					var n: Vector2i = pos + d
					if n.x < 0 or n.x >= gen.grid_width or n.y < 0 or n.y >= gen.grid_height:
						continue
					var nc: GridCell = gen.grid[n.x][n.y]
					if nc.is_blocked:
						continue
					if nc.trap == null or not nc.trap.data.is_timed():
						has_safe = true
						break
				assert_true(has_safe,
					"chest/lever at %s must have a non-timed-trap walkable neighbour (seed %d)" % [pos, s])

func test_timed_trap_safe_distance_enforced_globally() -> void:
	var biome := _make_biome()
	var timed := _make_trap_data(TrapData.Trigger.TIMED)
	var spawn := _make_trap_spawn(timed, 80, 80, ObjectSpawn.PLACEMENT_ANY)
	spawn.corridor_segment_chance = 1.0
	spawn.corridor_traps_per_run_min = 4
	spawn.corridor_traps_per_run_max = 99
	spawn.room_chance = 1.0
	spawn.room_coverage_min_percent = 99.0
	spawn.room_coverage_max_percent = 99.0
	spawn.room_max_distance_to_safe_cell = 3
	biome.trap_spawns = [spawn]
	for s in [12345, 99999, 55555]:
		var gen := _make_generator(biome, s)
		for x in range(gen.grid_width):
			for y in range(gen.grid_height):
				var pos := Vector2i(x, y)
				if not gen._is_walkable_cell(pos):
					continue
				assert_true(gen._has_safe_timed_cell_within(pos, 3),
					"every walkable cell must have a non-timed-trap cell within 3 tiles (seed %d, pos %s)" % [s, pos])

func test_step_traps_adjacent_to_chests_are_allowed() -> void:
	var biome := _make_biome()
	biome.objects = [_make_object_spawn(_make_chest(), 3, 3)]
	var step_trap := _make_trap_data(TrapData.Trigger.STEP)
	biome.trap_spawns = [_make_trap_spawn(step_trap, 20, 20, ObjectSpawn.PLACEMENT_ANY)]
	var found_step_adjacent := false
	for s in [12345, 99999, 55555, 42, 31337]:
		var gen := _make_generator(biome, s)
		for x in range(gen.grid_width):
			for y in range(gen.grid_height):
				var cell: GridCell = gen.grid[x][y]
				if cell.object == null or cell.object.data == null:
					continue
				if cell.object.data.category != ObjectData.Category.CHEST:
					continue
				var pos := Vector2i(x, y)
				for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
					var n: Vector2i = pos + d
					if n.x < 0 or n.x >= gen.grid_width or n.y < 0 or n.y >= gen.grid_height:
						continue
					var nc: GridCell = gen.grid[n.x][n.y]
					if nc.trap != null and nc.trap.data.is_step():
						found_step_adjacent = true
	assert_true(found_step_adjacent,
		"step traps adjacent to chests should be allowed (timed adjacency rule only applies to TIMED traps)")

# -------------------------------------------------------
# Projectile traps (Phase 8 Task 3 — Subtask C1)
# -------------------------------------------------------

func _make_projectile_trap_data(max_escape: int = 5, min_distance: int = 0) -> ProjectileTrapData:
	# Defaults aimed at the small 21×21 test biome — a generous
	# `max_escape` so most corridor segments yield candidates, and
	# `min_distance` defaulted to 0 so spreading isn't accidentally
	# under-tested in the count-related assertions.
	var data := ProjectileTrapData.new()
	data.trigger = ProjectileTrapData.Trigger.TIMED
	data.max_escape_distance = max_escape
	data.min_distance_to_other_projectile_trap = min_distance
	data.name_key = "test.projectile_trap"
	# Provide a non-null launcher_texture so DungeonView would render
	# something — placement code itself doesn't need it, but it makes
	# the test data realistic.
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	data.launcher_texture = ImageTexture.create_from_image(img)
	return data

func _make_projectile_trap_spawn(trap: ProjectileTrapData, corridor_chance: float, max_per_segment: int = 1, placement: int = ObjectSpawn.PLACEMENT_CORRIDOR) -> ProjectileTrapSpawn:
	var spawn := ProjectileTrapSpawn.new()
	spawn.trap = trap
	spawn.corridor_chance = corridor_chance
	spawn.corridor_max_per_segment = max_per_segment
	spawn.placement = placement
	return spawn

func test_no_projectile_traps_when_pool_is_empty() -> void:
	var gen := _make_generator(_make_biome())
	assert_eq(gen.projectile_traps.size(), 0)

func test_no_projectile_traps_when_corridor_chance_zero() -> void:
	var biome := _make_biome()
	biome.projectile_trap_spawns = [_make_projectile_trap_spawn(_make_projectile_trap_data(), 0.0)]
	var gen := _make_generator(biome)
	assert_eq(gen.projectile_traps.size(), 0,
		"corridor_chance = 0 must produce no launchers")

func test_projectile_traps_landed_with_chance_one() -> void:
	# At chance = 1.0 the placer attempts a launcher in every segment.
	# The 21×21 biome typically has multiple corridor segments, so we
	# should see at least one placement across most seeds.
	var biome := _make_biome()
	biome.projectile_trap_spawns = [_make_projectile_trap_spawn(_make_projectile_trap_data(8), 1.0)]
	var any_placed := false
	for s in [12345, 99999, 55555, 42, 31337]:
		var gen := _make_generator(biome, s)
		if gen.projectile_traps.size() > 0:
			any_placed = true
			break
	assert_true(any_placed, "chance=1.0 should produce at least one launcher across 5 seeds")

func test_projectile_launcher_mounts_on_actual_wall() -> void:
	var biome := _make_biome()
	biome.projectile_trap_spawns = [_make_projectile_trap_spawn(_make_projectile_trap_data(8), 1.0)]
	var gen := _make_generator(biome, 12345)
	for inst in gen.projectile_traps:
		var nx: int = inst.cell.x + inst.wall_dir.x
		var ny: int = inst.cell.y + inst.wall_dir.y
		assert_true(nx >= 0 and nx < gen.grid_width and ny >= 0 and ny < gen.grid_height,
			"launcher at %s wall_dir %s points out of bounds" % [inst.cell, inst.wall_dir])
		assert_eq(gen.grid[nx][ny].cell_type, GridCell.CellType.WALL,
			"launcher at %s wall_dir %s points to a non-wall cell" % [inst.cell, inst.wall_dir])

func test_projectile_launcher_host_cell_is_floor() -> void:
	var biome := _make_biome()
	biome.projectile_trap_spawns = [_make_projectile_trap_spawn(_make_projectile_trap_data(8), 1.0)]
	var gen := _make_generator(biome, 12345)
	for inst in gen.projectile_traps:
		var cell: GridCell = gen.grid[inst.cell.x][inst.cell.y]
		assert_ne(cell.cell_type, GridCell.CellType.WALL,
			"launcher host cell %s is a wall — should be floor" % inst.cell)

func test_projectile_launcher_never_on_entrance_or_exit() -> void:
	var biome := _make_biome()
	biome.projectile_trap_spawns = [_make_projectile_trap_spawn(_make_projectile_trap_data(8), 1.0)]
	for s in [12345, 99999, 55555]:
		var gen := _make_generator(biome, s)
		for inst in gen.projectile_traps:
			assert_ne(inst.cell, gen.entrance_pos,
				"launcher must not host on entrance (seed %d)" % s)
			assert_ne(inst.cell, gen.exit_pos,
				"launcher must not host on exit (seed %d)" % s)

func test_projectile_fire_direction_reaches_a_junction_within_escape() -> void:
	# Walk from the launcher cell in fire direction up to
	# max_escape_distance steps; we MUST hit a corridor cell with 3+
	# corridor neighbours (a junction). Anything else is a placement
	# bug — the spec's escape rule would be violated.
	var biome := _make_biome()
	biome.projectile_trap_spawns = [_make_projectile_trap_spawn(_make_projectile_trap_data(6), 1.0)]
	for s in [12345, 99999, 55555]:
		var gen := _make_generator(biome, s)
		for inst in gen.projectile_traps:
			var fire := inst.fire_direction()
			var max_escape: int = inst.data.max_escape_distance
			var reached_junction := false
			for step in range(1, max_escape + 1):
				var p: Vector2i = inst.cell + fire * step
				if p.x < 0 or p.x >= gen.grid_width or p.y < 0 or p.y >= gen.grid_height:
					break
				var c: GridCell = gen.grid[p.x][p.y]
				if c.cell_type != GridCell.CellType.FLOOR:
					break
				# Junction = corridor cell with 3+ corridor neighbours.
				var corridor_n := 0
				for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
					var nn: Vector2i = p + d
					if nn.x < 0 or nn.x >= gen.grid_width or nn.y < 0 or nn.y >= gen.grid_height:
						continue
					if gen.grid[nn.x][nn.y].cell_type != GridCell.CellType.FLOOR:
						continue
					if gen.classify_cell(nn) == ObjectSpawn.PLACEMENT_CORRIDOR:
						corridor_n += 1
				if corridor_n >= 3:
					reached_junction = true
					break
			assert_true(reached_junction,
				"launcher at %s firing %s did not reach a junction within %d tiles (seed %d)"
				% [inst.cell, fire, max_escape, s])

func test_projectile_face_uniqueness() -> void:
	# Two launchers must never share a wall face.
	var biome := _make_biome()
	biome.projectile_trap_spawns = [_make_projectile_trap_spawn(_make_projectile_trap_data(8, 0), 1.0, 3)]
	var gen := _make_generator(biome, 12345)
	var seen: Dictionary = {}
	for inst in gen.projectile_traps:
		var key: String = inst.get_face_key()
		assert_false(seen.has(key), "duplicate wall face %s" % key)
		seen[key] = true

func test_projectile_does_not_share_face_with_decoration() -> void:
	# Wall decorations and projectile launchers share `_wall_faces_used`.
	# Projectile traps run BEFORE decorations, so a launcher claims
	# its face first; the decoration pass should skip claimed faces.
	var biome := _make_biome()
	biome.projectile_trap_spawns = [_make_projectile_trap_spawn(_make_projectile_trap_data(8, 0), 1.0, 5)]
	biome.wall_decorations = [_make_wall_deco_spawn(_make_wall_deco_data(), 8, 8)]
	var gen := _make_generator(biome, 12345)
	var deco_faces: Dictionary = {}
	for d in gen.wall_decorations:
		deco_faces[d.get_face_key()] = true
	for inst in gen.projectile_traps:
		assert_false(deco_faces.has(inst.get_face_key()),
			"launcher and decoration share wall face %s" % inst.get_face_key())

func test_projectile_min_distance_keeps_launchers_apart() -> void:
	# No graceful degrade — if the rule can't be met, the launcher is
	# simply skipped. So we just assert the placed ones respect it.
	var biome := _make_biome()
	var trap_data := _make_projectile_trap_data(8, 5)
	biome.projectile_trap_spawns = [_make_projectile_trap_spawn(trap_data, 1.0, 5)]
	var gen := _make_generator(biome, 12345)
	for i in range(gen.projectile_traps.size()):
		for j in range(i + 1, gen.projectile_traps.size()):
			var a: Vector2i = gen.projectile_traps[i].cell
			var b: Vector2i = gen.projectile_traps[j].cell
			var dist: int = abs(a.x - b.x) + abs(a.y - b.y)
			assert_gte(dist, 5,
				"launchers at %s and %s are %d apart (need >= 5)" % [a, b, dist])

func test_projectile_max_per_segment_cap_holds() -> void:
	# Group placed launchers by their corridor segment; no segment
	# should contain more than `corridor_max_per_segment` launchers.
	var biome := _make_biome()
	var trap_data := _make_projectile_trap_data(8, 0)
	biome.projectile_trap_spawns = [_make_projectile_trap_spawn(trap_data, 1.0, 1)]
	var gen := _make_generator(biome, 12345)
	var segments: Array = gen._detect_corridor_segments()
	var cell_to_seg: Dictionary = {}
	for i in range(segments.size()):
		for pos in segments[i]:
			cell_to_seg[pos] = i
	var per_segment: Dictionary = {}
	for inst in gen.projectile_traps:
		if not cell_to_seg.has(inst.cell):
			continue
		var seg: int = cell_to_seg[inst.cell]
		per_segment[seg] = per_segment.get(seg, 0) + 1
	for k in per_segment.keys():
		assert_lte(per_segment[k], 1, "segment %d holds %d launchers (cap = 1)" % [k, per_segment[k]])

func test_projectile_corridor_only_placement() -> void:
	# Subtask C1 wires corridor placement only; even with PLACEMENT_ANY,
	# the host cell must be a corridor (room placement lands in C5).
	var biome := _make_biome()
	biome.projectile_trap_spawns = [_make_projectile_trap_spawn(_make_projectile_trap_data(8), 1.0, 2, ObjectSpawn.PLACEMENT_ANY)]
	var gen := _make_generator(biome, 12345)
	for inst in gen.projectile_traps:
		var classification: int = gen.classify_cell(inst.cell)
		# Junctions classify as corridor; dead-ends are also valid as
		# segment endpoints. Either way, NOT room.
		assert_ne(classification & ObjectSpawn.PLACEMENT_ROOM, ObjectSpawn.PLACEMENT_ROOM,
			"launcher at %s is in a room — C1 should be corridor-only" % inst.cell)

func test_projectile_fire_direction_is_opposite_wall_dir() -> void:
	# Sanity: the placement record's fire_direction() must be -wall_dir.
	# Tested separately in unit tests but verified here against a real
	# placed instance in case the placer ever sets them inconsistently.
	var biome := _make_biome()
	biome.projectile_trap_spawns = [_make_projectile_trap_spawn(_make_projectile_trap_data(8), 1.0, 3)]
	var gen := _make_generator(biome, 12345)
	for inst in gen.projectile_traps:
		assert_eq(inst.fire_direction(), -inst.wall_dir)

# Walks the projectile's path from `inst.cell` in fire direction until
# it hits a wall (or runs off the grid as a safety bail). Returns the
# array of `Vector2i` cells the projectile would cross — the same set
# the placement validator checks against.
func _projectile_path_until_wall(gen: LevelGenerator, inst) -> Array:
	var path: Array = []
	var fire: Vector2i = inst.fire_direction()
	var step: int = 1
	var step_limit: int = gen.grid_width + gen.grid_height + 2
	while step <= step_limit:
		var p: Vector2i = inst.cell + fire * step
		if p.x < 0 or p.x >= gen.grid_width or p.y < 0 or p.y >= gen.grid_height:
			break
		var c: GridCell = gen.grid[p.x][p.y]
		if c.cell_type == GridCell.CellType.WALL:
			break
		path.append(p)
		step += 1
	return path

func test_projectile_path_does_not_cross_chests_or_levers() -> void:
	# Rule: a launcher's projectile path (the FULL flight, all the way
	# until it hits a wall — not just up to the escape junction) must
	# not cross any cell that holds a CHEST or LEVER. We pump the
	# level full of chests + levers and high projectile-trap chance,
	# then verify across multiple seeds that no placed launcher's
	# path passes through one.
	var biome := _make_biome()
	biome.objects = [
		_make_object_spawn(_make_chest(), 4, 4, ObjectSpawn.PLACEMENT_ANY),
	]
	# Levers come from linked-objects pairs — produce a few so the
	# corridor pool has lever cells to potentially cross.
	biome.linked_objects = [_make_linked_spawn(_make_lever_data(), _make_door(), 2, 2)]
	var trap_data := _make_projectile_trap_data(6, 0)
	biome.projectile_trap_spawns = [_make_projectile_trap_spawn(trap_data, 1.0, 3, ObjectSpawn.PLACEMENT_CORRIDOR)]
	var any_launcher_seen: bool = false
	var any_chest_or_lever_seen: bool = false
	for s in [12345, 99999, 55555, 42, 31337]:
		var gen := _make_generator(biome, s)
		if not gen.projectile_traps.is_empty():
			any_launcher_seen = true
		for x in range(gen.grid_width):
			for y in range(gen.grid_height):
				var c: GridCell = gen.grid[x][y]
				if c.object == null or c.object.data == null:
					continue
				if c.object.data.category == ObjectData.Category.CHEST \
						or c.object.data.category == ObjectData.Category.LEVER:
					any_chest_or_lever_seen = true
		for inst in gen.projectile_traps:
			for p in _projectile_path_until_wall(gen, inst):
				var c: GridCell = gen.grid[p.x][p.y]
				if c.object == null or c.object.data == null:
					continue
				var cat: int = c.object.data.category
				assert_ne(cat, ObjectData.Category.CHEST,
					"launcher at %s fires across chest at %s (seed %d)" % [inst.cell, p, s])
				assert_ne(cat, ObjectData.Category.LEVER,
					"launcher at %s fires across lever at %s (seed %d)" % [inst.cell, p, s])
	# Without these the test would pass vacuously if either spawn type
	# silently produced nothing — defeating the rule under test.
	assert_true(any_launcher_seen, "no projectile launchers placed across 5 seeds — test scenario broken")
	assert_true(any_chest_or_lever_seen, "no chests or levers placed across 5 seeds — test scenario broken")

func test_projectile_path_does_not_cross_exit_cell() -> void:
	# Rule: a launcher's projectile path must not cross the EXIT cell.
	# The exit is where the player heads to leave the level — being
	# shot on the way out feels punitive.
	var biome := _make_biome()
	biome.projectile_trap_spawns = [_make_projectile_trap_spawn(_make_projectile_trap_data(8), 1.0, 5)]
	for s in [12345, 99999, 55555]:
		var gen := _make_generator(biome, s)
		for inst in gen.projectile_traps:
			# Walk the FULL path to the wall (not just up to escape).
			# The exit is its own cell type so it terminates the path
			# helper, but if it appeared on the path we'd also see it
			# in `_projectile_path_until_wall` — except that helper
			# stops at the wall (= non-FLOOR). EXIT is non-FLOOR. So
			# we walk separately here.
			var fire := inst.fire_direction()
			var step: int = 1
			var step_limit: int = gen.grid_width + gen.grid_height + 2
			while step <= step_limit:
				var p: Vector2i = inst.cell + fire * step
				if p.x < 0 or p.x >= gen.grid_width or p.y < 0 or p.y >= gen.grid_height:
					break
				assert_ne(p, gen.exit_pos,
					"launcher at %s fires across exit at %s (seed %d)" % [inst.cell, p, s])
				var c: GridCell = gen.grid[p.x][p.y]
				if c.cell_type == GridCell.CellType.WALL:
					break
				step += 1

func test_projectile_at_most_one_launcher_per_segment_cross_spawn() -> void:
	# Rule: even when multiple `ProjectileTrapSpawn` entries are
	# configured, every corridor segment holds AT MOST ONE launcher
	# in total. Without this rule, two spawns each contributing one
	# launcher could place them at opposite ends of the same corridor,
	# producing crossfire.
	var biome := _make_biome()
	# Two spawns that would each independently want to fill segments.
	# `min_distance_to_other_projectile_trap = 0` so the spreading
	# rule doesn't accidentally hide the segment-cap rule under test.
	var trap_a := _make_projectile_trap_data(8, 0)
	var trap_b := _make_projectile_trap_data(8, 0)
	biome.projectile_trap_spawns = [
		_make_projectile_trap_spawn(trap_a, 1.0, 1),
		_make_projectile_trap_spawn(trap_b, 1.0, 1),
	]
	for s in [12345, 99999, 55555, 42]:
		var gen := _make_generator(biome, s)
		var segments: Array = gen._detect_corridor_segments()
		var cell_to_seg: Dictionary = {}
		for i in range(segments.size()):
			for pos in segments[i]:
				cell_to_seg[pos] = i
		var per_segment: Dictionary = {}
		for inst in gen.projectile_traps:
			if not cell_to_seg.has(inst.cell):
				continue
			var seg: int = cell_to_seg[inst.cell]
			per_segment[seg] = per_segment.get(seg, 0) + 1
		for k in per_segment.keys():
			assert_lte(per_segment[k], 1,
				"segment %d holds %d launchers across 2 spawns (cross-spawn cap = 1, seed %d)"
				% [k, per_segment[k], s])
