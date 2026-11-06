extends Node
func shot(name_value: String) -> void:
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png("res://build/captures/"+name_value+".png")
	print("POSE_CAPTURE ",name_value," ",error)

func _ready() -> void:
	State.new_game()
	var game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	await get_tree().create_timer(0.3).timeout
	game.set_process(false)
	game.start_game(true)
	game.player.enabled = false
	for item in [[0.5,"11-deitado"],[3.4,"12-apoiando"],[5.0,"13-sentado"],[6.8,"14-ajoelhado"],[9.2,"15-levantando"],[11.8,"16-onde-estou"]]:
		game.intro_clock = 0
		game.process_intro(item[0])
		print("POSE ",item[0]," hip ",game.player.model.position," phase ",game.player.wake_phase," ankle ",game.player.feet[0].global_position)
		await shot(item[1])
	game.finish_intro()
	game.player.enabled = false
	game.toast_time = 0
	game.toast_label.visible = false
	game.cam_pitch = 0.12
	game.camera_target = game.player.position+Vector3(0,1.28,0)
	game.camera.position = game.player.position+Vector3(0,0.68,5.7)
	game.update_camera(1)
	game.update_interaction()
	await shot("03-exploracao")
	game.clear_overlay()
	game.hud.visible = false
	game.player.stand_pose()
	game.camera.fov = 38
	game.camera.position = Vector3(1.45,1.4,-3.2)
	game.camera.look_at(Vector3(0,1.0,0))
	await shot("08-personagem-jovem")
	game.camera.fov = 58
	game.player.position = Vector3(0,0,-LineaForest.MOUNTAIN_RADIUS)
	game.forest.update_streaming(game.player.position,true)
	game.camera_target = game.player.position+Vector3(0,1.28,0)
	game.camera.position = game.player.position+Vector3(0,0.68,5.7)
	game.update_camera(1)
	game.process_game(0)
	await get_tree().create_timer(2.0).timeout
	await shot("17-pe-da-montanha")
	game.queue_free()
	await get_tree().process_frame
	get_tree().quit()
