class_name LineaHumanoid
extends RefCounted
## A young adult human silhouette built from tapered anatomical volumes, not voxels.
## Pixel detail comes from the fabric shader and the game's low-res viewport.

static func material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.95
	result.metallic_specular = 0.15
	if glow > 0:
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = glow
	return result

static func cylinder(bottom: float, top: float, height: float, sides: int) -> CylinderMesh:
	var result := CylinderMesh.new()
	result.bottom_radius = bottom
	result.top_radius = top
	result.height = height
	result.radial_segments = sides
	result.rings = 1
	return result

static func fabric(color: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/fabric.gdshader")
	mat.set_shader_parameter("base_color",color)
	return mat

static func mesh(parent: Node3D, geometry: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.mesh = geometry
	result.material_override = mat
	parent.add_child(result)
	result.position = pos
	return result

static func oval(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, sides: int = 12) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = 0.5
	shape.height = 1.0
	shape.radial_segments = sides
	shape.rings = 6
	var result := mesh(parent,shape,pos,mat)
	result.scale = size
	return result

static func volume(rings: Array, sides: int = 12) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(rings.size()-1):
		var lower: Vector3 = rings[j]
		var upper: Vector3 = rings[j+1]
		for i in sides:
			var a := i*TAU/sides
			var b := (i+1)*TAU/sides
			var vertices := [Vector3(sin(a)*lower.y,lower.x,cos(a)*lower.z),Vector3(sin(b)*lower.y,lower.x,cos(b)*lower.z),Vector3(sin(a)*upper.y,upper.x,cos(a)*upper.z),Vector3(sin(b)*upper.y,upper.x,cos(b)*upper.z)]
			var uvs := [Vector2(float(i)/sides,float(j)/(rings.size()-1)),Vector2(float(i+1)/sides,float(j)/(rings.size()-1)),Vector2(float(i)/sides,float(j+1)/(rings.size()-1)),Vector2(float(i+1)/sides,float(j+1)/(rings.size()-1))]
			for index in [0,2,1,2,3,1]:
				st.set_uv(uvs[index])
				st.add_vertex(vertices[index])
	st.generate_normals()
	return st.commit()

static func tube(parent: Node3D, start: Vector3, finish: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var geometry := cylinder(radius,radius*0.8,start.distance_to(finish),8)
	var node := mesh(parent,geometry,(start+finish)*0.5,mat)
	node.basis = Basis(Quaternion(Vector3.UP,(finish-start).normalized()))
	return node

static func create(parent: Node3D) -> Dictionary:
	var rig := Node3D.new()
	rig.name = "YoungTraveler"
	rig.scale = Vector3.ONE*0.96
	parent.add_child(rig)
	var coat := fabric(Color("344f51"))
	var trousers := fabric(Color("535b59"))
	var skin := material(Color("c7a080"))
	var leather := material(Color("5f4938"))
	var boots := material(Color("29312f"))
	var hair := material(Color("332c27"))
	var scarf := fabric(Color("9b5d43"))
	var steel := material(Color("b8c7c3"),0.1)
	# Pelvis, tapered waist, ribcage and sloping shoulder line.
	var pelvis := mesh(rig,volume([Vector3(0.87,0.12,0.09),Vector3(0.94,0.175,0.125),Vector3(1.06,0.17,0.12)]),Vector3.ZERO,trousers)
	mesh(rig,volume([Vector3(0.95,0.175,0.13),Vector3(1.08,0.155,0.115),Vector3(1.25,0.195,0.125),Vector3(1.38,0.205,0.12),Vector3(1.46,0.13,0.085)]),Vector3.ZERO,coat)
	mesh(rig,volume([Vector3(1.015,0.174,0.127),Vector3(1.055,0.171,0.125)]),Vector3.ZERO,leather)
	tube(rig,Vector3(0,1.07,-0.126),Vector3(0,1.39,-0.126),0.008,boots)
	for side in [-1.0,1.0]:
		var lapel := oval(rig,Vector3(0.075,0.22,0.025),Vector3(side*0.095,1.34,-0.12),coat)
		lapel.rotation.z = side*-0.4
		oval(rig,Vector3(0.07,0.045,0.02),Vector3(side*0.11,1.17,-0.125),leather)
	tube(rig,Vector3(0,1.44,0),Vector3(0,1.56,0),0.061,skin)
	# The head is about one seventh of total height, with a chin and jaw.
	var head := Node3D.new()
	head.name = "Head"
	rig.add_child(head)
	head.position = Vector3(0,1.635,0)
	head.scale = Vector3(1.035,0.94,1.0)
	mesh(head,volume([Vector3(-0.13,0.036,0.04),Vector3(-0.105,0.066,0.074),Vector3(-0.045,0.094,0.1),Vector3(0.035,0.105,0.106),Vector3(0.1,0.097,0.09),Vector3(0.145,0.035,0.04)]),Vector3.ZERO,skin)
	mesh(head,volume([Vector3(0.075,0.104,0.099),Vector3(0.12,0.099,0.094),Vector3(0.16,0.06,0.055),Vector3(0.165,0.002,0.002)]),Vector3.ZERO,hair)
	oval(head,Vector3(0.19,0.15,0.07),Vector3(0,0.035,0.081),hair)
	for side in [-1.0,1.0]:
		oval(head,Vector3(0.042,0.071,0.042),Vector3(side*0.106,-0.005,0),skin,8)
		oval(head,Vector3(0.038,0.018,0.012),Vector3(side*0.044,0.022,-0.101),material(Color("e0d3bc")),8)
		oval(head,Vector3(0.012,0.014,0.008),Vector3(side*0.043,0.022,-0.108),boots,8)
		tube(head,Vector3(side*0.025,0.052,-0.102),Vector3(side*0.066,0.054,-0.095),0.005,hair)
	oval(head,Vector3(0.029,0.048,0.036),Vector3(0,-0.012,-0.112),skin,8)
	var mouth := oval(head,Vector3(0.038,0.009,0.01),Vector3(0,-0.056,-0.104),material(Color("694d40")),8)
	for i in 5:
		var lock := oval(head,Vector3(0.052,0.095,0.045),Vector3(-0.077+i*0.036,0.085-0.008*(i%2),-0.077),hair,8)
		lock.rotation.z = -0.38+i*0.09
	# A wrapped scarf and a narrow hanging cloth, not a rectangular torso.
	mesh(rig,volume([Vector3(1.45,0.08,0.075),Vector3(1.5,0.09,0.085),Vector3(1.54,0.065,0.065)]),Vector3.ZERO,scarf)
	var cloth := mesh(rig,volume([Vector3(1.14,0.035,0.014),Vector3(1.27,0.043,0.019),Vector3(1.47,0.035,0.022)],6),Vector3(-0.065,0,-0.135),scarf)
	cloth.rotation.z = -0.06
	# Thigh/knee/calf and upper-arm/elbow/forearm are independently articulated.
	var limbs: Array[Node3D] = []
	var joints: Array[Node3D] = []
	var feet: Array[Node3D] = []
	for i in 4:
		var side := -1.0 if i%2 == 0 else 1.0
		var pivot := Node3D.new()
		var joint := Node3D.new()
		rig.add_child(pivot)
		pivot.add_child(joint)
		if i < 2:
			pivot.name = "LeftHip" if i == 0 else "RightHip"
			pivot.position = Vector3(side*0.097,0.955,0)
			joint.name = "Knee"
			joint.position.y = -0.425
			mesh(pivot,volume([Vector3(-0.425,0.067,0.072),Vector3(-0.23,0.087,0.09),Vector3(0,0.089,0.095)]),Vector3.ZERO,trousers)
			oval(pivot,Vector3(0.14,0.14,0.14),Vector3(0,-0.4,0),trousers,10)
			mesh(joint,volume([Vector3(-0.36,0.048,0.052),Vector3(-0.18,0.063,0.068),Vector3(0,0.064,0.07)]),Vector3.ZERO,trousers)
			var ankle := Node3D.new()
			ankle.name = "Ankle"
			joint.add_child(ankle)
			ankle.position.y = -0.425
			oval(ankle,Vector3(0.13,0.17,0.245),Vector3(0,-0.015,-0.045),boots,10)
			mesh(ankle,volume([Vector3(0.02,0.058,0.061),Vector3(0.20,0.057,0.06)]),Vector3.ZERO,boots)
			feet.append(ankle)
		else:
			pivot.name = "LeftShoulder" if i == 2 else "RightShoulder"
			pivot.position = Vector3(side*0.214,1.385,0)
			joint.name = "Elbow"
			joint.position.y = -0.335
			oval(pivot,Vector3(0.16,0.19,0.18),Vector3(0,-0.045,0),coat)
			mesh(pivot,volume([Vector3(-0.335,0.052,0.057),Vector3(-0.14,0.071,0.075),Vector3(0.01,0.073,0.078)]),Vector3.ZERO,coat)
			oval(pivot,Vector3(0.106,0.1,0.11),Vector3(0,-0.33,0),coat)
			mesh(joint,volume([Vector3(-0.3,0.038,0.043),Vector3(-0.17,0.054,0.058),Vector3(0,0.051,0.056)]),Vector3.ZERO,coat)
			oval(joint,Vector3(0.072,0.135,0.052),Vector3(0,-0.352,0),skin,10)
			oval(joint,Vector3(0.028,0.07,0.035),Vector3(-side*0.04,-0.342,-0.01),skin,8)
		limbs.append(pivot)
		joints.append(joint)
	var bag := oval(rig,Vector3(0.19,0.235,0.13),Vector3(0.23,1.02,0.035),leather,10)
	bag.rotation.z = -0.15
	tube(rig,Vector3(-0.15,1.4,-0.135),Vector3(0.19,1.03,-0.135),0.018,leather)
	var knife := Node3D.new()
	knife.name = "MarkingKnife"
	joints[2].add_child(knife)
	knife.position = Vector3(0,-0.365,0)
	tube(knife,Vector3.ZERO,Vector3(0,-0.1,0),0.023,leather)
	tube(knife,Vector3(-0.055,-0.1,0),Vector3(0.055,-0.1,0),0.012,steel)
	mesh(knife,volume([Vector3(-0.43,0.001,0.001),Vector3(-0.16,0.008,0.035),Vector3(-0.115,0.009,0.038)],4),Vector3.ZERO,steel)
	var lantern := Node3D.new()
	joints[3].add_child(lantern)
	lantern.position = Vector3(0,-0.49,-0.01)
	var glow := material(Color("e9c17e"),1.2)
	mesh(lantern,cylinder(0.075,0.065,0.17,8),Vector3.ZERO,glow)
	for y in [-0.105,0.105]:
		mesh(lantern,cylinder(0.09,0.08,0.035,8),Vector3(0,y,0),boots)
	for i in 4:
		var a := i*TAU/4
		tube(lantern,Vector3(cos(a)*0.073,-0.1,sin(a)*0.073),Vector3(cos(a)*0.073,0.1,sin(a)*0.073),0.008,boots)
	tube(lantern,Vector3(-0.05,0.11,0),Vector3(0,0.2,0),0.01,boots)
	tube(lantern,Vector3(0,0.2,0),Vector3(0.05,0.11,0),0.01,boots)
	var light := OmniLight3D.new()
	light.light_color = Color("ffd39a")
	light.light_energy = 1.1
	light.omni_range = 5.5
	light.omni_attenuation = 1.6
	lantern.add_child(light)
	# A pelvis hinge lets the chest lean independently of planted legs.
	var upper := Node3D.new()
	upper.name = "ChestPivot"
	rig.add_child(upper)
	upper.position.y = 0.955
	for child in rig.get_children():
		if child not in [upper,pelvis,limbs[0],limbs[1]]:
			child.reparent(upper,true)
	return {"rig":rig,"limbs":limbs,"joints":joints,"feet":feet,"upper":upper,"head":head,"mouth":mouth,"light":light,"knife":knife,"lantern":lantern}
