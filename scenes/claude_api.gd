extends Node

signal request_completed(request_id: String, text: String)
signal request_failed(request_id: String, error_message: String)

const API_URL := "https://api.anthropic.com/v1/messages"
const MODEL := "claude-sonnet-4-20250514"
const MAX_TOKENS := 300
const API_VERSION := "2023-06-01"

var _api_key: String = ""
var _pending_requests: Dictionary = {}


func _ready() -> void:
	var config := ConfigFile.new()
	var err := config.load("res://config/api_key.cfg")
	if err == OK:
		_api_key = config.get_value("anthropic", "api_key", "")
	if _api_key.is_empty():
		push_warning("ClaudeAPI: No API key found in config/api_key.cfg — AI readings disabled")


func is_available() -> bool:
	return not _api_key.is_empty()


func generate_reading(
	request_id: String,
	client_name: String,
	story_parts: Array,
	slot_index: int,
	card_name: String,
	card_meaning: String,
	locked_paragraphs: Array[String]
) -> void:
	if not is_available():
		request_failed.emit(request_id, "API key not configured")
		return

	var system_prompt := (
		"You are a mystical tarot card reader with a gothic, atmospheric voice. "
		+ "You speak in second person, addressing the querent directly. "
		+ "Write exactly one paragraph of 2-4 sentences. "
		+ "Be evocative and specific to the card's meaning and the client's situation. "
		+ "Do not use markdown, bullet points, or headers. Just flowing prose."
	)

	var user_prompt := "Client: %s\n\n" % client_name
	user_prompt += "The story unfolds in parts, with card readings woven between them:\n\n"

	for i in range(slot_index + 1):
		user_prompt += "--- Story segment %d ---\n%s\n\n" % [i + 1, story_parts[i]]
		if i < slot_index and not locked_paragraphs[i].is_empty():
			user_prompt += "--- Card reading %d ---\n%s\n\n" % [i + 1, locked_paragraphs[i]]

	user_prompt += "The querent now places card %d of 3.\n" % (slot_index + 1)
	user_prompt += "The card drawn is: %s\n" % card_name.replace("_", " ")
	user_prompt += "Its meaning: %s\n\n" % card_meaning
	user_prompt += "Write the reading paragraph for this moment in the story. It should flow naturally after the story segment above."

	var body := {
		"model": MODEL,
		"max_tokens": MAX_TOKENS,
		"system": system_prompt,
		"messages": [{"role": "user", "content": user_prompt}],
	}

	var json_body := JSON.stringify(body)
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"x-api-key: %s" % _api_key,
		"anthropic-version: %s" % API_VERSION,
	])

	var http_request := HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(
		_on_http_completed.bind(request_id, http_request)
	)

	_pending_requests[request_id] = http_request

	var err := http_request.request(API_URL, headers, HTTPClient.METHOD_POST, json_body)
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
		push_warning("ClaudeAPI: HTTP %d — %s" % [response_code, error_text])
		request_failed.emit(request_id, "HTTP %d" % response_code)
		return

	var json := JSON.new()
	var parse_err := json.parse(body.get_string_from_utf8())
	if parse_err != OK:
		request_failed.emit(request_id, "JSON parse error")
		return

	var response: Dictionary = json.get_data()
	var content: Array = response.get("content", [])
	if content.is_empty():
		request_failed.emit(request_id, "Empty response content")
		return

	var text: String = content[0].get("text", "")
	if text.is_empty():
		request_failed.emit(request_id, "Empty text in response")
		return

	request_completed.emit(request_id, text.strip_edges())


func _cleanup_request(request_id: String) -> void:
	if _pending_requests.has(request_id):
		var http_request: HTTPRequest = _pending_requests[request_id]
		_pending_requests.erase(request_id)
		http_request.queue_free()
