extends Node

signal auth_state_changed

const CONFIG := preload("res://SupabaseConfig.gd")
const SESSION_FILE := "user://supabase_session.json"
const SERVER_UNAVAILABLE_MESSAGE := "이메일 로그인·회원가입은 준비 중입니다."

# is_logged_in means a registered account; anonymous Auth users remain guests.
var is_logged_in: bool = false
var is_guest: bool = false
var is_authenticated: bool = false
var user_id: String = ""
var email: String = ""
var nickname: String = ""
var _session: Dictionary = {}
var _busy: bool = false
var _cache_error: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_session()
	var timer := Timer.new()
	timer.wait_time = 30.0
	timer.timeout.connect(_refresh_if_needed)
	add_child(timer)
	timer.start()


func enter_guest_mode() -> String:
	if _busy:
		return "인증 처리 중입니다. 잠시 기다려 주세요."
	if not _cache_error.is_empty():
		return _cache_error
	_busy = true
	var error := ""
	if is_authenticated and _expires_at() > Time.get_unix_time_from_system() + 60:
		error = _save_session()
	else:
		var restoring := not _session.is_empty()
		var endpoint := "/token?grant_type=refresh_token" if restoring else "/signup"
		var payload := {"refresh_token": str(_session.get("refresh_token", ""))} if restoring else {"data": {}}
		var result: Dictionary = await _request(endpoint, payload)
		error = str(result.get("error", ""))
		if error.is_empty():
			error = _accept_session(result.get("data", {}), restoring)
	_busy = false
	return error


func _request(endpoint: String, payload: Dictionary) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 20.0
	http.body_size_limit = 1024 * 1024
	add_child(http)
	var headers := PackedStringArray([
		"apikey: " + CONFIG.PUBLISHABLE_KEY,
		"Content-Type: application/json",
		"Accept: application/json"
	])
	var started := http.request(CONFIG.URL + "/auth/v1" + endpoint, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if started != OK:
		http.queue_free()
		return {"error": "서버에 연결하지 못했습니다. 인터넷 연결을 확인한 뒤 다시 시도해 주세요."}
	var response: Array = await http.request_completed
	http.queue_free()
	if int(response[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"error": "서버 응답을 받지 못했습니다. 인터넷 연결을 확인한 뒤 다시 시도해 주세요."}
	var status := int(response[1])
	var body: PackedByteArray = response[3]
	var json := JSON.new()
	var parse_error := json.parse(body.get_string_from_utf8())
	var parsed = json.data if parse_error == OK else null
	if status < 200 or status >= 300:
		var code := str(parsed.get("error_code", "")) if parsed is Dictionary else ""
		if status == 429:
			return {"error": "인증 요청이 많습니다. 잠시 후 다시 시도해 주세요."}
		if code == "anonymous_provider_disabled":
			return {"error": "Supabase에서 익명 인증을 활성화해 주세요."}
		if code == "captcha_failed":
			return {"error": "서버의 보안 인증 설정을 확인해 주세요. 현재 게임에는 CAPTCHA가 연결되어 있지 않습니다."}
		if code in ["refresh_token_not_found", "refresh_token_already_used", "session_not_found", "user_not_found", "user_banned"]:
			return {"error": "기존 비회원 인증을 복구하지 못했습니다. 로컬 플레이는 가능하며 기존 저장은 유지됩니다."}
		return {"error": "인증에 실패했습니다. 서버 설정을 확인하거나 다시 시도해 주세요. (HTTP %d)" % status}
	if not parsed is Dictionary:
		return {"error": "서버 인증 응답을 확인하지 못했습니다. 다시 시도해 주세요."}
	return {"data": parsed}


func _accept_session(data: Dictionary, restoring: bool) -> String:
	var user = data.get("user", {})
	if not user is Dictionary or str(user.get("id", "")).is_empty() or not bool(user.get("is_anonymous", false)):
		return "비회원 인증 정보를 확인하지 못했습니다."
	if str(data.get("access_token", "")).is_empty() or str(data.get("refresh_token", "")).is_empty():
		return "서버가 인증 토큰을 반환하지 않았습니다."
	if restoring and str(_session.get("user_id", "")) != str(user["id"]):
		return "기존 비회원과 다른 인증 정보입니다. 기존 저장을 보호하기 위해 연결을 중단했습니다."
	_session = {
		"project_url": CONFIG.URL,
		"user_id": str(user["id"]),
		"access_token": str(data["access_token"]),
		"refresh_token": str(data["refresh_token"]),
		"expires_at": int(data.get("expires_at", Time.get_unix_time_from_system() + int(data.get("expires_in", 3600))))
	}
	is_authenticated = true
	is_logged_in = false
	is_guest = true
	user_id = str(user["id"])
	email = ""
	nickname = "비회원"
	auth_state_changed.emit()
	return _save_session()


func _save_session() -> String:
	var temporary := SESSION_FILE + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return "인증 정보의 로컬 저장에 실패했습니다. 저장 공간과 브라우저 설정을 확인해 주세요."
	file.store_string(JSON.stringify(_session))
	file.flush()
	var error := file.get_error()
	file.close()
	if error == OK:
		error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(SESSION_FILE))
	if error != OK:
		return "인증 정보를 저장하지 못했습니다. 다시 시도해 주세요."
	return ""


func _load_session() -> void:
	if not FileAccess.file_exists(SESSION_FILE):
		return
	var json := JSON.new()
	var parse_error := json.parse(FileAccess.get_file_as_string(SESSION_FILE))
	var parsed = json.data if parse_error == OK else null
	if not parsed is Dictionary or str(parsed.get("project_url", "")) != CONFIG.URL:
		_cache_error = "저장된 인증 정보를 읽을 수 없습니다. 로컬 플레이로 기존 저장을 이용할 수 있습니다."
		return
	for key in ["user_id", "access_token", "refresh_token"]:
		if str(parsed.get(key, "")).is_empty():
			_cache_error = "저장된 인증 정보가 불완전합니다. 로컬 플레이로 기존 저장을 이용할 수 있습니다."
			return
	_session = parsed
	# A saved anonymous session must be usable before the login scene is visited again.
	is_guest = true
	is_authenticated = true
	is_logged_in = false
	user_id = str(parsed.get("user_id", ""))
	nickname = "비회원"


func _expires_at() -> float:
	return float(_session.get("expires_at", 0))


func get_access_token() -> String:
	# Future online requests should await this instead of reading cached tokens.
	if _session.is_empty():
		return ""
	if not is_guest:
		is_guest = true
		user_id = str(_session.get("user_id", ""))
	if _expires_at() <= Time.get_unix_time_from_system() + 60:
		if not (await enter_guest_mode()).is_empty():
			return ""
	return str(_session.get("access_token", "")) if is_authenticated else ""


func refresh_access_token() -> String:
	if _session.is_empty():
		return ""
	var waited := 0
	while _busy and waited < 50:
		await get_tree().create_timer(0.1).timeout
		waited += 1
	if _busy:
		print("[auth] refresh is still busy")
		return ""
	is_authenticated = false
	var error := await enter_guest_mode()
	if not error.is_empty():
		print("[auth] refresh failed: ", error)
		return ""
	return str(_session.get("access_token", ""))


func _refresh_if_needed() -> void:
	if _busy or not is_authenticated or _session.is_empty():
		return
	if _expires_at() > Time.get_unix_time_from_system() + 60:
		return
	var error: String = await enter_guest_mode()
	if not error.is_empty() and _expires_at() <= Time.get_unix_time_from_system():
		is_authenticated = false
		auth_state_changed.emit()


func enter_local_guest_mode() -> void:
	# Keep the cached online identity for the next connection attempt.
	is_logged_in = false
	is_guest = true
	is_authenticated = false
	user_id = ""
	email = ""
	nickname = "비회원"
	auth_state_changed.emit()


func sign_in(_email: String, _password: String) -> String:
	return SERVER_UNAVAILABLE_MESSAGE


func sign_up(_email: String, _password: String) -> String:
	return SERVER_UNAVAILABLE_MESSAGE


func sign_out() -> void:
	# Local sign-out only. Does not revoke server tokens or delete game saves.
	if _busy:
		return
	if FileAccess.file_exists(SESSION_FILE):
		if DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_FILE)) != OK:
			return
	_session = {}
	_cache_error = ""
	is_logged_in = false
	is_guest = false
	is_authenticated = false
	user_id = ""
	email = ""
	nickname = ""
	auth_state_changed.emit()
