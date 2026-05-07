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

#### Phase 4 polish — Per-placement texture selection
Today's wall / floor / ceiling textures are picked uniformly across the whole grid. Designers should be able to author textures that ONLY appear in specific cell types — e.g. a moss-covered "dead-end wall", a vaulted "room ceiling", a worn-cobble "corridor floor". This makes the level read better and gives biomes a stronger sense of place.
Sketch:
- New `BiomeTextureEntry.gd` resource wrapping a single (albedo + normal) pair plus a placement flag-set (Corridor / Room / Dead End — same constants `LootEntry` and `ObjectSpawn` already use). Default: any.
- `BiomeData` swaps `wall_albedo` / `wall_normal` (and floor / ceiling pairs) for `wall_textures: Array[BiomeTextureEntry]` etc. Keep backwards-compat: if the legacy flat arrays are non-empty, treat each texture as `placement = ANY`.
- `DungeonView` (or a new helper) classifies each cell on biome apply (corridor / room / dead-end) using the same logic as `_classify_floor_cells`, then picks each surface's texture from the eligible pool. Cells with no matching texture fall back to the ANY pool (defensive).
- Walls inherit their cell's classification from the cell they're attached to. (A wall between a corridor cell and a room cell counts as corridor for the corridor-side face, room for the room-side face — though in practice we render walls per-cell.)
- Ceilings follow the same per-cell classification.
- Tests: a small unit / integration test that classifies a known maze and asserts each surface's texture pool was filtered correctly.

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
3. ✅ `LeverInstance.gd` (RefCounted, extends `ObjectInstance`) — adds `linked_doors: Array`, overrides `get_visual_opened()` so the lever sprite mirrors "any linked door is open"
4. ✅ `DoorInstance.linked_levers: Array` back-link populated at placement; used by `Game._toggle_door` to refresh lever sprites after a direct door click
5. ✅ `ObjectInstance.get_visual_opened()` virtual method (default returns `opened`) — DungeonView reads it instead of `opened` for cell-bound rendering, so the chest contract stays unchanged
6. ✅ `LevelGenerator._place_linked_objects()` runs after `_place_doors()`. For each pair: pick a 1-wide corridor edge for the door (reuse decorative-door eligibility), then pick a chest-style cell for the lever that's reachable from the entrance EVEN WITH the linked door treated as closed. Rolls back the door if no lever cell qualifies, so we never ship orphan halves.
7. ✅ `Game._on_object_clicked` dispatches `LeverInstance` to a pull handler that flips every linked door's state, plays the lever's interact sound, and rebuilds both door and cell-object visuals
8. ✅ `MapPopup` draws lever as a small slate diamond (filled when the linked door is closed; outline-only when open) so players can find their levers from the map
9. ✅ Localization: `object.lever_forest.name`, `object.lever_forest.description`
10. ✅ Tests: `test_linked_object_spawn.gd`, `test_lever_instance.gd` (unit); linked-pair placement integration tests in `test_level_generator.gd`
11. ⏳ Manual asset work (developer): `res://assets/objects/lever_forest.tres` (closed = lever down, opened = lever up sprites), lever sprites + interact sound, add a `LinkedObjectSpawn` entry to `res://assets/biomes/forest.tres`

#### Task 2b critical fix — Multi-pair lever reachability ✅
**Bug:** With multiple `LinkedObjectSpawn` pairs the placement check was per-pair only — already-placed sibling doors weren't taken into account. Two doors could land with both levers behind both doors, hard-stucking the player at game start.

**Fix:** Replaced the single-edge check with a **chain-reachability** simulation in `LevelGenerator`:
1. ✅ `_chain_reachable_from_entrance()` — iterative fixed-point. Start with every directly-clickable door treated as open; BFS; mark every lever-reachable door as openable; BFS again until no progress.
2. ✅ `_try_place_linked_pair()` snapshots `pre_chain` before each attempt; `_try_place_lever_for_door()` mutates the grid with each candidate, computes `post_chain`, and validates that `pre_chain ⊆ post_chain ∪ {new_lever_cell}` AND the new lever has a chain-reachable neighbour. Failures roll back lever + door together — no orphan halves.
3. ✅ Permits progressive gating (lever_1 opens door_A, behind which is lever_2) but rejects cycles. Implicit consequences: existing levers stay reachable, existing chests stay interactable, exit stays reachable (all were in `pre_chain`).
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

#### Task 2b follow-up — Richer lever ↔ door pairing
1. Allow one lever to toggle multiple doors (lever's `linked_doors` already an Array)
2. Allow one door to be toggled by multiple levers (door's `linked_levers` already an Array; lever sprite already uses "any door open" — confirm or revisit semantics for many-to-many)
3. Decide AND/OR semantics if needed (e.g. door opens only when ALL levers pulled vs. ANY lever pulled). Today the model is "each pull flips each linked door", which is consistent for 1:1 and degrades reasonably for many.
4. Update `LinkedObjectSpawn` shape to express N:M pairing rules (probably `lever_count_per_pair`, `door_count_per_pair`, or a more declarative pairing graph)

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
- Spike trap (periodic up/down)
- Fireball trap (pressure plate or continuous)
- Immobilize trap (player can't move, can turn and attack)
- Alert trap (aggros enemies in 10-tile radius — needs Phase 10 enemies first)

#### Task 4 — Wall-mounted decorations
- Paintings, torches, lanterns
- Sprite3D pinned to a wall face rather than floor
- No interaction; pure ambiance

#### Task 4b — Wall-mounted chests
Lootable chests embedded in the wall instead of standing on the floor — e.g. a forest tree with a hollow that holds loot. Same chest contract as Task 1 (rolls loot on first interact, persists items, opens `LootPopup`); just placed and rendered against a wall face instead of on a `GridCell`.
- Reuses Task 4's wall-anchoring renderer (Sprite3D pinned to a wall face rather than floor) and Task 1's `ObjectInstance` chest semantics
- New placement path: pick a wall face adjacent to a 1-wide-corridor / room cell, anchor sprite to that face
- A wall-chest cell is **not** blocked for movement (the wall already blocks the player); the click hitbox lives on the wall face
- Per-biome opt-in via a new `BiomeData.wall_object_spawns` shape (or extends `objects` with a placement-axis flag — TBD when we get there)
- Texture pair: closed (e.g. tree with intact trunk) + opened (tree with visible hollow + items spilling out)

#### Task 5 — Campfires
- Rest point (heal HP/MP, save?)
- Must clear nearby enemies before resting (needs Phase 10)

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

1. Create remaining biome textures and BiomeData resources
2. Implement biome-specific mechanics:
   - Underwater biome (air bubbles for breathing, drowning timer)
   - Damage floor biome (50% of tiles deal damage if stopped >10 seconds)
   - Swamp biome (mud slows movement, levitation bypasses)
3. Implement biome progression system (biome sequence with boss/town checkpoints)
4. Implement biome path selection (choosing between up to 3 alternative biomes)
5. Create town levels (safe zones, shops, NPCs)
6. Create boss encounters

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
