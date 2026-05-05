extends GutTest

# Toast lives in the scene tree so its hide-timer can fire. add_child_autofree
# handles cleanup. show_message uses tr() under the hood, so we use known keys
# from strings.csv to verify resolution.

func _make_toast() -> Toast:
	var t := Toast.new()
	add_child_autofree(t)
	return t

func test_starts_hidden() -> void:
	var t := _make_toast()
	assert_false(t.visible)

func test_show_message_makes_visible_and_sets_text() -> void:
	var t := _make_toast()
	t.show_message("ui.feedback.no_effect", 1.0)
	assert_true(t.visible)
	assert_eq(t.text, "No effect")

func test_show_message_uses_translation_lookup() -> void:
	var t := _make_toast()
	t.show_message("ui.pickup.bar_full", 1.0)
	assert_eq(t.text, tr("ui.pickup.bar_full"))

func test_unknown_key_falls_back_to_key() -> void:
	var t := _make_toast()
	t.show_message("ui.does_not_exist", 1.0)
	assert_eq(t.text, "ui.does_not_exist")

func test_hides_after_duration() -> void:
	var t := _make_toast()
	t.show_message("ui.feedback.no_effect", 0.2)
	assert_true(t.visible)
	await get_tree().create_timer(0.4).timeout
	assert_false(t.visible)

func test_calling_show_message_again_resets_the_timer() -> void:
	var t := _make_toast()
	t.show_message("ui.feedback.no_effect", 0.2)
	# Wait past the original duration but call again before it expires.
	await get_tree().create_timer(0.1).timeout
	t.show_message("ui.feedback.no_effect", 0.4)
	# Past the original 0.2 cutoff but within the new 0.4 — still visible.
	await get_tree().create_timer(0.2).timeout
	assert_true(t.visible)
	# Past the new cutoff — hidden.
	await get_tree().create_timer(0.3).timeout
	assert_false(t.visible)
