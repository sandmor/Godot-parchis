extends "res://tests/support/test_case.gd"
const Audio := preload("res://ArenaAudio.gd")
var scene: Node3D

func _run() -> void:
	scene = load_game()
	await process_frame
	var audio: Node = scene.audio
	audio.enabled = true
	check(audio.sounds.size() == 14, "All event effects are packaged assets")
	for key in Audio.KEYS:
		var sound := audio.sounds[key] as AudioStreamWAV
		check(sound != null and sound.get_length() > .02, "Sound imports: " + key)
		var bytes := _source_pcm("res://assets/audio/%s.wav" % key)
		var peak := 0
		for offset in range(0, bytes.size(), 2):
			peak = maxi(peak, absi(bytes.decode_s16(offset)))
		check(not bytes.is_empty() and peak > 100 and peak <= 30000, "Sound has signal without clipping: " + key)
	scene._start_match()
	scene.game.roll(6, 5)
	scene.game.roll(1, 2)
	check(scene.faction_briefing.reveal.revealing, "Prologue reveals dialogue interactively")
	await process_frame
	check(scene.faction_briefing.portrait.speaking, "Portrait speaks while text reveals")
	scene.faction_briefing.reveal.complete()
	await process_frame
	check(not scene.faction_briefing.portrait.speaking and scene.faction_briefing.dialogue.visible_characters == -1, "Showing all text immediately stops talking")
	scene.faction_briefing.finish()
	await process_frame
	check(scene.comms_reveal.revealing, "Field comms share the silent talking system")
	scene.comms_reveal.complete()
	scene.guide.enabled = false
	scene._react("capture", 2)
	scene._refresh_guidance()
	check(scene.faction_card.visible and scene.faction_portrait.faction_id == 2 and scene.guide.active.is_empty(), "Faction reactions work after tutorials are disabled")
	check(scene.faction_portrait.expression == "resolve", "Event dialogue selects the expressive pose")
	scene._dismiss_guidance()
	check(not scene.faction_card.visible, "Reaction can be dismissed without changing tutorial preference")
	scene.guide.enabled = true
	scene._refresh_guidance()
	var comms_position: int = scene.faction_message.visible_characters
	scene._refresh_guidance()
	check(scene.faction_message.visible_characters == comms_position, "Frame refresh does not restart text")
	scene._open_sound_settings()
	check(scene.sound_overlay.visible and scene.is_board_input_locked(), "Settings are modal")
	var state: int = scene._rng.state
	await scene._roll_clicked()
	check(scene._rng.state == state, "Settings block accidental background rolls")
	var effects := scene.sound_overlay.find_child("EffectsVolume", true, false) as HSlider
	var dialogue := scene.sound_overlay.find_child("DialogueVolume", true, false) as HSlider
	effects.value = .27
	dialogue.value = .12
	check(is_equal_approx(audio.effects_volume, .27) and is_equal_approx(audio.dialogue_volume, .12), "Mix channels have independent controls")
	audio.play("launch", 0)
	check(audio.voices.any(func(voice: AudioStreamPlayer): return voice.playing), "Unmuted effects start playback")
	audio.set_muted(true)
	var stopped := true
	for voice in audio.voices:
		stopped = stopped and not voice.playing
	check(stopped, "Mute stops already playing sounds")
	audio.play("capture")
	for voice in audio.voices:
		check(not voice.playing, "Muted effects do not start")
	# Preference persistence uses a temporary file, never the player's settings.
	audio.settings_path = "user://test-audio-%d.cfg" % Time.get_ticks_usec()
	audio.remember_preferences = true
	audio.portrait_motion = false
	audio.save_preferences()
	var restored := Audio.new()
	restored.settings_path = audio.settings_path
	root.add_child(restored)
	check(not restored.enabled and not restored.portrait_motion and is_equal_approx(restored.effects_volume, .27) and is_equal_approx(restored.dialogue_volume, .12), "Mute, both levels and portrait preference persist")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(audio.settings_path))
	audio.remember_preferences = false
	check(scene.game.pawns[0] == [-1, -1, -1, -1], "Audio/dialogue settings leave rules untouched")
	await finish("audio/dialogue checks, assets, dialogue reveal, mix controls, mute and persistence")

func _source_pcm(path: String) -> PackedByteArray:
	# Imported audio may use QOA compression. Check the original PCM signal.
	var source := FileAccess.get_file_as_bytes(path)
	var cursor := 12
	while cursor + 8 <= source.size():
		var chunk_size := source.decode_u32(cursor + 4)
		if source.slice(cursor, cursor + 4).get_string_from_ascii() == "data":
			return source.slice(cursor + 8, cursor + 8 + chunk_size)
		cursor += 8 + chunk_size + chunk_size % 2
	return PackedByteArray()
