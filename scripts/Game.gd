extends Node3D

var _player_controller = null

func _ready() -> void:
	var dungeon_view      = $DungeonView
	var player_controller = $DungeonView/PlayerController
	var hud               = $HUD

	if dungeon_view == null or player_controller == null or hud == null:
		push_error("Required node missing")
		return

	var gen = LevelGenerator.new()
	add_child(gen)
	gen.generate()

	dungeon_view.biome = load("res://assets/biomes/forest.tres")
	dungeon_view.setup(gen)
	player_controller.setup(dungeon_view, gen)

	_player_controller = player_controller

	# Movement pad signals
	var pad = hud.movement_pad
	pad.forward_pressed.connect(player_controller.move_forward)
	pad.backward_pressed.connect(player_controller.move_backward)
	pad.turn_left_pressed.connect(player_controller.turn_left)
	pad.turn_right_pressed.connect(player_controller.turn_right)
	pad.strafe_left_pressed.connect(player_controller.strafe_left)
	pad.strafe_right_pressed.connect(player_controller.strafe_right)

func _input(event: InputEvent) -> void:
	if _player_controller == null:
		return
	if not event is InputEventKey or not event.pressed:
		return
	match event.keycode:
		KEY_W, KEY_UP:   _player_controller.move_forward()
		KEY_S, KEY_DOWN: _player_controller.move_backward()
		KEY_Q:           _player_controller.turn_left()
		KEY_E:           _player_controller.turn_right()
		KEY_A:           _player_controller.strafe_left()
		KEY_D:           _player_controller.strafe_right()
