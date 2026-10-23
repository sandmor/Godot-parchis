extends Control
class_name LocalSetup

signal back_pressed
signal start_game(players_data: Array[Dictionary])

@onready var player_count_option: OptionButton = %PlayerCountOption
@onready var slots_container: VBoxContainer = %SlotsContainer
@onready var btn_back: Button = %BtnBack
@onready var btn_start: Button = %BtnStart
@onready var status_label: Label = %StatusLabel

const PlayerSlotScene := preload("res://src/UI/menus/PlayerSlot.tscn")
const DEFAULT_COLORS: Array[int] = [0, 2, 1, 3]

var slot_instances: Array[PlayerSlot] = []

func _ready() -> void:
	_setup_count_options()
	_create_slots()
	player_count_option.item_selected.connect(_on_count_changed)
	btn_back.pressed.connect(_on_back_pressed)
	btn_start.pressed.connect(_on_start_pressed)
	_update_slot_visibility()

func _setup_count_options() -> void:
	player_count_option.clear()
	player_count_option.add_item("2 Jugadores", 2)
	player_count_option.add_item("3 Jugadores", 3)
	player_count_option.add_item("4 Jugadores", 4)
	player_count_option.select(2) # Default 4 players

func _create_slots() -> void:
	# Clear existing children if any
	for child in slots_container.get_children():
		child.queue_free()
	slot_instances.clear()
	
	for i in range(4):
		var slot: PlayerSlot = PlayerSlotScene.instantiate()
		slots_container.add_child(slot)
		slot.configure(i, "Jugador %d" % (i + 1), DEFAULT_COLORS[i])
		slot.data_changed.connect(_on_slot_data_changed)
		slot_instances.append(slot)

func _on_count_changed(_index: int) -> void:
	_update_slot_visibility()

func _update_slot_visibility() -> void:
	var count: int = get_selected_player_count()
	for i in range(slot_instances.size()):
		slot_instances[i].visible = (i < count)
	status_label.text = ""

func get_selected_player_count() -> int:
	return player_count_option.get_selected_id()

func _on_slot_data_changed() -> void:
	status_label.text = ""

func _on_back_pressed() -> void:
	print("[LocalSetup] Volviendo al Menú Principal...")
	back_pressed.emit()

func _on_start_pressed() -> void:
	var count := get_selected_player_count()
	var players: Array[Dictionary] = []
	var chosen_colors: Array[int] = []
	
	for i in range(count):
		var data: Dictionary = slot_instances[i].get_player_data()
		if data.name.is_empty():
			status_label.text = "⚠️ El jugador %d debe tener un nombre." % (i + 1)
			return
		if chosen_colors.has(data.faction_id):
			status_label.text = "⚠️ Cada jugador debe tener una facción/color diferente."
			return
		chosen_colors.append(data.faction_id)
		players.append(data)
	
	status_label.text = ""
	
	# Simular carga de partida en consola
	print("==================================================")
	print("[LocalSetup] 🎲 INICIANDO PARTIDA LOCAL...")
	print("  -> Jugadores activos: %d" % count)
	for p in players:
		print("     - Puesto %02d: '%s' | Facción ID: %d" % [p.seat + 1, p.name, p.faction_id])
	print("  -> Generando tablero 3D y reglas de Parqués...")
	print("  -> ¡Partida lista para jugar!")
	print("==================================================")
	
	start_game.emit(players)

