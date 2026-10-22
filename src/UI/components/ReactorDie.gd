extends Label
## Draw the settled dice as pips; keep numeric values in accessible tooltips.
var value := 0
var available := false
var accent := Color.WHITE

func display(number: int, usable: bool, color: Color) -> void:
	value = number
	available = usable
	accent = color if usable else Color("577080")
	text = ""
	tooltip_text = "%d%s" % [number, " · available" if usable else " · spent"] if number > 0 else "No roll yet"
	queue_redraw()

func _draw() -> void:
	var origin := size * .5
	var bounds := Rect2(origin - Vector2(25, 25), Vector2(50, 50))
	draw_style_box(_die_style(), bounds)
	var layouts := [[], [4], [0, 8], [0, 4, 8], [0, 2, 6, 8], [0, 2, 4, 6, 8], [0, 2, 3, 5, 6, 8]]
	for index in layouts[clampi(value, 0, 6)]:
		var offset := Vector2(index % 3 - 1, int(index / 3) - 1) * 12
		draw_circle(origin + offset, 3.4, accent)

func _die_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("10202c") if available else Color("0b141e")
	style.border_color = accent.darkened(.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style
