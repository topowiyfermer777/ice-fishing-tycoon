extends Node

const SAMPLE_RATE := 22050
const POOL_SIZE := 16

var muted: bool = false
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_generate_all_sfx()

func set_muted(value: bool) -> void:
	muted = value

func toggle_muted() -> bool:
	muted = not muted
	return muted

func play(sfx_name: String, pitch_scale: float = 1.0, volume_db: float = -6.0) -> void:
	if muted:
		return
	var stream: AudioStreamWAV = _streams.get(sfx_name)
	if stream == null:
		return
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.stream = stream
	p.pitch_scale = clampf(pitch_scale + _rng.randf_range(-0.03, 0.03), 0.5, 2.2)
	p.volume_db = volume_db
	p.play()

func _generate_all_sfx() -> void:
	_streams["pick_hit"] = _make_pick_hit()
	_streams["ice_break"] = _make_ice_break()
	_streams["fish_whoosh"] = _make_whoosh()
	_streams["chop"] = _make_chop()
	_streams["pop"] = _make_pop()
	_streams["cash"] = _make_cash()
	_streams["pad_tick"] = _make_pad_tick()
	_streams["build"] = _make_build_fanfare()

func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		var v := clampi(int(clampf(samples[i], -1.0, 1.0) * 32767.0), -32768, 32767)
		bytes.encode_s16(i * 2, v)
	wav.data = bytes
	return wav

func _make_pick_hit() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.12)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 34.0)
		var tone := sin(TAU * 980.0 * t) * 0.5 + sin(TAU * 1470.0 * t) * 0.35
		var crunch := _rng.randf_range(-0.4, 0.4) * exp(-t * 60.0)
		s[i] = (tone + crunch) * env * 0.7
	return _to_wav(s)

func _make_ice_break() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.24)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 16.0)
		var noise := _rng.randf_range(-0.7, 0.7)
		var sparkle := sin(TAU * (1800.0 - t * 2400.0) * t) * 0.3
		s[i] = (noise + sparkle) * env * 0.75
	return _to_wav(s)

func _make_whoosh() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.18)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var env := sin(PI * (t / 0.18))
		var tone := sin(TAU * (360.0 + t * 1400.0) * t) * 0.4
		s[i] = (tone + _rng.randf_range(-0.15, 0.15)) * env * 0.45
	return _to_wav(s)

func _make_chop() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.09)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 48.0)
		var thud := sin(TAU * (190.0 * exp(-t * 14.0)) * t) * 0.75
		var snap := _rng.randf_range(-0.35, 0.35) * exp(-t * 80.0)
		s[i] = (thud + snap) * env * 0.75
	return _to_wav(s)

func _make_pop() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.11)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 28.0)
		var freq := 420.0 + t * 2800.0
		s[i] = sin(TAU * freq * t) * env * 0.55
	return _to_wav(s)

func _make_cash() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.18)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var f := 1046.5 if t < 0.07 else 1318.5
		var local_t := t if t < 0.07 else (t - 0.07)
		var env := exp(-local_t * 22.0)
		s[i] = (sin(TAU * f * t) * 0.6 + sin(TAU * f * 2.0 * t) * 0.2) * env * 0.5
	return _to_wav(s)

func _make_pad_tick() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.06)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var env := exp(-t * 42.0)
		s[i] = sin(TAU * 880.0 * t) * env * 0.45
	return _to_wav(s)

func _make_build_fanfare() -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * 0.42)
	var s := PackedFloat32Array()
	s.resize(n)
	var notes := [523.25, 659.25, 783.99, 1046.5]
	for i in range(n):
		var t := float(i) / SAMPLE_RATE
		var idx := mini(int(t / 0.09), 3)
		var local_t := t - float(idx) * 0.09
		var env := exp(-local_t * 11.0)
		var f: float = notes[idx]
		s[i] = (sin(TAU * f * t) * 0.55 + sin(TAU * f * 1.5 * t) * 0.2) * env * 0.65
	return _to_wav(s)
