class_name Toast
extends Label

# Tiny self-hiding feedback label. Use Hud.show_toast(key, duration) to
# flash a translated message. Hidden by default.

const DEFAULT_DURATION := 1.2

var _hide_timer: SceneTreeTimer = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_theme_color_override("font_color", Color(1, 1, 1, 1))
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	add_theme_constant_override("outline_size", 6)

func show_message(translation_key: String, duration: float = DEFAULT_DURATION) -> void:
	text = tr(translation_key)
	visible = true
	if _hide_timer != null:
		_hide_timer.timeout.disconnect(_on_hide_timeout)
	_hide_timer = get_tree().create_timer(duration)
	_hide_timer.timeout.connect(_on_hide_timeout)

func _on_hide_timeout() -> void:
	_hide_timer = null
	visible = false
