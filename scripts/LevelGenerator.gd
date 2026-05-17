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
var trap_spawns_pool: Array[TrapSpawn] = []
var projectile_trap_spawns_pool: Array[ProjectileTrapSpawn] = []
var spinner_spawns_pool: Array[SpinnerSpawn] = []
var wall_decorations_pool: Array[WallDecorationSpawn] = []
var secret_wall_spawns_pool: Array[SecretWallSpawn] = []
# Outdoor-mode filler sprites — trees, rocks, bushes spawned on
# WALL cells + border ring in `outdoor_mode` biomes (BiomeData). The
# placement pass `_place_fillers()` is a no-op for non-outdoor biomes
# (empty pool, nothing to do).
var filler_spawns_pool: Array[FillerSpawn] = []
# When true, _place_fillers() also seeds the border ring outside the
# grid (configured per-FillerSpawn). When false, fillers stay inside
# the grid even if the biome opts in. Mirrors BiomeData.outdoor_mode
# — the renderer uses the same flag to decide whether to skip wall
# quads.
var outdoor_mode: bool = false
# Phase 15 Task 6 — Phase A. Singular (NOT array) — one teleporter
# config per biome. Null = no teleporters this biome.
var teleporter_spawn_config: TeleporterSpawn = null

var grid: Array = []
var entrance_pos: Vector2i = Vector2i.ZERO
var exit_pos: Vector2i = Vector2i.ZERO
var _current_corridor_width: int = 1
var _room_rects: Array = []

# Doors live on EDGES, not on cells. Authoritative list (renderer +
# map iterate this); _doors_by_edge is just an O(1) lookup index.
var doors: Array[DoorInstance] = []
var _doors_by_edge: Dictionary = {}  # edge_key (String) -> DoorInstance

# Secret walls also live on EDGES. The list + index mirror doors so
# the renderer (DungeonView) and the map (MapPopup) can iterate them
# the same way. Secret walls are PURELY VISUAL — they never appear in
# the movement-blocking edge check (PlayerController + chain
# reachability ignore them entirely). Placement still excludes edges
# already used by doors so the two systems don't fight over the same
# corridor edge.
var secret_walls: Array[SecretWallInstance] = []
var _secret_walls_by_edge: Dictionary = {}  # edge_key (String) -> SecretWallInstance

# Wall-mounted decorations live on FACES (a side of a floor cell that
# abuts a wall cell), not on cells. Authoritative list — DungeonView
# iterates this and the placement code prevents two decos from sharing
# the same face via _wall_faces_used.
var wall_decorations: Array[WallDecorationInstance] = []
var _wall_faces_used: Dictionary = {}  # face_key (String) -> true

# Outdoor-mode filler sprites — runtime placements. Each instance is
# a single billboarded sprite (tree, rock, bush) sitting on a WALL
# cell (or a cell in the border ring outside the grid). The renderer
# (DungeonView._build_fillers) iterates this list and emits one
# Sprite3D per entry. Empty for non-outdoor biomes.
var fillers: Array[FillerInstance] = []

# Traps live on cells (`GridCell.trap`) but we also keep a flat list
# so the renderer + Game tick can iterate without re-scanning the
# whole grid each frame. Subtask A places single-cell traps; Subtask
# B layers corridor clusters / room density.
var traps: Array[TrapInstance] = []
# Subset of trap cells produced by the corridor-cluster pass (Subtask
# B1). The scattered pass uses this to exclude its candidates from
# being 4-adjacent to a cluster cell — without it, a 5-cell segment
# with a 3-cell cluster leaves the 2 leftover cells eligible for
# scattered placement, producing a contiguous run of 5 traps that
# defeats the per-segment cluster cap.
var _cluster_cells: Dictionary = {}

# Wall-mounted projectile launchers (Phase 8 Task 3 — Subtask C).
# Live on wall FACES (cell + wall_dir) like wall decorations and share
# the same `_wall_faces_used` registry so a face never holds both a
# decoration and a launcher. Authoritative list — DungeonView iterates
# this for rendering and Game ticks each entry's firing logic (C2).
var projectile_traps: Array[ProjectileTrapInstance] = []
# Active in-flight projectiles (Phase 8 Task 3 — Subtask C2). Spawned
# by launcher tick rollovers and removed on IMPACT. Game.gd advances
# every entry each frame and DungeonView mirrors them as Sprite3D
# billboards under `ProjectilesRoot`.
var projectiles: Array[ProjectileInstance] = []
# Every cell that lies on the projectile path of an already-placed
# launcher (from the cell directly opposite the wall up to and
# including the cell where the projectile dies — past the escape
# junction, all the way to the terminating wall). The placer rejects
# any new candidate whose path would cross a cell in this set, so two
# launchers can never have overlapping fire lines. Catches the
# crossfire cases the per-segment cap alone would miss: two launchers
# in perpendicular corridors both targeting the same T-junction would
# land the player in dual line of fire when they try to escape.
var _projectile_path_cells: Dictionary = {}

# Spinners live on cells (`GridCell.spinner`) — flat list mirrors the
# grid slots so the renderer + Game-tick can iterate without a per-
# frame grid scan (Phase 8 Task 8). Placement enforces mutual exclusion
# vs traps, objects (chest / lever), projectile-trap plate cells, and
# floor items.
var spinners: Array[SpinnerInstance] = []
# Subset of spinner cells produced by the corridor-cluster pass —
# scattered placements use this to avoid being 4-adjacent to a cluster
# (mirrors `_cluster_cells` for traps).
var _spinner_cluster_cells: Dictionary = {}

# Teleporter pairs (Phase 15 Task 6). Both endpoints of a pair point
# to the SAME instance — `cell.teleporter` on each endpoint cell is
# the per-cell lookup; this list is the renderer + map iteration
# source. Phase A places pairs at random non-special floor cells;
# Phase C will replace this with island-topology partitioning.
var teleporters: Array[TeleporterInstance] = []

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
	trap_spawns_pool = biome.trap_spawns
	projectile_trap_spawns_pool = biome.projectile_trap_spawns
	spinner_spawns_pool = biome.spinner_spawns
	wall_decorations_pool = biome.wall_decorations
	secret_wall_spawns_pool = biome.secret_wall_spawns
	teleporter_spawn_config = biome.teleporter_spawn
	filler_spawns_pool = biome.filler_spawns
	outdoor_mode = biome.outdoor_mode

func generate() -> void:
	_fill_with_walls()
	doors.clear()
	_doors_by_edge.clear()
	wall_decorations.clear()
	_wall_faces_used.clear()
	fillers.clear()
	traps.clear()
	_cluster_cells.clear()
	projectile_traps.clear()
	projectiles.clear()
	_projectile_path_cells.clear()
	spinners.clear()
	_spinner_cluster_cells.clear()
	secret_walls.clear()
	_secret_walls_by_edge.clear()
	teleporters.clear()
	if room_count > 0:
		_place_rooms()
	_grow_maze()
	_connect_regions()
	_place_entrance_and_exit()
	if not _validate_path():
		push_warning("LevelGenerator: regenerating...")
		generate()
		return
	# Phase 15 Task 6 — Phase C. Partition pass runs FIRST (right after
	# _validate_path) so every downstream placement pass sees the
	# island-split topology. Only fires if the biome opts in via
	# `island_count_max >= 2`; otherwise the legacy Phase A
	# `_place_teleporters()` at the end of the pipeline handles
	# shortcut pairs instead. The two modes are mutually exclusive.
	_partition_and_place_teleporters_if_enabled()
	_place_objects()
	_place_doors()
	_place_linked_objects()
	_place_key_doors()
	_place_traps()
	_validate_chest_lever_timed_adjacency()
	_validate_timed_trap_safe_distance()
	_place_items()
	_validate_step_trap_reachability()
	_place_projectile_traps()
	_place_spinners()
	_place_secret_walls()
	_place_teleporters()
	_place_wall_decorations()
	_place_fillers()

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
	#
	# Strategy:
	#   - When `min_distance_to_other_object > 0`: farthest-point
	#     insertion. Each new chest goes to the candidate cell that
	#     MAXIMIZES the Manhattan distance to the nearest already-placed
	#     object. This keeps chests well-spread even on layouts where the
	#     configured floor is geometrically impossible — the old
	#     "degrade min_distance to 0, then shuffle" approach silently
	#     collapsed to random placement, which biases toward big rooms
	#     (a 5×5 room contributes 25 candidate cells vs. one per
	#     dead-end) and clusters chests together.
	#   - When `min_distance_to_other_object == 0`: legacy shuffle.
	#     The designer explicitly opted out of spacing, so don't force
	#     spread.
	var before_reachable := _bfs_walkable_from(entrance_pos)
	var candidates := _candidate_cells_for_spawn(spawn, cells_by_type)
	var viable: Array = []
	for pos in candidates:
		if grid[pos.x][pos.y].object != null:
			continue
		if not before_reachable.has(pos):
			continue
		viable.append(pos)
	if viable.is_empty():
		push_warning("LevelGenerator: could not place '%s' anywhere — no eligible cell preserves level reachability" % _spawn_label(spawn))
		return

	var min_required: int = max(0, spawn.min_distance_to_other_object)
	var ordered: Array
	if min_required > 0:
		ordered = _rank_by_farthest_object(viable)
	else:
		ordered = []
		viable.shuffle()
		for pos in viable:
			ordered.append([-1, pos])

	for entry in ordered:
		var score: int = entry[0]
		var pos: Vector2i = entry[1]
		var cell: GridCell = grid[pos.x][pos.y]
		if cell.object != null:
			continue
		var instance := ObjectInstance.create(spawn.object)
		instance.loot_table = spawn.loot_table
		cell.object = instance
		if _placement_preserves_reachability(pos, before_reachable):
			cells_by_type[classify_cell(pos)].erase(pos)
			if min_required > 0 and score >= 0 and score < min_required:
				push_warning("LevelGenerator: placed '%s' at distance %d to nearest object (configured floor: %d) — biome geometry doesn't permit further spread" % [_spawn_label(spawn), score, min_required])
			return
		cell.object = null
	push_warning("LevelGenerator: could not place '%s' anywhere — no eligible cell preserves level reachability" % _spawn_label(spawn))

# Rank candidate cells by Manhattan distance to the NEAREST already-placed
# object (descending). Cells with no other object on the grid get a sentinel
# score of -1 (treated as "max possible"). Ties are shuffled within their
# score group so the choice is non-deterministic when geometry doesn't
# break ties for us.
func _rank_by_farthest_object(positions: Array) -> Array:
	var has_any_object := false
	for x in range(grid_width):
		if has_any_object:
			break
		for y in range(grid_height):
			if grid[x][y].object != null:
				has_any_object = true
				break
	var scored: Array = []
	for pos in positions:
		var score: int
		if has_any_object:
			score = _nearest_object_distance(pos)
		else:
			score = -1
		scored.append([score, pos])
	scored.sort_custom(func(a, b): return a[0] > b[0])
	var i := 0
	while i < scored.size():
		var j := i
		while j < scored.size() and scored[j][0] == scored[i][0]:
			j += 1
		if j - i > 1:
			var slice: Array = scored.slice(i, j)
			slice.shuffle()
			for k in range(slice.size()):
				scored[i + k] = slice[k]
		i = j
	return scored

func _nearest_object_distance(pos: Vector2i) -> int:
	var best: int = -1
	for x in range(grid_width):
		for y in range(grid_height):
			if grid[x][y].object == null:
				continue
			var dist: int = abs(pos.x - x) + abs(pos.y - y)
			if best == -1 or dist < best:
				best = dist
	return best

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

# Public — DungeonView calls this per floor cell to pick a texture
# variant. Returns one of the PLACEMENT_* constants. For wall cells
# the result is arbitrary (the predicates fall through to
# PLACEMENT_CORRIDOR), so the renderer only calls this on floor cells.
func classify_cell(pos: Vector2i) -> int:
	if _is_dead_end(pos):
		return ObjectSpawn.PLACEMENT_DEAD_END
	if _is_in_room(pos):
		return ObjectSpawn.PLACEMENT_ROOM
	return ObjectSpawn.PLACEMENT_CORRIDOR

# Per-wall-face classification used by the renderer when picking a
# wall texture variant. Mostly mirrors `classify_cell`, with one
# special case: at a dead-end cell, only the BACK wall (opposite the
# single open direction the player walks in from) inherits
# `PLACEMENT_DEAD_END`. The two side walls behave as corridor walls,
# so a dead-end-only texture (e.g. a giant tree at the end of the
# tunnel) appears once in front of the player rather than wrapping
# the cell on three sides.
func classify_wall_face(pos: Vector2i, wall_dir: Vector2i) -> int:
	if _is_dead_end(pos):
		var open_dir: Vector2i = _dead_end_open_dir(pos)
		if open_dir != Vector2i.ZERO and wall_dir == -open_dir:
			return ObjectSpawn.PLACEMENT_DEAD_END
		return ObjectSpawn.PLACEMENT_CORRIDOR
	if _is_in_room(pos):
		return ObjectSpawn.PLACEMENT_ROOM
	return ObjectSpawn.PLACEMENT_CORRIDOR

# Direction from a dead-end cell toward its single floor neighbour.
# Returns Vector2i.ZERO if `pos` isn't a dead end, so callers can
# branch on the result without re-running `_is_dead_end`.
func _dead_end_open_dir(pos: Vector2i) -> Vector2i:
	for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var nx: int = pos.x + d.x
		var ny: int = pos.y + d.y
		if _in_bounds(nx, ny) and grid[nx][ny].cell_type != GridCell.CellType.WALL:
			return d
	return Vector2i.ZERO

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
	#   - it isn't already holding a chest / blocking object,
	#   - it isn't already a teleporter endpoint (Phase 15 Task 6 —
	#     Phase C: the partition pass runs before doors / secret walls,
	#     so a teleporter endpoint shouldn't double-host a door slab or
	#     a secret-wall edge endpoint).
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
	if cell.teleporter != null:
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
# Linked objects (Phase 8 Task 2b follow-up — M:N lever ↔ door
# clusters). Each LinkedObjectSpawn produces N independent clusters.
# A cluster contains levers_per_cluster levers and doors_per_cluster
# doors, all cross-linked. A door's opened state is a function of
# the pulled state of every lever in its cluster, evaluated under
# the cluster's AND/OR rule.
# -------------------------------------------------------

const _CLUSTER_OUTER_ATTEMPTS := 30
const _CLUSTER_INNER_ATTEMPTS := 30

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
			_try_place_cluster(spawn)

func _try_place_cluster(spawn: LinkedObjectSpawn) -> void:
	var pre_chain: Dictionary = _chain_reachable_from_entrance()
	var n_doors: int = max(1, spawn.doors_per_cluster)
	var n_levers: int = max(1, spawn.levers_per_cluster)

	for _outer in range(_CLUSTER_OUTER_ATTEMPTS):
		var cluster_doors: Array = []
		var cluster_levers: Array = []
		var cluster_lever_positions: Array = []

		# --- Phase 1: place doors ---
		if not _try_place_cluster_doors(spawn, n_doors, cluster_doors):
			_rollback_cluster(cluster_doors, cluster_lever_positions, cluster_levers)
			continue

		# --- Phase 2: place levers ---
		if not _try_place_cluster_levers(spawn, n_levers, cluster_doors, cluster_levers, cluster_lever_positions, pre_chain):
			_rollback_cluster(cluster_doors, cluster_lever_positions, cluster_levers)
			continue

		# --- Phase 3: final validation ---
		var post_chain: Dictionary = _chain_reachable_from_entrance()
		if not _chain_preserved_after_cluster(pre_chain, post_chain, cluster_lever_positions):
			_rollback_cluster(cluster_doors, cluster_lever_positions, cluster_levers)
			continue

		if spawn.door_must_gate_content:
			var any_gates := false
			for door in cluster_doors:
				if _door_gates_content(door):
					any_gates = true
					break
			if not any_gates:
				_rollback_cluster(cluster_doors, cluster_lever_positions, cluster_levers)
				continue

		return  # cluster committed

	push_warning("LevelGenerator: could not place cluster (lever='%s', door='%s', %d×%d)" %
		[_obj_label(spawn.lever_object), _obj_label(spawn.door_object), n_levers, n_doors])

func _try_place_cluster_doors(spawn: LinkedObjectSpawn, n_doors: int, cluster_doors: Array) -> bool:
	var base_edges: Array = _candidate_edges_for_door_object(spawn.door_object, 0)
	base_edges.shuffle()
	for _door_i in range(n_doors):
		var pool: Array = []
		for edge in base_edges:
			if _doors_by_edge.has(DoorInstance.edge_key(edge[0], edge[1])):
				continue
			if spawn.door_min_distance_to_other_object > 0:
				if _too_close_to_existing_door(edge, spawn.door_min_distance_to_other_object):
					continue
			pool.append(edge)
		if pool.is_empty():
			return false
		var edge: Array = pool[randi() % pool.size()]
		var door := DoorInstance.create_door(spawn.door_object, edge[0], edge[1])
		door.lever_logic = spawn.lever_logic
		doors.append(door)
		_doors_by_edge[DoorInstance.edge_key(edge[0], edge[1])] = door
		cluster_doors.append(door)
	return true

func _try_place_cluster_levers(spawn: LinkedObjectSpawn, n_levers: int, cluster_doors: Array, cluster_levers: Array, cluster_lever_positions: Array, pre_chain: Dictionary) -> bool:
	var and_reachable: Dictionary = {}
	if spawn.lever_logic == DoorInstance.LeverLogic.AND:
		var excluded: Dictionary = {}
		for door in cluster_doors:
			excluded[DoorInstance.edge_key(door.cell_a, door.cell_b)] = true
		and_reachable = _chain_reachable_from_entrance(excluded)

	for _lever_i in range(n_levers):
		if not _try_place_one_cluster_lever(spawn, cluster_doors, cluster_levers, cluster_lever_positions, pre_chain, and_reachable):
			return false
	return true

func _try_place_one_cluster_lever(spawn: LinkedObjectSpawn, cluster_doors: Array, cluster_levers: Array, cluster_lever_positions: Array, pre_chain: Dictionary, and_reachable: Dictionary) -> bool:
	var distance: int = max(0, spawn.lever_min_distance_to_other_object)
	while distance >= 0:
		var obj_snapshot: Array = _snapshot_occupied_cells()
		var pool: Array = _build_lever_candidate_pool(spawn, cluster_doors, cluster_lever_positions, distance, obj_snapshot, and_reachable)
		var attempts := 0
		while attempts < _CLUSTER_INNER_ATTEMPTS and not pool.is_empty():
			var idx: int
			if cluster_lever_positions.is_empty():
				idx = randi() % pool.size()
			else:
				idx = _pick_farthest_from(pool, cluster_lever_positions)
			var candidate: Vector2i = pool[idx]
			pool.remove_at(idx)

			var lever := LeverInstance.create_lever(spawn.lever_object)
			grid[candidate.x][candidate.y].object = lever
			lever.linked_doors = cluster_doors.duplicate()
			for door in cluster_doors:
				door.linked_levers.append(lever)

			var post_chain: Dictionary = _chain_reachable_from_entrance()
			if _chain_preserved_after_cluster(pre_chain, post_chain, cluster_lever_positions + [candidate]):
				cluster_levers.append(lever)
				cluster_lever_positions.append(candidate)
				return true

			grid[candidate.x][candidate.y].object = null
			for door in cluster_doors:
				door.linked_levers.erase(lever)
			lever.linked_doors = []
			attempts += 1
		distance -= 1
	return false

func _build_lever_candidate_pool(spawn: LinkedObjectSpawn, cluster_doors: Array, cluster_lever_positions: Array, min_distance: int, obj_snapshot: Array, and_reachable: Dictionary) -> Array:
	var cells_by_type: Dictionary = _classify_floor_cells()
	var pool: Array = []
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
			if not _within_lever_to_cluster_door_range(pos, cluster_doors, spawn):
				continue
			if min_distance > 0 and _too_close_to_snapshot(pos, obj_snapshot, min_distance):
				continue
			if not and_reachable.is_empty() and not and_reachable.has(pos):
				continue
			if not _room_unique_for_cluster(pos, cluster_lever_positions):
				continue
			pool.append(pos)
	return pool

func _within_lever_to_cluster_door_range(lever_pos: Vector2i, cluster_doors: Array, spawn: LinkedObjectSpawn) -> bool:
	var min_d: int = max(0, spawn.lever_to_door_min_distance)
	var max_d: int = spawn.lever_to_door_max_distance
	if min_d == 0 and max_d < 0:
		return true
	var nearest_dist := 999999
	for door in cluster_doors:
		nearest_dist = min(nearest_dist, min(_manhattan(lever_pos, door.cell_a), _manhattan(lever_pos, door.cell_b)))
	if nearest_dist < min_d:
		return false
	if max_d >= 0 and nearest_dist > max_d:
		return false
	return true

func _room_index_at(pos: Vector2i) -> int:
	for i in range(_room_rects.size()):
		if (_room_rects[i] as Rect2i).has_point(pos):
			return i
	return -1

func _room_unique_for_cluster(pos: Vector2i, existing_positions: Array) -> bool:
	var my_room: int = _room_index_at(pos)
	if my_room < 0:
		return true
	for lpos in existing_positions:
		if _room_index_at(lpos) == my_room:
			return false
	return true

func _snapshot_occupied_cells() -> Array:
	var positions: Array = []
	for x in range(grid_width):
		for y in range(grid_height):
			if grid[x][y].object != null:
				positions.append(Vector2i(x, y))
	return positions

func _too_close_to_snapshot(pos: Vector2i, snapshot: Array, min_distance: int) -> bool:
	for p in snapshot:
		if _manhattan(pos, p) < min_distance:
			return true
	return false

func _pick_farthest_from(pool: Array, siblings: Array) -> int:
	var best_idx := 0
	var best_dist := -1
	for i in range(pool.size()):
		var min_dist := 999999
		for sib in siblings:
			var d: int = _manhattan(pool[i], sib)
			if d < min_dist:
				min_dist = d
		if min_dist > best_dist:
			best_dist = min_dist
			best_idx = i
	return best_idx

func _chain_preserved_after_cluster(before: Dictionary, after: Dictionary, lever_positions: Array) -> bool:
	var blocked: Dictionary = {}
	for lpos in lever_positions:
		blocked[lpos] = true
	for cell_pos in before:
		if blocked.has(cell_pos):
			continue
		if not after.has(cell_pos):
			return false
	for lpos in lever_positions:
		if not _has_reachable_neighbour(lpos, after):
			return false
	return true

func _rollback_cluster(cluster_doors: Array, cluster_lever_positions: Array, cluster_levers: Array) -> void:
	for pos in cluster_lever_positions:
		grid[pos.x][pos.y].object = null
	for lever in cluster_levers:
		lever.linked_doors = []
	for door in cluster_doors:
		door.linked_levers = []
		doors.erase(door)
		_doors_by_edge.erase(DoorInstance.edge_key(door.cell_a, door.cell_b))

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
func _chain_reachable_from_entrance(excluded_door_keys: Dictionary = {}, extra_closed_edges: Dictionary = {}) -> Dictionary:
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
		if door.data != null and door.data.interactable and not door.is_key_locked() and door.linked_levers.is_empty():
			open_door_keys[k0] = true
	# Phase 15 Task 6 — Phase C / chain reachability v3. Build the
	# teleporter-links dict once at the top so every BFS iteration of
	# the fixed-point loop sees the same warp graph. Each endpoint
	# maps to its partner; the BFS enqueues the partner whenever it
	# visits an endpoint, modelling teleporter pairs as bidirectional
	# permission-free edges. Empty when the level has no teleporters
	# (Phase A levels still set this), so this is a strict superset of
	# the legacy chain-reachability behaviour.
	var teleporter_links: Dictionary = _build_teleporter_links()
	var reachable: Dictionary = {}
	while true:
		reachable = _bfs_with_doors_state(entrance_pos, open_door_keys, extra_closed_edges, teleporter_links)
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
		# Collect reachable levers, then evaluate each lever-locked door
		# under its AND/OR logic.
		var reachable_levers: Dictionary = {}
		for x in range(grid_width):
			for y in range(grid_height):
				var cell: GridCell = grid[x][y]
				if not (cell.object is LeverInstance):
					continue
				var pos := Vector2i(x, y)
				if not _has_reachable_neighbour(pos, reachable):
					continue
				reachable_levers[cell.object] = true
		for door in doors:
			if door.linked_levers.is_empty():
				continue
			var key := DoorInstance.edge_key(door.cell_a, door.cell_b)
			if excluded_door_keys.has(key):
				continue
			if open_door_keys.has(key):
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

func _bfs_with_doors_state(origin: Vector2i, open_door_keys: Dictionary, extra_closed_edges: Dictionary = {}, teleporter_links: Dictionary = {}) -> Dictionary:
	# BFS treating each door in `doors` as closed UNLESS its edge_key
	# is in `open_door_keys`. `extra_closed_edges` lets callers seal
	# additional edges that aren't doors (used by the secret-wall
	# gating check to simulate "what if this corridor edge were a
	# real wall?"). `teleporter_links` (Phase 15 Task 6 — Phase C
	# / chain reachability v3) maps each teleporter endpoint cell to
	# its partner, so BFS enqueues the partner whenever it visits an
	# endpoint — teleporters participate as bidirectional graph edges.
	# Powers the chain-reachability loop.
	var closed_edges: Dictionary = extra_closed_edges.duplicate()
	for door in doors:
		var key := DoorInstance.edge_key(door.cell_a, door.cell_b)
		if not open_door_keys.has(key):
			closed_edges[key] = true
	return _bfs_walkable_with_closed_edges(origin, closed_edges, teleporter_links)

# Phase 15 Task 6 — Phase C / chain reachability v3. Flattens
# `self.teleporters` into the {endpoint → partner} dict the BFS
# consumes. Each pair contributes BOTH directions so the BFS doesn't
# need to know which endpoint it visited first. Cheap O(N) where N is
# the number of placed pairs (typically 1–3 per level); built once
# per `_chain_reachable_from_entrance` call rather than per BFS pass
# inside the fixed-point loop. Empty when no pairs are placed (Phase A
# levels with no teleporter_spawn OR Phase A levels where placement
# rolled count = 0).
func _build_teleporter_links() -> Dictionary:
	var result: Dictionary = {}
	for inst in teleporters:
		if inst == null:
			continue
		result[inst.cell_a] = inst.cell_b
		result[inst.cell_b] = inst.cell_a
	return result

func _has_reachable_neighbour(pos: Vector2i, reachable: Dictionary) -> bool:
	for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		if reachable.has(pos + d):
			return true
	return false


func _bfs_walkable_with_closed_edges(origin: Vector2i, closed_edges: Dictionary, teleporter_links: Dictionary = {}) -> Dictionary:
	# Same as _bfs_walkable_from but treats the given edges as walls.
	# Powers chain reachability for linked-pair validation.
	#
	# `teleporter_links` (Phase 15 Task 6 — Phase C / chain reachability
	# v3) maps each teleporter endpoint cell to its partner. Whenever
	# BFS visits an endpoint, it enqueues the partner — this models
	# teleporters as bidirectional graph edges in the reachability
	# simulation. Permission-free (no key required), so it slots
	# cleanly into BFS without needing a separate fixed-point pass —
	# every existing chain-reachability caller (linked-object placement,
	# key-door placement, secret-wall gating) gets island-aware
	# reachability transparently. Empty dict means "no teleporters" —
	# legacy callers and Phase A levels are unaffected.
	var visited: Dictionary = {origin: true}
	var queue: Array = [origin]
	# If the origin itself is a teleporter endpoint, seed its partner.
	# Edge case — would only fire if a future caller starts a BFS from
	# a teleporter cell (today the entrance is always the origin and
	# the placer excludes entrance from teleporter endpoints), but
	# documents the symmetric semantics.
	if teleporter_links.has(origin):
		var seed_partner: Vector2i = teleporter_links[origin]
		if not visited.has(seed_partner) and _in_bounds(seed_partner.x, seed_partner.y) and not grid[seed_partner.x][seed_partner.y].is_blocked:
			visited[seed_partner] = true
			queue.append(seed_partner)
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
			# Phase 15 Task 6 — Phase C / chain reachability v3.
			# Teleporter participation: if the cell we just enqueued
			# is an endpoint, also enqueue its partner. Bidirectional
			# by construction (each pair seeds both directions in the
			# links dict), so we never miss the reverse warp. Visited
			# check above prevents re-enqueueing once the partner is
			# already reached via corridors.
			if teleporter_links.has(npos):
				var partner: Vector2i = teleporter_links[npos]
				if not visited.has(partner) and _in_bounds(partner.x, partner.y) and not grid[partner.x][partner.y].is_blocked:
					visited[partner] = true
					queue.append(partner)
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


# -------------------------------------------------------
# Traps (Phase 8 Task 3 — Subtasks A + B)
#
# Traps live on `GridCell.trap` (separate slot from `cell.object`).
# Placed AFTER all object passes so trap cells are guaranteed to be
# free of chests / doors / levers, and BEFORE items so the item
# placement skips trap cells. Traps don't block movement, so they
# don't affect chain reachability — no BFS validation needed at this
# layer.
#
# Three placement modes per spawn (additive — combine freely):
#   1. Corridor clusters (Subtask B1) — runs first. For each corridor
#      segment, roll `corridor_segment_chance`; on hit, lay a contiguous
#      run of N trap cells inside that segment. Segments that already
#      hold traps from an earlier spawn's pass are skipped so two
#      spawns don't fight over the same corridor.
#   2. Room density (Subtask B2) — runs second. For each room, roll
#      `room_chance`; on hit, place N traps inside the room where N
#      is a percentage of the room's eligible cells, with optional
#      Manhattan spacing between them.
#   3. Scattered (Subtask A) — runs last. The legacy per-cell mode:
#      lay `count_min..count_max` individual traps with a distance
#      preference between them.
# -------------------------------------------------------
func _place_traps() -> void:
	if trap_spawns_pool.is_empty():
		return
	# Detect segments once per generation — the topology doesn't change
	# between spawns; only which cells are eligible for THIS spawn does.
	var segments: Array = _detect_corridor_segments()
	var cells_by_type := _classify_floor_cells()
	for spawn in trap_spawns_pool:
		if spawn == null or spawn.trap == null:
			continue
		# Corridor clusters first — they consume cells in bulk, which
		# the room + scattered passes implicitly avoid via `cell.trap`.
		if spawn.uses_corridor_clusters() and spawn.allows(ObjectSpawn.PLACEMENT_CORRIDOR):
			_place_corridor_traps(spawn, segments, cells_by_type)
		if spawn.uses_room_density() and spawn.allows(ObjectSpawn.PLACEMENT_ROOM):
			_place_room_traps(spawn, cells_by_type)
		var count := randi_range(max(0, spawn.count_min), max(spawn.count_min, spawn.count_max))
		for _i in range(count):
			_try_place_trap(spawn, cells_by_type)

# Returns Array[Array[Vector2i]] — each inner array is a maximal
# connected component of NON-JUNCTION corridor cells. A "junction" is
# a corridor cell with 3+ corridor neighbours (a T-intersection or
# crossroads), excluded so two corridors meeting at a T don't merge
# into one giant segment that reads as a single "trapped corridor"
# from the player's perspective.
#
# Tests rely on this method's output shape and stability — keep the
# return contract stable.
func _detect_corridor_segments() -> Array:
	var corridor_cells: Dictionary = {}  # Vector2i -> true
	var junctions: Dictionary = {}        # Vector2i -> true
	for x in range(grid_width):
		for y in range(grid_height):
			var pos := Vector2i(x, y)
			var cell: GridCell = grid[x][y]
			if cell.cell_type != GridCell.CellType.FLOOR:
				continue
			if classify_cell(pos) != ObjectSpawn.PLACEMENT_CORRIDOR:
				continue
			corridor_cells[pos] = true
			var corridor_neighbours := 0
			for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				var n: Vector2i = pos + d
				if not _in_bounds(n.x, n.y):
					continue
				var nc: GridCell = grid[n.x][n.y]
				if nc.cell_type != GridCell.CellType.FLOOR:
					continue
				if classify_cell(n) == ObjectSpawn.PLACEMENT_CORRIDOR:
					corridor_neighbours += 1
			if corridor_neighbours >= 3:
				junctions[pos] = true
	# BFS connected components on non-junction corridor cells.
	var segments: Array = []
	var visited: Dictionary = {}
	for pos_key in corridor_cells:
		var pos: Vector2i = pos_key
		if junctions.has(pos) or visited.has(pos):
			continue
		var segment: Array = []
		var queue: Array = [pos]
		visited[pos] = true
		while not queue.is_empty():
			var cur: Vector2i = queue.pop_front()
			segment.append(cur)
			for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				var n: Vector2i = cur + d
				if not corridor_cells.has(n) or junctions.has(n) or visited.has(n):
					continue
				visited[n] = true
				queue.append(n)
		if not segment.is_empty():
			segments.append(segment)
	return segments

func _place_corridor_traps(spawn: TrapSpawn, segments: Array, cells_by_type: Dictionary) -> void:
	# Precompute cell -> segment-index lookup so the junction-adjacency
	# check can verify the WHOLE neighbour segment for traps (not just
	# its boundary cell — clusters can land far from a segment's end,
	# leaving the cell-adjacent-to-junction untrapped while the segment
	# itself is still trapped).
	var cell_to_seg: Dictionary = {}
	for i in range(segments.size()):
		for pos in segments[i]:
			cell_to_seg[pos] = i
	for segment in segments:
		# Skip if this segment OR a junction-adjacent segment already
		# holds traps. Two rules in one check:
		#   - One spawn per segment (avoids layered hazards within a
		#     single corridor — "this corridor is poisoned with X").
		#   - One trapped segment per junction (a non-trappable
		#     junction cell between two clusters reads as ONE long
		#     run with a single safe tile, which forces more damage
		#     than the per-segment max would suggest).
		if _segment_blocked_by_existing_traps(segment, segments, cell_to_seg):
			continue
		if randf() >= spawn.corridor_segment_chance:
			continue
		# Eligible cells inside the segment: skip entrance/exit, cells
		# with an object, and cells already holding a trap (defensive —
		# segment-has-traps above should have caught these).
		var eligible: Array = _eligible_segment_cells(segment)
		var min_n: int = max(1, spawn.corridor_traps_per_run_min)
		if eligible.size() < min_n:
			# Segment too short — open-question 1 settled (skip rather
			# than under-deliver).
			continue
		var max_n: int = max(min_n, spawn.corridor_traps_per_run_max)
		# Clamp the target to what the segment can actually hold.
		max_n = min(max_n, eligible.size())
		var target_n: int = randi_range(min_n, max_n)
		var run: Array = _gather_run_in_segment(eligible, target_n)
		for pos in run:
			var inst := TrapInstance.create(spawn.trap, pos)
			grid[pos.x][pos.y].trap = inst
			traps.append(inst)
			_cluster_cells[pos] = true
			# Keep cells_by_type in sync with the scattered pass'
			# expectations — same pattern as `_try_place_trap`.
			cells_by_type[classify_cell(pos)].erase(pos)

func _segment_blocked_by_existing_traps(segment: Array, segments: Array, cell_to_seg: Dictionary) -> bool:
	# Direct check — any cell in this segment already holds a trap.
	for pos in segment:
		if grid[pos.x][pos.y].trap != null:
			return true
	# Junction-adjacency check — for each cell in this segment, look at
	# its 4 neighbours for junctions (corridor cells with 3+ corridor
	# neighbours, excluded from segments). If a junction's corridor
	# neighbour belongs to a DIFFERENT segment, scan that segment for
	# any trap — checking the boundary cell alone misses clusters that
	# landed at the segment's far end.
	var my_seg_indices: Dictionary = {}
	for pos in segment:
		if cell_to_seg.has(pos):
			my_seg_indices[cell_to_seg[pos]] = true
	var checked_segs: Dictionary = {}
	for pos in segment:
		for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var jpos: Vector2i = pos + d
			if not _in_bounds(jpos.x, jpos.y):
				continue
			if grid[jpos.x][jpos.y].cell_type != GridCell.CellType.FLOOR:
				continue
			if classify_cell(jpos) != ObjectSpawn.PLACEMENT_CORRIDOR:
				continue
			# Inline junction check — segments are small and this only
			# fires while picking placement targets.
			var corridor_n := 0
			for d2: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				var nn: Vector2i = jpos + d2
				if not _in_bounds(nn.x, nn.y):
					continue
				if grid[nn.x][nn.y].cell_type != GridCell.CellType.FLOOR:
					continue
				if classify_cell(nn) == ObjectSpawn.PLACEMENT_CORRIDOR:
					corridor_n += 1
			if corridor_n < 3:
				continue
			# `jpos` is a junction. For each of its corridor neighbours,
			# resolve the segment and check the WHOLE segment for traps.
			for d3: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				var npos: Vector2i = jpos + d3
				if not _in_bounds(npos.x, npos.y):
					continue
				if not cell_to_seg.has(npos):
					continue  # non-corridor, dead-end, or another junction — not in any segment
				var other_seg: int = cell_to_seg[npos]
				if my_seg_indices.has(other_seg) or checked_segs.has(other_seg):
					continue
				checked_segs[other_seg] = true
				for cell_pos in segments[other_seg]:
					if grid[cell_pos.x][cell_pos.y].trap != null:
						return true
	return false

func _eligible_segment_cells(segment: Array) -> Array:
	var result: Array = []
	for pos in segment:
		if pos == entrance_pos or pos == exit_pos:
			continue
		var cell: GridCell = grid[pos.x][pos.y]
		if cell.object != null:
			continue
		if cell.trap != null:
			continue
		if cell.teleporter != null:
			continue
		if not cell.items.is_empty():
			continue
		result.append(pos)
	return result

# Picks a random eligible start in the segment and walks outward
# (BFS-flood, restricted to the eligible set) collecting up to
# `target_n` cells. Yields a contiguous run even when eligibility
# carves the segment into sub-blocks (e.g. a chest in the middle
# splits one segment into two; the flood stays inside the sub-block
# the start sits in).
func _gather_run_in_segment(eligible: Array, target_n: int) -> Array:
	if eligible.is_empty() or target_n <= 0:
		return []
	var eligible_set: Dictionary = {}
	for pos in eligible:
		eligible_set[pos] = true
	var start: Vector2i = eligible[randi() % eligible.size()]
	var result: Array = []
	var visited: Dictionary = {start: true}
	var queue: Array = [start]
	while not queue.is_empty() and result.size() < target_n:
		var cur: Vector2i = queue.pop_front()
		result.append(cur)
		for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var n: Vector2i = cur + d
			if not eligible_set.has(n) or visited.has(n):
				continue
			visited[n] = true
			queue.append(n)
	return result

func _place_room_traps(spawn: TrapSpawn, cells_by_type: Dictionary) -> void:
	for room_obj in _room_rects:
		var room: Rect2i = room_obj as Rect2i
		if randf() >= spawn.room_chance:
			continue
		# Exclusivity — when this spawn opts out of sharing, skip any
		# room that already has traps from an earlier spawn's pass.
		# Designer choice: gives a room a single-spawn identity
		# ("this room is poison-spike trapped") instead of mixed
		# variety ("this room has both step AND timed hazards").
		if not spawn.allow_mixed_room_traps and _room_has_any_trap(room):
			continue
		var room_cells: Array = _eligible_room_cells(room)
		if room_cells.is_empty():
			continue
		var coverage_min: float = clamp(spawn.room_coverage_min_percent, 0.0, 100.0)
		var coverage_max: float = clamp(spawn.room_coverage_max_percent, coverage_min, 100.0)
		var coverage_pct: float = randf_range(coverage_min, coverage_max) / 100.0
		var target_count: int = max(1, int(ceil(room_cells.size() * coverage_pct)))
		# Random walk the eligible set, placing traps that satisfy the
		# spacing rule, until the target is hit or no candidate fits.
		# Graceful degrade: if spacing over-constrains coverage we
		# stop early rather than crashing or warning.
		room_cells.shuffle()
		var placed_count: int = 0
		for pos in room_cells:
			if placed_count >= target_count:
				break
			if _too_close_to_room_traps(pos, room, spawn.room_min_spacing):
				continue
			# Gameplay rule: every walkable cell (in or just outside
			# the room) must have a non-trap walkable cell within
			# `room_max_distance_to_safe_cell` Manhattan tiles. Caps
			# realised coverage when the rule is set, so dense room
			# rolls can't leave the player without a step-to-safety.
			if spawn.room_max_distance_to_safe_cell > 0 \
					and _placement_would_isolate_a_cell(pos, room, spawn.room_max_distance_to_safe_cell):
				continue
			var inst := TrapInstance.create(spawn.trap, pos)
			grid[pos.x][pos.y].trap = inst
			traps.append(inst)
			placed_count += 1
			# Keep cells_by_type in sync so the scattered pass won't
			# re-pick this cell.
			cells_by_type[classify_cell(pos)].erase(pos)

func _eligible_room_cells(room: Rect2i) -> Array:
	var result: Array = []
	for x in range(room.position.x, room.position.x + room.size.x):
		for y in range(room.position.y, room.position.y + room.size.y):
			if not _in_bounds(x, y):
				continue
			var cell: GridCell = grid[x][y]
			if cell.cell_type != GridCell.CellType.FLOOR:
				continue
			var pos := Vector2i(x, y)
			if pos == entrance_pos or pos == exit_pos:
				continue
			if cell.object != null:
				continue
			if cell.trap != null:
				continue
			if cell.teleporter != null:
				continue
			if not cell.items.is_empty():
				continue
			result.append(pos)
	return result

func _room_has_any_trap(room: Rect2i) -> bool:
	for inst in traps:
		if inst == null:
			continue
		if room.has_point(inst.cell):
			return true
	return false

func _too_close_to_room_traps(pos: Vector2i, room: Rect2i, min_spacing: int) -> bool:
	if min_spacing <= 0:
		return false
	for inst in traps:
		if inst == null:
			continue
		# Only enforce spacing against traps inside the same room —
		# corridor cluster cells outside the room rect are unrelated.
		if not room.has_point(inst.cell):
			continue
		var d: int = abs(pos.x - inst.cell.x) + abs(pos.y - inst.cell.y)
		if d < min_spacing:
			return true
	return false

# Returns true iff committing a trap at `candidate` would leave at
# least one walkable cell (inside the room OR within the buffer zone
# around it — the corridor-adjacent cell counts as valid retreat) more
# than `radius` Manhattan tiles from the nearest non-trap walkable
# cell. Used as a pre-placement guard for the room-density pass to
# enforce `TrapSpawn.room_max_distance_to_safe_cell`.
func _placement_would_isolate_a_cell(candidate: Vector2i, room: Rect2i, radius: int) -> bool:
	# Examine every walkable cell in the room AND a 1-cell margin around
	# it. A cell just outside the room can also lose its safe neighbour
	# if all its in-room neighbours are trapped, but checking a margin
	# of `radius` would be excessive — a 1-cell margin captures the
	# case where the corridor IS the retreat for an edge room cell.
	var x0: int = room.position.x - 1
	var y0: int = room.position.y - 1
	var x1: int = room.position.x + room.size.x
	var y1: int = room.position.y + room.size.y
	for cx in range(x0, x1 + 1):
		for cy in range(y0, y1 + 1):
			if not _in_bounds(cx, cy):
				continue
			var cpos := Vector2i(cx, cy)
			if not _is_walkable_room_cell(cpos):
				continue
			if not _has_safe_walkable_within(cpos, candidate, radius):
				return true
	return false

# True when `pos` is a floor cell with no blocking object — i.e. a
# cell the player could stand on. Trap presence is intentionally
# ignored here; the safety check below handles "trapped vs. safe".
func _is_walkable_room_cell(pos: Vector2i) -> bool:
	if not _in_bounds(pos.x, pos.y):
		return false
	var cell: GridCell = grid[pos.x][pos.y]
	if cell.cell_type != GridCell.CellType.FLOOR:
		return false
	if cell.object != null and cell.object.data != null and cell.object.data.blocks_movement:
		return false
	return true

# Returns true iff at least one cell within `radius` Manhattan tiles
# of `target` is a walkable, non-trap floor cell. `extra_trap` is the
# tentative trap cell currently being evaluated — treated as trapped
# during the scan even though it isn't yet committed to the grid.
func _has_safe_walkable_within(target: Vector2i, extra_trap: Vector2i, radius: int) -> bool:
	for dx in range(-radius, radius + 1):
		var max_dy: int = radius - abs(dx)
		for dy in range(-max_dy, max_dy + 1):
			var n := target + Vector2i(dx, dy)
			if not _in_bounds(n.x, n.y):
				continue
			if n == extra_trap:
				continue
			if not _is_walkable_room_cell(n):
				continue
			if grid[n.x][n.y].trap != null:
				continue
			return true
	return false

func _try_place_trap(spawn: TrapSpawn, cells_by_type: Dictionary) -> void:
	var base_candidates := _trap_candidates_for_spawn(spawn, cells_by_type)
	if base_candidates.is_empty():
		return
	# Graceful degrade on min_distance — same pattern items / objects /
	# decorations use. Better to ship a slightly clustered set of traps
	# than a silent zero when the constraint over-constrains.
	var distance: int = max(0, spawn.min_distance_to_other_trap)
	while distance >= 0:
		var candidates: Array = base_candidates
		if distance > 0:
			candidates = base_candidates.filter(
				func(p): return not _too_close_to_existing_trap(p, distance)
			)
		if not candidates.is_empty():
			var pos: Vector2i = candidates[randi() % candidates.size()]
			var inst := TrapInstance.create(spawn.trap, pos)
			grid[pos.x][pos.y].trap = inst
			traps.append(inst)
			# Remove from the cells-by-type pool so subsequent traps in
			# the same biome don't re-pick this cell. Removing from the
			# typed list keeps `_classify_floor_cells` re-roll-free.
			cells_by_type[classify_cell(pos)].erase(pos)
			return
		distance -= 1

func _trap_candidates_for_spawn(spawn: TrapSpawn, cells_by_type: Dictionary) -> Array:
	var result: Array = []
	for placement_bit in [ObjectSpawn.PLACEMENT_CORRIDOR, ObjectSpawn.PLACEMENT_ROOM, ObjectSpawn.PLACEMENT_DEAD_END]:
		if not spawn.allows(placement_bit):
			continue
		for pos in cells_by_type[placement_bit]:
			if pos == entrance_pos or pos == exit_pos:
				continue
			var cell: GridCell = grid[pos.x][pos.y]
			if cell.object != null:
				continue
			if cell.trap != null:
				continue
			if cell.teleporter != null:
				continue
			if not cell.items.is_empty():
				continue
			if _is_adjacent_to_cluster(pos):
				continue
			result.append(pos)
	return result

func _is_adjacent_to_cluster(pos: Vector2i) -> bool:
	if _cluster_cells.is_empty():
		return false
	for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		if _cluster_cells.has(pos + d):
			return true
	return false

func _too_close_to_existing_trap(pos: Vector2i, min_distance: int) -> bool:
	if min_distance <= 0:
		return false
	for inst in traps:
		if inst == null:
			continue
		var d: int = abs(pos.x - inst.cell.x) + abs(pos.y - inst.cell.y)
		if d < min_distance:
			return true
	return false

# -------------------------------------------------------
# Trap removal + post-placement validators (Subtask B3)
# -------------------------------------------------------

func _remove_trap_at(pos: Vector2i) -> void:
	var cell: GridCell = grid[pos.x][pos.y]
	if cell.trap == null:
		return
	var inst: TrapInstance = cell.trap
	cell.trap = null
	traps.erase(inst)
	_cluster_cells.erase(pos)

func _validate_chest_lever_timed_adjacency() -> void:
	for x in range(grid_width):
		for y in range(grid_height):
			var cell: GridCell = grid[x][y]
			if cell.object == null:
				continue
			var cat: int = cell.object.data.category if cell.object.data != null else -1
			if cat != ObjectData.Category.CHEST and cat != ObjectData.Category.LEVER:
				continue
			var pos := Vector2i(x, y)
			var has_safe := false
			for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				var n: Vector2i = pos + d
				if not _in_bounds(n.x, n.y):
					continue
				var nc: GridCell = grid[n.x][n.y]
				if nc.is_blocked:
					continue
				if nc.trap == null or not nc.trap.data.is_timed():
					has_safe = true
					break
			if has_safe:
				continue
			# No safe adjacent cell — remove a timed trap from a neighbour.
			for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				var n: Vector2i = pos + d
				if not _in_bounds(n.x, n.y):
					continue
				var nc: GridCell = grid[n.x][n.y]
				if nc.is_blocked:
					continue
				if nc.trap != null and nc.trap.data.is_timed():
					_remove_trap_at(n)
					break

func _validate_step_trap_reachability() -> void:
	# Dijkstra from entrance to ALL reachable cells. Step-trap cells
	# cost 100, regular walkable cells cost 1. Blocking objects and
	# walls are impassable. Doors are passable (openable by the player).
	# After Dijkstra, trace cheapest paths to exit + every chest (via
	# an adjacent cell) + every lever + every floor-item cell and remove
	# every step trap along those paths in one batch.
	var STEP_COST := 100
	var dist: Dictionary = {entrance_pos: 0}
	var prev: Dictionary = {}
	var open: Array = [[0, entrance_pos]]

	while not open.is_empty():
		var entry: Array = open.pop_front()
		var cost: int = entry[0]
		var current: Vector2i = entry[1]
		if cost > dist.get(current, 999999):
			continue
		for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var nx: int = current.x + d.x
			var ny: int = current.y + d.y
			if not _in_bounds(nx, ny):
				continue
			var npos := Vector2i(nx, ny)
			var ncell: GridCell = grid[nx][ny]
			if ncell.cell_type == GridCell.CellType.WALL:
				continue
			if ncell.object != null and ncell.object.data != null and ncell.object.data.blocks_movement:
				continue
			var edge_cost := 1
			if ncell.trap != null and ncell.trap.data != null and ncell.trap.data.is_step():
				edge_cost = STEP_COST
			var new_dist: int = cost + edge_cost
			if new_dist < dist.get(npos, 999999):
				dist[npos] = new_dist
				prev[npos] = current
				var lo := 0
				var hi := open.size()
				while lo < hi:
					var mid := (lo + hi) / 2
					if open[mid][0] < new_dist:
						lo = mid + 1
					else:
						hi = mid
				open.insert(lo, [new_dist, npos])

	# Collect all required targets: exit, chests (via adjacent cell),
	# levers, floor-item cells.
	var targets: Array = []
	if prev.has(exit_pos):
		targets.append(exit_pos)
	else:
		push_warning("LevelGenerator: no walkable path from entrance to exit — cannot clear step traps")
	for x in range(grid_width):
		for y in range(grid_height):
			var cell: GridCell = grid[x][y]
			var pos := Vector2i(x, y)
			if cell.object != null and cell.object.data != null:
				var cat: int = cell.object.data.category
				if cat == ObjectData.Category.CHEST or cat == ObjectData.Category.LEVER:
					# Blocking — find cheapest reachable 4-adjacent cell.
					var best_n := Vector2i(-1, -1)
					var best_cost := 999999
					for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
						var n: Vector2i = pos + d
						if dist.has(n) and dist[n] < best_cost:
							best_cost = dist[n]
							best_n = n
					if best_n != Vector2i(-1, -1):
						targets.append(best_n)
			if not cell.items.is_empty():
				if prev.has(pos) or pos == entrance_pos:
					targets.append(pos)

	# Trace back from each target and collect step-trap cells.
	var traps_to_remove: Dictionary = {}
	for target in targets:
		var cursor: Vector2i = target
		while cursor != entrance_pos:
			if not prev.has(cursor):
				break
			var c: GridCell = grid[cursor.x][cursor.y]
			if c.trap != null and c.trap.data != null and c.trap.data.is_step():
				traps_to_remove[cursor] = true
			cursor = prev[cursor]

	for pos in traps_to_remove:
		_remove_trap_at(pos)

func _validate_timed_trap_safe_distance() -> void:
	# Enforce room_max_distance_to_safe_cell globally (not just within
	# rooms during placement). After all trap passes, corridor clusters
	# meeting room edges can create long timed-trap runs that exceed the
	# per-room guarantee. This pass removes timed traps until every
	# walkable cell has a non-timed-trap walkable cell within K tiles.
	var k := 0
	for spawn in trap_spawns_pool:
		if spawn != null and spawn.room_max_distance_to_safe_cell > k:
			k = spawn.room_max_distance_to_safe_cell
	if k <= 0:
		return
	var changed := true
	while changed:
		changed = false
		for x in range(grid_width):
			for y in range(grid_height):
				var pos := Vector2i(x, y)
				if not _is_walkable_cell(pos):
					continue
				if _has_safe_timed_cell_within(pos, k):
					continue
				# This cell is too far from any non-timed-trap walkable
				# cell. If it has a timed trap, remove it.
				var cell: GridCell = grid[x][y]
				if cell.trap != null and cell.trap.data != null and cell.trap.data.is_timed():
					_remove_trap_at(pos)
					changed = true

func _is_walkable_cell(pos: Vector2i) -> bool:
	if not _in_bounds(pos.x, pos.y):
		return false
	var cell: GridCell = grid[pos.x][pos.y]
	if cell.cell_type == GridCell.CellType.WALL:
		return false
	if cell.object != null and cell.object.data != null and cell.object.data.blocks_movement:
		return false
	return true

func _has_safe_timed_cell_within(target: Vector2i, radius: int) -> bool:
	for dx in range(-radius, radius + 1):
		var max_dy: int = radius - abs(dx)
		for dy in range(-max_dy, max_dy + 1):
			var n := target + Vector2i(dx, dy)
			if not _in_bounds(n.x, n.y):
				continue
			if not _is_walkable_cell(n):
				continue
			var nc: GridCell = grid[n.x][n.y]
			if nc.trap == null or not nc.trap.data.is_timed():
				return true
	return false

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

# -------------------------------------------------------
# Wall decorations (paintings, torches, lanterns)
# -------------------------------------------------------
# -------------------------------------------------------
# Projectile traps (Phase 8 Task 3 — Subtask C)
# -------------------------------------------------------

func _place_projectile_traps() -> void:
	# Subtask C1: corridor placement; Subtask C5: room placement. Both
	# passes are additive — a spawn can opt into either or both. We
	# deliberately don't claim wall-face exclusivity for the spike trap
	# pass — spike traps live on cells, not faces, so there's no conflict.
	if projectile_trap_spawns_pool.is_empty():
		return
	var segments: Array = _detect_corridor_segments()
	# Junction lookup — corridor cells with 3+ corridor neighbours,
	# excluded from segments by `_detect_corridor_segments`. The fire
	# direction must reach a junction within `max_escape_distance`
	# tiles, so we precompute the junction set once per generation.
	# Used by the corridor pass only — rooms have no junction concept.
	var junctions: Dictionary = _detect_corridor_junctions()
	for spawn in projectile_trap_spawns_pool:
		if spawn == null or spawn.trap == null:
			continue
		if spawn.uses_corridor() and spawn.allows(ObjectSpawn.PLACEMENT_CORRIDOR):
			_place_corridor_projectile_traps(spawn, segments, junctions)
		if spawn.uses_room() and spawn.allows(ObjectSpawn.PLACEMENT_ROOM):
			_place_room_projectile_traps(spawn)

# Returns Dictionary[Vector2i -> true] of every corridor cell with 3+
# corridor neighbours. Mirrors the junction logic in
# `_detect_corridor_segments` but exposed as a standalone set so the
# projectile-trap placer can ask "is this cell a junction" in O(1).
func _detect_corridor_junctions() -> Dictionary:
	var junctions: Dictionary = {}
	for x in range(grid_width):
		for y in range(grid_height):
			var pos := Vector2i(x, y)
			var cell: GridCell = grid[x][y]
			if cell.cell_type != GridCell.CellType.FLOOR:
				continue
			if classify_cell(pos) != ObjectSpawn.PLACEMENT_CORRIDOR:
				continue
			var corridor_n := 0
			for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				var n: Vector2i = pos + d
				if not _in_bounds(n.x, n.y):
					continue
				if grid[n.x][n.y].cell_type != GridCell.CellType.FLOOR:
					continue
				if classify_cell(n) == ObjectSpawn.PLACEMENT_CORRIDOR:
					corridor_n += 1
			if corridor_n >= 3:
				junctions[pos] = true
	return junctions

func _place_corridor_projectile_traps(spawn: ProjectileTrapSpawn, segments: Array, junctions: Dictionary) -> void:
	var max_escape: int = max(1, spawn.trap.max_escape_distance)
	for segment in segments:
		if randf() >= spawn.corridor_chance:
			continue
		# Cross-spawn cap: a corridor segment must hold AT MOST ONE
		# launcher across all `ProjectileTrapSpawn` entries combined.
		# (The path-overlap rule below also catches same-segment
		# placements, but this short-circuit avoids re-tracing every
		# wall face inside an already-trapped segment for nothing.)
		if _segment_has_projectile_trap(segment):
			continue
		# Build the candidate (cell, wall_dir, path) pool for this
		# segment. `_projectile_launch_path` returns the full path on
		# success and an empty array on rejection — see its comment
		# for the candidate validity rules. We carry the path through
		# so we don't have to re-trace it when registering the win.
		var candidates: Array = []
		for pos in segment:
			if pos == entrance_pos or pos == exit_pos:
				continue
			# Skip cells with a blocking object — a chest at the
			# launcher's host cell would mean the player walks UP to
			# the chest standing right where the launcher mounts. The
			# wall face is fine geometrically but the visual gets weird.
			var host_cell: GridCell = grid[pos.x][pos.y]
			if host_cell.object != null:
				continue
			# Same idea for spike traps — spike-hole decals directly
			# under a launcher read as layered hazards and visually
			# compete. The plate-cell check (in
			# `_pick_plate_cell_for_corridor`) excludes spike-trap
			# cells too, so PRESSURE_PLATE traps don't end up with
			# their plate sharing a tile with a spike trap.
			if host_cell.trap != null:
				continue
			for wall_dir: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				var path: Array = _projectile_launch_path(pos, wall_dir, junctions, max_escape)
				if path.is_empty():
					continue
				# PRESSURE_PLATE-only fairness rule: the projectile path
				# must contain a junction at a NON-ENDPOINT position
				# (i.e., with at least one path cell before AND after
				# the junction). Without this, geometries like a 2-cell
				# path where the only junction is the terminal cell put
				# the plate immediately adjacent to the junction with
				# no buffer cell — the player stepping onto the plate
				# is in the firing line and has no fair way to traverse
				# past it (e.g., to reach a side branch off the host
				# cell). TIMED traps don't have this issue because the
				# player can time their entry through the cooldown.
				if spawn.trap.is_pressure_plate() and not _path_has_middle_junction(path, junctions):
					continue
				candidates.append([pos, wall_dir, path])
		if candidates.is_empty():
			continue
		var max_n: int = max(1, spawn.corridor_max_per_segment)
		var placed_in_segment: int = 0
		# Shuffle so repeated runs across the same segment don't always
		# pick the same cell first.
		candidates.shuffle()
		for c in candidates:
			if placed_in_segment >= max_n:
				break
			var pos: Vector2i = c[0]
			var wall_dir: Vector2i = c[1]
			var path: Array = c[2]
			# Re-check the face registry AND path overlap — an earlier
			# candidate in this same loop iteration may have claimed
			# the face or laid down a path that this candidate's path
			# now intersects. The path was traced before any of those
			# claims, so we revalidate before committing.
			var face_key: String = ProjectileTrapInstance.face_key(pos, wall_dir)
			if _wall_faces_used.has(face_key):
				continue
			if _path_overlaps_existing(path):
				continue
			# Spreading rule — no graceful degrade per the spec; just
			# skip the candidate if too close to an existing launcher.
			if _too_close_to_existing_projectile_trap(pos, spawn.trap.min_distance_to_other_projectile_trap):
				continue
			# PRESSURE_PLATE traps need a plate cell that satisfies the
			# distance bounds; reject the launcher if no plate fits
			# (otherwise the trap would be a dead inert wall mount).
			# TIMED traps don't need a plate — `plate_cell` stays at
			# the NO_PLATE sentinel for them.
			var plate_cell: Vector2i = ProjectileTrapInstance.NO_PLATE
			if spawn.trap.is_pressure_plate():
				plate_cell = _pick_plate_cell_for_corridor(path, pos, junctions, spawn.trap)
				if plate_cell == ProjectileTrapInstance.NO_PLATE:
					continue
			var inst := ProjectileTrapInstance.create(spawn.trap, pos, wall_dir)
			# Per-instance phase shift on top of the data's base offset
			# so multiple TIMED launchers placed in the same area don't
			# fire in lockstep. Rolled here (rather than in `create()`)
			# so unit tests constructing instances directly stay
			# deterministic — only the placer, which already runs under
			# a seeded RNG, picks a random phase.
			if spawn.trap.is_timed():
				var break_duration: float = max(0.001, spawn.trap.timed_break_duration)
				inst.timed_offset = fposmod(spawn.trap.timed_initial_offset + randf() * break_duration, break_duration)
				inst.timer = inst.timed_offset
			inst.plate_cell = plate_cell
			projectile_traps.append(inst)
			_wall_faces_used[face_key] = true
			for p in path:
				_projectile_path_cells[p] = true
			placed_in_segment += 1

# Room placement (Subtask C5). Mirrors the corridor pass with three
# differences: (1) the candidate validator
# (`_projectile_launch_path_in_room`) requires the FULL projectile
# path to stay inside the room rect — escaping through a doorway into
# a corridor makes the projectile unavoidable outside the controlled
# space; (2) there's no junction-reachability rule (rooms have no
# junctions in the corridor sense; the player can sidestep inside the
# room or step out through any doorway to escape the firing line); (3)
# the PRESSURE_PLATE plate picker (`_pick_plate_cell_for_room`) drops
# the junction-distance bound and keeps only the min-distance-to-
# launcher bound.
func _place_room_projectile_traps(spawn: ProjectileTrapSpawn) -> void:
	for room_obj in _room_rects:
		var room: Rect2i = room_obj as Rect2i
		if randf() >= spawn.room_chance:
			continue
		# Build the candidate (cell, wall_dir, path) pool for this room.
		# Same shape as the corridor pass — `_projectile_launch_path_in_room`
		# returns the full path on success and an empty array on rejection.
		var candidates: Array = []
		for x in range(room.position.x, room.position.x + room.size.x):
			for y in range(room.position.y, room.position.y + room.size.y):
				if not _in_bounds(x, y):
					continue
				var pos := Vector2i(x, y)
				if pos == entrance_pos or pos == exit_pos:
					continue
				var host_cell: GridCell = grid[pos.x][pos.y]
				if host_cell.cell_type != GridCell.CellType.FLOOR:
					continue
				# Same host-cell exclusions as corridor placement — a
				# blocking object or a spike trap on the launcher's host
				# cell reads as layered hazard/decor and looks weird.
				if host_cell.object != null:
					continue
				if host_cell.trap != null:
					continue
				for wall_dir: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
					var path: Array = _projectile_launch_path_in_room(pos, wall_dir, room)
					if path.is_empty():
						continue
					candidates.append([pos, wall_dir, path])
		if candidates.is_empty():
			continue
		var max_n: int = max(1, spawn.room_max_per_room)
		var placed_in_room: int = 0
		candidates.shuffle()
		for c in candidates:
			if placed_in_room >= max_n:
				break
			var pos: Vector2i = c[0]
			var wall_dir: Vector2i = c[1]
			var path: Array = c[2]
			# Revalidate against state that may have changed since the
			# candidate list was built (an earlier winner in this loop,
			# or the corridor pass running before us, may have claimed
			# the face or laid down an overlapping path).
			var face_key: String = ProjectileTrapInstance.face_key(pos, wall_dir)
			if _wall_faces_used.has(face_key):
				continue
			if _path_overlaps_existing(path):
				continue
			# Spreading rule applies globally — no graceful degrade,
			# matching the corridor pass.
			if _too_close_to_existing_projectile_trap(pos, spawn.trap.min_distance_to_other_projectile_trap):
				continue
			var plate_cell: Vector2i = ProjectileTrapInstance.NO_PLATE
			if spawn.trap.is_pressure_plate():
				plate_cell = _pick_plate_cell_for_room(path, pos, spawn.trap)
				if plate_cell == ProjectileTrapInstance.NO_PLATE:
					continue
			var inst := ProjectileTrapInstance.create(spawn.trap, pos, wall_dir)
			if spawn.trap.is_timed():
				var break_duration: float = max(0.001, spawn.trap.timed_break_duration)
				inst.timed_offset = fposmod(spawn.trap.timed_initial_offset + randf() * break_duration, break_duration)
				inst.timer = inst.timed_offset
			inst.plate_cell = plate_cell
			projectile_traps.append(inst)
			_wall_faces_used[face_key] = true
			for p in path:
				_projectile_path_cells[p] = true
			placed_in_room += 1

# Returns the projectile's full flight path as Array[Vector2i] when
# the (cell, wall_dir) candidate is launchable INSIDE THE ROOM; empty
# array otherwise. Used in Subtask C5.
#
# A wall face is launchable in a room iff:
#   - the wall_dir neighbour is a WALL (mount point — typically the
#     room's outer boundary wall)
#   - tracing forward in fire_direction = -wall_dir, every cell on the
#     full path until the projectile hits a wall is a FLOOR cell INSIDE
#     the same room rect. Escaping through a doorway into a corridor
#     or an adjacent room would make the projectile unavoidable outside
#     the controlled space.
#   - no cell on the path holds a CHEST or LEVER (same fairness rule
#     as the corridor pass — projectiles crossing reward / interactive
#     points feel unfair)
#   - no cell on the path is the EXIT (rare in rooms but possible if
#     the level designer dropped an exit in one)
#   - no cell on the path is on another launcher's path
#   - the face isn't already claimed
#
# No junction requirement (rooms have no junctions in the corridor
# sense — the player escapes by sidestepping inside the room or
# stepping out through a doorway).
func _projectile_launch_path_in_room(cell: Vector2i, wall_dir: Vector2i, room: Rect2i) -> Array:
	var empty: Array = []
	if not room.has_point(cell):
		return empty
	var wx: int = cell.x + wall_dir.x
	var wy: int = cell.y + wall_dir.y
	if not _in_bounds(wx, wy):
		return empty
	if grid[wx][wy].cell_type != GridCell.CellType.WALL:
		return empty
	if _wall_faces_used.has(ProjectileTrapInstance.face_key(cell, wall_dir)):
		return empty
	var fire_dir: Vector2i = -wall_dir
	var path: Array = []
	var step_limit: int = grid_width + grid_height + 2
	var step: int = 1
	while step <= step_limit:
		var nx: int = cell.x + fire_dir.x * step
		var ny: int = cell.y + fire_dir.y * step
		if not _in_bounds(nx, ny):
			return empty
		var nc: GridCell = grid[nx][ny]
		if nc.cell_type == GridCell.CellType.WALL:
			break
		if nc.cell_type == GridCell.CellType.EXIT:
			return empty
		if nc.cell_type != GridCell.CellType.FLOOR:
			return empty
		var npos := Vector2i(nx, ny)
		# Path must stay inside the SAME room. A projectile leaking out
		# through a doorway into a corridor (or an adjacent room) becomes
		# unavoidable outside the controlled space.
		if not room.has_point(npos):
			return empty
		if nc.object != null and nc.object.data != null:
			var cat: int = nc.object.data.category
			if cat == ObjectData.Category.CHEST or cat == ObjectData.Category.LEVER:
				return empty
		if _projectile_path_cells.has(npos):
			return empty
		path.append(npos)
		step += 1
	return path

# Pick a plate cell for a PRESSURE_PLATE room launcher, or return
# `ProjectileTrapInstance.NO_PLATE` if no valid candidate exists.
# Relaxed version of `_pick_plate_cell_for_corridor`: the plate must
# be on the projectile path AND ≥ `min_plate_to_launcher_distance`
# from the launcher; the junction-distance constraint is dropped
# because rooms have no junctions and the player's escape is
# sidestepping inside the room or stepping out through a doorway.
func _pick_plate_cell_for_room(path: Array, launcher_cell: Vector2i, data: ProjectileTrapData) -> Vector2i:
	if path.is_empty():
		return ProjectileTrapInstance.NO_PLATE
	var min_to_launcher: int = max(1, data.min_plate_to_launcher_distance)
	var candidates: Array = []
	for plate_pos in path:
		# Same spike-trap exclusion as the corridor variant — stepping
		# on the plate must not trigger a co-located spike at the same
		# time, and the decals must not z-fight.
		if grid[plate_pos.x][plate_pos.y].trap != null:
			continue
		# Phase 15 Task 6 — Phase C. Skip plate placements that land on
		# a teleporter endpoint. A warp glyph and a pressure-plate decal
		# would z-fight visually, and stepping onto the plate to trigger
		# the launcher mid-warp would be unreadable.
		if grid[plate_pos.x][plate_pos.y].teleporter != null:
			continue
		if _manhattan(plate_pos, launcher_cell) < min_to_launcher:
			continue
		candidates.append(plate_pos)
	if candidates.is_empty():
		return ProjectileTrapInstance.NO_PLATE
	return candidates[randi() % candidates.size()]

# Pick a plate cell for a PRESSURE_PLATE corridor launcher, or return
# `ProjectileTrapInstance.NO_PLATE` if no valid candidate exists. The
# plate must be:
#   - on the projectile path (so a player triggering it is already
#     in the firing line — they have to dodge AFTER stepping on it)
#   - ≥ `min_plate_to_launcher_distance` cells from the launcher
#     (Manhattan; on a straight corridor segment this is the step
#     count along fire direction). Without this minimum the
#     projectile would hit the player instantly with no time to
#     react.
#   - ≤ `max_plate_to_junction_distance` Manhattan cells from the
#     nearest path junction (the player's escape route after
#     triggering). Without this maximum the player would have no
#     reachable escape after the projectile fires.
# Picks uniformly at random among valid candidates. Empty path and
# no-junction-on-path are both treated as "no plate" — the path
# validator already guarantees a junction exists, but defensive.
func _pick_plate_cell_for_corridor(path: Array, launcher_cell: Vector2i, junctions: Dictionary, data: ProjectileTrapData) -> Vector2i:
	if path.is_empty():
		return ProjectileTrapInstance.NO_PLATE
	var path_junctions: Array = []
	for p in path:
		if junctions.has(p):
			path_junctions.append(p)
	if path_junctions.is_empty():
		return ProjectileTrapInstance.NO_PLATE
	var min_to_launcher: int = max(1, data.min_plate_to_launcher_distance)
	var max_to_junction: int = max(1, data.max_plate_to_junction_distance)
	var candidates: Array = []
	for plate_pos in path:
		# A plate must never share its cell with a spike trap. Without
		# this check, stepping onto the plate would trigger BOTH
		# hazards on the same frame (spike damage + fireball spawn),
		# and the plate / spike-hole decals would z-fight visually.
		# Spike traps are placed before projectile traps in `generate()`,
		# so the check is simply "is `cell.trap` non-null at this
		# moment".
		if grid[plate_pos.x][plate_pos.y].trap != null:
			continue
		# Phase 15 Task 6 — Phase C. Same z-fight + "stepping on this
		# triggers something the player can't make sense of" reasoning
		# as spike-trap exclusion: a plate decal under a teleporter
		# rune circle would be visually unreadable, and the player
		# warps mid-step before the launcher could meaningfully react.
		if grid[plate_pos.x][plate_pos.y].teleporter != null:
			continue
		# Step distance from launcher along the fire direction equals
		# Manhattan distance for cardinal flight.
		if _manhattan(plate_pos, launcher_cell) < min_to_launcher:
			continue
		var nearest_junction_dist: int = -1
		for j in path_junctions:
			var d: int = _manhattan(plate_pos, j)
			if nearest_junction_dist == -1 or d < nearest_junction_dist:
				nearest_junction_dist = d
		if nearest_junction_dist == -1 or nearest_junction_dist > max_to_junction:
			continue
		candidates.append(plate_pos)
	if candidates.is_empty():
		return ProjectileTrapInstance.NO_PLATE
	return candidates[randi() % candidates.size()]

func _path_overlaps_existing(path: Array) -> bool:
	for p in path:
		if _projectile_path_cells.has(p):
			return true
	return false

# True iff at least one path cell at a non-endpoint position
# (`index in [1, path.size() - 2]`) is a junction. "Non-endpoint"
# means the junction has at least one path cell before it AND at
# least one path cell after it — a "middle" junction. Used by the
# corridor placer to gate PRESSURE_PLATE launchers: without a
# middle junction the plate ends up adjacent to a terminal-cell
# junction with no buffer for fair traversal past the plate.
# TIMED launchers don't call into this — their fairness comes
# from the player timing their entry through the cooldown.
func _path_has_middle_junction(path: Array, junctions: Dictionary) -> bool:
	if path.size() < 3:
		return false
	for i in range(1, path.size() - 1):
		if junctions.has(path[i]):
			return true
	return false

# Returns the projectile's full flight path as Array[Vector2i] when
# the (cell, wall_dir) candidate is launchable; empty array otherwise.
#
# A wall face is launchable iff:
#   - the wall_dir neighbour is a WALL (mount point)
#   - tracing forward in fire_direction = -wall_dir, the FULL path
#     until the projectile hits a wall stays entirely on corridor
#     floor cells (no rooms, no entrance, no exit) and crosses no
#     CHEST or LEVER object — projectiles crossing those cells would
#     force the player to take damage on their way to a reward /
#     interactive point. Junctions count as corridor.
#   - somewhere on that path within `max_escape_distance` tiles there
#     is a junction (corridor cell with 3+ corridor neighbours) — the
#     player's escape route from the firing line
#   - no cell on the path is already on another launcher's path (no
#     crossfire — the player escaping launcher A by reaching a
#     junction must not walk into launcher B's line of fire there)
#   - the face isn't already claimed
#
# The path is traced past the escape junction all the way to the
# terminating wall: the projectile in C2 will fly the entire way, and
# a chest / lever / exit anywhere along the flight is a problem
# regardless of how far past the junction it sits.
#
# Returning the path (instead of a bool) lets the caller register the
# winning path cells in `_projectile_path_cells` without recomputing.
func _projectile_launch_path(cell: Vector2i, wall_dir: Vector2i, junctions: Dictionary, max_escape: int) -> Array:
	var empty: Array = []
	var wx: int = cell.x + wall_dir.x
	var wy: int = cell.y + wall_dir.y
	if not _in_bounds(wx, wy):
		return empty
	if grid[wx][wy].cell_type != GridCell.CellType.WALL:
		return empty
	if _wall_faces_used.has(ProjectileTrapInstance.face_key(cell, wall_dir)):
		return empty
	var fire_dir: Vector2i = -wall_dir
	var path: Array = []
	var found_junction_within_escape: bool = false
	# Hard cap on iterations as a safety net — every projectile must
	# eventually hit a wall (the grid border is wall), so this loop
	# terminates naturally; the cap just protects against ever
	# producing an infinite trace from a malformed grid.
	var step_limit: int = grid_width + grid_height + 2
	var step: int = 1
	while step <= step_limit:
		var nx: int = cell.x + fire_dir.x * step
		var ny: int = cell.y + fire_dir.y * step
		if not _in_bounds(nx, ny):
			return empty
		var nc: GridCell = grid[nx][ny]
		# Wall terminates projectile flight — natural end of path.
		if nc.cell_type == GridCell.CellType.WALL:
			break
		# Exit on path — projectiles fly onto the exit cell, forcing
		# damage on the player as they leave the level.
		if nc.cell_type == GridCell.CellType.EXIT:
			return empty
		# Any other non-FLOOR cell type (e.g. ENTRANCE) — bail.
		if nc.cell_type != GridCell.CellType.FLOOR:
			return empty
		var npos := Vector2i(nx, ny)
		# Path must stay in corridors. A projectile flying out of the
		# corridor into a room could become unavoidable since rooms
		# are open spaces. Junctions still classify as PLACEMENT_CORRIDOR.
		# Subtask C5 handles room placement (where the projectile is
		# constrained to stay inside the room instead).
		if classify_cell(npos) != ObjectSpawn.PLACEMENT_CORRIDOR:
			return empty
		# Reject if the path crosses an interactive object — chests
		# and levers are reward / interactive points the player has
		# to walk to deliberately, and being shot on the way feels
		# unfair. Doors live on EDGES (not on `cell.object`), so they
		# don't trip this check; a projectile passing through a door
		# cell is fine geometrically.
		if nc.object != null and nc.object.data != null:
			var cat: int = nc.object.data.category
			if cat == ObjectData.Category.CHEST or cat == ObjectData.Category.LEVER:
				return empty
		# No crossfire — reject if any cell on this path is already
		# on another launcher's projectile path. Catches the case
		# two perpendicular corridors both target the same T-junction
		# (the escape route from launcher A becomes the firing line
		# of launcher B), and any other path overlap.
		if _projectile_path_cells.has(npos):
			return empty
		# Track junction-within-escape-budget. Continue past it — the
		# projectile keeps flying, and chests / levers past the junction
		# matter too.
		if junctions.has(npos) and step <= max_escape:
			found_junction_within_escape = true
		path.append(npos)
		step += 1
	if not found_junction_within_escape:
		return empty
	return path

# True iff any cell in `segment` already hosts a placed projectile-trap
# launcher. Used to enforce the cross-spawn one-launcher-per-segment
# rule — without it, two spawns each contributing a launcher to the
# same corridor produce crossfire at opposite ends.
func _segment_has_projectile_trap(segment: Array) -> bool:
	if projectile_traps.is_empty():
		return false
	var seg_set: Dictionary = {}
	for pos in segment:
		seg_set[pos] = true
	for inst in projectile_traps:
		if seg_set.has(inst.cell):
			return true
	return false

func _too_close_to_existing_projectile_trap(pos: Vector2i, min_distance: int) -> bool:
	if min_distance <= 0:
		return false
	for inst in projectile_traps:
		if _manhattan(pos, inst.cell) < min_distance:
			return true
	return false

func _place_wall_decorations() -> void:
	if wall_decorations_pool.is_empty():
		return
	var cells_by_type := _classify_floor_cells()
	for spawn in wall_decorations_pool:
		if spawn == null or spawn.decoration == null:
			continue
		var count := randi_range(max(0, spawn.count_min), max(spawn.count_min, spawn.count_max))
		for _i in range(count):
			_try_place_one_wall_decoration(spawn, cells_by_type)

func _try_place_one_wall_decoration(spawn: WallDecorationSpawn, cells_by_type: Dictionary) -> void:
	# Build a (cell, wall_dir) candidate pool from cells matching
	# `placement` flags. A wall_dir is valid only if the neighbour in
	# that direction is a WALL cell (otherwise there's no wall face to
	# attach to). Doors live on FLOOR↔FLOOR edges so they can never
	# coincide with the FLOOR↔WALL edges decorations occupy.
	var base_candidates: Array = []
	for placement_bit in [ObjectSpawn.PLACEMENT_CORRIDOR, ObjectSpawn.PLACEMENT_ROOM, ObjectSpawn.PLACEMENT_DEAD_END]:
		if not spawn.allows(placement_bit):
			continue
		for pos in cells_by_type[placement_bit]:
			for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				if not _is_decoratable_wall(pos, d):
					continue
				base_candidates.append([pos, d])
	if base_candidates.is_empty():
		return
	# Graceful degrade on min_distance: same approach the items pool uses.
	var distance: int = max(0, spawn.min_distance_to_other_decoration)
	while distance >= 0:
		var candidates: Array = base_candidates
		if distance > 0:
			candidates = base_candidates.filter(
				func(c): return not _too_close_to_existing_decoration(c[0], distance)
			)
		if not candidates.is_empty():
			var picked: Array = candidates[randi() % candidates.size()]
			var inst := WallDecorationInstance.create(spawn.decoration, picked[0], picked[1])
			wall_decorations.append(inst)
			_wall_faces_used[inst.get_face_key()] = true
			return
		distance -= 1

func _is_decoratable_wall(cell: Vector2i, wall_dir: Vector2i) -> bool:
	# Wall-dir neighbour must be a WALL cell (in bounds). The face
	# itself must not already hold a decoration.
	var nx: int = cell.x + wall_dir.x
	var ny: int = cell.y + wall_dir.y
	if not _in_bounds(nx, ny):
		return false
	if grid[nx][ny].cell_type != GridCell.CellType.WALL:
		return false
	if _wall_faces_used.has(WallDecorationInstance.face_key(cell, wall_dir)):
		return false
	return true

func _too_close_to_existing_decoration(pos: Vector2i, min_distance: int) -> bool:
	if min_distance <= 0:
		return false
	for inst in wall_decorations:
		if _manhattan(pos, inst.cell) < min_distance:
			return true
	return false

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
			# Trap cells are walkable (traps don't block) but we don't
			# want chests / floor items piling on top of a hazard, so the
			# pool excludes them. Placement passes that EXPLICITLY want
			# to consider trap cells (none today) would build their own
			# candidate set instead of going through this helper.
			if cell.trap != null:
				continue
			# Teleporter cells are also walkable but reserved — Phase 15
			# Task 6 / Phase C places teleporter pairs BEFORE all other
			# floor passes, so a chest / item / trap on the same cell as
			# a rune circle would visually overlap the warp glyph and
			# step-on a teleporter while standing on a trap. Same
			# exclusion treatment as trap cells.
			if cell.teleporter != null:
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
# Secret walls (edge-based, purely visual)
#
# A secret wall sits on the boundary between two adjacent 1-wide
# corridor floor cells — same eligibility rules as a door. It is
# never recorded in any movement-blocking structure: PlayerController
# walks through the edge as if it weren't there, and chain
# reachability ignores secret walls entirely. The DungeonView paints
# a wall quad on the edge so the player SEES a wall; the map paints
# an "S" so the player has a hint that the wall is special.
#
# Each SecretWallSpawn produces count_min..count_max instances. When
# `gate_mode != NONE`, the placement only commits an edge if sealing
# that edge would cut off content of the configured kind from the
# entrance — a secret wall that hides nothing is rejected.
# -------------------------------------------------------
func _place_secret_walls() -> void:
	if secret_wall_spawns_pool.is_empty():
		return
	for spawn in secret_wall_spawns_pool:
		if spawn == null:
			continue
		var count := randi_range(max(0, spawn.count_min), max(spawn.count_min, spawn.count_max))
		for _i in range(count):
			_try_place_secret_wall(spawn)

func _try_place_secret_wall(spawn: SecretWallSpawn) -> void:
	# Reuse the door candidate-edge helper — eligibility (1-wide
	# corridor, not entrance/exit, no chest etc.) is identical.
	#
	# Strategy mirrors `_try_place_object`:
	#   - When `min_distance_to_other_object > 0`: farthest-point
	#     insertion. Each new wall goes to the candidate edge that
	#     MAXIMIZES the Manhattan distance from EITHER endpoint to the
	#     nearest already-placed cell-object (chest / lever), door
	#     endpoint, OR previously-placed secret-wall endpoint. This
	#     keeps secret walls well-spread even when the configured
	#     floor is geometrically impossible.
	#
	#     Bugfix history: the old placer's distance predicate ignored
	#     other secret walls entirely (only checked `cell.object` and
	#     `doors`), so a second wall could land 1 tile from the first
	#     no matter how high `min_distance_to_other_object` was set.
	#     The new helper `_nearest_existing_edge_neighbor_distance`
	#     includes secret walls in the set it measures against.
	#
	#   - When `min_distance_to_other_object == 0`: legacy random
	#     shuffle. The designer explicitly opted out of spacing.
	var candidates: Array = _candidate_edges_for_secret_wall()
	if candidates.is_empty():
		push_warning("LevelGenerator: could not place secret wall — no eligible 1-wide-corridor edge satisfies gating + spacing")
		return

	var min_required: int = max(0, spawn.min_distance_to_other_object)
	var ordered: Array
	if min_required > 0:
		ordered = _rank_edges_by_farthest_neighbor(candidates)
	else:
		ordered = []
		candidates.shuffle()
		for edge in candidates:
			ordered.append([-1, edge])

	for entry in ordered:
		var score: int = entry[0]
		var edge: Array = entry[1]
		var a: Vector2i = edge[0]
		var b: Vector2i = edge[1]
		# Edges already hosting a door or another secret wall are
		# off-limits — two edge-bound elements on the same edge
		# would fight for rendering and confuse the map.
		if _doors_by_edge.has(DoorInstance.edge_key(a, b)):
			continue
		if _secret_walls_by_edge.has(SecretWallInstance.edge_key(a, b)):
			continue
		if spawn.gate_mode != SecretWallSpawn.GateMode.NONE \
				and not _secret_wall_gates_content(a, b, spawn.gate_mode):
			continue
		# Belt-and-suspenders runtime check: any non-NONE placement
		# must be on a bridge (sealing the edge must disconnect at
		# least one endpoint from the entrance). The gating check
		# above already enforces this, but a loud `push_error` here
		# would catch any future regression in the chain-reachability
		# helpers that lets a loop edge slip through.
		if spawn.gate_mode != SecretWallSpawn.GateMode.NONE:
			var verify_closed: Dictionary = {SecretWallInstance.edge_key(a, b): true}
			var verify_reach: Dictionary = _chain_reachable_from_entrance({}, verify_closed)
			if verify_reach.has(a) and verify_reach.has(b):
				push_error("LevelGenerator: secret wall about to commit on a LOOP edge %s/%s — gating check is broken (gate_mode=%d)" % [a, b, spawn.gate_mode])
				continue
		var inst := SecretWallInstance.create(a, b)
		secret_walls.append(inst)
		_secret_walls_by_edge[SecretWallInstance.edge_key(a, b)] = inst
		if min_required > 0 and score >= 0 and score < min_required:
			push_warning("LevelGenerator: placed secret wall at distance %d to nearest neighbour (configured floor: %d) — biome geometry doesn't permit further spread" % [score, min_required])
		return
	push_warning("LevelGenerator: could not place secret wall — no eligible 1-wide-corridor edge satisfies gating + spacing")

# Ranks edge-bound candidates (each entry is a [cell_a, cell_b] pair)
# by Manhattan distance to the nearest existing edge-relevant neighbour:
# cell-objects (chests / levers), door endpoints, and secret-wall
# endpoints. Edges with no neighbours yet score -1 (treated as "max
# possible"). Ties shuffled. Mirrors `_rank_by_farthest_object` but
# operates on edges instead of single cells.
func _rank_edges_by_farthest_neighbor(edges: Array) -> Array:
	var has_any: bool = (not doors.is_empty()) or (not secret_walls.is_empty())
	if not has_any:
		for x in range(grid_width):
			if has_any:
				break
			for y in range(grid_height):
				if grid[x][y].object != null:
					has_any = true
					break
	var scored: Array = []
	for edge in edges:
		var score: int
		if has_any:
			score = _nearest_existing_edge_neighbor_distance(edge)
		else:
			score = -1
		scored.append([score, edge])
	scored.sort_custom(func(a, b): return a[0] > b[0])
	var i := 0
	while i < scored.size():
		var j := i
		while j < scored.size() and scored[j][0] == scored[i][0]:
			j += 1
		if j - i > 1:
			var slice: Array = scored.slice(i, j)
			slice.shuffle()
			for k in range(slice.size()):
				scored[i + k] = slice[k]
		i = j
	return scored

# Min Manhattan distance from either endpoint of `edge` to:
#   - any cell with a non-null `object` (chests, levers)
#   - any door endpoint (doors are edge-bound)
#   - any already-placed secret-wall endpoint
# Returns -1 if nothing of the above is on the grid (callers treat -1
# as "score doesn't matter, every cell is tied").
func _nearest_existing_edge_neighbor_distance(edge: Array) -> int:
	var a: Vector2i = edge[0]
	var b: Vector2i = edge[1]
	var best: int = -1
	for x in range(grid_width):
		for y in range(grid_height):
			if grid[x][y].object == null:
				continue
			var dist: int = min(_manhattan(a, Vector2i(x, y)), _manhattan(b, Vector2i(x, y)))
			if best == -1 or dist < best:
				best = dist
	for door in doors:
		var dist_d: int = min(
			min(_manhattan(a, door.cell_a), _manhattan(a, door.cell_b)),
			min(_manhattan(b, door.cell_a), _manhattan(b, door.cell_b))
		)
		if best == -1 or dist_d < best:
			best = dist_d
	for sw in secret_walls:
		var dist_s: int = min(
			min(_manhattan(a, sw.cell_a), _manhattan(a, sw.cell_b)),
			min(_manhattan(b, sw.cell_a), _manhattan(b, sw.cell_b))
		)
		if best == -1 or dist_s < best:
			best = dist_s
	return best

func _candidate_edges_for_secret_wall() -> Array:
	# Same shape as `_candidate_edges_for_door` (1-wide corridor cells
	# on both ends, no entrance/exit, no chest underneath) but without
	# the ObjectSpawn placement-flag gate — secret walls only ever
	# live on corridor edges.
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
				var pair: Array = SecretWallInstance.canonical_pair(pos, npos)
				var key: String = "%d,%d|%d,%d" % [pair[0].x, pair[0].y, pair[1].x, pair[1].y]
				if seen.has(key):
					continue
				seen[key] = true
				result.append(pair)
	return result

func _secret_wall_gates_content(a: Vector2i, b: Vector2i, gate_mode: int) -> bool:
	# Decides whether a secret wall on edge (a, b) is allowed under
	# `gate_mode`. Simulates "this edge is a real, permanent wall" and
	# walks the world from the entrance under chain reachability with
	# the secret-wall edge sealed. The secret-wall edge isn't a door,
	# so we feed it through the extra_closed_edges parameter rather
	# than `excluded_door_keys` (which only suppresses doors that DO
	# exist on that edge).
	#
	# Three rules combine:
	#
	# 1. BRIDGE: the wall must be on a graph bridge. Sealing the edge
	#    must disconnect at least one of its endpoints from the
	#    entrance. If both endpoints stay reachable, the wall sits on
	#    a loop and walking through it reveals nothing the player
	#    couldn't have reached otherwise — fail fast. The downstream
	#    content checks would catch this too (a loop wall gates
	#    nothing), but stating it explicitly here documents the
	#    intent and serves as a safety net.
	#
	# 2. `gates_loot`: at least one chest cell OR non-key floor-item
	#    cell becomes unreachable from the entrance.
	#
	# 3. `gates_progression`: the exit, a lever, a key (floor OR
	#    inside a chest) becomes unreachable. These are "important"
	#    cells the player can't be allowed to lose access to.
	#
	# Then per mode:
	#   - ANY_CONTENT: pass if gates_loot OR gates_progression.
	#     Mirrors the locked-door must_gate_content rule.
	#   - LOOT_ONLY: pass if gates_loot AND NOT gates_progression.
	#     The wall must hide loot AND must not block any progression
	#     element. A wall that gates "a chest AND the exit" is
	#     rejected here — the user explicitly doesn't want secret
	#     walls walling off the main path.
	#   - NONE: this function isn't called.
	var extra_closed: Dictionary = {SecretWallInstance.edge_key(a, b): true}
	var restricted: Dictionary = _chain_reachable_from_entrance({}, extra_closed)
	# Rule 1: bridge check.
	if restricted.has(a) and restricted.has(b):
		return false
	var gates_loot: bool = false
	var gates_progression: bool = false
	for x in range(grid_width):
		for y in range(grid_height):
			var cell: GridCell = grid[x][y]
			var pos := Vector2i(x, y)
			if cell.cell_type == GridCell.CellType.EXIT:
				if not restricted.has(pos):
					gates_progression = true
			if cell.object != null and cell.object is LeverInstance:
				if not _has_reachable_neighbour(pos, restricted):
					gates_progression = true
			# Floor items: a key item routes to progression, every
			# other item routes to loot. Same cell can hold both —
			# scan each item independently.
			if not cell.items.is_empty() and not restricted.has(pos):
				for item in cell.items:
					if item == null:
						continue
					if item.get_key_id() != "":
						gates_progression = true
					else:
						gates_loot = true
			if cell.object != null and cell.object.is_chest():
				if not _has_reachable_neighbour(pos, restricted):
					gates_loot = true
					# Chests holding a key route to progression too.
					for chest_item in cell.object.items:
						if chest_item != null and chest_item.get_key_id() != "":
							gates_progression = true
	match gate_mode:
		SecretWallSpawn.GateMode.ANY_CONTENT:
			return gates_loot or gates_progression
		SecretWallSpawn.GateMode.LOOT_ONLY:
			return gates_loot and not gates_progression
		_:
			return false

# Public — DungeonView and MapPopup iterate `secret_walls` directly;
# this helper is here for symmetry with `get_door_at_edge`.
func get_secret_wall_at_edge(a: Vector2i, b: Vector2i) -> SecretWallInstance:
	return _secret_walls_by_edge.get(SecretWallInstance.edge_key(a, b), null)

# -------------------------------------------------------
# Teleporters (Phase 15 Task 6 — Phase C: island topology)
# -------------------------------------------------------
# Partition pass runs RIGHT AFTER `_validate_path()` and BEFORE every
# object / door / trap / item pass. It seals K-1 articulation corridor
# cells (converting them to WALL) and places K-1 teleporter pairs as
# a spanning tree connecting the K resulting islands. After this
# pass, every downstream placement pass sees the partitioned topology
# and chain reachability v3 (`_chain_reachable_from_entrance`)
# transparently treats teleporters as bidirectional graph edges, so
# lever / key / chest placement keeps validating correctly even when
# the chain crosses an island boundary via a warp.
#
# Atomic rollback: any failure (no articulation candidates, no valid
# spanning-tree placement, chain reachability fails) restores every
# sealed cell to FLOOR and clears placed teleporters. A flat level
# is fine; a broken one is not.

# Maximum attempts to find a viable seal-then-place configuration
# before giving up and shipping a flat (no partition) level. Each
# attempt rolls fresh seal candidates because the order of articulation
# checks depends on RNG via _pick_seal_cells's pool shuffle.
const _PARTITION_OUTER_ATTEMPTS := 8

func _partition_and_place_teleporters_if_enabled() -> void:
	if teleporter_spawn_config == null:
		return
	var spawn := teleporter_spawn_config
	if not spawn.uses_partition():
		return
	if spawn.data == null:
		push_warning("LevelGenerator: teleporter_spawn set with island_count >= 2 but data is null — partition disabled this level")
		return
	# Roll K (number of islands) once per level. Clamped to >= 2 since
	# partition mode requires at least one split.
	var k_min: int = max(2, spawn.island_count_min)
	var k_max: int = max(k_min, spawn.island_count_max)
	var K: int = randi_range(k_min, k_max)
	# Outer retry loop: a single set of seal cells might happen to leave
	# an island that's too small to host a teleporter endpoint with the
	# configured min_distance_between_partners. Reroll seals up to
	# `_PARTITION_OUTER_ATTEMPTS` times before falling through to a
	# flat level.
	for attempt in range(_PARTITION_OUTER_ATTEMPTS):
		if _try_partition_attempt(spawn, K):
			return
	push_warning("LevelGenerator: partition failed after %d attempts (K=%d) — shipping a flat level" % [_PARTITION_OUTER_ATTEMPTS, K])

# One attempt at the seal + spanning-tree pipeline. Returns true on
# success (level is partitioned + warps placed), false on rollback.
# Failure modes — each rolls back atomically:
#   - fewer than K-1 viable seal candidates (loopy maze)
#   - seals don't produce exactly K islands (rare; defensive against
#     a bug in `_pick_seal_cells` that picked non-articulation cells)
#   - any spanning-tree pair fails to find two valid endpoints across
#     its assigned island pair (island too small / too cramped)
#   - final chain reachability fails (exit unreachable from entrance
#     under the warp graph — would mean the spanning tree didn't
#     actually connect the entrance's island to the exit's island)
func _try_partition_attempt(spawn: TeleporterSpawn, K: int) -> bool:
	# Snapshot for atomic rollback. teleporters was empty at the start
	# of generate(), but we snapshot defensively in case a future
	# pipeline change places some teleporters earlier.
	var teleporters_snapshot: Array = teleporters.duplicate()
	var seal_cells: Array[Vector2i] = []
	# 1. Pick K-1 articulation corridor cells.
	var picked: Array[Vector2i] = _pick_seal_cells(K - 1, spawn)
	if picked.size() < K - 1:
		return false
	# 2. Apply seals (convert each picked cell to WALL).
	for cell in picked:
		grid[cell.x][cell.y].cell_type = GridCell.CellType.WALL
		seal_cells.append(cell)
	# 3. Identify K connected components.
	var islands: Array = _identify_islands()
	if islands.size() != K:
		# Defensive — the articulation check should guarantee this, but
		# a degenerate maze (e.g. a tight T-junction whose three arms
		# are each one cell long) could in theory produce a different
		# count. Roll back and let the outer loop retry.
		_rollback_partition(seal_cells, teleporters_snapshot)
		return false
	# 4. Build spanning tree of islands rooted at the entrance's
	# island. Tree edges are pairs of island indices.
	var entrance_island: int = _island_index_for(islands, entrance_pos)
	if entrance_island < 0:
		_rollback_partition(seal_cells, teleporters_snapshot)
		return false
	var tree_edges: Array = _spanning_tree_of_islands(islands, entrance_island)
	if tree_edges.size() != K - 1:
		# Shouldn't happen — a spanning tree over K nodes has exactly
		# K-1 edges by definition. Defensive guard.
		_rollback_partition(seal_cells, teleporters_snapshot)
		return false
	# 5. Place K-1 teleporter pairs, one per tree edge.
	var pair_index: int = 0
	for edge in tree_edges:
		var island_a: Array = islands[edge[0]]
		var island_b: Array = islands[edge[1]]
		var ok: bool = _place_teleporter_pair_across_islands(spawn, island_a, island_b, pair_index)
		if not ok:
			_rollback_partition(seal_cells, teleporters_snapshot)
			return false
		pair_index += 1
	# 6. Final validation: chain reachability from entrance reaches
	# the exit. Without this check, a buggy spanning tree could leave
	# the exit's island unreachable even though structurally the
	# islands are bridged.
	var reachable: Dictionary = _chain_reachable_from_entrance()
	if not reachable.has(exit_pos):
		push_warning("LevelGenerator: partition broke entrance→exit reachability — rolling back")
		_rollback_partition(seal_cells, teleporters_snapshot)
		return false
	return true

# Picks `count` articulation corridor cells. An articulation cell is
# a 1-wide corridor floor cell (exactly 2 non-wall neighbours, which
# `_is_door_endpoint` already captures) whose removal disconnects the
# graph. The picker is QUALITY-DRIVEN, not random:
#   1. Find every articulation candidate on the original grid.
#   2. Score each by the size of the SMALLER component it produces
#      (large = more balanced split, small = the cell strands a stub).
#   3. Reject candidates below `spawn.min_island_size` — a 1-3 cell
#      stub strands the warp on nothing for the player to do.
#   4. Sort the remaining candidates by smaller-component-size descending
#      and incrementally seal them (each new seal is re-evaluated
#      against the post-previous-seals grid). Adds light jitter — pick
#      randomly among the top quartile — so different seeds don't all
#      land on the same maximally-balanced seal cell.
#
# Greedy on the SORTED order is good enough for K=2 (the common case).
# For K=3+ the second seal is scored against the post-first-seal grid,
# which can leave fewer balanced options; the outer retry loop reseeds
# if we run out of candidates.
func _pick_seal_cells(count: int, spawn: TeleporterSpawn) -> Array[Vector2i]:
	var picked: Array[Vector2i] = []
	if count <= 0:
		return picked
	var min_to_ee: int = max(0, spawn.min_seal_distance_to_entrance_exit)
	var min_between: int = max(0, spawn.min_seal_distance_between_seals)
	var min_island: int = max(1, spawn.min_island_size)
	# Each iteration picks ONE seal. Re-scoring per iteration means K=3+
	# picks are evaluated against the post-previous-seals grid (so the
	# second seal doesn't accidentally re-strand a tiny piece of what
	# was a healthy island).
	for _i in range(count):
		var scored: Array = _score_seal_candidates(min_to_ee, min_island, picked, min_between)
		if scored.is_empty():
			break
		# Pick from the top quartile to add seed-to-seed variety while
		# still biasing toward balanced splits. With 20 candidates the
		# top 5 typically share similar "smaller component" sizes.
		var top_n: int = max(1, scored.size() / 4)
		var pick_entry: Dictionary = scored[randi() % top_n]
		var cand: Vector2i = pick_entry["cell"]
		# Commit this seal temporarily so the next iteration's scoring
		# sees the updated grid. The outer pipeline owns the atomic
		# commit; we roll these back below before returning.
		grid[cand.x][cand.y].cell_type = GridCell.CellType.WALL
		picked.append(cand)
	# Roll back the temporary seals — the outer pipeline applies them
	# atomically alongside the teleporter placements. Keeping the
	# state machine in `_try_partition_attempt` instead of `_pick_seal_cells`
	# means rollback paths only have to undo one layer of state, not two.
	for p in picked:
		grid[p.x][p.y].cell_type = GridCell.CellType.FLOOR
	return picked

# Scoring pass for `_pick_seal_cells`. Returns an Array of
# `{cell: Vector2i, smaller_size: int}` dicts SORTED descending by
# `smaller_size`. Each candidate must be:
#   - a 1-wide corridor cell on the CURRENT grid (`_is_door_endpoint`)
#   - ≥ `min_to_ee` Manhattan tiles from entrance AND exit
#   - ≥ `min_between` Manhattan tiles from every already-picked seal
#   - an articulation point on the CURRENT grid
#   - produces a smaller component of ≥ `min_island_size` cells
# The smaller component size is computed via
# `_smaller_component_size_if_sealed`, which runs one BFS per candidate
# — O(V * pool_size) total, well under a millisecond on a 21x21 grid.
func _score_seal_candidates(min_to_ee: int, min_island_size: int, already_picked: Array, min_between: int) -> Array:
	var scored: Array = []
	for x in range(grid_width):
		for y in range(grid_height):
			var pos := Vector2i(x, y)
			if not _is_door_endpoint(pos):
				continue
			if _manhattan(pos, entrance_pos) < min_to_ee:
				continue
			if _manhattan(pos, exit_pos) < min_to_ee:
				continue
			var too_close: bool = false
			for p in already_picked:
				if _manhattan(pos, p) < min_between:
					too_close = true
					break
			if too_close:
				continue
			if not _is_articulation_cell(pos):
				continue
			var smaller_size: int = _smaller_component_size_if_sealed(pos)
			if smaller_size < min_island_size:
				continue
			scored.append({"cell": pos, "smaller_size": smaller_size})
	scored.sort_custom(func(a, b): return a["smaller_size"] > b["smaller_size"])
	return scored

# Returns the size of the SMALLER component produced by virtually
# sealing `pos`. Uses the existing `_bfs_walkable_skipping` helper to
# count entrance-reachable floor cells; the other component's size is
# `total_floor - 1 - reachable_count` (subtract 1 for `pos` itself,
# which is virtually walled). The minimum of these two is the
# "smaller-component" score the seal picker uses to balance splits.
# A non-articulation cell would produce smaller_size = 0 (the seal
# doesn't disconnect anything) — but the picker filters those out via
# `_is_articulation_cell` before calling this, so we always return a
# meaningful number.
func _smaller_component_size_if_sealed(pos: Vector2i) -> int:
	var skip := {pos: true}
	var entrance_side: Dictionary = _bfs_walkable_skipping(entrance_pos, skip)
	var total: int = 0
	for x in range(grid_width):
		for y in range(grid_height):
			if grid[x][y].cell_type != GridCell.CellType.WALL:
				total += 1
	# `pos` is non-wall but skipped — subtract it from the total floor
	# count so the two sides sum correctly.
	var other_side: int = total - 1 - entrance_side.size()
	return min(entrance_side.size(), other_side)

# True iff converting `pos` to WALL would disconnect the floor graph.
# BFS from entrance with `pos` treated as wall — if any floor cell
# (other than `pos` itself) becomes unreachable, `pos` is an
# articulation point. O(V) per call; called O(pool_size) times per
# partition attempt, so total cost is O(V * pool_size) ≈ O(V²) on a
# typical 21x21 grid — well under a millisecond.
func _is_articulation_cell(pos: Vector2i) -> bool:
	if pos == entrance_pos or pos == exit_pos:
		return false
	if grid[pos.x][pos.y].cell_type == GridCell.CellType.WALL:
		return false
	# Count floor cells reachable from entrance WITHOUT going through
	# `pos`. If that count is less than (total_floor_cells - 1),
	# removing `pos` strands at least one cell.
	var skip := {pos: true}
	var visited: Dictionary = _bfs_walkable_skipping(entrance_pos, skip)
	# Total non-wall cells minus `pos` (which we're virtually removing).
	var total: int = 0
	for x in range(grid_width):
		for y in range(grid_height):
			if grid[x][y].cell_type != GridCell.CellType.WALL:
				total += 1
	# `pos` itself is a non-wall but skip'd, so subtract 1.
	return visited.size() < (total - 1)

# BFS from `origin` skipping cells in `skip_cells`. Used by the
# articulation check; intentionally simpler than the chain-reachability
# BFS (no doors / teleporters considered — the question is purely
# "if I delete this cell, does the floor graph stay connected?").
func _bfs_walkable_skipping(origin: Vector2i, skip_cells: Dictionary) -> Dictionary:
	if skip_cells.has(origin):
		return {}
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
			if skip_cells.has(npos):
				continue
			if grid[nx][ny].cell_type == GridCell.CellType.WALL:
				continue
			visited[npos] = true
			queue.append(npos)
	return visited

# Computes the K connected components of the floor graph (post-seal).
# Returns an Array of Arrays — each inner array is the list of cells
# belonging to that island. Order matches BFS discovery order; the
# entrance's island always exists and `_island_index_for` finds it.
func _identify_islands() -> Array:
	var islands: Array = []
	var visited: Dictionary = {}
	for x in range(grid_width):
		for y in range(grid_height):
			var pos := Vector2i(x, y)
			if visited.has(pos):
				continue
			if grid[x][y].cell_type == GridCell.CellType.WALL:
				continue
			# Flood-fill from this cell to discover a new island.
			var island_cells: Array[Vector2i] = []
			var queue: Array = [pos]
			visited[pos] = true
			while not queue.is_empty():
				var current: Vector2i = queue.pop_front()
				island_cells.append(current)
				for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
					var nx: int = current.x + d.x
					var ny: int = current.y + d.y
					if not _in_bounds(nx, ny):
						continue
					var npos := Vector2i(nx, ny)
					if visited.has(npos):
						continue
					if grid[nx][ny].cell_type == GridCell.CellType.WALL:
						continue
					visited[npos] = true
					queue.append(npos)
			islands.append(island_cells)
	return islands

# Linear scan for the island containing `target`. Returns -1 if no
# island matches — shouldn't happen for valid entrance / exit cells
# since both are floor by construction, but defensive.
func _island_index_for(islands: Array, target: Vector2i) -> int:
	for i in range(islands.size()):
		if (islands[i] as Array).has(target):
			return i
	return -1

# Builds a spanning tree over K islands as a sequence of (a, b) index
# pairs. Rooted at `root_index` (the entrance's island) so the tree
# expands outward — a BFS over the "two islands are adjacent if a
# cell in one is 4-adjacent to a sealed cell that borders the other"
# graph. Simpler model used here: greedily connect each unvisited
# island to the closest visited one (Manhattan between any pair of
# cells across the two islands). Produces K-1 edges by induction.
func _spanning_tree_of_islands(islands: Array, root_index: int) -> Array:
	var tree: Array = []
	var in_tree: Dictionary = {root_index: true}
	var n: int = islands.size()
	# K-1 iterations — each adds one previously-unconnected island.
	while in_tree.size() < n:
		var best_in: int = -1
		var best_out: int = -1
		var best_dist: int = -1  # -1 sentinel = "no candidate yet"
		for i in in_tree.keys():
			for j in range(n):
				if in_tree.has(j):
					continue
				var dist: int = _islands_closest_distance(islands[i], islands[j])
				if best_dist < 0 or dist < best_dist:
					best_dist = dist
					best_in = i
					best_out = j
		if best_out < 0:
			# All remaining islands are unreachable from the seed tree
			# — shouldn't happen with a well-formed sealed grid where
			# every island has SOME cell pair within reasonable distance.
			break
		tree.append([best_in, best_out])
		in_tree[best_out] = true
	return tree

# Cheapest Manhattan between any cell of `a` and any cell of `b`.
# Quadratic in the island sizes but island sizes are typically small
# (< 100 cells each), so total cost stays tiny.
func _islands_closest_distance(a: Array, b: Array) -> int:
	var best: int = -1
	for ca in a:
		for cb in b:
			var d: int = _manhattan(ca, cb)
			if best < 0 or d < best:
				best = d
	return best

# Place one teleporter pair across `island_a` and `island_b`. The two
# endpoints sit one in each island; they satisfy
# `min_distance_between_partners` (graceful-degrade), avoid entrance /
# exit, and avoid any cells already holding objects / traps / items /
# previous teleporter endpoints (defensive even though Phase C runs
# before every other placement pass — keeps the function reusable if
# the order ever shifts).
func _place_teleporter_pair_across_islands(spawn: TeleporterSpawn, island_a: Array, island_b: Array, pair_index: int) -> bool:
	var pool_a: Array[Vector2i] = _filter_island_for_teleporter(island_a)
	var pool_b: Array[Vector2i] = _filter_island_for_teleporter(island_b)
	if pool_a.is_empty() or pool_b.is_empty():
		return false
	pool_a.shuffle()
	pool_b.shuffle()
	# Graceful-degrade on min_distance_between_partners. The picked
	# pair is the first (a, b) the shuffle order produces that meets
	# the current distance threshold.
	var min_partner: int = max(0, spawn.min_distance_between_partners)
	var d := min_partner
	while d >= 0:
		for cell_a in pool_a:
			for cell_b in pool_b:
				if _manhattan(cell_a, cell_b) < d:
					continue
				var inst := TeleporterInstance.create(spawn.data, cell_a, cell_b, pair_index)
				grid[cell_a.x][cell_a.y].teleporter = inst
				grid[cell_b.x][cell_b.y].teleporter = inst
				teleporters.append(inst)
				return true
		d -= 1
	return false

# Returns the subset of `island` cells eligible to host a teleporter
# endpoint: floor cells, not entrance / exit, no object / trap /
# spinner / item / existing teleporter. In partition mode this runs
# BEFORE all other placement passes so the per-cell check is mostly
# defensive — entrance / exit and current teleporters are the only
# real exclusions today.
func _filter_island_for_teleporter(island: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for pos in island:
		if pos == entrance_pos or pos == exit_pos:
			continue
		var cell: GridCell = grid[pos.x][pos.y]
		if cell.cell_type != GridCell.CellType.FLOOR:
			continue
		if cell.object != null or cell.trap != null or cell.spinner != null:
			continue
		if not cell.items.is_empty():
			continue
		if cell.teleporter != null:
			continue
		result.append(pos)
	return result

# Undo a partition attempt atomically. Restores every sealed cell to
# FLOOR and clears the teleporters list back to the snapshot. Per-cell
# teleporter slot pointers are cleared by iterating the discarded
# instances (rather than walking the whole grid).
func _rollback_partition(seal_cells: Array, teleporters_snapshot: Array) -> void:
	for pos in seal_cells:
		grid[pos.x][pos.y].cell_type = GridCell.CellType.FLOOR
	# Clear per-cell teleporter slots for any instance added since the
	# snapshot.
	for i in range(teleporters_snapshot.size(), teleporters.size()):
		var inst: TeleporterInstance = teleporters[i]
		if inst == null:
			continue
		grid[inst.cell_a.x][inst.cell_a.y].teleporter = null
		grid[inst.cell_b.x][inst.cell_b.y].teleporter = null
	teleporters = teleporters_snapshot

# -------------------------------------------------------
# Teleporters (Phase 15 Task 6 — Phase A: dumb placement)
# -------------------------------------------------------
# Phase A places `count` random teleporter PAIRS on non-special floor
# cells. No partitioning — the warp is a pure shortcut. Phase C will
# replace this with the island-topology variant where the level is
# split into K islands and each pair bridges two of them.
#
# Order: runs AFTER `_place_secret_walls()` and BEFORE
# `_place_wall_decorations()` — last among floor passes so every other
# pass's placements are known and the exclusion set is complete.
# Wall decorations don't share cells with teleporters (one's on a wall
# face, the other on a floor cell), so coming last among floor passes
# is enough.
func _place_teleporters() -> void:
	if teleporter_spawn_config == null:
		return
	var spawn := teleporter_spawn_config
	# Phase 15 Task 6 — Phase C. When partition mode is active the
	# partition pass at the START of generation has already placed
	# the spanning-tree pairs; skip the legacy Phase A shortcut pass.
	if spawn.uses_partition():
		return
	if spawn.data == null:
		push_warning("LevelGenerator: teleporter_spawn set but data is null — skipping teleporter placement")
		return
	var lo: int = max(0, spawn.count_min)
	var hi: int = max(lo, spawn.count_max)
	var count: int = randi_range(lo, hi)
	if count <= 0:
		return
	var special_cells: Dictionary = _gather_teleporter_excluded_cells()
	var pair_index: int = 0
	for _i in range(count):
		if _try_place_teleporter_pair(spawn, special_cells, pair_index):
			# Newly placed teleporter endpoints become "special" for
			# subsequent pairs — this is in addition to the per-pair
			# `min_distance_to_other_teleporter` check, which gives a
			# spacing buffer even between the cells themselves. We add
			# them to `special_cells` so the `min_distance_to_other_object`
			# check (which is usually smaller) doesn't let a new pair
			# land directly ON an existing endpoint.
			special_cells[teleporters[-1].cell_a] = true
			special_cells[teleporters[-1].cell_b] = true
			pair_index += 1

func _try_place_teleporter_pair(spawn: TeleporterSpawn, special_cells: Dictionary, pair_index: int) -> bool:
	# Graceful-degrade BOTH "distance to other special content" and
	# "distance to other teleporter" — same pattern as spinner /
	# trap / item placement. Distance between partners is degraded
	# separately AFTER the candidate pool is locked in, so a tight
	# config can still produce a pair on the available cells.
	var min_obj: int = max(0, spawn.min_distance_to_other_object)
	var min_tele: int = max(0, spawn.min_distance_to_other_teleporter)
	var pool: Array = []
	var d_obj := min_obj
	while d_obj >= 0 and pool.size() < 2:
		var d_tele := min_tele
		while d_tele >= 0:
			pool = _build_teleporter_candidate_pool(special_cells, d_obj, d_tele)
			if pool.size() >= 2:
				break
			d_tele -= 1
		if pool.size() >= 2:
			break
		d_obj -= 1
	if pool.size() < 2:
		push_warning("LevelGenerator: could not place teleporter pair %d — no eligible floor cells" % pair_index)
		return false
	pool.shuffle()
	var cell_a: Vector2i = pool[0]
	# Pick partner with graceful-degrade on min_distance_between_partners.
	var min_partner: int = max(0, spawn.min_distance_between_partners)
	var cell_b: Vector2i = Vector2i(-1, -1)
	var d_partner := min_partner
	while d_partner >= 0:
		for cand in pool:
			if cand == cell_a:
				continue
			if _manhattan(cell_a, cand) >= d_partner:
				cell_b = cand
				break
		if cell_b != Vector2i(-1, -1):
			break
		d_partner -= 1
	if cell_b == Vector2i(-1, -1):
		push_warning("LevelGenerator: could not satisfy min_distance_between_partners for teleporter pair %d" % pair_index)
		return false
	var inst := TeleporterInstance.create(spawn.data, cell_a, cell_b, pair_index)
	grid[cell_a.x][cell_a.y].teleporter = inst
	grid[cell_b.x][cell_b.y].teleporter = inst
	teleporters.append(inst)
	return true

func _build_teleporter_candidate_pool(special_cells: Dictionary, min_to_object: int, min_to_other_teleporter: int) -> Array:
	# Returns every FLOOR cell that:
	#   - is not entrance / exit
	#   - holds NO object, trap, spinner, item, or existing teleporter
	#     endpoint (these are hard exclusions — `special_cells` carries
	#     them plus door endpoint cells + projectile-trap plates +
	#     entrance / exit)
	#   - is at least `min_to_object` Manhattan tiles from every cell
	#     in `special_cells` (buffer — graceful-degrade by caller)
	#   - is at least `min_to_other_teleporter` Manhattan tiles from
	#     every PREVIOUSLY placed teleporter endpoint (buffer between
	#     pairs — graceful-degrade by caller)
	var result: Array = []
	for x in range(grid_width):
		for y in range(grid_height):
			var pos := Vector2i(x, y)
			var cell: GridCell = grid[x][y]
			if cell.cell_type != GridCell.CellType.FLOOR:
				continue
			if special_cells.has(pos):
				continue
			if cell.teleporter != null:
				continue
			if min_to_object > 0 and _too_close_to_special_cell(pos, special_cells, min_to_object):
				continue
			if min_to_other_teleporter > 0 and _too_close_to_existing_teleporter(pos, min_to_other_teleporter):
				continue
			result.append(pos)
	return result

func _gather_teleporter_excluded_cells() -> Dictionary:
	# Cells that are FORBIDDEN for teleporter placement AND drive the
	# `min_distance_to_other_object` buffer. The two roles use the same
	# set: a cell with content is hard-excluded; cells WITHIN
	# min_distance of one are buffer-excluded. Includes:
	#   - entrance + exit (the player should never warp out of the start
	#     tile or onto the exit tile, and visually a teleporter glued to
	#     either is confusing)
	#   - chest / lever cells (cell.object)
	#   - trap cells (cell.trap)
	#   - spinner cells (cell.spinner)
	#   - floor item cells (cell.items not empty)
	#   - door endpoint cells (doors are edge-bound; both endpoint cells
	#     get excluded so a teleporter doesn't sit right at a door)
	#   - projectile-trap pressure plate cells (cell-bound floor decals)
	var result: Dictionary = {}
	result[entrance_pos] = true
	result[exit_pos] = true
	for x in range(grid_width):
		for y in range(grid_height):
			var pos := Vector2i(x, y)
			var cell: GridCell = grid[x][y]
			if cell.object != null:
				result[pos] = true
			if cell.trap != null:
				result[pos] = true
			if cell.spinner != null:
				result[pos] = true
			if not cell.items.is_empty():
				result[pos] = true
	for door in doors:
		result[door.cell_a] = true
		result[door.cell_b] = true
	for ptrap in projectile_traps:
		if ptrap == null:
			continue
		if ptrap.has_plate():
			result[ptrap.plate_cell] = true
	return result

func _too_close_to_special_cell(pos: Vector2i, special_cells: Dictionary, min_distance: int) -> bool:
	for k in special_cells:
		if _manhattan(pos, k) < min_distance:
			return true
	return false

func _too_close_to_existing_teleporter(pos: Vector2i, min_distance: int) -> bool:
	for inst in teleporters:
		if _manhattan(pos, inst.cell_a) < min_distance:
			return true
		if _manhattan(pos, inst.cell_b) < min_distance:
			return true
	return false

# Public — Game.gd uses this to resolve the partner cell when the
# player steps onto a teleporter. Mirrors the shape of
# `get_door_at_edge` / `get_secret_wall_at_edge`.
func get_teleporter_at(cell: Vector2i) -> TeleporterInstance:
	if not _in_bounds(cell.x, cell.y):
		return null
	return grid[cell.x][cell.y].teleporter

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

# -------------------------------------------------------
# Spinners (Phase 8 Task 8)
# -------------------------------------------------------
#
# Spinners run LAST among floor passes (after spike traps, items, and
# projectile traps) so the placer knows every "this cell already has
# something on it" exclusion: chests / levers (`cell.object`), spike
# traps (`cell.trap`), floor items (`cell.items`), and projectile-trap
# pressure plates (collected once at pass start from
# `projectile_traps`). The placer mirrors `_place_traps` — three
# additive modes per spawn (corridor cluster, room density, scattered)
# all reusing the same exclusion set.

func _place_spinners() -> void:
	if spinner_spawns_pool.is_empty():
		return
	# Topology hasn't changed since `_place_traps` ran. Re-detect here
	# rather than caching across passes — cheap on a 31×31 grid and
	# avoids subtle drift if a future pass ever mutates corridor cells.
	var segments: Array = _detect_corridor_segments()
	# Pressure plates live on `ProjectileTrapInstance.plate_cell` and
	# were assigned by `_place_projectile_traps()` immediately before
	# this pass. Collect once into a Dictionary[Vector2i -> true] for
	# O(1) exclusion lookup inside the candidate filters.
	var plate_cells: Dictionary = _gather_plate_cells()
	# Build the per-classification candidate pool with all exclusions
	# applied up-front. Same structure as `_classify_floor_cells` but
	# additionally filters out spinner cells, floor-item cells, and
	# plate cells — those are the late additions the existing helper
	# doesn't know about.
	var cells_by_type := _classify_spinner_candidate_cells(plate_cells)
	for spawn in spinner_spawns_pool:
		if spawn == null or spawn.spinner == null:
			continue
		if spawn.uses_corridor_clusters() and spawn.allows(ObjectSpawn.PLACEMENT_CORRIDOR):
			_place_corridor_spinners(spawn, segments, cells_by_type)
		if spawn.uses_room_density() and spawn.allows(ObjectSpawn.PLACEMENT_ROOM):
			_place_room_spinners(spawn, cells_by_type)
		var count := randi_range(max(0, spawn.count_min), max(spawn.count_min, spawn.count_max))
		for _i in range(count):
			_try_place_spinner(spawn, cells_by_type)

# Builds the per-classification candidate pool used by all three
# spinner passes. Mirrors `_classify_floor_cells` but applies the
# spinner-specific exclusions: chest / lever (cell.object), spike trap
# (cell.trap), floor item (cell.items), and projectile-trap plate
# cells (passed in). Entrance / exit are excluded too — the player
# shouldn't be spun on the level boundaries where their bearings
# matter most.
func _classify_spinner_candidate_cells(plate_cells: Dictionary) -> Dictionary:
	var result := {
		ObjectSpawn.PLACEMENT_CORRIDOR: [],
		ObjectSpawn.PLACEMENT_ROOM:     [],
		ObjectSpawn.PLACEMENT_DEAD_END: [],
	}
	for x in range(1, grid_width - 1):
		for y in range(1, grid_height - 1):
			var cell: GridCell = grid[x][y]
			if cell.cell_type != GridCell.CellType.FLOOR:
				continue
			var pos := Vector2i(x, y)
			if pos == entrance_pos or pos == exit_pos:
				continue
			# Mutual-exclusion checks — kept here (not in is_blocked)
			# so non-blocking objects like levers still register as
			# "occupied" for spinner purposes.
			if cell.object != null:
				continue
			if cell.trap != null:
				continue
			if cell.spinner != null:
				continue
			# Phase 15 Task 6 — Phase C. Teleporters placed FIRST in
			# partition mode; a spinner on a teleporter endpoint would
			# spin the player after the warp lands, undoing the warp's
			# directional intent + double-stacking decals.
			if cell.teleporter != null:
				continue
			if not cell.items.is_empty():
				continue
			if plate_cells.has(pos):
				continue
			if _is_dead_end(pos):
				result[ObjectSpawn.PLACEMENT_DEAD_END].append(pos)
			elif _is_in_room(pos):
				result[ObjectSpawn.PLACEMENT_ROOM].append(pos)
			else:
				result[ObjectSpawn.PLACEMENT_CORRIDOR].append(pos)
	return result

# Collects every projectile-trap plate cell into a Dictionary for
# O(1) lookup during candidate filtering. NO_PLATE sentinel is
# filtered out (TIMED launchers have no plate).
func _gather_plate_cells() -> Dictionary:
	var result: Dictionary = {}
	for ptrap in projectile_traps:
		if ptrap == null:
			continue
		if not ptrap.has_plate():
			continue
		result[ptrap.plate_cell] = true
	return result

func _place_corridor_spinners(spawn: SpinnerSpawn, segments: Array, cells_by_type: Dictionary) -> void:
	# One spawn per segment — same identity rule clusters use for
	# traps. Adjacent-junction segments aren't dis-allowed for spinners
	# the way they are for traps: a player crossing a junction between
	# two spinner clusters gets spun in each, which is fine (and
	# arguably the disorientation peak). Skip only the direct-overlap
	# case so two clusters from the same biome don't carpet a single
	# segment.
	for segment in segments:
		if _segment_has_spinner(segment):
			continue
		if randf() >= spawn.corridor_segment_chance:
			continue
		var eligible: Array = _eligible_spinner_segment_cells(segment)
		var min_n: int = max(1, spawn.corridor_spinners_per_run_min)
		if eligible.size() < min_n:
			continue
		var max_n: int = max(min_n, spawn.corridor_spinners_per_run_max)
		max_n = min(max_n, eligible.size())
		var target_n: int = randi_range(min_n, max_n)
		var run: Array = _gather_run_in_segment(eligible, target_n)
		for pos in run:
			_commit_spinner_at(spawn, pos, cells_by_type)
			_spinner_cluster_cells[pos] = true

func _place_room_spinners(spawn: SpinnerSpawn, cells_by_type: Dictionary) -> void:
	for room_obj in _room_rects:
		var room: Rect2i = room_obj as Rect2i
		if randf() >= spawn.room_chance:
			continue
		if not spawn.allow_mixed_room_spinners and _room_has_any_spinner(room):
			continue
		var room_cells: Array = _eligible_spinner_room_cells(room)
		if room_cells.is_empty():
			continue
		var coverage_min: float = clamp(spawn.room_coverage_min_percent, 0.0, 100.0)
		var coverage_max: float = clamp(spawn.room_coverage_max_percent, coverage_min, 100.0)
		var coverage_pct: float = randf_range(coverage_min, coverage_max) / 100.0
		var target_count: int = max(1, int(ceil(room_cells.size() * coverage_pct)))
		room_cells.shuffle()
		var placed_count: int = 0
		for pos in room_cells:
			if placed_count >= target_count:
				break
			if _too_close_to_room_spinners(pos, room, spawn.room_min_spacing):
				continue
			_commit_spinner_at(spawn, pos, cells_by_type)
			placed_count += 1

func _try_place_spinner(spawn: SpinnerSpawn, cells_by_type: Dictionary) -> void:
	var base_candidates := _spinner_candidates_for_spawn(spawn, cells_by_type)
	if base_candidates.is_empty():
		return
	var distance: int = max(0, spawn.min_distance_to_other_spinner)
	while distance >= 0:
		var candidates: Array = base_candidates
		if distance > 0:
			candidates = base_candidates.filter(
				func(p): return not _too_close_to_existing_spinner(p, distance)
			)
		if not candidates.is_empty():
			var pos: Vector2i = candidates[randi() % candidates.size()]
			_commit_spinner_at(spawn, pos, cells_by_type)
			return
		distance -= 1

# Materialises a SpinnerInstance for `spawn` at `pos`. Rolls the
# instance's fixed direction + rotation count from the spawn's
# SpinnerData range using the seeded RNG, stores it on the cell + flat
# list, and removes the cell from the candidate pool so the next pass
# (or the next spawn iteration) won't re-pick it.
func _commit_spinner_at(spawn: SpinnerSpawn, pos: Vector2i, cells_by_type: Dictionary) -> void:
	var data: SpinnerData = spawn.spinner
	var rotations: int = randi_range(max(1, data.min_spins), max(data.min_spins, data.max_spins))
	var dir: int = _roll_spinner_direction(data.direction)
	var inst := SpinnerInstance.create(data, pos, dir, rotations)
	grid[pos.x][pos.y].spinner = inst
	spinners.append(inst)
	cells_by_type[classify_cell(pos)].erase(pos)

# Collapses SpinnerData.Direction.RANDOM to a concrete CLOCKWISE or
# COUNTER_CLOCKWISE via the seeded RNG. CLOCKWISE / COUNTER_CLOCKWISE
# pass through unchanged.
func _roll_spinner_direction(policy: int) -> int:
	if policy == SpinnerData.Direction.CLOCKWISE:
		return SpinnerInstance.Direction.CLOCKWISE
	if policy == SpinnerData.Direction.COUNTER_CLOCKWISE:
		return SpinnerInstance.Direction.COUNTER_CLOCKWISE
	# RANDOM (or unknown — defensive). 50/50 split.
	if randi() % 2 == 0:
		return SpinnerInstance.Direction.CLOCKWISE
	return SpinnerInstance.Direction.COUNTER_CLOCKWISE

func _spinner_candidates_for_spawn(spawn: SpinnerSpawn, cells_by_type: Dictionary) -> Array:
	var result: Array = []
	for placement_bit in [ObjectSpawn.PLACEMENT_CORRIDOR, ObjectSpawn.PLACEMENT_ROOM, ObjectSpawn.PLACEMENT_DEAD_END]:
		if not spawn.allows(placement_bit):
			continue
		for pos in cells_by_type[placement_bit]:
			# cells_by_type was filtered when built — but the in-flight
			# additions from this same pass (spinners just placed in
			# corridor / room sub-passes) are erased from it via
			# `_commit_spinner_at`, so this is enough.
			if _is_adjacent_to_spinner_cluster(pos):
				continue
			result.append(pos)
	return result

func _is_adjacent_to_spinner_cluster(pos: Vector2i) -> bool:
	if _spinner_cluster_cells.is_empty():
		return false
	for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		if _spinner_cluster_cells.has(pos + d):
			return true
	return false

func _too_close_to_existing_spinner(pos: Vector2i, min_distance: int) -> bool:
	if min_distance <= 0:
		return false
	for inst in spinners:
		if inst == null:
			continue
		var d: int = abs(pos.x - inst.cell.x) + abs(pos.y - inst.cell.y)
		if d < min_distance:
			return true
	return false

func _segment_has_spinner(segment: Array) -> bool:
	for pos in segment:
		if grid[pos.x][pos.y].spinner != null:
			return true
	return false

func _eligible_spinner_segment_cells(segment: Array) -> Array:
	var result: Array = []
	for pos in segment:
		var cell: GridCell = grid[pos.x][pos.y]
		if pos == entrance_pos or pos == exit_pos:
			continue
		if cell.object != null:
			continue
		if cell.trap != null:
			continue
		if cell.spinner != null:
			continue
		# Phase 15 Task 6 — Phase C. Teleporters placed FIRST in
		# partition mode; a spinner co-located with a warp would spin
		# the player on warp-in and stack two decals on the same cell.
		# The corridor-cluster pass needs this check independently of
		# `_classify_spinner_candidate_cells` (the scattered pass) —
		# without it, cluster placements bypass the exclusion entirely.
		if cell.teleporter != null:
			continue
		if not cell.items.is_empty():
			continue
		if _cell_holds_plate(pos):
			continue
		result.append(pos)
	return result

func _eligible_spinner_room_cells(room: Rect2i) -> Array:
	var result: Array = []
	for x in range(room.position.x, room.position.x + room.size.x):
		for y in range(room.position.y, room.position.y + room.size.y):
			if not _in_bounds(x, y):
				continue
			var cell: GridCell = grid[x][y]
			if cell.cell_type != GridCell.CellType.FLOOR:
				continue
			var pos := Vector2i(x, y)
			if pos == entrance_pos or pos == exit_pos:
				continue
			if cell.object != null:
				continue
			if cell.trap != null:
				continue
			if cell.spinner != null:
				continue
			# Phase 15 Task 6 — Phase C. Same teleporter exclusion as
			# the corridor-cluster filter above; without it, the
			# room-density pass can drop a spinner on a warp endpoint.
			if cell.teleporter != null:
				continue
			if not cell.items.is_empty():
				continue
			if _cell_holds_plate(pos):
				continue
			result.append(pos)
	return result

func _room_has_any_spinner(room: Rect2i) -> bool:
	for inst in spinners:
		if inst == null:
			continue
		if room.has_point(inst.cell):
			return true
	return false

func _too_close_to_room_spinners(pos: Vector2i, room: Rect2i, min_spacing: int) -> bool:
	if min_spacing <= 0:
		return false
	for inst in spinners:
		if inst == null:
			continue
		if not room.has_point(inst.cell):
			continue
		var d: int = abs(pos.x - inst.cell.x) + abs(pos.y - inst.cell.y)
		if d < min_spacing:
			return true
	return false

# Linear scan (small N — projectile traps cap is biome-bounded). The
# segment / room eligibility passes call this once per candidate cell,
# so an O(P) scan per check is bounded by O(cells × P).
func _cell_holds_plate(pos: Vector2i) -> bool:
	for ptrap in projectile_traps:
		if ptrap == null:
			continue
		if not ptrap.has_plate():
			continue
		if ptrap.plate_cell == pos:
			return true
	return false

# -------------------------------------------------------
# Outdoor-mode fillers (trees / rocks / bushes)
# -------------------------------------------------------
# Iterates every WALL cell inside the grid and — for each FillerSpawn
# in the biome's pool — samples a density, picks sprites uniformly
# from the spawn's pool, and pushes one `FillerInstance` per sprite
# with a sub-cell jitter offset.
#
# When `border_ring_depth > 0`, ALSO seeds a ring of cells outside
# the grid (negative coords and coords >= grid_width/height). These
# out-of-grid cells aren't real GridCells — they're virtual positions
# the renderer converts to world space the same way as in-grid cells.
# The ring exists so the playable area sits inside a thicker frame of
# trees that fades into fog instead of an abrupt edge of world.
#
# No-op for non-outdoor biomes (the `outdoor_mode` flag is checked
# up-front and short-circuits before any iteration). The pool stays
# unused on indoor biomes — designers don't need to clear it when
# toggling outdoor_mode off.
func _place_fillers() -> void:
	if not outdoor_mode:
		return
	if filler_spawns_pool.is_empty():
		return
	for spawn in filler_spawns_pool:
		if spawn == null or spawn.fillers.is_empty():
			continue
		_place_one_filler_spawn(spawn)

# How close to the cell edge the front-row bias pulls a sprite, as
# a fraction of CELL_SIZE. 0.5 = exactly on the boundary (risk of
# Z-fighting with the adjacent cell's sprites at the seam); 0.45 =
# a small margin inside the cell so adjacent-cell sprites don't
# overlap perfectly. Constant rather than per-spawn because it's a
# fix for visual seam stitching, not a design knob.
const _FILLER_FRONT_ROW_EDGE: float = 0.45

func _place_one_filler_spawn(spawn: FillerSpawn) -> void:
	var depth: int = max(0, spawn.border_ring_depth)
	var x_min: int = -depth
	var x_max: int = grid_width + depth
	var y_min: int = -depth
	var y_max: int = grid_height + depth
	for x in range(x_min, x_max):
		for y in range(y_min, y_max):
			var pos := Vector2i(x, y)
			if not _is_filler_cell(pos):
				continue
			# Direction to the average of this cell's 4-adjacent FLOOR
			# neighbours (zero if none). Cached per cell — every filler
			# in this cell shares the same bias direction.
			var floor_dir: Vector2 = _floor_neighbour_direction(pos)
			# `randi()` runs through the global RNG — same source the
			# other placers use, so a `seed(N)` ahead of `generate()`
			# makes filler placement deterministic for tests.
			var density: int = spawn.sample_density(randi())
			for _i in range(density):
				var fd: FillerData = spawn.pick_filler(randi())
				if fd == null:
					continue
				var jx: float = randf_range(-spawn.jitter_radius, spawn.jitter_radius)
				var jy: float = randf_range(-spawn.jitter_radius, spawn.jitter_radius)
				var offset := Vector2(jx, jy)
				# Lerp the random offset toward the FLOOR-adjacent
				# cell edge — front-row sprites cluster at the wall
				# line so the player can read the boundary clearly.
				# Skipped when the cell has no FLOOR neighbours
				# (interior wall / deep border ring / isolated pillar
				# with FLOOR on all 4 sides — direction sums to zero)
				# or when the spawn opted out (front_row_bias = 0).
				if spawn.front_row_bias > 0.0 and floor_dir != Vector2.ZERO:
					var biased := floor_dir * _FILLER_FRONT_ROW_EDGE
					offset = offset.lerp(biased, spawn.front_row_bias)
				var scale: float = spawn.sample_scale(randf())
				fillers.append(FillerInstance.create(fd, pos, offset, scale))

# A cell is "fillable" if it's outside the grid (always blocked — no
# GridCell at all) OR it's a WALL cell inside the grid. Floor cells
# (FLOOR / ENTRANCE / EXIT) are skipped — fillers must never block
# the player's walkable area.
func _is_filler_cell(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= grid_width or pos.y < 0 or pos.y >= grid_height:
		return true
	var cell: GridCell = grid[pos.x][pos.y]
	if cell == null:
		return true
	return cell.cell_type == GridCell.CellType.WALL

# Direction (normalized) toward the average of `pos`'s 4-adjacent
# in-grid FLOOR (/ ENTRANCE / EXIT) neighbours. Used by the filler
# placer to pull "front-row" sprites toward the walkable boundary so
# the wall line reads clearly. Zero vector when:
#   - the cell has no in-grid FLOOR neighbours (interior wall, deep
#     border-ring cell that doesn't touch the grid)
#   - the cell has FLOOR neighbours on opposite sides that cancel out
#     (single-wall pillar surrounded by floor — the direction sum is
#     zero so there's no "front" to bias toward)
func _floor_neighbour_direction(pos: Vector2i) -> Vector2:
	var dir := Vector2.ZERO
	for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var npos: Vector2i = pos + d
		if _is_in_grid_floor(npos):
			dir += Vector2(d.x, d.y)
	if dir == Vector2.ZERO:
		return Vector2.ZERO
	return dir.normalized()

func _is_in_grid_floor(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= grid_width or pos.y < 0 or pos.y >= grid_height:
		return false
	var cell: GridCell = grid[pos.x][pos.y]
	if cell == null:
		return false
	return cell.cell_type != GridCell.CellType.WALL
