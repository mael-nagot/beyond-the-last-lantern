extends Node

# Autoload singleton for short-form SFX. Pool of AudioStreamPlayer nodes
# allows overlap (rapid pickups don't cut each other off). A separate
# player is reserved for biome ambient loops (Phase 19, hooked but unused
# until ambient loops land on BiomeData).
#
# Game.gd assigns `audio_config` and `current_biome` so the convenience
# methods (play_move, play_turn, play_map_open, ...) can resolve their
# streams without each callsite knowing where the data lives.

const SFX_PLAYER_COUNT := 8

var audio_config: AudioConfig = null
var current_biome: BiomeData = null

var _sfx_players: Array[AudioStreamPlayer] = []
var _next_player_index: int = 0
var _ambient_player: AudioStreamPlayer = null

func _ready() -> void:
	for i in range(SFX_PLAYER_COUNT):
		var player := AudioStreamPlayer.new()
		player.name = "SFXPlayer%d" % i
		add_child(player)
		_sfx_players.append(player)
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.name = "AmbientPlayer"
	add_child(_ambient_player)

# -------------------------------------------------------
# Basic playback — null streams and empty arrays are no-ops.
# -------------------------------------------------------

func play(stream: AudioStream) -> void:
	if stream == null:
		return
	var player := _sfx_players[_next_player_index]
	_next_player_index = (_next_player_index + 1) % SFX_PLAYER_COUNT
	player.stream = stream
	player.play()

func play_random(streams: Array[AudioStream]) -> void:
	if streams.is_empty():
		return
	play(streams[randi() % streams.size()])

func play_ambient(stream: AudioStream) -> void:
	if stream == null:
		stop_ambient()
		return
	if _ambient_player.stream == stream and _ambient_player.playing:
		return
	_ambient_player.stream = stream
	_ambient_player.play()

func stop_ambient() -> void:
	if _ambient_player != null and _ambient_player.playing:
		_ambient_player.stop()

# -------------------------------------------------------
# Convenience — each lookup is null-safe so a missing audio_config or
# biome just produces silence rather than a crash.
# -------------------------------------------------------

func play_move() -> void:
	if current_biome != null:
		play_random(current_biome.move_sounds)

func play_turn() -> void:
	if audio_config != null:
		play_random(audio_config.turn_sounds)

func play_wall_bump() -> void:
	if audio_config != null:
		play(audio_config.wall_bump_sound)

func play_negative() -> void:
	if audio_config != null:
		play(audio_config.negative_sound)

func play_map_open() -> void:
	if audio_config != null:
		play(audio_config.map_open_sound)

func play_map_close() -> void:
	if audio_config != null:
		play(audio_config.map_close_sound)
