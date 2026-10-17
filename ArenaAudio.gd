extends Node
## Baked original effects, separate dialogue UI mix, bounded voice pool.
const SETTINGS := "user://audio_settings.cfg"
const KEYS := ["select", "dice_charge", "dice_impact", "launch", "travel", "land", "shield", "capture", "finish", "victory", "comms", "text", "turn", "doubles"]
var enabled := true
var effects_volume := .65
var dialogue_volume := .35
var portrait_motion := true
var remember_preferences := true
var settings_path := SETTINGS
var voices: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var _last_played: Dictionary = {}
var _serial := 0

func _ready() -> void:
	for index in range(12):
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	for key in KEYS:
		sounds[key] = load("res://assets/audio/%s.wav" % key)
	if remember_preferences:
		var config := ConfigFile.new()
		if config.load(settings_path) == OK:
			portrait_motion = config.get_value("audio", "portrait_motion", true)
			enabled = config.get_value("audio", "enabled", true)
			effects_volume = clampf(float(config.get_value("audio", "effects", .65)), 0, 1)
			dialogue_volume = clampf(float(config.get_value("audio", "dialogue", .35)), 0, 1)

func play(key: String, faction: int = -1, gain: float = 1.0) -> void:
	var dialogue_sound := key in ["comms", "text"]
	var level := dialogue_volume if dialogue_sound else effects_volume
	if not enabled or level <= 0 or not sounds.has(key):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(key, -10000)) < (65 if key == "text" else 35):
		return
	_last_played[key] = now
	var selected: AudioStreamPlayer
	for voice in voices:
		if not voice.playing:
			selected = voice
			break
	if not is_instance_valid(selected):
		# Frequent dialogue ticks never steal a launch, dice impact, or victory cue.
		if dialogue_sound:
			return
		selected = voices[_serial % voices.size()]
	_serial += 1
	selected.stream = sounds[key]
	selected.set_meta("dialogue", dialogue_sound)
	selected.volume_db = linear_to_db(level * (.18 if key == "text" else .55) * clampf(gain,.05,1))
	selected.pitch_scale = [0.9, 1.06, 1.16, 1.0][clampi(faction, 0, 3)] if faction >= 0 and key in ["launch", "travel", "comms", "text", "dice_charge", "dice_impact"] else 1.0
	selected.play()

func set_muted(muted: bool) -> void:
	enabled = not muted
	if muted:
		for voice in voices:
			voice.stop()
	save_preferences()

func set_volume(channel: String, level: float) -> void:
	if channel == "dialogue":
		dialogue_volume = clampf(level, 0, 1)
	else:
		effects_volume = clampf(level, 0, 1)
	for voice in voices:
		var is_dialogue := bool(voice.get_meta("dialogue", false))
		if is_dialogue == (channel == "dialogue"):
			voice.volume_db = linear_to_db(maxf(.00001, level * (.18 if voice.stream == sounds.get("text") else .55)))
	save_preferences()

func save_preferences() -> void:
	if not remember_preferences:
		return
	var config := ConfigFile.new()
	config.set_value("audio", "portrait_motion", portrait_motion)
	config.set_value("audio", "enabled", enabled)
	config.set_value("audio", "effects", effects_volume)
	config.set_value("audio", "dialogue", dialogue_volume)
	config.save(settings_path)
