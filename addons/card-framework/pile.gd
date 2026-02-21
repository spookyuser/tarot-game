## A stacked card container with directional positioning and interaction controls.
##
## Cards stack in a configurable direction (UP/DOWN/LEFT/RIGHT) with gap spacing.
## Supports full, top-only, or no-movement interaction modes.
##
## Positioning constraint: uses `position + offset` for card placement, so this
## node's parent must have global_position (0,0) or card positions will be wrong.
class_name Pile
extends CardContainer

enum PileDirection {
	UP,
	DOWN,
	LEFT,
	RIGHT
}

@export_group("pile_layout")
@export var stack_display_gap := CardFrameworkSettings.LAYOUT_STACK_GAP
@export var max_stack_display := CardFrameworkSettings.LAYOUT_MAX_STACK_DISPLAY
@export var card_face_up := true
@export var layout := PileDirection.UP

@export_group("pile_interaction")
@export var allow_card_movement: bool = true
@export var restrict_to_top_card: bool = true
@export var align_drop_zone_with_top_card := true


func get_top_cards(n: int) -> Array[Card]:
	var arr_size: int = _held_cards.size()
	var count: int = min(n, arr_size)
	var result: Array[Card] = []
	for i: int in range(count):
		result.append(_held_cards[arr_size - 1 - i])
	return result


func _update_target_z_index() -> void:
	for i: int in range(_held_cards.size()):
		var card: Card = _held_cards[i]
		if card.is_pressed:
			card.stored_z_index = CardFrameworkSettings.VISUAL_PILE_Z_INDEX + i
		else:
			card.stored_z_index = i


func _update_target_positions() -> void:
	var last_index: int = max(_held_cards.size() - 1, 0)
	var last_offset: Vector2 = _calculate_offset(last_index)

	if enable_drop_zone and align_drop_zone_with_top_card:
		drop_zone.change_sensor_position_with_offset(last_offset)

	for i: int in range(_held_cards.size()):
		var card: Card = _held_cards[i]
		var offset: Vector2 = _calculate_offset(i)
		var target_pos: Vector2 = position + offset

		card.show_front = card_face_up
		card.move(target_pos, 0.0)

		if not allow_card_movement:
			card.can_be_interacted_with = false
		elif restrict_to_top_card:
			card.can_be_interacted_with = (i == _held_cards.size() - 1)
		else:
			card.can_be_interacted_with = true


func _calculate_offset(index: int) -> Vector2:
	var actual_index: int = min(index, max_stack_display - 1)
	var offset_value: float = actual_index * stack_display_gap
	var offset := Vector2.ZERO

	match layout:
		PileDirection.UP:
			offset.y -= offset_value
		PileDirection.DOWN:
			offset.y += offset_value
		PileDirection.RIGHT:
			offset.x += offset_value
		PileDirection.LEFT:
			offset.x -= offset_value

	return offset
