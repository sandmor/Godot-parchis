@tool
extends Node3D
class_name PieceVisual
## Visual and kinetic rig component for game pieces.
## Handles procedural geometry generation, materials, and motion kinematics.

const FACTION_DEFAULT_COLORS: Array[Color] = [
	Color("ff536c"), # 0: Crimson Vanguard
	Color("48e7a0"), # 1: Viridian Accord
	Color("5c9dff"), # 2: Azure Continuum
	Color("ffcf58")  # 3: Solar Corsairs
]

const CALLSIGNS := [
	["Bulwark", "Pathfinder", "Standard", "Veteran"],
	["Rootkeeper", "Bloomtender", "Wayfarer", "Elder"],
	["Surveyor", "Cartographer", "Relay", "Archivist"],
	["Hotshot", "Longwing", "Courier", "Old Glory"]
]

# --- Editor Preview Controls ---

@export_group("Faction & Crew")
@export_enum("Crimson Sentinel:0", "Viridian Warden:1", "Azure Drone:2", "Solar Skimmer:3") var preview_faction: int = 0:
	set(value):
		preview_faction = value
		if auto_faction_color:
			preview_color = FACTION_DEFAULT_COLORS[clampi(value, 0, 3)]
		_update_callsign_display()
		if Engine.is_editor_hint() and is_inside_tree():
			_refresh_editor_preview()

@export_range(0, 3) var preview_slot: int = 0:
	set(value):
		preview_slot = value
		_update_callsign_display()
		if Engine.is_editor_hint() and is_inside_tree():
			_refresh_editor_preview()

@export var callsign: String = "Bulwark":
	get:
		return CALLSIGNS[clampi(preview_faction, 0, 3)][posmod(preview_slot, 4)]
	set(_value):
		pass

@export var auto_faction_color: bool = true:
	set(value):
		auto_faction_color = value
		if value:
			preview_color = FACTION_DEFAULT_COLORS[clampi(preview_faction, 0, 3)]
			if Engine.is_editor_hint() and is_inside_tree():
				_refresh_editor_preview()

@export var preview_color: Color = Color("ff536c"):
	set(value):
		preview_color = value
		if Engine.is_editor_hint() and is_inside_tree():
			_refresh_editor_preview()

@export_group("Editor Animation Preview")
@export var animate_in_editor: bool = false:
	set(value):
		animate_in_editor = value
		if not value and is_instance_valid(rig):
			rig.rotation = Vector3.ZERO
			rig.position = Vector3.ZERO
			activity = 0.0

@export var preview_moving: bool = false:
	set(value):
		preview_moving = value
		moving = value

@export var preview_attention: bool = false:
	set(value):
		preview_attention = value
		if value:
			acknowledge()

# --- Visual Rig State ---

var rig: Node3D
var faction := 0
var variant := 0
var phase := 0.0
var moving := false
var activity := 0.0
var heading := 0.0
var arrival := 0.0
var attention := 0.0
var launch := 0.0
var cadence := 1.0

var limbs: Array[Node3D] = []
var knees: Array[Node3D] = []
var elbows: Array[Node3D] = []
var petals: Array[Node3D] = []
var accessories: Array[Node3D] = []
var satellites: Node3D
var core: Node3D
var torso: Node3D
var head: Node3D
var exhausts: Array[Node3D] = []
var _materials: Dictionary = {}
static var _shapes: Dictionary = {}

func _ready() -> void:
	if Engine.is_editor_hint():
		_update_callsign_display()
		_refresh_editor_preview()

func _update_callsign_display() -> void:
	callsign = CALLSIGNS[clampi(preview_faction, 0, 3)][posmod(preview_slot, 4)]

func _refresh_editor_preview() -> void:
	build(preview_faction, preview_slot, preview_color)
	moving = preview_moving

func build(team: int, slot: int, color: Color) -> void:
	if team >= 0:
		faction = clampi(team, 0, 3)
	variant = posmod(slot, 4)
	phase = variant * 1.73
	cadence = [1.0, 1.09, .94, .88][variant]
	moving = preview_moving if Engine.is_editor_hint() else false
	activity = 0.0
	heading = 0.0
	arrival = 0.0
	attention = 0.0
	launch = 0.0
	if is_instance_valid(rig):
		remove_child(rig)
		rig.queue_free()
	limbs.clear()
	knees.clear()
	elbows.clear()
	petals.clear()
	accessories.clear()
	exhausts.clear()
	satellites = null
	core = null
	torso = null
	head = null
	_materials.clear()
	rig = Node3D.new()
	rig.name = "AnimatedRig"
	add_child(rig)
	set_meta("callsign", CALLSIGNS[faction][variant])
	_build_faction(color)

func face_destination(destination: Vector3) -> void:
	var direction := destination - global_position
	if Vector2(direction.x, direction.z).length_squared() > .0001:
		heading = atan2(direction.x, direction.z)

func play_arrival() -> void:
	arrival = 1.0

func acknowledge() -> void:
	attention = 1.0

func play_launch() -> void:
	launch = 1.0

func step_duration() -> float:
	return [.115, .13, .095, .085][faction] / cadence

func _process(delta: float) -> void:
	if not is_instance_valid(rig): return
	if Engine.is_editor_hint() and not animate_in_editor: return
	phase += delta * cadence
	activity = move_toward(activity, 1.0 if moving else 0.0, delta * 5)
	arrival = move_toward(arrival, 0.0, delta * 2.7)
	attention = move_toward(attention, 0.0, delta * .7)
	launch = move_toward(launch, 0.0, delta * 1.8)
	var turn := angle_difference(rig.rotation.y, heading)
	rig.rotation.y = lerp_angle(rig.rotation.y, heading, 1.0 - exp(-delta * 10))
	rig.position = Vector3.ZERO
	rig.rotation.x = 0
	rig.rotation.z = 0
	var breath := sin(phase * 1.8)
	var glance := sin(phase * .73 + sin(phase * .31)) * (1.0 - activity)
	var settle := sin(arrival * TAU) * arrival
	_animate_faction(delta, breath, glance, settle, turn)

func _build_faction(color: Color) -> void:
	match faction:
		0: _build_sentinel(color)
		1: _build_warden(color)
		2: _build_drone(color)
		3: _build_skimmer(color)

func _animate_faction(delta: float, breath: float, glance: float, settle: float, turn: float) -> void:
	match faction:
		0: _animate_sentinel(delta, breath, glance, settle, turn)
		1: _animate_warden(delta, breath, glance, settle, turn)
		2: _animate_drone(delta, breath, glance, settle, turn)
		3: _animate_skimmer(delta, breath, glance, settle, turn)

# --- Procedural faction builders and animators ---

func _build_sentinel(color: Color) -> void:
	var armor := Color("26303e")
	var trim := Color("99a8b5")
	var cloth := color.darkened(.58)
	plate(rig, Vector3(0, .43, 0), Vector3(.29, .13, .23), armor)
	for side in [-1, 1]:
		var hip := pivot(rig, Vector3(side * .1, .43, 0), "Hip")
		limbs.append(hip)
		joint(hip, Vector3.ZERO, .065, trim)
		plate(hip, Vector3(0, -.09, 0), Vector3(.14, .18, .16), armor)
		var knee := pivot(hip, Vector3(0, -.19, 0), "Knee")
		knees.append(knee)
		joint(knee, Vector3.ZERO, .06, trim)
		plate(knee, Vector3(0, -.065, .035), Vector3(.16, .17, .18), color.darkened(.32))
		plate(knee, Vector3(0, -.17, .055), Vector3(.18, .09, .27), armor)
	torso = pivot(rig, Vector3(0, .52, 0), "Spine")
	mesh(torso, crystal_mesh(.23, .2), Vector3(0, .14, 0), armor).scale = Vector3(1, 1, .7)
	plate(torso, Vector3(0, .18, .075), Vector3(.37, .17, .18), color.darkened(.23))
	plate(torso, Vector3(0, .19, .173), Vector3(.06, .13, .024), trim)
	plate(torso, Vector3(0, .08, .15), Vector3(.12, .028, .025), color, .65)
	plate(torso, Vector3(0, .12, -.15), Vector3(.26, .29, .12), armor)
	for side in [-1, 1]:
		plate(torso, Vector3(side * .09, .19, -.23), Vector3(.07, .18, .05), trim)
		var shoulder := pivot(torso, Vector3(side * .235, .22, 0), "Shoulder")
		limbs.append(shoulder)
		joint(shoulder, Vector3.ZERO, .075, trim)
		var pauldron := plate(shoulder, Vector3(side * .035, 0, 0), Vector3(.22, .16, .29), color.darkened(.15))
		pauldron.rotation.z = side * -.17
		plate(shoulder, Vector3(0, -.115, 0), Vector3(.115, .19, .13), armor)
		var elbow := pivot(shoulder, Vector3(0, -.21, 0), "Elbow")
		elbows.append(elbow)
		joint(elbow, Vector3.ZERO, .052, trim)
		plate(elbow, Vector3(0, -.07, .035), Vector3(.13, .17, .16), armor)
		joint(elbow, Vector3(0, -.16, .04), .055, trim)
		if side == -1:
			plate(elbow, Vector3(-.065, -.06, .11), Vector3(.075, .36 if variant == 0 else .27, .3), color.darkened(.25))
			plate(elbow, Vector3(-.108, -.06, .12), Vector3(.018, .22, .17), trim)
		else:
			plate(elbow, Vector3(0, -.15, .16), Vector3(.1, .1, .33), armor)
			plate(elbow, Vector3(0, -.15, .34), Vector3(.055, .05, .04), color, .8)
	head = pivot(torso, Vector3(0, .36, 0), "Neck")
	joint(head, Vector3(0, -.015, 0), .065, trim)
	plate(head, Vector3(0, .065, 0), Vector3(.235, .22, .24), armor)
	plate(head, Vector3(0, .075, .124), Vector3(.19, .035, .025), color.lightened(.55), .8)
	plate(head, Vector3(0, -.005, .12), Vector3(.12, .05, .04), trim)
	for side in [-1, 1]:
		var flap := pivot(torso, Vector3(side * .09, .11, -.21), "Mantle")
		mesh(flap, leaf_mesh(.18, .44, .025), Vector3(0, -.2, 0), cloth)
		accessories.append(flap)
	if variant == 1:
		plate(head, Vector3(-.13, .16, -.03), Vector3(.025, .22, .025), trim)
		joint(head, Vector3(.13, .08, .08), .042, Color("a5ebff"), .6)
	elif variant == 2:
		var banner := pivot(torso, Vector3(-.12, .2, -.25), "RescueStandard")
		plate(banner, Vector3(0, .22, 0), Vector3(.025, .62, .025), trim)
		mesh(banner, leaf_mesh(.24, .35, .02), Vector3(.11, .35, 0), color.darkened(.2))
		accessories.append(banner)
	elif variant == 3:
		for index in range(3):
			plate(torso, Vector3(.06 + index * .035, .24, .18), Vector3(.018, .055, .012), Color("e6c58b"))
		plate(head, Vector3(0, .19, -.015), Vector3(.06, .065, .21), color.darkened(.18))

func _animate_sentinel(_delta: float, breath: float, glance: float, settle: float, _turn: float) -> void:
	var gait := phase * 12
	var stride := sin(gait) * activity
	for index in range(2):
		var sign_side := 1.0 if index == 0 else -1.0
		limbs[index].rotation.x = stride * [.38, .49, .42, .35][variant] * sign_side
		knees[index].rotation.x = -maxf(0, sin(gait + index * PI)) * .72 * activity - arrival * .16
		limbs[index + 2].rotation.x = -stride * .18 * sign_side - attention * .12
		elbows[index].rotation.x = -.25 - activity * .3 - attention * .25
	rig.position.y = absf(stride) * .025 + breath * .004 + settle * .035
	rig.rotation.x = activity * [.055, .1, .075, .065][variant] + launch * .12
	torso.rotation.z = -stride * [.025, .045, .035, .02][variant]
	torso.rotation.y = stride * .055
	head.rotation.y = glance * .16 + attention * .2
	head.rotation.x = -attention * .13
	for index in range(accessories.size()):
		accessories[index].rotation.x = -.08 - activity * .25 + sin(phase * 3 + index) * .035

func _build_warden(color: Color) -> void:
	var bark := Color("343c30")
	var gold := Color("bca36a")
	var leaf_color := color.darkened(.4)
	for side in [-1, 1]:
		var hip := pivot(rig, Vector3(side * .085, .36, 0), "RootHip")
		limbs.append(hip)
		plate(hip, Vector3(0, -.07, 0), Vector3(.085, .16, .1), bark)
		var knee := pivot(hip, Vector3(0, -.15, 0), "RootKnee")
		knees.append(knee)
		plate(knee, Vector3(0, -.07, 0), Vector3(.08, .16, .09), bark)
		mesh(knee, leaf_mesh(.12, .19, .035), Vector3(0, -.12, .07), leaf_color).rotation.x = PI * .5
	torso = pivot(rig, Vector3(0, .49, 0), "LivingSpine")
	mesh(torso, crystal_mesh(.17, .22), Vector3(0, .07, 0), bark).scale.z = .75
	plate(torso, Vector3(0, -.07, 0), Vector3(.27, .055, .22), gold)
	for index in range(7):
		var angle := index * TAU / 7
		var leaf := pivot(torso, Vector3(sin(angle) * .12, .17, cos(angle) * .12), "CloakLeaf")
		leaf.rotation.y = angle
		petals.append(leaf)
		mesh(leaf, leaf_mesh(.2, .48, .07), Vector3(0, -.2, .04), color.darkened(.45 if index % 2 else .22))
		plate(leaf, Vector3(0, -.18, .102), Vector3(.012, .28, .013), gold)
	head = pivot(torso, Vector3(0, .31, 0), "Gaze")
	joint(head, Vector3(0, .035, 0), .105, Color("9eae87"))
	for side in [-1, 1]:
		plate(head, Vector3(side * .037, .045, .099), Vector3(.027, .018, .018), Color("ffe4a3"), .4)
		var ear := mesh(head, leaf_mesh(.08, .2, .025), Vector3(side * .12, .065, 0), leaf_color)
		ear.rotation.z = side * -.95
		var branch := pivot(head, Vector3(side * .065, .11, -.025), "CrownBranch")
		branch.rotation.z = side * -.4
		plate(branch, Vector3(0, .09, 0), Vector3(.025, .21, .025), gold)
		for bud in range(2 + variant % 2):
			var frond := mesh(branch, leaf_mesh(.09, .15, .025), Vector3(side * .035, .07 + bud * .065, 0), color.darkened(.2))
			frond.rotation.z = side * -.6
	for side in [-1, 1]:
		var arm := pivot(torso, Vector3(side * .18, .17, 0), "OfferingShoulder")
		limbs.append(arm)
		joint(arm, Vector3.ZERO, .055, gold)
		plate(arm, Vector3(0, -.09, 0), Vector3(.09, .18, .105), bark)
		mesh(arm, leaf_mesh(.15, .23, .055), Vector3(side * .02, -.04, .02), leaf_color)
		var elbow := pivot(arm, Vector3(0, -.16, 0), "OfferingElbow")
		elbows.append(elbow)
		plate(elbow, Vector3(0, -.085, 0), Vector3(.075, .17, .08), bark)
		joint(elbow, Vector3(0, -.17, 0), .048, gold)
	core = pivot(torso, Vector3(0, .05, .275), "LivingSeed")
	joint(core, Vector3.ZERO, .062 + variant * .005, Color("d1ffc1"), .75)
	for side in [-1, 1]:
		mesh(core, leaf_mesh(.1, .17, .045), Vector3(side * .065, -.035, 0), leaf_color).rotation.z = side * -.8
	var pack := pivot(torso, Vector3(0, .09, -.16), "SeedSatchel")
	mesh(pack, crystal_mesh(.13, .17), Vector3.ZERO, bark)
	for index in range(variant + 1):
		var sprout := mesh(pack, leaf_mesh(.09, .22, .025), Vector3((index - variant * .5) * .065, .18, -.035), color.darkened(.15))
		sprout.rotation.z = (index - variant * .5) * .35
	if variant == 1:
		for side in [-1, 1]: joint(head, Vector3(side * .12, .19, 0), .045, Color("f1bcba"))
	elif variant == 2:
		plate(pack, Vector3(.15, 0, 0), Vector3(.07, .3, .08), gold)
	elif variant == 3:
		mesh(head, leaf_mesh(.16, .2, .025), Vector3(0, -.1, .055), Color("a8ba99"))

func _animate_warden(_delta: float, breath: float, glance: float, settle: float, _turn: float) -> void:
	var gait := phase * 8
	var stride := sin(gait) * activity
	for index in range(2):
		limbs[index].rotation.x = stride * [.33, .3, .41, .26][variant] * (1 if index == 0 else -1)
		knees[index].rotation.x = -maxf(0, sin(gait + index * PI)) * .55 * activity
		limbs[index + 2].rotation.x = -.22 + breath * .025
		limbs[index + 2].rotation.z = (.22 if index == 0 else -.22)
		elbows[index].rotation.x = -1.05 - attention * .15
	rig.position.y = breath * .008 + absf(stride) * .016 + settle * .02
	torso.rotation.z = stride * .045
	torso.rotation.x = (.075 if variant == 3 else 0.0) - attention * .08
	head.rotation.y = glance * .22
	head.rotation.x = .12 + breath * .035 - attention * .18
	for index in range(petals.size()):
		petals[index].rotation.x = sin(phase * 2 + index * .7) * .055 + activity * .25
	core.position.y = .05 + breath * .009 + attention * .04
	core.rotation.y = sin(phase * .8) * .3

func _build_drone(color: Color) -> void:
	var porcelain := Color("c2d5e5")
	var dark := Color("22334e")
	core = pivot(rig, Vector3(0, .67, 0), "NavigationGimbal")
	mesh(core, crystal_mesh(.18, .26), Vector3.ZERO, porcelain)
	mesh(core, crystal_mesh(.125, .16), Vector3(0, -.17, 0), dark)
	head = pivot(core, Vector3(0, .025, .15), "OpticalGimbal")
	joint(head, Vector3.ZERO, .09, dark)
	joint(head, Vector3(0, 0, .045), .058, color.lightened(.65), 1)
	for side in [-1, 1]:
		var shutter := pivot(head, Vector3(side * .075, 0, .01), "OpticalShutter")
		plate(shutter, Vector3.ZERO, Vector3(.035, .15, .06), porcelain)
		accessories.append(shutter)
	var halo := mesh(core, ring_mesh(.235, .252), Vector3.ZERO, porcelain)
	halo.rotation.z = .42
	var meridian := mesh(core, ring_mesh(.26, .275), Vector3.ZERO, color, .45)
	meridian.rotation.x = PI * .5
	satellites = pivot(rig, Vector3(0, .67, 0), "OrbitalArray")
	for index in range(3):
		var angle := index * TAU / 3
		var socket := pivot(satellites, Vector3(cos(angle) * .33, 0, sin(angle) * .33), "PrismFin")
		socket.rotation.y = -angle
		mesh(socket, crystal_mesh(.075, .22), Vector3.ZERO, porcelain).scale.z = .65
		plate(socket, Vector3(.045, 0, 0), Vector3(.035, .24, .1), dark)
		plate(socket, Vector3(.066, 0, 0), Vector3(.015, .17, .055), color, .75)
		var hinge := pivot(socket, Vector3(0, -.1, 0), "VectorVane")
		mesh(hinge, leaf_mesh(.13, .24, .025), Vector3(0, -.08, 0), dark)
		elbows.append(hinge)
		petals.append(socket)
	for index in range(variant + 1):
		var chip := pivot(core, Vector3((index - variant * .5) * .08, .27, 0), "MapFragment")
		mesh(chip, crystal_mesh(.025, .065), Vector3.ZERO, color, .5)
	if variant == 1:
		mesh(core, ring_mesh(.31, .323), Vector3.ZERO, dark).rotation.z = -.5
	elif variant == 2:
		for side in [-1, 1]:
			plate(core, Vector3(side * .14, .18, -.04), Vector3(.025, .27, .035), porcelain)
			joint(core, Vector3(side * .14, .32, -.04), .035, color, .7)
	elif variant == 3:
		mesh(core, crystal_mesh(.1, .12), Vector3(0, -.37, 0), color.darkened(.35))
	var emitter := mesh(rig, crystal_mesh(.065, .13), Vector3(0, .22, 0), color, .65)
	emitter.name = "GravityLens"

func _animate_drone(_delta: float, _breath: float, glance: float, settle: float, turn: float) -> void:
	rig.position.y = .035 + sin(phase * 2.1) * .035 + settle * .045 + launch * .08
	rig.rotation.x = activity * .18
	rig.rotation.z = clampf(-turn * .18, -.15, .15) * activity
	satellites.rotation.y = phase * [.45, -.38, .6, -.3][variant]
	satellites.rotation.z = sin(phase * .8) * .12 * (1 - activity)
	core.rotation.z = sin(phase * 1.3) * .09
	head.rotation.y = glance * .3
	for index in range(petals.size()):
		var angle := index * TAU / 3
		var radius := .33 + activity * .055 + attention * .045
		petals[index].position = Vector3(cos(angle) * radius, sin(phase * 2 + angle) * .035, sin(angle) * radius)
		petals[index].rotation.z = activity * .3 + sin(phase * 1.7 + index) * .08
		elbows[index].rotation.x = activity * .6
	for index in range(accessories.size()):
		accessories[index].rotation.y = (1 if index == 0 else -1) * (.15 + attention * .5 + sin(phase * 1.5) * .1)

func _build_skimmer(color: Color) -> void:
	rig.scale = Vector3.ONE * .85
	var armor := Color("303b49")
	var trim := Color("a68c61")
	plate(rig, Vector3(0, .36, 0), Vector3(.28, .17, .65), color.darkened(.4))
	mesh(rig, prow_mesh(), Vector3(0, .36, .27), color.darkened(.15))
	plate(rig, Vector3(0, .41, .42), Vector3(.045, .03, .2), Color("fff0c4"), .6)
	plate(rig, Vector3(0, .48, .19), Vector3(.25, .17, .1), Color("397785")).rotation.x = -.4
	plate(rig, Vector3(0, .42, -.08), Vector3(.18, .1, .24), armor)
	torso = pivot(rig, Vector3(0, .48, -.09), "PilotSpine")
	plate(torso, Vector3(0, .07, 0), Vector3(.16, .19, .13), Color("5c4639"))
	plate(torso, Vector3(0, .065, .075), Vector3(.1, .13, .035), color.darkened(.25))
	head = pivot(torso, Vector3(0, .23, .015), "PilotNeck")
	joint(head, Vector3.ZERO, .09, color.darkened(.1))
	plate(head, Vector3(0, .015, .075), Vector3(.145, .05, .04), Color("9ee9eb"), .3)
	for side in [-1, 1]:
		var arm := pivot(torso, Vector3(side * .105, .13, 0), "PilotShoulder")
		limbs.append(arm)
		plate(arm, Vector3(0, -.06, 0), Vector3(.065, .13, .07), Color("5c4639"))
		var elbow := pivot(arm, Vector3(0, -.12, 0), "PilotElbow")
		elbows.append(elbow)
		plate(elbow, Vector3(0, -.06, 0), Vector3(.055, .13, .06), armor)
		plate(rig, Vector3(side * .1, .4, .13), Vector3(.07, .07, .14), armor)
		plate(rig, Vector3(side * .14, .29, .04), Vector3(.055, .04, .39), trim)
		var wing := pivot(rig, Vector3(side * .19, .33, -.12), "Stabilizer")
		petals.append(wing)
		var vane := mesh(wing, leaf_mesh(.25 if variant != 1 else .38, .43, .035), Vector3(side * .1, 0, 0), armor)
		vane.rotation = Vector3(PI * .5, 0, side * -.35)
		plate(wing, Vector3(side * .16, .015, -.04), Vector3(.035, .035, .25), color, .4)
		plate(rig, Vector3(side * .215, .34, -.29), Vector3(.14, .15, .3), trim)
		plate(rig, Vector3(side * .215, .34, -.45), Vector3(.1, .09, .035), Color("bcefff"), .9)
		var plume := mesh(rig, crystal_mesh(.045, .13), Vector3(side * .215, .34, -.55), Color("68cfff"), .8)
		plume.rotation.x = PI * .5
		exhausts.append(plume)
		var fin := mesh(rig, leaf_mesh(.15, .31, .025), Vector3(side * .15, .5, -.3), color.darkened(.2))
		fin.rotation.z = side * -.3
	var scarf := pivot(torso, Vector3(0, .17, -.07), "PilotScarf")
	mesh(scarf, leaf_mesh(.09, .35, .025), Vector3(0, -.12, -.04), Color("db735a") if variant % 2 == 0 else Color("d6d4b7"))
	accessories.append(scarf)
	if variant == 0:
		plate(rig, Vector3(-.12, .47, .35), Vector3(.07, .025, .14), Color("fff0c4"))
	elif variant == 2:
		for side in [-1, 1]: plate(rig, Vector3(side * .25, .48, -.18), Vector3(.15, .17, .2), Color("777f68"))
	elif variant == 3:
		plate(rig, Vector3(.145, .37, .27), Vector3(.045, .055, .2), trim)
		plate(rig, Vector3(-.15, .56, -.29), Vector3(.025, .32, .025), armor)

func _animate_skimmer(_delta: float, breath: float, glance: float, settle: float, turn: float) -> void:
	rig.position.y = sin(phase * 2.5) * .018 + activity * .045 + settle * .04 + launch * .08
	rig.rotation.x = -activity * .14 + arrival * .08
	rig.rotation.z = clampf(-turn * .55, -.3, .3) * activity + sin(phase * 4) * activity * [.045, .02, .015, .03][variant]
	torso.rotation.x = activity * .23 + breath * .025
	torso.rotation.z = -rig.rotation.z * .65
	head.rotation.y = glance * .28 + attention * .3
	for index in range(limbs.size()):
		limbs[index].rotation.x = -.4 - activity * .12
		elbows[index].rotation.x = -.85
	for index in range(petals.size()):
		petals[index].rotation.z = (1 if index == 0 else -1) * (activity * .16 + arrival * .1)
	for plume in exhausts:
		plume.scale.y = .6 + activity * (2.5 + sin(phase * 32) * .25) + launch * 1.2
	for scarf in accessories:
		scarf.rotation.x = .3 + activity * 1.0 + sin(phase * 9) * (.04 + activity * .09)
		scarf.rotation.z = sin(phase * 6) * (.06 + activity * .12)

# --- Helper methods for procedural parts and meshes ---

func pivot(parent: Node3D, at: Vector3, label: String) -> Node3D:
	var node := Node3D.new()
	node.name = label
	node.position = at
	parent.add_child(node)
	return node

func plate(parent: Node3D, at: Vector3, dimensions: Vector3, color: Color, glow: float = 0) -> MeshInstance3D:
	var key := str(dimensions)
	if not _shapes.has(key): _shapes[key] = beveled_box(dimensions)
	return mesh(parent, _shapes[key], at, color, glow)

func joint(parent: Node3D, at: Vector3, radius: float, color: Color, glow: float = 0) -> MeshInstance3D:
	var key := "sphere" + str(radius)
	if not _shapes.has(key):
		var shape := SphereMesh.new()
		shape.radius = radius
		shape.height = radius * 2
		shape.radial_segments = 12
		shape.rings = 6
		_shapes[key] = shape
	return mesh(parent, _shapes[key], at, color, glow)

func mesh(parent: Node3D, shape: Mesh, at: Vector3, color: Color, glow: float = 0) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = shape
	item.position = at
	var key := str(color) + ":" + str(glow)
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.metallic = .45
		material.roughness = .53
		if glow > 0:
			material.emission_enabled = true
			material.emission = color
			material.emission_energy_multiplier = glow * 1.4
		_materials[key] = material
	item.material_override = _materials[key]
	parent.add_child(item)
	return item

func ring_mesh(inner: float, outer: float) -> TorusMesh:
	var ring := TorusMesh.new()
	ring.inner_radius = inner
	ring.outer_radius = outer
	ring.rings = 32
	ring.ring_segments = 6
	return ring

static func beveled_box(size: Vector3, bevel: float = .025) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	var half := size * .5
	bevel = minf(bevel, minf(half.x, minf(half.y, half.z)) * .45)
	var rings: Array[PackedVector3Array] = []
	for band in range(4):
		var inset := bevel if band in [0, 3] else 0.0
		var x := half.x - inset
		var z := half.z - inset
		var cut := minf(x, z) * .3
		var y: float = [-half.y, -half.y + bevel, half.y - bevel, half.y][band]
		rings.append(PackedVector3Array([
			Vector3(-x + cut, y, -z), Vector3(x - cut, y, -z),
			Vector3(x, y, -z + cut), Vector3(x, y, z - cut),
			Vector3(x - cut, y, z), Vector3(-x + cut, y, z),
			Vector3(-x, y, z - cut), Vector3(-x, y, -z + cut)
		]))
	for band in range(3):
		for index in range(8):
			var next := (index + 1) % 8
			triangle(surface, rings[band][index], rings[band + 1][index], rings[band + 1][next])
			triangle(surface, rings[band][index], rings[band + 1][next], rings[band + 1][next])
	for index in range(8):
		var next := (index + 1) % 8
		triangle(surface, Vector3(0, -half.y, 0), rings[0][index], rings[0][next])
		triangle(surface, Vector3(0, half.y, 0), rings[3][next], rings[3][index])
	surface.generate_normals()
	return surface.commit()

static func leaf_mesh(width: float, height: float, depth: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	var tip := Vector3(0, height * .5, 0)
	var root_point := Vector3(0, -height * .5, 0)
	var left := Vector3(-width * .5, 0, 0)
	var right := Vector3(width * .5, 0, 0)
	var ridge := Vector3(0, 0, depth)
	for edge in [[tip, left], [left, root_point], [root_point, right], [right, tip]]:
		triangle(surface, edge[0], edge[1], ridge)
		triangle(surface, edge[1], edge[0], Vector3(0, 0, -depth * .25))
	surface.generate_normals()
	return surface.commit()

static func crystal_mesh(radius: float, height: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	for index in range(6):
		var angle := index * TAU / 6
		var next := (index + 1) * TAU / 6
		var a := Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		var b := Vector3(cos(next) * radius, 0, sin(next) * radius)
		triangle(surface, Vector3(0, height, 0), b, a)
		triangle(surface, Vector3(0, -height, 0), a, b)
	surface.generate_normals()
	return surface.commit()

static func prow_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	var a := Vector3(-.16, -.09, 0)
	var b := Vector3(.16, -.09, 0)
	var c := Vector3(.12, .07, 0)
	var d := Vector3(-.12, .07, 0)
	var tip := Vector3(0, -.04, .37)
	triangle(surface, a, b, c)
	triangle(surface, a, c, d)
	triangle(surface, tip, b, a)
	triangle(surface, tip, c, b)
	triangle(surface, tip, d, c)
	triangle(surface, tip, a, d)
	surface.generate_normals()
	return surface.commit()

static func triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)
