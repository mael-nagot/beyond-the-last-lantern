extends GutTest

func _make_step_data(damage: int = 5, activation: float = 0.5, cooldown: float = 1.5) -> TrapData:
	var data := TrapData.new()
	data.trigger = TrapData.Trigger.STEP
	data.damage = damage
	data.step_activation_duration = activation
	data.step_cooldown_duration = cooldown
	return data

func _make_timed_data(damage: int = 5, up: float = 1.0, down: float = 2.0, offset: float = 0.0) -> TrapData:
	var data := TrapData.new()
	data.trigger = TrapData.Trigger.TIMED
	data.damage = damage
	data.timed_up_duration = up
	data.timed_down_duration = down
	data.timed_initial_offset = offset
	return data

func test_create_starts_retracted_for_step() -> void:
	var inst := TrapInstance.create(_make_step_data(), Vector2i(3, 4))
	assert_eq(inst.state, TrapInstance.State.RETRACTED)
	assert_eq(inst.cell, Vector2i(3, 4))
	assert_eq(inst.timer, 0.0)
	assert_false(inst.on_cooldown)
	assert_false(inst.damage_applied_this_extension)

func test_create_timed_with_zero_offset_starts_retracted() -> void:
	var inst := TrapInstance.create(_make_timed_data(), Vector2i.ZERO)
	assert_eq(inst.state, TrapInstance.State.RETRACTED)
	assert_eq(inst.timer, 0.0)

func test_create_timed_with_offset_inside_down_phase_keeps_retracted_with_advanced_timer() -> void:
	# down=2.0; offset=0.7 → still retracted, timer = 0.7
	var inst := TrapInstance.create(_make_timed_data(5, 1.0, 2.0, 0.7), Vector2i.ZERO)
	assert_eq(inst.state, TrapInstance.State.RETRACTED)
	assert_almost_eq(inst.timer, 0.7, 0.0001)

func test_create_timed_with_offset_past_down_phase_starts_extended() -> void:
	# down=2.0; offset=2.5 → 0.5 into the up phase
	var inst := TrapInstance.create(_make_timed_data(5, 1.0, 2.0, 2.5), Vector2i.ZERO)
	assert_eq(inst.state, TrapInstance.State.EXTENDED)
	assert_almost_eq(inst.timer, 0.5, 0.0001)

func test_step_on_player_step_extends_and_returns_true_when_damage_positive() -> void:
	var inst := TrapInstance.create(_make_step_data(10), Vector2i.ZERO)
	var should_damage: bool = inst.on_player_step()
	assert_true(should_damage)
	assert_eq(inst.state, TrapInstance.State.EXTENDED)
	assert_eq(inst.timer, 0.0)

func test_step_on_player_step_returns_false_when_damage_zero() -> void:
	var inst := TrapInstance.create(_make_step_data(0), Vector2i.ZERO)
	var should_damage: bool = inst.on_player_step()
	assert_false(should_damage)
	# State still flipped — visual should still update.
	assert_eq(inst.state, TrapInstance.State.EXTENDED)

func test_step_on_cooldown_blocks_re_trigger() -> void:
	var inst := TrapInstance.create(_make_step_data(10), Vector2i.ZERO)
	inst.on_player_step()
	# Activation duration elapses → retraction → cooldown begins.
	inst.tick(0.5)
	assert_eq(inst.state, TrapInstance.State.RETRACTED)
	assert_true(inst.on_cooldown)
	# A second step during cooldown is a no-op.
	var should_damage: bool = inst.on_player_step()
	assert_false(should_damage)
	assert_eq(inst.state, TrapInstance.State.RETRACTED)

func test_step_cooldown_clears_after_full_duration() -> void:
	var inst := TrapInstance.create(_make_step_data(10, 0.5, 1.0), Vector2i.ZERO)
	inst.on_player_step()
	inst.tick(0.5)  # retracts → cooldown
	assert_true(inst.on_cooldown)
	inst.tick(1.0)  # cooldown expires
	assert_false(inst.on_cooldown)
	# Now it can re-trigger.
	var should_damage: bool = inst.on_player_step()
	assert_true(should_damage)

func test_step_zero_cooldown_clears_immediately_on_next_tick() -> void:
	var inst := TrapInstance.create(_make_step_data(10, 0.5, 0.0), Vector2i.ZERO)
	inst.on_player_step()
	inst.tick(0.5)  # retracts; cooldown set false because duration = 0
	assert_eq(inst.state, TrapInstance.State.RETRACTED)
	assert_false(inst.on_cooldown)

func test_step_tick_returns_deactivated_event_on_retraction() -> void:
	var inst := TrapInstance.create(_make_step_data(10), Vector2i.ZERO)
	inst.on_player_step()
	var event: int = inst.tick(0.5)
	assert_eq(event, TrapInstance.Event.DEACTIVATED)

func test_timed_tick_alternates_states_with_correct_events() -> void:
	var inst := TrapInstance.create(_make_timed_data(5, 1.0, 2.0), Vector2i.ZERO)
	# Down phase: 2.0 seconds. After 1.0 still retracted.
	assert_eq(inst.tick(1.0), TrapInstance.Event.NONE)
	assert_eq(inst.state, TrapInstance.State.RETRACTED)
	# After another 1.0 the down phase elapses → ACTIVATED.
	assert_eq(inst.tick(1.0), TrapInstance.Event.ACTIVATED)
	assert_eq(inst.state, TrapInstance.State.EXTENDED)
	# Up phase: 1.0 second. After full duration → DEACTIVATED.
	assert_eq(inst.tick(1.0), TrapInstance.Event.DEACTIVATED)
	assert_eq(inst.state, TrapInstance.State.RETRACTED)

func test_timed_on_player_step_returns_false() -> void:
	# Timed traps don't react to step events.
	var inst := TrapInstance.create(_make_timed_data(10), Vector2i.ZERO)
	var should_damage: bool = inst.on_player_step()
	assert_false(should_damage)
	assert_eq(inst.state, TrapInstance.State.RETRACTED)

func test_is_extended_reflects_state() -> void:
	var inst := TrapInstance.create(_make_step_data(), Vector2i.ZERO)
	assert_false(inst.is_extended())
	inst.on_player_step()
	assert_true(inst.is_extended())

func test_damages_on_presence_only_when_timed_and_extended() -> void:
	# Step trap → never (damage flows through on_player_step).
	var step_inst := TrapInstance.create(_make_step_data(), Vector2i.ZERO)
	step_inst.on_player_step()
	assert_false(step_inst.damages_on_presence())
	# Timed trap, retracted → no damage.
	var timed_inst := TrapInstance.create(_make_timed_data(), Vector2i.ZERO)
	assert_false(timed_inst.damages_on_presence())
	# Timed trap, extended → damage.
	timed_inst.tick(2.0)  # advance through down phase
	assert_true(timed_inst.is_extended())
	assert_true(timed_inst.damages_on_presence())

func test_tick_with_null_data_is_noop() -> void:
	var inst := TrapInstance.new()
	# Don't crash, return NONE.
	assert_eq(inst.tick(1.0), TrapInstance.Event.NONE)

func test_tick_with_zero_or_negative_delta_is_noop() -> void:
	var inst := TrapInstance.create(_make_timed_data(), Vector2i.ZERO)
	assert_eq(inst.tick(0.0), TrapInstance.Event.NONE)
	assert_eq(inst.tick(-0.1), TrapInstance.Event.NONE)

func test_timed_damage_latch_resets_on_each_new_extension() -> void:
	# Game.gd uses `damage_applied_this_extension` to suppress
	# repeated damage within the same up phase. The state machine is
	# responsible for resetting the latch on every new
	# RETRACTED→EXTENDED transition so the next extension can
	# damage once.
	var inst := TrapInstance.create(_make_timed_data(5, 1.0, 2.0), Vector2i.ZERO)
	# Simulate Game.gd applying damage during the first extension.
	inst.tick(2.0)  # RETRACTED → EXTENDED (ACTIVATED event)
	inst.damage_applied_this_extension = true
	# Up phase completes → DEACTIVATED. Latch persists across the
	# down phase so a player who walks onto a still-cooling-down
	# cell doesn't get hit by the previous extension's damage.
	inst.tick(1.0)
	assert_eq(inst.state, TrapInstance.State.RETRACTED)
	assert_true(inst.damage_applied_this_extension)
	# Next down phase elapses → ACTIVATED again → latch resets.
	inst.tick(2.0)
	assert_eq(inst.state, TrapInstance.State.EXTENDED)
	assert_false(inst.damage_applied_this_extension)

func test_step_trap_does_not_touch_damage_latch() -> void:
	# The latch is timed-only. STEP traps' damage flow goes through
	# on_player_step and respects on_cooldown instead — the latch is
	# inert for them.
	var inst := TrapInstance.create(_make_step_data(10), Vector2i.ZERO)
	inst.on_player_step()
	# Latch stays at its default — STEP traps don't manage it.
	assert_false(inst.damage_applied_this_extension)
	inst.tick(0.5)  # retract
	assert_false(inst.damage_applied_this_extension)
