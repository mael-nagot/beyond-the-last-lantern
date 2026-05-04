# Below the Last Lantern — Game Design & Development Agent File

## Game Overview

**Below the Last Lantern** is a mobile-first (also desktop compatible) dungeon crawler inspired by classic titles like Lands of Lore and Eye of the Beholder, enriched with roguelite progression elements similar to Dead Cells. Built in Godot 4.

The player navigates procedurally generated grid-based levels in first-person, step by step. The game features turn-based combat, party management (up to 3 characters), equipment systems, elemental magic, and a meta-progression system called the Grimoire.

The visual style is old-school 2D pixel art on 3D flat quads — hand-drawn textures applied to walls, floors, and ceilings with triplanar mapping, ambient lighting, and fog for atmosphere.

---

## Game Structure — Level Progression

The game is structured as a sequence of biomes, boss fights, and towns:

```
Biome 1 → Biome 2 → Biome 3 → BOSS → TOWN → Biome 4 → Biome 5 → BOSS → TOWN → Biome 6 → Biome 7 → FINAL BOSS
```

### Biome Branching

- **Biome 1** and **Towns** are always the same (no alternatives).
- Every other biome slot has **3 alternative biome paths** the player can choose from.
- **V1:** Only 1 path per slot is available initially.
- Alternative biome paths are unlocked via **Grimoire Pages** (see Meta Progression below).

### Level Generation

Each level is a procedurally generated grid using a **Growing Tree** maze algorithm with configurable parameters:

- `maze_bias` (0.0–1.0): controls corridor style (bushy vs winding)
- `wiggle` (0.0–1.0): how much corridors bend instead of going straight
- `corridor_min_width` / `corridor_max_width`: fluctuating corridor width
- `width_change_chance`: how often width shifts per step
- `room_count`, `room_min_size`, `room_max_size`: optional rooms punched into the maze
- `entrance_at_dead_end` / `exit_at_dead_end`: whether entrance/exit sit at corridor tips
- `min_exit_distance`: minimum Manhattan distance between entrance and exit

Levels are closed with a solid wall border. There is one entrance and one or two exits (additional exits unlocked via Grimoire Pages).

---

## Core Mechanics

### Movement

Step-by-step grid movement in first person. Six actions: forward, backward, strafe left, strafe right, turn left, turn right. Controlled via 6 touch buttons (mobile) or WASD/QE (desktop). Camera tweens smoothly between grid positions (0.12s).

### Party System

- Starts with 1 character chosen at game start.
- Up to 2 additional characters can be found in levels and recruited.
- All 3 characters are displayed horizontally in the HUD — their placement matters for gameplay.
- Each character has: portrait, HP bar, MP bar, name label, and 3 action buttons (Attack, Spell, Defense).
- Clicking the portrait opens that character's inventory.

### Character Classes

Four starting classes with different base stats:

| Class | HP | MP | STR | DEX | INT | Starting Spell |
|---|---|---|---|---|---|---|
| Warrior | High | Low | High | Med | Low | None |
| Wizard | Low | High | Low | Med | High | Minor Lightning |
| Battle Mage | Med | Med | Med | Med | Med | Minor Lightning |
| Rogue | Med | Low | Med | High | Low | None |

Gender selection (male/female) and portrait selection at character creation.

### Stats

- **PV Max** (HP): health points
- **PM Max** (MP): mana points
- **Strength**: physical damage
- **Dexterity**: dodge, hit chance, rogue skills
- **Intelligence**: spell damage, MP scaling
- **Physical Defense**: from equipment
- **Magic Defense**: from equipment

### Equipment Slots (per character)

8 slots total:
- Weapon (1H or 2H)
- Shield (only if weapon is 1H) OR second weapon (deals 50% damage)
- Helmet
- Armor
- Boots
- Ring × 2
- Necklace

Each character starts with basic equipment (bad weapon + bad armor).

### Mana System

- **Mana regenerates when exploring new tiles.** The amount of mana regenerated per new tile increases with the character's magic level/Intelligence.
- **Mana regen equipment modifier:** item that multiplies mana regen by ×1.25.
- **Mana regen on kill:** item that restores mana when an enemy is killed.
- **Mana Leacher enemies:** enemies that drain the player's mana.

### Combat

Turn-based combat triggered when stepping into an enemy's detection range. The combat queue alternates: player party acts, then enemies act.

**Damage formula:** `(weapon_base + strength_mod) - (target_defense + armor)`, clamped to 0. Spells use PM and scale with Intelligence.

**Special combat mechanics:**

- **Kick action:** pushes an enemy back 1 tile on the grid.
- **Parry/Defense:** some enemies have a powerful attack every N hits that must be parried. Screen shake on impact.
- **Back attacks:** dealing more damage when attacking an enemy from behind.
- **Side-only attacks:** enemies with large shields can only be hit from the sides.
- **Elemental spells:** fire, ice, lightning, etc. Enemies have elemental resistances and weaknesses.
- **Curse mechanic:** doubles damage dealt but also doubles damage taken.
- **Levitation spell:** allows levitating over traps, swamp mud, etc.

---

## Enemies

### Enemy Base Stats

Each enemy has: HP, Movement Speed, Flying (yes/no), Intelligence, Strength, and a set of attacks (spell, distance, melee).

### Enemy Types

| Enemy | Behavior |
|---|---|
| **Charging enemy** | Charges at the player, must be parried every N attacks |
| **Heavy hitter** | Massive attack every 3 hits — must parry. Screen shake. |
| **Tile Corruptor** | Places fire or poison on the tile it stands on |
| **Magnet enemy** | Pulls the player toward it |
| **Splitting Slime** | Splits into smaller slimes when killed |
| **Summoner** | Summons additional enemies during combat |
| **Fusion enemy** | Merges with nearby enemies to become much stronger |
| **Shielded enemy** | Can only be hit from the sides (large front shield) |
| **Mana Leacher** | Drains the player's MP with each attack |
| **Shadow enemy** | Extremely strong in darkness, normal in light |
| **Ghost** | Passes through walls, cannot be blocked by terrain |
| **Trapper** | Immobilizes the player, preventing movement (can still turn and attack) |
| **Armor Melter** | Destroys metal armor on hit — leather armor found in level is safe |
| **Alert Trap enemy** | When triggered, alerts all enemies within 10 tiles |

---

## Objects & Interactables

### Floor Objects

Objects that sit on tiles. Can occupy 1 or more tiles (e.g., a table covering 4 tiles). Some block movement, some don't. No blocking object may ever cut off the path between entrance and any exit (enforced by BFS validation).

| Object | Type | Blocks? |
|---|---|---|
| Table | Neutral decoration | Yes (multi-tile) |
| Chest | Lootable container | No |
| Spike Trap | Periodic damage (up/down cycle) | No (damage on step) |
| Fire Trap | Triggers on tile step or continuous | No (damage) |
| Immobilize Trap | Prevents player from moving, can still turn and attack | No |
| Alert Trap | Alerts all enemies in 10-tile radius when stepped on | No |
| Campfire | Rest point, interrupted if zone not cleared first | No |
| Swamp/Mud | Slows movement, levitation spell bypasses | No |
| Damage Floor | 50% of tiles in a biome deal heavy damage if stopped for >10 seconds | No |

### Wall Objects

Objects attached to walls, rendered as sprites on the wall face.

| Object | Type |
|---|---|
| Painting | Decoration |
| Switch/Lever | Activates doors, bridges, reveals secrets |
| Door | Blocks passage until opened (key, switch, or spell) |
| Torch/Lantern | Light source, affects Shadow enemies |

### Underwater / Special Biome Mechanics

- **Underwater biome:** Air bubbles scattered that the player must reach to breathe. Drowning damage if bubbles missed.

---

## Traps Summary

| Trap | Effect |
|---|---|
| Spike trap | Periodic damage — spikes go up and down, damage if up when stepped on |
| Fireball trap (tile) | Fires when player steps on a pressure plate |
| Fireball trap (continuous) | Fires at regular intervals regardless of player position |
| Immobilize trap | Player cannot move, only turn and attack |
| Alert trap | All enemies within 10 tiles become aware of the player |
| Damage floor (biome) | 50% of floor tiles deal heavy damage if player stays >10 seconds |

---

## Biome System

Each biome defines:

- Wall, floor, and ceiling textures (albedo + normal)
- Fog settings (color, density, aerial perspective)
- Ambient light settings (color, energy)
- Wall height
- Ceiling visibility
- Triplanar mapping settings
- Which enemies can spawn
- Which objects can appear on floors and walls
- Which traps are present
- Special mechanics (underwater bubbles, damage floors, etc.)
- Background/skybox

Biomes are stored as `BiomeData` resources (`.tres` files) in `res://assets/biomes/`.

---

## Meta Progression — Grimoire System

Similar to Dead Cells blueprints:

1. **Finding Grimoire Pages:** pages are found as loot within levels.
2. **Finishing the level:** the player must complete the current level while carrying the page.
3. **Spending Void Ink:** a currency found in levels, used to "inscribe" the page into the Grimoire.
4. **Unlocking rewards:** once inscribed, the page permanently unlocks its reward.

### Unlockable Rewards

- New biome paths (alternative routes through the game)
- New weapons
- New perks/abilities
- New playable characters
- New quests
- Additional exit in a level (branching paths)

### Void Ink

Currency dropped by enemies and found in chests. Spent at the Grimoire screen (accessible from the title screen).

---

## Title Screen

- **New Game** — character creation (class, gender, portrait) then start
- **Continue** — resume an unfinished run (only if a run is in progress)
- **Grimoire Pages** — view collected pages, spend Void Ink to unlock rewards
- **Options** — language selection (English / French)

---

## Towns

Towns appear between boss fights. They serve as safe zones where the player can:

- Rest and heal
- Buy/sell equipment
- Manage inventory
- Interact with NPCs for lore and quests
- Access the Grimoire

---

## UI Layout

Responsive HUD that adapts to portrait and landscape orientations, and scales down for tablets.

### Portrait Layout

```
┌──────────────────┐
│ ⚙ 🗺              │  Top bar (settings, map)
│                  │
│   3D Dungeon     │  SubViewport (width × 1.15)
│   View           │
│                  │
├──────────────────┤
│ Char1 Char2 Char3│  Party panel (full width)
├────────────┬─────┤
│ □□□□□      │ ↰▲↱ │  Item bar (5×2) + Movement pad
│ □□□□□      │ ◀▼▶ │
└────────────┴─────┘
```

### Landscape Layout

```
┌─────────────────────┬──────────┐
│ ⚙ 🗺                 │ □□□□□    │  Item bar (5×2)
│                     │ □□□□□    │
│                     ├──────────┤
│    3D Dungeon       │ C1 C2 C3 │  Party panel
│    View             │          │
│                     ├──────────┤
│    (height × 1.15)  │   ↰▲↱   │  Movement pad
│                     │   ◀▼▶   │
└─────────────────────┴──────────┘
```

### Adaptive Scaling

- DungeonView ratio reduces from 1.15 toward 1.0 on tablets to make room for UI.
- If ratio reaches minimum (1.0), UI elements scale down (minimum 50%) to fit.
- All button sizes are based on `min(screen.x, screen.y) * percentage` for consistent sizing across devices.

---

## Map System

- Opened via the map button (🗺) in the top bar.
- Full-screen popup with yellowish parchment background.
- **Fog of war:** only explored tiles are visible.
- Exploration reveals the current tile and all 8 adjacent tiles.
- Walls drawn as lines, floor tiles as slightly darker than background.
- Exit shown as a green diamond.
- Player shown as a red blinking arrow pointing in the facing direction.
- Debug mode: `debug_reveal_all` export toggle reveals the entire map.

---

## Technical Architecture

### Engine & Platform

- **Engine:** Godot 4
- **Primary platform:** Mobile (iOS/Android)
- **Secondary platform:** Desktop
- **Rendering:** 3D with flat quad geometry, hand-drawn 2D textures
- **Resolution:** SubViewport for the dungeon view, CanvasLayer for HUD

### Project Structure

```
res://
├── assets/
│   ├── biomes/
│   │   └── forest.tres
│   └── textures/
│       └── biomes/
│           └── forest/
│               ├── walls/
│               ├── floors/
│               └── ceilings/
├── scenes/
│   ├── Game.tscn
│   ├── DungeonView.tscn
│   └── hud/
│       ├── HUD.tscn
│       ├── TopBar.tscn
│       ├── ItemBar.tscn
│       ├── PartyPanel.tscn
│       ├── CharacterSlot.tscn
│       ├── MovementPad.tscn
│       └── MapPopup.tscn
├── scripts/
│   ├── Game.gd
│   ├── GridCell.gd
│   ├── LevelGenerator.gd
│   ├── DungeonView.gd
│   ├── PlayerController.gd
│   ├── BiomeData.gd
│   ├── MapData.gd
│   └── hud/
│       ├── HUD.gd
│       ├── ItemBar.gd
│       ├── PartyPanel.gd
│       ├── CharacterSlot.gd
│       ├── MovementPad.gd
│       └── MapPopup.gd
└── shaders/
    └── vignette.gdshader (unused currently)
```

### Scene Tree (Runtime)

```
Game (Node3D, Game.gd)
└── DungeonView (Node3D, DungeonView.gd)
│   ├── SubViewportContainer
│   │   └── SubViewport
│   │       ├── Camera (Camera3D)
│   │       ├── DungeonRoot (Node3D) — holds all wall/floor/ceiling quads
│   │       └── WorldEnvironment
│   └── PlayerController (Node, PlayerController.gd)
└── HUD (CanvasLayer, HUD.gd)
    └── HUDRoot (Control, full rect)
        ├── TopBar (HBoxContainer)
        │   ├── BtnSettings (Button, "⚙")
        │   └── BtnMap (Button, "🗺")
        ├── PartyPanel (HBoxContainer, PartyPanel.gd)
        │   ├── Slot0 (CharacterSlot instance)
        │   ├── Slot1 (CharacterSlot instance)
        │   └── Slot2 (CharacterSlot instance)
        ├── ItemBar (Container, ItemBar.gd)
        ├── MovementPad (GridContainer, MovementPad.gd)
        │   ├── BtnTurnLeft, BtnForward, BtnTurnRight
        │   └── BtnStrafeLeft, BtnBackward, BtnStrafeRight
        └── MapPopup (Control, MapPopup.gd)
            ├── Background (ColorRect)
            ├── CloseButton (Button)
            └── MapDrawArea (Control)
```

---

## What Has Been Developed (Completed)

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

## Development Roadmap — What's Next

### Phase 7 — Objects & Interactables (Next)

**Priority: HIGH — Foundation for gameplay variety**

1. Create `ObjectData.gd` resource (type, size in tiles, blocks movement, wall-attached, sprite texture)
2. Create object placement system in LevelGenerator (respecting path validation)
3. Implement `Sprite3D` billboards for floor objects (chests, campfires)
4. Implement wall-mounted sprites for wall objects (levers, paintings, torches)
5. Create interaction system (player steps on or faces object, presses interact)
6. Implement specific objects:
   - Chest (lootable, opens inventory popup)
   - Door (blocks until key/switch/spell)
   - Switch/Lever (toggles doors, reveals secrets)
   - Spike trap (periodic up/down, damage when up)
   - Fireball trap (pressure plate or continuous)
   - Immobilize trap (player can't move, can turn and attack)
   - Alert trap (aggros enemies in 10-tile radius)
   - Campfire (rest point, must clear zone first)

### Phase 8 — Character Data System

**Priority: HIGH — Required for combat and inventory**

1. Create `CharacterData.gd` resource (stats, class, gender, portrait, equipment, spells)
2. Create `WeaponData.gd`, `ArmorData.gd`, `SpellData.gd` resources
3. Implement equipment slot system (8 slots per character)
4. Implement stat calculation: base stats + equipment modifiers → final stats
5. Create character creation screen (class, gender, portrait selection)
6. Wire CharacterSlot UI to actual character data (HP/MP bars, portrait, name)
7. Create inventory popup (opened by clicking character portrait)
8. Implement drag-and-drop or tap-to-equip for items

### Phase 9 — Combat System

**Priority: HIGH — Core gameplay loop**

1. Create `CombatManager.gd` (turn queue, damage resolution, status effects)
2. Create `EnemyData.gd` resource (HP, speed, flying, INT, STR, attack set, element resistances)
3. Implement enemy placement in LevelGenerator (configurable per biome)
4. Implement enemy detection range and combat trigger
5. Implement basic attack resolution (weapon damage vs defense)
6. Implement spell casting (MP cost, INT scaling, elemental damage)
7. Implement defense/parry action
8. Implement kick action (push enemy back 1 tile)
9. Implement back-attack bonus damage
10. Implement elemental resistances and weaknesses
11. Implement screen shake on heavy hits
12. Implement loot drops on enemy death (items, Void Ink, Grimoire Pages)

### Phase 10 — Enemy AI & Special Enemies

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

### Phase 11 — Mana & Resource Systems

**Priority: MEDIUM — Enriches exploration and combat**

1. Mana regeneration on new tile exploration (scales with INT/magic level)
2. Mana regen equipment modifier (×1.25 multiplier item)
3. Mana regen on kill (equipment perk)
4. Curse mechanic (double damage dealt and taken)
5. Levitation spell (bypass traps, swamp mud)

### Phase 12 — Premade Blocks

**Priority: MEDIUM — Content variety**

1. Create premade block format (small grid sections with fixed layout)
2. Create block library per biome (boss rooms, lore sections, puzzle rooms)
3. Integrate premade blocks into LevelGenerator (placed at specific locations)
4. Boss room blocks (fixed layout for each boss fight)
5. Lore room blocks (story/NPC encounters)

### Phase 13 — Biome Manager & Content

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

### Phase 14 — Title Screen & Save System

**Priority: MEDIUM — Required for complete game loop**

1. Create title screen scene (New Game, Continue, Grimoire, Options)
2. Implement save/load system (current run state persisted to disk)
3. Implement Continue detection (show button only when a run exists)
4. Implement options screen (language EN/FR)
5. Implement Godot TranslationServer for EN/FR localization

### Phase 15 — Grimoire & Meta Progression

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

### Phase 16 — Polish & Final

**Priority: LOW — Pre-release**

1. Sound effects and music per biome
2. Particle effects (dust, leaves, fire, magic)
3. Screen transitions between levels
4. Tutorial / first-time player guidance
5. Achievement system
6. Performance optimization for mobile
7. Touch gesture refinements
8. Final balancing pass (enemy stats, item drops, progression curve)

---

## Key Design Principles

1. **Mobile first:** all interactions must work with touch. Buttons must be ≥5% of screen short side.
2. **Biome driven:** textures, enemies, objects, mechanics all defined per biome for maximum variety.
3. **Procedural with authored moments:** levels are generated but premade blocks inject hand-crafted content.
4. **Roguelite loop:** each run is fresh, but Grimoire unlocks carry over permanently.
5. **Old school feel:** pixel art textures, unshaded or ambient-only lighting, billboard sprites for objects.
6. **Configurable everything:** every parameter is an `@export` so designers can tune without code changes.
