class_name DamageFlash
extends ColorRect

# Full-rect red overlay that briefly tints the screen when the party
# takes damage. Phase 8 Task 3 — Subtask A.
#
# Built programmatically by HUD.gd (no scene dependency, mirrors the
# Toast / PickupPrompt pattern). Sits as a child of HUDRoot ABOVE
# every other HUD element, so the tint covers both the dungeon view
# (the SubViewportContainer is on a layer below) and the rest of the
# HUD. mouse_filter = IGNORE so it never blocks input — drag-drop,
# button presses, and map clicks pass through.

const FLASH_PEAK_ALPHA: float = 0.4
const FLASH_RAMP_UP_DURATION: float = 0.05
const FLASH_RAMP_DOWN_DURATION: float = 0.25

var _flash_tween: Tween = null

func _ready() -> void:
	color = Color(0.85, 0.05, 0.05, FLASH_PEAK_ALPHA)
	# Default invisible — tween modulates alpha up then back to 0.
	modulate = Color(1, 1, 1, 0.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

# Trigger one flash. Calling rapid-fire kills any in-flight tween so
# the new flash always starts from alpha 0 — keeps successive hits
# visually punchy without compounding the brightness.
func flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	modulate.a = 0.0
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "modulate:a", 1.0, FLASH_RAMP_UP_DURATION)
	_flash_tween.tween_property(self, "modulate:a", 0.0, FLASH_RAMP_DOWN_DURATION)
