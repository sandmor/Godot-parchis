extends RefCounted
## Progress completes through real actions, not through a sequence of Next buttons.
const PATH := "user://field_guide.cfg"
const CUES := {
	"camera": "GUIDE_CAMERA",
	"opening": "GUIDE_OPENING",
	"jail": "GUIDE_JAIL",
	"select": "GUIDE_SELECT",
	"release": "GUIDE_RELEASE",
	"move": "GUIDE_MOVE",
	"roll": "GUIDE_ROLL",
	"bonus": "GUIDE_BONUS",
	"safe": "GUIDE_SAFE",
	"capture": "GUIDE_CAPTURE",
	"home": "GUIDE_HOME",
	"finish": "GUIDE_FINISH"
}
var storage_path := PATH
var seen: Dictionary = {}
var active := ""
var remember := true
var enabled := true

func restore() -> void:
	if not remember:
		return
	var config := ConfigFile.new()
	if config.load(storage_path) == OK:
		seen = config.get_value("guide", "seen", {})
		enabled = config.get_value("guide", "enabled", true)

func save() -> void:
	if not remember:
		return
	var config := ConfigFile.new()
	config.set_value("guide", "seen", seen)
	config.set_value("guide", "enabled", enabled)
	config.save(storage_path)

func cue(key: String) -> String:
	active = key if enabled and not seen.has(key) else ""
	var cue_key := str(CUES.get(active, ""))
	if cue_key.is_empty():
		return ""
	return str(TranslationServer.translate(StringName(cue_key)))

func complete(key: String) -> void:
	seen[key] = true
	if active == key:
		active = ""
	save()

func reset() -> void:
	seen.clear()
	active = ""
	save()
