class_name ShowEndPanelAction
extends ActionLeaf

var _shown := false


func before_run(_actor: Node, _blackboard: Blackboard) -> void:
	_shown = false


func tick(actor: Node, blackboard: Blackboard) -> int:
	var main := actor as Control

	if not _shown:
		_shown = true
		var game_state: Dictionary = GameStateHelpers.get_game_state(blackboard)
		main.end_screen.show_summary(
			game_state.get("encounters", []),
			main.portraits.get_portrait,
			main.back_texture
		)
		main.loading_panel.visible = false
		main.resolution_panel.visible = false

	return RUNNING


func after_run(_actor: Node, _blackboard: Blackboard) -> void:
	_shown = false
