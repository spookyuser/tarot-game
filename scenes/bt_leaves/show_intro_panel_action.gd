class_name ShowIntroPanelAction
extends ActionLeaf

var _shown := false


func before_run(actor: Node, blackboard: Blackboard) -> void:
	_shown = false
	blackboard.set_value("begin_pressed", false)


func tick(actor: Node, blackboard: Blackboard) -> int:
	var main := actor as Control

	if not _shown:
		_shown = true
		main._set_cards_visible(false)
		main.loading_panel.visible = false
		main.resolution_panel.visible = false

		var encounter: Dictionary = blackboard.get_value("current_encounter", {})
		if encounter is Dictionary:
			encounter = (encounter as Dictionary).duplicate(true)
		var client_name: String = encounter.get("client", {}).get("name", "Unknown")
		var context: String = encounter.get("client", {}).get("context", "")
		main.intro_panel.populate(client_name, context, main.portraits.get_portrait(client_name))

	if blackboard.get_value("begin_pressed", false):
		main.intro_panel.visible = false
		_shown = false
		return SUCCESS

	return RUNNING


func after_run(actor: Node, blackboard: Blackboard) -> void:
	_shown = false
