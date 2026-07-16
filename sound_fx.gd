extends Node

const SAMPLE_RATE := 22050
const PLAYER_COUNT := 16

var _players: Array[AudioStreamPlayer] = []
var _cursor := 0
var _rng := RandomNumberGenerator.new()
var _streams := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	for index in range(PLAYER_COUNT):
		var player := AudioStreamPlayer.new()
		player.name = "SFXPlayer%d" % index
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_players.append(player)
	_build_streams()

func _build_streams() -> void:
	_streams["dig_soft"] = _make_impact_stream(0.085, 118.0, 0.48, 101)
	_streams["dig_hard"] = _make_impact_stream(0.095, 185.0, 0.34, 202)
	_streams["block_break"] = _make_break_stream(0.19, 303)
	_streams["gem_found"] = _make_chime_stream([760.0, 1060.0], 0.18, 0.075)
	_streams["purchase"] = _make_chime_stream([520.0, 780.0], 0.16, 0.065)
	_streams["deposit"] = _make_chime_stream([650.0, 880.0, 1120.0], 0.20, 0.055)
	_streams["upgrade"] = _make_upgrade_stream(0.42)
	_streams["error"] = _make_error_stream(0.18)

func play_dig_hit(block_id: int = 0) -> void:
	var stream_name := "dig_hard" if block_id == 2 or block_id == 3 else "dig_soft"
	_play(stream_name, -16.0, 0.05)

func play_block_break(has_gem: bool = false) -> void:
	_play("block_break", -9.0, 0.035)
	if has_gem:
		_play("gem_found", -2.0, 0.025)

func play_purchase() -> void:
	_play("purchase", -3.0, 0.025)

func play_upgrade() -> void:
	_play("upgrade", -1.5, 0.018)

func play_error() -> void:
	_play("error", -5.0, 0.012)

func play_deposit(amount: int = 1) -> void:
	var amount_pitch := clampf(float(maxi(amount, 1) - 1) * 0.025, 0.0, 0.18)
	_play("deposit", -4.0, 0.02, amount_pitch)

func play_level_up() -> void:
	_play("upgrade", 0.0, 0.0, 0.08)

func _play(stream_name: String, volume_db: float, pitch_variation: float, pitch_offset: float = 0.0) -> void:
	if not _streams.has(stream_name) or _players.is_empty():
		return
	var selected: AudioStreamPlayer = null
	for step in range(_players.size()):
		var candidate := _players[(_cursor + step) % _players.size()]
		if not candidate.playing:
			selected = candidate
			_cursor = (_cursor + step + 1) % _players.size()
			break
	if selected == null:
		selected = _players[_cursor]
		_cursor = (_cursor + 1) % _players.size()
	selected.stop()
	selected.stream = _streams[stream_name]
	selected.volume_db = volume_db
	selected.pitch_scale = maxf(0.25, 1.0 + pitch_offset + _rng.randf_range(-pitch_variation, pitch_variation))
	selected.play()

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
