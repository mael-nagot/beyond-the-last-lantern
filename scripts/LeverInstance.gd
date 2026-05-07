class_name LeverInstance
extends ObjectInstance

# A clickable lever — cell-bound (lives on GridCell.object exactly
# like a chest). 2b follow-up: levers carry their OWN pulled state
# instead of mirroring linked doors. Each click toggles `pulled`,
# linked doors then re-derive their opened state via AND / OR over
# their linked_levers' pulled values (see DoorInstance.lever_logic).
#
# Why a real bool here instead of "any linked door open" like 2b:
# - With M:N pairing one lever can be linked to multiple doors that
#   each need different lever combos to open. The lever's visual
#   should track the LEVER, not any one door — its own up/down state.
# - AND-doors need to know which subset of levers is pulled even
#   when the door stays closed (partial-pulled hint). That requires
#   per-lever state.

var linked_doors: Array = []  # Array[DoorInstance] — typed at runtime to avoid cyclic typed-array trouble
var pulled: bool = false

static func create_lever(p_data: ObjectData) -> LeverInstance:
	var inst := LeverInstance.new()
	inst.data = p_data
	return inst

func is_lever() -> bool:
	return true

# Flip the pulled state. Game.gd calls this on click and then asks
# every linked door to recompute its opened state.
func toggle() -> void:
	pulled = not pulled

# Renderer-facing predicate. Lever sprite shows opened_sprite when
# pulled, closed_sprite otherwise. No longer mirrors door state.
func get_visual_opened() -> bool:
	return pulled
