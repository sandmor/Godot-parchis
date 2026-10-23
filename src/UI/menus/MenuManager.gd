extends Control
class_name MenuManager

## Coordinador principal del flujo de navegación entre menús.
## Administra las pantallas (MainMenu, LocalSetup, MultiplayerMenu, OptionsMenu)
## mediante un stack de navegación limpio e instantáneo.

@onready var main_menu: MainMenu = %MainMenu
@onready var local_setup: LocalSetup = %LocalSetup
@onready var multiplayer_menu: MultiplayerMenu = %MultiplayerMenu
@onready var options_menu: OptionsMenu = %OptionsMenu

var screen_stack: Array[Control] = []

func _ready() -> void:
	_connect_signals()
	# Inicializar mostrando únicamente el Menú Principal
	_hide_all_screens()
	push_screen(main_menu)

func _hide_all_screens() -> void:
	main_menu.visible = false
	local_setup.visible = false
	multiplayer_menu.visible = false
	options_menu.visible = false

func push_screen(new_screen: Control) -> void:
	if screen_stack.size() > 0:
		screen_stack.back().visible = false
	
	screen_stack.append(new_screen)
	new_screen.visible = true

func pop_screen() -> void:
	if screen_stack.size() <= 1:
		return
	
	var current: Control = screen_stack.pop_back()
	current.visible = false
	
	var previous: Control = screen_stack.back()
	previous.visible = true

func _connect_signals() -> void:
	# MainMenu signals
	main_menu.local_selected.connect(func() -> void: push_screen(local_setup))
	main_menu.multiplayer_selected.connect(func() -> void:
		push_screen(multiplayer_menu)
		multiplayer_menu.show_view("mode")
	)
	main_menu.options_selected.connect(func() -> void: push_screen(options_menu))
	main_menu.tutorial_selected.connect(_on_tutorial_selected)
	main_menu.quit_selected.connect(_on_quit_selected)
	
	# LocalSetup signals
	local_setup.back_pressed.connect(func() -> void: pop_screen())
	local_setup.start_game.connect(_on_start_local_game)
	
	# MultiplayerMenu signals
	multiplayer_menu.back_to_main_requested.connect(func() -> void: pop_screen())
	multiplayer_menu.host_started.connect(_on_host_started)
	multiplayer_menu.join_requested.connect(_on_join_requested)
	
	# OptionsMenu signals
	options_menu.back_pressed.connect(func() -> void: pop_screen())

func _on_tutorial_selected() -> void:
	print("[MenuManager] Tutorial de Parqués seleccionado.")
	print("  -> 1. Sacar fichas con pares en los dados.")
	print("  -> 2. Avanzar por las casillas del circuito respetando seguros y salidas.")
	print("  -> 3. Capturar fichas enemigas para enviarlas a la cárcel y ganar turnos extra.")
	print("  -> 4. Coronar todas las 4 fichas en la meta para la victoria.")

func _on_quit_selected() -> void:
	print("[MenuManager] Cerrando aplicación...")

func _on_start_local_game(players_data: Array[Dictionary]) -> void:
	print("[MenuManager] 🎮 Transfiriendo configuración y cambiando escena a MainGame.tscn...")
	MatchConfig.set_local_match(players_data)
	if ResourceLoader.exists("res://MainGame.tscn"):
		var err := get_tree().change_scene_to_file("res://MainGame.tscn")
		if err != OK:
			printerr("[MenuManager] Error cambiando a escena MainGame.tscn: ", err)
	else:
		printerr("[MenuManager] No se encontró el archivo de escena MainGame.tscn")

func _on_host_started(config: Dictionary) -> void:
	print("[MenuManager] 🎮 Sala multijugador iniciada con éxito: %s" % str(config))

func _on_join_requested(code: String, player_data: Dictionary) -> void:
	print("[MenuManager] 🎮 Conexión a sala %s completada para %s" % [code, player_data.name])

