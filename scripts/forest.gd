class_name LineaForest
extends Node3D
const TREE_COUNT := LineaWorldRules.MAX_TREE_ID+1
const MOUNTAIN_RADIUS := LineaWorldRules.MOUNTAIN_RADIUS
const CHUNK_SIZE := LineaWorldRules.CHUNK_SIZE
var trees: Dictionary = {}
var chunks: Dictionary = {}
var collision_trees: Dictionary = {}
var legacy_positions: Array[Vector3] = []
var marked_ids: Dictionary = {}
var chunk_center := Vector2i(99999,99999)
var collision_center := Vector3(99999,0,99999)
var tree_meshes: Array[Mesh] = []
var distant_meshes: Array[Mesh] = []
var bark: Material
var grass_material: Material
var grass_geometry: Mesh
var rock_material: Material
var rock_geometry: Mesh
var mist_material: Material
var doors: Array[Node3D] = []
var traps: Array[Dictionary] = []
var echo_nodes: Array[Node3D] = []
var echo_positions: Array[Vector3] = [Vector3(-82,0,-105),Vector3(235,0,192),Vector3(-390,0,438)]
var door_positions: Array[Vector3] = [Vector3(-312,0,-310),Vector3(432,0,158),Vector3(-385,0,365),Vector3(180,0,-603)]
var trap_positions: Array[Vector3] = [Vector3(104,0,-249),Vector3(-248,0,-145),Vector3(215,0,201),Vector3(-282,0,108),
    Vector3(319,0,-262),Vector3(-387,0,-214),Vector3(461,0,122),Vector3(-126,0,465),Vector3(208,0,538),
    Vector3(-533,0,208),Vector3(472,0,-447),Vector3(-227,0,-610),Vector3(535,0,405),Vector3(-554,0,-401)]
var environment: Environment
var sun: DirectionalLight3D
var rng := RandomNumberGenerator.new()
var mark_material: Material
var spent_material: Material
var focus_marker: MeshInstance3D
var focus_material: ShaderMaterial

func _ready() -> void:
	rng.seed = 9827601
	mark_material = LineaArt.material(Color("d8bb7a"), 0.35)
	spent_material = LineaArt.material(Color("59635c"))
	build_environment()
	build_ground()
	build_mountains()
	prepare_forest()
	build_doors()
	build_traps()
	build_echoes()
	build_clearing()
	build_focus_marker()
	update_streaming(Vector3.ZERO,true)
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
	environment.fog_density = 0.032
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
	plane.size = Vector2(1800,1800)
	ground.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ground.gdshader")
	ground.material_override = mat
	add_child(ground)
	LineaArt.collider(self, Vector3(1800,0.5,1800), Vector3(0,-0.25,0))

func build_mountains() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 128
	for i in count:
		var a := float(i) * TAU / count
		var b := float(i + 1) * TAU / count
		var h1 := 105.0+65.0*absf(sin(i*0.73))
		var h2 := 105.0+65.0*absf(sin((i+1)*0.73))
		var inner_a := Vector3(sin(a)*MOUNTAIN_RADIUS, -0.1, cos(a)*MOUNTAIN_RADIUS)
		var inner_b := Vector3(sin(b)*MOUNTAIN_RADIUS, -0.1, cos(b)*MOUNTAIN_RADIUS)
		var peak_a := Vector3(sin(a)*880, h1, cos(a)*880)
		var peak_b := Vector3(sin(b)*880, h2, cos(b)*880)
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
	for i in 64:
		var a := i*TAU/64.0
		var body := LineaArt.collider(self,Vector3(79,160,8),Vector3(sin(a)*783,75,cos(a)*783))
		body.rotation.y = a

func prepare_forest() -> void:
	# Keep all original tree positions and IDs, so existing marks stay in place.
	var legacy_rng := RandomNumberGenerator.new()
	legacy_rng.seed = 9827601
	for _i in 384:
		legacy_rng.randf_range(0,0.15)
	legacy_positions.assign([Vector3(3.3,0,-1.8),Vector3(-3.8,0,3.3),Vector3(4.3,0,4.5)])
	var old_reserved: Array[Vector3] = [Vector3(-19,0,-27),Vector3(29,0,19),Vector3(-26,0,30),
		Vector3(-12,0,-15),Vector3(17,0,8),Vector3(-21,0,21),Vector3(10,0,-39),
		Vector3(5,0,-8),Vector3(-8,0,-7),Vector3(12,0,17),Vector3(-15,0,7),Vector3(20,0,-23),
		Vector3(-28,0,-14),Vector3(33,0,8),Vector3(-7,0,31),Vector3(9,0,42),Vector3(-37,0,17),
		Vector3(35,0,-35),Vector3(-16,0,-42),Vector3(43,0,30),Vector3(-40,0,-34)]
	while legacy_positions.size() < LineaWorldRules.LEGACY_TREE_COUNT:
		var pos := Vector3(legacy_rng.randf_range(-68,68),0,legacy_rng.randf_range(-68,68))
		if pos.length() > 69 or pos.length() < 5:
			continue
		var clear := true
		for other in old_reserved:
			if pos.distance_to(other) < 4.0:
				clear = false
				break
		if clear:
			for other in legacy_positions:
				if pos.distance_to(other) < 3.8:
					clear = false
					break
		if clear:
			legacy_positions.append(pos)
	for id in State.marks:
		marked_ids[id] = true
	bark = ShaderMaterial.new()
	bark.shader = load("res://shaders/bark.gdshader")
	for i in 6:
		tree_meshes.append(LineaArt.tree_mesh(45+i*19))
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		LineaArt.limb(st,Vector3.ZERO,Vector3(0.12,6.5,0),0.32,0.055)
		LineaArt.limb(st,Vector3(0,3.8,0),Vector3(1.7,5.6,0.5),0.11,0.015)
		LineaArt.limb(st,Vector3(0,4.8,0),Vector3(-1.3,6.5,-0.5),0.09,0.01)
		distant_meshes.append(st.commit())
	grass_geometry = LineaArt.grass_mesh()
	grass_material = LineaArt.material(Color("626650"))
	grass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var stone := SphereMesh.new()
	stone.radial_segments = 5
	stone.rings = 2
	stone.radius = 0.7
	stone.height = 1
	rock_geometry = stone
	rock_material = LineaArt.material(Color("444e4c"))
	mist_material = ShaderMaterial.new()
	mist_material.shader = load("res://shaders/mist.gdshader")

static func chunk_key(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x/CHUNK_SIZE),floori(pos.z/CHUNK_SIZE))

func tree_data(id: int) -> Dictionary:
	if id < 0 or id > LineaWorldRules.MAX_TREE_ID:
		return {}
	if trees.has(id):
		return trees[id]
	var pos: Vector3
	if id < LineaWorldRules.LEGACY_TREE_COUNT:
		pos = legacy_positions[id]
	else:
		var n := id-LineaWorldRules.LEGACY_TREE_COUNT
		var cell := Vector2i(n/LineaWorldRules.GRID_WIDTH-LineaWorldRules.GRID_HALF,n%LineaWorldRules.GRID_WIDTH-LineaWorldRules.GRID_HALF)
		var seeded := RandomNumberGenerator.new()
		seeded.seed = 9827601+id*7919
		pos = Vector3(cell.x*8+4+seeded.randf_range(-2.0,2.0),0,cell.y*8+4+seeded.randf_range(-2.0,2.0))
		if pos.length() < 90 or pos.length() > MOUNTAIN_RADIUS-5:
			return {}
		for landmark in door_positions+trap_positions+echo_positions:
			if pos.distance_to(landmark) < 4:
				return {}
	return {"id":id,"position":pos,"marked":marked_ids.has(id)}

func chunk_tree_ids(key: Vector2i) -> Array[int]:
	var ids: Array[int] = []
	for id in legacy_positions.size():
		if chunk_key(legacy_positions[id]) == key:
			ids.append(id)
	for x in range(key.x*6,key.x*6+6):
		for z in range(key.y*6,key.y*6+6):
			if absi(x)>100 or absi(z)>100:
				continue
			var id := 240+(x+100)*201+(z+100)
			if not tree_data(id).is_empty():
				ids.append(id)
	return ids

func add_multimesh(parent: Node3D, geometry: Mesh, mat: Material, transforms: Array[Transform3D], shadows: bool = false) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = geometry
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i,transforms[i])
	node.multimesh = mm
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

func load_chunk(key: Vector2i) -> void:
	var root := Node3D.new()
	root.name = "Forest_%d_%d" % [key.x,key.y]
	add_child(root)
	var ids := chunk_tree_ids(key)
	var transforms: Array[Transform3D] = []
	var random := RandomNumberGenerator.new()
	random.seed = 9827601+key.x*7307+key.y*7919
	for id in ids:
		var data := tree_data(id)
		trees[id] = data
		var basis := Basis(Vector3.UP,random.randf_range(0,TAU)).scaled(Vector3.ONE*random.randf_range(0.9,1.3))
		transforms.append(Transform3D(basis,data.position))
	var variant := posmod(key.x*13+key.y*7,6)
	var instance := add_multimesh(root,tree_meshes[variant],bark,transforms,true)
	chunks[key] = {"node":root,"ids":ids,"mesh":instance,"variant":variant,"lod":false}
	for id in ids:
		if marked_ids.has(id):
			build_mark(id,root)
	var blades: Array[Transform3D] = []
	var rocks: Array[Transform3D] = []
	for i in 115:
		var pos := Vector3(key.x*48+random.randf_range(0,48),0,key.y*48+random.randf_range(0,48))
		if pos.length() < 4.5: continue
		var scale_value := random.randf_range(0.4,1)
		blades.append(Transform3D(Basis(Vector3.UP,random.randf_range(0,TAU)).scaled(Vector3.ONE*scale_value),pos))
		if i < 7:
			rocks.append(Transform3D(Basis(Vector3.UP,random.randf_range(0,TAU)).scaled(Vector3(0.8,0.5,1.1)),pos))
	add_multimesh(root,grass_geometry,grass_material,blades)
	add_multimesh(root,rock_geometry,rock_material,rocks)
	for i in 2:
		var plane := MeshInstance3D.new()
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(23,12)
		plane.mesh = mesh
		plane.material_override = mist_material
		plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(plane)
		plane.position = Vector3(key.x*48+random.randf_range(2,46),random.randf_range(0.25,0.7),key.y*48+random.randf_range(2,46))

func update_streaming(pos: Vector3, force: bool = false) -> void:
	var center := chunk_key(pos)
	if force or center != chunk_center:
		chunk_center = center
		var wanted: Dictionary = {}
		for x in range(center.x-2,center.x+3):
			for z in range(center.y-2,center.y+3):
				var key := Vector2i(x,z)
				wanted[key] = true
				if not chunks.has(key):
					load_chunk(key)
		for key in chunks.keys():
			if not wanted.has(key):
				for id in chunks[key].ids:
					trees.erase(id)
				chunks[key].node.queue_free()
				chunks.erase(key)
			else:
				var data: Dictionary = chunks[key]
				var far := absi(key.x-center.x)>1 or absi(key.y-center.y)>1
				data.mesh.multimesh.mesh = distant_meshes[data.variant] if far else tree_meshes[data.variant]
				data.mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if far else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				data.lod = far
	if force or pos.distance_to(collision_center) > 12:
		collision_center = pos
		var wanted_bodies: Dictionary = {}
		for data in nearby_trees(pos,38):
			wanted_bodies[data.id] = true
			if not collision_trees.has(data.id):
				var body := StaticBody3D.new()
				var cs := CollisionShape3D.new()
				var shape := CylinderShape3D.new()
				shape.radius = 0.4
				shape.height = 5
				cs.shape = shape
				cs.position.y = 2.5
				body.add_child(cs)
				add_child(body)
				body.position = data.position
				var camera_body := StaticBody3D.new()
				camera_body.collision_layer = 2
				camera_body.collision_mask = 0
				var camera_shape := CollisionShape3D.new()
				var camera_volume := CylinderShape3D.new()
				camera_volume.radius = 1.25
				camera_volume.height = 11
				camera_shape.shape = camera_volume
				camera_shape.position.y = 5.5
				camera_body.add_child(camera_shape)
				add_child(camera_body)
				camera_body.position = data.position
				collision_trees[data.id] = [body,camera_body]
		for id in collision_trees.keys():
			if not wanted_bodies.has(id):
				for body in collision_trees[id]: body.queue_free()
				collision_trees.erase(id)

func nearby_trees(pos: Vector3, radius: float = 2.5) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var first := chunk_key(pos-Vector3(radius,0,radius))
	var last := chunk_key(pos+Vector3(radius,0,radius))
	for x in range(first.x,last.x+1):
		for z in range(first.y,last.y+1):
			var key := Vector2i(x,z)
			if chunks.has(key):
				for id in chunks[key].ids:
					if trees[id].position.distance_to(pos) <= radius:
						result.append(trees[id])
	return result

func mark_tree(id: int) -> void:
	var data := tree_data(id)
	if data.is_empty(): return
	marked_ids[id] = true
	if trees.has(id):
		trees[id].marked = true
		build_mark(id,chunks[chunk_key(data.position)].node)

func build_mark(id: int, parent: Node3D) -> void:
	var data := tree_data(id)
	var mark_name := "Mark_%d" % id
	if parent.has_node(mark_name): return
	var root := Node3D.new()
	root.name = mark_name
	parent.add_child(root)
	root.position = data.position
	for side in 4:
		var holder := Node3D.new()
		root.add_child(holder)
		holder.rotation.y = side*PI/2
		for angle in [-0.65,0.65]:
			var cut := LineaArt.box(holder,Vector3(0.045,0.42,0.045),Vector3(0,1.28,0.37),mark_material)
			cut.rotation.z = angle

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

func apply_quality() -> void:
	sun.shadow_enabled = int(State.settings.quality) > 0

func build_focus_marker() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 32:
		if i%8 >= 5:
			continue
		var a := i*TAU/32.0
		var b := (i+1)*TAU/32.0
		var inner_a := Vector3(cos(a)*0.92,0,sin(a)*0.92)
		var outer_a := Vector3(cos(a),0,sin(a))
		var inner_b := Vector3(cos(b)*0.92,0,sin(b)*0.92)
		var outer_b := Vector3(cos(b),0,sin(b))
		for vertex in [inner_a,outer_a,inner_b,inner_b,outer_a,outer_b]:
			st.set_normal(Vector3.UP)
			st.add_vertex(vertex)
	focus_marker = MeshInstance3D.new()
	focus_marker.name = "InteractionFocus"
	focus_marker.mesh = st.commit()
	focus_material = ShaderMaterial.new()
	focus_material.shader = load("res://shaders/focus.gdshader")
	focus_marker.material_override = focus_material
	focus_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	focus_marker.visible = false
	add_child(focus_marker)

func focus_at(pos: Vector3, kind: String, already_marked: bool = false) -> void:
	focus_marker.visible = true
	focus_marker.position = Vector3(pos.x,0.09,pos.z)
	var radius := 0.95 if kind == "tree" else (1.3 if kind == "trap" else 1.15)
	focus_marker.scale = Vector3(radius,1,radius)
	var color := Color("9cbea1")
	if kind == "trap": color = Color("d6a86c")
	elif already_marked: color = Color("b8ae87")
	focus_material.set_shader_parameter("tint",color)

func play_wood_chips(pos: Vector3) -> void:
	var root := Node3D.new()
	root.name = "BarkChips"
	add_child(root)
	root.position = pos
	var chip_material := LineaArt.material(Color("baa17a"))
	for i in 7:
		var chip := LineaArt.box(root,Vector3(0.04,0.08,0.04),Vector3.ZERO,chip_material)
		var angle := float(i)*TAU/7
		var end := Vector3(cos(angle)*0.4,-0.75,sin(angle)*0.4)
		var tween := root.create_tween().set_parallel(true)
		tween.tween_property(chip,"position",end,0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(chip,"scale",Vector3.ZERO,0.45)
	root.create_tween().tween_callback(root.queue_free).set_delay(0.5)
