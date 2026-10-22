extends SceneTree
## Inspect every full-frame expression on a lit backdrop, with a face close-up grid.
const Lore := preload("res://Factions.gd")
const Portrait := preload("res://src/UI/components/AnimatedPortrait.gd")
const STATES := ["idle","speak_a","speak_b","blink","smile"]
const NAMES := ["VOSS","SAEL","LYRA-7","REYES"]
func _initialize() -> void: call_deferred("_capture")
func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/previews"))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1500,1000)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var backdrop := ColorRect.new()
	backdrop.color = Color("243547")
	backdrop.size = viewport.size
	viewport.add_child(backdrop)
	for team in range(4):
		var sequence: Resource = load(Lore.profile(team).portrait)
		for index in range(STATES.size()):
			var texture: Texture2D = sequence.frames[STATES[index]]
			var face := AtlasTexture.new()
			face.atlas = texture
			var factor := texture.get_width()/512.0
			face.region = Rect2(180*factor,90*factor,210*factor,160*factor)
			var image := TextureRect.new()
			image.position = Vector2(index*300+4,team*250+30)
			image.size = Vector2(292,216)
			image.texture = face
			image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			viewport.add_child(image)
			var label := Label.new()
			label.text = NAMES[team]+" / "+STATES[index]
			label.position = Vector2(index*300+12,team*250+4)
			label.add_theme_color_override("font_color",Lore.profile(team).color.lightened(.3))
			viewport.add_child(label)
	var suffix := "before" if "--before" in OS.get_cmdline_user_args() else "after"
	await _save(viewport,"portraits-"+suffix+"-faces")
	if "--motion" in OS.get_cmdline_user_args():
		for child in viewport.get_children(): child.queue_free()
		await process_frame
		viewport.size = Vector2i(1200,360)
		var background := ColorRect.new()
		background.color = Color("182535")
		background.size = viewport.size
		viewport.add_child(background)
		var portraits: Array[Control] = []
		for team in range(4):
			var portrait := Portrait.new()
			viewport.add_child(portrait)
			portrait.position = Vector2(team*300+10,20)
			portrait.size = Vector2(280,300)
			portrait.set_character(team)
			portrait.set_process(false)
			portrait.speaking = true
			portraits.append(portrait)
			var label := Label.new()
			label.text = NAMES[team]
			label.position = Vector2(team*300+115,330)
			viewport.add_child(label)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/previews/.portrait-motion"))
		for frame in range(144):
			for portrait in portraits:
				portrait._clock = frame/24.0
				portrait.speaking = frame<120
				portrait.expression = "celebrate" if frame>=120 else "calm"
				portrait._update_frame()
			await _save(viewport,".portrait-motion/frame-%04d" % frame)
	print("Saved all 20 portrait face close-ups" + " and motion frames" if "--motion" in OS.get_cmdline_user_args() else "Saved all 20 portrait face close-ups")
	quit()
func _save(viewport: SubViewport,label: String) -> void:
	for frame in range(3): await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://artifacts/previews/"+label+".png")
