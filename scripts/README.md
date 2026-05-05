# Below the Last Lantern — Scripts Reference

## Core Scripts (`res://scripts/`)

### GridCell.gd
**Type:** Resource (data only, not attached to a node)
**Purpose:** Represents a single tile in the dungeon grid. Stores the cell type (WALL, FLOOR, ENTRANCE, EXIT), wall flags for each side (north/south/east/west), and an optional object reference. The `is_blocked` property returns true if the cell is a wall.

### LevelGenerator.gd
**Type:** Node
**Purpose:** Procedurally generates dungeon levels using a Growing Tree maze algorithm. Creates a 2D grid of GridCell resources, carves corridors with configurable wiggle and width variation, optionally places rooms, connects all regions, and places entrance/exit points. Validates paths with BFS to ensure the exit is always reachable from the entrance.
**Key exports:** grid_width, grid_height, maze_bias, wiggle, corridor_min_width, corridor_max_width, width_change_chance, room_count, room_min_size, room_max_size, entrance_at_dead_end, exit_at_dead_end, min_exit_distance

### DungeonView.gd
**Type:** Node3D (attached to the DungeonView scene root)
**Purpose:** Renders the dungeon in 3D. Builds flat quad meshes (walls, floors, ceilings) from the grid data, applies biome textures with optional triplanar mapping and normal maps, manages the camera position and rotation, handles the SubViewport sizing for portrait/landscape orientations, and applies biome environment settings (fog, ambient light).
**Key exports:** show_ceiling, camera_eye_height, wall_height, biome, fov, viewport_ratio_portrait, viewport_ratio_landscape

### PlayerController.gd
**Type:** Node (attached to the PlayerController node inside DungeonView)
**Purpose:** Handles step-by-step player movement on the grid. Tracks grid position and facing direction. Provides 6 movement functions (forward, backward, strafe left/right, turn left/right). Checks cell traversability before moving. Tells DungeonView to tween the camera.
**Key methods:** move_forward(), move_backward(), strafe_left(), strafe_right(), turn_left(), turn_right()
**Key state:** grid_pos (Vector2i), facing (Direction enum)

### BiomeData.gd
**Type:** Resource (data only, loaded as .tres files)
**Purpose:** Defines all visual and environmental properties of a biome. Holds arrays of wall/floor/ceiling textures (albedo and normal), fog settings, ambient light settings, triplanar mapping toggles, and wall height. Loaded at runtime and passed to DungeonView to configure the dungeon's appearance.
**Key exports:** wall_albedo, wall_normal, floor_albedo, floor_normal, ceiling_albedo, ceiling_normal, fog_enabled, fog_color, fog_density, fog_aerial, ambient_color, ambient_energy, use_triplanar, triplanar_sharpness, triplanar_y_offset

### MapData.gd
**Type:** RefCounted (standalone script, not attached to any node)
**Purpose:** Tracks which tiles have been explored by the player. Provides reveal_around() to mark a tile and its 8 neighbors as explored. Used by MapPopup to determine which parts of the map to draw. Has a reveal_all() debug function.

### Game.gd
**Type:** Node3D (attached to the Game scene root)
**Purpose:** Main game orchestrator. Creates the LevelGenerator, loads the biome, initializes DungeonView and PlayerController, wires HUD signals (movement pad, map), and routes keyboard input to the PlayerController. Handles map updates on every player movement.

---

## HUD Scripts (`res://scripts/hud/`)

### HUD.gd
**Type:** CanvasLayer (attached to the HUD scene root)
**Purpose:** Master layout controller for all UI elements. Detects portrait vs landscape orientation and positions all UI panels accordingly. Calculates safe viewport ratios for tablets (reduces DungeonView size if UI doesn't fit). Applies UI scaling when the viewport ratio hits minimum. Wires the map button. Provides setup_dungeon_view() and setup_map() for initialization.
**Key exports:** viewport_ratio_portrait, viewport_ratio_landscape, min_viewport_ratio

### ItemBar.gd
**Type:** Container (attached to the ItemBar node)
**Purpose:** Manages 10 inventory slots displayed as a grid. Creates slot panels with styled borders programmatically. Relayouts as 10×1 (landscape) or 5×2 (portrait) grid depending on orientation. Slot sizes scale relative to screen dimensions. Emits slot_clicked signal when a slot is tapped.
**Key methods:** relayout(available_width) → returns Vector2 size, set_slot_icon(index, texture)

### PartyPanel.gd
**Type:** HBoxContainer (attached to the PartyPanel node)
**Purpose:** Holds references to the 3 CharacterSlot instances. Provides get_slot(index) to access individual character slots.

### CharacterSlot.gd
**Type:** BoxContainer (attached to each CharacterSlot scene root)
**Purpose:** Displays one party member's info: portrait (in a bordered frame), HP bar (green), MP bar (blue), name label, and 3 action buttons (Attack ⚔, Spell ✦, Defense 🛡). All sizes scale relative to screen dimensions with portrait/landscape adjustments. Emits signals for portrait_clicked, attack_pressed, spell_pressed, defense_pressed.
**Key methods:** set_hp(current, max), set_mp(current, max), set_portrait(texture), set_character_name(name)

### MovementPad.gd
**Type:** GridContainer (attached to the MovementPad node, columns=3)
**Purpose:** 6 directional buttons arranged in a 2×3 grid. Button sizes scale relative to screen short side. Emits signals: forward_pressed, backward_pressed, turn_left_pressed, turn_right_pressed, strafe_left_pressed, strafe_right_pressed.

### MapPopup.gd
**Type:** Control (attached to the MapPopup scene root)
**Purpose:** Full-screen map overlay. Draws the dungeon map using Godot's 2D draw functions on a Control node. Shows explored floor tiles as shaded rectangles, walls as lines, exit as a green diamond, and the player as a blinking red arrow. Handles open/close, blink timer, and layout for portrait/landscape.
**Key exports:** debug_reveal_all (reveals entire map for testing)
**Key methods:** setup(gen, map_data), open(), close(), update_player(pos, facing)
