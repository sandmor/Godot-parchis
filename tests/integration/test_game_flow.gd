extends "res://tests/support/test_case.gd"
const Rules := preload("res://ParquesRules.gd")
var scene: Node3D

func _run() -> void:
	scene = load_game()
	await process_frame
	check(scene.setup_overlay.visible, "Lobby opens first")
	for cell in range(Rules.CIRCUIT):
		check(scene.game.is_protected(cell) == scene.board.is_protected_cell(cell), "Rules match visible protected cells")
	for team in range(4):
		check(scene.board.launch_indices[team] == team * Rules.SECTOR + Rules.LAUNCH_OFFSET, "Pawn salida agrees with rendered board")
	scene.name_inputs[0].text = "Nova"
	scene.name_inputs[1].text = "Vega"
	scene.fast_dice.button_pressed = true
	scene.color_inputs[1].select(scene.color_inputs[0].selected)
	scene._start_match()
	check(scene.setup_overlay.visible and not scene.setup_error.text.is_empty(), "Duplicate color displays actionable lobby error")
	scene.color_inputs[1].select(2)
	scene._start_match()
	check(not scene.setup_overlay.visible and scene.game.phase == "opening", "Names/colors start opening contest")
	# The real roll action invokes the cinematic, commits the physical faces once,
	# and unlocks the next player's roll without overlapping actions.
	scene._rng.seed = 8291
	await scene._roll_clicked()
	check(not scene._busy and not scene.dice_overlay.visible, "Dice cinematic completes and unlocks interface")
	check(scene.game.last_roll.size() == 2, "Actual roll reaches game state")
	check(scene.game.last_roll == scene.dice_stage._values,"Rules consume the physical throw unchanged")
	while scene.game.phase == "opening":
		scene.game.roll(6, 5)
	check(scene.faction_briefing.visible, "Opening winner's faction introduces the match")
	check(scene._host_faction == scene.game.players[scene.game.current_player].color, "Narrator follows winner's chosen faction")
	check(scene.roll_button.disabled, "Briefing blocks gameplay until dismissed")
	await click(scene.faction_briefing.find_child("SkipBriefing", true, false))
	check(not scene.faction_briefing.visible, "Briefing can be skipped through real GUI input")
	var player: int = scene.game.current_player
	var team: int = scene.game.players[player].color
	check(scene.roll_button.disabled == false, "Active player can roll")
	scene.game.roll(1, 2)
	check("Pair required" in scene.status.text and scene.game.legal_moves().is_empty(), "Failed jail roll explains why there are no moves")
	await click(scene.move_overlay.get_node("pawn_1"))
	check(scene._selected == 1, "Real GUI click inspects a jailed pawn before doubles")
	check(scene.game.legal_moves().is_empty(), "Inspection does not unlock illegal movement")
	scene.game.roll(2, 2)
	for pawn_index in range(4):
		var piece: Node3D = scene.board.pawn_nodes[team][pawn_index]
		check(piece.find_children("*", "MeshInstance3D", true, false)[0].material_overlay != null, "Eligible pawn mesh itself glows")
	await click(scene.move_overlay.get_node("pawn_0"))
	check(scene._selected == 0, "Real GUI pin selects the desired eligible pawn")
	check(scene.choices.get_child_count() >= 1, "Selecting pawn shows legal move buttons")
	var release: Dictionary = scene.game.legal_moves()[0]
	await scene._execute_move(release)
	check(scene.game.pawns[player][0] == 0 and not scene._busy, "Release animation commits legal state")
	var pawn: Node3D = scene.board.pawn_nodes[team][0]
	check(pawn.position.distance_to(scene._position_for_progress(player, 0, 0)) < 0.01, "Pawn physically lands on its salida")
	scene.game.roll(2, 3)
	check(scene._selected == 0, "Only eligible pawn is selected automatically")
	var move_pins := 0
	for pin in scene.move_overlay.pins:
		if pin.kind == "move":
			move_pins += 1
	check(move_pins == 3, "Every legal die value has a readable GUI landing target")
	await create_timer(0.4).timeout
	var destination_pin: Button = scene.move_overlay.get_node("move_0")
	check(destination_pin.size.x >= 48 and destination_pin.size.y >= 38, "Landing targets retain a usable screen hit area")
	await click(destination_pin)
	check(scene._busy, "Real GUI destination click starts animated movement")
	while scene._busy:
		await process_frame
	check(scene.game.pawns[player][0] == 2 and scene.game.dice_remaining == [false, true], "Destination click spends correct die")
	scene._select_pawn(0)
	var second_move: Dictionary = scene.game.legal_moves()[0]
	await scene._execute_move(second_move)
	check(scene.game.pawns[player][0] == 5 and scene.game.current_player != player, "Remaining die moves, then turn passes")
	# Force a normal final legal roll to exercise the actual win presentation.
	player = scene.game.current_player
	scene.game.pawns[player] = [Rules.GOAL, Rules.GOAL, Rules.GOAL, Rules.GOAL - 1]
	scene.game.roll(1, 2)
	scene._refresh()
	var winning_move: Dictionary = scene.game.legal_moves()[0]
	await scene._execute_move(winning_move)
	check(scene.game.phase == "game_over" and scene.victory_overlay.visible, "Exact final move shows win screen")
	check(scene.roll_button.disabled, "Win locks roll action")
	scene.show_lobby()
	check(scene.setup_overlay.visible and scene.game.phase == "lobby", "Rematch returns to editable lobby")
	check(scene.highlights.get_child_count() == 0, "Rematch removes stale move hints")
	check(scene.setup_error.text.is_empty(), "Rematch clears old validation errors")
	scene.player_count.select(2)
	scene._update_setup()
	check(scene.player_rows[3].visible, "Four-player lobby displays all seats")
	scene._start_match()
	check(scene.game.players.size() == 4 and scene.game.phase == "opening", "Four-player lobby starts a match")
	scene.show_lobby()
	scene.player_count.select(0)
	scene._update_setup()
	await finish("game-flow checks: GUI clicks, dice commit, moves, victory and rematch")
