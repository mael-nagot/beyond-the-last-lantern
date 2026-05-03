class_name MapData
extends RefCounted

var explored: Dictionary = {}   # Vector2i -> true
var generator: LevelGenerator

func setup(gen: LevelGenerator) -> void:
	generator = gen

func reveal_around(pos: Vector2i) -> void:
	explored[pos] = true
	for d in [Vector2i(0,-1), Vector2i(0,1), Vector2i(-1,0), Vector2i(1,0),
			   Vector2i(-1,-1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(1,1)]:
		var n = pos + d
		if generator.get_cell(n.x, n.y) != null:
			explored[n] = true

func is_explored(pos: Vector2i) -> bool:
	return explored.has(pos)

func reveal_all() -> void:
	for x in range(generator.grid_width):
		for y in range(generator.grid_height):
			explored[Vector2i(x, y)] = true
