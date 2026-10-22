extends Node3D
## Local 2–4 player game. Rules have no dependency on the presentation.
const Lore := preload("res://Factions.gd")
const Briefing := preload("res://FactionBriefing.gd")
const Overlay := preload("res://MoveOverlay.gd")
const SIDEBAR_WIDTH := 288.0
const Rules := preload("res://ParquesRules.gd")
const DiceScene := preload("res://DiceThrow.tscn")
const DEFAULT_COLORS := [0, 2, 1, 3]
var game := Rules.new()
const Guide := preload("res://FieldGuide.gd")
var guide := Guide.new()
@export var remember_guidance := true
var effects: Node3D
var audio: Node
var guide_dismiss: Button
var _guide_event := ""
var _guide_event_until := 0.0
var _details_open := false
var settings: MenuButton
var guide_beacon: Control
var command_dock: PanelContainer
var comms_reveal: Node
var _comms_id := ""
var _reaction_text := ""
var _reaction_until := 0.0
var _reaction_team := 0
var sound_overlay: Control
@export var remember_audio_settings := true
var board: Node3D
var camera: Camera3D
var ui: Control
var setup_overlay: Control
var dice_overlay: Control
var victory_overlay: Control
var dice_stage: Node3D
var dice_viewport: SubViewport
var dice_caption: Label
var dice_result: Label
var roster: VBoxContainer
var turn_title: Label
var status: Label
var dice_labels: Array[Label] = []
var actions: HBoxContainer
var choices: VBoxContainer
var pawn_buttons: GridContainer
var move_overlay: Control
var cell_info: Label
var phase_badge: Label
var focus_button: Button
var _view_player := -1
var _glow_material: StandardMaterial3D
var _selected_glow: StandardMaterial3D
var roll_button: Button
var lobby_button: Button
var setup_error: Label
var player_count: OptionButton
var fast_dice: CheckBox
var name_inputs: Array[LineEdit] = []
var color_inputs: Array[OptionButton] = []
var player_rows: Array[HBoxContainer] = []
var highlights: Node3D
var _selected := -1
var _busy := false
var _clock := 0.0
var _rng := RandomNumberGenerator.new()
var _pawn_tweens: Array[Tween] = []
var _log: Array[String] = []
var history_label: Label
var _victory_shown := false
var faction_briefing: Control
var faction_card: PanelContainer
var faction_portrait: Control
var faction_heading: Label
var faction_speaker: Label
var faction_message: Label
var lobby_portrait: Control
var lobby_faction_name: Label
var lobby_character: Label
var lobby_description: Label
var _host_faction := -1
var _host_player_name := ""
var _opening_player_name := ""
var _host_opens_match := true
var _last_game_phase := "lobby"
## Future clients can set this to their local player's faction (color ID).
## -1 uses the opening winner as the shared screen's narrator.
@export_range(-1, 3) var local_faction_id: int = -1

func _ready() -> void:
	Lore.Manager._ensure_translations()
	board = get_node("Board")
	camera = get_node("Camera3D")
	var old_hud := get_node_or_null("HUD")
	if old_hud:
		remove_child(old_hud)
		old_hud.queue_free()
	_rng.randomize()
	highlights = Node3D.new()
	highlights.name = "MoveHighlights"
	board.add_child(highlights)
	guide.remember = remember_guidance
	guide.restore()
	effects = preload("res://ArenaEffects.gd").new()
	board.add_child(effects)
	audio = preload("res://ArenaAudio.gd").new()
	audio.remember_preferences = remember_audio_settings
	add_child(audio)
	comms_reveal = preload("res://DialogueReveal.gd").new()
	add_child(comms_reveal)
	comms_reveal.tick.connect(func(): audio.play("text", maxi(0, _host_faction)))
	_build_backdrop()
	_build_ui()
	game.changed.connect(_on_game_changed)
	show_lobby()

func _process(delta: float) -> void:
	_clock += delta
	if is_instance_valid(command_dock) and is_instance_valid(setup_overlay) and is_instance_valid(dice_overlay):
		command_dock.visible = not setup_overlay.visible and not dice_overlay.visible and not _briefing_open() and game.phase != "game_over"
	if is_instance_valid(faction_card):
		_refresh_guidance()
		faction_portrait.speaking = faction_card.is_visible_in_tree() and comms_reveal.revealing
	for portrait in get_tree().get_nodes_in_group("AnimatedPortraits"):
		portrait.motion_enabled = audio.portrait_motion
	if is_instance_valid(roll_button) and not roll_button.disabled and guide.active in ["opening", "jail", "roll"]:
		roll_button.modulate = Color.WHITE.lerp(Color("8ce5eb"), .25 + sin(_clock * 3) * .2)
	elif is_instance_valid(roll_button):
		roll_button.modulate = Color.WHITE
	if is_instance_valid(move_overlay):
		move_overlay.bounds = get_play_rect()
		_update_cell_info()
	if _glow_material:
		_glow_material.emission_energy_multiplier = 0.8 + sin(_clock * 4.5) * 0.25
	for child in highlights.get_children():
		if child is MeshInstance3D:
			var pulse := 1.0 + sin(_clock * 4.5) * 0.07
			child.scale = Vector3(pulse, 1, pulse)

func get_play_rect() -> Rect2:
	var viewport_size := get_viewport().get_visible_rect().size
	return Rect2(18, 18, maxf(100, viewport_size.x - SIDEBAR_WIDTH - 52), maxf(100, viewport_size.y - 62))

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "GameUI"
	add_child(layer)
	ui = Control.new()
	ui.name = "Interface"
	layer.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font_size = 17
	for kind in ["Button", "OptionButton", "LineEdit"]:
		theme.set_stylebox("normal", kind, _style(Color("152b40"), Color("356078")))
		theme.set_stylebox("hover", kind, _style(Color("23435b"), Color("45ddeb")))
		theme.set_stylebox("focus", kind, _style(Color(0.1, 0.25, 0.35, 0.5), Color("7df2ff")))
		theme.set_stylebox("pressed", kind, _style(Color("2c5b6d"), Color("82f4ff")))
		theme.set_stylebox("disabled", kind, _style(Color("101e2c"), Color("243744")))
		theme.set_color("font_color", kind, Color("e6f4ff"))
		theme.set_color("font_disabled_color", kind, Color("587084"))
	ui.theme = theme
	move_overlay = Overlay.new()
	move_overlay.name = "BoardTargets"
	ui.add_child(move_overlay)
	move_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	move_overlay.camera = camera
	move_overlay.bounds = get_play_rect()
	move_overlay.picked.connect(_pin_picked)
	var side := _panel(ui)
	command_dock = side
	side.name = "Sidebar"
	side.add_theme_stylebox_override("panel", _style(Color(.018, .035, .05, .9), Color(.16, .29, .34, .5)))
	side.anchor_left = 1
	side.anchor_right = 1
	side.anchor_bottom = 1
	side.offset_left = -SIDEBAR_WIDTH - 16
	side.offset_right = -16
	side.offset_top = 16
	side.offset_bottom = -42
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(scroll)
	var box := _vbox(scroll)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(box, "T H E  L O O M", 26)
	_label(box, "PARQUÉS  /  ORBITAL EXODUS", 11, Color("62bfc9"))
	var faction_panel := _panel(box)
	faction_panel.name = "FactionContact"
	faction_card = faction_panel
	var contact_row := HBoxContainer.new()
	contact_row.add_theme_constant_override("separation", 10)
	var guidance_box := _vbox(faction_panel)
	guidance_box.add_child(contact_row)
	faction_portrait = preload("res://AnimatedPortrait.gd").new()
	faction_portrait.custom_minimum_size = Vector2(88, 100)
	contact_row.add_child(faction_portrait)
	var contact_text := _vbox(contact_row)
	contact_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	faction_heading = _label(contact_text, "", 14)
	faction_speaker = _label(contact_text, "", 17)
	faction_message = _label(guidance_box, "", 15, Color("c9dce7"))
	faction_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	faction_message.custom_minimum_size.x = 230
	faction_message.mouse_filter = Control.MOUSE_FILTER_STOP
	faction_message.tooltip_text = "Click to show the full message"
	faction_message.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			comms_reveal.complete()
	)
	guide_dismiss = _button(guidance_box, "Hide guidance", _dismiss_guidance)
	guide_dismiss.add_theme_font_size_override("font_size", 12)
	faction_card.hide()
	roster = _vbox(box)
	box.add_child(HSeparator.new())
	turn_title = _label(box, "", 23)
	turn_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	turn_title.custom_minimum_size.x = 240
	phase_badge = _label(box, "", 15, Color("ffcf58"))
	var dice_row := HBoxContainer.new()
	box.add_child(dice_row)
	for index in range(2):
		var die_label := preload("res://ReactorDie.gd").new()
		dice_row.add_child(die_label)
		die_label.custom_minimum_size = Vector2(112, 58)
		die_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dice_labels.append(die_label)
	status = _label(box, "", 17, Color("c2d9e4"))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(240, 32)
	actions = HBoxContainer.new()
	box.add_child(actions)
	roll_button = _button(actions, tr("UI_ROLL_DICE"), _roll_clicked)
	roll_button.name = "RollDice"
	roll_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lobby_button = _button(actions, tr("UI_SETUP"), show_lobby)
	lobby_button.tooltip_text = tr("UI_TOOLTIP_SETUP")

	pawn_buttons = GridContainer.new()
	pawn_buttons.columns = 1
	box.add_child(pawn_buttons)
	pawn_buttons.hide()
	choices = VBoxContainer.new()
	choices.add_theme_constant_override("separation", 6)
	box.add_child(choices)
	choices.hide()
	box.add_child(HSeparator.new())
	var camera_row := HBoxContainer.new()
	box.add_child(camera_row)
	_button(camera_row, tr("UI_OVERVIEW"), func(): camera.overview())
	focus_button = _button(camera_row, tr("UI_FOCUS"), _focus_selected)
	_button(camera_row, tr("UI_VIEW_TOGGLE"), func(): camera.toggle_angle())
	settings = MenuButton.new()
	settings.text = tr("UI_OPTIONS")
	box.add_child(settings)
	var menu := settings.get_popup()
	menu.add_item(tr("MENU_PROLOGUE"), 0)
	menu.add_item(tr("MENU_RESTART_GUIDANCE"), 1)
	menu.add_check_item(tr("MENU_MOVE_LIST"), 2)
	menu.add_check_item(tr("MENU_COORDINATES"), 3)
	menu.add_item(tr("MENU_CAMERA_CONTROLS"), 4)
	menu.add_check_item(tr("MENU_MUTE_SOUND"), 5)
	menu.add_item(tr("MENU_AUDIO_SETTINGS"), 6)
	menu.set_item_checked(menu.get_item_index(5), not audio.enabled)
	menu.id_pressed.connect(_menu_action)
	var history_panel := _panel(box)
	history_panel.name = "HistoryPanel"
	history_label = _label(history_panel, "", 13, Color("8eafc0"))
	history_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	history_label.custom_minimum_size.x = 230
	history_panel.hide()
	cell_info = _label(ui, "", 14, Color("e0f5fc"))
	cell_info.anchor_top = 1
	cell_info.anchor_bottom = 1
	cell_info.offset_left = 22
	cell_info.offset_top = -32
	cell_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow_material = _pawn_glow(Color("79ffff"))
	_selected_glow = _pawn_glow(Color("fff3a6"))
	guide_beacon = preload("res://GuideBeacon.gd").new()
	ui.add_child(guide_beacon)
	_build_setup()
	_build_dice_overlay()
	faction_briefing = Briefing.new()
	faction_briefing.name = "FactionBriefing"
	ui.add_child(faction_briefing)
	faction_briefing.audio = audio
	faction_briefing.closed.connect(_on_briefing_closed)
	_build_sound_settings()

func _style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	return style

func _panel(parent: Node) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color(0.025, 0.055, 0.085, 1.0), Color("31566d")))
	parent.add_child(panel)
	return panel

func _vbox(parent: Node) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	parent.add_child(box)
	return box

func _label(parent: Node, text: String, size: int = 16, color: Color = Color("e4f2fa")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _extraction_progress(parent: Node, finished: int, color: Color) -> void:
	var progress := HBoxContainer.new()
	progress.name = "ExtractionProgress"
	progress.add_theme_constant_override("separation", 6)
	parent.add_child(progress)
	for slot in range(4):
		var light := Panel.new()
		light.custom_minimum_size = Vector2(10, 10)
		light.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		light.tooltip_text = "%d of 4 crew home" % finished
		var style := StyleBoxFlat.new()
		style.bg_color = color if slot < finished else Color("102332")
		style.border_color = color
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		light.add_theme_stylebox_override("panel", style)
		progress.add_child(light)
	_label(progress, "%d/4 home" % finished, 12, color)

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(button)
	button.pressed.connect(callback)
	return button

func _overlay(node_name: String) -> Control:
	var overlay := Control.new()
	overlay.name = node_name
	ui.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.004, 0.009, 0.022, 0.8)
	overlay.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return overlay

func _center_box(overlay: Control, width: float) -> VBoxContainer:
	var center := CenterContainer.new()
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := _panel(center)
	panel.custom_minimum_size.x = width
	return _vbox(panel)

func _build_setup() -> void:
	setup_overlay = _overlay("Lobby")
	var box := _center_box(setup_overlay, 650)
	_label(box, tr("LOBBY_TITLE"), 28, Color("69e4eb"))
	_label(box, tr("LOBBY_SUBTITLE"), 14)
	player_count = OptionButton.new()
	for count in [2, 3, 4]:
		player_count.add_item(tr("LOBBY_PLAYERS_COUNT").replace("{count}", str(count)), count)
	box.add_child(player_count)
	player_count.item_selected.connect(_update_setup.unbind(1))
	for index in range(4):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		box.add_child(row)
		player_rows.append(row)
		_label(row, "%02d" % (index + 1), 16, Color("6b9cae"))
		var name_field := LineEdit.new()
		name_field.placeholder_text = tr("LOBBY_PLAYER_NAME_PLACEHOLDER")
		name_field.text = tr("LOBBY_PLAYER_DEFAULT").replace("{n}", str(index + 1))
		name_field.max_length = 24
		name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_field)
		name_inputs.append(name_field)
		var color_field := OptionButton.new()
		color_field.custom_minimum_size.x = 210
		for team in range(4):
			color_field.add_item(Lore.profile(team).name, team)
		color_field.select(DEFAULT_COLORS[index])
		row.add_child(color_field)
		color_inputs.append(color_field)
		color_field.item_selected.connect(_preview_lobby_faction.bind(index).unbind(1))
	var preview_panel := _panel(box)
	var preview_row := HBoxContainer.new()
	preview_row.add_theme_constant_override("separation", 18)
	preview_panel.add_child(preview_row)
	lobby_portrait = preload("res://AnimatedPortrait.gd").new()
	lobby_portrait.custom_minimum_size = Vector2(150, 150)
	preview_row.add_child(lobby_portrait)
	var preview_text := _vbox(preview_row)
	preview_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lobby_faction_name = _label(preview_text, "", 20)
	lobby_character = _label(preview_text, "", 16)
	lobby_description = _label(preview_text, "", 14, Color("a1bdcc"))
	lobby_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lobby_description.custom_minimum_size.x = 410
	_preview_lobby_faction(0)
	fast_dice = CheckBox.new()
	fast_dice.text = tr("LOBBY_FAST_DICE")
	box.add_child(fast_dice)
	setup_error = _label(box, "", 14, Color("ff8493"))
	_button(box, tr("LOBBY_START_MATCH"), _start_match)
	_update_setup()

func _update_setup() -> void:
	var count := player_count.get_selected_id()
	for index in range(4):
		player_rows[index].visible = index < count
	setup_error.text = ""

func show_lobby() -> void:
	if _busy:
		return
	_kill_pawn_tweens()
	game.phase = "lobby"
	_last_game_phase = "lobby"
	_host_faction = -1
	_host_player_name = ""
	_opening_player_name = ""
	_host_opens_match = true
	if is_instance_valid(faction_briefing):
		faction_briefing.hide()
	faction_card.hide()
	_selected = -1
	_view_player = -1
	camera.overview(false)
	_victory_shown = false
	_log.clear()
	_guide_event = ""
	_comms_id = ""
	_reaction_text = ""
	_reaction_until = 0
	comms_reveal.stop()
	sound_overlay.hide()
	history_label.text = ""
	setup_error.text = ""
	setup_overlay.show()
	dice_overlay.hide()
	if is_instance_valid(victory_overlay):
		victory_overlay.queue_free()
		victory_overlay = null
	_clear_highlights()
	for team in range(4):
		for pawn in range(4):
			var node: Node3D = board.pawn_nodes[team][pawn]
			node.show()
			node.scale = Vector3.ONE * float(board.tile_spacing)
			node.position = board.jail_positions[team][pawn]
	for die_label in dice_labels:
		die_label.display(0, false, Color.WHITE)
	history_label.get_parent().hide()
	_clear_children(choices)
	turn_title.text = "Awaiting crew"
	turn_title.add_theme_color_override("font_color", Color("e4f2fa"))
	status.text = "Choose players and colors to start."
	phase_badge.text = "CREW SETUP"
	_clear_children(pawn_buttons)
	roll_button.disabled = true
	_clear_children(roster)
	_label(roster, "LOCAL MATCH", 16, Color("6bdde5"))

func _start_match() -> void:
	var entries: Array[Dictionary] = []
	for index in range(player_count.get_selected_id()):
		entries.append({"name": name_inputs[index].text.strip_edges(), "color": color_inputs[index].get_selected_id()})
	if not game.configure(entries):
		setup_error.text = "Enter every player's name and choose a different color for each."
		return
	setup_overlay.hide()
	_selected = -1
	_refresh()

func _build_dice_overlay() -> void:
	dice_overlay = _overlay("DiceCinematic")
	var box := _center_box(dice_overlay, 680)
	dice_caption = _label(box, "DICE REACTOR / ROLLING", 23, Color("6be8ec"))
	dice_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(640, 360)
	container.stretch = true
	box.add_child(container)
	dice_viewport = SubViewport.new()
	dice_viewport.name = "DiceViewport"
	dice_viewport.size = Vector2i(640, 360)
	dice_viewport.msaa_3d = Viewport.MSAA_4X
	dice_viewport.use_hdr_2d = true
	dice_viewport.own_world_3d = true
	dice_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	container.add_child(dice_viewport)
	dice_stage = DiceScene.instantiate()
	dice_viewport.add_child(dice_stage)
	dice_stage.sound_cue.connect(func(key: String):
		if key != "dice_impact": audio.play(key, int(game.players[game.current_player].color) if not game.players.is_empty() else -1))
	dice_stage.collision_cue.connect(func(strength: float): audio.play("dice_impact", int(game.players[game.current_player].color) if not game.players.is_empty() else -1, strength))
	dice_result = _label(box, "", 23)
	dice_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dice_stage.result_ready.connect(_dice_settled)
	dice_stage.animation_skipped.connect(_dice_animation_skipped)
	var skip_button := _button(box, tr("UI_SKIP_ANIMATION"), func(): dice_stage.skip())
	skip_button.name = "SkipDiceAnimation"
	dice_overlay.hide()

func _dice_animation_skipped() -> void:
	dice_overlay.hide()

func _dice_settled(values: Array[int]) -> void:
	var a := values[0]
	var b := values[1]
	dice_result.text = "%d  +  %d  =  %d%s" % [a,b,a+b,"  /  DOUBLES" if a == b else ""]
	if a == b: audio.play("doubles")

func _roll_clicked() -> void:
	if _busy or _briefing_open() or _sound_settings_open() or game.phase not in ["opening", "await_roll"]:
		return
	guide.complete("opening" if game.phase == "opening" else "jail" if _all_jailed() else "roll")
	_busy = true
	_clear_highlights()
	_refresh()
	var player: Dictionary = game.players[game.current_player]
	dice_caption.text = "%s / %s" % [player.name, "STARTING ORDER" if game.phase == "opening" else "DICE REACTOR"]
	dice_result.text = tr("UI_ROLLING")
	dice_overlay.show()
	# Numeric result appears when the cubes have settled, not before the throw.
	var values: Array[int] = await dice_stage.play(board.player_colors[int(player.color)], fast_dice.button_pressed, _rng.randi())
	var a := values[0]
	var b := values[1]
	dice_overlay.hide()
	var previous_name := str(player.name)
	var was_opening := game.phase == "opening"
	game.roll(a, b)
	_add_log("%s rolled %d + %d%s" % [previous_name, a, b, " (opening)" if was_opening else ""])
	_busy = false
	_refresh()
	if _selected >= 0:
		_focus_selected()

func _on_game_changed() -> void:
	var opening_finished := _last_game_phase == "opening" and game.phase == "await_roll"
	_last_game_phase = game.phase
	if _view_player != game.current_player:
		_selected = -1
		_view_player = game.current_player
		camera.overview()
		if game.phase != "opening": audio.play("turn")
	if _selected >= 0 and game.pawns[game.current_player][_selected] == Rules.FINISHED:
		_selected = -1
	_refresh()
	if game.phase == "bonus": _react("bonus", int(game.players[game.current_player].color))
	if opening_finished and _host_faction < 0:
		var first: Dictionary = game.players[game.current_player]
		_host_faction = local_faction_id if local_faction_id >= 0 else int(first.color)
		_host_player_name = str(first.name)
		_opening_player_name = str(first.name)
		_host_opens_match = _host_faction == int(first.color)
		for player in game.players:
			if local_faction_id >= 0 and int(player.color) == local_faction_id:
				_host_player_name = str(player.name)
		_show_faction_contact()
		faction_briefing.present(_host_faction, _host_player_name, _opening_player_name, _host_opens_match)
		_refresh()

func _refresh() -> void:
	if game.phase == "lobby":
		return
	var player: Dictionary = game.players[game.current_player]
	var color: Color = board.player_colors[int(player.color)]
	turn_title.text = "%s%s" % [player.name, " · command roll" if game.phase == "opening" else ""]
	turn_title.add_theme_color_override("font_color", color)
	_update_instruction()
	roll_button.disabled = _busy or _briefing_open() or game.phase not in ["opening", "await_roll"]
	roll_button.text = tr("UI_ROLL_FIRST") if game.phase == "opening" else (tr("UI_ROLL_DOUBLES") if _all_jailed() else tr("UI_ROLL_DICE"))
	lobby_button.disabled = _busy or _briefing_open()
	for index in range(2):
		dice_labels[index].display(int(game.last_roll[index]) if game.last_roll.size() == 2 else 0, game.dice_remaining[index] or game.phase == "opening", color)
		dice_labels[index].add_theme_color_override("font_color", color if game.dice_remaining[index] or game.phase == "opening" else Color("657f91"))
	_clear_children(roster)
	for index in range(game.players.size()):
		var entry: Dictionary = game.players[index]
		var profile := Lore.profile(int(entry.color))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		roster.add_child(row)
		var turn_marker := ColorRect.new()
		turn_marker.custom_minimum_size = Vector2(3, 38)
		turn_marker.color = profile.color if index == game.current_player else Color.TRANSPARENT
		turn_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(turn_marker)
		var portrait := preload("res://AnimatedPortrait.gd").new()
		portrait.set_character(int(entry.color))
		portrait.custom_minimum_size = Vector2(38, 38)
		row.add_child(portrait)
		var emblem := TextureRect.new()
		emblem.texture = load(str(profile.emblem))
		emblem.custom_minimum_size = Vector2(22, 22)
		emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		emblem.tooltip_text = str(profile.name)
		row.add_child(emblem)
		var details := _vbox(row)
		details.add_theme_constant_override("separation", 0)
		var name_label := _label(details, str(entry.name), 15, profile.color)
		name_label.clip_text = true
		name_label.custom_minimum_size.x = 170
		name_label.tooltip_text = str(entry.name)
		_extraction_progress(details, game.finished_count(index), profile.color)
	_update_faction_message()
	_sync_pawns()
	_rebuild_choices()
	_rebuild_highlights()
	if game.phase == "game_over" and not _victory_shown:
		_show_victory()

func _kill_pawn_tweens() -> void:
	for tween in _pawn_tweens:
		if tween.is_valid():
			tween.kill()
	_pawn_tweens.clear()
	for team in range(4):
		for pawn in range(4):
			if is_instance_valid(board) and board.pawn_nodes.size() > team and board.pawn_nodes[team].size() > pawn:
				var node = board.pawn_nodes[team][pawn]
				if node and node.has_method("kill_movement"):
					node.kill_movement()

func _sync_pawns() -> void:
	_kill_pawn_tweens()
	for team in range(4):
		var owner_index := -1
		for player in range(game.players.size()):
			if game.players[player].color == team:
				owner_index = player
		for pawn in range(4):
			var node: Node3D = board.pawn_nodes[team][pawn]
			if owner_index < 0 or game.pawns[owner_index][pawn] == Rules.FINISHED:
				node.hide()
				continue
			node.show()
			var target := _pawn_position(owner_index, pawn)
			node.scale = Vector3.ONE * float(board.tile_spacing) * (1.0 if game.pawns[owner_index][pawn] == -1 else 0.73)
			if node.position.distance_to(target) > 0.01:
				if node.has_method("move_smooth_to"):
					node.move_smooth_to(target, 0.3)
				else:
					var tween := create_tween()
					tween.tween_property(node, "position", target, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
					_pawn_tweens.append(tween)

func _position_for_progress(player: int, pawn: int, progress: int) -> Vector3:
	var team := int(game.players[player].color)
	if progress < 0:
		return board.jail_positions[team][pawn]
	if progress == Rules.FINISHED:
		return Vector3(0, 0.6, 0)
	if progress > Rules.TRACK_STEPS:
		return board.home_path_positions[team][progress - Rules.TRACK_STEPS - 1] + Vector3(0, 0.14, 0)
	return board.main_path_positions[game.circuit_index(player, progress)] + Vector3(0, 0.14, 0)

func _pawn_position(player: int, pawn: int) -> Vector3:
	var progress := int(game.pawns[player][pawn])
	var pos := _position_for_progress(player, pawn, progress)
	if progress < 0 or progress == Rules.FINISHED:
		return pos
	var occupants: Array[Vector2i] = []
	var target_cell := game.circuit_index(player, progress)
	for other in range(game.players.size()):
		for piece in range(4):
			var other_progress := int(game.pawns[other][piece])
			if (target_cell >= 0 and game.circuit_index(other, other_progress) == target_cell) or (target_cell < 0 and other == player and other_progress == progress):
				occupants.append(Vector2i(other, piece))
	if occupants.size() > 1:
		var slot := occupants.find(Vector2i(player, pawn))
		var angle := TAU * float(slot) / occupants.size()
		pos += Vector3(cos(angle), 0.04 * slot, sin(angle)) * 0.24 * float(board.tile_spacing)
	return pos

func _unhandled_input(event: InputEvent) -> void:
	if is_board_input_locked() or game.phase not in ["await_roll", "move", "bonus"]:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse := event.position as Vector2
		if _selected >= 0 and game.phase == "move":
			var closest_move: Dictionary = {}
			var distance := 24.0
			for move in game.legal_moves():
				if move.pawn != _selected:
					continue
				var destination := board.to_global(_position_for_progress(game.current_player, _selected, move.target))
				var screen := camera.unproject_position(destination)
				if screen.distance_to(mouse) < distance:
					distance = screen.distance_to(mouse)
					closest_move = move
			if not closest_move.is_empty():
				_execute_move(closest_move)
				return
		var selected := -1
		var nearest := 28.0
		var team := int(game.players[game.current_player].color)
		for pawn in range(4):
			if game.pawns[game.current_player][pawn] == Rules.FINISHED:
				continue
			var node: Node3D = board.pawn_nodes[team][pawn]
			var screen := camera.unproject_position(node.global_position + Vector3(0, 0.4, 0))
			if screen.distance_to(mouse) < nearest:
				nearest = screen.distance_to(mouse)
				selected = pawn
		if selected >= 0:
			_select_pawn(selected)

func _movable_pawns() -> Array[int]:
	var result: Array[int] = []
	if game.phase == "bonus":
		for pawn in range(4):
			if game.pawns[game.current_player][pawn] != Rules.FINISHED:
				result.append(pawn)
	elif game.phase == "move":
		for move in game.legal_moves():
			if move.pawn not in result:
				result.append(move.pawn)
	return result

func _all_jailed() -> bool:
	if game.players.is_empty():
		return true
	for progress in game.pawns[game.current_player]:
		if progress >= 0 and progress != Rules.FINISHED:
			return false
	return true

func _update_instruction() -> void:
	phase_badge.text = {"opening": "COMMAND ROLL", "await_roll": "POWER THE GATE", "move": "CHOOSE LANDING" if _selected >= 0 else "CHOOSE CREW", "bonus": "EXPRESS EXTRACTION", "game_over": "CREW RECOVERED"}.get(game.phase, "")
	status.text = ""
	if _busy:
		phase_badge.text = "ROLLING DICE" if dice_stage.playing else "IN TRANSIT"
	elif game.phase == "await_roll" and _all_jailed():
		status.text = "Pair required · %d tries" % game.jail_attempts
	elif game.phase == "move" and _selected >= 0:
		if _selected not in _movable_pawns():
			status.text = "Pair required" if game.pawns[game.current_player][_selected] < 0 else "Exact roll required"
		else:
			status.text = "Crew %d" % (_selected + 1)
	status.visible = not status.text.is_empty()

func _rebuild_choices() -> void:
	_clear_children(choices)
	_clear_children(pawn_buttons)
	focus_button.disabled = _selected < 0 or _busy or _briefing_open()
	if _busy or _briefing_open():
		return
	var movable := _movable_pawns()
	for pawn in range(4):
		var progress := int(game.pawns[game.current_player][pawn])
		var state := "GOAL" if progress == Rules.FINISHED else ("JAIL" if progress < 0 else "READY" if pawn in movable else "ON BOARD")
		var button := _button(pawn_buttons, "Crew %d · %s" % [pawn + 1, state], _select_pawn.bind(pawn))
		button.tooltip_text = str(board.pawn_nodes[int(game.players[game.current_player].color)][pawn].get_meta("callsign"))
		button.name = "Pawn%d" % (pawn + 1)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = progress == Rules.FINISHED or game.phase == "game_over"
		if pawn == _selected:
			button.add_theme_stylebox_override("normal", _style(Color("35402b"), Color("fff3a6")))
		elif pawn in movable:
			button.add_theme_stylebox_override("normal", _style(Color("16433c"), Color("9effb1")))
	if _selected < 0:
		return
	for move in game.legal_moves():
		if move.pawn != _selected:
			continue
		var destination := _destination_name(move.target)
		var text := "Release to " + destination if move.kind == "release" else "%s: +%d to %s" % ["Both" if move.mask == 3 else "D%d" % (1 if move.mask == 1 else 2), move.steps, destination]
		var button := _button(choices, text, _execute_move.bind(move))
		button.add_theme_color_override("font_color", Color("b9ff75"))

func _destination_name(progress: int) -> String:
	if progress == Rules.GOAL:
		return "GOAL"
	if progress > Rules.TRACK_STEPS:
		return "Home %d" % (progress - Rules.TRACK_STEPS)
	return "Cell %d" % (game.circuit_index(game.current_player, progress) + 1)

func _select_pawn(pawn: int) -> void:
	if _busy or _briefing_open() or _sound_settings_open() or pawn < 0 or pawn > 3 or game.phase not in ["await_roll", "move", "bonus", "opening"]:
		return
	if game.pawns[game.current_player][pawn] == Rules.FINISHED:
		return
	if game.phase == "bonus":
		_execute_bonus(pawn)
		return
	audio.play("select")
	board.pawn_nodes[int(game.players[game.current_player].color)][pawn].acknowledge()
	_selected = pawn
	if pawn in _movable_pawns():
		guide.complete("select")
	_update_instruction()
	_rebuild_choices()
	_rebuild_highlights()
	_focus_selected()

func _focus_selected() -> void:
	if _selected < 0 or game.phase in ["lobby", "game_over"]:
		return
	var points: Array[Vector3] = [board.to_global(_pawn_position(game.current_player, _selected))]
	for move in game.legal_moves():
		if move.pawn == _selected:
			points.append(board.to_global(_position_for_progress(game.current_player, _selected, move.target)))
	camera.focus_points(points)

func _pawn_glow(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(color, 0.3)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.8
	return material

func _clear_highlights() -> void:
	_clear_children(highlights)
	if is_instance_valid(move_overlay):
		move_overlay.set_pins([])
		move_overlay.route.clear()
	for team in range(4):
		for pawn in range(4):
			for child in board.pawn_nodes[team][pawn].find_children("*", "MeshInstance3D", true, false):
				if child is MeshInstance3D:
					child.material_overlay = null

func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _rebuild_highlights() -> void:
	_clear_highlights()
	if _busy or _briefing_open() or game.phase in ["lobby", "game_over"]:
		return
	var team := int(game.players[game.current_player].color)
	var movable := _movable_pawns()
	var pins: Array[Dictionary] = []
	for pawn in range(4):
		if game.pawns[game.current_player][pawn] == Rules.FINISHED:
			continue
		var can_move := pawn in movable
		var selected := pawn == _selected
		var color := Color("fff3a6") if selected else Color("79ffff") if can_move else Color("7a93ab")
		var pos := _pawn_position(game.current_player, pawn)
		pins.append({"id": "pawn_%d" % pawn, "kind": "pawn", "text": str(pawn + 1), "color": color, "world": board.to_global(pos + Vector3(0, 0.65, 0)), "tooltip": "%s · Crew %d · %s" % [board.pawn_nodes[team][pawn].get_meta("callsign"), pawn + 1, "ready to move" if can_move else "click to inspect"]})
		if can_move or selected:
			_marker(pos, color, 0.46)
			for child in board.pawn_nodes[team][pawn].find_children("*", "MeshInstance3D", true, false):
				if child is MeshInstance3D:
					child.material_overlay = _selected_glow if selected else _glow_material
	var max_steps := 0
	if _selected >= 0 and game.phase == "move":
		var moves := game.legal_moves()
		for index in range(moves.size()):
			var move: Dictionary = moves[index]
			if move.pawn != _selected:
				continue
			var pos := _position_for_progress(game.current_player, _selected, move.target)
			_marker(pos, Color("b9ff75"), 0.47)
			pins.append({"id": "move_%d" % index, "kind": "move", "text": "LAUNCH" if move.kind == "release" else "+%d" % move.steps, "color": Color("b9ff75"), "world": board.to_global(pos), "tooltip": _destination_name(move.target)})
			max_steps = maxi(max_steps, move.steps)
		if max_steps > 0:
			var start := int(game.pawns[game.current_player][_selected])
			for progress in range(start, start + max_steps + 1):
				move_overlay.route.append(board.to_global(_position_for_progress(game.current_player, _selected, progress)))
	move_overlay.set_pins(pins)

func _marker(pos: Vector3, color: Color, radius: float) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = (radius - 0.055) * float(board.tile_spacing)
	ring.outer_radius = (radius + 0.055) * float(board.tile_spacing)
	var mesh := MeshInstance3D.new()
	mesh.mesh = ring
	mesh.position = pos + Vector3(0, 0.08, 0)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.25
	mesh.material_override = material
	highlights.add_child(mesh)

func _pin_picked(id: String) -> void:
	if _busy or _briefing_open() or _sound_settings_open():
		return
	if id.begins_with("pawn_"):
		_select_pawn(int(id.trim_prefix("pawn_")))
	elif id.begins_with("move_"):
		var index := int(id.trim_prefix("move_"))
		var moves := game.legal_moves()
		if index >= 0 and index < moves.size() and moves[index].pawn == _selected:
			_execute_move(moves[index])

func _update_cell_info() -> void:
	if not is_instance_valid(cell_info) or setup_overlay.visible or dice_overlay.visible:
		return
	var mouse := get_viewport().get_mouse_position()
	if not get_play_rect().has_point(mouse):
		return
	var point: Variant = camera.ground_at(mouse)
	if point is not Vector3:
		return
	var local: Vector3 = board.to_local(point)
	for index in range(board.main_path_positions.size()):
		if Vector2(local.x, local.z).distance_to(Vector2(board.main_path_positions[index].x, board.main_path_positions[index].z)) < float(board.tile_spacing) * 0.48:
			cell_info.text = "CELL %d%s" % [index + 1, " · SALIDA / PROTECTED" if index in board.launch_indices else " · SEGURO / PROTECTED" if index in board.safe_indices else " · CAPTURES ALLOWED"]
			return
	cell_info.text = ""

func _execute_move(move: Dictionary) -> void:
	if _busy or _briefing_open() or _sound_settings_open() or game.phase != "move":
		return
	var valid := false
	for legal in game.legal_moves():
		if legal == move:
			valid = true
	if not valid:
		return
	_busy = true
	_clear_highlights()
	_refresh()
	_kill_pawn_tweens()
	var player := game.current_player
	var team := int(game.players[player].color)
	var node: Node3D = board.pawn_nodes[team][int(move.pawn)]
	var color: Color = board.player_colors[team]
	audio.play("launch" if move.kind == "release" else "travel", team)
	effects.follow(node, color)
	effects.burst(node.position, color)
	if node.has_method("move_release_to"):
		if move.kind == "release":
			var destination := _position_for_progress(player, move.pawn, 0)
			await node.move_release_to(destination)
		else:
			var start := int(game.pawns[player][int(move.pawn)])
			var waypoints: Array[Vector3] = []
			for progress in range(start + 1, int(move.target) + 1):
				waypoints.append(_position_for_progress(player, move.pawn, progress))
			var destination := _position_for_progress(player, move.pawn, move.target)
			await node.move_steps_to(waypoints, destination)
	else:
		node.moving = true
		if move.kind == "release": node.play_launch()
		var tween := create_tween()
		if move.kind == "release":
			var destination := _position_for_progress(player, move.pawn, 0)
			node.face_destination(destination)
			tween.tween_property(node, "position", (node.position + destination) * 0.5 + Vector3(0, 2.5, 0), 0.22).set_trans(Tween.TRANS_SINE)
			tween.tween_property(node, "position", destination, 0.22).set_trans(Tween.TRANS_SINE)
		else:
			var start := int(game.pawns[player][int(move.pawn)])
			for progress in range(start + 1, int(move.target) + 1):
				var destination := _position_for_progress(player, move.pawn, progress)
				tween.tween_callback(node.face_destination.bind(destination))
				tween.tween_property(node, "position", destination, node.step_duration())
			tween.tween_property(node, "position", _position_for_progress(player, move.pawn, move.target), .12).set_trans(Tween.TRANS_SINE)
		await tween.finished
		node.moving = false
		node.play_arrival()
	audio.play("finish" if int(move.target) == Rules.FINISHED else "land")
	effects.stop(node)
	effects.burst(node.position, color)
	guide.complete("release" if move.kind == "release" else "move")
	if move.kind == "release": _react("launch", team)
	var name_tag := str(game.players[player].name)
	# Snapshot the destination before the rules recall captured rivals.
	var impact := node.position
	game.play(move.pawn, move.mask)
	if int(move.target) == Rules.FINISHED:
		_guide_notice("finish")
		_react("finish", team)
	elif int(move.target) > Rules.TRACK_STEPS:
		_guide_notice("home")
	elif move.kind != "release" and board.is_protected_cell(game.circuit_index(player, int(move.target))):
		audio.play("shield")
		_guide_notice("safe")
		_react("shield", team)
	_add_log("%s · pawn %d %s" % [name_tag, int(move.pawn) + 1, "released" if move.kind == "release" else "+%d" % move.steps])
	if not game.captured.is_empty():
		_add_log("Captured %d rival pawn(s)" % game.captured.size())
		audio.play("capture")
		_guide_notice("capture")
		_react("capture", team)
		effects.burst(impact + Vector3(0, .4, 0), Color("ffb4a8"))
	_busy = false
	_refresh()

func _execute_bonus(pawn: int) -> void:
	if _busy or _briefing_open() or _sound_settings_open() or game.phase != "bonus":
		return
	_busy = true
	_refresh()
	_kill_pawn_tweens()
	var team := int(game.players[game.current_player].color)
	var node: Node3D = board.pawn_nodes[team][pawn]
	audio.play("launch", team)
	if node.has_method("move_bonus_to"):
		await node.move_bonus_to(Vector3(0, 0.6, 0))
	else:
		node.play_launch()
		var tween := create_tween()
		tween.tween_property(node, "position", Vector3(0, 3, 0), 0.6).set_trans(Tween.TRANS_SINE)
		tween.tween_property(node, "position", Vector3(0, 0.6, 0), 0.3)
		await tween.finished
	effects.burst(Vector3(0, .5, 0), board.player_colors[team])
	audio.play("finish")
	guide.complete("bonus")
	_react("finish", team)
	game.claim_bonus(pawn)
	_add_log("Three doubles · pawn %d promoted to goal" % (pawn + 1))
	_busy = false
	_refresh()

func _add_log(text: String) -> void:
	history_label.get_parent().visible = _details_open
	_log.append(text)
	while _log.size() > 3:
		_log.pop_front()
	history_label.text = "\n".join(_log)

func _show_victory() -> void:
	_victory_shown = true
	audio.play("victory")
	victory_overlay = _overlay("Victory")
	var box := _center_box(victory_overlay, 600)
	var team := int(game.players[game.winner].color)
	var portrait := preload("res://AnimatedPortrait.gd").new()
	portrait.set_character(team, "celebrate")
	portrait.custom_minimum_size = Vector2(300, 250)
	box.add_child(portrait)
	effects.burst(Vector3(0, .6, 0), board.player_colors[team])
	_label(box, "THE WAY HOME", 29, board.player_colors[team])
	_label(box, "%s wins!" % game.players[game.winner].name, 26)
	_label(box, "All four crew have crossed the Loom. Their journey lives on.", 17)
	_button(box, "Play again · return to lobby", show_lobby)

func _briefing_open() -> bool:
	return is_instance_valid(faction_briefing) and faction_briefing.visible

func is_board_input_locked() -> bool:
	return _busy or _briefing_open() or (is_instance_valid(sound_overlay) and sound_overlay.visible) or (is_instance_valid(setup_overlay) and setup_overlay.visible) or (is_instance_valid(dice_overlay) and dice_overlay.visible)

func _preview_lobby_faction(seat: int) -> void:
	if not is_instance_valid(lobby_portrait):
		return
	var faction := Lore.profile(color_inputs[seat].get_selected_id())
	lobby_portrait.set_character(int(faction.id), "calm")
	lobby_faction_name.text = faction.name
	lobby_faction_name.add_theme_color_override("font_color", faction.color)
	lobby_character.text = "%s %s" % [str(faction.title).capitalize(), faction.character]
	lobby_description.text = faction.description

func _show_faction_contact() -> void:
	var faction := Lore.profile(_host_faction)
	faction_portrait.set_character(_host_faction, "calm")
	faction_heading.text = str(faction.name).to_upper()
	faction_heading.add_theme_color_override("font_color", faction.color)
	faction_speaker.text = "%s %s" % [str(faction.title).capitalize(), faction.character]
	faction_card.show()

func replay_briefing() -> void:
	if _busy or _host_faction < 0 or game.phase in ["lobby", "opening", "game_over"] or _briefing_open():
		return
	faction_briefing.present(_host_faction, _host_player_name, _opening_player_name, _host_opens_match)
	_refresh()

func _on_briefing_closed() -> void:
	_refresh()
	if _selected >= 0:
		_focus_selected()

func _update_faction_message() -> void:
	_refresh_guidance()

func _build_backdrop() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -10
	layer.name = "OrbitalPainting"
	add_child(layer)
	var art := TextureRect.new()
	art.texture = preload("res://assets/loom-background.png")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var environment: Environment = get_node("WorldEnvironment").environment
	environment.background_mode = Environment.BG_CANVAS
	environment.background_canvas_max_layer = -1

func _refresh_guidance() -> void:
	if is_instance_valid(guide_beacon):
		guide_beacon.target = null
	if is_board_input_locked() or game.phase == "game_over" or game.players.is_empty():
		faction_card.hide()
		return
	var key := ""
	if not _guide_event.is_empty() and _clock < _guide_event_until and not guide.seen.has(_guide_event):
		key = _guide_event
	elif game.phase == "opening":
		key = "opening"
	elif game.phase == "await_roll":
		key = "jail" if _all_jailed() else "roll"
	elif game.phase == "bonus":
		key = "bonus"
	elif game.phase == "move":
		var has_release := false
		for move in game.legal_moves():
			has_release = has_release or move.kind == "release"
		key = "release" if has_release else "select" if _selected < 0 else "move"
	var text := guide.cue(key)
	if text.is_empty() and _clock < _reaction_until and not _reaction_text.is_empty():
		key = "reaction"
		text = _reaction_text
	faction_card.visible = not text.is_empty()
	if text.is_empty():
		return
	var team := _reaction_team if key == "reaction" else (_host_faction if _host_faction >= 0 else int(game.players[game.current_player].color))
	var faction := Lore.profile(team)
	faction_portrait.set_character(team, "resolve" if key in ["release", "bonus", "capture", "finish", "home", "reaction"] else "calm")
	faction_heading.text = "FIELD COMMS"
	faction_heading.add_theme_color_override("font_color", faction.color)
	faction_speaker.text = faction.character
	faction_speaker.add_theme_font_size_override("font_size", 15)
	var message_id := "%d:%s:%s" % [team, key, text]
	if _comms_id != message_id:
		_comms_id = message_id
		comms_reveal.begin(faction_message, text)
		audio.play("comms", team)
	if key in ["opening", "jail", "roll"]:
		guide_beacon.target = roll_button
	elif key in ["select", "move", "release", "bonus"]:
		var destination: Control
		var crew: Control
		for pin in move_overlay.pins:
			var control := move_overlay.get_node_or_null(str(pin.id)) as Control
			if pin.kind == "move" and not is_instance_valid(destination):
				destination = control
			if pin.kind == "pawn" and int(str(pin.id).trim_prefix("pawn_")) in _movable_pawns() and not is_instance_valid(crew):
				crew = control
		guide_beacon.target = destination if is_instance_valid(destination) else crew
	guide_dismiss.text = "Close comms" if key == "reaction" else "Understood" if key in ["safe", "capture", "home", "finish", "camera"] else "Hide guidance"

func _guide_notice(key: String) -> void:
	if not guide.seen.has(key):
		_guide_event = key
		_guide_event_until = _clock + 18

func _dismiss_guidance() -> void:
	if guide.active.is_empty():
		_reaction_until = 0
		_reaction_text = ""
	elif guide.active in ["safe", "capture", "home", "finish", "camera"]:
		guide.complete(guide.active)
	else:
		guide.enabled = false
		guide.save()
	_refresh_guidance()

func _menu_action(id: int) -> void:
	match id:
		0: replay_briefing()
		1:
			guide.reset()
			_refresh_guidance()
		2:
			_details_open = not _details_open
			settings.get_popup().set_item_checked(settings.get_popup().get_item_index(id), _details_open)
			pawn_buttons.visible = _details_open
			choices.visible = _details_open
			history_label.get_parent().visible = _details_open
		3:
			board.set_coordinates_visible(not board.coordinates_visible)
			settings.get_popup().set_item_checked(settings.get_popup().get_item_index(id), board.coordinates_visible)
		4:
			guide.enabled = true
			guide.seen.erase("camera")
			_guide_notice("camera")
		5:
			audio.set_muted(audio.enabled)
			settings.get_popup().set_item_checked(settings.get_popup().get_item_index(id), not audio.enabled)
		6:
			_open_sound_settings()

func _build_sound_settings() -> void:
	sound_overlay = _overlay("SoundSettings")
	var box := _center_box(sound_overlay, 520)
	_label(box, "SOUND & PORTRAITS", 24, Color("6be0ec"))
	for channel in ["effects", "dialogue"]:
		_label(box, "Game effects" if channel == "effects" else "Dialogue chimes & text ticks", 17)
		var slider := HSlider.new()
		slider.name = "EffectsVolume" if channel == "effects" else "DialogueVolume"
		slider.min_value = 0
		slider.max_value = 1
		slider.step = .01
		slider.custom_minimum_size = Vector2(450, 32)
		slider.value = audio.effects_volume if channel == "effects" else audio.dialogue_volume
		box.add_child(slider)
		slider.value_changed.connect(func(value: float): audio.set_volume(channel, value))
	var mute := CheckBox.new()
	mute.name = "MuteAudio"
	mute.text = "Mute all sounds"
	mute.button_pressed = not audio.enabled
	box.add_child(mute)
	mute.toggled.connect(func(value: bool):
		audio.set_muted(value)
		settings.get_popup().set_item_checked(settings.get_popup().get_item_index(5), value)
	)
	var motion := CheckBox.new()
	motion.name = "PortraitMotion"
	motion.text = "Animate dialogue portraits"
	motion.button_pressed = audio.portrait_motion
	box.add_child(motion)
	motion.toggled.connect(func(value: bool):
		audio.portrait_motion = value
		audio.save_preferences()
	)
	_button(box, "Preview effects", func(): audio.play("shield"))
	_button(box, "Done", func(): sound_overlay.hide())
	sound_overlay.hide()

func _open_sound_settings() -> void:
	if _busy or _briefing_open() or setup_overlay.visible:
		return
	var mute := sound_overlay.find_child("MuteAudio", true, false) as CheckBox
	mute.set_pressed_no_signal(not audio.enabled)
	sound_overlay.show()
	sound_overlay.find_child("EffectsVolume", true, false).grab_focus()

func _sound_settings_open() -> bool:
	return is_instance_valid(sound_overlay) and sound_overlay.visible

func _unhandled_key_input(event: InputEvent) -> void:
	if _sound_settings_open() and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		sound_overlay.hide()
		get_viewport().set_input_as_handled()

func _react(event: String, team: int) -> void:
	_comms_id = ""
	_reaction_text = Lore.reaction(team, event)
	_reaction_until = _clock + 5
	_reaction_team = team
