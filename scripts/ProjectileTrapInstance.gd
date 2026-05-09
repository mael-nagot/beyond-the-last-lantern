class_name ProjectileTrapInstance
extends RefCounted

# Runtime state for one wall-mounted projectile trap. Phase 8 Task 3
# follow-up.
#
# Owns the launcher position (wall face), optional pressure plate
# position, fire direction, state machine, and the in-flight Projectile.
# Game.gd calls `tick()` each frame with a wall-check callable and the
# player's cell. The instance manages the full lifecycle: countdown →
# launch → flight → wall-hit → cooldown → re-arm.
#
# Events are returned as a bitmask so the caller can react to
# simultaneous occurrences (e.g. player-hit AND wall-impact on the same
# frame when the player stands next to a wall).

const EVENT_NONE       := 0
const EVENT_LAUNCHED   := 1
const EVENT_PLAYER_HIT := 2
const EVENT_IMPACT     := 4

enum State {
	# Waiting to fire. TIMED: counting toward timed_interval.
	# PRESSURE_PLATE: waiting for on_plate_stepped() call.
	IDLE,
	# Projectile in flight. Advances each tick until wall hit.
	FIRING,
	# Brief pause after wall hit before re-arming (optional).
	COOLDOWN,
}

var data: ProjectileTrapData
# The floor cell the launcher is attached to. The launcher sprite
# renders on the wall face of this cell in the `wall_dir` direction.
var launcher_cell: Vector2i = Vector2i.ZERO
# Cardinal direction pointing FROM launcher_cell INTO the wall where
# the launcher is mounted.
var wall_dir: Vector2i = Vector2i.ZERO
# Direction the projectile travels (opposite of wall_dir — into the
# corridor / room).
var fire_direction: Vector2i = Vector2i.ZERO
# For PRESSURE_PLATE trigger: the floor cell with the pressure plate.
# Vector2i(-1, -1) when the trigger is TIMED (no plate).
var plate_cell: Vector2i = Vector2i(-1, -1)

var state: int = State.IDLE
var timer: float = 0.0
var active_projectile: Projectile = null


static func create(
	p_data: ProjectileTrapData,
	p_launcher_cell: Vector2i,
	p_wall_dir: Vector2i,
	p_plate_cell: Vector2i = Vector2i(-1, -1)
) -> ProjectileTrapInstance:
	var inst := ProjectileTrapInstance.new()
	inst.data = p_data
	inst.launcher_cell = p_launcher_cell
	inst.wall_dir = p_wall_dir
	inst.fire_direction = -p_wall_dir
	inst.plate_cell = p_plate_cell
	if p_data != null and p_data.is_timed():
		inst.timer = max(0.0, p_data.timed_initial_offset)
	return inst


# Called by Game.gd when the player steps on this trap's plate_cell.
# Returns true if a projectile was launched (caller should play
# plate_sound and spawn the launch visual). Returns false if the trap
# isn't a pressure plate or if a projectile is already in flight.
func on_plate_stepped() -> bool:
	if data == null or not data.is_pressure_plate():
		return false
	if state != State.IDLE:
		return false
	_fire_projectile()
	return true


# Advance the state machine. `is_passable` takes a Vector2i and
# returns true if that cell can be entered by the projectile (false
# for wall cells, out-of-bounds, etc.). `player_cell` is the player's
# current grid position for hit detection.
#
# Returns a bitmask of EVENT_* constants.
func tick(delta: float, is_passable: Callable, player_cell: Vector2i) -> int:
	if data == null or delta <= 0.0:
		return EVENT_NONE

	match state:
		State.IDLE:
			return _tick_idle(delta)
		State.FIRING:
			return _tick_firing(delta, is_passable, player_cell)
		State.COOLDOWN:
			return _tick_cooldown(delta)
	return EVENT_NONE


func has_active_projectile() -> bool:
	return active_projectile != null


func is_idle() -> bool:
	return state == State.IDLE


# --- internals ---

func _tick_idle(delta: float) -> int:
	if not data.is_timed():
		return EVENT_NONE
	timer += delta
	if timer >= max(0.01, data.timed_interval):
		_fire_projectile()
		return EVENT_LAUNCHED
	return EVENT_NONE


func _tick_firing(delta: float, is_passable: Callable, player_cell: Vector2i) -> int:
	if active_projectile == null:
		state = State.IDLE
		timer = 0.0
		return EVENT_NONE

	active_projectile.tick(delta)
	var event := EVENT_NONE

	var cells := active_projectile.cells_entered_this_tick()
	for cell in cells:
		if not is_passable.call(cell):
			event |= EVENT_IMPACT
			active_projectile = null
			_enter_cooldown_or_idle()
			return event
		if cell == player_cell and not active_projectile.has_hit_player:
			active_projectile.has_hit_player = true
			event |= EVENT_PLAYER_HIT

	# Also check the current cell when no transition happened this
	# tick (projectile still within the same cell as last frame).
	if cells.is_empty() and active_projectile != null:
		var current_cell := active_projectile.get_cell()
		if not is_passable.call(current_cell):
			event |= EVENT_IMPACT
			active_projectile = null
			_enter_cooldown_or_idle()
			return event
		if current_cell == player_cell and not active_projectile.has_hit_player:
			active_projectile.has_hit_player = true
			event |= EVENT_PLAYER_HIT

	return event


func _tick_cooldown(delta: float) -> int:
	timer += delta
	if timer >= max(0.0, data.cooldown_after_impact):
		state = State.IDLE
		timer = 0.0
	return EVENT_NONE


func _fire_projectile() -> void:
	# Start projectile at the wall face, offset 0.4 cells from cell
	# centre toward the wall so it visually emerges from the launcher.
	var start_pos := Vector2(launcher_cell) + Vector2(wall_dir) * 0.4
	active_projectile = Projectile.create(start_pos, fire_direction, data.projectile_speed)
	state = State.FIRING
	timer = 0.0


func _enter_cooldown_or_idle() -> void:
	if data.cooldown_after_impact > 0.0:
		state = State.COOLDOWN
		timer = 0.0
	else:
		state = State.IDLE
		timer = 0.0
