extends Node
## Original audio rendered offline; Android never builds PCM buffers at launch.
const KINDS := ["wind","drone","step","scratch","trap","door","echo","ui"]
var tracks: Dictionary = {}
var wind: AudioStreamPlayer
var drone: AudioStreamPlayer
var effects: AudioStreamPlayer
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 48217
	for kind in KINDS:
		var stream: AudioStreamOggVorbis = load("res://audio/%s.ogg" % kind)
		stream.loop = kind == "wind" or kind == "drone"
		tracks[kind] = stream
	wind = AudioStreamPlayer.new()
	drone = AudioStreamPlayer.new()
	effects = AudioStreamPlayer.new()
	effects.max_polyphony = 8
	add_child(wind)
	add_child(drone)
	add_child(effects)
	wind.stream = tracks.wind
	drone.stream = tracks.drone
	apply_volumes()

func start_ambience() -> void:
	if not wind.playing:
		wind.play()
	if not drone.playing:
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
	tracks.clear()

func play(kind: String) -> void:
	if not effects or not tracks.has(kind):
		return
	effects.stream = tracks[kind]
	effects.pitch_scale = rng.randf_range(0.9, 1.1) if kind == "step" else 1.0
	effects.play()
