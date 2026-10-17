extends "res://tests/support/test_case.gd"
## Regression: a real Skip click resolves two random dice without waiting for physics.
func _run() -> void:
	var scene: Node3D = load_game()
	await process_frame
	scene._start_match()
	var stage: Node = scene.dice_stage
	var skipped: Array[int] = []
	var results: Array[Array] = []
	var hidden_impacts: Array[float] = []
	var expected_rng := RandomNumberGenerator.new()
	stage.animation_skipped.connect(func(): skipped.append(1))
	stage.result_ready.connect(func(values: Array[int]): results.append(values.duplicate()))
	stage.collision_cue.connect(func(gain: float):
		if stage.was_skipped: hidden_impacts.append(gain))
	stage.skip()
	check(skipped.is_empty() and not stage.was_skipped,"Idle skips are ignored")
	var player: int = scene.game.current_player
	var opening_before: Dictionary = scene.game._opening_scores.duplicate()
	scene._roll_clicked()
	await process_frame
	check(stage.playing and stage._simulating and scene.dice_overlay.visible,"A live throw opens the overlay")
	var button: Button = scene.dice_overlay.find_child("SkipDiceAnimation",true,false)
	check(button != null and button.is_visible_in_tree(),"Skip is a visible clickable control")
	expected_rng.state = stage.throw_rng.state
	var expected: Array[int] = [expected_rng.randi_range(1,6),expected_rng.randi_range(1,6)]
	dispatch_click(button)
	check(not scene.dice_overlay.visible,"Click dismisses the animation immediately")
	check(stage._resolved and not stage._simulating,"Skip stops physics immediately")
	check(stage._values == expected,"Skip draws exactly two independent uniform random values")
	check(scene.game._opening_scores == opening_before,"Controller commits on its next process frame")
	stage.skip()
	check(skipped.size() == 1,"Repeated skips cannot reroll the result")
	scene._roll_clicked()
	await process_frame
	await process_frame
	check(not scene._busy and not stage.playing,"Controller unlocks within two frames without settlement")
	check(results.size() == 1 and results[0] == expected,"Exactly one random result is emitted")
	check(results[0] == [stage.read_top_value(0),stage.read_top_value(1)],"Stopped dice match the chosen values")
	check(scene.game._opening_scores[player] == expected[0]+expected[1],"Controller commits the chosen result to the rules")
	check(hidden_impacts.is_empty(),"Skipped animation has no hidden impact sounds")
	stage.skip()
	check(skipped.size() == 1,"Late skips cannot affect another roll")
	# Skip also works in the final result hold, after settlement.
	stage.play(Color.WHITE,true,17)
	check(not stage.was_skipped,"Next throw clears skip state")
	while not stage._resolved: await physics_frame
	check(stage.playing,"Resolved throw is in its result hold")
	var revealed: Array = stage._values.duplicate()
	stage.skip()
	check(stage._values == revealed,"Skipping a revealed result never rerolls")
	await process_frame
	await process_frame
	check(not stage.playing and skipped.size() == 2,"Skip ends the result hold")
	await finish("skip checks: real GUI dismissal, immediate random results, exact-once commit and hold skipping")
