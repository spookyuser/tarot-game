class_name ShowResolutionAction
extends ActionLeaf

var _shown := false


func before_run(actor: Node, blackboard: Blackboard) -> void:
	_shown = false
	blackboard.set_value("next_pressed", false)


func tick(actor: Node, blackboard: Blackboard) -> int:
	var main := actor as Control

	if not _shown:
		_shown = true
		main._set_cards_visible(false)

		var encounter: Dictionary = blackboard.get_value("current_encounter", {})
		if encounter is Dictionary:
			encounter = (encounter as Dictionary).duplicate(true)
		var title: String = "Reading for %s" % encounter.get("client", {}).get("name", "Unknown")
		var readings: Array[String] = []
		for i: int in range(3):
			readings.append(main.reading_slot_mgr.slot_readings[i])
		main.resolution_panel.populate(title, readings)

	if blackboard.get_value("next_pressed", false):
		_shown = false
		return SUCCESS

	return RUNNING


func after_run(actor: Node, blackboard: Blackboard) -> void:
	_shown = false
