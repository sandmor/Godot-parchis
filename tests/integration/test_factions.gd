extends "res://tests/support/test_case.gd"
const Lore := preload("res://Factions.gd")
var scene: Node3D

func _run() -> void:
	scene = load_game()
	await process_frame
	check(not scene.faction_briefing.visible and scene._host_faction == -1, "No narrator chosen before opening contest")
	var names := {}
	for faction_id in range(4):
		var faction := Lore.profile(faction_id)
		check(not names.has(faction.character), "Each faction has a distinct representative")
		names[faction.character] = true
		check(ResourceLoader.exists(faction.portrait), "Portrait is a project asset")
		check(load(faction.portrait) is PortraitSequence, "Portrait sequence loads successfully")
		scene.show_lobby()
		scene.color_inputs[0].select((faction_id + 1) % 4)
		scene.color_inputs[1].select(faction_id)
		scene.name_inputs[0].text = "Rival"
		scene.name_inputs[1].text = "Pilot"
		scene._preview_lobby_faction(1)
		check(scene.lobby_faction_name.text == faction.name and scene.lobby_portrait.texture != null, "Lobby previews chosen character and portrait")
		scene._start_match()
		scene.game.roll(1, 2)
		check(not scene.faction_briefing.visible, "Briefing waits for all opening rolls")
		scene.game.roll(6, 6)
		check(scene.game.current_player == 1, "Second seat wins opening contest")
		check(scene._host_faction == faction_id and scene.faction_briefing.faction_id == faction_id, "Narrator uses faction/color, not winner's seat index")
		check(scene.faction_briefing.portrait.texture != null and scene.faction_portrait.texture != null, "Briefing and contact card show the character")
		check("Pilot" in scene.faction_briefing.dialogue.text and "Loom" in scene.faction_briefing.dialogue.text, "Introduction addresses winner and introduces the Loom")
		check(scene.faction_briefing.page_index == 0 and scene.faction_briefing.pages.size() == 1, "Briefing starts at welcome")
		check(scene.is_board_input_locked() and scene.roll_button.disabled, "Briefing locks gameplay")
		var rng_state: int = scene._rng.state
		await scene._roll_clicked()
		scene._select_pawn(0)
		check(scene._rng.state == rng_state and scene._selected == -1, "Blocked clicks do not roll dice or select pawns")
		check(scene.game.pawns[1] == [-1, -1, -1, -1] and scene.game.consecutive_doubles == 0, "Opening doubles remain separate from jail release and streak")
		await click(scene.faction_briefing.next_button)
		check(not scene.faction_briefing.visible and not scene.roll_button.disabled, "Completing briefing enables first turn")
		check(scene.game.phase == "await_roll" and scene.game.current_player == 1 and scene.game.jail_attempts == 3, "Reading briefing never spends a turn or attempt")
		for attempt in range(3):
			scene.game.roll(3, 4)
		check(scene.game.current_player == 0 and not scene.faction_briefing.visible, "Later turns do not replay introduction automatically")
		check(scene._host_faction == faction_id and scene.faction_card.visible, "Opening faction remains the shared screen's contact")
		var progress: Array = scene.game.pawns.duplicate(true)
		scene.replay_briefing()
		check(scene.faction_briefing.visible and scene.faction_briefing.page_index == 0, "Briefing can be replayed")
		await click(scene.faction_briefing.find_child("SkipBriefing", true, false))
		check(not scene.faction_briefing.visible and scene.game.pawns == progress, "Skipping is safe and resumes the same match")
		scene.show_lobby()
		check(not scene.faction_card.visible and scene._host_faction == -1, "Returning to lobby resets narrator")
	# Opening ties must not trigger an introduction early.
	scene.color_inputs[0].select(0)
	scene.color_inputs[1].select(2)
	scene._start_match()
	scene.game.roll(3, 3)
	scene.game.roll(3, 3)
	check(scene.game.phase == "opening" and not scene.faction_briefing.visible, "Tied opening waits for rerolls")
	scene.game.roll(3, 4)
	scene.game.roll(4, 4)
	check(scene.faction_briefing.faction_id == 2, "Tie winner's faction introduces match")
	scene.faction_briefing.finish()
	scene.show_lobby()
	# Resolve the last opening roll through the actual asynchronous dice cinematic.
	# The briefing must stay modal after the controller clears its animation lock.
	scene._start_match()
	scene.game.roll(1, 2)
	scene._rng.seed = 8291
	scene.fast_dice.button_pressed = true
	await scene._roll_clicked()
	check(scene.faction_briefing.visible and not scene._busy and scene.roll_button.disabled, "Final cinematic transitions to a separately locked faction introduction")
	check(scene._host_faction == 2 and scene.game.phase == "await_roll", "Actual cinematic winner selects the correct faction")
	scene.faction_briefing.finish()
	scene.show_lobby()
	# Future per-screen presentation can choose the viewer without altering turns.
	scene.local_faction_id = 2
	scene.name_inputs[0].text = "First player"
	scene.name_inputs[1].text = "Local viewer"
	scene._start_match()
	scene.game.roll(6, 6)
	scene.game.roll(1, 2)
	check(scene.game.current_player == 0 and scene._host_faction == 2, "Local faction override changes narrator, not first player")
	check("Local viewer" in scene.faction_briefing.dialogue.text and "First player" in scene.faction_briefing.dialogue.text, "Local presentation addresses viewer and names the actual opening player")
	check("first turn confirmed" not in scene.faction_briefing.dialogue.text and "your opening total was highest" not in scene.faction_briefing.dialogue.text.to_lower(), "Non-opening viewer is not told they won the first turn")
	scene.faction_briefing.finish()
	await finish("faction checks across all four opening winners, single prologue, skip/replay, ties, rematch and local viewer override")

