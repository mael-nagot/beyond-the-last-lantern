class_name DungeonView
extends Node3D

## Per-scene fallback for ceiling rendering. Once `biome` is assigned,
## the biome's `show_ceiling` takes over — this only matters when
## previewing the scene without a biome configured.
@export var show_ceiling: bool = true
## Player camera height above the floor, in world units (~metres).
## Default 1.8 = adult human eye level. Lower values feel like a
## crouching / small character; higher feels giant.
@export var camera_eye_height: float = 1.8
## Per-scene fallback for wall height. Once `biome` is assigned, the
## biome's `wall_height` takes over.
@export var wall_height: float = 6.3
## The biome resource that drives all visuals + generation parameters
## (textures, fog, ambient, grid size, object pools …). Assigned by
## Game.gd at runtime; the inline value is a convenience for previewing
## a single scene in the editor.
@export var biome: BiomeData
## Camera vertical field-of-view in degrees. ~70 = realistic, ~100 =
## wider / more "old-school dungeon crawler". Higher widens peripheral
## vision but increases fisheye distortion at edges.
@export var fov: float = 100
## Aspect-ratio multiplier for the dungeon SubViewport in portrait
## orientation. >1 makes the dungeon view taller than the
## SubViewportContainer (the HUD compensates). 1.0 = exact fit.
## Default 1.15 gives the dungeon a bit more vertical room than the
## HUD allows, which feels less cramped on a phone.
@export var viewport_ratio_portrait:  float = 1.15
## Aspect-ratio multiplier for the dungeon SubViewport in landscape
## orientation. Same semantics as `viewport_ratio_portrait`.
@export var viewport_ratio_landscape: float = 1.15

const CELL_SIZE = 4.6
const ITEM_MAX_VISIBLE_PER_TILE = 3
const ITEM_STACK_OFFSETS: Array[Vector3] = [
	Vector3( 0.0, 0.0,  0.0),
	Vector3( 0.5, 0.0, -0.4),
	Vector3(-0.5, 0.0,  0.3),
]
# When the player stands ON a cell that holds items, the item sprites
# slide this many world units along the player's facing direction so
# they sit in the bottom of the view (otherwise they'd be directly
# under the camera and off-screen, given camera_eye_height vs item
# world_height). Snapped on cell-change and on turn — same trigger
# pattern as the chest-lean (`_object_position`).
const ITEM_ON_TILE_FORWARD_OFFSET: float = 1.5
const FACING_ANGLES = {
	Vector2i( 0, -1):    0.0,   # North
	Vector2i( 1,  0):  -90.0,   # East
	Vector2i( 0,  1): -180.0,   # South
	Vector2i(-1,  0): -270.0,   # West
}

var _current_angle: float = 0.0
var _current_facing: Vector2i = Vector2i(0, -1)
var _current_grid_pos: Vector2i = Vector2i.ZERO

@onready var viewport_container : SubViewportContainer = $SubViewportContainer
@onready var sub_viewport       : SubViewport          = $SubViewportContainer/SubViewport
@onready var camera             : Camera3D             = $SubViewportContainer/SubViewport/Camera
@onready var dungeon_root       : Node3D               = $SubViewportContainer/SubViewport/DungeonRoot
@onready var world_env          : WorldEnvironment      = $SubViewportContainer/SubViewport/WorldEnvironment

var generator: LevelGenerator
var _items_root: Node3D
var _objects_root: Node3D
var _doors_root: Node3D
# Wall-mounted switches — sibling to wall decorations + projectile-trap
# launchers in the "objects that live on wall FACES, not cells" group.
# Each WallSwitchInstance renders as a single Sprite3D anchored to its
# (view_cell, view_side) wall face with a child Area3D for click
# pickability. The sprite swap (closed/opened) mirrors any linked
# door's open state — same as LeverInstance via get_visual_opened().
# Switches with data.hide_when_active = true and is_on_door() = true
# vanish (sprite + Area3D) once a linked door opens; off-door switches
# ignore the flag.
var _wall_switches_root: Node3D
# WallSwitchInstance -> {root: Node3D, sprite: Sprite3D}. Keyed by
# instance so the per-click rebuild can flip a single switch's sprite
# without walking the scene tree.
var _wall_switch_visuals: Dictionary = {}
var _decorations_root: Node3D
# Outdoor-mode fillers (trees / rocks / bushes). Parented under its
# own root so a level rebuild can free the whole subtree in one go
# without touching the other rendered classes. Empty for indoor
# biomes — the build step short-circuits when biome.outdoor_mode is
# false or generator.fillers is empty.
var _fillers_root: Node3D
# Walkable-area scenery (trees, flowers, mushrooms, rocks). Parented
# under its own root so a level rebuild can free the whole subtree in
# one go without touching the other rendered classes. Each sprite is
# tracked in `_scenery_sprites` (SceneryInstance -> Sprite3D) so
# `_refresh_scenery_positions` can cheaply re-apply the lean offset on
# player turns — same pattern as `_object_sprites` for chests. Keyed by
# instance (not cell) because a cell with `density > 1` produces N
# Sprite3Ds that all share the same cell coord; the per-instance
# lookup is the only way to refresh them independently.
var _scenery_root: Node3D
var _scenery_sprites: Dictionary = {}
# Original WorldEnvironment background settings, captured the first
# time `_apply_biome_environment` runs. Used to RESTORE the indoor
# defaults when switching from an outdoor biome back to an indoor one
# (so the scene-authored environment is the source of truth, not
# whatever the last outdoor biome left behind).
var _saved_env_background_mode: int = -1
var _saved_env_background_color: Color = Color(0.0, 0.0, 0.0, 1.0)
var _saved_env_sky: Sky = null
var _traps_root: Node3D
# Wall-mounted projectile-trap launchers (Phase 8 Task 3 — Subtask C).
# Subtask C1 renders the launcher sprite statically. Subtask C2 adds
# in-flight projectile sprites under `_projectiles_root` (separate
# root so projectile churn doesn't disturb the launcher subtree). C4
# will add a plate decal subtree.
var _projectile_traps_root: Node3D
var _projectiles_root: Node3D
# ProjectileInstance → Sprite3D. DungeonView spawns one Sprite3D per
# active projectile in `spawn_projectile_visual`, syncs its position
# and per-camera-angle texture in `update_projectile_visual` (called
# every frame by Game.gd while the projectile is in flight), and
# frees it in `despawn_projectile_visual` on impact. The dictionary
# keeps the lookup O(1) without scanning the scene tree.
var _projectile_visuals: Dictionary = {}
# ProjectileTrapInstance → MeshInstance3D for the plate floor decal
# (Subtask C4). Only PRESSURE_PLATE traps that the placer assigned a
# valid plate cell appear here. The decal's material is swapped
# between idle and triggered textures via `_update_plate_visual_states`
# whenever the player enters / leaves a plate cell, so the player
# (and future enemies — Phase 10) get visual feedback that something
# is on the plate.
var _plate_visuals: Dictionary = {}
# ProjectileTrapInstance → bool. Tracks whether each plate is currently
# rendering its triggered material so we only swap on state CHANGES,
# not every camera move. Without this we'd issue a `material_override`
# write for every plate every step, even when the state didn't change.
var _plate_triggered_state: Dictionary = {}
# TrapInstance → Dictionary { "root": Node3D, "spikes_root": Node3D }
# Lookup so update_trap_visual / _refresh_trap_spike_positions can
# touch the spike subtree without walking the scene tree. The floor
# decal is permanent and not tracked here — only the spike root
# toggles per state change.
var _trap_visuals: Dictionary = {}

# Phase 8 Task 8 — spinner rendering. Each spinner gets a `Node3D`
# root parented to `_spinners_root`, with a flat decal `MeshInstance3D`
# as its child. The dict stores the ROOT (whose Y rotation is animated
# per frame) — not the decal mesh — so the visual rotation reads as
# a clean spin around the world Y axis instead of entangling with the
# decal's -90° X tilt. `_process` advances rotation directly each
# frame (cheaper than a looping tween, and naturally pauses with the
# SceneTree).
var _spinners_root: Node3D
var _spinner_visuals: Dictionary = {}  # SpinnerInstance -> Node3D root
# Teleporters (Phase 15 Task 6). One entry per endpoint (so a single
# pair has TWO entries — one per endpoint cell). The dict is keyed by
# endpoint cell (Vector2i) because each cell holds at most one
# teleporter endpoint, and Game.gd looks up visuals by the player's
# grid cell. Each entry stores:
#   - root: Node3D (positioned at the cell + lean offset)
#   - sprite_node: Sprite3D / AnimatedSprite3D (may be null when the
#     data has no sprite/frames but does have a light)
#   - light: OmniLight3D (may be null when light_energy = 0)
#   - data: TeleporterData (cached for the pulse update)
#   - pulse_phase: float (radians, per-pair offset)
#   - base_glow: float (TeleporterData.glow_multiplier — held so the
#     pulse update can centre the modulation on the configured value)
#   - base_alpha: float (same idea for alpha)
#   - base_light_energy: float (same for the light)
var _teleporters_root: Node3D
var _teleporter_visuals: Dictionary = {}
# Decorations using face_camera mode — DungeonView's `_process` rotates
# each one each frame to face the camera, with a designer-configured
# X-axis tilt so the top leans toward the player.
var _billboard_decorations: Array[Node3D] = []
# Lights that flicker — DungeonView's `_process` jitters each one's
# `light_energy` around its base value using a cheap multi-octave sine
# pseudo-noise. Metadata on each light stores base_energy, amount,
# and a per-placement phase so torches don't flicker in sync.
var _flickering_lights: Array[OmniLight3D] = []
var _object_sprites: Dictionary = {}  # Vector2i -> Sprite3D (for cheap per-move repositioning)
# Vector2i -> Array[Sprite3D]. Lookup so `_refresh_item_positions` can
# touch the visible stack on the player's current cell (and the cell
# they just left) without walking the scene tree. Populated by
# `_build_items`, cleared at the top of every rebuild.
var _item_sprites: Dictionary = {}
# Tween that slides item sprites between centred and shifted-forward
# positions in sync with the 0.12s camera move / rotate tween. Tracked
# so consecutive steps / turns kill the prior tween instead of fighting
# it for the sprite's position property.
var _item_tween: Tween = null
# One StandardMaterial3D per BiomeTextureEntry, reused across every
# quad that resolves to the same entry. Without this each quad allocated
# its own material, which costs hundreds of duplicate materials per
# level (one per wall side per cell).
var _material_cache: Dictionary = {}  # BiomeTextureEntry -> StandardMaterial3D
# Separate cache keyed by Texture2D for trap floor decals. Kept
# distinct from `_material_cache` so the two caches never collide on
# their key types.
var _trap_floor_material_cache: Dictionary = {}  # Texture2D -> StandardMaterial3D
var drop_target: DungeonDropTarget

func setup(gen: LevelGenerator) -> void:
	generator = gen
	_ensure_items_root()
	_ensure_objects_root()
	_ensure_doors_root()
	_ensure_wall_switches_root()
	_ensure_decorations_root()
	_ensure_traps_root()
	_ensure_projectile_traps_root()
	_ensure_projectiles_root()
	_ensure_spinners_root()
	_ensure_teleporters_root()
	_ensure_drop_target()
	_build_mesh()
	_build_objects()
	_build_doors()
	_build_wall_switches()
	_build_items()
	_build_traps()
	_build_projectile_traps()
	_clear_projectile_visuals()
	_build_spinners()
	_build_teleporters()
	_build_wall_decorations()
	_ensure_fillers_root()
	_build_outdoor_floors()
	_build_fillers()
	_ensure_scenery_root()
	_build_scenery()
	_place_camera_at_entrance()
	_apply_biome_environment()
	_update_viewport_size()
	get_viewport().size_changed.connect(_on_viewport_resized)

func _ensure_items_root() -> void:
	if _items_root != null and is_instance_valid(_items_root):
		return
	_items_root = Node3D.new()
	_items_root.name = "ItemsRoot"
	sub_viewport.add_child(_items_root)

func _ensure_objects_root() -> void:
	if _objects_root != null and is_instance_valid(_objects_root):
		return
	_objects_root = Node3D.new()
	_objects_root.name = "ObjectsRoot"
	sub_viewport.add_child(_objects_root)

func _ensure_doors_root() -> void:
	if _doors_root != null and is_instance_valid(_doors_root):
		return
	_doors_root = Node3D.new()
	_doors_root.name = "DoorsRoot"
	sub_viewport.add_child(_doors_root)

func _ensure_wall_switches_root() -> void:
	if _wall_switches_root != null and is_instance_valid(_wall_switches_root):
		return
	_wall_switches_root = Node3D.new()
	_wall_switches_root.name = "WallSwitchesRoot"
	sub_viewport.add_child(_wall_switches_root)

func _ensure_decorations_root() -> void:
	if _decorations_root != null and is_instance_valid(_decorations_root):
		return
	_decorations_root = Node3D.new()
	_decorations_root.name = "WallDecorationsRoot"
	sub_viewport.add_child(_decorations_root)

func _ensure_fillers_root() -> void:
	if _fillers_root != null and is_instance_valid(_fillers_root):
		return
	_fillers_root = Node3D.new()
	_fillers_root.name = "FillersRoot"
	sub_viewport.add_child(_fillers_root)

func _ensure_scenery_root() -> void:
	if _scenery_root != null and is_instance_valid(_scenery_root):
		return
	_scenery_root = Node3D.new()
	_scenery_root.name = "SceneryRoot"
	sub_viewport.add_child(_scenery_root)

func _ensure_traps_root() -> void:
	if _traps_root != null and is_instance_valid(_traps_root):
		return
	_traps_root = Node3D.new()
	_traps_root.name = "TrapsRoot"
	sub_viewport.add_child(_traps_root)

func _ensure_projectile_traps_root() -> void:
	if _projectile_traps_root != null and is_instance_valid(_projectile_traps_root):
		return
	_projectile_traps_root = Node3D.new()
	_projectile_traps_root.name = "ProjectileTrapsRoot"
	sub_viewport.add_child(_projectile_traps_root)

func _ensure_projectiles_root() -> void:
	if _projectiles_root != null and is_instance_valid(_projectiles_root):
		return
	_projectiles_root = Node3D.new()
	_projectiles_root.name = "ProjectilesRoot"
	sub_viewport.add_child(_projectiles_root)

func _ensure_spinners_root() -> void:
	if _spinners_root != null and is_instance_valid(_spinners_root):
		return
	_spinners_root = Node3D.new()
	_spinners_root.name = "SpinnersRoot"
	sub_viewport.add_child(_spinners_root)

func _ensure_teleporters_root() -> void:
	if _teleporters_root != null and is_instance_valid(_teleporters_root):
		return
	_teleporters_root = Node3D.new()
	_teleporters_root.name = "TeleportersRoot"
	sub_viewport.add_child(_teleporters_root)

# Frees every active projectile sprite and resets the lookup dict.
# Called from `setup()` so a level transition doesn't leak in-flight
# projectile sprites from the previous level (the projectile list on
# `LevelGenerator` is also cleared in `generate()`, so the two stay
# in sync).
func _clear_projectile_visuals() -> void:
	for proj in _projectile_visuals.keys():
		var sprite: Node = _projectile_visuals[proj]
		if is_instance_valid(sprite):
			sprite.queue_free()
	_projectile_visuals.clear()

func _ensure_drop_target() -> void:
	if drop_target != null and is_instance_valid(drop_target):
		return
	# SubViewportContainer captures input by default and rejects drops
	# (it has no _can_drop_data of its own). Disable its capture so the
	# overlay we add can receive drag events instead.
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drop_target = DungeonDropTarget.new()
	drop_target.name = "DropTarget"
	drop_target.camera = camera
	viewport_container.add_child(drop_target)
	drop_target.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _on_viewport_resized() -> void:
	_update_viewport_size()

func _update_viewport_size() -> void:
	var screen      = get_viewport().get_visible_rect().size
	var is_portrait = screen.y > screen.x

	var vp_width: int
	var vp_height: int

	if is_portrait:
		vp_width  = int(screen.x)
		vp_height = int(screen.x * viewport_ratio_portrait)
	else:
		vp_height = int(screen.y)
		vp_width  = int(screen.y * viewport_ratio_landscape)

	sub_viewport.size       = Vector2i(vp_width, vp_height)
	viewport_container.size = Vector2(vp_width, vp_height)

	if is_portrait:
		viewport_container.position = Vector2((screen.x - vp_width) * 0.5, 0)
	else:
		viewport_container.position = Vector2(0, (screen.y - vp_height) * 0.5)

	camera.fov = fov

	# Force black background in the sub viewport
	sub_viewport.transparent_bg = false
	RenderingServer.set_default_clear_color(Color(0.0, 0.0, 0.0, 1.0))

func update_viewport_ratios(portrait_ratio: float, landscape_ratio: float) -> void:
	viewport_ratio_portrait  = portrait_ratio
	viewport_ratio_landscape = landscape_ratio
	_update_viewport_size()

func _build_mesh() -> void:
	for child in dungeon_root.get_children():
		child.queue_free()
	# Materials may have been built against a stale biome on the previous
	# generate; rebuild from scratch so designers tweaking the biome live
	# see their edits.
	_material_cache.clear()
	# Per-surface placement history — each maps `BiomeTextureEntry` →
	# `Array[Vector2i]` of cells already using that entry. Picker reads
	# this to enforce `min_distance_to_same` and we append after each
	# pick. Iteration order (x outer, y inner) is stable, so the history
	# evolves identically across rebuilds.
	var wall_history: Dictionary = {}
	var floor_history: Dictionary = {}
	var ceiling_history: Dictionary = {}
	# Outdoor biomes have no wall geometry and no ceiling — the player
	# sees floors, fillers (trees / rocks), and the sky background.
	# Coupling the two is intentional: an outdoor biome with a ceiling
	# would feel like a closed room with invisible walls.
	var outdoor: bool = biome != null and biome.outdoor_mode
	var ceiling_enabled: bool = show_ceiling and not outdoor

	for x in range(generator.grid_width):
		for y in range(generator.grid_height):
			var cell = generator.get_cell(x, y)
			if cell == null or cell.cell_type == GridCell.CellType.WALL:
				continue

			var cx = x * CELL_SIZE + CELL_SIZE * 0.5
			var cy = y * CELL_SIZE + CELL_SIZE * 0.5
			var grid_pos := Vector2i(x, y)
			# A wall between a corridor cell and a room cell is two
			# separate quads (one drawn from each floor cell's side); each
			# uses its host floor cell's classification, so the same wall
			# can render mossy on the corridor side and clean on the room
			# side without any extra book-keeping.
			var classification: int = generator.classify_cell(grid_pos)

			var floor_entry: BiomeTextureEntry = BiomeTextureEntry.pick_for(
				biome.floor_textures, classification, grid_pos, floor_history)
			if floor_entry != null:
				_record_history(floor_history, floor_entry, grid_pos)
				_add_horizontal_quad(Vector3(cx, 0.0, cy), _material_for_entry(floor_entry))

			if ceiling_enabled:
				var ceil_entry: BiomeTextureEntry = BiomeTextureEntry.pick_for(
					biome.ceiling_textures, classification, grid_pos, ceiling_history)
				if ceil_entry != null:
					_record_history(ceiling_history, ceil_entry, grid_pos)
					_add_horizontal_quad(Vector3(cx, wall_height, cy), _material_for_entry(ceil_entry), true)

			if outdoor:
				# Wall geometry is replaced by fillers (see _build_fillers).
				continue

			var neighbours = [
				[Vector2i( 0, -1), Vector3(cx, wall_height * 0.5, cy - CELL_SIZE * 0.5),   0.0],
				[Vector2i( 0,  1), Vector3(cx, wall_height * 0.5, cy + CELL_SIZE * 0.5), 180.0],
				[Vector2i(-1,  0), Vector3(cx - CELL_SIZE * 0.5, wall_height * 0.5, cy),  90.0],
				[Vector2i( 1,  0), Vector3(cx + CELL_SIZE * 0.5, wall_height * 0.5, cy), 270.0],
			]
			# Wall classification is per-face (not per-cell) so that a
			# dead-end cell's BACK wall — the one facing the player as
			# they walk toward the dead end — can pick from
			# PLACEMENT_DEAD_END entries while the two side walls fall
			# back to PLACEMENT_CORRIDOR. The same hash + same matching
			# set still resolves to the same entry, so within one
			# classification all faces stay coherent.
			for n in neighbours:
				var dir   = n[0] as Vector2i
				var npos  = Vector2i(x + dir.x, y + dir.y)
				var ncell = generator.get_cell(npos.x, npos.y)
				# Either a real wall on this side OR a secret wall on the
				# edge between this floor cell and the neighbour cell —
				# both render the same way (a wall quad picked from the
				# biome's wall_textures pool), so the secret wall is
				# indistinguishable from a regular corridor wall.
				var has_real_wall: bool = ncell != null and ncell.cell_type == GridCell.CellType.WALL
				var has_secret_wall: bool = false
				if not has_real_wall and ncell != null:
					has_secret_wall = generator.get_secret_wall_at_edge(grid_pos, npos) != null
				if has_real_wall or has_secret_wall:
					var wall_classification: int = generator.classify_wall_face(grid_pos, dir)
					var wall_entry: BiomeTextureEntry = BiomeTextureEntry.pick_for(
						biome.wall_textures, wall_classification, grid_pos, wall_history)
					if wall_entry != null:
						_record_history(wall_history, wall_entry, grid_pos)
						_add_vertical_quad(n[1], n[2], _material_for_entry(wall_entry))

func _record_history(history: Dictionary, entry: BiomeTextureEntry, cell_pos: Vector2i) -> void:
	if not history.has(entry):
		history[entry] = []
	history[entry].append(cell_pos)

func rebuild_items() -> void:
	if _items_root == null:
		return
	_build_items()
	# An item appearing on or leaving a plate cell flips the plate's
	# triggered visual state (and its blocking effect on the trap —
	# see `Game._check_pressure_plate_trigger`). The diff inside
	# `_update_plate_visual_states` is cheap when nothing changed,
	# so calling it unconditionally on every item change is fine.
	_update_plate_visual_states()

func rebuild_objects() -> void:
	if _objects_root == null:
		return
	_build_objects()

func rebuild_doors() -> void:
	if _doors_root == null:
		return
	_build_doors()
	# Wall switches care about their linked doors' state (sprite swap +
	# hide_when_active). Refreshing both in lockstep keeps the click
	# feedback consistent — never a "door is now open but the switch
	# still shows its closed sprite" frame.
	rebuild_wall_switches()

func rebuild_wall_switches() -> void:
	if _wall_switches_root == null:
		return
	_build_wall_switches()

func _build_objects() -> void:
	for child in _objects_root.get_children():
		child.queue_free()
	_object_sprites.clear()
	for x in range(generator.grid_width):
		for y in range(generator.grid_height):
			var cell: GridCell = generator.get_cell(x, y)
			if cell == null or cell.object == null or cell.object.data == null:
				continue
			var data: ObjectData = cell.object.data
			# get_visual_opened() lets a LeverInstance derive its sprite
			# from its linked door's state; for a chest it just mirrors
			# the chest's own `opened` flag.
			var tex: Texture2D = data.opened_sprite if (cell.object.get_visual_opened() and data.opened_sprite != null) else data.closed_sprite
			if tex == null:
				continue
			var grid_pos := Vector2i(x, y)

			var sprite := Sprite3D.new()
			sprite.texture = tex
			var tex_h: int = max(1, tex.get_height())
			sprite.pixel_size = data.world_height / float(tex_h)
			sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			sprite.position = _object_position(grid_pos, data)

			# Click pickability — Area3D + matching box collider. The
			# DungeonDropTarget raycasts on left-click to find these.
			var area := Area3D.new()
			area.input_ray_pickable = true
			area.set_meta("object_instance", cell.object)
			area.set_meta("grid_pos", grid_pos)
			var col := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(data.world_height, data.world_height, data.world_height)
			col.shape = box
			area.add_child(col)
			sprite.add_child(area)

			_objects_root.add_child(sprite)
			_object_sprites[grid_pos] = sprite

func _object_position(grid_pos: Vector2i, data: ObjectData) -> Vector3:
	var cx: float = grid_pos.x * CELL_SIZE + CELL_SIZE * 0.5
	var cz: float = grid_pos.y * CELL_SIZE + CELL_SIZE * 0.5
	var ox: float = 0.0
	var oz: float = 0.0
	if data.lean_toward_player > 0.0:
		var diff := _current_grid_pos - grid_pos
		# Lean along the axis the PLAYER is currently facing (turning is
		# what switches the lean axis; strafing one tile sideways keeps
		# you on the same axis so the chest stays on the same side).
		# If the player has zero displacement along the facing axis but
		# is offset on the other, fall back to that other axis so the
		# chest still picks a side.
		var prefer_x: bool = abs(_current_facing.x) > abs(_current_facing.y)
		if prefer_x and diff.x != 0:
			ox = float(signi(diff.x)) * data.lean_toward_player
		elif (not prefer_x) and diff.y != 0:
			oz = float(signi(diff.y)) * data.lean_toward_player
		elif diff.x != 0:
			ox = float(signi(diff.x)) * data.lean_toward_player
		elif diff.y != 0:
			oz = float(signi(diff.y)) * data.lean_toward_player
	return Vector3(cx + ox, data.world_height * 0.5 + data.y_offset, cz + oz)

func _refresh_object_positions() -> void:
	# Cheap per-move update — only sprites whose cell.object.data has a
	# non-zero lean actually need new positions, but the per-call work
	# is trivial (O(n) over ~10 chests) so we just iterate them all.
	for grid_pos in _object_sprites.keys():
		var sprite: Sprite3D = _object_sprites[grid_pos]
		if not is_instance_valid(sprite):
			continue
		var cell: GridCell = generator.get_cell(grid_pos.x, grid_pos.y)
		if cell == null or cell.object == null or cell.object.data == null:
			continue
		sprite.position = _object_position(grid_pos, cell.object.data)

# -------------------------------------------------------
# Doors — edge-based, fully static once placed. NEVER repositioned
# on player movement / turn. Position and orientation are derived
# entirely from (cell_a, cell_b) on the DoorInstance.
# -------------------------------------------------------
func _build_doors() -> void:
	for child in _doors_root.get_children():
		child.queue_free()
	if generator == null:
		return
	for door in generator.doors:
		if door == null or door.data == null:
			continue
		# Hidden doors (`appears_as_wall = true`) render as biome wall
		# geometry when closed and as NOTHING when open — a true secret
		# passage. The closed_sprite / opened_sprite fields are
		# ignored. No Area3D either — the door panel mustn't be
		# clickable; the wall switch is the only interaction surface
		# (paired switches always render via WallSwitchesRoot).
		var node: Node3D
		if door.data.appears_as_wall:
			node = _make_hidden_door_node(door)
		else:
			node = _make_door_node(door)
		if node != null:
			_doors_root.add_child(node)

func _make_door_node(door: DoorInstance) -> Node3D:
	var data: ObjectData = door.data
	var tex: Texture2D = data.opened_sprite if (door.opened and data.opened_sprite != null) else data.closed_sprite
	if tex == null:
		return null

	# Anchor the whole door (visual + collider) at the edge midpoint
	# so position is computed once and never drifts.
	var root := Node3D.new()
	root.position = _door_position(door)
	root.rotation_degrees = Vector3(0.0, _door_y_rotation_deg(door), 0.0)

	var sprite := Sprite3D.new()
	sprite.texture = tex
	var tex_w: int = max(1, tex.get_width())
	var tex_h: int = max(1, tex.get_height())
	sprite.pixel_size = data.world_height / float(tex_h)
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	# Sprite3D is centred — the root already sits at (mid_x, world_h/2 + y_off, mid_z),
	# so the sprite stays at local origin.
	sprite.position = Vector3.ZERO
	# Stretch horizontally so a square wall texture renders at corridor
	# proportions. world_width = 0 keeps the texture's natural aspect.
	if data.world_width > 0.0:
		var natural_world_width: float = float(tex_w) * sprite.pixel_size
		if natural_world_width > 0.0:
			sprite.scale = Vector3(data.world_width / natural_world_width, 1.0, 1.0)
	root.add_child(sprite)

	# Click pickability lives on a sibling Area3D so the sprite's
	# scale.x doesn't deform the collider. The Area3D is created
	# REGARDLESS of `data.interactable` — that flag now controls
	# whether the click toggles the door or just plays feedback
	# (locked sound + toast). Either way, the click must register.
	var area := Area3D.new()
	area.input_ray_pickable = true
	area.set_meta("object_instance", door)
	# grid_pos is meaningless for an edge object; expose cell_a as
	# a stable single-cell sentinel for handlers that expect one.
	area.set_meta("grid_pos", door.cell_a)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var box_width: float = data.world_width if data.world_width > 0.0 else CELL_SIZE
	box.size = Vector3(box_width, data.world_height, 0.6)
	col.shape = box
	area.add_child(col)
	root.add_child(area)

	return root

func _door_position(door: DoorInstance) -> Vector3:
	# Midpoint between cell centres. With cell_a + cell_b canonically
	# sorted (axis is (1,0) or (0,1)), this lands exactly on the cell
	# boundary along the corridor axis.
	var mid_x: float = (float(door.cell_a.x + door.cell_b.x) + 1.0) * 0.5 * CELL_SIZE
	var mid_z: float = (float(door.cell_a.y + door.cell_b.y) + 1.0) * 0.5 * CELL_SIZE
	var y: float = door.data.world_height * 0.5 + door.data.y_offset
	return Vector3(mid_x, y, mid_z)

func _door_y_rotation_deg(door: DoorInstance) -> float:
	# Default Sprite3D faces local -Z. To make the door's plane sit on
	# the cell boundary we rotate around Y depending on the corridor's
	# axis:
	#   axis (1,0) (E-W corridor) → door faces +/- X → rotate 90°
	#   axis (0,1) (N-S corridor) → door faces +/- Z → rotate 0°
	if door.axis() == Vector2i(1, 0):
		return 90.0
	return 0.0

# -------------------------------------------------------
# Hidden doors (`ObjectData.appears_as_wall = true`).
#
# When CLOSED: render as two flat wall quads (one drawn from each
# side of the edge) using a single material picked deterministically
# from `biome.wall_textures` so both faces match — a mismatched pair
# would give the secret away. Width = CELL_SIZE (one corridor wide),
# height = wall_height (matching the surrounding cell walls). The
# material is the same StandardMaterial3D the regular cell-wall pass
# uses, drawn from `_material_for_entry`, so the panel is
# pixel-indistinguishable from any other corridor wall.
#
# When OPEN: render NOTHING — the corridor is open. The map renders
# similarly (a wall LINE on the edge when closed, no edge at all
# when open).
#
# No Area3D — clicking the wall does nothing. The paired wall switch
# is the only interaction surface.
# -------------------------------------------------------
func _make_hidden_door_node(door: DoorInstance) -> Node3D:
	if door.opened:
		# True secret passage — completely open when activated. Returning
		# an empty Node3D rather than null keeps the parent slot present
		# (defensive against any future caller expecting the index).
		return Node3D.new()
	if biome == null or biome.wall_textures.is_empty():
		return null
	# Pick a deterministic wall variant per door so the same hidden
	# door always uses the same texture across mesh rebuilds. Using
	# door.cell_a as the hash position keeps the result stable.
	var entry: BiomeTextureEntry = BiomeTextureEntry.pick_for(
		biome.wall_textures, ObjectSpawn.PLACEMENT_CORRIDOR, door.cell_a, {})
	if entry == null:
		# Final fallback — pick the first non-null entry so we never
		# render a completely blank panel (which would be MORE
		# noticeable than a slightly-wrong texture).
		for e in biome.wall_textures:
			if e != null and e.albedo != null:
				entry = e
				break
		if entry == null:
			return null
	var mat: StandardMaterial3D = _material_for_entry(entry)
	# Anchor at the edge midpoint, oriented like a regular door (the
	# meshes themselves don't need rotation — we build them so their
	# normals point outward from each cell). Building two MeshInstance3Ds
	# instead of one keeps each face's normals correct for back-face
	# culling and matches the way the cell-wall pass renders edges.
	var root := Node3D.new()
	var mid_x: float = (float(door.cell_a.x + door.cell_b.x) + 1.0) * 0.5 * CELL_SIZE
	var mid_z: float = (float(door.cell_a.y + door.cell_b.y) + 1.0) * 0.5 * CELL_SIZE
	root.position = Vector3(mid_x, wall_height * 0.5, mid_z)
	# Y rotation per axis: same convention as `_door_y_rotation_deg` so
	# the quad's plane sits ON the edge (not parallel to it).
	#   E-W corridor → axis (1, 0) → quad must run along Z → rotate 90°.
	#   N-S corridor → axis (0, 1) → quad must run along X → rotate 0°.
	var y_rot: float = 90.0 if door.axis() == Vector2i(1, 0) else 0.0
	root.rotation_degrees = Vector3(0.0, y_rot, 0.0)
	# Two co-planar quads with opposite-facing normals — same material
	# on both, so the secret stays hidden whichever side the player is
	# on. `flip` toggles the second quad's normal.
	root.add_child(_make_hidden_door_quad(mat, false))
	root.add_child(_make_hidden_door_quad(mat, true))
	return root

func _make_hidden_door_quad(mat: StandardMaterial3D, flip: bool) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(CELL_SIZE, wall_height)
	quad.surface_set_material(0, mat)
	mesh_instance.mesh = quad
	# QuadMesh defaults to a vertical quad in XY plane facing +Z. To
	# make a second quad facing -Z, flip 180° around Y. The flipped
	# quad's normal points the opposite way so back-face culling
	# correctly shows the right face to each side of the corridor.
	if flip:
		mesh_instance.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	return mesh_instance

# -------------------------------------------------------
# Wall switches — sibling to wall decorations + projectile-trap
# launchers. Each switch is anchored to a (view_cell, view_side) wall
# face: the player stands in view_cell looking at the wall whose
# normal points -view_side (toward the player). The Sprite3D is
# rotated so it faces back at the player; an Area3D + box collider
# makes the click pickable. Sprite swap (closed/opened) mirrors any
# linked door's `opened` state via `WallSwitchInstance.get_visual_opened()`.
#
# `should_hide()` (true iff data.hide_when_active is on AND the
# switch sits on the door panel AND a linked door is open) skips
# rendering entirely — the switch + its click area both vanish. Off-
# door switches IGNORE the flag.
# -------------------------------------------------------
func _build_wall_switches() -> void:
	for child in _wall_switches_root.get_children():
		child.queue_free()
	_wall_switch_visuals.clear()
	if generator == null:
		return
	for sw in generator.wall_switches:
		if sw == null or sw.data == null:
			continue
		if sw.should_hide():
			continue
		var node := _make_wall_switch_node(sw)
		if node == null:
			continue
		_wall_switches_root.add_child(node)
		# `_wall_switch_visuals` keeps the root + sprite handle around
		# in case a future incremental update wants to swap a single
		# switch's texture without rebuilding the whole subtree. Today
		# `rebuild_wall_switches` just rebuilds — the dict is here for
		# future use and consistency with `_object_sprites`.
		_wall_switch_visuals[sw] = node

func _make_wall_switch_node(sw: WallSwitchInstance) -> Node3D:
	var data: ObjectData = sw.data
	var tex: Texture2D = data.opened_sprite if (sw.get_visual_opened() and data.opened_sprite != null) else data.closed_sprite
	if tex == null:
		return null
	var root := Node3D.new()
	root.position = _wall_switch_position(sw)
	root.rotation_degrees = Vector3(0.0, _wall_switch_y_rotation_deg(sw.view_side), 0.0)
	var sprite := Sprite3D.new()
	sprite.texture = tex
	var tex_h: int = max(1, tex.get_height())
	sprite.pixel_size = data.world_height / float(tex_h)
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.position = Vector3.ZERO
	# Optional horizontal stretch — usually unset for switches (small
	# props don't need to fill the corridor like doors do).
	if data.world_width > 0.0:
		var tex_w: int = max(1, tex.get_width())
		var natural_world_width: float = float(tex_w) * sprite.pixel_size
		if natural_world_width > 0.0:
			sprite.scale = Vector3(data.world_width / natural_world_width, 1.0, 1.0)
	root.add_child(sprite)
	# Click pickability. Same Area3D + box collider pattern as the
	# door. Always created (the switch is always interactable when
	# rendered — `should_hide` already filtered the hidden case).
	var area := Area3D.new()
	area.input_ray_pickable = true
	area.set_meta("object_instance", sw)
	# Stable single-cell sentinel for handlers that expect grid_pos —
	# the switch's view_cell.
	area.set_meta("grid_pos", sw.view_cell)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# Box matches the sprite's logical bounds. The thin depth (0.6)
	# matches the door's collider so a click through the sprite plane
	# still registers.
	var box_w: float = data.world_width if data.world_width > 0.0 else data.world_height
	box.size = Vector3(box_w, data.world_height, 0.6)
	col.shape = box
	area.add_child(col)
	root.add_child(area)
	return root

# World position of the switch sprite's centre. The wall face midpoint
# sits half a cell from the view_cell centre in the wall direction;
# the sprite is then shifted by `along_offset` along the wall tangent
# (perpendicular to the wall normal in the XZ plane). NORTH/SOUTH
# walls use +X as their tangent; EAST/WEST walls use +Z. Sign of the
# offset is rolled at placement, so a fixed tangent direction works.
# A tiny inward bias (0.02 world units) prevents Z-fighting with the
# wall texture beneath, mirroring the WallDecoration `depth_offset`
# default.
const _WALL_SWITCH_DEPTH_BIAS: float = 0.02

func _wall_switch_position(sw: WallSwitchInstance) -> Vector3:
	var cx: float = sw.view_cell.x * CELL_SIZE + CELL_SIZE * 0.5
	var cz: float = sw.view_cell.y * CELL_SIZE + CELL_SIZE * 0.5
	var wall_dir := WallSwitchInstance.dir_for_side(sw.view_side)
	# The wall face midpoint is half a cell from the cell centre in
	# the wall direction. We then back off by the depth bias so the
	# sprite floats slightly in front of the wall (toward the player).
	var face_x: float = cx + float(wall_dir.x) * (CELL_SIZE * 0.5 - _WALL_SWITCH_DEPTH_BIAS)
	var face_z: float = cz + float(wall_dir.y) * (CELL_SIZE * 0.5 - _WALL_SWITCH_DEPTH_BIAS)
	# Tangent along the wall. NORTH/SOUTH walls run along X; EAST/WEST
	# along Z.
	if sw.view_side == WallSwitchInstance.SIDE_NORTH or sw.view_side == WallSwitchInstance.SIDE_SOUTH:
		face_x += sw.along_offset
	else:
		face_z += sw.along_offset
	var y: float = sw.data.world_height * 0.5 + sw.data.y_offset
	return Vector3(face_x, y, face_z)

# Rotation around Y so the sprite (which defaults to facing local -Z =
# world north) faces back at the player who stands in view_cell. With
# the wall on the cell's NORTH side, the player faces north when
# looking at the switch, so the switch must face south (+Z) — rotate
# 180°. The other three sides mirror this.
func _wall_switch_y_rotation_deg(view_side: int) -> float:
	match view_side:
		WallSwitchInstance.SIDE_NORTH:
			return 180.0
		WallSwitchInstance.SIDE_SOUTH:
			return 0.0
		WallSwitchInstance.SIDE_EAST:
			return -90.0
		WallSwitchInstance.SIDE_WEST:
			return 90.0
	return 0.0

# -------------------------------------------------------
# Traps — Phase 8 Task 3 Subtask A.
#
# Each trap renders as TWO pieces inside `TrapsRoot`:
#  1. Flat floor decals ("holes" art). A trap with a `grid_cols × grid_rows`
#     grid emits one decal per slot, all coplanar slightly above the floor.
#     Always visible — the holes communicate danger even when spikes are
#     retracted. To keep draw calls cheap when many traps are placed
#     (e.g. corridor clusters + room density combined), every decal
#     across every trap that shares a `holes_sprite` texture renders as
#     a single batched `MultiMeshInstance3D` — N hundred individual
#     `MeshInstance3D` nodes collapse into one draw call per texture.
#  2. A per-spike Sprite3D billboard tree under a "Spikes" Node3D
#     (visible only while the trap is EXTENDED). Each spike is its
#     own billboard so the cluster reads as 3D — multiple billboards
#     at different XZ positions parallax against each other as the
#     player moves around the cell. These STAY individual nodes
#     because (a) they need FIXED_Y billboarding which MultiMesh would
#     need a custom shader to replicate, and (b) Game.gd toggles their
#     `visible` flag per state — bookkeeping is cleaner with a per-trap
#     parent. Spikes are also only on-screen while extended, so peak
#     draw-call cost is a fraction of the always-visible decals.
#
# Per-trap state lookup: `_trap_visuals` keys by TrapInstance and stores
# `{ root, spikes_root }` (the spike parent Node3D, used by
# `update_trap_visual` and `_refresh_trap_spike_positions`). The decals
# live in shared MultiMesh nodes and don't need per-trap handles —
# they're never toggled or moved after the level is built.
# -------------------------------------------------------
func _build_traps() -> void:
	for child in _traps_root.get_children():
		child.queue_free()
	# Kill any in-flight extension tweens from the previous build — the
	# Sprite3D nodes they target are about to be queue_freed. The
	# callbacks are guarded by `is_instance_valid` so they'd no-op, but
	# leaving a doomed tween running burns frames.
	for entry in _trap_visuals.values():
		var prev_tween: Variant = entry.get("tween", null)
		if prev_tween != null and prev_tween is Tween and prev_tween.is_running():
			prev_tween.kill()
	_trap_visuals.clear()
	if generator == null:
		return
	# Group floor decals by `holes_sprite` so each texture gets exactly
	# one MultiMeshInstance3D — a single draw call across every trap
	# that shares that art. Collected up front, built once after the
	# per-trap loop so the MultiMesh's `instance_count` is final before
	# we set transforms.
	var decals_by_texture: Dictionary = {}  # Texture2D -> Array[Transform3D]
	for trap in generator.traps:
		if trap == null or trap.data == null:
			continue
		var entry: Dictionary = _make_trap_spikes(trap)
		# Empty dict signals "nothing renderable" (assets misconfigured).
		if entry.is_empty():
			continue
		_traps_root.add_child(entry["root"])
		_trap_visuals[trap] = entry
		_gather_trap_decal_transforms(trap, decals_by_texture)
	for tex in decals_by_texture:
		var transforms: Array = decals_by_texture[tex]
		if transforms.is_empty():
			continue
		_traps_root.add_child(_make_trap_decal_multimesh(tex, transforms))

func rebuild_traps() -> void:
	if _traps_root == null:
		return
	_build_traps()

func rebuild_projectile_traps() -> void:
	if _projectile_traps_root == null:
		return
	_build_projectile_traps()

# Cheap per-tick path: flip the spike subtree's `visible` flag without
# rebuilding the trap. Game.gd calls this on each ACTIVATED /
# DEACTIVATED event from TrapInstance.tick.
#
# When the TrapData has both `extended_sprite_frame1` and
# `extended_sprite_frame2` set, the transition is animated by swapping
# the texture on every spike Sprite3D at fixed intervals:
#   extending: hidden → frame1 → frame2 → extended (2 dwells)
#   retracting: extended → frame2 → frame1 → hidden (2 dwells)
# Otherwise the visibility flag is flipped instantly (original
# behaviour, preserved for trap variants without intermediate art).
func update_trap_visual(trap: TrapInstance) -> void:
	if trap == null:
		return
	var entry: Variant = _trap_visuals.get(trap, null)
	if entry == null:
		return
	var spikes_root: Node3D = entry["spikes_root"]
	if not is_instance_valid(spikes_root):
		return
	var data: TrapData = trap.data
	var sprites: Array = entry.get("sprites", [])
	var animate: bool = data != null \
		and data.extended_sprite_frame1 != null \
		and data.extended_sprite_frame2 != null \
		and not sprites.is_empty()
	# Kill any in-flight animation so a fast retrigger (rare with the
	# default timings, but possible if the designer pushes durations
	# below the animation length) replaces it cleanly instead of
	# stacking texture-swap callbacks.
	var prev: Variant = entry.get("tween", null)
	if prev != null and prev is Tween and prev.is_running():
		prev.kill()
	entry["tween"] = null
	if not animate:
		spikes_root.visible = trap.is_extended()
		return
	var step: float = max(0.001, data.extension_frame_duration)
	var t := create_tween()
	if trap.is_extended():
		# Extending. Make spikes visible at the first intermediate
		# frame straight away — any delay here feels like input lag.
		spikes_root.visible = true
		_set_trap_sprite_textures(sprites, data.extended_sprite_frame1)
		t.tween_interval(step)
		t.tween_callback(_set_trap_sprite_textures.bind(sprites, data.extended_sprite_frame2))
		t.tween_interval(step)
		t.tween_callback(_set_trap_sprite_textures.bind(sprites, data.extended_sprite))
	else:
		# Retracting. The "fully extended" state has been on-screen for
		# the activation duration already, so we skip showing it again
		# and step straight down through frame2 → frame1 → hidden.
		_set_trap_sprite_textures(sprites, data.extended_sprite_frame2)
		t.tween_interval(step)
		t.tween_callback(_set_trap_sprite_textures.bind(sprites, data.extended_sprite_frame1))
		t.tween_interval(step)
		t.tween_callback(_hide_trap_spikes.bind(spikes_root, sprites, data.extended_sprite))
	entry["tween"] = t

func _set_trap_sprite_textures(sprites: Array, tex: Texture2D) -> void:
	for s in sprites:
		if s is Sprite3D and is_instance_valid(s):
			s.texture = tex

# End-of-retraction callback: hide the spike subtree and reset the
# texture to `extended_sprite` so the next activation builds up from
# a clean baseline (frame1 set explicitly at start, but defensive).
func _hide_trap_spikes(spikes_root: Node3D, sprites: Array, reset_tex: Texture2D) -> void:
	if is_instance_valid(spikes_root):
		spikes_root.visible = false
	_set_trap_sprite_textures(sprites, reset_tex)

# Per-trap "lean toward player" offset for the spike subtree. Mirrors
# the cell-object lean (used by chests) but applies only to the
# spikes — the floor holes stay anchored to the cell centre. Refresh
# is called on player turn (same trigger as `_refresh_object_positions`)
# because the lean axis is tied to facing, not position; refreshing
# on move would visibly snap the spikes mid-step.
func _refresh_trap_spike_positions() -> void:
	if _trap_visuals.is_empty():
		return
	for trap in _trap_visuals.keys():
		var entry: Variant = _trap_visuals.get(trap, null)
		if entry == null:
			continue
		var spikes_root: Node3D = entry["spikes_root"]
		if not is_instance_valid(spikes_root) or trap == null or trap.data == null:
			continue
		spikes_root.position = _trap_spike_offset(trap)

# Cell-relative offset for a trap's spike subtree. Returns Vector3.ZERO
# unless `data.spike_lean_toward_player > 0` AND the player is on a
# cell different from the trap (lean direction tied to whichever
# cardinal axis the player currently faces). Same algorithm as
# `_object_position` but emitting a delta instead of an absolute
# position so the trap root can stay parked at the cell centre.
func _trap_spike_offset(trap: TrapInstance) -> Vector3:
	var data: TrapData = trap.data
	if data.spike_lean_toward_player <= 0.0:
		return Vector3.ZERO
	var diff := _current_grid_pos - trap.cell
	if diff == Vector2i.ZERO:
		# Player is standing on the trap — no axis to lean on,
		# spikes stay centred. Returning early avoids a divide-by-
		# zero-ish branch below.
		return Vector3.ZERO
	var ox: float = 0.0
	var oz: float = 0.0
	var prefer_x: bool = abs(_current_facing.x) > abs(_current_facing.y)
	if prefer_x and diff.x != 0:
		ox = float(signi(diff.x)) * data.spike_lean_toward_player
	elif (not prefer_x) and diff.y != 0:
		oz = float(signi(diff.y)) * data.spike_lean_toward_player
	elif diff.x != 0:
		ox = float(signi(diff.x)) * data.spike_lean_toward_player
	elif diff.y != 0:
		oz = float(signi(diff.y)) * data.spike_lean_toward_player
	return Vector3(ox, 0.0, oz)

func _make_trap_spikes(trap: TrapInstance) -> Dictionary:
	var data: TrapData = trap.data
	if data.holes_sprite == null and data.extended_sprite == null:
		# Nothing to render — likely an asset misconfiguration. Don't
		# emit a node, but warn so the developer notices.
		push_warning("DungeonView: trap '%s' at %s has neither holes_sprite nor extended_sprite — skipped" % [data.name_key, trap.cell])
		return {}
	var cx: float = trap.cell.x * CELL_SIZE + CELL_SIZE * 0.5
	var cz: float = trap.cell.y * CELL_SIZE + CELL_SIZE * 0.5

	var root := Node3D.new()
	root.position = Vector3(cx, 0.0, cz)

	# Spikes subtree — a single Node3D parent toggled visible/hidden
	# in lockstep with `trap.state`. Per-spike billboards inside it
	# parallax against each other at close range. Position is
	# offset by `_trap_spike_offset` so designers can lean the
	# spikes toward the player (just the spikes — the floor holes
	# stay anchored to the cell centre, batched in a separate
	# MultiMeshInstance3D).
	var spikes_root := Node3D.new()
	spikes_root.name = "Spikes"
	spikes_root.visible = trap.is_extended()
	spikes_root.position = _trap_spike_offset(trap)
	# Collected so `update_trap_visual` can swap the texture on every
	# spike billboard in lockstep when the animation frames are set.
	# Required because the FIXED_Y billboard rules out a MultiMesh
	# approach, so each spike is its own Sprite3D node.
	var sprites: Array = []
	if data.extended_sprite != null:
		var positions := _trap_grid_positions_local(data)
		var tex: Texture2D = data.extended_sprite
		var tex_w: int = max(1, tex.get_width())
		var tex_h: int = max(1, tex.get_height())
		var pixel_size: float = data.world_height / float(tex_h)
		var spike_y: float = data.world_height * 0.5 + data.y_offset
		# Force a horizontal stretch via scale.x when the designer wants
		# the spike base wider/narrower than its texture's natural aspect
		# (e.g. matching `hole_world_size` so each spike fills its hole).
		# Mirrors the door's world_width pattern.
		var x_scale: float = 1.0
		if data.spike_world_width > 0.0:
			var natural_world_width: float = float(tex_w) * pixel_size
			if natural_world_width > 0.0:
				x_scale = data.spike_world_width / natural_world_width
		for offset: Vector3 in positions:
			var sprite := Sprite3D.new()
			sprite.texture = tex
			sprite.pixel_size = pixel_size
			sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			sprite.position = Vector3(offset.x, spike_y, offset.z)
			if x_scale != 1.0:
				sprite.scale = Vector3(x_scale, 1.0, 1.0)
			spikes_root.add_child(sprite)
			sprites.append(sprite)
	root.add_child(spikes_root)

	# Note: TIMED trap activate / deactivate audio used to live on a
	# per-trap AudioStreamPlayer3D here, but Godot 4's spatial audio
	# inside a SubViewport gave us inconsistent listener routing —
	# sounds often went silent. Game.gd now plays trap sounds through
	# SoundManager (non-spatial) with a manual distance gate against
	# `hearing_distance`. Drops the smooth distance falloff curve in
	# exchange for reliability; revisit in Phase 19 when audio gets
	# the dedicated polish pass.

	return {
		"root": root,
		"spikes_root": spikes_root,
		"sprites": sprites,
		"tween": null,
	}

# Append the per-decal world transforms for THIS trap into the shared
# decal bucket (keyed by holes_sprite Texture2D). Each transform
# encodes: (a) the trap's world position, (b) the per-slot offset from
# the cell centre, (c) a -90° X rotation to lay the quad flat, and
# (d) a hole_world_size scale on the quad's local X/Y axes.
func _gather_trap_decal_transforms(trap: TrapInstance, decals_by_texture: Dictionary) -> void:
	var data: TrapData = trap.data
	if data.holes_sprite == null:
		return
	if not decals_by_texture.has(data.holes_sprite):
		decals_by_texture[data.holes_sprite] = []
	var positions := _trap_grid_positions_local(data)
	var hole_size: float = data.hole_world_size if data.hole_world_size > 0.0 else _natural_hole_world_size(data.holes_sprite, data, positions.size())
	var cx: float = trap.cell.x * CELL_SIZE + CELL_SIZE * 0.5
	var cz: float = trap.cell.y * CELL_SIZE + CELL_SIZE * 0.5
	# Rotate -90° around X so a quad authored on the XY plane lies flat
	# on the XZ floor plane. Scale on (local) X / Y to set the per-tile
	# size; the post-rotation Z scale is irrelevant for a planar quad.
	var basis_template := Basis(Vector3(1.0, 0.0, 0.0), -PI * 0.5).scaled(Vector3(hole_size, hole_size, 1.0))
	var bucket: Array = decals_by_texture[data.holes_sprite]
	for offset: Vector3 in positions:
		bucket.append(Transform3D(basis_template, Vector3(cx + offset.x, 0.01, cz + offset.z)))

# Build one MultiMeshInstance3D that renders every decal sharing a
# given holes_sprite. The MultiMesh's mesh is a unit QuadMesh — the
# per-instance transform's scale handles the actual hole size, so a
# single shared mesh resource serves all variants. Material is the
# same alpha-scissor StandardMaterial3D the per-cell decals used to
# build individually (still cached in `_trap_floor_material_cache`).
func _make_trap_decal_multimesh(tex: Texture2D, transforms: Array) -> MultiMeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = false
	mm.use_custom_data = false
	mm.mesh = quad
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _build_trap_floor_material(tex)
	return mmi

# Build the world-space XZ offsets (Y = 0) for one cell's spike+hole
# grid. Designer-controlled via `grid_cols / grid_rows / grid_inset`.
# Inset 0 = touches cell edges; 0.5 = bunched at centre. Positions
# distribute evenly: with cols=1 the column centres on 0; with
# cols=2 they sit symmetrically around 0; with cols=3 they're at
# -k, 0, +k; etc.
func _trap_grid_positions_local(data: TrapData) -> Array:
	var cols: int = max(1, data.grid_cols)
	var rows: int = max(1, data.grid_rows)
	var inset: float = clamp(data.grid_inset, 0.0, 0.5)
	# Span = cell minus inset on both sides. Each axis range goes from
	# (-span/2) to (+span/2) inclusive when count > 1; centred at 0
	# when count == 1.
	var span: float = CELL_SIZE * (1.0 - inset * 2.0)
	var result: Array = []
	for r in range(rows):
		var rt: float = 0.0 if rows == 1 else float(r) / float(rows - 1) - 0.5
		var rz: float = rt * span
		for c in range(cols):
			var ct: float = 0.0 if cols == 1 else float(c) / float(cols - 1) - 0.5
			var cxr: float = ct * span
			result.append(Vector3(cxr, 0.0, rz))
	return result

func _natural_hole_world_size(_tex: Texture2D, data: TrapData, slot_count: int) -> float:
	# Fallback when the designer leaves hole_world_size at 0. Sizes
	# the hole so a 2×2 grid roughly fills the cell — good default.
	# Larger grids shrink each tile; smaller grids leave breathing
	# room.
	var per_axis: int = max(1, int(round(sqrt(float(slot_count)))))
	var span: float = CELL_SIZE * (1.0 - clamp(data.grid_inset, 0.0, 0.5) * 2.0)
	var size_estimate: float = span / float(max(1, per_axis))
	if size_estimate <= 0.0:
		return 1.0
	return size_estimate

func _build_trap_floor_material(albedo: Texture2D) -> StandardMaterial3D:
	# Cached on the texture so multiple traps sharing the same
	# holes_sprite share one material (same trick as biome textures).
	if _trap_floor_material_cache.has(albedo):
		return _trap_floor_material_cache[albedo]
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = albedo
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# The floor mesh below uses triplanar mapping; the trap decal is
	# UV-mapped so the hole stays sharp regardless of cell position.
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	_trap_floor_material_cache[albedo] = mat
	return mat

# -------------------------------------------------------
# Spinners (Phase 8 Task 8)
# -------------------------------------------------------
#
# Each spinner renders as a single flat `MeshInstance3D` quad lying
# horizontal on the floor (Y = data.y_offset, default 0.01 to dodge
# Z-fighting with the floor plane), textured with `data.decal_sprite`
# through the same alpha-scissor material cache spike traps use.
#
# The decal continuously rotates around its Y axis at
# `data.visual_rotation_degrees_per_second` so the spinner is
# self-advertising — players learn to read "swirling tile = spin
# hazard". Rotation is advanced per frame in `_update_spinner_rotations`
# so it pauses automatically when the SceneTree pauses (map popup,
# etc.) — a looped tween would NOT pause cleanly in that case.

func _build_spinners() -> void:
	for child in _spinners_root.get_children():
		child.queue_free()
	_spinner_visuals.clear()
	if generator == null:
		return
	for spinner in generator.spinners:
		if spinner == null or spinner.data == null:
			continue
		var decal := _make_spinner_decal(spinner)
		if decal == null:
			continue
		_spinners_root.add_child(decal)
		_spinner_visuals[spinner] = decal

func rebuild_spinners() -> void:
	if _spinners_root == null:
		return
	_build_spinners()

# Builds a Node3D root parked at the spinner cell with the flat decal
# as a child. Per-frame rotation animates the ROOT's Y so the world
# Y-axis rotation is unambiguous — rotating the decal mesh directly
# would entangle with its -90° X tilt and read as a tilt-wobble.
# Returns null when the spinner has no decal_sprite (a valid
# "invisible" configuration: the player only feels the spin).
func _make_spinner_decal(spinner: SpinnerInstance) -> Node3D:
	var data: SpinnerData = spinner.data
	if data.decal_sprite == null:
		return null
	var root := Node3D.new()
	var cx: float = spinner.cell.x * CELL_SIZE + CELL_SIZE * 0.5
	var cz: float = spinner.cell.y * CELL_SIZE + CELL_SIZE * 0.5
	root.position = Vector3(cx, data.y_offset, cz)
	var mesh := MeshInstance3D.new()
	var quad := QuadMesh.new()
	var s: float = max(0.01, data.decal_world_size) * CELL_SIZE
	quad.size = Vector2(s, s)
	mesh.mesh = quad
	mesh.material_override = _build_trap_floor_material(data.decal_sprite)
	# Decal authored on the XY plane — lay it flat onto XZ.
	mesh.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	root.add_child(mesh)
	return root

# Sets each spinner root's Y rotation to an angle DERIVED FROM CLOCK
# TIME (not accumulated from delta). Direction sign matches the
# instance's resolved direction so a clockwise spinner decal visually
# spins clockwise when viewed from above (Godot's right-hand
# convention: looking down -Y, positive Y rotation is counter-
# clockwise — hence the negation for CLOCKWISE).
#
# Time-based rather than delta-accumulated so `visual_frame_count > 0`
# can quantize cleanly: a stepped spinner snaps to N equally-spaced
# angles per full revolution. Accumulating delta then snapping would
# drift toward the same pose on every tick (the snap would feed back
# into the next frame's accumulator); deriving from absolute time
# means the underlying angle keeps growing and the snap just lags by
# at most one step.
func _update_spinner_rotations(_delta: float) -> void:
	if _spinner_visuals.is_empty():
		return
	var t: float = Time.get_ticks_msec() / 1000.0
	for spinner in _spinner_visuals.keys():
		var root: Node3D = _spinner_visuals[spinner]
		if not is_instance_valid(root) or spinner == null or spinner.data == null:
			continue
		var rate: float = spinner.data.visual_rotation_degrees_per_second
		if rate == 0.0:
			continue
		var dir_sign: float = -1.0 if spinner.is_clockwise() else 1.0
		var angle: float = deg_to_rad(rate * dir_sign) * t
		var frame_count: int = spinner.data.visual_frame_count
		if frame_count > 0:
			# Quantize to N equally-spaced angles per full revolution
			# ("spritesheet" look). `floor` snaps to the most recent
			# frame in whichever direction time is flowing (dir_sign
			# baked into the angle already), so the visual ticks
			# forward in lockstep with rotation direction.
			var step_size: float = TAU / float(frame_count)
			angle = floor(angle / step_size) * step_size
		root.rotation.y = fmod(angle, TAU)

# Phase 15 Task 6 — teleporter rendering. Each TeleporterInstance has
# TWO endpoints; we render BOTH as identical-looking UPRIGHT Sprite3D
# billboards (BILLBOARD_FIXED_Y — rotates around Y to face the camera,
# stays vertical like chests / levers). Visuals are keyed by endpoint
# cell (Vector2i) in `_teleporter_visuals`, not by instance — Game.gd
# triggers the warp from the player's current cell, so a cell-keyed
# lookup is the natural fit. Static `data.sprite` is the V1 path;
# `data.frames` opts into an `AnimatedSprite3D` auto-playing
# `default_animation` for designers who want animated rune circles.
func _build_teleporters() -> void:
	for child in _teleporters_root.get_children():
		child.queue_free()
	_teleporter_visuals.clear()
	if generator == null:
		return
	for inst in generator.teleporters:
		if inst == null or inst.data == null:
			continue
		for endpoint in inst.endpoints():
			var entry := _make_teleporter_visual(inst, endpoint)
			if entry.is_empty():
				continue
			_teleporters_root.add_child(entry["root"])
			_teleporter_visuals[endpoint] = entry

func rebuild_teleporters() -> void:
	if _teleporters_root == null:
		return
	_build_teleporters()

# Returns a dict (or empty dict on "skip render") with:
#   {root, sprite_node, light, data, pulse_phase, base_glow,
#    base_alpha, base_light_energy}
# Returns {} when the data has no sprite/frames AND no light —
# designers can ship a "ghost" teleporter (the warp still fires
# because it's keyed off `cell.teleporter`, not the visual), but a
# fully-empty Node3D would be wasted scene-tree weight.
#
# Sprite anchoring matches the chest / lever pattern:
#   - `BILLBOARD_FIXED_Y` keeps the sprite upright as the camera turns
#   - `pixel_size = world_height / texture_height` decouples world
#     size from source-art resolution
#   - position Y = `world_height * 0.5 + y_offset` so the sprite's
#     BOTTOM sits at floor level (Y=0); `y_offset` nudges it up for
#     art with transparent padding at the bottom
#   - `lean_toward_player` shifts the WHOLE ROOT horizontally toward
#     the player (refreshed on turn, NOT on movement — same rule the
#     chest lean uses to avoid mid-step snapping)
func _make_teleporter_visual(inst: TeleporterInstance, endpoint: Vector2i) -> Dictionary:
	var data: TeleporterData = inst.data
	var has_sprite: bool = data.sprite != null
	var has_frames: bool = data.frames != null
	var has_visual: bool = has_sprite or has_frames
	var has_light: bool = data.light_energy > 0.0
	if not has_visual and not has_light:
		return {}
	var root := Node3D.new()
	root.position = _teleporter_position(endpoint, data)
	var sprite_node: SpriteBase3D = null
	if has_visual:
		var tex_h: int = 1
		if has_frames:
			# Animated path — AnimatedSprite3D auto-plays
			# `default_animation` so designers don't need wiring code.
			var anim := AnimatedSprite3D.new()
			anim.sprite_frames = data.frames
			anim.animation = &"default_animation"
			anim.play()
			# Derive pixel_size from the FIRST frame's texture height
			# — assumes frames share dimensions (the convention for
			# AnimatedSprite3D + SpriteFrames).
			var first_anim: StringName = &"default_animation"
			if data.frames.has_animation(first_anim) and data.frames.get_frame_count(first_anim) > 0:
				var first_tex: Texture2D = data.frames.get_frame_texture(first_anim, 0)
				if first_tex != null:
					tex_h = max(1, first_tex.get_height())
			sprite_node = anim
		else:
			var sprite := Sprite3D.new()
			sprite.texture = data.sprite
			tex_h = max(1, data.sprite.get_height())
			sprite_node = sprite
		sprite_node.pixel_size = data.world_height / float(tex_h)
		sprite_node.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite_node.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		# ALPHA_CUT_OPAQUE_PREPASS rather than ALPHA_CUT_DISCARD: the
		# prepass mode keeps the texture's transparent BACKGROUND
		# crisply cut while letting the opaque pixels render at any
		# `modulate.a` (DISCARD would drop sub-threshold pixels and a
		# user setting alpha = 0.3 would see an invisible sprite).
		sprite_node.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
		# Phase 15 Task 6 — transparency + glow knobs. `modulate`
		# multiplies the texture per RGBA channel. The PULSE update
		# (`_update_teleporter_pulse`) rewrites this every frame; we
		# set the BASE value here so the first frame renders cleanly
		# even before _process kicks in.
		var glow: float = max(0.0, data.glow_multiplier)
		var modulate_alpha: float = clampf(data.alpha, 0.0, 1.0)
		sprite_node.modulate = Color(glow, glow, glow, modulate_alpha)
		# Anchor the sprite BOTTOM at floor level so it visually sits
		# on the ground. y_offset nudges upward for transparent-padding
		# compensation.
		sprite_node.position = Vector3(0.0, data.world_height * 0.5 + data.y_offset, 0.0)
		root.add_child(sprite_node)
	var light: OmniLight3D = null
	if has_light:
		light = OmniLight3D.new()
		light.light_color = data.light_color
		light.light_energy = data.light_energy
		light.omni_range = max(0.01, data.light_range)
		# Light at the sprite's mid-height so the glow appears to come
		# from the rune circle itself, not from the floor underneath.
		var light_y: float = data.world_height * 0.5 if has_visual else 0.5
		light.position = Vector3(0.0, light_y, 0.0)
		root.add_child(light)
	# Pulse state — both endpoints of a pair share `pair_index`, so
	# they pulse in sync; consecutive pairs are offset by
	# `pulse_phase_per_pair` radians so they feel independent.
	var pulse_phase: float = float(inst.pair_index) * data.pulse_phase_per_pair
	return {
		"root": root,
		"sprite_node": sprite_node,
		"light": light,
		"data": data,
		"pulse_phase": pulse_phase,
		"base_glow": data.glow_multiplier,
		"base_alpha": data.alpha,
		"base_light_energy": data.light_energy,
	}

# Returns the world position of a teleporter endpoint, accounting for
# `lean_toward_player`. Mirrors `_object_position` for chests — the
# lean axis follows the player's facing (turning is what switches the
# lean axis; strafing one tile sideways stays on the same axis so the
# rune doesn't flip mid-strafe).
func _teleporter_position(endpoint: Vector2i, data: TeleporterData) -> Vector3:
	var cx: float = endpoint.x * CELL_SIZE + CELL_SIZE * 0.5
	var cz: float = endpoint.y * CELL_SIZE + CELL_SIZE * 0.5
	var ox: float = 0.0
	var oz: float = 0.0
	if data.lean_toward_player > 0.0:
		var diff := _current_grid_pos - endpoint
		var prefer_x: bool = abs(_current_facing.x) > abs(_current_facing.y)
		if prefer_x and diff.x != 0:
			ox = float(signi(diff.x)) * data.lean_toward_player
		elif (not prefer_x) and diff.y != 0:
			oz = float(signi(diff.y)) * data.lean_toward_player
		elif diff.x != 0:
			ox = float(signi(diff.x)) * data.lean_toward_player
		elif diff.y != 0:
			oz = float(signi(diff.y)) * data.lean_toward_player
	return Vector3(cx + ox, 0.0, cz + oz)

# Refresh every teleporter root's position so the lean-toward-player
# offset tracks the current facing. Called on player turn (NOT on
# movement — same rule the chest lean uses to avoid mid-step snapping).
# Cheap O(n) over a typical 1–2 placed teleporter pairs.
func _refresh_teleporter_positions() -> void:
	for endpoint in _teleporter_visuals.keys():
		var entry: Dictionary = _teleporter_visuals[endpoint]
		var root: Node3D = entry.get("root", null)
		if not is_instance_valid(root):
			continue
		var data: TeleporterData = entry.get("data", null)
		if data == null:
			continue
		root.position = _teleporter_position(endpoint, data)

# Per-frame pulse driver. Modulates each teleporter's sprite color +
# alpha + light energy along a sine wave so the rune reads as a living
# energy ball, breathing in and out. The same phase is shared between
# both endpoints of a pair (so a single warp pair pulses as one
# creature) but offset between pairs (so two pairs in view don't pulse
# in lockstep).
func _update_teleporter_pulse(_delta: float) -> void:
	if _teleporter_visuals.is_empty():
		return
	var t: float = Time.get_ticks_msec() / 1000.0
	for endpoint in _teleporter_visuals.keys():
		var entry: Dictionary = _teleporter_visuals[endpoint]
		var data: TeleporterData = entry.get("data", null)
		if data == null:
			continue
		# Static (no pulse) — both knobs collapse to a no-op. The
		# sprite + light already carry the base values from _build.
		if data.pulse_amount <= 0.0 or data.pulse_speed <= 0.0:
			continue
		var phase: float = entry.get("pulse_phase", 0.0)
		# Phase-quantize for the stepped "spritesheet" look when
		# `pulse_frame_count > 0`: snap the phase to N equally-spaced
		# samples per full cycle BEFORE evaluating sine. Each frame
		# then holds for an equal duration (uniform-time playback,
		# like a real spritesheet) and the brightness levels are
		# `sin(2π·i/N)` for i in [0, N) — uneven in value (the sine
		# clusters near ±1 at the peaks) but even in time. Quantizing
		# the sine OUTPUT instead would give uniform brightness levels
		# but uneven dwell time, which reads less like a spritesheet.
		var phase_total: float = t * data.pulse_speed + phase
		var frame_count: int = data.pulse_frame_count
		if frame_count > 0:
			var step_size: float = TAU / float(frame_count)
			phase_total = floor(phase_total / step_size) * step_size
		# sine in [-1, 1], scaled by pulse_amount into [-amount, amount],
		# centred on 1.0 so the multiplier swings between
		# (1 - amount) and (1 + amount).
		var swing: float = sin(phase_total) * data.pulse_amount
		var multiplier: float = 1.0 + swing
		var sprite_node: SpriteBase3D = entry.get("sprite_node", null)
		if is_instance_valid(sprite_node):
			var base_glow: float = entry.get("base_glow", 1.0)
			var base_alpha: float = entry.get("base_alpha", 1.0)
			var g: float = max(0.0, base_glow * multiplier)
			# Alpha also breathes — slightly transparent at the dim
			# end of the cycle reads as "the energy is gathering /
			# dissipating", not just "the brightness is changing".
			var a: float = clampf(base_alpha * multiplier, 0.0, 1.0)
			sprite_node.modulate = Color(g, g, g, a)
		var light: OmniLight3D = entry.get("light", null)
		if is_instance_valid(light):
			var base_energy: float = entry.get("base_light_energy", 1.0)
			light.light_energy = max(0.0, base_energy * multiplier)

func _build_wall_decorations() -> void:
	_billboard_decorations.clear()
	_flickering_lights.clear()
	for child in _decorations_root.get_children():
		child.queue_free()
	if generator == null:
		return
	for inst in generator.wall_decorations:
		if inst == null or inst.data == null:
			continue
		var node := _make_wall_decoration_node(inst)
		if node != null:
			_decorations_root.add_child(node)

# Extends floor geometry under filler sprites and out across the
# `outdoor_floor_extent` border ring. Without this pass, outdoor
# biomes only have floor under FLOOR cells (the walkable area),
# so trees appear to float on the sky background — broken depth
# cue. With it, the player sees ground stretching out beneath the
# trees and fog smoothly hides the edge.
#
# Texture pool: `biome.filler_floor_textures` if non-empty, else
# `biome.floor_textures`. Same `BiomeTextureEntry` picker the main
# mesh uses (deterministic position-hash, supports weights and
# min_distance_to_same), with a fresh placement history so under-
# filler choices don't fight the walkable-floor history for
# variety distribution.
#
# Indoor biomes early-out — the function is a no-op when
# `outdoor_mode = false`.
func _build_outdoor_floors() -> void:
	if biome == null or not biome.outdoor_mode:
		return
	var pool: Array[BiomeTextureEntry] = biome.filler_floor_textures
	if pool.is_empty():
		pool = biome.floor_textures
	if pool.is_empty():
		return
	var extent: int = max(0, biome.outdoor_floor_extent)
	# Local history so this pass picks variety independently from
	# the walkable-floor pass — they conceptually represent two
	# different surfaces (path vs. undergrowth) even when they
	# share a texture pool by default.
	var history: Dictionary = {}
	for x in range(-extent, generator.grid_width + extent):
		for y in range(-extent, generator.grid_height + extent):
			var pos := Vector2i(x, y)
			# Skip cells that already have a floor quad from the
			# main `_build_mesh` pass (FLOOR / ENTRANCE / EXIT).
			# Out-of-grid cells fall through.
			if pos.x >= 0 and pos.x < generator.grid_width \
					and pos.y >= 0 and pos.y < generator.grid_height:
				var cell = generator.get_cell(pos.x, pos.y)
				if cell != null and cell.cell_type != GridCell.CellType.WALL:
					continue
			var entry: BiomeTextureEntry = BiomeTextureEntry.pick_for(
				pool, ObjectSpawn.PLACEMENT_CORRIDOR, pos, history)
			if entry == null:
				continue
			_record_history(history, entry, pos)
			var cx = x * CELL_SIZE + CELL_SIZE * 0.5
			var cy = y * CELL_SIZE + CELL_SIZE * 0.5
			_add_horizontal_quad(Vector3(cx, 0.0, cy), _material_for_entry(entry))

# Outdoor-mode filler sprites (trees / rocks / bushes). Iterates
# `generator.fillers` and creates one Sprite3D per entry, parented
# under `_fillers_root`. No-op when the list is empty (every indoor
# biome) — no need to early-out on `outdoor_mode` here, the placer
# already short-circuited.
#
# Sprites use BILLBOARD_FIXED_Y so trees stay vertical but always face
# the camera horizontally — that's what makes a flat tree silhouette
# read as a cylinder rather than a card. No lean (decorations stay
# centred per CLAUDE.md's billboard rules) and no per-frame update
# (the billboard mode does the work in the shader).
func _build_fillers() -> void:
	for child in _fillers_root.get_children():
		child.queue_free()
	if generator == null:
		return
	for inst in generator.fillers:
		if inst == null or inst.data == null or inst.data.texture == null:
			continue
		var sprite := _make_filler_sprite(inst)
		if sprite != null:
			_fillers_root.add_child(sprite)

# Walkable-area scenery (trees, flowers, mushrooms). Mirrors
# `_build_objects` for chests but without the Area3D — scenery is
# never clickable, never interactive. Non-walkable scenery still
# blocks movement (the player can never step onto a tree cell) — that
# rule is enforced on the model side via `GridCell.is_blocked`, not
# here. Each `SceneryInstance` produces ONE Sprite3D; cells with
# density > 1 produce N instances + N sprites, each with its own
# sub-cell jitter offset and per-sprite scale.
func _build_scenery() -> void:
	for child in _scenery_root.get_children():
		child.queue_free()
	_scenery_sprites.clear()
	if generator == null:
		return
	for inst in generator.scenery:
		if inst == null or inst.data == null or inst.data.texture == null:
			continue
		var data: SceneryData = inst.data
		var sprite := Sprite3D.new()
		sprite.texture = data.texture
		var tex_h: int = max(1, data.texture.get_height())
		# pixel_size is derived from the SCALED world height so per-
		# sprite scale variance (subtle "this tree is a bit smaller")
		# changes the on-screen size without re-importing the texture.
		var effective_height: float = data.world_height * inst.scale
		sprite.pixel_size = effective_height / float(tex_h)
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.position = _scenery_position(inst)
		_scenery_root.add_child(sprite)
		_scenery_sprites[inst] = sprite

func _scenery_position(inst: SceneryInstance) -> Vector3:
	# Cell-centred position + per-sprite sub-cell jitter + optional
	# player-facing lean (same rule as `_object_position` for chests —
	# shift the sprite toward whichever cardinal side the player is
	# currently on so the tree reads as a solid object rather than a
	# flat cluster). Walkable scenery typically leaves
	# `lean_toward_player` at 0 (a flower centred in its cell is fine).
	# The sub-cell jitter is applied ON TOP of the lean so a cluster of
	# trees in one cell all lean together but stay scattered.
	var data: SceneryData = inst.data
	var grid_pos: Vector2i = inst.cell
	var cx: float = grid_pos.x * CELL_SIZE + CELL_SIZE * 0.5
	var cz: float = grid_pos.y * CELL_SIZE + CELL_SIZE * 0.5
	var ox: float = 0.0
	var oz: float = 0.0
	if data.lean_toward_player > 0.0:
		var diff := _current_grid_pos - grid_pos
		var prefer_x: bool = abs(_current_facing.x) > abs(_current_facing.y)
		if prefer_x and diff.x != 0:
			ox = float(signi(diff.x)) * data.lean_toward_player
		elif (not prefer_x) and diff.y != 0:
			oz = float(signi(diff.y)) * data.lean_toward_player
		elif diff.x != 0:
			ox = float(signi(diff.x)) * data.lean_toward_player
		elif diff.y != 0:
			oz = float(signi(diff.y)) * data.lean_toward_player
	# Sub-cell jitter (fractions of CELL_SIZE) — applied AFTER the
	# lean so a cluster scatters around the leaned anchor.
	var jx: float = inst.cell_offset.x * CELL_SIZE
	var jz: float = inst.cell_offset.y * CELL_SIZE
	var effective_height: float = data.world_height * inst.scale
	return Vector3(cx + ox + jx, effective_height * 0.5 + data.y_offset, cz + oz + jz)

func _refresh_scenery_positions() -> void:
	# Cheap per-turn update — only sprites whose data has a non-zero
	# lean actually need new positions, but iterating the dict is
	# trivial so we just touch them all.
	for inst in _scenery_sprites.keys():
		var sprite: Sprite3D = _scenery_sprites[inst]
		if not is_instance_valid(sprite) or inst == null or inst.data == null:
			continue
		sprite.position = _scenery_position(inst)

func _make_filler_sprite(inst: FillerInstance) -> Sprite3D:
	var data: FillerData = inst.data
	var tex_h: int = data.texture.get_height()
	if tex_h <= 0:
		tex_h = 1
	# Effective real-world height after the per-instance scale; the
	# sprite's bottom sits at y=0 so we raise the centre by half of
	# that, then nudge by the data's y_offset (lets designers push the
	# sprite into the ground if the PNG has trunk padding below).
	var effective_height: float = data.world_height * inst.scale
	var sprite := Sprite3D.new()
	sprite.texture = data.texture
	sprite.pixel_size = effective_height / float(tex_h)
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	# Convert grid cell + sub-cell offset to world coords here (the
	# generator stays grid-space). cell_offset is in fractions of
	# CELL_SIZE so each component multiplies up to ±half a cell.
	var wx: float = (float(inst.cell.x) + 0.5 + inst.cell_offset.x) * CELL_SIZE
	var wz: float = (float(inst.cell.y) + 0.5 + inst.cell_offset.y) * CELL_SIZE
	var wy: float = effective_height * 0.5 + data.y_offset
	sprite.position = Vector3(wx, wy, wz)
	return sprite

func _process(delta: float) -> void:
	_update_billboard_decorations()
	_update_flickering_lights()
	_update_spinner_rotations(delta)
	_update_teleporter_pulse(delta)

func _update_billboard_decorations() -> void:
	# Per-frame Y-billboard with X-tilt for face_camera decorations.
	# Each root sits at the BOTTOM of its sprite (anchored to the wall),
	# so this basis rotates the sprite around the wall-attached base —
	# the bottom never moves, only the top swings.
	if camera == null or _billboard_decorations.is_empty():
		return
	var cam_pos: Vector3 = camera.global_position
	for root in _billboard_decorations:
		if not is_instance_valid(root):
			continue
		var dx: float = cam_pos.x - root.global_position.x
		var dz: float = cam_pos.z - root.global_position.z
		if dx * dx + dz * dz < 0.0001:
			continue
		var y_angle: float = atan2(dx, dz)
		var x_tilt: float = root.get_meta("billboard_tilt", 0.0)
		# Y rotation (face camera) THEN X tilt — composition order
		# matters: applying X first puts the lean in the local frame
		# after the Y face-camera rotation, so the top tilts toward
		# the camera regardless of where the camera is.
		root.basis = Basis(Vector3.UP, y_angle) * Basis(Vector3.RIGHT, x_tilt)

func _update_flickering_lights() -> void:
	# Cheap multi-octave sine produces a fire-like wobble: three
	# non-commensurate frequencies summed and normalised to roughly
	# [-1, 1]. Per-light phase decorrelates the array so torches
	# never flicker in unison.
	if _flickering_lights.is_empty():
		return
	var t: float = float(Time.get_ticks_msec()) / 1000.0
	for light in _flickering_lights:
		if not is_instance_valid(light):
			continue
		var base: float = light.get_meta("flicker_base_energy", 1.0)
		var amount: float = light.get_meta("flicker_amount", 0.0)
		var phase: float = light.get_meta("flicker_phase", 0.0)
		var n: float = sin(t * 17.0 + phase) * 0.5 \
			+ sin(t * 31.0 + phase * 1.7) * 0.3 \
			+ sin(t * 7.0 + phase * 2.3) * 0.2
		light.light_energy = base * (1.0 + n * amount)

func _make_wall_decoration_node(inst: WallDecorationInstance) -> Node3D:
	var data: WallDecorationData = inst.data
	var sprite := _make_wall_decoration_sprite(data)
	if sprite == null:
		return null

	var root := Node3D.new()
	root.position = _wall_decoration_position(inst)
	if data.face_camera:
		# Sprite extends UP from root (= bottom of decoration). Per-frame
		# basis update in `_update_billboard_decorations` rotates the
		# root to face the camera + tilt top toward camera. The bottom
		# stays pinned to root (= wall surface) under any rotation.
		sprite.position = Vector3(0.0, data.world_height * 0.5, 0.0)
		root.set_meta("billboard_tilt", deg_to_rad(data.top_tilt_degrees))
		_billboard_decorations.append(root)
	else:
		root.rotation_degrees = Vector3(0.0, _wall_decoration_y_rotation_deg(inst), 0.0)
	root.add_child(sprite)

	if data.light_energy > 0.0:
		var light := OmniLight3D.new()
		light.light_color = data.light_color
		light.light_energy = data.light_energy
		light.omni_range = data.light_range
		# Position is relative to the sprite's CENTRE in both modes so
		# `light_y_offset` is portable between flat and face_camera.
		var sprite_centre_y_local: float = data.world_height * 0.5 if data.face_camera else 0.0
		light.position = Vector3(0.0, sprite_centre_y_local + data.light_y_offset, 0.0)
		root.add_child(light)
		if data.light_flicker_amount > 0.0:
			light.set_meta("flicker_base_energy", data.light_energy)
			light.set_meta("flicker_amount", data.light_flicker_amount)
			light.set_meta("flicker_phase", randf_range(0.0, TAU))
			_flickering_lights.append(light)

	return root

func _make_wall_decoration_sprite(data: WallDecorationData) -> SpriteBase3D:
	# Picks AnimatedSprite3D for animated decorations (torches), Sprite3D
	# for static ones (paintings). Same anchoring + scaling logic for
	# both — the caller positions / rotates the returned node.
	var sprite: SpriteBase3D = null
	var tex_h: int = 0
	if data.is_animated():
		var animated := AnimatedSprite3D.new()
		animated.sprite_frames = data.frames
		var anim_name: String = data.default_animation
		if anim_name == "" or not data.frames.has_animation(anim_name):
			anim_name = data.frames.get_animation_names()[0] if data.frames.get_animation_names().size() > 0 else ""
		if anim_name != "":
			animated.animation = anim_name
			animated.play(anim_name)
			var first_frame: Texture2D = data.frames.get_frame_texture(anim_name, 0)
			if first_frame != null:
				tex_h = first_frame.get_height()
		sprite = animated
	else:
		if data.texture == null:
			return null
		var s := Sprite3D.new()
		s.texture = data.texture
		tex_h = data.texture.get_height()
		sprite = s
	if tex_h <= 0:
		tex_h = 1
	sprite.pixel_size = data.world_height / float(tex_h)
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	return sprite

func _wall_decoration_position(inst: WallDecorationInstance) -> Vector3:
	# Cell centre, then shift by half a cell in `wall_dir` to land on the
	# wall face, then pull back into the corridor by `depth_offset` so
	# the sprite doesn't Z-fight the wall texture beneath.
	#
	# Y placement differs by mode. Flat: root sits at the visual centre
	# of the decoration. Face-camera: root sits at the BOTTOM (so the
	# X-axis tilt rotates around the wall-attached base). Both modes
	# end up with the decoration's centre at the same height
	# (wall_height/2 + y_offset), which keeps `y_offset` semantically
	# stable when designers flip the flag.
	var cx: float = inst.cell.x * CELL_SIZE + CELL_SIZE * 0.5
	var cz: float = inst.cell.y * CELL_SIZE + CELL_SIZE * 0.5
	var face_x: float = cx + float(inst.wall_dir.x) * CELL_SIZE * 0.5
	var face_z: float = cz + float(inst.wall_dir.y) * CELL_SIZE * 0.5
	var pulled_x: float = face_x - float(inst.wall_dir.x) * inst.data.depth_offset
	var pulled_z: float = face_z - float(inst.wall_dir.y) * inst.data.depth_offset
	var y_centre: float = wall_height * 0.5 + inst.data.y_offset
	if inst.data.face_camera:
		return Vector3(pulled_x, y_centre - inst.data.world_height * 0.5, pulled_z)
	return Vector3(pulled_x, y_centre, pulled_z)

func _wall_decoration_y_rotation_deg(inst: WallDecorationInstance) -> float:
	# Match the wall mesh's own y_rotation so the decoration sits flush
	# with the wall and faces the same way (visible side toward the
	# corridor). Mapping mirrors `_build_mesh`'s wall_offsets table.
	if inst.wall_dir == Vector2i(0, -1):  # north wall
		return 0.0
	if inst.wall_dir == Vector2i(0, 1):   # south wall
		return 180.0
	if inst.wall_dir == Vector2i(-1, 0):  # west wall
		return 90.0
	if inst.wall_dir == Vector2i(1, 0):   # east wall
		return 270.0
	return 0.0

# Phase 8 Task 3 — Subtask C1: static launcher rendering. Each launcher
# is a single Sprite3D anchored at the wall-face midpoint, Y-rotated to
# face into the corridor. Subtask C4 adds a floor-decal MeshInstance3D
# at the linked plate cell (only PRESSURE_PLATE traps get one — TIMED
# traps have no plate, `plate_cell == NO_PLATE`).
func _build_projectile_traps() -> void:
	for child in _projectile_traps_root.get_children():
		child.queue_free()
	# Plate visuals are children of `_projectile_traps_root`, so the
	# `queue_free` loop above already detached them — but the
	# dictionaries hold stale RefCounted keys → freed-Node values.
	# Reset both here so the next iteration starts clean.
	_plate_visuals.clear()
	_plate_triggered_state.clear()
	if generator == null:
		return
	for inst in generator.projectile_traps:
		if inst == null or inst.data == null:
			continue
		var node := _make_projectile_trap_node(inst)
		if node != null:
			_projectile_traps_root.add_child(node)
		# Plate decal (Subtask C4) — only for PRESSURE_PLATE traps that
		# the placer assigned a valid plate cell AND have at least an
		# idle texture. Lives under the same root as the launcher so a
		# level rebuild frees both together.
		if inst.has_plate() and inst.data.plate_texture_idle != null:
			var plate_entry := _make_plate_decal_node(inst)
			if not plate_entry.is_empty():
				_projectile_traps_root.add_child(plate_entry["root"])
				_plate_visuals[inst] = plate_entry
				_plate_triggered_state[inst] = false
	# Initial trigger states reflect the camera's current grid pos
	# (the player may already be on a plate when the level builds).
	_update_plate_visual_states()

func _make_projectile_trap_node(inst: ProjectileTrapInstance) -> Node3D:
	var data: ProjectileTrapData = inst.data
	if data.launcher_texture == null:
		return null
	var sprite := Sprite3D.new()
	sprite.texture = data.launcher_texture
	var tex_h: int = max(1, data.launcher_texture.get_height())
	sprite.pixel_size = data.launcher_world_height / float(tex_h)
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	var root := Node3D.new()
	root.position = _projectile_launcher_position(inst)
	root.rotation_degrees = Vector3(0.0, _projectile_launcher_y_rotation_deg(inst), 0.0)
	root.add_child(sprite)
	return root

func _projectile_launcher_position(inst: ProjectileTrapInstance) -> Vector3:
	# Cell centre, then shift by half a cell along `wall_dir` to land on
	# the wall face, then pull back toward the corridor by
	# `launcher_depth_offset` so the sprite doesn't Z-fight the wall
	# texture beneath. Vertical = wall midheight + `launcher_y_offset`.
	# `launcher_horizontal_offset` shifts along the wall's tangent axis
	# (perpendicular to wall_dir in the horizontal plane) so designers
	# can nudge a launcher with one-sided art into visual centre.
	var data: ProjectileTrapData = inst.data
	var cx: float = inst.cell.x * CELL_SIZE + CELL_SIZE * 0.5
	var cz: float = inst.cell.y * CELL_SIZE + CELL_SIZE * 0.5
	var face_x: float = cx + float(inst.wall_dir.x) * CELL_SIZE * 0.5
	var face_z: float = cz + float(inst.wall_dir.y) * CELL_SIZE * 0.5
	var pulled_x: float = face_x - float(inst.wall_dir.x) * data.launcher_depth_offset
	var pulled_z: float = face_z - float(inst.wall_dir.y) * data.launcher_depth_offset
	# Wall tangent — perpendicular to wall_dir in the XZ plane.
	# wall_dir=(0,-1) [north]  → tangent=(1,0)  → shift along X
	# wall_dir=(0, 1) [south]  → tangent=(-1,0) → shift along -X
	# wall_dir=(-1,0) [west]   → tangent=(0,-1) → shift along -Z
	# wall_dir=(1, 0) [east]   → tangent=(0, 1) → shift along  Z
	# (The signs flip when the wall is on the opposite side so a
	# positive `launcher_horizontal_offset` always shifts to the
	# launcher's RIGHT as seen from in front of it.)
	var tan_x: float = float(-inst.wall_dir.y)
	var tan_z: float = float(inst.wall_dir.x)
	var shifted_x: float = pulled_x + tan_x * data.launcher_horizontal_offset
	var shifted_z: float = pulled_z + tan_z * data.launcher_horizontal_offset
	var y_centre: float = wall_height * 0.5 + data.launcher_y_offset
	return Vector3(shifted_x, y_centre, shifted_z)

# Plate floor decal (Phase 8 Task 3 — Subtask C4). One MeshInstance3D
# per PRESSURE_PLATE launcher, lying flat at Y = 0.01 above the floor
# to avoid Z-fighting with the floor mesh below. Sized via
# `plate_world_size` (1.0 = fills the cell). Same alpha-scissor +
# NEAREST-filter material the spike-trap holes use, cached on the
# texture in `_trap_floor_material_cache` (cache is shared because the
# material setup is identical — if a designer reuses the same texture
# for both, they reuse the same cached material).
# Plate decal returns a {root, mi} dict so the caller can both track
# the parent Node3D (for tweenable Y rotation that follows the camera
# — see `_refresh_plate_y_rotation`) AND the inner MeshInstance3D
# (for swapping the idle / triggered material). Wrapping the mesh in
# a Node3D lets us tween `rotation_degrees:y` directly without
# fighting the -90° X tilt that lays the quad flat on the floor.
func _make_plate_decal_node(inst: ProjectileTrapInstance) -> Dictionary:
	var data: ProjectileTrapData = inst.data
	if data.plate_texture_idle == null:
		return {}
	if inst.plate_cell == ProjectileTrapInstance.NO_PLATE:
		return {}
	var size_factor: float = max(0.01, data.plate_world_size)
	var quad := QuadMesh.new()
	quad.size = Vector2(CELL_SIZE * size_factor, CELL_SIZE * size_factor)
	# Outer Node3D: anchors the plate at its cell centre and owns the
	# Y rotation that tracks the camera. Tweenable as a single
	# `rotation_degrees:y` property so we can ride the same 0.12s
	# rotation tween the camera uses, keeping the plate texture
	# locked in screen-space throughout the rotate.
	var root := Node3D.new()
	var cx: float = inst.plate_cell.x * CELL_SIZE + CELL_SIZE * 0.5
	var cz: float = inst.plate_cell.y * CELL_SIZE + CELL_SIZE * 0.5
	root.position = Vector3(cx, 0.01, cz)
	root.rotation_degrees = Vector3(0.0, _current_angle, 0.0)
	# Inner MeshInstance3D: laid flat by a -90° X rotation, no
	# translation (the parent positions it). The X rotation is
	# constant — only the parent's Y rotation changes over time.
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = _build_trap_floor_material(data.plate_texture_idle)
	mi.transform = Transform3D(
		Basis(Vector3(1.0, 0.0, 0.0), -PI * 0.5),
		Vector3.ZERO
	)
	root.add_child(mi)
	return {"root": root, "mi": mi}

# Update one plate's Y rotation immediately (no tween) — used during
# `_build_projectile_traps` so plates render correctly from the very
# first frame. Per-plate tweening alongside camera rotation lives in
# `rotate_camera_to`.
func _refresh_plate_y_rotation(entry: Dictionary) -> void:
	if entry.is_empty():
		return
	var root: Node3D = entry.get("root", null)
	if root == null or not is_instance_valid(root):
		return
	root.rotation_degrees = Vector3(0.0, _current_angle, 0.0)

# Phase 8 Task 3 — Subtask C4. Walks every tracked plate visual and
# swaps its material to the triggered or idle texture based on whether
# the player is currently on the plate cell. Called from
# `_build_projectile_traps` (initial state on level build) and from
# `move_camera_to` (every player step). Diffs against
# `_plate_triggered_state` so we only issue a `material_override`
# write on actual state CHANGES, not every step.
#
# Future Phase 10 enemies that walk over plates will hook into the
# same path — the `_plate_should_be_triggered` predicate is the only
# thing that needs to extend (also check enemy positions). The
# diff-and-swap mechanic stays the same.
func _update_plate_visual_states() -> void:
	if _plate_visuals.is_empty():
		return
	for inst in _plate_visuals.keys():
		var should_trigger: bool = _plate_should_be_triggered(inst)
		var current: bool = _plate_triggered_state.get(inst, false)
		if should_trigger == current:
			continue
		var entry: Dictionary = _plate_visuals[inst]
		var mi: MeshInstance3D = entry.get("mi", null)
		if mi == null or not is_instance_valid(mi):
			# Decal was freed (level rebuild mid-frame, etc.) — drop
			# the stale entry so we don't keep checking it.
			_plate_visuals.erase(inst)
			_plate_triggered_state.erase(inst)
			continue
		var data: ProjectileTrapData = inst.data
		# Resolve the texture for the new state. Triggered falls back
		# to idle when the variant didn't supply a triggered texture
		# (Phase 10 enemies will still affect the bool state, but the
		# visual stays the same — acceptable and simple).
		var tex: Texture2D
		if should_trigger and data.plate_texture_triggered != null:
			tex = data.plate_texture_triggered
		else:
			tex = data.plate_texture_idle
		mi.material_override = _build_trap_floor_material(tex)
		_plate_triggered_state[inst] = should_trigger

func _plate_should_be_triggered(inst: ProjectileTrapInstance) -> bool:
	# Triggered (depressed) visual state when EITHER:
	#   - the player stands on the plate cell (the existing rule), OR
	#   - any item sits on the plate cell — dropping an item onto a
	#     plate holds it down and disables the trap until pickup.
	#     `Game._check_pressure_plate_trigger` mirrors this — the trap
	#     does not fire while an item is on the plate.
	# Phase 10 enemies that walk over plates will also count; keep
	# this predicate centralised so the extension is one place.
	if inst.plate_cell == _current_grid_pos:
		return true
	if generator != null:
		var c: GridCell = generator.grid[inst.plate_cell.x][inst.plate_cell.y]
		if c != null and not c.items.is_empty():
			return true
	return false

func _projectile_launcher_y_rotation_deg(inst: ProjectileTrapInstance) -> float:
	# Same wall-face → Y-rotation mapping wall decorations use, so the
	# launcher sprite sits flush with the wall mesh and its visible
	# side points into the corridor (toward the player).
	if inst.wall_dir == Vector2i(0, -1):  # north wall
		return 0.0
	if inst.wall_dir == Vector2i(0, 1):   # south wall
		return 180.0
	if inst.wall_dir == Vector2i(-1, 0):  # west wall
		return 90.0
	if inst.wall_dir == Vector2i(1, 0):   # east wall
		return 270.0
	return 0.0

# -------------------------------------------------------
# In-flight projectile rendering (Phase 8 Task 3 — Subtask C2)
# -------------------------------------------------------
#
# One Sprite3D per active projectile under `ProjectilesRoot`. Game.gd
# calls `spawn_projectile_visual` when a launcher fires,
# `update_projectile_visual` every frame the projectile is alive
# (syncs world position from `ProjectileInstance.cell_pos` and re-picks
# the texture for the current camera angle), and
# `despawn_projectile_visual` on impact. The 4-direction sprite picker
# is a static method on `ProjectileInstance` so its logic is unit-
# testable without a scene tree.

func spawn_projectile_visual(proj: ProjectileInstance) -> void:
	if proj == null or proj.data == null:
		return
	_ensure_projectiles_root()
	var sprite := Sprite3D.new()
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_projectiles_root.add_child(sprite)
	_projectile_visuals[proj] = sprite
	# Set initial position + texture in one call so the sprite never
	# renders at world origin for a frame before the first update.
	update_projectile_visual(proj)

func update_projectile_visual(proj: ProjectileInstance) -> void:
	if proj == null or not _projectile_visuals.has(proj):
		return
	var sprite: Sprite3D = _projectile_visuals[proj]
	if not is_instance_valid(sprite):
		_projectile_visuals.erase(proj)
		return
	# World position from continuous cell coordinates. Y sits at the
	# corridor mid-height + designer y-offset so a thrown projectile
	# clears the floor and stays visible.
	var x: float = proj.cell_pos.x * CELL_SIZE
	var z: float = proj.cell_pos.y * CELL_SIZE
	var y: float = wall_height * 0.5 + proj.data.projectile_y_offset
	sprite.position = Vector3(x, y, z)
	# Re-pick the texture each frame against the camera's current
	# forward direction. The camera in this game only rotates in
	# 90° steps, so most frames the picked view doesn't change and
	# the if-different guard below avoids a redundant texture set.
	var view: int = _projectile_view_for(proj)
	var tex: Texture2D = proj.data.projectile_sprite_for(view)
	if tex == null:
		# A misconfigured variant — bail without crashing. The sprite
		# stays invisible until the variant is fixed.
		return
	if sprite.texture != tex:
		sprite.texture = tex
		var tex_h: int = max(1, tex.get_height())
		sprite.pixel_size = proj.data.projectile_world_height / float(tex_h)

func despawn_projectile_visual(proj: ProjectileInstance) -> void:
	if proj == null or not _projectile_visuals.has(proj):
		return
	var sprite: Node = _projectile_visuals[proj]
	if is_instance_valid(sprite):
		sprite.queue_free()
	_projectile_visuals.erase(proj)

func _projectile_view_for(proj: ProjectileInstance) -> int:
	# Camera forward vector projected onto the horizontal XZ plane.
	# In Godot, the camera looks down -Z, so forward = -basis.z. Cell-
	# space x maps to world x and cell-space y maps to world z, so we
	# can compare the camera's (x, z) with the projectile's
	# (direction.x, direction.y) directly.
	if camera == null:
		return ProjectileInstance.CameraView.FRONT
	var fwd_3d: Vector3 = -camera.global_transform.basis.z
	var fwd_xz: Vector2 = Vector2(fwd_3d.x, fwd_3d.z)
	return ProjectileInstance.view_for_camera(proj.direction, fwd_xz)

func _build_items() -> void:
	for child in _items_root.get_children():
		child.queue_free()
	_item_sprites.clear()

	for x in range(generator.grid_width):
		for y in range(generator.grid_height):
			var cell: GridCell = generator.get_cell(x, y)
			if cell == null or cell.items.is_empty():
				continue
			var grid_pos := Vector2i(x, y)
			var visible_count: int = min(cell.items.size(), ITEM_MAX_VISIBLE_PER_TILE)
			var cell_sprites: Array[Sprite3D] = []
			for i in range(visible_count):
				var inst: ItemInstance = cell.items[i]
				if inst == null or inst.data == null or inst.data.dungeon_sprite == null:
					continue
				var sprite := _make_item_sprite(inst)
				sprite.position = _item_world_position(grid_pos, i, inst)
				_items_root.add_child(sprite)
				cell_sprites.append(sprite)
			if not cell_sprites.is_empty():
				_item_sprites[grid_pos] = cell_sprites

# Positions a single item sprite on its cell. When `grid_pos` is the
# player's current cell the whole stack slides forward along the
# player's facing direction so items appear at the bottom of view
# instead of directly under the camera. Otherwise the stack stays
# centred so a pile across the corridor reads as one cluster.
func _item_world_position(grid_pos: Vector2i, stack_index: int, inst: ItemInstance) -> Vector3:
	var cx: float = grid_pos.x * CELL_SIZE + CELL_SIZE * 0.5
	var cz: float = grid_pos.y * CELL_SIZE + CELL_SIZE * 0.5
	var offset: Vector3 = ITEM_STACK_OFFSETS[stack_index]
	var shift_x: float = 0.0
	var shift_z: float = 0.0
	if grid_pos == _current_grid_pos:
		shift_x = float(_current_facing.x) * ITEM_ON_TILE_FORWARD_OFFSET
		shift_z = float(_current_facing.y) * ITEM_ON_TILE_FORWARD_OFFSET
	var sprite_y: float = inst.data.dungeon_sprite_world_height * 0.5 + inst.data.dungeon_sprite_y_offset
	return Vector3(cx + offset.x + shift_x, sprite_y, cz + offset.z + shift_z)

# Re-positions every item sprite. Cheap (O(num items on level) — a few
# dozen) so we just iterate them all instead of diffing previous /
# current cell. Called from `set_initial_facing` (animated = false —
# initial-frame snap, no camera animation to sync with), `move_camera_to`
# (animated = true — items on the entered cell glide forward, items on
# the cell we just left glide back to centre, in sync with the 0.12s
# camera move), and `rotate_camera_to` (animated = true — stack
# rotates around cell centre in sync with the 0.12s camera turn).
# A previous `_item_tween` is killed so consecutive moves / turns don't
# fight each other for the sprite's position property.
func _refresh_item_positions(animated: bool = false) -> void:
	# A natural-end tween becomes invalid but stays non-null, so the
	# lazy-create check (`if _item_tween == null`) below would skip
	# creation and call tween_property on a dead tween — a back-to-back
	# spinner rotation reliably hits this. Always drop the reference.
	if _item_tween != null:
		if _item_tween.is_valid():
			_item_tween.kill()
		_item_tween = null
	# Tween is created lazily on the first sprite that actually needs to
	# move. Creating it up-front would emit a "started with no Tweeners"
	# error whenever the player moves through a room with no items (or
	# where no item changed cell-residency) — that path was firing on
	# every step and turn.
	for grid_pos in _item_sprites.keys():
		var cell: GridCell = generator.get_cell(grid_pos.x, grid_pos.y)
		if cell == null:
			continue
		var sprites: Array = _item_sprites[grid_pos]
		for i in range(sprites.size()):
			var sprite: Sprite3D = sprites[i]
			if not is_instance_valid(sprite):
				continue
			if i >= cell.items.size():
				continue
			var inst: ItemInstance = cell.items[i]
			if inst == null or inst.data == null:
				continue
			var target_pos: Vector3 = _item_world_position(grid_pos, i, inst)
			if animated and sprite.position != target_pos:
				if _item_tween == null:
					_item_tween = create_tween()
					_item_tween.set_parallel(true)
				_item_tween.tween_property(sprite, "position", target_pos, 0.12)
			else:
				sprite.position = target_pos

func _make_item_sprite(inst: ItemInstance) -> Sprite3D:
	var data: ItemData = inst.data
	# Per-instance hue-rotated dungeon sprite when the placer baked
	# one (KeyDoorSpawn pair >= 1); falls back to data.dungeon_sprite
	# otherwise.
	var tex: Texture2D = inst.get_dungeon_sprite()
	var sprite := Sprite3D.new()
	sprite.texture = tex
	var tex_h: int = max(1, tex.get_height())
	sprite.pixel_size = data.dungeon_sprite_world_height / float(tex_h)
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	return sprite

# Returns a cached StandardMaterial3D for the given entry, building one
# on the first request and reusing it on every subsequent call. With
# multiple variants per surface this collapses N quads × M materials
# into one material per variant.
func _material_for_entry(entry: BiomeTextureEntry) -> StandardMaterial3D:
	if _material_cache.has(entry):
		return _material_cache[entry]
	var mat: StandardMaterial3D = _build_material(entry.albedo)
	_material_cache[entry] = mat
	return mat

func _build_material(albedo: Texture2D) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()

	if albedo != null:
		mat.albedo_texture = albedo

	if biome.use_triplanar:
		var scale_x = 1.0 / CELL_SIZE
		var scale_y = 1.0 / wall_height
		var scale_z = 1.0 / CELL_SIZE
		mat.uv1_triplanar           = true
		mat.uv1_triplanar_sharpness = biome.triplanar_sharpness
		mat.uv1_scale               = Vector3(scale_x, scale_y, scale_z)
		mat.uv1_offset              = Vector3(0.0, biome.triplanar_y_offset, 0.0)

	# Nearest (not linear) keeps pixel-art textures crisp — linear blends
	# neighbouring texels and turns hand-drawn pixel walls to mush. Mipmaps
	# are kept on so distant walls in fog don't sparkle/moiré.
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS

	return mat

func _apply_biome_environment() -> void:
	var env = world_env.environment

	if env == null:
		push_error("No Environment resource on WorldEnvironment node")
		return

	env.fog_enabled              = biome.fog_enabled
	env.fog_light_color          = biome.fog_color
	env.fog_light_energy         = 1.0
	env.fog_density              = biome.fog_density
	env.fog_aerial_perspective   = biome.fog_aerial

	env.ambient_light_source     = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color      = biome.ambient_color
	env.ambient_light_energy     = biome.ambient_energy

	_apply_biome_sky(env)

# Sky override for outdoor biomes. Three modes:
#   - biome.sky_material non-null → wrap it in a Sky resource and use
#     BG_SKY. Path to swap in a panorama PNG later without code edits.
#   - biome.sky_color.a > 0       → use BG_COLOR with that flat colour.
#   - neither set                 → RESTORE the WorldEnvironment's
#     scene-authored defaults (captured on first run). Stops a
#     SparseForest blue sky from leaking into the next indoor biome.
func _apply_biome_sky(env: Environment) -> void:
	if _saved_env_background_mode == -1:
		_saved_env_background_mode = env.background_mode
		_saved_env_background_color = env.background_color
		_saved_env_sky = env.sky

	if biome.sky_material != null:
		var sky := Sky.new()
		sky.sky_material = biome.sky_material
		env.background_mode = Environment.BG_SKY
		env.sky = sky
		return

	if biome.sky_color.a > 0.0:
		env.background_mode = Environment.BG_COLOR
		env.background_color = biome.sky_color
		env.sky = null
		return

	env.background_mode = _saved_env_background_mode as Environment.BGMode
	env.background_color = _saved_env_background_color
	env.sky = _saved_env_sky

func _add_horizontal_quad(pos: Vector3, mat: StandardMaterial3D, flip: bool = false) -> void:
	var mesh_instance              = MeshInstance3D.new()
	var quad                       = QuadMesh.new()
	quad.size                      = Vector2(CELL_SIZE, CELL_SIZE)
	quad.surface_set_material(0, mat)
	mesh_instance.mesh             = quad
	mesh_instance.position         = pos
	mesh_instance.rotation_degrees = Vector3(-90.0 if not flip else 90.0, 0, 0)
	dungeon_root.add_child(mesh_instance)

func _add_vertical_quad(pos: Vector3, y_rotation: float, mat: StandardMaterial3D) -> void:
	var mesh_instance              = MeshInstance3D.new()
	var quad                       = QuadMesh.new()
	quad.size                      = Vector2(CELL_SIZE, wall_height)
	quad.surface_set_material(0, mat)
	mesh_instance.mesh             = quad
	mesh_instance.position         = pos
	mesh_instance.rotation_degrees = Vector3(0, y_rotation, 0)
	dungeon_root.add_child(mesh_instance)

func _place_camera_at_entrance() -> void:
	var ep = generator.entrance_pos
	_current_grid_pos = ep
	camera.position = _grid_to_world(ep.x, ep.y)

func set_initial_facing(facing: Vector2i) -> void:
	_current_facing           = facing
	_current_angle            = FACING_ANGLES.get(facing, 0.0)
	camera.rotation_degrees.y = _current_angle
	camera.position           = _grid_to_world(_current_grid_pos.x, _current_grid_pos.y)
	_refresh_object_positions()
	_refresh_scenery_positions()
	_refresh_item_positions()
	_refresh_trap_spike_positions()
	_refresh_teleporter_positions()
	# Snap every plate's Y rotation to the new camera angle so they
	# render correctly from the very first frame after a level setup
	# (no tween — this runs before the player has moved at all).
	for inst in _plate_visuals.keys():
		_refresh_plate_y_rotation(_plate_visuals[inst])

func move_camera_to(grid_pos: Vector2i, facing: Vector2i) -> void:
	_current_grid_pos = grid_pos
	_current_facing   = facing
	var target_pos    = _grid_to_world(grid_pos.x, grid_pos.y)
	# Kill any prior movement tween so consecutive moves don't compound
	# (and so shake_camera's kill-and-snap path sees a single owner of
	# camera.position).
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.set_parallel(true)
	_move_tween.tween_property(camera, "position", target_pos, 0.12)
	_move_tween.tween_property(camera, "rotation_degrees:y", _current_angle, 0.12)
	# Object positions are intentionally NOT refreshed here — the lean
	# axis is tied to facing, so the chest only re-leans when the player
	# turns. Refreshing on move would visibly snap the chest mid-step.
	# Item positions DO refresh on move: the on-tile shift is keyed to
	# cell-residency, not facing, so cell-change is exactly when it
	# needs to update — items on the destination slide forward into
	# view, items on the cell we just left slide back to centre, in
	# sync with the 0.12s camera tween.
	_refresh_item_positions(true)
	# Pressure-plate visual state (Subtask C4) — diff against the
	# previous-frame state and only swap material on actual change.
	_update_plate_visual_states()

func rotate_camera_to(turn_right: bool, facing: Vector2i = Vector2i.ZERO) -> void:
	_current_angle += -90.0 if turn_right else 90.0
	if facing != Vector2i.ZERO:
		_current_facing = facing
	var tween = create_tween().set_parallel(true)
	tween.tween_property(camera, "rotation_degrees:y", _current_angle, 0.12)
	# Phase 8 Task 3 — Subtask C4: rotate every plate decal alongside
	# the camera so the texture stays locked in screen space (the
	# player always sees the plate from the same perspective). This is
	# the trick that lets designers bake shadows / fake depth into the
	# plate art — without it, the texture's "front" would be visually
	# correct from only one of the four cardinal angles.
	for inst in _plate_visuals.keys():
		var entry: Dictionary = _plate_visuals[inst]
		var root: Node3D = entry.get("root", null)
		if root != null and is_instance_valid(root):
			tween.tween_property(root, "rotation_degrees:y", _current_angle, 0.12)
	_refresh_object_positions()
	_refresh_scenery_positions()
	_refresh_item_positions(true)
	_refresh_trap_spike_positions()
	_refresh_teleporter_positions()

const SHAKE_INTENSITY := 0.12
const SHAKE_DURATION  := 0.18
const SHAKE_STEPS     := 5

var _shake_tween: Tween = null
var _shake_origin: Vector3 = Vector3.ZERO
# Tween created by `move_camera_to`. Tracked so `shake_camera` can
# kill an in-flight movement before starting its own animation —
# without this, both tweens fight for `camera.position` and the
# shake's anchor lands at wherever the camera was MID-MOVE, which
# visibly pulls the player back from the cell they just stepped
# onto (the original "step trap pushes you back" bug).
var _move_tween: Tween = null

# Phase 15 Task 6 — fade-to-black overlay used by the teleporter warp
# (and reusable by Phase 15 Task 1 sub-level transitions). Lazily
# constructed on first use as a child of `viewport_container` so it
# covers the 3D view; alpha tweens between 0 and 1. Tween tracked so
# back-to-back warps don't fight each other for the alpha property.
var _fade_overlay: ColorRect = null
var _fade_tween: Tween = null
const _DEFAULT_FADE_DURATION: float = 0.18

# Brief omni-directional jolt of the camera position. Used for wall
# bumps and rejected interactions (locked-door click feedback).
# `magnitude` scales the base SHAKE_INTENSITY: 1.0 = full wall bump,
# ~0.4 = a softer "click on locked thing" jolt. Safe to call rapid-
# fire — an active shake is killed and the camera reset before a
# fresh shake starts so successive shakes don't drift.
func shake_camera(magnitude: float = 1.0) -> void:
	# Kill any in-flight movement tween — without this, the move tween
	# (0.12s) keeps trying to interpolate camera.position toward the
	# target cell while the shake tween (0.18s) interpolates around
	# its captured origin. The two fight for the same property each
	# frame and the shake's "settle" position visibly drags the camera
	# back to wherever it was when the shake started, not the cell the
	# player walked onto. Killing the move tween here makes the shake
	# the sole owner of camera.position for its duration.
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
		_move_tween = null
	if _shake_tween != null and _shake_tween.is_running():
		_shake_tween.kill()
		camera.position = _shake_origin
	# Anchor the shake on the LOGICAL grid cell, not whatever
	# camera.position currently is. If we get here mid-move (trap
	# damage fires the same frame the player steps onto the trap)
	# camera.position is still partway between cells, and using it
	# as the origin would settle the shake at that intermediate
	# point — visually pulling the player back. _grid_to_world gives
	# us the canonical "where the player IS" coordinate.
	_shake_origin = _grid_to_world(_current_grid_pos.x, _current_grid_pos.y)
	# Snap camera to the canonical origin BEFORE the shake starts so
	# step #1's interpolation begins from the trap cell rather than
	# from the (possibly stale) mid-move position. Otherwise the
	# first 0.04s of the shake animates from "old position" to
	# "trap cell + offset", which reads as a slide.
	camera.position = _shake_origin
	_shake_tween = create_tween()
	var intensity: float = SHAKE_INTENSITY * magnitude
	var step_dur := SHAKE_DURATION / float(SHAKE_STEPS)
	for i in range(SHAKE_STEPS):
		var decay := 1.0 - float(i) / float(SHAKE_STEPS)
		var offset := Vector3(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity) * 0.4,
			randf_range(-intensity, intensity),
		) * decay
		_shake_tween.tween_property(camera, "position", _shake_origin + offset, step_dur)
	_shake_tween.tween_property(camera, "position", _shake_origin, step_dur)

func _grid_to_world(x: int, y: int) -> Vector3:
	return Vector3(
		x * CELL_SIZE + CELL_SIZE * 0.5,
		camera_eye_height,
		y * CELL_SIZE + CELL_SIZE * 0.5
	)

# Phase 15 Task 6 — teleporter warp + Phase 15 Task 1 sub-level
# transitions both want a fade-to-black / fade-from-black overlay to
# hide a discontinuous camera move. The overlay is a single ColorRect
# parented to the SubViewportContainer so it covers the 3D view but
# not the HUD. Lazily constructed; cleaned up automatically on
# `viewport_container` free.
func _ensure_fade_overlay() -> void:
	if _fade_overlay != null and is_instance_valid(_fade_overlay):
		return
	_fade_overlay = ColorRect.new()
	_fade_overlay.name = "FadeOverlay"
	_fade_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	# MOUSE_FILTER_IGNORE so the overlay never eats clicks even while
	# fully opaque — input gating during the warp is the caller's job
	# (Game._is_world_paused), not the renderer's.
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport_container.add_child(_fade_overlay)
	_fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Render on top of the SubViewportContainer's content — ColorRect
	# is a sibling of the SubViewport's render output and draws in
	# child order, so being added last is enough.

# Fades the overlay from current alpha to opaque black over `duration`.
# Returns the tween's `finished` Signal so callers can `await` it. A
# duration <= 0 snaps immediately (still returns a one-shot Signal so
# callers don't have to special-case it).
func fade_to_black(duration: float = _DEFAULT_FADE_DURATION) -> Signal:
	_ensure_fade_overlay()
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	if duration <= 0.0:
		_fade_overlay.color = Color(0.0, 0.0, 0.0, 1.0)
	else:
		_fade_tween.tween_property(_fade_overlay, "color", Color(0.0, 0.0, 0.0, 1.0), duration)
	return _fade_tween.finished

# Reverse of `fade_to_black`. Returns the tween's `finished` Signal.
func fade_from_black(duration: float = _DEFAULT_FADE_DURATION) -> Signal:
	_ensure_fade_overlay()
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	if duration <= 0.0:
		_fade_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	else:
		_fade_tween.tween_property(_fade_overlay, "color", Color(0.0, 0.0, 0.0, 0.0), duration)
	return _fade_tween.finished

# Hard-snap the camera to `grid_pos` with the given `facing`. Kills any
# in-flight move tween so a teleporter warp's discontinuous cell change
# isn't interpolated from the source cell (which would defeat the fade).
# Mirrors `set_initial_facing` but takes the target cell explicitly so
# the caller doesn't have to mutate `_current_grid_pos` first.
func snap_camera_to(grid_pos: Vector2i, facing: Vector2i) -> void:
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
		_move_tween = null
	_current_grid_pos = grid_pos
	set_initial_facing(facing)
