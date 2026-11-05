extends Node
## Original synthesized ambience and foley; no external recordings.
var wind: AudioStreamPlayer
var drone: AudioStreamPlayer
var effects: AudioStreamPlayer
var cache: Dictionary = {}
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 48217
	wind = AudioStreamPlayer.new()
	drone = AudioStreamPlayer.new()
	effects = AudioStreamPlayer.new()
	effects.max_polyphony = 8
	add_child(wind)
	add_child(drone)
	add_child(effects)
	wind.stream = synth("wind", 5.0, true)
	drone.stream = synth("drone", 8.0, true)
	apply_volumes()
	wind.play()
	drone.play()

func apply_volumes() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(State.settings.master), 0.0001)))
	if wind:
		wind.volume_db = linear_to_db(maxf(float(State.settings.ambience) * 0.22, 0.0001))
		drone.volume_db = linear_to_db(maxf(float(State.settings.ambience) * 0.12, 0.0001))
		effects.volume_db = linear_to_db(maxf(float(State.settings.effects) * 0.6, 0.0001))

func _exit_tree() -> void:
	for player in [wind,drone,effects]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	cache.clear()

func play(kind: String) -> void:
	if not effects:
		return
	if not cache.has(kind):
		var duration := 0.14 if kind == "step" else 0.55
		if kind == "door" or kind == "echo":
			duration = 1.6
		cache[kind] = synth(kind, duration)
	effects.stream = cache[kind]
	effects.pitch_scale = rng.randf_range(0.9, 1.1) if kind == "step" else 1.0
	effects.play()

func synth(kind: String, duration: float, loop: bool = false) -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var smooth := 0.0
	for i in count:
		var t := float(i) / rate
		var noise := rng.randf_range(-1.0, 1.0)
		smooth = lerpf(smooth, noise, 0.025)
		var sample := 0.0
		var envelope := pow(1.0 - float(i) / count, 2.0)
		match kind:
			"wind": sample = smooth * (0.6 + 0.3 * sin(TAU * t / duration))
			"drone": sample = sin(TAU * 55.0 * t) * 0.23 + sin(TAU * 82.5 * t) * 0.16 + sin(TAU * 110.0 * t) * 0.08
			"step": sample = (noise * 0.3 + sin(TAU * 100 * t) * 0.6) * envelope * 0.4
			"scratch": sample = noise * envelope * (0.4 + 0.3 * sin(t * 190))
			"trap": sample = (sin(TAU * 180 * t) + sin(TAU * 311 * t) * 0.4 + noise * 0.4) * envelope * 0.5
			"door": sample = (sin(TAU * (80 + t * 70) * t) * 0.4 + smooth) * sin(PI * t / duration)
			"echo": sample = (sin(TAU * 440 * t) + sin(TAU * 660 * t) * 0.4) * envelope * 0.35
			_: sample = sin(TAU * 330 * t) * envelope * 0.2
		# Fade loop edges to suppress discontinuities.
		if loop:
			sample *= minf(1.0, minf(t, duration - t) * 8.0)
		var pcm := int(clampf(sample, -1.0, 1.0) * 24000)
		bytes.encode_s16(i * 2, pcm)
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = rate
	audio.data = bytes
	if loop:
		audio.loop_mode = AudioStreamWAV.LOOP_FORWARD
		audio.loop_end = count
	return audio
