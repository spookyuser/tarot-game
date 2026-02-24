class_name StartResolutionTimerAction
extends ActionLeaf


func tick(actor: Node, blackboard: Blackboard) -> int:
	blackboard.set_value("resolution_timer_done", false)
	actor.get_tree().create_timer(1.2).timeout.connect(
		func() -> void: blackboard.set_value("resolution_timer_done", true)
	)
	blackboard.set_value("phase", "resolution_pending")
	return SUCCESS
