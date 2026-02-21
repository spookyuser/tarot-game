extends Node

signal request_completed(request_id: String, text: String)
signal request_failed(request_id: String, error_message: String)

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
	reading_state: Dictionary
) -> void:
	if not is_available():
		request_failed.emit(request_id, "API URL not configured")
		return

	if not reading_state.has("game_state") or not reading_state.has("runtime_state"):
		var shape_error := "Invalid reading state payload: missing game_state or runtime_state"
		_debug_log(shape_error, reading_state)
		request_failed.emit(request_id, shape_error)
		return

	var body: Dictionary = reading_state.duplicate(true)

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

	_debug_log("POST %s request_id=%s" % [_api_url, request_id], body)
	var err := http_request.request(_api_url, headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		_debug_log("Failed to start request_id=%s error=%d" % [request_id, err], body)
		_cleanup_request(request_id)
		request_failed.emit(request_id, "HTTP request failed to start: %d" % err)


func cancel_request(request_id: String) -> void:
	if _pending_requests.has(request_id):
		_debug_log("Canceling request_id=%s" % request_id)
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
	var response_text := body.get_string_from_utf8()
	_debug_log(
		"Response received request_id=%s result=%d code=%d" % [request_id, result, response_code],
		{
			"headers": _headers,
			"body": response_text,
		}
	)

	if result != HTTPRequest.RESULT_SUCCESS:
		request_failed.emit(request_id, "HTTP result error: %d" % result)
		return

	if response_code != 200:
		var error_text := response_text
		push_warning("ReadingAPI: HTTP %d — %s" % [response_code, error_text])
		request_failed.emit(request_id, "HTTP %d" % response_code)
		return

	var json := JSON.new()
	var parse_err := json.parse(response_text)
	if parse_err != OK:
		_debug_log("JSON parse error request_id=%s parse_err=%d" % [request_id, parse_err], response_text)
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


func _debug_log(message: String, data: Variant = null) -> void:
	if not OS.is_debug_build():
		return
	if data == null:
		print("[ReadingAPI][Debug] %s" % message)
		return
	print("[ReadingAPI][Debug] %s\n%s" % [message, JSON.stringify(data, "  ")])
