extends Node
var failures := 0
var checks := 0

func verify(condition: bool, title: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("CHECK FAILED: " + title)
	else:
		print("PASS: ",title)

func _ready() -> void:
	get_tree().root.size = Vector2i(1280,720)
	await get_tree().process_frame
	State.new_game()
	var game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	game.start_game(true)
	game.process_intro(9.5)
	verify(game.mode == "intro" and game.player.model.rotation.z < PI/2,"cutscene moves the camera and wakes the fallen man")
	var sight := PhysicsRayQueryParameters3D.create(game.camera.position,Vector3(0,0.8,0),1,[game.player.get_rid()])
	verify(game.forest.get_world_3d().direct_space_state.intersect_ray(sight).is_empty(),"waking cutscene keeps the man visible between the trees")
	game.finish_intro()
	verify(State.intro_seen and game.mode == "play","intro skip enters gameplay and persists")
	verify(game.forest.trees.size() == 240,"deterministic forest has all 240 markable trees")
	verify(game.forest.doors.size() == 4 and game.forest.traps.size() == 14,"doors and hazards are present")
	verify(game.forest.echo_positions.size() == 3,"three optional story memories")
	var contact := InputEventScreenTouch.new()
	contact.index = 0
	contact.position = Vector2(128,596)
	contact.pressed = true
	get_viewport().push_input(contact,true)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(160,570)
	drag.relative = Vector2(32,-26)
	get_viewport().push_input(drag,true)
	Input.flush_buffered_events()
	await get_tree().process_frame
	var second_contact := InputEventScreenTouch.new()
	second_contact.index = 1
	second_contact.position = game.dodge_button.get_global_rect().get_center()
	second_contact.pressed = true
	get_viewport().push_input(second_contact,true)
	Input.flush_buffered_events()
	await get_tree().process_frame
	verify(game.touch.movement.length() > 0.1 and game.player.dodge_cooldown > 0,"two fingers can hold movement and trigger a dodge simultaneously")
	var release: InputEventScreenTouch = contact.duplicate()
	var second_release: InputEventScreenTouch = second_contact.duplicate()
	release.pressed = false
	second_release.pressed = false
	get_viewport().push_input(release,true)
	get_viewport().push_input(second_release,true)
	Input.flush_buffered_events()
	game.touch.reset()
	game.player.dodge_time = 0
	game.player.dodge_cooldown = 0
	# Exercise actual CharacterBody movement and collisions via the InputMap.
	Input.action_press("forward")
	await get_tree().create_timer(0.7).timeout
	Input.action_release("forward")
	verify(game.player.position.z < -1.2,"WASD moves the physical player across the ground")
	game.player.position = game.forest.trees[0].position+Vector3(0,0,1.6)
	game.update_interaction()
	verify(game.interaction.get("type") == "tree","nearby trees can be selected")
	game.interact()
	var marked_xp: int = State.xp
	game.update_interaction()
	game.interact()
	verify(State.marks == [0] and State.xp == marked_xp,"tree marking is persistent and cannot farm XP")
	game.player.position = game.forest.trap_positions[0]+Vector3(0,0,2)
	game.update_interaction()
	game.interact()
	verify(State.disarmed.has(0) and game.forest.traps[0].disarmed,"trap can be disarmed from its safe edge")
	game.player.position = game.forest.trap_positions[1]
	game.update_hazards(0)
	verify(State.health == 72,"walking onto live spikes damages health")
	game.player.position = game.forest.trap_positions[2]
	game.player.input_vector = Vector2(1,0)
	game.player.dodge()
	game.update_hazards(0)
	verify(State.health == 72,"timed dodge protects against a trap")
	game.player.dodge_time = 0
	game.player.position = game.forest.echo_positions[0]+Vector3(0,0,1)
	game.update_interaction()
	game.interact()
	verify(State.echoes.has(0) and game.mode == "note","story stone grants a memory and pauses gameplay")
	game.resume_game()
	# Cross a doorway's plane, rather than triggering it by mere proximity.
	var door: Node3D = game.forest.doors[0]
	game.player.position = door.to_global(Vector3(0,0,0.3))
	game.update_hazards(0)
	game.player.position = door.to_global(Vector3(0,0,-0.3))
	game.update_hazards(0)
	verify(game.mode == "transition","crossing a door begins the return transition")
	await get_tree().create_timer(1.3).timeout
	verify(game.mode == "play" and game.player.position.length() < 1.0,"door returns to the original clearing")
	verify(State.health == 72 and State.marks.has(0) and State.echoes.has(0),"door preserves health, marks and discoveries")
	# Check the core story promise in eight directions around the entire map.
	for i in 8:
		if is_instance_valid(game.forest.exit_node):
			game.forest.exit_node.free()
			game.forest.exit_node = null
		State.mountain_found = false
		var a := i*TAU/8
		var direction := Vector3(sin(a),0,cos(a))
		game.player.position = direction*59
		game.process_game(0)
		verify(State.mountain_found and game.forest.exit_position.normalized().dot(direction) > 0.99,"mountain and chapter exit can be discovered in direction %d" % i)
	var before_xp: int = State.xp
	game.process_game(0)
	verify(State.xp == before_xp,"mountain discovery awards XP once")
	game.player.position = Vector3.ZERO
	game.update_interaction()
	game.interact()
	verify(State.health == 100,"resting in the clearing restores health")
	game.snapshot()
	var before_save := State.to_data().duplicate(true)
	State.marks.clear()
	State.echoes.clear()
	State.load_game()
	verify(State.marks == before_save.marks and State.echoes == before_save.echoes and State.xp == before_save.xp,"save/load roundtrip restores gameplay progress")
	game.player.position = game.forest.exit_position+Vector3(0,0,1)
	var before_ending: int = State.xp
	await game.finish_chapter()
	verify(State.completed and State.xp == before_ending+60,"chapter ending is reachable and grants its first-completion reward")
	game.resume_game()
	await game.finish_chapter()
	verify(State.xp == before_ending+60,"replaying the ending does not farm XP")
	game.resume_game()
	game.show_settings("pause")
	verify(is_instance_valid(game.update_button),"settings exposes the GitHub updater")
	game.settings_back()
	verify(game.mode == "pause","settings returns to pause without restarting the chapter")
	State.apply_data({"health":-3,"xp":-50,"marks":[0,0,-1,999,"bad"],"position":[10000,0,0]})
	verify(State.health == 1 and State.xp == 0 and State.marks == [0] and State.last_position == Vector3.ZERO,"malformed save values are bounded and deduplicated")
	var url := Updates.DOWNLOAD_PREFIX + "v0.2.0/TheLastLinea.apk"
	Updates.expected_asset_url = url
	Updates.expected_size = 200000
	var valid := {"version_code":1002,"version":"0.2.0","size":200000,"sha256":"a".repeat(64),"apk_url":url}
	verify(Updates.validate_manifest(valid),"valid same-repository release manifest is accepted")
	var wrong := valid.duplicate()
	wrong.apk_url = "https://github.com/attacker/other/releases/download/x/TheLastLinea.apk"
	verify(not Updates.validate_manifest(wrong),"updater rejects another repository")
	wrong = valid.duplicate()
	wrong.sha256 = "not-a-hash"
	verify(not Updates.validate_manifest(wrong),"updater requires a full SHA-256 digest")
	wrong = valid.duplicate()
	wrong.size = 200001
	verify(not Updates.validate_manifest(wrong),"updater cross-checks APK length against GitHub release metadata")
	wrong = valid.duplicate()
	wrong.version_code = 1002.5
	verify(not Updates.validate_manifest(wrong),"updater rejects fractional build numbers")
	verify(not Updates.trusted_download("https://github.com.evil.example/"+Updates.REPOSITORY+"/releases/download/x"),"updater rejects lookalike hosts")
	print("RESULT: %d checks, %d failures" % [checks,failures])
	game.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)
