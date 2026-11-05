extends Node
## Local, versioned, atomic saves. No account or network required to play.
signal changed
const SAVE_PATH := "user://chapter_1.json"
const SETTINGS_PATH := "user://settings.cfg"
const SCHEMA := 1
const MAP_LIMIT := 73.0
var health: int = 100
var xp: int = 0
var marks: Array[int] = []
var echoes: Array[int] = []
var disarmed: Array[int] = []
var mountain_found: bool = false
var mountain_angle: float = 0.0
var completed: bool = false
var intro_seen: bool = false
var last_position := Vector3.ZERO
var settings := {"master": 0.8, "ambience": 0.8, "effects": 0.9, "sensitivity": 1.0,
	"quality": 1, "fps": 60, "show_fps": false, "touch_scale": 1.0}
var save_error := ""

func _ready() -> void:
	load_settings()
	load_game()
	Engine.max_fps = int(settings.fps)

func level() -> int:
	return 1 + xp / 100

func add_xp(amount: int) -> void:
	xp += maxi(amount, 0)
	changed.emit()

func new_game() -> void:
	health = 100
	xp = 0
	marks.clear()
	echoes.clear()
	disarmed.clear()
	mountain_found = false
	mountain_angle = 0.0
	completed = false
	intro_seen = false
	last_position = Vector3.ZERO
	save_game()
	changed.emit()

func to_data() -> Dictionary:
	return {"schema": SCHEMA, "health": health, "xp": xp, "marks": marks,
		"echoes": echoes, "disarmed": disarmed, "mountain_found": mountain_found,
		"mountain_angle": mountain_angle, "completed": completed, "intro_seen": intro_seen,
		"position": [last_position.x, last_position.y, last_position.z]}

func save_game() -> bool:
	var file := FileAccess.open(SAVE_PATH + ".tmp", FileAccess.WRITE)
	if file == null:
		save_error = "Não foi possível salvar o progresso. Verifique o espaço disponível."
		return false
	file.store_string(JSON.stringify(to_data()))
	file.flush()
	file.close()
	var result := DirAccess.rename_absolute(ProjectSettings.globalize_path(SAVE_PATH + ".tmp"),
		ProjectSettings.globalize_path(SAVE_PATH))
	if result != OK:
		save_error = "Não foi possível gravar o progresso."
		return false
	save_error = ""
	return true

func has_save() -> bool:
	return intro_seen

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not data is Dictionary or int(data.get("schema", 0)) != SCHEMA:
		save_error = "O salvamento está ilegível. Você pode iniciar um novo capítulo."
		return
	apply_data(data)

func apply_data(data: Dictionary) -> void:
	health = clampi(int(data.get("health", 100)), 1, 100)
	xp = clampi(int(data.get("xp", 0)), 0, 100000)
	marks = valid_ids(data.get("marks", []), 239)
	echoes = valid_ids(data.get("echoes", []), 2)
	disarmed = valid_ids(data.get("disarmed", []), 13)
	mountain_found = bool(data.get("mountain_found", false))
	mountain_angle = float(data.get("mountain_angle", 0.0))
	if not is_finite(mountain_angle):
		mountain_angle = 0.0
	completed = bool(data.get("completed", false))
	intro_seen = bool(data.get("intro_seen", false))
	var pos: Variant = data.get("position", [0, 0, 0])
	last_position = Vector3.ZERO
	if pos is Array and pos.size() == 3:
		var candidate := Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
		if candidate.is_finite() and Vector2(candidate.x, candidate.z).length() < MAP_LIMIT:
			last_position = Vector3(candidate.x, clampf(candidate.y, 0.0, 4.0), candidate.z)

func valid_ids(value: Variant, maximum: int) -> Array[int]:
	var result: Array[int] = []
	if value is Array:
		for item in value:
			if (item is int or item is float) and float(item) == int(item):
				var id := int(item)
				if id >= 0 and id <= maximum and not result.has(id):
					result.append(id)
	return result

func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in settings:
		cfg.set_value("game", key, settings[key])
	cfg.save(SETTINGS_PATH)
	Engine.max_fps = int(settings.fps)
	if is_instance_valid(Sound):
		Sound.apply_volumes()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for key in settings:
		var value: Variant = cfg.get_value("game", key, settings[key])
		if typeof(value) == typeof(settings[key]) or (value is float and settings[key] is int):
			settings[key] = value
	settings.master = clampf(float(settings.master), 0.0, 1.0)
	settings.ambience = clampf(float(settings.ambience), 0.0, 1.0)
	settings.effects = clampf(float(settings.effects), 0.0, 1.0)
	settings.sensitivity = clampf(float(settings.sensitivity), 0.3, 2.5)
	settings.touch_scale = clampf(float(settings.touch_scale), 0.8, 1.3)
	settings.quality = clampi(int(settings.quality), 0, 2)
	settings.fps = 30 if int(settings.fps) < 45 else 60
