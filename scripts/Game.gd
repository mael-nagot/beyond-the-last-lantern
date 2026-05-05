extends Node3D

var _player_controller = null
var _hud = null

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

	var pad = hud.movement_pad
	pad.forward_pressed.connect(_on_move.bind("forward"))
	pad.backward_pressed.connect(_on_move.bind("backward"))
	pad.turn_left_pressed.connect(_on_move.bind("turn_left"))
	pad.turn_right_pressed.connect(_on_move.bind("turn_right"))
	pad.strafe_left_pressed.connect(_on_move.bind("strafe_left"))
	pad.strafe_right_pressed.connect(_on_move.bind("strafe_right"))

	_update_map()

func _on_move(action: String) -> void:
	match action:
		"forward":     _player_controller.move_forward()
		"backward":    _player_controller.move_backward()
		"turn_left":   _player_controller.turn_left()
		"turn_right":  _player_controller.turn_right()
		"strafe_left": _player_controller.strafe_left()
		"strafe_right":_player_controller.strafe_right()
	_update_map()

func _update_map() -> void:
	if _hud and _player_controller:
		_hud.update_player_on_map(
			_player_controller.grid_pos,
			PlayerController.DIR_VECTORS[_player_controller.facing]
		)

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
	_update_map()
