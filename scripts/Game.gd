extends Node3D

var _player_controller = null
var _hud = null
var _dungeon_view = null
var _generator: LevelGenerator = null
var _party: Array[Character] = []

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
	# A non-interactable door (lever-only) that ISN'T key-locked
	# (or has been unlocked above) needs feedback rather than a
	# toggle. The Area3D is always built so the click registers.
	if not door.data.interactable and not door.unlocked:
		_play_locked_feedback(door.data)
		return
	door.opened = not door.opened
	SoundManager.play(door.data.interact_sound)
	if _dungeon_view != null:
		_dungeon_view.rebuild_doors()
		# Lever sprites mirror their linked door's state via
		# get_visual_opened() — refresh cell-bound objects so any
		# levers paired with this door swap their sprite too.
		if not door.linked_levers.is_empty():
			_dungeon_view.rebuild_objects()

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
	# Small camera jolt — softer than a wall bump, just enough to
	# read as "you tried, it didn't budge".
	if _dungeon_view != null:
		_dungeon_view.shake_camera(0.4)

func _pull_lever(lever: LeverInstance) -> void:
	# A non-interactable lever (rusted shut, magically sealed, ...)
	# gives feedback instead of pulling — same contract as doors.
	if not lever.data.interactable:
		_play_locked_feedback(lever.data)
		return
	# Pulling flips every linked door's state. The lever's own visual
	# is derived (mirrors the doors), so we don't store its own bool.
	# 2b ships with one linked door per lever; multi-door pairing
	# falls out naturally when the list grows.
	for door in lever.linked_doors:
		if door != null:
			door.opened = not door.opened
	SoundManager.play(lever.data.interact_sound)
	if _dungeon_view != null:
		_dungeon_view.rebuild_doors()
		_dungeon_view.rebuild_objects()

func _open_chest(instance: ObjectInstance) -> void:
	if not instance.data.interactable:
		_play_locked_feedback(instance.data)
		return
	if not instance.opened:
		_roll_chest_loot(instance)
		instance.opened = true
		SoundManager.play(instance.data.interact_sound)
		if _dungeon_view != null:
			_dungeon_view.rebuild_objects()
	if instance.has_remaining_loot():
		if _hud != null and _hud.loot_popup != null:
			_hud.loot_popup.open(instance)

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
	match action:
		"forward":     _player_controller.move_forward()
		"backward":    _player_controller.move_backward()
		"turn_left":   _player_controller.turn_left()
		"turn_right":  _player_controller.turn_right()
		"strafe_left": _player_controller.strafe_left()
		"strafe_right":_player_controller.strafe_right()
	_update_map()
	_update_pickup_prompt()

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
