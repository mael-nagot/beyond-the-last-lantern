class_name Projectile
extends RefCounted

# A single projectile in flight. Phase 8 Task 3 follow-up.
#
# Pure trajectory — no game logic, no node access. Tracks a continuous
# float position in grid-cell coordinates, advancing each tick by
# `direction * speed * delta`. The owning ProjectileTrapInstance handles
# wall collision, player-hit detection, and despawn.
#
# Direction is always axis-aligned (one of the 4 cardinals), so the
# projectile moves along a single axis and cell-transition tracking is
# trivial. `cells_entered_this_tick()` returns every new cell the
# projectile crossed into since the last tick — handles the rare case
# where a very fast projectile at low frame rate skips a cell.

var direction: Vector2i
var speed: float
# Continuous position in grid-cell units. The centre of cell (x, y)
# is at float position (x, y). The projectile starts near the wall
# face and moves in `direction`.
var position: Vector2
# Latched true after the first player-hit so a single flight never
# deals damage twice (the projectile passes through the player and
# keeps flying until hitting a wall).
var has_hit_player: bool = false

var _previous_cell: Vector2i


static func create(p_position: Vector2, p_direction: Vector2i, p_speed: float) -> Projectile:
	var proj := Projectile.new()
	proj.position = p_position
	proj.direction = p_direction
	proj.speed = p_speed
	proj._previous_cell = proj.get_cell()
	return proj


func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	_previous_cell = get_cell()
	position += Vector2(direction) * speed * delta


func get_cell() -> Vector2i:
	return Vector2i(roundi(position.x), roundi(position.y))


# Returns every new cell entered since the last tick, in travel order.
# Empty when the projectile hasn't crossed a cell boundary. Handles
# multi-cell jumps (high speed / low fps) by walking from
# _previous_cell + direction to current cell inclusive.
func cells_entered_this_tick() -> Array[Vector2i]:
	var current := get_cell()
	if current == _previous_cell:
		return []
	var result: Array[Vector2i] = []
	var dist := absi(current.x - _previous_cell.x) + absi(current.y - _previous_cell.y)
	for i in range(1, dist + 1):
		result.append(_previous_cell + direction * i)
	return result
