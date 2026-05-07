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
var objects_pool: Array[ObjectSpawn] = []
var linked_objects_pool: Array[LinkedObjectSpawn] = []
var key_door_spawns_pool: Array[KeyDoorSpawn] = []

var grid: Array = []
var entrance_pos: Vector2i = Vector2i.ZERO
var exit_pos: Vector2i = Vector2i.ZERO
var _current_corridor_width: int = 1
var _room_rects: Array = []

# Doors live on EDGES, not on cells. Authoritative list (renderer +
# map iterate this); _doors_by_edge is just an O(1) lookup index.
var doors: Array[DoorInstance] = []
var _doors_by_edge: Dictionary = {}  # edge_key (String) -> DoorInstance

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
	objects_pool = biome.objects
	linked_objects_pool = biome.linked_objects
	key_door_spawns_pool = biome.key_door_spawns

func generate() -> void:
	_fill_with_walls()
	doors.clear()
	_doors_by_edge.clear()
	if room_count > 0:
		_place_rooms()
	_grow_maze()
	_connect_regions()
	_place_entrance_and_exit()
	if not _validate_path():
		push_warning("LevelGenerator: regenerating...")
		generate()
		return
	_place_objects()
	_place_doors()
	_place_linked_objects()
	_place_key_doors()
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
# Objects (chests, doors, levers, traps, …) — placed before items so
# items can land on / next to them as the level intends.
#
# A blocking object on a FLOOR cell turns that cell into a wall for
# pathing purposes. We therefore validate after each placement that:
#   1. exit is still reachable from entrance, AND
#   2. every other floor cell is reachable too (no part of the level
#      becomes inaccessible because of the new obstacle).
# If either check fails, we undo and try a different cell.
# -------------------------------------------------------
func _place_objects() -> void:
	if objects_pool.is_empty():
		return
	var cells_by_type := _classify_floor_cells()
	for spawn in objects_pool:
		if spawn == null or spawn.object == null:
			continue
		# Doors are edge-bound; they're handled by _place_doors() and
		# never stored on a GridCell.
		if spawn.object.category == ObjectData.Category.DOOR:
			continue
		var count := randi_range(max(0, spawn.count_min), max(spawn.count_min, spawn.count_max))
		for _i in range(count):
			_try_place_object(spawn, cells_by_type)

func _try_place_object(spawn: ObjectSpawn, cells_by_type: Dictionary) -> void:
	# Snapshot what's reachable from entrance RIGHT NOW (with any
	# previously-placed chests treated as blockers). A new placement is
	# OK iff every cell currently reachable stays reachable after
	# placement (the chest's own cell is excluded), AND the chest cell
	# has at least one walkable neighbour so the player can interact.
	# This tolerates pre-existing isolated regions of the dungeon
	# (a connectorless room) — those cells were never reachable, so a
	# chest placement isn't blamed for them.
	var before_reachable := _bfs_walkable_from(entrance_pos)
	var candidates := _candidate_cells_for_spawn(spawn, cells_by_type)
	var distance: int = max(0, spawn.min_distance_to_other_object)
	while distance >= 0:
		if _attempt_place(spawn, candidates, cells_by_type, distance, before_reachable):
			return
		distance -= 1
	push_warning("LevelGenerator: could not place '%s' anywhere — no eligible cell preserves level reachability" % _spawn_label(spawn))

func _attempt_place(spawn: ObjectSpawn, candidates: Array, cells_by_type: Dictionary, min_distance: int, before_reachable: Dictionary) -> bool:
	var pool := candidates.duplicate()
	if min_distance > 0:
		var filtered: Array = []
		for pos in pool:
			if not _too_close_to_existing_object(pos, min_distance):
				filtered.append(pos)
		pool = filtered
	if pool.is_empty():
		return false
	pool.shuffle()
	for pos in pool:
		var cell: GridCell = grid[pos.x][pos.y]
		if cell.object != null:
			continue
		# Pre-check: candidate must itself be reachable from entrance
		# right now. Skips chests inside connectorless room islands.
		if not before_reachable.has(pos):
			continue
		var instance := ObjectInstance.create(spawn.object)
		instance.loot_table = spawn.loot_table
		cell.object = instance
		if _placement_preserves_reachability(pos, before_reachable):
			cells_by_type[_classify_single(pos)].erase(pos)
			return true
		cell.object = null
	return false

func _placement_preserves_reachability(placed_pos: Vector2i, before: Dictionary) -> bool:
	var after := _bfs_walkable_from(entrance_pos)
	for cell_pos in before:
		if cell_pos == placed_pos:
			continue
		if not after.has(cell_pos):
			return false
	# The chest itself must have at least one walkable neighbour so
	# the player can stand next to it and interact.
	for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		if after.has(placed_pos + d):
			return true
	return false

func _bfs_walkable_from(origin: Vector2i) -> Dictionary:
	var visited: Dictionary = {origin: true}
	var queue: Array = [origin]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var nx: int = current.x + d.x
			var ny: int = current.y + d.y
			if not _in_bounds(nx, ny):
				continue
			var npos := Vector2i(nx, ny)
			if visited.has(npos):
				continue
			var ncell: GridCell = grid[nx][ny]
			if ncell.is_blocked:
				continue
			visited[npos] = true
			queue.append(npos)
	return visited

func _spawn_label(spawn: ObjectSpawn) -> String:
	if spawn != null and spawn.object != null and spawn.object.name_key != "":
		return spawn.object.name_key
	return "<unnamed>"

func _too_close_to_existing_object(pos: Vector2i, min_distance: int) -> bool:
	if min_distance <= 0:
		return false
	for x in range(grid_width):
		for y in range(grid_height):
			if grid[x][y].object == null:
				continue
			var dist: int = abs(pos.x - x) + abs(pos.y - y)
			if dist < min_distance:
				return true
	return false

func _candidate_cells_for_spawn(spawn: ObjectSpawn, cells_by_type: Dictionary) -> Array:
	var result: Array = []
	for placement_bit in [ObjectSpawn.PLACEMENT_CORRIDOR, ObjectSpawn.PLACEMENT_ROOM, ObjectSpawn.PLACEMENT_DEAD_END]:
		if not spawn.allows(placement_bit):
			continue
		for pos in cells_by_type[placement_bit]:
			if pos == entrance_pos or pos == exit_pos:
				continue
			result.append(pos)
	return result

func _classify_single(pos: Vector2i) -> int:
	if _is_dead_end(pos):
		return ObjectSpawn.PLACEMENT_DEAD_END
	if _is_in_room(pos):
		return ObjectSpawn.PLACEMENT_ROOM
	return ObjectSpawn.PLACEMENT_CORRIDOR

# -------------------------------------------------------
# Doors (edge-based — never stored on a GridCell)
#
# A door sits on the boundary between two adjacent floor cells. Both
# cells must be 1-cell-wide-corridor cells (exactly 2 non-wall
# neighbours each), neither can be entrance / exit, and neither can
# already hold a chest / blocking object. Reachability isn't an issue
# for decorative doors — open doors don't block, and closed doors are
# always re-openable by the player. (Task 2c will add gating logic
# under ObjectSpawn.must_gate_content.)
# -------------------------------------------------------
func _place_doors() -> void:
	if objects_pool.is_empty():
		return
	for spawn in objects_pool:
		if spawn == null or spawn.object == null:
			continue
		if spawn.object.category != ObjectData.Category.DOOR:
			continue
		var count := randi_range(max(0, spawn.count_min), max(spawn.count_min, spawn.count_max))
		for _i in range(count):
			_try_place_door(spawn)

func _try_place_door(spawn: ObjectSpawn) -> void:
	# Build the candidate edge list once per door — eligibility
	# depends on already-placed doors, but the underlying corridor
	# topology is fixed.
	var candidates: Array = _candidate_edges_for_door(spawn)
	var distance: int = max(0, spawn.min_distance_to_other_object)
	while distance >= 0:
		var pool: Array = candidates.duplicate()
		if distance > 0:
			pool = pool.filter(
				func(edge): return not _too_close_to_existing_door(edge, distance)
			)
		# Filter out edges that already have a door (could happen if
		# multiple door spawns share corridors).
		pool = pool.filter(
			func(edge): return not _doors_by_edge.has(DoorInstance.edge_key(edge[0], edge[1]))
		)
		if not pool.is_empty():
			var edge: Array = pool[randi() % pool.size()]
			var inst := DoorInstance.create_door(spawn.object, edge[0], edge[1])
			doors.append(inst)
			_doors_by_edge[DoorInstance.edge_key(edge[0], edge[1])] = inst
			return
		distance -= 1
	push_warning("LevelGenerator: could not place door '%s' — no eligible 1-wide-corridor edge available" % _spawn_label(spawn))

func _candidate_edges_for_door(spawn: ObjectSpawn) -> Array:
	# Returns an Array of [cell_a, cell_b] pairs (canonically sorted)
	# where a door of this spawn type may be placed. ObjectSpawn's
	# placement flags (Corridor / Room / Dead End) are kept for symmetry
	# with chests but doors only meaningfully live on Corridor edges.
	if not spawn.allows(ObjectSpawn.PLACEMENT_CORRIDOR):
		return []
	var seen: Dictionary = {}
	var result: Array = []
	for x in range(grid_width):
		for y in range(grid_height):
			var pos := Vector2i(x, y)
			if not _is_door_endpoint(pos):
				continue
			# Only walk east + south to avoid emitting each edge twice.
			for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				var npos: Vector2i = pos + d
				if not _is_door_endpoint(npos):
					continue
				var pair: Array = DoorInstance.canonical_pair(pos, npos)
				var key: String = "%d,%d|%d,%d" % [pair[0].x, pair[0].y, pair[1].x, pair[1].y]
				if seen.has(key):
					continue
				seen[key] = true
				result.append(pair)
	return result

func _is_door_endpoint(pos: Vector2i) -> bool:
	# A cell qualifies as a door endpoint iff:
	#   - it's a non-wall cell (FLOOR / ENTRANCE / EXIT — but we exclude
	#     entrance/exit explicitly because doors must never sit on them),
	#   - it has exactly 2 non-wall orthogonal neighbours (1-wide
	#     corridor — straight or bend; T-junctions, dead-ends, room
	#     interiors are excluded by this count),
	#   - it isn't already holding a chest / blocking object.
	if not _in_bounds(pos.x, pos.y):
		return false
	var cell: GridCell = grid[pos.x][pos.y]
	if cell == null:
		return false
	if cell.cell_type == GridCell.CellType.WALL:
		return false
	if cell.cell_type == GridCell.CellType.ENTRANCE or cell.cell_type == GridCell.CellType.EXIT:
		return false
	if cell.object != null:
		return false
	var floor_neighbours := 0
	for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var nx: int = pos.x + d.x
		var ny: int = pos.y + d.y
		if _in_bounds(nx, ny) and grid[nx][ny].cell_type != GridCell.CellType.WALL:
			floor_neighbours += 1
	return floor_neighbours == 2

func _too_close_to_existing_door(edge: Array, min_distance: int) -> bool:
	if min_distance <= 0:
		return false
	var a: Vector2i = edge[0]
	var b: Vector2i = edge[1]
	for existing in doors:
		var dist: int = min(
			min(_manhattan(a, existing.cell_a), _manhattan(a, existing.cell_b)),
			min(_manhattan(b, existing.cell_a), _manhattan(b, existing.cell_b))
		)
		if dist < min_distance:
			return true
	return false

func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

# Public API used by PlayerController (movement check) and rendering.
func get_door_at_edge(a: Vector2i, b: Vector2i) -> DoorInstance:
	return _doors_by_edge.get(DoorInstance.edge_key(a, b), null)

func is_edge_blocked(a: Vector2i, b: Vector2i) -> bool:
	var d: DoorInstance = _doors_by_edge.get(DoorInstance.edge_key(a, b), null)
	if d == null:
		return false
	return d.is_edge_blocked()

# -------------------------------------------------------
# Linked objects (Phase 8 Task 2b — lever ↔ door pairs)
#
# For each LinkedObjectSpawn entry we place count pairs. Each pair
# is validated against CHAIN reachability — not just per-pair
# reachability — so the player can never end up in a stuck state
# where every lever is locked behind every door.
#
# Chain reachability simulates "starting at the entrance, opening
# every directly-clickable door, and progressively pulling every
# lever the player can reach". A pair is only accepted if, after
# placement, every placed lever AND the exit AND every chest
# remain in the chain-reachable set. This permits PROGRESSIVE
# gating (lever_1 opens door_A, behind which is lever_2 — fine)
# but rejects CYCLES (every lever locked behind every door).
#
# 2b follow-up extends this to M:N CLUSTERS: each cluster places
# `levers_per_cluster` levers and `doors_per_cluster` doors. Every
# lever cross-links to every door in the cluster, and each door's
# `lever_logic` (AND default, OR opt-in) decides whether the door
# is currently open. AND clusters require all M levers chain-
# reachable; OR clusters require at least one lever chain-reachable
# (the simulator handles this naturally — chain v2 evaluates each
# door's openness via lever_logic against the simulated_pulled set).
# 1:1 / AND falls out as a degenerate case so existing biomes are
# unaffected.
# -------------------------------------------------------
func _place_linked_objects() -> void:
	if linked_objects_pool.is_empty():
		return
	for spawn in linked_objects_pool:
		if spawn == null:
			continue
		if spawn.lever_object == null or spawn.door_object == null:
			push_warning("LevelGenerator: linked spawn missing lever or door object — skipping")
			continue
		var count := randi_range(max(0, spawn.count_min), max(spawn.count_min, spawn.count_max))
		for _i in range(count):
			_try_place_linked_cluster(spawn)

func _try_place_linked_cluster(spawn: LinkedObjectSpawn) -> void:
	# Snapshot chain reachability BEFORE the cluster lands. After
	# placement we require post_chain ⊇ pre_chain ∖ {new_lever_cells}
	# — nothing previously reachable becomes unreachable, modulo the
	# cells the new levers themselves now occupy.
	var pre_chain: Dictionary = _chain_reachable_from_entrance()

	var doors_per: int = max(1, spawn.doors_per_cluster)
	var levers_per: int = max(1, spawn.levers_per_cluster)

	var edges: Array = _candidate_edges_for_door_object(spawn.door_object, spawn.door_min_distance_to_other_object)
	edges.shuffle()
	if edges.size() < doors_per:
		push_warning("LevelGenerator: not enough candidate edges (%d) for cluster of %d doors" %
			[edges.size(), doors_per])
		return

	# Greedy walk through the candidate edges, picking `doors_per` at a
	# time. On lever-placement / chain / must_gate failure, slide the
	# window forward by 1 and retry. Bounded by the number of edges
	# minus the cluster size.
	var window_start: int = 0
	while window_start + doors_per <= edges.size():
		var doors_in_cluster: Array = []
		var combo_failed := false
		for i in range(doors_per):
			var edge: Array = edges[window_start + i]
			var a: Vector2i = edge[0]
			var b: Vector2i = edge[1]
			if _doors_by_edge.has(DoorInstance.edge_key(a, b)):
				combo_failed = true  # earlier cluster claimed this edge
				break
			var door := DoorInstance.create_door(spawn.door_object, a, b)
			door.lever_logic = spawn.lever_logic
			doors.append(door)
			_doors_by_edge[DoorInstance.edge_key(a, b)] = door
			doors_in_cluster.append(door)

		if combo_failed:
			for d in doors_in_cluster:
				doors.erase(d)
				_doors_by_edge.erase(DoorInstance.edge_key(d.cell_a, d.cell_b))
			window_start += 1
			continue

		var levers_in_cluster: Array = _try_place_levers_for_cluster(spawn, doors_in_cluster, pre_chain, levers_per)
		if not levers_in_cluster.is_empty():
			# must_gate_content: at least one door in the cluster
			# must gate something meaningful (chest / lever / key /
			# exit becomes unreachable when that door stays closed).
			# Multi-door clusters are typically redundant paths, so
			# requiring ALL doors to gate would be too strict —
			# requiring AT LEAST ONE keeps the cluster meaningful
			# while allowing the others to be parallel routes.
			if spawn.door_must_gate_content:
				var any_gates := false
				for d in doors_in_cluster:
					if _door_gates_content(d):
						any_gates = true
						break
				if not any_gates:
					_rollback_linked_cluster(doors_in_cluster, levers_in_cluster)
					window_start += 1
					continue
			return  # cluster committed

		# Lever placement failed — rollback doors and slide window.
		for d in doors_in_cluster:
			doors.erase(d)
			_doors_by_edge.erase(DoorInstance.edge_key(d.cell_a, d.cell_b))
		window_start += 1

	push_warning("LevelGenerator: could not place linked cluster (lever='%s', door='%s', %d×%d)" %
		[_obj_label(spawn.lever_object), _obj_label(spawn.door_object), levers_per, doors_per])

func _try_place_levers_for_cluster(spawn: LinkedObjectSpawn, doors_in_cluster: Array, pre_chain: Dictionary, levers_per: int) -> Array:
	# Chest-style cell classification, then a chain-reachability check
	# after committing all M levers + N doors with cross-links. Returns
	# the placed lever instances on success or an empty Array on
	# failure. Caller is responsible for rolling back the doors when
	# we return empty.
	var cells_by_type: Dictionary = _classify_floor_cells()
	var raw_pool: Array = []
	for placement_bit in [ObjectSpawn.PLACEMENT_CORRIDOR, ObjectSpawn.PLACEMENT_ROOM, ObjectSpawn.PLACEMENT_DEAD_END]:
		if (spawn.lever_placement & placement_bit) == 0:
			continue
		for pos in cells_by_type[placement_bit]:
			if pos == entrance_pos or pos == exit_pos:
				continue
			if grid[pos.x][pos.y].object != null:
				continue
			if _is_any_door_endpoint(pos):
				continue
			if not _within_lever_to_cluster_range(pos, doors_in_cluster, spawn):
				continue
			raw_pool.append(pos)
	if raw_pool.size() < levers_per:
		return []

	# Graceful-degrade min_distance, matching chest behaviour.
	var distance: int = max(0, spawn.lever_min_distance_to_other_object)
	while distance >= 0:
		var pool: Array = raw_pool.duplicate()
		if distance > 0:
			pool = pool.filter(
				func(p): return not _too_close_to_existing_object(p, distance)
			)
		if pool.size() < levers_per:
			distance -= 1
			continue
		pool.shuffle()
		# A few attempts per distance — pick `levers_per` cells, commit,
		# check chain. If the random combo fails, reshuffle and retry.
		# Bounded so a hostile pool can't burn forever.
		var attempts: int = 0
		var max_attempts: int = 6
		while attempts < max_attempts and pool.size() >= levers_per:
			attempts += 1
			var cells: Array = pool.slice(0, levers_per)
			var levers: Array = []
			for cell_pos in cells:
				var lever := LeverInstance.create_lever(spawn.lever_object)
				grid[cell_pos.x][cell_pos.y].object = lever
				levers.append(lever)
			# Cross-link: every lever sees every door, every door sees
			# every lever. lever_logic was already set on each door at
			# creation time.
			for lever in levers:
				lever.linked_doors = doors_in_cluster.duplicate()
			for door in doors_in_cluster:
				door.linked_levers = levers.duplicate()

			var post_chain: Dictionary = _chain_reachable_from_entrance()
			if _chain_preserved_after_cluster(pre_chain, post_chain, cells, doors_in_cluster, spawn.lever_logic):
				return levers  # leave mutations in place

			# Rollback this combo and reshuffle for the next attempt.
			for i in range(levers.size()):
				var pos: Vector2i = cells[i]
				grid[pos.x][pos.y].object = null
				levers[i].linked_doors = []
			for door in doors_in_cluster:
				door.linked_levers = []
			pool.shuffle()
		distance -= 1
	return []

func _candidate_edges_for_door_object(door_data: ObjectData, min_distance: int) -> Array:
	# Mirrors `_candidate_edges_for_door` but takes raw ObjectData +
	# min_distance because LinkedObjectSpawn doesn't share the
	# ObjectSpawn placement-flag shape.
	var seen: Dictionary = {}
	var result: Array = []
	for x in range(grid_width):
		for y in range(grid_height):
			var pos := Vector2i(x, y)
			if not _is_door_endpoint(pos):
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				var npos: Vector2i = pos + d
				if not _is_door_endpoint(npos):
					continue
				var pair: Array = DoorInstance.canonical_pair(pos, npos)
				var key: String = "%d,%d|%d,%d" % [pair[0].x, pair[0].y, pair[1].x, pair[1].y]
				if seen.has(key):
					continue
				seen[key] = true
				if min_distance > 0 and _too_close_to_existing_door(pair, min_distance):
					continue
				result.append(pair)
	# Avoid the unused-param warning; door_data is reserved for future
	# per-door-type placement filtering (e.g. a thick door that needs
	# 2-wide corridors).
	if door_data == null:
		return []
	return result

# -------------------------------------------------------
# Key-locked doors (Phase 8 Task 2c — door + key pairs)
#
# For each KeyDoorSpawn we place count pairs. Each pair:
#   1. Picks a 1-wide-corridor edge for the door (same eligibility
#      as decorative / lever-locked doors). The door starts CLOSED
#      with a generated lock_id.
#   2. Picks a key spawn location per `key_spawn_locations` flags
#      (Floor / Chest / Enemy Drop) — Enemy Drop is reserved for
#      Phase 10 and falls through with a warning.
#   3. Validates with chain reachability v2 (collects keys + opens
#      locked doors during the simulation): the key must be
#      reachable from entrance WITHOUT crossing this door, and after
#      placement everything that was reachable before must still be.
#   4. If `door_must_gate_content` is true, runs an extra check:
#      simulating "this door permanently closed", at least one
#      content cell (chest, lever, key, or exit) must become
#      unreachable. A lock that gates nothing is rejected.
# -------------------------------------------------------
func _place_key_doors() -> void:
	if key_door_spawns_pool.is_empty():
		return
	var counter := 0
	for spawn in key_door_spawns_pool:
		if spawn == null or spawn.door_object == null or spawn.key_item == null:
			push_warning("LevelGenerator: key-door spawn missing door or key — skipping")
			continue
		var count := randi_range(max(0, spawn.count_min), max(spawn.count_min, spawn.count_max))
		for _i in range(count):
			var prefix := spawn.lock_id_prefix
			if prefix == "":
				prefix = "lock"
			var lock_id := "%s_%d" % [prefix, counter]
			var pair_index := counter
			counter += 1
			_try_place_key_door_pair(spawn, lock_id, pair_index)

func _try_place_key_door_pair(spawn: KeyDoorSpawn, lock_id: String, pair_index: int) -> void:
	var pre_chain: Dictionary = _chain_reachable_from_entrance()
	var edges: Array = _candidate_edges_for_door_object(spawn.door_object, spawn.door_min_distance_to_other_object)
	edges.shuffle()
	for edge in edges:
		var pair: Array = edge as Array
		var a: Vector2i = pair[0]
		var b: Vector2i = pair[1]
		if _doors_by_edge.has(DoorInstance.edge_key(a, b)):
			continue

		# Tentatively place the locked door.
		var door := DoorInstance.create_door(spawn.door_object, a, b)
		door.lock_id = lock_id
		doors.append(door)
		_doors_by_edge[DoorInstance.edge_key(a, b)] = door

		if _try_place_key_for_door(spawn, door, lock_id, pair_index, pre_chain):
			# must_gate_content check — placement-time only. After we
			# confirmed the world is solvable WITH the key collectable,
			# verify the door actually GATES something when it stays
			# closed. If not, the lock is meaningless — try another
			# edge.
			if spawn.door_must_gate_content and not _door_gates_content(door):
				_rollback_key_door_pair(door)
				continue
			return
		# No key cell preserved chain reachability — roll back the door
		# and try a different edge.
		doors.erase(door)
		_doors_by_edge.erase(DoorInstance.edge_key(a, b))

	push_warning("LevelGenerator: could not place key-door pair (door='%s', key='%s', lock='%s')" %
		[_obj_label(spawn.door_object), _item_label(spawn.key_item), lock_id])

func _try_place_key_for_door(spawn: KeyDoorSpawn, paired_door: DoorInstance, lock_id: String, pair_index: int, pre_chain: Dictionary) -> bool:
	# Build a weighted ordering of enabled spawn locations. The first
	# pick is "primary" (tried first); on failure, fall through to
	# the rest in (weighted-)random order.
	var locations: Array = _ordered_key_locations(spawn)
	if locations.is_empty():
		locations = [KeyDoorSpawn.KEY_LOCATION_FLOOR]
	for location in locations:
		match location:
			KeyDoorSpawn.KEY_LOCATION_FLOOR:
				if _try_place_key_on_floor(spawn, paired_door, lock_id, pair_index, pre_chain):
					return true
			KeyDoorSpawn.KEY_LOCATION_CHEST:
				if _try_place_key_in_chest(spawn, paired_door, lock_id, pair_index, pre_chain):
					return true
			KeyDoorSpawn.KEY_LOCATION_ENEMY_DROP:
				push_warning("LevelGenerator: KEY_LOCATION_ENEMY_DROP not yet supported (Phase 10) — falling back to next enabled location")
	return false

func _ordered_key_locations(spawn: KeyDoorSpawn) -> Array:
	# Returns the spawn's enabled key locations in weighted-random
	# order. Each pick is removed from the pool, so the resulting
	# array has each enabled location exactly once.
	var entries: Array = []  # of {"loc": int, "weight": int}
	if spawn.allows_location(KeyDoorSpawn.KEY_LOCATION_FLOOR) and spawn.floor_weight > 0:
		entries.append({"loc": KeyDoorSpawn.KEY_LOCATION_FLOOR, "weight": spawn.floor_weight})
	if spawn.allows_location(KeyDoorSpawn.KEY_LOCATION_CHEST) and spawn.chest_weight > 0:
		entries.append({"loc": KeyDoorSpawn.KEY_LOCATION_CHEST, "weight": spawn.chest_weight})
	if spawn.allows_location(KeyDoorSpawn.KEY_LOCATION_ENEMY_DROP) and spawn.enemy_drop_weight > 0:
		entries.append({"loc": KeyDoorSpawn.KEY_LOCATION_ENEMY_DROP, "weight": spawn.enemy_drop_weight})
	var ordered: Array = []
	while not entries.is_empty():
		var idx: int = _pick_weighted_index(entries)
		if idx < 0:
			break
		ordered.append(entries[idx]["loc"])
		entries.remove_at(idx)
	return ordered

func _pick_weighted_index(entries: Array) -> int:
	# Picks an index into `entries` proportional to its "weight" key.
	# Returns -1 if total weight is non-positive.
	var total: int = 0
	for e in entries:
		total += max(0, int(e.get("weight", 0)))
	if total <= 0:
		return -1
	var roll: int = randi() % total
	for i in range(entries.size()):
		var w: int = max(0, int(entries[i].get("weight", 0)))
		if roll < w:
			return i
		roll -= w
	return entries.size() - 1

func _try_place_key_on_floor(spawn: KeyDoorSpawn, paired_door: DoorInstance, lock_id: String, pair_index: int, pre_chain: Dictionary) -> bool:
	var cells_by_type: Dictionary = _classify_floor_cells()
	var raw_pool: Array = []
	for placement_bit in [ObjectSpawn.PLACEMENT_CORRIDOR, ObjectSpawn.PLACEMENT_ROOM, ObjectSpawn.PLACEMENT_DEAD_END]:
		if (spawn.key_floor_placement & placement_bit) == 0:
			continue
		for pos in cells_by_type[placement_bit]:
			if pos == entrance_pos or pos == exit_pos:
				continue
			if grid[pos.x][pos.y].object != null:
				continue
			# Don't pile a key onto a cell that already holds items —
			# the player should clearly see the key as the floor item
			# at that tile.
			if not grid[pos.x][pos.y].items.is_empty():
				continue
			if _is_any_door_endpoint(pos):
				continue
			if not _within_key_to_door_range(pos, paired_door, spawn):
				continue
			raw_pool.append(pos)
	if raw_pool.is_empty():
		return false
	var distance: int = max(0, spawn.key_min_distance_to_other_object)
	while distance >= 0:
		var pool: Array = raw_pool.duplicate()
		if distance > 0:
			pool = pool.filter(
				func(p): return not _too_close_to_existing_object(p, distance)
			)
		pool.shuffle()
		for candidate in pool:
			var key_inst := ItemInstance.create(spawn.key_item, 1)
			key_inst.key_id = lock_id
			key_inst.apply_hue_shift(_hue_shift_for_pair_index(pair_index))
			grid[candidate.x][candidate.y].items.append(key_inst)
			var post_chain: Dictionary = _chain_reachable_from_entrance()
			if _chain_preserved_after_key(pre_chain, post_chain, paired_door):
				return true
			grid[candidate.x][candidate.y].items.erase(key_inst)
		distance -= 1
	return false

func _try_place_key_in_chest(spawn: KeyDoorSpawn, paired_door: DoorInstance, lock_id: String, pair_index: int, pre_chain: Dictionary) -> bool:
	# Find chests whose neighbour is in pre_chain (i.e. reachable
	# WITHOUT this lock). The chest's contents are pre-seeded with
	# the key so when the player opens it they collect the key.
	var candidates: Array = []
	for x in range(grid_width):
		for y in range(grid_height):
			var cell: GridCell = grid[x][y]
			if cell.object == null or not cell.object.is_chest():
				continue
			# When the spawn forbids stacking keys in one chest,
			# skip chests that already hold ANY key (from this
			# spawn or earlier ones).
			if not spawn.allow_multiple_keys_per_chest and _chest_holds_a_key(cell.object):
				continue
			var pos := Vector2i(x, y)
			if not _has_reachable_neighbour(pos, pre_chain):
				continue
			if not _within_key_to_door_range(pos, paired_door, spawn):
				continue
			candidates.append(pos)
	if candidates.is_empty():
		return false
	candidates.shuffle()
	for chest_pos in candidates:
		var chest: ObjectInstance = grid[chest_pos.x][chest_pos.y].object
		var key_inst := ItemInstance.create(spawn.key_item, 1)
		key_inst.key_id = lock_id
		key_inst.apply_hue_shift(_hue_shift_for_pair_index(pair_index))
		chest.items.append(key_inst)
		var post_chain: Dictionary = _chain_reachable_from_entrance()
		if _chain_preserved_after_key(pre_chain, post_chain, paired_door):
			return true
		chest.items.erase(key_inst)
	return false

func _chain_preserved_after_key(before: Dictionary, after: Dictionary, paired_door: DoorInstance) -> bool:
	# For key placement we don't add a new blocking object (the key
	# is just an item), so every cell in `before` must remain in
	# `after` — no exception cell. The locked door's two endpoints
	# must also be reachable in `after`, otherwise the door is dead
	# weight (the key opens it, but the player can't reach the door
	# itself).
	for cell_pos in before:
		if not after.has(cell_pos):
			return false
	return after.has(paired_door.cell_a) and after.has(paired_door.cell_b)

func _hue_shift_for_pair_index(index: int) -> float:
	# Per-pair key hue rotation in [0, 1). Pair 0 returns 0.0 (no
	# shift — original art preserved). Pair >= 1 gets a golden-ratio-
	# stepped hue rotation, scaled by HUE_SHIFT_STRENGTH to soften
	# the difference between pairs. At 1.0 the shifts span the full
	# colour wheel (very vivid distinctions); at 0.65 they stay
	# closer to the original hue while remaining clearly different
	# from each other and from pair 0. Tweak the constant to taste.
	if index <= 0:
		return 0.0
	const HUE_SHIFT_STRENGTH := 0.4
	var raw: float = fmod(float(index) * 0.61803398875, 1.0)
	return raw * HUE_SHIFT_STRENGTH

func _chest_holds_a_key(chest: ObjectInstance) -> bool:
	if chest == null:
		return false
	for item in chest.items:
		if item != null and item.get_key_id() != "":
			return true
	return false

func _within_key_to_door_range(key_pos: Vector2i, paired_door: DoorInstance, spawn: KeyDoorSpawn) -> bool:
	var min_d: int = max(0, spawn.key_to_door_min_distance)
	var max_d: int = spawn.key_to_door_max_distance
	if min_d == 0 and max_d < 0:
		return true
	var dist: int = min(_manhattan(key_pos, paired_door.cell_a),
		_manhattan(key_pos, paired_door.cell_b))
	if dist < min_d:
		return false
	if max_d >= 0 and dist > max_d:
		return false
	return true

func _door_gates_content(door: DoorInstance) -> bool:
	# True iff closing this door (alone) cuts off at least one chest
	# cell, lever cell, key cell, or the exit. Used by
	# must_gate_content to reject locks that gate nothing meaningful.
	var excluded: Dictionary = {DoorInstance.edge_key(door.cell_a, door.cell_b): true}
	var restricted_chain: Dictionary = _chain_reachable_from_entrance(excluded)
	for x in range(grid_width):
		for y in range(grid_height):
			var cell: GridCell = grid[x][y]
			var pos := Vector2i(x, y)
			# Exit
			if cell.cell_type == GridCell.CellType.EXIT:
				if not restricted_chain.has(pos):
					return true
			# Chest / lever — reachable means at least one neighbour
			if cell.object != null and (cell.object.is_chest() or cell.object is LeverInstance):
				if not _has_reachable_neighbour(pos, restricted_chain):
					return true
			# Floor keys
			for item in cell.items:
				if item != null and item.get_key_id() != "":
					if not restricted_chain.has(pos):
						return true
			# Chest keys (cell hosts a chest with a key inside)
			if cell.object != null and cell.object.is_chest():
				for item in cell.object.items:
					if item != null and item.get_key_id() != "":
						if not _has_reachable_neighbour(pos, restricted_chain):
							return true
	return false

func _rollback_linked_cluster(doors_in_cluster: Array, levers_in_cluster: Array) -> void:
	# Mirror of _rollback_key_door_pair but for lever-locked clusters.
	# Removes every door in the cluster AND clears every cell holding
	# a lever in the cluster. Used when door_must_gate_content rejects
	# an otherwise-valid placement.
	for x in range(grid_width):
		for y in range(grid_height):
			var cell: GridCell = grid[x][y]
			if cell.object != null and cell.object in levers_in_cluster:
				cell.object = null
	for lever in levers_in_cluster:
		if lever != null:
			lever.linked_doors = []
	for door in doors_in_cluster:
		if door == null:
			continue
		door.linked_levers = []
		doors.erase(door)
		_doors_by_edge.erase(DoorInstance.edge_key(door.cell_a, door.cell_b))

func _rollback_key_door_pair(door: DoorInstance) -> void:
	# Remove the door from the doors list / index AND any items
	# (floor or chest) we tentatively placed for this lock.
	doors.erase(door)
	_doors_by_edge.erase(DoorInstance.edge_key(door.cell_a, door.cell_b))
	for x in range(grid_width):
		for y in range(grid_height):
			var cell: GridCell = grid[x][y]
			var floor_to_drop: Array = []
			for item in cell.items:
				if item != null and item.get_key_id() == door.lock_id:
					floor_to_drop.append(item)
			for k in floor_to_drop:
				cell.items.erase(k)
			if cell.object != null and cell.object.is_chest():
				var chest_to_drop: Array = []
				for item in cell.object.items:
					if item != null and item.get_key_id() == door.lock_id:
						chest_to_drop.append(item)
				for k in chest_to_drop:
					cell.object.items.erase(k)

func _item_label(data: ItemData) -> String:
	if data != null and data.item_name != "":
		return data.item_name
	return "<unnamed-item>"

# -------------------------------------------------------
# Chain reachability — the safety net for multi-pair lever placement
# -------------------------------------------------------
func _chain_reachable_from_entrance(excluded_door_keys: Dictionary = {}) -> Dictionary:
	# Chain reachability v2 — tracks both open doors AND collected
	# keys. Iterative fixed-point:
	#   1. Start with every directly-clickable door treated as open
	#      (the player can click them anytime). No keys yet.
	#   2. BFS from entrance using current open set.
	#   3. Find every reachable lever — mark its linked doors as
	#      openable. Find every reachable key (on the floor OR inside
	#      a reachable chest) — add its key_id to collected. Find
	#      every locked door whose lock_id is collected — mark it as
	#      openable.
	#   4. If any of step 3 changed the open set, re-BFS. Otherwise
	#      we've reached the fixed point.
	#
	# `excluded_door_keys` (optional) is a set of edge_keys that are
	# treated as PERMANENTLY CLOSED regardless of their normal
	# openability rules. Used by the must_gate_content check to
	# simulate "what's reachable if THIS door never opens?".
	var open_door_keys: Dictionary = {}
	var collected_keys: Dictionary = {}
	for door in doors:
		var k0 := DoorInstance.edge_key(door.cell_a, door.cell_b)
		if excluded_door_keys.has(k0):
			continue
		if door.data != null and door.data.interactable and not door.is_key_locked():
			open_door_keys[k0] = true
	var reachable: Dictionary = {}
	while true:
		reachable = _bfs_with_doors_state(entrance_pos, open_door_keys)
		var progressed: bool = false
		# Collect keys lying on the floor or inside reachable chests.
		for x in range(grid_width):
			for y in range(grid_height):
				var cell: GridCell = grid[x][y]
				var pos := Vector2i(x, y)
				# Floor keys: any item in cell.items whose data is a KEY.
				if not cell.items.is_empty() and reachable.has(pos):
					for item in cell.items:
						if item == null:
							continue
						var kid: String = item.get_key_id()
						if kid != "" and not collected_keys.has(kid):
							collected_keys[kid] = true
							progressed = true
				# Chest keys: items inside a chest whose neighbour is
				# reachable. The player walks up and opens the chest.
				if cell.object != null and cell.object.is_chest():
					if not _has_reachable_neighbour(pos, reachable):
						continue
					for item in cell.object.items:
						if item == null:
							continue
						var kid2: String = item.get_key_id()
						if kid2 != "" and not collected_keys.has(kid2):
							collected_keys[kid2] = true
							progressed = true
		# Pull every reachable lever (one-shot — never un-pulled in the
		# simulation, mirrors a player who optimally pulls every lever
		# they encounter). Levers are tracked separately from open
		# doors because a single lever might be one of several an
		# AND-door requires; the door only flips open once ALL its
		# linked levers are in this set.
		var simulated_pulled: Dictionary = {}
		for x in range(grid_width):
			for y in range(grid_height):
				var cell: GridCell = grid[x][y]
				if not (cell.object is LeverInstance):
					continue
				var pos := Vector2i(x, y)
				if not _has_reachable_neighbour(pos, reachable):
					continue
				simulated_pulled[cell.object] = true
		# Evaluate every lever-locked door under its lever_logic
		# (AND vs OR) against the simulated_pulled set. With AND, a
		# door opens only when EVERY linked lever is reachable; with
		# OR, when any one is.
		for door in doors:
			if door.linked_levers.is_empty():
				continue
			var key := DoorInstance.edge_key(door.cell_a, door.cell_b)
			if excluded_door_keys.has(key):
				continue
			if open_door_keys.has(key):
				continue
			var sim_pulled_pred: Callable = func(lever): return lever != null and simulated_pulled.has(lever)
			if door._evaluate_lever_logic_with(sim_pulled_pred):
				open_door_keys[key] = true
				progressed = true
		# Unlock every locked door whose key is collected.
		for door in doors:
			if door.lock_id == "":
				continue
			if not collected_keys.has(door.lock_id):
				continue
			var key2 := DoorInstance.edge_key(door.cell_a, door.cell_b)
			if excluded_door_keys.has(key2):
				continue
			if not open_door_keys.has(key2):
				open_door_keys[key2] = true
				progressed = true
		if not progressed:
			return reachable
	return {}

func _bfs_with_doors_state(origin: Vector2i, open_door_keys: Dictionary) -> Dictionary:
	# BFS treating each door in `doors` as closed UNLESS its edge_key
	# is in `open_door_keys`. Powers the chain-reachability loop.
	var closed_edges: Dictionary = {}
	for door in doors:
		var key := DoorInstance.edge_key(door.cell_a, door.cell_b)
		if not open_door_keys.has(key):
			closed_edges[key] = true
	return _bfs_walkable_with_closed_edges(origin, closed_edges)

func _has_reachable_neighbour(pos: Vector2i, reachable: Dictionary) -> bool:
	for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		if reachable.has(pos + d):
			return true
	return false

func _chain_preserved_after_cluster(before: Dictionary, after: Dictionary, new_lever_cells: Array, doors_in_cluster: Array, lever_logic: int) -> bool:
	# Every cell reachable BEFORE the cluster must still be reachable
	# AFTER (modulo the new lever cells themselves, which may now host
	# a blocking lever). Plus each lever-cluster must be USEFUL:
	#   - AND-cluster: ALL levers must have a reachable neighbour, since
	#     every lever has to be pulled for the cluster's doors to ever
	#     open. If any lever stays unreachable, the cluster is unsolvable.
	#   - OR-cluster: AT LEAST ONE lever must have a reachable neighbour
	#     (any pull opens all doors; the others can sit behind them as
	#     "secondary" levers, harmless).
	# Implicit consequences mirror the 1:1 case:
	#   - existing levers / chests stay reachable (their neighbours were
	#     in `before`)
	#   - exit stays reachable (it was in `before`, post-`_validate_path`)
	# `doors_in_cluster` is unused today but accepted so future
	# extensions (e.g. weighting OR-clusters by lever-side distribution)
	# don't have to plumb extra args through.
	if doors_in_cluster == null:
		return false
	var lever_cell_set: Dictionary = {}
	for c in new_lever_cells:
		lever_cell_set[c] = true
	for cell_pos in before:
		if lever_cell_set.has(cell_pos):
			continue
		if not after.has(cell_pos):
			return false
	# Lever usability check, dispatched by logic.
	if lever_logic == DoorInstance.LeverLogic.AND:
		for cell_pos in new_lever_cells:
			if not _has_reachable_neighbour(cell_pos, after):
				return false
		return true
	# OR
	for cell_pos in new_lever_cells:
		if _has_reachable_neighbour(cell_pos, after):
			return true
	return false

func _bfs_walkable_with_closed_edges(origin: Vector2i, closed_edges: Dictionary) -> Dictionary:
	# Same as _bfs_walkable_from but treats the given edges as walls.
	# Powers chain reachability for linked-pair validation.
	var visited: Dictionary = {origin: true}
	var queue: Array = [origin]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var nx: int = current.x + d.x
			var ny: int = current.y + d.y
			if not _in_bounds(nx, ny):
				continue
			var npos := Vector2i(nx, ny)
			if visited.has(npos):
				continue
			var ncell: GridCell = grid[nx][ny]
			if ncell.is_blocked:
				continue
			if closed_edges.has(DoorInstance.edge_key(current, npos)):
				continue
			visited[npos] = true
			queue.append(npos)
	return visited

func _obj_label(data: ObjectData) -> String:
	if data != null and data.name_key != "":
		return data.name_key
	return "<unnamed>"

func _is_any_door_endpoint(pos: Vector2i) -> bool:
	# Levers must never sit on a cell that's also a door endpoint —
	# either decorative or linked (including the door this lever is
	# being paired with). Visually the lever-right-next-to-its-door
	# case reads as redundant; mechanically a lever inside the door's
	# slab projection is just confusing.
	for door in doors:
		if door.cell_a == pos or door.cell_b == pos:
			return true
	return false

func _within_lever_to_cluster_range(lever_pos: Vector2i, doors_in_cluster: Array, spawn: LinkedObjectSpawn) -> bool:
	# Hard-constraint check: the lever's nearest-endpoint distance to
	# the NEAREST door in its cluster must lie in [min, max] Manhattan
	# tiles. max < 0 means unlimited. min == 0 means no minimum.
	# For 1-door clusters this collapses to the original 1:1 rule.
	var min_d: int = max(0, spawn.lever_to_door_min_distance)
	var max_d: int = spawn.lever_to_door_max_distance
	if min_d == 0 and max_d < 0:
		return true
	var nearest: int = -1
	for door in doors_in_cluster:
		if door == null:
			continue
		var d: int = min(_manhattan(lever_pos, door.cell_a),
			_manhattan(lever_pos, door.cell_b))
		if nearest < 0 or d < nearest:
			nearest = d
	if nearest < 0:
		return false  # no doors — degenerate, reject
	if nearest < min_d:
		return false
	if max_d >= 0 and nearest > max_d:
		return false
	return true

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
		var base_candidates := _candidates_for_entry(entry, cells_by_type)
		if base_candidates.is_empty():
			continue
		# Graceful degrade on min_distance: try with the configured
		# distance first; if no candidate qualifies, relax by 1 and try
		# again, all the way down to 0. The constraint is per-roll so
		# we don't carry partial progress between rolls.
		var distance: int = max(0, entry.min_distance_to_other_item)
		while distance >= 0:
			var candidates: Array = base_candidates
			if distance > 0:
				candidates = base_candidates.filter(
					func(p): return not _too_close_to_existing_item(p, distance)
				)
			if not candidates.is_empty():
				var pos: Vector2i = candidates[randi() % candidates.size()]
				grid[pos.x][pos.y].items.append(ItemInstance.create(entry.item, 1))
				break
			distance -= 1

func _too_close_to_existing_item(pos: Vector2i, min_distance: int) -> bool:
	if min_distance <= 0:
		return false
	for x in range(grid_width):
		for y in range(grid_height):
			if grid[x][y].items.is_empty():
				continue
			var dist: int = abs(pos.x - x) + abs(pos.y - y)
			if dist < min_distance:
				return true
	return false

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
			if cell.is_blocked:
				# A blocking object already sits here (chest, door, …)
				# — the player can't stand on it, so items shouldn't pile
				# on it either.
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
