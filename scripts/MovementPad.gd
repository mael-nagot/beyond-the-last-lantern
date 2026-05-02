class_name MovementPad
extends GridContainer

signal forward_pressed
signal backward_pressed
signal turn_left_pressed
signal turn_right_pressed
signal strafe_left_pressed
signal strafe_right_pressed

func _ready() -> void:
	var screen     = get_viewport().get_visible_rect().size
	var short_side = min(screen.x, screen.y)
	var is_portrait = screen.y > screen.x
	var btn_size   = short_side * (0.12 if is_portrait else 0.13)

	for child in get_children():
		if child is Button:
			child.custom_minimum_size = Vector2(btn_size, btn_size)

	$BtnTurnLeft.pressed.connect(func(): turn_left_pressed.emit())
	$BtnForward.pressed.connect(func(): forward_pressed.emit())
	$BtnTurnRight.pressed.connect(func(): turn_right_pressed.emit())
	$BtnStrafeLeft.pressed.connect(func(): strafe_left_pressed.emit())
	$BtnBackward.pressed.connect(func(): backward_pressed.emit())
	$BtnStrafeRight.pressed.connect(func(): strafe_right_pressed.emit())
