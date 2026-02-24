class_name IsDeckExhaustedCondition
extends ConditionLeaf


func tick(_actor: Node, blackboard: Blackboard) -> int:
	if blackboard.get_value("deck_exhausted", false):
		return SUCCESS
	return FAILURE
