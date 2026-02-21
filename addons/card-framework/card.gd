## A card object that represents a single playing card with drag-and-drop functionality.
##
## Extends DraggableObject with card-specific state: front/back faces, reversal,
## container reference, and global hover/hold mutual exclusion via static counters.
class_name Card
extends DraggableObject

static var hovering_card_count: int = 0
static var holding_card_count: int = 0

@export var card_name: String
@export var card_size: Vector2 = CardFrameworkSettings.LAYOUT_DEFAULT_CARD_SIZE
@export var front_image: Texture2D
@export var back_image: Texture2D
@export var show_front: bool = true:
	set(value):
		_show_front = value
		_update_face_visibility()
	get:
		return _show_front
@export var front_face_texture: TextureRect
@export var back_face_texture: TextureRect

var card_info: Dictionary = {}
var card_container: CardContainer
var is_reversed: bool = false:
	set(value):
		is_reversed = value
		_apply_reversed_texture()
var reversed_front_image: Texture2D
var _upright_front_image: Texture2D
var _show_front: bool = true


func _ready() -> void:
	super._ready()

	if front_face_texture == null:
		front_face_texture = $FrontFace/TextureRect if has_node("FrontFace/TextureRect") else null
	if back_face_texture == null:
		back_face_texture = $BackFace/TextureRect if has_node("BackFace/TextureRect") else null

	if front_face_texture == null or back_face_texture == null:
		push_error("Card requires front_face_texture and back_face_texture to be assigned or FrontFace/TextureRect and BackFace/TextureRect nodes to exist")
		return

	front_face_texture.size = card_size
	back_face_texture.size = card_size
	if front_image:
		front_face_texture.texture = front_image
	if back_image:
		back_face_texture.texture = back_image
	pivot_offset = card_size / 2
	_update_face_visibility()


func _update_face_visibility() -> void:
	if front_face_texture != null and back_face_texture != null:
		front_face_texture.visible = _show_front
		back_face_texture.visible = not _show_front


func _on_move_done() -> void:
	card_container.on_card_move_done(self)


func set_faces(front_face: Texture2D, back_face: Texture2D) -> void:
	_upright_front_image = front_face
	front_face_texture.texture = front_face
	back_face_texture.texture = back_face
	_apply_reversed_texture()


func _apply_reversed_texture() -> void:
	if front_face_texture == null or _upright_front_image == null:
		return
	if is_reversed and reversed_front_image != null:
		front_face_texture.texture = reversed_front_image
	else:
		front_face_texture.texture = _upright_front_image


func return_card() -> void:
	super.return_to_original()


func _enter_state(state: DraggableState, from_state: DraggableState) -> void:
	super._enter_state(state, from_state)
	match state:
		DraggableState.HOVERING:
			hovering_card_count += 1
		DraggableState.HOLDING:
			holding_card_count += 1
			if card_container:
				card_container.hold_card(self)


func _exit_state(state: DraggableState) -> void:
	match state:
		DraggableState.HOVERING:
			hovering_card_count -= 1
		DraggableState.HOLDING:
			holding_card_count -= 1
	super._exit_state(state)


## @deprecated Use state machine transitions instead.
func set_holding() -> void:
	if card_container:
		card_container.hold_card(self)


func get_string() -> String:
	return card_name


func _can_start_hovering() -> bool:
	return hovering_card_count == 0 and holding_card_count == 0


func _handle_mouse_pressed() -> void:
	card_container.on_card_pressed(self)
	super._handle_mouse_pressed()


func _handle_mouse_released() -> void:
	super._handle_mouse_released()
	if card_container:
		card_container.release_holding_cards()
