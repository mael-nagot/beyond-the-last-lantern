class_name SceneryData
extends Resource

## Template for a walkable-area scenery sprite — trees, flowers,
## mushrooms, rocks. Scenery sits on FLOOR cells INSIDE the dungeon
## (unlike `FillerData`, which sits on WALL cells in outdoor biomes).
##
## Scenery is pure decoration: it never carries loot, never has an
## interactive state, never animates. The only behavioural knob is
## `walkable` — non-walkable scenery (trees, big rocks) blocks the
## cell like a chest; walkable scenery (flowers, grass tufts) lets
## the player walk through.

## Translation key for the editor / debug label. Reserved for future
## map-cursor / bestiary use. Convention: `scenery.<biome>.<id>.name`.
@export var name_key: String = ""

## Translation key for an editor / debug description.
## Convention: `scenery.<biome>.<id>.description`.
@export_multiline var description_key: String = ""

@export_group("Behaviour")
## When true (default): the cell stays walkable, player can step
## through (flowers, ferns, grass tufts).
## When false: the cell becomes blocked (trees, big rocks) and the
## level generator runs a BFS reachability check to make sure the
## tree never severs the path from entrance to exit / chest / lever /
## key / item / teleporter.
@export var walkable: bool = true

@export_group("Art")
## The sprite texture. Transparent background expected — alpha-scissor
## discards transparent pixels so silhouettes read cleanly against
## the biome. Set Filter = Nearest on the import settings to keep
## pixel art crisp.
@export var texture: Texture2D

## Real-world height of the sprite, in metres. The renderer derives
## `pixel_size = world_height / texture_height` so swapping a 256px
## tree for a 512px tree doesn't change its on-screen size — the
## designer controls real-world size here regardless of PNG resolution.
## Typical values: trees 3.5–5.0, bushes 0.6–1.2, flowers 0.2–0.5.
@export var world_height: float = 1.0

## Vertical offset added to the sprite's centre, in metres. The
## renderer anchors the sprite so its bottom sits at floor level
## (y = 0) before applying y_offset.
## Positive shifts the whole sprite up.
## Negative pushes it into the floor (useful when the source PNG has
## transparent padding below the trunk / stem that should sit
## underground).
@export var y_offset: float = 0.0

## Shifts the sprite off the cell centre, toward whichever cardinal
## side the player is currently on. 0.0 = always centred (right for
## small flat decorations like flowers). For a tree, ~1.0–1.5 makes
## it sit close to the player's side of the cell so it reads as a
## solid object rather than a distant pixel cluster. The sprite snaps
## to the new offset whenever the player turns; with the player on
## the same axis there's no visible motion. Walkable scenery typically
## leaves this at 0 — leaning a flower toward the player serves no
## purpose since the player walks over it.
@export var lean_toward_player: float = 0.0

func get_display_name() -> String:
	return tr(name_key)

func get_display_description() -> String:
	return tr(description_key)
