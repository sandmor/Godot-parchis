extends "res://tests/support/test_case.gd"
const Rules := preload("res://ParquesRules.gd")
const Guide := preload("res://FieldGuide.gd")
var scene: Node3D

func _run() -> void:
	scene = load_game()
	await process_frame
	check(not scene.faction_card.visible, "Lobby does not compete with field guidance")
	scene.fast_dice.button_pressed = true
	scene._start_match()
	scene._refresh_guidance()
	check(scene.guide.active == "opening" and scene.faction_card.visible, "Opening asks for a real roll")
	check(not scene.is_board_input_locked(), "Field guidance permits real actions")
	await scene._roll_clicked()
	check(scene.guide.seen.has("opening"), "Real roll completes opening instruction")
	while scene.game.phase == "opening":
		scene.game.roll(6, 5)
	scene.faction_briefing.finish()
	scene._refresh_guidance()
	check(scene.guide.active == "jail", "Jail guidance follows the opening contest")
	check(scene.game.pawns[scene.game.current_player] == [-1, -1, -1, -1], "Reading the story never releases crew")
	# Rules fixture for release guidance; physical/controller integration is tested above.
	scene.guide.complete("jail")
	scene.game.roll(3,3)
	scene._refresh_guidance()
	check(scene.guide.seen.has("jail") and scene.guide.active == "release", "Pair unlocks the first launch instruction")
	check(not scene.guide.seen.has("release"), "Available action does not count as a completed launch")
	var player: int = scene.game.current_player
	scene._select_pawn(0)
	check(scene.guide.seen.has("select"), "Selecting a legal unit records the interaction")
	check(not scene.pawn_buttons.visible and not scene.choices.visible, "Duplicate lists are hidden by default")
	var launch: Dictionary = scene.game.legal_moves()[0]
	await scene._execute_move(launch)
	check(scene.game.pawns[player][0] == 0 and scene.guide.seen.has("release"), "Animated real launch completes release guidance")
	check(scene.game.phase == "await_roll", "Launch still requires a fresh movement roll")
	scene.game.roll(2, 3)
	scene._refresh_guidance()
	check(scene.guide.active == "move", "Landing selection is taught when a real move exists")
	await scene._execute_move({"pawn": 0, "mask": 3, "target": 80})
	check(not scene.guide.seen.has("move"), "Rejected actions do not advance tutorial progress")
	await scene._execute_move(scene.game.legal_moves()[0])
	check(scene.guide.seen.has("move"), "Real destination choice completes movement instruction")
	scene._guide_notice("capture")
	scene._refresh_guidance()
	check(scene.guide.active == "capture", "Event guidance explains captures only when triggered")
	scene._dismiss_guidance()
	check(scene.guide.seen.has("capture") and scene.guide.enabled, "Acknowledging an event keeps guidance enabled")
	scene.guide.enabled = false
	scene._refresh_guidance()
	check(scene.guide.active.is_empty(), "Guidance can be hidden without blocking play")
	scene._menu_action(1)
	check(scene.guide.enabled and scene.guide.seen.is_empty(), "Options restarts first-action guidance")
	scene._menu_action(2)
	check(scene.pawn_buttons.visible and scene.choices.visible, "Optional detailed controls remain accessible")
	scene._menu_action(3)
	check(scene.board.coordinates_visible, "Coordinates are optional")
	for label in get_nodes_in_group("ArenaCoordinates"):
		check(label.visible, "Enabling coordinates reveals each space number")
	await create_timer(.9).timeout
	check(scene.effects.trails.is_empty() and scene.effects.get_child_count() == 0, "Travel effects clean themselves up")
	var first := Guide.new()
	first.storage_path = "user://test-guide-%d.cfg" % Time.get_ticks_usec()
	first.complete("move")
	first.enabled = false
	first.save()
	var second := Guide.new()
	second.storage_path = first.storage_path
	second.restore()
	check(second.seen.has("move") and not second.enabled, "Progress and preference survive reload")
	second.reset()
	var third := Guide.new()
	third.storage_path = first.storage_path
	third.restore()
	check(third.seen.is_empty() and third.enabled, "Guidance reset persists")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(first.storage_path))
	await finish("guidance checks, real actions, optional controls, persistence and effect cleanup")
