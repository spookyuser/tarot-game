class_name CardUtils
extends RefCounted


static func find_held_card(hand: Hand) -> Card:
	for card: Card in hand._held_cards:
		if card.current_state == DraggableObject.DraggableState.HOLDING:
			return card
	return null
