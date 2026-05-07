# Wall decoration resources

`.tres` files in this folder are `WallDecorationData` resources — templates for paintings, torches, lanterns, and other wall-mounted ambiance. See `res://scripts/WallDecorationData.gd` for the full field reference.

## Adding a new decoration

1. Prepare the texture(s):
   - **Static** (paintings): one PNG, transparent background. Recommended 128×128.
   - **Animated** (torches, lanterns): N frames in `res://assets/textures/decorations/<name>/<name>_NN.png`, all the same dimensions, same anchor. See that folder's README.
2. For animated decorations, create a `SpriteFrames` resource:
   - Right-click in FileSystem → New Resource → SpriteFrames → save as `<name>_frames.tres` next to the data resource.
   - Open it in the inspector. Rename the default animation to `idle` (or whatever you like — the data resource's `default_animation` field must match). Set `Speed (FPS)` (~6 for a torch flicker), enable `Loop`. Drag the frame PNGs into the timeline IN ORDER.
3. Create the data resource:
   - Right-click in this folder → New Resource → WallDecorationData → save as `<name>.tres`.
   - Set `name_key` and `description_key` (translation keys; add rows in `res://localization/strings.csv`).
   - **Static**: set `Texture` to your single PNG. Leave `Frames` null.
   - **Animated**: set `Frames` to the SpriteFrames resource. Make sure `Default Animation` matches the animation name. Leave `Texture` null.
   - Set `World Height` (~1.5 for a torch, ~2.0 for a tall painting).
   - For 3D-volume decorations (torches, lanterns), enable `Face Camera` and set `Top Tilt Degrees` (~15 is a good starting point). The renderer then pins the base to the wall and rotates the sprite each frame to face the player with the top leaning out — reads as a 3D object the player walks around. Leave `Face Camera` off for flat paintings.
   - For glowing decorations, set `Light Color` (warm orange ≈ `1, 0.7, 0.4`), `Light Energy` (~1.5–2.0 for a torch), `Light Range` (~6). Use `Light Y Offset` to push the bright spot up onto the flame instead of the middle of the wooden handle — for a 1.5 m torch with the flame in the upper third, ~`0.4` works well. Negative values shift it down.
   - For flickering lights (torches, candles), set `Light Flicker Amount` to ~`0.15`–`0.25` (fraction of base energy). 0 = steady glow. Each placement gets its own random phase, so torches in the same biome never pulse in sync.
4. Wire it into a biome:
   - Open the biome `.tres` (e.g. `res://assets/biomes/forest.tres`).
   - In the `Wall Decorations` array, add a `WallDecorationSpawn`. Set `Decoration` to your new resource, `Count Min/Max`, `Placement` flags, optional `Min Distance To Other Decoration`.
