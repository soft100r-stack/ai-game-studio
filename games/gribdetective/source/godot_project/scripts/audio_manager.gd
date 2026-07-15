extends Node

var sfx_player: AudioStreamPlayer
var music_player: AudioStreamPlayer
var current_music: String = ''

func _ready() -> void:
	sfx_player = AudioStreamPlayer.new()
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -18.0
	sfx_player.volume_db = -7.0
	add_child(sfx_player)
	add_child(music_player)

func play_sfx(id: String) -> void:
	if sfx_player == null:
		return
	var stream: AudioStreamWAV
	match id:
		'match':
			stream = _make_tone(600.0, 1000.0, 0.18, 0.55)
		'tap_button':
			stream = _make_tone(850.0, 820.0, 0.09, 0.35)
		'special_element':
			stream = _make_chord([1100.0, 1400.0, 1700.0], 0.18, 0.45)
		'win':
			stream = _make_chord([523.25, 659.25, 783.99], 0.35, 0.55)
		'lose':
			stream = _make_tone(560.0, 300.0, 0.28, 0.45)
		'booster':
			stream = _make_chord([392.0, 493.88, 587.33, 739.99], 0.18, 0.45)
		_:
			stream = _make_tone(600.0, 600.0, 0.08, 0.25)
	if stream != null:
		sfx_player.stream = stream
		sfx_player.play()

func play_music(scene: String) -> void:
	if music_player == null or current_music == scene:
		return
	current_music = scene
	var base: float = 146.83
	if scene == 'gameplay':
		base = 196.0
	elif scene == 'win':
		base = 261.63
	elif scene == 'lose':
		base = 185.0
	music_player.stream = _make_loop_drone(base, scene != 'win' and scene != 'lose')
	music_player.play()

func stop_music() -> void:
	if music_player != null:
		music_player.stop()
	current_music = ''

func _make_tone(start_hz: float, end_hz: float, duration: float, volume: float) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var frames: int = int(duration * float(sample_rate))
	var data: PackedByteArray = PackedByteArray()
	data.resize(frames * 2)
	for i: int in range(frames):
		var t: float = float(i) / float(sample_rate)
		var k: float = float(i) / max(1.0, float(frames - 1))
		var freq: float = lerpf(start_hz, end_hz, k)
		var env: float = sin(k * PI)
		var sample: int = int(sin(TAU * freq * t) * env * volume * 32767.0)
		data.encode_s16(i * 2, sample)
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav

func _make_chord(freqs: Array[float], duration: float, volume: float) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var frames: int = int(duration * float(sample_rate))
	var data: PackedByteArray = PackedByteArray()
	data.resize(frames * 2)
	for i: int in range(frames):
		var t: float = float(i) / float(sample_rate)
		var k: float = float(i) / max(1.0, float(frames - 1))
		var env: float = sin(k * PI)
		var mixed: float = 0.0
		for freq: float in freqs:
			mixed += sin(TAU * freq * t)
		mixed /= float(freqs.size())
		var sample: int = int(mixed * env * volume * 32767.0)
		data.encode_s16(i * 2, sample)
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav

func _make_loop_drone(base_hz: float, should_loop: bool) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 4.0
	var frames: int = int(duration * float(sample_rate))
	var data: PackedByteArray = PackedByteArray()
	data.resize(frames * 2)
	var freqs: Array[float] = [base_hz, base_hz * 1.5, base_hz * 2.0, base_hz * 2.25]
	for i: int in range(frames):
		var t: float = float(i) / float(sample_rate)
		var bar: float = fmod(t, 1.0)
		var env: float = 0.35 + 0.35 * sin(TAU * bar)
		var mixed: float = 0.0
		for freq: float in freqs:
			mixed += sin(TAU * freq * t) * 0.25
		mixed += sin(TAU * base_hz * 0.5 * t) * 0.35
		var sample: int = int(mixed * env * 0.35 * 32767.0)
		data.encode_s16(i * 2, sample)
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD if should_loop else AudioStreamWAV.LOOP_DISABLED
	wav.loop_begin = 0
	wav.loop_end = frames
	wav.data = data
	return wav
