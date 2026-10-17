extends "res://tests/support/test_case.gd"
const Rules := preload("res://ParquesRules.gd")

func fresh() -> ParquesRules:
	var rules := Rules.new()
	var entries: Array[Dictionary] = [{"name": "Red", "color": 0}, {"name": "Blue", "color": 2}]
	check(rules.configure(entries), "Valid setup")
	check(rules.roll(6, 6), "First opening roll")
	check(rules.roll(1, 2), "Second opening roll")
	check(rules.phase == "await_roll" and rules.current_player == 0, "Highest opening total starts")
	return rules

func _run() -> void:
	_test_setup_and_ties()
	_test_jail_and_dice()
	_test_capture_and_protection()
	_test_doubles_and_goal()
	_test_turn_order()
	_simulate_matches()
	await finish("rule checks, including complete simulated 2/3/4-player matches")

func _test_setup_and_ties() -> void:
	var rules := Rules.new()
	var duplicate: Array[Dictionary] = [{"name": "A", "color": 0}, {"name": "B", "color": 0}]
	check(not rules.configure(duplicate), "Duplicate colors rejected")
	var blank: Array[Dictionary] = [{"name": " ", "color": 0}, {"name": "B", "color": 2}]
	check(not rules.configure(blank), "Blank name rejected")
	var entries: Array[Dictionary] = [{"name": "A", "color": 0}, {"name": "B", "color": 2}, {"name": "C", "color": 1}]
	check(rules.configure(entries), "Three players can register")
	rules.roll(6, 1)
	rules.roll(3, 4)
	rules.roll(1, 2)
	check(rules.phase == "opening" and rules.current_player == 0, "Only highest tied candidates reroll")
	rules.roll(2, 2)
	rules.roll(5, 1)
	check(rules.phase == "await_roll" and rules.current_player == 1, "Opening tie resolves correctly")
	check(rules.consecutive_doubles == 0, "Opening doubles do not count toward bonus")
	check(not rules.roll(0, 7), "Invalid dice rejected")
	check(not rules.configure(entries), "Player registration is locked during a match")
	check(rules.players.size() == 3 and rules.current_player == 1, "Rejected registration preserves match")

func _test_jail_and_dice() -> void:
	var rules := fresh()
	rules.roll(1, 2)
	check(rules.current_player == 0 and rules.jail_attempts == 2, "First jail failure retains turn")
	rules.roll(3, 4)
	check(rules.jail_attempts == 1, "Second jail failure")
	rules.roll(5, 6)
	check(rules.current_player == 1 and rules.jail_attempts == 3, "Third failure passes turn")
	rules.roll(2, 2)
	check(rules.phase == "move" and rules.legal_moves().size() == 4, "Doubles highlight all jailed pawns")
	check(not rules.play(0, 1), "Release requires the pair")
	check(rules.play(0, 3), "Pair releases selected pawn")
	check(rules.pawns[1][0] == 0 and rules.phase == "await_roll", "Release goes to salida and rolls again")
	rules.roll(2, 3)
	check(not rules.play(1, 3), "Cannot release on unequal dice")
	check(rules.legal_moves().size() == 3, "One die, other die, and combined choices")
	check(rules.play(0, 1), "Spend first die")
	check(rules.pawns[1][0] == 2 and rules.dice_remaining == [false, true], "First die consumed exactly")
	check(not rules.play(0, 1), "Cannot reuse spent die")
	check(not rules.roll(6, 6), "Cannot roll before spending remaining legal die")
	check(rules.play(0, 2), "Spend remaining die")
	check(rules.pawns[1][0] == 5 and rules.current_player == 0, "Both values moved and turn passed")
	var combined := fresh()
	combined.pawns[0][0] = 0
	combined.roll(3, 5)
	check(combined.play(0, 3) and combined.pawns[0][0] == 8, "Both dice combine on one pawn")
	var split := fresh()
	split.pawns[0] = [0, 0, -1, -1]
	split.roll(1, 2)
	split.play(0, 1)
	split.play(1, 2)
	check(split.pawns[0] == [1, 2, -1, -1], "Dice can be distributed over two pawns")

func _test_capture_and_protection() -> void:
	var rules := fresh()
	rules.pawns[0][0] = 0
	rules.pawns[1][0] = 49 # Both land on shared cell 2 after Red moves 1.
	rules.roll(1, 2)
	rules.play(0, 1)
	check(rules.pawns[1][0] == -1 and rules.captured.size() == 1, "Unsafe landing captures rival")
	var safe := fresh()
	safe.pawns[0][0] = 78
	safe.pawns[1][0] = 31 # Shared seguro 20.
	safe.roll(1, 2)
	safe.play(0, 1)
	check(safe.pawns[1][0] == 31 and safe.captured.is_empty(), "Seguro prevents capture")
	var salida := fresh()
	salida.pawns[0][0] = 71
	salida.pawns[1][0] = 24 # Shared salida 27.
	salida.roll(1, 2)
	salida.play(0, 1)
	check(salida.pawns[1][0] == 24, "Salida prevents capture")
	check(salida.circuit_index(0, Rules.TRACK_STEPS + 1) == -1, "Home lanes cannot be captured on shared path")
	check(salida.circuit_index(0, Rules.TRACK_STEPS) == 11, "Own gate connects to home entrance")
	var release := fresh()
	release.pawns[1][0] = 48 # Rival on Red salida.
	release.roll(2, 2)
	release.play(0, 3)
	check(release.pawns[1][0] == 48, "Releasing onto occupied salida preserves rival")

func _test_doubles_and_goal() -> void:
	var rules := fresh()
	rules.roll(2, 2)
	rules.play(0, 3)
	rules.roll(3, 3)
	rules.play(0, 3)
	check(rules.phase == "await_roll" and rules.consecutive_doubles == 2, "Doubles retain turn and count consecutively")
	rules.roll(4, 4)
	check(rules.phase == "bonus" and not rules.play(0, 3), "Third doubles offer bonus instead of ordinary move")
	check(rules.claim_bonus(2) and rules.pawns[0][2] == Rules.FINISHED, "Chosen pawn can be promoted from jail")
	check(rules.phase == "await_roll" and rules.consecutive_doubles == 0, "Bonus resets streak and retains turn")
	check(not rules.claim_bonus(1), "Cannot claim extra bonus")
	var stranded := fresh()
	stranded.pawns[0] = [Rules.GOAL - 1, Rules.GOAL, Rules.GOAL, Rules.GOAL]
	stranded.roll(6, 6)
	check(stranded.current_player == 0 and stranded.phase == "await_roll", "Unusable doubles still retain the turn")
	stranded.roll(5, 5)
	stranded.roll(4, 4)
	check(stranded.phase == "bonus", "Unusable doubles count toward third-pair bonus")
	var exact := fresh()
	exact.pawns[0][0] = Rules.GOAL - 2
	exact.roll(1, 2)
	check(exact.legal_moves().size() == 2, "Overshoot is illegal")
	check(not exact.play(0, 3), "Combined overshoot rejected")
	exact.play(0, 2)
	check(exact.finished_count(0) == 1, "Exact roll finishes pawn")
	check(exact.current_player == 1, "Unusable remaining die is forfeited automatically")
	var win := fresh()
	win.pawns[0] = [Rules.GOAL, Rules.GOAL, Rules.GOAL, Rules.GOAL - 2]
	win.roll(2, 4)
	win.play(3, 1)
	check(win.phase == "game_over" and win.winner == 0, "Four finished pawns win")
	check(not win.roll(1, 1) and not win.play(3, 2), "Game over locks actions")
	var bonus_win := fresh()
	bonus_win.pawns[0] = [Rules.GOAL, Rules.GOAL, Rules.GOAL, -1]
	bonus_win.consecutive_doubles = 2
	bonus_win.roll(1, 1)
	bonus_win.claim_bonus(3)
	check(bonus_win.phase == "game_over", "Bonus may finish the match")

func _test_turn_order() -> void:
	var rules := Rules.new()
	var entries: Array[Dictionary] = [{"name": "Red", "color": 0}, {"name": "Green", "color": 1}, {"name": "Blue", "color": 2}, {"name": "Yellow", "color": 3}]
	rules.configure(entries)
	rules.roll(6, 6)
	for index in range(3):
		rules.roll(1, 2)
	for color_id in [3, 2, 1, 0]:
		for attempt in range(3):
			rules.roll(1, 2)
		check(rules.players[rules.current_player].color == color_id, "Turns pass to the right")

func _simulate_matches() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 158342
	for count in [2, 3, 4]:
		for match_index in range(3):
			var rules := Rules.new()
			var entries: Array[Dictionary] = []
			for index in range(count):
				entries.append({"name": "P%d" % index, "color": index})
			rules.configure(entries)
			var actions := 0
			while rules.phase != "game_over" and actions < 30000:
				actions += 1
				if rules.phase in ["opening", "await_roll"]:
					check(rules.roll(rng.randi_range(1, 6), rng.randi_range(1, 6)), "Simulated roll is valid")
				elif rules.phase == "move":
					var moves := rules.legal_moves()
					check(not moves.is_empty(), "Move phase always has legal choices")
					var move: Dictionary = moves[rng.randi_range(0, moves.size() - 1)]
					check(rules.play(move.pawn, move.mask), "Generated move executes")
				elif rules.phase == "bonus":
					for pawn in range(4):
						if rules.pawns[rules.current_player][pawn] != Rules.FINISHED:
							check(rules.claim_bonus(pawn), "Simulated bonus")
							break
				else:
					check(false, "Unexpected phase")
				for row in rules.pawns:
					for progress in row:
						check(progress >= -1 and progress <= Rules.GOAL, "Pawns stay within legal route")
			check(rules.phase == "game_over", "Random match reaches victory without a deadlock")
