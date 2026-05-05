class_name PickupPrompt
extends Button

const PROMPT_KEY := "ui.pickup.prompt"
const BAR_FULL_KEY := "ui.pickup.bar_full"
const BAR_FULL_FLASH_SECONDS := 1.5

var _count: int = 0
var _showing_bar_full: bool = false
var _bar_full_timer: SceneTreeTimer = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_refresh_text()

func set_count(count: int) -> void:
	_count = count
	visible = count > 0 or _showing_bar_full
	_refresh_text()

func flash_bar_full() -> void:
	_showing_bar_full = true
	visible = true
	_refresh_text()
	if _bar_full_timer != null:
		_bar_full_timer.timeout.disconnect(_clear_bar_full)
	_bar_full_timer = get_tree().create_timer(BAR_FULL_FLASH_SECONDS)
	_bar_full_timer.timeout.connect(_clear_bar_full)

func _clear_bar_full() -> void:
	_showing_bar_full = false
	_bar_full_timer = null
	visible = _count > 0
	_refresh_text()

func _refresh_text() -> void:
	if _showing_bar_full:
		text = tr(BAR_FULL_KEY)
	elif _count > 0:
		text = "%s (%d)" % [tr(PROMPT_KEY), _count]
	else:
		text = tr(PROMPT_KEY)
