extends Node

var current_music_scene: String = ""
var music_player: AudioStreamPlayer
var master_volume_db: float = -10.0

func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "ProceduralMusicPlayer"
	music_player.volume_db = -22.0
	add_child(music_player)

func play_music(scene: String) -> void:
	if current_music_scene == scene and music_player.playing:
		return
	current_music_scene = scene
	var base_freq: float = 146.83
	if scene == "gameplay":
		base_freq = 196.0
	elif scene == "win":
		base_freq = 261.63
	elif scene == "lose":
		base_freq = 185.0
	music_player.stop()
	music_player.stream = _make_loop_stream(base_freq, scene)
	music_player.play()

func stop_music() -> void:
	if is_instance_valid(music_player):
		music_player.stop()

func play_sfx(id: String) -> void:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.volume_db = master_volume_db
	add_child(player)
	player.stream = _make_sfx_stream(id)
	player.finished.connect(Callable(player, "queue_free"))
	player.play()

func _make_loop_stream(base_freq: float, scene: String) -> AudioStreamWAV:
	var rate: int = 22050
	var seconds: float = 4.0
	if scene == "win" or scene == "lose":
		seconds = 2.0
	var frames: int = int(rate * seconds)
	var data: PackedByteArray = PackedByteArray()
	data.resize(frames * 2)
	var chord: Array[float] = [1.0, 1.2, 1.5, 2.0]
	if scene == "gameplay":
		chord = [1.0, 1.189, 1.334, 1.782]
	elif scene == "lose":
		chord = [1.0, 1.06, 1.414]
	for i in range(frames):
		var t: float = float(i) / float(rate)
		var pulse: float = 0.55 + 0.45 * sin(TAU * 0.85 * t)
		var sample: float = 0.0
		for m in chord:
			sample += sin(TAU * base_freq * m * t) * 0.08
		sample += sin(TAU * base_freq * 0.5 * t) * 0.12 * pulse
		if scene == "gameplay":
			sample += sin(TAU * base_freq * 2.0 * t) * 0.035 * (0.5 + 0.5 * sin(TAU * 3.2 * t))
		var v: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, v)
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = frames
	return wav

func _make_sfx_stream(id: String) -> AudioStreamWAV:
	var rate: int = 44100
	var duration: float = 0.18
	var start_freq: float = 850.0
	var end_freq: float = 850.0
	if id == "match":
		duration = 0.18
		start_freq = 600.0
		end_freq = 1000.0
	elif id == "special_element":
		duration = 0.24
		start_freq = 1100.0
		end_freq = 1700.0
	elif id == "win":
		duration = 0.42
		start_freq = 523.25
		end_freq = 783.99
	elif id == "lose":
		duration = 0.32
		start_freq = 560.0
		end_freq = 300.0
	elif id == "booster":
		duration = 0.22
		start_freq = 392.0
		end_freq = 740.0
	elif id == "tap_button":
		duration = 0.09
		start_freq = 850.0
		end_freq = 850.0
	var frames: int = int(rate * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var p: float = float(i) / float(max(frames - 1, 1))
		var freq: float = lerpf(start_freq, end_freq, p)
		if id == "booster":
			var arp: Array[float] = [392.0, 493.88, 587.33, 739.99]
			freq = arp[min(int(p * 4.0), 3)]
		var env: float = min(p / 0.08, 1.0) * pow(1.0 - p, 1.7)
		if id == "tap_button":
			env = pow(1.0 - p, 2.0)
		var wave: float = sin(TAU * freq * float(i) / float(rate))
		if id == "tap_button" or id == "booster":
			wave = asin(sin(TAU * freq * float(i) / float(rate))) * 0.6366
		if id == "win":
			wave = (sin(TAU * 523.25 * float(i) / float(rate)) + sin(TAU * 659.25 * float(i) / float(rate)) + sin(TAU * 783.99 * float(i) / float(rate))) / 3.0
		var v: int = clampi(int(wave * env * 22000.0), -32768, 32767)
		data.encode_s16(i * 2, v)
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
