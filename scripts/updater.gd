extends Node
## Public GitHub releases only. No token, credentials or arbitrary download URLs.
signal changed
const REPOSITORY := "emanoelb5-lgtm/the-last-Linea"
const RELEASES_URL := "https://github.com/" + REPOSITORY + "/releases"
const API_URL := "https://api.github.com/repos/" + REPOSITORY + "/releases/latest"
const DOWNLOAD_PREFIX := RELEASES_URL + "/download/"
const MAX_APK_BYTES := 250 * 1024 * 1024
const PART_PATH := "user://updates/TheLastLinea.apk.part"
const APK_PATH := "user://updates/TheLastLinea.apk"
var current_code: int = 1
var status_text := "Você pode buscar uma nova versão aqui."
var busy := false
var available := false
var ready_to_install := false
var request: HTTPRequest
var phase := ""
var manifest: Dictionary = {}
var expected_asset_url := ""
var expected_size := 0
var progress_clock := 0.0

func _ready() -> void:
	var version_file: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://version.json"))
	if version_file is Dictionary:
		current_code = int(version_file.get("version_code",1))
	request = HTTPRequest.new()
	request.timeout = 25
	request.body_size_limit = 1024*1024
	request.max_redirects = 5
	add_child(request)
	request.request_completed.connect(on_response)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://updates"))
	# A partial download is never treated as an installable update.
	if FileAccess.file_exists(PART_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PART_PATH))

func set_status(text_value: String) -> void:
	status_text = text_value
	changed.emit()

func fail(text_value: String) -> void:
	busy = false
	phase = ""
	request.download_file = ""
	if FileAccess.file_exists(PART_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PART_PATH))
	set_status(text_value)

func check() -> void:
	if busy:
		return
	available = false
	ready_to_install = false
	manifest.clear()
	busy = true
	phase = "release"
	request.timeout = 25
	request.download_file = ""
	request.body_size_limit = 1024*1024
	set_status("Buscando a release mais recente…")
	var err := request.request(API_URL,PackedStringArray(["Accept: application/vnd.github+json","User-Agent: TheLastLinea-Android"]))
	if err != OK:
		fail("Não foi possível conectar. Verifique sua internet e tente novamente.")

func trusted_download(url: String) -> bool:
	return url.begins_with(DOWNLOAD_PREFIX) and not url.contains("..") and not url.contains("?") and not url.contains("#") and not url.contains("\\")

func validate_manifest(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if typeof(data.get("version_code")) not in [TYPE_INT,TYPE_FLOAT]:
		return false
	if float(data.version_code) != int(data.version_code) or int(data.version_code) < 1:
		return false
	var hash_value := str(data.get("sha256",""))
	var regex := RegEx.new()
	regex.compile("^[a-f0-9]{64}$")
	var size_value := int(data.get("size",0))
	var url := str(data.get("apk_url",""))
	return regex.search(hash_value) != null and size_value > 100000 and size_value <= MAX_APK_BYTES and trusted_download(url) and url.ends_with("/TheLastLinea.apk") and url == expected_asset_url and size_value == expected_size

func on_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		if response_code == 404 and phase == "release":
			fail("A primeira release ainda está sendo preparada. Tente novamente mais tarde.")
		elif response_code == 403 or response_code == 429:
			fail("O GitHub limitou as consultas por enquanto. Tente novamente em alguns minutos.")
		else:
			fail("A conexão foi interrompida. Seu jogo está salvo; você pode tentar novamente.")
		return
	if phase == "release":
		var release: Variant = JSON.parse_string(body.get_string_from_utf8())
		if not release is Dictionary or not release.get("assets") is Array or bool(release.get("draft",true)) or bool(release.get("prerelease",true)):
			fail("O GitHub retornou uma release inválida.")
			return
		var manifest_url := ""
		expected_asset_url = ""
		expected_size = 0
		for asset in release.assets:
			if not asset is Dictionary:
				continue
			if asset.get("name") == "update.json":
				manifest_url = str(asset.get("browser_download_url",""))
			elif asset.get("name") == "TheLastLinea.apk":
				expected_asset_url = str(asset.get("browser_download_url",""))
				expected_size = int(asset.get("size",0))
		if not trusted_download(manifest_url) or not trusted_download(expected_asset_url):
			fail("Esta release ainda não tem todos os arquivos de atualização.")
			return
		phase = "manifest"
		var err := request.request(manifest_url,PackedStringArray(["User-Agent: TheLastLinea-Android"]))
		if err != OK:
			fail("Não foi possível ler os dados da atualização.")
	elif phase == "manifest":
		var data: Variant = JSON.parse_string(body.get_string_from_utf8())
		if not validate_manifest(data):
			fail("Os dados da atualização não passaram pela verificação.")
			return
		busy = false
		phase = ""
		if int(data.version_code) <= current_code:
			set_status("Você já está na versão mais recente disponível.")
			return
		manifest = data
		available = true
		set_status("Nova versão: %s · %.1f MB. Seu progresso será mantido." % [str(data.get("version","")),float(data.size)/1048576.0])
	elif phase == "download":
		request.download_file = ""
		if not FileAccess.file_exists(PART_PATH):
			fail("O download não foi concluído. Tente novamente.")
			return
		var file := FileAccess.open(PART_PATH,FileAccess.READ)
		if file == null:
			fail("Não foi possível abrir o arquivo baixado.")
			return
		var size_value := file.get_length()
		file.close()
		set_status("Conferindo a integridade do APK…")
		if size_value != int(manifest.size) or FileAccess.get_sha256(PART_PATH) != str(manifest.sha256):
			fail("O arquivo chegou incompleto ou diferente do esperado. Baixe novamente.")
			return
		var rename := DirAccess.rename_absolute(ProjectSettings.globalize_path(PART_PATH),ProjectSettings.globalize_path(APK_PATH))
		if rename != OK:
			fail("Não há espaço para preparar a atualização.")
			return
		busy = false
		phase = ""
		ready_to_install = true
		set_status("Download verificado. Toque em Instalar atualização para continuar.")

func download() -> void:
	if busy or not available or manifest.is_empty():
		return
	busy = true
	phase = "download"
	request.timeout = 300
	request.body_size_limit = MAX_APK_BYTES
	request.download_file = PART_PATH
	set_status("Baixando atualização… 0%")
	var err := request.request(str(manifest.apk_url),PackedStringArray(["User-Agent: TheLastLinea-Android"]))
	if err != OK:
		fail("Não foi possível iniciar o download. Tente novamente.")

func _process(delta: float) -> void:
	if phase != "download" or not busy:
		return
	progress_clock += delta
	if progress_clock > 0.4:
		progress_clock = 0
		var percent := clampi(roundi(float(request.get_downloaded_bytes()) / maxf(1.0,float(manifest.get("size",1)))*100),0,100)
		set_status("Baixando atualização… %d%%" % percent)

func install() -> void:
	if not ready_to_install or not FileAccess.file_exists(APK_PATH):
		return
	if Engine.has_singleton("LineaUpdater"):
		var native := Engine.get_singleton("LineaUpdater")
		var result: int = native.installApk(ProjectSettings.globalize_path(APK_PATH))
		if result == 1:
			set_status("Ative ‘Permitir desta fonte’ para este jogo, volte aqui e toque em Instalar atualização novamente.")
		elif result == 0:
			set_status("O instalador do Android foi aberto. Confirme a atualização para concluir.")
		else:
			set_status("O Android não conseguiu abrir este APK (código %d). Você também pode baixá-lo pela página de releases." % result)
	elif OS.has_feature("android"):
		set_status("O instalador não está disponível nesta compilação. Abrindo o download oficial no navegador.")
		OS.shell_open(str(manifest.apk_url))
	else:
		set_status("APK verificado. A instalação desta versão é feita em um aparelho Android.")
