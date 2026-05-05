extends GutTest

# SoundManager extends Node and is registered as an autoload, but for
# isolation we instantiate a fresh copy per test (preload + add_child_autofree).
# The script intentionally has no class_name to avoid colliding with the
# autoload's global name.

const SoundManagerScript = preload("res://scripts/SoundManager.gd")

func _make_manager() -> Node:
	var m: Node = SoundManagerScript.new()
	add_child_autofree(m)
	return m

func _make_stream() -> AudioStream:
	return AudioStreamGenerator.new()

func _make_config() -> AudioConfig:
	var c := AudioConfig.new()
	c.negative_sound = _make_stream()
	c.wall_bump_sound = _make_stream()
	c.map_open_sound = _make_stream()
	c.map_close_sound = _make_stream()
	c.turn_sounds = [_make_stream(), _make_stream()]
	return c

# -------------------------------------------------------
# Pool initialisation
# -------------------------------------------------------

func test_creates_pool_of_eight_sfx_players() -> void:
	var m := _make_manager()
	assert_eq(m._sfx_players.size(), SoundManagerScript.SFX_PLAYER_COUNT)
	for player in m._sfx_players:
		assert_true(player is AudioStreamPlayer)

func test_creates_a_dedicated_ambient_player() -> void:
	var m := _make_manager()
	assert_not_null(m._ambient_player)
	assert_true(m._ambient_player is AudioStreamPlayer)

# -------------------------------------------------------
# Null-safety
# -------------------------------------------------------

func test_play_with_null_stream_is_noop() -> void:
	var m := _make_manager()
	m.play(null)
	# Nothing to assert beyond "didn't crash" — pool index unchanged
	assert_eq(m._next_player_index, 0)

func test_play_random_with_empty_array_is_noop() -> void:
	var m := _make_manager()
	var empty: Array[AudioStream] = []
	m.play_random(empty)
	assert_eq(m._next_player_index, 0)

func test_play_ambient_with_null_stops_ambient() -> void:
	var m := _make_manager()
	m._ambient_player.stream = _make_stream()
	m._ambient_player.play()
	m.play_ambient(null)
	assert_false(m._ambient_player.playing)

func test_stop_ambient_when_not_playing_is_noop() -> void:
	var m := _make_manager()
	# Should not crash even though no ambient is playing
	m.stop_ambient()
	assert_false(m._ambient_player.playing)

# -------------------------------------------------------
# play() advances the round-robin pool
# -------------------------------------------------------

func test_play_assigns_stream_and_advances_pool_index() -> void:
	var m := _make_manager()
	var s := _make_stream()
	m.play(s)
	assert_eq(m._sfx_players[0].stream, s)
	assert_eq(m._next_player_index, 1)
	m.play(s)
	assert_eq(m._sfx_players[1].stream, s)
	assert_eq(m._next_player_index, 2)

func test_pool_wraps_around_after_eight_calls() -> void:
	var m := _make_manager()
	for i in range(SoundManagerScript.SFX_PLAYER_COUNT):
		m.play(_make_stream())
	assert_eq(m._next_player_index, 0)

# -------------------------------------------------------
# Convenience methods are null-safe when config/biome are unset
# -------------------------------------------------------

func test_play_move_with_no_biome_is_noop() -> void:
	var m := _make_manager()
	m.play_move()
	assert_eq(m._next_player_index, 0)

func test_play_turn_with_no_config_is_noop() -> void:
	var m := _make_manager()
	m.play_turn()
	assert_eq(m._next_player_index, 0)

func test_play_negative_with_no_config_is_noop() -> void:
	var m := _make_manager()
	m.play_negative()
	assert_eq(m._next_player_index, 0)

func test_play_map_open_close_with_no_config_is_noop() -> void:
	var m := _make_manager()
	m.play_map_open()
	m.play_map_close()
	assert_eq(m._next_player_index, 0)

# -------------------------------------------------------
# Convenience methods route to the right config field
# -------------------------------------------------------

func test_play_negative_uses_audio_config_stream() -> void:
	var m := _make_manager()
	m.audio_config = _make_config()
	m.play_negative()
	assert_eq(m._sfx_players[0].stream, m.audio_config.negative_sound)

func test_play_wall_bump_uses_audio_config_stream() -> void:
	var m := _make_manager()
	m.audio_config = _make_config()
	m.play_wall_bump()
	assert_eq(m._sfx_players[0].stream, m.audio_config.wall_bump_sound)

func test_play_map_open_uses_audio_config_stream() -> void:
	var m := _make_manager()
	m.audio_config = _make_config()
	m.play_map_open()
	assert_eq(m._sfx_players[0].stream, m.audio_config.map_open_sound)

func test_play_map_close_uses_audio_config_stream() -> void:
	var m := _make_manager()
	m.audio_config = _make_config()
	m.play_map_close()
	assert_eq(m._sfx_players[0].stream, m.audio_config.map_close_sound)

func test_play_turn_picks_from_audio_config_array() -> void:
	var m := _make_manager()
	m.audio_config = _make_config()
	m.play_turn()
	assert_true(m.audio_config.turn_sounds.has(m._sfx_players[0].stream))

func test_play_move_picks_from_biome_array() -> void:
	var m := _make_manager()
	var biome := BiomeData.new()
	biome.move_sounds = [_make_stream(), _make_stream()]
	m.current_biome = biome
	m.play_move()
	assert_true(biome.move_sounds.has(m._sfx_players[0].stream))
