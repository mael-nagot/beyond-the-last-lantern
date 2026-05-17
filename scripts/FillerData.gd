class_name FillerData
extends Resource

## Template for one outdoor-biome filler sprite (tree, rock, bush).
## Fillers replace wall geometry entirely in `outdoor_mode` biomes —
## they're the silhouettes the player sees beyond the last walkable
## tile. Pure decoration: never blocks, never interacts, never animates.

## Translation key for the editor / debug label (not currently shown
## to the player, but reserved for future map-cursor / bestiary use).
## Convention: `filler.<biome>.<sprite>.name`.
@export var name_key: String = ""

## Translation key for an editor / debug description.
## Convention: `filler.<biome>.<sprite>.description`.
@export_multiline var description_key: String = ""

@export_group("Art")
## The sprite texture. Transparent background expected — alpha-scissor
## discards transparent pixels so silhouettes read cleanly against
## the sky / fog. Set Filter = Nearest on the import settings to keep
## pixel art crisp.
@export var texture: Texture2D

## Real-world height of the sprite in metres. The renderer derives
## `pixel_size = world_height / texture_height`, so swapping a 256px
## tree for a 512px tree doesn't change its on-screen size — the
## designer controls real-world size here regardless of PNG resolution.
## Typical values: trees 3.5–5.0, bushes 0.6–1.2, rocks 0.4–1.5.
@export var world_height: float = 4.0

## Vertical offset added to the sprite's centre, in metres. The
## renderer anchors the sprite so its bottom sits at floor level
## (y = 0) before applying y_offset.
## Positive shifts the whole sprite up.
## Negative pushes it into the floor (useful when the source PNG has
## transparent padding below the trunk that should sit underground).
@export var y_offset: float = 0.0

func get_display_name() -> String:
	return tr(name_key)

func get_display_description() -> String:
	return tr(description_key)
