@tool
extends Node3D
## Procedural sci-fi parqués arena. Navigation positions are in board-local space.
## The shared circuit is ordered; home lanes run from entrance to goal.

@export var rebuild_in_editor: bool = false:
	set(value):
		if value and is_inside_tree():
			generate_board()
		rebuild_in_editor = false
@export_group("Grid Settings")
@export_range(0.5, 2.0, 0.05) var tile_spacing: float = 1.0
@export var tile_size: Vector3 = Vector3(0.86, 0.14, 0.86)
@export_group("Arena Visuals")
@export var enable_decorations: bool = true
@export_range(0.0, 2.0, 0.05) var neon_intensity: float = 0.85
@export var base_color: Color = Color("111e30")

const CIRCUIT_LENGTH := 96
const ARM_LENGTH := 12
const SECTOR_LENGTH := 24
const HOME_LENGTH := 10
const DECK_SCALE := 4.0 / 3.0
const GENERATED_NAME := "GeneratedArena"
const TEAM_NAMES := ["CRIMSON", "VIRIDIAN", "AZURE", "SOLAR"]
const DIRECTIONS := [Vector3.FORWARD, Vector3.RIGHT, Vector3.BACK, Vector3.LEFT]
const CORNERS := [Vector3(-5.8, 0, -5.8), Vector3(5.8, 0, -5.8), Vector3(5.8, 0, 5.8), Vector3(-5.8, 0, 5.8)]
const CYAN := Color("45ddeb")
var player_colors: Array[Color] = [Color("ff536c"), Color("48e7a0"), Color("5c9dff"), Color("ffcf58")]
var main_path_positions: Array[Vector3] = []
var home_path_positions: Array[Array] = [[], [], [], []]
var jail_positions: Array[Array] = [[], [], [], []]
var pawn_nodes: Array[Array] = [[], [], [], []]
var launch_indices: Array[int] = []
var safe_indices: Array[int] = []
var center_goal_position := Vector3.ZERO
var _root: Node3D
var _materials: Dictionary = {}
var _hologram: Node3D
var _time := 0.0
var coordinates_visible := false
const Unit := preload("res://UnitVisual.gd")

func _ready() -> void:
	generate_board()

func generate_board() -> void:
	# Only replace generated geometry, preserving any user-authored children.
	var previous := get_node_or_null(GENERATED_NAME)
	if previous:
		remove_child(previous)
		previous.queue_free()
	_materials.clear()
	main_path_positions.clear()
	home_path_positions = [[], [], [], []]
	jail_positions = [[], [], [], []]
	pawn_nodes = [[], [], [], []]
	launch_indices.clear()
	safe_indices.clear()
	_hologram = null
	_root = Node3D.new()
	_root.name = GENERATED_NAME
	add_child(_root)
	_build_base_platform()
	_build_main_circuit()
	_build_home_paths()
	_build_jails()
	_build_center_goal()
	if enable_decorations:
		_build_visual_decorations()

func is_protected_cell(index: int) -> bool:
	return index in safe_indices or index in launch_indices

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_instance_valid(_hologram):
		return
	_time += delta
	_hologram.rotation.y += delta * 0.35
	_hologram.position.y = 1.4 + sin(_time * 1.4) * 0.12

func _group(node_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	_root.add_child(node)
	return node

func _build_base_platform() -> void:
	var group := _group("PlatformFoundation")
	# Floating causeways leave the painted orbital environment visible between outposts.
	_box(group, Vector3(0, -.35, 0), Vector3(3.35, .5, 25.6), Color("101b29"))
	_box(group, Vector3(0, -.35, 0), Vector3(25.6, .5, 3.35), Color("101b29"))
	for side in [-1.0, 1.0]:
		_box(group, Vector3(side * 1.64, -.12, 0), Vector3(.025, .04, 25.5), CYAN, .35)
		_box(group, Vector3(0, -.12, side * 1.64), Vector3(25.5, .04, .025), CYAN, .35)

func _build_main_circuit() -> void:
	var group := _group("MainPath")
	# 11 outward cells + 1 tip + 11 inward cells + 1 corner = 24 per arm.
	# All 96 cells, including sector transitions, are one grid step apart.
	for arm in range(4):
		var forward: Vector3 = DIRECTIONS[arm]
		var side := Vector3(-forward.z, 0, forward.x)
		for step in range(2, ARM_LENGTH + 1):
			main_path_positions.append((forward * step - side) * tile_spacing)
		main_path_positions.append(forward * ARM_LENGTH * tile_spacing)
		for step in range(ARM_LENGTH, 1, -1):
			main_path_positions.append((forward * step + side) * tile_spacing)
		main_path_positions.append((forward + side) * tile_spacing)
		launch_indices.append(arm * SECTOR_LENGTH + 3)
		# Three seguros per sector; salidas are protected separately.
		for offset in [8, 14, 20]:
			safe_indices.append(arm * SECTOR_LENGTH + offset)
	for index in range(main_path_positions.size()):
		var pos := main_path_positions[index]
		var team := floori(float(index) / SECTOR_LENGTH)
		var is_launch := index in launch_indices
		var is_safe := index in safe_indices
		var col := Color("24364a")
		if is_launch:
			col = player_colors[team].darkened(0.35)
		elif is_safe:
			col = Color("316371")
		var tile := _box(group, pos, tile_size * tile_spacing, col)
		tile.name = "Cell_%02d" % (index + 1)
		if is_safe or is_launch:
			var accent := player_colors[team] if is_launch else CYAN
			for sign_value in [-1.0, 1.0]:
				_box(group, pos + Vector3(sign_value * 0.41 * tile_spacing, 0.09, 0), Vector3(0.025, 0.025, 0.84) * tile_spacing, accent, 0.65)
				_box(group, pos + Vector3(0, 0.09, sign_value * 0.41 * tile_spacing), Vector3(0.84, 0.025, 0.025) * tile_spacing, accent, 0.65)
		_text(group, str(index + 1), pos + Vector3(0, 0.105, 0), 0.64 * tile_spacing, Color("d9e8ef"))
		group.get_child(-1).add_to_group("ArenaCoordinates")
		group.get_child(-1).visible = coordinates_visible
		if is_safe:
			_ring(group, pos + Vector3(0, .1, 0), .22 * tile_spacing, CYAN)
		elif is_launch:
			_box(group, pos + Vector3(0, .11, 0), Vector3(.3, .025, .3), player_colors[team], .7)

func _build_home_paths() -> void:
	var group := _group("HomePaths")
	for team in range(4):
		var forward: Vector3 = DIRECTIONS[team]
		# Ten approach cells connect the outer tip to the central goal.
		for step in range(ARM_LENGTH - 1, 1, -1):
			var pos := forward * step * tile_spacing
			home_path_positions[team].append(pos)
			_box(group, pos, tile_size * tile_spacing, player_colors[team].darkened(0.5))
			_box(group, pos + Vector3(0, 0.08, 0), Vector3(0.46, 0.018, 0.035) * tile_spacing, player_colors[team], 0.7)
		# A colored triangular finish points from each home lane toward the core.
		var mesh := ImmediateMesh.new()
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		mesh.surface_add_vertex((forward * 1.45 - Vector3(-forward.z, 0, forward.x) * 0.45) * tile_spacing)
		mesh.surface_add_vertex(forward * 0.35 * tile_spacing)
		mesh.surface_add_vertex((forward * 1.45 + Vector3(-forward.z, 0, forward.x) * 0.45) * tile_spacing)
		mesh.surface_end()
		var triangle := MeshInstance3D.new()
		triangle.mesh = mesh
		triangle.position.y = 0.1
		triangle.material_override = _material(player_colors[team], 0.5)
		group.add_child(triangle)

func _build_jails() -> void:
	var group := _group("JailBases")
	var slots := [Vector3(-1.1, 0.15, -1.1), Vector3(1.1, 0.15, -1.1), Vector3(-1.1, 0.15, 1.1), Vector3(1.1, 0.15, 1.1)]
	for team in range(4):
		var pos: Vector3 = CORNERS[team] * tile_spacing * DECK_SCALE
		var col := player_colors[team]
		var island := _cylinder(group, pos + Vector3(0, -.5, 0), 4.5 * tile_spacing, .7, col.darkened(.88))
		island.mesh = island.mesh.duplicate()
		island.mesh.radial_segments = 8 if team != 1 else 32
		_ring(group, pos + Vector3(0, -.12, 0), 4.1 * tile_spacing, col.darkened(.3))
		_build_outpost(group, pos, team)
		for slot in range(4):
			var pawn_pos: Vector3 = pos + slots[slot] * tile_spacing * DECK_SCALE
			jail_positions[team].append(pawn_pos)
			_cylinder(group, pawn_pos - Vector3(0, 0.08, 0), 0.58 * tile_spacing, 0.12, Color("24364a"))
			_ring(group, pawn_pos, 0.48 * tile_spacing, col)
			pawn_nodes[team].append(_build_pawn(group, pawn_pos, team, slot))

func _build_pawn(parent: Node3D, pos: Vector3, team: int, slot: int) -> Node3D:
	var pawn := Unit.new()
	pawn.name = "%s_Pawn_%d" % [TEAM_NAMES[team], slot + 1]
	pawn.position = pos
	pawn.scale = Vector3.ONE * tile_spacing
	parent.add_child(pawn)
	pawn.build(team, slot, player_colors[team])
	return pawn

func set_coordinates_visible(value: bool) -> void:
	coordinates_visible = value
	for label in get_tree().get_nodes_in_group("ArenaCoordinates"):
		if is_ancestor_of(label):
			label.visible = value

func _build_outpost(parent: Node3D, pos: Vector3, team: int) -> void:
	var col := player_colors[team]
	# Architecture stays outside the four launch slots and the shared causeway.
	for side in [-1.0, 1.0]:
		var origin := pos + Vector3(side * 2.8, 0, -2.3) * tile_spacing
		match team:
			0:
				_box(parent, origin + Vector3(0, .55, 0), Vector3(.75, 1.5, .8), Color("20242e"))
				_box(parent, origin + Vector3(0, 1.35, .1), Vector3(.8, .12, .7), col, .7)
				_box(parent, pos + Vector3(0, .15, -3.1), Vector3(4.9, .6, .45), Color("20242e"))
			1:
				var stem := _cylinder(parent, origin + Vector3(0, .6, 0), .16, 1.5, col.darkened(.7))
				stem.rotation.z = side * .25
				for leaf_index in range(3):
					var leaf := _box(parent, origin + Vector3(side * .3, .6 + leaf_index * .3, 0), Vector3(.7, .1, .38), col.darkened(.3), .15)
					leaf.rotation.z = side * .6
			2:
				var prism := _box(parent, origin + Vector3(0, 1, 0), Vector3(.38, 1.5, .38), col, .35)
				prism.rotation_degrees = Vector3(0, 45, 15 * side)
				_ring(parent, origin + Vector3(0, 1.7, 0), .6, col)
			3:
				var fin := _box(parent, origin + Vector3(0, .55, 0), Vector3(.16, 1.4, 1.3), col.darkened(.45))
				fin.rotation.z = side * -.3
				_box(parent, origin + Vector3(0, .12, .75), Vector3(.35, .25, .15), col, 1.0)

func _build_center_goal() -> void:
	var group := _group("CenterGoal")
	center_goal_position = Vector3.ZERO
	_cylinder(group, Vector3(0, -0.04, 0), 0.74 * tile_spacing, 0.18, Color("142438"))
	_cylinder(group, Vector3(0, 0.12, 0), 0.53 * tile_spacing, 0.25, Color("263e52"))
	_ring(group, Vector3(0, 0.27, 0), 0.45 * tile_spacing, CYAN)

func _build_visual_decorations() -> void:
	var group := _group("Decorations")
	for team in range(4):
		var corner: Vector3 = CORNERS[team].normalized() * 18.4 * tile_spacing
		_cylinder(group, corner + Vector3(0, -0.16, 0), 0.38 * tile_spacing, 0.4, Color("30445b"))
		_cylinder(group, corner + Vector3(0, 0.5, 0), 0.07 * tile_spacing, 1.2, player_colors[team], 1.0)
	# Thin etched circuits fill the deck without competing with the path.
	for team in range(4):
		var corner: Vector3 = CORNERS[team] * tile_spacing * DECK_SCALE
		for offset in [-0.3, 0.3]:
			_box(group, corner + Vector3(offset, -0.315, 0), Vector3(0.018, 0.008, 8.4) * tile_spacing, player_colors[team].darkened(0.65), 0.2)
	_hologram = Node3D.new()
	_hologram.name = "VictoryHologram"
	_hologram.position = Vector3(0, 1.4, 0)
	group.add_child(_hologram)
	for index in range(3):
		var ring := TorusMesh.new()
		ring.inner_radius = .65 + index * .18
		ring.outer_radius = ring.inner_radius + .035
		var orbit := _mesh(_hologram, ring, Vector3.ZERO, CYAN.darkened(index * .12), .5)
		orbit.rotation = Vector3(index * .8, 0, index * .65)
	var diamond := _box(_hologram, Vector3.ZERO, Vector3.ONE * 0.4 * tile_spacing, CYAN, 0.8)
	diamond.rotation_degrees = Vector3(45, 0, 45)

func _box(parent: Node3D, pos: Vector3, size: Vector3, col: Color, energy: float = 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, mesh, pos, col, energy)

func _cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, col: Color, energy: float = 0.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 32
	return _mesh(parent, mesh, pos, col, energy)

func _ring(parent: Node3D, pos: Vector3, radius: float, col: Color) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - 0.025 * tile_spacing
	mesh.outer_radius = radius + 0.025 * tile_spacing
	mesh.rings = 24
	mesh.ring_segments = 8
	_mesh(parent, mesh, pos, col, 0.8)

func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, col: Color, energy: float = 0.0) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = _material(col, energy)
	parent.add_child(instance)
	return instance

func _material(col: Color, energy: float = 0.0) -> StandardMaterial3D:
	var key := "%s:%s" % [col.to_html(), energy]
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.65
	mat.metallic = 0.25
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if energy > 0:
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = energy * neon_intensity * 2.5
	_materials[key] = mat
	return mat

func _text(parent: Node3D, value: String, pos: Vector3, size: float, col: Color) -> void:
	var label := Label3D.new()
	label.text = value
	label.font_size = 48
	label.pixel_size = size / 48.0
	label.position = pos
	label.rotation_degrees.x = -90
	label.modulate = col
	label.outline_size = 0
	label.no_depth_test = false
	parent.add_child(label)
