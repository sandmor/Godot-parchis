extends RefCounted
## Progress completes through real actions, not through a sequence of Next buttons.
const PATH := "user://field_guide.cfg"
const CUES := {
	"camera": "Wheel: zoom toward cursor. Right drag: orbit. Middle drag: pan. O: overview. G: angled / top view. Select crew to focus.",
	"opening": "First, roll for command. The highest total takes the first turn; this roll cannot launch anyone.",
	"jail": "Your crew is held in stasis. Roll a matching pair to unlock a launch. You have three attempts per turn.",
	"select": "The illuminated crew can act. Select one to project its possible landing sites.",
	"release": "The bay is open. Select a crew member, then the green LAUNCH marker. Launch spends both dice; roll again afterward.",
	"move": "Choose a green landing marker. Its number is the distance; use either die or combine both. You must spend the whole chosen die.",
	"roll": "Roll to power the next journey. A matching pair keeps your turn after you spend the dice.",
	"bonus": "Three consecutive pairs opened the express gate. Select any unfinished crew member to send them straight home.",
	"safe": "A shield marks protected ground. Crew here cannot be captured, including on a faction's launch space.",
	"capture": "Direct hit. An unshielded rival was recalled to stasis and needs a pair to launch again.",
	"home": "You entered your private approach lane. You are protected here; the last jump needs an exact roll.",
	"finish": "One crew member made it through the Loom. Bring all four through to win."
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
	return CUES.get(active, "")

func complete(key: String) -> void:
	seen[key] = true
	if active == key:
		active = ""
	save()

func reset() -> void:
	seen.clear()
	enabled = true
	active = ""
	save()
