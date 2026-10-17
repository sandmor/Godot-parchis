extends SceneTree
## Render the actual game at a consistent landscape size, independent of the WM.
func _initialize() -> void:
	call_deferred("_capture_previews")

func _capture_previews() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1440, 1000)
	viewport.own_world_3d = true
	viewport.use_hdr_2d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene := load("res://MainGame.tscn").instantiate() as Node3D
	scene.remember_guidance = false
	scene.remember_audio_settings = false
	viewport.add_child(scene)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/previews"))
	scene.name_inputs[0].text = "Nova"
	scene.name_inputs[1].text = "Vega"
	await _save(viewport, "res://artifacts/previews/lobby.png")
	scene._start_match()
	scene.game.roll(6, 5)
	scene.game.roll(1, 2)
	await create_timer(2.5).timeout
	await _save(viewport, "res://artifacts/previews/talking.png")
	scene.faction_briefing.reveal.complete()
	await _save(viewport, "res://artifacts/previews/faction-intro.png")
	scene.faction_briefing.next_page()
	await _save(viewport, "res://artifacts/previews/faction-tutorial.png")
	scene.faction_briefing.finish()
	scene.game.roll(4, 6)
	await _save(viewport, "res://artifacts/previews/jailed.png")
	scene.game.pawns[0] = [0, 6, -1, -1]
	scene.game.roll(3, 5)
	await create_timer(0.4).timeout
	await _save(viewport, "res://artifacts/previews/overview.png")
	scene._select_pawn(0)
	await create_timer(0.4).timeout
	await _save(viewport, "res://artifacts/previews/game.png")
	scene._open_sound_settings()
	await _save(viewport, "res://artifacts/previews/sound-settings.png")
	scene.sound_overlay.hide()
	scene.dice_overlay.show()
	await scene.dice_stage.play(scene.board.player_colors[0], true)
	scene.dice_caption.text = "NOVA / DICE REACTOR"
	scene._dice_settled(scene.dice_stage._values)
	await _save(viewport, "res://artifacts/previews/dice.png")
	print("Saved landscape lobby, game, and dice previews")
	quit()

func _save(viewport: SubViewport, path: String) -> void:
	for frame in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	image.linear_to_srgb()
	image.save_png(path)
