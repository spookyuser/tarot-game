class_name AdvanceEncounterAction
extends ActionLeaf


func tick(actor: Node, blackboard: Blackboard) -> int:
	var game_state: Dictionary = GameStateHelpers.get_game_state(blackboard)
	var encounters: Array = game_state.get("encounters", [])
	var encounter_index: int = int(blackboard.get_value("current_encounter_index", 0))

	if encounter_index >= encounters.size():
		blackboard.set_value("phase", "client_loading")
		return SUCCESS

	var encounter: Dictionary = encounters[encounter_index]
	blackboard.set_value("current_encounter", encounter.duplicate(true))
	blackboard.set_value("current_encounter_index", encounter_index + 1)
	blackboard.set_value("phase", "intro")
	return SUCCESS
