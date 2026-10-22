extends HBoxContainer
## Extraction progress indicator showing docked crew lights.

func set_progress(finished: int, color: Color) -> void:
	name = "ExtractionProgress"
	for slot in range(4):
		var light := get_node_or_null("Slot%d" % slot) as Panel
		if not light:
			light = Panel.new()
			light.name = "Slot%d" % slot
			light.custom_minimum_size = Vector2(10, 10)
			light.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			add_child(light)
		light.tooltip_text = "%d of 4 crew home" % finished
		var style := StyleBoxFlat.new()
		style.bg_color = color if slot < finished else Color("102332")
		style.border_color = color
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		light.add_theme_stylebox_override("panel", style)

	var label := get_node_or_null("CountLabel") as Label
	if not label:
		label = Label.new()
		label.name = "CountLabel"
		label.add_theme_font_size_override("font_size", 12)
		add_child(label)
	label.text = "%d/4 home" % finished
	label.add_theme_color_override("font_color", color)
