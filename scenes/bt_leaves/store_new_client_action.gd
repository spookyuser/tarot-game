class_name StoreNewClientAction
extends ActionLeaf


func tick(actor: Node, blackboard: Blackboard) -> int:
	var main := actor as Control
	var client_data: Dictionary = blackboard.get_value("client_data", {})

	main.loading_panel.visible = false

	var new_encounter: Dictionary = {
		"client": {
			"name": client_data.get("name", "Unknown"),
			"context": client_data.get("context", "")
		},
		"slots": [
			{"card": "", "text": "", "orientation": ""},
			{"card": "", "text": "", "orientation": ""},
			{"card": "", "text": "", "orientation": ""}
		]
	}

	var game_state: Dictionary = GameStateHelpers.get_game_state(blackboard)
	var encounters: Array = game_state.get("encounters", [])
	encounters.append(new_encounter)
	game_state["encounters"] = encounters
	GameStateHelpers.set_game_state(blackboard, game_state)

	var encounter_index: int = encounters.size() - 1
	blackboard.set_value("current_encounter", new_encounter.duplicate(true))
	blackboard.set_value("current_encounter_index", encounter_index + 1)

	blackboard.set_value("client_data_ready", false)
	blackboard.set_value("client_request_failed", false)
	blackboard.set_value("phase", "intro")
	return SUCCESS
