extends Node

signal request_completed(request_id: String, text: String)
signal request_failed(request_id: String, error_message: String)

signal client_request_completed(request_id: String, client_data: Dictionary)
signal client_request_failed(request_id: String, error_message: String)

signal end_summary_request_completed(request_id: String, text: String)
signal end_summary_request_failed(request_id: String, error_message: String)

var _api_url: String = "http://localhost:3000/api/reading"
var _api_clients_url: String = "http://localhost:3000/api/clients"
var _api_summary_url: String = "http://localhost:3000/api/summary"
var _pending_requests: Dictionary = {}


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load("res://config/api_url.cfg") != OK:
		return
	var url: String = config.get_value("api", "url", "")
	if not url.is_empty():
		_api_url = url
	var clients_url: String = config.get_value("api", "clients_url", "")
	if not clients_url.is_empty():
		_api_clients_url = clients_url
	var summary_url: String = config.get_value("api", "summary_url", "")
	if not summary_url.is_empty():
		_api_summary_url = summary_url


func is_available() -> bool:
	return not _api_url.is_empty()


func generate_reading(request_id: String, reading_state: Dictionary) -> void:
	if not is_available():
		request_failed.emit(request_id, "API URL not configured")
		return

	if not reading_state.has("game_state") or not reading_state.has("runtime_state"):
		var shape_error := "Invalid reading state payload: missing game_state or runtime_state"
		_debug_log(shape_error, reading_state)
		request_failed.emit(request_id, shape_error)
		return

	_make_post_request(
		_api_url,
		request_id,
		reading_state.duplicate(true),
		_on_http_completed,
		func(rid: String, msg: String) -> void: request_failed.emit(rid, msg)
	)


func generate_client(request_id: String, game_state: Dictionary) -> void:
	if _api_clients_url.is_empty():
		client_request_failed.emit(request_id, "Clients API URL not configured")
		return

	_make_post_request(
		_api_clients_url,
		request_id,
		{"game_state": game_state},
		_on_client_http_completed,
		func(rid: String, msg: String) -> void: client_request_failed.emit(rid, msg)
	)


func generate_end_summary(request_id: String, game_state: Dictionary) -> void:
	if _api_summary_url.is_empty():
		end_summary_request_failed.emit(request_id, "Summary API URL not configured")
		return

	_make_post_request(
		_api_summary_url,
		request_id,
		{"game_state": game_state},
		_on_end_summary_http_completed,
		func(rid: String, msg: String) -> void: end_summary_request_failed.emit(rid, msg)
	)


func cancel_request(request_id: String) -> void:
	if not _pending_requests.has(request_id):
		return
	_debug_log("Canceling request_id=%s" % request_id)
	var http_request: HTTPRequest = _pending_requests[request_id]
	http_request.cancel_request()
	_cleanup_request(request_id)


# --- Private ---

func _make_post_request(
	url: String,
	request_id: String,
	body: Dictionary,
	on_complete: Callable,
	on_start_fail: Callable
) -> void:
	var json_body := JSON.stringify(body)
	var headers := PackedStringArray(["Content-Type: application/json"])

	var http_request := HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(on_complete.bind(request_id, http_request))
	_pending_requests[request_id] = http_request

	_debug_log("POST %s request_id=%s" % [url, request_id], body)
	var err: int = http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		_debug_log("Failed to start request_id=%s error=%d" % [request_id, err], body)
		_cleanup_request(request_id)
		on_start_fail.call(request_id, "HTTP request failed to start: %d" % err)


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
		{"headers": _headers, "body": response_text}
	)

	if result != HTTPRequest.RESULT_SUCCESS:
		request_failed.emit(request_id, "HTTP result error: %d" % result)
		return

	if response_code != 200:
		push_warning("ReadingAPI: HTTP %d — %s" % [response_code, response_text])
		request_failed.emit(request_id, "HTTP %d" % response_code)
		return

	var json := JSON.new()
	if json.parse(response_text) != OK:
		_debug_log("JSON parse error request_id=%s" % request_id, response_text)
		request_failed.emit(request_id, "JSON parse error")
		return

	var response: Dictionary = json.get_data()
	var text: String = response.get("generated", "")
	if text.is_empty():
		request_failed.emit(request_id, "Empty generated text in response")
		return

	request_completed.emit(request_id, text.strip_edges())


func _on_client_http_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	request_id: String,
	_http_request: HTTPRequest
) -> void:
	_cleanup_request(request_id)
	var response_text := body.get_string_from_utf8()
	_debug_log(
		"Client response received request_id=%s result=%d code=%d" % [request_id, result, response_code],
		{"headers": _headers, "body": response_text}
	)

	if result != HTTPRequest.RESULT_SUCCESS:
		client_request_failed.emit(request_id, "HTTP result error: %d" % result)
		return

	if response_code != 200:
		push_warning("ReadingAPI: HTTP %d — %s" % [response_code, response_text])
		client_request_failed.emit(request_id, "HTTP %d" % response_code)
		return

	var json := JSON.new()
	if json.parse(response_text) != OK:
		_debug_log("JSON parse error request_id=%s" % request_id, response_text)
		client_request_failed.emit(request_id, "JSON parse error")
		return

	var response: Dictionary = json.get_data()
	if not response.has("name") or not response.has("context"):
		client_request_failed.emit(request_id, "Invalid client response shape")
		return

	client_request_completed.emit(request_id, response)


func _on_end_summary_http_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
	request_id: String,
	_http_request: HTTPRequest
) -> void:
	_cleanup_request(request_id)
	var response_text := body.get_string_from_utf8()
	_debug_log(
		"Summary response received request_id=%s result=%d code=%d" % [request_id, result, response_code],
		{"headers": _headers, "body": response_text}
	)

	if result != HTTPRequest.RESULT_SUCCESS:
		end_summary_request_failed.emit(request_id, "HTTP result error: %d" % result)
		return

	if response_code != 200:
		push_warning("ReadingAPI: HTTP %d — %s" % [response_code, response_text])
		end_summary_request_failed.emit(request_id, "HTTP %d" % response_code)
		return

	var json := JSON.new()
	if json.parse(response_text) != OK:
		_debug_log("JSON parse error request_id=%s" % request_id, response_text)
		end_summary_request_failed.emit(request_id, "JSON parse error")
		return

	var response: Dictionary = json.get_data()
	if not response.has("summary"):
		end_summary_request_failed.emit(request_id, "Invalid summary response shape")
		return

	end_summary_request_completed.emit(request_id, response.get("summary", ""))


func _cleanup_request(request_id: String) -> void:
	if not _pending_requests.has(request_id):
		return
	var http_request: HTTPRequest = _pending_requests[request_id]
	_pending_requests.erase(request_id)
	http_request.queue_free()


func _debug_log(message: String, data: Variant = null) -> void:
	if not OS.is_debug_build():
		return
	if data == null:
		print("[ReadingAPI][Debug] %s" % message)
	else:
		print("[ReadingAPI][Debug] %s\n%s" % [message, JSON.stringify(data, "  ")])
