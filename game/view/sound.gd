extends Node
var volume := 0.45
var player := AudioStreamPlayer.new()
var playback: AudioStreamGeneratorPlayback
var voices: Array[Dictionary] = []
const SAMPLE_RATE := 22050.0

func _ready() -> void:
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = SAMPLE_RATE
	stream.buffer_length = 0.08
	player.stream = stream
	add_child(player)
	player.play()
	playback = player.get_stream_playback()

func play_event(event: String) -> void:
	var frequency := 0.0
	var duration := 0.08
	match event:
		"gold": frequency = 1250
		"jump": frequency = 240; duration = 0.055
		"switch": frequency = 560; duration = 0.13
		"death": frequency = 80; duration = 0.25
		"win": frequency = 880; duration = 0.3
	if frequency > 0 and voices.size() < 12:
		voices.append({"frequency": frequency, "duration": duration, "time": 0.0, "phase": 0.0})

func _exit_tree() -> void:
	player.stop()
	playback = null

func _process(_delta: float) -> void:
	if playback == null:
		return
	var frames := playback.get_frames_available()
	var buffer := PackedVector2Array()
	buffer.resize(frames)
	for i in range(frames):
		var value := 0.0
		for j in range(voices.size() - 1, -1, -1):
			var voice := voices[j]
			voice.time += 1.0 / SAMPLE_RATE
			if voice.time >= voice.duration:
				voices.remove_at(j)
				continue
			var envelope: float = pow(1 - voice.time / voice.duration, 2)
			voice.phase += TAU * voice.frequency / SAMPLE_RATE
			value += sin(voice.phase) * envelope * 0.12 * volume
		buffer[i] = Vector2.ONE * clampf(value, -0.8, 0.8)
	playback.push_buffer(buffer)
