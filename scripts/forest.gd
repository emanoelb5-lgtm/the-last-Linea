class_name LineaForest
extends Node3D
const TREE_COUNT := 240
const MOUNTAIN_RADIUS := 57.0
const EXIT_RADIUS := 66.0
var trees: Array[Dictionary] = []
var doors: Array[Node3D] = []
var traps: Array[Dictionary] = []
var echo_nodes: Array[Node3D] = []
var echo_positions: Array[Vector3] = [Vector3(-19,0,-27), Vector3(29,0,19), Vector3(-26,0,30)]
var door_positions: Array[Vector3] = [Vector3(-12,0,-15), Vector3(17,0,8), Vector3(-21,0,21), Vector3(10,0,-39)]
var trap_positions: Array[Vector3] = [Vector3(5,0,-8), Vector3(-8,0,-7), Vector3(12,0,17), Vector3(-15,0,7),
	Vector3(20,0,-23), Vector3(-28,0,-14), Vector3(33,0,8), Vector3(-7,0,31), Vector3(9,0,42),
	Vector3(-37,0,17), Vector3(35,0,-35), Vector3(-16,0,-42), Vector3(43,0,30), Vector3(-40,0,-34)]
var exit_node: Node3D
var exit_position := Vector3.ZERO
var environment: Environment
var sun: DirectionalLight3D
var rng := RandomNumberGenerator.new()
var mark_material: Material
var spent_material: Material

func _ready() -> void:
	rng.seed = 9827601
	mark_material = LineaArt.material(Color("d8bb7a"), 0.35)
	spent_material = LineaArt.material(Color("59635c"))
	build_environment()
	build_ground()
	build_mountains()
	build_trees()
	build_scatter()
	build_mist()
	build_doors()
	build_traps()
	build_echoes()
	build_clearing()
	if State.mountain_found:
		place_exit(State.mountain_angle)
	apply_quality()

func build_environment() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("243238")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("9eb5b0")
	environment.ambient_light_energy = 0.52
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.fog_enabled = true
	environment.fog_light_color = Color("4b6062")
	environment.fog_light_energy = 0.68
	environment.fog_density = 0.019
	environment.fog_sky_affect = 1.0
	var env := WorldEnvironment.new()
	env.environment = environment
	add_child(env)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -28, 0)
	sun.light_color = Color("b1c8c8")
	sun.light_energy = 0.72
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 35
	add_child(sun)

func build_ground() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(220, 220)
	ground.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ground.gdshader")
	ground.material_override = mat
	add_child(ground)
	LineaArt.collider(self, Vector3(220, 0.5, 220), Vector3(0,-0.25,0))

func build_mountains() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 64
	for i in count:
		var a := float(i) * TAU / count
		var b := float(i + 1) * TAU / count
		var h1 := 19.0 + 13.0 * absf(sin(i * 2.41))
		var h2 := 19.0 + 13.0 * absf(sin((i + 1) * 2.41))
		var inner_a := Vector3(sin(a)*74, -0.1, cos(a)*74)
		var inner_b := Vector3(sin(b)*74, -0.1, cos(b)*74)
		var peak_a := Vector3(sin(a)*89, h1, cos(a)*89)
		var peak_b := Vector3(sin(b)*89, h2, cos(b)*89)
		for vertex in [inner_a, peak_a, inner_b, inner_b, peak_a, peak_b]:
			st.set_color(Color("4b5756").darkened(rng.randf_range(0, 0.15)))
			st.add_vertex(vertex)
	st.generate_normals()
	var mountains := MeshInstance3D.new()
	mountains.mesh = st.commit()
	var rock := LineaArt.material(Color.WHITE)
	rock.vertex_color_use_as_albedo = true
	rock.cull_mode = BaseMaterial3D.CULL_DISABLED
	mountains.material_override = rock
	add_child(mountains)
	for i in 40:
		var a := float(i) * TAU / 40
		var body := LineaArt.collider(self, Vector3(13,30,5), Vector3(sin(a)*77,10,cos(a)*77))
		body.rotation.y = a

func reserved(pos: Vector3) -> bool:
	if pos.length() < 5.0:
		return true
	for p in door_positions + echo_positions + trap_positions:
		if pos.distance_to(p) < 4.0:
			return true
	return false

func build_trees() -> void:
	var positions: Array[Vector3] = [Vector3(3.3,0,-1.8), Vector3(-3.8,0,3.3), Vector3(4.3,0,4.5)]
	var attempts := 0
	while positions.size() < TREE_COUNT and attempts < 20000:
		attempts += 1
		var pos := Vector3(rng.randf_range(-68,68),0,rng.randf_range(-68,68))
		if pos.length() > 69 or reserved(pos):
			continue
		var clear := true
		for other in positions:
			if pos.distance_to(other) < 3.8:
				clear = false
				break
		if clear:
			positions.append(pos)
	var bark := ShaderMaterial.new()
	bark.shader = load("res://shaders/bark.gdshader")
	for variant in 6:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = LineaArt.tree_mesh(45 + variant * 19)
		mm.instance_count = 40
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = mm
		instance.material_override = bark
		add_child(instance)
		for j in 40:
			var id := variant * 40 + j
			var pos := positions[id]
			var rotation_y := rng.randf_range(0, TAU)
			var scale_value := rng.randf_range(0.9, 1.3)
			mm.set_instance_transform(j, Transform3D(Basis(Vector3.UP, rotation_y).scaled(Vector3.ONE * scale_value), pos))
			var body := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			var shape := CylinderShape3D.new()
			shape.radius = 0.4
			shape.height = 5
			cs.shape = shape
			cs.position.y = 2.5
			body.add_child(cs)
			add_child(body)
			body.position = pos
			trees.append({"id": id, "position": pos, "marked": false})
	for id in State.marks:
		mark_tree(id)

func mark_tree(id: int) -> void:
	if id < 0 or id >= trees.size() or trees[id].marked:
		return
	trees[id].marked = true
	var root := Node3D.new()
	add_child(root)
	root.position = trees[id].position
	for side in 4:
		var holder := Node3D.new()
		root.add_child(holder)
		holder.rotation.y = side * PI / 2
		for angle in [-0.65, 0.65]:
			var cut := LineaArt.box(holder, Vector3(0.045,0.42,0.045), Vector3(0,1.28,0.37), mark_material)
			cut.rotation.z = angle

func build_scatter() -> void:
	var grass := MultiMesh.new()
	grass.transform_format = MultiMesh.TRANSFORM_3D
	grass.mesh = LineaArt.grass_mesh()
	grass.instance_count = 1400
	var gi := MultiMeshInstance3D.new()
	gi.multimesh = grass
	var gm := LineaArt.material(Color("626650"))
	gm.cull_mode = BaseMaterial3D.CULL_DISABLED
	gi.material_override = gm
	add_child(gi)
	for i in 1400:
		var a := rng.randf_range(0,TAU)
		var r := sqrt(rng.randf()) * 70
		var scale_value := rng.randf_range(0.4,1.0)
		grass.set_instance_transform(i, Transform3D(Basis(Vector3.UP,a).scaled(Vector3.ONE*scale_value),Vector3(sin(a)*r,0,cos(a)*r)))
	var rocks := MultiMesh.new()
	rocks.transform_format = MultiMesh.TRANSFORM_3D
	var stone := SphereMesh.new()
	stone.radial_segments = 5
	stone.rings = 2
	stone.radius = 0.7
	stone.height = 1.0
	rocks.mesh = stone
	rocks.instance_count = 90
	var ri := MultiMeshInstance3D.new()
	ri.multimesh = rocks
	ri.material_override = LineaArt.material(Color("444e4c"))
	add_child(ri)
	for i in 90:
		var pos := Vector3(rng.randf_range(-68,68),0.15,rng.randf_range(-68,68))
		rocks.set_instance_transform(i,Transform3D(Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3(rng.randf_range(0.4,1.4),0.6,rng.randf_range(0.5,1.3))),pos))

func build_mist() -> void:
	var fog := ShaderMaterial.new()
	fog.shader = load("res://shaders/mist.gdshader")
	for i in 22:
		var plane := MeshInstance3D.new()
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(rng.randf_range(14,24),rng.randf_range(6,12))
		plane.mesh = mesh
		plane.material_override = fog
		plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(plane)
		plane.position = Vector3(rng.randf_range(-55,55),rng.randf_range(0.3,0.9),rng.randf_range(-55,55))

func build_doors() -> void:
	var wood := LineaArt.material(Color("4c3931"))
	var metal := LineaArt.material(Color("8c8268"))
	for i in door_positions.size():
		var door := Node3D.new()
		add_child(door)
		door.position = door_positions[i]
		door.rotation.y = i * 1.7 + 0.3
		door.set_meta("last_side", 0.0)
		for x in [-1.1, 1.1]:
			LineaArt.box(door,Vector3(0.22,3.1,0.3),Vector3(x,1.55,0),wood)
			LineaArt.collider(door,Vector3(0.22,3.1,0.3),Vector3(x,1.55,0))
		LineaArt.box(door,Vector3(2.45,0.22,0.33),Vector3(0,3.15,0),wood)
		var leaf := LineaArt.box(door,Vector3(1.95,2.9,0.09),Vector3(-0.9,1.5,0.5),wood)
		leaf.rotation.y = -1.0
		for y in [0.65, 2.35]:
			LineaArt.box(door,Vector3(0.2,0.12,0.34),Vector3(-1.1,y,0),metal)
		var panel := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(1.97,3.0)
		panel.mesh = quad
		panel.position.y = 1.5
		var portal := ShaderMaterial.new()
		portal.shader = load("res://shaders/door.gdshader")
		panel.material_override = portal
		door.add_child(panel)
		var glow := OmniLight3D.new()
		glow.light_color = Color("72c7b0")
		glow.light_energy = 0.5
		glow.omni_range = 4.5
		glow.position.y = 1.5
		door.add_child(glow)
		doors.append(door)

func build_traps() -> void:
	var iron := LineaArt.material(Color("817761"))
	var dirt := LineaArt.material(Color("392f29"))
	for i in trap_positions.size():
		var root := Node3D.new()
		add_child(root)
		root.position = trap_positions[i]
		var plate := MeshInstance3D.new()
		plate.mesh = LineaArt.cylinder(1.1,1.1,0.05,10)
		plate.material_override = dirt
		root.add_child(plate)
		plate.position.y = 0.035
		var spikes := Node3D.new()
		root.add_child(spikes)
		for j in 7:
			var a := j * TAU / 7
			var spike := MeshInstance3D.new()
			spike.mesh = LineaArt.cylinder(0.09,0,0.8,4)
			spike.material_override = iron
			spikes.add_child(spike)
			spike.position = Vector3(cos(a)*0.65,-0.24,sin(a)*0.65)
		# Broken sticks and a visible metal plate telegraph the hazard.
		LineaArt.box(root,Vector3(0.7,0.045,0.12),Vector3(0,0.09,0),iron)
		traps.append({"id":i,"position":root.position,"node":root,"spikes":spikes,"timer":0.0,"disarmed":false})
		if State.disarmed.has(i):
			disarm_trap(i)

func disarm_trap(id: int) -> void:
	if id < 0 or id >= traps.size():
		return
	traps[id].disarmed = true
	traps[id].spikes.visible = false
	var plate := traps[id].node.get_child(0) as MeshInstance3D
	plate.material_override = spent_material

func build_echoes() -> void:
	for i in echo_positions.size():
		var root := Node3D.new()
		add_child(root)
		root.position = echo_positions[i]
		var stone := LineaArt.box(root,Vector3(0.8,1.25,0.45),Vector3(0,0.6,0),LineaArt.material(Color("414f4d")))
		stone.rotation.z = -0.15
		var glow := Color("81c5ad") if not State.echoes.has(i) else Color("6b7e71")
		for j in 3:
			LineaArt.box(root,Vector3(0.35-j*0.07,0.035,0.02),Vector3(0,0.6+j*0.15,0.24),LineaArt.material(glow,0.6))
		var light := OmniLight3D.new()
		light.light_color = glow
		light.light_energy = 0.55
		light.omni_range = 3.5
		light.position.y = 1.0
		root.add_child(light)
		echo_nodes.append(root)

func build_clearing() -> void:
	var stone := LineaArt.material(Color("686f60"))
	for i in 9:
		var a := i * TAU / 9
		var mesh := LineaArt.box(self,Vector3(0.45,0.16,0.35),Vector3(sin(a)*2.2,0.07,cos(a)*2.2),stone)
		mesh.rotation.y = a
	var satchel := LineaArt.box(self,Vector3(0.6,0.25,0.45),Vector3(-1.8,0.15,-0.5),LineaArt.material(Color("66513d")))
	satchel.rotation.y = -0.5
	LineaArt.box(self,Vector3(0.58,0.04,0.035),Vector3(-1.8,0.28,-0.5),mark_material)

func place_exit(angle: float) -> void:
	if is_instance_valid(exit_node):
		return
	exit_position = Vector3(sin(angle)*EXIT_RADIUS,0,cos(angle)*EXIT_RADIUS)
	exit_node = Node3D.new()
	add_child(exit_node)
	exit_node.position = exit_position
	exit_node.rotation.y = angle
	var mat := LineaArt.material(Color("485652"))
	for x in [-1.5,1.5]:
		var column := LineaArt.box(exit_node,Vector3(1.1,4.6,1.4),Vector3(x,2.3,0),mat)
		column.rotation.z = -signf(x)*0.15
	LineaArt.box(exit_node,Vector3(3.8,0.8,1.5),Vector3(0,4.2,0),mat)
	var panel := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.9,3.8)
	panel.mesh = quad
	panel.position.y = 1.9
	var glow := ShaderMaterial.new()
	glow.shader = load("res://shaders/door.gdshader")
	glow.set_shader_parameter("tint",Color("c0b992"))
	panel.material_override = glow
	exit_node.add_child(panel)
	var light := OmniLight3D.new()
	light.position.y = 2
	light.light_color = Color("d9d3a6")
	light.light_energy = 1.6
	light.omni_range = 8
	exit_node.add_child(light)

func apply_quality() -> void:
	sun.shadow_enabled = int(State.settings.quality) > 0
