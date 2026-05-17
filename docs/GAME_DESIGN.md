# Below the Last Lantern — Game Design Document

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

### Sub-Levels

A level can contain one or more **sub-level portals** — special floor tiles that transport the player into a smaller, self-contained level generated from a different `BiomeData`. The player can explore the sub-level and return to the parent level at the same portal they entered. This is distinct from the main EXIT, which advances the run to the next biome without return.

**Examples:**
- A hidden cave entrance in a forest biome leads to a small cave sub-level with its own loot, traps, and enemies.
- A house door in a town leads to a single-room interior with an NPC or shop.

**Rules:**
- A level can have **multiple sub-level portals**, each leading to a different sub-biome (e.g., a town with several enterable houses).
- Sub-level portals are two-way: the sub-level's entrance tile returns the player to the parent level.
- The parent level is preserved in memory while the player is in the sub-level — all state (explored tiles, opened chests, pulled levers, picked-up items) is intact on return.
- Sub-levels do NOT nest further (one depth only). A sub-level never contains its own sub-level portals.
- Sub-levels use the same generation pipeline as regular levels — they are just smaller (smaller `grid_width`/`grid_height` on their `BiomeData`) and have no main EXIT.
- The main EXIT in the parent level advances the run to the next biome as usual, regardless of whether the player has visited any sub-levels.

**Town buildings as sub-levels:**
Towns use this system for enterable buildings. Each building (shop, inn, NPC house) is a sub-level portal on the town grid leading to a small interior level. This keeps towns and dungeons on the same architectural foundation.

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

## Items

### Item Types

Items can be found on the dungeon floor, inside chests, dropped by enemies on death, or bought at shops in towns.

| Category | Examples |
|---|---|
| Health restoration | Health potion (small, medium, large) |
| Mana restoration | Mana potion (small, medium, large) |
| Stat boost (temporary) | Strength elixir, speed potion, shield draught |
| Status cure | Antidote (poison), salve (burn), clarity (curse) |
| Offensive throwable | Bomb (AoE damage), poison flask (poison status on enemy) |
| Status inflict | Paralyze dust, blind powder |
| Equipment | Weapons, armor, rings, necklaces (see Equipment Slots) |

### Item Interactions

- **In the dungeon:** items sit on the floor as 2D sprites (Sprite3D billboards). Multiple items on the same tile stack visually. Click/tap to pick up and add to the item bar. Items persist on the floor until picked up or the player leaves the level.
- **Item bar:** 10 slots. Drag an item to the party panel to use it on a character (healing, stat boost, cure). Drag an item to the dungeon view to throw it (bombs, poison flasks). Items in the item bar carry over between tiles but not between levels unless explicitly kept.
- **Inventory/Equipment:** drag an item from the item bar into a character's inventory to equip it. Equipment goes into the appropriate slot.
- **Shops:** items displayed with their icon and price. Tap to buy and add to item bar.

### Item Art Requirements

Each item needs two images:
- **Icon** (small, square): used in the item bar, equipment slots, and shop UI
- **Dungeon sprite** (larger, transparent background): used as the Sprite3D billboard when the item sits on the dungeon floor

---

## Enemies

### Enemy Base Stats

Each enemy has: HP, Movement Speed, Flying (yes/no), Intelligence, Strength, and a set of attacks (spell, distance, melee). Each enemy also has elemental resistances and weaknesses.

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
| Spinner | Rotates the player a fixed number of 90° turns when stepped on (direction + count rolled once per spinner). Re-arms when the player steps off. | No |

### Wall Objects

Objects attached to walls, rendered as sprites on the wall face.

| Object | Type |
|---|---|
| Painting | Decoration |
| Switch/Lever | Activates doors, bridges, reveals secrets |
| Door | Blocks passage until opened (key, switch, or spell) |
| Torch/Lantern | Light source, affects Shadow enemies |
| Secret wall | Looks like a normal corridor wall; the player can walk through it freely. The map draws the wall line at reduced opacity — observant players notice the lighter line and try walking through. Placement requires the wall to gate content. ANY_CONTENT mode allows gating anything (chest/lever/key/exit); LOOT_ONLY mode REQUIRES the wall to gate a chest or non-key floor item AND REJECTS placements that would also gate the exit, a lever, or a key — so secret walls in that mode are always pure side-rewards. |

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

## Quest System

Each biome has a pool of quests that are randomly chosen and placed during level generation. Quests add variety and narrative to the procedural levels.

### Quest Types

| Quest | Description |
|---|---|
| **Fetch quest** | An NPC asks the player to find a specific object somewhere in the level and bring it back |
| **Locked door** | A door requires a specific key (e.g., copper key) to open. The key is always placed in an accessible area before the door |
| **Rescue NPC** | An NPC is fleeing from an elite monster. The player can choose to fight the monster to save them |
| **Riddle statue** | A talking statue asks a riddle. Correct answer reveals a secret or grants a reward |
| **Thug encounter** | A thug NPC with multiple dialogue choices. Correct answers befriend them (potential party member or reward). Wrong answers trigger a fight |
| **Torch puzzle** | Light 3 (or more) torches with a fireball spell to make a hidden wall disappear, revealing a secret area |
| **Escort quest** | Protect a weak NPC as they walk to the exit |
| **Hunt quest** | Kill a specific elite enemy that roams the level |

### Quest Placement Rules

- Quests are placed after the base level is generated but before the player enters.
- Quest objects (keys, NPCs, puzzle elements) must be placed in reachable locations.
- Keys must always be accessible before their corresponding locked door (enforced by BFS).
- Each level has 0–3 quests depending on the biome configuration.
- Some quests are biome-specific (e.g., underwater quests only in underwater biome).

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
- Which quests can appear
- Special mechanics (underwater bubbles, damage floors, etc.)
- Background/skybox

Biomes are stored as `BiomeData` resources (`.tres` files) in `res://assets/biomes/`.

### Outdoor Biomes (no walls)

Some biomes are open-air — a sparse forest, a beach, a clifftop path — and have no solid walls. The player still moves on the same grid, but the impassable space outside the walkable area is filled with **billboarded filler sprites** (trees, rocks, bushes) instead of wall geometry. The sky is visible past the silhouettes.

A biome opts in by setting `outdoor_mode = true`. Four things change automatically:

1. **No wall geometry.** The renderer skips wall quads on every floor cell.
2. **No ceiling.** Outdoor biomes never render a ceiling regardless of `show_ceiling`.
3. **Fillers spawn instead.** Each `FillerSpawn` entry on the biome seeds N sprites per blocked cell, plus a configurable ring of cells outside the grid (so the horizon fades into trees instead of stopping at the grid edge).
4. **Floor extends past the walkable area.** A second floor-quad pass draws ground under every WALL cell inside the grid and across `outdoor_floor_extent` cells outside it, sampled from `filler_floor_textures` (or `floor_textures` as a fallback). Without this the trees float on the sky background and the player loses their depth cue.

The sky background is overridden per biome:
- `sky_material` (e.g. a `PanoramaSkyMaterial` with a panoramic texture) takes precedence when set.
- Otherwise `sky_color` (any opaque colour) fills the background as a flat hue.
- Otherwise the scene's default WorldEnvironment background stays as-is.

**Banned in outdoor biomes** (they need real wall geometry to attach to):
- Wall decorations (paintings, torches, lanterns)
- Projectile traps (wall-mounted launchers)
- Secret walls (the disguise relies on a normal-looking wall)

Leave those biome arrays empty for outdoor biomes.

**Wayfinding caveat.** Trees don't read as "you can't walk here" as instantly as solid walls. Density carries some of the illusion, but the heavy lifting is `FillerSpawn.front_row_bias` — sprites in WALL cells that border a FLOOR cell are pulled toward the floor-adjacent edge of their cell so the wall line clusters right at the boundary the player is approaching. Without this bias, random jitter can leave a tree at the far side of its cell and create the visual impression of a walkable gap that the player tries to step into and bumps an invisible wall. Default bias is 0.7 (strong wall-line read with lateral scatter for organic feel); tune up to 1.0 for a clearer boundary or down to 0 for pure random scatter. Typical setup also uses 3–5 sprites per blocked cell and a 4-cell border ring; fog hides the seam where the filler ring ends.

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

## Title Screen & Main Menu

### Main Menu

The title screen is the entry point of the game. It displays the game logo/title art and four buttons:

- **New Game** — opens the character creation screen
- **Continue** — resumes the current unfinished run (button only visible if a saved run exists)
- **Grimoire Pages** — opens the Grimoire screen to view collected pages, spend Void Ink, and unlock rewards
- **Options** — opens the options screen

### Character Creation (New Game Flow)

When the player selects "New Game", they go through the following steps:

1. **Class selection** — choose between Warrior, Wizard, Battle Mage, or Rogue. Each class card shows the base stats and starting equipment/spell so the player can make an informed choice.
2. **Gender selection** — Male or Female. Affects the portrait options available.
3. **Portrait selection** — choose a character portrait from a set of available portraits for the selected class and gender. Portraits are displayed as a scrollable gallery.
4. **Name entry** — type a name for the character (optional, default name provided per class).
5. **Confirmation** — summary screen showing the chosen class, gender, portrait, and name. Player confirms to start the run.

Each class starts with:
- Base stats determined by class
- A basic (bad) weapon appropriate to the class
- A basic (bad) armor
- Wizard and Battle Mage start with Minor Lightning spell
- Warrior and Rogue start with no spell

### Save & Load System

The game uses an **auto-save** system — the game state is saved automatically at key moments:

**When the game saves:**
- When entering a new level
- When exiting a level (reaching an exit)
- When the player opens the pause/settings menu
- When the app goes to background (mobile)

**What is saved (run state):**
- Current level number and biome
- Full grid state of the current level (explored tiles, object states, enemy positions)
- Player party data (all characters: stats, HP, MP, equipment, inventory, spells)
- Item bar contents
- Map exploration state (which tiles have been revealed)
- Grimoire pages carried (not yet inscribed)
- Void Ink collected this run
- Player position and facing direction on the grid

**What is saved (persistent/meta state):**
- Grimoire progress (which pages have been inscribed, which rewards unlocked)
- Total Void Ink available for spending
- Unlocked biome paths
- Unlocked characters, weapons, perks
- Options/settings (language, etc.)
- Best run statistics

**Save file location:** uses Godot's `user://` directory (`user://save_run.json` for the current run, `user://save_meta.json` for persistent data).

**Continue button logic:** the title screen checks if `user://save_run.json` exists and is valid. If yes, the Continue button is visible and loads the run. If the player dies or completes the game, the run save is deleted (but meta progress is kept).

### Options Screen

Accessible from the title screen and from the in-game settings button (⚙):

- **Language** — English, French, Spanish, Chinese, Japanese, Korean, German, Italian
- **Sound/Music volume** (future)
- **Screen orientation lock** (future)
- **Touch sensitivity** (future)

---

## Towns

Towns appear between boss fights. They serve as safe zones where the player can:

- Rest and heal
- Buy/sell equipment and items at shops
- Manage inventory
- Interact with NPCs for lore and quests
- Access the Grimoire

Towns are generated from a town-specific `BiomeData` (open layout, no enemies, no traps). Buildings (shops, inns, NPC houses) are **sub-level portals** — the player steps on a building entrance tile and enters a small interior sub-level generated from an interior `BiomeData`. Exiting the interior returns the player to the town at the building entrance. This keeps towns on the same architectural foundation as dungeons (see Sub-Levels under Level Progression).

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

## Key Design Principles

1. **Mobile first:** all interactions must work with touch. Buttons must be ≥5% of screen short side.
2. **Biome driven:** textures, enemies, objects, mechanics all defined per biome for maximum variety.
3. **Procedural with authored moments:** levels are generated but premade blocks inject hand-crafted content.
4. **Roguelite loop:** each run is fresh, but Grimoire unlocks carry over permanently.
5. **Old school feel:** pixel art textures, unshaded or ambient-only lighting, billboard sprites for objects.
6. **Configurable everything:** every parameter is an `@export` so designers can tune without code changes.
