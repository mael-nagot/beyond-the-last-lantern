class_name ProjectileInstance
extends RefCounted

# A projectile in flight. Phase 8 Task 3 — Subtask C2.
#
# Spawned by `ProjectileTrapInstance.tick()` when the launcher's
# trigger fires (TIMED rollover, or PRESSURE_PLATE step in C4). Lives
# in `LevelGenerator.projectiles` (flat list) so `Game._process()` can
# advance every active projectile each frame without scanning the
# grid.
#
# Pure state machine — no node access, no audio, nothing observable
# beyond `cell_pos`, `direction`, and the event returned by `tick()`.
# DungeonView reads `cell_pos` each frame to position the sprite;
# Game reacts to IMPACT events (despawn visual + impact sound + remove
# from list).
#
# **Coordinate convention:** `cell_pos` is in continuous CELL units
# (matches `LevelGenerator.grid` indexing). `cell_pos = Vector2(5.5,
# 7.0)` means horizontal centre of column 5, exactly on the boundary
# between rows 6 and 7. Cell `(x, y)` covers the half-open rect
# `[x, x+1) × [y, y+1)`. DungeonView multiplies by `CELL_SIZE` to get
# world-space.
#
# Wall collision walks integer cells from current to new position one
# cell at a time so a high-speed projectile (where one tick crosses
# multiple cells) still impacts the FIRST wall it meets, not whichever
# cell the new position happens to land in.

enum Event {
	NONE,
	# Just hit a wall (or the grid edge) this tick. `cell_pos` is
	# clamped to the wall's near face so the visible projectile sits
	# on the wall, not inside it. Caller should despawn this instance.
	IMPACT,
}

# Mirrors `ProjectileTrapData.ProjectileView` so callers don't have
# to know the data resource exists. Used by the static sprite-picker
# `view_for_camera()` below — DungeonView calls it each frame to swap
# the projectile's texture as the player rotates.
enum CameraView { FRONT, BACK, LEFT, RIGHT }

var data: ProjectileTrapData
# Continuous float position in CELL units. See coordinate convention
# in the file header.
var cell_pos: Vector2 = Vector2.ZERO
# Cardinal flight direction. One of (1,0) / (-1,0) / (0,1) / (0,-1).
var direction: Vector2i = Vector2i.ZERO
# Latched true the first frame the projectile crosses the player's
# cell so it can't damage twice on the same flight. Wrapper
# `consume_damage_for_player` is the canonical setter.
var damage_latch: bool = false
# Back-reference to the launcher that fired this projectile. Set by
# `ProjectileTrapInstance.spawn_projectile`. Phase 8 Task 3 — Subtask
# C4 reads this on IMPACT to clear the launcher's `in_flight` lock so
# a PRESSURE_PLATE trap can fire again after its projectile dies.
# TIMED traps don't set / read in_flight but we set the back-ref
# anyway so the same Game.gd impact-handling code path covers both.
# Strong ref is safe — projectiles are released via
# `LevelGenerator.projectiles.clear()` in `generate()` BEFORE
# launchers are released via `projectile_traps.clear()`, so no cycle.
var launcher: ProjectileTrapInstance = null

static func create(p_data: ProjectileTrapData, p_cell_pos: Vector2, p_direction: Vector2i) -> ProjectileInstance:
	var inst := ProjectileInstance.new()
	inst.data = p_data
	inst.cell_pos = p_cell_pos
	inst.direction = p_direction
	return inst

# Advance the projectile by `delta` seconds. Returns NONE when the
# projectile is still in flight, IMPACT when it has hit a wall (or
# the grid edge) this tick. On IMPACT, `cell_pos` is clamped to the
# wall's near face — the projectile visibly sits AT the wall, never
# inside it.
#
# Walks integer cells one at a time along `direction` from the
# current cell to the cell `cell_pos + direction * speed * delta`
# would land in, so a high-speed projectile that crosses multiple
# cells in one tick still impacts the FIRST wall it meets rather
# than skipping past it.
#
# `grid` is `LevelGenerator.grid` (Array of Array of GridCell). Read
# only — passing it in keeps this script pure (no node lookups, no
# autoload calls) and lets unit tests construct a fake grid in pure
# code.
func tick(delta: float, grid: Array, gw: int, gh: int) -> int:
	if data == null or delta <= 0.0:
		return Event.NONE
	if direction == Vector2i.ZERO:
		# Stationary projectile — shouldn't happen in practice; bail
		# defensively so the caller can despawn the malformed instance.
		return Event.IMPACT
	var distance: float = max(0.0, data.speed_cells_per_second) * delta
	if distance <= 0.0:
		return Event.NONE
	var dir_v := Vector2(float(direction.x), float(direction.y))
	var new_pos: Vector2 = cell_pos + dir_v * distance
	var current_cell := Vector2i(int(floor(cell_pos.x)), int(floor(cell_pos.y)))
	var target_cell := Vector2i(int(floor(new_pos.x)), int(floor(new_pos.y)))
	# Walk one integer cell at a time from current → target along
	# `direction`. For cardinal motion, this is a straight line.
	while current_cell != target_cell:
		current_cell += direction
		if current_cell.x < 0 or current_cell.x >= gw or current_cell.y < 0 or current_cell.y >= gh:
			# Off the grid before hitting a wall — shouldn't happen on
			# a normal level (the grid border is wall), but guard
			# defensively. Treat as IMPACT so the caller despawns.
			cell_pos = _clamped_to_wall_face(current_cell)
			return Event.IMPACT
		var c: GridCell = grid[current_cell.x][current_cell.y]
		if c.cell_type == GridCell.CellType.WALL:
			# Clamp the visible position to the wall's near face — the
			# face on the side the projectile entered from — so the
			# sprite doesn't sink into the wall mesh.
			cell_pos = _clamped_to_wall_face(current_cell)
			return Event.IMPACT
	cell_pos = new_pos
	return Event.NONE

# Position on the wall cell's near face — the face on the side the
# projectile entered from. For direction `(1, 0)` (east) the wall's
# near face is its WEST edge (= `wall_cell.x`); for direction `(-1,
# 0)` it's the EAST edge (= `wall_cell.x + 1`). The other axis stays
# whatever it was when the projectile entered (cardinal motion only
# changes one axis).
func _clamped_to_wall_face(wall_cell: Vector2i) -> Vector2:
	var p := cell_pos
	if direction.x > 0:
		p.x = float(wall_cell.x)
	elif direction.x < 0:
		p.x = float(wall_cell.x + 1)
	if direction.y > 0:
		p.y = float(wall_cell.y)
	elif direction.y < 0:
		p.y = float(wall_cell.y + 1)
	return p

# Returns true iff this projectile should apply damage to a player at
# `player_cell` THIS frame. Sets `damage_latch = true` on success so a
# follow-up call (next frame, or another caller in the same frame)
# returns false — a single projectile damages once per flight, full
# stop. Phase 8 Task 3 — Subtask C3.
#
# Game.gd polls this each frame after `tick()`, and when it returns
# true calls `_apply_party_damage(data.damage)` (which handles all 3
# party members + camera shake + screen flash + pain sound — same
# pipeline spike traps use, so the feel is consistent).
#
# Pure: caller never has to remember to set the latch — that's the
# whole point of the wrapper. Returning a bool keeps the call site a
# single `if`. Variants with `damage <= 0` (harmless prop projectiles)
# always return false, so the latch never trips and follow-up logic
# in C5/C6 can reuse it without paying for those variants.
func consume_damage_for_player(player_cell: Vector2i) -> bool:
	if data == null or damage_latch:
		return false
	if data.damage <= 0:
		return false
	var pc := Vector2i(int(floor(cell_pos.x)), int(floor(cell_pos.y)))
	if pc != player_cell:
		return false
	damage_latch = true
	return true

# Picks the camera-relative view of a projectile flying in `direction`
# given a camera looking in `camera_forward_xz` (Vector2 of the
# camera's forward direction projected onto the horizontal XZ plane,
# in world units — DungeonView passes the camera basis -Z component).
#
# In this dungeon the camera always faces a cardinal direction, so
# `camera_forward_xz` is always one of (1,0) / (-1,0) / (0,1) / (0,-1)
# in practice, and `dot(camera_forward, fire)` is exactly -1, 0, or
# 1. The 0.5 thresholds are belt-and-braces against floating-point
# drift in case the camera is mid-rotation tween when this is called.
#
# Static + pure so unit tests can drive the matrix without a scene
# tree.
static func view_for_camera(p_direction: Vector2i, camera_forward_xz: Vector2) -> int:
	var fire := Vector2(float(p_direction.x), float(p_direction.y))
	if fire.length_squared() < 0.0001:
		return CameraView.FRONT
	if camera_forward_xz.length_squared() < 0.0001:
		return CameraView.FRONT
	var cf: Vector2 = camera_forward_xz.normalized()
	var fw: Vector2 = fire.normalized()
	var dot: float = cf.dot(fw)
	# Camera looks roughly OPPOSITE the projectile → camera sees its
	# FRONT (the player faces the incoming projectile).
	if dot <= -0.5:
		return CameraView.FRONT
	# Camera looks roughly the SAME direction the projectile is
	# travelling → camera sees its BACK (the player chases it).
	if dot >= 0.5:
		return CameraView.BACK
	# Perpendicular case. 2D pseudo-cross product picks the side:
	# > 0 → camera sees the projectile's RIGHT side (right from the
	#       projectile's POV, looking in fire direction)
	# < 0 → LEFT side
	# Worked out by example for fire = (1, 0) east:
	#   - cam_forward = (0, -1) [camera south of arrow, looking north]:
	#     cross = 0*0 - (-1)*1 = +1 → RIGHT (matches: camera at south
	#     sees the south side of the arrow, which is its right side
	#     from the arrow's east-facing POV)
	#   - cam_forward = (0,  1) [camera north, looking south]:
	#     cross = 0*0 - 1*1 = -1 → LEFT (camera at north sees the
	#     north side, the arrow's left side)
	var cross: float = cf.x * fw.y - cf.y * fw.x
	if cross > 0.0:
		return CameraView.RIGHT
	return CameraView.LEFT
