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
	verify(game.pixel_size(Vector2.ZERO,1) == Vector2i(480,270) and game.pixel_size(Vector2(0,720),1).x >= 2,"Android surface starts with a valid pixel viewport even before layout")
	verify(game.pixel_size(Vector2(1280,720),99) == Vector2i(640,360),"pixel quality and render dimensions stay bounded")
	verify(game.player.limbs.size() == 4 and game.player.joints.size() == 4 and is_instance_valid(game.player.head),"human rig has a head, two arms, two legs, elbows and knees")
	var human_mesh := LineaHumanoid.volume([Vector3(-0.1,0.1,0.1),Vector3(0.1,0.1,0.1)])
	var human_arrays := human_mesh.surface_get_arrays(0)
	var human_vertex: Vector3 = human_arrays[Mesh.ARRAY_VERTEX][0]
	var human_normal: Vector3 = human_arrays[Mesh.ARRAY_NORMAL][0]
	verify(human_normal.dot(Vector3(human_vertex.x,0,human_vertex.z)) > 0,"human mesh faces and normals point outward")
	var audio_valid := Sound.tracks.size() == 8
	for stream in Sound.tracks.values():
		audio_valid = audio_valid and stream is AudioStreamOggVorbis and stream.get_length() > 0.1
	verify(audio_valid and Sound.wind.stream.loop and Sound.drone.stream.loop,"all original sounds load from imported Ogg assets with ambient loops")
	game.start_game(true)
	game.player.wake_pose(5.0)
	var seated_height: float = game.player.head.global_position.y
	game.player.wake_pose(6.8)
	var planted_foot: Vector3 = game.player.feet[0].global_position
	verify(game.player.joints[1].global_position.y > 0.02 and game.player.joints[1].global_position.y < 0.18,"one knee supports the body near the ground during the rise")
	game.player.wake_pose(9.2)
	verify(game.player.feet[0].global_position.distance_to(planted_foot) < 0.02,"supporting foot remains planted while the pelvis rises")
	game.player.wake_pose(11.8)
	verify(seated_height < 1.1 and game.player.head.global_position.y > 1.5,"the spine and pelvis pass from sitting to a full human standing height")
	var continuous := true
	game.player.wake_pose(0)
	var previous_head: Vector3 = game.player.head.global_position
	for frame in 321:
		game.player.wake_pose(frame*0.05)
		var current_head: Vector3 = game.player.head.global_position
		continuous = continuous and current_head.is_finite() and current_head.distance_to(previous_head) < 0.16
		previous_head = current_head
	verify(continuous,"waking poses interpolate continuously without a whole-body flip or nonfinite transforms")
	game.process_intro(9.5)
	verify(game.mode == "intro" and game.player.wake_phase == "rising","cutscene wakes the young man with a supported rise")
	var sight := PhysicsRayQueryParameters3D.create(game.camera.position,Vector3(0,0.8,0),1,[game.player.get_rid()])
	verify(game.forest.get_world_3d().direct_space_state.intersect_ray(sight).is_empty(),"waking cutscene keeps the man visible between the trees")
	game.finish_intro()
	verify(State.intro_seen and game.mode == "play","intro skip enters gameplay and persists")
	game.propagate_notification(NOTIFICATION_APPLICATION_PAUSED)
	await get_tree().process_frame
	await get_tree().process_frame
	verify(game.mode == "pause" and is_instance_valid(game.overlay) and game.overlay.is_inside_tree(),"Android pause builds a visible menu after the tree unlocks notification propagation")
	game.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await get_tree().process_frame
	await get_tree().process_frame
	verify(game.mode == "play","Android back resumes without mutating children inside notification propagation")
	verify(game.forest.legacy_positions.size() == 240 and game.forest.chunks.size() == 25,"large forest streams 25 regions while preserving the original 240 tree positions")
	verify(LineaForest.MOUNTAIN_RADIUS >= 750 and State.MAP_LIMIT > LineaForest.MOUNTAIN_RADIUS,"mountain foot is more than 750 metres from the awakening")
	var safe := true
	for pos in game.forest.trap_positions: safe = safe and pos.length() >= 260
	for pos in game.forest.door_positions: safe = safe and pos.length() >= 410
	verify(safe,"no trap is within 260 metres and no door is within 410 metres of the start")
	verify(game.camera.position.y < 3.0,"cinematic camera stays below the treetops")
	game.rotate_camera(Vector2(0,9999))
	verify(game.cam_pitch <= 0.22,"looking around cannot raise the camera above the forest")
	game.cam_pitch = 0.12
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
	game.player.position = game.forest.tree_data(0).position+Vector3(0,0,1.6)
	game.update_interaction()
	verify(game.interaction.get("type") == "tree","nearby trees can be selected")
	verify(game.forest.focus_marker.visible,"selected interaction has a visible world marker")
	game.interact()
	verify(game.player.busy() and State.marks.is_empty() and game.player.knife.visible,"tree cutting uses the visible knife before awarding its persistent mark")
	game.interact()
	await get_tree().create_timer(0.2).timeout
	game.show_pause()
	var frozen_action: float = game.player.scratch_time
	await get_tree().create_timer(0.3).timeout
	verify(is_equal_approx(game.player.scratch_time,frozen_action) and State.marks.is_empty(),"pause freezes an unfinished action without awarding XP")
	game.resume_game()
	await get_tree().create_timer(1.0).timeout
	verify(not game.player.busy() and State.marks == [0],"resuming completes the cut and records exactly one mark")
	var marked_xp: int = State.xp
	game.update_interaction()
	game.interact()
	verify(State.marks == [0] and State.xp == marked_xp,"tree marking is persistent and cannot farm XP")
	game.player.position = game.forest.trap_positions[0]+Vector3(0,0,2)
	game.update_interaction()
	game.interact()
	verify(game.player.busy() and not State.disarmed.has(0),"disarming takes time and leaves the trap active until completed")
	await get_tree().create_timer(1.2).timeout
	verify(State.disarmed.has(0) and game.forest.traps[0].disarmed,"trap can be disarmed from its safe edge")
	game.player.position = game.forest.tree_data(1).position+Vector3(0,0,1.7)
	game.update_interaction()
	game.interact()
	game.damage(1)
	verify(not game.player.busy() and not State.marks.has(1),"damage cancels an unfinished interaction without granting a mark")
	State.health = 100
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
	# The chapter ends on contact with the mountain base in every direction.
	var before_foot: int = State.xp
	game.player.position = Vector3(0,0,-(LineaForest.MOUNTAIN_RADIUS-5))
	game.process_game(0)
	verify(game.mode == "play" and not State.completed,"walking near the mountain does not finish before reaching its foot")
	var streaming_peak: int = game.forest.trees.size()
	for i in 8:
		game.set_mode("play")
		game.mountain_contact_latched = false
		var a := i*TAU/8
		var direction := Vector3(sin(a),0,cos(a))
		game.player.position = direction*(LineaForest.MOUNTAIN_RADIUS+0.2)
		game.process_game(0)
		verify(State.mountain_found and State.completed and game.mode == "ending","reaching the mountain foot automatically ends the chapter in direction %d" % i)
		streaming_peak = maxi(streaming_peak,game.forest.trees.size())
		await get_tree().create_timer(1.9).timeout
	verify(State.xp == before_foot+100,"mountain discovery and first ending grant their rewards only once")
	verify(game.forest.chunks.size() == 25 and streaming_peak < 1400,"walking across the large world keeps a bounded number of tree instances loaded")
	game.resume_game()
	game.player.position = Vector3.ZERO
	game.forest.update_streaming(Vector3.ZERO,true)
	verify(game.forest.trees[0].marked,"tree marks survive unloading and returning to the original region")
	game.player.position = Vector3.ZERO
	game.update_interaction()
	game.interact()
	verify(State.health == 100,"resting in the clearing restores health")
	var obstruction := LineaArt.collider(game.forest,Vector3(6,6,0.4),Vector3(0,3,3))
	obstruction.collision_layer = 2
	obstruction.collision_mask = 0
	await get_tree().physics_frame
	game.camera_target = Vector3(0,1.15,0)
	game.camera.position = Vector3(0,5,8)
	game.cam_yaw = 0
	game.update_camera(0.005)
	verify(game.camera.position.z < 2.8,"camera smoothing cannot leave the camera behind a blocking trunk")
	obstruction.free()
	game.snapshot()
	var before_save := State.to_data().duplicate(true)
	State.marks.clear()
	State.echoes.clear()
	State.load_game()
	verify(State.marks == before_save.marks and State.echoes == before_save.echoes and State.xp == before_save.xp,"save/load roundtrip restores gameplay progress")
	game.player.position = Vector3(0,0,-LineaForest.MOUNTAIN_RADIUS)
	var before_ending: int = State.xp
	await game.finish_chapter()
	verify(State.completed and State.xp == before_ending,"completed chapter can be viewed again without another reward")
	game.resume_game()
	await game.finish_chapter()
	verify(State.xp == before_ending,"replaying the ending does not farm XP")
	game.resume_game()
	game.show_settings("pause")
	verify(is_instance_valid(game.update_button),"settings exposes the GitHub updater")
	game.settings_back()
	verify(game.mode == "pause","settings returns to pause without restarting the chapter")
	State.apply_data({"health":-3,"xp":-50,"marks":[0,0,-1,LineaWorldRules.MAX_TREE_ID+1,"bad"],"position":[10000,0,0]})
	verify(State.health == 1 and State.xp == 0 and State.marks == [0] and State.last_position == Vector3.ZERO,"malformed save values are bounded and deduplicated")
	State.apply_data({"schema":1,"health":64,"xp":135,"marks":[0,12],"echoes":[2],"disarmed":[0],"mountain_found":true,"mountain_angle":1.2,"intro_seen":true,"completed":false,"position":[2,0,-3]})
	verify(State.health == 64 and State.xp == 135 and State.marks == [0,12] and State.echoes == [2] and State.disarmed == [0] and State.mountain_found and State.intro_seen and State.last_position == Vector3(2,0,-3),"version 0.1 progress remains compatible with the new interactions")
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
