class_name LineaPlayer
extends CharacterBody3D
signal stepped
signal action_finished(kind: String, target_id: int)
var model: Node3D
var limbs: Array[Node3D] = []
var joints: Array[Node3D] = []
var head: Node3D
var lamp: OmniLight3D
var knife: Node3D
var input_vector := Vector2.ZERO
var camera_yaw := 0.0
var enabled := false
var sprinting := false
var dodge_time := 0.0
var dodge_cooldown := 0.0
var dodge_direction := Vector3.FORWARD
var walk_cycle := 0.0
var step_time := 0.0
var scratch_time := 0.0
var action_duration := 0.0
var action_kind := ""
var action_target_id := -1
var action_target := Vector3.ZERO
var asleep := true

func _ready() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.82
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.91
	add_child(collision)
	var art := LineaArt.character(self)
	model = art.rig
	limbs.assign(art.limbs)
	joints.assign(art.joints)
	head = art.head
	lamp = art.light
	knife = art.knife
	sleep_pose()

func sleep_pose() -> void:
	cancel_action()
	asleep = true
	knife.visible = false
	model.rotation.x = 0
	model.rotation.z = PI * 0.5
	model.position = Vector3(0.8, 0.34, 0)
	joints[2].rotation.x = 0.3
	joints[3].rotation.x = 0.2
	lamp.light_energy = 0.55

func stand_pose() -> void:
	asleep = false
	knife.visible = true
	model.rotation.x = 0
	model.rotation.z = 0
	model.position = Vector3.ZERO
	for limb in limbs:
		limb.rotation = Vector3.ZERO
	for joint in joints:
		joint.rotation = Vector3.ZERO
	lamp.light_energy = 1.1

func dodge() -> bool:
	if not enabled or dodge_cooldown > 0 or busy():
		return false
	dodge_direction = Vector3(input_vector.x, 0, input_vector.y).rotated(Vector3.UP, camera_yaw)
	if dodge_direction.length() < 0.1:
		dodge_direction = -model.basis.z
	dodge_time = 0.42
	dodge_cooldown = 1.3
	return true

func invulnerable() -> bool:
	return dodge_time > 0.0

func busy() -> bool:
	return not action_kind.is_empty()

func action_progress() -> float:
	return 1.0-clampf(scratch_time/maxf(action_duration,0.001),0.0,1.0)

func cancel_action() -> void:
	scratch_time = 0
	action_duration = 0
	action_kind = ""
	action_target_id = -1

func begin_action(kind: String, id: int, target: Vector3) -> bool:
	if not enabled or busy() or dodge_time > 0 or kind not in ["tree","trap"]:
		return false
	var dir := target - global_position
	if dir.length() > 0.1:
		model.rotation.y = atan2(-dir.x, -dir.z)
	action_kind = kind
	action_target_id = id
	action_target = target
	action_duration = 1.1
	scratch_time = action_duration
	velocity = Vector3.ZERO
	return true

func _physics_process(delta: float) -> void:
	if not enabled:
		velocity = Vector3.ZERO
		return
	dodge_cooldown = maxf(0, dodge_cooldown - delta)
	dodge_time = maxf(0, dodge_time - delta)
	if busy():
		scratch_time = maxf(0,scratch_time-delta)
		if scratch_time <= 0:
			var finished_kind := action_kind
			var finished_id := action_target_id
			cancel_action()
			action_finished.emit(finished_kind,finished_id)
	var direction := Vector3(input_vector.x, 0, input_vector.y).rotated(Vector3.UP, camera_yaw)
	var speed := 5.2 if sprinting else 3.35
	if busy():
		direction = Vector3.ZERO
		if action_kind == "tree" and action_progress() < 0.45:
			var approach := action_target-global_position
			approach.y = 0
			if approach.length() > 1.45:
				direction = approach.normalized()
				speed = minf(3.2,(approach.length()-1.45)/maxf(delta,0.001))
	if dodge_time > 0:
		direction = dodge_direction
		speed = 9.5
	velocity.x = move_toward(velocity.x, direction.x * speed, delta * 24)
	velocity.z = move_toward(velocity.z, direction.z * speed, delta * 24)
	if not is_on_floor():
		velocity.y -= 22 * delta
	else:
		velocity.y = -0.1
	move_and_slide()
	# Hard outer limit supplements the visible mountain collision ring.
	var flat := Vector2(position.x, position.z)
	if flat.length() > State.MAP_LIMIT:
		flat = flat.normalized() * State.MAP_LIMIT
		position.x = flat.x
		position.z = flat.y
	var moving := Vector2(velocity.x, velocity.z).length() > 0.25
	if moving:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-direction.x, -direction.z), delta * 12)
		walk_cycle += delta * (12 if sprinting else 8)
		step_time -= delta
		if step_time <= 0 and is_on_floor():
			step_time = 0.32 if sprinting else 0.48
			stepped.emit()
	for i in limbs.size():
		var sign_value := -1.0 if i in [0,3] else 1.0
		var amplitude := 0.55 if i < 2 else (0.28 if i == 2 else 0.13)
		var angle := sin(walk_cycle) * (amplitude if moving else 0.0) * sign_value
		limbs[i].rotation.x = lerpf(limbs[i].rotation.x, angle, delta * 16)
		limbs[i].rotation.z = lerpf(limbs[i].rotation.z,0.0,delta*14)
		var bend := -maxf(0.0,-sin(walk_cycle)*sign_value)*0.85 if i < 2 and moving else (0.18 if i >= 2 else 0.0)
		joints[i].rotation.x = lerpf(joints[i].rotation.x,bend,delta*12)
	var crouch := 0.0
	if busy():
		var progress := action_progress()
		if action_kind == "tree":
			var cutting := clampf((progress-0.45)/0.55,0.0,1.0)
			limbs[2].rotation.x = lerpf(0.6,1.1,minf(1.0,progress*5))+sin(cutting*PI*4)*0.25
			limbs[2].rotation.z = sin(cutting*PI*4)*0.3
			joints[2].rotation.x = 0.3+sin(cutting*PI*4)*0.15
		else:
			crouch = sin(progress*PI)*0.28
			limbs[2].rotation.x = 0.6+sin(progress*PI*6)*0.12
			for i in 2:
				limbs[i].rotation.x += crouch*1.6
				joints[i].rotation.x = -crouch*3.2
			joints[2].rotation.x = 0.7
	model.position.y = (absf(sin(walk_cycle))*0.045 if moving else sin(Time.get_ticks_msec()*0.002)*0.012)-crouch
	model.rotation.x = lerpf(model.rotation.x,(-0.12 if sprinting and moving else 0.0)-sin(dodge_time/0.42*PI)*0.5,delta*12)
	model.rotation.z = sin(dodge_time / 0.42 * PI) * 0.32
