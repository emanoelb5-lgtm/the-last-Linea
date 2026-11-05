class_name LineaArt
extends RefCounted
## Small original meshes, instanced across the forest. No downloaded art.
static func material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	return mat

static func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = mat
	parent.add_child(node)
	node.position = pos
	return node

static func cylinder(bottom: float, top: float, height: float, sides: int = 6) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	return mesh

static func limb(st: SurfaceTool, a: Vector3, b: Vector3, bottom: float, top: float) -> void:
	var direction := (b - a).normalized()
	var transform := Transform3D(Basis(Quaternion(Vector3.UP, direction)), (a + b) * 0.5)
	st.append_from(cylinder(bottom, top, a.distance_to(b)), 0, transform)

static func tree_mesh(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var height := rng.randf_range(4.7, 7.0)
	var lean := Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
	limb(st, Vector3.ZERO, Vector3(lean.x, height, lean.z), 0.35, 0.09)
	for i in 5:
		var angle := float(i) * 2.4 + rng.randf_range(-0.4, 0.4)
		var start := Vector3(lean.x * 0.6, height * rng.randf_range(0.45, 0.78), lean.z * 0.6)
		var end := start + Vector3(cos(angle) * 1.6, rng.randf_range(0.5, 1.2), sin(angle) * 1.6)
		limb(st, start, end, 0.14, 0.045)
		limb(st, end, end + Vector3(cos(angle + 0.5) * 0.6, 1.2, sin(angle + 0.5) * 0.6), 0.048, 0.012)
	for i in 4:
		var a := float(i) * TAU / 4.0
		limb(st, Vector3(0, 0.4, 0), Vector3(cos(a) * 0.8, 0.02, sin(a) * 0.8), 0.18, 0.025)
	return st.commit()

static func grass_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 3:
		var a := float(i) * PI / 3
		var offset := Vector3(cos(a) * 0.2, 0, sin(a) * 0.2)
		st.set_normal(Vector3.UP)
		st.add_vertex(-offset)
		st.add_vertex(offset)
		st.add_vertex(Vector3(offset.x * 1.8, 0.55 + i * 0.08, offset.z * 1.8))
	return st.commit()

static func collider(parent: Node3D, size: Vector3, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	body.position = pos
	return body

static func character(parent: Node3D) -> Dictionary:
	var rig := Node3D.new()
	rig.name = "Man"
	parent.add_child(rig)
	var coat := material(Color("39464a"))
	var trim := material(Color("52615f"))
	var skin := material(Color("b89c83"))
	var hair := material(Color("292c2b"))
	var boot := material(Color("242c2e"))
	var scarf := material(Color("925d45"))
	var leather := material(Color("655540"))
	box(rig, Vector3(0.58, 0.65, 0.35), Vector3(0, 1.02, 0), coat)
	box(rig, Vector3(0.62, 0.28, 0.39), Vector3(0, 0.65, 0), coat)
	box(rig, Vector3(0.58, 0.075, 0.38), Vector3(0, 0.85, 0), leather)
	box(rig, Vector3(0.065, 0.65, 0.02), Vector3(0, 1.02, -0.19), trim)
	box(rig, Vector3(0.44, 0.44, 0.4), Vector3(0, 1.6, 0), skin)
	box(rig, Vector3(0.47, 0.17, 0.43), Vector3(0, 1.8, 0.01), hair)
	box(rig, Vector3(0.47, 0.22, 0.08), Vector3(0, 1.63, 0.2), hair)
	for x in [-0.12, 0.12]:
		box(rig, Vector3(0.055, 0.055, 0.025), Vector3(x, 1.61, -0.21), hair)
	box(rig, Vector3(0.53, 0.15, 0.42), Vector3(0, 1.35, 0), scarf)
	box(rig, Vector3(0.16, 0.4, 0.045), Vector3(-0.14, 1.17, 0.21), scarf)
	box(rig, Vector3(0.27, 0.33, 0.2), Vector3(0.36, 0.8, 0.04), leather)
	var limbs: Array[Node3D] = []
	for i in 4:
		var pivot := Node3D.new()
		rig.add_child(pivot)
		var side := -1.0 if i % 2 == 0 else 1.0
		if i < 2:
			pivot.position = Vector3(side * 0.17, 0.59, 0)
			box(pivot, Vector3(0.22, 0.42, 0.24), Vector3(0, -0.22, 0), trim)
			box(pivot, Vector3(0.24, 0.16, 0.34), Vector3(0, -0.52, -0.04), boot)
		else:
			pivot.position = Vector3(side * 0.4, 1.26, 0)
			box(pivot, Vector3(0.2, 0.43, 0.24), Vector3(0, -0.2, 0), coat)
			box(pivot, Vector3(0.16, 0.14, 0.18), Vector3(0, -0.46, 0), skin)
		limbs.append(pivot)
	var lantern := Node3D.new()
	limbs[3].add_child(lantern)
	lantern.position = Vector3(0, -0.63, -0.03)
	box(lantern, Vector3(0.22, 0.3, 0.22), Vector3.ZERO, material(Color("a68a52")))
	box(lantern, Vector3(0.15, 0.19, 0.235), Vector3.ZERO, material(Color("e2b86b"), 1.2))
	box(lantern, Vector3(0.24, 0.045, 0.24), Vector3(0, 0.17, 0), boot)
	var light := OmniLight3D.new()
	light.light_color = Color("ffd39a")
	light.light_energy = 1.1
	light.omni_range = 5.5
	light.omni_attenuation = 1.6
	light.shadow_enabled = false
	lantern.add_child(light)
	return {"rig": rig, "limbs": limbs, "light": light}
