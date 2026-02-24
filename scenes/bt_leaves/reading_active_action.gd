class_name ReadingActiveAction
extends ActionLeaf

var _time_passed: float = 0.0


func before_run(_actor: Node, _blackboard: Blackboard) -> void:
	_time_passed = 0.0


func tick(actor: Node, blackboard: Blackboard) -> int:
	var main := actor as Control
	var delta: float = actor.get_process_delta_time()

	_time_passed += delta * 3.0
	var rsm_active: int = main.reading_slot_mgr.active_slot
	var rsm_filled: Array[bool] = main.reading_slot_mgr.slot_filled
	for i: int in range(3):
		if i == rsm_active and not rsm_filled[i]:
			var pulse: float = (sin(_time_passed) + 1.0) * 0.5
			var active_color := Color(StoryRenderer.SLOT_COLORS[i])
			main.slot_bgs[i].modulate = active_color.lerp(Color.WHITE, 0.2)
			main.slot_bgs[i].modulate.a = lerp(0.5, 1.0, pulse)
		else:
			main.slot_bgs[i].modulate = Color(1.0, 1.0, 1.0, 0.4)

	var panels_blocking: bool = main.intro_panel.visible or main.loading_panel.visible or main.resolution_panel.visible or main.end_screen.visible
	main.hover_spotlight_mgr.update(
		main.reading_vignette, main.player_hand, main.slot_piles,
		main.reading_slot_mgr.active_slot, panels_blocking,
		main.get_global_mouse_position()
	)
	main.card_hover_panel.update_display(main.player_hand)
	main.reading_slot_mgr.process_frame()

	if blackboard.get_value("all_slots_filled", false):
		return SUCCESS

	return RUNNING
