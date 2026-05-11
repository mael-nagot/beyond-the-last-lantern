class_name SecretWallInstance
extends RefCounted

# Runtime state for a single placed secret wall. Edge-based like a
# door: the wall lives on the boundary between two adjacent floor
# cells (1-wide corridor cells on both ends). Unlike a door, this
# instance is pure metadata — there is no `opened` / `discovered`
# flag because the wall NEVER blocks movement and the renderer ALWAYS
# draws the wall quads on this edge. The player walks back and forth
# freely; the illusion of a wall stays.
#
# The cells are stored in canonical (sorted) order so the same edge
# never gets indexed twice. The helpers mirror DoorInstance for
# consistency with the existing edge-based plumbing.

var cell_a: Vector2i
var cell_b: Vector2i

static func canonical_pair(a: Vector2i, b: Vector2i) -> Array:
	if a.x < b.x or (a.x == b.x and a.y < b.y):
		return [a, b]
	return [b, a]

static func edge_key(a: Vector2i, b: Vector2i) -> String:
	var pair: Array = canonical_pair(a, b)
	var lo: Vector2i = pair[0]
	var hi: Vector2i = pair[1]
	return "%d,%d|%d,%d" % [lo.x, lo.y, hi.x, hi.y]

static func create(a: Vector2i, b: Vector2i) -> SecretWallInstance:
	var inst := SecretWallInstance.new()
	var pair: Array = canonical_pair(a, b)
	inst.cell_a = pair[0]
	inst.cell_b = pair[1]
	return inst

# (1, 0) for an east-west corridor, (0, 1) for a north-south corridor.
# Always non-negative because cells are canonically sorted.
func axis() -> Vector2i:
	return cell_b - cell_a
