class_name CharacterSlot
extends BoxContainer

signal portrait_clicked
signal attack_pressed
signal spell_pressed
signal defense_pressed
signal item_consumed(slot_index: int)
signal item_rejected(slot_index: int)

var character: Character = null

@onready var portrait_frame : Panel         = $LeftSide/PortraitFrame
@onready var portrait       : TextureButton = $LeftSide/PortraitFrame/Portrait
@onready var hp_bar         : ProgressBar   = $LeftSide/HPBar
@onready var mp_bar         : ProgressBar   = $LeftSide/MPBar
@onready var name_label     : Label         = $LeftSide/NameLabel
@onready var btn_attack     : Button        = $ActionButtons/BtnAttack
@onready var btn_spell      : Button        = $ActionButtons/BtnSpell
@onready var btn_defense    : Button        = $ActionButtons/BtnDefense

func _ready() -> void:
	var screen      = get_viewport().get_visible_rect().size
	var short_side  = min(screen.x, screen.y)
	var is_portrait = screen.y > screen.x
	var unit        = short_side * (0.012 if is_portrait else 0.01)

	# Portrait frame and portrait
	portrait_frame.custom_minimum_size = Vector2(unit * 12, unit * 12)
	var frame_style = StyleBoxFlat.new()
	frame_style.bg_color     = Color(0.0, 0.0, 0.0, 0.3)
	frame_style.border_color = Color(1.0, 1.0, 1.0, 0.2)
	frame_style.set_border_width_all(1)
	frame_style.set_corner_radius_all(4)
	frame_style.set_content_margin_all(2)
	portrait_frame.add_theme_stylebox_override("panel", frame_style)

	portrait.custom_minimum_size = Vector2(unit * 11, unit * 11)
	portrait.anchors_preset      = Control.PRESET_FULL_RECT

	# Action buttons
	btn_attack.custom_minimum_size  = Vector2(unit * 9, unit * 7)
	btn_spell.custom_minimum_size   = Vector2(unit * 9, unit * 7)
	btn_defense.custom_minimum_size = Vector2(unit * 9, unit * 7)

	# HP bar
	hp_bar.custom_minimum_size = Vector2(unit * 12, max(unit * 1.0, 8))
	hp_bar.show_percentage     = false

	var hp_bg = StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.0, 0.0, 0.0, 0.5)
	hp_bg.set_corner_radius_all(2)
	hp_bar.add_theme_stylebox_override("background", hp_bg)

	var hp_fill = StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.85, 0.15, 0.15)
	hp_fill.set_corner_radius_all(2)
	hp_bar.add_theme_stylebox_override("fill", hp_fill)

	# MP bar
	mp_bar.custom_minimum_size = Vector2(unit * 12, max(unit * 1.0, 8))
	mp_bar.show_percentage     = false

	var mp_bg = StyleBoxFlat.new()
	mp_bg.bg_color = Color(0.0, 0.0, 0.0, 0.5)
	mp_bg.set_corner_radius_all(2)
	mp_bar.add_theme_stylebox_override("background", mp_bg)

	var mp_fill = StyleBoxFlat.new()
	mp_fill.bg_color = Color(0.2, 0.4, 0.9)
	mp_fill.set_corner_radius_all(2)
	mp_bar.add_theme_stylebox_override("fill", mp_fill)

	# Name label
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", max(int(unit * 1.5), 12))
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.8))
	name_label.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Drag-and-drop: the slot's portrait, bars, name, and gaps should accept
	# item drops; the action buttons should NOT (they remain MOUSE_FILTER_STOP
	# so drops there fail with the can't-drop cursor and don't bubble to the
	# slot's _can_drop_data).
	mouse_filter = Control.MOUSE_FILTER_STOP
	portrait.mouse_filter    = Control.MOUSE_FILTER_PASS
	hp_bar.mouse_filter      = Control.MOUSE_FILTER_PASS
	mp_bar.mouse_filter      = Control.MOUSE_FILTER_PASS
	name_label.mouse_filter  = Control.MOUSE_FILTER_PASS
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_PASS

	# Signals
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

func set_character_name(char_name: String) -> void:
	name_label.text = char_name

func bind(c: Character) -> void:
	if character != null and character.changed.is_connected(_refresh_from_character):
		character.changed.disconnect(_refresh_from_character)
	character = c
	if character != null:
		character.changed.connect(_refresh_from_character)
	_refresh_from_character()

func _refresh_from_character() -> void:
	if character == null:
		return
	set_hp(character.current_hp, character.max_hp)
	set_mp(character.current_mp, character.max_mp)
	set_character_name(character.get_display_name())

# -------------------------------------------------------
# Drag & drop target
# -------------------------------------------------------

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if character == null:
		return false
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if data.get("type") != ItemSlotButton.DRAG_TYPE:
		return false
	var instance = data.get("instance")
	if not (instance is ItemInstance) or instance.data == null:
		return false
	# Ask the character if the effect would do anything; if not, reject
	# the drop so the bar stack isn't consumed.
	return _would_apply(instance.data)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var instance: ItemInstance = data.get("instance")
	var slot_index: int = data.get("slot_index", -1)
	if instance == null or instance.data == null or character == null:
		item_rejected.emit(slot_index)
		SoundManager.play_negative()
		return
	if character.apply_item(instance.data):
		item_consumed.emit(slot_index)
		SoundManager.play(instance.data.use_sound)
	else:
		item_rejected.emit(slot_index)
		SoundManager.play_negative()

# Dry-run check matching Character.apply_item's accept-conditions, used
# from _can_drop_data so a wasteful drop is refused before the drag ends.
func _would_apply(data: ItemData) -> bool:
	if character == null or data == null:
		return false
	match data.effect_type:
		ItemData.EffectType.HEAL_HP:
			return not character.is_full_hp() and data.effect_value > 0
		ItemData.EffectType.HEAL_MP:
			return not character.is_full_mp() and data.effect_value > 0
		_:
			return false
