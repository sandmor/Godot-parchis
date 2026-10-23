extends HBoxContainer
class_name PlayerSlot

signal data_changed

@onready var number_label: Label = $NumberLabel
@onready var name_input: LineEdit = $NameInput
@onready var faction_option: OptionButton = $FactionOption
@onready var role_badge: Label = $RoleBadge

var slot_index: int = 0
var is_waiting_connection: bool = false

const FACTION_NAMES: Array[String] = [
	"Crimson Vanguard (Rojo)",
	"Viridian Accord (Verde)",
	"Azure Continuum (Azul)",
	"Solar Corsairs (Amarillo)"
]

const DEFAULT_COLORS: Array[int] = [0, 2, 1, 3]

func _ready() -> void:
	_populate_factions()
	name_input.text_changed.connect(func(_new_text: String) -> void: data_changed.emit())
	faction_option.item_selected.connect(func(_idx: int) -> void: data_changed.emit())

func _populate_factions() -> void:
	if faction_option.item_count > 0:
		return
	
	# Try to fetch from project Lore / FactionManager if present
	var lore_script := load("res://Factions.gd")
	for i in range(4):
		var faction_title := FACTION_NAMES[i]
		if lore_script and lore_script.has_method("profile"):
			var prof: Dictionary = lore_script.profile(i)
			if prof.has("name"):
				faction_title = "%s (%s)" % [prof.name, ["Rojo", "Verde", "Azul", "Amarillo"][i]]
		faction_option.add_item(faction_title, i)

func configure(index: int, default_name: String = "", default_faction: int = -1) -> void:
	slot_index = index
	is_waiting_connection = false
	_populate_factions()
	
	if number_label:
		number_label.text = "%02d" % (index + 1)
	
	if name_input:
		name_input.editable = true
		if default_name.is_empty():
			name_input.text = "Jugador %d" % (index + 1)
		else:
			name_input.text = default_name
		name_input.placeholder_text = "Nombre Jugador %d" % (index + 1)
	
	if faction_option:
		faction_option.disabled = false
		var chosen_color := default_faction if default_faction >= 0 else DEFAULT_COLORS[index % DEFAULT_COLORS.size()]
		faction_option.select(chosen_color)

func set_waiting_state() -> void:
	is_waiting_connection = true
	_populate_factions()
	if name_input:
		name_input.text = ""
		name_input.placeholder_text = "Esperando conexión..."
		name_input.editable = false
	if faction_option:
		faction_option.disabled = true
	set_role_tag("ESPERANDO", false)

func receive_remote_player(player_name: String, faction_id: int = -1) -> void:
	is_waiting_connection = false
	_populate_factions()
	if name_input:
		name_input.text = player_name
		name_input.editable = false # Host cannot rename remote players!
	if faction_option:
		if faction_id >= 0:
			faction_option.select(faction_id)
		faction_option.disabled = true # Remote player decides their faction
	set_role_tag("CONECTADO", true)
	data_changed.emit()

func set_role_tag(tag_text: String, is_accent: bool = false) -> void:
	if not role_badge:
		return
	if tag_text.is_empty():
		role_badge.visible = false
	else:
		role_badge.visible = true
		role_badge.text = tag_text
		if is_accent:
			role_badge.modulate = Color(0.41, 0.89, 0.92, 1.0)
		else:
			role_badge.modulate = Color(0.65, 0.65, 0.7, 0.8)

func get_player_data() -> Dictionary:
	return {
		"seat": slot_index,
		"name": name_input.text.strip_edges() if name_input else "Jugador %d" % (slot_index + 1),
		"faction_id": faction_option.get_selected_id() if faction_option else slot_index,
		"is_connected": not is_waiting_connection
	}

func set_editable(enabled: bool) -> void:
	name_input.editable = enabled
	faction_option.disabled = not enabled
