extends GutTest

# PickupPrompt extends Button. Button needs to be in the scene tree so
# its theme defaults resolve and _ready() runs. add_child_autofree
# ensures cleanup between tests.

func _make_prompt() -> PickupPrompt:
	var prompt := PickupPrompt.new()
	add_child_autofree(prompt)
	return prompt

# -------------------------------------------------------
# Visibility driven by set_count
# -------------------------------------------------------

func test_starts_hidden() -> void:
	var prompt := _make_prompt()
	assert_false(prompt.visible)

func test_set_count_zero_hides() -> void:
	var prompt := _make_prompt()
	prompt.set_count(3)
	assert_true(prompt.visible)
	prompt.set_count(0)
	assert_false(prompt.visible)

func test_set_count_positive_shows() -> void:
	var prompt := _make_prompt()
	prompt.set_count(2)
	assert_true(prompt.visible)

func test_set_count_one_still_shows() -> void:
	var prompt := _make_prompt()
	prompt.set_count(1)
	assert_true(prompt.visible)

# -------------------------------------------------------
# Label content
# -------------------------------------------------------

func test_label_includes_localized_pickup_text() -> void:
	var prompt := _make_prompt()
	prompt.set_count(2)
	assert_string_contains(prompt.text, tr(PickupPrompt.PROMPT_KEY))

func test_label_includes_count_when_above_one() -> void:
	var prompt := _make_prompt()
	prompt.set_count(7)
	assert_string_contains(prompt.text, "7")

func test_label_omits_count_section_when_count_is_zero() -> void:
	var prompt := _make_prompt()
	prompt.set_count(0)
	# Label still has the base text (used when shown via flash_bar_full
	# fallback paths), but no parenthesised number.
	assert_false(prompt.text.contains("("), "expected no '(' in label, got: %s" % prompt.text)

# -------------------------------------------------------
# flash_bar_full
# -------------------------------------------------------

func test_flash_bar_full_makes_prompt_visible() -> void:
	var prompt := _make_prompt()
	prompt.set_count(0)
	prompt.flash_bar_full()
	assert_true(prompt.visible)

func test_flash_bar_full_shows_bar_full_text() -> void:
	var prompt := _make_prompt()
	prompt.flash_bar_full()
	assert_eq(prompt.text, tr(PickupPrompt.BAR_FULL_KEY))

func test_flash_bar_full_overrides_count_text() -> void:
	var prompt := _make_prompt()
	prompt.set_count(5)
	prompt.flash_bar_full()
	# Even with count > 0, bar_full takes priority while flashing.
	assert_eq(prompt.text, tr(PickupPrompt.BAR_FULL_KEY))

func test_flash_clears_after_timer_when_count_is_zero() -> void:
	var prompt := _make_prompt()
	prompt.set_count(0)
	prompt.flash_bar_full()
	assert_true(prompt.visible)
	await get_tree().create_timer(PickupPrompt.BAR_FULL_FLASH_SECONDS + 0.2).timeout
	assert_false(prompt.visible)
	assert_eq(prompt.text, tr(PickupPrompt.PROMPT_KEY))

func test_flash_returns_to_count_text_after_timer() -> void:
	var prompt := _make_prompt()
	prompt.set_count(3)
	prompt.flash_bar_full()
	await get_tree().create_timer(PickupPrompt.BAR_FULL_FLASH_SECONDS + 0.2).timeout
	assert_true(prompt.visible)
	assert_string_contains(prompt.text, tr(PickupPrompt.PROMPT_KEY))
	assert_string_contains(prompt.text, "3")

# -------------------------------------------------------
# Translation keys are wired to strings.csv
# -------------------------------------------------------

func test_pickup_translation_key_resolves() -> void:
	assert_eq(tr("ui.pickup.prompt"), "Pick up")

func test_bar_full_translation_key_resolves() -> void:
	assert_eq(tr("ui.pickup.bar_full"), "Bag full")
