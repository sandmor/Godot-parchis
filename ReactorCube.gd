extends RigidBody3D
## One machined shell and six flush, inset pip panels. No protruding pip meshes.
signal collision_hit(strength: float, point: Vector3)
const ENERGY_SHADER := preload("res://shaders/reactor_energy.gdshader")
const FACE_SHADER := preload("res://shaders/reactor_die.gdshader")
const NORMALS := [Vector3.UP,Vector3.BACK,Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.DOWN]
var face_materials: Array[ShaderMaterial] = []
var shell_material: StandardMaterial3D
var energy_material: ShaderMaterial
var glow_light: OmniLight3D
var emission_color := Color("20f9cf")
var contacts_enabled := false
var impact_count := 0
var _contact_cooldown := 0.0
var _flare := 0.0
var support_vertices := PackedVector3Array()
static var _shell: ArrayMesh

func build(color: Color) -> void:
	if not _shell: _shell = beveled_box(Vector3.ONE*1.34,.105)
	support_vertices = _shell.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var shell := MeshInstance3D.new()
	shell.mesh = _shell
	shell_material = StandardMaterial3D.new()
	shell_material.albedo_color = color.lightened(.08)
	shell_material.metallic = .75
	shell_material.roughness = .32
	shell.material_override = shell_material
	add_child(shell)
	mass = 1.0
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 12
	freeze = true
	gravity_scale = 1.35
	linear_damp = .08
	angular_damp = .18
	var physics := PhysicsMaterial.new()
	physics.friction = .5
	physics.bounce = .52
	physics_material_override = physics
	var collider := CollisionShape3D.new()
	var hull := ConvexPolygonShape3D.new()
	hull.points = support_vertices
	collider.shape = hull
	add_child(collider)
	energy_material = ShaderMaterial.new()
	energy_material.shader = ENERGY_SHADER
	for axis in range(3):
		for a in [-1,1]:
			for b in [-1,1]:
				var edge := MeshInstance3D.new()
				var tube := CylinderMesh.new()
				tube.top_radius = .013
				tube.bottom_radius = .013
				tube.height = 1.04
				tube.radial_segments = 8
				edge.mesh = tube
				if axis == 0:
					edge.position = Vector3(0,a*.617,b*.617)
					edge.rotation.z = PI/2
				elif axis == 1:
					edge.position = Vector3(a*.617,0,b*.617)
				else:
					edge.position = Vector3(a*.617,b*.617,0)
					edge.rotation.x = PI/2
				edge.material_override = energy_material
				add_child(edge)
	glow_light = OmniLight3D.new()
	glow_light.omni_range = 2.4
	glow_light.light_energy = .65
	add_child(glow_light)
	for value in range(1,7):
		var normal: Vector3 = NORMALS[value-1]
		var tangent := Vector3.RIGHT if absf(normal.x)<.5 else Vector3.BACK
		var panel := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE*1.105
		panel.mesh = quad
		panel.basis = Basis(tangent,normal.cross(tangent),normal)
		panel.position = normal*.671
		var material := ShaderMaterial.new()
		material.shader = FACE_SHADER
		material.set_shader_parameter("value",value)
		material.set_shader_parameter("shell_color",color)
		panel.material_override = material
		face_materials.append(material)
		add_child(panel)

func illuminate(color: Color, amount: float) -> void:
	for material in face_materials:
		material.set_shader_parameter("accent",color)
		material.set_shader_parameter("reveal",amount)
		material.set_shader_parameter("energy_color",emission_color)
	energy_material.set_shader_parameter("energy_color",emission_color)
	glow_light.light_color = emission_color

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	_contact_cooldown = maxf(0,_contact_cooldown-state.step)
	if not contacts_enabled: return
	var strongest := 0.0
	var point := global_position
	for contact in range(state.get_contact_count()):
		var impulse := state.get_contact_impulse(contact).length()
		if impulse > strongest:
			strongest = impulse
			point = state.get_contact_local_position(contact)
	if strongest > .65 and _contact_cooldown <= 0:
		_contact_cooldown = .09
		impact_count += 1
		_flare = minf(strongest/9,1)
		collision_hit.emit(strongest,point)

func _process(delta: float) -> void:
	_flare = move_toward(_flare,0,delta*5)
	if energy_material: energy_material.set_shader_parameter("flare",_flare)

func top_face() -> int:
	var selected := 0
	var highest := -2.0
	for index in range(6):
		var up: float = (basis*NORMALS[index]).y
		if up > highest:
			highest = up
			selected = index
	return selected

func top_value() -> int:
	return int(face_materials[top_face()].get_shader_parameter("value"))

func support_height() -> float:
	var height := 0.0
	for vertex in support_vertices:
		height = maxf(height,-(basis*vertex).y)
	return height+.006

static func beveled_box(dimensions: Vector3, bevel: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	var half := dimensions*.5
	var rings: Array[PackedVector3Array] = []
	bevel = minf(bevel,minf(minf(half.x,half.y),half.z)*.7)
	for band in range(4):
		var inset := bevel if band in [0,3] else 0.0
		var x := half.x-inset
		var z := half.z-inset
		var cut := bevel*.6
		var y: float = [-half.y,-half.y+bevel,half.y-bevel,half.y][band]
		rings.append(PackedVector3Array([Vector3(-x+cut,y,-z),Vector3(x-cut,y,-z),Vector3(x,y,-z+cut),Vector3(x,y,z-cut),Vector3(x-cut,y,z),Vector3(-x+cut,y,z),Vector3(-x,y,z-cut),Vector3(-x,y,-z+cut)]))
	for band in range(3):
		for index in range(8):
			var next := (index+1)%8
			_triangle(surface,rings[band][index],rings[band+1][index],rings[band+1][next])
			_triangle(surface,rings[band][index],rings[band+1][next],rings[band][next])
	for index in range(8):
		var next := (index+1)%8
		_triangle(surface,Vector3(0,-half.y,0),rings[0][index],rings[0][next])
		_triangle(surface,Vector3(0,half.y,0),rings[3][next],rings[3][index])
	surface.generate_normals()
	return surface.commit()

static func _triangle(surface: SurfaceTool,a: Vector3,b: Vector3,c: Vector3) -> void:
	for point in [a,c,b]: surface.add_vertex(point)
