class_name IsPhaseCondition
extends ConditionLeaf

@export var expected_phase: String = ""


func tick(actor: Node, blackboard: Blackboard) -> int:
	var phase: String = str(blackboard.get_value("phase", ""))
	if phase == expected_phase:
		return SUCCESS
	return FAILURE
