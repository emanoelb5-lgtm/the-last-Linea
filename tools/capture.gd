extends Node
var destination := "res://build/captures"

func capture(name_value: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(destination+"/"+name_value+".png")
	print("CAPTURE: ",name_value," ",image.get_size()," error=",error)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination))
	State.new_game()
	var game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	await get_tree().create_timer(0.6).timeout
	game.set_process(false)
	game.camera.position = Vector3(8,4.8,10)
	game.camera.look_at(Vector3(0,0.8,0))
	await capture("01-menu")
	game.start_game(true)
	game.process_intro(6.5)
	await capture("02-abertura")
	game.finish_intro()
	game.player.position = Vector3(1.4,0,-0.7)
	game.camera_target = game.player.position+Vector3(0,1.15,0)
	game.camera.position = game.player.position+Vector3(0,5.5,8)
	game.update_camera(1.0)
	game.update_interaction()
	game.toast_time = 0
	game.toast_label.visible = false
	await capture("03-exploracao")
	game.player.position = game.forest.door_positions[0]+Vector3(0,0,4)
	game.camera.position = game.player.position+Vector3(6,4.8,7)
	game.camera.look_at(game.forest.door_positions[0]+Vector3(0,1.3,0))
	game.update_interaction()
	await capture("04-porta")
	game.show_settings("pause")
	await capture("05-configuracoes")
	game.queue_free()
	await get_tree().process_frame
	get_tree().quit()
