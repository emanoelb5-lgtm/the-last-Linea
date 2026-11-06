class_name LineaPlayer
extends CharacterBody3D
signal stepped
signal action_finished(kind: String, target_id: int)
var model: Node3D
var limbs: Array[Node3D] = []
var joints: Array[Node3D] = []
var head: Node3D
var upper_body: Node3D
var feet: Array[Node3D] = []
var mouth: Node3D
var lantern: Node3D
var wake_phase := "lying"
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
	shape.height = 1.78
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.89
	add_child(collision)
	var art := LineaArt.character(self)
	model = art.rig
	limbs.assign(art.limbs)
	joints.assign(art.joints)
	head = art.head
	upper_body = art.upper
	feet.assign(art.feet)
	mouth = art.mouth
	lantern = art.lantern
	lamp = art.light
	knife = art.knife
	sleep_pose()

func sleep_pose() -> void:
	cancel_action()
	asleep = true
	knife.visible = false
	wake_pose(0)
	lamp.light_energy = 0.55

func stand_pose() -> void:
	asleep = false
	knife.visible = true
	model.rotation = Vector3.ZERO
	model.position = Vector3.ZERO
	upper_body.rotation = Vector3.ZERO
	head.rotation = Vector3.ZERO
	mouth.scale = Vector3(0.038,0.009,0.01)
	lantern.position = Vector3(0,-0.49,-0.01)
	lantern.rotation = Vector3.ZERO
	lantern.scale = Vector3.ONE
	for limb in limbs: limb.rotation = Vector3.ZERO
	for joint in joints: joint.rotation = Vector3.ZERO
	for ankle in feet: ankle.rotation = Vector3.ZERO
	lamp.light_energy = 1.1

# Pelvis, spine, hands and feet move through distinct supported poses.
# Feet are held in place through the push; only the balancing foot steps.
const WAKE_KEYS := [
 {"t":0.0,"hip":Vector3(0,0.20,0),"body":Vector3(1.47,0,-0.10),"chest":0.0,"lf":Vector3(-0.1,0.10,-0.78),"rf":Vector3(0.1,0.10,-0.72),"lh":Vector3(-0.38,0.10,0.30),"rh":Vector3(0.38,0.10,0.34)},
 {"t":2.0,"hip":Vector3(0,0.20,0),"body":Vector3(1.40,0,-0.18),"chest":-0.04,"lf":Vector3(-0.1,0.10,-0.78),"rf":Vector3(0.1,0.10,-0.72),"lh":Vector3(-0.40,0.08,0.30),"rh":Vector3(0.36,0.09,0.48)},
 {"t":3.4,"hip":Vector3(0,0.19,0.04),"body":Vector3(0.80,0,-0.12),"chest":0.0,"lf":Vector3(-0.1,0.10,-0.73),"rf":Vector3(0.1,0.10,-0.60),"lh":Vector3(-0.36,0.07,0.26),"rh":Vector3(0.35,0.07,0.30)},
 {"t":5.0,"hip":Vector3(0,0.16,0.08),"body":Vector3(0.10,0,0),"chest":0.18,"lf":Vector3(-0.1,0.10,-0.72),"rf":Vector3(0.1,0.10,-0.61),"lh":Vector3(-0.34,0.07,0.20),"rh":Vector3(0.36,0.07,0.20)},
 {"t":6.8,"hip":Vector3(0,0.48,0.02),"body":Vector3.ZERO,"chest":-0.65,"lf":Vector3(-0.1,0.10,-0.38),"rf":Vector3(0.1,0.10,0.40),"lh":Vector3(-0.33,0.07,-0.42),"rh":Vector3(0.33,0.09,-0.28)},
 {"t":8.0,"hip":Vector3(0,0.48,0.02),"body":Vector3.ZERO,"chest":-0.50,"lf":Vector3(-0.1,0.10,-0.38),"rf":Vector3(0.1,0.10,0.40),"lh":Vector3(-0.33,0.07,-0.42),"rh":Vector3(0.50,0.37,0.26)},
 {"t":9.2,"hip":Vector3(0,0.70,-0.18),"body":Vector3.ZERO,"chest":-0.35,"lf":Vector3(-0.1,0.10,-0.38),"rf":Vector3(0.1,0.18,0.14),"lh":Vector3(-0.27,0.43,-0.32),"rh":Vector3(0.32,0.58,0.09)},
 {"t":10.8,"hip":Vector3(0,0.9168,-0.26),"body":Vector3.ZERO,"chest":-0.02,"lf":Vector3(-0.1,0.10,-0.38),"rf":Vector3(0.1,0.10,-0.14),"lh":Vector3(-0.22,0.68,-0.02),"rh":Vector3(0.22,0.68,-0.02)},
 {"t":12.5,"hip":Vector3(0,0.9168,-0.26),"body":Vector3(0,0,0.015),"chest":0.0,"lf":Vector3(-0.1,0.10,-0.26),"rf":Vector3(0.1,0.10,-0.26),"lh":Vector3(-0.22,0.68,-0.02),"rh":Vector3(0.22,0.68,-0.02)}
]

func solve_limb(index: int, target_local: Vector3, pole: Vector3, upper_length: float, lower_length: float) -> void:
	var scale_value := 0.96
	var start := limbs[index].global_position
	var target := to_global(target_local)
	var vector := target-start
	var d := clampf(vector.length(),0.01,(upper_length+lower_length)*scale_value-0.001)
	var direction := vector.normalized()
	var perpendicular := pole-direction*pole.dot(direction)
	if perpendicular.length_squared() < 0.001: perpendicular = Vector3.RIGHT
	perpendicular = perpendicular.normalized()
	var l1 := upper_length*scale_value
	var l2 := lower_length*scale_value
	var along := (l1*l1+d*d-l2*l2)/(2*d)
	var height := sqrt(maxf(0,l1*l1-along*along))
	var elbow := start+direction*along+perpendicular*height
	limbs[index].global_basis = Basis(Quaternion(Vector3.DOWN,(elbow-start).normalized())).scaled(Vector3.ONE*scale_value)
	joints[index].global_basis = Basis(Quaternion(Vector3.DOWN,(start+direction*d-elbow).normalized())).scaled(Vector3.ONE*scale_value)

func wake_pose(time: float) -> void:
	var t := clampf(time,0,16)
	var index := 0
	while index < WAKE_KEYS.size()-2 and t > float(WAKE_KEYS[index+1].t): index += 1
	var a: Dictionary = WAKE_KEYS[index]
	var b: Dictionary = WAKE_KEYS[index+1]
	var progress := smoothstep(float(a.t),float(b.t),t)
	var hip: Vector3 = a.hip.lerp(b.hip,progress)
	model.rotation = a.body.lerp(b.body,progress)
	model.position = hip-model.basis*Vector3(0,0.955,0)
	upper_body.rotation.x = lerpf(float(a.chest),float(b.chest),progress)
	var lf: Vector3 = a.lf.lerp(b.lf,progress)
	var rf: Vector3 = a.rf.lerp(b.rf,progress)
	if t > 8 and t < 12.5:
		rf.y += sin(progress*PI)*0.04
	solve_limb(0,lf,Vector3(0,0,-1),0.425,0.425)
	solve_limb(1,rf,Vector3(0,0,-1),0.425,0.425)
	var shoe_pitch := lerpf(1.15,0,smoothstep(2,5,t))
	for ankle in feet: ankle.global_basis = Basis(Vector3.RIGHT,shoe_pitch).scaled(Vector3.ONE*0.96)
	solve_limb(2,a.lh.lerp(b.lh,progress),Vector3(-1,0,0.2),0.335,0.352)
	solve_limb(3,a.rh.lerp(b.rh,progress),Vector3(1,0,0.2),0.335,0.352)
	head.rotation = Vector3(0.08*sin(t*0.7),0.0,0)
	if t > 10.8:
		head.rotation.y = sin((t-10.8)*1.4)*0.55
	mouth.scale = Vector3(0.038,0.009*(1+0.6*absf(sin(t*15.0))) if t>10.8 and t<13.8 else 0.009,0.01)
	var normal_lantern := joints[3].to_global(Vector3(0,-0.49,-0.01))
	lantern.global_position = to_global(Vector3(0.55,0.16,0.22)).lerp(normal_lantern,smoothstep(7.7,10.2,t))
	lantern.global_basis = Basis.IDENTITY.scaled(Vector3.ONE*0.96)
	wake_phase = "lying" if t<2 else ("bracing" if t<5 else ("sitting" if t<5.8 else ("kneeling" if t<8.2 else ("rising" if t<10.8 else "looking"))))

func finish_wake() -> void:
	position.z -= 0.26
	stand_pose()

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
	for i in feet.size():
		feet[i].rotation.x = -(limbs[i].rotation.x+joints[i].rotation.x)*0.5
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
