extends Camera3D
## Tactical overview, contextual pawn focus, cursor zoom, and ground-plane panning.
var _yaw := 0.0
var _elevation := 1.12
var _zoom_factor := 1.0
var _dragging := false
var _panning := false
var _points: Array[Vector3] = []
var _center := Vector3.ZERO
var _smooth := false
var _focus_tween: Tween

func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	keep_aspect = Camera3D.KEEP_HEIGHT
	far = 350.0
	current = true
	overview(false)
	get_viewport().size_changed.connect(_update_camera)

func _process(_delta: float) -> void:
	_update_camera()

func play_rect() -> Rect2:
	if get_parent().has_method("get_play_rect"):
		return get_parent().get_play_rect()
	return get_viewport().get_visible_rect().grow(-24)

func overview(animate: bool = true) -> void:
	var board := get_parent().get_node_or_null("Board")
	var extent := 14.35 * (float(board.tile_spacing) if board else 1.0)
	var points: Array[Vector3] = []
	for x in [-extent, extent]:
		for z in [-extent, extent]:
			points.append(board.to_global(Vector3(x, 0, z)) if board else Vector3(x, 0, z))
	_frame(points, animate)

func focus_points(points: Array[Vector3]) -> void:
	if not points.is_empty():
		_frame(points, true)

func _frame(points: Array[Vector3], animate: bool) -> void:
	if _focus_tween and _focus_tween.is_valid():
		_focus_tween.kill()
	_smooth = animate
	_points.assign(points)
	var low := points[0]
	var high := points[0]
	for point in points:
		low = low.min(point)
		high = high.max(point)
	var target := (low + high) * 0.5
	target.y = 0
	_zoom_factor = 1.0
	if animate:
		_focus_tween = create_tween()
		_focus_tween.tween_property(self, "_center", target, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_center = target
	_update_camera()

func ground_at(screen: Vector2) -> Variant:
	return Plane(Vector3.UP, 0.12).intersects_ray(project_ray_origin(screen), project_ray_normal(screen))

func _unhandled_input(event: InputEvent) -> void:
	if get_parent().has_method("is_board_input_locked") and get_parent().is_board_input_locked():
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and play_rect().has_point(event.position):
			if _focus_tween and _focus_tween.is_valid():
				_focus_tween.kill()
			_smooth = false
			var before: Variant = ground_at(event.position)
			_zoom_factor = clampf(_zoom_factor * (0.85 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.18), 0.32, 2.0)
			_update_camera()
			var after: Variant = ground_at(event.position)
			if before is Vector3 and after is Vector3:
				_center += before - after
	elif event is InputEventMouseMotion:
		if _dragging:
			_yaw -= event.relative.x * 0.006
			_elevation = clampf(_elevation + event.relative.y * 0.005, 0.55, 1.56)
		elif _panning:
			if _focus_tween and _focus_tween.is_valid():
				_focus_tween.kill()
			var before: Variant = ground_at(event.position - event.relative)
			var after: Variant = ground_at(event.position)
			if before is Vector3 and after is Vector3:
				_center += before - after
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_R, KEY_O]:
			_yaw = 0
			_elevation = 1.56
			overview(false)
		elif event.keycode == KEY_T:
			_yaw = 0
			_elevation = 1.56
		elif event.keycode == KEY_G:
			toggle_angle()
	_update_camera()

func toggle_angle() -> void:
	_elevation = 1.0 if _elevation > 1.4 else 1.56
	_update_camera()

func _update_camera() -> void:
	if not is_inside_tree() or _points.is_empty():
		return
	position = _center + Vector3(sin(_yaw) * cos(_elevation), sin(_elevation), cos(_yaw) * cos(_elevation)) * 80.0
	look_at(_center, Vector3.UP)
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for point in _points:
		var local := basis.inverse() * (point - _points[0])
		var projected := Vector2(local.x, local.y)
		low = low.min(projected)
		high = high.max(projected)
	# Contextual views retain some neighboring cells instead of zooming into a head.
	var span := (high - low + Vector2(2.2, 2.2)).max(Vector2(10, 10))
	var viewport_size := get_viewport().get_visible_rect().size
	var area := play_rect()
	var world_per_pixel := maxf(span.x / maxf(area.size.x, 1), span.y / maxf(area.size.y, 1)) * _zoom_factor
	var target_size := world_per_pixel * viewport_size.y
	if _smooth:
		size = lerpf(size, target_size, 1.0 - exp(-get_process_delta_time() * 18.0))
		if absf(size - target_size) < 0.01:
			_smooth = false
	else:
		size = target_size
	world_per_pixel = size / viewport_size.y
	h_offset = (viewport_size.x * 0.5 - area.get_center().x) * world_per_pixel
	v_offset = (area.get_center().y - viewport_size.y * 0.5) * world_per_pixel
