extends Node

signal request_completed(request_id: String, text: String)
signal request_failed(request_id: String, error_message: String)

const POSITION_NAMES := ["past", "present", "future"]

var _api_url: String = "http://localhost:3000/api/reading"
var _pending_requests: Dictionary = {}


func _ready() -> void:
	var config := ConfigFile.new()
	var err := config.load("res://config/api_url.cfg")
	if err == OK:
		var url: String = config.get_value("api", "url", "")
		if not url.is_empty():
			_api_url = url


func is_available() -> bool:
	return not _api_url.is_empty()


func generate_reading(
	request_id: String,
	client_name: String,
	client_context: String,
	slot_cards: Array,
	slot_texts: Array[String],
	target_slot: int
) -> void:
	if not is_available():
		request_failed.emit(request_id, "API URL not configured")
		return

	var slots := []
	for i in range(mini(3, slot_cards.size())):
		var slot := {
			"position": POSITION_NAMES[i],
		}
		var card_data: Dictionary = slot_cards[i] if slot_cards[i] is Dictionary else {}
		var card_name: String = card_data.get("name", "") if not card_data.is_empty() else (slot_cards[i] if slot_cards[i] is String else "")
		if not card_name.is_empty():
			slot["card"] = card_name.replace("_", " ")
			if card_data.has("sentiment"):
				slot["sentiment"] = card_data["sentiment"]
			if card_data.has("keywords"):
				slot["keywords"] = card_data["keywords"]
			if card_data.has("description"):
				slot["description"] = card_data["description"]
		else:
			slot["card"] = null
		if not slot_texts[i].is_empty():
			slot["text"] = slot_texts[i]
		else:
			slot["text"] = null
		slots.append(slot)

	var body := {
		"client": {
			"name": client_name,
			"situation": client_context,
		},
		"slots": slots,
	}

	var json_body := JSON.stringify(body)
	var headers := PackedStringArray([
		"Content-Type: application/json",
	])

	var http_request := HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(
		_on_http_completed.bind(request_id, http_request)
	)

	_pending_requests[request_id] = http_request

	var err := http_request.request(_api_url, headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		_cleanup_request(request_id)
		request_failed.emit(request_id, "HTTP request failed to start: %d" % err)


func cancel_request(request_id: String) -> void:
	if _pending_requests.has(request_id):
		var http_request: HTTPRequest = _pending_requests[request_id]
		http_request.cancel_request()
		_cleanup_request(request_id)


func _on_http_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	request_id: String,
	http_request: HTTPRequest
) -> void:
	_cleanup_request(request_id)

	if result != HTTPRequest.RESULT_SUCCESS:
		request_failed.emit(request_id, "HTTP result error: %d" % result)
		return

	if response_code != 200:
		var error_text := body.get_string_from_utf8()
		push_warning("ReadingAPI: HTTP %d — %s" % [response_code, error_text])
		request_failed.emit(request_id, "HTTP %d" % response_code)
		return

	var json := JSON.new()
	var parse_err := json.parse(body.get_string_from_utf8())
	if parse_err != OK:
		request_failed.emit(request_id, "JSON parse error")
		return

	var response: Dictionary = json.get_data()
	var text: String = response.get("generated", "")
	if text.is_empty():
		request_failed.emit(request_id, "Empty generated text in response")
		return

	request_completed.emit(request_id, text.strip_edges())


func _cleanup_request(request_id: String) -> void:
	if _pending_requests.has(request_id):
		var http_request: HTTPRequest = _pending_requests[request_id]
		_pending_requests.erase(request_id)
		http_request.queue_free()
