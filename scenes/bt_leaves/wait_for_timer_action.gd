class_name WaitForTimerAction
extends ActionLeaf


func tick(_actor: Node, blackboard: Blackboard) -> int:
	if blackboard.get_value("resolution_timer_done", false):
		return SUCCESS
	return RUNNING
