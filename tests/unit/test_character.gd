extends GutTest

func _make_potion(effect: int = ItemData.EffectType.HEAL_HP, value: int = 30) -> ItemData:
	var data := ItemData.new()
	data.item_name = "test.potion"
	data.effect_type = effect
	data.effect_value = value
	return data

# -------------------------------------------------------
# create / defaults
# -------------------------------------------------------

func test_create_starts_at_full_hp_and_mp() -> void:
	var c := Character.create("test.warrior", 30, 5)
	assert_eq(c.max_hp, 30)
	assert_eq(c.current_hp, 30)
	assert_eq(c.max_mp, 5)
	assert_eq(c.current_mp, 5)

func test_create_clamps_max_hp_to_at_least_one() -> void:
	var c := Character.create("x", 0, 0)
	assert_eq(c.max_hp, 1)

func test_create_clamps_max_mp_to_at_least_zero() -> void:
	var c := Character.create("x", 10, -5)
	assert_eq(c.max_mp, 0)

# -------------------------------------------------------
# damage
# -------------------------------------------------------

func test_damage_reduces_current_hp() -> void:
	var c := Character.create("x", 30)
	c.damage(7)
	assert_eq(c.current_hp, 23)

func test_damage_floors_at_zero() -> void:
	var c := Character.create("x", 10)
	c.damage(50)
	assert_eq(c.current_hp, 0)

func test_damage_zero_or_negative_is_noop() -> void:
	var c := Character.create("x", 30)
	c.damage(0)
	c.damage(-5)
	assert_eq(c.current_hp, 30)

func test_damage_emits_changed() -> void:
	var c := Character.create("x", 30)
	watch_signals(c)
	c.damage(5)
	assert_signal_emitted(c, "changed")

# -------------------------------------------------------
# apply_item — heal HP
# -------------------------------------------------------

func test_apply_heal_hp_at_partial_hp_returns_true_and_heals() -> void:
	var c := Character.create("x", 30)
	c.damage(20)  # current = 10
	var ok := c.apply_item(_make_potion(ItemData.EffectType.HEAL_HP, 15))
	assert_true(ok)
	assert_eq(c.current_hp, 25)

func test_apply_heal_hp_at_full_hp_returns_false_and_does_nothing() -> void:
	var c := Character.create("x", 30)
	var ok := c.apply_item(_make_potion(ItemData.EffectType.HEAL_HP, 15))
	assert_false(ok)
	assert_eq(c.current_hp, 30)

func test_apply_heal_hp_clamps_to_max() -> void:
	var c := Character.create("x", 30)
	c.damage(5)  # current = 25
	c.apply_item(_make_potion(ItemData.EffectType.HEAL_HP, 100))
	assert_eq(c.current_hp, 30)

func test_apply_heal_hp_with_zero_effect_returns_false() -> void:
	var c := Character.create("x", 30)
	c.damage(10)
	var ok := c.apply_item(_make_potion(ItemData.EffectType.HEAL_HP, 0))
	assert_false(ok)

func test_apply_heal_emits_changed_only_on_success() -> void:
	var c := Character.create("x", 30)
	watch_signals(c)
	# At full HP — heal should be refused, no signal
	c.apply_item(_make_potion(ItemData.EffectType.HEAL_HP, 5))
	assert_signal_not_emitted(c, "changed")
	# After damage, heal succeeds, signal fires
	c.damage(10)
	c.apply_item(_make_potion(ItemData.EffectType.HEAL_HP, 5))
	assert_signal_emit_count(c, "changed", 2)  # damage + heal

# -------------------------------------------------------
# apply_item — heal MP
# -------------------------------------------------------

func test_apply_heal_mp_at_partial_mp_returns_true_and_restores() -> void:
	var c := Character.create("x", 10, 20)
	c.current_mp = 5
	var ok := c.apply_item(_make_potion(ItemData.EffectType.HEAL_MP, 8))
	assert_true(ok)
	assert_eq(c.current_mp, 13)

func test_apply_heal_mp_at_full_mp_returns_false() -> void:
	var c := Character.create("x", 10, 20)  # mp starts full
	var ok := c.apply_item(_make_potion(ItemData.EffectType.HEAL_MP, 5))
	assert_false(ok)

func test_apply_heal_mp_clamps_to_max() -> void:
	var c := Character.create("x", 10, 20)
	c.current_mp = 18
	c.apply_item(_make_potion(ItemData.EffectType.HEAL_MP, 100))
	assert_eq(c.current_mp, 20)

# -------------------------------------------------------
# apply_item — unsupported / nil
# -------------------------------------------------------

func test_apply_item_with_null_returns_false() -> void:
	var c := Character.create("x", 30)
	assert_false(c.apply_item(null))

func test_apply_unsupported_effect_returns_false() -> void:
	var c := Character.create("x", 30)
	c.damage(20)
	for effect in [
		ItemData.EffectType.NONE,
		ItemData.EffectType.STAT_BOOST,
		ItemData.EffectType.CURE_STATUS,
		ItemData.EffectType.DAMAGE,
		ItemData.EffectType.INFLICT_STATUS,
	]:
		var ok := c.apply_item(_make_potion(effect, 30))
		assert_false(ok, "expected effect %d to be refused" % effect)
	# HP must remain damaged — no effect applied through any of the above
	assert_eq(c.current_hp, 10)

# -------------------------------------------------------
# is_full_*
# -------------------------------------------------------

func test_is_full_hp_true_at_max() -> void:
	var c := Character.create("x", 30)
	assert_true(c.is_full_hp())

func test_is_full_hp_false_after_damage() -> void:
	var c := Character.create("x", 30)
	c.damage(1)
	assert_false(c.is_full_hp())

func test_is_full_mp_true_at_max() -> void:
	var c := Character.create("x", 1, 10)
	assert_true(c.is_full_mp())

func test_is_full_mp_false_when_below_max() -> void:
	var c := Character.create("x", 1, 10)
	c.current_mp = 5
	assert_false(c.is_full_mp())

# -------------------------------------------------------
# Translation
# -------------------------------------------------------

func test_get_display_name_resolves_known_key() -> void:
	var c := Character.create("character.placeholder.warrior", 1)
	assert_eq(c.get_display_name(), "Warrior")
