class_name ProjectileTrapInstance
extends RefCounted

# Runtime placement record for one wall-mounted projectile launcher.
# Phase 8 Task 3 — Subtask C.
#
# Stored in `LevelGenerator.projectile_traps` (NOT on a `GridCell` —
# launchers live on wall FACES, not cells, like wall decorations).
#
# `cell` is the floor cell the launcher is attached TO; `wall_dir` is
# the cardinal direction from that cell pointing INTO the wall. So a
# launcher on the north wall of cell (5, 7) has cell = (5, 7) and
# wall_dir = (0, -1). The projectile then fires SOUTH (the opposite of
# wall_dir) into the corridor.
#
# **Subtask C1 scope:** placement record + `face_key` for the shared
# wall-face registry + `fire_direction` for the placement validator.
# Firing logic (timer / projectile spawn) lands in C2; pressure-plate
# linkage lands in C4.

const DIR_NORTH := Vector2i(0, -1)
const DIR_SOUTH := Vector2i(0, 1)
const DIR_WEST  := Vector2i(-1, 0)
const DIR_EAST  := Vector2i(1, 0)

# Sentinel for "no plate" — populated by Subtask C4 for PRESSURE_PLATE
# traps, left as Vector2i(-1, -1) for TIMED traps.
const NO_PLATE := Vector2i(-1, -1)

var data: ProjectileTrapData
var cell: Vector2i
var wall_dir: Vector2i
# PRESSURE_PLATE only. NO_PLATE for TIMED traps. Wired in Subtask C4.
var plate_cell: Vector2i = NO_PLATE
# TIMED only — phase-shift offset (0..timed_period). Two values feed
# into this:
#   - `data.timed_initial_offset` — designer-chosen base shift,
#     same for every instance of this variant
#   - the placer's per-instance random component, applied AFTER
#     `create()` returns, so multiple TIMED launchers in the same
#     area don't fire in lockstep
# `create()` initialises `timed_offset` from the data field only —
# random desync is added by `LevelGenerator` so test code building
# instances directly stays deterministic.
var timed_offset: float = 0.0
# Time accumulated within the current TIMED cycle. Initialised to
# `timed_offset` at create() so the first launch fires at
# `timed_period - timed_offset` seconds. Reset modulo period on each
# rollover.
var timer: float = 0.0
# PRESSURE_PLATE only. Set true when a projectile is in flight from
# this launcher; cleared on its IMPACT. Used in C4 to block
# re-triggering while the plate's projectile is still flying.
var in_flight: bool = false

static func create(p_data: ProjectileTrapData, p_cell: Vector2i, p_wall_dir: Vector2i) -> ProjectileTrapInstance:
	var inst := ProjectileTrapInstance.new()
	inst.data = p_data
	inst.cell = p_cell
	inst.wall_dir = p_wall_dir
	if p_data != null and p_data.is_timed():
		# Seed the timer with the data's base offset. The placer adds
		# a per-instance random component on top so simultaneous traps
		# desync — see `LevelGenerator._place_corridor_projectile_traps`.
		inst.timed_offset = p_data.timed_initial_offset
		inst.timer = p_data.timed_initial_offset
	return inst

# Advance the launcher's internal clock by `delta` seconds and return
# a new `ProjectileInstance` if it should fire this tick, else null.
#
# Phase 8 Task 3 — Subtask C2 wires TIMED firing only. PRESSURE_PLATE
# (Subtask C4) will spawn projectiles via `_on_player_entered_cell()`
# instead of `tick()` (the player's step is the trigger event).
#
# Pure state machine — no node access, no audio. Game.gd wires audio
# (launch_sound) and visual (DungeonView.spawn_projectile_visual)
# when this returns a non-null instance.
func tick(delta: float) -> ProjectileInstance:
	if data == null or delta <= 0.0:
		return null
	if not data.is_timed():
		return null
	timer += delta
	var period: float = max(0.001, data.timed_period)
	if timer < period:
		return null
	# Rollover. `fposmod` keeps the remainder in `[0, period)` even
	# when delta is huge (e.g. after a long pause).
	timer = fposmod(timer, period)
	return _spawn_projectile()

# Spawn one projectile from this launcher's mouth in fire_direction.
# Public so PRESSURE_PLATE traps (C4) can call it directly when the
# player steps on the plate, bypassing the TIMED clock.
func _spawn_projectile() -> ProjectileInstance:
	if data == null:
		return null
	var fire_dir: Vector2i = fire_direction()
	# Start position: the wall face on the inside of the host cell.
	# Cell centre + half a cell toward the wall = the wall surface
	# the launcher is mounted on. The projectile then travels in
	# fire_dir into the corridor.
	var start_pos := Vector2(float(cell.x) + 0.5, float(cell.y) + 0.5) \
		+ Vector2(float(wall_dir.x), float(wall_dir.y)) * 0.5
	return ProjectileInstance.create(data, start_pos, fire_dir)

# Cardinal direction the projectile flies. Always opposite the wall
# the launcher is mounted on (i.e., away from the wall, into the
# corridor or room). Used by both placement (validation) and rendering
# (Y-rotation of the launcher sprite + future projectile spawn).
func fire_direction() -> Vector2i:
	return -wall_dir

# Canonical key — uniquely identifies the wall face this launcher
# occupies. Format matches `WallDecorationInstance.face_key` so the
# same `_wall_faces_used` dictionary on `LevelGenerator` blocks both
# decorations and launchers from claiming the same face.
static func face_key(p_cell: Vector2i, p_wall_dir: Vector2i) -> String:
	return "%d,%d|%d,%d" % [p_cell.x, p_cell.y, p_wall_dir.x, p_wall_dir.y]

func get_face_key() -> String:
	return face_key(cell, wall_dir)

# True iff this launcher has a linked pressure plate (Subtask C4).
# In C1 always false — `plate_cell` is left at NO_PLATE.
func has_plate() -> bool:
	return plate_cell != NO_PLATE
