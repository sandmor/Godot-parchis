extends Node3D
## Short-lived travel and gate effects; never consumes the rules RNG.
var trails: Array[Dictionary] = []
var elapsed := 0.0

func follow(unit: Node3D, color: Color) -> void:
	trails.append({"unit": unit, "color": color})

func stop(unit: Node3D) -> void:
	trails = trails.filter(func(entry: Dictionary): return entry.unit != unit)

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed < .045:
		return
	elapsed = 0
	for entry in trails:
		if is_instance_valid(entry.unit):
			spark(entry.unit.position + Vector3(0, .35, 0), entry.color, .1, .35)

func spark(pos: Vector3, color: Color, radius: float, duration: float) -> void:
	var item := MeshInstance3D.new()
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2
	item.mesh = shape
	item.position = pos
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color, .8)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.3
	item.material_override = mat
	add_child(item)
	var tween := create_tween().set_parallel()
	tween.tween_property(item, "scale", Vector3.ONE * .02, duration)
	tween.tween_property(mat, "albedo_color:a", 0.0, duration)
	tween.chain().tween_callback(item.queue_free)

func burst(pos: Vector3, color: Color) -> void:
	for index in range(12):
		var angle := index * TAU / 12.0
		var offset := Vector3(cos(angle), .2, sin(angle))
		spark(pos + offset * .4, color, .1, .7)
	var item := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = .36
	ring.outer_radius = .4
	item.mesh = ring
	item.position = pos + Vector3(0, .15, 0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	item.material_override = mat
	add_child(item)
	var tween := create_tween().set_parallel()
	tween.tween_property(item, "scale", Vector3.ONE * 3, .65)
	tween.tween_property(mat, "albedo_color:a", 0.0, .65)
	tween.chain().tween_callback(item.queue_free)
