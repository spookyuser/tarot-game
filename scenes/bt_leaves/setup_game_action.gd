class_name SetupGameAction
extends ActionLeaf


func tick(actor: Node, blackboard: Blackboard) -> int:
	var main := actor as Control

	var initial_state: Dictionary = {
		"encounters": [
			{
				"client": {
					"name": "Maria the Widow",
					"context": "I got married at 23. Everyone told me not to but i did and last week, my husband just, he's just dead, i'm sad and i don't know what to do. is he at peace?"
				},
				"slots": [
					{"card": "", "text": "", "orientation": ""},
					{"card": "", "text": "", "orientation": ""},
					{"card": "", "text": "", "orientation": ""}
				]
			}
		]
	}

	GameStateHelpers.set_game_state(blackboard, initial_state)
	blackboard.set_value("current_encounter_index", 0)
	blackboard.set_value("current_encounter", {})
	blackboard.set_value("client_count", 0)

	main.portraits.load_all()
	main.deck.build_card_names()
	main.deck.shuffle(9)
	main.sound_manager.play_shuffle()
	main.sound_manager.play_ambient()

	# Set up first encounter
	var encounters: Array = initial_state.get("encounters", [])
	var encounter: Dictionary = encounters[0]
	blackboard.set_value("current_encounter", encounter.duplicate(true))
	blackboard.set_value("current_encounter_index", 1)

	blackboard.set_value("phase", "intro")
	return SUCCESS
