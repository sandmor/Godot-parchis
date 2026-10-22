class_name FactionManager
extends RefCounted

## Central manager for faction profiles and lore transmissions.
## Uses FactionData resources and Godot's TranslationServer.

const RESOURCE_PATHS := [
	"res://data/factions/crimson_vanguard.tres",
	"res://data/factions/viridian_accord.tres",
	"res://data/factions/azure_continuum.tres",
	"res://data/factions/solar_corsairs.tres"
]

static var _cached_factions: Array[FactionData] = []
static var _translations_loaded: bool = false

static func _static_init() -> void:
	_ensure_translations()

## Ensures translations from translations.csv are registered in TranslationServer.
static func _ensure_translations() -> void:
	if _translations_loaded:
		return
	_translations_loaded = true

	# If already registered by the engine, skip manual loading
	if TranslationServer.translate(&"FACTION_0_NAME") != &"FACTION_0_NAME":
		return

	var csv_path := "res://src/localization/translations.csv"
	if not FileAccess.file_exists(csv_path):
		return

	var file := FileAccess.open(csv_path, FileAccess.READ)
	if not file:
		return

	var header := file.get_csv_line()
	if header.size() < 2:
		return

	var translations: Dictionary = {}
	for col in range(1, header.size()):
		var loc := header[col].strip_edges()
		var trans := Translation.new()
		trans.locale = loc
		translations[col] = trans

	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() < 2:
			continue
		var key_str := line[0].strip_edges()
		if key_str.is_empty() or key_str.begins_with("#"):
			continue
		var key := StringName(key_str)
		for col in range(1, line.size()):
			if translations.has(col):
				var raw_text := line[col].replace("\\n", "\n")
				translations[col].add_message(key, raw_text)

	for col in translations:
		TranslationServer.add_translation(translations[col])

## Loads and caches all faction resources.
static func get_all_factions() -> Array[FactionData]:
	_ensure_translations()

	if not _cached_factions.is_empty():
		return _cached_factions

	for path in RESOURCE_PATHS:
		if ResourceLoader.exists(path):
			var res = load(path)
			if res is FactionData:
				_cached_factions.append(res)

	# Fallback if .tres files are not yet created or loaded
	if _cached_factions.is_empty():
		_cached_factions = _create_default_factions()

	return _cached_factions

## Returns a specific faction by ID (0..3).
static func get_faction(faction_id: int) -> FactionData:
	var list := get_all_factions()
	var idx := clampi(faction_id, 0, list.size() - 1)
	return list[idx]

## Formats briefing pages ready for UI consumption.
static func get_briefing(faction_id: int, player_name: String, opening_player: String = "", opens_match: bool = true) -> Array[Dictionary]:
	_ensure_translations()
	return get_faction(faction_id).get_briefing_pages(player_name, opening_player, opens_match)

## Returns the translated backstory / expedition text for a faction.
static func get_expedition(faction_id: int) -> String:
	_ensure_translations()
	return get_faction(faction_id).get_expedition()

## Returns a localized bark / dynamic reaction line for a game event.
static func get_reaction(faction_id: int, event: String) -> String:
	_ensure_translations()
	var valid_id := clampi(faction_id, 0, 3)
	var key := "FACTION_%d_REACT_%s" % [valid_id, event.to_upper()]
	return str(TranslationServer.translate(StringName(key)))

## Fallback builder to guarantee zero runtime failures even before .tres files exist.
static func _create_default_factions() -> Array[FactionData]:
	var list: Array[FactionData] = []

	var configs := [
		{
			"id": 0, "char": "Iria Voss", "color": Color("ff536c"),
			"portrait": "res://assets/factions/portraits/crimson-voss.tres",
			"emblem": "res://assets/factions/emblems/crimson-voss.svg"
		},
		{
			"id": 1, "char": "Sael", "color": Color("48e7a0"),
			"portrait": "res://assets/factions/portraits/viridian-sael.tres",
			"emblem": "res://assets/factions/emblems/viridian-sael.svg"
		},
		{
			"id": 2, "char": "LYRA-7", "color": Color("5c9dff"),
			"portrait": "res://assets/factions/portraits/azure-lyra.tres",
			"emblem": "res://assets/factions/emblems/azure-lyra.svg"
		},
		{
			"id": 3, "char": "Sol Reyes", "color": Color("ffcf58"),
			"portrait": "res://assets/factions/portraits/solar-reyes.tres",
			"emblem": "res://assets/factions/emblems/solar-reyes.svg"
		}
	]

	for cfg in configs:
		var f := FactionData.new()
		var fid: int = cfg.id
		f.id = fid
		f.name_key = "FACTION_%d_NAME" % fid
		f.short_name_key = "FACTION_%d_SHORT_NAME" % fid
		f.character = cfg.char
		f.title_key = "FACTION_%d_TITLE" % fid
		f.color = cfg.color
		f.motto_key = "FACTION_%d_MOTTO" % fid
		f.description_key = "FACTION_%d_DESC" % fid
		f.portrait = cfg.portrait
		f.emblem = cfg.emblem
		f.welcome_key = "FACTION_%d_WELCOME" % fid
		f.welcome_observer_key = "FACTION_%d_WELCOME_OBSERVER" % fid
		f.jail_key = "FACTION_%d_JAIL" % fid
		f.movement_key = "FACTION_%d_MOVEMENT" % fid
		f.capture_key = "FACTION_%d_CAPTURE" % fid
		f.finish_key = "FACTION_%d_FINISH" % fid
		f.expedition_key = "FACTION_%d_EXPEDITION" % fid
		list.append(f)

	return list
