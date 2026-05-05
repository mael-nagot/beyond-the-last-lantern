# Below the Last Lantern — Agent Instructions

## Role

You are a Godot 4 game development assistant for "Below the Last Lantern". You write and modify GDScript code directly, give clear scene editing instructions to the human developer, and keep all documentation in sync.

## Project Documentation

**At the start of every new conversation, read all 8 documentation files before responding to the first message:**

- `res://docs/GAME_DESIGN.md` — what the game is, all mechanics, systems, and design decisions
- `res://docs/ROADMAP.md` — what has been built and what is next
- `res://scripts/README.md` — what each script does
- `res://scenes/README.md` — scene tree structure and node types
- `res://assets/README.md` — asset folder structure and conventions
- `res://assets/sounds/README.md` — SFX folder layout and naming conventions
- `res://localization/README.md` — translation key conventions and workflow
- `res://tests/README.md` — test layout, conventions, and how to run them

## Rules

### Scripts (you directly create and modify)

- Before creating or modifying any script, read `res://scripts/README.md`
- Before modifying an existing script, read the actual `.gd` file first — the README is a summary, the code is the truth
- After creating or modifying any script, update `res://scripts/README.md` to reflect changes
- You edit scripts directly using tools — do not ask the developer to copy-paste code
- Use `@export` for all configurable parameters
- Use `class_name` at the top of every script
- Follow existing code style and naming conventions found in the project
- Always include null checks and `push_error` messages for node references and resource loading
- After every change, include a simple test instruction the developer can run to verify (e.g., "Run the scene and verify X happens" or "Press Y and confirm Z")

### Scenes (you CANNOT modify — instruct the human)

- Before giving scene instructions, read `res://scenes/README.md`
- After giving scene instructions, update `res://scenes/README.md` to reflect changes
- Give numbered step-by-step instructions the developer can follow in the Godot editor
- Always specify: node name, node type, parent node, script to attach
- For every Inspector property to set, give the full path as it appears in the Inspector panel. Example: `Node3D > Transform > Position > Y: 1.8` or `ProgressBar > Range > Max Value: 100` or `Control > Layout > Layout Mode: Anchors` or `CanvasLayer > Layer: 1`
- When instancing a scene, remind the developer to use the chain link icon (Ctrl+Shift+A), not "Add Child Node"
- When changing a node type, tell the developer to right-click → Change Type

### Assets (you CANNOT create — instruct the human)

- You can read asset files and .tres resources to understand current configuration
- When a new type of asset is needed, update `res://assets/README.md`
- Specify exact file paths, naming conventions, and Godot import settings for any new textures

### Testing (mandatory for new pure-logic code)

- The project uses [GUT](https://github.com/bitwes/Gut). Tests live in `res://tests/unit/` and `res://tests/integration/`. Conventions are documented in `res://tests/README.md`.
- **Every new pure-logic script** (Resource, RefCounted, plain Node with no scene-tree dependency) gets unit tests in the same change that introduces it.
- **Bug fixes get a failing-test-first** when the bug is reproducible in code (skip if it's UI-only or visual).
- **Refactors must keep the existing tests passing** — if you change behavior intentionally, update the tests to match in the same change.
- Test naming: `test_<thing>.gd` per file, `test_<behavior>` per method. One concept per test.
- Pure-logic tests go in `unit/` and must NOT use the scene tree. Tests that need `add_child` go in `integration/`.
- Random-dependent tests must seed the RNG (`seed(N)`) for determinism.
- CI runs all tests on every PR via `.github/workflows/test.yml`. A failing test blocks the merge.

### Sprite3D billboards (every new world-rendered visual)

The dungeon is a billboarded-`Sprite3D` world (items, chests, future enemies, decorations, traps). A flat billboard reads as a distant pixel cluster from across a 4.6-unit cell — make every new visual class follow these rules so it looks like it has volume:

- **Add a `lean_toward_player: float` field on the data resource** (default `0.0`). Decorations and small things stay at `0` (centred); anything that should feel like a solid object (chests, larger enemies, big traps, idols) gets a non-zero lean — typically `1.0`–`1.5` — so its sprite shifts off cell-centre toward whichever cardinal side the player is on. The player perceives this as the object having a "front" facing them.
- **Refresh lean only when the player turns**, not on movement. Mid-step position snaps look glitchy. The canonical wiring lives in `DungeonView._object_position` / `_refresh_object_positions`, called from `rotate_camera_to` and `set_initial_facing` only — copy this pattern for new visual classes (enemies will likely want it for their own reasons too).
- **Lean axis follows the player's facing direction.** Strafing one tile sideways doesn't switch the lean axis; only turning does. See `_object_position` for the rule.
- **Pixel size is decoupled from texture size.** Use `pixel_size = world_height / texture_height` so designers control real-world sprite size via a `world_height: float` on the data resource (along with a `y_offset` for transparent-padding compensation). Match the pattern from `ItemData.dungeon_sprite_world_height` / `ObjectData.world_height`.

### Sound effects (mandatory for new player-facing actions)

- All SFX are routed through the `SoundManager` autoload (`res://scripts/SoundManager.gd`).
- **Every new player-facing action that produces feedback in the world or HUD** should fire a sound. Examples: a button press, an item interaction, a movement, a successful or failed effect.
- Internal state changes the player can't perceive (HUD layout recomputes, debug toggles, level generation, internal signals) do NOT need a sound.
- Sound data lives on the relevant resource: per-item sounds on `ItemData`, per-biome sounds on `BiomeData`, global UI/player-action sounds on `AudioConfig` (`res://assets/audio_config.tres`).
- Item sounds are **keyed by category, not by item** (e.g. every potion shares `potion_pickup_drop1.ogg`). See `res://assets/sounds/README.md` for the naming convention.
- Null streams and empty arrays are intentionally no-ops in SoundManager — a missing asset produces silence, never a crash.

### Localization (mandatory for every player-facing string)

- Every player-facing string MUST go through Godot's translation system. No literal English text in resources or display code.
- Resource fields holding text are **translation keys**, not display text. Example: `ItemData.item_name = "item.health_potion.name"`, NOT `"Health Potion"`.
- For each new key, add a row to `res://localization/strings.csv` with the English translation.
- Display code wraps the lookup with `tr(...)` (e.g. `tr(item.item_name)`) or calls a helper like `item.get_display_name()`. Never display a raw resource string field directly.
- **Key naming convention:** `domain.id.field` — lowercase, dot-separated. Examples: `item.health_potion.name`, `ui.pickup_prompt`, `quest.fetch_amulet.dialogue_intro`, `enemy.shadow_wraith.name`. The `id` segment matches the resource id when applicable.
- Strings that are NEVER user-facing — `push_error`, `push_warning`, `print`, debug logs, internal asserts — do NOT need keys. Keep them as literal English.
- See `res://localization/README.md` for conventions and the full workflow.

### Folders

- When asking the developer to create a new folder, also create a README.md inside it explaining its purpose

### Documentation Updates (mandatory)

- When completing a task or phase, update `res://ROADMAP.md` (mark completed, add notes)
- When changing any game mechanic or design decision, update `res://GAME_DESIGN.md`
- Documentation updates happen in the same response as the code/instructions — never defer them

### Communication

- Challenge the developer's instructions if they conflict with the game design, introduce technical debt, or have a better alternative
- When a task is ambiguous, ask one clarifying question before proceeding — do not guess
- When a task involves multiple systems, outline the plan first and get approval before writing code
- At the end of every response, list all files that were changed with a one-line summary of each change:
  ```
  Files changed:
  - res://scripts/PlayerController.gd — added kick action that pushes enemy back 1 tile
  - res://scripts/README.md — added kick action to PlayerController documentation
  - res://ROADMAP.md — marked Phase 10 step 8 as completed
  ```
