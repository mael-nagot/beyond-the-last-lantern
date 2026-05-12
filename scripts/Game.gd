extends Node3D

var _player_controller = null
var _hud = null
var _dungeon_view = null
var _generator: LevelGenerator = null
var _party: Array[Character] = []

# Brief jolt magnitude when the party takes damage from a trap.
const _DAMAGE_SHAKE_MAGNITUDE: float = 0.7

# Delay between a successful step ONTO a trap and the trap firing.
# Slightly longer than DungeonView's 0.12s movement tween so the
# camera has visibly arrived at the cell before the spike pops, the
# screen flashes, and the shake hits — sells "I just stepped on
# something nasty" instead of "I teleported onto something nasty".
# If the player triggers another move during this window, the new
# move and the deferred trap effect proceed independently — the
# trap effect still resolves for the cell that was actually entered.
const _TRAP_ACTIVATION_DELAY: float = 0.13

# Phase 8 Task 8 — spinner state.
#
# `_spinner_spinning` gates every movement / interaction handler so
# the player can't queue another move (or pick up an item, click a
# chest, etc.) while a chained-rotation animation is mid-way through.
# Folded into `_is_world_paused()` so the existing pause checks in
# `_on_move` / `_input` honour it without duplication.
#
# `_spinner_just_triggered_cell` is the "armed" guard for re-entry:
# once a spinner fires for the player on cell X, this is set to X and
# subsequent re-checks of the same cell are no-ops. The next
# `_on_player_entered_cell` for a DIFFERENT cell clears it, so
# stepping off-and-back-on rearms naturally. Stepping back onto a
# different spinner (immediately) still fires correctly. Sentinel
# Vector2i(-1, -1) means "no spinner currently latched".
var _spinner_spinning: bool = false
const _SPINNER_NO_CELL := Vector2i(-1, -1)
var _spinner_just_triggered_cell: Vector2i = _SPINNER_NO_CELL

# Phase 15 Task 6 — teleporter state. Mirrors the spinner pattern:
#   - `_teleporter_warping` gates every movement / interaction handler
#     while the fade-warp-fade chain is mid-flight. Folded into
#     `_is_world_paused()` so `_on_move` / `_input` honour it without
#     duplicate logic.
#   - `_teleporter_just_arrived_cell` is the armed-cell latch that
#     prevents an immediate bounce-back: after a warp lands the player
#     on cell X, this is set to X, and subsequent re-checks of cell X
#     are no-ops. The next `_check_teleporter_trigger` on a DIFFERENT
#     cell clears the latch, so stepping off-and-back-on re-warps.
var _teleporter_warping: bool = false
const _TELEPORTER_NO_CELL := Vector2i(-1, -1)
var _teleporter_just_arrived_cell: Vector2i = _TELEPORTER_NO_CELL
# Default fade duration on each leg (in → snap → out) of the warp.
# Lifted into a constant so the spinner-style cell tests below can
# document the timing intent without re-reading the magic number.
const _TELEPORTER_FADE_DURATION: float = 0.18

func _ready() -> void:
	var dungeon_view      = $DungeonView
	var player_controller = $DungeonView/PlayerController
	var hud               = $HUD

	if dungeon_view == null or player_controller == null or hud == null:
		push_error("Required node missing")
		return

	var biome = load("res://assets/biomes/forest.tres")
	if biome == null:
		push_error("Game: failed to load biome resource")
		return

	var audio_config: AudioConfig = load("res://assets/audio_config.tres")
	if audio_config == null:
		push_warning("Game: audio_config.tres not found — sounds will be silent")
	SoundManager.audio_config = audio_config
	SoundManager.current_biome = biome

	var gen = LevelGenerator.new()
	add_child(gen)
	gen.configure(biome)
	gen.generate()

	dungeon_view.biome = biome
	dungeon_view.setup(gen)
	player_controller.setup(dungeon_view, gen)

	hud.setup_map(gen)
	hud.setup_dungeon_view(dungeon_view)

	_player_controller = player_controller
	_hud = hud
	_dungeon_view = dungeon_view
	_generator = gen

	var pad = hud.movement_pad
	pad.forward_pressed.connect(_on_move.bind("forward"))
	pad.backward_pressed.connect(_on_move.bind("backward"))
	pad.turn_left_pressed.connect(_on_move.bind("turn_left"))
	pad.turn_right_pressed.connect(_on_move.bind("turn_right"))
	pad.strafe_left_pressed.connect(_on_move.bind("strafe_left"))
	pad.strafe_right_pressed.connect(_on_move.bind("strafe_right"))

	if hud.pickup_prompt != null:
		hud.pickup_prompt.pressed.connect(_on_pickup_pressed)

	_setup_party()
	_wire_drop_targets()

	_update_map()
	_update_pickup_prompt()

func _setup_party() -> void:
	_party = [
		Character.create("character.placeholder.warrior", 30, 5),
		Character.create("character.placeholder.wizard", 15, 25),
		Character.create("character.placeholder.rogue", 22, 10),
	]
	var party_panel = _hud.party_panel
	for i in range(_party.size()):
		var slot = party_panel.get_slot(i)
		if slot == null:
			continue
		slot.bind(_party[i])
		var idx := i
		slot.item_consumed.connect(_on_item_used_on_character.bind(idx))
		slot.item_rejected.connect(_on_item_rejected.bind(idx))

func _wire_drop_targets() -> void:
	if _dungeon_view != null and _dungeon_view.drop_target != null:
		_dungeon_view.drop_target.item_dropped.connect(_on_item_dropped_on_dungeon)
		_dungeon_view.drop_target.object_clicked.connect(_on_object_clicked)
	if _hud != null and _hud.loot_popup != null:
		_hud.loot_popup.item_taken.connect(_on_loot_item_taken)
		_hud.loot_popup.take_all_requested.connect(_on_loot_take_all)
		_hud.loot_popup.close_requested.connect(_on_loot_close)
	if _hud != null and _hud.item_bar != null:
		_hud.item_bar.slot_clicked.connect(_on_item_slot_clicked)
		_hud.item_bar.inventory_changed.connect(_on_inventory_changed)
	if _hud != null and _hud.item_description_popup != null:
		_hud.item_description_popup.close_requested.connect(_on_item_description_close)

# -------------------------------------------------------
# Chest interaction
# -------------------------------------------------------

func _on_object_clicked(instance: ObjectInstance, _grid_pos: Vector2i) -> void:
	if instance == null or instance.data == null:
		return
	if instance is DoorInstance:
		_toggle_door(instance as DoorInstance)
		return
	if instance is LeverInstance:
		_pull_lever(instance as LeverInstance)
		return
	if instance.is_chest():
		_open_chest(instance)

func _toggle_door(door: DoorInstance) -> void:
	# Key-locked door: try to apply a matching key from the bar
	# BEFORE the interactable=false feedback path. If the player
	# holds the right key, consume one count, flip `unlocked`, and
	# fall through to the normal toggle (which now opens the door).
	# If they don't have it, the locked-feedback path fires per the
	# door's own locked_message_key (configured to say "needs key"
	# on key-locked door .tres files).
	if door.is_key_locked():
		var key_slot: int = _find_key_slot_for(door.lock_id)
		if key_slot < 0:
			_play_locked_feedback(door.data)
			return
		if _hud != null and _hud.item_bar != null:
			_hud.item_bar.remove_one(key_slot)
		door.unlocked = true
		# Fall through to the normal toggle path — door is now open.
	# Lever-locked doors never toggle via click — the levers control them.
	if door.is_lever_locked():
		_play_lever_locked_feedback(door)
		return
	# A non-interactable door that ISN'T key-locked (or has been
	# unlocked above) needs feedback rather than a toggle.
	if not door.data.interactable and not door.unlocked:
		_play_locked_feedback(door.data)
		return
	door.opened = not door.opened
	SoundManager.play(door.data.interact_sound)
	if _dungeon_view != null:
		_dungeon_view.rebuild_doors()

func _find_key_slot_for(lock_id: String) -> int:
	# Scan the item bar for a slot holding an ItemInstance whose
	# get_key_id() == lock_id. Returns the slot index, or -1.
	if _hud == null or _hud.item_bar == null:
		return -1
	for i in range(ItemBar.SLOT_COUNT):
		var inst: ItemInstance = _hud.item_bar.get_slot(i)
		if inst != null and inst.get_key_id() == lock_id:
			return i
	return -1

func _play_locked_feedback(data: ObjectData) -> void:
	if data.locked_sound != null:
		SoundManager.play(data.locked_sound)
	if _hud != null and data.locked_message_key != "":
		_hud.show_toast(data.locked_message_key)
	if _dungeon_view != null:
		_dungeon_view.shake_camera(0.4)

func _play_lever_locked_feedback(door: DoorInstance) -> void:
	if door.data.locked_sound != null:
		SoundManager.play(door.data.locked_sound)
	var msg_key: String = door.data.locked_message_key
	if door.lever_logic == DoorInstance.LeverLogic.AND:
		var any_pulled := false
		for lever in door.linked_levers:
			if lever != null and lever.pulled:
				any_pulled = true
				break
		if any_pulled and door.data.partial_locked_message_key != "":
			msg_key = door.data.partial_locked_message_key
	if _hud != null and msg_key != "":
		_hud.show_toast(msg_key)
	if _dungeon_view != null:
		_dungeon_view.shake_camera(0.4)

const _LEVER_DOOR_SOUND_DELAY: float = 0.2

func _pull_lever(lever: LeverInstance) -> void:
	if not lever.data.interactable:
		_play_locked_feedback(lever.data)
		return
	lever.toggle()
	# Recompute each linked door; remember which ones actually changed
	# state so we can play their interact sound (the satisfying "thunk"
	# the player expects when the puzzle resolves). For an AND-3 door
	# this only fires on the lever pull that actually opens it.
	var changed_door_data: ObjectData = null
	for door in lever.linked_doors:
		if door == null:
			continue
		var was_opened: bool = door.opened
		door.opened = door.compute_lever_opened()
		if door.opened != was_opened and changed_door_data == null:
			changed_door_data = door.data
	SoundManager.play(lever.data.interact_sound)
	if _dungeon_view != null:
		_dungeon_view.rebuild_doors()
		_dungeon_view.rebuild_objects()
	if changed_door_data != null:
		# Brief delay so the door's "thunk" lands AFTER the lever
		# click instead of stepping on it — reads as cause-and-effect.
		await get_tree().create_timer(_LEVER_DOOR_SOUND_DELAY).timeout
		SoundManager.play(changed_door_data.interact_sound)

func _open_chest(instance: ObjectInstance) -> void:
	if not instance.data.interactable:
		_play_locked_feedback(instance.data)
		return
	var was_opened: bool = instance.opened
	if not instance.opened:
		_roll_chest_loot(instance)
		instance.opened = true
		SoundManager.play(instance.data.interact_sound)
		if _dungeon_view != null:
			_dungeon_view.rebuild_objects()
	if instance.has_remaining_loot():
		if _hud != null and _hud.loot_popup != null:
			_hud.loot_popup.open(instance)
	else:
		# Empty chest: show a toast so the click isn't silent. On a
		# re-click the negative sound carries the audible feedback;
		# on the first open the chest's own interact_sound already did.
		if _hud != null:
			_hud.show_toast("ui.feedback.empty_chest")
		if was_opened:
			SoundManager.play_negative()

func _roll_chest_loot(instance: ObjectInstance) -> void:
	var table: LootTable = instance.loot_table
	if table == null or table.entries.is_empty():
		return
	# Local pool — entries flagged allow_duplicates=false are removed
	# from this pool after they're picked, so they can appear at most
	# once per chest.
	var pool: Array = []
	for entry in table.entries:
		if entry != null and entry.item != null and entry.weight > 0:
			pool.append(entry)
	var count := randi_range(max(0, table.min_rolls), max(table.min_rolls, table.max_rolls))
	for _i in range(count):
		if pool.is_empty():
			break
		var entry := _pick_weighted_loot_table_entry(pool)
		if entry == null:
			continue
		instance.items.append(ItemInstance.create(entry.item, 1))
		if not entry.allow_duplicates:
			pool.erase(entry)

func _pick_weighted_loot_table_entry(pool: Array) -> LootTableEntry:
	var total := 0
	for entry in pool:
		total += max(0, entry.weight)
	if total <= 0:
		return null
	var roll := randi() % total
	for entry in pool:
		var w: int = max(0, entry.weight)
		if roll < w:
			return entry
		roll -= w
	return null

func _on_loot_item_taken(slot_index: int) -> void:
	if _hud == null or _hud.loot_popup == null or _hud.item_bar == null:
		return
	var instance: ObjectInstance = _hud.loot_popup.get_current_instance()
	if instance == null:
		return
	if slot_index < 0 or slot_index >= instance.items.size():
		return
	var item: ItemInstance = instance.items[slot_index]
	# Snapshot stack count up-front so we can tell whether anything
	# actually moved into the bar — `add_item` mutates `item` and
	# returns it as the leftover when the bar can't fit everything.
	var before_count: int = item.stack_count if item != null else 0
	var leftover: ItemInstance = _hud.item_bar.add_item(item)
	var transferred: bool = (leftover == null) or (leftover.stack_count < before_count)
	if transferred and item != null and item.data != null:
		SoundManager.play(item.data.pickup_drop_sound)
	if leftover == null:
		instance.items.remove_at(slot_index)
	# else: same instance with reduced stack stays in chest
	if instance.items.is_empty():
		_hud.loot_popup.close()
	else:
		_hud.loot_popup.refresh()

func _on_loot_take_all() -> void:
	if _hud == null or _hud.loot_popup == null or _hud.item_bar == null:
		return
	var instance: ObjectInstance = _hud.loot_popup.get_current_instance()
	if instance == null:
		return
	# Pick the first item-with-a-sound up-front, mirroring the floor-
	# pickup pattern in _on_pickup_pressed. We play this sound once
	# at the end if anything was actually transferred — playing it
	# per-item would spam the audio on a full chest.
	var pickup_sound: AudioStream = null
	for item in instance.items:
		if item != null and item.data != null and item.data.pickup_drop_sound != null:
			pickup_sound = item.data.pickup_drop_sound
			break
	# would_fit_all has already gated the button — but defend in case of races.
	var copy: Array = instance.items.duplicate()
	var any_transferred := false
	for item in copy:
		var before_count: int = item.stack_count if item != null else 0
		var leftover: ItemInstance = _hud.item_bar.add_item(item)
		if (leftover == null) or (leftover.stack_count < before_count):
			any_transferred = true
		if leftover == null:
			instance.items.erase(item)
	if any_transferred:
		SoundManager.play(pickup_sound)
	if instance.items.is_empty():
		_hud.loot_popup.close()
	else:
		_hud.loot_popup.refresh()

func _on_loot_close() -> void:
	if _hud != null and _hud.loot_popup != null:
		_hud.loot_popup.close()

func _on_item_slot_clicked(slot_index: int) -> void:
	if _hud == null or _hud.item_bar == null or _hud.item_description_popup == null:
		return
	var inst: ItemInstance = _hud.item_bar.get_slot(slot_index)
	if inst == null or inst.data == null:
		return
	# Tapping the same slot while the popup is already showing it
	# closes — feels like a toggle.
	var popup: ItemDescriptionPopup = _hud.item_description_popup
	if popup.is_open() and popup.get_current_instance() == inst:
		popup.close()
		return
	popup.open(inst)

func _on_inventory_changed() -> void:
	# Any inventory mutation (drag-use, drop on dungeon, pickup, debug
	# spawn) closes the popup so it never displays stale state.
	if _hud != null and _hud.item_description_popup != null and _hud.item_description_popup.is_open():
		_hud.item_description_popup.close()

func _on_item_description_close() -> void:
	if _hud != null and _hud.item_description_popup != null:
		_hud.item_description_popup.close()

func _on_item_used_on_character(slot_index: int, _character_index: int) -> void:
	if _hud == null or _hud.item_bar == null:
		return
	_hud.item_bar.remove_one(slot_index)

func _on_item_rejected(_slot_index: int, _character_index: int) -> void:
	if _hud != null:
		_hud.show_toast("ui.feedback.no_effect")

func _on_item_dropped_on_dungeon(slot_index: int, source_instance: ItemInstance) -> void:
	if _hud == null or _hud.item_bar == null:
		return
	if source_instance == null or source_instance.data == null:
		return
	var cell := _current_cell()
	if cell == null:
		return
	var single := ItemInstance.create(source_instance.data, 1)
	cell.items.append(single)
	_hud.item_bar.remove_one(slot_index)
	if _dungeon_view != null:
		_dungeon_view.rebuild_items()
	SoundManager.play(source_instance.data.pickup_drop_sound)
	_update_pickup_prompt()

func _on_move(action: String) -> void:
	# Any modal popup that paused the world (map today; future
	# settings / inventory) should suppress movement. Reading
	# `get_tree().paused` keeps this generic — every future popup
	# that registers as a pause source automatically gates input
	# without changing this callback.
	if _is_world_paused():
		return
	var prev_pos: Vector2i = _player_controller.grid_pos
	match action:
		"forward":     _player_controller.move_forward()
		"backward":    _player_controller.move_backward()
		"turn_left":   _player_controller.turn_left()
		"turn_right":  _player_controller.turn_right()
		"strafe_left": _player_controller.strafe_left()
		"strafe_right":_player_controller.strafe_right()
	_update_map()
	_update_pickup_prompt()
	if _player_controller.grid_pos != prev_pos:
		_on_player_entered_cell()

func _is_world_paused() -> bool:
	# Single source of truth: the SceneTree's paused flag, owned by
	# HUD's pause-source registry. Game.gd doesn't need to know
	# WHICH popup paused — only whether gameplay input should be
	# routed through.
	if get_tree() != null and get_tree().paused:
		return true
	# Spinner spins also gate input — they're internal (no SceneTree
	# pause) so they don't fight the existing pause-source registry,
	# but they need the same "drop player input" behaviour. Teleporter
	# warps share the same model.
	return _spinner_spinning or _teleporter_warping

func _update_map() -> void:
	if _hud and _player_controller:
		_hud.update_player_on_map(
			_player_controller.grid_pos,
			PlayerController.DIR_VECTORS[_player_controller.facing]
		)

func _update_pickup_prompt() -> void:
	if _hud == null or _hud.pickup_prompt == null or _generator == null or _player_controller == null:
		return
	var cell := _current_cell()
	var count := 0 if cell == null else cell.items.size()
	_hud.pickup_prompt.set_count(count)

func _current_cell() -> GridCell:
	if _generator == null or _player_controller == null:
		return null
	var pos: Vector2i = _player_controller.grid_pos
	return _generator.get_cell(pos.x, pos.y)

func _on_pickup_pressed() -> void:
	if _hud == null or _hud.item_bar == null or _hud.pickup_prompt == null:
		return
	var cell := _current_cell()
	if cell == null or cell.items.is_empty():
		return
	var pickup_sound: AudioStream = null
	for item in cell.items:
		if item != null and item.data != null and item.data.pickup_drop_sound != null:
			pickup_sound = item.data.pickup_drop_sound
			break
	var transferred: int = _hud.item_bar.pickup_from(cell)
	if _dungeon_view != null:
		_dungeon_view.rebuild_items()
	if transferred == 0:
		_hud.pickup_prompt.flash_bar_full()
		SoundManager.play_negative()
	else:
		SoundManager.play(pickup_sound)
	_update_pickup_prompt()

func _input(event: InputEvent) -> void:
	if _player_controller == null:
		return
	if not event is InputEventKey or not event.pressed:
		return
	if event.is_echo():
		return
	# A paused world (modal popup open) blocks every gameplay-
	# affecting key (movement, pickup, debug spawns / damage). Modal
	# closes are wired to their own ✕ buttons, so we don't need an
	# Escape-to-close shortcut here.
	if _is_world_paused():
		return
	var prev_pos: Vector2i = _player_controller.grid_pos
	match event.keycode:
		KEY_W, KEY_UP:   _player_controller.move_forward()
		KEY_S, KEY_DOWN: _player_controller.move_backward()
		KEY_Q:           _player_controller.turn_left()
		KEY_E:           _player_controller.turn_right()
		KEY_A:           _player_controller.strafe_left()
		KEY_D:           _player_controller.strafe_right()
		KEY_F:           _on_pickup_pressed()
		KEY_F1:          _debug_spawn_health_potion()
		KEY_F2:          _debug_damage_party()
		KEY_F3:          _debug_reveal_full_map()
	_update_map()
	_update_pickup_prompt()
	if _player_controller.grid_pos != prev_pos:
		_on_player_entered_cell()

func _debug_damage_party() -> void:
	for c in _party:
		c.damage(10)

func _debug_reveal_full_map() -> void:
	if _hud == null or _hud.map_data == null:
		return
	_hud.map_data.reveal_all()
	if _hud.map_popup != null:
		_hud.map_popup.redraw()

func _debug_spawn_health_potion() -> void:
	if _hud == null or _hud.item_bar == null:
		push_error("Game._debug_spawn_health_potion: HUD or item_bar missing")
		return
	var path := "res://assets/items/health_potion.tres"
	var data: ItemData = load(path)
	if data == null:
		push_error("Game._debug_spawn_health_potion: failed to load %s — create the resource first" % path)
		return
	var leftover = _hud.item_bar.add_item(ItemInstance.create(data, 1))
	if leftover != null:
		push_warning("Item bar full — health potion not added")

# -------------------------------------------------------
# Traps — step entry, periodic tick, damage, feedback
# -------------------------------------------------------

# Called on every successful position change. STEP traps fire here
# (single-shot, immediate damage). TIMED trap presence is checked in
# the per-frame tick instead, since their damage event is the
# RETRACTED→EXTENDED transition rather than the cell-entry event.
func _on_player_entered_cell() -> void:
	if _generator == null:
		return
	var cell := _current_cell()
	# Snapshot the spike trap on the cell — projectile-trap plates
	# (Subtask C4) trigger from a separate registry so we still want
	# to run that branch on cells WITHOUT a spike trap.
	var spike_trap: TrapInstance = null
	if cell != null:
		spike_trap = cell.trap
	# Defer trap activation/feedback until the move tween has visibly
	# completed. Without this delay the spike-pop / shake / flash /
	# damage all fire on the same frame the player presses W, making
	# the cell entry read as a teleport. The 0.13s window is just
	# longer than DungeonView's 0.12s position tween. If the world
	# is paused during the wait (modal popup), the timer pauses too —
	# trap effects resume when the modal closes.
	await get_tree().create_timer(_TRAP_ACTIVATION_DELAY).timeout
	# Re-check we're still alive after the await.
	if not is_instance_valid(self) or _generator == null:
		return
	# Spike trap branch (Subtask A) — guarded by null + still-on-cell
	# check so a future runtime trap removal (disarm, transition)
	# doesn't fire on a stale ref.
	if spike_trap != null:
		var post_cell := _current_cell()
		if post_cell != null and post_cell.trap == spike_trap:
			if spike_trap.data.is_timed():
				# TIMED trap: walking ONTO a cell with spikes already
				# extended should damage the player once. The latch
				# (damage_applied_this_extension) prevents a double-charge
				# if the player walks off and back on within the same up
				# phase, or stood there when ACTIVATED already triggered
				# damage. The state machine resets the latch on every
				# RETRACTED→EXTENDED transition so each extension can
				# damage once.
				if spike_trap.is_extended() and not spike_trap.damage_applied_this_extension and spike_trap.data.damage > 0:
					spike_trap.damage_applied_this_extension = true
					_apply_party_damage(spike_trap.data.damage)
			elif spike_trap.data.is_step():
				var should_damage: bool = spike_trap.on_player_step()
				if _dungeon_view != null:
					_dungeon_view.update_trap_visual(spike_trap)
				# Activate sound — STEP traps fire at the player's feet,
				# so route through SoundManager (non-spatial) for
				# consistent loudness even if the spatial player would
				# attenuate.
				if spike_trap.data.activate_sound != null:
					SoundManager.play(spike_trap.data.activate_sound)
				if should_damage:
					_apply_party_damage(spike_trap.data.damage)
	# Pressure-plate branch (Subtask C4). Player cell is re-read here
	# so a plate fires only if the player is STILL on it after the
	# await — same conservative behaviour as the spike-trap branch.
	if _player_controller != null:
		_check_pressure_plate_trigger(_player_controller.grid_pos)
	# Spinner branch (Phase 8 Task 8). Runs even when the cell has no
	# trap and no plate. The armed-cell guard prevents re-firing
	# during a single stay; clearing it for cells that DON'T hold a
	# spinner lets a player who steps off, then back onto a spinner
	# rearm it.
	if _player_controller != null:
		_check_spinner_trigger(_player_controller.grid_pos)
	# Teleporter branch (Phase 15 Task 6 — Phase A). Runs LAST so the
	# spike/plate/spinner branches always resolve for the source cell
	# before the warp fires. The armed-cell guard
	# (`_teleporter_just_arrived_cell`) is the bounce-back prevention
	# for the warp itself; stepping off the teleporter cell clears it
	# and a return step rearms naturally.
	if _player_controller != null:
		_check_teleporter_trigger(_player_controller.grid_pos)

# Phase 8 Task 3 — Subtask C4. Scans every PRESSURE_PLATE launcher;
# if its plate cell matches the player's current cell AND the launcher
# isn't already mid-flight, spawns a projectile and plays the plate +
# launch sounds (always at full volume — the player is right at the
# plate, no hearing-distance gate).
#
# Multiple plates on the same cell are not blocked here — if two
# launchers somehow share a plate cell (placement should prevent it
# but this stays safe), each fires independently. `spawn_projectile`
# returns null if `in_flight` is set, so a re-entry while the
# projectile is still flying is a no-op.
func _check_pressure_plate_trigger(player_cell: Vector2i) -> void:
	if _generator == null:
		return
	# An item sitting on the plate cell holds the plate in the
	# triggered (depressed) position — the plate is already "down",
	# so the player's step doesn't sense a fresh pressure transition.
	# Sacrifices the item but disables the trap until the item is
	# picked up. After pickup the plate re-arms; the next FRESH step
	# onto the plate fires normally. This is interpretation A from
	# the design check — pickup itself doesn't fire even if the
	# player is standing on the plate (plate fires only on step-on
	# events, not on weight-change events).
	var pcell: GridCell = _generator.grid[player_cell.x][player_cell.y]
	if pcell != null and not pcell.items.is_empty():
		return
	for ptrap in _generator.projectile_traps:
		if ptrap == null or ptrap.data == null:
			continue
		if not ptrap.data.is_pressure_plate():
			continue
		if not ptrap.has_plate():
			continue
		if ptrap.plate_cell != player_cell:
			continue
		var spawned: ProjectileInstance = ptrap.spawn_projectile()
		if spawned == null:
			# in_flight already true — projectile from this plate is
			# still in the air, so the plate doesn't re-trigger.
			continue
		_generator.projectiles.append(spawned)
		if _dungeon_view != null:
			_dungeon_view.spawn_projectile_visual(spawned)
		if ptrap.data.plate_sound != null:
			SoundManager.play(ptrap.data.plate_sound)
		if ptrap.data.launch_sound != null:
			SoundManager.play(ptrap.data.launch_sound)

# Phase 8 Task 8 — Spinner trigger. Called from `_on_player_entered_cell`
# after every other branch so spike-trap damage / plate firing always
# resolve first (they shouldn't share a tile with a spinner anyway, but
# the order keeps the contract clean if a future placement bug ever
# slips through).
#
# Re-trigger guard: `_spinner_just_triggered_cell` records the cell of
# the most recent spin so subsequent re-checks on the same cell (e.g.
# the player presses a turn key while standing on the spinner) don't
# re-fire. Stepping to ANY other cell clears the latch — the next
# spinner step rearms naturally. This matches the "step fully off to
# rearm" rule from the design spec.
func _check_spinner_trigger(player_cell: Vector2i) -> void:
	if _generator == null:
		return
	var pcell: GridCell = _generator.grid[player_cell.x][player_cell.y]
	if pcell == null or pcell.spinner == null:
		# Clear the latch when leaving the spinner cell so a step-off /
		# step-back-on cycle re-triggers the spin.
		_spinner_just_triggered_cell = _SPINNER_NO_CELL
		return
	if _spinner_just_triggered_cell == player_cell:
		# Same cell as last trigger — still armed-down. The player
		# turned voluntarily while standing on the spinner; don't
		# re-fire.
		return
	# Latch BEFORE the await so a second step-onto-this-cell during
	# the spin (impossible while paused, but belt-and-braces) reads
	# as "already triggered".
	_spinner_just_triggered_cell = player_cell
	_trigger_spinner(pcell.spinner)

# Drives the chained 90° rotations for one spinner activation. Sets
# the input-lock flag, dispatches `rotations` turns to PlayerController
# in the resolved direction (each turn awaits the `spin_step_duration`
# so consecutive 0.12s tweens in DungeonView's `rotate_camera_to`
# don't fight for `camera.rotation_degrees:y`), and clears the lock.
#
# Sound: per-90°-turn whoosh. Falls back to the global turn sound when
# the spinner's `spin_sound` is empty so designers can opt out of
# bespoke audio without going silent. The PlayerController turn is
# called with `play_sound = false` so its own per-turn rustle doesn't
# double up.
func _trigger_spinner(spinner: SpinnerInstance) -> void:
	if spinner == null or spinner.data == null:
		return
	if _player_controller == null:
		return
	_spinner_spinning = true
	# Floor each step at the rotate tween's duration (0.12s) so the
	# camera tween settles before the next call replaces it. Designers
	# can speed spinners up by lowering `spin_step_duration` toward
	# 0.12, but going below would visually fight the tween — clamp.
	var step_dur: float = max(0.12, spinner.data.spin_step_duration)
	var n: int = max(1, spinner.rotations)
	var cw: bool = spinner.is_clockwise()
	for _i in range(n):
		if cw:
			_player_controller.turn_right(false)
		else:
			_player_controller.turn_left(false)
		# Voluntary turns flow through `_on_move` / `_input`, both of
		# which call `_update_map()` after the turn so the map's
		# player_facing tracks `PlayerController.facing`. Spinner spins
		# bypass that path, so without this explicit call the map's
		# arrow would stay frozen on the pre-spin facing — most
		# obviously when the player opens the map right after being
		# spun and sees the arrow pointing the wrong way.
		_update_map()
		var snd: AudioStream = spinner.data.spin_sound
		if snd != null:
			SoundManager.play(snd)
		else:
			SoundManager.play_turn()
		# `process_always = false` so the timer pauses with the
		# SceneTree — if the player opens the map mid-spin, the
		# remaining steps wait for the resume. Matches what the
		# rotate tween already does (it inherits process_mode).
		await get_tree().create_timer(step_dur, false).timeout
		if not is_instance_valid(self) or _generator == null:
			# Level transition mid-spin — bail out, leaving the
			# flag cleared via the defer below.
			break
	_spinner_spinning = false

# Phase 15 Task 6 — Phase A teleporter trigger. Called from
# `_on_player_entered_cell` after every other branch so a spinner /
# trap / plate on the source cell resolves before we warp away. The
# armed-cell latch (`_teleporter_just_arrived_cell`) prevents bounce-
# back: when we land on a cell via warp the latch is set to that cell,
# and subsequent entry-checks for the same cell exit early. Stepping
# off the teleporter to any other cell clears the latch so a return
# step rearms naturally — mirrors the spinner re-trigger pattern.
func _check_teleporter_trigger(player_cell: Vector2i) -> void:
	if _generator == null:
		return
	var inst: TeleporterInstance = _generator.get_teleporter_at(player_cell)
	if inst == null:
		# Stepped onto a non-teleporter cell — clear the latch so a
		# future return to either endpoint re-fires the warp.
		_teleporter_just_arrived_cell = _TELEPORTER_NO_CELL
		return
	if _teleporter_just_arrived_cell == player_cell:
		# Just warped onto this cell — don't re-fire.
		return
	var partner: Vector2i = inst.partner_of(player_cell)
	if partner == _TELEPORTER_NO_CELL:
		push_error("Game._check_teleporter_trigger: teleporter at %s missing partner endpoint" % player_cell)
		return
	# Latch the DESTINATION up front so any re-entry check during the
	# warp (defensive — shouldn't happen because `_teleporter_warping`
	# also gates input) returns false. Fire-and-forget the warp; the
	# `_teleporter_warping` flag set inside `_trigger_teleporter` takes
	# effect synchronously (before the first await) so the input lock
	# is active by the time this function returns.
	_teleporter_just_arrived_cell = partner
	_trigger_teleporter(inst, partner)

# Async warp driver. Sequence:
#   1. Set `_teleporter_warping` (input lock).
#   2. Play warp sound at the moment of decision.
#   3. Fade-to-black.
#   4. Snap player + camera to the partner cell. PlayerController's
#      grid_pos is set directly; DungeonView's `snap_camera_to` kills
#      any in-flight move tween and resets via `set_initial_facing` so
#      every per-cell visual (chest leans, item shift, plate rotations,
#      spike spikes) recalibrates to the new cell.
#   5. Reveal the destination on the map + refresh pickup prompt.
#   6. Fade-from-black.
#   7. Clear `_teleporter_warping`.
#   8. Re-fire `_on_player_entered_cell` so any spike trap / plate /
#      spinner ON the destination cell still resolves (the armed-cell
#      latch keeps this from re-warping).
#
# Robustness: bails out cleanly if the level transitions mid-warp
# (`is_instance_valid(self)` checks after each await). The fade tween
# is owned by DungeonView, so it pauses naturally with the SceneTree.
func _trigger_teleporter(inst: TeleporterInstance, destination: Vector2i) -> void:
	if _dungeon_view == null or _player_controller == null:
		return
	if inst == null or inst.data == null:
		return
	_teleporter_warping = true
	# Play the warp cue BEFORE the fade so the audio leads the visual —
	# the player hears "something happened" the instant they step on
	# the cell, even before the screen darkens.
	if inst.data.warp_sound != null:
		SoundManager.play(inst.data.warp_sound)
	await _dungeon_view.fade_to_black(_TELEPORTER_FADE_DURATION)
	if not is_instance_valid(self) or _generator == null or _player_controller == null:
		return
	_player_controller.grid_pos = destination
	_dungeon_view.snap_camera_to(destination, PlayerController.DIR_VECTORS[_player_controller.facing])
	# Clear the spinner armed-cell latch so a spinner on the
	# destination (or a return to a previously-spun cell via warp) is
	# treated as a fresh step-on, not a re-trigger of an existing stay.
	_spinner_just_triggered_cell = _SPINNER_NO_CELL
	_update_map()
	_update_pickup_prompt()
	await _dungeon_view.fade_from_black(_TELEPORTER_FADE_DURATION)
	if not is_instance_valid(self):
		return
	_teleporter_warping = false
	# Re-fire cell-entry handlers on the destination so traps / plates
	# / spinners there still resolve. The teleporter-armed-cell latch
	# (`_teleporter_just_arrived_cell == destination`) prevents the
	# warp from re-firing on this re-entry.
	_on_player_entered_cell()

# Per-frame tick. Advances every trap's state machine and reacts to
# observed transitions:
#   ACTIVATED   — TIMED trap just popped up. If the player is on the
#                 cell, apply damage. Sound plays through the trap's
#                 own AudioStreamPlayer3D (spatial). Visual flips on.
#   DEACTIVATED — spikes retracted. STEP traps' deactivate sound is
#                 non-spatial (player just stood there); TIMED traps
#                 use their 3D player. Visual flips off.
#
# `_is_world_paused` would already freeze _process via SceneTree, but
# we also gate explicitly so the state-machine clock doesn't drift if
# we ever change `process_mode`. Cheap belt-and-braces.
func _process(delta: float) -> void:
	if _generator == null:
		return
	if _is_world_paused():
		return
	var current: Vector2i = _player_controller.grid_pos if _player_controller != null else Vector2i.ZERO
	for trap in _generator.traps:
		if trap == null:
			continue
		var event: int = trap.tick(delta)
		match event:
			TrapInstance.Event.ACTIVATED:
				_on_trap_activated(trap, current)
			TrapInstance.Event.DEACTIVATED:
				_on_trap_deactivated(trap)
	# Phase 8 Task 3 — Subtask C2. Tick wall-mounted projectile
	# launchers (TIMED rollovers spawn projectiles) and every
	# in-flight projectile, removing those that hit a wall this frame.
	# Order matters: launchers first so a projectile spawned this
	# frame also gets one tick of motion, instead of waiting until
	# next frame to start moving.
	_tick_projectile_launchers(delta)
	_tick_projectiles(delta)

func _tick_projectile_launchers(delta: float) -> void:
	if _generator.projectile_traps.is_empty():
		return
	for ptrap in _generator.projectile_traps:
		if ptrap == null:
			continue
		var spawned: ProjectileInstance = ptrap.tick(delta)
		if spawned == null:
			continue
		_generator.projectiles.append(spawned)
		if _dungeon_view != null:
			_dungeon_view.spawn_projectile_visual(spawned)
		# Launch sound. TIMED traps gate by hearing distance — same
		# pattern as spike timed traps. PRESSURE_PLATE traps (C4) play
		# unconditionally since the player is on the plate.
		if ptrap.data.is_timed() and _player_within_projectile_trap_hearing(ptrap):
			if ptrap.data.launch_sound != null:
				SoundManager.play(ptrap.data.launch_sound)

func _tick_projectiles(delta: float) -> void:
	if _generator.projectiles.is_empty():
		return
	# Snapshot the player's cell once for the whole loop so multi-projectile
	# frames see a consistent player position even if some downstream side
	# effect tried to move the player (none today, but defensive).
	var player_cell: Vector2i = _player_controller.grid_pos if _player_controller != null else Vector2i(-99999, -99999)
	# Iterate by index then collect impacts so we can remove cleanly
	# after the loop without invalidating the indexing. Modifying the
	# array mid-iteration would skip entries.
	var impacted: Array[ProjectileInstance] = []
	for proj in _generator.projectiles:
		if proj == null:
			impacted.append(proj)
			continue
		var event: int = proj.tick(delta, _generator.grid, _generator.grid_width, _generator.grid_height)
		if _dungeon_view != null:
			_dungeon_view.update_projectile_visual(proj)
		# Phase 8 Task 3 — Subtask C3: damage check after tick. The
		# wrapper sets `damage_latch` atomically so a single projectile
		# can only damage once per flight, even if it sits on the
		# player's cell for multiple frames or multiple ticks see it
		# there before the projectile moves on. Reuses
		# `_apply_party_damage` so the feedback (camera shake + flash
		# + pain sound) matches spike traps and any future damage
		# source — designers don't have to wire feedback per system.
		if proj.consume_damage_for_player(player_cell):
			_apply_party_damage(proj.data.damage)
		if event == ProjectileInstance.Event.IMPACT:
			# Clear the launcher's PRESSURE_PLATE in-flight lock so
			# the plate can re-fire on the next player step. TIMED
			# launchers don't read in_flight, but clearing it anyway
			# keeps state tidy and lets future systems treat all
			# projectile-trap launchers uniformly.
			if proj.launcher != null:
				proj.launcher.in_flight = false
			if _player_within_projectile_hearing(proj):
				if proj.data.impact_sound != null:
					SoundManager.play(proj.data.impact_sound)
			if _dungeon_view != null:
				_dungeon_view.despawn_projectile_visual(proj)
			impacted.append(proj)
	for proj in impacted:
		_generator.projectiles.erase(proj)

func _on_trap_activated(trap: TrapInstance, player_cell: Vector2i) -> void:
	if _dungeon_view != null:
		_dungeon_view.update_trap_visual(trap)
	# Trap activation sound. TIMED traps gate by hearing distance —
	# inside `hearing_distance` (Manhattan tiles) plays at full
	# volume, beyond is silent. We dropped the AudioStreamPlayer3D
	# falloff curve because it wasn't reliably audible inside the
	# SubViewport; the manual gate is louder and simpler. STEP traps
	# never reach here (their state activates via on_player_step,
	# not via tick), so this branch is timed-only in practice.
	if trap.data.is_timed() and _player_within_trap_hearing(trap):
		SoundManager.play(trap.data.activate_sound)
	# Damage iff the player is standing on this trap's cell at the
	# moment it pops. Standing-on-trap is checked against the cached
	# `player_cell` snapshot rather than re-reading mid-loop, so
	# multi-trap activations in the same frame each see the same
	# player position. Latch the per-extension flag so a subsequent
	# walk-off-and-back-on within this same up phase doesn't
	# double-damage (covered by _on_player_entered_cell's check).
	if trap.cell == player_cell and trap.data.damage > 0:
		trap.damage_applied_this_extension = true
		_apply_party_damage(trap.data.damage)

func _on_trap_deactivated(trap: TrapInstance) -> void:
	if _dungeon_view == null:
		return
	_dungeon_view.update_trap_visual(trap)
	# Same gating as activate: TIMED traps only emit sound when the
	# player is within hearing range; STEP traps fire at the player's
	# feet and play unconditionally.
	if trap.data.is_timed():
		if _player_within_trap_hearing(trap):
			SoundManager.play(trap.data.deactivate_sound)
	else:
		SoundManager.play(trap.data.deactivate_sound)

# Manhattan-tile distance from player to trap, scaled by CELL_SIZE,
# compared against `hearing_distance`. Used to gate timed-trap audio
# so far-off cycles stay silent — the player's "this dungeon has
# trap X over there" mental map should depend on proximity, not on
# every trap in the level firing every cycle.
func _player_within_trap_hearing(trap: TrapInstance) -> bool:
	if _player_controller == null or trap == null or trap.data == null:
		return false
	if trap.data.hearing_distance <= 0.0:
		return false
	var diff: Vector2i = _player_controller.grid_pos - trap.cell
	# Manhattan distance in tiles; convert to world units against
	# CELL_SIZE (4.6) so `hearing_distance` reads as world units like
	# every other game distance.
	var dist_tiles: float = float(abs(diff.x) + abs(diff.y))
	var dist_world: float = dist_tiles * 4.6
	return dist_world <= trap.data.hearing_distance

# Same pattern as `_player_within_trap_hearing` but for wall-mounted
# projectile launchers. Distance measured from the player to the
# launcher's host cell — that's the visual / audio source location.
# Used to gate `launch_sound` on TIMED traps so distant launchers
# don't spam the audio mix.
func _player_within_projectile_trap_hearing(ptrap: ProjectileTrapInstance) -> bool:
	if _player_controller == null or ptrap == null or ptrap.data == null:
		return false
	if ptrap.data.hearing_distance <= 0.0:
		return false
	var diff: Vector2i = _player_controller.grid_pos - ptrap.cell
	var dist_tiles: float = float(abs(diff.x) + abs(diff.y))
	var dist_world: float = dist_tiles * 4.6
	return dist_world <= ptrap.data.hearing_distance

# Hearing gate for an in-flight projectile's IMPACT sound. The audio
# source location is wherever the projectile died, so distance is
# measured from the player to the projectile's current cell (which on
# IMPACT has been clamped to the wall face). Same Manhattan-tiles ×
# CELL_SIZE convention as the launcher / spike-trap gates.
func _player_within_projectile_hearing(proj: ProjectileInstance) -> bool:
	if _player_controller == null or proj == null or proj.data == null:
		return false
	if proj.data.hearing_distance <= 0.0:
		return false
	var proj_cell := Vector2i(int(floor(proj.cell_pos.x)), int(floor(proj.cell_pos.y)))
	var diff: Vector2i = _player_controller.grid_pos - proj_cell
	var dist_tiles: float = float(abs(diff.x) + abs(diff.y))
	var dist_world: float = dist_tiles * 4.6
	return dist_world <= proj.data.hearing_distance

# Single damage entry point — applies `amount` to every party
# member, then fires the standard feedback (camera shake + screen
# flash + pain sound). Future damage sources (combat, status
# effects) reuse this path so the feel is consistent.
func _apply_party_damage(amount: int) -> void:
	if amount <= 0:
		return
	for c in _party:
		if c == null:
			continue
		c.damage(amount)
	if _dungeon_view != null:
		_dungeon_view.shake_camera(_DAMAGE_SHAKE_MAGNITUDE)
	if _hud != null:
		_hud.flash_damage()
	var cfg: AudioConfig = SoundManager.audio_config
	if cfg != null:
		SoundManager.play(cfg.pain_sound)
