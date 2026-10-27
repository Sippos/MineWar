extends Node

const SAMPLE_RATE := 22050
const SFX_PLAYER_COUNT := 12
const UI_PLAYER_COUNT := 4
const STINGER_PLAYER_COUNT := 3

var _players: Array[AudioStreamPlayer] = []
var _sfx_players: Array[AudioStreamPlayer] = []
var _ui_players: Array[AudioStreamPlayer] = []
var _stinger_players: Array[AudioStreamPlayer] = []

var _sfx_cursor := 0
var _ui_cursor := 0
var _stinger_cursor := 0

var _rng := RandomNumberGenerator.new()
var _streams := {}
var _last_play_ticks := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_ensure_buses()
	_init_players()
	_build_streams()

func _ensure_buses() -> void:
	var required_buses: Array[StringName] = [&"Music", &"SFX", &"UI", &"Stingers"]
	for bus_name in required_buses:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, &"Master")

func _init_players() -> void:
	for index in range(SFX_PLAYER_COUNT):
		var player := AudioStreamPlayer.new()
		player.name = "SFXPlayer%d" % index
		player.bus = "SFX"
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_sfx_players.append(player)
		_players.append(player)

	for index in range(UI_PLAYER_COUNT):
		var player := AudioStreamPlayer.new()
		player.name = "UIPlayer%d" % index
		player.bus = "UI"
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_ui_players.append(player)
		_players.append(player)

	for index in range(STINGER_PLAYER_COUNT):
		var player := AudioStreamPlayer.new()
		player.name = "StingerPlayer%d" % index
		player.bus = "Stingers"
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_stinger_players.append(player)
		_players.append(player)

func _build_streams() -> void:
	_streams["dig_soft"] = _make_impact_stream(0.085, 118.0, 0.48, 101)
	_streams["dig_hard"] = _make_impact_stream(0.095, 185.0, 0.34, 202)
	_streams["block_break"] = _make_break_stream(0.19, 303)
	_streams["gem_found"] = _make_chime_stream([760.0, 1060.0], 0.18, 0.075)
	_streams["purchase"] = _make_chime_stream([520.0, 780.0], 0.16, 0.065)
	_streams["deposit"] = _make_chime_stream([650.0, 880.0, 1120.0], 0.20, 0.055)
	_streams["upgrade"] = _make_upgrade_stream(0.42)
	_streams["error"] = _make_error_stream(0.18)
	_streams["mine_awaken"] = _make_chime_stream([240.0, 360.0, 520.0], 0.48, 0.11)
	_streams["warning_drum"] = _make_impact_stream(0.26, 62.0, 0.24, 404)
	_streams["warning_horn"] = _make_horn_stream(0.78, 185.0, 277.5)
	_streams["breach"] = _make_break_stream(0.52, 505)
	_streams["objective_tick"] = _make_chime_stream([620.0, 820.0], 0.16, 0.055)
	_streams["cache_open"] = _make_cache_open_stream(0.55)
	_streams["cache_collapse"] = _make_cache_collapse_stream(0.42)
	_streams["anomaly_reveal"] = _make_anomaly_reveal_stream(0.68)
	_streams["relic_activated"] = _make_relic_activated_stream(0.85)

# --- Public API ---

func play_dig_hit(block_id: int = 0) -> void:
	var stream_name := "dig_hard" if block_id == 2 or block_id == 3 else "dig_soft"
	var now := Time.get_ticks_msec()
	if now - int(_last_play_ticks.get(stream_name, 0)) < 32:
		return
	_last_play_ticks[stream_name] = now
	_play_sfx(stream_name, -15.0, 0.05)

func play_block_break(has_gem: bool = false) -> void:
	_play_sfx("block_break", -8.5, 0.035)
	if has_gem:
		_play_sfx("gem_found", -1.5, 0.025)

func play_purchase() -> void:
	_play_ui("purchase", -2.5, 0.025)

func play_upgrade() -> void:
	_play_ui("upgrade", -1.0, 0.018)

func play_error() -> void:
	_play_ui("error", -4.5, 0.012)

func play_deposit(amount: int = 1) -> void:
	var amount_pitch := clampf(float(maxi(amount, 1) - 1) * 0.025, 0.0, 0.22)
	_play_sfx("deposit", -3.5, 0.02, amount_pitch)

func play_level_up() -> void:
	_play_ui("upgrade", 0.0, 0.0, 0.08)

func play_mine_awaken() -> void:
	_play_stinger("mine_awaken", -3.5, 0.015)
	_duck_music(1.8, -8.0)

func play_warning_drum(stage: int = 1) -> void:
	var pitch_boost := clampf(float(stage - 1) * 0.06, 0.0, 0.18)
	_play_stinger("warning_drum", -4.0, 0.02, pitch_boost)

func play_warning_horn() -> void:
	_play_stinger("warning_horn", 0.5, 0.01)
	_duck_music(2.6, -12.0)

func play_war_horn() -> void:
	play_warning_horn()

func play_breach() -> void:
	_play_stinger("breach", 1.0, 0.015)
	_duck_music(2.2, -12.0)

func play_objective_tick(progress: int = 1) -> void:
	_play_ui("objective_tick", -7.5, 0.015, clampf(float(progress - 1) * 0.035, 0.0, 0.18))

func play_cache_open() -> void:
	_play_stinger("cache_open", 0.0, 0.015)
	_duck_music(1.4, -6.0)

func play_cache_collapse() -> void:
	_play_sfx("cache_collapse", -6.5, 0.03)

func play_anomaly_reveal() -> void:
	_play_stinger("anomaly_reveal", -2.0, 0.015)
	_duck_music(1.2, -6.0)

func play_relic_activated() -> void:
	_play_stinger("relic_activated", 1.0, 0.01)
	_duck_music(2.0, -10.0)

# --- Routing & Pooling ---

func _play_sfx(stream_name: String, volume_db: float, pitch_variation: float, pitch_offset: float = 0.0) -> void:
	_play_from_pool(_sfx_players, _sfx_cursor, stream_name, volume_db, pitch_variation, pitch_offset)
	_sfx_cursor = (_sfx_cursor + 1) % _sfx_players.size()

func _play_ui(stream_name: String, volume_db: float, pitch_variation: float, pitch_offset: float = 0.0) -> void:
	_play_from_pool(_ui_players, _ui_cursor, stream_name, volume_db, pitch_variation, pitch_offset)
	_ui_cursor = (_ui_cursor + 1) % _ui_players.size()

func _play_stinger(stream_name: String, volume_db: float, pitch_variation: float, pitch_offset: float = 0.0) -> void:
	_play_from_pool(_stinger_players, _stinger_cursor, stream_name, volume_db, pitch_variation, pitch_offset)
	_stinger_cursor = (_stinger_cursor + 1) % _stinger_players.size()

func _play_from_pool(pool: Array[AudioStreamPlayer], start_cursor: int, stream_name: String, volume_db: float, pitch_variation: float, pitch_offset: float) -> void:
	if not _streams.has(stream_name) or pool.is_empty():
		return
	var selected: AudioStreamPlayer = null
	for step in range(pool.size()):
		var candidate := pool[(start_cursor + step) % pool.size()]
		if not candidate.playing:
			selected = candidate
			break
	if selected == null:
		selected = pool[start_cursor]
	selected.stop()
	selected.stream = _streams[stream_name]
	selected.volume_db = volume_db
	selected.pitch_scale = maxf(0.25, 1.0 + pitch_offset + _rng.randf_range(-pitch_variation, pitch_variation))
	selected.play()

func _duck_music(duration: float, target_db: float) -> void:
	var music_mgr := get_node_or_null("/root/MusicManager")
	if music_mgr and music_mgr.has_method("duck"):
		music_mgr.call("duck", duration, target_db)

# --- Procedural Audio Synthesizers (16-bit 22.05kHz PCM) ---

func _make_impact_stream(duration: float, body_frequency: float, noise_mix: float, random_seed: int) -> AudioStreamWAV:
	var sample_count := maxi(1, int(SAMPLE_RATE * duration))
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = random_seed
	for index in range(sample_count):
		var t := float(index) / float(SAMPLE_RATE)
		var progress := t / duration
		var envelope := pow(maxf(0.0, 1.0 - progress), 3.2)
		var noise := local_rng.randf_range(-1.0, 1.0)
		var body := sin(TAU * body_frequency * t) + 0.34 * sin(TAU * body_frequency * 2.15 * t)
		var transient := local_rng.randf_range(-1.0, 1.0) * pow(maxf(0.0, 1.0 - progress * 7.0), 2.0)
		samples[index] = clampf((body * (1.0 - noise_mix) + noise * noise_mix + transient * 0.65) * envelope * 0.72, -1.0, 1.0)
	return _make_wav(samples)

func _make_break_stream(duration: float, random_seed: int) -> AudioStreamWAV:
	var sample_count := maxi(1, int(SAMPLE_RATE * duration))
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = random_seed
	var filtered_noise := 0.0
	for index in range(sample_count):
		var t := float(index) / float(SAMPLE_RATE)
		var progress := t / duration
		var envelope := pow(maxf(0.0, 1.0 - progress), 2.1)
		filtered_noise = lerpf(filtered_noise, local_rng.randf_range(-1.0, 1.0), 0.28)
		var rumble := sin(TAU * (72.0 - 24.0 * progress) * t)
		var crack_a := local_rng.randf_range(-1.0, 1.0) * exp(-pow((progress - 0.08) * 28.0, 2.0))
		var crack_b := local_rng.randf_range(-1.0, 1.0) * exp(-pow((progress - 0.29) * 36.0, 2.0))
		samples[index] = clampf((filtered_noise * 0.58 + rumble * 0.38 + crack_a + crack_b * 0.7) * envelope * 0.78, -1.0, 1.0)
	return _make_wav(samples)

func _make_chime_stream(frequencies: Array, duration: float, spacing: float) -> AudioStreamWAV:
	var sample_count := maxi(1, int(SAMPLE_RATE * duration))
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	for index in range(sample_count):
		var t := float(index) / float(SAMPLE_RATE)
		var value := 0.0
		for tone_index in range(frequencies.size()):
			var start := float(tone_index) * spacing
			var local_t := t - start
			if local_t < 0.0:
				continue
			var tone_length := maxf(0.04, duration - start)
			var envelope := pow(maxf(0.0, 1.0 - local_t / tone_length), 3.0)
			var frequency := float(frequencies[tone_index])
			value += (sin(TAU * frequency * local_t) + 0.28 * sin(TAU * frequency * 2.0 * local_t)) * envelope
		samples[index] = clampf(value * 0.34, -1.0, 1.0)
	return _make_wav(samples)

func _make_horn_stream(duration: float, fundamental: float, fifth: float) -> AudioStreamWAV:
	var sample_count := maxi(1, int(SAMPLE_RATE * duration))
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	for index in range(sample_count):
		var t := float(index) / float(SAMPLE_RATE)
		var progress := t / duration
		# Brass swell: fast crescendo attack (0.09s), steady sustained call, rich release
		var attack := clampf(progress / 0.12, 0.0, 1.0)
		var release := pow(clampf((1.0 - progress) / 0.45, 0.0, 1.0), 1.6)
		var envelope := attack * release
		var vibrato := 1.0 + 0.008 * sin(TAU * 5.2 * t)
		var f1 := fundamental * vibrato
		var f2 := fifth * vibrato
		# Harmonics for authentic brass timbre (saw/resonant overtones)
		var tone1 := sin(TAU * f1 * t) + 0.55 * sin(TAU * f1 * 2.0 * t) + 0.32 * sin(TAU * f1 * 3.0 * t) + 0.18 * sin(TAU * f1 * 4.0 * t)
		var tone2 := sin(TAU * f2 * t) + 0.45 * sin(TAU * f2 * 2.0 * t) + 0.22 * sin(TAU * f2 * 3.0 * t)
		var mix := (tone1 * 0.62 + tone2 * 0.38) * envelope * 0.75
		samples[index] = clampf(mix, -1.0, 1.0)
	return _make_wav(samples)

func _make_cache_open_stream(duration: float) -> AudioStreamWAV:
	var sample_count := maxi(1, int(SAMPLE_RATE * duration))
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var frequencies := [523.25, 659.25, 783.99, 1046.50]
	var spacing := 0.05
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = 777
	for index in range(sample_count):
		var t := float(index) / float(SAMPLE_RATE)
		# Initial heavy stone mechanism click/latch
		var stone_latch := (local_rng.randf_range(-1.0, 1.0) * 0.6 + sin(TAU * 140.0 * t)) * exp(-pow(t * 45.0, 2.0))
		var chime_value := 0.0
		for tone_index in range(frequencies.size()):
			var start := float(tone_index) * spacing
			var local_t := t - start
			if local_t < 0.0:
				continue
			var tone_length := maxf(0.06, duration - start)
			var envelope := pow(maxf(0.0, 1.0 - local_t / tone_length), 2.8)
			var freq: float = frequencies[tone_index]
			chime_value += (sin(TAU * freq * local_t) + 0.35 * sin(TAU * freq * 2.0 * local_t) + 0.12 * sin(TAU * freq * 3.0 * local_t)) * envelope
		var combined := stone_latch * 0.5 + chime_value * 0.38
		samples[index] = clampf(combined, -1.0, 1.0)
	return _make_wav(samples)

func _make_cache_collapse_stream(duration: float) -> AudioStreamWAV:
	var sample_count := maxi(1, int(SAMPLE_RATE * duration))
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = 888
	var filtered_noise := 0.0
	for index in range(sample_count):
		var t := float(index) / float(SAMPLE_RATE)
		var progress := t / duration
		var envelope := pow(maxf(0.0, 1.0 - progress), 2.4)
		filtered_noise = lerpf(filtered_noise, local_rng.randf_range(-1.0, 1.0), 0.22)
		var subterranean_rumble := sin(TAU * (58.0 - 22.0 * progress) * t)
		var grit := local_rng.randf_range(-1.0, 1.0) * pow(progress, 1.4) * (1.0 - progress) * 0.6
		samples[index] = clampf((filtered_noise * 0.42 + subterranean_rumble * 0.48 + grit) * envelope * 0.82, -1.0, 1.0)
	return _make_wav(samples)

func _make_upgrade_stream(duration: float) -> AudioStreamWAV:
	var sample_count := maxi(1, int(SAMPLE_RATE * duration))
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	for index in range(sample_count):
		var t := float(index) / float(SAMPLE_RATE)
		var progress := t / duration
		var frequency := lerpf(360.0, 1180.0, progress * progress)
		var rise := sin(TAU * frequency * t)
		var shimmer := 0.45 * sin(TAU * frequency * 1.5 * t) + 0.22 * sin(TAU * frequency * 2.0 * t)
		var envelope := sin(PI * clampf(progress, 0.0, 1.0))
		var finish := sin(TAU * 1480.0 * t) * pow(clampf((progress - 0.68) / 0.32, 0.0, 1.0), 2.0) * (1.0 - progress)
		samples[index] = clampf((rise + shimmer) * envelope * 0.32 + finish * 0.42, -1.0, 1.0)
	return _make_wav(samples)

func _make_anomaly_reveal_stream(duration: float) -> AudioStreamWAV:
	var sample_count := maxi(1, int(SAMPLE_RATE * duration))
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var frequencies := [329.63, 440.0, 659.25, 880.0, 1318.51]
	for index in range(sample_count):
		var t := float(index) / float(SAMPLE_RATE)
		var progress := t / duration
		var drone := sin(TAU * 110.0 * t) * 0.25 * pow(maxf(0.0, 1.0 - progress), 1.2)
		var shimmer := 0.0
		for i in range(frequencies.size()):
			var start := float(i) * 0.04
			var local_t := t - start
			if local_t < 0.0:
				continue
			var freq: float = frequencies[i] * (1.0 + 0.006 * sin(TAU * 6.5 * local_t))
			var env := pow(maxf(0.0, 1.0 - local_t / (duration - start)), 2.2)
			shimmer += (sin(TAU * freq * local_t) + 0.3 * sin(TAU * freq * 2.0 * local_t)) * env
		var mix := (drone + shimmer * 0.28) * 0.75
		samples[index] = clampf(mix, -1.0, 1.0)
	return _make_wav(samples)

func _make_relic_activated_stream(duration: float) -> AudioStreamWAV:
	var sample_count := maxi(1, int(SAMPLE_RATE * duration))
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var chords := [130.81, 196.0, 261.63, 392.0]
	for index in range(sample_count):
		var t := float(index) / float(SAMPLE_RATE)
		var progress := t / duration
		var attack := clampf(progress / 0.15, 0.0, 1.0)
		var release := pow(clampf((1.0 - progress) / 0.75, 0.0, 1.0), 1.8)
		var env := attack * release
		var brass := 0.0
		for root_freq in chords:
			brass += sin(TAU * root_freq * t) + 0.4 * sin(TAU * root_freq * 2.0 * t) + 0.2 * sin(TAU * root_freq * 3.0 * t)
		var sparkle_freq := lerpf(880.0, 1760.0, pow(progress, 0.7))
		var sparkle := sin(TAU * sparkle_freq * t) * (1.0 + sin(TAU * 18.0 * t) * 0.5) * env * 0.35
		var mix := (brass * 0.25 + sparkle) * env * 0.85
		samples[index] = clampf(mix, -1.0, 1.0)
	return _make_wav(samples)

func _make_error_stream(duration: float) -> AudioStreamWAV:
	var sample_count := maxi(1, int(SAMPLE_RATE * duration))
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	for index in range(sample_count):
		var t := float(index) / float(SAMPLE_RATE)
		var progress := t / duration
		var frequency := 210.0 if progress < 0.48 else 145.0
		var envelope := pow(maxf(0.0, 1.0 - progress), 1.5)
		var square_wave := 1.0 if sin(TAU * frequency * t) >= 0.0 else -1.0
		samples[index] = square_wave * envelope * 0.24
	return _make_wav(samples)

func _make_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for index in range(samples.size()):
		var pcm := int(clampf(samples[index], -1.0, 1.0) * 32767.0)
		data[index * 2] = pcm & 0xff
		data[index * 2 + 1] = (pcm >> 8) & 0xff
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.set_data(data)
	return wav
