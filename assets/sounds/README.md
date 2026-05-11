# Sounds

All SFX are routed through the `SoundManager` autoload (see `res://scripts/SoundManager.gd`).

## Folder layout

```
res://assets/sounds/
├── ui/                ← global UI sounds (referenced by audio_config.tres)
├── movement/          ← non-biome player-action sounds (turn rustles, wall bump)
├── items/             ← per-item-category sounds, REUSABLE across items
└── biomes/<biome>/    ← biome-specific (footsteps, future ambient loop)
```

## Item sounds are reusable across items

Item sounds live under `items/` keyed **by category, not by item**. Multiple `.tres` files (Health Potion, Mana Potion, Antidote…) can all reference the same `items/potion_pickup_drop1.ogg`. Adding a numeric suffix (`_1`, `_2`) makes it easy to introduce variants later.

Naming convention: `<category>_<event>[N].ogg`

Examples:
- `items/potion_pickup_drop1.ogg` — used by every potion
- `items/potion_use1.ogg` — used by every potion
- `items/sword_pickup_drop1.ogg` — used by every weapon (future)
- `items/armor_pickup_drop1.ogg` — used by every armor piece (future)

## Where each sound is referenced

| Folder | File | Used by |
|---|---|---|
| `ui/` | `map_open.ogg`, `map_close.ogg`, `negative.ogg`, `pain.ogg` | `audio_config.tres` |
| `movement/` | `wall_bump.ogg`, `turn/turn_*.ogg` | `audio_config.tres` |
| `items/` | `potion_pickup_drop1.ogg`, `potion_use1.ogg`, … | individual item `.tres` files |
| `biomes/<biome>/move/` | `step_*.ogg` | the biome's `.tres` (`move_sounds` array) |
| `traps/` | `spike_activate.ogg`, `spike_deactivate.ogg`, … | individual trap `.tres` files (Phase 8 Task 3) |
| `spinners/` | `spin_whoosh.ogg`, … | individual spinner `.tres` files (Phase 8 Task 8 — optional; spinners fall back to the global `play_turn()` sound when their `spin_sound` is null) |

Trap sounds are referenced from per-variant `TrapData` `.tres` files via `activate_sound` / `deactivate_sound`. STEP traps play these non-spatially through SoundManager (the player is at the trap's feet — distance falloff would feel wrong); TIMED traps play them through a per-instance `AudioStreamPlayer3D` so the player hears them coming from across the dungeon. The 3D player's `max_distance` is set from `TrapData.hearing_distance` (linear-feeling falloff via inverse-distance attenuation).

## Adding a new sound

1. Drop the `.ogg` (or `.wav`) under the right folder following the conventions above.
2. Set `Loop = false` in the import tab unless it's a biome ambient loop (Phase 19).
3. Reference it from the right `.tres` (`audio_config.tres`, an item, or a biome).
4. SoundManager plays it via `play()`, `play_random()`, or one of its convenience methods.

## CI / headless

Tests run with `godot --headless` which uses the dummy audio driver — calls to `SoundManager.play()` are no-ops, no actual sound is rendered. Audio playback is not asserted in tests; only the SoundManager's null/empty-input safety is.
