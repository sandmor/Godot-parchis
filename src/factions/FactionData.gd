class_name FactionData
extends Resource

## Data container representing a playable faction in the game.
## Strings are stored as translation keys to support multi-language localization.

@export var id: int = 0
@export var name_key: String = ""
@export var short_name_key: String = ""
@export var character: String = ""
@export var title_key: String = ""
@export var color: Color = Color.WHITE
@export var motto_key: String = ""
@export var description_key: String = ""
@export_file("*.tres") var portrait: String = ""
@export_file("*.svg", "*.png") var emblem: String = ""

@export_group("Dialogue Keys")
@export var welcome_key: String = ""
@export var welcome_observer_key: String = ""
@export var jail_key: String = ""
@export var movement_key: String = ""
@export var capture_key: String = ""
@export var finish_key: String = ""
@export var expedition_key: String = ""

func _t(key: String) -> String:
	return str(TranslationServer.translate(StringName(key)))

## Returns the translated faction name.
func get_faction_name() -> String:
	return _t(name_key)

## Returns the translated short name.
func get_short_name() -> String:
	return _t(short_name_key)

## Returns the translated military/diplomatic title.
func get_title() -> String:
	return _t(title_key)

## Returns the translated motto.
func get_motto() -> String:
	return _t(motto_key)

## Returns the translated description.
func get_description() -> String:
	return _t(description_key)

## Formats and returns the welcome transmission for deployment or observing.
func get_welcome(player_name: String, opening_player: String = "", opens_match: bool = true) -> String:
	var key := welcome_key if opens_match else welcome_observer_key
	var text := _t(key)
	return text.replace("{player}", player_name).replace("{first}", opening_player)

## Returns the translated backstory / expedition lore.
func get_expedition() -> String:
	return _t(expedition_key)

## Returns tutorial pages structured for FactionBriefing.
func get_briefing_pages(player_name: String, opening_player: String = "", opens_match: bool = true) -> Array[Dictionary]:
	var pages: Array[Dictionary] = []
	var welcome_body := get_welcome(player_name, opening_player, opens_match)
	var welcome_note := _t("BRIEFING_OPENING_NOTE")
	pages.append({
		"title": _t("BRIEFING_TITLE_WELCOME"),
		"text": "%s\n\n%s" % [welcome_body, welcome_note]
	})
	pages.append({"title": _t("BRIEFING_TITLE_JAIL"), "text": _t(jail_key)})
	pages.append({"title": _t("BRIEFING_TITLE_MOVEMENT"), "text": _t(movement_key)})
	pages.append({"title": _t("BRIEFING_TITLE_CAPTURE"), "text": _t(capture_key)})
	pages.append({"title": _t("BRIEFING_TITLE_FINISH"), "text": _t(finish_key)})
	return pages

## Exports a legacy dictionary compatible with older calls to Factions.profile().
func to_legacy_profile() -> Dictionary:
	return {
		"id": id,
		"name": get_faction_name(),
		"short_name": get_short_name(),
		"character": character,
		"title": get_title(),
		"color": color,
		"motto": get_motto(),
		"description": get_description(),
		"portrait": portrait,
		"emblem": emblem,
		"welcome": _t(welcome_key),
		"welcome_observer": _t(welcome_observer_key),
		"jail": _t(jail_key),
		"movement": _t(movement_key),
		"capture": _t(capture_key),
		"finish": _t(finish_key)
	}
