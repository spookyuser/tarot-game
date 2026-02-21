## A draggable object that supports mouse interaction with state-based animation system.
##
## This class provides a robust state machine for handling mouse interactions including
## hover effects, drag operations, and programmatic movement using Tween animations.
## All interactive cards and objects extend this base class to inherit consistent
## drag-and-drop behavior.
##
## State Transitions:
## IDLE → HOVERING → HOLDING → MOVING → IDLE
class_name DraggableObject
extends Control

enum DraggableState {
	IDLE,
	HOVERING,
	HOLDING,
	MOVING
}

@export var moving_speed: int = CardFrameworkSettings.ANIMATION_MOVE_SPEED
@export var can_be_interacted_with: bool = true
@export var hover_distance: int = CardFrameworkSettings.PHYSICS_HOVER_DISTANCE
@export var hover_scale: float = CardFrameworkSettings.ANIMATION_HOVER_SCALE
@export var hover_rotation: float = CardFrameworkSettings.ANIMATION_HOVER_ROTATION
@export var hover_duration: float = CardFrameworkSettings.ANIMATION_HOVER_DURATION

# Legacy variables kept for subclass compatibility (pile.gd checks is_pressed)
var is_pressed: bool = false
var is_holding: bool = false
var stored_z_index: int:
	set(value):
		z_index = value
		stored_z_index = value

var current_state: DraggableState = DraggableState.IDLE
var is_mouse_inside: bool = false
var is_moving_to_destination: bool = false
var is_returning_to_original: bool = false

var current_holding_mouse_position: Vector2 = Vector2.ZERO
var original_position: Vector2 = Vector2.ZERO
var original_scale: Vector2 = Vector2.ONE
var original_hover_rotation: float = 0.0
var current_hover_position: Vector2 = Vector2.ZERO

var target_destination: Vector2 = Vector2.ZERO
var target_rotation: float = 0.0
var original_destination: Vector2 = Vector2.ZERO
var original_rotation: float = 0.0
var destination_degree: float = 0.0

var move_tween: Tween = null
var hover_tween: Tween = null

var allowed_transitions: Dictionary = {
	DraggableState.IDLE: [DraggableState.HOVERING, DraggableState.HOLDING, DraggableState.MOVING],
	DraggableState.HOVERING: [DraggableState.IDLE, DraggableState.HOLDING, DraggableState.MOVING],
	DraggableState.HOLDING: [DraggableState.IDLE, DraggableState.MOVING],
	DraggableState.MOVING: [DraggableState.IDLE]
}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_enter)
	mouse_exited.connect(_on_mouse_exit)
	gui_input.connect(_on_gui_input)

	original_destination = global_position
	original_rotation = rotation
	original_position = position
	original_scale = scale
	original_hover_rotation = rotation
	stored_z_index = z_index


func change_state(new_state: DraggableState) -> bool:
	if new_state == current_state:
		return true

	if not new_state in allowed_transitions[current_state]:
		return false

	_exit_state(current_state)
	var old_state: DraggableState = current_state
	current_state = new_state
	_enter_state(new_state, old_state)
	return true


func _enter_state(state: DraggableState, from_state: DraggableState) -> void:
	match state:
		DraggableState.IDLE:
			z_index = stored_z_index
			mouse_filter = Control.MOUSE_FILTER_STOP

		DraggableState.HOVERING:
			z_index = stored_z_index + CardFrameworkSettings.VISUAL_DRAG_Z_OFFSET
			_start_hover_animation()

		DraggableState.HOLDING:
			if from_state == DraggableState.HOVERING:
				_preserve_hover_position()
			current_holding_mouse_position = get_local_mouse_position()
			z_index = stored_z_index + CardFrameworkSettings.VISUAL_DRAG_Z_OFFSET
			rotation = original_hover_rotation

		DraggableState.MOVING:
			if hover_tween and hover_tween.is_valid():
				hover_tween.kill()
				hover_tween = null
			z_index = stored_z_index + CardFrameworkSettings.VISUAL_DRAG_Z_OFFSET
			mouse_filter = Control.MOUSE_FILTER_IGNORE


func _exit_state(state: DraggableState) -> void:
	match state:
		DraggableState.HOVERING:
			z_index = stored_z_index
			_stop_hover_animation()

		DraggableState.HOLDING:
			z_index = stored_z_index
			scale = original_scale
			rotation = original_hover_rotation

		DraggableState.MOVING:
			mouse_filter = Control.MOUSE_FILTER_STOP


func _process(_delta: float) -> void:
	match current_state:
		DraggableState.HOLDING:
			global_position = get_global_mouse_position() - current_holding_mouse_position


func _finish_move() -> void:
	is_moving_to_destination = false
	rotation = destination_degree

	if not is_returning_to_original:
		original_destination = target_destination
		original_rotation = target_rotation

	is_returning_to_original = false
	change_state(DraggableState.IDLE)
	_on_move_done()


func _on_move_done() -> void:
	pass


func _start_hover_animation() -> void:
	if hover_tween and hover_tween.is_valid():
		hover_tween.kill()
		hover_tween = null
		position = original_position
		scale = original_scale
		rotation = original_hover_rotation

	original_position = position
	original_scale = scale
	original_hover_rotation = rotation
	current_hover_position = position

	hover_tween = create_tween()
	hover_tween.set_parallel(true)

	var target_position := Vector2(position.x, position.y - hover_distance)
	hover_tween.tween_property(self, "position", target_position, hover_duration)
	hover_tween.tween_property(self, "scale", original_scale * hover_scale, hover_duration)
	hover_tween.tween_property(self, "rotation", original_hover_rotation + deg_to_rad(hover_rotation), hover_duration)
	hover_tween.tween_method(_update_hover_position, position, target_position, hover_duration)


func _stop_hover_animation() -> void:
	if hover_tween and hover_tween.is_valid():
		hover_tween.kill()
		hover_tween = null

	hover_tween = create_tween()
	hover_tween.set_parallel(true)
	hover_tween.tween_property(self, "position", original_position, hover_duration)
	hover_tween.tween_property(self, "scale", original_scale, hover_duration)
	hover_tween.tween_property(self, "rotation", original_hover_rotation, hover_duration)
	hover_tween.tween_method(_update_hover_position, position, original_position, hover_duration)


func _update_hover_position(pos: Vector2) -> void:
	current_hover_position = pos


func _preserve_hover_position() -> void:
	if hover_tween and hover_tween.is_valid():
		hover_tween.kill()
		hover_tween = null
	position = current_hover_position


func _can_start_hovering() -> bool:
	return true


func _on_mouse_enter() -> void:
	is_mouse_inside = true
	if can_be_interacted_with and _can_start_hovering():
		change_state(DraggableState.HOVERING)


func _on_mouse_exit() -> void:
	is_mouse_inside = false
	match current_state:
		DraggableState.HOVERING:
			change_state(DraggableState.IDLE)


func _on_gui_input(event: InputEvent) -> void:
	if not can_be_interacted_with:
		return
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)


func move(p_target_destination: Vector2, degree: float) -> void:
	if global_position == p_target_destination and rotation == degree:
		return

	change_state(DraggableState.MOVING)

	if move_tween and move_tween.is_valid():
		move_tween.kill()
		move_tween = null

	target_destination = p_target_destination
	target_rotation = degree
	rotation = 0
	destination_degree = degree
	is_moving_to_destination = true

	var distance: float = global_position.distance_to(p_target_destination)
	var duration: float = distance / moving_speed

	move_tween = create_tween()
	move_tween.tween_property(self, "global_position", p_target_destination, duration)
	move_tween.tween_callback(_finish_move)


func _handle_mouse_button(mouse_event: InputEventMouseButton) -> void:
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if current_state == DraggableState.MOVING:
		return
	if mouse_event.is_pressed():
		_handle_mouse_pressed()
	if mouse_event.is_released():
		_handle_mouse_released()


func return_to_original() -> void:
	is_returning_to_original = true
	move(original_destination, original_rotation)


func _handle_mouse_pressed() -> void:
	is_pressed = true
	match current_state:
		DraggableState.HOVERING:
			change_state(DraggableState.HOLDING)
		DraggableState.IDLE:
			if is_mouse_inside and can_be_interacted_with and _can_start_hovering():
				change_state(DraggableState.HOLDING)


func _handle_mouse_released() -> void:
	is_pressed = false
	match current_state:
		DraggableState.HOLDING:
			change_state(DraggableState.IDLE)
