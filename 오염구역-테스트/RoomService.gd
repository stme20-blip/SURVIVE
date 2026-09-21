extends Node

const CONFIG := preload("res://SupabaseConfig.gd")
var _busy := false


func create_room(display_name: String, episode_id: String) -> Dictionary:
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
	]), HTTPClient.METHOD_POST, JSON.stringify({"display_name": display_name.strip_edges().left(20), "episode_id": episode_id}))
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
	if uuid.search(str(data.get("room_id", ""))) == null or code_pattern.search(str(data.get("invite_code", ""))) == null or data.get("max_players") != 4 or data.get("status") != "lobby" or data.get("episode_id") not in ["school", "hospital"]:
		return _failure("unexpected_response", "서버 생성 응답이 불완전합니다. 재시도 전 Dashboard의 rooms를 확인해 주세요.", status)
	print("[create-room] success; room_id=", data.room_id)
	return {"data": {"room_id": data.room_id, "invite_code": data.invite_code, "max_players": 4, "status": "lobby", "episode_id": data.episode_id}}


func _failure(code: String, message: String, status: int = 0) -> Dictionary:
	# Never log response bodies, headers or credentials.
	print("[create-room] error=", code, "; HTTP=", status)
	return {"error": code, "message": message}


func join_room(invite_code: String) -> Dictionary:
	var code := invite_code.strip_edges().to_upper()
	if RegEx.create_from_string("^[A-HJ-NP-Z2-9]{6}$").search(code) == null:
		return _online_failure("INVALID_INVITE_CODE")
	var result: Dictionary = await _online_request("/functions/v1/join-room", HTTPClient.METHOD_POST, {"invite_code": code})
	if result.has("error"):
		return result
	return _validate_join(result.data, code)


func _validate_join(data: Variant, code: String) -> Dictionary:
	if not data is Dictionary:
		return _online_failure("UNEXPECTED_RESPONSE")
	if not _is_uuid(data.get("room_id")) or not _is_uuid(data.get("host_user_id")) or data.get("invite_code") != code or not data.get("is_host") is bool or data.get("is_host") != (data.get("host_user_id") == AuthManager.user_id) or data.get("max_players") != 4 or data.get("status") not in ["lobby", "playing"] or data.get("episode_id") not in ["school", "hospital"]:
		return _online_failure("UNEXPECTED_RESPONSE")
	var count = data.get("member_count")
	if not (count is int or count is float) or count != int(count) or count < 1 or count > 4:
		return _online_failure("UNEXPECTED_RESPONSE")
	print("[join-room] success; room_id=", data.room_id, "; is_host=", data.is_host)
	return {"data": data}


func get_members(room_id: String) -> Dictionary:
	if not _is_uuid(room_id):
		return _online_failure("UNEXPECTED_RESPONSE", 0, true)
	# Web uses the same CORS-safe Edge route as create/join. The function verifies membership.
	var result: Dictionary = await _online_request("/functions/v1/get-room-members", HTTPClient.METHOD_POST, {"room_id": room_id})
	if result.has("error"):
		return result
	if not result.data is Dictionary:
		return _online_failure("UNEXPECTED_RESPONSE", 0, true)
	return _validate_members(result.data.get("members", null))


func update_member_profile(room_id: String, display_name: String) -> Dictionary:
	if not _is_uuid(room_id) or display_name.strip_edges().is_empty():
		return _online_failure("UNEXPECTED_RESPONSE")
	return await _online_request("/functions/v1/update-member-profile", HTTPClient.METHOD_POST, {"room_id": room_id, "display_name": display_name.strip_edges().left(20)})


func leave_room(room_id: String) -> Dictionary:
	return await _online_request("/functions/v1/leave-room", HTTPClient.METHOD_POST, {"room_id": room_id})


func delete_online_room(room_id: String) -> Dictionary:
	return await _online_request("/functions/v1/delete-room", HTTPClient.METHOD_POST, {"room_id": room_id})


func room_comments(payload: Dictionary) -> Dictionary:
	return await _online_request("/functions/v1/room-comments", HTTPClient.METHOD_POST, payload)


func _validate_members(data: Variant) -> Dictionary:
	if not data is Array or data.is_empty() or data.size() > 4:
		return _online_failure("MEMBERS_UNAVAILABLE", 0, true)
	var own_member := false
	var ids: Array = []
	for member in data:
		if not member is Dictionary or not _is_uuid(member.get("user_id")) or member.get("role") not in ["host", "member"] or ids.has(member.get("user_id")):
			return _online_failure("UNEXPECTED_RESPONSE", 0, true)
		ids.append(member.user_id)
		own_member = own_member or member.user_id == AuthManager.user_id
	if not own_member:
		return _online_failure("MEMBERS_UNAVAILABLE", 0, true)
	return {"data": data}


func _is_uuid(value: Variant) -> bool:
	return value is String and RegEx.create_from_string("^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$").search(value) != null


func _online_request(path: String, method: HTTPClient.Method, payload: Dictionary = {}) -> Dictionary:
	var reading := method == HTTPClient.METHOD_GET
	if _busy:
		return _online_failure("BUSY", 0, reading)
	_busy = true
	var token: String = await AuthManager.get_access_token()
	if token.is_empty():
		_busy = false
		return _online_failure("UNAUTHORIZED", 0, reading)
	var http := HTTPRequest.new()
	http.timeout = 30.0
	http.body_size_limit = 65536
	add_child(http)
	var started := http.request(CONFIG.URL + path, PackedStringArray([
		"Authorization: Bearer " + token, "apikey: " + CONFIG.PUBLISHABLE_KEY,
		"Content-Type: application/json", "Accept: application/json"
	]), method, "" if reading else JSON.stringify(payload))
	if started != OK:
		http.queue_free()
		_busy = false
		return _online_failure("NETWORK_ERROR", 0, reading)
	var response: Array = await http.request_completed
	http.queue_free()
	_busy = false
	if int(response[0]) != HTTPRequest.RESULT_SUCCESS:
		return _online_failure("NETWORK_ERROR", int(response[1]), reading)
	var json := JSON.new()
	var body: PackedByteArray = response[3]
	var parsed := json.parse(body.get_string_from_utf8()) == OK
	var status := int(response[1])
	if status == 401:
		var refreshed_token: String = await AuthManager.refresh_access_token()
		if not refreshed_token.is_empty():
			var retry := HTTPRequest.new()
			retry.timeout = 30.0
			retry.body_size_limit = 65536
			add_child(retry)
			var retry_started := retry.request(CONFIG.URL + path, PackedStringArray(["Authorization: Bearer " + refreshed_token, "apikey: " + CONFIG.PUBLISHABLE_KEY, "Content-Type: application/json", "Accept: application/json"]), method, "" if reading else JSON.stringify(payload))
			if retry_started == OK:
				var retry_response: Array = await retry.request_completed
				status = int(retry_response[1])
				body = retry_response[3]
				parsed = json.parse(body.get_string_from_utf8()) == OK
			retry.queue_free()
	if status < 200 or status >= 300:
		var code := "JOIN_FAILED"
		if parsed and json.data is Dictionary:
			var received := str(json.data.get("error", ""))
			if received in ["ROOM_NOT_FOUND", "ROOM_FULL", "ROOM_CLOSED", "UNAUTHORIZED", "INVALID_INVITE_CODE", "NETWORK_ERROR", "ROOM_ACCESS_DENIED", "EPISODE_NOT_READY"]:
				code = received
		if status == 401:
			code = "UNAUTHORIZED"
		return _online_failure(code, status, reading)
	if not parsed:
		return _online_failure("UNEXPECTED_RESPONSE", status, reading)
	return {"data": json.data}


func _online_failure(code: String, status: int = 0, reading: bool = false) -> Dictionary:
	var messages := {
		"ROOM_NOT_FOUND": "존재하지 않는 초대 코드입니다.",
		"ROOM_FULL": "이미 참가 인원이 가득 찬 서버입니다.",
		"ROOM_CLOSED": "종료된 서버입니다.",
		"UNAUTHORIZED": "인증 정보가 만료되었습니다. 다시 접속해주세요.",
		"NETWORK_ERROR": "서버에 연결할 수 없습니다.",
		"INVALID_INVITE_CODE": "6자리 초대 코드를 확인해주세요. I, O, 0, 1은 사용하지 않습니다.",
		"BUSY": "요청 처리 중입니다. 잠시 기다려 주세요.",
		"ROOM_ACCESS_DENIED": "이 서버의 참가자 목록을 볼 권한이 없습니다."
	}
	var fallback := "참가자 목록을 불러오지 못했습니다. 다시 시도해 주세요." if reading else "서버 참가 중 오류가 발생했습니다."
	print("[room-service]", " error=", code, "; HTTP=", status)
	return {"error": code, "message": messages.get(code, fallback)}
