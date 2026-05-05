class_name LevelGenerator
extends Node

var grid_width: int = 31
var grid_height: int = 31
var min_exit_distance: int = 10
var entrance_at_dead_end: bool = true
var exit_at_dead_end: bool = true
var maze_bias: float = 0.4
var wiggle: float = 1.0
var corridor_min_width: int = 1
var corridor_max_width: int = 1
var width_change_chance: float = 0.15
var room_count: int = 6
var room_min_size: int = 3
var room_max_size: int = 5
var floor_loot: Array[LootEntry] = []
var floor_items_min: int = 3
var floor_items_max: int = 8

var grid: Array = []
var entrance_pos: Vector2i = Vector2i.ZERO
var exit_pos: Vector2i = Vector2i.ZERO
var _current_corridor_width: int = 1
var _room_rects: Array = []

func configure(biome: BiomeData) -> void:
	if biome == null:
		push_error("LevelGenerator: biome is null, using defaults")
		return
	grid_width = biome.grid_width
	grid_height = biome.grid_height
	min_exit_distance = biome.min_exit_distance
	entrance_at_dead_end = biome.entrance_at_dead_end
	exit_at_dead_end = biome.exit_at_dead_end
	maze_bias = biome.maze_bias
	wiggle = biome.wiggle
	corridor_min_width = biome.corridor_min_width
	corridor_max_width = biome.corridor_max_width
	width_change_chance = biome.width_change_chance
	room_count = biome.room_count
	room_min_size = biome.room_min_size
	room_max_size = biome.room_max_size
	floor_loot = biome.floor_loot
	floor_items_min = biome.floor_items_min
	floor_items_max = biome.floor_items_max

func generate() -> void:
	_fill_with_walls()
	if room_count > 0:
		_place_rooms()
	_grow_maze()
	_connect_regions()
	_place_entrance_and_exit()
	if not _validate_path():
		push_warning("LevelGenerator: regenerating...")
		generate()
		return
	_place_items()

# -------------------------------------------------------
# Fill
# -------------------------------------------------------
func _fill_with_walls() -> void:
	grid = []
	for x in range(grid_width):
		var col = []
		for y in range(grid_height):
			var c = GridCell.new()
			c.cell_type = GridCell.CellType.WALL
			col.append(c)
		grid.append(col)
	_room_rects = []

# -------------------------------------------------------
# Rooms
# -------------------------------------------------------
func _place_rooms() -> void:
	_room_rects = []
	var attempts = room_count * 10
	for _i in range(attempts):
		if _room_rects.size() >= room_count:
			break
		var rw = room_min_size + randi() % max(1, room_max_size - room_min_size + 1)
		var rh = room_min_size + randi() % max(1, room_max_size - room_min_size + 1)
		var rx = 1 + (randi() % ((grid_width  - rw - 2) / 2)) * 2
		var ry = 1 + (randi() % ((grid_height - rh - 2) / 2)) * 2
		var room = Rect2i(rx, ry, rw, rh)
		if not _overlaps_any_room(room):
			_room_rects.append(room)
			_carve_rect(room)

func _overlaps_any_room(r: Rect2i) -> bool:
	for existing in _room_rects:
		var expanded = Rect2i(existing.position - Vector2i(1, 1), existing.size + Vector2i(2, 2))
		if expanded.intersects(r):
			return true
	return false

func _carve_rect(room: Rect2i) -> void:
	for x in range(room.position.x, room.end.x):
		for y in range(room.position.y, room.end.y):
			if _in_inner_bounds(x, y):
				grid[x][y].cell_type = GridCell.CellType.FLOOR

# -------------------------------------------------------
# Growing Tree maze
# -------------------------------------------------------
func _grow_maze() -> void:
	_current_corridor_width = corridor_min_width
	var active: Array = []
	var last_direction: Dictionary = {}  # cell -> Vector2i, remembers how we arrived

	var start = _find_wall_odd_cell()
	if start == Vector2i(-1, -1):
		return
	_carve_maze_cell(start, Vector2i(1, 0))
	active.append(start)
	last_direction[start] = Vector2i(1, 0)

	while not active.is_empty():
		var idx: int
		if randf() < maze_bias:
			idx = active.size() - 1
		else:
			idx = randi() % active.size()

		var cell = active[idx]
		var neighbours = _unvisited_neighbours(cell)

		if neighbours.is_empty():
			active.remove_at(idx)
		else:
			var came_from: Vector2i = last_direction.get(cell, Vector2i(1, 0))
			var chosen = _pick_neighbour(neighbours, cell, came_from)
			var direction = (chosen - cell) / 2
			var between = cell + direction
			_maybe_change_width()
			_carve_maze_cell(between, direction)
			_carve_maze_cell(chosen, direction)
			last_direction[chosen] = direction
			active.append(chosen)

func _pick_neighbour(neighbours: Array, cell: Vector2i, came_from: Vector2i) -> Vector2i:
	if neighbours.size() == 1 or wiggle == 0.0:
		return neighbours[randi() % neighbours.size()]

	# Split neighbours into same-direction and turning ones
	var straight = []
	var turning = []
	for n in neighbours:
		var dir = (n - cell) / 2
		if dir == came_from:
			straight.append(n)
		else:
			turning.append(n)

	# wiggle=0 → prefer straight, wiggle=1 → prefer turning
	var prefer_turn = randf() < wiggle
	if prefer_turn and not turning.is_empty():
		return turning[randi() % turning.size()]
	elif not prefer_turn and not straight.is_empty():
		return straight[randi() % straight.size()]
	else:
		return neighbours[randi() % neighbours.size()]

func _unvisited_neighbours(cell: Vector2i) -> Array:
	var result = []
	for d in [Vector2i(0, -2), Vector2i(0, 2), Vector2i(-2, 0), Vector2i(2, 0)]:
		var n = cell + d
		if _in_inner_bounds(n.x, n.y) and grid[n.x][n.y].cell_type == GridCell.CellType.WALL:
			result.append(n)
	return result

func _find_wall_odd_cell() -> Vector2i:
	var candidates = []
	for x in range(1, grid_width - 1, 2):
		for y in range(1, grid_height - 1, 2):
			if grid[x][y].cell_type == GridCell.CellType.WALL:
				candidates.append(Vector2i(x, y))
	if candidates.is_empty():
		return Vector2i(-1, -1)
	return candidates[randi() % candidates.size()]

func _carve_maze_cell(pos: Vector2i, direction: Vector2i) -> void:
	if not _in_inner_bounds(pos.x, pos.y):
		return

	grid[pos.x][pos.y].cell_type = GridCell.CellType.FLOOR

	if _current_corridor_width <= 1:
		return

	var perp = Vector2i(direction.y, direction.x)
	for i in range(1, _current_corridor_width):
		for side in [1, -1]:
			var nx = pos.x + perp.x * i * side
			var ny = pos.y + perp.y * i * side
			if _in_inner_bounds(nx, ny) and not _has_floor_neighbour_except(nx, ny, perp):
				grid[nx][ny].cell_type = GridCell.CellType.FLOOR

func _maybe_change_width() -> void:
	if randf() < width_change_chance:
		_current_corridor_width = corridor_min_width + randi() % max(1, corridor_max_width - corridor_min_width + 1)

func _has_floor_neighbour_except(x: int, y: int, excluded_dir: Vector2i) -> bool:
	for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		if d == excluded_dir or d == -excluded_dir:
			continue
		var nx = x + d.x
		var ny = y + d.y
		if _in_bounds(nx, ny) and grid[nx][ny].cell_type == GridCell.CellType.FLOOR:
			return true
	return false

# -------------------------------------------------------
# Connect rooms to maze
# -------------------------------------------------------
func _connect_regions() -> void:
	for room in _room_rects:
		_connect_room_to_maze(room)

func _connect_room_to_maze(room: Rect2i) -> void:
	var connectors = []
	for x in range(room.position.x - 1, room.end.x + 1):
		for y in range(room.position.y - 1, room.end.y + 1):
			if room.has_point(Vector2i(x, y)):
				continue
			if not _in_inner_bounds(x, y):
				continue
			if grid[x][y].cell_type != GridCell.CellType.WALL:
				continue
			for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				var nx = x + d.x
				var ny = y + d.y
				if _in_bounds(nx, ny) and not room.has_point(Vector2i(nx, ny)):
					if grid[nx][ny].cell_type == GridCell.CellType.FLOOR:
						connectors.append(Vector2i(x, y))
						break

	if connectors.is_empty():
		return

	connectors.shuffle()
	grid[connectors[0].x][connectors[0].y].cell_type = GridCell.CellType.FLOOR
	if connectors.size() > 1 and randf() < 0.5:
		grid[connectors[1].x][connectors[1].y].cell_type = GridCell.CellType.FLOOR

# -------------------------------------------------------
# Entrance / exit
# -------------------------------------------------------
func _place_entrance_and_exit() -> void:
	var dead_ends = _get_dead_ends()
	var floor_cells = _get_all_floor_cells()

	var entrance_pool = dead_ends if (entrance_at_dead_end and dead_ends.size() >= 2) else floor_cells
	if entrance_pool.is_empty():
		push_error("No floor cells to place entrance!")
		return

	entrance_pos = entrance_pool[randi() % entrance_pool.size()]
	grid[entrance_pos.x][entrance_pos.y].cell_type = GridCell.CellType.ENTRANCE

	var exit_pool = dead_ends if (exit_at_dead_end and dead_ends.size() >= 2) else floor_cells
	var distant = exit_pool.filter(func(pos):
		var dist = abs(pos.x - entrance_pos.x) + abs(pos.y - entrance_pos.y)
		return dist >= min_exit_distance and pos != entrance_pos
	)
	if distant.is_empty():
		distant = exit_pool.filter(func(pos): return pos != entrance_pos)

	exit_pos = distant[randi() % distant.size()]
	grid[exit_pos.x][exit_pos.y].cell_type = GridCell.CellType.EXIT
	
func _get_dead_ends() -> Array:
	var result = []
	for x in range(1, grid_width - 1):
		for y in range(1, grid_height - 1):
			if grid[x][y].cell_type != GridCell.CellType.FLOOR:
				continue
			var floor_neighbours = 0
			for d in [Vector2i(0,-1), Vector2i(0,1), Vector2i(-1,0), Vector2i(1,0)]:
				var nx = x + d.x
				var ny = y + d.y
				if _in_bounds(nx, ny) and grid[nx][ny].cell_type != GridCell.CellType.WALL:
					floor_neighbours += 1
			if floor_neighbours == 1:
				result.append(Vector2i(x, y))
	return result	

func _get_all_floor_cells() -> Array:
	var result = []
	for x in range(grid_width):
		for y in range(grid_height):
			if grid[x][y].cell_type != GridCell.CellType.WALL:
				result.append(Vector2i(x, y))
	return result

# -------------------------------------------------------
# Items
# -------------------------------------------------------
func _place_items() -> void:
	if floor_loot.is_empty():
		return

	var cells_by_type := _classify_floor_cells()
	var count := randi_range(max(0, floor_items_min), max(floor_items_min, floor_items_max))
	for _i in range(count):
		var entry := _pick_weighted_loot()
		if entry == null or entry.item == null:
			continue
		var candidates := _candidates_for_entry(entry, cells_by_type)
		if candidates.is_empty():
			continue
		var pos: Vector2i = candidates[randi() % candidates.size()]
		grid[pos.x][pos.y].items.append(ItemInstance.create(entry.item, 1))

func _classify_floor_cells() -> Dictionary:
	var result := {
		LootEntry.PLACEMENT_CORRIDOR: [],
		LootEntry.PLACEMENT_ROOM:     [],
		LootEntry.PLACEMENT_DEAD_END: [],
	}
	for x in range(1, grid_width - 1):
		for y in range(1, grid_height - 1):
			var cell: GridCell = grid[x][y]
			if cell.cell_type != GridCell.CellType.FLOOR:
				continue
			var pos := Vector2i(x, y)
			if _is_dead_end(pos):
				result[LootEntry.PLACEMENT_DEAD_END].append(pos)
			elif _is_in_room(pos):
				result[LootEntry.PLACEMENT_ROOM].append(pos)
			else:
				result[LootEntry.PLACEMENT_CORRIDOR].append(pos)
	return result

func _is_dead_end(pos: Vector2i) -> bool:
	var floor_neighbours := 0
	for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var nx: int = pos.x + d.x
		var ny: int = pos.y + d.y
		if _in_bounds(nx, ny) and grid[nx][ny].cell_type != GridCell.CellType.WALL:
			floor_neighbours += 1
	return floor_neighbours == 1

func _is_in_room(pos: Vector2i) -> bool:
	for room in _room_rects:
		if (room as Rect2i).has_point(pos):
			return true
	return false

func _pick_weighted_loot() -> LootEntry:
	var total := 0
	for entry in floor_loot:
		if entry == null or entry.item == null:
			continue
		total += max(0, entry.weight)
	if total <= 0:
		return null
	var roll := randi() % total
	for entry in floor_loot:
		if entry == null or entry.item == null:
			continue
		var w: int = max(0, entry.weight)
		if roll < w:
			return entry
		roll -= w
	return null

func _candidates_for_entry(entry: LootEntry, cells_by_type: Dictionary) -> Array:
	var result: Array = []
	for placement_bit in [LootEntry.PLACEMENT_CORRIDOR, LootEntry.PLACEMENT_ROOM, LootEntry.PLACEMENT_DEAD_END]:
		if entry.allows(placement_bit):
			for pos in cells_by_type[placement_bit]:
				if pos == entrance_pos or pos == exit_pos:
					continue
				result.append(pos)
	return result

# -------------------------------------------------------
# BFS validation
# -------------------------------------------------------
func _validate_path() -> bool:
	var visited = {}
	var queue = [entrance_pos]
	visited[entrance_pos] = true
	while not queue.is_empty():
		var current = queue.pop_front()
		if current == exit_pos:
			return true
		for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var next = current + d
			if _in_bounds(next.x, next.y) and not visited.has(next):
				if grid[next.x][next.y].cell_type != GridCell.CellType.WALL:
					visited[next] = true
					queue.append(next)
	return false

# -------------------------------------------------------
# Utility
# -------------------------------------------------------
func _in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < grid_width and y >= 0 and y < grid_height

func _in_inner_bounds(x: int, y: int) -> bool:
	return x >= 1 and x < grid_width - 1 and y >= 1 and y < grid_height - 1

func get_cell(x: int, y: int) -> GridCell:
	if _in_bounds(x, y):
		return grid[x][y]
	return null
