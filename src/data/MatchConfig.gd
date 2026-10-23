extends Node

## Gestiona la transferencia de datos entre el Menú Principal (LocalSetup / MultiplayerMenu)
## y la escena de juego 3D (MainGame.tscn / GameController.gd).
## Registrado como singleton Autoload en project.godot (MatchConfig).

var pending_players: Array[Dictionary] = []
var pending_fast_dice: bool = false

## Registra la configuración de jugadores para la partida local:
## players debe contener diccionarios con claves 'name' y 'faction_id' o 'color'.
func set_local_match(players: Array[Dictionary], fast_dice: bool = false) -> void:
	pending_players.clear()
	for p in players:
		var color_val: int = int(p.get("faction_id", p.get("color", 0)))
		var name_val: String = str(p.get("name", "Jugador")).strip_edges()
		pending_players.append({
			"name": name_val,
			"color": color_val
		})
	pending_fast_dice = fast_dice
	print("[MatchConfig] Configuración de partida guardada para %d jugadores: %s" % [pending_players.size(), str(pending_players)])

func has_pending_match() -> bool:
	return pending_players.size() >= 2

func consume_match_players() -> Array[Dictionary]:
	var result := pending_players.duplicate(true)
	pending_players.clear()
	return result

func clear() -> void:
	pending_players.clear()
	pending_fast_dice = false
