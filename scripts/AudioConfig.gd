class_name AudioConfig
extends Resource

# Global, non-biome-specific UI and player-action sounds.
# One `audio_config.tres` instance lives in res://assets/audio_config.tres
# and is loaded by Game.gd at startup, then assigned to SoundManager.

@export_group("UI")
## Played when the map popup opens. Null = silent.
@export var map_open_sound: AudioStream
## Played when the map popup closes. Null = silent.
@export var map_close_sound: AudioStream
## Generic "rejected / unavailable" cue used for empty-chest re-clicks
## and similar dead-click feedback. Null = silent.
@export var negative_sound: AudioStream

@export_group("Player Movement (non-biome)")
## Played when the player tries to walk into a wall (or into a closed
## door from the wrong side). Null = silent.
@export var wall_bump_sound: AudioStream
## Pool of rustle / step-shift sounds. One is picked at random on every
## turn (left / right) so successive turns don't sound identical.
## Empty array = silent.
@export var turn_sounds: Array[AudioStream] = []

@export_group("Damage Feedback")
## Played when the party takes damage (traps today; combat / status
## effects later). Centred on the player — non-spatial. Null = silent.
@export var pain_sound: AudioStream
