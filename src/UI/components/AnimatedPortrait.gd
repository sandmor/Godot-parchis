extends Control
## Playback of complete transparent images. One frame, one draw.
const Lore := preload("res://Factions.gd")
var faction_id := -1
var expression := "calm"
var speaking := false
var motion_enabled := true
var texture: Texture2D
var definition: Resource
var frame_state := "idle"
var _clock := 0.0

func _ready() -> void:
	add_to_group("AnimatedPortraits")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(queue_redraw)

func set_character(team: int, mood: String = "calm") -> void:
	if faction_id != team:
		faction_id = team
		definition = load(str(Lore.profile(team).portrait))
		_clock = 0.0
	expression = mood
	_update_frame()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		speaking = false
		return
	_clock += delta
	_update_frame()

func _update_frame() -> void:
	if not definition: return
	var next := "idle"
	if motion_enabled:
		if fmod(_clock + faction_id*.47,4.7) > 4.54:
			next = "blink"
		elif speaking:
			next = ["idle","speak_a","speak_a","idle","speak_b","idle","idle"][int(_clock*8)%7]
		elif expression == "celebrate":
			next = "smile"
	var selected: Texture2D = definition.frames.get(next,definition.frames.idle)
	if texture != selected:
		frame_state = next
		texture = selected
		queue_redraw()

func _draw() -> void:
	if not texture: return
	var canvas := texture.get_size()
	var factor := maxf(size.x/canvas.x,size.y/canvas.y)
	draw_texture_rect(texture,Rect2((size-canvas*factor)*.5,canvas*factor),false)
