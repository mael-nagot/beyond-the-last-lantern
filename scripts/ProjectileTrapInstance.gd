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
# TIMED only — phase-shift offset (0..timed_break_duration). Two
# values feed into this:
#   - `data.timed_initial_offset` — designer-chosen base shift,
#     same for every instance of this variant
#   - the placer's per-instance random component, applied AFTER
#     `create()` returns, so multiple TIMED launchers in the same
#     area don't fire in lockstep
# `create()` initialises `timed_offset` from the data field only —
# random desync is added by `LevelGenerator` so test code building
# instances directly stays deterministic.
var timed_offset: float = 0.0
# Time accumulated within the current TIMED break. The timer is
# paused while `in_flight` is true (a projectile is still alive),
# so this only counts the empty-corridor break. Initialised to
# `timed_offset` at create() so the first launch fires at
# `timed_break_duration - timed_offset` seconds after spawn. Reset
# modulo break duration on each rollover.
var timer: float = 0.0
# Set true when a projectile is in flight from this launcher;
# cleared on its IMPACT by Game.gd via the projectile's `launcher`
# back-reference. Used by:
#   - PRESSURE_PLATE: gates re-triggering while the plate's
#     projectile is still flying (one projectile per plate at a time).
#   - TIMED: pauses `tick()` so `timed_break_duration` counts only
#     empty-corridor time, not flight time. Without this, the launch
#     period would silently include the flight (a 4s period with a
#     1.25s flight would feel like 2.75s of empty corridor).
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
# TIMED traps pause the timer while a projectile is in flight (the
# `in_flight` flag is cleared by Game.gd in the projectile's IMPACT
# handler). Effect: `timed_break_duration` measures only the empty-
# corridor break between impact and next launch, not launch-to-launch
# period. This decouples the designer's "break feel" tuning from the
# variant's speed and the corridor's path length.
#
# PRESSURE_PLATE traps spawn projectiles via
# `_check_pressure_plate_trigger` in Game.gd instead — the player's
# step is the trigger, not the timer.
#
# Pure state machine — no node access, no audio. Game.gd wires audio
# (launch_sound) and visual (DungeonView.spawn_projectile_visual)
# when this returns a non-null instance.
func tick(delta: float) -> ProjectileInstance:
	if data == null or delta <= 0.0:
		return null
	if not data.is_timed():
		return null
	# Pause the timer while the previous projectile is still alive —
	# `timed_break_duration` counts only the empty-corridor break, not
	# the flight time.
	if in_flight:
		return null
	timer += delta
	var break_duration: float = max(0.001, data.timed_break_duration)
	if timer < break_duration:
		return null
	# Rollover. `fposmod` keeps the remainder in `[0, break_duration)`
	# even when delta is huge (e.g. after a long pause).
	timer = fposmod(timer, break_duration)
	return spawn_projectile()

# Spawn one projectile from this launcher's mouth in fire_direction.
# Public so PRESSURE_PLATE traps (C4) can call it directly when the
# player steps on the plate, bypassing the TIMED clock.
#
# **In-flight lock** — both TIMED and PRESSURE_PLATE traps set
# `in_flight = true` here on success. Game.gd clears it in the
# projectile's IMPACT handler (via the `launcher` back-reference on
# the spawned `ProjectileInstance`). The lock means:
#   - PRESSURE_PLATE: the plate can't re-trigger while the previous
#     projectile is still alive (one projectile per plate at a time).
#   - TIMED: `tick()` pauses while the lock is held, so the break
#     duration counts only empty-corridor time, not flight time.
# Callers (the TIMED `tick()` path; Game.gd for PRESSURE_PLATE)
# already guard against re-spawning while in_flight, so this method
# never spawns a second projectile from a launcher with one alive.
func spawn_projectile() -> ProjectileInstance:
	if data == null:
		return null
	if in_flight:
		return null
	var fire_dir: Vector2i = fire_direction()
	# Start position: the wall face on the inside of the host cell.
	# Cell centre + half a cell toward the wall = the wall surface
	# the launcher is mounted on. The projectile then travels in
	# fire_dir into the corridor.
	var start_pos := Vector2(float(cell.x) + 0.5, float(cell.y) + 0.5) \
		+ Vector2(float(wall_dir.x), float(wall_dir.y)) * 0.5
	var inst := ProjectileInstance.create(data, start_pos, fire_dir)
	inst.launcher = self
	in_flight = true
	return inst

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
