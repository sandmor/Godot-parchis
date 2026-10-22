extends SceneTree
## Capture each facial state at the reported 279px portrait size.
func _initialize() -> void:
	call_deferred("_capture")
func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/previews"))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(279,279)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var portrait := preload("res://src/UI/components/AnimatedPortrait.gd").new()
	viewport.add_child(portrait)
	portrait.size = viewport.size
	portrait.set_process(false)
	portrait.set_character(int(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() else 0,"calm")
	for state in ["idle","speak_a","speak_b","smile","blink"]:
		portrait.texture = portrait.definition.frames[state]
		portrait.queue_redraw()
		for frame in range(4):await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("res://artifacts/previews/character-%d-%s.png" % [portrait.faction_id,state])
	quit()
