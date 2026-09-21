extends Node

const CONFIG := preload("res://SupabaseConfig.gd")
var _busy := false


func create_room() -> Dictionary:
	if _busy:
		return _failure("busy", "서버 생성 중입니다. 잠시 기다려 주세요.")
	_busy = true
	var token: String = await AuthManager.get_access_token()
	if token.is_empty():
		_busy = false
		return _failure("no_session", "인증 세션이 없습니다. 로그인 화면에서 비회원 인증 후 다시 시도해 주세요.")
	var http := HTTPRequest.new()
	http.timeout = 30.0
	http.body_size_limit = 65536
	add_child(http)
	var started := http.request(CONFIG.URL + "/functions/v1/create-room", PackedStringArray([
		"Authorization: Bearer " + token,
		"apikey: " + CONFIG.PUBLISHABLE_KEY,
		"Content-Type: application/json"
	]), HTTPClient.METHOD_POST, "{}")
	if started != OK:
		http.queue_free()
		_busy = false
		return _failure("request_failed", "서버에 연결하지 못했습니다. 인터넷 연결을 확인해 주세요.")
	var response: Array = await http.request_completed
	http.queue_free()
	_busy = false
	return _decode_response(int(response[0]), int(response[1]), response[3])


func _decode_response(result: int, status: int, body: PackedByteArray) -> Dictionary:
	if result != HTTPRequest.RESULT_SUCCESS:
		return _failure("network_failure", "서버 응답을 받지 못했습니다. 생성 여부가 불확실하므로 재시도 전 Dashboard의 rooms를 확인해 주세요.", status)
	var json := JSON.new()
	var parsed_ok := json.parse(body.get_string_from_utf8()) == OK
	if status < 200 or status >= 300:
		if status == 401:
			return _failure("unauthorized", "인증 세션을 확인하지 못했습니다. 로그인 화면에서 다시 인증해 주세요.", status)
		var code := "function_error"
		if parsed_ok and json.data is Dictionary:
			var received := str(json.data.get("error", ""))
			if received in ["room_creation_failed", "invite_code_exhausted", "server_configuration_error", "auth_unavailable", "upstream_failure", "unexpected_response"]:
				code = received
		var message := "Supabase 함수 오류입니다. 배포 상태와 함수 로그를 확인해 주세요."
		if code in ["room_creation_failed", "invite_code_exhausted"]:
			message = "서버 생성에 실패했습니다. Supabase 함수 로그와 DB 설정을 확인해 주세요."
		return _failure(code, message + " (HTTP %d)" % status, status)
	if not parsed_ok or not json.data is Dictionary:
		return _failure("unexpected_response", "예상하지 못한 서버 응답입니다. 재시도 전 Dashboard의 rooms를 확인해 주세요.", status)
	var data: Dictionary = json.data
	var uuid := RegEx.create_from_string("^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$")
	var code_pattern := RegEx.create_from_string("^[A-Z0-9]{6}$")
	if uuid.search(str(data.get("room_id", ""))) == null or code_pattern.search(str(data.get("invite_code", ""))) == null or data.get("max_players") != 4 or data.get("status") != "lobby":
		return _failure("unexpected_response", "서버 생성 응답이 불완전합니다. 재시도 전 Dashboard의 rooms를 확인해 주세요.", status)
	print("[create-room] success; room_id=", data.room_id)
	return {"data": {"room_id": data.room_id, "invite_code": data.invite_code, "max_players": 4, "status": "lobby"}}


func _failure(code: String, message: String, status: int = 0) -> Dictionary:
	# Never log response bodies, headers or credentials.
	print("[create-room] error=", code, "; HTTP=", status)
	return {"error": code, "message": message}
