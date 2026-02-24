class_name ShowLoadingPanelAction
extends ActionLeaf

var _requested := false


func before_run(actor: Node, blackboard: Blackboard) -> void:
	_requested = false


func tick(actor: Node, blackboard: Blackboard) -> int:
	var main := actor as Control

	if not _requested:
		_requested = true
		main._set_cards_visible(false)
		main.loading_panel.visible = true
		main.resolution_panel.visible = false
		main.card_hover_panel.visible = false

		for i: int in range(3):
			main.reading_labels[i].text = ""
			main.slot_labels[i].text = ""
			main.slot_piles[i].enable_drop_zone = false

		var game_state: Dictionary = GameStateHelpers.get_game_state(blackboard)
		main.claude_api.generate_client("client_req", game_state)
		blackboard.set_value("client_data_ready", false)
		blackboard.set_value("client_request_failed", false)

	return RUNNING


func after_run(actor: Node, blackboard: Blackboard) -> void:
	_requested = false
