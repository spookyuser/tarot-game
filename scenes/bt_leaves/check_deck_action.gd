class_name CheckDeckAction
extends ActionLeaf


func tick(actor: Node, blackboard: Blackboard) -> int:
	var main := actor as Control
	var exhausted: bool = main.player_hand.get_card_count() < 3
	blackboard.set_value("deck_exhausted", exhausted)
	return SUCCESS
