extends Control
## A visual nudge pointing at the real, clickable control. Never intercepts input.
var target: Control
var clock := 0.0
var accent := Color("b9ff93")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(target) or not target.is_visible_in_tree():
		return
	var rect := target.get_global_rect()
	var point := Vector2(rect.get_center().x, rect.position.y - 9)
	if point.y < 24:
		return
	point.y -= (sin(clock * 4) + 1) * 3
	draw_colored_polygon(PackedVector2Array([point, point + Vector2(-6, -8), point + Vector2(6, -8)]), accent)
	draw_line(point + Vector2(0, -8), point + Vector2(0, -23), accent, 2, true)
