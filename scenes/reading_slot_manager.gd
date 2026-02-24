class_name ReadingSlotManager
extends Node

const READING_LOADING_TEXT: String = "The cards are speaking..."
const READING_ERROR_TEXT: String = "The cards are silent..."

signal slot_locked(slot_index: int, card_name: String, display_name: String, reading: String)
signal all_slots_filled()
signal reading_received(slot_index: int, text: String)
signal story_changed()
signal request_reading_sound(suit: String)
signal request_stop_reading_sound()
signal request_card_drop_sound()
signal waiting_for_reading_started(slot_index: int)
signal waiting_for_reading_ended(slot_index: int)

var slot_filled: Array[bool] = [false, false, false]
var slot_readings: Array[String] = ["", "", ""]
var active_slot: int = 0
var current_hover_slot: int = -1
var hover_preview_text: String = ""

var _slot_prev_counts: Array[int] = [0, 0, 0]
var _reading_cache: Dictionary = {}
var _current_hover_card_name: String = ""
var _pending_requests: Dictionary = {}
var _loading_slots: Dictionary = {}
var _waiting_for_reading_slot: int = -1

var _slot_piles: Array[Pile] = []
var _slot_labels: Array[Label] = []
var _reading_labels: Array[RichTextLabel] = []
var _player_hand: Hand
var _claude_api: Node
var _game_blackboard: Node

var _encounter_index: int = 0


func initialize(
	p_slot_piles: Array[Pile],
	p_slot_labels: Array[Label],
	p_reading_labels: Array[RichTextLabel],
	p_player_hand: Hand,
	p_claude_api: Node,
	p_game_blackboard: Node
) -> void:
	_slot_piles = p_slot_piles
	_slot_labels = p_slot_labels
	_reading_labels = p_reading_labels
	_player_hand = p_player_hand
	_claude_api = p_claude_api
	_game_blackboard = p_game_blackboard

	_claude_api.request_completed.connect(_on_claude_request_completed)
	_claude_api.request_failed.connect(_on_claude_request_failed)


func reset_for_client(encounter_index: int) -> void:
	_encounter_index = encounter_index

	slot_filled = [false, false, false]
	_slot_prev_counts = [0, 0, 0]
	slot_readings = ["", "", ""]
	_reading_cache.clear()
	active_slot = 0
	current_hover_slot = -1
	_current_hover_card_name = ""
	hover_preview_text = ""
	_pending_requests.clear()
	_loading_slots.clear()
	_waiting_for_reading_slot = -1

	for i: int in range(3):
		_reading_labels[i].text = ""
		_slot_piles[i].enable_drop_zone = (i == 0)

	_update_slot_labels()


func process_frame() -> void:
	_update_hover_previews()
	_detect_drops()


func cleanup() -> void:
	for request_id: String in _pending_requests.keys():
		_claude_api.cancel_request(request_id)
	_pending_requests.clear()
	_loading_slots.clear()
	current_hover_slot = -1
	_current_hover_card_name = ""
	hover_preview_text = ""
	_waiting_for_reading_slot = -1


# --- Hover Preview System ---


func _update_hover_previews() -> void:
	if active_slot >= 3:
		return

	var new_hover_slot: int = -1
	var new_hover_card_name: String = ""

	if Card.holding_card_count > 0:
		var held_card: Card = _find_held_card()
		if held_card != null:
			new_hover_card_name = held_card.card_name
			if _slot_piles[active_slot].drop_zone != null and _slot_piles[active_slot].drop_zone.check_mouse_is_in_drop_zone():
				new_hover_slot = active_slot

	# Hover exit
	if current_hover_slot != -1 and (current_hover_slot != new_hover_slot or _current_hover_card_name != new_hover_card_name):
		request_stop_reading_sound.emit()
		if not slot_filled[current_hover_slot]:
			_reading_labels[current_hover_slot].text = ""
			hover_preview_text = ""
			story_changed.emit()
		if _loading_slots.has(current_hover_slot):
			_loading_slots.erase(current_hover_slot)
			if current_hover_slot == active_slot:
				_slot_piles[active_slot].enable_drop_zone = true

	# No card hovering
	if new_hover_slot == -1:
		if current_hover_slot != -1:
			if not slot_filled[active_slot]:
				_reading_labels[active_slot].text = ""
			hover_preview_text = ""
			story_changed.emit()
			if _loading_slots.has(active_slot):
				_loading_slots.erase(active_slot)
				_slot_piles[active_slot].enable_drop_zone = true
		current_hover_slot = -1
		_current_hover_card_name = ""
		return

	# Same hover as last frame
	if new_hover_slot == current_hover_slot and new_hover_card_name == _current_hover_card_name:
		return

	# Hover enter
	current_hover_slot = new_hover_slot
	_current_hover_card_name = new_hover_card_name

	var held_card: Card = _find_held_card()
	var orientation_key: String = "reversed" if (held_card != null and held_card.is_reversed) else "upright"
	var cache_key: String = "%s:%s:%d" % [new_hover_card_name, orientation_key, new_hover_slot]

	if _reading_cache.has(cache_key):
		var cached: String = _reading_cache[cache_key]
		_reading_labels[new_hover_slot].text = "[color=%s][i][wave amp=20.0 freq=5.0]%s[/wave][/i][/color]" % [StoryRenderer.HOVER_COLORS[new_hover_slot], cached]
		hover_preview_text = cached
		story_changed.emit()
		return

	_reading_labels[new_hover_slot].text = "[color=#6a5a80][i][wave amp=20.0 freq=5.0]%s[/wave][/i][/color]" % READING_LOADING_TEXT
	hover_preview_text = READING_LOADING_TEXT
	story_changed.emit()
	_loading_slots[new_hover_slot] = true
	_slot_piles[active_slot].enable_drop_zone = false

	if held_card == null:
		return

	request_reading_sound.emit(held_card.card_info.get("suit", "major"))

	var request_id: String = cache_key
	_pending_requests[request_id] = new_hover_slot

	var slot_cards: Array[String] = _build_slot_cards(new_hover_slot, held_card)
	var slot_texts: Array[String] = _build_slot_texts()
	var slot_orientations: Array[String] = _build_slot_orientations(new_hover_slot, held_card)
	var request_state: Dictionary = _build_reading_request_state(slot_cards, slot_texts, slot_orientations)

	_claude_api.generate_reading(request_id, request_state)


# --- Drop Detection ---


func _detect_drops() -> void:
	if active_slot >= 3:
		return

	var i: int = active_slot
	var current_count: int = _slot_piles[i].get_card_count()
	if current_count > 0 and _slot_prev_counts[i] == 0:
		_lock_slot(i)
	_slot_prev_counts[i] = current_count


func _lock_slot(slot_index: int) -> void:
	request_card_drop_sound.emit()
	request_stop_reading_sound.emit()
	slot_filled[slot_index] = true
	_slot_piles[slot_index].enable_drop_zone = false

	var cards: Array[Card] = _slot_piles[slot_index].get_top_cards(1)
	if cards.size() > 0:
		var card: Card = cards[0]
		var orient_key: String = "reversed" if card.is_reversed else "upright"
		var cache_key: String = "%s:%s:%d" % [card.card_name, orient_key, slot_index]

		var reading: String
		if _reading_cache.has(cache_key):
			reading = _reading_cache[cache_key]
		else:
			reading = READING_LOADING_TEXT
			_waiting_for_reading_slot = slot_index
			waiting_for_reading_started.emit(slot_index)

		slot_readings[slot_index] = reading
		_reading_labels[slot_index].text = reading
		_persist_slot_state(slot_index, card.card_name, orient_key, reading)

		var display_name: String = StoryRenderer.humanize_token(card.card_name)
		if card.is_reversed:
			display_name += " (Reversed)"
		_slot_labels[slot_index].text = display_name
		_slot_labels[slot_index].self_modulate = Color(0.85, 0.7, 0.4, 1.0)

		slot_locked.emit(slot_index, card.card_name, display_name, reading)

	_invalidate_unfilled_caches()

	current_hover_slot = -1
	_current_hover_card_name = ""
	hover_preview_text = ""
	_loading_slots.erase(slot_index)

	active_slot = slot_index + 1
	if active_slot < 3:
		_slot_piles[active_slot].enable_drop_zone = true

	_update_slot_labels()
	story_changed.emit()

	if slot_filled[0] and slot_filled[1] and slot_filled[2]:
		all_slots_filled.emit()


# --- API Callbacks ---


func _on_claude_request_completed(request_id: String, text: String) -> void:
	_reading_cache[request_id] = text
	request_stop_reading_sound.emit()

	if not _pending_requests.has(request_id):
		return
	var slot_index: int = _pending_requests[request_id]
	_pending_requests.erase(request_id)
	_loading_slots.erase(slot_index)

	var card_name: String = request_id.get_slice(":", 0)

	if slot_filled[slot_index]:
		slot_readings[slot_index] = text
		_reading_labels[slot_index].text = text
		_persist_slot_text(slot_index, text)
		story_changed.emit()
		if _waiting_for_reading_slot == slot_index:
			_waiting_for_reading_slot = -1
			waiting_for_reading_ended.emit(slot_index)
		reading_received.emit(slot_index, text)
	elif current_hover_slot == slot_index and _current_hover_card_name == card_name:
		_reading_labels[slot_index].text = "[color=%s][i][wave amp=20.0 freq=5.0]%s[/wave][/i][/color]" % [StoryRenderer.HOVER_COLORS[slot_index], text]
		hover_preview_text = text
		story_changed.emit()
		if slot_index == active_slot and not slot_filled[slot_index]:
			_slot_piles[active_slot].enable_drop_zone = true
	else:
		if slot_index == active_slot and not slot_filled[slot_index]:
			_reading_labels[slot_index].text = ""
			_slot_piles[active_slot].enable_drop_zone = true


func _on_claude_request_failed(request_id: String, _error_message: String) -> void:
	if not _pending_requests.has(request_id):
		return
	var slot_index: int = _pending_requests[request_id]
	_pending_requests.erase(request_id)
	_loading_slots.erase(slot_index)
	if slot_index == active_slot and not slot_filled[slot_index]:
		_slot_piles[active_slot].enable_drop_zone = true

	_reading_cache[request_id] = READING_ERROR_TEXT

	var card_name: String = request_id.get_slice(":", 0)

	if slot_filled[slot_index]:
		slot_readings[slot_index] = READING_ERROR_TEXT
		_reading_labels[slot_index].text = READING_ERROR_TEXT
		_persist_slot_text(slot_index, READING_ERROR_TEXT)
		story_changed.emit()
		if _waiting_for_reading_slot == slot_index:
			_waiting_for_reading_slot = -1
			waiting_for_reading_ended.emit(slot_index)
		reading_received.emit(slot_index, READING_ERROR_TEXT)
	elif current_hover_slot == slot_index and _current_hover_card_name == card_name:
		_reading_labels[slot_index].text = "[color=#a05a5a][i][wave amp=20.0 freq=5.0]%s[/wave][/i][/color]" % READING_ERROR_TEXT
		hover_preview_text = READING_ERROR_TEXT
		story_changed.emit()


# --- Helpers ---


func _find_held_card() -> Card:
	return CardUtils.find_held_card(_player_hand)


func _update_slot_labels() -> void:
	for i: int in range(3):
		if slot_filled[i]:
			pass
		elif i == active_slot:
			_slot_labels[i].text = "Place a card"
			_slot_labels[i].self_modulate = Color(0.85, 0.7, 0.4, 1.0)
		else:
			_slot_labels[i].text = ""


func _invalidate_unfilled_caches() -> void:
	var keys_to_erase: Array[String] = []
	for key: String in _reading_cache.keys():
		var parts: PackedStringArray = key.split(":")
		if parts.size() == 3:
			var idx: int = parts[2].to_int()
			if not slot_filled[idx]:
				keys_to_erase.append(key)
	for key: String in keys_to_erase:
		_reading_cache.erase(key)


func _build_slot_cards(hover_slot: int, hover_card: Card) -> Array[String]:
	var cards: Array[String] = ["", "", ""]
	for i: int in range(3):
		if slot_filled[i]:
			var pile_cards: Array[Card] = _slot_piles[i].get_top_cards(1)
			if pile_cards.size() > 0:
				cards[i] = pile_cards[0].card_name
		elif i == hover_slot and hover_card != null:
			cards[i] = hover_card.card_name
	return cards


func _build_slot_orientations(hover_slot: int, hover_card: Card) -> Array[String]:
	var orientations: Array[String] = ["", "", ""]
	for i: int in range(3):
		if slot_filled[i]:
			var pile_cards: Array[Card] = _slot_piles[i].get_top_cards(1)
			if pile_cards.size() > 0:
				orientations[i] = "reversed" if pile_cards[0].is_reversed else "upright"
		elif i == hover_slot and hover_card != null:
			orientations[i] = "reversed" if hover_card.is_reversed else "upright"
	return orientations


func _build_slot_texts() -> Array[String]:
	return slot_readings.duplicate()


func _build_reading_request_state(slot_cards: Array[String], slot_texts: Array[String], slot_orientations: Array[String] = []) -> Dictionary:
	var full_game_state: Dictionary = _get_game_state()
	var encounter_index: int = maxi(_encounter_index, 0)
	var encounters: Array = full_game_state.get("encounters", [])

	if encounter_index < encounters.size() and encounters[encounter_index] is Dictionary:
		var encounter_state: Dictionary = encounters[encounter_index]
		var encounter_slots: Array = encounter_state.get("slots", [])

		while encounter_slots.size() < 3:
			encounter_slots.append({"card": "", "text": "", "orientation": ""})

		for i: int in range(3):
			var runtime_card: String = slot_cards[i] if i < slot_cards.size() else ""
			var runtime_text: String = slot_texts[i] if i < slot_texts.size() else ""
			var orientation_value: String = slot_orientations[i] if i < slot_orientations.size() else ""

			encounter_slots[i] = {
				"card": runtime_card,
				"text": runtime_text,
				"orientation": orientation_value,
			}

		encounter_state["slots"] = encounter_slots
		encounters[encounter_index] = encounter_state
		full_game_state["encounters"] = encounters

	return {
		"game_state": full_game_state,
		"active_encounter_index": encounter_index,
		"runtime_state": {
			"slot_cards": slot_cards.duplicate(true),
			"slot_texts": slot_texts.duplicate(true),
			"slot_orientations": slot_orientations.duplicate(true) if not slot_orientations.is_empty() else [],
		},
	}


func _persist_slot_state(slot_index: int, card_name: String, orientation: String, text: String) -> void:
	var game_state: Dictionary = _get_game_state()
	var encounters: Array = game_state.get("encounters", [])
	if _encounter_index < 0 or _encounter_index >= encounters.size():
		return
	if not (encounters[_encounter_index] is Dictionary):
		return

	var encounter_state: Dictionary = encounters[_encounter_index]
	var encounter_slots: Array = encounter_state.get("slots", [])
	while encounter_slots.size() < 3:
		encounter_slots.append({"card": "", "text": "", "orientation": ""})

	encounter_slots[slot_index] = {
		"card": card_name,
		"text": text,
		"orientation": orientation,
	}

	encounter_state["slots"] = encounter_slots
	encounters[_encounter_index] = encounter_state
	game_state["encounters"] = encounters
	_set_game_state(game_state)


func _persist_slot_text(slot_index: int, text: String) -> void:
	var slot_state: Dictionary = _get_persisted_slot(slot_index)
	_persist_slot_state(
		slot_index,
		slot_state.get("card", ""),
		slot_state.get("orientation", ""),
		text
	)


func _get_persisted_slot(slot_index: int) -> Dictionary:
	var game_state: Dictionary = _get_game_state()
	var encounters: Array = game_state.get("encounters", [])
	if _encounter_index < 0 or _encounter_index >= encounters.size():
		return {}
	if not (encounters[_encounter_index] is Dictionary):
		return {}

	var encounter_state: Dictionary = encounters[_encounter_index]
	var slots: Array = encounter_state.get("slots", [])
	if slot_index < 0 or slot_index >= slots.size():
		return {}
	if not (slots[slot_index] is Dictionary):
		return {}
	return (slots[slot_index] as Dictionary).duplicate(true)


func _get_game_state() -> Dictionary:
	return GameStateHelpers.get_game_state(_game_blackboard)


func _set_game_state(game_state: Dictionary) -> void:
	GameStateHelpers.set_game_state(_game_blackboard, game_state)
