extends Node

var _player_controller = null

func _ready() -> void:
	var dungeon_view      = $DungeonView
	var player_controller = $DungeonView/PlayerController

	if dungeon_view == null:
		push_error("DungeonView node not found")
		return
	if player_controller == null:
		push_error("PlayerController node not found")
		return

	var gen = LevelGenerator.new()
	add_child(gen)
	gen.generate()

	dungeon_view.biome = load("res://assets/biomes/forest.tres")
	dungeon_view.setup(gen)
	player_controller.setup(dungeon_view, gen)

	_player_controller = player_controller

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
