@tool
extends Area3D
class_name Piece
## Physical and logical piece entity.
## Handles game board movement, interpolation tweens, collision detection,
## and orchestrates the child PieceVisual component.

signal moved_to(destination: Vector3)
signal step_reached(step_position: Vector3)
signal movement_finished()
signal piece_selected()

@export_group("Piece Identity")
@export var team: int = 0:
	set(value):
		team = value
		if is_instance_valid(visual):
			visual.preview_faction = value

@export var slot: int = 0:
	set(value):
		slot = value
		if is_instance_valid(visual):
			visual.preview_slot = value

@export var piece_color: Color = Color("ff536c"):
	set(value):
		piece_color = value
		if is_instance_valid(visual):
			visual.preview_color = value

@onready var visual: PieceVisual = $Visual if has_node("Visual") else null
@onready var collision_shape: CollisionShape3D = $CollisionShape3D if has_node("CollisionShape3D") else null

var _active_tween: Tween = null

# --- Delegated Visual Properties (for backward compatibility) ---

var moving: bool:
	get:
		return visual.moving if is_instance_valid(visual) else false
	set(value):
		if is_instance_valid(visual): visual.moving = value

var rig: Node3D:
	get:
		return visual.rig if is_instance_valid(visual) else null

var activity: float:
	get:
		return visual.activity if is_instance_valid(visual) else 0.0

var heading: float:
	get:
		return visual.heading if is_instance_valid(visual) else 0.0
	set(value):
		if is_instance_valid(visual): visual.heading = value

var cadence: float:
	get:
		return visual.cadence if is_instance_valid(visual) else 1.0

var limbs: Array[Node3D]:
	get:
		return visual.limbs if is_instance_valid(visual) else []

var knees: Array[Node3D]:
	get:
		return visual.knees if is_instance_valid(visual) else []

var elbows: Array[Node3D]:
	get:
		return visual.elbows if is_instance_valid(visual) else []

func _ready() -> void:
	_ensure_visual()
	if not input_event.is_connected(_on_input_event):
		input_event.connect(_on_input_event)

func _on_input_event(_camera: Camera3D, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		piece_selected.emit()

func build(team_idx: int, slot_idx: int, col: Color) -> void:
	team = team_idx
	slot = slot_idx
	piece_color = col
	_ensure_visual()
	visual.build(team_idx, slot_idx, col)
	if has_meta("callsign"):
		remove_meta("callsign")
	set_meta("callsign", visual.get_meta("callsign", "Bulwark"))

func _ensure_visual() -> void:
	if not is_instance_valid(visual):
		visual = get_node_or_null("Visual")
		if not is_instance_valid(visual):
			visual = PieceVisual.new()
			visual.name = "Visual"
			add_child(visual)

func step_duration() -> float:
	return visual.step_duration() if is_instance_valid(visual) else 0.1

func face_destination(destination: Vector3) -> void:
	if is_instance_valid(visual):
		visual.face_destination(destination)

func acknowledge() -> void:
	if is_instance_valid(visual):
		visual.acknowledge()

func play_launch() -> void:
	if is_instance_valid(visual):
		visual.play_launch()

func play_arrival() -> void:
	if is_instance_valid(visual):
		visual.play_arrival()

# --- High-level Board Movement Methods ---

## Kills any active tween movement on this piece.
func kill_movement() -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null
	if is_instance_valid(visual):
		visual.moving = false

## Moves the piece from jail to the exit point with a parabolic launch leap.
func move_release_to(destination: Vector3) -> Signal:
	kill_movement()
	_ensure_visual()
	visual.moving = true
	visual.play_launch()
	face_destination(destination)
	var mid_apex: Vector3 = (position + destination) * 0.5 + Vector3(0, 2.5, 0)
	_active_tween = create_tween()
	_active_tween.tween_property(self, "position", mid_apex, 0.22).set_trans(Tween.TRANS_SINE)
	_active_tween.tween_property(self, "position", destination, 0.22).set_trans(Tween.TRANS_SINE)
	_active_tween.finished.connect(_on_release_finished.bind(destination), CONNECT_ONE_SHOT)
	return movement_finished

func _on_release_finished(destination: Vector3) -> void:
	if is_instance_valid(visual):
		visual.moving = false
		visual.play_arrival()
	moved_to.emit(destination)
	movement_finished.emit()

## Moves the piece tile-by-tile along the waypoint path, then settles at final_target.
func move_steps_to(waypoints: Array[Vector3], final_target: Vector3) -> Signal:
	kill_movement()
	_ensure_visual()
	visual.moving = true
	var step_time: float = step_duration()
	_active_tween = create_tween()
	for wp in waypoints:
		_active_tween.tween_callback(face_destination.bind(wp))
		_active_tween.tween_property(self, "position", wp, step_time)
		_active_tween.tween_callback(func(): step_reached.emit(wp))
	_active_tween.tween_property(self, "position", final_target, 0.12).set_trans(Tween.TRANS_SINE)
	_active_tween.finished.connect(_on_steps_finished.bind(final_target), CONNECT_ONE_SHOT)
	return movement_finished

func _on_steps_finished(final_target: Vector3) -> void:
	if is_instance_valid(visual):
		visual.moving = false
		visual.play_arrival()
	moved_to.emit(final_target)
	movement_finished.emit()

## Special bonus promotion leap directly to the center goal core.
func move_bonus_to(goal_position: Vector3) -> Signal:
	kill_movement()
	_ensure_visual()
	visual.play_launch()
	_active_tween = create_tween()
	_active_tween.tween_property(self, "position", Vector3(0, 3, 0), 0.6).set_trans(Tween.TRANS_SINE)
	_active_tween.tween_property(self, "position", goal_position, 0.3)
	_active_tween.finished.connect(_on_bonus_finished.bind(goal_position), CONNECT_ONE_SHOT)
	return movement_finished

func _on_bonus_finished(goal_position: Vector3) -> void:
	if is_instance_valid(visual):
		visual.moving = false
		visual.play_arrival()
	moved_to.emit(goal_position)
	movement_finished.emit()

## Smooth position interpolation for sync, captures, or re-centering.
func move_smooth_to(target_pos: Vector3, duration: float = 0.3) -> Signal:
	kill_movement()
	_active_tween = create_tween()
	_active_tween.tween_property(self, "position", target_pos, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_active_tween.finished.connect(func(): movement_finished.emit(), CONNECT_ONE_SHOT)
	return movement_finished
