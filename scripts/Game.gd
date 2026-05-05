extends Node3D

var _player_controller = null
var _hud = null
var _dungeon_view = null
var _generator: LevelGenerator = null

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

	_update_map()
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
	var transferred: int = _hud.item_bar.pickup_from(cell)
	if _dungeon_view != null:
		_dungeon_view.rebuild_items()
	if transferred == 0:
		_hud.pickup_prompt.flash_bar_full()
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
	_update_map()
	_update_pickup_prompt()

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
