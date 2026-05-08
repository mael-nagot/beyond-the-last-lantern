class_name TrapInstance
extends RefCounted

# Runtime state for a single placed trap. Phase 8 Task 3.
#
# Lives on `GridCell.trap` (separate slot from `GridCell.object` —
# placement enforces "trap OR object, not both" so they never share a
# tile). Stored on the cell so the renderer can iterate the grid the
# same way it does for objects, and Game.gd can resolve "the trap I'm
# standing on" with O(1) cell lookup.
#
# Game.gd owns the per-frame tick that advances `timer` and flips
# `state` according to `data.trigger`. State transitions are
# observable by the caller via `tick(delta)` returning a non-NONE
# event so the renderer can swap visuals and audio without the
# instance reaching back into the scene.

enum State {
	# Spikes hidden (only the floor holes are visible).
	RETRACTED,
	# Spikes extended above the floor — damage applies on transition
	# in and on step entry while in this state.
	EXTENDED,
}

# Returned by tick() so Game / DungeonView can react without each
# tick caller re-deriving "did the visual just change". Saves a
# rebuild-everything pass each frame.
enum Event {
	NONE,
	# Just transitioned RETRACTED → EXTENDED this tick.
	ACTIVATED,
	# Just transitioned EXTENDED → RETRACTED this tick.
	DEACTIVATED,
}

var data: TrapData
var state: int = State.RETRACTED
# Time accumulated in the CURRENT state (or in cooldown for STEP).
# Reset to 0 on each state transition so the state machine reads
# linearly (no carry-over arithmetic).
var timer: float = 0.0
# STEP only: true while the post-activation lockout is active. The
# cell can be entered without re-triggering during this window.
var on_cooldown: bool = false
# TIMED only: latched to true the first time damage is applied during
# the current EXTENDED phase, so a player who walks onto an already-
# extended cell takes damage once but standing-through-the-cycle (or
# walking off and back on) doesn't double-charge. Reset on every
# EXTENDED → RETRACTED transition.
#
# Game.gd is responsible for SETTING this true after applying damage
# (in both the ACTIVATED-with-player-on-cell case and the
# walk-onto-already-extended case). The state machine RESETS it on
# retraction so the trap stays a pure data type — Game.gd just owns
# the "did I damage this cycle yet" decision.
var damage_applied_this_extension: bool = false
# Cell this trap occupies. Set by LevelGenerator at placement time —
# the renderer uses it to anchor the floor decal and per-spike
# billboards.
var cell: Vector2i = Vector2i.ZERO

static func create(p_data: TrapData, p_cell: Vector2i) -> TrapInstance:
	var inst := TrapInstance.new()
	inst.data = p_data
	inst.cell = p_cell
	# TIMED traps with a non-zero initial_offset start mid-cycle so
	# multiple traps don't pop in sync. Negative offsets are clamped
	# to 0 to keep the state machine well-defined.
	if p_data != null and p_data.is_timed():
		inst.timer = max(0.0, p_data.timed_initial_offset)
		# If the offset exceeds the down phase, fast-forward into the
		# extended phase so phase 0 isn't always RETRACTED.
		var down: float = max(0.0, p_data.timed_down_duration)
		if inst.timer >= down and down > 0.0:
			inst.state = State.EXTENDED
			inst.timer = inst.timer - down
	return inst

# Player just stepped onto this trap's cell. STEP traps activate (if
# not on cooldown) and apply damage; TIMED traps don't react to step
# entries — the player only takes damage from a TIMED trap on its
# RETRACTED→EXTENDED transition while standing on the cell.
#
# Returns true iff damage should be applied to the party as a result
# of this step. Caller is responsible for the actual damage call +
# feedback (shake / flash / pain sound) so the trap stays a pure
# state machine.
func on_player_step() -> bool:
	if data == null:
		return false
	if not data.is_step():
		return false
	if on_cooldown:
		return false
	if state == State.EXTENDED:
		# Already extended (and not on cooldown — shouldn't normally
		# happen, but guards against re-entrancy / state bugs). No
		# new damage event.
		return false
	state = State.EXTENDED
	timer = 0.0
	return data.damage > 0

# Advance the state machine by `delta` seconds. Returns the
# observable event (NONE / ACTIVATED / DEACTIVATED) so the caller
# can sync visuals + audio without re-inspecting the trap.
#
# This is a pure state transition — no node access, no audio,
# nothing observable beyond `state`, `timer`, and `on_cooldown`.
# Tests can drive the machine deterministically.
func tick(delta: float) -> int:
	if data == null or delta <= 0.0:
		return Event.NONE
	timer += delta
	if data.is_step():
		return _tick_step()
	if data.is_timed():
		return _tick_timed()
	return Event.NONE

func _tick_step() -> int:
	if state == State.EXTENDED:
		if timer >= max(0.0, data.step_activation_duration):
			state = State.RETRACTED
			timer = 0.0
			# Cooldown begins immediately on retraction. With
			# step_cooldown_duration <= 0 we set on_cooldown anyway
			# so the next tick clears it via the same path; saves a
			# branch.
			on_cooldown = max(0.0, data.step_cooldown_duration) > 0.0
			return Event.DEACTIVATED
		return Event.NONE
	# RETRACTED + on_cooldown — wait out the lockout.
	if on_cooldown:
		if timer >= max(0.0, data.step_cooldown_duration):
			on_cooldown = false
			timer = 0.0
		return Event.NONE
	# RETRACTED, no cooldown — idle, nothing to do until a step.
	return Event.NONE

func _tick_timed() -> int:
	if state == State.RETRACTED:
		if timer >= max(0.0, data.timed_down_duration):
			state = State.EXTENDED
			timer = 0.0
			# Fresh extension — clear the latch so any player on (or
			# walking onto) the cell during this cycle takes damage
			# once. Game.gd sets it back to true after applying damage.
			damage_applied_this_extension = false
			return Event.ACTIVATED
		return Event.NONE
	# EXTENDED
	if timer >= max(0.0, data.timed_up_duration):
		state = State.RETRACTED
		timer = 0.0
		return Event.DEACTIVATED
	return Event.NONE

func is_extended() -> bool:
	return state == State.EXTENDED

# True iff a player standing on this cell would currently take
# damage from a presence check (used by TIMED traps on the
# ACTIVATED event). STEP traps deliver damage via on_player_step,
# so this returns false for them — Game.gd never queries them via
# this path.
func damages_on_presence() -> bool:
	return data != null and data.is_timed() and state == State.EXTENDED
