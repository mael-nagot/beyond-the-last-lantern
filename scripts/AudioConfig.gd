class_name AudioConfig
extends Resource

# Global, non-biome-specific UI and player-action sounds.
# One `audio_config.tres` instance lives in res://assets/audio_config.tres
# and is loaded by Game.gd at startup, then assigned to SoundManager.

@export_group("UI")
@export var map_open_sound: AudioStream
@export var map_close_sound: AudioStream
@export var negative_sound: AudioStream

@export_group("Player Movement (non-biome)")
@export var wall_bump_sound: AudioStream
@export var turn_sounds: Array[AudioStream] = []
