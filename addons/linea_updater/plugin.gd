@tool
extends EditorPlugin
var exporter: EditorExportPlugin

func _enter_tree() -> void:
	exporter = AndroidExporter.new()
	add_export_plugin(exporter)

func _exit_tree() -> void:
	remove_export_plugin(exporter)
	exporter = null

class AndroidExporter extends EditorExportPlugin:
	func _get_name() -> String:
		return "LineaUpdater"
	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid
	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		var path := "res://addons/linea_updater/bin/linea-updater.aar"
		return PackedStringArray([path]) if FileAccess.file_exists(path) else PackedStringArray()
