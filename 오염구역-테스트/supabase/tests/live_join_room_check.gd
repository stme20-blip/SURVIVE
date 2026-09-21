extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(ProjectSettings.get_setting("application/config/custom_user_dir", "") == "CodexLiveJoinValidation")
	var auth = root.get_node("AuthManager")
	var service = load("res://RoomService.gd").new()
	root.add_child(service)
	assert((await auth.enter_guest_mode()).is_empty())
	var host_id: String = auth.user_id
	var created: Dictionary = await service.create_room()
	assert(created.has("data"))
	var room: Dictionary = created.data
	assert(room.max_players == 4 and room.status == "lobby")
	var second: Dictionary = await _create_second_anonymous_user()
	assert(second.has("data"))
	var session: Dictionary = second.data
	var second_user: Dictionary = session.user
	assert(str(second_user.get("id", "")) != host_id)
	# Isolated test process only: switch the existing client service to user B.
	auth._session = {
		"project_url": "https://emcnxoqmdhksahtaxfqc.supabase.co",
		"user_id": str(second_user.id),
		"access_token": str(session.access_token),
		"refresh_token": str(session.refresh_token),
		"expires_at": int(session.get("expires_at", Time.get_unix_time_from_system() + 3600))
	}
	auth.is_authenticated = true
	auth.is_guest = true
	auth.is_logged_in = false
	auth.user_id = str(second_user.id)
	var joined: Dictionary = await service.join_room(str(room.invite_code).to_lower())
	assert(joined.has("data"))
	assert(joined.data.room_id == room.room_id and not joined.data.is_host and joined.data.member_count == 2)
	var members: Dictionary = await service.get_members(str(room.room_id))
	assert(members.has("data") and members.data.size() == 2)
	var host_count := 0
	var member_count := 0
	for member in members.data:
		host_count += 1 if member.role == "host" else 0
		member_count += 1 if member.user_id == auth.user_id else 0
	assert(host_count == 1 and member_count == 1)
	var rejoined: Dictionary = await service.join_room(str(room.invite_code))
	assert(rejoined.has("data") and rejoined.data.member_count == 2)
	print("LIVE_JOIN_CHECK passed; room_id=", room.room_id, "; invite_code=", room.invite_code, "; member_count=2")
	quit()


func _create_second_anonymous_user() -> Dictionary:
	var config = preload("res://SupabaseConfig.gd")
	var http := HTTPRequest.new()
	http.timeout = 20.0
	root.add_child(http)
	var error := http.request(config.URL + "/auth/v1/signup", PackedStringArray([
		"apikey: " + config.PUBLISHABLE_KEY,
		"Content-Type: application/json", "Accept: application/json"
	]), HTTPClient.METHOD_POST, JSON.stringify({"data": {}}))
	if error != OK:
		http.queue_free()
		return {"error": "request_start"}
	var response: Array = await http.request_completed
	http.queue_free()
	if int(response[0]) != HTTPRequest.RESULT_SUCCESS or int(response[1]) < 200 or int(response[1]) >= 300:
		return {"error": "signup_failed"}
	var json := JSON.new()
	if json.parse((response[3] as PackedByteArray).get_string_from_utf8()) != OK or not json.data is Dictionary:
		return {"error": "signup_response"}
	return {"data": json.data}
