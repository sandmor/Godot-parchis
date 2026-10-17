extends SceneTree
## Record a genuine physics throw, then render its fixed-step poses for review.
const Stage := preload("res://DiceThrow.gd")
var frames: Array[Dictionary] = []
func _initialize() -> void: call_deferred("_capture")
func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/previews"))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.own_world_3d = true
	viewport.use_hdr_2d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stage := Stage.new()
	viewport.add_child(stage)
	stage.throw_rng.seed = 17
	stage.play(Color("ff536c"))
	while stage.playing:
		await physics_frame
		frames.append({"poses":[stage.dice[0].transform,stage.dice[1].transform],"camera":stage.camera.transform,"fov":stage.camera.fov,"reveal":clampf(stage._reveal_time/.18,0,1) if stage._resolved else 0.0,"pulses":[stage.pulses[0].transform,stage.pulses[1].transform],"visible":[stage.pulses[0].visible,stage.pulses[1].visible],"colors":[stage.pulse_materials[0].albedo_color,stage.pulse_materials[1].albedo_color]})
	var contacts := stage.collision_log.duplicate(true)
	stage.set_physics_process(false)
	for die in stage.dice: die.set_process(false)
	var first_contact := int(float(stage.collision_log[0].time)*Engine.physics_ticks_per_second)
	for entry in [["charge",0],["flight",15],["impact",first_contact],["settled",frames.size()-1]]:
		_apply(stage,frames[mini(entry[1],frames.size()-1)])
		await _save(viewport,"reactor-"+entry[0])
	var events := {"physics_fps":Engine.physics_ticks_per_second,"frame_count":frames.size(),"contacts":contacts}
	if "--motion" in OS.get_cmdline_user_args():
		viewport.size = Vector2i(960,540)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/previews/.dice-motion"))
		stage._prepare(Color("ff536c"))
		for frame in range(0,frames.size(),2):
			_apply(stage,frames[frame])
			await _save(viewport,".dice-motion/frame-%04d" % (frame/2))
	FileAccess.open("res://artifacts/dice-physics-recording.json",FileAccess.WRITE).store_string(JSON.stringify(events,"\t"))
	print("Saved physics reactor previews; recorded %d physics frames" % frames.size())
	quit()
func _apply(stage: Node3D, frame: Dictionary) -> void:
	stage.camera.transform = frame.camera
	stage.camera.fov = frame.fov
	for index in range(2):
		stage.dice[index].transform = frame.poses[index]
		stage.dice[index].illuminate(stage._accent,frame.reveal)
		stage.pulses[index].transform = frame.pulses[index]
		stage.pulses[index].visible = frame.visible[index]
		stage.pulse_materials[index].albedo_color = frame.colors[index]
func _save(viewport: SubViewport,label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var result := viewport.get_texture().get_image()
	result.convert(Image.FORMAT_RGBA8)
	result.linear_to_srgb()
	result.save_png("res://artifacts/previews/"+label+".png")
