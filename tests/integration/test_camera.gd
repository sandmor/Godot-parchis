extends "res://tests/support/test_case.gd"

func _run() -> void:
	for resolution in [Vector2i(1440, 1000), Vector2i(1920, 1080), Vector2i(1152, 800), Vector2i(1024, 768)]:
		var viewport := SubViewport.new()
		viewport.size = resolution
		viewport.own_world_3d = true
		root.add_child(viewport)
		var scene := load_game(viewport)
		await process_frame
		scene.setup_overlay.hide()
		var camera: Camera3D = scene.camera
		camera.overview(false)
		var area: Rect2 = scene.get_play_rect()
		for x in [-14.134, 14.134]:
			for z in [-14.134, 14.134]:
				check(area.has_point(camera.unproject_position(Vector3(x, 0, z))), "Overview must keep deck out of sidebar and footer")
		var label: Label3D
		for child in scene.board.get_node("GeneratedArena/MainPath").get_children():
			if child is Label3D:
				label = child
				break
		var world_height := label.pixel_size * label.font_size
		var a := camera.unproject_position(Vector3.ZERO)
		var b := camera.unproject_position(Vector3(0, 0, world_height))
		check(a.distance_to(b) >= 12, "Cell labels need at least 12 screen pixels of text height at supported sizes")
		# Several pawns on one safe space still need distinct clickable labels,
		# even when that space projects against the edge of the play area.
		var cluster_point: Vector3 = camera.ground_at(area.position + Vector2(70, 15))
		var items: Array[Dictionary] = []
		for index in range(4):
			items.append({"id": "cluster_%d" % index, "kind": "pawn", "text": str(index + 1), "world": cluster_point, "color": Color.CYAN})
		scene.move_overlay.set_pins(items)
		scene.move_overlay.update_positions()
		var occupied: Array[Rect2] = []
		for pin in scene.move_overlay.pins:
			var rect: Rect2 = pin.button.get_rect()
			check(area.encloses(rect), "Edge labels stay inside the play area")
			for other in occupied:
				check(not rect.intersects(other), "Stacked pawn labels have separate click targets")
			occupied.append(rect)
		scene.move_overlay.set_pins([])
		var overview_size := camera.size
		var cursor := area.get_center() + Vector2(-80, 60)
		var before: Vector3 = camera.ground_at(cursor)
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		wheel.position = cursor
		camera._unhandled_input(wheel)
		var after: Vector3 = camera.ground_at(cursor)
		check(before.distance_to(after) < 0.01, "Wheel zoom must preserve the ground point under the cursor")
		check(camera.size < overview_size, "Wheel zooms inward")
		var focus: Array[Vector3] = [Vector3(-1, 0.14, -5), Vector3(-1, 0.14, -2), Vector3(-3, 0.14, -1), Vector3(-6, 0.14, -1)]
		camera.focus_points(focus)
		await create_timer(0.55).timeout
		check(camera.size < overview_size * 0.65, "Pawn focus materially enlarges the local board")
		for point in focus:
			check(area.has_point(camera.unproject_position(point)), "Focus must keep pawn and every destination visible")
		camera.overview(false)
		camera.toggle_angle()
		for x in [-14.134, 14.134]:
			for z in [-14.134, 14.134]:
				check(area.has_point(camera.unproject_position(Vector3(x, 0, z))), "Angled view must also respect play area")
		var top := InputEventKey.new()
		top.pressed = true
		top.keycode = KEY_T
		camera._unhandled_input(top)
		check(camera.position.y > 34.0, "Top-view keyboard action changes camera elevation")
		top.keycode = KEY_R
		camera._unhandled_input(top)
		check(camera.position.y > 75.0, "Reset restores top-view camera elevation")
		for point in [Vector3(-14.134, 0, -14.134), Vector3(14.134, 0, 14.134)]:
			check(area.has_point(camera.unproject_position(point)), "Keyboard reset restores full-board framing after focus and zoom")
		viewport.queue_free()
		await process_frame
	await finish("camera checks at 1440×1000, 1920×1080, 1152×800, and 1024×768")
