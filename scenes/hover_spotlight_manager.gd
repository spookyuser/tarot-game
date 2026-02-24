class_name HoverSpotlightManager
extends Node

var _target: Control = null
var _padding: float = 0.0


func update(
	vignette: VignetteEffect,
	player_hand: Hand,
	slot_piles: Array[Pile],
	active_slot: int,
	panels_blocking: bool,
	mouse_pos: Vector2,
) -> void:
	if panels_blocking:
		_set_target(vignette, null, 0.0)
		return

	if active_slot < 0 or active_slot >= slot_piles.size():
		_set_target(vignette, null, 0.0)
		return

	if not slot_piles[active_slot].get_global_rect().has_point(mouse_pos):
		_set_target(vignette, null, 0.0)
		return

	var held_card: Card = CardUtils.find_held_card(player_hand)
	if held_card != null:
		_set_target(vignette, held_card, 78.0)
		return

	var slot_cards: Array[Card] = slot_piles[active_slot].get_top_cards(1)
	if slot_cards.size() > 0:
		_set_target(vignette, slot_cards[0], 82.0)
	else:
		_set_target(vignette, slot_piles[active_slot], 74.0)


func clear(vignette: VignetteEffect) -> void:
	_set_target(vignette, null, 0.0)


func _set_target(vignette: VignetteEffect, target: Control, padding: float) -> void:
	var is_moving_card: bool = target is Card and (target as Card).current_state == DraggableObject.DraggableState.HOLDING
	var changed: bool = _target != target or not is_equal_approx(_padding, padding)

	if not changed:
		if is_moving_card:
			vignette.focus_control(target, padding)
		return

	_target = target
	_padding = padding

	if target == null:
		vignette.fade_out_spotlight()
	elif is_moving_card:
		vignette.fade_spotlight_to_control(target, padding, 0.2)
	else:
		vignette.fade_spotlight_to_control(target, padding)
