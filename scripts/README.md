# Below the Last Lantern — Scripts Reference

Tests for these scripts live in `res://tests/`. See `res://tests/README.md` for conventions.

## Core Scripts (`res://scripts/`)

### GridCell.gd
**Type:** Resource (data only, not attached to a node)
**Purpose:** Represents a single tile in the dungeon grid. Stores the cell type (WALL, FLOOR, ENTRANCE, EXIT), wall flags for each side (north/south/east/west), an optional object id, and an `items` array (`Array[ItemInstance]`) for items piled on this tile. The `is_blocked` property returns true if the cell is a wall.

### LevelGenerator.gd
**Type:** Node
**Purpose:** Procedurally generates dungeon levels using a Growing Tree maze algorithm. Creates a 2D grid of GridCell resources, carves corridors with configurable wiggle and width variation, optionally places rooms, connects all regions, places entrance/exit points, and (after BFS validation) drops items on floor cells. Items are placed by weighted-rolling each `LootEntry` in the biome's `floor_loot` list and dropping it on a random eligible cell, where eligibility is constrained by the entry's placement flags (corridor/room/dead-end) and excludes entrance/exit. All generation parameters are read from a BiomeData resource via `configure(biome)`.
**Key methods:** configure(biome: BiomeData), generate()

### DungeonView.gd
**Type:** Node3D (attached to the DungeonView scene root)
**Purpose:** Renders the dungeon in 3D. Builds flat quad meshes (walls, floors, ceilings) from the grid data, applies biome textures with optional triplanar mapping and normal maps, spawns Sprite3D billboards for items piled on floor cells (up to 3 visible per tile, billboard mode FIXED_Y, NEAREST filter, alpha-cut DISCARD), creates an `ItemsRoot` Node3D under the SubViewport at runtime to hold them, also creates a transparent `DungeonDropTarget` overlay on top of the SubViewportContainer to accept item drags (with the container itself set to MOUSE_FILTER_IGNORE so it doesn't reject drops first), manages the camera position and rotation, handles the SubViewport sizing for portrait/landscape orientations, and applies biome environment settings (fog, ambient light). `rebuild_items()` re-syncs the Sprite3D set from the current grid (used after pickup or dungeon drop).
**Key exports:** show_ceiling, camera_eye_height, wall_height, biome, fov, viewport_ratio_portrait, viewport_ratio_landscape
**Public references:** drop_target (DungeonDropTarget)
**Key methods:** setup(gen), rebuild_items(), move_camera_to(grid_pos, facing), rotate_camera_to(turn_right), set_initial_facing(facing)

### PlayerController.gd
**Type:** Node (attached to the PlayerController node inside DungeonView)
**Purpose:** Handles step-by-step player movement on the grid. Tracks grid position and facing direction. Provides 6 movement functions (forward, backward, strafe left/right, turn left/right). Checks cell traversability before moving. Tells DungeonView to tween the camera.
**Key methods:** move_forward(), move_backward(), strafe_left(), strafe_right(), turn_left(), turn_right()
**Key state:** grid_pos (Vector2i), facing (Direction enum)

### BiomeData.gd
**Type:** Resource (data only, loaded as .tres files)
**Purpose:** Defines all visual, environmental, level generation, and loot properties of a biome. Holds arrays of wall/floor/ceiling textures (albedo and normal), fog settings, ambient light settings, triplanar mapping toggles, wall height, all dungeon generation parameters (grid size, maze behavior, corridor width, room placement, entrance/exit rules), and the floor loot pool (Array of LootEntry + min/max items per level). Loaded at runtime and passed to both DungeonView (appearance) and LevelGenerator (generation + item placement).
**Key exports:** wall_albedo, wall_normal, floor_albedo, floor_normal, ceiling_albedo, ceiling_normal, fog_enabled, fog_color, fog_density, fog_aerial, ambient_color, ambient_energy, use_triplanar, triplanar_sharpness, triplanar_y_offset, grid_width, grid_height, maze_bias, wiggle, corridor_min_width, corridor_max_width, width_change_chance, room_count, room_min_size, room_max_size, entrance_at_dead_end, exit_at_dead_end, min_exit_distance, floor_loot, floor_items_min, floor_items_max

### LootEntry.gd
**Type:** Resource (data only, used inside BiomeData.floor_loot)
**Purpose:** One entry in a biome's loot pool. Pairs an `ItemData` with a `weight` (relative probability) and a `placement` flag-set (Corridor / Room / Dead End — any combination). Defaults to weight 1, placement = all three types. `allows(placement_type)` checks one of the constants `PLACEMENT_CORRIDOR / PLACEMENT_ROOM / PLACEMENT_DEAD_END`.
**Key exports:** item, weight, placement

### MapData.gd
**Type:** RefCounted (standalone script, not attached to any node)
**Purpose:** Tracks which tiles have been explored by the player. Provides reveal_around() to mark a tile and its 8 neighbors as explored. Used by MapPopup to determine which parts of the map to draw. Has a reveal_all() debug function.

### ItemData.gd
**Type:** Resource (data only, loaded as .tres files)
**Purpose:** Template for an item type (e.g. "Health Potion"). Defines name, description, category enum (CONSUMABLE, EQUIPMENT, THROWABLE, QUEST), effect type/value/duration, stacking rules, art (icon for UI + dungeon sprite for Sprite3D + world height + y offset), and economy (buy/sell prices). `dungeon_sprite_world_height` controls the sprite's size in world units (independent of texture pixel dimensions); `dungeon_sprite_y_offset` nudges it vertically to compensate for transparent padding in the texture. **`item_name` and `description` are translation keys** (e.g. `item.health_potion.name`), not literal display text — see `res://localization/`. Use `get_display_name()` / `get_display_description()` to fetch the translated text. One `.tres` file per item lives in `res://assets/items/`.
**Key exports:** item_name, description, category, effect_type, effect_value, effect_duration, stackable, stack_max, icon, dungeon_sprite, dungeon_sprite_world_height, dungeon_sprite_y_offset, buy_price, sell_price
**Key methods:** get_display_name() → translated name, get_display_description() → translated description

### ItemInstance.gd
**Type:** RefCounted (runtime data, not attached to any node)
**Purpose:** A live instance of an item — points at an `ItemData` and tracks per-instance state (`stack_count`, `durability`). Stackable items share an instance with `stack_count > 1`; equipment with durability gets one instance per piece. Use `ItemInstance.create(data, count)` to build one. `can_stack_with(other)` checks if two instances can merge.

### Character.gd
**Type:** RefCounted (runtime data)
**Purpose:** Minimal party-member state used while we wait for Phase 9's full `CharacterData`. Holds a localized `name_key`, `current_hp/max_hp`, `current_mp/max_mp`, and an `apply_item(data) -> bool` that handles the `HEAL_HP` and `HEAL_MP` effect types and refuses everything else. Emits `changed` whenever HP/MP move so bound UI can refresh.
**Key methods:** Character.create(name_key, max_hp, max_mp = 0), get_display_name(), is_full_hp(), is_full_mp(), damage(amount), apply_item(data) → bool

### ItemSlotButton.gd
**Type:** TextureButton (subclass, used as the inner button of every ItemBar slot)
**Purpose:** Acts as the slot's clickable area AND its drag source. `_get_drag_data` packages the slot's current `ItemInstance` plus index into a dictionary `{"type": "item", "slot_index", "instance"}` and sets a translucent icon-textured drag preview centered on the cursor. Returns null if the slot is empty. `build_drag_payload()` is the pure helper used both by `_get_drag_data` and by tests (avoids the engine's drag-preview assertion when not actually dragging).

### DungeonDropTarget.gd
**Type:** Control (transparent overlay sized to fill the SubViewportContainer)
**Purpose:** Catches `ItemSlotButton` drags landing on the dungeon view. Validates the payload then emits `item_dropped(slot_index, instance)`. Game handles the actual cell mutation (drops one item at a time onto the player's current cell, decrements the source bar slot by one).
**Key signals:** item_dropped(slot_index: int, instance: ItemInstance)

### Toast.gd
**Type:** Label (auto-hiding feedback message)
**Purpose:** Tiny self-hiding label used for transient HUD feedback (e.g. "No effect" when a drag-drop is rejected). `show_message(translation_key, duration)` sets the localized text, makes it visible, and queues a hide timer.

### Game.gd
**Type:** Node3D (attached to the Game scene root)
**Purpose:** Main game orchestrator. Loads the biome resource, creates the LevelGenerator (configured from the biome), initializes DungeonView and PlayerController, builds a 3-character placeholder party and binds them to CharacterSlots, wires HUD signals (movement pad, map, pickup prompt, drag-drop targets), and routes keyboard input to the PlayerController. Handles map updates and pickup-prompt updates on every player movement. Handles pickup actions, character item-use (consumes one stack on success, shows a "No effect" toast on rejection), and dungeon drops (drops one item at a time onto the player's current cell, rebuilds Sprite3Ds, refreshes the pickup prompt).
**Inputs:** WASD/arrows + Q/E for movement; F to pick up items on the current tile.
**Debug keys:** F1 spawns a Health Potion into the item bar; F2 damages every party member by 10 HP for testing heal.

---

## HUD Scripts (`res://scripts/hud/`)

### HUD.gd
**Type:** CanvasLayer (attached to the HUD scene root)
**Purpose:** Master layout controller for all UI elements. Detects portrait vs landscape orientation and positions all UI panels accordingly (top bar, party panel, item bar, movement pad, pickup prompt, toast). Calculates safe viewport ratios for tablets (reduces DungeonView size if UI doesn't fit). Applies UI scaling when the viewport ratio hits minimum. Sets `HUDRoot.mouse_filter = IGNORE` so the dungeon view's drop target overlay (one CanvasLayer below) can receive item drops cleanly. Creates `PickupPrompt` and `Toast` programmatically as children of HUDRoot. Wires the map button. Provides setup_dungeon_view(), setup_map(), and `show_toast(translation_key, duration)` for transient feedback.
**Key exports:** viewport_ratio_portrait, viewport_ratio_landscape, min_viewport_ratio
**Public references:** item_bar, movement_pad, pickup_prompt, toast, party_panel, map_popup
**Key methods:** show_toast(translation_key, duration)

### ItemBar.gd
**Type:** Container (attached to the ItemBar node)
**Purpose:** Manages 10 inventory slots displayed as a grid AND owns the player's item-bar inventory model (`Array[ItemInstance]` of size 10). Creates slot panels with styled borders + icon button + stack-count label programmatically. Relayouts as 5×2 grid depending on orientation. Slot sizes scale relative to screen dimensions. `add_item(instance)` auto-stacks onto compatible existing stacks then fills empty slots, returning any leftover that didn't fit. `pickup_from(cell)` drains every stack from a `GridCell` into the bar, leaving any leftover stacks on the cell.
**Key signals:** slot_clicked(index), inventory_changed
**Key methods:** add_item(instance) → leftover ItemInstance, pickup_from(cell) → int (total individual items transferred — `0` distinguishes "nothing fit" from a partial pickup), get_slot(index), set_slot(index, instance), clear_slot(index), remove_one(index), relayout(available_width) → Vector2

### PartyPanel.gd
**Type:** HBoxContainer (attached to the PartyPanel node)
**Purpose:** Holds references to the 3 CharacterSlot instances. Provides get_slot(index) to access individual character slots.

### CharacterSlot.gd
**Type:** BoxContainer (attached to each CharacterSlot scene root)
**Purpose:** Displays one party member's info: portrait (in a bordered frame), HP bar (red), MP bar (blue), name label, and 3 action buttons (Attack ⚔, Spell ✦, Defense 🛡). All sizes scale relative to screen dimensions with portrait/landscape adjustments. `bind(character)` connects to a `Character` resource and refreshes the bars whenever the character changes; `_can_drop_data` / `_drop_data` accept dragged `ItemSlotButton` payloads on the portrait/bars/name/gaps (action buttons stay non-droppable), run the effect via `Character.apply_item`, and emit `item_consumed(slot_index)` on success or `item_rejected(slot_index)` if the effect would be wasted.
**Key signals:** portrait_clicked, attack_pressed, spell_pressed, defense_pressed, item_consumed(slot_index), item_rejected(slot_index)
**Key methods:** bind(character), set_hp(current, max), set_mp(current, max), set_portrait(texture), set_character_name(name)

### MovementPad.gd
**Type:** GridContainer (attached to the MovementPad node, columns=3)
**Purpose:** 6 directional buttons arranged in a 2×3 grid. Button sizes scale relative to screen short side. Emits signals: forward_pressed, backward_pressed, turn_left_pressed, turn_right_pressed, strafe_left_pressed, strafe_right_pressed.

### PickupPrompt.gd
**Type:** Button (created programmatically by `Hud.gd` as a child of HUDRoot)
**Purpose:** Floating "Pick up (N)" button that appears when the player stands on a tile with items. `set_count(n)` updates the visible count and shows/hides the button. `flash_bar_full()` temporarily replaces the label with the localized "bag full" message for ~1.5 s when a pickup attempt fails because the inventory is full. Text is built from the `ui.pickup.prompt` and `ui.pickup.bar_full` translation keys.
**Key methods:** set_count(count: int), flash_bar_full()

### MapPopup.gd
**Type:** Control (attached to the MapPopup scene root)
**Purpose:** Full-screen map overlay. Draws the dungeon map using Godot's 2D draw functions on a Control node. Shows explored floor tiles as shaded rectangles, walls as lines, exit as a green diamond, and the player as a blinking red arrow. Handles open/close, blink timer, and layout for portrait/landscape.
**Key exports:** debug_reveal_all (reveals entire map for testing)
**Key methods:** setup(gen, map_data), open(), close(), update_player(pos, facing)
