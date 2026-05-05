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

#### Task 2 — Doors + switches/levers (next)
1. Door object with `closed` / `opened` states; closed blocks movement, opened doesn't
2. Switch/lever object that toggles a target door's state
3. BFS still passes after every state change (doors close to walls but always have a switch path)

#### Task 3 — Traps
- Spike trap (periodic up/down)
- Fireball trap (pressure plate or continuous)
- Immobilize trap (player can't move, can turn and attack)
- Alert trap (aggros enemies in 10-tile radius — needs Phase 10 enemies first)

#### Task 4 — Wall-mounted decorations
- Paintings, torches, lanterns
- Sprite3D pinned to a wall face rather than floor
- No interaction; pure ambiance

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
