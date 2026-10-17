extends "res://tests/support/test_case.gd"
const Stage := preload("res://DiceThrow.gd")
func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var stage := Stage.new()
	viewport.add_child(stage)
	check(stage.camera.projection == Camera3D.PROJECTION_PERSPECTIVE,"Reactor uses perspective")
	for die in stage.dice:
		check(die is RigidBody3D and die.continuous_cd and die.face_materials.size() == 6,"Each die is a convex rigid body with six flush pip faces")
	# Canonical faces never change; opposite faces sum to seven.
	for value in range(1,7):
		stage.dice[0].basis = Basis.from_euler(stage.LANDING_ROTATIONS[value-1])
		check(stage.read_top_value(0) == value,"Physical orientation selects the permanently numbered face")
	for pair in [[0,5],[1,4],[2,3]]:
		check(int(stage.dice[0].face_materials[pair[0]].get_shader_parameter("value"))+int(stage.dice[0].face_materials[pair[1]].get_shader_parameter("value")) == 7,"Opposite faces sum to seven")
	# Deliberately create a stacked pair; the containment field must dislodge it.
	stage._prepare(Color.WHITE)
	stage._launch()
	for index in range(2):
		var die: RigidBody3D = stage.dice[index]
		die.freeze = true
		die.basis = Basis.IDENTITY
		die.position = Vector3(0,.67+index*1.34,0)
		die.linear_velocity = Vector3.ZERO
		die.angular_velocity = Vector3.ZERO
		die.freeze = false
		die.sleeping = false
	while stage.simulation_time < 4 and (stage.dice[1].position.y>1.15 or stage.simulation_time<2.0):
		await physics_frame
	check(stage.dice[0].position.y < 1.15 and stage.dice[1].position.y < 1.15,"The physical containment field dislodges stacked dice")
	stage._resolve()
	var sound_events: Array[Dictionary] = []
	var gains: Array[float] = []
	stage.sound_cue.connect(func(key: String): sound_events.append({"sound":key,"contacts":stage.collision_log.size()}))
	stage.collision_cue.connect(func(gain: float): gains.append(gain))
	var previous_launch := Vector3.ZERO
	for seed_value in [17,38,91,122,250]:
		stage.throw_rng.seed = seed_value
		stage.play(Color("ff536c"))
		check(stage.launch_vectors.size() == 2 and stage.launch_vectors[0] != stage.launch_vectors[1],"Each die has an independent launch vector")
		check(stage.launch_vectors[0] != previous_launch,"Different seeds produce different throws")
		previous_launch = stage.launch_vectors[0]
		var rebounds := [false,false]
		var was_falling := [false,false]
		var contained := true
		var in_frame := true
		var above_floor := true
		while stage.playing:
			await physics_frame
			for index in range(2):
				var die: RigidBody3D = stage.dice[index]
				if was_falling[index] and die.linear_velocity.y > .8: rebounds[index] = true
				if die.linear_velocity.y < -1: was_falling[index] = true
				for face in range(6):
					check(int(die.face_materials[face].get_shader_parameter("value")) == face+1,"Pips must never be remapped during a roll")
				contained = contained and absf(die.position.x) < 4.3 and absf(die.position.z) < 3.0
				for vertex in die.support_vertices:
					var point: Vector3 = die.transform*vertex
					above_floor = above_floor and point.y > -.15
					in_frame = in_frame and Rect2(Vector2.ZERO,viewport.size).has_point(stage.camera.unproject_position(point))
		check(contained and above_floor,"Real collisions contain the dice in the tray without tunneling")
		check(in_frame,"Camera contains both bodies during varied physical throws")
		check(stage.collision_log.size() > 0,"Impacts are reported by the physics solver")
		check(stage.read_top_value(0) == stage._values[0] and stage.read_top_value(1) == stage._values[1],"Results come from actual upward numbered faces")
		check(rebounds[0] and rebounds[1],"Both dice rebound upward after falling")
		print("Seed %d: %s, settled %.2fs" % [seed_value,stage._values,stage.simulation_time])
		check(stage.dice[0].freeze and stage.dice[1].freeze,"Bodies stop safely for result reading")
	for event in sound_events:
		if event.sound == "dice_impact": check(event.contacts > 0,"No impact sound occurs without a solver contact")
	check(gains.size() > 0,"Contact strength reaches the sound mixer")
	for gain in gains: check(gain >= .2 and gain <= 1,"Collision loudness stays within the mix range")
	sound_events.clear()
	var quick: Array[int] = await stage.play(Color.WHITE,true)
	check(not stage.collision_log.is_empty(),"Quick mode still uses physical contacts")
	check(quick == stage._values and quick == [stage.read_top_value(0),stage.read_top_value(1)],"Quick results match the actual visible faces")
	await finish("physical dice checks")
