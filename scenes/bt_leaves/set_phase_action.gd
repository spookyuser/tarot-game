class_name SetPhaseAction
extends ActionLeaf

@export var target_phase: String = ""


func tick(_actor: Node, blackboard: Blackboard) -> int:
	blackboard.set_value("phase", target_phase)
	return SUCCESS
