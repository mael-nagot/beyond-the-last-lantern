class_name MapData
extends RefCounted

var explored: Dictionary = {}   # Vector2i -> true
var generator: LevelGenerator

func setup(gen: LevelGenerator) -> void:
	generator = gen

func reveal_around(pos: Vector2i) -> void:
	# Reveals the 8 surrounding tiles, EXCEPT where a secret wall sits
	# between the player and the neighbour. A secret wall blocks the
	# orthogonal cell it hides AND the two diagonals on that side —
	# in a bent corridor the diagonal cell can itself be the gated
	# floor tile, and revealing the bend would leak the secret. Other
	# (regular) walls do NOT block reveal: the player learns the
	# corridor shape by seeing where the walls are.
	explored[pos] = true
	var blocked_orthogonals: Dictionary = {}  # Vector2i -> true
	for d in [Vector2i(0,-1), Vector2i(0,1), Vector2i(-1,0), Vector2i(1,0)]:
		if generator.get_secret_wall_at_edge(pos, pos + d) != null:
			blocked_orthogonals[d] = true
	var neighbours: Array = [
		Vector2i(0,-1), Vector2i(0,1), Vector2i(-1,0), Vector2i(1,0),
		Vector2i(-1,-1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(1,1),
	]
	for d in neighbours:
		var is_diagonal: bool = d.x != 0 and d.y != 0
		if is_diagonal:
			# Block a diagonal if EITHER of its component orthogonals
			# is blocked — conservative rule that prevents leaking the
			# bend cell behind a secret wall in a turning corridor.
			if blocked_orthogonals.has(Vector2i(d.x, 0)) or blocked_orthogonals.has(Vector2i(0, d.y)):
				continue
		else:
			if blocked_orthogonals.has(d):
				continue
		var n: Vector2i = pos + d
		if generator.get_cell(n.x, n.y) != null:
			explored[n] = true

func is_explored(pos: Vector2i) -> bool:
	return explored.has(pos)

func reveal_all() -> void:
	for x in range(generator.grid_width):
		for y in range(generator.grid_height):
			explored[Vector2i(x, y)] = true
