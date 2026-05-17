class_name FillerData
extends Resource

# Template for an "outdoor filler" sprite — a tree, rock, bush or other
# silhouette spawned in the impassable space outside the walkable area
# of an `outdoor_mode` biome. Fillers replace wall geometry entirely
# (the renderer skips wall quads in outdoor biomes) so they're what
# the player sees beyond the last walkable tile.
#
# Fillers are pure decoration — they never block, never interact, and
# never carry quest logic. They follow the standard Sprite3D pattern
# (CLAUDE.md): `pixel_size = world_height / texture_height` keeps the
# real-world height under designer control regardless of PNG size, and
# `lean_toward_player` stays 0 because fillers are decorations (the
# billboard does the work of making them feel 3D).

@export var name_key: String = ""        # translation key — for editor / debug
@export_multiline var description_key: String = ""

@export_group("Art")
# The sprite texture. Transparent background expected (alpha-scissor
# discards transparent pixels so silhouettes read cleanly against the
# sky / fog).
@export var texture: Texture2D

# Real-world height of the sprite in metres. The renderer derives
# `pixel_size` from `world_height / texture_height` so swapping a 256px
# tree for a 512px tree doesn't double its on-screen size.
@export var world_height: float = 4.0

# Vertical offset added to the sprite's centre, in metres. The renderer
# anchors the sprite so its BOTTOM sits at floor level (y = 0) before
# applying y_offset — positive shifts the whole sprite up, negative
# pushes it into the floor. Useful when the source PNG has transparent
# padding below the trunk that should sit underground.
@export var y_offset: float = 0.0

func get_display_name() -> String:
	return tr(name_key)

func get_display_description() -> String:
	return tr(description_key)
