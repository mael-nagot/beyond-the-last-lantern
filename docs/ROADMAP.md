# Below the Last Lantern — Development Roadmap

## Cross-Cutting Infrastructure

### Testing ✅
- GUT (Godot Unit Test) installed under `res://addons/gut/`
- `res://tests/{unit,integration}/` directories with conventions in `tests/README.md`
- `.gutconfig.json` configures discovery and exit-on-completion
- CI workflow (`.github/workflows/test.yml`) runs all tests on every PR using chickensoft-games/setup-godot
- Initial coverage: ItemInstance, LootEntry, GridCell, ItemData, MapData (unit); ItemBar, LevelGenerator (integration)
- CLAUDE.md mandates tests for every new pure-logic script and a failing-test-first for code-reproducible bugs

### Localization scaffolding ✅
- See Phase 17 entry below

### Sound effects framework ✅
- `SoundManager` autoload with 8-player SFX pool + dedicated ambient player (overlap-friendly playback for rapid actions)
- `AudioConfig.gd` resource holds global UI + player-action sounds (`audio_config.tres`)
- Sound fields on `ItemData` (`pickup_drop_sound`, `use_sound`) and `BiomeData` (`move_sounds: Array[AudioStream]`)
- Item sounds are reusable across items by category (e.g. every potion shares `potion_pickup_drop1.ogg`)
- All trigger points wired: pickup, drop on dungeon, drop on character (use), no-effect rejection, bag-full rejection, move (biome-specific), turn (global rustle), wall bump, map open/close
- CLAUDE.md mandates SFX for every new player-facing action; `assets/sounds/README.md` documents conventions
- Per-biome ambient loops + music are deferred to Phase 19

## Completed Phases

### Phase 1 — Level Generator ✅

- `GridCell.gd` resource with cell types (WALL, FLOOR, ENTRANCE, EXIT)
- `LevelGenerator.gd` with Growing Tree maze algorithm
- Configurable parameters: maze_bias, wiggle, corridor width range, room count/size
- Entrance/exit placement with configurable dead-end preference and minimum distance
- BFS path validation (entrance to exit always reachable)
- Room placement with overlap prevention
- Room-to-maze connection system

#### Phase 1 polish — Connectorless room islands
`_validate_path` only verifies entrance→exit reachability, not that EVERY floor cell is reachable. The Growing Tree + room-connection step occasionally produces a small floor area (typically a tiny detached room) that the entrance can't reach — visible as an unreachable square on the F3-revealed map. Existing object placement explicitly tolerates these "pre-existing isolated regions" (see comments in `_try_place_object`), but they're a level-generation polish gap. Two possible fixes: (a) in `_validate_path`, BFS every floor cell and regenerate if any are unreachable; (b) in `_connect_regions`, also connect orphan floor pockets back to the maze. Option (b) keeps more of the level intact; (a) is a brute-force safety net. Either qualifies.

### Phase 2 — 3D Dungeon View ✅

- Flat quad rendering (walls, floors, ceilings) instead of box meshes
- Triplanar texture mapping with configurable sharpness and Y offset
- Normal map support (subtle, with ambient-only lighting)
- Biome-driven textures, fog, and ambient light via BiomeData resource
- SubViewport rendering with configurable aspect ratio per orientation
- FOV configuration
- Camera eye height configuration

### Phase 3 — Player Movement ✅

- Step-by-step grid movement with 6 actions
- Smooth camera tweening (position and rotation)
- Correct coordinate system alignment (Godot -Z = North)
- Accumulated angle tracking for rotation (no drift, no 270° snap)
- Echo filtering for keyboard input (no multi-step on key hold)

### Phase 4 — Biome System (Partial) ✅

- `BiomeData.gd` resource with texture arrays, fog, ambient light, triplanar settings
- Forest biome created with hand-drawn textures
- Biome loaded and applied at level generation time

#### Phase 4 polish — Per-placement texture selection ✅
Wall / floor / ceiling textures per biome are now selectable by cell type (Corridor / Room / Dead End) so designers can author location-specific art (mossy dead-end walls, vaulted room ceilings, worn corridor floors).
1. ✅ `BiomeTextureEntry.gd` Resource — `albedo` + `placement` flag-set reusing `PLACEMENT_CORRIDOR / ROOM / DEAD_END / ANY` from `LootEntry` / `ObjectSpawn` / `WallDecorationSpawn` + `weight` (deterministic weighted pick; 0 excludes an entry, all-zero falls back to uniform) + `min_distance_to_same` (Manhattan tiles between two placements of the same entry; constraint relaxes when nothing else fits so a quad never goes blank). Normal maps were intentionally dropped — they don't help the chunky pixel-art look under ambient-only lighting.
2. ✅ `BiomeData` switched its flat `Array[Texture2D]` fields to `Array[BiomeTextureEntry]` (`wall_textures`, `floor_textures`, `ceiling_textures`); old `wall_albedo / wall_normal / floor_albedo / floor_normal / ceiling_albedo / ceiling_normal` removed
3. ✅ `LevelGenerator.classify_cell(pos)` exposes the existing Corridor / Room / Dead-End classifier publicly so `DungeonView` can ask per cell. `classify_wall_face(pos, wall_dir)` is the per-face variant — at a dead-end cell only the BACK wall (the one facing the player walking in) keeps `PLACEMENT_DEAD_END`; side walls fall back to `PLACEMENT_CORRIDOR` so a dead-end-only texture (e.g. a giant tree mural) lands once in front rather than wrapping the cell on three sides
4. ✅ Wall side classification — a wall between a corridor cell and a room cell renders as two separate quads (one drawn from each floor cell's side); each quad inherits its host floor cell's classification, so the same wall can show mossy art on the corridor side and clean art on the room side without extra book-keeping
5. ✅ `BiomeTextureEntry.pick_for(entries, classification, cell_pos, placed_history)` static helper — three-stage filter: classification → min_distance → weighted hash. Each stage falls back to the previous pool when its filter would empty the set (designer intent: render *something* rather than a blank face). Picks deterministically from a position-hash so the same cell renders identically across mesh rebuilds, save/load, and seed replays. Caller maintains `placed_history` (entry → array of Vector2i) and appends after each pick — `DungeonView._build_mesh` keeps three (wall / floor / ceiling)
6. ✅ Material cache in `DungeonView` — one `StandardMaterial3D` per `BiomeTextureEntry`, shared across every quad resolving to it (replaces the previous "new material per quad" pattern; cleared on each `_build_mesh` so live biome edits still pick up)
7. ✅ Tests: `test_biome_texture_entry.gd` (defaults, allows() matrix, pick_for empty / matching / fallback / determinism / distribution / null-skipping)
8. ✅ Manual asset wiring (developer): `assets/biomes/forest.tres` migrated — the old single albedo / normal pair is now wrapped in a default `BiomeTextureEntry` per surface (placement = ANY). To take advantage of the new feature, drop in additional entries with narrower placement flags (e.g. a dead-end-only mossy wall variant).

### Phase 5 — UI / HUD ✅

- Full responsive HUD adapting to portrait and landscape
- TopBar with settings and map buttons
- PartyPanel with 3 CharacterSlot instances (portrait, HP/MP bars, action buttons)
- ItemBar with 10 slots in 5×2 grid layout
- MovementPad with 6 directional buttons
- All button sizes scale relative to screen short side
- Adaptive viewport ratio reduction for tablets
- UI scale reduction as fallback when viewport ratio hits minimum

### Phase 6 — Map System ✅

- Full-screen map popup with parchment background
- Fog of war exploration (current tile + 8 adjacent revealed)
- Wall-line rendering (not filled blocks)
- Exit shown as green diamond
- Player shown as blinking red directional arrow
- Debug full reveal toggle
- Map updates on every player movement

#### Phase 6 polish — Map should pause input ✅
Architected as proper world-pause via `SceneTree.paused`, not a narrow input gate, so it scales to future systems (traps, enemies, timers, tweens) and to future modal popups (settings, inventory) without per-popup wiring.

1. ✅ HUD owns a `_pause_sources: Dictionary` keyed by popup id; `add_pause_source(id)` / `remove_pause_source(id)` reflects the set onto `get_tree().paused`. The set composes — closing one popup while another is open keeps the tree paused.
2. ✅ `MapPopup` emits `pause_requested` (on open) and `pause_released` (on `_finish_close` and defensively on `_exit_tree`); HUD wires those to `add_pause_source("map")` / `remove_pause_source("map")` in `_ready`. Future settings / inventory popups follow the same signal shape.
3. ✅ `MapPopup.process_mode = PROCESS_MODE_ALWAYS` so its open / close tween, blink `_process`, and ✕ button keep working while the SceneTree is paused. Children inherit. Default popups (LootPopup, ItemDescriptionPopup) don't pause — they're gameplay-adjacent.
4. ✅ `Game._on_move` and `Game._input` both early-return via `_is_world_paused()` (reads `get_tree().paused`) — generic gate, no per-popup checks.
5. ✅ Free benefit: when traps (Phase 8 Task 3) and enemies (Phase 10) arrive with `_process` / `_physics_process` / `Timer` / `Tween` based ticks, they'll freeze automatically while a modal is up — no extra wiring per system.
6. ✅ Tests: world-pause gating is UI / SceneTree-state behaviour rather than pure logic, and both `HUD` and `MapPopup` are scene-driven (use `@onready` refs to scene children), so a programmatic GUT test can't construct them cleanly. Covered by the manual test plan instead.

---

## Upcoming Phases

### Phase 7 — Items & Loot System

**Priority: HIGH — Foundation for inventory, combat rewards, and economy**

Split into 4 incremental tasks; some sub-points depend on later phases (drag-to-equip needs Phase 9, throwables/enemy drops need Phase 10, chest loot needs Phase 8) and are deferred.

#### Task 1 — Item data foundation + first health potion ✅
1. ✅ Create `ItemData.gd` resource:
   - Item name, description, category (consumable, equipment, throwable, quest)
   - Effect type (heal HP, heal MP, stat boost, cure status, damage, inflict status)
   - Effect value, effect duration
   - Stackable / stack_max
   - Icon texture, dungeon sprite texture
   - Buy price / sell price
   - *(Equipment slot + stat modifiers deferred to Phase 9)*
2. ✅ Create `ItemInstance.gd` (runtime: data ref, stack count, durability)
3. ✅ Upgrade `ItemBar.gd` from visual-only slots to a real inventory model with auto-stacking and a stack-count badge
4. ✅ F1 debug key in `Game.gd` spawns a Health Potion into the bar
5. ✅ Asset folder scaffolding: `res://assets/items/`, `res://assets/textures/items/{icons,sprites}/`

#### Task 2 — Items on the dungeon floor ✅
1. ✅ `LootEntry.gd` resource (item + weight + placement flags: Corridor / Room / Dead End)
2. ✅ Per-biome loot pool on `BiomeData`: `floor_loot: Array[LootEntry]`, `floor_items_min`, `floor_items_max`
3. ✅ `items: Array` field on `GridCell` for per-tile piles
4. ✅ Item placement in `LevelGenerator` after BFS validation: weighted-roll a `LootEntry`, pick a random eligible cell (placement-flagged, not entrance/exit), drop an `ItemInstance`
5. ✅ Floor items rendered as `Sprite3D` billboards in `DungeonView` (FIXED_Y billboard, NEAREST filter, alpha-cut DISCARD), placed inside a runtime `ItemsRoot` Node3D under the SubViewport
6. ✅ Visual stacking: up to 3 sprites per tile with small XZ offsets so a pile is visible
7. ✅ Items persist on the floor (stored on `GridCell`) — pickup comes in Task 3

#### Task 3 — Tap-to-pickup ✅
1. ✅ `PickupPrompt` Button shown in HUD when the player stands on a tile with items, hidden otherwise. Label is `Pick up (N)` localized via `ui.pickup.prompt`.
2. ✅ Tap the prompt (or press `F` on desktop) drains every stack from the current cell into `ItemBar.pickup_from()`, with auto-stacking.
3. ✅ Sprite3Ds rebuilt after pickup so the dungeon visually reflects the empty/remaining tile.
4. ✅ Bar-full case: stacks that don't fit stay on the cell; if nothing was transferred, prompt flashes a localized "Bag full" message (`ui.pickup.bar_full`) for ~1.5 s.

#### Task 4 — Use items on party ✅
1. ✅ `Character` RefCounted holds `name_key`, `current_hp/max_hp`, `current_mp/max_mp` and `apply_item(data) → bool` (HEAL_HP / HEAL_MP for now; refuses everything else)
2. ✅ `CharacterSlot.bind(character)` connects to a Character; bars and name auto-refresh on the character's `changed` signal. HP bar is red, MP bar is blue.
3. ✅ `ItemSlotButton` (TextureButton subclass) is the drag source for every ItemBar slot; produces a translucent icon-textured drag preview centered on the cursor. `build_drag_payload()` is exposed for tests.
4. ✅ Drop on `CharacterSlot` runs `Character.apply_item`; emits `item_consumed` on success → bar stack -1, `item_rejected` on failure → HUD shows "No effect" toast. Drop area covers the whole slot rect EXCEPT the action buttons.
5. ✅ Drop on `DungeonDropTarget` (overlay over the SubViewport) drops **one** item from the source stack onto the player's current cell, decrements the bar slot by one, rebuilds Sprite3Ds and the pickup prompt
6. ✅ `Toast` component for transient HUD feedback (auto-hides after 1.2 s)
7. ✅ Game seeds 3 placeholder party members (Warrior 30 HP / 5 MP, Wizard 15 / 25, Rogue 22 / 10) so the heal flow is testable end-to-end
8. ✅ Localization: `character.placeholder.{warrior,wizard,rogue}` + `ui.feedback.no_effect`
9. ✅ Debug key F2 damages every party member by 10 HP

Mouse-filter setup (drag-drop hit areas):
- `HUDRoot` is set to `MOUSE_FILTER_IGNORE` at runtime so HUDRoot's full-screen rect doesn't reject drops landing on the dungeon area; child UI controls remain unaffected.
- `SubViewportContainer` is set to `IGNORE` so the `DungeonDropTarget` overlay child receives drops directly.
- `CharacterSlot` itself is `STOP`; portrait/bars/name/frame are `PASS` (so drops bubble to the slot's `_can_drop_data`); action buttons stay `STOP` (drops there are rejected).

Future-friendly behaviours:
- Drop on dungeon currently drops onto the current cell. The roadmap notes a future split: lower 1/3 of the dungeon view = drop on current cell; upper 2/3 = throw at enemies up to N tiles away (Phase 10 combat targeting).
- `Character` is intentionally minimal — Phase 9 will replace it with a full `CharacterData` resource (stats, equipment, spells).

#### Phase 7 polish — Item description popup ✅
Single-click (not drag) on a populated item-bar slot opens a centered modal showing the item's tinted icon, translated name, and translated description. Especially useful for Phase 8 Task 2c keys whose hue tints differ but whose name/description are identical — the popup surfaces the tint at a much larger size and pairs visually with the matching lock on the map.
1. ✅ `ItemDescriptionPopup.gd` (Control) — full-screen modal with backdrop, panel, big icon, name label, autowrap description, ✕ button
2. ✅ Built programmatically by `HUD.gd` and exposed as `item_description_popup` (mirrors the LootPopup wiring)
3. ✅ `Game.gd` subscribes to the existing `ItemBar.slot_clicked` (already emitted, previously unconnected) — empty slots are no-ops, tapping the same slot while the popup is open toggles closed
4. ✅ `Game.gd` subscribes to `ItemBar.inventory_changed` so any mutation (drag-use, dungeon drop, pickup, F1 spawn) auto-closes the popup — the popup never shows stale state
5. ✅ Drag-source isn't disturbed: `TextureButton.pressed` only fires on a complete click cycle, so `_get_drag_data` continues to win when the mouse drags past threshold
6. ✅ Per-instance icon: the popup uses `ItemInstance.get_icon()` so hue-rotated keys (Task 2c follow-up) are shown in their actual baked tint, not the data's untinted source
7. ✅ Localization: no new keys needed — `ItemData.get_display_name()` / `get_display_description()` already wrap `tr()`. The ✕ glyph is symbolic and matches LootPopup
8. ✅ Tests: `test_item_description_popup.gd` (integration) — visibility, null-instance safety, name/description content, per-instance icon for hue-shifted keys, close + backdrop signals

#### Deferred (blocked by other phases)
- Drag-to-equip (Phase 9 — character inventory)
- Drag-to-throw / throwables (Phase 10 — combat targeting)
- Item drops from enemy deaths (Phase 10)
- Chest loot tables (Phase 8 — objects/chests)

### Phase 8 — Objects & Interactables

**Priority: HIGH — Foundation for gameplay variety**

Split into 5 incremental tasks. Task 1 builds the foundation that the rest reuse.

#### Task 1 — Chests + interaction foundation ✅
1. ✅ `ObjectData.gd` Resource (category enum, blocks_movement, closed/opened sprites, world_height/y_offset, interact_sound, chest loot pool + min/max)
2. ✅ `ObjectInstance.gd` RefCounted (data + opened bool + items array — chest contents persist across popup close)
3. ✅ `ObjectSpawn.gd` Resource (per-biome entry: object + count_min + count_max + placement flags)
4. ✅ `BiomeData.objects: Array[ObjectSpawn]` for per-biome configurable spawning
5. ✅ `GridCell.object: ObjectInstance` (replaces unused `object_id`); `is_blocked` checks both walls AND blocking objects
6. ✅ `LevelGenerator._place_objects()` runs after BFS validation: for each spawn, roll count, place tentatively, re-validate full reachability (entrance can reach every floor cell AND every blocked-object's adjacent neighbour). Roll back and retry on failure.
7. ✅ `DungeonView` gains `ObjectsRoot` Node3D + `_build_objects()` + `rebuild_objects()`. Each object Sprite3D has a child Area3D + box collider tagged with the ObjectInstance for click pickability.
8. ✅ Chest interaction: click → `DungeonDropTarget` raycasts from camera, finds Area3D, emits `object_clicked(instance, grid_pos)`. Game.gd opens the chest: roll loot once, sprite swap, play `interact_sound`, open `LootPopup`.
9. ✅ `LootPopup` UI: full-screen modal showing chest contents as a grid; click slot → take that stack; "Take All" enabled via `ItemBar.would_fit_all` dry-run; click backdrop or X → close. Remaining items stay in chest for later.
10. ✅ Localization: `object.chest_wooden.name/description`, `object.chest_iron.name/description`, `ui.loot.title_chest`, `ui.loot.take_all`

#### Task 1 polish — Chest loot pickup sounds ✅
Floor pickup plays `ItemData.pickup_drop_sound` (see `Game._on_pickup_pressed`), but transferring items out of a chest via `LootPopup` was silent. Both fixes in `Game.gd`:
1. ✅ `_on_loot_item_taken(slot_index)`: snapshots `item.stack_count` before `add_item`, plays the item's `pickup_drop_sound` only when the count actually dropped (handles the bar-full edge case where nothing transferred)
2. ✅ `_on_loot_take_all()`: picks the first item-with-a-sound up-front (mirroring `_on_pickup_pressed`), plays it once at the end iff anything was transferred — single sound, never N

#### Task 2a — Decorative doors (direct-click toggle) ✅ (code; awaits manual asset/biome wiring)
Doors live on the EDGE between two adjacent corridor cells, never on a `GridCell`.
1. ✅ `DoorInstance.gd` (RefCounted, extends `ObjectInstance`) — stores `cell_a`, `cell_b` canonically; `axis()`, `is_edge_blocked()`, static `canonical_pair` / `edge_key` / `create_door` helpers
2. ✅ `ObjectData.world_width: float` (0 = keep texture aspect; > 0 forces non-uniform horizontal stretch via `Sprite3D.scale.x` so a square wall texture renders at corridor proportions)
3. ✅ `ObjectData.interactable: bool` (false = skip Area3D so clicks pass through; reserved for future archways/vaults)
4. ✅ `ObjectSpawn.must_gate_content: bool` (reserved for Task 2c; default false)
5. ✅ `LevelGenerator.doors: Array[DoorInstance]` + `_doors_by_edge` index; `_place_doors()` runs after `_place_objects()`. Door endpoints must be 1-cell-wide-corridor cells (exactly 2 non-wall neighbours each), neither entrance/exit, neither holds a chest. `min_distance_to_other_object` honoured with the same graceful-degrade-by-1 approach chests use. `is_edge_blocked(a, b)` is the single source of truth for movement.
6. ✅ `PlayerController._step()` wall-bumps when `LevelGenerator.is_edge_blocked(current, target)` is true
7. ✅ `DungeonView._build_doors()` (separate code path from `_build_objects`): each door is a `Node3D` anchored at the edge midpoint, Y-rotated to the corridor axis; non-billboarded `Sprite3D` (with optional `scale.x` stretch); SIBLING `Area3D` + box collider so the sprite's `scale.x` doesn't deform the collider. Door positions are STATIC — never refreshed on movement or turn — so they cannot drift.
8. ✅ `Game._on_object_clicked` dispatches `DoorInstance` to a toggle handler that flips `opened`, plays `interact_sound`, and calls `DungeonView.rebuild_doors()`
9. ✅ `MapPopup` draws door slabs on cell boundaries (filled when blocking, outline when open) — only when both endpoints are explored
10. ✅ Localization: `object.door_forest.name`, `object.door_forest.description`
11. ✅ Tests: `test_door_instance.gd` (unit), door placement integration tests in `test_level_generator.gd`
12. ✅ Manual asset work (developer): `res://assets/objects/door_forest.tres` + textures + sound; door spawn added to `res://assets/biomes/forest.tres`

#### Task 2b — Levers + linked doors ✅ (code; awaits manual asset/biome wiring)
The lever lives on a `GridCell.object` (chest-style cell-bound object). The door lives on an edge (Task 2a). They cross-link at placement time so each remembers the other.
1. ✅ `LinkedObjectSpawn.gd` Resource (biome-level pair entry: lever_object, door_object, count, lever_placement, lever_min_distance / door_min_distance for anti-clustering, lever_to_door_min_distance / lever_to_door_max_distance for puzzle spread, door_must_gate_content reserved for 2c)
2. ✅ `BiomeData.linked_objects: Array[LinkedObjectSpawn]` (separate from `objects` so chests/decorative-doors keep their simple shape)
3. ✅ `LeverInstance.gd` (RefCounted, extends `ObjectInstance`) — `linked_doors: Array`, `pulled: bool`, `toggle()`, `get_visual_opened()` returns `pulled` directly
4. ✅ `DoorInstance.linked_levers: Array` + `lever_logic` (AND/OR) + `compute_lever_opened()` + `is_lever_locked()`
5. ✅ `ObjectInstance.get_visual_opened()` virtual method (default returns `opened`) — DungeonView reads it instead of `opened` for cell-bound rendering, so the chest contract stays unchanged
6. ✅ `LevelGenerator._place_linked_objects()` runs after `_place_doors()`. For each pair: pick a 1-wide corridor edge for the door (reuse decorative-door eligibility), then pick a chest-style cell for the lever that's reachable from the entrance EVEN WITH the linked door treated as closed. Rolls back the door if no lever cell qualifies, so we never ship orphan halves.
7. ✅ `Game._on_object_clicked` dispatches `LeverInstance` to a pull handler that toggles `pulled`, recomputes each linked door's state via `compute_lever_opened()`, plays sound, and rebuilds both door and cell-object visuals. Lever-locked doors show locked/partial feedback on direct click.
8. ✅ `MapPopup` draws lever as a small slate diamond (filled when un-pulled; outline-only when pulled) so players can find their levers from the map
9. ✅ Localization: `object.lever_forest.name`, `object.lever_forest.description`
10. ✅ Tests: `test_linked_object_spawn.gd`, `test_lever_instance.gd` (unit); linked-pair placement integration tests in `test_level_generator.gd`
11. ⏳ Manual asset work (developer): `res://assets/objects/lever_forest.tres` (closed = lever down, opened = lever up sprites), lever sprites + interact sound, add a `LinkedObjectSpawn` entry to `res://assets/biomes/forest.tres`

#### Task 2b critical fix — Multi-pair lever reachability ✅
**Bug:** With multiple `LinkedObjectSpawn` pairs the placement check was per-pair only — already-placed sibling doors weren't taken into account. Two doors could land with both levers behind both doors, hard-stucking the player at game start.

**Fix:** Replaced the single-edge check with a **chain-reachability** simulation in `LevelGenerator`:
1. ✅ `_chain_reachable_from_entrance()` — iterative fixed-point. Lever-locked doors are excluded from initial open-set. Each iteration collects reachable levers, then evaluates each lever-locked door under its AND/OR logic. BFS again until no progress.
2. ✅ `_try_place_cluster()` snapshots `pre_chain` before each attempt; places doors then levers; validates `pre_chain ⊆ post_chain ∪ {lever_cells}` AND all cluster levers have chain-reachable neighbours. Failures roll back entire cluster atomically.
3. ✅ Permits progressive gating but rejects cycles. Implicit consequences: existing levers stay reachable, existing chests stay interactable, exit stays reachable (all were in `pre_chain`).
4. ✅ Dropped the now-redundant `_lever_placement_preserves_reachability` and `_bfs_walkable_with_closed_edges_and_wall` helpers.
5. ✅ Tests: `test_every_lever_chain_reachable_with_three_pairs` + `test_exit_remains_chain_reachable_with_linked_pairs` exercise the cycle case across multiple seeds.

#### Task 2b polish — Locked-door click feedback ✅
The renderer-level meaning of `ObjectData.interactable` shifted: instead of "skip Area3D so clicks pass through" (the original 2a meaning, never used in practice), `interactable = false` now means "click registers but plays a locked sound + HUD toast instead of toggling". Used today to make lever-controlled doors feel like they're really locked when the player clicks them; will extend without further wiring to Task 2c key-locked doors.
1. ✅ `ObjectData.locked_sound` (feedback SFX) and `ObjectData.locked_message_key` (toast translation key)
2. ✅ `DungeonView` always builds the door's Area3D — the click must register either way for feedback to fire
3. ✅ Every Game.gd click dispatch (chest / door / lever) short-circuits to `_play_locked_feedback` when `instance.data.interactable` is false
4. ✅ Localization: `object.door_forest.locked`

#### Task 2c follow-up — Per-pair key tint (visual differentiation) ✅
Multiple key-locked pairs in the same biome shared the same `key_*.tres`, so all keys looked identical even though they unlocked different doors. Fixed by baking a per-pair hue-rotated copy of the key's icon + dungeon sprite at level-gen time. The first attempt used multiplicative `modulate` Color tinting, which only produced brightness variations on a strongly-coloured base sprite (yellow key + blue tint = darker yellow, not blue). Replaced with a real per-pixel hue rotation that's independent of the base sprite's colour.
1. ✅ `ItemInstance.hue_shift: float = 0.0` plus cached `_tinted_icon` / `_tinted_dungeon_sprite` (private). `apply_hue_shift(shift)` bakes the recoloured textures via a per-pixel HSV rotation pass (preserves saturation, value, alpha). `get_icon()` / `get_dungeon_sprite()` return the baked textures when present, else fall back to `data.*`.
2. ✅ `LevelGenerator._hue_shift_for_pair_index(i)` — pair 0 returns 0.0 (no shift); pair ≥ 1 returns `fmod(i * 0.618, 1.0)` (golden-ratio steps for good colour-wheel separation even with small N).
3. ✅ `_try_place_key_door_pair` propagates the global counter as `pair_index` to floor + chest placement, which calls `key_inst.apply_hue_shift(...)` after creating the instance.
4. ✅ Renderers updated to call `inst.get_icon()` / `inst.get_dungeon_sprite()`: `ItemBar._refresh_slot` (TextureButton.texture_normal), `DungeonView._make_item_sprite` (Sprite3D.texture, signature now takes ItemInstance), `LootPopup` (slot button texture).
5. ✅ Tests: `test_item_instance` extended (`hue_shift` default; `apply_hue_shift` clears cache when shift is 0; baked pixels actually rotate hue); `test_keys_are_hue_shifted_per_pair_index` (integration — pair 0 falls through to data.icon, pair ≥ 1 has non-zero shift and a distinct baked icon).

#### Task 2b follow-up — Enforce `door_must_gate_content` on LinkedObjectSpawn ✅
1. ✅ `LevelGenerator._try_place_linked_pair` now calls `_door_gates_content(door)` after `_try_place_lever_for_door` commits the pair; on rejection, both halves are rolled back via the new `_rollback_linked_pair` helper and the loop tries another edge
2. ✅ Default stays `false` so existing biomes / tests keep their previous behaviour — designers opt in per spawn
3. ✅ Tests: `test_linked_must_gate_content_rejects_useless_locks` (every placed lever-locked door gates a chest / lever / key / exit) and `test_linked_pair_rollback_clears_lever_cell_when_must_gate_rejects` (multi-seed: every lever cell still resolves to a door in `gen.doors`, no orphan levers shipped)

#### Task 2b follow-up — M:N lever ↔ door clusters ✅
Generalised from 1:1 pairs to M:N clusters. Each `LinkedObjectSpawn` produces N independent clusters, each containing `levers_per_cluster` levers and `doors_per_cluster` doors, all cross-linked. Doors evaluate their opened state under a per-cluster AND/OR rule (`lever_logic`).
1. ✅ **Lever model:** `LeverInstance.pulled: bool` + `toggle()` — lever now has its own state. `get_visual_opened()` returns `pulled` directly (no longer derives from linked doors). `Game._pull_lever` toggles `pulled` and recomputes each linked door via `door.compute_lever_opened()`.
2. ✅ **Door model:** `DoorInstance.LeverLogic` enum (AND/OR), `lever_logic` field, `is_lever_locked()`, `compute_lever_opened()`. AND: all levers must be pulled. OR: any one suffices. Lever-locked doors never toggle via direct click — `Game._toggle_door` shows locked/partial feedback instead.
3. ✅ **Partial locked feedback:** `ObjectData.partial_locked_message_key` — shown for AND-logic doors when some (but not all) levers are pulled. Falls back to `locked_message_key` when empty.
4. ✅ **LinkedObjectSpawn cluster shape:** `levers_per_cluster`, `doors_per_cluster`, `lever_logic` fields. Defaults (1, 1, AND) preserve backward compat with existing biome .tres files.
5. ✅ **Placement:** `_try_place_cluster` places doors first, then levers via farthest-first heuristic with one-lever-per-room uniqueness. Distance constraints degrade gracefully (~30 attempts). Atomic rollback of entire cluster on failure.
6. ✅ **Chain simulator fix:** Initial open-set now excludes lever-locked doors (regardless of `interactable`). Lever evaluation uses AND/OR logic: collects reachable levers into a set, then evaluates each door's `lever_logic` over its linked levers. Both production and test-side simulators updated.
7. ✅ **Tests:** Unit tests for pulled/toggle/visual, LeverLogic/compute/is_lever_locked, cluster shape fields. Integration tests for 2:1, 1:2, 2:2 cross-linking, lever_logic propagation, chain reachability, atomic rollback.

#### Task 2b follow-up — Rename `LinkedObjectSpawn` → `LeverDoorSpawn`
Cosmetic rename to mirror `KeyDoorSpawn`'s naming pattern. Touches the class file (`scripts/LinkedObjectSpawn.gd` → `LeverDoorSpawn.gd`), `BiomeData.linked_objects` field name (→ `lever_door_spawns`), every `.tres` referencing the old class (`forest.tres`), function names (`_place_linked_objects` → `_place_lever_doors`), pool variable (`linked_objects_pool` → `lever_door_spawns_pool`), and tests. No behaviour change.

A first attempt (`claude/rename-lever-door-spawn`) ran into Godot import-cache errors at runtime — `forest.tres` parser still referenced `LinkedObjectSpawn.gd` after the file was renamed, despite the `.uid` companion being preserved. Diagnosis still pending; the abandoned branch is on remote for inspection. Re-attempt once we understand whether this needs a cleaner cache wipe or a different rename procedure (e.g. let the Godot editor do the rename so it can update all `.tres` references via UID resolution).

#### Task 2c — Locked doors + gating placement ✅ (code; awaits manual asset/biome wiring)
A door tagged with a `lock_id` requires a matching key item (`ItemData` with `key_id == lock_id`). On click without the key: locked feedback (sound + toast). On click with the key: one count of the key is consumed from the bar, the door unlocks PERMANENTLY, and toggles open. Future clicks behave normally.
1. ✅ `ItemData`: added `KEY` to the `Category` enum, plus `key_id: String` (per-data default; usually empty so per-placement override on `ItemInstance` carries the auto-generated lock id)
2. ✅ `ItemInstance`: added `key_id: String` (per-instance override) and `get_key_id()` helper. Two keys with different ids never stack even when sharing an `ItemData`.
3. ✅ `DoorInstance`: added `lock_id: String`, `unlocked: bool`, and `is_key_locked()`. The `unlocked` flag is sticky — once true, the door behaves like a normal interactable door.
4. ✅ `KeyDoorSpawn.gd` Resource (biome-level pair entry): door_object, key_item, count_min/max, lock_id_prefix (auto-generates `<prefix>_<index>` ids when blank), door_must_gate_content (default TRUE), `key_spawn_locations` flag-set (Floor / Chest / Enemy Drop), `key_floor_placement`, all distance fields mirroring LinkedObjectSpawn
5. ✅ `BiomeData.key_door_spawns: Array[KeyDoorSpawn]` — placed AFTER linked_objects
6. ✅ `LevelGenerator._place_key_doors()` — for each pair: pick a corridor edge for the door, pick a key location per the spawn's flags (random with fallback when multiple are checked), validate via chain reachability v2. Failures roll back the door + the key (no orphan halves).
7. ✅ Chain reachability v2: extends the iterative fixed-point to also COLLECT keys (floor + chest contents) and UNLOCK matching doors. Permits progressive gating across keys and levers; rejects cycles.
8. ✅ `must_gate_content` enforcement: simulates "this door permanently closed" and rejects the placement if no chest, lever, key, or exit becomes unreachable. Captures the "lever counts as gated content" nuance.
9. ✅ Enemy Drop: reserved (Phase 10). Flag exists; placement falls back to the next enabled location with a `push_warning` if Enemy Drop is the only one set.
10. ✅ `Game._toggle_door`: key-locked branch consumes a matching key from the bar, sets `unlocked = true`, and falls through to the normal toggle. No matching key → locked-feedback path with the door's per-data message ("It's locked. You need the right key.").
11. ✅ Localization: `object.door_forest_locked.{name,description,locked}`, `item.key_forest.{name,description}`
12. ✅ Tests:
    - Unit: `test_door_instance` extended (lock_id default, is_key_locked, sticky unlock); `test_item_data` extended (KEY enum, key_id default); `test_item_instance` extended (per-instance override, no-stacking with mismatched ids); new `test_key_door_spawn`
    - Integration: locked doors get auto-generated lock_ids; floor keys 1-to-1 with locked doors; key chain-reachable before its door; chain v2 unlocks via collected keys; must_gate_content rejects useless locks; KEY_LOCATION_CHEST plants the key inside a chest
13. ✅ Manual asset work (developer): `res://assets/objects/door_forest_locked.tres`, `res://assets/items/key_forest.tres` + textures + sounds, `KeyDoorSpawn` entry in `forest.tres`
14. ✅ Polish — weighted location lottery + no-duplicate-keys-per-chest:
    - `KeyDoorSpawn.floor_weight` / `chest_weight` / `enemy_drop_weight` (default 1 each = even). The per-pair location is picked weighted-random; setting `chest_weight = 3` biases pairs toward chest spawns, etc.
    - `KeyDoorSpawn.allow_multiple_keys_per_chest: bool = false` — skips chests already holding any key when placing a new one, so keys spread across multiple chests instead of stacking.

#### Task 3 — Traps

Split into two subtasks. Subtask A lands the core trap system (data, rendering, behaviour, simple distance-based placement); Subtask B layers the corridor-segment / room-density / clear-path placement rules on top.

##### Subtask A — Core trap system + step + timed spike traps ✅ (code; awaits manual asset/biome wiring)
1. ✅ `TrapData.gd` Resource — `trigger: enum { STEP, TIMED }`, `damage`, STEP timings (`step_activation_duration`, `step_cooldown_duration`), TIMED timings (`timed_up_duration`, `timed_down_duration`, `timed_initial_offset`), art (`holes_sprite`, `extended_sprite`, `world_height`, `hole_world_size`, `y_offset`), per-cell layout (`grid_cols`, `grid_rows`, `grid_inset`), audio (`activate_sound`, `deactivate_sound`, `hearing_distance` for TIMED spatial falloff)
2. ✅ `TrapInstance.gd` RefCounted — pure state machine (`state` RETRACTED/EXTENDED, `timer`, `on_cooldown`, `cell`). `tick(delta) → Event` (NONE / ACTIVATED / DEACTIVATED) so callers don't re-derive transitions. `on_player_step()` flips state for STEP traps and returns whether damage should apply. STEP cooldown blocks re-trigger; zero-cooldown traps re-trigger on every entry. TIMED `timed_initial_offset` lets the placer phase-shift traps so they don't pop in unison.
3. ✅ `TrapSpawn.gd` Resource — biome-level entry: `trap`, `count_min`, `count_max`, `placement` flags (Corridor / Room / Dead End reusing ObjectSpawn's bits), `min_distance_to_other_trap` with graceful-degrade-by-1.
4. ✅ `GridCell.trap` field (separate slot from `cell.object` — placement enforces "trap OR object, not both"). Traps NEVER block movement.
5. ✅ `BiomeData.trap_spawns: Array[TrapSpawn]` — placed AFTER all object passes (so trap cells are guaranteed free of chests / doors / levers) and BEFORE items (so loot doesn't pile on a hazard).
6. ✅ `LevelGenerator._place_traps()` — simple distance-based placement reusing the same flag-based candidate pool model objects use. Skips entrance / exit. Removes placed cells from `cells_by_type` so subsequent traps in the same biome don't re-pick. Updates `_classify_floor_cells` to also exclude trap cells so the item pass skips them.
7. ✅ `LevelGenerator.traps: Array[TrapInstance]` — flat list mirroring `cell.trap` per-cell lookups so the per-frame tick iterates without re-scanning the grid.
8. ✅ `DungeonView` rendering — new `TrapsRoot` Node3D + `_build_traps()` + `rebuild_traps()` + `update_trap_visual(trap)` + `play_trap_sound(trap, stream)`. Each trap is TWO pieces under a per-trap root: a flat `MeshInstance3D` quad for the holes (always visible, lying horizontal at Y = 0.01, alpha-scissor) + a per-spike `Sprite3D` billboard tree under a "Spikes" Node3D (visible only when EXTENDED). Spikes spread evenly across the cell via `grid_cols × grid_rows` with `grid_inset` controlling cell-edge distance — N individual billboards parallax against each other for a 3D feel at close range. TIMED traps additionally get an `AudioStreamPlayer3D` child positioned at the spike-cluster centre with `max_distance = data.hearing_distance` (linear-feeling falloff via inverse-distance attenuation).
9. ✅ `Game.gd` behaviour — `_process(delta)` advances every trap and reacts to events. `_on_player_entered_cell()` (called when grid_pos changes) handles STEP traps. ACTIVATED on TIMED with player-on-cell → damage. STEP traps' activate / deactivate sounds route through SoundManager (non-spatial since the player is right there); TIMED routes through the per-trap 3D player. `_apply_party_damage(amount)` is the unified damage entry point: damages all 3 party members + shake + flash + pain sound. World-pause gates the tick belt-and-braces.
10. ✅ Damage feedback — `DungeonView.shake_camera(0.7)` (already existed), `DamageFlash` ColorRect overlay (new — full-rect, sits ABOVE every other HUD element so the red tint covers both the dungeon view and the rest of the HUD; tween 0 → 0.4 → 0 over 0.3s, kills in-flight tween before each new flash), `AudioConfig.pain_sound` played non-spatially via SoundManager.

##### Subtask A — feel iteration (after first developer playtest)
- ✅ **Sprite proportions** — bumped default `world_height` from 0.5 → 1.2 so spikes feel substantial against the 1.0-unit hole, added `spike_world_width` so designers can stretch the spike base independently of the texture's natural aspect (set to match `hole_world_size` for spikes that fill their hole)
- ✅ **Step trap teleport fix** — original implementation killed the in-flight movement tween before shaking, which played as instant snap onto the trap. Replaced with a 0.13s await in `Game._on_player_entered_cell` so the move tween has visibly completed before the spike pops, screen flashes, and shake hits. The kill-move-tween is kept as defensive (any future damage source that fires shake without deferring won't fight the move tween).
- ✅ **Timed trap audio path** — original `AudioStreamPlayer3D` per trap had inconsistent listener routing inside the SubViewport (sounds went silent). Replaced with non-spatial SoundManager + manual hearing gate (`_player_within_trap_hearing(trap)`): in-range plays at full volume, out-of-range stays silent. Drops the smooth distance falloff curve in exchange for reliability — Phase 19 audio polish can revisit.
- ✅ **Walk-onto-extended damage** — TIMED traps now damage when the player walks onto an already-extended cell (was: damage only on `RETRACTED → EXTENDED` transition). New `TrapInstance.damage_applied_this_extension` latch caps it at one damage per up phase; reset by the state machine on every fresh extension. Game.gd sets the latch from both the ACTIVATED-with-player-on-cell path and the walk-onto-extended path.
- ✅ **Spike vertical alignment** — added `spike_lean_toward_player: float` to TrapData. Mirrors `ObjectData.lean_toward_player` but only nudges the SPIKE subtree — the floor holes stay anchored to the cell centre. Refreshed on player turn (same trigger as the chest lean) so the lean axis follows facing without snapping mid-step.
11. ✅ Localization: `trap.spike_step.{name,description}`, `trap.spike_timed.{name,description}`.
12. ✅ Tests: `test_trap_data` (defaults, is_step / is_timed predicates, key resolution); `test_trap_instance` (state transitions for both triggers, cooldown gating, zero-cooldown immediate clear, timed phase-shift via initial_offset, null/zero-delta safety, damages_on_presence predicate); `test_trap_spawn` (defaults, placement allows matrix); `test_grid_cell` extended (default trap is null, trap doesn't block movement); integration tests in `test_level_generator` (count_min/max, no-spawn-on-entrance/exit, floor-only, classification respect, trap ↔ object cell exclusivity, items skip trap cells, min_distance graceful degrade, flat-list ↔ grid-slot consistency, timed initial state).
13. ⏳ Manual asset work (developer): `res://assets/textures/objects/spike_hole.png` (single hole, top-down view, transparent background, ~64×64), `res://assets/textures/objects/spike_extended.png` (single spike, side view, transparent background, ~64×128). Two `.tres` files: `res://assets/objects/trap_spike_step.tres` (TrapData with STEP trigger) and `res://assets/objects/trap_spike_timed.tres` (TrapData with TIMED trigger). Sounds: `spike_activate.ogg`, `spike_deactivate.ogg`, `pain.ogg`. Add `TrapSpawn` entries to `forest.tres` and reference `pain_sound` in `audio_config.tres`.

##### Subtask B — Advanced placement

Split into three incremental sub-PRs so each one has something testable in-engine before merging.

###### Subtask B1 — Corridor segment detection + cluster placement ✅ (code; awaits developer playtest)
1. ✅ `_detect_corridor_segments()` on `LevelGenerator` — connected-components over corridor-classified cells, excluding "junctions" (corridor cells with 3+ corridor neighbours) so two corridors meeting at a T don't merge into one giant segment. Returns `Array[Array[Vector2i]]`.
2. ✅ `TrapSpawn` extended with `corridor_segment_chance: float` (per-segment roll), `corridor_traps_per_run_min/max: int` (cluster size). Defaults preserve Subtask A's scattered-only behaviour. `uses_corridor_clusters()` predicate gates the new pass.
3. ✅ `_place_corridor_traps()` runs BEFORE the legacy scattered pass on the same spawn — modes are additive. Per-segment rules:
   - Skip if the segment already holds traps from a previous spawn's pass (one spawn per segment so the player reads "this corridor is poisoned with X" rather than a layered hazard)
   - Skip if the segment is **junction-adjacent** to a segment that already holds traps. Without this, two clusters separated only by a non-trappable junction cell read as one long run with a single safe tile in the middle, forcing more damage than the per-segment max would suggest. Caught during developer playtest; fix lives in `_segment_blocked_by_existing_traps`.
   - Skip if eligible-cell count < `corridor_traps_per_run_min` (silent under-delivery is worse than placing fewer traps elsewhere)
   - Otherwise pick a random eligible start cell and BFS-flood within the segment to gather up to N contiguous cells (N rolled in [min, max], clamped to eligible count)
   - Cluster cells are tracked in `_cluster_cells` and the **scattered pass excludes any candidate 4-adjacent to a cluster cell**. Without this, a 5-cell segment with a 3-cell cluster leaves the 2 leftover cells eligible for the scattered pass, producing a contiguous 5-trap run that defeats the per-segment cluster cap. Caught during developer playtest of an S-shaped corridor.
4. ✅ `MapPopup.debug_show_traps: bool = false` — when on, draws a small upward triangle on every explored trap cell (red = STEP, orange = TIMED). Off by default in shipping; flip on in the Inspector to validate placement.
5. ✅ Tests: unit (`test_trap_spawn` extended — corridor field defaults, `uses_corridor_clusters` matrix); integration (`test_level_generator` extended — segments only contain corridors, exclude junctions, are disjoint; clusters lay consecutive cells; corridor-only landing; chance=0 produces no traps; run size ≤ max; second spawn skips already-trapped segments).
6. ⏳ Manual asset work (developer): bump `corridor_segment_chance` and `corridor_traps_per_run_min/max` on a `TrapSpawn` in `forest.tres` to validate placement in-engine. The new fields default to 0/1/3 so existing biome configs keep their previous scattered-only behaviour until the developer opts in.

###### Subtask B2 — Room density placement ✅ (code; awaits developer playtest)
1. ✅ `TrapSpawn` extended with `room_chance: float` (per-room roll), `room_coverage_min_percent / max_percent: float` (target coverage range), `room_min_spacing: int` (visual rule — Manhattan spacing between traps in the same room, cross-spawn), `room_max_distance_to_safe_cell: int` (gameplay rule — every walkable cell in or near the room must have a non-trap walkable cell within N Manhattan tiles, so dense coverage rolls can't strand the player without a step-to-safety), `allow_mixed_room_traps: bool` (default true — opt out for "this room is one trap type" exclusivity, mirroring the one-spawn-per-segment rule for corridor clusters). `uses_room_density()` predicate gates the new pass.
2. ✅ `_place_room_traps()` runs AFTER the corridor pass and BEFORE the scattered pass on the same spawn — modes are additive. Per-room rules:
   - Skip if `randf() >= room_chance`
   - Skip if `not allow_mixed_room_traps` and the room already holds traps from a prior spawn
   - Roll target coverage in [min, max], compute target count = ceil(eligible_cells × coverage)
   - Random-walk eligible cells, placing traps that satisfy `room_min_spacing` against ALL existing traps in the same room (cross-spawn)
   - Stop early if no candidate fits — graceful degrade when spacing over-constrains coverage
3. ✅ Tests: unit (`test_trap_spawn` extended — room field defaults, `uses_room_density` matrix); integration (`test_level_generator` extended — zero-chance places nothing, room-only landing, `room_min_spacing` honoured cross-room and cross-spawn, coverage falls within rolled range, entrance/exit excluded, `allow_mixed_room_traps = false` blocks second spawn from sharing rooms, `= true` allows mixed rooms).
4. ⏳ Manual asset work (developer): bump `room_chance` and `room_coverage_min/max_percent` on a `TrapSpawn` in `forest.tres` to validate room placement in-engine. Mix two spawns with `allow_mixed_room_traps` flipped differently to test exclusivity.

###### Subtask B3 — Path-safety validators + chest/lever adjacency ✅
1. ✅ **Trap placement skips floor-item cells** — `_eligible_segment_cells`, `_eligible_room_cells`, and `_trap_candidates_for_spawn` all skip cells where `cell.items` is non-empty, preventing step traps from landing on floor keys placed by `_place_key_doors`.
2. ✅ **`_remove_trap_at(pos)`** — single entry point for trap removal: clears `cell.trap`, removes from the `traps` flat list, removes from `_cluster_cells` if present. Used by both validators below.
3. ✅ **Chest/lever timed-trap adjacency** (`_validate_chest_lever_timed_adjacency`) — scans every chest/lever cell; if no 4-adjacent walkable cell is free of TIMED traps, removes one timed trap from a neighbour. Step traps adjacent are OK (they're one-shot, the player can wait off-cell after triggering).
4. ✅ **Step-trap-free reachability** (`_validate_step_trap_reachability`) — Dijkstra from entrance to ALL reachable cells: step-trap cells cost 100, regular walkable cells cost 1, blocking objects/walls impassable, doors passable. Traces cheapest paths to exit + every chest (via adjacent cell) + every lever + every floor-item cell, removes every step trap along those paths in one batch. Runs AFTER `_place_items()` so floor-item positions are known. Guarantees damage-free routes to all interactive content while preserving trap density (~30 removals on a 200+ trap level, avg 135 surviving).
5. ✅ **Timed-trap safe distance** (`_validate_timed_trap_safe_distance`) — enforces `room_max_distance_to_safe_cell` globally (not just within rooms). Corridor clusters meeting room edges can create long timed-trap runs exceeding the per-room guarantee; this pass removes timed traps until every walkable cell has a non-timed-trap walkable cell within K tiles (K = max across all spawns).
6. ✅ Tests: integration (`test_level_generator` extended — exit reachable without step traps across 5 seeds with dense configs, chests reachable via adjacent cell, floor items reachable, average trap count stays high >50, `_remove_trap_at` clears cell + list + cluster_cells, traps never share cells with floor items, chest/lever timed adjacency guaranteed, timed-trap safe distance enforced globally, step traps adjacent to chests are allowed).
7. ⏳ Manual playtest (developer): run in-engine with `forest.tres` using step trap variant, verify: (a) there's always a damage-free path to exit, chests, levers, and items, (b) trap density is visually high, (c) chests near timed traps have a safe waiting spot, (d) room-to-corridor transitions don't create excessively long timed-trap runs.

##### Subtask C — Projectile trap system

A new sibling system to spike traps: wall-mounted launchers that fire projectiles across cells until they hit a wall. Data-driven so one code path supports many variants (fireballs, darts, poison darts, ice shards). Two trigger modes (TIMED / PRESSURE_PLATE). Status effects on hit (poison / burn / slow) live on the data resource now but their gameplay application is deferred to a later phase. **Naming note:** the spec is sometimes referenced as "fireball trap" — Projectile Trap is the canonical name (fireball is one variant among several).

This is a SEPARATE system from `TrapData` — projectile traps are wall-mounted (not cell-bound), they have a flight phase, and their placement logic is fundamentally different. They do NOT share `GridCell.trap`; they live on `LevelGenerator.projectile_traps` keyed by wall face (cell + wall_dir), like wall decorations.

Split into six sub-PRs so each one has something testable in-engine before merging.

###### Subtask C1 — Data resource + corridor placement + static launcher rendering ⏳
1. ⏳ `ProjectileTrapData.gd` Resource — `trigger: enum { TIMED, PRESSURE_PLATE }`, `damage`, flight (`speed_cells_per_second`), TIMED timings (`timed_period`, `timed_initial_offset`), placement constraints (`max_escape_distance`, `min_plate_to_launcher_distance`, `max_plate_to_junction_distance`, `min_distance_to_other_projectile_trap`), 4-direction projectile sprites (`projectile_sprite_front` mandatory + optional `_back`/`_left`/`_right` with front fallback), launcher art (`launcher_texture`, `launcher_world_height`, `launcher_horizontal_offset`, `launcher_y_offset`, `launcher_depth_offset`), pressure-plate art (`plate_texture`, `plate_world_size`), projectile art (`projectile_world_height`, `projectile_y_offset`), audio (`launch_sound`, `impact_sound`, `plate_sound`, `hearing_distance` for TIMED), status effect data (`status_effect_id: String`, `status_effect_duration: float`, `status_effect_magnitude: float` — populated now, gameplay deferred).
2. ⏳ `ProjectileTrapInstance.gd` RefCounted — placement record holding `data`, `cell` (host floor cell), `wall_dir` (cardinal direction into the wall). `fire_direction()` returns `-wall_dir`. `face_key()` / `get_face_key()` mirror `WallDecorationInstance` so the same `_wall_faces_used` registry blocks decorations from sharing the wall. `plate_cell` field defined now (Vector2i.MAX sentinel = no plate); populated by Subtask C4.
3. ⏳ `ProjectileTrapSpawn.gd` Resource — biome-level entry: `trap`, corridor placement (`corridor_chance`, `corridor_max_per_segment`), room placement fields (`room_chance`, `room_max_per_room` — defined but unused until Subtask C5), `placement` flags reusing `ObjectSpawn.PLACEMENT_*` bits.
4. ⏳ `BiomeData.projectile_trap_spawns: Array[ProjectileTrapSpawn]` — placed AFTER spike traps and BEFORE wall decorations so the wall-face registry is shared and decorations can't claim a launcher's face.
5. ⏳ `LevelGenerator.projectile_traps: Array[ProjectileTrapInstance]` + `_place_projectile_traps()` + `_place_corridor_projectile_traps()` — for each corridor segment: roll `corridor_chance`, reject the segment if it already holds a launcher from a prior spawn (fast short-circuit for the common case), find candidate (cell, wall_dir) tuples. The candidate validator walks the FULL projectile flight (from `cell + fire_direction` until it hits a wall — past the escape junction) and rejects if: any path cell is a non-corridor floor (room) or non-FLOOR cell type, any path cell is the EXIT, any path cell holds a CHEST or LEVER (projectiles crossing reward / interactive points feel unfair), any path cell is already on another placed launcher's path (no crossfire — covers both same-segment and "two perpendicular corridors targeting the same T-junction" cases), or no junction exists within `max_escape_distance` tiles. Excludes faces already in `_wall_faces_used`, enforces `min_distance_to_other_projectile_trap` Manhattan spreading (no graceful degrade — skip if too close), per-spawn cap on top. Maintains `_projectile_path_cells: Dictionary` of every cell on every placed launcher's path so the no-overlap rule is O(path_size) per check.
6. ⏳ `DungeonView` static launcher rendering — `ProjectileTrapsRoot` Node3D under SubViewport, one Sprite3D per launcher anchored at the wall-face midpoint, Y-rotated to match the wall mesh, `pixel_size = launcher_world_height / texture_height`, horizontal/vertical/depth offsets applied. No firing yet.
7. ⏳ `MapPopup.debug_show_projectile_traps: bool = false` — when on, draws a small cyan arrow on the wall edge between every explored launcher and its mount wall, pointing in `fire_direction()`. Drawn on the wall edge (not inside the cell) so the marker reads as "launcher on the wall" rather than "launcher on the floor". Off by default in shipping; flip on in the Inspector to validate placement.
8. ⏳ Localization: `projectile_trap.fireball_timed.{name,description}` (sample variant).
9. ⏳ Tests: unit (`test_projectile_trap_data` defaults / sprite-direction fallbacks; `test_projectile_trap_instance` face_key, fire_direction); integration (`test_level_generator` extended — corridor placement points fire direction toward a junction, escape distance honoured, no shared wall face with decorations, spreading respected).
10. ⏳ Manual asset work (developer): `res://assets/textures/objects/wall/fireball_launcher.png` and a `res://assets/textures/objects/projectiles/fireball_front.png` (other directional slots optional — a spherical fireball can fall back to FRONT). One `.tres` `res://assets/objects/traps/projectile_trap_fireball_timed.tres`. Wire a `ProjectileTrapSpawn` into a forest biome `.tres`. Pressure plate decals and impact / launch SFX can wait until later subtasks.

###### Subtask C2 — TIMED firing + projectile flight + 4-direction sprite + impact (no damage) ⏳
1. ✅ `ProjectileInstance.gd` RefCounted — flight state: `data`, `cell_pos: Vector2` (continuous, float-based), `direction: Vector2i` (cardinal), `damage_latch: bool` (defined now, used in C3). `tick(delta, grid, gw, gh) → Event` (NONE / IMPACT) walks integer cells one-at-a-time so a high-speed projectile still impacts the FIRST wall it meets, not whichever cell new_pos lands in. On IMPACT, `cell_pos` is clamped to the wall's near face so the visible projectile sits on the wall, not inside it. Pure state machine — no node access; the grid is passed in read-only so unit tests can drive it with a fake grid in pure code. Also exposes a static `view_for_camera(direction, camera_forward_xz) → CameraView` (FRONT/BACK/LEFT/RIGHT) using dot/cross — DungeonView calls it each frame to pick the right sprite for the current camera angle.
2. ✅ TIMED trigger logic on `ProjectileTrapInstance` — new `timer` and `in_flight` fields. `tick(delta) → ProjectileInstance` advances `timer`; on rollover (`timer >= timed_period`) returns a new `ProjectileInstance` starting at the wall face inside the host cell, flying in `fire_direction()`. `LevelGenerator` rolls a per-instance `randf() * period` phase shift on top of the data's `timed_initial_offset` so multiple TIMED launchers placed in the same area desync. Tests building instances directly stay deterministic (random shift only happens in the placer, which already runs under a seeded RNG).
3. ✅ `LevelGenerator.projectiles: Array[ProjectileInstance]` flat list, cleared in `generate()`. Game.gd advances every entry each frame.
4. ✅ `Game._process(delta)` extended — `_tick_projectile_launchers(delta)` polls each launcher's `tick`, appends spawned projectiles, plays `launch_sound` (gated by `_player_within_projectile_trap_hearing`). `_tick_projectiles(delta)` advances each in-flight projectile, calls `DungeonView.update_projectile_visual` for the live sprite, and on IMPACT plays `impact_sound` (gated by `_player_within_projectile_hearing` measured to the projectile's death cell), despawns the visual, and removes the instance from the list. The early-return-when-traps-empty guard in `_process` was loosened so projectile traps still tick on levels without spike traps.
5. ✅ `DungeonView` projectile rendering — new `ProjectilesRoot` Node3D under SubViewport, `_projectile_visuals: Dictionary[ProjectileInstance → Sprite3D]`. `spawn_projectile_visual(proj)` creates a `BILLBOARD_FIXED_Y` Sprite3D with NEAREST filtering and ALPHA_CUT_DISCARD. `update_projectile_visual(proj)` syncs position from `cell_pos × CELL_SIZE` (Y at corridor mid-height + `projectile_y_offset`) and re-picks the texture each frame via `ProjectileInstance.view_for_camera` against the camera's current forward — only swaps if the picked view changed since last frame. `despawn_projectile_visual(proj)` frees the sprite and clears the dict entry. `setup()` clears any leftover visuals so a level transition doesn't leak in-flight sprites.
6. ✅ Audio — `launch_sound` on TIMED launcher rollover, `impact_sound` on every projectile IMPACT. Routed through SoundManager non-spatially with the same hearing-distance gate spike timed traps use (per-trap `hearing_distance` controls audibility radius). PRESSURE_PLATE traps will play unconditionally in C4.
7. ✅ Tests: unit (`test_projectile_instance` — tick advances along fire direction, hits wall + clamps to near face for all 4 cardinals, high-speed catches first wall not last cell, off-grid → IMPACT, sprite-direction picker matrix covers all 4 fire × 4 camera combinations, zero-input fallback to FRONT, damage_latch defaults false; `test_projectile_trap_instance` extended — TIMED tick advances timer / spawns at rollover / handles long delta via fposmod / null-data + zero-delta no-op / spawned projectile starts at wall face / direction matches fire_direction for all 4 wall mounts); integration (`test_level_generator` extended — placer assigns distinct `timed_offset` values across instances).

###### Subtask C3 — Player damage + feedback on hit ✅ (code; awaits manual playtest)
1. ✅ Pass-through damage — `ProjectileInstance.consume_damage_for_player(player_cell)` checks if the projectile is on the player's cell, and if so, sets `damage_latch = true` and returns true. Atomic — caller can't forget to set the latch. Game.gd polls this each frame after `tick()` and on success calls `_apply_party_damage(data.damage)`. The latch ensures a single projectile damages once per flight even if it sits on the player's cell for multiple frames or multiple ticks see it there before it moves on. Variants with `damage <= 0` short-circuit without tripping the latch so a future tuning to `> 0` damage starts working without weird latched-state carryover.
2. ✅ Reuses the existing `_apply_party_damage` pipeline (all 3 party members + `DungeonView.shake_camera` + `Hud.flash_damage` + pain sound) — same feedback as spike traps and any future damage source.
3. ✅ Tests: unit (`test_projectile_instance` extended — first call returns true and sets the latch, second call returns false; non-matching player cell returns false WITHOUT setting the latch; zero-damage variants short-circuit without tripping the latch; null data is safe; `cell_pos.x = 5.99` correctly floors to cell 5; pre-set latch refuses to fire). Manual playtest covers the integration path (walk into an active projectile, verify single damage per flight + feedback).

###### Subtask C4 — PRESSURE_PLATE trigger + plate placement + plate rendering ✅ (code; awaits manual playtest)
1. ✅ PRESSURE_PLATE trigger logic on `ProjectileTrapInstance` — `spawn_projectile()` (now public; was private `_spawn_projectile` in C2) gates on `in_flight` for PRESSURE_PLATE traps and returns null if a previous projectile is still flying. Sets `in_flight = true` on success and assigns the new `ProjectileInstance.launcher` back-reference so Game.gd can clear the lock on IMPACT. TIMED traps don't read or write `in_flight` — their period drives everything and overlapping projectiles are acceptable.
2. ✅ Plate placement — `_pick_plate_cell_for_corridor(path, launcher_cell, junctions, data)` picks uniformly at random among path cells that satisfy: ≥ `min_plate_to_launcher_distance` Manhattan tiles from launcher (so the projectile has visible travel time after triggering) AND ≤ `max_plate_to_junction_distance` from the nearest path junction (so the player has a reachable escape after stepping on the plate). PRESSURE_PLATE launchers that can't satisfy both constraints are rejected — placing them would produce inert traps that never fire. TIMED traps keep `plate_cell == NO_PLATE`.
3. ✅ `DungeonView._make_plate_decal_node(inst)` — flat `MeshInstance3D` `QuadMesh` lying horizontal at Y = 0.01 above the floor (same Z-fight prevention as spike-trap decals), sized `plate_world_size × CELL_SIZE` (1.0 = fills the cell). Reuses the `_trap_floor_material_cache` since the alpha-scissor + NEAREST-filter material setup is identical to spike-trap holes — designers can even share a texture between the two systems and get one cached material. Plate decals are added under `ProjectileTrapsRoot` alongside the launcher Sprite3Ds so a level rebuild frees both together. **Idle / triggered states:** `plate_texture_idle` is the default look; `plate_texture_triggered` (optional, falls back to idle) renders while ANY entity stands on the plate cell. Today that's just the player; Phase 10 enemies that walk over plates will hook into the same path. `_plate_visuals: Dictionary[ProjectileTrapInstance → MeshInstance3D]` tracks each plate; `_update_plate_visual_states()` runs in `move_camera_to()` (every player step) and diffs against `_plate_triggered_state` so we only issue a `material_override` write on actual state changes, not every step.
4. ✅ `Game._check_pressure_plate_trigger(player_cell)` — called from `_on_player_entered_cell` AFTER the trap-activation-delay await (so the projectile spawns visibly after the move tween completes, consistent with spike-trap timing). Scans every PRESSURE_PLATE launcher; on a plate-cell match calls `spawn_projectile()`, appends the result to `LevelGenerator.projectiles`, and plays `plate_sound` + `launch_sound` unconditionally (always full volume — the player is right at the plate, no hearing-distance gate). The pre-await spike-trap branch was refactored to no longer early-return on `cell.trap == null` so the post-await plate branch always runs even on cells without a spike trap.
5. ✅ `Game._tick_projectiles` IMPACT handler — reads `proj.launcher` and clears `launcher.in_flight = false` so the plate can re-fire on the next player step. TIMED launchers don't read in_flight but the assignment is safe and keeps state tidy.
6. ✅ `MapPopup` debug — when `debug_show_projectile_traps` is on, PRESSURE_PLATE traps additionally render a small filled cyan square on the explored plate cell, matching the launcher arrow's tint so the developer reads them as a pair.
7. ✅ Tests: unit (`test_projectile_trap_instance` extended — `spawn_projectile` sets the `launcher` back-ref, sets `in_flight` for PRESSURE_PLATE only, blocks a second spawn while in_flight, succeeds again after the lock clears); integration (`test_level_generator` extended — PRESSURE_PLATE launchers always have a plate, the plate sits on the projectile path, plate ≥ min distance from launcher, plate ≤ max distance from nearest path junction, TIMED traps keep `plate_cell = NO_PLATE`).

###### Subtask C5 — Room placement + wall-face exclusivity vs decorations ⏳
1. ⏳ `_place_room_projectile_traps()` — for each room and each candidate (cell, wall_dir), trace the projectile path; reject if any path cell falls outside the room. Per-room launcher cap. Spreading rule still applied.
2. ⏳ Wall-face exclusivity — projectile launchers and wall decorations share `_wall_faces_used` (already in C1). C5 adds the room placement pass that respects this.
3. ⏳ PRESSURE_PLATE plates inside rooms — relaxed junction rule (path + launcher distance only; no junction inside a room).
4. ⏳ Tests: integration (room placements never produce a projectile path leaving the room; per-room cap honoured).

###### Subtask C6 — Variants + status effect data populated ⏳
1. ⏳ Additional `.tres` variants — `projectile_trap_poison_dart_timed.tres`, `projectile_trap_fireball_pressure.tres`, `projectile_trap_ice_shard_timed.tres` — each tunes sprites, audio, world_height, speed, damage, and status effect fields independently. No code branches per variant.
2. ⏳ Status effect fields populated on each variant (gameplay deferred — comment in `ProjectileTrapData.gd` points to the future status-effect phase).
3. ⏳ Variants spread across biomes via `projectile_trap_spawns`.
4. ⏳ Localization: `projectile_trap.{poison_dart,fireball,ice_shard}.{name,description}` rows added to `strings.csv`.
5. ⏳ Tests: resource-load sanity (each `.tres` loads, fields parse, status data round-trips).

#### Task 3 follow-ups (after Subtasks A–C)
- Immobilize trap (player can't move, can turn and attack)
- Alert trap (aggros enemies in 10-tile radius — needs Phase 10 enemies first)
- Sub-biome portal reachability: when Phase 15 Task 1 adds `SUB_EXIT` portal cells, `_validate_step_trap_reachability()` must include them as targets so there is always a step-trap-free path from the entrance to every sub-biome portal

#### Task 4 — Wall-mounted decorations ✅ (code; awaits manual asset wiring)
Paintings, torches, lanterns mounted on wall faces (a side of a floor cell that abuts a wall cell). No interaction; pure ambiance. Animated decorations (torches) supported via `SpriteFrames`.
1. ✅ `WallDecorationData.gd` Resource — `texture: Texture2D` (static) OR `frames: SpriteFrames` (animated, takes precedence). `is_animated()` predicate. `world_height` / `y_offset` / `depth_offset` for sizing. Optional `light_color` / `light_energy` / `light_range` — when energy > 0 the renderer attaches an `OmniLight3D` for torch glow.
2. ✅ `WallDecorationInstance.gd` (RefCounted) — placement record holding `cell` (host floor cell) + `wall_dir` (cardinal direction into the wall). `face_key()` and `_wall_faces_used` prevent two decos from stacking on the same face.
3. ✅ `WallDecorationSpawn.gd` Resource — biome-level entry: `decoration`, `count_min/max`, `placement` (Corridor/Room/Dead End flags reused from `ObjectSpawn`), `min_distance_to_other_decoration` with graceful-degrade-by-1 spreading.
4. ✅ `BiomeData.wall_decorations: Array[WallDecorationSpawn]`
5. ✅ `LevelGenerator._place_wall_decorations()` runs LAST among scenery passes. For each spawn: build (cell, wall_dir) candidate pool from cells matching placement flags whose wall_dir neighbour is a WALL cell, apply min_distance with graceful degrade, place.
6. ✅ `DungeonView._build_wall_decorations()` — separate render path. Anchors a `Node3D` at the wall-face midpoint, Y-rotates to match the wall mesh's own rotation. Picks `AnimatedSprite3D` (auto-plays `default_animation`) when `frames` is set, else `Sprite3D`. Adds `OmniLight3D` child when `light_energy > 0`. `WallDecorationsRoot` Node3D under SubViewport.
7. ✅ Tests: unit (data defaults, is_animated precedence, instance + face_key, spawn placement flags); integration (count_min/max respected, decorations attach to actual walls, host cell is floor, face uniqueness, min_distance, placement flag filtering, animated path uses frames).
8. ⏳ Manual asset work (developer): torch frame PNGs (128×128, 4 frames), `SpriteFrames.tres`, `torch_forest.tres` referencing the frames + a warm orange light, add a `WallDecorationSpawn` entry to `forest.tres`.

#### Task 5 — Campfires
- Rest point (heal HP/MP, save?)
- Must clear nearby enemies before resting (needs Phase 10)

#### Task 6 — Teleporters
Pairs of floor tiles that warp the player from one to the other. Adds shortcut topology to large biomes and unlocks puzzle layouts where two regions share a teleporter pair instead of a corridor.
- New `TeleporterInstance` (RefCounted) — holds the two paired cells; `partner_of(cell)` resolves the destination
- Per-biome `Array[TeleporterSpawn]` on `BiomeData` (count_min/max, placement flags, min_distance_between_pair so pairs aren't visually next to each other, max_distance_between_pair so pairs aren't degenerate)
- Generator places pairs after standard objects but before items; both endpoints must be chain-reachable from the entrance (separately — a teleporter mustn't be the only way to reach its destination, otherwise locked-door / lever puzzles get bypassed)
- `Game.gd` triggers the warp when the player steps on a teleporter cell — fades camera, snaps to partner, plays warp sound. Prevents immediate re-trigger by remembering the cell the player just arrived on (stepping off + back on re-arms)
- Map: paired teleporters drawn as matching coloured glyphs (per-pair hue rotation, same trick as Phase 8 Task 2c keys) so the player can see which goes where on explored tiles
- Visual: animated rune-circle Sprite3D on the floor (FIXED_Y billboard), warm glow via OmniLight3D
- Localization: `object.teleporter_forest.{name,description}`, `ui.feedback.teleporter_warped`

#### Task 7 — Trade doors
A door that demands a fixed cost in consumables (food, potions, weapons, armour) instead of a key. Always guards a chest (the cost has to feel worth paying), so the placement code requires a chest in the gated region.
- New `TradeDoorSpawn` resource (biome-level): door_object, cost_item_data, cost_count, count_min/max, distance constraints. `must_gate_chest` is implicit `true` — the door's whole point is the reward chest behind it
- New `TradeCostInstance` field on `DoorInstance` (or extend `DoorInstance` with `cost_item: ItemData` + `cost_count: int`) — sticky `unlocked` flag mirrors the key-locked door
- Generator: same placement model as `KeyDoorSpawn` (1-wide-corridor edge), but instead of placing a key in a reachable cell, the placement just verifies that closing this door cuts off a chest cell. Reuses chain-reachability v2 (treats the door as permanently closed) to confirm the gated region holds at least one chest
- `Game._toggle_door`: trade-locked branch checks if the bar holds ≥ N of the cost item; consumes them via `ItemBar.remove_n`; door's `unlocked` flips true; falls through to normal toggle. No / not enough cost items → locked feedback with a translated "needs N foo" toast
- Localization: `object.door_forest_trade.{name,description,locked}` (with placeholders for item name + count), `ui.feedback.trade_door_paid`
- Reuses the locked-feedback path + camera shake from Task 2c — no new feedback wiring

#### Task 8 — Spinners
Floor tile that rotates the player N times when stepped on, disorienting them (loses bearing of which way the entrance is). Light comedic / puzzle effect; pairs well with biomes where the map is partially obscured.
- New `SpinnerData` Resource (extends `ObjectData`) — `rotation_count: int = 3` (how many 90° turns), `rotation_direction` enum (clockwise / counter-clockwise / random)
- Cell-bound (`GridCell.object`), non-blocking (`blocks_movement = false`), `interactable = false` (no click — the trigger is stepping on)
- Per-biome `Array[ObjectSpawn]` entry — corridor placement flag preferred (rooms are too easy to recover orientation in)
- `Game._on_move` (or `PlayerController` post-move hook): when the destination cell holds a spinner and isn't the cell the player just left voluntarily turning, fire `rotate_camera_to(...)` N times in sequence (chained tweens). Only spins on FIRST entry — re-entering doesn't re-spin until the player has stepped fully off
- Visual: arrow-vortex Sprite3D, FIXED_Y billboard, slowly auto-rotating texture (or animated frames)
- Sound: low whoosh per turn
- Localization: `object.spinner_forest.{name,description}`

### Phase 9 — Character Data System

**Priority: HIGH — Required for combat and inventory**

1. Create `CharacterData.gd` resource (stats, class, gender, portrait, equipment, spells)
2. Create `WeaponData.gd`, `ArmorData.gd`, `SpellData.gd` resources
3. Implement equipment slot system (8 slots per character)
4. Implement stat calculation: base stats + equipment modifiers → final stats
5. Create character creation screen (class, gender, portrait selection)
6. Wire CharacterSlot UI to actual character data (HP/MP bars, portrait, name)
7. Create inventory popup (opened by clicking character portrait)
8. Implement drag-and-drop or tap-to-equip for items

### Phase 10 — Combat System

**Priority: HIGH — Core gameplay loop**

1. Create `CombatManager.gd` (turn queue, damage resolution, status effects)
2. Create `EnemyData.gd` resource (HP, speed, flying, INT, STR, attack set, element resistances)
3. Implement enemy placement in LevelGenerator (configurable per biome)
4. Implement enemy rendering as Sprite3D billboards in DungeonView
5. Implement enemy detection range and combat trigger
6. Implement basic attack resolution (weapon damage vs defense)
7. Implement spell casting (MP cost, INT scaling, elemental damage)
8. Implement defense/parry action
9. Implement kick action (push enemy back 1 tile)
10. Implement back-attack bonus damage
11. Implement elemental resistances and weaknesses
12. Implement screen shake on heavy hits
13. Implement loot drops on enemy death (items, Void Ink, Grimoire Pages)
    - **Different shape from chest loot.** A chest's `LootTable` rolls
      between `min_rolls` and `max_rolls` items; an enemy drops AT
      MOST one item, with an explicit "nothing" outcome baked into
      the probabilities. Recommend a new `DropTable` resource (or an
      added flag on LootTable) where each entry is a probability
      slice of the 0..1 range — e.g. 60% nothing, 20% health potion,
      20% 100 gold — and rolling produces 0 or 1 `ItemInstance`.
      Should NOT reuse the chest weighted-bag-with-min/max logic.
14. Implement status effects (poison, burn, paralyze, blind, curse)

### Phase 11 — Enemy AI & Special Enemies

**Priority: MEDIUM — Adds depth to combat**

1. Basic AI: melee approach, ranged keep distance, spell casters
2. Implement specific enemy behaviors:
   - Heavy hitter (big attack every 3 turns, must parry)
   - Charging enemy (charges, must parry every N attacks)
   - Tile Corruptor (places fire/poison on tile)
   - Magnet enemy (pulls player toward it)
   - Splitting Slime (splits into 2 smaller slimes on death)
   - Summoner (spawns additional enemies)
   - Fusion enemy (merges with nearby enemies, becomes stronger)
   - Shielded enemy (only hittable from sides)
   - Mana Leacher (drains player MP per attack)
   - Shadow enemy (ultra strong in dark, normal in light)
   - Ghost (moves through walls)
   - Trapper (immobilizes player)
   - Armor Melter (destroys metal armor, leather armor immune)

### Phase 12 — Mana & Resource Systems

**Priority: MEDIUM — Enriches exploration and combat**

1. Mana regeneration on new tile exploration (scales with INT/magic level)
2. Mana regen equipment modifier (×1.25 multiplier item)
3. Mana regen on kill (equipment perk)
4. Curse mechanic (double damage dealt and taken)
5. Levitation spell (bypass traps, swamp mud)

### Phase 13 — Quest System

**Priority: MEDIUM — Adds narrative and variety to levels**

1. Create `QuestData.gd` resource (quest type, requirements, rewards, dialogue)
2. Create quest pool per biome in BiomeData
3. Implement quest placement during level generation (0–3 quests per level)
4. Implement quest types:
   - Fetch quest (NPC requests an object, object placed elsewhere in level)
   - Locked door (requires specific key, key placed before door — enforced by BFS)
   - Rescue NPC (NPC fleeing elite monster, player can choose to fight)
   - Riddle statue (talking statue, correct answer gives reward)
   - Thug encounter (dialogue choices: correct = befriend, wrong = fight)
   - Torch puzzle (light N torches with fireball to reveal hidden area)
   - Escort quest (protect weak NPC to exit)
   - Hunt quest (kill specific elite enemy roaming the level)
5. Implement quest UI (quest log, objectives, completion feedback)
6. Implement quest reward system (items, Void Ink, Grimoire Pages, XP)

### Phase 14 — Premade Blocks

**Priority: MEDIUM — Content variety**

1. Create premade block format (small grid sections with fixed layout)
2. Create block library per biome (boss rooms, lore sections, puzzle rooms)
3. Integrate premade blocks into LevelGenerator (placed at specific locations)
4. Boss room blocks (fixed layout for each boss fight)
5. Lore room blocks (story/NPC encounters)

### Phase 15 — Biome Manager & Content

**Priority: MEDIUM — Required for full game progression**

#### Task 1 — Sub-level system (level stack)
Infrastructure for entering and returning from smaller side-levels within a parent level. Towns reuse this system for enterable buildings (shops, houses, inns).

1. Add `SUB_EXIT` to `GridCell.CellType` — a floor tile that acts as a portal into a sub-level
2. `SubBiomeEntry.gd` Resource — defines one sub-level portal type for a biome:
   - `sub_biome: BiomeData` (the biome template for the generated sub-level — typically smaller grid)
   - `portal_object: ObjectData` (visual for the portal tile — cave mouth, house door, staircase)
   - `count_min / count_max: int` (how many portals of this type per level)
   - `placement` flags (Corridor / Room / Dead End — reuses existing placement system)
   - `min_distance_to_other_portal: int` (spreading constraint)
3. `BiomeData.sub_biome_entries: Array[SubBiomeEntry]` — per-biome portal pool, placed during generation
4. `LevelGenerator._place_sub_exits()` — runs in the object placement pipeline. Each placed portal stores its `SubBiomeEntry` on the `GridCell` so `Game.gd` knows which sub-biome to generate on entry
5. Level stack in `Game.gd`:
   - `_level_stack: Array` — each entry holds the full parent level state (grid, generator, player position + facing, objects, traps, decorations, explored map state)
   - On portal entry: push current state, generate the sub-level from the portal's `sub_biome`, rebuild `DungeonView`, place player at the sub-level entrance
   - On sub-level entrance tile (return): pop the stack, restore the parent level state, rebuild `DungeonView`, place player back on the portal tile they entered from
6. Sub-levels have an ENTRANCE (the return point) but NO main EXIT — the only way out is back through the entrance
7. Sub-levels do NOT contain `SUB_EXIT` tiles — one nesting depth only. `_place_sub_exits()` is skipped when generating a sub-level
8. `DungeonView` teardown + rebuild on push/pop — clear all Node3D children, regenerate mesh, objects, traps, decorations from the (new or restored) level state
9. Camera transition: fade-to-black on portal entry/exit (reusable for Phase 19 screen transitions between biomes)
10. Map state: sub-level has its own independent fog-of-war. Parent map state is preserved in the stack and restored on return
11. Save system integration (Phase 16 dependency): the full level stack must be serializable — each stacked level's grid + object states + map exploration included in `save_run.json`
12. Localization: `ui.feedback.entering_sub_level`, `ui.feedback.returning` (toast on transition)

#### Task 2 — Biome content
1. Create remaining biome textures and BiomeData resources
2. Implement biome-specific mechanics:
   - Underwater biome (air bubbles for breathing, drowning timer)
   - Damage floor biome (50% of tiles deal damage if stopped >10 seconds)
   - Swamp biome (mud slows movement, levitation bypasses)
3. Implement biome progression system (biome sequence with boss/town checkpoints)
4. Implement biome path selection (choosing between up to 3 alternative biomes)

#### Task 3 — Towns
Towns are safe zones between boss fights. Each town is a regular level generated from a town `BiomeData` (no enemies, no traps). Enterable buildings (shops, inns, NPC houses) use the **sub-level system** (Task 1) — each building is a `SubBiomeEntry` portal leading to a small interior sub-level.

1. Create town `BiomeData` (open layout: high room count, wide corridors, no traps, no enemies)
2. Create interior `BiomeData` templates for building types (shop interior, inn interior, NPC house — small grids, e.g. 7×7 or 9×9)
3. Add `SubBiomeEntry` portals to the town biome for each building type (house door visual, 1–3 shops, 1 inn, 2–4 NPC houses per town)
4. Shop interaction system (buy/sell UI inside shop sub-level)
5. Inn rest mechanic (full heal, save point)
6. NPC dialogue system for house interiors
7. Grimoire access point in town

#### Task 4 — Boss encounters
1. Create boss encounters
2. Boss room premade blocks (Phase 14 dependency)

### Phase 16 — Title Screen, Save System & Character Creation

**Priority: MEDIUM — Required for complete game loop**

1. Create title screen scene with game logo/title art
2. Implement 4 main menu buttons (New Game, Continue, Grimoire Pages, Options)
3. Implement Continue button visibility (only show when a saved run exists)
4. **Character creation flow:**
   a. Class selection screen — 4 class cards (Warrior, Wizard, Battle Mage, Rogue) showing base stats and starting gear
   b. Gender selection screen (Male / Female)
   c. Portrait gallery — scrollable grid of portraits filtered by class and gender
   d. Name entry screen with default name per class
   e. Confirmation summary screen
5. **Save system — run state:**
   a. Create `SaveManager.gd` autoload
   b. Define run save data structure (level, grid, party, inventory, map, position)
   c. Implement auto-save triggers (new level, exit level, pause menu, app background)
   d. Serialize run state to `user://save_run.json`
   e. Implement run load (deserialize and restore full game state)
   f. Delete run save on death or game completion
6. **Save system — persistent/meta state:**
   a. Define meta save data structure (Grimoire progress, Void Ink, unlocks, settings)
   b. Serialize meta state to `user://save_meta.json`
   c. Load meta state on game launch
   d. Save meta state when Grimoire pages are inscribed or settings change
7. **Options screen:**
   a. Language selection using Godot TranslationServer
   b. Accessible from title screen and in-game settings button

### Phase 17 — Localization

**Priority: MEDIUM — Required for international release**

#### Scaffolding (done early, alongside Phase 7) ✅
- ✅ `res://localization/strings.csv` — single-source CSV with `keys,en` columns
- ✅ `res://localization/README.md` — conventions doc
- ✅ Convention: resource text fields hold translation keys (e.g. `item.health_potion.name`), not literal English
- ✅ `ItemData.get_display_name()` / `get_display_description()` helpers wrap `tr()`
- ✅ Existing strings (health_potion name + description) migrated to keys
- ✅ CLAUDE.md mandates localization for every new player-facing string

#### Full Phase 17 (later)
1. ~~Set up Godot TranslationServer with CSV-based translation files~~ (done in scaffolding)
2. ~~Create translation keys for all UI text, item names, quest dialogue, NPC dialogue~~ (ongoing — every new string follows the convention)
3. Implement language switching at runtime (options screen)
4. **Supported languages:**
   - English (base language) ✅
   - French
   - Spanish
   - Chinese (Simplified)
   - Japanese
   - Korean
   - German
   - Italian
5. Set up font fallbacks for CJK character rendering
6. Handle right-to-left text if Arabic is added later
7. Test all UI layouts with longest translations (German tends to be longest)
8. Localize item descriptions, quest text, NPC dialogue, tutorial text, menu labels

### Phase 18 — Grimoire & Meta Progression

**Priority: LOW — Polish phase**

1. Create Grimoire screen UI (list of pages, Void Ink balance, unlock buttons)
2. Implement Grimoire Page drops in levels
3. Implement "carry page to level exit" mechanic
4. Implement Void Ink spending to inscribe pages
5. Implement unlockable rewards:
   - New biome paths
   - New weapons
   - New characters
   - New perks
   - Quests
   - Additional level exits

### Phase 19 — Polish & Final

**Priority: LOW — Pre-release**

1. **Audio: ambient + music per biome** (SFX framework already exists — see Cross-Cutting Infrastructure)
   - Add `ambient_loop: AudioStream` to `BiomeData`
   - Add `music_track: AudioStream` to `BiomeData`
   - Hook up via `SoundManager.play_ambient()` (ambient player slot already reserved)
   - Author / source loops for each biome (forest = birds + wind, dungeon = drips + distant moans, swamp = frogs + bubbles, …)
   - Crossfade on biome transitions
   - Volume sliders in Options screen (Master / Music / SFX buses)
2. Particle effects (dust, leaves, fire, magic)
3. Screen transitions between levels
4. Tutorial / first-time player guidance
5. Achievement system
6. Performance optimization for mobile
7. Touch gesture refinements
8. Final balancing pass (enemy stats, item drops, progression curve)
