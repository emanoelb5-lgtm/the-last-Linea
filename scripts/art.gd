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
	return LineaHumanoid.create(parent)
