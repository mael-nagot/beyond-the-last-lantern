# Below the Last Lantern — Scripts Reference

Tests for these scripts live in `res://tests/`. See `res://tests/README.md` for conventions.

## Core Scripts (`res://scripts/`)

### GridCell.gd
**Type:** Resource (data only, not attached to a node)
**Purpose:** Represents a single tile in the dungeon grid. Stores the cell type (WALL, FLOOR, ENTRANCE, EXIT), wall flags for each side (north/south/east/west), an optional `object: ObjectInstance` (chest, door, etc. — null when empty), and an `items: Array[ItemInstance]` for items piled on this tile. The `is_blocked` property returns true if the cell is a wall OR if it holds an object whose `data.blocks_movement` is true.

### LevelGenerator.gd
**Type:** Node
**Purpose:** Procedurally generates dungeon levels using a Growing Tree maze algorithm. Creates a 2D grid of GridCell resources, carves corridors with configurable wiggle and width variation, optionally places rooms, connects all regions, places entrance/exit points, then in order: cell-bound objects (chests etc.), edge-bound doors, lever ↔ door linked pairs, **key ↔ locked-door pairs (Phase 8 Task 2c)**, and finally floor items. Object placement runs after BFS validation with a per-placement reachability check (each blocking object must keep every floor cell reachable from the entrance AND every blocked-but-walkable-adjacent object reachable too — if not, the object is rolled back and a different cell is tried). Door placement: doors live on EDGES (between two adjacent floor cells) — never on a `GridCell` — and are stored exclusively in `LevelGenerator.doors`. Doors only land on edges where both endpoints are 1-cell-wide-corridor cells (exactly 2 non-wall neighbours; straight or bend), neither is entrance/exit, and neither holds a chest. Decorative doors (`ObjectSpawn.must_gate_content = false`) need no extra reachability check because open doors don't block and closed doors are always re-openable. Linked-pair placement (lever + door) runs after both and is validated against **chain reachability** rather than per-pair reachability: starting at the entrance with directly-clickable doors treated as open, the simulator iteratively pulls every reachable lever (opening its linked doors) until no further progress. A pair is only accepted if, after tentative placement, no cell that was previously chain-reachable becomes unreachable (modulo the new lever's own blocking cell) AND the new lever has at least one chain-reachable neighbour. This permits *progressive* gating (lever_1 opens door_A, behind which is lever_2 — fine puzzle) but rejects *cycles* (every lever locked behind every door, leaving the player stuck at start). Pair rollbacks include both the door and the lever — no orphan halves. **Chain reachability v2** (Phase 8 Task 2c) extends the simulator to also collect keys and unlock matching doors during the iteration: at each fixed-point step, every key on a reachable cell or inside a reachable chest is collected, and every locked door whose `lock_id` is collected becomes openable. Key-door placement uses the same accept-or-rollback model with floor/chest fallback locations; `must_gate_content=true` (the default for key-doors) additionally rejects placements where the locked door doesn't actually gate any chest, lever, key, or exit cell. Item placement skips cells already occupied by a blocking object. All generation parameters are read from a `BiomeData` resource via `configure(biome)`.
**Key state:** `doors: Array[DoorInstance]`, `_doors_by_edge: Dictionary` (internal index), `linked_objects_pool: Array[LinkedObjectSpawn]`
**Key methods:** configure(biome: BiomeData), generate(), get_door_at_edge(a, b) → DoorInstance, is_edge_blocked(a, b) → bool

### DungeonView.gd
**Type:** Node3D (attached to the DungeonView scene root)
**Purpose:** Renders the dungeon in 3D. Builds flat quad meshes (walls, floors, ceilings) from the grid data, applies biome textures with optional triplanar mapping and normal maps, spawns Sprite3D billboards for items (under `ItemsRoot`), cell-bound objects like chests and levers (under `ObjectsRoot`), and edge-bound doors (under `DoorsRoot`). Cell-object Sprite3Ds carry a child `Area3D` with a box collider and metadata pointing back at the `ObjectInstance`; the renderer reads `instance.get_visual_opened()` (not `instance.opened`) to choose between `closed_sprite` and `opened_sprite` so a `LeverInstance` can mirror its linked door's state. Door rendering is a separate code path: each door is a `Node3D` anchored at the edge midpoint (computed once from `cell_a + cell_b`) and Y-rotated to the corridor axis; it holds a non-billboarded `Sprite3D` (with optional `scale.x` stretch via `ObjectData.world_width` so a square wall texture renders at corridor proportions) and a SIBLING `Area3D` with a box collider (sibling, not child, so the sprite's `scale.x` doesn't deform the collider). The Area3D is built unconditionally — the `interactable` flag now controls Game.gd's response to a click (toggle vs. locked-feedback), not whether the click is detected. Door positions are static — they are never refreshed on movement or turn, so they cannot drift. Also creates a transparent `DungeonDropTarget` overlay on top of the SubViewportContainer for drag-drop and click handling (with the container set to MOUSE_FILTER_IGNORE so it doesn't reject input first). Manages camera position/rotation, SubViewport sizing for portrait/landscape, biome environment (fog, ambient). `rebuild_items()` re-syncs item sprites; `rebuild_objects()` re-syncs cell-object sprites (used when a chest opens, when a lever is pulled, or when a door whose lever mirrors it changes state); `rebuild_doors()` re-syncs door visuals (used when a door is toggled). `shake_camera()` is the brief jolt fired on wall bumps.
**Key exports:** show_ceiling, camera_eye_height, wall_height, biome, fov, viewport_ratio_portrait, viewport_ratio_landscape
**Public references:** drop_target (DungeonDropTarget)
**Key methods:** setup(gen), rebuild_items(), rebuild_objects(), rebuild_doors(), move_camera_to(grid_pos, facing), rotate_camera_to(turn_right), set_initial_facing(facing), shake_camera(magnitude = 1.0) — magnitude scales the jolt; wall bumps use the default, locked-door click feedback passes ~0.4 for a softer hit

### PlayerController.gd
**Type:** Node (attached to the PlayerController node inside DungeonView)
**Purpose:** Handles step-by-step player movement on the grid. Tracks grid position and facing direction. Provides 6 movement functions (forward, backward, strafe left/right, turn left/right). Before moving, checks both that the target cell is unblocked AND that the edge between current and target isn't blocked by a closed door (`LevelGenerator.is_edge_blocked`). Tells DungeonView to tween the camera.
**Key methods:** move_forward(), move_backward(), strafe_left(), strafe_right(), turn_left(), turn_right()
**Key state:** grid_pos (Vector2i), facing (Direction enum)

### BiomeData.gd
**Type:** Resource (data only, loaded as .tres files)
**Purpose:** Defines all visual, environmental, level generation, and loot properties of a biome. Holds arrays of wall/floor/ceiling textures (albedo and normal), fog settings, ambient light settings, triplanar mapping toggles, wall height, all dungeon generation parameters (grid size, maze behavior, corridor width, room placement, entrance/exit rules), and the floor loot pool (Array of LootEntry + min/max items per level). Loaded at runtime and passed to both DungeonView (appearance) and LevelGenerator (generation + item placement).
**Key exports:** wall_albedo, wall_normal, floor_albedo, floor_normal, ceiling_albedo, ceiling_normal, fog_enabled, fog_color, fog_density, fog_aerial, ambient_color, ambient_energy, use_triplanar, triplanar_sharpness, triplanar_y_offset, grid_width, grid_height, maze_bias, wiggle, corridor_min_width, corridor_max_width, width_change_chance, room_count, room_min_size, room_max_size, entrance_at_dead_end, exit_at_dead_end, min_exit_distance, floor_loot, floor_items_min, floor_items_max, objects, linked_objects, key_door_spawns, move_sounds

### LootEntry.gd
**Type:** Resource (data only, used inside BiomeData.floor_loot)
**Purpose:** One entry in a biome's floor-loot pool. Pairs an `ItemData` with a `weight` (relative probability), a `placement` flag-set (Corridor / Room / Dead End — any combination), and a `min_distance_to_other_item` preference (Manhattan tiles from any already-placed floor item; the algorithm relaxes by 1 down to 0 if the constraint can't be satisfied). Defaults: weight 1, placement = all three types, no min distance. `allows(placement_type)` checks one of the constants `PLACEMENT_CORRIDOR / PLACEMENT_ROOM / PLACEMENT_DEAD_END`.
**Key exports:** item, weight, placement, min_distance_to_other_item

### MapData.gd
**Type:** RefCounted (standalone script, not attached to any node)
**Purpose:** Tracks which tiles have been explored by the player. Provides reveal_around() to mark a tile and its 8 neighbors as explored. Used by MapPopup to determine which parts of the map to draw. Has a reveal_all() debug function.

### ItemData.gd
**Type:** Resource (data only, loaded as .tres files)
**Purpose:** Template for an item type (e.g. "Health Potion"). Defines name, description, category enum (CONSUMABLE, EQUIPMENT, THROWABLE, QUEST, KEY), effect type/value/duration, stacking rules, art (icon for UI + dungeon sprite for Sprite3D + world height + y offset), economy (buy/sell prices), and an optional `key_id` for KEY-category items. `dungeon_sprite_world_height` controls the sprite's size in world units (independent of texture pixel dimensions); `dungeon_sprite_y_offset` nudges it vertically to compensate for transparent padding in the texture. **`item_name` and `description` are translation keys** (e.g. `item.health_potion.name`), not literal display text — see `res://localization/`. Use `get_display_name()` / `get_display_description()` to fetch the translated text. `key_id` (Phase 8 Task 2c) marks the item as a key that unlocks a `DoorInstance` whose `lock_id` matches; per-placement overrides happen on the `ItemInstance` (auto-generated lock ids), so this field on the .tres is mainly used for hand-authored static keys. One `.tres` file per item lives in `res://assets/items/`.
**Key exports:** item_name, description, category, effect_type, effect_value, effect_duration, stackable, stack_max, icon, dungeon_sprite, dungeon_sprite_world_height, dungeon_sprite_y_offset, pickup_drop_sound, use_sound, buy_price, sell_price, key_id
**Key methods:** get_display_name() → translated name, get_display_description() → translated description

### SoundManager.gd
**Type:** Autoload singleton (`Node`, registered in `project.godot` as `SoundManager`)
**Purpose:** Owns a pool of 8 `AudioStreamPlayer` nodes for short SFX (overlap allowed) plus a dedicated player for biome ambient loops (Phase 19, hooked but unused). Game.gd assigns `audio_config` and `current_biome` so convenience methods can resolve their streams without each callsite knowing where the data lives. Null streams and empty arrays are no-ops — a missing asset produces silence.
**Public state:** audio_config (AudioConfig), current_biome (BiomeData)
**Key methods:** play(stream), play_random(streams), play_ambient(stream), stop_ambient(), play_move(), play_turn(), play_wall_bump(), play_negative(), play_map_open(), play_map_close()

### AudioConfig.gd
**Type:** Resource (data only, loaded from `res://assets/audio_config.tres`)
**Purpose:** Holds global, non-biome-specific SFX references — UI sounds (map open / close, generic "negative" feedback) and player-action sounds (wall bump, turn rustle variants). Loaded by Game.gd at startup and assigned to `SoundManager.audio_config`.
**Key exports:** map_open_sound, map_close_sound, negative_sound, wall_bump_sound, turn_sounds (Array[AudioStream])

### ItemInstance.gd
**Type:** RefCounted (runtime data, not attached to any node)
**Purpose:** A live instance of an item — points at an `ItemData` and tracks per-instance state (`stack_count`, `durability`, `key_id`, `hue_shift` + cached recoloured textures). Stackable items share an instance with `stack_count > 1`; equipment with durability gets one instance per piece. Use `ItemInstance.create(data, count)` to build one. `can_stack_with(other)` checks if two instances can merge — for keys, two instances built from the same key `.tres` but with different `key_id`s do NOT stack (they unlock different doors). `get_key_id()` returns the per-instance `key_id` if non-empty, else falls back to `data.key_id` — auto-generated lock ids land on the instance, designer-baked ones live on the data. `apply_hue_shift(shift: float)` bakes per-pixel hue-rotated copies of `data.icon` and `data.dungeon_sprite` (preserving saturation, value, alpha) and caches them; `get_icon()` / `get_dungeon_sprite()` return the baked texture when present, falling back to `data.*` otherwise. Renderers (`ItemBar` slot button, `DungeonView` floor sprite, `LootPopup` slot icon) call those accessors — multiplicative `modulate` tinting was abandoned because on a strongly-coloured base sprite (e.g. a yellow key) it only produced brightness variations, not real hue differences. `KeyDoorSpawn` placement calls `apply_hue_shift` per pair so keys for different locks but the same `.tres` render in actually different colours.

### ObjectData.gd
**Type:** Resource (data only, loaded as .tres files in `res://assets/objects/`)
**Purpose:** Template for an interactable dungeon object — chests, doors, levers, traps, campfires, decorations. Holds the category, blocks_movement flag, closed/opened sprite textures, world height/width + y-offset + lean-toward-player offset, the `interactable` flag, and three sound/feedback fields (`interact_sound`, `locked_sound`, `locked_message_key`). One `.tres` per object type — multiple chests of the same type share data, only their `ObjectInstance` state differs. `world_width = 0` keeps the texture's natural aspect (chests, small props); `> 0` forces a non-uniform horizontal stretch via `Sprite3D.scale.x` (used by doors so a square wall texture renders at corridor proportions). `interactable = true` (default): clicks toggle state (chest opens, door swings, lever pulls). `interactable = false`: clicks still register, but instead of toggling, the object plays `locked_sound` and the HUD shows a toast built from `locked_message_key` — used for doors that need a lever or key to actually open. The Area3D is built either way so the player gets feedback rather than a silent dead click. **Loot is no longer stored here**; it lives on the per-placement `ObjectSpawn.loot_table` so the same chest visual can hold different contents in different biomes.
**Key exports:** name_key, description_key, category, blocks_movement, closed_sprite, opened_sprite, world_height, world_width, y_offset, lean_toward_player, interactable, interact_sound, locked_sound, locked_message_key
**Key methods:** get_display_name(), get_display_description()

### ObjectInstance.gd
**Type:** RefCounted (runtime data)
**Purpose:** A placed object's runtime state. Holds the `ObjectData` reference, an `opened: bool` flag (chest been looted, door been opened, etc.), an `items: Array[ItemInstance]` for chest contents (rolled once on first open, persists if popup closes mid-take so the player can come back), and a `loot_table: LootTable` reference set by `LevelGenerator` at placement time (copied from the `ObjectSpawn` that placed this instance). `get_visual_opened()` returns `opened` by default — subclasses override it to derive their sprite state from elsewhere (a `LeverInstance` mirrors its linked door's state, for example).
**Key methods:** ObjectInstance.create(data), is_chest(), has_remaining_loot(), get_visual_opened()

### DoorInstance.gd
**Type:** RefCounted (extends `ObjectInstance`)
**Purpose:** Runtime state for a door placed on the EDGE between two adjacent floor cells. Doors are NEVER stored on a `GridCell` — they live exclusively in `LevelGenerator.doors`. This is structural: the cell-based renderer / movement code cannot see them, so the door cannot be drawn at cell centre or treated as a cell-blocker by mistake. `cell_a` and `cell_b` are stored canonically (smaller cell first under lex ordering — lower x, then lower y) so any pair `(a, b)` and `(b, a)` resolves to the same door. Static helpers `canonical_pair(a, b)` and `edge_key(a, b)` keep dictionary keys order-independent. `axis()` returns `(1,0)` for E-W corridors or `(0,1)` for N-S corridors, derived from the cells. `is_edge_blocked()` is true iff the door currently obstructs movement (`data.blocks_movement` is true AND `opened` is false). `is_door()` returns true; `is_chest()` returns false. `linked_levers: Array` holds back-links to any `LeverInstance` that toggle this door (populated by `LevelGenerator` for `LinkedObjectSpawn` doors; empty for decorative doors) — `Game.gd` uses it to refresh lever sprites after a direct door click. **Phase 8 Task 2c — key locks:** `lock_id: String` is set by `LevelGenerator` for KeyDoorSpawn doors (auto-generated unless the spawn's `lock_id_prefix` is set); `unlocked: bool` flips true the first time the player applies the matching key and stays true forever ("once unlocked, never re-locks"). `is_key_locked()` returns true iff `lock_id` is non-empty AND `unlocked` is false.
**Key fields:** cell_a, cell_b, linked_levers, lock_id, unlocked
**Key static methods:** canonical_pair(a, b), edge_key(a, b), create_door(data, a, b)
**Key methods:** axis(), is_edge_blocked(), is_door(), is_key_locked()

### LeverInstance.gd
**Type:** RefCounted (extends `ObjectInstance`)
**Purpose:** Runtime state for a clickable lever. Cell-bound (lives on `GridCell.object` exactly like a chest), but with a side-link `linked_doors: Array` that the lever's pull toggles. The lever doesn't carry its own open/closed bool — `get_visual_opened()` is overridden to return "any linked door is open", so the renderer picks `opened_sprite` while at least one linked door is open and `closed_sprite` otherwise. 2b ships with one linked door per lever; the Array shape extends naturally to many-to-many in the planned 2b follow-up.
**Key fields:** linked_doors
**Key static methods:** create_lever(data)
**Key methods:** is_lever(), get_visual_opened()

### ObjectSpawn.gd
**Type:** Resource (data only, used inside `BiomeData.objects`)
**Purpose:** One entry in a biome's object pool. Each entry says "spawn this `object` between `count_min` and `count_max` times in cells matching `placement` flags, preferably keeping at least `min_distance_to_other_object` Manhattan tiles from any already-placed object, and (when chest) populate it from `loot_table`". The same `object` (e.g. `chest_wooden.tres`) can appear in multiple `ObjectSpawn` entries with different `loot_table` references — that's how the same chest visual ends up holding different contents per biome. `min_distance_to_other_object` is a *preference* — `LevelGenerator` walks every distance-valid candidate; if all break reachability it relaxes the distance by 1 and tries again down to 0. The reachability check snapshots the entrance-reachable set before placement and only fails if a candidate would shrink that set, so pre-existing isolated regions don't get blamed on the chest. `placement` flags are honoured strictly. For DOOR-category spawns, only `PLACEMENT_CORRIDOR` is meaningful (doors live on edges between two corridor cells); the placement code skips door spawns that don't include the corridor flag. `must_gate_content` is reserved for Task 2c (locked / keyed / lever-gated doors): when true, placement requires that closing this door alone cuts off at least one chest cell or the exit. For Task 2a (decorative doors) it stays false. Defaults: 1–1 of the object, placement = `Room | Dead End`, no minimum distance, no loot table, `must_gate_content = false`.
**Key exports:** object, count_min, count_max, placement, min_distance_to_other_object, loot_table, must_gate_content
**Key constants:** PLACEMENT_CORRIDOR / PLACEMENT_ROOM / PLACEMENT_DEAD_END / PLACEMENT_ANY / PLACEMENT_DEFAULT
**Key methods:** allows(placement_type)

### LinkedObjectSpawn.gd
**Type:** Resource (data only, used inside `BiomeData.linked_objects`)
**Purpose:** A biome-level entry that spawns a paired LEVER + DOOR as a coherent unit. Each entry produces between `count_min` and `count_max` independent pairs. For each pair, `LevelGenerator` first picks a 1-wide-corridor edge for the door (same eligibility as decorative doors), then picks a chest-style cell for the lever such that the lever is reachable from the entrance even when the linked door is treated as closed. Lever placement uses chest-style flag-based filters (`lever_placement` — Corridor / Room / Dead End). Two distinct distance concepts: `lever_min_distance_to_other_object` and `door_min_distance_to_other_object` are anti-clustering rules vs. ANY already-placed object (same graceful-degrade-by-1 as chests / decorative doors); `lever_to_door_min_distance` and `lever_to_door_max_distance` are puzzle-design constraints on the spread between the lever and its OWN paired door's nearest endpoint, enforced as HARD bounds (no degrade — failure pushes a warning so the designer adjusts). `lever_to_door_max_distance = -1` means unlimited. `door_must_gate_content` is reserved for Task 2c. If lever placement fails, the door is rolled back so we never ship orphan halves.
**Key exports:** lever_object, door_object, count_min, count_max, lever_placement, lever_min_distance_to_other_object, door_min_distance_to_other_object, lever_to_door_min_distance, lever_to_door_max_distance, door_must_gate_content

### KeyDoorSpawn.gd
**Type:** Resource (data only, used inside `BiomeData.key_door_spawns`)
**Purpose:** A biome-level entry that spawns a key-locked DOOR + a matching KEY item as a coherent puzzle unit (Phase 8 Task 2c). For each pair `LevelGenerator` picks a 1-wide-corridor edge for the door (auto-generates a unique `lock_id` from `lock_id_prefix` — empty prefix → `"lock_<index>"`), then picks a key spawn location per the `key_spawn_locations` flag-set. Locations: **Floor** (place key on a chest-style cell, `key_floor_placement` flags filter Corridor / Room / Dead End), **Chest** (append key item to a chain-reachable chest's items array — guaranteed loot, no roll), **Enemy Drop** (reserved for Phase 10 — currently warns and falls through). Multiple flags = pick one per key, fall back to others on failure. Anti-clustering distances mirror LinkedObjectSpawn (`key_min_distance_to_other_object`, `door_min_distance_to_other_object`, graceful-degrade). Puzzle-spread `key_to_door_min_distance` / `key_to_door_max_distance` are HARD bounds (`max = -1` for unlimited). `door_must_gate_content` defaults TRUE — placement rejects locks that gate nothing meaningful (no chest, lever, key, or exit becomes unreachable when this door stays closed). All placements validated by chain reachability v2 (tracks open doors AND collected keys); failures roll back lever, key, and door together — no orphan halves.
When multiple location flags are enabled, the per-pair lottery is **weighted-random**: `floor_weight`, `chest_weight`, `enemy_drop_weight` (default 1 each = even shuffle, original behaviour). Setting `chest_weight = 3, floor_weight = 1` biases ~75% of pairs to try Chest first, falling back to Floor only if no eligible chest fits. Setting any weight to 0 disables that location even if its flag is on. `allow_multiple_keys_per_chest` (default **false**) prevents two keys from landing in the same chest — the placement skips chests that already hold any key item and falls through to the next candidate. Set to true for biomes that want richer "hoard" chests.
**Key constants:** KEY_LOCATION_FLOOR / KEY_LOCATION_CHEST / KEY_LOCATION_ENEMY_DROP / KEY_LOCATION_DEFAULT
**Key exports:** door_object, key_item, count_min, count_max, lock_id_prefix, door_must_gate_content, key_spawn_locations, floor_weight, chest_weight, enemy_drop_weight, allow_multiple_keys_per_chest, key_floor_placement, key_min_distance_to_other_object, door_min_distance_to_other_object, key_to_door_min_distance, key_to_door_max_distance
**Key methods:** allows_location(location_bit) → bool

### LootTable.gd
**Type:** Resource (data only, loaded as .tres files in `res://assets/loot_tables/`)
**Purpose:** A reusable bag of weighted items with min/max draw counts. Used for chest contents today; will fit enemy drops and quest rewards in later phases. Each entry is a `LootTableEntry` (item + weight + allow_duplicates flag).
**Key exports:** min_rolls, max_rolls, entries (Array[LootTableEntry])

### LootTableEntry.gd
**Type:** Resource (data only, used inside `LootTable.entries`)
**Purpose:** One row of a loot table — pairs an `ItemData` with a relative `weight` and an `allow_duplicates` flag. When `allow_duplicates` is false, this entry can be picked at most once per loot roll session (a unique sword that should never spawn twice in the same chest); when true (default), the entry stays in the pool after each pick and can stack (multiple health potions in the same chest).
**Key exports:** item, weight, allow_duplicates

### Character.gd
**Type:** RefCounted (runtime data)
**Purpose:** Minimal party-member state used while we wait for Phase 9's full `CharacterData`. Holds a localized `name_key`, `current_hp/max_hp`, `current_mp/max_mp`, and an `apply_item(data) -> bool` that handles the `HEAL_HP` and `HEAL_MP` effect types and refuses everything else. Emits `changed` whenever HP/MP move so bound UI can refresh.
**Key methods:** Character.create(name_key, max_hp, max_mp = 0), get_display_name(), is_full_hp(), is_full_mp(), damage(amount), apply_item(data) → bool

### ItemSlotButton.gd
**Type:** TextureButton (subclass, used as the inner button of every ItemBar slot)
**Purpose:** Acts as the slot's clickable area AND its drag source. `_get_drag_data` packages the slot's current `ItemInstance` plus index into a dictionary `{"type": "item", "slot_index", "instance"}` and sets a translucent icon-textured drag preview centered on the cursor. Returns null if the slot is empty. `build_drag_payload()` is the pure helper used both by `_get_drag_data` and by tests (avoids the engine's drag-preview assertion when not actually dragging).

### DungeonDropTarget.gd
**Type:** Control (transparent overlay sized to fill the SubViewportContainer)
**Purpose:** Two roles. (1) Catches `ItemSlotButton` drags landing on the dungeon view, validates the payload, then emits `item_dropped(slot_index, instance)` for Game to handle (drops one item onto the player's current cell). (2) On left-click in `_gui_input`, raycasts from the camera through the click position via `PhysicsRayQueryParameters3D` (areas only, not bodies) and, if the ray hits an `Area3D` with `object_instance` metadata, emits `object_clicked(instance, grid_pos)`. The camera reference is set by DungeonView at construction.
**Public state:** camera (Camera3D — set by DungeonView)
**Key signals:** item_dropped(slot_index: int, instance: ItemInstance), object_clicked(instance: ObjectInstance, grid_pos: Vector2i)

### Toast.gd
**Type:** Label (auto-hiding feedback message)
**Purpose:** Tiny self-hiding label used for transient HUD feedback (e.g. "No effect" when a drag-drop is rejected). `show_message(translation_key, duration)` sets the localized text, makes it visible, and queues a hide timer.

### LootPopup.gd
**Type:** Control (full-screen modal, created programmatically by `Hud.gd`)
**Purpose:** Opens when the player clicks a chest. Shows the chest's remaining `ItemInstance`s as a grid of icon+count slots. Clicking a slot emits `item_taken(slot_index)` (Game transfers that one stack into the bar). The "Take All" button is enabled only when `ItemBar.would_fit_all` returns true, and emits `take_all_requested`. The "✕" button or clicking the dim backdrop emits `close_requested`. Items that don't fit stay in the chest's `instance.items` so the player can come back.
**Key signals:** item_taken(slot_index: int), take_all_requested, close_requested
**Key methods:** setup(item_bar), open(instance: ObjectInstance), close(), is_open()

### Game.gd
**Type:** Node3D (attached to the Game scene root)
**Purpose:** Main game orchestrator. Loads the biome resource, creates the LevelGenerator (configured from the biome), initializes DungeonView and PlayerController, builds a 3-character placeholder party and binds them to CharacterSlots, wires HUD signals (movement pad, map, pickup prompt, drag-drop targets), and routes keyboard input to the PlayerController. Handles map updates and pickup-prompt updates on every player movement. Handles pickup actions, character item-use (consumes one stack on success, shows a "No effect" toast on rejection), and dungeon drops (drops one item at a time onto the player's current cell, rebuilds Sprite3Ds, refreshes the pickup prompt). On `object_clicked`, dispatches by type: a `DoorInstance` toggles open/closed, plays the interact sound, asks DungeonView to rebuild door visuals, and additionally rebuilds cell-bound objects when the door has linked levers so their sprites update too; a `LeverInstance` flips every linked door's state, plays the lever's interact sound, and rebuilds both doors and cell-objects; a chest opens (rolls loot the first time, swaps to the opened sprite, opens the loot popup). Loot transfers (single-slot click in `LootPopup` and Take All) play the moved item's `pickup_drop_sound` — one sound for Take All (first item with a sound), and only when something actually transferred (no sound when the bar was full and zero items moved). Every dispatch path also short-circuits if `instance.data.interactable` is false: it routes to `_play_locked_feedback`, which plays `locked_sound` and shows a toast from `locked_message_key` instead of the success path. **Key-locked doors (Phase 8 Task 2c):** `_toggle_door` checks `door.is_key_locked()` BEFORE the locked-feedback branch — if the bar holds an `ItemInstance` whose `get_key_id()` matches the door's `lock_id`, one count is consumed via `ItemBar.remove_one`, the door's `unlocked` flag flips true (sticky), and execution falls through to the normal toggle (which now opens the door). When no matching key is found, the locked-feedback path fires using the door .tres's own `locked_message_key` (designer sets this to the "needs key" string for key-locked variants). `_find_key_slot_for(lock_id)` is the helper that scans the bar.
**Inputs:** WASD/arrows + Q/E for movement; F to pick up items on the current tile.
**Debug keys:** F1 spawns a Health Potion into the item bar; F2 damages every party member by 10 HP for testing heal; F3 reveals the entire map.

---

## HUD Scripts (`res://scripts/hud/`)

### HUD.gd
**Type:** CanvasLayer (attached to the HUD scene root)
**Purpose:** Master layout controller for all UI elements. Detects portrait vs landscape orientation and positions all UI panels accordingly (top bar, party panel, item bar, movement pad, pickup prompt, toast). Calculates safe viewport ratios for tablets (reduces DungeonView size if UI doesn't fit). Applies UI scaling when the viewport ratio hits minimum. Sets `HUDRoot.mouse_filter = IGNORE` so the dungeon view's drop target overlay (one CanvasLayer below) can receive item drops cleanly. Creates `PickupPrompt` and `Toast` programmatically as children of HUDRoot. Wires the map button. Provides setup_dungeon_view(), setup_map(), and `show_toast(translation_key, duration)` for transient feedback.
**Key exports:** viewport_ratio_portrait, viewport_ratio_landscape, min_viewport_ratio
**Public references:** item_bar, movement_pad, pickup_prompt, toast, loot_popup, party_panel, map_popup
**Key methods:** show_toast(translation_key, duration)

### ItemBar.gd
**Type:** Container (attached to the ItemBar node)
**Purpose:** Manages 10 inventory slots displayed as a grid AND owns the player's item-bar inventory model (`Array[ItemInstance]` of size 10). Creates slot panels with styled borders + icon button + stack-count label programmatically. Relayouts as 5×2 grid depending on orientation. Slot sizes scale relative to screen dimensions. `add_item(instance)` auto-stacks onto compatible existing stacks then fills empty slots, returning any leftover that didn't fit. `pickup_from(cell)` drains every stack from a `GridCell` into the bar, leaving any leftover stacks on the cell.
**Key signals:** slot_clicked(index), inventory_changed
**Key methods:** add_item(instance) → leftover ItemInstance, pickup_from(cell) → int (total individual items transferred — `0` distinguishes "nothing fit" from a partial pickup), would_fit_all(items) → bool (dry-run for "Take All"), get_slot(index), set_slot(index, instance), clear_slot(index), remove_one(index), relayout(available_width) → Vector2

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
**Purpose:** Full-screen map overlay. Draws the dungeon map using Godot's 2D draw functions on a Control node. Shows explored floor tiles as shaded rectangles, walls as lines, the exit as a green diamond, the player as a blinking red arrow, any explored objects as markers (chests = brown filled square; opened chests = outline-only so already-looted ones are visually distinct; levers = small slate-toned diamond, filled when the linked door is closed and outline-only when open), and any explored doors as thin slabs perpendicular to the corridor at the cell boundary (filled when the door currently blocks; outline-only when open). Door slabs are only drawn when both endpoint cells have been explored, so they don't leak fog-of-war info about unvisited corridors. Handles open/close (with a page-flip-style scale + tilt + fade animation that pairs with the `map_open` / `map_close` SFX), blink timer, and layout for portrait/landscape. Spamming the map button is safe — an in-flight animation is killed and the transform reset before a new one starts.
**Key exports:** debug_reveal_all (reveals entire map for testing)
**Key methods:** setup(gen, map_data), open(), close(), update_player(pos, facing), redraw() (force a redraw of the map after external state changes — used by F3 debug reveal)
