class_name SetupClientUIAction
extends ActionLeaf


func tick(actor: Node, blackboard: Blackboard) -> int:
	var main := actor as Control

	main._set_cards_visible(true)
	var client_count: int = int(blackboard.get_value("client_count", 0)) + 1
	blackboard.set_value("client_count", client_count)
	main.loading_panel.visible = false

	main.card_hover_panel.hide_immediately()
	main.reading_vignette.reset()

	var encounter_index: int = int(blackboard.get_value("current_encounter_index", 0))
	main.reading_slot_mgr.reset_for_client(maxi(encounter_index - 1, 0))

	var encounter: Dictionary = blackboard.get_value("current_encounter", {})
	if encounter is Dictionary:
		encounter = (encounter as Dictionary).duplicate(true)
	var client_name: String = encounter.get("client", {}).get("name", "Unknown")
	main.sidebar.update_client(client_name, client_count, main.portraits.get_portrait(client_name))
	main.sidebar.update_deck_count(main.player_hand.get_card_count())
	main.sidebar.update_progress(main.reading_slot_mgr.slot_filled)
	main.story_title_label.text = client_name
	main.client_context_text.text = encounter.get("client", {}).get("context", "")

	main._render_story()
	main.resolution_panel.visible = false
	main._deal_hand()

	blackboard.set_value("all_slots_filled", false)
	blackboard.set_value("phase", "reading_active")
	return SUCCESS
