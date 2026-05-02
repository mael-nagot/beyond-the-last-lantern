class_name CharacterSlot
extends BoxContainer

signal portrait_clicked
signal attack_pressed
signal spell_pressed
signal defense_pressed

@onready var portrait    : TextureButton = $LeftSide/Portrait
@onready var hp_bar      : ProgressBar   = $LeftSide/HPBar
@onready var mp_bar      : ProgressBar   = $LeftSide/MPBar
@onready var btn_attack  : Button        = $ActionButtons/BtnAttack
@onready var btn_spell   : Button        = $ActionButtons/BtnSpell
@onready var btn_defense : Button        = $ActionButtons/BtnDefense

func _ready() -> void:
	portrait.custom_minimum_size    = Vector2(64, 64)
	btn_attack.custom_minimum_size  = Vector2(50, 40)
	btn_spell.custom_minimum_size   = Vector2(50, 40)
	btn_defense.custom_minimum_size = Vector2(50, 40)

	# Thin progress bars with no text
	hp_bar.custom_minimum_size = Vector2(64, 8)
	hp_bar.show_percentage     = false
	mp_bar.custom_minimum_size = Vector2(64, 8)
	mp_bar.show_percentage     = false

	# Style HP bar — green with dark background
	var hp_bg = StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.0, 0.0, 0.0, 0.5)
	hp_bg.set_corner_radius_all(2)
	hp_bar.add_theme_stylebox_override("background", hp_bg)

	var hp_fill = StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.2, 0.8, 0.2)
	hp_fill.set_corner_radius_all(2)
	hp_bar.add_theme_stylebox_override("fill", hp_fill)

	# Style MP bar — blue with dark background
	var mp_bg = StyleBoxFlat.new()
	mp_bg.bg_color = Color(0.0, 0.0, 0.0, 0.5)
	mp_bg.set_corner_radius_all(2)
	mp_bar.add_theme_stylebox_override("background", mp_bg)

	var mp_fill = StyleBoxFlat.new()
	mp_fill.bg_color = Color(0.2, 0.4, 0.9)
	mp_fill.set_corner_radius_all(2)
	mp_bar.add_theme_stylebox_override("fill", mp_fill)

	portrait.pressed.connect(func():    portrait_clicked.emit())
	btn_attack.pressed.connect(func():  attack_pressed.emit())
	btn_spell.pressed.connect(func():   spell_pressed.emit())
	btn_defense.pressed.connect(func(): defense_pressed.emit())

func set_hp(current: int, max_value: int) -> void:
	hp_bar.max_value = max_value
	hp_bar.value     = current

func set_mp(current: int, max_value: int) -> void:
	mp_bar.max_value = max_value
	mp_bar.value     = current

func set_portrait(texture: Texture2D) -> void:
	portrait.texture_normal = texture
