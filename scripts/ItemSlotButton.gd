class_name ItemSlotButton
extends TextureButton

# A bar slot's clickable area. Doubles as the drag source for the item
# living in this slot. The owning ItemBar sets `slot_index` and
# `bar_ref` on creation so the button can fetch its current contents
# at drag time.

const DRAG_TYPE := "item"

var slot_index: int = -1
var bar_ref: ItemBar = null

func _get_drag_data(_at_position: Vector2) -> Variant:
	var payload := build_drag_payload()
	if payload.is_empty():
		return null
	set_drag_preview(_make_drag_preview(payload["instance"]))
	return payload

# Pure helper so tests can verify the payload shape without triggering
# the engine's drag-preview assertion (set_drag_preview only works while
# a real drag is in progress).
func build_drag_payload() -> Dictionary:
	if bar_ref == null:
		return {}
	var instance: ItemInstance = bar_ref.get_slot(slot_index)
	if instance == null or instance.data == null:
		return {}
	return {
		"type": DRAG_TYPE,
		"slot_index": slot_index,
		"instance": instance,
	}

func _make_drag_preview(instance: ItemInstance) -> Control:
	# Wrap the preview so we can center it on the cursor — set_drag_preview
	# anchors the wrapper's origin (top-left) at the cursor by default.
	var wrapper := Control.new()
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.size = Vector2.ZERO

	var preview := TextureRect.new()
	preview.texture = instance.data.icon
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = size
	preview.size = size
	preview.position = -size * 0.5
	preview.modulate = Color(1, 1, 1, 0.85)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(preview)
	return wrapper
