class_name Character
extends RefCounted

# Minimal party-member state used by Phase 7 Task 4. Phase 9 will extend
# this into a full CharacterData resource (stats, equipment, spells).

signal changed

var name_key: String = ""  # translation key (e.g. "character.placeholder.warrior")
var current_hp: int = 1
var max_hp: int = 1
var current_mp: int = 0
var max_mp: int = 0

static func create(p_name_key: String, p_max_hp: int, p_max_mp: int = 0) -> Character:
	var c := Character.new()
	c.name_key = p_name_key
	c.max_hp = max(1, p_max_hp)
	c.current_hp = c.max_hp
	c.max_mp = max(0, p_max_mp)
	c.current_mp = c.max_mp
	return c

func get_display_name() -> String:
	return tr(name_key)

func is_full_hp() -> bool:
	return current_hp >= max_hp

func is_full_mp() -> bool:
	return current_mp >= max_mp

func damage(amount: int) -> void:
	if amount <= 0:
		return
	current_hp = max(0, current_hp - amount)
	changed.emit()

# Returns true if the item produced any effect on this character. Returns
# false if the item type is unsupported here, or if the effect would be
# wasted (e.g. healing at full HP).
func apply_item(data: ItemData) -> bool:
	if data == null:
		return false
	match data.effect_type:
		ItemData.EffectType.HEAL_HP:
			if is_full_hp() or data.effect_value <= 0:
				return false
			current_hp = min(max_hp, current_hp + data.effect_value)
			changed.emit()
			return true
		ItemData.EffectType.HEAL_MP:
			if is_full_mp() or data.effect_value <= 0:
				return false
			current_mp = min(max_mp, current_mp + data.effect_value)
			changed.emit()
			return true
		_:
			# STAT_BOOST, CURE_STATUS, DAMAGE, INFLICT_STATUS, NONE — not
			# supported on a friendly target in Task 4. Refuse the drop so
			# the bar stack isn't consumed.
			return false
