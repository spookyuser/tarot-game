class_name GameStateHelpers
extends RefCounted

const BB_KEY_GAME_STATE: StringName = &"game_state"


static func get_game_state(bb: Blackboard, fallback: Dictionary = {"encounters": []}) -> Dictionary:
	if bb == null:
		return fallback.duplicate(true)
	var game_state: Variant = bb.get_value(BB_KEY_GAME_STATE, fallback)
	if game_state is Dictionary:
		return (game_state as Dictionary).duplicate(true)
	return fallback.duplicate(true)


static func set_game_state(bb: Blackboard, game_state: Dictionary) -> void:
	if bb == null:
		return
	bb.set_value(BB_KEY_GAME_STATE, game_state.duplicate(true))
