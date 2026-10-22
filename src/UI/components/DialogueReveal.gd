extends Node
## Reusable silent typewriter. Drives portraits and optional nonverbal UI ticks.
signal tick
signal finished
var label: Control
var revealing := false
var characters_per_second := 65.0
var _text := ""
var _position := 0
var _budget := 0.0
var _pause := 0.0

func begin(target: Control, message: String, speed: float = 65) -> void:
	label = target
	_text = message
	characters_per_second = speed
	_position = 0
	_budget = 0
	_pause = 0
	label.text = message
	label.visible_characters = 0
	revealing = not message.is_empty()

func _process(delta: float) -> void:
	if not revealing or not is_instance_valid(label) or not label.is_visible_in_tree():
		return
	_pause -= delta
	if _pause > 0:
		return
	_budget += delta * characters_per_second
	while _budget >= 1 and _position < _text.length():
		_budget -= 1
		var character := _text[_position]
		_position += 1
		label.visible_characters = _position
		if character in [".", "!", "?", ":"]:
			_pause = .14
			_budget = 0
			break
		if _position % 3 == 0 and character.strip_edges() != "":
			tick.emit()
	if _position >= _text.length():
		complete()

func complete() -> void:
	var was_revealing := revealing
	revealing = false
	if is_instance_valid(label):
		label.visible_characters = -1
	if was_revealing:
		finished.emit()

func stop() -> void:
	revealing = false
