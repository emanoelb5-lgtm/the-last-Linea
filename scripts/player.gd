class_name LineaPlayer
extends CharacterBody3D
signal stepped
var model: Node3D
var limbs: Array[Node3D] = []
var lamp: OmniLight3D
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
var asleep := true

func _ready() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.75
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.88
	add_child(collision)
	var art := LineaArt.character(self)
	model = art.rig
	limbs.assign(art.limbs)
	lamp = art.light
	sleep_pose()

func sleep_pose() -> void:
	asleep = true
	model.rotation.z = PI * 0.5
	model.position = Vector3(0.8, 0.24, 0)
	lamp.light_energy = 0.55

func stand_pose() -> void:
	asleep = false
	model.rotation.z = 0
	model.position = Vector3.ZERO
	lamp.light_energy = 1.1

func dodge() -> bool:
	if not enabled or dodge_cooldown > 0:
		return false
	dodge_direction = Vector3(input_vector.x, 0, input_vector.y).rotated(Vector3.UP, camera_yaw)
	if dodge_direction.length() < 0.1:
		dodge_direction = -model.basis.z
	dodge_time = 0.42
	dodge_cooldown = 1.3
	return true

func invulnerable() -> bool:
	return dodge_time > 0.0

func scratch(target: Vector3) -> void:
	var dir := target - global_position
	if dir.length() > 0.1:
		model.rotation.y = atan2(-dir.x, -dir.z)
	scratch_time = 0.6

func _physics_process(delta: float) -> void:
	dodge_cooldown = maxf(0, dodge_cooldown - delta)
	dodge_time = maxf(0, dodge_time - delta)
	scratch_time = maxf(0, scratch_time - delta)
	if not enabled:
		velocity = Vector3.ZERO
		return
	var direction := Vector3(input_vector.x, 0, input_vector.y).rotated(Vector3.UP, camera_yaw)
	var speed := 5.2 if sprinting else 3.35
	if scratch_time > 0:
		direction = Vector3.ZERO
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
		var sign_value := -1.0 if i % 2 == 0 else 1.0
		var angle := sin(walk_cycle) * (0.55 if moving else 0.0) * sign_value
		limbs[i].rotation.x = lerpf(limbs[i].rotation.x, angle, delta * 16)
	if scratch_time > 0:
		limbs[2].rotation.x = -1.4 + sin(scratch_time * 38) * 0.4
	model.position.y = absf(sin(walk_cycle)) * 0.045 if moving else sin(Time.get_ticks_msec() * 0.002) * 0.012
	model.rotation.z = sin(dodge_time / 0.42 * PI) * 0.32
