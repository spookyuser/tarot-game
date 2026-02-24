class_name ShowClientErrorAction
extends ActionLeaf


func tick(actor: Node, blackboard: Blackboard) -> int:
	var main := actor as Control
	var error_msg: String = str(blackboard.get_value("client_error_message", "Unknown error"))

	main._set_cards_visible(false)
	main.loading_panel.visible = false
	main.story_rich_text.text = "[color=#a05a5a]No one came to the table. (%s)[/color]" % error_msg

	blackboard.set_value("client_request_failed", false)
	blackboard.set_value("phase", "end")
	return SUCCESS
