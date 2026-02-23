extends Node

signal request_completed(request_id: String, text: String)
signal request_failed(request_id: String, error_message: String)

signal client_request_completed(request_id: String, client_data: Dictionary)
signal client_request_failed(request_id: String, error_message: String)

const SLOT_COUNT: int = 3
const DEFAULT_ENDPOINT_URL: String = "https://gateway.ai.cloudflare.com/v1/00b4144a8738939d6f258250f7c5f063/tarot/compat/chat/completions"
const CORS_PROXY_URL: String = "https://dibalik.wenhop.workers.dev/?url="
const DEFAULT_MODEL: String = "anthropic/claude-sonnet-4-6"

const BB_KEY_LLM_REQUEST_STATE: StringName = &"llm_request_state"
const BB_KEY_LLM_LAST_ERROR: StringName = &"llm_last_error"
const BB_KEY_LLM_LAST_RESPONSE: StringName = &"llm_last_response"

const REQUEST_KIND_READING: String = "reading"
const REQUEST_KIND_CLIENT: String = "client"
const SYSTEM_PROMPT_READING: String = """You are an oracle in a port town. The cards show what will happen - not metaphors, not advice, but events that are already in motion.

You'll receive a client (who they are, what brought them here) and three reading slots. Exactly one slot has a card placed but no text yet. Write one sentence for that slot.

## Voice
- Second person ("you")
- One sentence. Short enough to read at a glance.
- Concrete and specific: a person's name, a street, an object, a time of day. No abstractions, no metaphors, no poetic flourishes
- These events WILL happen. Write them as settled fact.
- Slightly oblique - the event is clear, but its full meaning may not be obvious yet

## Using the Card
A reversed card means the energy is blocked, inverted, or arrives unwanted. The event still happens - it just cuts differently.

## Slot Positions
- Slot 0: Something arrives or is discovered
- Slot 1: Something shifts or complicates
- Slot 2: Where it leads - a door opens or closes
If earlier slots have text, continue from them. Never contradict what's established.

## Echoes Across Readings
If previous readings from other clients are included, you may OCCASIONALLY reuse a specific detail from an earlier reading - the same street name, object, time of day, or person's name - woven naturally into THIS client's event. Do this rarely (at most once per full reading, and not every reading). Never explain the connection. Never call attention to it. The player notices, or they don't.

Return ONLY the sentence. No JSON. No quotes. No commentary. It should be short and direct enough to fit on a small slip of paper."""

const SYSTEM_PROMPT_CLIENT: String = """You invent people who walk into a tarot reader's tent in a small port town. Each person is real - they have a job, a home, people they care about, a specific problem they can't solve alone.

Output a JSON object:
- \"name\": First name and a descriptor rooted in who they are - their trade, a habit, a reputation.
- \"context\": [MAX 1 sentence] A short direct sentence in first person (\"I\"). What they say when they sit down. Raw, direct, specific. They're stuck and they need answers.

Guidelines:
- They should have problems that are human and that we all understand - not \"I want to find love\" but \"I can't stop arguing with my partner, and I don't know if we can fix it.\" Not \"I'm stressed about money\" but \"I lost my job and I have rent due in three days.\" The more specific, the better. The cards will be more specific in response.

Return ONLY valid JSON. No markdown. No commentary."""

var _endpoint_url: String = DEFAULT_ENDPOINT_URL
var _api_key: String = "67eQd-UKCheP0BYLHV_-rsXoCe8dovdkD2-Gm4Tq"

var _reading_model: String = DEFAULT_MODEL
var _client_model: String = "anthropic/claude-opus-4-6" 
var _pending_requests: Dictionary = {}
var _request_metadata: Dictionary = {}
var _cards_by_name: Dictionary = {}

var _game_blackboard: Blackboard
var _request_state: Dictionary = {}


func _ready() -> void:
	_load_configuration()
	_load_card_data()
	_bind_blackboard_if_available()
	_sync_request_state_to_blackboard()


func initialize(game_blackboard: Blackboard) -> void:
	_game_blackboard = game_blackboard
	_sync_request_state_to_blackboard()


func is_available() -> bool:
	return not _api_key.is_empty()


func generate_reading(request_id: String, reading_state: Dictionary) -> void:
	if not is_available():
		request_failed.emit(request_id, "API key not configured")
		return

	var normalized := _normalize_reading_request(reading_state)
	if normalized.is_empty():
		request_failed.emit(request_id, "Invalid reading state payload")
		return

	var slots: Array = normalized.get("slots", [])
	var target_index: int = _find_target_slot_index(slots)
	if target_index == -1:
		request_failed.emit(request_id, "No target slot found. One slot must have a card with no text.")
		return

	var user_prompt: String = _build_reading_prompt_payload(normalized)
	_queue_messages_request(
		request_id,
		REQUEST_KIND_READING,
		_reading_model,
		SYSTEM_PROMPT_READING,
		user_prompt,
		150,
		-1.0
	)


func generate_client(request_id: String, game_state: Dictionary) -> void:
	if not is_available():
		client_request_failed.emit(request_id, "API key not configured")
		return

	var prompt: String = _build_client_prompt(game_state)
	_queue_messages_request(
		request_id,
		REQUEST_KIND_CLIENT,
		_client_model,
		SYSTEM_PROMPT_CLIENT,
		prompt,
		150,
		0.2
	)


func cancel_request(request_id: String) -> void:
	if not _pending_requests.has(request_id):
		return

	var kind: String = _request_kind_from_metadata(request_id)
	var http_request: HTTPRequest = _pending_requests[request_id]
	http_request.cancel_request()
	_cleanup_request(request_id)
	_set_request_status(request_id, kind, "canceled")


func _queue_messages_request(
	request_id: String,
	kind: String,
	model: String,
	system_prompt: String,
	user_prompt: String,
	max_tokens: int,
	temperature: float
) -> void:
	if _pending_requests.has(request_id):
		cancel_request(request_id)

	var body: Dictionary = {
		"model": model,
		"max_tokens": max_tokens,
		"messages": [
			{
				"role": "system",
				"content": system_prompt,
			},
			{
				"role": "user",
				"content": user_prompt,
			}
		],
	}
	if temperature >= 0.0:
		body["temperature"] = temperature

	var headers := PackedStringArray([
		"content-type: application/json",
		"Authorization: Bearer %s" % _api_key,
	])

	var http_request := HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_http_completed.bind(request_id, kind, http_request))

	_pending_requests[request_id] = http_request
	_request_metadata[request_id] = {
		"kind": kind,
		"model": model,
		"started_unix": Time.get_unix_time_from_system(),
	}
	_set_request_status(request_id, kind, "pending")

	var json_body: String = JSON.stringify(body)
	var target_url: String = _endpoint_url
	if OS.has_feature("web"):
		target_url = CORS_PROXY_URL + _endpoint_url.uri_encode()
	var err: int = http_request.request(target_url, headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		_cleanup_request(request_id)
		var message := "HTTP request failed to start: %d" % err
		_set_request_status(request_id, kind, "failed", message)
		_emit_failure(kind, request_id, message)


func _on_http_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	request_id: String,
	kind: String,
	http_request: HTTPRequest
) -> void:
	if not _pending_requests.has(request_id):
		if is_instance_valid(http_request):
			http_request.queue_free()
		return

	_cleanup_request(request_id)

	if result != HTTPRequest.RESULT_SUCCESS:
		var result_message := "HTTP result error: %d" % result
		_set_request_status(request_id, kind, "failed", result_message)
		_emit_failure(kind, request_id, result_message)
		return

	var response_text: String = body.get_string_from_utf8()
	if response_code != 200:
		var api_error: String = _extract_api_error_message(response_text)
		var status_message := "HTTP %d: %s" % [response_code, api_error]
		_set_request_status(request_id, kind, "failed", status_message)
		_emit_failure(kind, request_id, status_message)
		return

	var parsed_response: Variant = JSON.parse_string(response_text)
	if not (parsed_response is Dictionary):
		var parse_message := "JSON parse error"
		_set_request_status(request_id, kind, "failed", parse_message)
		_emit_failure(kind, request_id, parse_message)
		return

	var response: Dictionary = parsed_response
	var message_text: String = _extract_assistant_text(response)
	if message_text.is_empty():
		var empty_message := "Empty generated text in response"
		_set_request_status(request_id, kind, "failed", empty_message)
		_emit_failure(kind, request_id, empty_message)
		return

	_set_request_status(request_id, kind, "completed")
	_record_last_response(request_id, kind, message_text)

	match kind:
		REQUEST_KIND_READING:
			request_completed.emit(request_id, message_text)
		REQUEST_KIND_CLIENT:
			var client_data: Dictionary = _parse_client_json(message_text)
			var name: String = str(client_data.get("name", "")).strip_edges()
			var context: String = str(client_data.get("context", "")).strip_edges()
			if name.is_empty() or context.is_empty():
				var shape_error := "Invalid client response shape"
				_set_request_status(request_id, kind, "failed", shape_error)
				_emit_failure(kind, request_id, shape_error)
				return
			client_request_completed.emit(
				request_id,
				{
					"name": name,
					"context": context,
				}
			)
		_:
			_emit_failure(kind, request_id, "Unsupported request kind")


func _extract_assistant_text(response: Dictionary) -> String:
	var choices_value: Variant = response.get("choices", [])
	if not (choices_value is Array):
		return ""

	var choices: Array = choices_value
	if choices.is_empty():
		return ""

	var first_choice: Variant = choices[0]
	if not (first_choice is Dictionary):
		return ""

	var message_value: Variant = (first_choice as Dictionary).get("message", {})
	if not (message_value is Dictionary):
		return ""

	var content: String = str((message_value as Dictionary).get("content", "")).strip_edges()
	return content


func _extract_api_error_message(response_text: String) -> String:
	var parsed: Variant = JSON.parse_string(response_text)
	if parsed is Dictionary:
		var dict: Dictionary = parsed
		if dict.has("error") and dict["error"] is Dictionary:
			var error_obj: Dictionary = dict["error"]
			var message: String = str(error_obj.get("message", "")).strip_edges()
			if not message.is_empty():
				return message
		var fallback: String = str(dict.get("message", "")).strip_edges()
		if not fallback.is_empty():
			return fallback

	var trimmed: String = response_text.strip_edges()
	if trimmed.is_empty():
		return "Unknown API error"
	return trimmed.left(200)


func _parse_client_json(raw_text: String) -> Dictionary:
	var cleaned: String = _strip_markdown_code_fence(raw_text.strip_edges())
	var parsed: Variant = JSON.parse_string(cleaned)
	if parsed is Dictionary:
		return parsed

	var open_brace: int = cleaned.find("{")
	var close_brace: int = cleaned.rfind("}")
	if open_brace != -1 and close_brace > open_brace:
		var candidate: String = cleaned.substr(open_brace, close_brace - open_brace + 1)
		var candidate_parsed: Variant = JSON.parse_string(candidate)
		if candidate_parsed is Dictionary:
			return candidate_parsed

	return {}


func _strip_markdown_code_fence(text: String) -> String:
	if not text.begins_with("```"):
		return text

	var lines: PackedStringArray = text.split("\n")
	if lines.size() > 0 and lines[0].begins_with("```"):
		lines.remove_at(0)
	if lines.size() > 0 and lines[lines.size() - 1].strip_edges().begins_with("```"):
		lines.remove_at(lines.size() - 1)
	return "\n".join(lines).strip_edges()


func _normalize_reading_request(reading_state: Dictionary) -> Dictionary:
	if not reading_state.has("game_state"):
		return {}

	var game_state_value: Variant = reading_state.get("game_state", {})
	if not (game_state_value is Dictionary):
		return {}
	var game_state: Dictionary = (game_state_value as Dictionary).duplicate(true)

	var encounters_value: Variant = game_state.get("encounters", [])
	if not (encounters_value is Array):
		return {}
	var encounters: Array = encounters_value
	if encounters.is_empty():
		return {}

	var requested_index: int = int(reading_state.get("active_encounter_index", 0))
	var active_encounter_index: int = clampi(requested_index, 0, encounters.size() - 1)
	var encounter_value: Variant = encounters[active_encounter_index]
	if not (encounter_value is Dictionary):
		return {}
	var encounter: Dictionary = encounter_value

	var client_value: Variant = encounter.get("client", {})
	if not (client_value is Dictionary):
		return {}
	var encounter_client: Dictionary = client_value

	var client_name: String = str(encounter_client.get("name", "")).strip_edges()
	var client_situation: String = str(
		encounter_client.get("context", encounter_client.get("situation", ""))
	).strip_edges()
	if client_name.is_empty() or client_situation.is_empty():
		return {}

	var runtime_state: Dictionary = {}
	var runtime_value: Variant = reading_state.get("runtime_state", {})
	if runtime_value is Dictionary:
		runtime_state = runtime_value

	var runtime_cards: Array = _as_array(runtime_state.get("slot_cards", []))
	var runtime_texts: Array = _as_array(runtime_state.get("slot_texts", []))
	var runtime_orientations: Array = _as_array(runtime_state.get("slot_orientations", []))
	var encounter_slots: Array = _as_array(encounter.get("slots", []))

	var slots: Array = []
	for i: int in range(SLOT_COUNT):
		var has_runtime_card: bool = i < runtime_cards.size()
		var has_runtime_text: bool = i < runtime_texts.size()

		var card_name: String = ""
		var card_text: String = ""
		var orientation: String = ""

		if has_runtime_card or has_runtime_text:
			card_name = _normalize_card_name(_as_string(runtime_cards[i] if has_runtime_card else ""))
			card_text = _as_string(runtime_texts[i] if has_runtime_text else "")
			orientation = _normalize_orientation(runtime_orientations[i] if i < runtime_orientations.size() else "")
		else:
			var encounter_slot_value: Variant = encounter_slots[i] if i < encounter_slots.size() else {}
			var encounter_slot: Dictionary = _normalize_slot(encounter_slot_value, i)
			card_name = _normalize_card_name(encounter_slot.get("card", ""))
			card_text = _as_string(encounter_slot.get("text", ""))
			orientation = _normalize_orientation(encounter_slot.get("orientation", ""))

		slots.append(
			{
				"index": i,
				"card": card_name,
				"text": card_text,
				"orientation": orientation,
			}
		)

	return {
		"client": {
			"name": client_name,
			"situation": client_situation,
		},
		"slots": slots,
		"game_state": game_state,
		"active_encounter_index": active_encounter_index,
	}


func _normalize_slot(slot_input: Variant, index: int) -> Dictionary:
	if not (slot_input is Dictionary):
		return {
			"index": index,
			"card": "",
			"text": "",
			"orientation": "",
		}

	var slot_record: Dictionary = slot_input
	return {
		"index": index,
		"card": _normalize_card_name(_as_string(slot_record.get("card", ""))),
		"text": _as_string(slot_record.get("text", "")),
		"orientation": _normalize_orientation(slot_record.get("orientation", "")),
	}


func _normalize_card_name(card_name: String) -> String:
	return card_name.replace("_", " ").strip_edges()


func _normalize_orientation(value: Variant) -> String:
	var orientation: String = _as_string(value)
	if orientation == "upright" or orientation == "reversed":
		return orientation
	return ""


func _find_target_slot_index(slots: Array) -> int:
	for i: int in range(slots.size()):
		if not (slots[i] is Dictionary):
			continue
		var slot: Dictionary = slots[i]
		var card: String = _as_string(slot.get("card", ""))
		var text: String = _as_string(slot.get("text", ""))
		if not card.is_empty() and text.is_empty():
			return i
	return -1


func _build_reading_prompt_payload(normalized_request: Dictionary) -> String:
	var payload: Dictionary = {
		"client": normalized_request.get("client", {}),
		"slots": _build_enriched_slots(normalized_request.get("slots", [])),
	}

	var previous_readings: Array = _extract_previous_readings(normalized_request)
	if not previous_readings.is_empty():
		payload["previous_readings"] = previous_readings

	return JSON.stringify(payload, "  ")


func _build_enriched_slots(slots_value: Variant) -> Array:
	var slots: Array = _as_array(slots_value)
	var enriched_slots: Array = []

	for slot_value: Variant in slots:
		if not (slot_value is Dictionary):
			continue
		var slot: Dictionary = (slot_value as Dictionary).duplicate(true)
		var card_name: String = _as_string(slot.get("card", ""))
		if card_name.is_empty():
			enriched_slots.append(slot)
			continue

		var lookup_name: String = card_name
		if not _cards_by_name.has(lookup_name):
			lookup_name = card_name.replace(" ", "_")

		if _cards_by_name.has(lookup_name):
			var card_data: Dictionary = _cards_by_name[lookup_name]
			var description: String = _as_string(card_data.get("description", ""))
			if not description.is_empty():
				slot["card_meaning"] = description

			var keywords: Array = _as_array(card_data.get("keywords", []))
			if keywords.is_empty():
				keywords = _as_array(card_data.get("tags", []))
			if not keywords.is_empty():
				slot["card_tags"] = keywords.duplicate(true)

			var outcome: String = _as_string(card_data.get("sentiment", card_data.get("outcome", "")))
			if not outcome.is_empty():
				slot["card_outcome"] = outcome

		enriched_slots.append(slot)

	return enriched_slots


func _extract_previous_readings(normalized_request: Dictionary) -> Array:
	var game_state_value: Variant = normalized_request.get("game_state", {})
	if not (game_state_value is Dictionary):
		return []

	var active_index: int = int(normalized_request.get("active_encounter_index", -1))
	if active_index < 0:
		return []

	var game_state: Dictionary = game_state_value
	var encounters: Array = _as_array(game_state.get("encounters", []))
	if encounters.is_empty():
		return []

	var previous: Array = []
	var start_index: int = maxi(0, active_index - 3)
	for i: int in range(start_index, mini(active_index, encounters.size())):
		if not (encounters[i] is Dictionary):
			continue
		var encounter: Dictionary = encounters[i]
		var client: Dictionary = _as_dict(encounter.get("client", {}))
		var name: String = _as_string(client.get("name", ""))
		if name.is_empty():
			continue

		var readings: Array[String] = []
		var slots: Array = _as_array(encounter.get("slots", []))
		for slot_value: Variant in slots:
			if not (slot_value is Dictionary):
				continue
			var slot: Dictionary = slot_value
			var text: String = _as_string(slot.get("text", ""))
			if not text.is_empty():
				readings.append(text)

		if not readings.is_empty():
			previous.append(
				{
					"client": name,
					"readings": readings,
				}
			)

	return previous


func _build_client_prompt(game_state: Dictionary) -> String:
	var prompt := "A new visitor walks into the tent. Create them."
	var encounters: Array = _as_array(game_state.get("encounters", []))
	if encounters.is_empty():
		return prompt

	var history_lines: Array[String] = []
	var start_index: int = maxi(0, encounters.size() - 4)
	for i: int in range(start_index, encounters.size()):
		if not (encounters[i] is Dictionary):
			continue
		var encounter: Dictionary = encounters[i]
		var client: Dictionary = _as_dict(encounter.get("client", {}))
		var name: String = _as_string(client.get("name", "Unknown"))
		var context: String = _as_string(client.get("context", ""))

		var readings: Array[String] = []
		var slots: Array = _as_array(encounter.get("slots", []))
		for slot_value: Variant in slots:
			if not (slot_value is Dictionary):
				continue
			var slot: Dictionary = slot_value
			var text: String = _as_string(slot.get("text", ""))
			if not text.is_empty():
				readings.append(text)

		var line := "- %s: %s" % [name, context]
		if not readings.is_empty():
			var quoted_readings: Array[String] = []
			for reading: String in readings:
				quoted_readings.append("\"%s\"" % reading)
			line += "\n  Readings: %s" % " / ".join(quoted_readings)
		history_lines.append(line)

	if history_lines.is_empty():
		return prompt

	prompt += "\n\nOther visitors today (for variety - do NOT reference them or their stories):\n"
	prompt += "\n".join(history_lines)
	prompt += "\n\nThis new person has their own life and their own problem. They are not here because of anyone else. Make them distinct from the people above in age, occupation, temperament, and concern."
	return prompt


func _load_configuration() -> void:
	pass


func _load_card_data() -> void:
	_cards_by_name.clear()
	var cards_dir := DirAccess.open("res://data/cards")
	if cards_dir == null:
		return

	cards_dir.list_dir_begin()
	var file_name: String = cards_dir.get_next()
	while not file_name.is_empty():
		if not cards_dir.current_is_dir() and file_name.ends_with(".json"):
			var full_path: String = "res://data/cards/%s" % file_name
			var raw: String = FileAccess.get_file_as_string(full_path)
			var parsed: Variant = JSON.parse_string(raw)
			if parsed is Dictionary:
				var card_data: Dictionary = parsed
				var canonical_name: String = _as_string(card_data.get("name", ""))
				if not canonical_name.is_empty():
					_cards_by_name[canonical_name] = card_data
					_cards_by_name[canonical_name.replace("_", " ")] = card_data
		file_name = cards_dir.get_next()
	cards_dir.list_dir_end()


func _bind_blackboard_if_available() -> void:
	if _game_blackboard != null:
		return
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var blackboard_node: Node = parent_node.get_node_or_null("GameBlackboard")
	if blackboard_node is Blackboard:
		_game_blackboard = blackboard_node


func _set_request_status(request_id: String, kind: String, status: String, detail: String = "") -> void:
	_request_state[request_id] = {
		"kind": kind,
		"status": status,
		"updated_unix": Time.get_unix_time_from_system(),
	}
	if not detail.is_empty():
		var entry: Dictionary = _request_state[request_id]
		entry["detail"] = detail
		_request_state[request_id] = entry
		_record_last_error(request_id, kind, detail)

	_prune_request_state(64)
	_sync_request_state_to_blackboard()


func _prune_request_state(max_entries: int) -> void:
	while _request_state.size() > max_entries:
		var oldest_key: String = ""
		var oldest_time: float = INF
		for request_id: String in _request_state.keys():
			var entry: Dictionary = _request_state[request_id]
			var updated_unix: float = float(entry.get("updated_unix", 0.0))
			if updated_unix < oldest_time:
				oldest_time = updated_unix
				oldest_key = request_id
		if oldest_key.is_empty():
			return
		_request_state.erase(oldest_key)


func _sync_request_state_to_blackboard() -> void:
	if _game_blackboard == null:
		return
	_game_blackboard.set_value(BB_KEY_LLM_REQUEST_STATE, _request_state.duplicate(true))


func _record_last_error(request_id: String, kind: String, detail: String) -> void:
	if _game_blackboard == null:
		return
	_game_blackboard.set_value(
		BB_KEY_LLM_LAST_ERROR,
		{
			"request_id": request_id,
			"kind": kind,
			"detail": detail,
			"updated_unix": Time.get_unix_time_from_system(),
		}
	)


func _record_last_response(request_id: String, kind: String, text: String) -> void:
	if _game_blackboard == null:
		return
	_game_blackboard.set_value(
		BB_KEY_LLM_LAST_RESPONSE,
		{
			"request_id": request_id,
			"kind": kind,
			"text": text,
			"updated_unix": Time.get_unix_time_from_system(),
		}
	)


func _request_kind_from_metadata(request_id: String) -> String:
	if not _request_metadata.has(request_id):
		return "unknown"
	var metadata: Dictionary = _request_metadata[request_id]
	return _as_string(metadata.get("kind", "unknown"))


func _emit_failure(kind: String, request_id: String, message: String) -> void:
	match kind:
		REQUEST_KIND_READING:
			request_failed.emit(request_id, message)
		REQUEST_KIND_CLIENT:
			client_request_failed.emit(request_id, message)
		_:
			request_failed.emit(request_id, message)


func _cleanup_request(request_id: String) -> void:
	if _pending_requests.has(request_id):
		var http_request: HTTPRequest = _pending_requests[request_id]
		_pending_requests.erase(request_id)
		if is_instance_valid(http_request):
			http_request.queue_free()
	_request_metadata.erase(request_id)


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _as_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _as_string(value: Variant) -> String:
	if value == null:
		return ""
	return str(value).strip_edges()
