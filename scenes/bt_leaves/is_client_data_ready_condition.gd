class_name IsClientDataReadyCondition
extends ConditionLeaf


func tick(_actor: Node, blackboard: Blackboard) -> int:
	if blackboard.get_value("client_data_ready", false):
		return SUCCESS
	return FAILURE
