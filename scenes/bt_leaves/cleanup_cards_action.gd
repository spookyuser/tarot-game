class_name CleanupCardsAction
extends ActionLeaf


func tick(actor: Node, blackboard: Blackboard) -> int:
	var main := actor as Control

	main._set_cards_visible(false)
	main._destroy_all_card_nodes()
	return SUCCESS
