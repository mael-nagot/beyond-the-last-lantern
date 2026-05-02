class_name MovementPad
extends GridContainer

signal forward_pressed
signal backward_pressed
signal turn_left_pressed
signal turn_right_pressed
signal strafe_left_pressed
signal strafe_right_pressed

func _ready() -> void:
	for child in get_children():
		if child is Button:
			child.custom_minimum_size = Vector2(80, 80)

	$BtnTurnLeft.pressed.connect(func(): turn_left_pressed.emit())
	$BtnForward.pressed.connect(func(): forward_pressed.emit())
	$BtnTurnRight.pressed.connect(func(): turn_right_pressed.emit())
	$BtnStrafeLeft.pressed.connect(func(): strafe_left_pressed.emit())
	$BtnBackward.pressed.connect(func(): backward_pressed.emit())
	$BtnStrafeRight.pressed.connect(func(): strafe_right_pressed.emit())
