class_name HasClientRequestFailedCondition
extends ConditionLeaf


func tick(_actor: Node, blackboard: Blackboard) -> int:
	if blackboard.get_value("client_request_failed", false):
		return SUCCESS
	return FAILURE
