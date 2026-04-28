class_name BiomeData
extends Resource

@export var biome_name: String = "Forest"

@export_group("Wall Textures")
@export var wall_albedo_textures: Array[Texture2D] = []
@export var wall_normal_textures: Array[Texture2D] = []

@export_group("Floor Textures")
@export var floor_albedo_textures: Array[Texture2D] = []
@export var floor_normal_textures: Array[Texture2D] = []

@export_group("Ceiling Textures")
@export var ceiling_albedo_textures: Array[Texture2D] = []
@export var ceiling_normal_textures: Array[Texture2D] = []

@export_group("Appearance")
@export var wall_height: float = 2.5
@export var show_ceiling: bool = true
@export var ambient_light_color: Color = Color(0.2, 0.35, 0.15)
@export var ambient_light_energy: float = 0.8
@export var fog_color: Color = Color(0.1, 0.2, 0.1)
@export var fog_density: float = 0.04
